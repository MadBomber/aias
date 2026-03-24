# frozen_string_literal: true

module Aias
  class CLI
    desc "add PATH", "Add (or replace) a single scheduled prompt in the crontab"
    def add(path)
      absolute = File.expand_path(path)
      unless File.file?(absolute) && absolute.end_with?(".md")
        say_error "aias [error] '#{path}' must be an existing .md file"
        exit(1)
      end
      prompts_dir = effective_prompts_dir_for(absolute)
      result      = PromptScanner.new(prompts_dir: prompts_dir).scan_one(absolute)
      vr          = validator.validate(result)

      unless vr.valid?
        say_error "aias [error] #{result.prompt_id}: #{vr.errors.join('; ')}"
        exit(1)
      end

      cron_line = builder.build(result, prompts_dir: prompts_dir)
      manager.ensure_log_directories([result.prompt_id])
      manager.add_job(cron_line, result.prompt_id)
      say "aias: added #{result.prompt_id} (#{CronDescriber.display(result.schedule)})"
    rescue Aias::Error => e
      say_error "aias [error] #{e.message}"
      exit(1)
    end
  end
end
