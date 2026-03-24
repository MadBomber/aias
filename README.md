# aias

Schedule [AIA](https://github.com/madbomber/aia) prompts as cron jobs. Add a `schedule:` key to any prompt's YAML frontmatter — `aias update` does the rest.

No separate configuration file. No daemon. The OS cron daemon runs each job as a fresh `aia` process.

## Installation

```bash
gem install aias
```

Or add to your `Gemfile`:

```ruby
gem "aias"
```

**Requirements:** Ruby >= 3.2, the `aia` CLI installed and reachable in your login shell, `AIA_PROMPTS_DIR` set to your prompts directory.

## Quick Start

**1. Add a schedule to any prompt's frontmatter:**

```yaml
---
schedule: "0 8 * * *"
description: Morning briefing
---
Summarize what happened overnight in the Ruby and AI ecosystems.
```

**2. Validate and install:**

```bash
aias update
```

**3. Verify:**

```bash
aias list
aias check
```

## CLI Commands

| Command | Description |
|---|---|
| `aias update` | Scan prompts, regenerate all crontab entries, install. Primary command. |
| `aias add PATH` | Add or replace a single prompt's cron job without touching others. |
| `aias check` | Diff view: prompts with `schedule:` vs what is installed. |
| `aias list` | Report all installed jobs: prompt ID, schedule, log file. |
| `aias dry-run` | Show what `update` would write without touching the crontab. |
| `aias show PROMPT_ID` | Show the installed crontab entry for a single prompt. |
| `aias next [N]` | Show next scheduled run time for installed jobs (default 5). |
| `aias last [N]` | Show last-run time for installed jobs (default 5). |
| `aias clear` | Remove all aias-managed crontab entries. Non-aias entries untouched. |

### `aias add PATH`

Installs or replaces the cron job for a single prompt file. All other installed jobs are left untouched. Errors immediately if the file has no `schedule:` in its frontmatter or fails validation.

```bash
aias add ~/.prompts/standup.md
# aias: added standup (every weekday at 9:00am (0 9 * * 1-5))

aias add ~/.prompts/drafts/idea.md
# aias [error] 'drafts/idea' has no schedule: in its frontmatter
```

Use `add` when you want to schedule a single new prompt without re-scanning the entire prompts directory. Use `update` to synchronise everything at once.

### Global Option

`--prompts-dir PATH` (alias `-p`) overrides the `AIA_PROMPTS__DIR` / `AIA_PROMPTS_DIR` environment variables for any command that reads prompt files:

```bash
aias --prompts-dir ~/work/prompts update
aias -p ~/work/prompts dry-run
aias -p ~/work/prompts check
```

## Schedule Format

The `schedule:` value accepts either a raw cron expression or a whenever DSL string:

```yaml
schedule: "0 8 * * *"               # cron expression
schedule: "@daily"                   # cron keyword
schedule: "every 1.day at 8:00am"   # whenever DSL
schedule: "every :monday at 9:00am"  # whenever DSL
schedule: "every 6.hours"            # whenever DSL
```

Remove the `schedule:` line to disable scheduling without deleting the prompt.

## Validation

Before installing, `aias` validates each scheduled prompt:

- **Schedule syntax** — cron expression or whenever DSL must be parseable
- **Parameter completeness** — all `parameters:` keys must have default values (interactive input is impossible in cron)
- **AIA binary** — `aia` must be locatable in the login-shell PATH **or** in a known version-manager shim directory (`~/.rbenv/shims`, `~/.rbenv/bin`, `~/.rvm/bin`, `~/.asdf/shims`, `/usr/local/bin`, `/usr/bin`, `/opt/homebrew/bin`)

Invalid prompts are warned and excluded. The remaining valid prompts are installed.

## Logging

Each job logs to `~/.aia/schedule/logs/<prompt_id>.log`. stdout and stderr are combined and always appended.

```
~/.aia/schedule/logs/
  daily_digest.log
  reports/
    weekly.log
```

## Public API

### `Aias::CLI`

Thor-based CLI. All commands are public instance methods.

```ruby
cli = Aias::CLI.new
cli.update       # scan, validate, install
cli.add(path)    # add/replace a single prompt by file path
cli.check        # diff view
cli.list         # print installed jobs
cli.dry_run      # print cron output without installing
cli.show(id)     # show single job
cli.upcoming     # show next scheduled run time (aliased as `next`)
cli.last_run     # show last-run time from log mtime (aliased as `last`)
cli.clear        # remove all aias-managed entries
```

Collaborators are injected via lazy accessors; set instance variables before calling a command to override defaults:

```ruby
cli.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
```

### `Aias::PromptScanner`

```ruby
scanner = Aias::PromptScanner.new(prompts_dir: "/path/to/prompts")
results = scanner.scan              # => Array<Aias::PromptScanner::Result>
result  = scanner.scan_one(path)   # => Aias::PromptScanner::Result (raises on error)
```

`scan_one` accepts an absolute or relative path. It raises `Aias::Error` when the file is missing, outside the prompts directory, or carries no `schedule:` in its frontmatter.

Each `Result` (a frozen `Data` object) has: `prompt_id`, `schedule`, `metadata`, `file_path`.

Raises `Aias::Error` when `AIA_PROMPTS_DIR` is missing or unreadable.

### `Aias::Validator`

```ruby
validator = Aias::Validator.new(
  binary_to_check: "aia",
  fallback_dirs:   Aias::Validator::BINARY_FALLBACK_DIRS
)
vr = validator.validate(scanner_result)  # => Aias::Validator::ValidationResult
vr.valid?   # => true / false
vr.errors   # => Array<String>
```

### `Aias::JobBuilder`

```ruby
builder = Aias::JobBuilder.new(shell: ENV["SHELL"])
builder = Aias::JobBuilder.new(shell: ENV["SHELL"], prompts_dir: "/path/to/prompts")
cron    = builder.build(scanner_result)   # => String (raw cron line)
log     = builder.log_path_for(prompt_id) # => String (absolute path)
```

When `prompts_dir:` is provided, every generated `aia` invocation includes `--prompts-dir DIR` so the cron job targets the same prompts directory that `aias` was run with.

### `Aias::CrontabManager`

```ruby
manager = Aias::CrontabManager.new(crontab_command: "crontab", log_base: "~/.aia/schedule/logs")
manager.install(dsl_string)                  # replace entire aias block
manager.add_job(cron_line, prompt_id)        # upsert one entry; others untouched
manager.clear                                # remove all aias-managed entries
manager.dry_run(dsl_string)                  # => String (cron output, no write)
manager.installed_jobs                       # => Array<Hash> (:prompt_id, :cron_expr, :log_path)
manager.current_block                        # => String (raw aias crontab block)
manager.ensure_log_directories(ids)          # create log subdirs for prompt IDs
```

## How It Works

```
AIA prompt files (YAML frontmatter)
         │
         ▼
  PromptScanner.scan          grep -rl + PM::Metadata parsing
         │
         ▼
  Validator.validate          schedule syntax + parameters + aia binary
         │
         ▼
  JobBuilder.build            prompt ID + schedule → raw cron line
         │
         ▼
  CrontabManager.install      whenever → crontab block replace
         │
         ▼
  OS cron daemon              runs: aia <prompt_id> >> log 2>&1
```

## Development

```bash
bin/setup                        # install dependencies
bundle exec rake test            # run all tests
bundle exec ruby -Ilib:test test/test_cli.rb -n test_method_name  # single test
bin/console                      # interactive REPL
```

## License

[MIT](LICENSE.txt)
