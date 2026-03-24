# frozen_string_literal: true

module Aias
  class CLI
    desc "clear", "Remove all aias-managed crontab entries"
    def clear
      manager.clear
      say "aias: all managed crontab entries removed"
    end
  end
end
