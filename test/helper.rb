# Copyright 2016 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  # rubocop:disable Style/StderrPuts
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  # rubocop:enable Style/StderrPuts
  exit e.status_code
end
require 'test/unit'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'fluent/test'
unless ENV.key?('VERBOSE')
  nulllogger = Object.new
  nulllogger.instance_eval do |_|
    def respond_to_missing?(_method, _include_private = false)
      true
    end

    def method_missing(_method, *_args)
      # pass
    end
  end
  # global $log variable is used by fluentd
  $log = nulllogger # rubocop:disable Style/GlobalVars
end

require 'fluent/plugin/out_detect_exceptions'
