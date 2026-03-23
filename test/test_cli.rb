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
    cli.instance_variable_set(:@builder,  Aias::JobBuilder.new(shell: "/bin/bash"))
    cli.instance_variable_set(:@manager,  new_manager)
    out, = capture_io { cli.update }
    assert_match "no valid scheduled prompts", out
  ensure
    FileUtils.remove_entry(other_dir)
  end

  def test_prompts_dir_option_is_passed_to_generated_aia_command
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    mgr = new_manager
    cli = Aias::CLI.new([], { prompts_dir: @prompts_dir })
    cli.instance_variable_set(:@scanner,  Aias::PromptScanner.new(prompts_dir: @prompts_dir))
    cli.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
    cli.instance_variable_set(:@builder,  Aias::JobBuilder.new(shell: "/bin/bash", prompts_dir: @prompts_dir))
    cli.instance_variable_set(:@manager,  mgr)
    capture_io { cli.update }
    assert_match "--prompts-dir #{@prompts_dir}", mgr.current_block,
      "Generated crontab entry must include --prompts-dir when the option was given"
  end

  def test_no_prompts_dir_option_omits_flag_from_generated_aia_command
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    mgr = new_manager
    # new_cli injects a builder with no prompts_dir
    cli = Aias::CLI.new.tap do |c|
      c.instance_variable_set(:@scanner,  Aias::PromptScanner.new(prompts_dir: @prompts_dir))
      c.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
      c.instance_variable_set(:@builder,  Aias::JobBuilder.new(shell: "/bin/bash"))
      c.instance_variable_set(:@manager,  mgr)
    end
    capture_io { cli.update }
    refute_match "--prompts-dir", mgr.current_block
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
  # upcoming (next)
  # ---------------------------------------------------------------------------

  def test_upcoming_prints_no_jobs_when_empty
    out, = capture_io { new_cli.upcoming }
    assert_match "no installed jobs", out
  end

  def test_upcoming_prints_job_schedule
    preset_crontab(sample_crontab_block("daily_digest", "0 8 * * *"))
    out, = capture_io { new_cli.upcoming }
    assert_match "daily_digest", out
    assert_match "0 8 * * *", out
  end

  def test_upcoming_limits_output_to_n_jobs
    # Single block with two cron lines; ask for only 1.
    preset_crontab(multi_job_crontab_block(
      ["daily_digest",    "0 8 * * *"],
      ["morning_standup", "0 9 * * 1-5"]
    ))
    out, = capture_io { new_cli.upcoming("1") }
    assert_match "daily_digest", out
    refute_match "morning_standup", out
  end

  def test_upcoming_default_n_is_5
    # Single block with 6 cron lines; default of 5 should omit the 6th.
    rows = (1..6).map { |i| ["job_#{i}", "0 #{i} * * *"] }
    preset_crontab(multi_job_crontab_block(*rows))
    out, = capture_io { new_cli.upcoming }
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
      cli.instance_variable_set(:@builder,   Aias::JobBuilder.new(shell: "/bin/bash"))
      cli.instance_variable_set(:@manager,   mgr)
    end
  end

  # A CLI whose scanner will raise Aias::Error (prompts dir does not exist).
  def new_cli_with_bad_dir
    Aias::CLI.new.tap do |cli|
      cli.instance_variable_set(:@scanner,   Aias::PromptScanner.new(prompts_dir: "/nonexistent_dir_xyz_aias_test"))
      cli.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
      cli.instance_variable_set(:@builder,   Aias::JobBuilder.new(shell: "/bin/bash"))
      cli.instance_variable_set(:@manager,   new_manager)
    end
  end

  # Fresh CrontabManager pointing at the test's fake crontab script.
  def new_manager
    Aias::CrontabManager.new(crontab_command: @fake_crontab, log_base: @log_base)
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
end
