# frozen_string_literal: true

module Aias
  class CLI
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
  end
end
