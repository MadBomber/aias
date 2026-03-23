# aias clear

Remove all aias-managed crontab entries.

```bash
aias clear
```

## What It Does

Calls `whenever --clear` for the `aias` identifier, removing the entire `aias`-managed block from the crontab. All other crontab entries (your own manually added jobs or other `whenever`-managed blocks) are left untouched.

## Output

```
aias: all managed crontab entries removed
```

## Use Cases

**Temporarily disable all scheduled prompts** without editing any prompt files:

```bash
aias clear
# Re-enable later:
aias update
```

**Reset before a clean reinstall:**

```bash
aias clear
aias update
```

## Notes

`clear` does not validate prompts or read `$AIA_PROMPTS_DIR`. It simply removes whatever `aias` block is currently in the crontab.

After `clear`, `aias list` returns "no installed jobs" and `aias check` shows all scheduled prompts as `NEW`.

## See Also

- [`aias update`](update.md) — reinstall after clearing
- [`aias list`](list.md) — verify the crontab is empty after clearing
