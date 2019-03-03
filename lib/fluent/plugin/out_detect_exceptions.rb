#
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

require 'fluent/plugin/exception_detector'
require 'fluent/output'

module Fluent
  # This output plugin consumes a log stream of JSON objects which contain
  # single-line log messages. If a consecutive sequence of log messages form
  # an exception stack trace, they forwarded as a single, combined JSON
  # object. Otherwise, the input log data is forwarded as is.
  class DetectExceptionsOutput < Output
    desc 'The field which contains the raw message text in the input JSON data.'
    config_param :message, :string, default: ''
    desc 'The prefix to be removed from the input tag when outputting a record.'
    config_param :remove_tag_prefix, :string, default: ''
    desc 'The prefix to add for detected exceptions.'
    config_param :exception_tag_prefix, :string, default: ''
    desc 'The interval of flushing the buffer for multiline format.'
    config_param :multiline_flush_interval, :time, default: nil
    desc 'Programming languages for which to detect exceptions. Default: all.'
    config_param :languages, :array, value_type: :string, default: []
    desc 'Maximum number of lines to flush (0 means no limit). Default: 1000.'
    config_param :max_lines, :integer, default: 1000
    desc 'Maximum number of bytes to flush (0 means no limit). Default: 0.'
    config_param :max_bytes, :integer, default: 0
    desc 'Separate log streams by this field in the input JSON data.'
    config_param :stream, :string, default: ''

    Fluent::Plugin.register_output('detect_exceptions', self)

    def configure(conf)
      super

      if multiline_flush_interval
        @check_flush_interval = [multiline_flush_interval * 0.1, 1].max
      end

      @languages = languages.map(&:to_sym)

      # Maps log stream tags to a corresponding TraceAccumulator.
      @accumulators = {}
    end

    def start
      super

      if multiline_flush_interval
        @flush_buffer_mutex = Mutex.new
        @stop_check = false
        @thread = Thread.new(&method(:check_flush_loop))
      end
    end

    def before_shutdown
      flush_buffers
      super if defined?(super)
    end

    def shutdown
      # Before shutdown is not available in older fluentd versions.
      # Hence, we make sure that we flush the buffers here as well.
      flush_buffers
      @thread.join if @multiline_flush_interval
      super
    end

    def emit(tag, es, chain)
      es.each do |time_sec, record|
        process_record(tag, time_sec, record)
      end
      chain.next
    end

    private

    def process_record(tag, time_sec, record)
      synchronize do
        log_id = [tag]
        log_id.push(record.fetch(@stream, '')) unless @stream.empty?
        unless @accumulators.key?(log_id)
          new_tag = tag.sub(/^#{Regexp.escape(@remove_tag_prefix)}\./, '')
          @accumulators[log_id] =
            Fluent::TraceAccumulator.new(@message, @languages,
                                         max_lines: @max_lines,
                                         max_bytes: @max_bytes) do |t, r, d|
              out_tag = if d && @exception_tag_prefix != ''
                          "#{@exception_tag_prefix}.#{new_tag}"
                        else
                          new_tag
                        end
              router.emit(out_tag, t, r)
            end
        end

        @accumulators[log_id].push(time_sec, record)
      end
    end

    def flush_buffers
      synchronize do
        @stop_check = true
        @accumulators.each_value(&:force_flush)
      end
    end

    def check_flush_loop
      @flush_buffer_mutex.synchronize do
        loop do
          @flush_buffer_mutex.sleep(@check_flush_interval)
          now = Time.now
          break if @stop_check
          @accumulators.each_value do |acc|
            acc.force_flush if now - acc.buffer_start_time >
                               @multiline_flush_interval
          end
        end
      end
    rescue
      log.error 'error in check_flush_loop', error: $ERROR_INFO.to_s
      log.error_backtrace
    end

    def synchronize(&block)
      if @multiline_flush_interval
        @flush_buffer_mutex.synchronize(&block)
      else
        yield
      end
    end
  end
end
