# aias show

Show the installed crontab entry for a single prompt.

```bash
aias show PROMPT_ID
```

## Arguments

| Argument | Description |
|---|---|
| `PROMPT_ID` | The prompt ID as it appears in `aias list` (full subpath, no `.md` extension) |

## Output

```bash
aias show daily_digest
```

```
prompt_id : daily_digest
schedule  : 0 8 * * *
log       : /Users/you/.aia/schedule/logs/daily_digest.log
```

For a nested prompt:

```bash
aias show reports/weekly
```

```
prompt_id : reports/weekly
schedule  : 0 9 * * 1
log       : /Users/you/.aia/schedule/logs/reports/weekly.log
```

## Error

When the prompt ID is not found in the crontab, `show` prints a message and exits 1:

```
aias: 'nonexistent' is not currently installed
```

## Notes

`show` reads from the installed crontab, not from the prompt files. A prompt must have been installed via `aias update` before it appears.

## See Also

- [`aias list`](list.md) — all installed jobs
- [`aias check`](check.md) — compare installed vs scheduled
