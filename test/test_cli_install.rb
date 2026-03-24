# frozen_string_literal: true

require_relative "cli_test_case"

class TestCliInstall < CliTestCase
  def test_writes_api_keys_to_env_file
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env("ANTHROPIC_API_KEY" => "sk-ant-test", "OPENAI_API_KEY" => "sk-open-test") do
      capture_io { cli.install }
    end
    block = ef.current_block
    assert_match 'export ANTHROPIC_API_KEY="sk-ant-test"', block
    assert_match 'export OPENAI_API_KEY="sk-open-test"', block
  end

  def test_writes_path_to_env_file
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env({}) { capture_io { cli.install } }
    assert_match "export PATH=", ef.current_block
  end

  def test_prints_installed_var_names
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    out, = with_env("ANTHROPIC_API_KEY" => "sk-ant-test") do
      capture_io { cli.install }
    end
    assert_match "ANTHROPIC_API_KEY", out
    assert_match "PATH", out
  end

  def test_with_pattern_adds_matching_vars
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env("AIA_MODEL" => "claude-haiku-4-5", "AIA_BACKEND" => "anthropic") do
      capture_io { cli.install("AIA_*") }
    end
    block = ef.current_block
    assert_match 'export AIA_MODEL="claude-haiku-4-5"', block
    assert_match 'export AIA_BACKEND="anthropic"', block
  end

  def test_with_multiple_patterns
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env("AIA_MODEL" => "claude-haiku-4-5", "ANTHROPIC_API_KEY" => "sk-ant-test") do
      capture_io { cli.install("AIA_*") }
    end
    block = ef.current_block
    assert_match 'export AIA_MODEL="claude-haiku-4-5"', block
    assert_match 'export ANTHROPIC_API_KEY="sk-ant-test"', block
  end

  def test_with_space_separated_patterns_in_single_arg
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env("AIA_MODEL" => "claude-haiku-4-5", "OPENAI_API_KEY" => "sk-open-test") do
      capture_io { cli.install("AIA_* OPENAI_*") }
    end
    block = ef.current_block
    assert_match 'export AIA_MODEL="claude-haiku-4-5"', block
    assert_match 'export OPENAI_API_KEY="sk-open-test"', block
  end

  def test_pattern_is_case_insensitive
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env("AIA_MODEL" => "claude-haiku-4-5") do
      capture_io { cli.install("aia_*") }
    end
    assert_match 'export AIA_MODEL="claude-haiku-4-5"', ef.current_block
  end

  def test_pattern_does_not_add_non_matching_vars
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env("AIA_MODEL" => "claude-haiku-4-5", "UNRELATED_VAR" => "nope") do
      capture_io { cli.install("AIA_*") }
    end
    refute_match "UNRELATED_VAR", ef.current_block
  end

  def test_uninstall_removes_api_keys_from_env_file
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    with_env("ANTHROPIC_API_KEY" => "sk-ant-test") { capture_io { cli.install } }
    capture_io { cli.uninstall }
    assert_empty ef.current_block
  end

  def test_uninstall_prints_confirmation
    ef = new_env_file
    cli = new_cli
    cli.instance_variable_set(:@env_file, ef)
    out, = capture_io { cli.uninstall }
    assert_match "removed", out
  end
end
