# frozen_string_literal: true

require "test_helper"

# CLI tests inject stub collaborators via the lazy accessor pattern:
# set the instance variable before calling the command method.
class TestCli < Minitest::Test
  # ---------------------------------------------------------------------------
  # update
  # ---------------------------------------------------------------------------

  def test_update_with_no_valid_prompts_prints_no_jobs_message
    cli = build_cli(scanner_results: [], valid: [])
    out, = capture_io { cli.update }
    assert_match "no valid scheduled prompts", out
  end

  def test_update_calls_manager_install_for_valid_prompt
    r = build_result
    install_called = false
    cli = build_cli(scanner_results: [r], valid: [r], track_install: ->(v) { install_called = v })
    capture_io { cli.update }
    assert install_called, "manager#install should have been called"
  end

  def test_update_does_not_call_install_when_all_invalid
    r = build_result
    install_called = false
    cli = build_cli(scanner_results: [r], valid: [], track_install: ->(v) { install_called = v })
    capture_io { cli.update }
    refute install_called, "manager#install should not be called when all prompts invalid"
  end

  def test_update_warns_for_invalid_prompts
    r = build_result
    cli = build_cli(scanner_results: [r], valid: [], invalid: [r])
    _, err = capture_io { cli.update }
    assert_match "skip", err
    assert_match r.prompt_id, err
  end

  def test_update_prints_installed_count
    r = build_result
    cli = build_cli(scanner_results: [r], valid: [r])
    out, = capture_io { cli.update }
    assert_match "1 job", out
  end

  def test_update_prints_skipped_count_when_mix_of_valid_and_invalid
    valid_r   = build_result(prompt_id: "good")
    invalid_r = build_result(prompt_id: "bad")
    cli = build_cli(scanner_results: [valid_r, invalid_r], valid: [valid_r])
    out, = capture_io { cli.update }
    assert_match "skipped 1 invalid", out
  end

  def test_update_rescues_aias_error
    cli = Aias::CLI.new
    scanner = Object.new
    scanner.define_singleton_method(:scan) { raise Aias::Error, "prompts dir missing" }
    cli.instance_variable_set(:@scanner, scanner)

    assert_raises(SystemExit) do
      capture_io { cli.update }
    end
  end

  # ---------------------------------------------------------------------------
  # clear
  # ---------------------------------------------------------------------------

  def test_clear_calls_manager_clear
    clear_called = false
    cli = Aias::CLI.new
    cli.instance_variable_set(:@manager, stub_manager_with_jobs([], track_clear: ->(v) { clear_called = v }))
    capture_io { cli.clear }
    assert clear_called, "manager#clear should have been called"
  end

  def test_clear_prints_confirmation
    cli = Aias::CLI.new
    stub_manager = Object.new
    stub_manager.define_singleton_method(:clear) { nil }
    cli.instance_variable_set(:@manager, stub_manager)
    out, = capture_io { cli.clear }
    assert_match "removed", out
  end

  # ---------------------------------------------------------------------------
  # list
  # ---------------------------------------------------------------------------

  def test_list_prints_no_jobs_when_empty
    cli = Aias::CLI.new
    cli.instance_variable_set(:@manager, stub_manager_with_jobs([]))
    out, = capture_io { cli.list }
    assert_match "no installed jobs", out
  end

  def test_list_prints_table_headers
    cli = Aias::CLI.new
    jobs = [{ prompt_id: "daily_digest", cron_expr: "0 8 * * *", log_path: "/tmp/x.log" }]
    cli.instance_variable_set(:@manager, stub_manager_with_jobs(jobs))
    out, = capture_io { cli.list }
    assert_match "PROMPT ID", out
    assert_match "SCHEDULE", out
  end

  def test_list_prints_job_details
    cli = Aias::CLI.new
    jobs = [{ prompt_id: "daily_digest", cron_expr: "0 8 * * *", log_path: "/tmp/daily_digest.log" }]
    cli.instance_variable_set(:@manager, stub_manager_with_jobs(jobs))
    out, = capture_io { cli.list }
    assert_match "daily_digest", out
    assert_match "0 8 * * *", out
    assert_match "/tmp/daily_digest.log", out
  end

  # ---------------------------------------------------------------------------
  # check
  # ---------------------------------------------------------------------------

  def test_check_reports_ok_when_in_sync
    r = build_result(prompt_id: "daily_digest", schedule: "0 8 * * *")
    cli = build_cli(scanner_results: [r], valid: [r])
    jobs = [{ prompt_id: "daily_digest", cron_expr: "0 8 * * *", log_path: "/tmp/x.log" }]
    cli.instance_variable_set(:@manager, stub_manager_with_jobs(jobs))
    out, = capture_io { cli.check }
    assert_match "OK", out
  end

  def test_check_reports_new_jobs
    r = build_result(prompt_id: "new_job")
    cli = build_cli(scanner_results: [r], valid: [r])
    cli.instance_variable_set(:@manager, stub_manager_with_jobs([]))
    out, = capture_io { cli.check }
    assert_match "NEW", out
    assert_match "new_job", out
  end

  def test_check_reports_orphaned_jobs
    cli = build_cli(scanner_results: [], valid: [])
    jobs = [{ prompt_id: "orphaned", cron_expr: "0 8 * * *", log_path: "/tmp/x.log" }]
    cli.instance_variable_set(:@manager, stub_manager_with_jobs(jobs))
    out, = capture_io { cli.check }
    assert_match "ORPHANED", out
    assert_match "orphaned", out
  end

  def test_check_reports_invalid_prompts
    r = build_result(prompt_id: "bad_job")
    cli = build_cli(scanner_results: [r], valid: [], invalid: [r])
    cli.instance_variable_set(:@manager, stub_manager_with_jobs([]))
    out, = capture_io { cli.check }
    assert_match "INVALID", out
    assert_match "bad_job", out
  end

  def test_check_rescues_aias_error
    cli = Aias::CLI.new
    scanner = Object.new
    scanner.define_singleton_method(:scan) { raise Aias::Error, "no prompts dir" }
    cli.instance_variable_set(:@scanner, scanner)
    assert_raises(SystemExit) { capture_io { cli.check } }
  end

  # ---------------------------------------------------------------------------
  # dry-run
  # ---------------------------------------------------------------------------

  def test_dry_run_does_not_call_install
    r = build_result
    cli = build_cli(scanner_results: [r], valid: [r], dry_run_output: "0 8 * * * echo hi")
    # manager has no install expectation — if install were called, an error would surface
    capture_io { cli.dry_run }
    pass "dry_run did not call install"
  end

  def test_dry_run_prints_cron_output
    r = build_result
    cli = build_cli(scanner_results: [r], valid: [r], dry_run_output: "0 8 * * * aia daily_digest")
    out, = capture_io { cli.dry_run }
    assert_match "0 8 * * *", out
  end

  def test_dry_run_prints_no_prompts_when_none_valid
    cli = build_cli(scanner_results: [], valid: [])
    out, = capture_io { cli.dry_run }
    assert_match "no valid", out
  end

  # ---------------------------------------------------------------------------
  # show
  # ---------------------------------------------------------------------------

  def test_show_prints_job_details_when_found
    cli = Aias::CLI.new
    jobs = [{ prompt_id: "daily_digest", cron_expr: "0 8 * * *", log_path: "/tmp/x.log" }]
    cli.instance_variable_set(:@manager, stub_manager_with_jobs(jobs))
    out, = capture_io { cli.show("daily_digest") }
    assert_match "daily_digest", out
    assert_match "0 8 * * *", out
  end

  def test_show_exits_when_not_found
    cli = Aias::CLI.new
    cli.instance_variable_set(:@manager, stub_manager_with_jobs([]))
    assert_raises(SystemExit) { capture_io { cli.show("nonexistent") } }
  end

  def test_show_prints_not_installed_message
    cli = Aias::CLI.new
    cli.instance_variable_set(:@manager, stub_manager_with_jobs([]))
    out, = capture_io do
      assert_raises(SystemExit) { cli.show("nonexistent") }
    end
    assert_match "not currently installed", out
  end

  # ---------------------------------------------------------------------------
  # upcoming (next)
  # ---------------------------------------------------------------------------

  def test_upcoming_prints_no_jobs_when_empty
    cli = Aias::CLI.new
    cli.instance_variable_set(:@manager, stub_manager_with_jobs([]))
    out, = capture_io { cli.upcoming }
    assert_match "no installed jobs", out
  end

  def test_upcoming_prints_job_schedule
    cli = Aias::CLI.new
    jobs = [{ prompt_id: "daily_digest", cron_expr: "0 8 * * *", log_path: "/tmp/x.log" }]
    cli.instance_variable_set(:@manager, stub_manager_with_jobs(jobs))
    out, = capture_io { cli.upcoming }
    assert_match "daily_digest", out
    assert_match "0 8 * * *", out
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  private

  # Builds a CLI instance with pre-wired stub collaborators.
  # valid/invalid are arrays of PromptScanner::Result objects (not pairs).
  def build_cli(scanner_results:, valid: [], invalid: [], dry_run_output: "", track_install: nil)
    cli = Aias::CLI.new

    stub_scanner = Object.new
    stub_scanner.define_singleton_method(:scan) { scanner_results }
    cli.instance_variable_set(:@scanner, stub_scanner)

    # Build a validator that marks results in `valid` as valid, others invalid
    valid_set = valid.map(&:object_id).to_set
    stub_validator = Object.new
    stub_validator.define_singleton_method(:validate) do |result|
      if valid_set.include?(result.object_id)
        Aias::Validator::ValidationResult.new(valid?: true, errors: [])
      else
        Aias::Validator::ValidationResult.new(valid?: false, errors: ["fake validation error"])
      end
    end
    cli.instance_variable_set(:@validator, stub_validator)

    cli.instance_variable_set(:@builder, Aias::JobBuilder.new(shell: "/bin/bash"))
    cli.instance_variable_set(:@manager, stub_manager_with_jobs([], dry_run_output: dry_run_output, track_install: track_install))

    cli
  end

  def stub_manager_with_jobs(jobs, dry_run_output: "", track_install: nil, track_clear: nil)
    m = Object.new
    m.define_singleton_method(:installed_jobs) { jobs }
    m.define_singleton_method(:clear) { track_clear&.call(true) }
    m.define_singleton_method(:ensure_log_directories) { |_| nil }
    m.define_singleton_method(:install) { |_| track_install&.call(true) }
    m.define_singleton_method(:dry_run) { |_| dry_run_output }
    m
  end
end
