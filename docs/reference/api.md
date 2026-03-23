# API Reference

All public classes live under the `Aias::` namespace and are autoloaded by Zeitwerk when `require "aias"` is called.

---

## `Aias::CLI`

**Inherits:** `Thor`

The command-line interface. All eight commands are public instance methods. `CLI.start(ARGV)` is the gem entry point called by the `aias` binary.

### Class Methods

#### `.exit_on_failure?`

Returns `true`. Thor uses this to call `exit(1)` when a command raises an unhandled error.

### Instance Methods

#### `#update`

Scan, validate, and install all scheduled prompts.

```ruby
cli = Aias::CLI.new
cli.update
```

#### `#add(path)`

Add or replace a single prompt's cron job. `path` is an absolute or relative path to the prompt file.

```ruby
cli.add("/Users/you/.prompts/standup.md")
cli.add("./example_prompts/morning_standup.md")
```

Raises `SystemExit(1)` when the file is missing, outside the prompts directory, has no `schedule:` key, or fails validation.

See [`aias add`](../cli/add.md) for full behaviour and upsert semantics.

#### `#check`

Print a diff between scheduled prompts and installed jobs.

```ruby
cli.check
```

#### `#list`

Print a table of all installed jobs.

```ruby
cli.list
```

#### `#dry_run`

Print the cron output that `update` would write, without touching the crontab.

```ruby
cli.dry_run
```

#### `#show(prompt_id)`

Print details for a single installed job. Exits 1 if not found.

```ruby
cli.show("daily_digest")
cli.show("reports/weekly")
```

#### `#upcoming(n = "5")`

Print schedule and last-run information for all installed jobs. Aliased as `aias next` on the command line.

```ruby
cli.upcoming
cli.upcoming("10")
```

#### `#clear`

Remove all aias-managed crontab entries.

```ruby
cli.clear
```

### Dependency Injection

Collaborators are initialized lazily via private accessors. Set instance variables before invoking a command to inject alternatives:

```ruby
cli = Aias::CLI.new
cli.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
cli.instance_variable_set(:@scanner,  Aias::PromptScanner.new(prompts_dir: "/tmp/test"))
cli.update
```

---

## `Aias::PromptScanner`

Discovers AIA prompt files that declare a `schedule:` key and parses their frontmatter.

### `::Result`

```ruby
Aias::PromptScanner::Result = Data.define(:prompt_id, :schedule, :metadata, :file_path)
```

A frozen, immutable value object. Fields:

| Field | Type | Description |
|---|---|---|
| `prompt_id` | `String` | Subpath relative to prompts dir, no `.md` extension |
| `schedule` | `String` | Raw value of the `schedule:` frontmatter key |
| `metadata` | `PM::Metadata` | Full parsed frontmatter object |
| `file_path` | `String` | Absolute path to the prompt file |

### `.new`

```ruby
scanner = Aias::PromptScanner.new
scanner = Aias::PromptScanner.new(prompts_dir: "/path/to/prompts")
```

| Parameter | Default | Description |
|---|---|---|
| `prompts_dir:` | `ENV["AIA_PROMPTS_DIR"]` | Directory to scan |

### `#scan`

```ruby
results = scanner.scan  # => Array<Aias::PromptScanner::Result>
```

Returns an array of `Result` objects for every prompt that has a non-empty `schedule:` key.

**Raises** `Aias::Error` when:

- `prompts_dir` is nil or empty (AIA_PROMPTS_DIR not set)
- The directory does not exist
- The directory is not readable

Prompts with unparseable frontmatter are warned to stderr and skipped (no exception).

### `#scan_one`

```ruby
result = scanner.scan_one(path)  # => Aias::PromptScanner::Result
```

Parses a single prompt file by path (absolute or relative). Returns a `Result` on success.

**Raises** `Aias::Error` when:

