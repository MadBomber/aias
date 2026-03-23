# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "aias"

# Eager-load all Zeitwerk-managed files so SimpleCov instruments every class,
# including those that would otherwise be loaded lazily on first reference.
Zeitwerk::Loader.eager_load_all

require "minitest/autorun"

# Shared factory for building PromptScanner::Result test fixtures.
# Used by tests for Validator, JobBuilder, CrontabManager, and CLI
# so those tests do not depend on PromptScanner actually running.
def build_result(prompt_id: "daily_digest", schedule: "0 8 * * *", metadata: nil)
  metadata ||= PM::Metadata.new("schedule" => schedule)
  Aias::PromptScanner::Result.new(
    prompt_id: prompt_id,
    schedule:  schedule,
    metadata:  metadata,
    file_path: "/tmp/#{prompt_id}.md"
  )
end
