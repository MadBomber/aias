# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Gem Does

`aias` schedules AIA prompts as cron jobs. It scans AIA prompt files for a `schedule:` key in their YAML frontmatter, then uses the `whenever` gem to install corresponding crontab entries. No separate config file — the prompt files are self-describing.

The design specification lives in `aia_schedule_idea.md`. Read it before implementing anything significant.

## Commands

```bash
# Run all tests
eval "$(rbenv init -)" && bundle exec rake test

# Run a single test file
eval "$(rbenv init -)" && bundle exec ruby -Ilib:test test/test_aias.rb

# Run a single test by name
eval "$(rbenv init -)" && bundle exec ruby -Ilib:test test/test_aias.rb -n test_method_name

# Interactive console
eval "$(rbenv init -)" && bin/console

# Install dependencies
eval "$(rbenv init -)" && bin/setup
```

Ruby version manager: **rbenv**. No `.ruby-version` file — gem requires `>= 3.2.0`.

## Planned Architecture

Five classes under the `Aias::` namespace (from `aia_schedule_idea.md`):

| Class | Role |
|---|---|
| `Aias::CLI` | Thor-based CLI: `update`, `clear`, `list`, `check`, `dry-run`, `next`, `show` |
| `Aias::PromptScanner` | `grep -rl "schedule:" $AIA_PROMPTS_DIR` + `PM::Metadata` frontmatter parsing |
| `Aias::JobBuilder` | Prompt ID + schedule string → whenever job definition |
| `Aias::CrontabManager` | Wraps `whenever`; installs/clears/reads the managed crontab block |
| `Aias::Validator` | Cron syntax, parameter defaults, `aia` binary presence, prompts dir readability |

Use **Zeitwerk** for autoloading. Files go in `lib/aias/` following standard naming conventions.

## Key Design Decisions

- **`whenever` over `rufus-scheduler`** — no daemon; OS cron handles reliability; each job is a fresh `aia` process
- **Full sync on `update`** — the entire `whenever`-managed crontab block is replaced each run; orphaned entries self-clean
- **Cron environment** — wrap every entry in a login shell (`bash -l -c` or `zsh -l -c`) detected from `ENV['SHELL']` via `whenever`'s `job_template`
- **`schedule:` key** — single string only; raw cron expression or whenever DSL. Presence = enabled; remove line = disabled
- **All `parameters:` must have defaults** — interactive input is impossible in cron context; validate and reject if not
- **Log location**: `~/.aia/schedule/logs/<prompt_id>.log`; always append; stdout+stderr combined

## Dependencies (to be added to gemspec)

```ruby
spec.add_dependency "aia"             # no version pin
spec.add_dependency "prompt_manager"  # frontmatter parsing via PM::Metadata
spec.add_dependency "whenever"        # crontab generation and management
spec.add_dependency "thor"            # CLI framework
spec.add_dependency "zeitwerk"        # autoloading
```

## Testing

Framework: **Minitest**. Test files in `test/`, named `test_<module>.rb`. Each class should have an isolated unit test. Use `test_helper.rb` — it prepends `lib` to `$LOAD_PATH` and requires `minitest/autorun`.
