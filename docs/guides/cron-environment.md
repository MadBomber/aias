# Cron Environment

> New to cron? See [Understanding Cron and Crontab](understanding-cron.md) first.

Cron runs processes in a nearly empty environment: no `PATH` beyond `/usr/bin:/bin`, no Ruby version manager, no user-defined variables. Without intervention, `aia` would not be found and API keys would not be set, so every job would fail silently.

## How aias Solves This

`aias` captures your live shell environment into a file and sources it before every cron invocation. This is a one-time setup step:

```bash
aias install
```

`install` reads your current session's environment and writes it to `~/.config/aia/schedule/env.sh`. Every generated cron entry sources that file before running `aia`:

```bash
0 8 * * * /bin/bash -c 'source ~/.config/aia/schedule/env.sh && \
  aia --prompts-dir /path/to/prompts \
      --config ~/.config/aia/schedule/aia.yml \
      daily_digest > ~/.config/aia/schedule/logs/daily_digest.log 2>&1'
```

## What Gets Captured

`aias install` captures these variable groups by default:

| Group | Example variables |
|---|---|
| `PATH` | The full path including rbenv/asdf shims, Homebrew, MCP server binaries |
| `*_API_KEY` | `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, etc. |
| `AIA_*` | `AIA_PROMPTS__DIR`, `AIA_MODEL`, `AIA_FLAGS__VERBOSE`, etc. |
| `LANG`, `LC_ALL` | Locale settings (required for Ruby UTF-8 string handling) |

### Capturing Additional Variables

Pass glob patterns to `aias install` to capture additional variable groups:

```bash
aias install 'OPENROUTER_*'
aias install 'AIA_*' 'MY_SERVICE_*'
aias install 'AIA_* OPENROUTER_*'   # space-separated in a single argument
```

Patterns are matched case-insensitively. Variables matching the default groups are always included regardless of patterns.

## Keeping env.sh Current

`env.sh` is a snapshot of your environment at the time `aias install` was run. Re-run `install` whenever:

- You rotate or add an API key
- You install a new MCP server binary (it needs to be on `PATH`)
- You change your Ruby version or version manager configuration
- You add or change an `AIA_*` variable

```bash
aias install   # re-captures and overwrites the managed block in env.sh
```

The file uses `# BEGIN aias-env` / `# END aias-env` markers. If you add your own content to `env.sh` outside those markers it is preserved on every `install` run.

## Why Not a Login Shell?

An earlier version of `aias` used `-l` (login shell) to source the user's shell profile on each run. This was unreliable on macOS: `/usr/libexec/path_helper` — invoked by the login profile — unconditionally rebuilds `PATH` from `/etc/paths` and `/etc/paths.d/`, discarding any rbenv or asdf shims added earlier in the session. Version manager shims would disappear, `aia` would not be found, and jobs would fail.

The `env.sh` approach captures `PATH` at the moment you run `aias install` — when the correct, fully-activated PATH is already in place — and replays it verbatim in every cron invocation.

## Viewing the Captured Environment

```bash
cat ~/.config/aia/schedule/env.sh
```

The managed block looks like:

```bash
# BEGIN aias-env
export PATH="/Users/you/.rbenv/shims:/opt/homebrew/bin:/usr/bin:/bin"
export ANTHROPIC_API_KEY="sk-ant-..."
export AIA_PROMPTS__DIR="/Users/you/.prompts"
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
# END aias-env
```

## Removing the Captured Environment

```bash
aias uninstall
```

Removes the managed block from `env.sh`. The rest of the file (and the rest of the schedule configuration) is preserved. Installed cron jobs are not removed — use `aias clear` for that.

## Troubleshooting

If a job is failing, check the log first:

```bash
cat ~/.config/aia/schedule/logs/daily_digest.log
```

**`aia: command not found`**
The `aia` binary path captured in `env.sh` is no longer valid. Common cause: you changed Ruby versions or reinstalled gems. Fix: re-run `aias install`.

**Ruby encoding error (`"\xE2" on US-ASCII`)**
`LANG` or `LC_ALL` is missing from `env.sh`. Fix: re-run `aias install` from a terminal with a UTF-8 locale.

**API authentication error**
The API key in `env.sh` is expired or wrong. Fix: set the correct key in your shell, then re-run `aias install`.

**MCP server binary not found**
The binary was installed after the last `aias install`. Fix: re-run `aias install` to capture the updated `PATH`.
