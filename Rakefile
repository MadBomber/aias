# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

# SimpleCov must be required and started BEFORE minitest/autorun registers its
# at_exit hook. Ruby runs at_exit handlers in LIFO order, so whichever gem
# calls at_exit last will run first. We want:
#   1. Minitest at_exit → tests execute
#   2. SimpleCov at_exit → results collected after tests finish
#
# Achieving this requires SimpleCov to register its at_exit first (i.e. load
# before minitest/autorun). The test_prelude is prepended to the -e string
# before 'require "minitest/autorun"', giving us the correct ordering.
SIMPLECOV_PRELUDE = <<~RUBY.tr("\n", ";")
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
    enable_coverage :branch
  end
RUBY

Minitest::TestTask.create do |t|
  t.test_prelude = "#{SIMPLECOV_PRELUDE} require \"minitest/autorun\"; "
end

task default: :test
