# frozen_string_literal: true

require "yaml"

module Aias
  class CLI < Thor
    def self.exit_on_failure? = true

    class_option :prompts_dir,
      type:    :string,
      aliases: "-p",
      desc:    "Prompts directory (overrides AIA_PROMPTS__DIR / AIA_PROMPTS_DIR env vars)"

    AIA_CONFIG_SRC   = Paths::AIA_CONFIG
    AIA_SCHEDULE_DIR = Paths::SCHEDULE_DIR
    AIA_SCHEDULE_CFG = Paths::SCHEDULE_CFG

    # Aliases
    map "-v"        => :version
    map "--version" => :version
    map "ins"     => :install
    map "unins"   => :uninstall
    map "rm"      => :remove
    map "delete"  => :remove
    map "dry-run" => :dry_run
    map "next"    => :upcoming
    map "last"    => :last_run

    # ---------------------------------------------------------------------------
    # help — appends crontab reference when listing all commands
    # ---------------------------------------------------------------------------

    def help(command = nil, subcommand = false)
      super
      return if command

      say ""
      say "Crontab commands:"
      say "  crontab -l               # view current crontab"
      say "  crontab -e               # edit crontab in $EDITOR"
      say "  EDITOR=nano crontab -e   # edit with a specific editor"
      say "  crontab -r               # remove entire crontab"
    end

    private

    # Lazy collaborator accessors — allows injection in tests via instance
    # variable assignment before invoking a command.
    def scanner   = @scanner   ||= PromptScanner.new(prompts_dir: options[:prompts_dir])
    def validator = @validator ||= Validator.new
    def builder   = @builder   ||= JobBuilder.new(config_file: AIA_SCHEDULE_CFG)
    def manager   = @manager   ||= CrontabManager.new
    def env_file  = @env_file  ||= EnvFile.new

    # Splits results into [valid, invalid] where each element is [result, validation_result].
    def partition_results(results)
      pairs = results.map { |r| [r, validator.validate(r)] }
      pairs.partition { |_r, vr| vr.valid? }
    end

    # Determines the effective prompts directory for `aias add`.
    # See full description in cli/add.rb.
    def effective_prompts_dir_for(absolute)
      return File.expand_path(options[:prompts_dir]) if options[:prompts_dir]

      env_dir = ENV[PromptScanner::PROMPTS_DIR_ENVVAR_NEW] ||
                ENV[PromptScanner::PROMPTS_DIR_ENVVAR_OLD]
      env_dir = File.expand_path(env_dir) if env_dir

      if env_dir && absolute.start_with?("#{env_dir}/")
        env_dir
      else
        File.dirname(absolute)
      end
    end
  end
end

require_relative "cli/update"
require_relative "cli/add"
require_relative "cli/remove"
require_relative "cli/install"
require_relative "cli/uninstall"
require_relative "cli/clear"
require_relative "cli/list"
require_relative "cli/check"
require_relative "cli/dry_run"
require_relative "cli/next"
require_relative "cli/last"
require_relative "cli/show"
require_relative "cli/version"
