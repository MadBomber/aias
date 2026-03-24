# frozen_string_literal: true

module Aias
  # Single source of truth for all filesystem paths used by aias.
  # Every class that needs a path should reference Aias::Paths rather than
  # defining its own constant.
  module Paths
    AIA_CONFIG   = File.expand_path("~/.config/aia/aia.yml")
    SCHEDULE_DIR = File.expand_path("~/.config/aia/schedule")
    SCHEDULE_CFG = File.expand_path("~/.config/aia/schedule/aia.yml")
    SCHEDULE_LOG = File.expand_path("~/.config/aia/schedule/logs")
    SCHEDULE_ENV = File.expand_path("~/.config/aia/schedule/env.sh")
  end
end
