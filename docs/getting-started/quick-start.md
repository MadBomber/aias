# Quick Start

Get a prompt running on a schedule in under five minutes.

## Step 1 — Capture Your Environment

Run this once after installing `aias`:

```bash
aias install
```

This snapshots your current shell's `PATH`, API keys, and `AIA_*` variables into `~/.config/aia/schedule/env.sh`. Every cron job sources that file so `aia` and its dependencies are available at run time.

Re-run `aias install` whenever you rotate an API key, install a new MCP server binary, or change your Ruby version.

See [Cron Environment](../guides/cron-environment.md) for full details.

## Step 2 — Add a `schedule:` Key to a Prompt

Open any AIA prompt file (`.md` in your prompts directory) and add a `schedule:` key to its YAML frontmatter:

```yaml
---
description: Morning digest
schedule: "0 8 * * *"
---
Summarize what happened overnight in the Ruby and AI ecosystems.
Keep the summary under 300 words.
```

The `schedule:` value accepts either a raw cron expression or a natural-language string. See [Scheduling Prompts](../guides/scheduling-prompts.md) for the full syntax.

## Step 3 — Preview the Crontab Entry

Before writing anything, see what `aias` would install:

```bash
aias dry-run
```

Example output:

```
0 8 * * * /bin/bash -c 'source ~/.config/aia/schedule/env.sh && \
  aia --prompts-dir /Users/you/.prompts \
      --config ~/.config/aia/schedule/aia.yml \
      daily_digest > ~/.config/aia/schedule/logs/daily_digest.log 2>&1'
```

## Step 4 — Install

```bash
aias update
```

`aias` scans every prompt file, validates the scheduled ones, and replaces the entire `aias`-managed block in your crontab:

```
aias: installed 1 job(s)
```

## Step 5 — Confirm

```bash
aias list
```

```
PROMPT ID                       SCHEDULE         LOG
------------------------------  ---------------  -----------------------------------------------
daily_digest                    0 8 * * *        /Users/you/.config/aia/schedule/logs/daily_digest.log
```

```bash
aias check
```

When everything is in sync:

```
=== aias check ===

OK — crontab is in sync with scheduled prompts
```

## Step 6 — Add More Prompts (Optional)

Every `aias update` is a full sync. Add `schedule:` to more prompts, then run `update` again — new prompts are added, removed prompts are cleaned up automatically.

## What Happens at Runtime

When cron fires the job:

1. `env.sh` is sourced — PATH, API keys, and AIA variables are set
2. `aia` is invoked with the prompts directory and schedule config
3. AIA reads the prompt file, merges its frontmatter over the schedule config
4. The prompt runs using the model and settings defined in the frontmatter (or the schedule config defaults)
5. All output is written to `~/.config/aia/schedule/logs/<prompt_id>.log`

See [Configuration Layering](../guides/configuration-layering.md) for how `env.sh`, the schedule config, and prompt frontmatter combine.

## Disabling a Prompt

Remove or comment out the `schedule:` line, then run `aias update`. The orphaned crontab entry is removed automatically.
