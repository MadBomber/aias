# aias - AI Assistant (AIA) Scheduler

> [!INFO]
> See the [CHANGELOG](CHANGELOG.md) for the latest changes.

<br>
<table>
<tr>
<td width="40%" align="center" valign="top">
<img src="docs/assets/images/logo.jpg" alt="aias"><br>
<em>"Schedule. Batch. Execute."</em><br><br>
<a href="https://madbomber.github.io/aias">Full Documentation</a>
</td>
<td width="60%" valign="top">
<h2>Key Features</h2>

- Natural Language Scheduling
- Zero Configuration
- Reliable Cron Environment
- MCP Server Support
- Per-Prompt Overrides
- Schedule-Specific Config
- Single-Prompt Control
- Full Sync on Update
- Safe Validation
- Rich Inspection Commands
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

## Usage

```
$ aias help
Commands:
  aias add PATH              # Add (or replace) a single scheduled prompt in the crontab
  aias check                 # Diff view: scheduled prompts vs what is installed
  aias clear                 # Remove all aias-managed crontab entries
  aias dry-run               # Show what `update` would write without touching the crontab
  aias help [COMMAND]        # Describe available commands or one specific command
  aias install [PATTERN...]  # Capture PATH, API keys, and env vars into ~/.config/aia/schedule/env.sh
  aias last [N]              # Show last-run time for installed jobs (default 5)
  aias list                  # List all installed aias cron jobs
  aias next [N]              # Show next scheduled run time for installed jobs (default 5)
  aias remove PROMPT_ID      # Remove a single scheduled prompt from the crontab
  aias show PROMPT_ID        # Show the installed crontab entry for a single prompt
  aias uninstall             # Remove managed env block from ~/.config/aia/schedule/env.sh
  aias update                # Scan prompts, regenerate all crontab entries, and install
  aias version               # Print the aias version

Options:
  -p, [--prompts-dir=PROMPTS_DIR]  # Prompts directory (overrides AIA_PROMPTS__DIR / AIA_PROMPTS_DIR env vars)
```

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
| `aias version` | Print the installed aias version. |

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

## How It Works

```
Prompt file with schedule: in YAML frontmatter
         │
         ▼
aias update scans prompts directory for schedule: keys
         │
         ▼
Each prompt is validated: schedule syntax, parameter defaults, aia binary
         │
         ▼
A cron entry is written for each valid prompt
         │
         ▼
OS cron daemon runs each job on schedule:
  source env.sh && aia [--prompts-dir DIR] prompt_id > log 2>&1
```

## Development

```bash
bin/setup                                     # install dependencies
bundle exec rake test                         # run all tests
bundle exec ruby -Ilib:test test/test_aias.rb # run a single test file
bin/console                                   # interactive REPL
```

## License

[MIT](LICENSE.txt)
