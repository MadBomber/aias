# Configuration Layering

Every `aias`-scheduled job is configured through three independent layers that AIA merges at runtime. Understanding those layers — and their precedence — is the key to writing prompts that work reliably in a cron context.

```
env.sh              ← Layer 1: runtime environment
schedule/aia.yml    ← Layer 2: base AIA configuration for all scheduled jobs
prompt frontmatter  ← Layer 3: per-prompt overrides (wins over everything)
```

Frontmatter always wins. The schedule config provides defaults. `env.sh` makes the process runnable.

---

## Layer 1 — env.sh

**File:** `~/.config/aia/schedule/env.sh`
**Purpose:** Reproduce the environment that existed when `aias install` was run.

Cron starts processes with a nearly empty environment: no Ruby version manager, no user-defined variables, no API keys. `env.sh` is sourced before every cron invocation, injecting the values AIA and its dependencies need:

| What it provides | Why it matters |
|---|---|
| `PATH` | rbenv/asdf shims, gem bin dirs, MCP server binaries |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, etc. | LLM API authentication |
| `AIA_*` variables | AIA runtime defaults (`AIA_PROMPTS__DIR`, `AIA_MODEL`, etc.) |
| `LANG`, `LC_ALL` | UTF-8 encoding for Ruby string handling |

**Populated by:** `aias install` — run once (or re-run when your shell environment changes). If you add a new API key or install a new MCP server binary, re-run `aias install` to capture it.

---

## Layer 2 — Schedule config

**File:** `~/.config/aia/schedule/aia.yml`
**Purpose:** Base AIA configuration shared by all scheduled prompts.

Passed to every cron entry via the `--config` flag:

```bash
aia --prompts-dir /path/to/prompts --config ~/.config/aia/schedule/aia.yml you_are_good
```

When `--config` is used, AIA resets to its built-in defaults and loads this file. Your interactive `~/.config/aia/aia.yml` is **not** read during scheduled runs — the schedule config replaces it entirely. This isolation is intentional: scheduled jobs should not be affected by changes to your interactive configuration.

The schedule config sets:

| Setting | Typical value | What it does |
|---|---|---|
| `llm.adapter` | `ruby_llm` | Default AI backend |
| `models` | `claude-haiku-4-5` | Default model (low cost, fast) |
| `llm.temperature`, `max_tokens` | base LLM parameters | Applied unless overridden by frontmatter |
| `output.append` | `false` | Each run overwrites the output file |
| `logging.llm.level` | `warn` | Log only warnings from the LLM layer |
| `logging.mcp.level` | `warn` | Log only warnings from MCP |
| `mcp_servers` | github, brew, crimson, etc. | MCP tools available to all scheduled prompts |
| `require_libs` | `["shared_tools"]` | Libraries loaded for every scheduled run |
| `prompts.dir` | your prompts path | Fallback if `--prompts-dir` is not on the command line |

Keep the schedule config conservative. It should represent the minimum needed for any scheduled prompt to run. Per-prompt requirements go in the frontmatter.

---

## Layer 3 — Prompt frontmatter

**File:** the prompt `.md` file itself
**Purpose:** Per-prompt overrides that make each prompt self-contained.

AIA reads the YAML frontmatter of the prompt file after loading the schedule config. Frontmatter keys override any matching key in the schedule config. A prompt should declare in its frontmatter everything that makes it different from the base config.

---

## Worked Example: `you_are_good.md`

```yaml
---
flags:
  debug: true
  verbose: true
provider: ollama
models:
  - name: gpt-oss:latest
    role:
schedule: every 2 minutes
required: ['shared_tools']
tools:
  rejected: ['browser_tool']
---
You are a supportive coding mentor. Generate a single, original positive
affirmation sentence about my Ruby programming skills...
```

### `flags: debug: true / verbose: true`

The schedule config sets `logging.llm.level: warn` and `logging.mcp.level: warn` — quiet output for most jobs. This prompt overrides that with full debug and verbose logging, producing a detailed log entry for every run. Useful for a prompt you want to keep an eye on, or while developing a new prompt.

