# aias last

Show the last-run time for installed jobs.

```bash
aias last [N]
```

The command is also accessible as `aias last_run` (the Ruby method name).

## Arguments

| Argument | Default | Description |
|---|---|---|
| `N` | `5` | Maximum number of jobs to show |

## Output

```
daily_digest
  schedule : every day at 8am (0 8 * * *)
  last run : 2026-03-23 08:00:01 -0500
  log      : /Users/you/.aia/schedule/logs/daily_digest.log

reports/weekly
  schedule : every Monday at 9am (0 9 * * 1)
  last run : never run
  log      : /Users/you/.aia/schedule/logs/reports/weekly.log

(Pass N as argument to show N entries. Last-run time is derived from the log file modification timestamp.)
```

When no jobs are installed:

```
aias: no installed jobs
```

## Notes

**Last run time** is derived from the log file's modification timestamp. If the log file does not exist, `never run` is shown.

Use [`aias next`](next.md) to see when each job is next scheduled to run.

## See Also

- [`aias next [N]`](next.md) — next scheduled run time for installed jobs
- [`aias list`](list.md) — tabular view of installed jobs
- [`aias show PROMPT_ID`](show.md) — details for a single job
