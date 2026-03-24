# frozen_string_literal: true

module Aias
  class CLI
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
  end
end
