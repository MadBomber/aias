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
    PATH = File.expand_path("~/.config/aia/schedule/env.sh")

    BLOCK_OPEN  = "# BEGIN aias-env"
    BLOCK_CLOSE = "# END aias-env"

    def initialize(path: PATH)
      @path = path
    end

    # Writes env_vars into the managed block (merge — new values win on conflict).
    # env_vars is a Hash of { "KEY" => "value" }.
    # Chmod 0600 is applied so API keys are not world-readable.
    def install(env_vars)
      FileUtils.mkdir_p(File.dirname(@path))
      merged = parse_block(current_block).merge(env_vars)
      lines  = merged.map { |k, v| "export #{k}=\"#{v}\"" }
      write(replace_block(read, lines))
      FileUtils.chmod(0o600, @path)
    end

    # Removes the managed block from the file.
    # Deletes the file entirely when no other content remains.
    def uninstall
      content = strip_block(read)
      if content.strip.empty?
        File.delete(@path) if File.exist?(@path)
      else
        write(content)
      end
    end

    # Returns the raw content of the managed block (markers excluded).
    # Returns an empty string when no block exists.
    def current_block
      extract_block(read)
    end

    private

    def read
      File.exist?(@path) ? File.read(@path) : ""
    end

    def write(content)
      File.write(@path, content)
    end

    def extract_block(content)
      in_block = false
      lines    = []
      content.each_line do |line|
        if line.chomp == BLOCK_OPEN
          in_block = true
        elsif line.chomp == BLOCK_CLOSE
          in_block = false
        elsif in_block
          lines << line
        end
      end
      lines.join
    end

    def strip_block(content)
      in_block = false
      lines    = content.each_line.reject do |line|
        if line.chomp == BLOCK_OPEN
          in_block = true
        elsif line.chomp == BLOCK_CLOSE
          in_block = false
        else
          next in_block
        end
        true
      end
      lines.join
    end

    def replace_block(content, export_lines)
      cleaned   = strip_block(content)
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
