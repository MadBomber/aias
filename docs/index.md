# aias

<table>
<tr>
<td width="40%" align="center" valign="top">
<img src="assets/images/logo.jpg" alt="aias"><br>
<em>"Schedule. Batch. Execute."</em>
</td>
<td width="60%" valign="top">
<h2>Key Features</h2>
<ul>
<li>Natural Language Scheduling</li>
<li>Zero Configuration</li>
<li>Reliable Cron Environment</li>
<li>MCP Server Support</li>
<li>Per-Prompt Overrides</li>
<li>Schedule-Specific Config</li>
<li>Single-Prompt Control</li>
<li>Full Sync on Update</li>
<li>Safe Validation</li>
<li>Rich Inspection Commands</li>
</ul>
</td>
</tr>
</table>

`aias` turns any AIA prompt into a recurring batch job by reading a `schedule:` key directly from its YAML frontmatter. It scans your prompts directory, validates each scheduled prompt, and installs the results into your crontab.

---

## Commands

```
$ aias help
Commands:
  aias add PATH              # Add (or replace) a single scheduled prompt in the crontab
  aias check                 # Diff view: scheduled prompts vs what is installed
  aias clear                 # Remove all aias-managed crontab entries
  aias dry-run               # Show what `update` would write without touching the crontab
  aias help [COMMAND]        # Describe available commands or one specific command
  aias install [PATTERN...]  # Capture PATH, API keys, and env vars into ~/.config/aia/schedule/env.sh
  aias last [N]              # Show last-run time for installed jobs (default 5)
  aias list                  # List all installed aias cron jobs
  aias next [N]              # Show next scheduled run time for installed jobs (default 5)
  aias remove PROMPT_ID      # Remove a single scheduled prompt from the crontab
  aias show PROMPT_ID        # Show the installed crontab entry for a single prompt
  aias uninstall             # Remove managed env block from ~/.config/aia/schedule/env.sh
  aias update                # Scan prompts, regenerate all crontab entries, and install
  aias version               # Print the aias version

Options:
  -p, [--prompts-dir=PROMPTS_DIR]  # Prompts directory (overrides AIA_PROMPTS__DIR / AIA_PROMPTS_DIR env vars)
```

---

## How It Works

```
Prompt file with schedule: in YAML frontmatter
         │
         ▼
aias update scans prompts directory for schedule: keys
         │
         ▼
Each prompt is validated: schedule syntax, parameter defaults, aia binary
         │
         ▼
A cron entry is written for each valid prompt
         │
         ▼
OS cron daemon runs each job on schedule:
  source env.sh && aia [--prompts-dir DIR] prompt_id > log 2>&1
```

---

## Core Design Principles

**Self-describing prompts.** A prompt that wants to run on a schedule says so in its own frontmatter. No external config file maps prompts to schedules.

**Full sync on every `update`.** The entire managed crontab block is replaced on each run. Deleted or de-scheduled prompts are automatically removed — there are no orphaned entries to clean up manually.

**OS cron reliability.** No long-running daemon. The system cron daemon handles job execution, reboots, and missed runs. Each `aia` invocation is a fresh, clean process.

**Explicit environment capture.** `aias install` snapshots your live PATH, API keys, and AIA variables into `~/.config/aia/schedule/env.sh`. Every cron entry sources that file, giving `aia` the same environment it has in your interactive shell — without relying on a login shell that may rebuild PATH unexpectedly.

---

## At a Glance

```bash
# Add schedule: to a prompt's frontmatter, then:
aias update     # install all scheduled prompts into crontab
aias check      # diff: prompts with schedule: vs what is installed
aias list       # show all installed jobs
aias dry-run    # preview what update would write
```

See the [Quick Start](getting-started/quick-start.md) to get running in under five minutes.
