# Scheduling Prompts

## The `schedule:` Key

Add a single `schedule:` key to any AIA prompt's YAML frontmatter to make it a scheduled job:

```yaml
---
description: Morning briefing
schedule: "0 8 * * *"
---
Summarize what happened overnight.
```

The value is a plain string — either a raw cron expression or a whenever DSL fragment. That is all `aias` needs.

## Enabling and Disabling

| Action | How |
|---|---|
| Enable scheduling | Add `schedule:` to the frontmatter |
| Disable scheduling | Remove or comment out the `schedule:` line |
| Change the schedule | Edit the `schedule:` value, then run `aias update` |

After any change, run `aias update` to sync the crontab.

## Schedule Formats

### Raw Cron Expressions

Standard five-field cron syntax and shorthand keywords:

```yaml
schedule: "0 8 * * *"      # 8:00 AM every day
schedule: "30 6 * * 1-5"   # 6:30 AM weekdays
schedule: "0 */4 * * *"    # every 4 hours
schedule: "@daily"          # shorthand for 0 0 * * *
schedule: "@hourly"         # shorthand for 0 * * * *
schedule: "@weekly"         # shorthand for 0 0 * * 0
schedule: "@monthly"        # shorthand for 0 0 1 * *
```

### Whenever DSL

Human-readable scheduling via the `whenever` gem's DSL:

```yaml
schedule: "1.day"                    # once per day (at midnight)
schedule: "1.day, at: '8:00am'"     # daily at 8 AM
schedule: "6.hours"                  # every 6 hours
schedule: "1.week"                   # weekly
schedule: ":monday, at: '9:00am'"   # every Monday at 9 AM
schedule: ":friday, at: '5:00pm'"   # every Friday at 5 PM
```

!!! tip
    When in doubt about whether your schedule string will parse correctly, use `aias check` or `aias dry-run` to validate it before running `aias update`.

## Parameters in Scheduled Prompts

If your prompt uses `parameters:`, **every parameter must have a default value**. Cron runs unattended — there is no interactive session to prompt the user for input.

**This will fail validation:**

```yaml
---
schedule: "0 8 * * *"
parameters:
  topic:              # ← no default — invalid for scheduled prompts
---
Write about <%= topic %>.
```

**This is valid:**

```yaml
---
schedule: "0 8 * * *"
parameters:
  topic: "Ruby news"  # ← default provided — always safe to run unattended
---
Write about <%= topic %>.
```

`aias` rejects prompts with missing parameter defaults and warns loudly. The prompt is excluded from the crontab install.

## Example: Nested Prompt

Prompts in subdirectories work exactly the same. The full subpath (minus `.md`) becomes the prompt ID:

```
$AIA_PROMPTS_DIR/
  reports/
    weekly_digest.md     → prompt ID: reports/weekly_digest
  daily_digest.md        → prompt ID: daily_digest
```

```yaml
# reports/weekly_digest.md
---
description: Weekly summary of team activity
schedule: "0 9 * * 1"   # every Monday at 9 AM
---
Summarize this week's key developments.
```

The log file path mirrors the directory structure:

```
~/.aia/schedule/logs/reports/weekly_digest.log
```

## What Gets Passed to AIA

`aias` passes only the prompt ID to `aia`:

```bash
aia daily_digest
aia reports/weekly_digest
```

AIA reads the prompt file itself, including any flags, model settings, or roles defined in the frontmatter. `aias` does not need to know about those.
