# CLI Reference

`aias` provides eight commands. All are available via `aias help` at the terminal.

```
aias help
```

## Command Summary

| Command | Purpose |
|---|---|
| [`aias update`](update.md) | Scan prompts, validate, install all scheduled jobs. Primary command. |
| [`aias add PATH`](add.md) | Add or replace a single prompt's cron job without touching others. |
| [`aias check`](check.md) | Diff view: what is scheduled vs what is installed. |
| [`aias list`](list.md) | Print all currently installed jobs. |
| [`aias dry-run`](dry-run.md) | Preview `update` output without writing the crontab. |
| [`aias show PROMPT_ID`](show.md) | Inspect a single installed job. |
| [`aias next [N]`](next.md) | Show schedule and last-run information for installed jobs. |
| [`aias clear`](clear.md) | Remove all aias-managed crontab entries. |

## Global Option

`--prompts-dir PATH` (alias `-p`) overrides the `AIA_PROMPTS__DIR` / `AIA_PROMPTS_DIR` environment variables for any command that reads prompt files. It has no effect on commands that only read from the crontab (`list`, `show`, `next`, `clear`).

```bash
aias --prompts-dir ~/work/prompts update
aias --prompts-dir ~/work/prompts add ~/work/prompts/standup.md
aias -p ~/work/prompts dry-run
aias -p ~/work/prompts check
```

The lookup order for the prompts directory is:

1. `--prompts-dir` CLI option (highest priority)
2. `AIA_PROMPTS__DIR` environment variable (AIA >= 0.8.0)
3. `AIA_PROMPTS_DIR` environment variable (AIA < 0.8.0)
4. Error — neither option nor env var is set

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Error (bad prompts directory, crontab write failure, prompt not found) |

Validation failures during `update` do **not** cause a non-zero exit — invalid prompts are warned and skipped while valid ones are installed.
