#!/usr/bin/env rake

require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'
require 'rubocop/rake_task'

desc 'Run Rubocop to check for style violations'
RuboCop::RakeTask.new

desc 'Run benchmark tests'
Rake::TestTask.new(:bench) do |test|
  test.libs << 'lib' << 'test'
  test.test_files = FileList['test/plugin/bench*.rb']
  test.verbose = true
end

desc 'Run unit tests'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.test_files = FileList['test/plugin/test*.rb']
  test.verbose = true
end

# Building the gem will use the local file mode, so ensure it's world-readable.
desc 'Check plugin file permissions'
task :check_perms do
  plugin = 'lib/fluent/plugin/out_detect_exceptions.rb'
  mode = File.stat(plugin).mode & 0o777
  raise "Unexpected mode #{mode.to_s(8)} for #{plugin}" unless
    mode & 0o444 == 0o444
end

desc 'Run unit tests and RuboCop to check for style violations'
task all: [:test, :rubocop, :check_perms]

task default: :all
