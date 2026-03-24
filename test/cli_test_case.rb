# frozen_string_literal: true

require "test_helper"
require "tmpdir"

# Shared base class for CLI command tests.
# Provides per-test tmpdir isolation and helper methods for wiring CLI
# collaborators, writing prompt files, and simulating crontab state.
#
# CLI tests wire real collaborators. Test isolation comes from:
#   - a per-test tmpdir that holds prompt files, the fake crontab state,
#     and log directories
#   - Validator(binary_to_check: "ruby") so the binary check always passes
#     without requiring aia to be installed in the test environment
class CliTestCase < Minitest::Test
  def setup
    @prompts_dir   = Dir.mktmpdir("aias_cli_test_")
    @log_base      = File.join(@prompts_dir, "logs")
    @crontab_state = File.join(@prompts_dir, "crontab_state")
    @fake_crontab  = write_fake_crontab(@prompts_dir, @crontab_state)
    @env_file_path = File.join(@prompts_dir, "env.sh")
  end

  def teardown
    FileUtils.remove_entry(@prompts_dir)
  end

  private

  # Builds a CLI wired with real collaborators pointing at the test tmpdir.
  def new_cli
    new_cli_with_manager(new_manager)
  end

  # CLI with a shared manager — lets tests inspect manager state after commands.
  def new_cli_with_manager(mgr)
    Aias::CLI.new.tap do |cli|
      cli.instance_variable_set(:@scanner,   Aias::PromptScanner.new(prompts_dir: @prompts_dir))
      cli.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
      cli.instance_variable_set(:@builder,   Aias::JobBuilder.new(shell: "/bin/bash", aia_path: "/usr/local/bin/aia", env_file: @env_file_path, config_file: Aias::Paths::SCHEDULE_CFG))
      cli.instance_variable_set(:@manager,   mgr)
      cli.instance_variable_set(:@env_file,  new_env_file)
    end
  end

  # A CLI whose scanner will raise Aias::Error (prompts dir does not exist).
  def new_cli_with_bad_dir
    Aias::CLI.new.tap do |cli|
      cli.instance_variable_set(:@scanner,   Aias::PromptScanner.new(prompts_dir: "/nonexistent_dir_xyz_aias_test"))
      cli.instance_variable_set(:@validator, Aias::Validator.new(binary_to_check: "ruby"))
      cli.instance_variable_set(:@builder,   Aias::JobBuilder.new(shell: "/bin/bash", aia_path: "/usr/local/bin/aia", env_file: @env_file_path, config_file: Aias::Paths::SCHEDULE_CFG))
      cli.instance_variable_set(:@manager,   new_manager)
      cli.instance_variable_set(:@env_file,  new_env_file)
    end
  end

  # Fresh CrontabManager pointing at the test's fake crontab script.
  def new_manager
    Aias::CrontabManager.new(crontab_command: @fake_crontab, log_base: @log_base)
  end

  # Fresh EnvFile pointing at the test's temp file.
  def new_env_file
    Aias::EnvFile.new(path: @env_file_path)
  end

  # Writes a prompt file into @prompts_dir and returns its absolute path.
  # schedule: is optional; omitting it produces a file with no YAML frontmatter
  # so that PM.parse does not choke on an empty frontmatter block.
  def write_prompt(filename, schedule: nil, parameters: nil)
    path = File.join(@prompts_dir, filename)
    frontmatter = {}
    frontmatter["schedule"]   = schedule   if schedule
    frontmatter["parameters"] = parameters if parameters

    content =
      if frontmatter.empty?
        "No scheduled prompt.\n"
      else
        yaml_body = frontmatter.to_yaml.sub(/\A---\n/, "")
        "---\n#{yaml_body}---\nContent.\n"
      end

    File.write(path, content)
    path
  end

  # Writes content to the crontab state file (simulates pre-existing crontab).
  def preset_crontab(content)
    File.write(@crontab_state, content)
  end

  # Creates a minimal aias crontab block for a single job.
  def sample_crontab_block(prompt_id, cron_expr)
    log = File.join(@log_base, "#{prompt_id}.log")
    <<~CRON
      # BEGIN aias
      #{cron_expr} /bin/bash -l -c 'aia #{prompt_id} >> #{log} 2>&1'
      # END aias
    CRON
  end

  # Creates a single aias block containing multiple cron lines.
  # Each argument is a [prompt_id, cron_expr] pair.
  def multi_job_crontab_block(*jobs)
    lines = jobs.map do |prompt_id, cron_expr|
      log = File.join(@log_base, "#{prompt_id}.log")
      "#{cron_expr} /bin/bash -l -c 'aia #{prompt_id} >> #{log} 2>&1'"
    end.join("\n")
    <<~CRON
      # BEGIN aias
      #{lines}
      # END aias
    CRON
  end

  # Creates a shell script that simulates the crontab(1) command.
  # Supports: -l (list), - (write from stdin), -r (remove).
  def write_fake_crontab(dir, state_file)
    path = File.join(dir, "fake_crontab")
    File.write(path, <<~BASH)
      #!/bin/bash
      STATE="#{state_file}"
      if [ "$1" = "-l" ]; then
        if [ -f "$STATE" ]; then cat "$STATE"; exit 0; else echo "no crontab for $USER" >&2; exit 1; fi
      elif [ "$1" = "-" ]; then
        cat > "$STATE"; exit 0
      elif [ "$1" = "-r" ]; then
        rm -f "$STATE"; exit 0
      else
        exit 1
      fi
    BASH
    File.chmod(0o755, path)
    path
  end

  # Temporarily overrides ENV with the given hash for the duration of the block.
  # Removes *_API_KEY and AIA_* vars from the environment before setting the
  # provided vars, so tests are not affected by the developer's real environment.
  MANAGED_PATTERNS = [
    ->(k) { k.end_with?("_API_KEY") },
    ->(k) { k.start_with?("AIA_") }
  ].freeze

  def with_env(vars)
    old = ENV.to_h
    old.each_key { |k| ENV.delete(k) if MANAGED_PATTERNS.any? { |p| p.call(k) } }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each_key { |k| ENV.delete(k) if MANAGED_PATTERNS.any? { |p| p.call(k) } }
    old.each { |k, v| ENV[k] = v if MANAGED_PATTERNS.any? { |p| p.call(k) } }
  end
end
