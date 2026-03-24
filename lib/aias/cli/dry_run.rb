# frozen_string_literal: true

module Aias
  class CLI
    desc "dry-run", "Show what `update` would write without touching the crontab"
    def dry_run
      results = scanner.scan
      valid, invalid = partition_results(results)

      invalid.each { |r, vr| $stderr.puts "aias [skip] #{r.prompt_id}: #{vr.errors.join('; ')}" }

      if valid.empty?
        say "aias: no valid scheduled prompts found"
        return
      end

      cron_lines = valid.map { |r, _vr| builder.build(r) }
      say manager.dry_run(cron_lines)
    rescue Aias::Error => e
      say_error "aias [error] #{e.message}"
      exit(1)
    end
  end
end
