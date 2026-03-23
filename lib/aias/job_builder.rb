# frozen_string_literal: true

module Aias
  class JobBuilder
    LOG_BASE = File.expand_path("~/.aia/schedule/logs")

    def initialize(shell: ENV.fetch("SHELL", "/bin/bash"))
      @shell = shell
    end

    # Returns the complete whenever DSL string for a single scheduled prompt.
    # The string is suitable for passing to Whenever.cron(string: ...) or
    # appending to a combined DSL passed to CrontabManager#install.
    def build(scanner_result)
      prompt_id = scanner_result.prompt_id
      schedule  = scanner_result.schedule
      log       = log_path_for(prompt_id)

      <<~DSL
        set :job_template, "#{shell_binary} -l -c ':job'"
        job_type :aia_job, "aia :task :output"
        every #{schedule_arg(schedule)} do
          aia_job "#{prompt_id}", output: "#{log}"
        end
      DSL
    end

    # Returns the log file path for a given prompt_id.
    # Mirrors the subdirectory structure of the prompt_id.
    # e.g. "reports/weekly" → "~/.aia/schedule/logs/reports/weekly.log"
    def log_path_for(prompt_id)
      File.join(LOG_BASE, "#{prompt_id}.log")
    end

    private

    # Returns the shell binary path from ENV['SHELL'].
    # Falls back to /bin/bash if SHELL is not set or empty.
    def shell_binary
      return "/bin/bash" if @shell.nil? || @shell.strip.empty?
      @shell.strip
    end

    # Wraps raw cron expressions in single quotes so whenever passes them
    # through as literal cron syntax. Whenever DSL fragments (e.g. "1.day"
    # or "1.day, at: '8:00am'") are used as-is since they are valid Ruby
    # evaluated in the context of Whenever::JobList.
    def schedule_arg(schedule)
      cron_expression?(schedule) ? "'#{schedule}'" : schedule
    end

    def cron_expression?(schedule)
      schedule.match?(Whenever::Output::Cron::REGEX)
    end
  end
end
