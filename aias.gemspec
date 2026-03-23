# frozen_string_literal: true

require_relative "lib/aias/version"

Gem::Specification.new do |spec|
  spec.name = "aias"
  spec.version = Aias::VERSION
  spec.authors = ["Dewayne VanHoozer"]
  spec.email = ["dewayne@vanhoozer.me"]

  spec.summary = "Schedule AIA prompts as cron jobs via frontmatter"
  spec.description = "aias scans AIA prompt files for a schedule: key in YAML frontmatter and installs corresponding crontab entries via the whenever gem. No separate config file needed — prompts are self-describing."
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
  spec.add_dependency "whenever"
  spec.add_dependency "thor"
  spec.add_dependency "zeitwerk"
end
