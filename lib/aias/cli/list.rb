# frozen_string_literal: true

module Aias
  class CLI
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
  end
end
