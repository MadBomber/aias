# frozen_string_literal: true

module Aias
  class CLI
    desc "version", "Print the aias version"
    def version
      say Aias::VERSION
    end
  end
end
