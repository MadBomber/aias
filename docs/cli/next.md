# aias next

Show schedule and last-run information for all installed jobs.

```bash
aias next [N]
```

The command is also accessible as `aias upcoming` (the Ruby method name, since `next` is a reserved keyword).

## Arguments

| Argument | Default | Description |
|---|---|---|
| `N` | `5` | Ignored in v1 (reserved for future next-run time calculation) |

## Output

```
daily_digest
  schedule : 0 8 * * *
  last run : 2025-03-20 08:00:01 +0000
  log      : /Users/you/.aia/schedule/logs/daily_digest.log

reports/weekly
  schedule : 0 9 * * 1
  last run : never run
  log      : /Users/you/.aia/schedule/logs/reports/weekly.log

(Pass N as argument to show N entries. Next-run times require `fugit` gem — v1 shows log timestamps instead.)
```

When no jobs are installed:

```
aias: no installed jobs
```

## Notes

**Last run time** is derived from the log file's modification timestamp. If the log file does not exist, "never run" is shown.

**Next run time** calculation requires the `fugit` gem, which is not a dependency of v1. The argument `N` is accepted but ignored in this release.

## See Also

- [`aias list`](list.md) — tabular view of installed jobs
- [`aias show PROMPT_ID`](show.md) — details for a single job
