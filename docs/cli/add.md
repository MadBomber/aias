# aias add

Add or replace a single prompt's cron job without touching any other installed jobs.

```bash
aias add PATH
```

`PATH` is the path to the prompt file — absolute or relative. The file must live inside the configured prompts directory.

## What It Does

1. Expands `PATH` to an absolute path
2. Verifies the file exists and is inside the prompts directory
3. Parses the file's YAML frontmatter via `PM::Metadata`
4. Errors immediately if the file has no `schedule:` key
5. Runs the same validation as `update` (schedule syntax, parameter defaults, `aia` binary)
6. Derives the prompt ID from the file's path relative to the prompts directory
7. Upserts the single cron entry into the aias-managed crontab block — if the prompt was already installed, its old entry is replaced; all other entries are left untouched

## When to Use `add` vs `update`

| Situation | Command |
|---|---|
| You edited or created one prompt and want it scheduled now | `aias add PATH` |
| You edited multiple prompts, or want to sync everything | `aias update` |
| You want to see what would change first | `aias dry-run` or `aias check` |

`add` is faster than `update` for large prompts directories because it does not scan the entire tree — it only reads the one file you specify.

## Example Output

**Success:**

```
aias: added standup (every weekday at 9:00am (0 9 * * 1-5))
```

**Prompt has no schedule:**

```
aias [error] 'drafts/idea' has no schedule: in its frontmatter
```

**Invalid schedule:**

```
aias [error] bad_prompt: Schedule 'every banana': not a valid cron expression or natural language schedule
```

**File outside prompts directory:**

```
aias [error] '/tmp/idea.md' is not inside the prompts directory '/Users/you/.prompts'
```

## Upsert Semantics

Re-running `add` on the same prompt replaces its cron entry cleanly — no duplicates are created. This makes `add` safe to run any number of times:

```bash
# Install:
aias add ~/.prompts/standup.md
# aias: added standup (every weekday at 9:00am (0 9 * * 1-5))

# Update the schedule in the file, then re-install:
aias add ~/.prompts/standup.md
# aias: added standup (every weekday at 10:00am (0 10 * * 1-5))
```

## Prompt ID Derivation

The prompt ID is derived the same way as `update`: the file's absolute path with the prompts directory prefix and `.md` extension removed.

```
prompts_dir:  /Users/you/.prompts
file:         /Users/you/.prompts/reports/weekly.md
prompt_id:    reports/weekly
```

## Options

| Option | Alias | Description |
|---|---|---|
| `--prompts-dir PATH` | `-p` | Use PATH as the prompts directory (also determines the prompt ID prefix) |

When `--prompts-dir` is not supplied, the prompts directory is read from `AIA_PROMPTS__DIR` or `AIA_PROMPTS_DIR`. The same value is embedded in the generated `aia` command so the cron job runs against the correct directory.

## Exit Codes

| Code | Condition |
|---|---|
| `0` | Job installed successfully |
| `1` | File not found, outside prompts dir, no `schedule:`, validation failure, or crontab write error |

## See Also

- [`aias update`](update.md) — sync all scheduled prompts at once
- [`aias check`](check.md) — diff view before making changes
- [`aias list`](list.md) — confirm the job was installed
- [Scheduling Prompts](../guides/scheduling-prompts.md) — schedule format reference
