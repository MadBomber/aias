# frozen_string_literal: true

require "yaml"

module Aias
  # Manages ~/.config/aia/schedule/aia.yml — the AIA config file used by all
  # scheduled cron jobs. Provides targeted updates without clobbering user
  # settings already in the file.
  class ScheduleConfig
    def initialize(path: Paths::SCHEDULE_CFG)
      @path = path
    end

    # Sets prompts.dir in the config file to +dir+ if it is not already that value.
    # Returns true when the file was updated, false when already correct or file absent.
    # Raises Aias::Error on YAML parse failure or write error.
    def set_prompts_dir(dir)
      return false unless File.exist?(@path)

      config = YAML.safe_load_file(@path) || {}
      return false if config.dig("prompts", "dir") == dir

      config["prompts"]        ||= {}
      config["prompts"]["dir"]   = dir
      File.write(@path, config.to_yaml)
      true
    rescue Psych::Exception => e
      raise Aias::Error, "could not update prompts.dir in #{@path}: #{e.message}"
    end
  end
end
