# aias Gem — Analysis & Requirements

## Origin

Inspired by reviewing the `ai_sentinel` gem (https://github.com/mcelicalderon/ai_sentinel),
a lightweight Ruby gem for scheduling AI-driven automation tasks via YAML-defined workflows
and Rufus-scheduler.

---

## Core Concept

`aias` is a standalone gem that runs AIA prompts as scheduled batch jobs. Schedule
information lives directly in the YAML frontmatter of individual AIA prompt files —
no separate configuration file is needed. The gem scans the prompts directory, discovers
all prompts that declare a `schedule:` key, and installs them as crontab entries via the
`whenever` gem.

The prompts are self-describing — a prompt that wants to run on a schedule says so in
its own frontmatter.

---

## Gem Identity

| Property | Value |
|---|---|
| Gem name | `aias` |
| Binary | `aias` |
| Ruby module | `Aias::` |
| Version | Tracks `aia` version exactly (reads from the same `.version` file) |
| Author / license | Same as `aia` — madbomber's RubyGems account, MIT license |
| Distribution | Standalone gem, released independently from `aia` |
| Entry point | Separate `aias` binary — not an `aia` subcommand |

---

## Scheduling Backend: `whenever`

`whenever` was chosen over `rufus-scheduler` because:

- AIA is already a CLI tool — scheduled jobs are simply `aia <prompt_id>` invocations
- No long-running daemon to manage; the OS cron daemon handles reliability and reboots
- Each job runs as a fresh, clean `aia` process — no shared state between runs
- Crontab entries are visible and auditable with standard Unix tools (`crontab -l`)

`whenever` is normally driven by a hand-written `config/schedule.rb`. `aias` eliminates
that file entirely — it auto-generates the equivalent by scanning prompt frontmatter,
then hands the result to `whenever` to install into the user's crontab.

`whenever` is a **hard dependency** — its marker-block management and cron DSL are not
worth reimplementing.

---

## The `schedule:` Frontmatter Key

A single string value. No hash form. No additional fields.

```yaml
# Raw cron expression
schedule: "0 8 * * *"

# whenever human-readable DSL — both forms accepted
schedule: "every 1.day at 8:00am"
schedule: "every :monday at 9:00am"
schedule: "every 6.hours"
```

Everything else is derived — there is nothing else to configure at the prompt level:

| Concern | Behaviour |
|---|---|
| Enabled / disabled | Presence of `schedule:` means enabled. Remove the line to disable. |
| Log file | Composed from prompt ID: `~/.aia/schedule/logs/<prompt_id>.log` |
| Append vs overwrite | Always append (`>>`). Log entries accumulate across runs. |
| stdout + stderr | Always combined (`2>&1`). No separate error log. |
| AIA flags / model / role | AIA reads these from the prompt's own frontmatter. `aias` passes only the prompt ID. |

### Example scheduled prompt

```yaml
---
name: daily_digest
description: Summarizes overnight news and activity
schedule: "every 1.day at 8:00am"
---
Summarize what happened overnight in the Ruby and AI ecosystems.
```

### Non-scheduled prompt (unchanged, ignored by aias)

```yaml
---
name: ad_hoc
description: An Ad Hoc prompt for on the fly consultations
parameters:
  what_now_human: "I'm going to give you my resume and then we are going to talk about it."
---
<%= what_now_human %>
```

---

## How It Works

### Prompt Discovery

`aias` uses `grep -rl "schedule:" $AIA_PROMPTS_DIR` to find candidate files. This is
recursive, filename-only output, POSIX-standard, and reads only files that actually
contain the word `schedule:` — avoiding loading every prompt in the directory.

The full subpath relative to `$AIA_PROMPTS_DIR` is the prompt ID:

```
~/.prompts/reports/weekly_digest.md  →  aia reports/weekly_digest
~/.prompts/daily_digest.md           →  aia daily_digest
```

### Primary Operation: `aias update`

1. Run `grep -rl "schedule:" $AIA_PROMPTS_DIR` to find candidates
2. Parse frontmatter of each candidate via `PM::Metadata`
3. Validate each scheduled prompt (see Validation below)
4. For valid prompts, build an `aia <prompt_id>` invocation string
5. Generate a complete `whenever`-managed crontab block
6. Install, replacing the previous `aias`-managed block entirely

This is a **full sync on every run**. Orphaned entries (from deleted or de-scheduled
prompts) are automatically removed because the entire block is replaced.

### The Cron Environment

Cron runs in a minimal shell with no PATH, no rbenv/rvm activation, and no user
environment variables. `aias` solves this by wrapping every cron entry in a login
shell invocation, detected from `ENV['SHELL']` at `update` time.

`whenever` supports this natively via `job_template`:

```ruby
set :job_template, "zsh -l -c ':job'"   # or bash -l -c, fish -l -c, etc.
```

The login shell sources the user's profile, providing rbenv, PATH, and all AIA
environment variables automatically. No PATH capture or manual config step required.

### Example Generated Crontab Entry

```
# aias -- reports/daily_digest
0 8 * * *  /bin/zsh -l -c 'aia reports/daily_digest >> ~/.aia/schedule/logs/reports/daily_digest.log 2>&1'
```

---

## CLI Commands

| Command | Description |
|---|---|
| `aias update` | Full sync: scan prompts, regenerate all crontab entries, install. Primary command. |
| `aias clear` | Remove all `aias`-managed entries from crontab. Non-AIA entries untouched. |
| `aias list` | Report all `aias` jobs currently in the crontab: prompt ID, schedule, log file. |
| `aias check` | Diff view: prompts with `schedule:` vs what is installed. Surfaces uninstalled, orphaned, and invalid prompts. |
| `aias dry-run` | Show what `update` would write without touching the crontab. |
| `aias next [N]` | Show next N scheduled run times for all installed jobs (default N=5). |
| `aias show <prompt_id>` | Show the installed crontab entry for a single prompt. |

---

## Architecture

```
aias gem
├── Aias::CLI             (Thor: update, clear, list, check, dry-run, next, show)
├── Aias::PromptScanner   (grep -rl discovery + PM::Metadata frontmatter parsing)
├── Aias::JobBuilder      (prompt ID + schedule string → whenever job definition)
├── Aias::CrontabManager  (wraps whenever; installs/clears/reads managed crontab block)
└── Aias::Validator       (cron expression syntax, parameter defaults, aia binary presence)
```

---

## Validation

Before writing to crontab, `aias` validates each scheduled prompt:

1. **Schedule syntax** — cron expression or whenever DSL string is parseable
2. **Parameter completeness** — all `parameters:` keys must have default values;
   interactive input is impossible in a cron context
3. **AIA binary** — `aia` must be locatable (checked via `which aia` inside the login shell)
4. **Prompts directory** — `$AIA_PROMPTS_DIR` must exist and be readable

On validation failure during `update`: the invalid prompt is warned loudly, excluded
from the install, and any existing crontab entry for it is removed.

Validation also runs standalone via `aias check`.

---

## Output and Logging

- Log directory: `~/.aia/schedule/logs/` — created on first `update` if absent
- Log file per prompt: `~/.aia/schedule/logs/<prompt_id>.log`
  (subdirectory structure mirrors the prompt subpath, e.g. `logs/reports/daily_digest.log`)
- stdout and stderr always combined (`2>&1`)
- Always append — logs accumulate across runs

---

## Key Dependencies

```ruby
spec.add_dependency "aia"            # no version constraint
spec.add_dependency "prompt_manager" # already used by aia
spec.add_dependency "whenever"       # crontab generation and management
spec.add_dependency "thor"           # CLI framework
spec.add_dependency "zeitwerk"       # autoloading
```

`sequel`, `sqlite3`, and `rufus-scheduler` are not required.

---

## Deferred Decisions

| Topic | Notes |
|---|---|
| `timeout:` support | Would require wrapping cron entry with Unix `timeout` command. Deferred to post-v1. |

---

## All Resolved Decisions

| Decision | Outcome |
|---|---|
| Scheduling backend | `whenever` — no daemon, OS cron handles reliability |
| Invocation method | Shell out to `aia` binary — fresh process, clean state per job |
| Separate config file | None — schedule data lives entirely in prompt frontmatter |
| `schedule:` format | Single string only — cron expression or whenever DSL |
| Enabled/disabled | Presence of `schedule:` key means enabled; remove line to disable |
| AIA flags in schedule block | Not needed — AIA reads its own frontmatter; `aias` passes only the prompt ID |
| Append vs overwrite | Always append |
| stdout/stderr | Always combined |
| Log location | Config-anchored: `~/.aia/schedule/logs/<prompt_id>.log` |
| Prompt discovery | `grep -rl "schedule:" $AIA_PROMPTS_DIR` — POSIX, no extra tools |
| Prompt ID format | Full subpath relative to prompts dir (e.g. `reports/weekly_digest`) |
| Cron environment | Login shell wrapping via `whenever`'s `job_template`, detected from `ENV['SHELL']` |
| Validation failure | Warn loudly, skip invalid prompt, remove any existing crontab entry for it |
| Parameters in scheduled prompts | All `parameters:` must have defaults in frontmatter |
| Gem name / binary | `aias` / `aias` |
| Gem boundary | Standalone gem, distributed separately from `aia` |
| Version tracking | Matches `aia` version; reads shared `.version` file |
| Ownership | madbomber RubyGems account, MIT license, same author as `aia` |
| `aia` dependency constraint | No version pin — user is responsible for compatibility |
| `whenever` coupling | Hard dependency |
| Execution history DB | Out of scope — cron logs to files |
