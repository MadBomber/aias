# frozen_string_literal: true

require "open3"

module Aias
  class PromptScanner
    # Immutable value object representing one discovered scheduled prompt.
    Result = Data.define(:prompt_id, :schedule, :metadata, :file_path)

    PROMPTS_DIR_ENVVAR_NEW = "AIA_PROMPTS__DIR"
    PROMPTS_DIR_ENVVAR_OLD = "AIA_PROMPTS_DIR"

    def initialize(prompts_dir: nil)
      @prompts_dir = (prompts_dir || ENV[PROMPTS_DIR_ENVVAR_NEW] || ENV[PROMPTS_DIR_ENVVAR_OLD]).to_s
    end

    # Returns Array<Result> of all prompts with a non-empty schedule: key.
    # Raises Aias::Error if the prompts directory is missing or unreadable.
    def scan
      validate_prompts_dir!
      candidate_files.filter_map { |path| build_result(path) }
    end

    # Parses a single prompt file by path (relative or absolute).
    # Derives the prompt_id using the configured prompts_dir.
    # Raises Aias::Error when the file is missing/unreadable, lies outside
    # the prompts directory, or carries no schedule: in its frontmatter.
    def scan_one(path)
      absolute = File.expand_path(path)

      raise Aias::Error, "Prompt file not found: #{absolute}"    unless File.exist?(absolute)
      raise Aias::Error, "Prompt file not readable: #{absolute}" unless File.readable?(absolute)

      validate_prompts_dir!

      base = @prompts_dir.chomp("/")
      unless absolute.start_with?("#{base}/")
        raise Aias::Error, "'#{absolute}' is not inside the prompts directory '#{@prompts_dir}'"
      end

      parsed, schedule = begin
        p = PM.parse(absolute)
        [p, p.metadata&.schedule]
      rescue => e
        raise Aias::Error, "Failed to parse '#{prompt_id_for(absolute)}': #{e.message}"
      end

      if schedule.nil? || schedule.to_s.strip.empty?
        raise Aias::Error, "'#{prompt_id_for(absolute)}' has no schedule: in its frontmatter"
      end

      Result.new(
        prompt_id: prompt_id_for(absolute),
        schedule:  schedule.to_s.strip,
        metadata:  parsed.metadata,
        file_path: absolute
      )
    end

    private

    def validate_prompts_dir!
      if @prompts_dir.empty?
        raise Aias::Error, "#{PROMPTS_DIR_ENVVAR_NEW} (or #{PROMPTS_DIR_ENVVAR_OLD}) is not set"
      end
      unless File.directory?(@prompts_dir)
        raise Aias::Error, "AIA_PROMPTS_DIR '#{@prompts_dir}' does not exist"
      end
      unless File.readable?(@prompts_dir)
        raise Aias::Error, "AIA_PROMPTS_DIR '#{@prompts_dir}' is not readable"
      end
    end

    # Runs grep via Open3 to avoid shell injection.
    # --include=*.md limits matches to prompt files; -m 1 stops after the first
    # match per file (presence is all we need). Returns [] when nothing matches.
    def candidate_files
      out, _err, _status = Open3.capture3(
        "grep", "-rl", "--include=*.md", "-m", "1", "schedule:", @prompts_dir
      )
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
