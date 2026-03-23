# aias update

Full sync: scan all prompts, validate, and install every scheduled prompt as a cron job.

```bash
aias update
```

## What It Does

1. Scans `$AIA_PROMPTS_DIR` recursively for files containing `schedule:` in their frontmatter
2. Parses the YAML frontmatter of each candidate file via `PM::Metadata`
3. Validates each scheduled prompt (schedule syntax, parameter defaults, `aia` binary)
4. Builds a `whenever` DSL string for each valid prompt
5. Combines all DSL strings and calls `whenever` to replace the entire `aias`-managed crontab block

## Output

```
aias: installed 3 job(s)
```

When some prompts are invalid:

```
aias: installed 2 job(s), skipped 1 invalid
```

Invalid prompts are printed to stderr:

```
aias [skip] bad_prompt: Schedule 'every banana': ...
```

When no valid prompts are found:

```
aias: no valid scheduled prompts found — crontab not changed
```

## Full Sync Semantics

Every `update` replaces the **entire** `aias`-managed crontab block. This means:

- Prompts that had their `schedule:` line removed are automatically uninstalled
- Schedule changes take effect on the next `update`
- No manual cleanup of orphaned entries is ever required

Non-aias crontab entries are never touched.

## Error Handling

| Condition | Behaviour |
|---|---|
| `AIA_PROMPTS_DIR` not set or missing | Exits 1 with an error message |
| Crontab write fails | Exits 1 with an error message |
| Invalid schedule syntax | Skips the prompt, warns to stderr |
| Missing parameter defaults | Skips the prompt, warns to stderr |
| `aia` binary not found | Skips all prompts, warns to stderr |

## Options

| Option | Alias | Description |
|---|---|---|
| `--prompts-dir PATH` | `-p` | Use PATH instead of `AIA_PROMPTS__DIR` / `AIA_PROMPTS_DIR` |

```bash
aias --prompts-dir ~/work/prompts update
```

## See Also

- [`aias dry-run`](dry-run.md) — preview without writing
- [`aias check`](check.md) — see what would change
- [Scheduling Prompts](../guides/scheduling-prompts.md) — schedule format reference
