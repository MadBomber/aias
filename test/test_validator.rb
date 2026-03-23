# frozen_string_literal: true

require "test_helper"

class TestValidator < Minitest::Test
  # ---------------------------------------------------------------------------
  # ValidationResult struct
  # ---------------------------------------------------------------------------

  def test_validation_result_has_valid_field
    result = Aias::Validator::ValidationResult.new(valid?: true, errors: [])
    assert result.valid?
  end

  def test_validation_result_has_errors_field
    result = Aias::Validator::ValidationResult.new(valid?: false, errors: ["oops"])
    assert_equal ["oops"], result.errors
  end

  def test_validation_result_struct_is_frozen
    result = Aias::Validator::ValidationResult.new(valid?: true, errors: [])
    assert result.frozen?, "ValidationResult Data instances should be frozen"
  end

  # ---------------------------------------------------------------------------
  # Schedule syntax — valid cron expressions
  # ---------------------------------------------------------------------------

  def test_valid_five_field_cron_expression
    result = validator.validate(build_result(schedule: "0 8 * * *"))
    assert_empty schedule_errors(result)
  end

  def test_valid_cron_at_midnight
    result = validator.validate(build_result(schedule: "0 0 * * *"))
    assert_empty schedule_errors(result)
  end

  def test_valid_cron_keyword_daily
    result = validator.validate(build_result(schedule: "@daily"))
    assert_empty schedule_errors(result)
  end

  def test_valid_cron_keyword_hourly
    result = validator.validate(build_result(schedule: "@hourly"))
    assert_empty schedule_errors(result)
  end

  # ---------------------------------------------------------------------------
  # Schedule syntax — valid natural language (fugit)
  # ---------------------------------------------------------------------------

  def test_valid_natural_language_every_day
    result = validator.validate(build_result(schedule: "every day at 8am"))
    assert_empty schedule_errors(result)
  end

  def test_valid_natural_language_every_weekday
    result = validator.validate(build_result(schedule: "every weekday at 8am"))
    assert_empty schedule_errors(result)
  end

  def test_valid_natural_language_every_monday
    result = validator.validate(build_result(schedule: "every monday at 9am"))
    assert_empty schedule_errors(result)
  end

  def test_valid_natural_language_every_6_hours
    result = validator.validate(build_result(schedule: "every 6 hours"))
    assert_empty schedule_errors(result)
  end

  # ---------------------------------------------------------------------------
  # Schedule syntax — invalid
  # ---------------------------------------------------------------------------

  def test_invalid_schedule_produces_error
    result = validator.validate(build_result(schedule: "every banana"))
    refute_empty schedule_errors(result)
  end

  def test_invalid_schedule_error_includes_schedule_string
    result = validator.validate(build_result(schedule: "every banana"))
    assert_match "every banana", schedule_errors(result).first
  end

  def test_invalid_cron_too_few_fields
    result = validator.validate(build_result(schedule: "0 8 *"))
    refute_empty schedule_errors(result)
  end

  # ---------------------------------------------------------------------------
  # Parameter completeness
  # ---------------------------------------------------------------------------

  def test_nil_parameters_passes
    metadata = PM::Metadata.new("schedule" => "0 8 * * *", "parameters" => nil)
    result = validator.validate(build_result(metadata: metadata))
    assert_empty parameter_errors(result)
  end

  def test_parameters_all_with_defaults_passes
    metadata = PM::Metadata.new(
      "schedule" => "0 8 * * *",
      "parameters" => { "topic" => "AI news", "format" => "bullet points" }
    )
    result = validator.validate(build_result(metadata: metadata))
    assert_empty parameter_errors(result)
  end

  def test_parameter_with_nil_value_fails
    metadata = PM::Metadata.new(
      "schedule" => "0 8 * * *",
      "parameters" => { "topic" => nil }
    )
    result = validator.validate(build_result(metadata: metadata))
    refute_empty parameter_errors(result)
  end

  def test_parameter_with_empty_string_fails
    metadata = PM::Metadata.new(
      "schedule" => "0 8 * * *",
      "parameters" => { "topic" => "" }
    )
    result = validator.validate(build_result(metadata: metadata))
    refute_empty parameter_errors(result)
  end

  def test_parameter_error_names_the_key
    metadata = PM::Metadata.new(
      "schedule" => "0 8 * * *",
      "parameters" => { "missing_key" => nil }
    )
    result = validator.validate(build_result(metadata: metadata))
    assert_match "missing_key", parameter_errors(result).first
  end

  def test_multiple_bad_parameters_each_produce_an_error
    metadata = PM::Metadata.new(
      "schedule" => "0 8 * * *",
      "parameters" => { "a" => nil, "b" => "" }
    )
    result = validator.validate(build_result(metadata: metadata))
    assert_equal 2, parameter_errors(result).size
  end

  # ---------------------------------------------------------------------------
  # AIA binary check — real binaries, no stubs
  # ---------------------------------------------------------------------------

  def test_aia_binary_found_produces_no_error
    # Use "ruby" which is guaranteed to be present in the test environment.
    v = Aias::Validator.new(binary_to_check: "ruby")
    result = v.validate(build_result)
    assert_empty binary_errors(result)
  end

  def test_aia_binary_missing_produces_error
    v = Aias::Validator.new(binary_to_check: "definitely_no_such_binary_aias_xyz_abc")
    result = v.validate(build_result)
    refute_empty binary_errors(result)
  end

  def test_aia_binary_error_message_mentions_binary_name
    v = Aias::Validator.new(binary_to_check: "definitely_no_such_binary_aias_xyz_abc")
    result = v.validate(build_result)
    assert_match "definitely_no_such_binary_aias_xyz_abc", binary_errors(result).first
  end

  def test_aia_binary_check_is_cached
    v = Aias::Validator.new(binary_to_check: "ruby")
    v.validate(build_result)
    # After the first validate call, the cache ivar must be set.
    assert v.instance_variable_defined?(:@aia_binary_errors),
      "Binary check result should be memoised after first validate"
    # A second validate call must return a consistent result.
    result2 = v.validate(build_result)
    assert result2.valid?, "Cached binary check should produce consistent validation result"
  end

  # ---------------------------------------------------------------------------
  # AIA binary check — fallback directory scan
  # ---------------------------------------------------------------------------

  def test_binary_found_in_fallback_dir_passes_when_shell_check_fails
    Dir.mktmpdir("aias_fallback_test_") do |dir|
      # Create a fake executable in the tmpdir.
      fake_bin = File.join(dir, "fake_aia_binary_xyz")
      File.write(fake_bin, "#!/bin/sh\nexit 0")
      File.chmod(0o755, fake_bin)

      # Use a nonexistent shell so the login-shell which check always fails,
      # but provide the tmpdir as a fallback location.
      v = Aias::Validator.new(
        shell: "/no/such/shell",
        binary_to_check: "fake_aia_binary_xyz",
        fallback_dirs: [dir]
      )
      result = v.validate(build_result)
      assert_empty binary_errors(result),
        "Binary found in fallback dir should produce no error"
    end
  end

  def test_binary_missing_from_both_shell_and_fallback_dirs_produces_error
    Dir.mktmpdir("aias_fallback_empty_") do |empty_dir|
      v = Aias::Validator.new(
        shell: "/no/such/shell",
        binary_to_check: "definitely_no_such_binary_aias_xyz_abc",
        fallback_dirs: [empty_dir]
      )
      result = v.validate(build_result)
      refute_empty binary_errors(result),
        "Binary missing from shell and fallback dirs should produce an error"
    end
  end

  def test_fallback_error_message_mentions_binary_name
    Dir.mktmpdir("aias_fallback_msg_") do |empty_dir|
      v = Aias::Validator.new(
        shell: "/no/such/shell",
        binary_to_check: "definitely_no_such_binary_aias_xyz_abc",
        fallback_dirs: [empty_dir]
      )
      result = v.validate(build_result)
      assert_match "definitely_no_such_binary_aias_xyz_abc", binary_errors(result).first
    end
  end

  def test_non_executable_file_in_fallback_dir_does_not_count
    Dir.mktmpdir("aias_fallback_noexec_") do |dir|
      # File exists but is NOT executable.
      fake_bin = File.join(dir, "fake_aia_binary_xyz")
      File.write(fake_bin, "#!/bin/sh\nexit 0")
      File.chmod(0o644, fake_bin)

      v = Aias::Validator.new(
        shell: "/no/such/shell",
        binary_to_check: "fake_aia_binary_xyz",
        fallback_dirs: [dir]
      )
      result = v.validate(build_result)
      refute_empty binary_errors(result),
        "Non-executable file in fallback dir should not satisfy the binary check"
    end
  end

  # ---------------------------------------------------------------------------
  # Overall validity
  # ---------------------------------------------------------------------------

  def test_valid_result_when_all_checks_pass
    result = validator.validate(build_result)
    assert result.valid?
    assert_empty result.errors
  end

  def test_invalid_result_when_schedule_bad
    result = validator.validate(build_result(schedule: "not a valid schedule xyz"))
    refute result.valid?
    refute_empty result.errors
  end

  def test_invalid_result_when_binary_missing
    v = Aias::Validator.new(binary_to_check: "definitely_no_such_binary_aias_xyz_abc")
    result = v.validate(build_result)
    refute result.valid?
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  private

  # Default validator uses "ruby" as the binary so the check always passes
  # without requiring aia to be installed in the test environment.
  def validator
    @validator ||= Aias::Validator.new(binary_to_check: "ruby")
  end

  def schedule_errors(result)
    result.errors.select { |e| e.include?("Schedule") || e.match?(/banana|field|cron/i) }
  end

  def parameter_errors(result)
    result.errors.select { |e| e.include?("Parameter") }
  end

  def binary_errors(result)
    result.errors.reject { |e| e.include?("Schedule") || e.include?("Parameter") }
  end
end
