# frozen_string_literal: true

require "yaml"

module Aias
  class CLI < Thor
    def self.exit_on_failure? = true

    class_option :prompts_dir,
      type:    :string,
      aliases: "-p",
      desc:    "Prompts directory (overrides AIA_PROMPTS__DIR / AIA_PROMPTS_DIR env vars)"

    # ---------------------------------------------------------------------------
    # update
    # ---------------------------------------------------------------------------

    desc "update", "Scan prompts, regenerate all crontab entries, and install"
    def update
      results = scanner.scan
      valid, invalid = partition_results(results)

      invalid.each do |r, vr|
        $stderr.puts "aias [skip] #{r.prompt_id}: #{vr.errors.join('; ')}"
      end

      if valid.empty?
        say "aias: no valid scheduled prompts found — crontab not changed"
        return
      end

      cron_lines = valid.map { |r, _vr| builder.build(r, prompts_dir: options[:prompts_dir]) }
      manager.ensure_log_directories(valid.map { |r, _vr| r.prompt_id })
      manager.install(cron_lines)

      say "aias: installed #{valid.size} job(s)" \
          "#{invalid.empty? ? '' : ", skipped #{invalid.size} invalid"}"
    rescue Aias::Error => e
      say_error "aias [error] #{e.message}"
      exit(1)
    end

    # ---------------------------------------------------------------------------
    # add
    # ---------------------------------------------------------------------------

    desc "add PATH", "Add (or replace) a single scheduled prompt in the crontab"
    def add(path)
      absolute = File.expand_path(path)
      unless File.file?(absolute) && absolute.end_with?(".md")
        say_error "aias [error] '#{path}' must be an existing .md file"
        exit(1)
      end
      prompts_dir = effective_prompts_dir_for(absolute)
      result      = PromptScanner.new(prompts_dir: prompts_dir).scan_one(absolute)
      vr          = validator.validate(result)

      unless vr.valid?
        say_error "aias [error] #{result.prompt_id}: #{vr.errors.join('; ')}"
        exit(1)
      end

      cron_line = builder.build(result, prompts_dir: prompts_dir)
      manager.ensure_log_directories([result.prompt_id])
      manager.add_job(cron_line, result.prompt_id)
      say "aias: added #{result.prompt_id} (#{CronDescriber.display(result.schedule)})"
    rescue Aias::Error => e
      say_error "aias [error] #{e.message}"
      exit(1)
    end

    # ---------------------------------------------------------------------------
    # remove
    # ---------------------------------------------------------------------------

    map "rm"     => :remove
    map "delete" => :remove
    desc "remove PROMPT_ID", "Remove a single scheduled prompt from the crontab"
    def remove(prompt_id)
      manager.remove_job(prompt_id)
      say "aias: removed #{prompt_id}"
    rescue Aias::Error => e
      say_error "aias [error] #{e.message}"
      exit(1)
    end

    # ---------------------------------------------------------------------------
    # install
    # ---------------------------------------------------------------------------

    AIA_CONFIG_SRC   = File.expand_path("~/.config/aia/aia.yml")
    AIA_SCHEDULE_DIR = File.expand_path("~/.config/aia/schedule")
    AIA_SCHEDULE_CFG = File.expand_path("~/.config/aia/schedule/aia.yml")

    map "ins" => :install
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
      say "aias: installed #{installed.join(', ')} into #{EnvFile::PATH}"

      FileUtils.mkdir_p(AIA_SCHEDULE_DIR)

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

      inject_prompts_dir(File.expand_path(ENV["AIA_PROMPTS__DIR"])) if ENV["AIA_PROMPTS__DIR"]
    rescue Aias::Error => e
      say_error "aias [error] #{e.message}"
      exit(1)
    end

    # ---------------------------------------------------------------------------
    # uninstall
    # ---------------------------------------------------------------------------

    map "unins" => :uninstall
    desc "uninstall", "Remove managed env block from ~/.config/aia/schedule/env.sh (schedule config preserved)"
    def uninstall
      env_file.uninstall
      say "aias: env vars removed from #{EnvFile::PATH}"
      say "      #{AIA_SCHEDULE_DIR} is unchanged"
    rescue Aias::Error => e
      say_error "aias [error] #{e.message}"
      exit(1)
    end

    # ---------------------------------------------------------------------------
    # clear
    # ---------------------------------------------------------------------------

    desc "clear", "Remove all aias-managed crontab entries"
    def clear
      manager.clear
      say "aias: all managed crontab entries removed"
    end

    # ---------------------------------------------------------------------------
    # list
    # ---------------------------------------------------------------------------

    desc "list", "List all installed aias cron jobs"
    def list
      jobs = manager.installed_jobs
      if jobs.empty?
        say "aias: no installed jobs"
        return
      end

      say format("%-30s  %-40s  %s", "PROMPT ID", "SCHEDULE", "LOG")
      say "-" * 100
      jobs.each do |job|
        say format("%-30s  %-40s  %s", job[:prompt_id], Aias::CronDescriber.display(job[:cron_expr]), job[:log_path])
      end
    end

    # ---------------------------------------------------------------------------
    # check
    # ---------------------------------------------------------------------------

    desc "check", "Diff view: scheduled prompts vs what is installed"
    def check
      results   = scanner.scan
      installed = manager.installed_jobs
      installed_ids = installed.map { |j| j[:prompt_id] }.to_set

      valid, invalid = partition_results(results)
      discovered_ids = valid.map { |r, _| r.prompt_id }.to_set

      new_jobs      = discovered_ids - installed_ids
      orphaned_jobs = installed_ids  - discovered_ids

      say "=== aias check ==="
      say ""

      unless invalid.empty?
        say "INVALID (would be skipped by update):"
        invalid.each { |r, vr| say "  #{r.prompt_id}: #{vr.errors.join('; ')}" }
        say ""
      end

      unless new_jobs.empty?
        say "NEW (not yet installed — run `aias update`):"
        new_jobs.each do |id|
          r = valid.find { |result, _| result.prompt_id == id }&.first
          sched = r ? "  #{CronDescriber.display(r.schedule)}" : ""
          say "  + #{id}#{sched}"
        end
        say ""
      end

      unless orphaned_jobs.empty?
        say "ORPHANED (installed but no longer scheduled):"
        orphaned_jobs.each { |id| say "  - #{id}" }
        say ""
      end

      if invalid.empty? && new_jobs.empty? && orphaned_jobs.empty?
        say "OK — crontab is in sync with scheduled prompts"
      end
    rescue Aias::Error => e
      say_error "aias [error] #{e.message}"
      exit(1)
    end

    # ---------------------------------------------------------------------------
    # dry-run  (Thor cannot define a method named dry-run; map the alias)
    # ---------------------------------------------------------------------------

    desc "dry-run", "Show what `update` would write without touching the crontab"
    map "dry-run" => :dry_run
    def dry_run
      results = scanner.scan
      valid, invalid = partition_results(results)

      invalid.each { |r, vr| $stderr.puts "aias [skip] #{r.prompt_id}: #{vr.errors.join('; ')}" }

      if valid.empty?
        say "aias: no valid scheduled prompts found"
        return
      end

      cron_lines = valid.map { |r, _vr| builder.build(r) }
      say manager.dry_run(cron_lines)
    rescue Aias::Error => e
      say_error "aias [error] #{e.message}"
      exit(1)
    end

    # ---------------------------------------------------------------------------
    # next  (conflicts with Ruby keyword; map the alias)
    # ---------------------------------------------------------------------------

    desc "next [N]", "Show next scheduled run time for installed jobs (default 5)"
    map "next" => :upcoming
    def upcoming(n = "5")
      jobs = manager.installed_jobs.first(n.to_i)

      if jobs.empty?
        say "aias: no installed jobs"
        return
      end

      now = Time.now
      jobs.each do |job|
        cron      = Fugit.parse_cronish(job[:cron_expr])
        next_time = cron ? cron.next_time(now).localtime.to_s : "unknown (invalid cron expression)"
        say "#{job[:prompt_id]}"
        say "  schedule : #{CronDescriber.display(job[:cron_expr])}"
        say "  next run : #{next_time}"
        say "  log      : #{job[:log_path]}"
        say ""
      end

      say "(Pass N as argument to show N entries.)"
    end

    # ---------------------------------------------------------------------------
    # last  (`last` is not a keyword but map the alias for consistency)
    # ---------------------------------------------------------------------------

    desc "last [N]", "Show last-run time for installed jobs (default 5)"
    map "last" => :last_run
    def last_run(n = "5")
      jobs = manager.installed_jobs.first(n.to_i)

      if jobs.empty?
        say "aias: no installed jobs"
        return
      end

      jobs.each do |job|
        log_stat = File.exist?(job[:log_path]) ? File.mtime(job[:log_path]).to_s : "never run"
        say "#{job[:prompt_id]}"
        say "  schedule : #{CronDescriber.display(job[:cron_expr])}"
        say "  last run : #{log_stat}"
        say "  log      : #{job[:log_path]}"
        say ""
      end

      say "(Pass N as argument to show N entries. Last-run time is derived from the log file modification timestamp.)"
    end

    # ---------------------------------------------------------------------------
    # show
    # ---------------------------------------------------------------------------

    desc "show PROMPT_ID", "Show the installed crontab entry for a single prompt"
    def show(prompt_id)
      job = manager.installed_jobs.find { |j| j[:prompt_id] == prompt_id }
      if job
        say "prompt_id : #{job[:prompt_id]}"
        say "schedule  : #{CronDescriber.display(job[:cron_expr])}"
        say "log       : #{job[:log_path]}"
      else
        say "aias: '#{prompt_id}' is not currently installed"
        exit(1)
      end
    end

    # ---------------------------------------------------------------------------
    # help — appends crontab reference when listing all commands
    # ---------------------------------------------------------------------------

    def help(command = nil, subcommand: false)
      super
      return if command

      say ""
      say "Crontab commands:"
      say "  crontab -l               # view current crontab"
      say "  crontab -e               # edit crontab in $EDITOR"
      say "  EDITOR=nano crontab -e   # edit with a specific editor"
      say "  crontab -r               # remove entire crontab"
    end

    private

    # Lazy collaborator accessors — allows injection in tests via instance
    # variable assignment before invoking a command.
    def scanner   = @scanner   ||= PromptScanner.new(prompts_dir: options[:prompts_dir])
    def validator = @validator ||= Validator.new
    def builder   = @builder   ||= JobBuilder.new(config_file: AIA_SCHEDULE_CFG)
    def manager   = @manager   ||= CrontabManager.new
    def env_file  = @env_file  ||= EnvFile.new

    # Splits results into [valid, invalid] where each element is [result, validation_result].
    def partition_results(results)
      pairs = results.map { |r| [r, validator.validate(r)] }
      pairs.partition { |_r, vr| vr.valid? }
    end

    # Determines the effective prompts directory for `aias add`:
    #
    # 1. The --prompts-dir CLI option, when given explicitly.
    # 2. The AIA_PROMPTS__DIR / AIA_PROMPTS_DIR env var, when the file lives
    #    inside that directory.
    # 3. The file's immediate parent directory — allows adding any prompt by
    #    absolute path without requiring a pre-configured prompts directory.
    #
    # Case 3 means `aias add ./example_prompts/standup.md` works even when
    # AIA_PROMPTS_DIR points elsewhere; the prompt ID becomes just "standup"
    # and the generated cron line embeds --prompts-dir pointing at the file's
    # parent.
    # Ensures the schedule config has prompts.dir set to the given directory.
    # This is necessary because --config-file triggers reset_to_defaults in AIA,
    # which wipes AIA_PROMPTS__DIR from the env var source. Having prompts.dir
    # in the config file itself ensures prompts are found even after that reset.
    # Silently skips if the schedule config does not exist or cannot be parsed.
    def inject_prompts_dir(dir)
      return unless File.exist?(AIA_SCHEDULE_CFG)

      config = YAML.safe_load_file(AIA_SCHEDULE_CFG) || {}
      return if config.dig("prompts", "dir") == dir

      config["prompts"] ||= {}
      config["prompts"]["dir"] = dir
      File.write(AIA_SCHEDULE_CFG, config.to_yaml)
      say "aias: set prompts.dir=#{dir} in #{AIA_SCHEDULE_CFG}"
    rescue StandardError => e
      say "aias: could not update prompts.dir in #{AIA_SCHEDULE_CFG}: #{e.message}"
    end

    def effective_prompts_dir_for(absolute)
      return File.expand_path(options[:prompts_dir]) if options[:prompts_dir]

      env_dir = ENV[PromptScanner::PROMPTS_DIR_ENVVAR_NEW] ||
                ENV[PromptScanner::PROMPTS_DIR_ENVVAR_OLD]
      env_dir = File.expand_path(env_dir) if env_dir

      if env_dir && absolute.start_with?("#{env_dir}/")
        env_dir
      else
        File.dirname(absolute)
      end
    end
  end
end
