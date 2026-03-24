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

The value is a plain string — either a standard cron expression or a natural language phrase that fugit understands. That is all `aias` needs. At install time `aias` calls `Fugit.parse_cronish` to resolve the value to a canonical cron expression, which is what gets written to the crontab.

## Enabling and Disabling

| Action | How |
|---|---|
| Enable scheduling | Add `schedule:` to the frontmatter |
| Disable scheduling | Remove the `schedule:` line, then run `aias update` |
| Change the schedule | Edit the `schedule:` value, then run `aias update` or `aias add PATH` |

Removing the `schedule:` line from a prompt that is already installed in the crontab does **not** automatically remove the cron entry. You must run `aias update` (full sync) or `aias remove PROMPT_ID` to remove it.

---

## Schedule Formats

### Standard Cron Expressions

Five-field cron syntax:

```
┌─ minute     (0–59)
│  ┌─ hour    (0–23)
│  │  ┌─ day  (1–31)
│  │  │  ┌─ month  (1–12 or jan–dec)
│  │  │  │  └─ weekday (0–7, 0=Sun, 7=Sun, or sun–sat)
│  │  │  │  │
*  *  *  *  *
```

```yaml
schedule: "0 8 * * *"        # 8:00 AM every day
schedule: "30 6 * * 1-5"     # 6:30 AM Monday–Friday
schedule: "0 */4 * * *"      # every 4 hours (at 0, 4, 8, 12, 16, 20)
schedule: "0 9 1,15 * *"     # 9 AM on the 1st and 15th of each month
schedule: "0 0 * * 0"        # midnight every Sunday
```

### `@` Shorthand Keywords

```yaml
schedule: "@hourly"          # 0 * * * *
schedule: "@daily"           # 0 0 * * *
schedule: "@weekly"          # 0 0 * * 0
schedule: "@monthly"         # 0 0 1 * *
schedule: "@yearly"          # 0 0 1 1 *
schedule: "@midnight"        # 0 0 * * *
```

---

## Natural Language Scheduling (fugit)

