# frozen_string_literal: true

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

      cron_lines = valid.map { |r, _vr| builder.build(r) }
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
      result = scanner.scan_one(path)
      vr     = validator.validate(result)

      unless vr.valid?
        say_error "aias [error] #{result.prompt_id}: #{vr.errors.join('; ')}"
        exit(1)
      end

      cron_line = builder.build(result)
      manager.ensure_log_directories([result.prompt_id])
      manager.add_job(cron_line, result.prompt_id)
      say "aias: added #{result.prompt_id} (#{CronDescriber.display(result.schedule)})"
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

    desc "next [N]", "Show schedule and last-run time for installed jobs (default 5)"
    map "next" => :upcoming
    def upcoming(n = "5")
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

    private

    # Lazy collaborator accessors — allows injection in tests via instance
    # variable assignment before invoking a command.
    def scanner   = @scanner   ||= PromptScanner.new(prompts_dir: options[:prompts_dir])
    def validator = @validator ||= Validator.new
    def builder   = @builder   ||= JobBuilder.new(prompts_dir: options[:prompts_dir])
    def manager   = @manager   ||= CrontabManager.new

    # Splits results into [valid, invalid] where each element is [result, validation_result].
    def partition_results(results)
      pairs = results.map { |r| [r, validator.validate(r)] }
      pairs.partition { |_r, vr| vr.valid? }
    end
  end
end
