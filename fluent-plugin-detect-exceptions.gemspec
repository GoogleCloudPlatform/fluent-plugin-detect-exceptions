Gem::Specification.new do |gem|
  gem.name          = 'fluent-plugin-detect-exceptions'
  gem.description   = <<-eos
   Fluentd output plugin which detects exception stack traces in a stream of
   JSON log messages and combines all single-line messages that belong to the
   same stack trace into one multi-line message.
   This is an official Google Ruby gem.
eos
  gem.summary       = \
    'fluentd output plugin for combining stack traces as multi-line JSON logs'
  gem.homepage      = \
    'https://github.com/GoogleCloudPlatform/fluent-plugin-detect-exceptions'
  gem.license       = 'Apache-2.0'
  gem.version       = '0.0.14'
  gem.authors       = ['Stackdriver Agents']
  gem.email         = ['stackdriver-agents@google.com']
  gem.required_ruby_version = Gem::Requirement.new('>= 2.0')

  gem.files         = Dir['**/*'].keep_if { |file| File.file?(file) }
  gem.test_files    = gem.files.grep(/^(test)/)
  gem.require_paths = ['lib']

  gem.add_runtime_dependency 'fluentd', '>= 0.10'

  gem.add_development_dependency 'rake', '~> 10.3'
  gem.add_development_dependency 'rubocop', '= 0.42.0'
  gem.add_development_dependency 'test-unit', '~> 3.0'
  gem.add_development_dependency 'flexmock', '~> 2.0'
end
