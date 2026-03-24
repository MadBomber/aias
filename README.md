# aias - AI Assistant (AIA) Scheduler

> [!INFO]
> See the [CHANGELOG](CHANGELOG.md) for the latest changes.

<br>
<table>
<tr>
<td width="50%" align="center" valign="top">
<img src="docs/assets/images/logo.jpg" alt="aias"><br>
<em>"Schedule. Batch. Execute."</em>
</td>
<td width="50%" valign="top">
<strong>Key Features</strong><br>

- <strong>Natural Language Scheduling</strong> — <code>schedule:</code> frontmatter accepts cron expressions or plain English (<code>"every weekday at 9am"</code>)<br>
- <strong>Zero Configuration</strong> — No separate config file; prompts describe their own schedule in frontmatter<br>
- <strong>Reliable Cron Environment</strong> — <code>aias install</code> captures PATH, API keys, and <code>AIA_*</code> vars into <code>env.sh</code> so jobs always run with the right environment<br>
- <strong>MCP Server Support</strong> — Capture credentials for GitHub, Homebrew, and any MCP server with glob patterns (<code>'GITHUB_*'</code>)<br>
- <strong>Per-Prompt Overrides</strong> — Frontmatter sets provider, model, flags, and tools per prompt; overrides the shared schedule config<br>
- <strong>Schedule-Specific Config</strong> — Separate <code>~/.config/aia/schedule/aia.yml</code> isolates scheduled jobs from interactive AIA settings<br>
- <strong>Single-Prompt Control</strong> — <code>aias add</code> and <code>aias remove</code> manage individual jobs without touching others<br>
- <strong>Full Sync</strong> — <code>aias update</code> replaces the entire managed crontab block; orphaned entries self-clean<br>
- <strong>Safe Validation</strong> — Rejects invalid schedules and prompts with un-defaulted parameters before touching the crontab<br>
- <strong>Rich Inspection</strong> — <code>list</code>, <code>show</code>, <code>check</code>, <code>next</code>, <code>last</code>, and <code>dry-run</code> commands
</td>
</tr>
</table>

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

**1. Capture your environment (once):**

```bash
aias install
```

**2. Add a schedule to any prompt's frontmatter:**

```yaml
---
schedule: "0 8 * * *"
description: Morning briefing
---
Summarize what happened overnight in the Ruby and AI ecosystems.
```

**3. Validate and install:**

```bash
aias update
```

**4. Verify:**

```bash
aias list
aias check
```

## Environment Setup

Cron runs with a minimal environment — no Ruby version manager, no API keys, no user-defined variables. `aias install` solves this by capturing your current shell environment into `~/.config/aia/schedule/env.sh`, which is sourced before every scheduled job.

### What gets captured automatically

| Variable group | Examples | Why |
|---|---|---|
| `PATH` | rbenv shims, Homebrew, gem bin dirs | `aia` and MCP server binaries must be findable |
| `*_API_KEY` | `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, etc. | LLM provider authentication |
| `AIA_*` | `AIA_PROMPTS__DIR`, `AIA_MODEL`, etc. | AIA runtime configuration |
| `LANG`, `LC_ALL` | `en_US.UTF-8` | Ruby UTF-8 string handling |

### MCP server credentials

If your scheduled prompts use MCP servers, those servers may need their own credentials — auth tokens, configuration paths, or other variables that are not covered by the defaults. Pass glob patterns to `aias install` to capture them:

```bash
# GitHub MCP server (needs a personal access token)
aias install 'GITHUB_*'

# Homebrew MCP server
aias install 'HOMEBREW_*'

