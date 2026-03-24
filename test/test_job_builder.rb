# frozen_string_literal: true

require "test_helper"

class TestJobBuilder < Minitest::Test
  LOG_BASE  = File.expand_path("~/.config/aia/schedule/logs")
  AIA_PATH  = "/usr/local/bin/aia"
  ENV_FILE  = "/fake/aias/env.sh"
  CFG_FILE  = "/fake/aias/schedule/aia.yml"

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
    line = Aias::JobBuilder.new(shell: "/bin/zsh", aia_path: AIA_PATH, env_file: ENV_FILE, config_file: CFG_FILE).build(build_result)
    assert_match "/bin/zsh -c", line
  end

  def test_build_does_not_use_login_shell_flag
    line = builder.build(build_result)
    refute_match "-l -c", line
    assert_match "-c '", line
  end

  def test_build_falls_back_to_bash_when_shell_nil
    line = Aias::JobBuilder.new(shell: nil, aia_path: AIA_PATH, env_file: ENV_FILE, config_file: CFG_FILE).build(build_result)
    assert_match "/bin/bash -c", line
  end

  def test_build_falls_back_to_bash_when_shell_empty
    line = Aias::JobBuilder.new(shell: "", aia_path: AIA_PATH, env_file: ENV_FILE, config_file: CFG_FILE).build(build_result)
    assert_match "/bin/bash -c", line
  end

  # ---------------------------------------------------------------------------
  # env.sh — sourced before the aia command
  # ---------------------------------------------------------------------------

  def test_build_sources_env_file
    line = builder.build(build_result)
    assert_match "source #{ENV_FILE} &&", line
  end

  def test_build_env_file_appears_before_aia_binary
    line = builder.build(build_result)
    assert line.index("source #{ENV_FILE}") < line.index(AIA_PATH),
      "source env.sh must appear before the aia binary"
  end

  # ---------------------------------------------------------------------------
  # aia binary — full path resolved at build time so cron doesn't need PATH
  # ---------------------------------------------------------------------------

  def test_build_uses_injected_aia_path
    line = Aias::JobBuilder.new(aia_path: "/home/user/.rbenv/shims/aia", env_file: ENV_FILE, config_file: CFG_FILE).build(build_result)
    assert_match "/home/user/.rbenv/shims/aia", line
  end

  def test_build_command_includes_aia_path
    line = builder.build(build_result)
    assert_match AIA_PATH, line
  end

  # ---------------------------------------------------------------------------
  # --config-file — schedule-specific AIA config
  # ---------------------------------------------------------------------------

  def test_build_includes_config_flag
    line = builder.build(build_result)
    assert_match "--config #{CFG_FILE}", line
  end

  def test_build_config_flag_appears_before_prompt_id
    line = builder.build(build_result(prompt_id: "daily_digest"))
    assert line.index("--config #{CFG_FILE}") < line.index("daily_digest"),
      "--config must appear before the prompt ID"
  end

  def test_build_without_config_file_omits_flag
    line = Aias::JobBuilder.new(shell: "/bin/bash", aia_path: AIA_PATH, env_file: ENV_FILE).build(build_result)
    refute_match "--config ", line
  end

  # ---------------------------------------------------------------------------
  # Prompt ID
  # ---------------------------------------------------------------------------

  def test_build_includes_simple_prompt_id
    line = builder.build(build_result(prompt_id: "daily_digest"))
    assert_match(/aia.*daily_digest/, line)
  end

  def test_build_includes_nested_prompt_id
    line = builder.build(build_result(prompt_id: "reports/weekly"))
    assert_match(/aia.*reports\/weekly/, line)
  end

  # ---------------------------------------------------------------------------
  # --prompts-dir — flag before prompt_id so aia finds prompts at runtime
  # ---------------------------------------------------------------------------

  def test_build_with_prompts_dir_includes_flag
    line = builder.build(build_result, prompts_dir: "/tmp/my_prompts")
    assert_match "--prompts-dir /tmp/my_prompts", line
  end

  def test_build_with_prompts_dir_flag_appears_before_prompt_id
    line = builder.build(build_result(prompt_id: "daily_digest"), prompts_dir: "/tmp/my_prompts")
    assert line.index("--prompts-dir") < line.index("daily_digest"),
      "--prompts-dir must appear before the prompt ID"
  end

  def test_build_without_prompts_dir_omits_flag
    line = builder.build(build_result)
    refute_match "--prompts-dir", line
  end

  def test_build_with_nil_prompts_dir_omits_flag
    line = builder.build(build_result, prompts_dir: nil)
    refute_match "--prompts-dir", line
  end

  def test_build_expands_relative_prompts_dir_to_absolute_path
    line = builder.build(build_result, prompts_dir: "relative/path")
    assert_match "--prompts-dir #{File.expand_path('relative/path')}", line
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
    assert_match "> #{File.join(LOG_BASE, 'daily_digest.log')} 2>&1", line
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

  private

  def builder
    @builder ||= Aias::JobBuilder.new(shell: "/bin/bash", aia_path: AIA_PATH, env_file: ENV_FILE, config_file: CFG_FILE)
  end
end
