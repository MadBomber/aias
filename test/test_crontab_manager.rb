# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TestCrontabManager < Minitest::Test
  # ---------------------------------------------------------------------------
  # Setup / teardown
  # ---------------------------------------------------------------------------

  def setup
    @tmpdir        = Dir.mktmpdir("aias_cron_test_")
    @log_base      = File.join(@tmpdir, "logs")
    @crontab_state = File.join(@tmpdir, "crontab_state")
    @fake_crontab  = write_fake_crontab(@tmpdir, @crontab_state)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  # ---------------------------------------------------------------------------
  # dry_run — safe (no system calls)
  # ---------------------------------------------------------------------------

  def test_dry_run_returns_cron_string
    output = new_manager.dry_run(build_job_dsl("daily_digest", "0 8 * * *"))
    assert_kind_of String, output
    assert_match "0 8 * * *", output
  end

  def test_dry_run_includes_prompt_id
    output = new_manager.dry_run(build_job_dsl("daily_digest", "0 8 * * *"))
    assert_match(/aia.*daily_digest/, output)
  end

  def test_dry_run_does_not_touch_crontab
    new_manager.dry_run(build_job_dsl("x", "0 8 * * *"))
    refute File.exist?(@crontab_state), "dry_run must not write to the crontab"
  end

  # ---------------------------------------------------------------------------
  # install — real write via fake crontab script
  # ---------------------------------------------------------------------------

  def test_install_writes_crontab_entry
    new_manager.install(build_job_dsl("daily_digest", "0 8 * * *"))
    jobs = new_manager.installed_jobs
    assert_equal 1, jobs.size
    assert_equal "daily_digest", jobs.first[:prompt_id]
  end

  def test_install_cron_expression_is_correct
    new_manager.install(build_job_dsl("daily_digest", "0 8 * * *"))
    job = new_manager.installed_jobs.first
    assert_equal "0 8 * * *", job[:cron_expr]
  end

  def test_install_raises_on_crontab_write_failure
    broken = File.join(@tmpdir, "broken_crontab")
    File.write(broken, "#!/bin/bash\nexit 1\n")
    File.chmod(0o755, broken)
    manager = Aias::CrontabManager.new(crontab_command: broken, log_base: @log_base)
    assert_raises(Aias::Error) do
      manager.install(build_job_dsl("daily_digest", "0 8 * * *"))
    end
  end

  def test_install_creates_log_base_directory
    new_manager.install(build_job_dsl("x", "0 8 * * *"))
    assert File.directory?(@log_base), "install should create the log base directory"
  end

  # ---------------------------------------------------------------------------
  # clear — real write via fake crontab script
  # ---------------------------------------------------------------------------

  def test_clear_removes_aias_entries
    new_manager.install(build_job_dsl("daily_digest", "0 8 * * *"))
    refute_empty new_manager.installed_jobs  # verify pre-condition
    new_manager.clear
    assert_empty new_manager.installed_jobs
  end

  def test_clear_leaves_non_aias_entries_intact
    # Pre-populate the crontab with a user-managed entry plus an aias block.
    preset_crontab(mixed_crontab)
    new_manager.clear
    content = File.read(@crontab_state)
    assert_match "good morning", content, "clear must not remove non-aias entries"
  end

  # ---------------------------------------------------------------------------
  # read_crontab — exercises real fake crontab
  # ---------------------------------------------------------------------------

  def test_read_crontab_returns_empty_when_crontab_exits_nonzero
    # State file absent → fake crontab exits 1 → read_crontab returns ""
    result = new_manager.send(:read_crontab)
    assert_equal "", result
  end

  def test_read_crontab_returns_output_when_crontab_succeeds
    File.write(@crontab_state, "0 8 * * * echo hi\n")
    result = new_manager.send(:read_crontab)
    assert_equal "0 8 * * * echo hi\n", result
  end

  # ---------------------------------------------------------------------------
  # current_block — stubbed crontab via preset_crontab
  # ---------------------------------------------------------------------------

  def test_current_block_returns_empty_when_no_aias_block
    preset_crontab("0 7 * * * echo hello\n")
    assert_equal "", new_manager.current_block
  end

  def test_current_block_returns_empty_when_no_crontab
    # No state file → empty crontab
    assert_equal "", new_manager.current_block
  end

  def test_current_block_extracts_aias_lines
    preset_crontab(sample_block)
    block = new_manager.current_block
    assert_match "aia daily_digest", block
    assert_match "aia reports/weekly", block
  end

  def test_current_block_excludes_marker_lines
    preset_crontab(sample_block)
    block = new_manager.current_block
    refute_match "BEGIN aias", block
    refute_match "END aias", block
  end

  def test_current_block_excludes_non_aias_entries
    preset_crontab(mixed_crontab)
    block = new_manager.current_block
    refute_match "good morning", block
    refute_match "goodnight", block
  end

  # ---------------------------------------------------------------------------
  # installed_jobs — parsed from preset crontab
  # ---------------------------------------------------------------------------

  def test_installed_jobs_returns_empty_when_no_block
    assert_equal [], new_manager.installed_jobs
  end

  def test_installed_jobs_returns_correct_count
    preset_crontab(sample_block)
    assert_equal 2, new_manager.installed_jobs.size
  end

  def test_installed_jobs_has_expected_keys
    preset_crontab(sample_block)
    job = new_manager.installed_jobs.first
    assert_includes job.keys, :prompt_id
    assert_includes job.keys, :cron_expr
    assert_includes job.keys, :log_path
  end

  def test_installed_jobs_prompt_id_is_correct
    preset_crontab(sample_block)
    ids = new_manager.installed_jobs.map { |j| j[:prompt_id] }
    assert_includes ids, "daily_digest"
    assert_includes ids, "reports/weekly"
  end

  def test_installed_jobs_cron_expr_is_correct
    preset_crontab(sample_block)
    exprs = new_manager.installed_jobs.map { |j| j[:cron_expr] }
    assert_includes exprs, "0 8 * * *"
    assert_includes exprs, "0 9 * * 1"
  end

  def test_installed_jobs_log_path_is_correct
    preset_crontab(sample_block)
    paths = new_manager.installed_jobs.map { |j| j[:log_path] }
    assert_includes paths, "#{@log_base}/daily_digest.log"
    assert_includes paths, "#{@log_base}/reports/weekly.log"
  end

  def test_installed_jobs_parses_entries_with_prompts_dir_flag
    block = <<~CRON
      # BEGIN aias
      0 8 * * * /bin/bash -l -c 'aia --prompts-dir /data/prompts daily_digest >> #{@log_base}/daily_digest.log 2>&1'
      0 9 * * 1 /bin/bash -l -c 'aia --prompts-dir /data/prompts reports/weekly >> #{@log_base}/reports/weekly.log 2>&1'
      # END aias
    CRON
    preset_crontab(block)
    jobs = new_manager.installed_jobs
    assert_equal 2, jobs.size
    ids = jobs.map { |j| j[:prompt_id] }
    assert_includes ids, "daily_digest"
    assert_includes ids, "reports/weekly"
  end

  def test_installed_jobs_prompt_id_not_confused_with_prompts_dir_value
    block = <<~CRON
      # BEGIN aias
      0 8 * * * /bin/bash -l -c 'aia --prompts-dir /data/prompts daily_digest >> #{@log_base}/daily_digest.log 2>&1'
      # END aias
    CRON
    preset_crontab(block)
    job = new_manager.installed_jobs.first
    assert_equal "daily_digest", job[:prompt_id],
      "prompt_id must be 'daily_digest', not the --prompts-dir path value"
  end

  def test_installed_jobs_parses_current_format_with_prompts_dir_after_prompt_id
    block = <<~CRON
      # BEGIN aias
      0 8 * * * /bin/bash -l -c 'aia daily_digest --prompts-dir /data/prompts --config ~/.config/aia/schedule/aia.yml >> #{@log_base}/daily_digest.log 2>&1'
      # END aias
    CRON
    preset_crontab(block)
    job = new_manager.installed_jobs.first
    assert_equal "daily_digest", job[:prompt_id]
    assert_equal "0 8 * * *", job[:cron_expr]
  end

  # ---------------------------------------------------------------------------
  # add_job — upsert a single entry
  # ---------------------------------------------------------------------------

  def test_add_job_installs_entry_when_block_is_empty
    new_manager.add_job(build_job_dsl("standup", "0 9 * * 1-5"), "standup")
    jobs = new_manager.installed_jobs
    assert_equal 1, jobs.size
    assert_equal "standup", jobs.first[:prompt_id]
  end

  def test_add_job_appends_to_existing_entries
    new_manager.install(build_job_dsl("daily_digest", "0 8 * * *"))
    new_manager.add_job(build_job_dsl("standup", "0 9 * * 1-5"), "standup")
    ids = new_manager.installed_jobs.map { |j| j[:prompt_id] }
    assert_includes ids, "daily_digest"
    assert_includes ids, "standup"
  end

  def test_add_job_replaces_existing_entry_for_same_prompt_id
    new_manager.install(build_job_dsl("standup", "0 8 * * *"))
    new_manager.add_job(build_job_dsl("standup", "0 10 * * *"), "standup")
    jobs = new_manager.installed_jobs.select { |j| j[:prompt_id] == "standup" }
    assert_equal 1, jobs.size, "duplicate entries must not be created on re-add"
    assert_equal "0 10 * * *", jobs.first[:cron_expr]
  end

  def test_add_job_leaves_other_entries_untouched
    new_manager.install([
      build_job_dsl("alpha", "0 8 * * *"),
      build_job_dsl("beta",  "0 10 * * *")
    ])
    new_manager.add_job(build_job_dsl("gamma", "0 12 * * *"), "gamma")
    ids = new_manager.installed_jobs.map { |j| j[:prompt_id] }
    assert_includes ids, "alpha"
    assert_includes ids, "beta"
    assert_includes ids, "gamma"
  end

  def test_add_job_preserves_non_aias_crontab_entries
    preset_crontab(mixed_crontab)
    new_manager.add_job(build_job_dsl("standup", "0 9 * * 1-5"), "standup")
    content = File.read(@crontab_state)
    assert_match "good morning", content
    assert_match "goodnight", content
  end

  def test_add_job_creates_log_base_directory
    new_manager.add_job(build_job_dsl("standup", "0 9 * * 1-5"), "standup")
    assert File.directory?(@log_base)
  end

  # ---------------------------------------------------------------------------
  # remove_job — delete a single entry
  # ---------------------------------------------------------------------------

  def test_remove_job_removes_the_entry
    new_manager.install(build_job_dsl("daily_digest", "0 8 * * *"))
    new_manager.remove_job("daily_digest")
    assert_empty new_manager.installed_jobs
  end

  def test_remove_job_leaves_other_entries_untouched
    new_manager.install([
      build_job_dsl("alpha", "0 8 * * *"),
      build_job_dsl("beta",  "0 10 * * *")
    ])
    new_manager.remove_job("alpha")
    ids = new_manager.installed_jobs.map { |j| j[:prompt_id] }
    refute_includes ids, "alpha"
    assert_includes ids, "beta"
  end

  def test_remove_job_raises_when_prompt_id_not_installed
    assert_raises(Aias::Error) { new_manager.remove_job("nonexistent") }
  end

  def test_remove_job_preserves_non_aias_crontab_entries
    preset_crontab(mixed_crontab)
    new_manager.install(build_job_dsl("daily_digest", "0 8 * * *"))
    new_manager.remove_job("daily_digest")
    content = File.read(@crontab_state)
    assert_match "good morning", content
    assert_match "goodnight", content
  end

  # ---------------------------------------------------------------------------
  # ensure_log_directories
  # ---------------------------------------------------------------------------

  def test_ensure_log_directories_creates_nested_dirs
    new_manager.ensure_log_directories(["reports/weekly", "daily_digest"])
    # "reports/weekly" → <log_base>/reports/
    assert File.directory?(File.join(@log_base, "reports"))
    # "daily_digest"   → <log_base>/   (dirname of daily_digest.log)
    assert File.directory?(@log_base)
  end

  # ---------------------------------------------------------------------------
  # installed_jobs — new format (source env.sh, no -l)
  # ---------------------------------------------------------------------------

  def test_installed_jobs_parses_new_format_with_source_and_config_file
    block = <<~CRON
      # BEGIN aias
      0 8 * * * /bin/bash -c 'source /fake/env.sh && /usr/local/bin/aia daily_digest --config-file /fake/schedule/aia.yml >> #{@log_base}/daily_digest.log 2>&1'
      # END aias
    CRON
    preset_crontab(block)
    job = new_manager.installed_jobs.first
    assert_equal "daily_digest", job[:prompt_id]
    assert_equal "0 8 * * *", job[:cron_expr]
    assert_equal "#{@log_base}/daily_digest.log", job[:log_path]
  end

  def test_installed_jobs_parses_new_format_with_inline_env_var
    block = <<~CRON
      # BEGIN aias
      0 8 * * * /bin/bash -c 'source /fake/env.sh && AIA_PROMPTS__DIR=/data/prompts /usr/local/bin/aia daily_digest --config-file /fake/schedule/aia.yml >> #{@log_base}/daily_digest.log 2>&1'
      # END aias
    CRON
    preset_crontab(block)
    job = new_manager.installed_jobs.first
    assert_equal "daily_digest", job[:prompt_id]
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  private

  # Builds a CrontabManager pointing at the test's fake crontab script.
  def new_manager
    Aias::CrontabManager.new(crontab_command: @fake_crontab, log_base: @log_base)
  end

  # Writes content to the crontab state file so the fake crontab "has" it.
  def preset_crontab(content)
    File.write(@crontab_state, content)
  end

  # Creates a shell script that simulates the crontab(1) command.
  # State is persisted in state_file across invocations.
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

  # Build a minimal valid cron line for a single prompt.
  def build_job_dsl(prompt_id, schedule)
    Aias::JobBuilder.new(shell: "/bin/bash", aia_path: "/usr/local/bin/aia", env_file: "/fake/env.sh", config_file: "/fake/schedule/aia.yml").build(
      build_result(prompt_id: prompt_id, schedule: schedule)
    )
  end

  # Sample aias crontab block using test log_base.
  def sample_block
    <<~CRON
      # BEGIN aias
      0 8 * * * /bin/bash -l -c 'aia daily_digest >> #{@log_base}/daily_digest.log 2>&1'
      0 9 * * 1 /bin/bash -l -c 'aia reports/weekly >> #{@log_base}/reports/weekly.log 2>&1'
      # END aias
    CRON
  end

  # A crontab that contains both non-aias and aias entries.
  def mixed_crontab
    <<~CRON
      # This is a user-managed entry
      0 7 * * * echo "good morning"

      # BEGIN aias
      0 8 * * * /bin/bash -l -c 'aia daily_digest >> #{@log_base}/daily_digest.log 2>&1'
      # END aias

      # Another user entry
      0 23 * * * echo "goodnight"
    CRON
  end
end
