# Architecture

## Overview

`aias` is a thin orchestration layer over three well-established tools: `grep` (for discovery), `PM::Metadata` from the `prompt_manager` gem (for frontmatter parsing), and `whenever` (for crontab management). Its five classes have narrow, well-defined responsibilities.

```
┌─────────────────────────────────────────────────────────────────┐
│                         aias gem                                │
│                                                                 │
│   Aias::CLI                                                     │
│   ├── Aias::PromptScanner   grep -rl + PM::Metadata             │
│   ├── Aias::Validator       schedule syntax + params + binary   │
│   ├── Aias::JobBuilder      prompt ID → whenever DSL            │
│   └── Aias::CrontabManager  whenever → crontab block            │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

```
$AIA_PROMPTS_DIR
      │
      ▼
PromptScanner#scan
      │ returns Array<PromptScanner::Result>
      │   Result = Data.define(:prompt_id, :schedule, :metadata, :file_path)
      ▼
Validator#validate(result)
      │ returns ValidationResult = Data.define(:valid?, :errors)
      ▼
[partition into valid / invalid]
      │
      ├── invalid → warn to stderr, skip
      │
      └── valid ──►  JobBuilder#build(result)
                         │ returns String (whenever DSL)
                         ▼
                    CrontabManager#install(dsl)
                         │ calls Whenever::CommandLine.execute
                         ▼
                    crontab (OS cron daemon manages execution)
```

## Class Responsibilities

### `Aias::CLI`

The entry point. A `Thor` subclass that exposes seven commands. CLI delegates all domain logic to its four collaborators; it only formats output and handles errors.

Collaborators are created lazily and accessible via private accessors (`scanner`, `validator`, `builder`, `manager`). Tests inject replacements by setting instance variables before calling a command.

### `Aias::PromptScanner`

Discovers scheduled prompts in two steps:

1. **grep phase**: runs `grep -rl "schedule:" $AIA_PROMPTS_DIR` via `Open3.capture3` (no shell injection)
2. **parse phase**: for each candidate file, calls `PM.parse(absolute_path)` and reads `metadata.schedule`

Returns an array of frozen `Result` value objects. Raises `Aias::Error` if the prompts directory is missing or unreadable.

### `Aias::Validator`

Validates a single `PromptScanner::Result` against three rules (see [Validation](../guides/validation.md)). Returns a frozen `ValidationResult` value object.

The `aia` binary check is memoised — it runs at most once per `Validator` instance.

The `binary_to_check:` constructor parameter makes the binary check testable without stubs.

### `Aias::JobBuilder`

Pure function: converts a `PromptScanner::Result` into a `whenever` DSL string. No I/O, no side effects.

Uses `ENV["SHELL"]` (defaulting to `/bin/bash`) for the login shell in `job_template`. Log paths follow the pattern `~/.aia/schedule/logs/<prompt_id>.log`.

### `Aias::CrontabManager`

Wraps `whenever`. Three categories of operations:

| Category | Methods | How |
|---|---|---|
| Write | `install(dsl)`, `clear` | `Whenever::CommandLine.execute` with `console: false` |
| Read | `installed_jobs`, `current_block` | Parses crontab via `crontab_command -l` |
| Preview | `dry_run(dsl)` | `Whenever.cron(string: dsl)` — no system calls |

The `crontab_command:` and `log_base:` constructor parameters make the manager fully testable with a fake crontab script backed by a tmpfile — no system crontab is ever touched during tests.

## Key Value Objects

Both value objects are defined with `Data.define` (Ruby 3.2+) and are automatically frozen and immutable.

```ruby
# Returned by PromptScanner#scan
Aias::PromptScanner::Result = Data.define(:prompt_id, :schedule, :metadata, :file_path)

# Returned by Validator#validate
Aias::Validator::ValidationResult = Data.define(:valid?, :errors)
```

## Autoloading

Zeitwerk handles autoloading. The `cli` filename is mapped to `Aias::CLI` (not `Aias::Cli`) via a custom inflection:

```ruby
loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("cli" => "CLI")
loader.setup
```

## Error Handling

A single `Aias::Error < StandardError` is raised for unrecoverable conditions (missing prompts dir, crontab write failure). The CLI rescues it, prints the message, and exits 1.

Recoverable per-prompt issues (invalid schedule, missing parameter defaults) are collected as error strings in `ValidationResult#errors` and never raised as exceptions.
