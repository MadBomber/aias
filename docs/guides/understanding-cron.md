# Understanding Cron and Crontab

`aias` schedules AIA prompts using your operating system's built-in job scheduler: **cron**. This page explains what cron is, how it works, and how `aias` fits into it — so you know what is happening when you run `aias update`.

---

## What Is Cron?

**Cron** is a time-based job scheduler built into every Unix-like operating system (macOS, Linux). It runs in the background at all times, waking up once per minute to check whether any scheduled job is due to run. When one is, cron launches it as a separate process and goes back to sleep.

Cron requires no ongoing configuration once a job is installed. Your Mac does not need to be awake — if the machine is asleep at the scheduled time, cron skips that run and waits for the next one. If you need guaranteed execution even after a missed run, look into `launchd` (macOS) or `systemd` timers (Linux) — but for most prompt scheduling purposes, cron is sufficient.

---

## What Is a Crontab?

**Crontab** (cron table) is the file that lists your scheduled jobs. Each user on the system has their own private crontab. Jobs in your crontab run as you, with your user permissions — they cannot see another user's files or processes.

To view your current crontab:

```bash
crontab -l
```

If you have no scheduled jobs yet, this prints nothing (or "no crontab for \<user\>").

A crontab entry looks like this:

```
0 8 * * * /bin/bash -c 'source ~/.config/aia/schedule/env.sh && aia daily_digest > ~/.config/aia/schedule/logs/daily_digest.log 2>&1'
```

The five fields before the command are the **schedule expression**.

---

## Reading a Cron Expression

A cron expression is five space-separated fields:

```
┌─── minute       (0–59)
│  ┌── hour        (0–23)
│  │  ┌─ day of month  (1–31)
│  │  │  ┌ month       (1–12)
│  │  │  │  ┌ day of week  (0–7, 0 and 7 = Sunday)
│  │  │  │  │
*  *  *  *  *   command
```

An asterisk (`*`) means "every". Common examples:

| Expression | Meaning |
|---|---|
| `0 8 * * *` | Every day at 8:00 AM |
| `0 9 * * 1-5` | Every weekday (Mon–Fri) at 9:00 AM |
| `30 6 * * 1` | Every Monday at 6:30 AM |
| `0 */6 * * *` | Every 6 hours |
| `0 0 1 * *` | The 1st of every month at midnight |

`aias` also accepts natural language — `"every weekday at 9am"` — and converts it to a cron expression automatically using the [fugit](https://github.com/floraison/fugit) gem. Use `aias dry-run` to see the resolved expression before installing.

---

## How aias Manages Your Crontab

`aias` never overwrites your entire crontab. It owns a single marked block, delimited by comments:

```
# BEGIN aias
0 8 * * * /bin/bash -c 'source ~/.config/aia/schedule/env.sh && aia daily_digest > ...'
0 9 * * 1-5 /bin/bash -c 'source ~/.config/aia/schedule/env.sh && aia standup > ...'
# END aias
```

Any jobs you have added outside this block — whether written by hand or installed by another tool — are left completely untouched. `aias update` replaces only the content between the markers.

---

## Why Cron Has No Environment

When cron launches a job it starts a new, bare-minimum process. Your shell profile (`~/.zshrc`, `~/.bash_profile`) is **not** sourced. Your `PATH` is reduced to `/usr/bin:/bin`. Your API keys, Ruby version manager shims, and `AIA_*` variables are gone.

This is the single biggest source of cron job failures. A command that works perfectly in your terminal fails silently under cron because `aia` is not on the stripped PATH.

`aias install` solves this once. It captures the critical parts of your live environment — `PATH`, `LANG`, `LC_ALL`, `AIA_*` variables, and `*_API_KEY` keys — and writes them to `~/.config/aia/schedule/env.sh`. Every `aias`-managed cron entry sources that file before running:

```bash
source ~/.config/aia/schedule/env.sh && aia prompt_id > log 2>&1
```

See [Cron Environment](cron-environment.md) for the full details on what is captured and how to keep it current.

---

## Crontab Commands You Should Know

| Command | What it does |
|---|---|
| `crontab -l` | Print your current crontab to the terminal |
| `crontab -e` | Open your crontab in `$EDITOR` for manual editing |
| `EDITOR=nano crontab -e` | Open with a specific editor |
| `crontab -r` | **Delete your entire crontab** — use with care |

> **Warning:** `crontab -r` removes *everything*, including any non-aias jobs. To remove only the `aias`-managed entries, use `aias clear`.

---

## Checking Whether a Job Ran

Cron itself provides no built-in log viewer. `aias` directs each job's output to a per-prompt log file:

```
~/.config/aia/schedule/logs/<prompt_id>.log
```

```bash
# View the log for a specific job
cat ~/.config/aia/schedule/logs/daily_digest.log

# Show when a job last ran
aias last

# Show when a job is next scheduled to run
aias next
```

If a job is failing, the log is the first place to look. Common causes and fixes are covered in [Cron Environment — Troubleshooting](cron-environment.md#troubleshooting).

---

## macOS Notes

On macOS, cron is managed by `launchd` and runs continuously in the background — you do not need to start or enable it. However, macOS may show a **Full Disk Access** prompt the first time a cron job runs, because cron does not automatically inherit the permissions granted to your terminal. If a job fails with a permission error, open **System Settings → Privacy & Security → Full Disk Access** and add `/usr/sbin/cron`.
