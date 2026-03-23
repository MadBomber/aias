# frozen_string_literal: true

module Aias
  class JobBuilder
    LOG_BASE = File.expand_path("~/.aia/schedule/logs")

    def initialize(shell: ENV.fetch("SHELL", "/bin/bash"), prompts_dir: nil)
      @shell       = shell
      @prompts_dir = prompts_dir
    end

    # Returns a single cron line string for the given scanner result, e.g.:
    #   0 8 * * * /bin/bash -l -c 'aia daily_digest >> ~/.aia/schedule/logs/daily_digest.log 2>&1'
    def build(scanner_result)
      cron_expr = resolved_cron(scanner_result.schedule)
      prompt_id = scanner_result.prompt_id
      log       = log_path_for(prompt_id)
      cmd       = "aia #{prompts_dir_flag}#{prompt_id} >> #{log} 2>&1"
      "#{cron_expr} #{shell_binary} -l -c '#{cmd}'"
    end

    # Returns the log file path for a given prompt_id.
    # Mirrors the subdirectory structure of the prompt_id.
    # e.g. "reports/weekly" → "~/.aia/schedule/logs/reports/weekly.log"
    def log_path_for(prompt_id)
      File.join(LOG_BASE, "#{prompt_id}.log")
    end

    private

    # Resolves the schedule string to a canonical 5-field cron expression
    # via fugit. Accepts both raw cron expressions and natural language.
    # Raises Aias::Error if the schedule cannot be resolved — this should
    # not happen in practice since Validator rejects invalid schedules first.
    def resolved_cron(schedule)
      cron = Fugit.parse_cronish(schedule)
      raise Aias::Error, "Cannot resolve schedule '#{schedule}' to a cron expression" unless cron

      cron.to_cron_s
    end

    # Returns the shell binary path. Falls back to /bin/bash if SHELL is unset.
    def shell_binary
      return "/bin/bash" if @shell.nil? || @shell.strip.empty?

      @shell.strip
    end

    # Returns "--prompts-dir DIR " (with trailing space) when a prompts_dir was
    # provided, or an empty string when it was not. Always uses an absolute path.
    def prompts_dir_flag
      return "" if @prompts_dir.nil? || @prompts_dir.strip.empty?

      "--prompts-dir #{File.expand_path(@prompts_dir)} "
    end
  end
end
