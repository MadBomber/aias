# Architecture

## Overview

`aias` is a thin orchestration layer over three well-established tools: `grep` (for discovery), `PM::Metadata` from the `prompt_manager` gem (for frontmatter parsing), and `fugit` (for cron expression parsing and natural-language schedule resolution). Its five classes have narrow, well-defined responsibilities.

```
┌─────────────────────────────────────────────────────────────────┐
│                         aias gem                                │
│                                                                 │
│   Aias::CLI                                                     │
│   ├── Aias::PromptScanner   grep -rl + PM::Metadata             │
│   ├── Aias::Validator       schedule syntax + params + binary   │
│   ├── Aias::JobBuilder      prompt ID + schedule → cron line    │
│   └── Aias::CrontabManager  crontab(1) read/write               │
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
                         │ returns String (raw cron line)
                         ▼
                    CrontabManager#install(cron_lines)
                         │ writes via crontab(1) command
                         ▼
                    crontab (OS cron daemon manages execution)
```

## Class Responsibilities

### `Aias::CLI`

The entry point. A `Thor` subclass that exposes nine commands. CLI delegates all domain logic to its four collaborators; it only formats output and handles errors.

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

Pure function: converts a `PromptScanner::Result` into a raw cron line string. No I/O, no side effects.

Uses `fugit` to resolve the `schedule:` value to a canonical 5-field cron expression, then assembles:

```
<cron_expr> <shell> -l -c 'aia [--prompts-dir DIR] <prompt_id> >> <log> 2>&1'
```

Uses `ENV["SHELL"]` (defaulting to `/bin/bash`) as the login shell. Log paths follow the pattern `~/.aia/schedule/logs/<prompt_id>.log`.

### `Aias::CrontabManager`

Manages the aias-owned block in the user's crontab by directly invoking the system `crontab(1)` command via `Open3`. Three categories of operations:

| Category | Methods | How |
|---|---|---|
| Write | `install(cron_lines)`, `add_job(cron_line, prompt_id)`, `clear` | `Open3.popen2(crontab_command, "-")` — pipes new content to stdin |
| Read | `installed_jobs`, `current_block` | `Open3.capture3(crontab_command, "-l")` |
| Preview | `dry_run(cron_lines)` | `Array(cron_lines).join("\n")` — no system calls |

The managed block is delimited by `# BEGIN aias` and `# END aias` marker comments. All other crontab entries are preserved verbatim.

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
