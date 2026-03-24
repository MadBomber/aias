# frozen_string_literal: true

require_relative "cli_test_case"

class TestCliDryRun < CliTestCase
  def test_does_not_write_crontab
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    capture_io { new_cli.dry_run }
    refute File.exist?(@crontab_state), "dry_run must not modify the crontab"
  end

  def test_prints_cron_output
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    out, = capture_io { new_cli.dry_run }
    assert_match "0 8 * * *", out
  end

  def test_prints_no_prompts_when_none_valid
    out, = capture_io { new_cli.dry_run }
    assert_match "no valid", out
  end
end
