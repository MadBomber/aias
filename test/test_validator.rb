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
    result = validator_with_aia.validate(build_result(schedule: "0 8 * * *"))
    assert_empty schedule_errors(result)
  end

  def test_valid_cron_at_midnight
    result = validator_with_aia.validate(build_result(schedule: "0 0 * * *"))
    assert_empty schedule_errors(result)
  end

  def test_valid_cron_keyword_daily
    result = validator_with_aia.validate(build_result(schedule: "@daily"))
    assert_empty schedule_errors(result)
  end

  def test_valid_cron_keyword_hourly
    result = validator_with_aia.validate(build_result(schedule: "@hourly"))
    assert_empty schedule_errors(result)
  end

  # ---------------------------------------------------------------------------
  # Schedule syntax — valid whenever DSL
  # ---------------------------------------------------------------------------

  def test_valid_whenever_numeric_day
    result = validator_with_aia.validate(build_result(schedule: "1.day"))
    assert_empty schedule_errors(result)
  end

  def test_valid_whenever_day_at_time
    result = validator_with_aia.validate(build_result(schedule: "1.day, at: '8:00am'"))
    assert_empty schedule_errors(result)
  end

  def test_valid_whenever_hours
    result = validator_with_aia.validate(build_result(schedule: "6.hours"))
    assert_empty schedule_errors(result)
  end

  def test_valid_whenever_symbol_weekday
    result = validator_with_aia.validate(build_result(schedule: ":monday, at: '9:00am'"))
    assert_empty schedule_errors(result)
  end

  # ---------------------------------------------------------------------------
  # Schedule syntax — invalid
  # ---------------------------------------------------------------------------

  def test_invalid_schedule_produces_error
    result = validator_with_aia.validate(build_result(schedule: "every banana"))
    refute_empty schedule_errors(result)
  end

  def test_invalid_schedule_error_includes_schedule_string
    result = validator_with_aia.validate(build_result(schedule: "every banana"))
    assert_match "every banana", schedule_errors(result).first
  end

  def test_invalid_cron_too_few_fields
    result = validator_with_aia.validate(build_result(schedule: "0 8 *"))
    refute_empty schedule_errors(result)
  end

  # ---------------------------------------------------------------------------
  # Parameter completeness
  # ---------------------------------------------------------------------------

  def test_nil_parameters_passes
    metadata = PM::Metadata.new("schedule" => "0 8 * * *", "parameters" => nil)
    result = validator_with_aia.validate(build_result(metadata: metadata))
    assert_empty parameter_errors(result)
  end

  def test_parameters_all_with_defaults_passes
    metadata = PM::Metadata.new(
      "schedule" => "0 8 * * *",
      "parameters" => { "topic" => "AI news", "format" => "bullet points" }
    )
    result = validator_with_aia.validate(build_result(metadata: metadata))
    assert_empty parameter_errors(result)
  end

  def test_parameter_with_nil_value_fails
    metadata = PM::Metadata.new(
      "schedule" => "0 8 * * *",
      "parameters" => { "topic" => nil }
    )
    result = validator_with_aia.validate(build_result(metadata: metadata))
    refute_empty parameter_errors(result)
  end

  def test_parameter_with_empty_string_fails
    metadata = PM::Metadata.new(
      "schedule" => "0 8 * * *",
      "parameters" => { "topic" => "" }
    )
    result = validator_with_aia.validate(build_result(metadata: metadata))
    refute_empty parameter_errors(result)
  end

  def test_parameter_error_names_the_key
    metadata = PM::Metadata.new(
      "schedule" => "0 8 * * *",
      "parameters" => { "missing_key" => nil }
    )
    result = validator_with_aia.validate(build_result(metadata: metadata))
    assert_match "missing_key", parameter_errors(result).first
  end

  def test_multiple_bad_parameters_each_produce_an_error
    metadata = PM::Metadata.new(
      "schedule" => "0 8 * * *",
      "parameters" => { "a" => nil, "b" => "" }
    )
    result = validator_with_aia.validate(build_result(metadata: metadata))
    assert_equal 2, parameter_errors(result).size
  end

  # ---------------------------------------------------------------------------
  # AIA binary check — stubbed
  # ---------------------------------------------------------------------------

  def test_aia_binary_found_produces_no_error
    validator = validator_with_aia
    result = validator.validate(build_result)
    assert_empty binary_errors(result)
  end

  def test_aia_binary_missing_produces_error
    validator = validator_without_aia
    result = validator.validate(build_result)
    refute_empty binary_errors(result)
  end

  def test_aia_binary_error_message_mentions_aia
    validator = validator_without_aia
    result = validator.validate(build_result)
    assert_match "aia", binary_errors(result).first
  end

  def test_aia_binary_check_is_cached
    call_count = 0
    status = Object.new
    status.define_singleton_method(:success?) { call_count += 1; true }
    validator = Aias::Validator.new(shell: "/bin/bash")

    Open3.stub(:capture3, ["", "", status]) do
      validator.validate(build_result)
      validator.validate(build_result)
    end

    assert_equal 1, call_count, "Binary check should be called only once per Validator instance"
  end

  # ---------------------------------------------------------------------------
  # Overall validity
  # ---------------------------------------------------------------------------

  def test_valid_result_when_all_checks_pass
    result = validator_with_aia.validate(build_result)
    assert result.valid?
    assert_empty result.errors
  end

  def test_invalid_result_when_schedule_bad
    result = validator_with_aia.validate(build_result(schedule: "not a valid schedule xyz"))
    refute result.valid?
    refute_empty result.errors
  end

  def test_invalid_result_when_aia_missing
    result = validator_without_aia.validate(build_result)
    refute result.valid?
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  private

  # A Validator whose aia binary check always succeeds (Open3 stubbed).
  def validator_with_aia
    stub_aia_check(exit_success: true)
  end

  # A Validator whose aia binary check always fails.
  def validator_without_aia
    stub_aia_check(exit_success: false)
  end

  def stub_aia_check(exit_success:)
    status = Object.new
    status.define_singleton_method(:success?) { exit_success }
    validator = Aias::Validator.new(shell: "/bin/bash")
    Open3.stub(:capture3, ["", "", status]) do
      validator.send(:aia_binary_errors)  # populate cache inside the stub
    end
    validator
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
