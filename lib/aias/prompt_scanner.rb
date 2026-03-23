# frozen_string_literal: true

require "open3"

module Aias
  class PromptScanner
    # Immutable value object representing one discovered scheduled prompt.
    Result = Data.define(:prompt_id, :schedule, :metadata, :file_path)

    def initialize(prompts_dir: ENV["AIA_PROMPTS_DIR"])
      @prompts_dir = prompts_dir.to_s
    end

    # Returns Array<Result> of all prompts with a non-empty schedule: key.
    # Raises Aias::Error if the prompts directory is missing or unreadable.
    def scan
      validate_prompts_dir!
      candidate_files.filter_map { |path| build_result(path) }
    end

    private

    def validate_prompts_dir!
      if @prompts_dir.empty?
        raise Aias::Error, "AIA_PROMPTS_DIR is not set"
      end
      unless File.directory?(@prompts_dir)
        raise Aias::Error, "AIA_PROMPTS_DIR '#{@prompts_dir}' does not exist"
      end
      unless File.readable?(@prompts_dir)
        raise Aias::Error, "AIA_PROMPTS_DIR '#{@prompts_dir}' is not readable"
      end
    end

    # Runs grep -rl via Open3 to avoid shell injection.
    # Returns [] when nothing matches (grep exits non-zero with no results).
    def candidate_files
      out, _err, _status = Open3.capture3("grep", "-rl", "schedule:", @prompts_dir)
      out.lines.map(&:chomp).reject(&:empty?)
    end

    # Strips the prompts_dir prefix and .md suffix to produce a prompt ID.
    # e.g. "/home/user/.prompts/reports/weekly.md" → "reports/weekly"
    def prompt_id_for(absolute_path)
      base = @prompts_dir.chomp("/")
      relative = absolute_path.delete_prefix("#{base}/")
      relative.delete_suffix(".md")
    end

    # Parses the file via PM and returns a Result if schedule: is present.
    # Returns nil (filter_map drops it) if schedule is absent or empty.
    # Warns to stderr and returns nil if PM.parse raises.
    def build_result(absolute_path)
      parsed   = PM.parse(absolute_path)
      schedule = parsed.metadata.schedule
      return nil if schedule.nil? || schedule.to_s.strip.empty?

      Result.new(
        prompt_id: prompt_id_for(absolute_path),
        schedule:  schedule.to_s.strip,
        metadata:  parsed.metadata,
        file_path: absolute_path
      )
    rescue => e
      warn "aias: skipping #{absolute_path}: #{e.message}"
      nil
    end
  end
end
