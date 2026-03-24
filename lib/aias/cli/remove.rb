# frozen_string_literal: true

module Aias
  class CLI
    desc "remove PROMPT_ID", "Remove a single scheduled prompt from the crontab"
    def remove(prompt_id)
      manager.remove_job(prompt_id)
      say "aias: removed #{prompt_id}"
    rescue Aias::Error => e
      say_error "aias [error] #{e.message}"
      exit(1)
    end
  end
end
