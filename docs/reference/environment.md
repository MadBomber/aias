# Environment Variables

## Prompts Directory Resolution

The prompts directory is resolved in this order:

| Priority | Source |
|---|---|
| 1 (highest) | `--prompts-dir PATH` CLI option |
| 2 | `AIA_PROMPTS__DIR` environment variable (AIA >= 0.8.0) |
| 3 | `AIA_PROMPTS_DIR` environment variable (AIA < 0.8.0) |
| — | Error if none of the above is set |

---

## `AIA_PROMPTS__DIR`

**Preferred.** Set by AIA >= 0.8.0. Takes precedence over `AIA_PROMPTS_DIR`.

```bash
export AIA_PROMPTS__DIR="$HOME/.prompts"
```

## `AIA_PROMPTS_DIR`

**Legacy (AIA < 0.8.0).** The absolute path to the directory containing your AIA prompt files. Used as a fallback when `AIA_PROMPTS__DIR` is not set.

```bash
export AIA_PROMPTS_DIR="$HOME/.prompts"
```

Set this in your login profile (`.zprofile`, `.bash_profile`) so it is available in cron jobs.

## `SHELL`

**Optional.** The shell binary used to wrap each cron entry with a login invocation.

`aias` reads `ENV["SHELL"]` when building job entries. If not set, falls back to `/bin/bash`.

```bash
echo $SHELL
# /bin/zsh
```

This produces cron entries of the form:

```
0 8 * * * /bin/zsh -l -c 'aia daily_digest >> ... 2>&1'
```

To override the shell for a specific `update` run:

```bash
SHELL=/bin/bash aias update
```

## Variables Needed by AIA at Runtime

These are not used by `aias` directly, but must be available in your login profile for cron jobs to succeed.

| Variable | Description |
|---|---|
| `ANTHROPIC_API_KEY` | Anthropic API key (when using Claude) |
| `OPENAI_API_KEY` | OpenAI API key (when using GPT models) |
| `AIA_PROMPTS_DIR` | Same as above — must be in login profile |

Set these in your login profile, not only in your interactive shell's rc file (`.bashrc`, `.zshrc`). See [Cron Environment](../guides/cron-environment.md) for details.
