# frozen_string_literal: true

require_relative "cli_test_case"

class TestCliCheck < CliTestCase
  def test_reports_ok_when_in_sync
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    capture_io { new_cli.update }  # install so it's in sync
    out, = capture_io { new_cli.check }
    assert_match "OK", out
  end

  def test_reports_new_jobs
    write_prompt("new_job.md", schedule: "0 8 * * *")
    # crontab is empty — new_job is not yet installed
    out, = capture_io { new_cli.check }
    assert_match "NEW", out
    assert_match "new_job", out
  end

  def test_reports_orphaned_jobs
    # No prompt files, but crontab has an aias entry
    preset_crontab(sample_crontab_block("orphaned", "0 8 * * *"))
    out, = capture_io { new_cli.check }
    assert_match "ORPHANED", out
    assert_match "orphaned", out
  end

  def test_reports_invalid_prompts
    write_prompt("bad_job.md", schedule: "every banana")
    out, = capture_io { new_cli.check }
    assert_match "INVALID", out
    assert_match "bad_job", out
  end

  def test_rescues_aias_error
    assert_raises(SystemExit) { capture_io { new_cli_with_bad_dir.check } }
  end
end
