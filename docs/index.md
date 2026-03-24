# aias

<table>
<tr>
<td width="50%" align="center" valign="top">
<img src="assets/images/logo.jpg" alt="aias"><br>
<em>"Schedule. Batch. Execute."</em>
</td>
<td width="50%" valign="top">
<h2>Key Features</h2>
<ul>
<li><strong>Natural Language Scheduling</strong> — <code>schedule:</code> frontmatter accepts cron expressions or plain English (<code>"every weekday at 9am"</code>)</li>
<li><strong>Zero Configuration</strong> — No separate config file; prompts describe their own schedule in frontmatter</li>
<li><strong>Reliable Cron Environment</strong> — <code>aias install</code> captures PATH, API keys, and <code>AIA_*</code> vars into <code>env.sh</code> so jobs always run with the right environment</li>
<li><strong>MCP Server Support</strong> — Capture credentials for GitHub, Homebrew, and any MCP server with glob patterns (<code>'GITHUB_*'</code>)</li>
<li><strong>Per-Prompt Overrides</strong> — Frontmatter sets provider, model, flags, and tools per prompt; overrides the shared schedule config</li>
<li><strong>Schedule-Specific Config</strong> — Separate <code>~/.config/aia/schedule/aia.yml</code> isolates scheduled jobs from interactive AIA settings</li>
<li><strong>Single-Prompt Control</strong> — <code>aias add</code> and <code>aias remove</code> manage individual jobs without touching others</li>
<li><strong>Full Sync</strong> — <code>aias update</code> replaces the entire managed crontab block; orphaned entries self-clean</li>
<li><strong>Safe Validation</strong> — Rejects invalid schedules and prompts with un-defaulted parameters before touching the crontab</li>
<li><strong>Rich Inspection</strong> — <code>list</code>, <code>show</code>, <code>check</code>, <code>next</code>, <code>last</code>, and <code>dry-run</code> commands</li>
</ul>
</td>
</tr>
</table>

`aias` turns any AIA prompt into a recurring batch job by reading a `schedule:` key directly from its YAML frontmatter. It scans your prompts directory, validates each scheduled prompt, and installs the results into your crontab.

---

## How It Works

```
AIA prompt files  ──►  PromptScanner  ──►  Validator  ──►  JobBuilder  ──►  CrontabManager
(YAML frontmatter)      grep + parse       syntax +          whenever          crontab block
                                           binary check       DSL string        replace
                                                                                    │
                                                                                    ▼
                                                                            OS cron daemon
                                                                     aia <prompt_id> >> log 2>&1
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
