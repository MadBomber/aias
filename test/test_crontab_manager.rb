# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TestCrontabManager < Minitest::Test
  LOG_BASE = File.expand_path("~/.aia/schedule/logs")

  # Sample whenever-generated crontab block (mimics real output)
  SAMPLE_BLOCK = <<~CRON
    # Begin Whenever generated tasks for: aias at: 2025-01-01 08:00:00 +0000
    0 8 * * * /bin/bash -l -c "aia daily_digest >> #{LOG_BASE}/daily_digest.log 2>&1"
    0 9 * * 1 /bin/bash -l -c "aia reports/weekly >> #{LOG_BASE}/reports/weekly.log 2>&1"
    # End Whenever generated tasks for: aias at: 2025-01-01 08:00:00 +0000
  CRON

  # A crontab that also has non-aias entries
  MIXED_CRONTAB = <<~CRON
    # This is a user-managed entry
    0 7 * * * echo "good morning"

    # Begin Whenever generated tasks for: aias at: 2025-01-01 08:00:00 +0000
    0 8 * * * /bin/bash -l -c "aia daily_digest >> #{LOG_BASE}/daily_digest.log 2>&1"
    # End Whenever generated tasks for: aias at: 2025-01-01 08:00:00 +0000

    # Another user entry
    0 23 * * * echo "goodnight"
  CRON

  # ---------------------------------------------------------------------------
  # dry_run — safe (no system calls)
  # ---------------------------------------------------------------------------

  def test_dry_run_returns_cron_string
    manager = Aias::CrontabManager.new
    dsl = build_job_dsl("daily_digest", "0 8 * * *")
    output = manager.dry_run(dsl)
    assert_kind_of String, output
    assert_match "0 8 * * *", output
  end

  def test_dry_run_includes_prompt_id
    manager = Aias::CrontabManager.new
    dsl = build_job_dsl("daily_digest", "0 8 * * *")
    output = manager.dry_run(dsl)
    assert_match "aia daily_digest", output
  end

  def test_dry_run_does_not_touch_crontab
    manager = Aias::CrontabManager.new
    # If crontab were called, the stub would fail with an unexpected call
    Open3.stub(:capture3, ->(*_) { raise "crontab should not be called!" }) do
      Whenever::CommandLine.stub(:execute, ->(*_) { raise "CommandLine should not be called!" }) do
        manager.dry_run(build_job_dsl("x", "0 8 * * *"))
      end
    end
    pass "dry_run made no system calls"
  end

  # ---------------------------------------------------------------------------
  # install — stubbed to avoid touching crontab
  # ---------------------------------------------------------------------------

  def test_install_calls_whenever_command_line_with_update
    manager = Aias::CrontabManager.new
    called_with = nil

    Whenever::CommandLine.stub(:execute, ->(opts) { called_with = opts; 0 }) do
      manager.install(build_job_dsl("daily_digest", "0 8 * * *"))
    end

    assert_equal true, called_with[:update]
  end

  def test_install_uses_aias_identifier
    manager = Aias::CrontabManager.new
    called_with = nil

    Whenever::CommandLine.stub(:execute, ->(opts) { called_with = opts; 0 }) do
      manager.install(build_job_dsl("daily_digest", "0 8 * * *"))
    end

    assert_equal "aias", called_with[:identifier]
  end

  def test_install_passes_console_false
    manager = Aias::CrontabManager.new
    called_with = nil

    Whenever::CommandLine.stub(:execute, ->(opts) { called_with = opts; 0 }) do
      manager.install(build_job_dsl("daily_digest", "0 8 * * *"))
    end

    assert_equal false, called_with[:console]
  end

  def test_install_raises_on_whenever_failure
    manager = Aias::CrontabManager.new
    Whenever::CommandLine.stub(:execute, ->(_opts) { 1 }) do
      assert_raises(Aias::Error) do
        manager.install(build_job_dsl("daily_digest", "0 8 * * *"))
      end
    end
  end

  def test_install_creates_log_base_directory
    manager = Aias::CrontabManager.new
    mkdir_calls = []

    FileUtils.stub(:mkdir_p, ->(path) { mkdir_calls << path }) do
      Whenever::CommandLine.stub(:execute, ->(_opts) { 0 }) do
        manager.install(build_job_dsl("x", "0 8 * * *"))
      end
    end

    assert_includes mkdir_calls, Aias::CrontabManager::LOG_BASE
  end

  # ---------------------------------------------------------------------------
  # clear — stubbed
  # ---------------------------------------------------------------------------

  def test_clear_calls_whenever_command_line_with_clear
    manager = Aias::CrontabManager.new
    called_with = nil

    Whenever::CommandLine.stub(:execute, ->(opts) { called_with = opts; 0 }) do
      manager.clear
    end

    assert_equal true, called_with[:clear]
  end

  def test_clear_uses_aias_identifier
    manager = Aias::CrontabManager.new
    called_with = nil

    Whenever::CommandLine.stub(:execute, ->(opts) { called_with = opts; 0 }) do
      manager.clear
    end

    assert_equal "aias", called_with[:identifier]
  end

  def test_clear_passes_console_false
    manager = Aias::CrontabManager.new
    called_with = nil

    Whenever::CommandLine.stub(:execute, ->(opts) { called_with = opts; 0 }) do
      manager.clear
    end

    assert_equal false, called_with[:console]
  end

  # ---------------------------------------------------------------------------
  # current_block — stubbed crontab reads
  # ---------------------------------------------------------------------------

  def test_current_block_returns_empty_when_no_aias_block
    manager = stub_crontab("0 7 * * * echo hello\n")
    assert_equal "", manager.current_block
  end

  def test_current_block_returns_empty_when_no_crontab
    manager = stub_crontab("")
    assert_equal "", manager.current_block
  end

  def test_current_block_extracts_aias_lines
    manager = stub_crontab(SAMPLE_BLOCK)
    block = manager.current_block
    assert_match "aia daily_digest", block
    assert_match "aia reports/weekly", block
  end

  def test_current_block_excludes_marker_lines
    manager = stub_crontab(SAMPLE_BLOCK)
    block = manager.current_block
    refute_match "Begin Whenever", block
    refute_match "End Whenever", block
  end

  def test_current_block_excludes_non_aias_entries
    manager = stub_crontab(MIXED_CRONTAB)
    block = manager.current_block
    refute_match "good morning", block
    refute_match "goodnight", block
  end

  # ---------------------------------------------------------------------------
  # installed_jobs — parsed from stubbed crontab
  # ---------------------------------------------------------------------------

  def test_installed_jobs_returns_empty_when_no_block
    manager = stub_crontab("")
    assert_equal [], manager.installed_jobs
  end

  def test_installed_jobs_returns_one_job
    manager = stub_crontab(SAMPLE_BLOCK)
    assert_equal 2, manager.installed_jobs.size
  end

  def test_installed_jobs_has_expected_keys
    manager = stub_crontab(SAMPLE_BLOCK)
    job = manager.installed_jobs.first
    assert_includes job.keys, :prompt_id
    assert_includes job.keys, :cron_expr
    assert_includes job.keys, :log_path
  end

  def test_installed_jobs_prompt_id_is_correct
    manager = stub_crontab(SAMPLE_BLOCK)
    ids = manager.installed_jobs.map { |j| j[:prompt_id] }
    assert_includes ids, "daily_digest"
    assert_includes ids, "reports/weekly"
  end

  def test_installed_jobs_cron_expr_is_correct
    manager = stub_crontab(SAMPLE_BLOCK)
    exprs = manager.installed_jobs.map { |j| j[:cron_expr] }
    assert_includes exprs, "0 8 * * *"
    assert_includes exprs, "0 9 * * 1"
  end

  def test_installed_jobs_log_path_is_correct
    manager = stub_crontab(SAMPLE_BLOCK)
    paths = manager.installed_jobs.map { |j| j[:log_path] }
    assert_includes paths, "#{LOG_BASE}/daily_digest.log"
    assert_includes paths, "#{LOG_BASE}/reports/weekly.log"
  end

  # ---------------------------------------------------------------------------
  # ensure_log_directories
  # ---------------------------------------------------------------------------

  def test_ensure_log_directories_creates_nested_dirs
    mkdir_calls = []
    FileUtils.stub(:mkdir_p, ->(path) { mkdir_calls << path }) do
      manager = Aias::CrontabManager.new
      manager.ensure_log_directories(["reports/weekly", "daily_digest"])
    end
    # "reports/weekly" → mkdir_p(<LOG_BASE>/reports)
    assert mkdir_calls.any? { |p| p.to_s.end_with?("reports") }
    # "daily_digest" → mkdir_p(<LOG_BASE>) since File.dirname of a flat file is its dir
    assert mkdir_calls.any? { |p| p.to_s == LOG_BASE }
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  private

  # Returns a CrontabManager whose read_crontab is stubbed to return the given text.
  def stub_crontab(text)
    manager = Aias::CrontabManager.new
    status = Object.new
    status.define_singleton_method(:success?) { true }
    Open3.stub(:capture3, [text, "", status]) do
      # Eagerly test current_block — but we can't pre-warm private method here.
      # Instead return a manager that stubs Open3 at call time via a wrapper.
    end

    # Patch the private read_crontab by reopening the instance
    manager.define_singleton_method(:read_crontab) { text }
    manager
  end

  # Build a minimal valid whenever DSL for a single prompt.
  def build_job_dsl(prompt_id, schedule)
    Aias::JobBuilder.new(shell: "/bin/bash").build(
      build_result(prompt_id: prompt_id, schedule: schedule)
    )
  end
end
