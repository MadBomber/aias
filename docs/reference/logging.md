# Logging

## Log File Location

Each scheduled prompt writes to its own log file under `~/.aia/schedule/logs/`:

```
~/.aia/schedule/logs/
  daily_digest.log
  reports/
    weekly.log
    monthly_summary.log
```

The subdirectory structure mirrors the prompt's subpath relative to `$AIA_PROMPTS_DIR`.

| Prompt ID | Log File |
|---|---|
| `daily_digest` | `~/.aia/schedule/logs/daily_digest.log` |
| `reports/weekly` | `~/.aia/schedule/logs/reports/weekly.log` |
| `a/b/deep` | `~/.aia/schedule/logs/a/b/deep.log` |

## Log Behaviour

| Behaviour | Details |
|---|---|
| **Always append** | `>>` is used — log entries accumulate across runs |
| **Combined stdout + stderr** | `2>&1` — all output goes to the same file |
| **Created by cron** | The log file is created on the first run; `aias` only creates the parent directory |

## Log Directory Creation

`aias update` calls `ensure_log_directories` before installing, which creates the necessary subdirectory structure under `~/.aia/schedule/logs/`. The directories are created even if no jobs have run yet.

## Viewing Logs

```bash
# Tail the log for a specific prompt
tail -f ~/.aia/schedule/logs/daily_digest.log

# Check the last run time
ls -la ~/.aia/schedule/logs/daily_digest.log

# View recent entries
tail -n 50 ~/.aia/schedule/logs/reports/weekly.log
```

## Using aias next

The `aias next` command shows the log file's modification timestamp as a proxy for the last run time:

```bash
aias next
```

```
daily_digest
  schedule : 0 8 * * *
  last run : 2025-03-20 08:00:01 +0000
  log      : /Users/you/.aia/schedule/logs/daily_digest.log
```

"never run" is shown when the log file does not exist.

## Customising the Log Base

The log base directory defaults to `~/.aia/schedule/logs`. It can be overridden when constructing `CrontabManager` directly:

```ruby
manager = Aias::CrontabManager.new(log_base: "/custom/log/dir")
```

This is intended for testing and programmatic use. The CLI always uses the default.