# Multiple patterns at once
aias install 'GITHUB_*' 'HOMEBREW_*'
```

Check the documentation for each MCP server you use to identify the variables it reads, then add the corresponding pattern. Re-run `aias install` any time you add a new API key, install a new MCP server binary, or change your Ruby version.

## CLI Commands

| Command | Description |
|---|---|
| `aias install [PATTERN...]` | Capture PATH, API keys, and env vars into `env.sh`. Run once before scheduling. |
| `aias update` | Scan prompts, regenerate all crontab entries, install. Primary command. |
| `aias add PATH` | Add or replace a single prompt's cron job without touching others. |
| `aias remove PROMPT_ID` | Remove a single prompt's cron job. Aliases: `rm`, `delete`. |
| `aias check` | Diff view: prompts with `schedule:` vs what is installed. |
| `aias list` | Report all installed jobs: prompt ID, schedule, log file. |
| `aias dry-run` | Show what `update` would write without touching the crontab. |
| `aias show PROMPT_ID` | Show the installed crontab entry for a single prompt. |
| `aias next [N]` | Show next scheduled run time for installed jobs (default 5). |
| `aias last [N]` | Show last-run time for installed jobs (default 5). |
| `aias clear` | Remove all aias-managed crontab entries. Non-aias entries untouched. |
| `aias uninstall` | Remove the managed env block from `env.sh`. |

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

The `schedule:` value accepts a standard cron expression, a `@`-shorthand keyword, or a natural language string. Natural language parsing is provided by the [fugit](https://github.com/floraison/fugit) gem.

```yaml
schedule: "0 8 * * *"                    # cron expression
schedule: "@daily"                        # @ shorthand
schedule: "every day at 8am"             # natural language
schedule: "every weekday at 9am"         # natural language
schedule: "every monday at 9am"          # natural language
schedule: "every monday through friday at 9am"  # natural language
schedule: "every 6 hours"               # natural language
schedule: "every 30 minutes"            # natural language
schedule: "every 1st of the month at midnight"  # natural language
schedule: "every day at 9am in America/New_York"  # with timezone
```

Natural language strings are resolved to cron expressions at install time. Use `aias dry-run` to preview the resolved expression before installing. See [Scheduling Prompts](docs/guides/scheduling-prompts.md) for the full reference including all supported patterns, limitations, and a quick-reference table.

Once a prompt has been scheduled and resides in the crontab you **cannot** remove it just by deleting or commenting out the `schedule:` line. Run `aias update` (full sync) or `aias remove PROMPT_ID` to remove it.


## Validation

Before installing, `aias` validates each scheduled prompt:

- **Schedule syntax** — cron expression or natural language must be parseable
- **Parameter completeness** — all `parameters:` keys must have default values (interactive input is impossible in cron)
- **AIA binary** — `aia` must be locatable in PATH or a known version-manager shim directory (`~/.rbenv/shims`, `~/.rvm/bin`, `~/.asdf/shims`, `/opt/homebrew/bin`)

Invalid prompts are warned and excluded. The remaining valid prompts are installed.

## Logging

Each job logs to `~/.config/aia/schedule/logs/<prompt_id>.log`. stdout and stderr are combined and overwrite the log on each run.

```
~/.config/aia/schedule/logs/
  daily_digest.log
  reports/
    weekly.log
```

## Public API

### `Aias::CLI`

Thor-based CLI. All commands are public instance methods.

```ruby
cli = Aias::CLI.new
cli.install      # capture environment into env.sh
cli.update       # scan, validate, install
cli.add(path)    # add/replace a single prompt by file path
cli.check        # diff view
cli.list         # print installed jobs
cli.dry_run      # print cron output without installing
cli.show(id)     # show single job
cli.upcoming     # show next scheduled run time (aliased as `next`)
cli.last_run     # show last-run time from log mtime (aliased as `last`)
cli.clear        # remove all aias-managed entries
cli.uninstall    # remove managed env block from env.sh
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
cron    = builder.build(scanner_result, prompts_dir: "/path")  # => String (raw cron line)
log     = builder.log_path_for(prompt_id)                      # => String (absolute path)
```

### `Aias::CrontabManager`

```ruby
manager = Aias::CrontabManager.new
manager.install(cron_lines)                  # replace entire aias block
manager.add_job(cron_line, prompt_id)        # upsert one entry; others untouched
manager.clear                                # remove all aias-managed entries
manager.dry_run(cron_lines)                  # => String (output, no write)
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
  CrontabManager.install      crontab block replace
         │
         ▼
  OS cron daemon
  source env.sh && aia --prompts-dir ... --config ... prompt_id > log 2>&1
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
