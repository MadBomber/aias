# frozen_string_literal: true

require_relative "cli_test_case"

class TestCliLast < CliTestCase
  def test_prints_no_jobs_when_empty
    out, = capture_io { new_cli.last_run }
    assert_match "no installed jobs", out
  end

  def test_prints_job_schedule_and_last_run
    preset_crontab(sample_crontab_block("daily_digest", "0 8 * * *"))
    out, = capture_io { new_cli.last_run }
    assert_match "daily_digest", out
    assert_match "0 8 * * *", out
    assert_match "last run", out
  end

  def test_shows_never_run_when_log_absent
    preset_crontab(sample_crontab_block("daily_digest", "0 8 * * *"))
    out, = capture_io { new_cli.last_run }
    assert_match "never run", out
  end

  def test_shows_mtime_when_log_exists
    preset_crontab(sample_crontab_block("daily_digest", "0 8 * * *"))
    log_path = File.join(@log_base, "daily_digest.log")
    FileUtils.mkdir_p(File.dirname(log_path))
    File.write(log_path, "output\n")
    out, = capture_io { new_cli.last_run }
    refute_match "never run", out
  end

  def test_limits_output_to_n_jobs
    preset_crontab(multi_job_crontab_block(
      ["daily_digest",    "0 8 * * *"],
      ["morning_standup", "0 9 * * *"]
    ))
    out, = capture_io { new_cli.last_run("1") }
    assert_match "daily_digest", out
    refute_match "morning_standup", out
  end

  def test_default_n_is_5
    rows = (1..6).map { |i| ["job_#{i}", "0 #{i} * * *"] }
    preset_crontab(multi_job_crontab_block(*rows))
    out, = capture_io { new_cli.last_run }
    assert_match "job_1", out
    refute_match "job_6", out
  end
end
