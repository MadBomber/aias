# frozen_string_literal: true

require "test_helper"
require "tmpdir"

# CLI tests wire real collaborators. Test isolation comes from:
#   - a per-test tmpdir that holds prompt files, the fake crontab state,
#     and log directories
#   - Validator(binary_to_check: "ruby") so the binary check always passes
#     without requiring aia to be installed in the test environment
class TestCli < Minitest::Test
  def setup
    @prompts_dir   = Dir.mktmpdir("aias_cli_test_")
    @log_base      = File.join(@prompts_dir, "logs")
    @crontab_state = File.join(@prompts_dir, "crontab_state")
    @fake_crontab  = write_fake_crontab(@prompts_dir, @crontab_state)
    @env_file_path = File.join(@prompts_dir, "env.sh")
  end

  def teardown
    FileUtils.remove_entry(@prompts_dir)
  end

  # ---------------------------------------------------------------------------
  # update
  # ---------------------------------------------------------------------------

  def test_update_with_no_valid_prompts_prints_no_jobs_message
    out, = capture_io { new_cli.update }
    assert_match "no valid scheduled prompts", out
  end

  def test_update_installs_crontab_for_valid_prompt
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    capture_io { new_cli.update }
    assert File.exist?(@crontab_state), "update should write to the crontab"
    assert_equal 1, new_manager.installed_jobs.size
  end

  def test_update_does_not_install_when_all_invalid
    write_prompt("bad.md", schedule: "every banana")
    capture_io { new_cli.update }
    refute File.exist?(@crontab_state), "crontab must not be written when all prompts are invalid"
  end

  def test_update_warns_for_invalid_prompts
    write_prompt("bad.md", schedule: "every banana")
    _, err = capture_io { new_cli.update }
    assert_match "skip", err
    assert_match "bad", err
  end

  def test_update_prints_installed_count
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    out, = capture_io { new_cli.update }
    assert_match "1 job", out
  end

  def test_update_prints_skipped_count_when_mix_of_valid_and_invalid
    write_prompt("good.md",  schedule: "0 8 * * *")
    write_prompt("bad.md",   schedule: "every banana")
    out, = capture_io { new_cli.update }
    assert_match "skipped 1 invalid", out
  end

  def test_update_rescues_aias_error
    assert_raises(SystemExit) do
      capture_io { new_cli_with_bad_dir.update }
    end
  end

  def test_prompts_dir_option_overrides_env_var
    other_dir = Dir.mktmpdir("aias_cli_other_")
    write_prompt("daily_digest.md", schedule: "0 8 * * *")  # in @prompts_dir
    # CLI pointed at other_dir (empty) — should find no prompts
    cli = Aias::CLI.new([], { prompts_dir: other_dir })
    cli.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
    cli.instance_variable_set(:@builder,  Aias::JobBuilder.new(shell: "/bin/bash", aia_path: "/usr/local/bin/aia"))
    cli.instance_variable_set(:@manager,  new_manager)
    out, = capture_io { cli.update }
    assert_match "no valid scheduled prompts", out
  ensure
    FileUtils.remove_entry(other_dir)
  end

  def test_generated_aia_command_includes_prompts_dir_flag
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    mgr = new_manager
    cli = Aias::CLI.new([], { prompts_dir: @prompts_dir })
    cli.instance_variable_set(:@scanner,  Aias::PromptScanner.new(prompts_dir: @prompts_dir))
    cli.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
    cli.instance_variable_set(:@builder,  Aias::JobBuilder.new(shell: "/bin/bash", aia_path: "/usr/local/bin/aia", env_file: @env_file_path))
    cli.instance_variable_set(:@manager,  mgr)
    capture_io { cli.update }
    assert_match %(--prompts-dir "#{File.expand_path(@prompts_dir)}"), mgr.current_block,
      "Generated crontab entry must include --prompts-dir flag"
    refute_match "--config", mgr.current_block
  end

  def test_generated_aia_command_has_no_inline_env_vars
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    mgr = new_manager
    cli = Aias::CLI.new.tap do |c|
      c.instance_variable_set(:@scanner,  Aias::PromptScanner.new(prompts_dir: @prompts_dir))
      c.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
      c.instance_variable_set(:@builder,  Aias::JobBuilder.new(shell: "/bin/bash", aia_path: "/usr/local/bin/aia"))
      c.instance_variable_set(:@manager,  mgr)
    end
    capture_io { cli.update }
    refute_match "AIA_MODEL=", mgr.current_block
    refute_match "ANTHROPIC_API_KEY=", mgr.current_block
  end

  # ---------------------------------------------------------------------------
  # add
  # ---------------------------------------------------------------------------

  def test_add_prints_success_message
    path = write_prompt("standup.md", schedule: "0 9 * * 1-5")
    out, = capture_io { new_cli.add(path) }
    assert_match "standup", out
  end

  def test_add_installs_the_job_in_crontab
    path = write_prompt("standup.md", schedule: "0 9 * * 1-5")
    mgr  = new_manager
    cli  = new_cli_with_manager(mgr)
    capture_io { cli.add(path) }
    ids = mgr.installed_jobs.map { |j| j[:prompt_id] }
    assert_includes ids, "standup"
  end

  def test_add_does_not_remove_other_installed_jobs
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    mgr = new_manager
    capture_io { new_cli_with_manager(mgr).update }   # install daily_digest first
    standup_path = write_prompt("standup.md", schedule: "0 9 * * 1-5")
    capture_io { new_cli_with_manager(mgr).add(standup_path) }
    ids = mgr.installed_jobs.map { |j| j[:prompt_id] }
    assert_includes ids, "daily_digest"
    assert_includes ids, "standup"
  end

  def test_add_replaces_existing_entry_for_same_prompt
    path = write_prompt("standup.md", schedule: "0 8 * * *")
    mgr  = new_manager
    capture_io { new_cli_with_manager(mgr).add(path) }
    # Overwrite the file with a different hour, re-add
    path = write_prompt("standup.md", schedule: "0 10 * * *")
    capture_io { new_cli_with_manager(mgr).add(path) }
    jobs = mgr.installed_jobs.select { |j| j[:prompt_id] == "standup" }
    assert_equal 1, jobs.size, "re-adding must not create a duplicate"
    assert_equal "0 10 * * *", jobs.first[:cron_expr]
  end

  def test_add_exits_when_prompt_has_no_schedule
    path = write_prompt("no_schedule.md")
    assert_raises(SystemExit) { capture_io { new_cli.add(path) } }
  end

  def test_add_prints_error_when_prompt_has_no_schedule
    path = write_prompt("no_schedule.md")
    _, err = capture_io do
      assert_raises(SystemExit) { new_cli.add(path) }
    end
    assert_match "error", err
    assert_match "no schedule:", err
  end

  def test_add_exits_when_schedule_is_invalid
    path = write_prompt("bad.md", schedule: "every banana")
    assert_raises(SystemExit) { capture_io { new_cli.add(path) } }
  end

  def test_add_prints_error_when_schedule_is_invalid
    path = write_prompt("bad.md", schedule: "every banana")
    _, err = capture_io do
      assert_raises(SystemExit) { new_cli.add(path) }
    end
    assert_match "error", err
  end

  def test_add_exits_when_file_does_not_exist
    assert_raises(SystemExit) do
      capture_io { new_cli.add(File.join(@prompts_dir, "ghost.md")) }
    end
  end

  def test_add_success_message_includes_human_readable_schedule
    path = write_prompt("standup.md", schedule: "0 9 * * 1-5")
    out, = capture_io { new_cli.add(path) }
    # CronDescriber.display("0 9 * * 1-5") => "every weekday at 9am (0 9 * * 1-5)"
    assert_match "weekday", out
  end

  # ---------------------------------------------------------------------------
  # remove
  # ---------------------------------------------------------------------------

  def test_remove_prints_success_message
    path = write_prompt("standup.md", schedule: "0 9 * * 1-5")
    mgr  = new_manager
    capture_io { new_cli_with_manager(mgr).add(path) }
    out, = capture_io { new_cli_with_manager(mgr).remove("standup") }
    assert_match "removed", out
    assert_match "standup", out
  end

  def test_remove_uninstalls_the_job_from_crontab
    path = write_prompt("standup.md", schedule: "0 9 * * 1-5")
    mgr  = new_manager
    capture_io { new_cli_with_manager(mgr).add(path) }
    capture_io { new_cli_with_manager(mgr).remove("standup") }
    assert_empty mgr.installed_jobs
  end

  def test_remove_leaves_other_jobs_intact
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    mgr = new_manager
    capture_io { new_cli_with_manager(mgr).update }
    standup_path = write_prompt("standup.md", schedule: "0 9 * * 1-5")
    capture_io { new_cli_with_manager(mgr).add(standup_path) }
    capture_io { new_cli_with_manager(mgr).remove("standup") }
    ids = mgr.installed_jobs.map { |j| j[:prompt_id] }
    assert_includes ids, "daily_digest"
    refute_includes ids, "standup"
  end

  def test_remove_exits_when_prompt_id_not_installed
    assert_raises(SystemExit) { capture_io { new_cli.remove("nonexistent") } }
  end

  def test_remove_prints_error_when_prompt_id_not_installed
    _, err = capture_io do
      assert_raises(SystemExit) { new_cli.remove("nonexistent") }
    end
    assert_match "error", err
    assert_match "nonexistent", err
  end

  # ---------------------------------------------------------------------------
  # install / uninstall
  # ---------------------------------------------------------------------------

  def test_install_writes_api_keys_to_env_file
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env("ANTHROPIC_API_KEY" => "sk-ant-test", "OPENAI_API_KEY" => "sk-open-test") do
      capture_io { cli.install }
    end
    block = ef.current_block
    assert_match 'export ANTHROPIC_API_KEY="sk-ant-test"', block
    assert_match 'export OPENAI_API_KEY="sk-open-test"', block
  end

  def test_install_writes_path_to_env_file
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env({}) { capture_io { cli.install } }
    assert_match "export PATH=", ef.current_block
  end

  def test_install_prints_installed_var_names
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    out, = with_env("ANTHROPIC_API_KEY" => "sk-ant-test") do
      capture_io { cli.install }
    end
    assert_match "ANTHROPIC_API_KEY", out
    assert_match "PATH", out
  end

  def test_install_with_pattern_adds_matching_vars
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env("AIA_MODEL" => "claude-haiku-4-5", "AIA_BACKEND" => "anthropic") do
      capture_io { cli.install("AIA_*") }
    end
    block = ef.current_block
    assert_match 'export AIA_MODEL="claude-haiku-4-5"', block
    assert_match 'export AIA_BACKEND="anthropic"', block
  end

  def test_install_with_multiple_patterns
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env("AIA_MODEL" => "claude-haiku-4-5", "ANTHROPIC_API_KEY" => "sk-ant-test") do
      capture_io { cli.install("AIA_*") }
    end
    block = ef.current_block
    assert_match 'export AIA_MODEL="claude-haiku-4-5"', block
    assert_match 'export ANTHROPIC_API_KEY="sk-ant-test"', block
  end

  def test_install_with_space_separated_patterns_in_single_arg
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env("AIA_MODEL" => "claude-haiku-4-5", "OPENAI_API_KEY" => "sk-open-test") do
      capture_io { cli.install("AIA_* OPENAI_*") }
    end
    block = ef.current_block
    assert_match 'export AIA_MODEL="claude-haiku-4-5"', block
    assert_match 'export OPENAI_API_KEY="sk-open-test"', block
  end

  def test_install_pattern_is_case_insensitive
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env("AIA_MODEL" => "claude-haiku-4-5") do
      capture_io { cli.install("aia_*") }
    end
    assert_match 'export AIA_MODEL="claude-haiku-4-5"', ef.current_block
  end

  def test_install_pattern_does_not_add_non_matching_vars
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env("AIA_MODEL" => "claude-haiku-4-5", "UNRELATED_VAR" => "nope") do
      capture_io { cli.install("AIA_*") }
    end
    refute_match "UNRELATED_VAR", ef.current_block
  end

  def test_uninstall_removes_api_keys_from_env_file
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env("ANTHROPIC_API_KEY" => "sk-ant-test") { capture_io { cli.install } }
    capture_io { cli.uninstall }
    assert_empty ef.current_block
  end

  def test_uninstall_prints_confirmation
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    out, = capture_io { cli.uninstall }
    assert_match "removed", out
  end

  # ---------------------------------------------------------------------------
  # clear
  # ---------------------------------------------------------------------------

  def test_clear_removes_installed_crontab_entries
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    capture_io { new_cli.update }  # install first
    refute_empty new_manager.installed_jobs  # verify pre-condition
    capture_io { new_cli.clear }
    assert_empty new_manager.installed_jobs
  end

  def test_clear_prints_confirmation
    out, = capture_io { new_cli.clear }
    assert_match "removed", out
  end

  # ---------------------------------------------------------------------------
  # list
  # ---------------------------------------------------------------------------

  def test_list_prints_no_jobs_when_empty
    out, = capture_io { new_cli.list }
    assert_match "no installed jobs", out
  end

  def test_list_prints_table_headers
    preset_crontab(sample_crontab_block("daily_digest", "0 8 * * *"))
    out, = capture_io { new_cli.list }
    assert_match "PROMPT ID", out
    assert_match "SCHEDULE", out
  end

  def test_list_prints_job_details
    preset_crontab(sample_crontab_block("daily_digest", "0 8 * * *"))
    out, = capture_io { new_cli.list }
    assert_match "daily_digest", out
    assert_match "0 8 * * *", out
    assert_match "daily_digest.log", out
  end

  # ---------------------------------------------------------------------------
  # check
  # ---------------------------------------------------------------------------

  def test_check_reports_ok_when_in_sync
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    capture_io { new_cli.update }  # install so it's in sync
    out, = capture_io { new_cli.check }
    assert_match "OK", out
  end

  def test_check_reports_new_jobs
    write_prompt("new_job.md", schedule: "0 8 * * *")
    # crontab is empty — new_job is not yet installed
    out, = capture_io { new_cli.check }
    assert_match "NEW", out
    assert_match "new_job", out
  end

  def test_check_reports_orphaned_jobs
    # No prompt files, but crontab has an aias entry
    preset_crontab(sample_crontab_block("orphaned", "0 8 * * *"))
    out, = capture_io { new_cli.check }
    assert_match "ORPHANED", out
    assert_match "orphaned", out
  end

  def test_check_reports_invalid_prompts
    write_prompt("bad_job.md", schedule: "every banana")
    out, = capture_io { new_cli.check }
    assert_match "INVALID", out
    assert_match "bad_job", out
  end

  def test_check_rescues_aias_error
    assert_raises(SystemExit) { capture_io { new_cli_with_bad_dir.check } }
  end

  # ---------------------------------------------------------------------------
  # dry-run
  # ---------------------------------------------------------------------------

  def test_dry_run_does_not_write_crontab
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    capture_io { new_cli.dry_run }
    refute File.exist?(@crontab_state), "dry_run must not modify the crontab"
  end

  def test_dry_run_prints_cron_output
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    out, = capture_io { new_cli.dry_run }
    assert_match "0 8 * * *", out
  end

  def test_dry_run_prints_no_prompts_when_none_valid
    out, = capture_io { new_cli.dry_run }
    assert_match "no valid", out
  end

  # ---------------------------------------------------------------------------
  # show
  # ---------------------------------------------------------------------------

  def test_show_prints_job_details_when_found
    preset_crontab(sample_crontab_block("daily_digest", "0 8 * * *"))
    out, = capture_io { new_cli.show("daily_digest") }
    assert_match "daily_digest", out
    assert_match "0 8 * * *", out
  end

  def test_show_exits_when_not_found
    assert_raises(SystemExit) { capture_io { new_cli.show("nonexistent") } }
  end

  def test_show_prints_not_installed_message
    out, = capture_io do
      assert_raises(SystemExit) { new_cli.show("nonexistent") }
    end
    assert_match "not currently installed", out
  end

  # ---------------------------------------------------------------------------
  # upcoming (aias next) — shows next scheduled run time via fugit
  # ---------------------------------------------------------------------------

  def test_upcoming_prints_no_jobs_when_empty
    out, = capture_io { new_cli.upcoming }
    assert_match "no installed jobs", out
  end

  def test_upcoming_prints_job_schedule_and_next_run
    preset_crontab(sample_crontab_block("daily_digest", "0 8 * * *"))
    out, = capture_io { new_cli.upcoming }
    assert_match "daily_digest", out
    assert_match "0 8 * * *", out
    assert_match "next run", out
  end

  def test_upcoming_limits_output_to_n_jobs
    preset_crontab(multi_job_crontab_block(
      ["daily_digest",    "0 8 * * *"],
      ["morning_standup", "0 9 * * *"]
    ))
    out, = capture_io { new_cli.upcoming("1") }
    assert_match "daily_digest", out
    refute_match "morning_standup", out
  end

  def test_upcoming_default_n_is_5
    rows = (1..6).map { |i| ["job_#{i}", "0 #{i} * * *"] }
    preset_crontab(multi_job_crontab_block(*rows))
    out, = capture_io { new_cli.upcoming }
    assert_match "job_1", out
    refute_match "job_6", out
  end

  # ---------------------------------------------------------------------------
  # last_run (aias last) — shows last-run timestamp from log file mtime
  # ---------------------------------------------------------------------------

  def test_last_run_prints_no_jobs_when_empty
    out, = capture_io { new_cli.last_run }
    assert_match "no installed jobs", out
  end

  def test_last_run_prints_job_schedule_and_last_run
    preset_crontab(sample_crontab_block("daily_digest", "0 8 * * *"))
    out, = capture_io { new_cli.last_run }
    assert_match "daily_digest", out
    assert_match "0 8 * * *", out
    assert_match "last run", out
  end

  def test_last_run_shows_never_run_when_log_absent
    preset_crontab(sample_crontab_block("daily_digest", "0 8 * * *"))
    out, = capture_io { new_cli.last_run }
    assert_match "never run", out
  end

  def test_last_run_shows_mtime_when_log_exists
    preset_crontab(sample_crontab_block("daily_digest", "0 8 * * *"))
    log_path = File.join(@log_base, "daily_digest.log")
    FileUtils.mkdir_p(File.dirname(log_path))
    File.write(log_path, "output\n")
    out, = capture_io { new_cli.last_run }
    refute_match "never run", out
  end

  def test_last_run_limits_output_to_n_jobs
    preset_crontab(multi_job_crontab_block(
      ["daily_digest",    "0 8 * * *"],
      ["morning_standup", "0 9 * * *"]
    ))
    out, = capture_io { new_cli.last_run("1") }
    assert_match "daily_digest", out
    refute_match "morning_standup", out
  end

  def test_last_run_default_n_is_5
    rows = (1..6).map { |i| ["job_#{i}", "0 #{i} * * *"] }
    preset_crontab(multi_job_crontab_block(*rows))
    out, = capture_io { new_cli.last_run }
    assert_match "job_1", out
    refute_match "job_6", out
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  private

  # Builds a CLI wired with real collaborators pointing at the test tmpdir.
  def new_cli
    new_cli_with_manager(new_manager)
  end

  # CLI with a shared manager — lets tests inspect manager state after commands.
  def new_cli_with_manager(mgr)
    Aias::CLI.new.tap do |cli|
      cli.instance_variable_set(:@scanner,   Aias::PromptScanner.new(prompts_dir: @prompts_dir))
      cli.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
      cli.instance_variable_set(:@builder,   Aias::JobBuilder.new(shell: "/bin/bash", aia_path: "/usr/local/bin/aia", env_file: @env_file_path, config_file: Aias::CLI::AIA_SCHEDULE_CFG))
      cli.instance_variable_set(:@manager,   mgr)
      cli.instance_variable_set(:@env_file,  new_env_file)
    end
  end

  # A CLI whose scanner will raise Aias::Error (prompts dir does not exist).
  def new_cli_with_bad_dir
    Aias::CLI.new.tap do |cli|
      cli.instance_variable_set(:@scanner,   Aias::PromptScanner.new(prompts_dir: "/nonexistent_dir_xyz_aias_test"))
      cli.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
      cli.instance_variable_set(:@builder,   Aias::JobBuilder.new(shell: "/bin/bash", aia_path: "/usr/local/bin/aia", env_file: @env_file_path, config_file: Aias::CLI::AIA_SCHEDULE_CFG))
      cli.instance_variable_set(:@manager,   new_manager)
      cli.instance_variable_set(:@env_file,  new_env_file)
    end
  end

  # Fresh CrontabManager pointing at the test's fake crontab script.
  def new_manager
    Aias::CrontabManager.new(crontab_command: @fake_crontab, log_base: @log_base)
  end

  # Fresh EnvFile pointing at the test's temp file.
  def new_env_file
    Aias::EnvFile.new(path: @env_file_path)
  end

  # Writes a prompt file into @prompts_dir and returns its absolute path.
  # schedule: is optional; omitting it produces a file with no YAML frontmatter
  # so that PM.parse does not choke on an empty frontmatter block.
  def write_prompt(filename, schedule: nil, parameters: nil)
    path = File.join(@prompts_dir, filename)
    frontmatter = {}
    frontmatter["schedule"]   = schedule   if schedule
    frontmatter["parameters"] = parameters if parameters

    content =
      if frontmatter.empty?
        "No scheduled prompt.\n"
      else
        yaml_body = frontmatter.to_yaml.sub(/\A---\n/, "")
        "---\n#{yaml_body}---\nContent.\n"
      end

    File.write(path, content)
    path
  end

  # Writes content to the crontab state file (simulates pre-existing crontab).
  def preset_crontab(content)
    File.write(@crontab_state, content)
  end

  # Creates a minimal aias crontab block for a single job.
  def sample_crontab_block(prompt_id, cron_expr)
    log = File.join(@log_base, "#{prompt_id}.log")
    <<~CRON
      # BEGIN aias
      #{cron_expr} /bin/bash -l -c 'aia #{prompt_id} >> #{log} 2>&1'
      # END aias
    CRON
  end

  # Creates a single aias block containing multiple cron lines.
  # Each argument is a [prompt_id, cron_expr] pair.
  def multi_job_crontab_block(*jobs)
    lines = jobs.map do |prompt_id, cron_expr|
      log = File.join(@log_base, "#{prompt_id}.log")
      "#{cron_expr} /bin/bash -l -c 'aia #{prompt_id} >> #{log} 2>&1'"
    end.join("\n")
    <<~CRON
      # BEGIN aias
      #{lines}
      # END aias
    CRON
  end

  # Creates a shell script that simulates the crontab(1) command.
  # Supports: -l (list), - (write from stdin), -r (remove).
  def write_fake_crontab(dir, state_file)
    path = File.join(dir, "fake_crontab")
    File.write(path, <<~BASH)
      #!/bin/bash
      STATE="#{state_file}"
      if [ "$1" = "-l" ]; then
        if [ -f "$STATE" ]; then cat "$STATE"; exit 0; else exit 1; fi
      elif [ "$1" = "-" ]; then
        cat > "$STATE"; exit 0
      elif [ "$1" = "-r" ]; then
        rm -f "$STATE"; exit 0
      else
        exit 1
      fi
    BASH
    File.chmod(0o755, path)
    path
  end

  # Temporarily overrides ENV with the given hash for the duration of the block.
  # Removes *_API_KEY and AIA_* vars from the environment before setting the
  # provided vars, so tests are not affected by the developer's real environment.
  MANAGED_PATTERNS = [
    ->(k) { k.end_with?("_API_KEY") },
    ->(k) { k.start_with?("AIA_") }
  ].freeze

  def with_env(vars)
    old = ENV.to_h
    old.each_key { |k| ENV.delete(k) if MANAGED_PATTERNS.any? { |p| p.call(k) } }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each_key { |k| ENV.delete(k) if MANAGED_PATTERNS.any? { |p| p.call(k) } }
    old.each { |k, v| ENV[k] = v if MANAGED_PATTERNS.any? { |p| p.call(k) } }
  end
end
