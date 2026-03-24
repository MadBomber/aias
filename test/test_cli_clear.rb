# frozen_string_literal: true

require_relative "cli_test_case"

class TestCliClear < CliTestCase
  def test_removes_installed_crontab_entries
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    capture_io { new_cli.update }  # install first
    refute_empty new_manager.installed_jobs  # verify pre-condition
    capture_io { new_cli.clear }
    assert_empty new_manager.installed_jobs
  end

  def test_prints_confirmation
    out, = capture_io { new_cli.clear }
    assert_match "removed", out
  end
end
