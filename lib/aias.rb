# frozen_string_literal: true

require "zeitwerk"
require "thor"
require "fugit"
require "pm"

require_relative "aias/version"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect("cli" => "CLI")
loader.ignore("#{__dir__}/aias/cli")
loader.setup

module Aias
  class Error < StandardError; end
end
