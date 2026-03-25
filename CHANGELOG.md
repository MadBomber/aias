# AIAS Change Log

The AI Assistant Scheduler

## [Unreleased]

## [0.1.0] 2026-03-24

### refactor(cli): split monolithic CLI into per-command files

Moved each of the twelve CLI commands into its own file under
`lib/aias/cli/` (e.g. `cli/update.rb`, `cli/add.rb`). The main
`cli.rb` is now a slim skeleton containing shared helpers, map aliases,
and `require_relative` calls. Zeitwerk is configured to ignore the
`cli/` subdirectory so the files are loaded explicitly rather than
autoloaded as constants.

Test suite split to match: shared helpers extracted into
`test/cli_test_case.rb`; each command has its own `test/test_cli_*.rb`
file. The monolithic `test/test_cli.rb` is removed.

### fix(cli): fix `c_l_i` namespace appearing in `aias help` output

Thor's `help` instance method takes `subcommand` as a positional
argument but the override declared it as a keyword argument
(`subcommand: false`). Ruby passed `{subcommand: false}` — a truthy
hash — to Thor's positional parameter, causing `formatted_usage` to
prepend the snake-cased class name (`c_l_i`) to every command in the
help table. Fixed by changing the signature to match Thor's:
`def help(command = nil, subcommand = false)`.

### feat(cli): add `aias version` command

Prints the installed gem version. Accessible as `aias version`,
`aias -v`, or `aias --version`.

### refactor: extract shared modules and classes

- `Aias::BlockParser` — shared `extract_block` / `strip_block` helpers
  used by both `CrontabManager` and `EnvFile`; eliminates ~60 lines of
  duplication
- `Aias::Paths` — single source of truth for all filesystem paths
  (`SCHEDULE_DIR`, `SCHEDULE_CFG`, `SCHEDULE_LOG`, `SCHEDULE_ENV`,
  `AIA_CONFIG`)
- `Aias::ScheduleConfig` — extracted from `CLI#install`; manages
  `prompts.dir` key in `~/.config/aia/schedule/aia.yml` with full test
  coverage

### fix(job_builder): double-quote paths in generated cron entries

Paths embedded in cron command strings are now wrapped in double quotes
inside the single-quoted shell string. Prevents failures when prompts
directory, log directory, or config file paths contain spaces.

### fix(crontab_manager): distinguish missing crontab from read failure

`crontab -l` exits non-zero both when the user has no crontab and when
a real error occurs. `read_crontab` now returns `""` only on the "no
crontab for" message and raises `Aias::Error` for any other failure,
preventing silent crontab overwrites on read errors.

### fix(prompt_scanner): tighten `grep` invocation

Added `--include=*.md` and `-m 1` flags to the `grep -rl` call.
Limits candidate files to Markdown and stops reading each file after
the first `schedule:` match, reducing I/O on large prompts directories.

### fix(security): create directories with mode 0700, env file with 0600

All `FileUtils.mkdir_p` calls now pass `mode: 0o700`. `EnvFile#write`
applies `chmod 0600` on every write so API keys in `env.sh` are never
world-readable, even if `umask` is permissive.

### docs: rewrite README for CLI users

- Removed the "Public API" section (internal Ruby classes belong in the
  full documentation site, not the README)
- Added "Usage" section with the full `aias help` output
- Rewrote "How It Works" in user-facing terms; no internal class names
- Key Features table: stripped per-feature descriptions; names only
- Added link to full documentation site under the logo
- CLI Commands table: added `aias version`
- Fixed stale single-test example (referenced deleted `test_cli.rb`)

### docs: update `docs/index.md` to match README structure

- Key Features: names only, no inline descriptions
- Added "Commands" section with full `aias help` output
- Rewrote "How It Works" in user-facing terms

### docs: add "Understanding Cron and Crontab" guide

New `docs/guides/understanding-cron.md` for users unfamiliar with cron.
Covers: what cron is; what a crontab is; reading a five-field cron
expression; how `aias` owns its block without disturbing other entries;
why cron strips the environment and how `aias install` solves it;
essential `crontab` commands; checking job logs; macOS Full Disk Access
note. Cross-linked from `guides/cron-environment.md`.

### feat(cli): add `aias add PATH` command

Installs or replaces a single prompt's cron job without touching any other
installed entries. Useful when you have edited one prompt and want it
scheduled immediately without re-scanning the entire prompts directory.

- `PromptScanner#scan_one(path)` — parses a single file by path; raises
  `Aias::Error` for missing files, files outside the prompts directory, or
  prompts with no `schedule:` in their frontmatter
- `CrontabManager#add_job(cron_line, prompt_id)` — upserts one entry into
  the aias-managed crontab block; existing entries for the same prompt ID
  are replaced cleanly; all other entries are left untouched
- Full validation (schedule syntax, parameter defaults, `aia` binary) runs
  before any crontab write, consistent with `aias update`

### docs: add `aias add` command documentation

- New `docs/cli/add.md` — full command reference with upsert semantics,
  worked examples, prompt ID derivation, options table, and exit codes
- Updated `docs/cli/index.md` — command count, table row, and
  `--prompts-dir` example
- Updated `docs/reference/api.md` — `CLI#add`, `PromptScanner#scan_one`,
  and `CrontabManager#add_job` API entries
- Updated `README.md` — command table, `aias add` section, and Public API
  entries for all three new methods

### chore(gemspec): update summary and description

- Summary sharpened to lead with the "no config file" differentiator
- Description rewritten as a `<<~DESC` heredoc covering the full feature
  set: `update`, `add`, schedule formats, runtime model, log location

### refactor(prompts): rewrite `code_health_check` example prompt

Replaced a passive checklist with an active review prompt that runs
commands, reads files, and reports findings directly rather than generating
to-do items for the user to complete manually.

## [0.1.0] - 2026-03-23

- Initial release
