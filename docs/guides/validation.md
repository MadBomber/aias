# Validation

Before writing anything to the crontab, `aias` validates every scheduled prompt. This prevents broken cron entries from silently failing at runtime.

## Validation Rules

### 1. Schedule Syntax

The `schedule:` value must be parseable as either a cron expression or a whenever DSL string.

`aias` validates this by evaluating a minimal whenever DSL fragment:

```ruby
every '0 8 * * *' do
  command 'true'
end
```

**Valid examples:**

```yaml
schedule: "0 8 * * *"
schedule: "@daily"
schedule: "every 1.day at 8:00am"
schedule: "every :monday at 9:00am"
schedule: "every 6.hours"
```

**Invalid examples (fail with an error):**

```yaml
schedule: "every banana"     # not valid whenever DSL
schedule: "0 8 *"            # too few cron fields
schedule: ""                 # empty
```

### 2. Parameter Completeness

All `parameters:` keys must have non-nil, non-empty default values. Cron jobs run unattended — there is no interactive session to supply missing values.

```yaml
# VALID — all parameters have defaults
parameters:
  topic: "Ruby news"
  format: "bullet points"

# INVALID — missing default
parameters:
  topic:           # nil value — rejected
  format: ""       # empty string — rejected
```

### 3. AIA Binary

The `aia` binary must be locatable. Two checks are performed in order; if either succeeds, the prompt passes:

1. **Login-shell `which`** — spawns a login shell and runs `which aia`. This is the normal path when the shell profile initialises the version manager (rbenv, rvm, asdf, etc.).

2. **Fallback directory scan** — if the login-shell check fails (common when `rbenv init` is not in the bash login profile), `aias` scans these directories for an executable named `aia`:

   | Directory | Manager |
   |---|---|
   | `~/.rbenv/shims` | rbenv |
   | `~/.rbenv/bin` | rbenv |
   | `~/.rvm/bin` | rvm |
   | `~/.asdf/shims` | asdf |
   | `/usr/local/bin` | Homebrew / manual |
   | `/usr/bin` | system |
   | `/opt/homebrew/bin` | Homebrew (Apple Silicon) |

   Only an **executable** file satisfies the check — a non-executable file at the path is ignored.

If `aia` is not found by either method, **all** prompts fail this check — no jobs are installed.

The check result is cached per `Validator` instance (shell spawn is expensive).

### 4. Prompts Directory

`$AIA_PROMPTS_DIR` must be set, exist, and be readable. This check happens before scanning, not per-prompt. If it fails, `aias` exits immediately with an error.

## Validation Flow

```
For each prompt file with schedule: in frontmatter:
  1. Check schedule syntax        → error if invalid
  2. Check parameter defaults     → error per missing default
  3. Check aia binary             → error if not found (cached)

  If all checks pass  → prompt is included in install
  If any check fails  → prompt is skipped, warning to stderr
```

The crontab write happens only after all valid prompts have been collected. A mix of valid and invalid prompts is handled gracefully — valid ones are installed, invalid ones are skipped.

## Seeing Validation Results

Use `aias check` to see validation results without modifying the crontab:

```bash
aias check
```

```
INVALID (would be skipped by update):
  bad_prompt: Schedule 'every banana': undefined method 'banana' for Integer

  bad_params: Parameter 'topic' has no default value (required for unattended cron execution)
```

Use `aias dry-run` to see what the valid prompts would generate:

```bash
aias dry-run
```
