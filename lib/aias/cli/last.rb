# frozen_string_literal: true

module Aias
  class CLI
    desc "last [N]", "Show last-run time for installed jobs (default 5)"
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
  end
end
