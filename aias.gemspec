# frozen_string_literal: true

require_relative "lib/aias/version"

Gem::Specification.new do |spec|
  spec.name = "aias"
  spec.version = Aias::VERSION
  spec.authors = ["Dewayne VanHoozer"]
  spec.email = ["dewayne@vanhoozer.me"]

  spec.summary = "Schedule AIA prompts as cron jobs — no config file, just frontmatter"
  spec.description = <<~DESC
    aias turns AIA prompt files into unattended cron jobs. Add a schedule: key
    to any prompt's YAML frontmatter and run `aias update` to install the full
    set, or `aias add <path>` to install a single prompt without touching the
    rest. Schedules accept raw cron expressions or natural-language strings
    ("every weekday at 9am"). Each job runs as a fresh `aia` process under your
    login shell and appends its output to a per-prompt log under
    ~/.aia/schedule/logs/. Prompts are self-describing — no separate
    configuration file is needed.
  DESC
  spec.homepage = "https://github.com/madbomber/aias"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "aia"
  spec.add_dependency "prompt_manager"
  spec.add_dependency "fugit"
  spec.add_dependency "thor"
  spec.add_dependency "zeitwerk"
end
