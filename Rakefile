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
# https://github.com/GoogleCloudPlatform/fluent-plugin-detect-exceptions/issues/32
desc 'Fix file permissions'
task :fix_perms do
  files = [
    'lib/fluent/plugin/*.rb'
  ].flat_map do |file|
    file.include?('*') ? Dir.glob(file) : [file]
  end

  files.each do |file|
    mode = File.stat(file).mode & 0o777
    next unless mode & 0o444 != 0o444

    puts "Changing mode of #{file} from #{mode.to_s(8)} to "\
         "#{(mode | 0o444).to_s(8)}"
    chmod mode | 0o444, file
  end
end

desc 'Run unit tests and RuboCop to check for style violations'
task all: %i[rubocop test fix_perms]

task default: :all