| Condition | Message |
|---|---|
| File does not exist | `"Prompt file not found: <path>"` |
| File is not readable | `"Prompt file not readable: <path>"` |
| File is outside `prompts_dir` | `"'<path>' is not inside the prompts directory '<dir>'"` |
| No `schedule:` in frontmatter | `"'<prompt_id>' has no schedule: in its frontmatter"` |
| Frontmatter is unparseable | `"Failed to parse '<prompt_id>': <original error>"` |
| `prompts_dir` missing or unreadable | Same as `#scan` |

Unlike `#scan`, `scan_one` never silently skips — every error condition is a raised exception.

---

## `Aias::Validator`

Validates a `PromptScanner::Result` against three rules: schedule syntax, parameter completeness, and `aia` binary presence.

### `::ValidationResult`

```ruby
Aias::Validator::ValidationResult = Data.define(:valid?, :errors)
```

A frozen, immutable value object. Fields:

| Field | Type | Description |
|---|---|---|
| `valid?` | `Boolean` | `true` when all checks pass |
| `errors` | `Array<String>` | Human-readable error messages (empty when valid) |

### `.new`

```ruby
validator = Aias::Validator.new
validator = Aias::Validator.new(
  shell:         "/bin/bash",
  binary_to_check: "aia",
  fallback_dirs: Aias::Validator::BINARY_FALLBACK_DIRS
)
```

| Parameter | Default | Description |
|---|---|---|
| `shell:` | `ENV["SHELL"]` or `"/bin/bash"` | Login shell used for binary check |
| `binary_to_check:` | `"aia"` | Binary name to locate |
| `fallback_dirs:` | `BINARY_FALLBACK_DIRS` | Directories scanned when the login-shell check fails |

`binary_to_check:` and `fallback_dirs:` are primarily useful in tests — pass `"ruby"` for a check that always succeeds, or an empty/nonexistent directory list for one that always fails.

### `::BINARY_FALLBACK_DIRS`

```ruby
Aias::Validator::BINARY_FALLBACK_DIRS
# => [
#      "~/.rbenv/shims",
#      "~/.rbenv/bin",
#      "~/.rvm/bin",
#      "~/.asdf/shims",
#      "/usr/local/bin",
#      "/usr/bin",
#      "/opt/homebrew/bin"
#    ]
```

The default fallback directory list. Covers rbenv, rvm, asdf, Homebrew (Intel + Apple Silicon), and the standard system paths.

### `#validate`

```ruby
vr = validator.validate(scanner_result)  # => Aias::Validator::ValidationResult
vr.valid?   # => true or false
vr.errors   # => ["Schedule 'x': ...", "Parameter 'y' has no default ..."]
```

The binary check result is memoised per `Validator` instance and only runs once.

### `#binary_in_fallback_location?`

```ruby
validator.binary_in_fallback_location?  # => true or false
```

Returns `true` when an executable file named `binary_to_check` exists in any of the `fallback_dirs`. Called automatically by `#validate`; exposed publicly for diagnostics.

---

## `Aias::JobBuilder`

Converts a `PromptScanner::Result` into a raw cron line string. Pure function — no I/O.

### `.new`

```ruby
builder = Aias::JobBuilder.new
builder = Aias::JobBuilder.new(shell: "/bin/zsh")
builder = Aias::JobBuilder.new(shell: "/bin/zsh", prompts_dir: "/path/to/prompts")
```

| Parameter | Default | Description |
|---|---|---|
| `shell:` | `ENV["SHELL"]` or `"/bin/bash"` | Login shell binary used to wrap the `aia` invocation |
| `prompts_dir:` | `nil` | When set, appends `--prompts-dir DIR` to every generated `aia` command |

### `#build`

```ruby
cron_line = builder.build(scanner_result)  # => String
```

Returns a fully-formed cron line string suitable for passing to `CrontabManager#install` or `#add_job`. Uses `fugit` to resolve the `schedule:` value to a canonical 5-field cron expression.

**Without `prompts_dir`:**

```
0 8 * * * /bin/zsh -l -c 'aia daily_digest >> /Users/you/.aia/schedule/logs/daily_digest.log 2>&1'
```

