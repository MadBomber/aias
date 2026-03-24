# frozen_string_literal: true

require "fileutils"

module Aias
  # Manages a shell env file (~/.config/aia/schedule/env.sh) using a
  # BEGIN/END block so user content above or below the block is preserved.
  #
  # The file is sourced by every cron entry before the aia command, giving
  # scheduled jobs a controlled PATH and all necessary env vars (API keys,
  # AIA_PROMPTS__DIR, etc.) without relying on crontab env vars or a login
  # shell that would reset PATH via path_helper.
  class EnvFile
    include BlockParser
    BLOCK_OPEN  = "# BEGIN aias-env"
    BLOCK_CLOSE = "# END aias-env"

    def initialize(path: Paths::SCHEDULE_ENV)
      @path = path
    end

    # Writes env_vars into the managed block (merge — new values win on conflict).
    # env_vars is a Hash of { "KEY" => "value" }.
    # Chmod 0600 is applied by write so API keys are never world-readable.
    def install(env_vars)
      FileUtils.mkdir_p(File.dirname(@path), mode: 0o700)
      merged = parse_block(current_block).merge(env_vars)
      lines  = merged.map { |k, v| "export #{k}=\"#{v}\"" }
      write(replace_block(read, lines))
    end

    # Removes the managed block from the file.
    # Deletes the file entirely when no other content remains.
    def uninstall
      content = strip_block(read, BLOCK_OPEN, BLOCK_CLOSE)
      if content.strip.empty?
        File.delete(@path) if File.exist?(@path)
      else
        write(content)
      end
    end

    # Returns the raw content of the managed block (markers excluded).
    # Returns an empty string when no block exists.
    def current_block
      extract_block(read, BLOCK_OPEN, BLOCK_CLOSE)
    end

    private

    def read
      File.exist?(@path) ? File.read(@path) : ""
    end

    def write(content)
      File.write(@path, content)
      FileUtils.chmod(0o600, @path)
    end

    def replace_block(content, export_lines)
      cleaned   = strip_block(content, BLOCK_OPEN, BLOCK_CLOSE)
      new_block = ([BLOCK_OPEN] + export_lines + [BLOCK_CLOSE]).join("\n") + "\n"
      cleaned.empty? ? new_block : new_block + "\n" + cleaned.lstrip
    end

    # Parses `export KEY="value"` lines into { "KEY" => "value" }.
    def parse_block(block_content)
      block_content.each_line.each_with_object({}) do |line, h|
        if (m = line.chomp.match(/\Aexport\s+(\w+)="(.*)"\z/))
          h[m[1]] = m[2]
        end
      end
    end
  end
end
