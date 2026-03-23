# aias check

Diff view: compare prompts that declare `schedule:` against what is currently installed in the crontab.

```bash
aias check
```

## What It Shows

`check` categorises every prompt and every installed job into one of four states:

| Label | Meaning |
|---|---|
| `OK` | Crontab is in sync — nothing to report |
| `NEW` | Prompt has `schedule:` but is not yet installed — run `update` |
| `ORPHANED` | Installed in crontab but no corresponding prompt found — run `update` to remove |
| `INVALID` | Prompt has `schedule:` but failed validation — shown with error details |

## Example Output

**In sync:**

```
=== aias check ===

OK — crontab is in sync with scheduled prompts
```

**Changes needed:**

```
=== aias check ===

INVALID (would be skipped by update):
  bad_prompt: Schedule 'every banana': undefined method 'banana' for ...

NEW (not yet installed — run `aias update`):
  + reports/weekly

ORPHANED (installed but no longer scheduled):
  - old_daily_job
```

## Typical Workflow

Run `check` after editing prompt files to see what `update` would change before actually running it:

```bash
# Edit a prompt's schedule:
vim $AIA_PROMPTS_DIR/daily_digest.md

# Preview the impact:
aias check

# Apply:
aias update
```

## Options

| Option | Alias | Description |
|---|---|---|
| `--prompts-dir PATH` | `-p` | Use PATH instead of `AIA_PROMPTS__DIR` / `AIA_PROMPTS_DIR` |

## See Also

- [`aias update`](update.md) — apply the changes shown by `check`
- [`aias dry-run`](dry-run.md) — preview the generated cron lines
- [`aias list`](list.md) — see all currently installed jobs
