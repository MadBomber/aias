# frozen_string_literal: true

module Aias
  # Shared block-parsing logic for classes that manage BEGIN/END marker blocks
  # inside text files (crontab, env.sh).  Both CrontabManager and EnvFile
  # include this module and pass their own marker constants.
  module BlockParser
    private

    # Returns lines between open_marker and close_marker (markers excluded).
    def extract_block(content, open_marker, close_marker)
      in_block = false
      lines    = []
      content.each_line do |line|
        if line.chomp == open_marker
          in_block = true
        elsif line.chomp == close_marker
          in_block = false
        elsif in_block
          lines << line
        end
      end
      lines.join
    end

    # Returns content with every line from open_marker through close_marker
    # (inclusive) removed.  Lines outside the block are preserved as-is.
    def strip_block(content, open_marker, close_marker)
      in_block = false
      content.each_line.reject do |line|
        if line.chomp == open_marker
          in_block = true
        elsif line.chomp == close_marker
          in_block = false
        else
          next in_block
        end
        true
      end.join
    end
  end
end
