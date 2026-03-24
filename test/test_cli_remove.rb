# frozen_string_literal: true

require_relative "cli_test_case"

class TestCliRemove < CliTestCase
  def test_prints_success_message
    path = write_prompt("standup.md", schedule: "0 9 * * 1-5")
    mgr  = new_manager
    capture_io { new_cli_with_manager(mgr).add(path) }
    out, = capture_io { new_cli_with_manager(mgr).remove("standup") }
    assert_match "removed", out
    assert_match "standup", out
  end

  def test_uninstalls_the_job_from_crontab
    path = write_prompt("standup.md", schedule: "0 9 * * 1-5")
    mgr  = new_manager
    capture_io { new_cli_with_manager(mgr).add(path) }
    capture_io { new_cli_with_manager(mgr).remove("standup") }
    assert_empty mgr.installed_jobs
  end

  def test_leaves_other_jobs_intact
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

  def test_exits_when_prompt_id_not_installed
    assert_raises(SystemExit) { capture_io { new_cli.remove("nonexistent") } }
  end

  def test_prints_error_when_prompt_id_not_installed
    _, err = capture_io do
      assert_raises(SystemExit) { new_cli.remove("nonexistent") }
    end
    assert_match "error", err
    assert_match "nonexistent", err
  end
end
