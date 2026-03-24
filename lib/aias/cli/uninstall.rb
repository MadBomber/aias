# frozen_string_literal: true

module Aias
  class CLI
    desc "uninstall", "Remove managed env block from ~/.config/aia/schedule/env.sh (schedule config preserved)"
    def uninstall
      env_file.uninstall
      say "aias: env vars removed from #{Paths::SCHEDULE_ENV}"
      say "      #{AIA_SCHEDULE_DIR} is unchanged"
    rescue Aias::Error => e
      say_error "aias [error] #{e.message}"
      exit(1)
    end
  end
end
