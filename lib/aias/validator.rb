# frozen_string_literal: true

require "open3"

module Aias
  class Validator
    # Immutable value object returned by #validate.
    ValidationResult = Data.define(:valid?, :errors)

    # Common locations where version managers install binary shims.
    # Checked as a fallback when the login shell cannot find the binary.
    BINARY_FALLBACK_DIRS = [
      File.expand_path("~/.rbenv/shims"),
      File.expand_path("~/.rbenv/bin"),
      File.expand_path("~/.rvm/bin"),
      File.expand_path("~/.asdf/shims"),
      "/usr/local/bin",
      "/usr/bin",
      "/opt/homebrew/bin"
    ].freeze

    def initialize(
      shell: ENV.fetch("SHELL", "/bin/bash"),
      binary_to_check: "aia",
      fallback_dirs: BINARY_FALLBACK_DIRS
    )
      @shell = shell
      @binary_to_check = binary_to_check
      @fallback_dirs = fallback_dirs
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

    # Validates the schedule string using fugit, which accepts both raw cron
    # expressions and natural language ("every weekday at 8am").
    def check_schedule_syntax(schedule)
      Fugit.parse_cronish(schedule) ? [] : ["Schedule '#{schedule}': not a valid cron expression or natural language schedule"]
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

    # Checks that `aia` is locatable in the login-shell PATH or in a known
    # version-manager shim directory. Results are cached per Validator instance
    # (shell spawn is expensive).
    #
    # Two-tier check:
    #   1. Spawn a login shell and run `which <binary>` — covers the normal case
    #      where the shell profile properly initialises the version manager.
    #   2. If that fails, scan fallback_dirs for an executable file with the
    #      binary name — covers setups where rbenv/rvm/asdf shims are installed
    #      but the login shell profile does not initialise the version manager.
    def aia_binary_errors
      return @aia_binary_errors if defined?(@aia_binary_errors)

      shell_found = begin
        _out, _err, status = Open3.capture3(@shell, "-l", "-c", "which #{@binary_to_check}")
        status.success?
      rescue Errno::ENOENT
        false
      end

      @aia_binary_errors =
        if shell_found || binary_in_fallback_location?
          []
        else
          ["#{@binary_to_check} binary not found in #{@shell} login shell PATH or known version manager directories"]
        end
    end

    # Returns true when an executable named @binary_to_check exists in any of
    # the @fallback_dirs entries.
    def binary_in_fallback_location?
      @fallback_dirs.any? do |dir|
        path = File.join(dir, @binary_to_check)
        File.executable?(path)
      end
    end
  end
end
