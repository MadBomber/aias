# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TestPromptScanner < Minitest::Test
  def setup
    @prompts_dir = Dir.mktmpdir("aias_test_")
    @original_env_old = ENV[Aias::PromptScanner::PROMPTS_DIR_ENVVAR_OLD]
    @original_env_new = ENV[Aias::PromptScanner::PROMPTS_DIR_ENVVAR_NEW]
    ENV[Aias::PromptScanner::PROMPTS_DIR_ENVVAR_OLD] = @prompts_dir
    ENV[Aias::PromptScanner::PROMPTS_DIR_ENVVAR_NEW] = nil
  end

  def teardown
    FileUtils.remove_entry(@prompts_dir)
    ENV[Aias::PromptScanner::PROMPTS_DIR_ENVVAR_OLD] = @original_env_old
    ENV[Aias::PromptScanner::PROMPTS_DIR_ENVVAR_NEW] = @original_env_new
  end

  # ---------------------------------------------------------------------------
  # Result struct
  # ---------------------------------------------------------------------------

  def test_result_struct_has_expected_fields
    result = build_result
    assert_respond_to result, :prompt_id
    assert_respond_to result, :schedule
    assert_respond_to result, :metadata
    assert_respond_to result, :file_path
  end

  def test_result_is_immutable
    result = build_result
    assert_raises(FrozenError, NoMethodError) { result.prompt_id = "other" }
  end

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  def test_scan_raises_when_prompts_dir_nil
    # nil means "use env vars"; clear both so there is genuinely nothing configured
    ENV[Aias::PromptScanner::PROMPTS_DIR_ENVVAR_NEW] = nil
    ENV[Aias::PromptScanner::PROMPTS_DIR_ENVVAR_OLD] = nil
    scanner = Aias::PromptScanner.new(prompts_dir: nil)
    assert_raises(Aias::Error) { scanner.scan }
  end

  def test_scan_uses_explicit_prompts_dir_over_env_vars
    other_dir = Dir.mktmpdir("aias_other_")
    write_prompt("env_test.md", schedule: "0 8 * * *")  # in @prompts_dir (env var)
    scanner = Aias::PromptScanner.new(prompts_dir: other_dir)  # points elsewhere
    results = scanner.scan
    assert_empty results, "explicit prompts_dir should take precedence over env vars"
  ensure
    FileUtils.remove_entry(other_dir)
  end

  def test_scan_raises_when_prompts_dir_empty_string
    scanner = Aias::PromptScanner.new(prompts_dir: "")
    assert_raises(Aias::Error) { scanner.scan }
  end

  def test_scan_raises_when_prompts_dir_missing
    scanner = Aias::PromptScanner.new(prompts_dir: "/nonexistent_aias_test_dir")
    assert_raises(Aias::Error) { scanner.scan }
  end

  def test_scan_raises_with_descriptive_message_for_missing_dir
    scanner = Aias::PromptScanner.new(prompts_dir: "/no_such_dir_aias")
    err = assert_raises(Aias::Error) { scanner.scan }
    assert_match "/no_such_dir_aias", err.message
  end

  # ---------------------------------------------------------------------------
  # Discovery — basic
  # ---------------------------------------------------------------------------

  def test_scan_returns_empty_array_when_no_prompts
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    assert_equal [], scanner.scan
  end

  def test_scan_finds_scheduled_prompt
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    results = scanner.scan
    assert_equal 1, results.size
  end

  def test_scan_ignores_prompt_without_schedule
    write_prompt("no_schedule.md")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    assert_equal [], scanner.scan
  end

  def test_scan_returns_only_scheduled_from_mixed_files
    write_prompt("with_schedule.md", schedule: "0 8 * * *")
    write_prompt("without_schedule.md")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    results = scanner.scan
    assert_equal 1, results.size
    assert_equal "with_schedule", results.first.prompt_id
  end

  def test_scan_finds_multiple_scheduled_prompts
    write_prompt("alpha.md", schedule: "0 8 * * *")
    write_prompt("beta.md", schedule: "every 1.hour")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    assert_equal 2, scanner.scan.size
  end

  # ---------------------------------------------------------------------------
  # Prompt ID derivation
  # ---------------------------------------------------------------------------

  def test_scan_derives_simple_prompt_id
    write_prompt("daily_digest.md", schedule: "0 8 * * *")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    result = scanner.scan.first
    assert_equal "daily_digest", result.prompt_id
  end

  def test_scan_derives_nested_prompt_id
    subdir = File.join(@prompts_dir, "reports")
    FileUtils.mkdir_p(subdir)
    write_prompt("reports/weekly.md", schedule: "0 9 * * 1")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    result = scanner.scan.first
    assert_equal "reports/weekly", result.prompt_id
  end

  def test_scan_derives_deeply_nested_prompt_id
    FileUtils.mkdir_p(File.join(@prompts_dir, "a/b"))
    write_prompt("a/b/deep.md", schedule: "0 8 * * *")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    result = scanner.scan.first
    assert_equal "a/b/deep", result.prompt_id
  end

  # ---------------------------------------------------------------------------
  # Result field values
  # ---------------------------------------------------------------------------

  def test_scan_result_has_correct_schedule
    write_prompt("job.md", schedule: "0 8 * * *")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    result = scanner.scan.first
    assert_equal "0 8 * * *", result.schedule
  end

  def test_scan_result_has_correct_file_path
    write_prompt("job.md", schedule: "0 8 * * *")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    result = scanner.scan.first
    assert_equal File.join(@prompts_dir, "job.md"), result.file_path
  end

  def test_scan_result_metadata_has_schedule
    write_prompt("job.md", schedule: "every 1.day at 8:00am")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    result = scanner.scan.first
    assert_equal "every 1.day at 8:00am", result.metadata.schedule
  end

  def test_scan_result_metadata_has_parameters_when_present
    write_prompt("paramjob.md", schedule: "0 8 * * *", parameters: { "topic" => "AI" })
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    result = scanner.scan.first
    assert_equal({ "topic" => "AI" }, result.metadata.parameters)
  end

  # ---------------------------------------------------------------------------
  # Resilience
  # ---------------------------------------------------------------------------

  def test_scan_skips_file_with_bad_frontmatter_and_returns_remainder
    # Write a file with valid "schedule:" text but invalid YAML frontmatter
    bad_path = File.join(@prompts_dir, "bad.md")
    File.write(bad_path, "---\nschedule: [unclosed\n---\nContent")
    write_prompt("good.md", schedule: "0 8 * * *")

    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    results = nil
    capture_io { results = scanner.scan }
    assert_equal 1, results.size
    assert_equal "good", results.first.prompt_id
  end

  def test_scan_uses_env_prompts_dir_by_default
    write_prompt("env_test.md", schedule: "0 8 * * *")
    scanner = Aias::PromptScanner.new  # uses AIA_PROMPTS__DIR or AIA_PROMPTS_DIR from ENV
    results = scanner.scan
    assert_equal 1, results.size
  end

  # ---------------------------------------------------------------------------
  # scan_one — happy path
  # ---------------------------------------------------------------------------

  def test_scan_one_returns_result_for_scheduled_prompt
    write_prompt("job.md", schedule: "0 8 * * *")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    result  = scanner.scan_one(File.join(@prompts_dir, "job.md"))
    assert_instance_of Aias::PromptScanner::Result, result
  end

  def test_scan_one_derives_simple_prompt_id
    write_prompt("standup.md", schedule: "0 9 * * 1-5")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    result  = scanner.scan_one(File.join(@prompts_dir, "standup.md"))
    assert_equal "standup", result.prompt_id
  end

  def test_scan_one_derives_nested_prompt_id
    FileUtils.mkdir_p(File.join(@prompts_dir, "reports"))
    write_prompt("reports/weekly.md", schedule: "0 9 * * 1")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    result  = scanner.scan_one(File.join(@prompts_dir, "reports/weekly.md"))
    assert_equal "reports/weekly", result.prompt_id
  end

  def test_scan_one_expands_relative_path
    write_prompt("job.md", schedule: "0 8 * * *")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    # Change to prompts_dir and pass a relative path; File.expand_path should resolve it.
    abs_path = File.join(@prompts_dir, "job.md")
    result   = scanner.scan_one(abs_path)
    assert_equal File.expand_path(abs_path), result.file_path
  end

  def test_scan_one_returns_correct_schedule
    write_prompt("job.md", schedule: "every weekday at 8am")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    result  = scanner.scan_one(File.join(@prompts_dir, "job.md"))
    assert_equal "every weekday at 8am", result.schedule
  end

  # ---------------------------------------------------------------------------
  # scan_one — error cases
  # ---------------------------------------------------------------------------

  def test_scan_one_raises_when_file_not_found
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    err = assert_raises(Aias::Error) do
      scanner.scan_one(File.join(@prompts_dir, "nonexistent.md"))
    end
    assert_match "not found", err.message
  end

  def test_scan_one_raises_when_file_is_outside_prompts_dir
    other_dir = Dir.mktmpdir("aias_outside_")
    outside   = File.join(other_dir, "outside.md")
    File.write(outside, "---\nschedule: \"0 8 * * *\"\n---\nContent.\n")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    err = assert_raises(Aias::Error) { scanner.scan_one(outside) }
    assert_match "not inside", err.message
  ensure
    FileUtils.remove_entry(other_dir)
  end

  def test_scan_one_raises_when_prompt_has_no_schedule
    write_prompt("no_schedule.md")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    err = assert_raises(Aias::Error) do
      scanner.scan_one(File.join(@prompts_dir, "no_schedule.md"))
    end
    assert_match "no schedule:", err.message
  end

  def test_scan_one_error_message_names_the_prompt_id
    write_prompt("standup.md")
    scanner = Aias::PromptScanner.new(prompts_dir: @prompts_dir)
    err = assert_raises(Aias::Error) do
      scanner.scan_one(File.join(@prompts_dir, "standup.md"))
    end
    assert_match "standup", err.message
  end

  def test_scan_one_raises_when_prompts_dir_is_missing
    scanner = Aias::PromptScanner.new(prompts_dir: "/nonexistent_aias_test_dir")
    assert_raises(Aias::Error) do
      scanner.scan_one("/nonexistent_aias_test_dir/job.md")
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  private

  def write_prompt(relative_path, schedule: nil, parameters: nil)
    full_path = File.join(@prompts_dir, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))

    frontmatter = {}
    frontmatter["schedule"]   = schedule   if schedule
    frontmatter["parameters"] = parameters if parameters

    if frontmatter.empty?
      File.write(full_path, "No schedule here.\n")
    else
      # to_yaml produces "---\nkey: value\n..." — strip the leading marker
      # so we can wrap it in the PM-expected "---\n<body>\n---\n<content>" format
      yaml_body = frontmatter.to_yaml.sub(/\A---\n/, "")
      File.write(full_path, "---\n#{yaml_body}---\nPrompt content.\n")
    end
  end
end
