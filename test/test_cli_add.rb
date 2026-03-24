# frozen_string_literal: true

require_relative "cli_test_case"

class TestCliAdd < CliTestCase
  def test_prints_success_message
    path = write_prompt("standup.md", schedule: "0 9 * * 1-5")
    out, = capture_io { new_cli.add(path) }
    assert_match "standup", out
  end

  def test_installs_the_job_in_crontab
    path = write_prompt("standup.md", schedule: "0 9 * * 1-5")
    mgr  = new_manager
    cli  = new_cli_with_manager(mgr)
    capture_io { cli.add(path) }
    ids = mgr.installed_jobs.map { |j| j[:prompt_id] }
    assert_includes ids, "standup"
  end

  def test_does_not_remove_other_installed_jobs
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    mgr = new_manager
    capture_io { new_cli_with_manager(mgr).update }   # install daily_digest first
    standup_path = write_prompt("standup.md", schedule: "0 9 * * 1-5")
    capture_io { new_cli_with_manager(mgr).add(standup_path) }
    ids = mgr.installed_jobs.map { |j| j[:prompt_id] }
    assert_includes ids, "daily_digest"
    assert_includes ids, "standup"
  end

  def test_replaces_existing_entry_for_same_prompt
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

  def test_exits_when_prompt_has_no_schedule
    path = write_prompt("no_schedule.md")
    assert_raises(SystemExit) { capture_io { new_cli.add(path) } }
  end

  def test_prints_error_when_prompt_has_no_schedule
    path = write_prompt("no_schedule.md")
    _, err = capture_io do
      assert_raises(SystemExit) { new_cli.add(path) }
    end
    assert_match "error", err
    assert_match "no schedule:", err
  end

  def test_exits_when_schedule_is_invalid
    path = write_prompt("bad.md", schedule: "every banana")
    assert_raises(SystemExit) { capture_io { new_cli.add(path) } }
  end

  def test_prints_error_when_schedule_is_invalid
    path = write_prompt("bad.md", schedule: "every banana")
    _, err = capture_io do
      assert_raises(SystemExit) { new_cli.add(path) }
    end
    assert_match "error", err
  end

  def test_exits_when_file_does_not_exist
    assert_raises(SystemExit) do
      capture_io { new_cli.add(File.join(@prompts_dir, "ghost.md")) }
    end
  end

  def test_success_message_includes_human_readable_schedule
    path = write_prompt("standup.md", schedule: "0 9 * * 1-5")
    out, = capture_io { new_cli.add(path) }
    # CronDescriber.display("0 9 * * 1-5") => "every weekday at 9am (0 9 * * 1-5)"
    assert_match "weekday", out
  end
end
