# aias

**Schedule [AIA](https://github.com/madbomber/aia) prompts as cron jobs — no config file, no daemon.**

`aias` turns any AIA prompt into a recurring batch job by reading a `schedule:` key directly from its YAML frontmatter. It scans your prompts directory, validates each scheduled prompt, and installs the results into your crontab via the `whenever` gem.

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

**Full sync on every `update`.** The entire `whenever`-managed crontab block is replaced on each run. Deleted or de-scheduled prompts are automatically removed — there are no orphaned entries to clean up manually.

**OS cron reliability.** No long-running daemon. The system cron daemon handles job execution, reboots, and missed runs. Each `aia` invocation is a fresh, clean process.

**Login shell wrapping.** Every cron entry runs inside a login shell (`bash -l -c` or the user's `$SHELL`), so rbenv, PATH, and all AIA environment variables are available automatically.

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