### `provider: ollama`

The schedule config's `llm.adapter: ruby_llm` points at cloud providers by default (Anthropic, OpenAI, etc.). `provider: ollama` routes this prompt to a local Ollama server instead.

**Why this matters for scheduled jobs:** cloud API calls can fail with rate limits, transient network errors, or timeouts. A local Ollama model has none of those risks. There are also no API costs. For prompts that don't require GPT-4-level reasoning — affirmations, local system tasks, scripted workflows — a local model is more reliable in an unattended context.

### `models: [{name: gpt-oss:latest}]`

Selects the specific Ollama model to use. Overrides the schedule config's `claude-haiku-4-5` default. The model must be pulled and running in Ollama before the cron job fires.

### `schedule: every 2 minutes`

This key is read exclusively by `aias` when building the cron entry. AIA itself ignores it at runtime. It is what caused `aias add` to produce:

```
0,2,4,6,8,...,58 * * * * /opt/homebrew/bin/bash -c '...'
```

### `required: ['shared_tools']`

Loads the `shared_tools` library, which provides the `eval` tool (shell command execution). The schedule config already declares `require_libs: ["shared_tools"]` globally, so this is redundant for this prompt — but it makes the prompt self-documenting. A reader can tell from the frontmatter alone what the prompt needs.

The `eval` tool is what allows the model to execute `say "..."` as a macOS speech command.

### `tools: rejected: ['browser_tool']`

Prevents the browser tool from being offered to the model even if the active MCP servers expose it. The schedule config loads several MCP servers (GitHub, brew, crimson, claude_code). Some of those may expose browsing capabilities; `rejected` is the safety valve that keeps this prompt narrowly scoped to only what it needs: the `eval`/shell tool.

---

## The Full Execution Flow

When cron fires this entry:

```bash
/opt/homebrew/bin/bash -c 'source ~/.config/aia/schedule/env.sh && \
  /path/to/aia \
    --prompts-dir /path/to/example_prompts \
    --config ~/.config/aia/schedule/aia.yml \
    you_are_good > ~/.config/aia/schedule/logs/you_are_good.log 2>&1'
```

1. **`source env.sh`** — PATH, API keys, AIA_* vars, LANG/LC_ALL injected into the process environment
2. **`aia` starts** — loads built-in defaults, then loads `schedule/aia.yml` via `--config` (base config set)
3. **`--prompts-dir`** — tells AIA where to find prompt files, bypassing any stale `prompts.dir` in the config
4. **AIA locates `you_are_good.md`** in the prompts directory
5. **Frontmatter merged** — `provider: ollama`, `models: gpt-oss:latest`, `flags`, `required`, `tools.rejected` all applied on top of the schedule config
6. **`shared_tools` loaded** — `eval`/shell tool registered and available to the model
7. **Prompt sent to Ollama `gpt-oss:latest`** — no API call, no network, no cost
8. **Model generates affirmation**, then calls `eval` with `say "..."`
9. **macOS `say`** speaks the affirmation aloud
10. **All output** (verbose/debug + response) written to `~/.config/aia/schedule/logs/you_are_good.log`

---

## Keeping Layers Separate

A useful mental model: each layer answers a different question.

| Layer | Question it answers |
|---|---|
| `env.sh` | Can the process find the tools it needs? |
| `schedule/aia.yml` | What are the safe defaults for any unattended job? |
| Prompt frontmatter | What does *this specific prompt* need that differs from those defaults? |

Settings that belong in the schedule config: output format, default model and adapter, log verbosity, MCP server list, libraries that every prompt uses.

Settings that belong in frontmatter: anything prompt-specific — provider override, a specialised model, flags for debugging, additional `required` libs, tool restrictions.

Settings that belong only in `env.sh`: secrets (API keys), PATH construction, locale.

Never put API keys in frontmatter or the schedule config. They would be committed to version control if you track your prompts in git.