**With `prompts_dir: "/data/prompts"`:**

```
0 8 * * * /bin/zsh -l -c 'aia --prompts-dir /data/prompts daily_digest >> /Users/you/.aia/schedule/logs/daily_digest.log 2>&1'
```

### `#log_path_for`

```ruby
builder.log_path_for("daily_digest")     # => "/Users/you/.aia/schedule/logs/daily_digest.log"
builder.log_path_for("reports/weekly")   # => "/Users/you/.aia/schedule/logs/reports/weekly.log"
```

Returns the absolute log path for a given prompt ID.

---

## `Aias::CrontabManager`

Manages the aias-owned block in the user's crontab by directly invoking the system `crontab(1)` command via `Open3`.

### Constants

| Constant | Value | Description |
|---|---|---|
| `IDENTIFIER` | `"aias"` | Whenever identifier that marks the managed block |
| `LOG_BASE` | `~/.aia/schedule/logs` | Default base directory for log files |
| `ENTRY_RE` | Regexp | Parses installed cron lines to extract `prompt_id`, `cron_expr`, `log_path` |

### `.new`

```ruby
manager = Aias::CrontabManager.new
manager = Aias::CrontabManager.new(crontab_command: "crontab", log_base: "/custom/log/base")
```

| Parameter | Default | Description |
|---|---|---|
| `crontab_command:` | `"crontab"` | Path to the `crontab(1)` binary |
| `log_base:` | `LOG_BASE` | Base directory for log files |

The `crontab_command:` parameter makes the manager testable with a fake crontab script backed by a tmpfile, with no system crontab involvement.

### `#install`

```ruby
manager.install(cron_lines)
```

Accepts a single cron line string or an array of cron line strings. Creates `@log_base` if absent, then replaces the entire `aias`-managed crontab block by piping the new content to `crontab -` via `Open3`.

**Raises** `Aias::Error` if the `crontab` command exits non-zero.

### `#add_job`

```ruby
manager.add_job(cron_line, prompt_id)
```

Upserts a single cron entry into the aias-managed block. Any existing entry whose `prompt_id` matches is removed first; the new `cron_line` is appended. All other managed entries are left unchanged. Non-aias crontab entries are never touched.

`cron_line` is a fully-formed cron line as produced by `JobBuilder#build`:

```
0 9 * * 1-5 /bin/zsh -l -c 'aia standup >> ~/.aia/schedule/logs/standup.log 2>&1'
```

Creates `@log_base` if absent. **Raises** `Aias::Error` if the crontab write fails.

### `#clear`

```ruby
manager.clear
```

Removes the `# BEGIN aias` … `# END aias` block from the crontab and rewrites it via `crontab -`. Non-aias entries are untouched.

### `#dry_run`

```ruby
output = manager.dry_run(cron_lines)  # => String
```

Returns the cron lines that would be installed joined by newlines, without making any system calls or writing to the crontab.

### `#installed_jobs`

```ruby
jobs = manager.installed_jobs
# => [
#      { prompt_id: "daily_digest", cron_expr: "0 8 * * *", log_path: "/..." },
#      { prompt_id: "reports/weekly", cron_expr: "0 9 * * 1", log_path: "/..." }
#    ]
```

Reads the current crontab and parses the `aias`-managed block. Returns an empty array when no block is installed.

### `#current_block`

```ruby
block = manager.current_block  # => String
```

Returns the raw text between the `# BEGIN aias` and `# END aias` marker lines (markers excluded). Returns `""` when no block exists.

### `#ensure_log_directories`

```ruby
manager.ensure_log_directories(["daily_digest", "reports/weekly"])
```

Creates the log subdirectory structure under `@log_base` for each prompt ID. Called by `CLI#update` before installing.

---

## `Aias::Error`

```ruby
class Aias::Error < StandardError; end
```

Raised for unrecoverable errors: missing prompts directory, crontab write failure. Caught by `CLI` which prints the message and exits 1.
