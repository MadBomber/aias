# aias list

Print all currently installed aias cron jobs.

```bash
aias list
```

## Output

```
PROMPT ID                       SCHEDULE         LOG
------------------------------  ---------------  -----------------------------------------------
daily_digest                    0 8 * * *        /Users/you/.aia/schedule/logs/daily_digest.log
reports/weekly                  0 9 * * 1        /Users/you/.aia/schedule/logs/reports/weekly.log
```

When no jobs are installed:

```
aias: no installed jobs
```

## Columns

| Column | Description |
|---|---|
| `PROMPT ID` | Full subpath relative to `$AIA_PROMPTS_DIR`, without the `.md` extension |
| `SCHEDULE` | The raw cron expression as it appears in the crontab |
| `LOG` | Absolute path to the log file for this job |

## Notes

`list` reads directly from the crontab — it shows what is actually installed, not what the current prompt files declare. Use [`aias check`](check.md) to see whether the installed jobs match the current prompt files.

## See Also

- [`aias check`](check.md) — diff between prompts and installed jobs
- [`aias show PROMPT_ID`](show.md) — details for a single job
- [`aias next`](next.md) — schedule and last-run information
