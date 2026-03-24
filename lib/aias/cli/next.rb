# frozen_string_literal: true

module Aias
  class CLI
    desc "next [N]", "Show next scheduled run time for installed jobs (default 5)"
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
  end
end
