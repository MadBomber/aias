## [Unreleased]

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
