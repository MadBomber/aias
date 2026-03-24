# aias remove

Remove a single scheduled prompt's cron job from the crontab.

```bash
aias remove PROMPT_ID
```

Aliases: `aias rm PROMPT_ID`, `aias delete PROMPT_ID`

---

## What It Does

Finds the cron entry for `PROMPT_ID` inside the `aias`-managed crontab block and removes it. All other installed jobs — both `aias`-managed and user-managed — are left untouched.

Exits with an error if `PROMPT_ID` is not currently installed.

## When to Use `remove` vs `clear` vs `update`

| Goal | Command |
|---|---|
| Remove one specific job | `aias remove PROMPT_ID` |
| Remove all aias-managed jobs | `aias clear` |
| Remove jobs for prompts that no longer have `schedule:` | `aias update` (full sync) |

`remove` is the right command when you want to unschedule a single prompt and leave everything else alone. It does not require the prompt file to exist — you can use it to clean up an orphaned entry after the file has already been deleted.

## Example Output

**Success:**

```
aias: removed daily_digest
```

**Not installed:**

```
aias [error] 'daily_digest' is not currently installed
```

## Finding the Prompt ID

Use `aias list` to see the exact ID strings for all installed jobs:

```bash
aias list
# PROMPT ID                       SCHEDULE              LOG
# ------------------------------  --------------------  ---
# daily_digest                    every day at 8am      ...
# reports/weekly                  every monday at 9am   ...
```

Then remove by that ID:

```bash
aias remove daily_digest
aias remove reports/weekly
```

## Removing an Orphaned Entry

If you deleted a prompt file without first running `aias remove` or `aias update`, the crontab entry persists as an orphan. Use `aias check` to see it, then `aias remove` to clean it up:

```bash
aias check
# ORPHANED (installed but no longer scheduled):
#   - reports/weekly

aias remove reports/weekly
# aias: removed reports/weekly
```

## Exit Codes

| Code | Condition |
|---|---|
| `0` | Job removed successfully |
| `1` | Prompt ID not installed, or crontab write error |

## See Also

- [`aias add PATH`](add.md) — add a single job (the inverse operation)
- [`aias list`](list.md) — see installed prompt IDs
- [`aias check`](check.md) — identify orphaned entries
- [`aias clear`](clear.md) — remove all aias-managed entries at once
