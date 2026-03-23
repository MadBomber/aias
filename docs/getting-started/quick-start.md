# Quick Start

Get a prompt running on a schedule in under five minutes.

## Step 1 — Add a `schedule:` Key to a Prompt

Open any AIA prompt file (`.md` in your `$AIA_PROMPTS_DIR`) and add a `schedule:` key to its YAML frontmatter:

```yaml
---
description: Morning digest
schedule: "0 8 * * *"
---
Summarize what happened overnight in the Ruby and AI ecosystems.
Keep the summary under 300 words.
```

The `schedule:` value accepts either a raw cron expression or a whenever DSL string. See [Schedule Format](../guides/scheduling-prompts.md) for the full syntax.

## Step 2 — Preview the Crontab Entry

Before writing anything, see what `aias` would install:

```bash
aias dry-run
```

Example output:

```
0 8 * * * /bin/zsh -l -c 'aia daily_digest >> /Users/you/.aia/schedule/logs/daily_digest.log 2>&1'
```

## Step 3 — Install

```bash
aias update
```

`aias` scans every prompt file, validates the scheduled ones, and replaces the entire `aias`-managed block in your crontab. Output shows how many jobs were installed and how many (if any) were skipped:

```
aias: installed 1 job(s)
```

## Step 4 — Confirm

```bash
aias list
```

```
PROMPT ID                       SCHEDULE         LOG
------------------------------  ---------------  -----------------------------------------------
daily_digest                    0 8 * * *        /Users/you/.aia/schedule/logs/daily_digest.log
```

```bash
aias check
```

When everything is in sync:

```
=== aias check ===

OK — crontab is in sync with scheduled prompts
```

## Step 5 — Add More Prompts (Optional)

Every `aias update` is a full sync. Add `schedule:` to more prompts, then run `update` again — new prompts are added, removed prompts are cleaned up automatically.

```bash
# Add more prompts, then:
aias update
```

## What Happens at Runtime

When cron fires the job, it runs:

```bash
/bin/zsh -l -c 'aia daily_digest >> ~/.aia/schedule/logs/daily_digest.log 2>&1'
```

The login shell (`-l`) ensures rbenv, PATH, and all your environment variables are loaded. stdout and stderr are both appended to the log file.

## Disabling a Prompt

Remove or comment out the `schedule:` line, then run `aias update`. The orphaned crontab entry is removed automatically.
