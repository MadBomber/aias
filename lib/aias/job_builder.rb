# frozen_string_literal: true

module Aias
  class JobBuilder
    def initialize(shell: ENV.fetch("SHELL", "/bin/bash"), aia_path: nil, env_file: nil, config_file: nil)
      @shell       = shell
      @aia_path    = aia_path || 'aia'
      @env_file    = env_file || Paths::SCHEDULE_ENV
      @config_file = config_file
    end

    # Returns a single cron line string for the given scanner result, e.g.:
    #   0 8 * * * /bin/bash -c 'source ~/.config/aia/schedule/env.sh && /path/to/aia --prompts-dir /path --config ~/.config/aia/schedule/aia.yml daily_digest > ~/.config/aia/schedule/logs/daily_digest.log 2>&1'
    #
    # env.sh is sourced first to set PATH, API keys, etc. All flags come before
    # the prompt ID. config_file selects the schedule-specific AIA config.
    # prompts_dir sets the directory AIA searches for the prompt file.
    def build(scanner_result, prompts_dir: nil)
      cron_expr    = resolved_cron(scanner_result.schedule)
      prompt_id    = scanner_result.prompt_id
      log          = log_path_for(prompt_id)
      prompts_flag = prompts_dir ? %( --prompts-dir "#{File.expand_path(prompts_dir)}") : ""
      config_flag  = @config_file ? %( --config "#{@config_file}") : ""
      cmd          = %(source "#{@env_file}" && #{@aia_path}#{prompts_flag}#{config_flag} #{prompt_id} > "#{log}" 2>&1)
      "#{cron_expr} #{shell_binary} -c '#{cmd}'"
    end

    # Returns the log file path for a given prompt_id.
    # Mirrors the subdirectory structure of the prompt_id.
    # e.g. "reports/weekly" → "~/.config/aia/schedule/logs/reports/weekly.log"
    def log_path_for(prompt_id)
      File.join(Paths::SCHEDULE_LOG, "#{prompt_id}.log")
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

  end
end
