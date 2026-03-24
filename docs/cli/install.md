# aias install

Capture your current shell environment into `~/.config/aia/schedule/env.sh` so scheduled jobs can find `aia`, authenticate with LLM APIs, and reach any MCP servers your prompts depend on.

```bash
aias install [PATTERN...]
```

Run this once after installing `aias`, and again any time your environment changes.

---

## What It Does

1. Reads a set of environment variables from the current shell process (see [Default Variables](#default-variables) below)
2. Writes them as `export KEY="value"` lines into `~/.config/aia/schedule/env.sh`, wrapped in `# BEGIN aias-env` / `# END aias-env` markers
3. Creates `~/.config/aia/schedule/` if it does not exist
4. Copies `~/.config/aia/aia.yml` to `~/.config/aia/schedule/aia.yml` if that file does not yet exist (first run only)
5. Sets file permissions on `env.sh` to `0600` (owner read/write only)

The generated `env.sh` is sourced at the start of every cron entry `aias` installs:

```bash
source ~/.config/aia/schedule/env.sh && aia --config ... prompt_id > log 2>&1
```

---

## Default Variables

The following groups are captured automatically on every `aias install`, with no pattern argument required.

### `PATH`

```bash
export PATH="/Users/you/.rbenv/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
```

**Why it is needed:** Cron's default `PATH` is `/usr/bin:/bin` — nothing else. The `aia` binary lives in a gem bin directory under a Ruby version manager shim path. MCP server binaries (Node packages, Homebrew-installed tools) live in `/opt/homebrew/bin` or similar locations. Without the full `PATH`, every scheduled job would fail immediately with `command not found`.

`PATH` is captured from your live shell at install time, when rbenv, asdf, or your version manager is already activated. This is why `aias install` must be run from an interactive terminal, not from a cron job itself.

### `*_API_KEY` (all variables ending in `_API_KEY`)

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
export GEMINI_API_KEY="..."
export OPENROUTER_API_KEY="..."
```

**Why they are needed:** Cron does not inherit your interactive shell's exports. Any variable you set in `.bashrc`, `.zshrc`, or in a terminal session is not available to cron unless it is explicitly written to a file that cron sources. Without the API key for the LLM provider your prompt uses, AIA cannot authenticate and every scheduled prompt run will return an authentication error.

The pattern `*_API_KEY` is broad by design — it captures keys for all LLM providers at once (Anthropic, OpenAI, Google, Together, OpenRouter, and any others you have set), so you do not need to list them individually.

### `AIA_*` (all variables starting with `AIA_`)

```bash
export AIA_PROMPTS__DIR="/Users/you/.prompts"
export AIA_MODEL="claude-haiku-4-5"
export AIA_FLAGS__VERBOSE="false"
```

**Why they are needed:** AIA's runtime behaviour is controlled through `AIA_*` environment variables. The most important is `AIA_PROMPTS__DIR`, which tells AIA where to find prompt files. Without it, AIA cannot resolve a prompt ID like `daily_digest` to an actual file, and the job fails with a "file not found" error.

Other `AIA_*` variables set defaults that you may have tuned in your interactive shell — model selection, output format flags, backend adapter settings. Capturing the entire `AIA_*` group ensures the scheduled environment matches your interactive environment as closely as possible.

### `LANG` and `LC_ALL`

```bash
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
```

**Why they are needed:** When neither `LANG` nor `LC_ALL` is set, Ruby defaults to `US-ASCII` encoding. AIA prompt files, LLM responses, and log output routinely contain UTF-8 characters (curly quotes, em dashes, emoji, non-English text). Without a UTF-8 locale, Ruby raises `Encoding::UndefinedConversionError` and the job fails mid-run with a cryptic encoding error. Setting these variables ensures Ruby uses UTF-8 for all string operations.

---

## Capturing Additional Variables with Patterns

Pass one or more glob patterns as arguments to capture variables beyond the defaults:

```bash
aias install 'PATTERN'
aias install 'PATTERN_1' 'PATTERN_2'
aias install 'PATTERN_1 PATTERN_2'   # space-separated in a single argument
```

Patterns are matched case-insensitively. The default groups (`PATH`, `*_API_KEY`, `AIA_*`, `LANG`, `LC_ALL`) are always included — patterns only add to them.

### MCP Server Variables

If your scheduled prompts use MCP servers, those servers often need their own credentials or configuration variables. Cron will not have these unless you explicitly capture them.

**GitHub MCP server**

The GitHub MCP server (`github-mcp-server`) requires a personal access token to authenticate with the GitHub API:

```bash
aias install 'GITHUB_*'
```

This captures variables like `GITHUB_TOKEN`, `GITHUB_PERSONAL_ACCESS_TOKEN`, and `GITHUB_API_KEY` — whichever your GitHub MCP server configuration expects. Without the token, any scheduled prompt that calls GitHub tools (reading issues, listing repositories, searching code) will receive an authentication error from the GitHub API.

**Homebrew MCP server**

The Homebrew MCP server (`brew mcp-server`) may read Homebrew-specific configuration variables:

```bash
aias install 'HOMEBREW_*'
```

This captures `HOMEBREW_PREFIX`, `HOMEBREW_CELLAR`, `HOMEBREW_REPOSITORY`, and any `HOMEBREW_*` variables you have set. Without them, the brew MCP server may fail to locate its own installation or behave differently than it does in your interactive shell.

**Combining patterns**

Install all at once in a single command:

```bash
aias install 'GITHUB_*' 'HOMEBREW_*'
```

Or add them to an existing `env.sh` incrementally — each `aias install` rewrites only the managed block, so running it multiple times with different patterns is safe. The last run wins for any variable that appears in more than one pattern.

**Other MCP servers**

The same principle applies to any MCP server that reads credentials or configuration from the environment. Check the documentation for each MCP server you use to identify its required environment variables, then add the appropriate pattern to your `aias install` command.

| MCP server | Variables to capture | Pattern |
|---|---|---|
| github-mcp-server | `GITHUB_TOKEN`, `GITHUB_PERSONAL_ACCESS_TOKEN` | `'GITHUB_*'` |
| brew mcp-server | `HOMEBREW_PREFIX`, `HOMEBREW_CELLAR`, etc. | `'HOMEBREW_*'` |
| OpenRouter | `OPEN_ROUTER_API_KEY` | captured by default (`*_API_KEY`) |
| crimson | Check crimson's documentation | `'CRIMSON_*'` |
| Custom MCP server | Depends on implementation | `'YOUR_SERVER_*'` |

---

## Example Output

```
aias: installed AGENTQL_API_KEY, AIA_FLAGS__VERBOSE, AIA_MODEL, AIA_PROMPTS__DIR,
  ANTHROPIC_API_KEY, GEMINI_API_KEY, GITHUB_TOKEN, HOMEBREW_PREFIX,
  LANG, LC_ALL, OPENAI_API_KEY, PATH into ~/.config/aia/schedule/env.sh
```

---

## The Schedule Config

On the first run, if `~/.config/aia/aia.yml` exists and `~/.config/aia/schedule/aia.yml` does not, `aias install` copies your interactive AIA config to the schedule directory as a starting point:

```
aias: copied ~/.config/aia/aia.yml → ~/.config/aia/schedule/aia.yml

Review ~/.config/aia/schedule/aia.yml — these settings apply to all scheduled prompts.
Prompt frontmatter overrides any setting in that file.
```

**Important:** edit `schedule/aia.yml` after this copy. Your interactive config almost certainly has settings that are wrong for unattended cron jobs — MCP servers you do not want loaded for every scheduled run, verbose output flags, or editor-specific settings. The schedule config should be a minimal, conservative baseline. See [Configuration Layering](../guides/configuration-layering.md) for guidance.

If `schedule/aia.yml` already exists, `aias install` leaves it untouched.

---

## Updating env.sh

Re-run `aias install` (with any patterns you need) whenever:

- You rotate or add an API key
- You install a new MCP server binary
- You change your Ruby version or version manager configuration
- You add or change an `AIA_*` variable in your shell profile
- You set up a new MCP server that needs its own credentials

The managed block in `env.sh` is replaced atomically on each run. Content you have written outside the markers is preserved.

---

## Viewing the Captured Environment

```bash
cat ~/.config/aia/schedule/env.sh
```

---

## Options

`aias install` accepts no named options — only the optional glob pattern arguments described above.

---

## See Also

- [`aias uninstall`](uninstall.md) — remove the managed env block from `env.sh`
- [Cron Environment](../guides/cron-environment.md) — how `env.sh` solves the cron PATH problem
- [Configuration Layering](../guides/configuration-layering.md) — how `env.sh`, the schedule config, and prompt frontmatter combine at runtime
