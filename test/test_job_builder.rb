# frozen_string_literal: true

require "test_helper"

class TestJobBuilder < Minitest::Test
  LOG_BASE = File.expand_path("~/.aia/schedule/logs")

  # ---------------------------------------------------------------------------
  # log_path_for
  # ---------------------------------------------------------------------------

  def test_log_path_for_simple_prompt_id
    builder = Aias::JobBuilder.new
    assert_equal File.join(LOG_BASE, "daily_digest.log"), builder.log_path_for("daily_digest")
  end

  def test_log_path_for_nested_prompt_id
    builder = Aias::JobBuilder.new
    assert_equal File.join(LOG_BASE, "reports/weekly.log"), builder.log_path_for("reports/weekly")
  end

  def test_log_path_for_deeply_nested_prompt_id
    builder = Aias::JobBuilder.new
    assert_equal File.join(LOG_BASE, "a/b/deep.log"), builder.log_path_for("a/b/deep")
  end

  # ---------------------------------------------------------------------------
  # Shell template
  # ---------------------------------------------------------------------------

  def test_build_uses_env_shell_in_job_template
    builder = Aias::JobBuilder.new(shell: "/bin/zsh")
    dsl = builder.build(build_result)
    assert_match "/bin/zsh -l -c", dsl
  end

  def test_build_uses_bash_when_shell_is_bash
    builder = Aias::JobBuilder.new(shell: "/bin/bash")
    dsl = builder.build(build_result)
    assert_match "/bin/bash -l -c", dsl
  end

  def test_build_falls_back_to_bash_when_shell_nil
    builder = Aias::JobBuilder.new(shell: nil)
    dsl = builder.build(build_result)
    assert_match "/bin/bash -l -c", dsl
  end

  def test_build_falls_back_to_bash_when_shell_empty
    builder = Aias::JobBuilder.new(shell: "")
    dsl = builder.build(build_result)
    assert_match "/bin/bash -l -c", dsl
  end

  def test_build_includes_job_template_line
    builder = Aias::JobBuilder.new(shell: "/bin/zsh")
    dsl = builder.build(build_result)
    assert_match "set :job_template", dsl
  end

  # ---------------------------------------------------------------------------
  # Job type definition
  # ---------------------------------------------------------------------------

  def test_build_defines_aia_job_type
    dsl = Aias::JobBuilder.new.build(build_result)
    assert_match "job_type :aia_job", dsl
  end

  def test_build_aia_job_type_uses_output_placeholder
    dsl = Aias::JobBuilder.new.build(build_result)
    assert_match ":output", dsl
  end

  # ---------------------------------------------------------------------------
  # Prompt ID in command
  # ---------------------------------------------------------------------------

  def test_build_includes_simple_prompt_id
    dsl = Aias::JobBuilder.new.build(build_result(prompt_id: "daily_digest"))
    assert_match 'aia_job "daily_digest"', dsl
  end

  def test_build_includes_nested_prompt_id
    dsl = Aias::JobBuilder.new.build(build_result(prompt_id: "reports/weekly"))
    assert_match 'aia_job "reports/weekly"', dsl
  end

  # ---------------------------------------------------------------------------
  # Log path in output
  # ---------------------------------------------------------------------------

  def test_build_output_includes_log_path
    dsl = Aias::JobBuilder.new.build(build_result(prompt_id: "daily_digest"))
    assert_match File.join(LOG_BASE, "daily_digest.log"), dsl
  end

  def test_build_output_includes_nested_log_path
    dsl = Aias::JobBuilder.new.build(build_result(prompt_id: "reports/weekly"))
    assert_match File.join(LOG_BASE, "reports/weekly.log"), dsl
  end

  # ---------------------------------------------------------------------------
  # Schedule handling — raw cron expressions
  # ---------------------------------------------------------------------------

  def test_build_quotes_raw_cron_expression
    dsl = Aias::JobBuilder.new.build(build_result(schedule: "0 8 * * *"))
    assert_match "every '0 8 * * *'", dsl
  end

  def test_build_quotes_midnight_cron
    dsl = Aias::JobBuilder.new.build(build_result(schedule: "0 0 * * *"))
    assert_match "every '0 0 * * *'", dsl
  end

  def test_build_quotes_cron_keyword
    dsl = Aias::JobBuilder.new.build(build_result(schedule: "@daily"))
    assert_match "every '@daily'", dsl
  end

  # ---------------------------------------------------------------------------
  # Schedule handling — whenever DSL fragments
  # ---------------------------------------------------------------------------

  def test_build_does_not_quote_numeric_day
    dsl = Aias::JobBuilder.new.build(build_result(schedule: "1.day"))
    assert_match "every 1.day", dsl
    refute_match "every '1.day'", dsl
  end

  def test_build_does_not_quote_day_with_at
    dsl = Aias::JobBuilder.new.build(build_result(schedule: "1.day, at: '8:00am'"))
    assert_match "every 1.day, at: '8:00am'", dsl
  end

  def test_build_does_not_quote_hours
    dsl = Aias::JobBuilder.new.build(build_result(schedule: "6.hours"))
    assert_match "every 6.hours", dsl
    refute_match "every '6.hours'", dsl
  end

  def test_build_does_not_quote_weekday_symbol
    dsl = Aias::JobBuilder.new.build(build_result(schedule: ":monday, at: '9:00am'"))
    assert_match "every :monday, at: '9:00am'", dsl
  end

  # ---------------------------------------------------------------------------
  # Output produces valid whenever DSL (integration-style)
  # ---------------------------------------------------------------------------

  def test_build_produces_valid_whenever_dsl_for_cron_schedule
    dsl = Aias::JobBuilder.new(shell: "/bin/bash").build(
      build_result(prompt_id: "daily_digest", schedule: "0 8 * * *")
    )
    output = Whenever.cron(string: dsl)
    assert_match "0 8 * * *", output
    assert_match "aia daily_digest", output
    assert_match ">> #{File.join(LOG_BASE, 'daily_digest.log')} 2>&1", output
  end

  def test_build_produces_valid_whenever_dsl_for_numeric_schedule
    dsl = Aias::JobBuilder.new(shell: "/bin/bash").build(
      build_result(prompt_id: "job", schedule: "1.day, at: '8:00am'")
    )
    output = Whenever.cron(string: dsl)
    assert_match "0 8 * * *", output
    assert_match "aia job", output
  end
end