`aias` uses the [fugit](https://github.com/floraison/fugit) gem (version 1.12.1) to parse natural language schedule strings. fugit converts them to cron expressions via `Fugit.parse_cronish`.

**Important:** fugit 1.12.1 generates explicit time lists rather than the `*/N` step notation. For example, `every 6 hours` produces `0 0,6,12,18 * * *`, not `0 */6 * * *`. Both are equivalent in meaning, but the explicit form is what you will see in the crontab.

### Frequency Intervals

```yaml
schedule: "every minute"       # 0,1,2,...,59 * * * *  (every minute)
schedule: "every 5 minutes"    # 0,5,10,15,20,25,30,35,40,45,50,55 * * * *
schedule: "every 10 minutes"   # 0,10,20,30,40,50 * * * *
schedule: "every 30 minutes"   # 0,30 * * * *
schedule: "every hour"         # 0 * * * *
schedule: "every 2 hours"      # 0 0,2,4,6,8,10,12,14,16,18,20,22 * * *
schedule: "every 4 hours"      # 0 0,4,8,12,16,20 * * *
schedule: "every 6 hours"      # 0 0,6,12,18 * * *
schedule: "every 12 hours"     # 0 0,12 * * *
schedule: "every day"          # 0 0 * * *
schedule: "every week"         # 0 0 * * 0
schedule: "every month"        # 0 0 1 * *
schedule: "every year"         # 0 0 1 1 *
```

Supported abbreviations:

| Abbreviation | Meaning |
|---|---|
| `s`, `sec`, `secs`, `second`, `seconds` | seconds |
| `m`, `min`, `mins`, `minute`, `minutes` | minutes |
| `h`, `hou`, `hour`, `hours` | hours |
| `d`, `day`, `days` | days |
| `M`, `month`, `months` | months (capital `M`) |

Note: `M` (capital) means months; `m` (lowercase) means minutes. Case matters here.

### Days of the Week

Day names are case-insensitive. Three-letter abbreviations work.

```yaml
schedule: "every monday"                        # 0 0 * * 1
schedule: "every tuesday"                       # 0 0 * * 2
schedule: "every friday"                        # 0 0 * * 5
schedule: "every weekday"                       # 0 0 * * 1,2,3,4,5
schedule: "every weekend"                       # 0 0 * * 6,0
schedule: "every monday and wednesday"          # 0 0 * * 1,3
schedule: "every tuesday and monday at 5pm"     # 0 17 * * 1,2
schedule: "every friday and saturday at 11pm"   # 0 23 * * 5,6
schedule: "every Mon to Fri at 9am"             # 0 9 * * 1,2,3,4,5
schedule: "every monday through friday at 9am"  # 0 9 * * 1,2,3,4,5
schedule: "every Mon,Tue,Wed,Thu,Fri at 9am"    # 0 9 * * 1,2,3,4,5
schedule: "every Mon, Tue, and Wed at 18:15"    # 15 18 * * 1,2,3
schedule: "from Monday to Friday at 9am"        # 0 9 * * 1,2,3,4,5
```

### Times of Day

```yaml
# Named times
schedule: "every day at noon"           # 0 12 * * *
schedule: "every day at midnight"       # 0 0 * * *
schedule: "every day at five"           # 0 5 * * *

# 24-hour clock
schedule: "every day at 8:30"           # 30 8 * * *
schedule: "every day at 16:00"          # 0 16 * * *
schedule: "every day at 18:22"          # 22 18 * * *

# AM/PM
schedule: "every day at 8am"            # 0 8 * * *
schedule: "every day at 5pm"            # 0 17 * * *
schedule: "every day at 8:30am"         # 30 8 * * *
schedule: "every day at 8:30 pm"        # 30 20 * * *

# Combined day + time
schedule: "every weekday at 9am"        # 0 9 * * 1,2,3,4,5
schedule: "every monday at 9am"         # 0 9 * * 1

# Multiple times — same minutes merge into one cron entry
schedule: "every day at 8am and 5pm"       # 0 8,17 * * *
schedule: "every day at 8:00 and 17:00"    # 0 8,17 * * *
```

**Limitation:** When two times have *different* minutes (e.g. `8:15 and 17:45`), only the first time is used. Use two separate prompt files with individual `schedule:` lines if you need two runs at different minutes.

### 12 AM/PM Edge Cases

Noon and midnight have special handling:

```yaml
schedule: "every day at 12pm"           # 0 12 * * *  (noon)
schedule: "every day at 12am"           # 0 0 * * *   (midnight)
schedule: "every day at 12 noon"        # 0 12 * * *
schedule: "every day at 12 midnight"    # 0 0 * * *
schedule: "every day at 12:30pm"        # 30 12 * * *
schedule: "every day at 12:30am"        # 30 0 * * *
```

### Day of Month

Ordinal words (`1st`, `2nd`, `3rd`, etc.) and the word `last` are supported:

```yaml
schedule: "every 1st of the month at midnight"         # 0 0 1 * *
schedule: "every 15th of the month at noon"            # 0 12 15 * *
schedule: "every month on the 1st at 9am"              # 0 9 1 * *
schedule: "every month on the 1st and 15th at noon"    # 0 12 1,15 * *
schedule: "every month on the 1st and last at noon"    # 0 12 1,L * *
schedule: "every month on days 1,15 at 10:00"          # 0 10 1,15 * *
```

### Time Windows (Range Within a Day)

Run a job on every hour (or minute) within a time range:

```yaml
schedule: "every weekday 9am to 5pm on the hour"    # 0 9,10,11,12,13,14,15,16,17 * * 1,2,3,4,5
schedule: "every hour, from 8am to 5pm"             # 0 8,9,10,11,12,13,14,15,16,17 * * *
schedule: "every minute from 8am to 5pm"            # * 8,9,10,11,12,13,14,15,16 * * *
```

### Timezone

Append `in TIMEZONE`, `on TIMEZONE`, or a bare timezone name:

```yaml
schedule: "every day at 9am in America/New_York"       # 0 9 * * * America/New_York
schedule: "every day at 5pm on America/Chicago"        # 0 17 * * * America/Chicago
schedule: "every day at midnight America/Los_Angeles"  # 0 0 * * * America/Los_Angeles
schedule: "every day at 6pm UTC"                       # 0 18 * * * UTC
schedule: "every day at 9am in Etc/GMT+5"              # 0 9 * * * Etc/GMT+5
```

Supported formats: IANA city names (`America/New_York`, `Asia/Tokyo`, etc.), `UTC`, `Z`, and offset codes (`Etc/GMT+5`).

If no timezone is given, the job runs in the system timezone of the machine where cron is running.

---

## Limitations

**`every 2 weeks` is not supported.** fugit does not parse multi-week intervals. Use a cron expression instead:

```yaml
schedule: "0 9 * * 1"    # every Monday — effectively every week
schedule: "0 9 1,15 * *" # approximate bi-weekly (1st and 15th of month)
```

**Maximum 256 characters.** Natural language strings longer than 256 characters are rejected.

**Two times with different minutes only fires at the first time.** `"every day at 8:15 and 17:45"` resolves to `15 8 * * *` — the 17:45 is silently dropped. Split into two prompts if you need both.

**`every 2 days` produces a long explicit list.** `"every 2 days"` resolves to `0 0 1,3,5,7,9,11,13,15,17,19,21,23,25,27,29,31 * *`. This is correct but verbose. A simpler alternative is the raw cron `"0 0 */2 * *"`.

---

## Checking Your Schedule

Before installing, preview exactly what cron expression your `schedule:` string resolves to:

```bash
aias dry-run
```

The output shows the literal cron line that will be written, so you can verify the expression is correct before committing it to the crontab.

You can also test a fugit parse directly in a Ruby one-liner:

```bash
ruby -rfugit -e 'puts Fugit.parse_cronish("every weekday at 9am").to_cron_s'
# => 0 9 * * 1,2,3,4,5
```

---

## Parameters in Scheduled Prompts

If your prompt uses `parameters:`, **every parameter must have a default value**. Cron runs unattended — there is no interactive session to prompt for input.

**This will fail validation:**

```yaml
---
schedule: "0 8 * * *"
parameters:
  topic:              # no default — invalid for scheduled prompts
---
Write about <%= topic %>.
```

**This is valid:**

```yaml
---
schedule: "0 8 * * *"
parameters:
  topic: "Ruby news"  # default provided — safe to run unattended
---
Write about <%= topic %>.
```

`aias` rejects prompts with missing parameter defaults and warns during `update` or `add`. The prompt is excluded from the crontab.

---

## Nested Prompts

Prompts in subdirectories work exactly the same. The full subpath (minus `.md`) becomes the prompt ID:

```
$AIA_PROMPTS_DIR/
  reports/
    weekly_digest.md     → prompt ID: reports/weekly_digest
  daily_digest.md        → prompt ID: daily_digest
```

The log file mirrors the directory structure:

```
~/.config/aia/schedule/logs/reports/weekly_digest.log
```

---

## Quick Reference

| Natural language | Resolved cron |
|---|---|
| `every minute` | `0,1,...,59 * * * *` |
| `every 5 minutes` | `0,5,10,...,55 * * * *` |
| `every 10 minutes` | `0,10,20,30,40,50 * * * *` |
| `every 30 minutes` | `0,30 * * * *` |
| `every hour` | `0 * * * *` |
| `every 6 hours` | `0 0,6,12,18 * * *` |
| `every 12 hours` | `0 0,12 * * *` |
| `every day` | `0 0 * * *` |
| `every day at 8am` | `0 8 * * *` |
| `every day at noon` | `0 12 * * *` |
| `every day at midnight` | `0 0 * * *` |
| `every day at 8:30` | `30 8 * * *` |
| `every weekday` | `0 0 * * 1,2,3,4,5` |
| `every weekday at 9am` | `0 9 * * 1,2,3,4,5` |
| `every monday` | `0 0 * * 1` |
| `every monday at 9am` | `0 9 * * 1` |
| `every monday through friday at 9am` | `0 9 * * 1,2,3,4,5` |
| `every friday and saturday at 11pm` | `0 23 * * 5,6` |
| `every 1st of the month at midnight` | `0 0 1 * *` |
| `every 15th of the month at noon` | `0 12 15 * *` |
| `every month on the 1st and 15th at noon` | `0 12 1,15 * *` |
| `@daily` | `0 0 * * *` |
| `@weekly` | `0 0 * * 0` |
| `@monthly` | `0 0 1 * *` |
| `@hourly` | `0 * * * *` |
