# frozen_string_literal: true

require_relative "cli_test_case"

class TestCliList < CliTestCase
  def test_prints_no_jobs_when_empty
    out, = capture_io { new_cli.list }
    assert_match "no installed jobs", out
  end

  def test_prints_table_headers
    preset_crontab(sample_crontab_block("daily_digest", "0 8 * * *"))
    out, = capture_io { new_cli.list }
    assert_match "PROMPT ID", out
    assert_match "SCHEDULE", out
  end

  def test_prints_job_details
    preset_crontab(sample_crontab_block("daily_digest", "0 8 * * *"))
    out, = capture_io { new_cli.list }
    assert_match "daily_digest", out
    assert_match "0 8 * * *", out
    assert_match "daily_digest.log", out
  end
end
