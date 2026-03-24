# frozen_string_literal: true

require_relative "cli_test_case"

class TestCliUpdate < CliTestCase
  def test_with_no_valid_prompts_prints_no_jobs_message
    out, = capture_io { new_cli.update }
    assert_match "no valid scheduled prompts", out
  end

  def test_installs_crontab_for_valid_prompt
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    capture_io { new_cli.update }
    assert File.exist?(@crontab_state), "update should write to the crontab"
    assert_equal 1, new_manager.installed_jobs.size
  end

  def test_does_not_install_when_all_invalid
    write_prompt("bad.md", schedule: "every banana")
    capture_io { new_cli.update }
    refute File.exist?(@crontab_state), "crontab must not be written when all prompts are invalid"
  end

  def test_warns_for_invalid_prompts
    write_prompt("bad.md", schedule: "every banana")
    _, err = capture_io { new_cli.update }
    assert_match "skip", err
    assert_match "bad", err
  end

  def test_prints_installed_count
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    out, = capture_io { new_cli.update }
    assert_match "1 job", out
  end

  def test_prints_skipped_count_when_mix_of_valid_and_invalid
    write_prompt("good.md",  schedule: "0 8 * * *")
    write_prompt("bad.md",   schedule: "every banana")
    out, = capture_io { new_cli.update }
    assert_match "skipped 1 invalid", out
  end

  def test_rescues_aias_error
    assert_raises(SystemExit) do
      capture_io { new_cli_with_bad_dir.update }
    end
  end

  def test_prompts_dir_option_overrides_env_var
    other_dir = Dir.mktmpdir("aias_cli_other_")
    write_prompt("daily_digest.md", schedule: "0 8 * * *")  # in @prompts_dir
    # CLI pointed at other_dir (empty) — should find no prompts
    cli = Aias::CLI.new([], { prompts_dir: other_dir })
    cli.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
    cli.instance_variable_set(:@builder,  Aias::JobBuilder.new(shell: "/bin/bash", aia_path: "/usr/local/bin/aia"))
    cli.instance_variable_set(:@manager,  new_manager)
    out, = capture_io { cli.update }
    assert_match "no valid scheduled prompts", out
  ensure
    FileUtils.remove_entry(other_dir)
  end

  def test_generated_aia_command_includes_prompts_dir_flag
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    mgr = new_manager
    cli = Aias::CLI.new([], { prompts_dir: @prompts_dir })
    cli.instance_variable_set(:@scanner,  Aias::PromptScanner.new(prompts_dir: @prompts_dir))
    cli.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
    cli.instance_variable_set(:@builder,  Aias::JobBuilder.new(shell: "/bin/bash", aia_path: "/usr/local/bin/aia", env_file: @env_file_path))
    cli.instance_variable_set(:@manager,  mgr)
    capture_io { cli.update }
    assert_match %(--prompts-dir "#{File.expand_path(@prompts_dir)}"), mgr.current_block,
      "Generated crontab entry must include --prompts-dir flag"
    refute_match "--config", mgr.current_block
  end

  def test_generated_aia_command_has_no_inline_env_vars
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    mgr = new_manager
    cli = Aias::CLI.new.tap do |c|
      c.instance_variable_set(:@scanner,  Aias::PromptScanner.new(prompts_dir: @prompts_dir))
      c.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
      c.instance_variable_set(:@builder,  Aias::JobBuilder.new(shell: "/bin/bash", aia_path: "/usr/local/bin/aia"))
      c.instance_variable_set(:@manager,  mgr)
    end
    capture_io { cli.update }
    refute_match "AIA_MODEL=", mgr.current_block
    refute_match "ANTHROPIC_API_KEY=", mgr.current_block
  end
end
