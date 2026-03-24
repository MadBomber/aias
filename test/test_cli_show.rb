# frozen_string_literal: true

require_relative "cli_test_case"

class TestCliShow < CliTestCase
  def test_prints_job_details_when_found
    preset_crontab(sample_crontab_block("daily_digest", "0 8 * * *"))
    out, = capture_io { new_cli.show("daily_digest") }
    assert_match "daily_digest", out
    assert_match "0 8 * * *", out
  end

  def test_exits_when_not_found
    assert_raises(SystemExit) { capture_io { new_cli.show("nonexistent") } }
  end

  def test_prints_not_installed_message
    out, = capture_io do
      assert_raises(SystemExit) { new_cli.show("nonexistent") }
    end
    assert_match "not currently installed", out
  end
end
