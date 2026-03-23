# frozen_string_literal: true

require "test_helper"

class TestJobBuilder < Minitest::Test
  LOG_BASE = File.expand_path("~/.aia/schedule/logs")

  # ---------------------------------------------------------------------------
  # log_path_for
  # ---------------------------------------------------------------------------

  def test_log_path_for_simple_prompt_id
    assert_equal File.join(LOG_BASE, "daily_digest.log"), builder.log_path_for("daily_digest")
  end

  def test_log_path_for_nested_prompt_id
    assert_equal File.join(LOG_BASE, "reports/weekly.log"), builder.log_path_for("reports/weekly")
  end

  def test_log_path_for_deeply_nested_prompt_id
    assert_equal File.join(LOG_BASE, "a/b/deep.log"), builder.log_path_for("a/b/deep")
  end

  # ---------------------------------------------------------------------------
  # build — output is a single cron line string
  # ---------------------------------------------------------------------------

  def test_build_returns_a_string
    assert_kind_of String, builder.build(build_result)
  end

  def test_build_returns_a_single_line
    line = builder.build(build_result)
    assert_equal 1, line.lines.size, "build must return exactly one line"
  end

  # ---------------------------------------------------------------------------
  # Shell
  # ---------------------------------------------------------------------------

  def test_build_uses_given_shell
    line = Aias::JobBuilder.new(shell: "/bin/zsh").build(build_result)
    assert_match "/bin/zsh -l -c", line
  end

  def test_build_falls_back_to_bash_when_shell_nil
    line = Aias::JobBuilder.new(shell: nil).build(build_result)
    assert_match "/bin/bash -l -c", line
  end

  def test_build_falls_back_to_bash_when_shell_empty
    line = Aias::JobBuilder.new(shell: "").build(build_result)
    assert_match "/bin/bash -l -c", line
  end

  # ---------------------------------------------------------------------------
  # Prompt ID
  # ---------------------------------------------------------------------------

  def test_build_includes_simple_prompt_id
    line = builder.build(build_result(prompt_id: "daily_digest"))
    assert_match "aia daily_digest", line
  end

  def test_build_includes_nested_prompt_id
    line = builder.build(build_result(prompt_id: "reports/weekly"))
    assert_match "aia reports/weekly", line
  end

  # ---------------------------------------------------------------------------
  # Log path
  # ---------------------------------------------------------------------------

  def test_build_includes_log_path
    line = builder.build(build_result(prompt_id: "daily_digest"))
    assert_match File.join(LOG_BASE, "daily_digest.log"), line
  end

  def test_build_includes_nested_log_path
    line = builder.build(build_result(prompt_id: "reports/weekly"))
    assert_match File.join(LOG_BASE, "reports/weekly.log"), line
  end

  def test_build_redirects_stdout_and_stderr_to_log
    line = builder.build(build_result(prompt_id: "daily_digest"))
    assert_match ">> #{File.join(LOG_BASE, 'daily_digest.log')} 2>&1", line
  end

  # ---------------------------------------------------------------------------
  # Schedule — fugit resolves to canonical cron expression
  # ---------------------------------------------------------------------------

  def test_build_resolves_raw_cron_expression
    line = builder.build(build_result(schedule: "0 8 * * *"))
    assert_match "0 8 * * *", line
  end

  def test_build_resolves_at_daily
    line = builder.build(build_result(schedule: "@daily"))
    assert_match "0 0 * * *", line
  end

  def test_build_resolves_natural_language_daily
    line = builder.build(build_result(schedule: "every day at 8am"))
    assert_match "0 8 * * *", line
  end

  def test_build_resolves_natural_language_weekday
    line = builder.build(build_result(schedule: "every weekday at 8am"))
    assert_match "0 8 * * 1,2,3,4,5", line
  end

  def test_build_resolves_natural_language_monday
    line = builder.build(build_result(schedule: "every monday at 9am"))
    assert_match "0 9 * * 1", line
  end

  def test_build_cron_expr_is_first_field_on_the_line
    line = builder.build(build_result(schedule: "0 8 * * *"))
    assert line.start_with?("0 8 * * *"), "cron expression must be at the start of the line"
  end

  # ---------------------------------------------------------------------------
  # --prompts-dir passthrough
  # ---------------------------------------------------------------------------

  def test_build_without_prompts_dir_omits_flag
    line = builder.build(build_result)
    refute_match "--prompts-dir", line
  end

  def test_build_with_prompts_dir_includes_flag
    line = Aias::JobBuilder.new(prompts_dir: "/tmp/my_prompts").build(build_result)
    assert_match "--prompts-dir /tmp/my_prompts", line
  end

  def test_build_with_prompts_dir_flag_appears_before_prompt_id
    line = Aias::JobBuilder.new(prompts_dir: "/tmp/my_prompts").build(build_result(prompt_id: "daily_digest"))
    assert line.index("--prompts-dir") < line.index("daily_digest"),
      "--prompts-dir must appear before the prompt_id in the command"
  end

  def test_build_with_nil_prompts_dir_omits_flag
    line = Aias::JobBuilder.new(prompts_dir: nil).build(build_result)
    refute_match "--prompts-dir", line
  end

  def test_build_with_empty_prompts_dir_omits_flag
    line = Aias::JobBuilder.new(prompts_dir: "").build(build_result)
    refute_match "--prompts-dir", line
  end

  def test_build_expands_relative_prompts_dir_to_absolute_path
    line = Aias::JobBuilder.new(prompts_dir: "relative/path").build(build_result)
    assert_match "--prompts-dir #{File.expand_path('relative/path')}", line
  end

  def test_build_prompts_dir_path_is_always_absolute
    line = Aias::JobBuilder.new(prompts_dir: "some/relative/dir").build(build_result)
    flag_value = line.match(/--prompts-dir (\S+)/)[1]
    assert flag_value.start_with?("/"),
      "Path in --prompts-dir flag must be absolute, got: #{flag_value}"
  end

  def test_build_with_prompts_dir_includes_prompt_id_in_command
    line = Aias::JobBuilder.new(prompts_dir: "/tmp/my_prompts").build(
      build_result(prompt_id: "daily_digest", schedule: "0 8 * * *")
    )
    assert_match "aia --prompts-dir /tmp/my_prompts daily_digest", line
  end

  private

  def builder
    @builder ||= Aias::JobBuilder.new(shell: "/bin/bash")
  end
end
