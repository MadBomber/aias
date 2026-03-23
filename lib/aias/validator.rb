# frozen_string_literal: true

require "open3"

module Aias
  class Validator
    # Immutable value object returned by #validate.
    ValidationResult = Data.define(:valid?, :errors)

    def initialize(shell: ENV.fetch("SHELL", "/bin/bash"))
      @shell = shell
    end

    # Returns a ValidationResult for the given PromptScanner::Result.
    def validate(scanner_result)
      errors = []
      errors.concat(check_schedule_syntax(scanner_result.schedule))
      errors.concat(check_parameters(scanner_result.metadata))
      errors.concat(aia_binary_errors)
      ValidationResult.new(valid?: errors.empty?, errors: errors)
    end

    private

    # Validates the schedule string by trying to evaluate a minimal whenever
    # DSL fragment. Raw cron expressions (matching REGEX) are quoted; all
    # other strings are used as the argument to `every` directly.
    def check_schedule_syntax(schedule)
      dsl = build_validation_dsl(schedule)
      Whenever.cron(string: dsl)
      []
    rescue StandardError, ScriptError => e
      ["Schedule '#{schedule}': #{e.message}"]
    end

    # Builds a minimal whenever DSL string for validation purposes.
    def build_validation_dsl(schedule)
      arg = cron_expression?(schedule) ? "'#{schedule}'" : schedule
      "every #{arg} do\n  command 'true'\nend\n"
    end

    # Returns true when the string is a raw cron expression or cron keyword.
    def cron_expression?(schedule)
      schedule.match?(Whenever::Output::Cron::REGEX)
    end

    # Validates that all parameter keys have non-nil, non-empty default values.
    # Scheduled prompts run unattended — interactive input is impossible.
    def check_parameters(metadata)
      params = metadata.parameters
      return [] if params.nil?

      errors = []
      params.each do |key, value|
        if value.nil? || value.to_s.strip.empty?
          errors << "Parameter '#{key}' has no default value (required for unattended cron execution)"
        end
      end
      errors
    end

    # Checks that `aia` is locatable in the login-shell PATH.
    # Results are cached per Validator instance (shell spawn is expensive).
    def aia_binary_errors
      return @aia_binary_errors if defined?(@aia_binary_errors)

      _out, _err, status = Open3.capture3(@shell, "-l", "-c", "which aia")
      @aia_binary_errors = status.success? ? [] : ["aia binary not found in #{@shell} login shell PATH"]
    end
  end
end
