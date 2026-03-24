# frozen_string_literal: true

module Aias
  class CLI
    desc "update", "Scan prompts, regenerate all crontab entries, and install"
    def update
      results = scanner.scan
      valid, invalid = partition_results(results)

      invalid.each do |r, vr|
        $stderr.puts "aias [skip] #{r.prompt_id}: #{vr.errors.join('; ')}"
      end

      if valid.empty?
        say "aias: no valid scheduled prompts found — crontab not changed"
        return
      end

      cron_lines = valid.map { |r, _vr| builder.build(r, prompts_dir: options[:prompts_dir]) }
      manager.ensure_log_directories(valid.map { |r, _vr| r.prompt_id })
      manager.install(cron_lines)

      say "aias: installed #{valid.size} job(s)" \
          "#{invalid.empty? ? '' : ", skipped #{invalid.size} invalid"}"
    rescue Aias::Error => e
      say_error "aias [error] #{e.message}"
      exit(1)
    end
  end
end
