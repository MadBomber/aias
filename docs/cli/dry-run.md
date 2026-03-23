# aias dry-run

Show what `aias update` would write to the crontab without making any changes.

```bash
aias dry-run
```

## Output

The raw cron lines that would be installed, exactly as they would appear in the crontab:

```
0 8 * * * /bin/zsh -l -c 'aia daily_digest >> /Users/you/.aia/schedule/logs/daily_digest.log 2>&1'
0 9 * * 1 /bin/zsh -l -c 'aia reports/weekly >> /Users/you/.aia/schedule/logs/reports/weekly.log 2>&1'
```

Invalid prompts are printed to stderr (same as `update`):

```
aias [skip] bad_prompt: Schedule 'every banana': ...
```

When no valid prompts are found:

```
aias: no valid scheduled prompts found
```

## Use Cases

**Verify the generated cron expression** before committing it to your crontab:

```bash
aias dry-run
# Inspect the output, then:
aias update
```

**Check login shell wrapping** — confirm the correct shell binary and `-l` flag appear in the output.

**Audit from CI** — `dry-run` is safe to run in automated pipelines because it never modifies the crontab.

## Notes

`dry-run` runs the full scan and validation pipeline. The only thing it skips is the final crontab write. This means it accurately reflects what `update` would do, including which prompts would be skipped.

## Options

| Option | Alias | Description |
|---|---|---|
| `--prompts-dir PATH` | `-p` | Use PATH instead of `AIA_PROMPTS__DIR` / `AIA_PROMPTS_DIR` |

## See Also

- [`aias update`](update.md) — apply the output shown by `dry-run`
- [`aias check`](check.md) — higher-level diff view
