# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "yaml"

class TestScheduleConfig < Minitest::Test
  def setup
    @dir  = Dir.mktmpdir("aias_schedule_config_test_")
    @path = File.join(@dir, "aia.yml")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def new_config
    Aias::ScheduleConfig.new(path: @path)
  end

  # ---------------------------------------------------------------------------
  # set_prompts_dir — file absent
  # ---------------------------------------------------------------------------

  def test_returns_false_when_config_file_does_not_exist
    refute new_config.set_prompts_dir("/my/prompts")
  end

  def test_does_not_create_file_when_absent
    new_config.set_prompts_dir("/my/prompts")
    refute File.exist?(@path)
  end

  # ---------------------------------------------------------------------------
  # set_prompts_dir — first write
  # ---------------------------------------------------------------------------

  def test_returns_true_when_value_is_written
    File.write(@path, {}.to_yaml)
    assert new_config.set_prompts_dir("/my/prompts")
  end

  def test_writes_prompts_dir_key
    File.write(@path, {}.to_yaml)
    new_config.set_prompts_dir("/my/prompts")
    config = YAML.safe_load_file(@path)
    assert_equal "/my/prompts", config.dig("prompts", "dir")
  end

  def test_preserves_existing_keys
    File.write(@path, { "model" => "gpt-4" }.to_yaml)
    new_config.set_prompts_dir("/my/prompts")
    config = YAML.safe_load_file(@path)
    assert_equal "gpt-4", config["model"]
  end

  # ---------------------------------------------------------------------------
  # set_prompts_dir — already set
  # ---------------------------------------------------------------------------

  def test_returns_false_when_dir_already_correct
    File.write(@path, { "prompts" => { "dir" => "/my/prompts" } }.to_yaml)
    refute new_config.set_prompts_dir("/my/prompts")
  end

  def test_does_not_rewrite_file_when_dir_already_correct
    File.write(@path, { "prompts" => { "dir" => "/my/prompts" } }.to_yaml)
    mtime_before = File.mtime(@path)
    sleep 0.01
    new_config.set_prompts_dir("/my/prompts")
    assert_equal mtime_before, File.mtime(@path)
  end

  def test_returns_true_when_dir_changes
    File.write(@path, { "prompts" => { "dir" => "/old/prompts" } }.to_yaml)
    assert new_config.set_prompts_dir("/new/prompts")
  end

  def test_updates_value_when_dir_changes
    File.write(@path, { "prompts" => { "dir" => "/old/prompts" } }.to_yaml)
    new_config.set_prompts_dir("/new/prompts")
    config = YAML.safe_load_file(@path)
    assert_equal "/new/prompts", config.dig("prompts", "dir")
  end

  # ---------------------------------------------------------------------------
  # set_prompts_dir — invalid YAML
  # ---------------------------------------------------------------------------

  def test_raises_on_invalid_yaml
    File.write(@path, "---\n: bad: yaml:\n  -\n")
    assert_raises(Aias::Error) { new_config.set_prompts_dir("/my/prompts") }
  end
end
