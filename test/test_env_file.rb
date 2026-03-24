# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TestEnvFile < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("aias_env_file_test_")
    @path   = File.join(@tmpdir, "env.sh")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  # ---------------------------------------------------------------------------
  # install — writes managed block with export format
  # ---------------------------------------------------------------------------

  def test_install_creates_file
    ef.install("ANTHROPIC_API_KEY" => "sk-ant-test")
    assert File.exist?(@path)
  end

  def test_install_writes_export_format
    ef.install("ANTHROPIC_API_KEY" => "sk-ant-test")
    assert_match 'export ANTHROPIC_API_KEY="sk-ant-test"', File.read(@path)
  end

  def test_install_writes_multiple_keys
    ef.install("ANTHROPIC_API_KEY" => "sk-ant-test", "OPENAI_API_KEY" => "sk-open-test")
    content = File.read(@path)
    assert_match 'export ANTHROPIC_API_KEY="sk-ant-test"', content
    assert_match 'export OPENAI_API_KEY="sk-open-test"', content
  end

  def test_install_merges_with_existing_block
    ef.install("ANTHROPIC_API_KEY" => "sk-ant-test")
    ef.install("OPENAI_API_KEY" => "sk-open-test")
    content = ef.current_block
    assert_match 'export ANTHROPIC_API_KEY="sk-ant-test"', content
    assert_match 'export OPENAI_API_KEY="sk-open-test"', content
  end

  def test_install_new_value_wins_on_conflict
    ef.install("ANTHROPIC_API_KEY" => "old")
    ef.install("ANTHROPIC_API_KEY" => "new")
    content = ef.current_block
    assert_match 'export ANTHROPIC_API_KEY="new"', content
    refute_match 'export ANTHROPIC_API_KEY="old"', content
  end

  def test_install_sets_permissions_to_0600
    ef.install("ANTHROPIC_API_KEY" => "sk-ant-test")
    mode = File.stat(@path).mode & 0o777
    assert_equal 0o600, mode, "env.sh must be chmod 0600 to protect API keys"
  end

  def test_install_preserves_content_outside_block
    File.write(@path, "# My custom settings\nexport FOO=bar\n")
    ef.install("ANTHROPIC_API_KEY" => "sk-ant-test")
    content = File.read(@path)
    assert_match "My custom settings", content
    assert_match "export FOO=bar", content
  end

  def test_install_writes_begin_and_end_markers
    ef.install("ANTHROPIC_API_KEY" => "sk-ant-test")
    content = File.read(@path)
    assert_match "# BEGIN aias-env", content
    assert_match "# END aias-env", content
  end

  # ---------------------------------------------------------------------------
  # current_block
  # ---------------------------------------------------------------------------

  def test_current_block_returns_empty_when_file_absent
    assert_equal "", ef.current_block
  end

  def test_current_block_returns_empty_when_no_managed_block
    File.write(@path, "export FOO=bar\n")
    assert_equal "", ef.current_block
  end

  def test_current_block_returns_managed_content_without_markers
    ef.install("ANTHROPIC_API_KEY" => "sk-ant-test")
    block = ef.current_block
    assert_match "ANTHROPIC_API_KEY", block
    refute_match "BEGIN aias-env", block
    refute_match "END aias-env", block
  end

  # ---------------------------------------------------------------------------
  # uninstall — removes managed block
  # ---------------------------------------------------------------------------

  def test_uninstall_removes_managed_block
    ef.install("ANTHROPIC_API_KEY" => "sk-ant-test")
    ef.uninstall
    assert_empty ef.current_block
  end

  def test_uninstall_deletes_file_when_only_managed_content
    ef.install("ANTHROPIC_API_KEY" => "sk-ant-test")
    ef.uninstall
    refute File.exist?(@path), "file should be deleted when only managed content remains"
  end

  def test_uninstall_preserves_file_when_user_content_exists
    File.write(@path, "# My custom settings\nexport FOO=bar\n")
    ef.install("ANTHROPIC_API_KEY" => "sk-ant-test")
    ef.uninstall
    assert File.exist?(@path)
    assert_match "My custom settings", File.read(@path)
  end

  def test_uninstall_when_no_block_is_a_no_op
    ef.uninstall  # should not raise
    refute File.exist?(@path)
  end

  private

  def ef
    @ef ||= Aias::EnvFile.new(path: @path)
  end
end
