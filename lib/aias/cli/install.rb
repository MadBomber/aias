# frozen_string_literal: true

module Aias
  class CLI
    desc "install [PATTERN...]", "Capture PATH, API keys, and env vars into ~/.config/aia/schedule/env.sh"
    long_desc <<~DESC
      Writes the current session's PATH, all *_API_KEY and AIA_PROMPTS__DIR
      environment variables into ~/.config/aia/schedule/env.sh so scheduled
      aia jobs have a correct PATH (including MCP server binaries) and can
      authenticate with LLM APIs. This file is sourced by every cron entry.

      Optional PATTERN arguments add extra env vars whose names match the given
      glob pattern(s). Quote patterns to prevent shell expansion:

        aias install 'AIA_*'
        aias install 'AIA_*' 'OPENROUTER_*'
    DESC
    def install(*patterns)
      env_vars = ENV.select { |k, _| k.end_with?("_API_KEY") || k.start_with?("AIA_") }
      env_vars["PATH"]   = ENV["PATH"]
      env_vars["LANG"]   = ENV["LANG"]   if ENV["LANG"]
      env_vars["LC_ALL"] = ENV["LC_ALL"] if ENV["LC_ALL"]

      patterns.flat_map(&:split).map(&:upcase).each do |pattern|
        ENV.each { |k, v| env_vars[k] = v if File.fnmatch(pattern, k) }
      end

      env_file.install(env_vars)
      installed = env_vars.keys.sort
      say "aias: installed #{installed.join(', ')} into #{Paths::SCHEDULE_ENV}"

      FileUtils.mkdir_p(AIA_SCHEDULE_DIR, mode: 0o700)

      unless File.exist?(AIA_SCHEDULE_CFG)
        if File.exist?(AIA_CONFIG_SRC)
          FileUtils.cp(AIA_CONFIG_SRC, AIA_SCHEDULE_CFG)
          say "aias: copied #{AIA_CONFIG_SRC} → #{AIA_SCHEDULE_CFG}"
        else
          say "aias: #{AIA_CONFIG_SRC} not found — create #{AIA_SCHEDULE_CFG} manually"
        end
        say ""
        say "Review #{AIA_SCHEDULE_CFG} — these settings apply to all scheduled prompts."
        say "Prompt frontmatter overrides any setting in that file."
      end

      if ENV["AIA_PROMPTS__DIR"]
        dir = File.expand_path(ENV["AIA_PROMPTS__DIR"])
        if ScheduleConfig.new.set_prompts_dir(dir)
          say "aias: set prompts.dir=#{dir} in #{AIA_SCHEDULE_CFG}"
        end
      end
    rescue Aias::Error => e
      say_error "aias [error] #{e.message}"
      exit(1)
    end
  end
end
