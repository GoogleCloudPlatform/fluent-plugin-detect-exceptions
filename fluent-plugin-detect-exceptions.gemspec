Gem::Specification.new do |gem|
  gem.name          = 'fluent-plugin-detect-exceptions'
  gem.description   = <<-DESCRIPTION
   Fluentd output plugin which detects exception stack traces in a stream of
   JSON log messages and combines all single-line messages that belong to the
   same stack trace into one multi-line message.
   This is an official Google Ruby gem.
  DESCRIPTION
  gem.summary       = \
    'fluentd output plugin for combining stack traces as multi-line JSON logs'
  gem.homepage      = \
    'https://github.com/GoogleCloudPlatform/fluent-plugin-detect-exceptions'
  gem.license       = 'Apache-2.0'
  gem.version       = '0.0.16'
  gem.authors       = ['Stackdriver Agents']
  gem.email         = ['stackdriver-agents@google.com']
  gem.required_ruby_version = Gem::Requirement.new('>= 2.6')

  gem.files         = Dir['**/*'].keep_if { |file| File.file?(file) }
  gem.test_files    = gem.files.grep(/^(test)/)
  gem.require_paths = ['lib']

  gem.add_runtime_dependency 'fluentd', '>= 1.14.2'

  gem.add_development_dependency 'flexmock', '~> 2.0'
  gem.add_development_dependency 'rake', '~> 10.3'
  gem.add_development_dependency 'rubocop', '= 1.48.1'
  gem.add_development_dependency 'test-unit', '~> 3.0'
end
