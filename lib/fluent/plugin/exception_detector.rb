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
#
module Fluent
  Struct.new('Rule', :from_states, :pattern, :to_state)

  # Configuration of the state machine that detects exceptions.
  module ExceptionDetectorConfig
    # Rule for a state transition: if pattern matches go to the given state.
    class RuleTarget
      attr_accessor :pattern, :to_state

      def initialize(pattern, state)
        @pattern = pattern
        @to_state = state
      end

      def ==(other)
        other.class == self.class && other.state == state
      end

      alias eql? ==

      def hash
        state.hash
      end

      def state
        [@pattern, @to_state]
      end
    end

    def self.rule(from_state_or_states, pattern, to_state)
      from_state_or_states = [from_state_or_states] unless
        from_state_or_states.is_a?(Array)
      Struct::Rule.new(from_state_or_states, pattern, to_state)
    end

    def self.supported
      RULES_BY_LANG.keys
    end

    JAVA_RULES = [
      rule(%i[start_state java_start_exception],
           /(?:Exception|Error|Throwable|V8 errors stack trace)[:\r\n]/,
           :java_after_exception),
      rule(:java_after_exception, /^[\t ]*nested exception is:[\t ]*/,
           :java_start_exception),
      rule(:java_after_exception, /^[\r\n]*$/, :java_after_exception),
      rule(%i[java_after_exception java], /^[\t ]+(?:eval )?at /, :java),

      rule(%i[java_after_exception java],
           # C# nested exception.
           /^[\t ]+--- End of inner exception stack trace ---$/,
           :java),

      rule(%i[java_after_exception java],
           # C# exception from async code.
           /^--- End of stack trace from previous (?x:
           )location where exception was thrown ---$/,
           :java),

      rule(%i[java_after_exception java], /^[\t ]*(?:Caused by|Suppressed):/,
           :java_after_exception),
      rule(%i[java_after_exception java],
           /^[\t ]*... \d+ (?:more|common frames omitted)/, :java)
    ].freeze

    PYTHON_RULES = [
      rule(:start_state, /^Traceback \(most recent call last\):$/, :python),
      rule(:python, /^[\t ]+File /, :python_code),
      rule(:python_code, /[^\t ]/, :python),
      rule(:python, /^(?:[^\s.():]+\.)*[^\s.():]+:/, :start_state)
    ].freeze

    PHP_RULES = [
      rule(:start_state, /
        (?:PHP\ (?:Notice|Parse\ error|Fatal\ error|Warning):)|
        (?:exception\ '[^']+'\ with\ message\ ')/x, :php_stack_begin),
      rule(:php_stack_begin, /^Stack trace:/, :php_stack_frames),
      rule(:php_stack_frames, /^#\d/, :php_stack_frames),
      rule(:php_stack_frames, /^\s+thrown in /, :start_state)
    ].freeze

    GO_RULES = [
      rule(:start_state, /\bpanic: /, :go_after_panic),
      rule(:start_state, /http: panic serving/, :go_goroutine),
      rule(:go_after_panic, /^$/, :go_goroutine),
      rule(%i[go_after_panic go_after_signal go_frame_line1],
           /^$/, :go_goroutine),
      rule(:go_after_panic, /^\[signal /, :go_after_signal),
      rule(:go_goroutine, /^goroutine \d+ \[[^\]]+\]:$/, :go_frame_line1),
      rule(:go_frame_line1, /^(?:[^\s.:]+\.)*[^\s.():]+\(|^created by /,
           :go_frame_line2),
      rule(:go_frame_line2, /^\s/, :go_frame_line1)
    ].freeze

    RUBY_RULES = [
      rule(:start_state, /Error \(.*\):$/, :ruby_before_rails_trace),
      rule(:ruby_before_rails_trace, /^  $/, :ruby),
      rule(:ruby_before_rails_trace, /^[\t ]+.*?\.rb:\d+:in `/, :ruby),
      rule(:ruby, /^[\t ]+.*?\.rb:\d+:in `/, :ruby)
    ].freeze

    DART_RULES = [
      rule(:start_state, /^Unhandled exception:$/, :dart_exc),
      rule(:dart_exc, /^Instance of/, :dart_stack),
      rule(:dart_exc, /^Exception/, :dart_stack),
      rule(:dart_exc, /^Bad state/, :dart_stack),
      rule(:dart_exc, /^IntegerDivisionByZeroException/, :dart_stack),
      rule(:dart_exc, /^Invalid argument/, :dart_stack),
      rule(:dart_exc, /^RangeError/, :dart_stack),
      rule(:dart_exc, /^Assertion failed/, :dart_stack),
      rule(:dart_exc, /^Cannot instantiate/, :dart_stack),
      rule(:dart_exc, /^Reading static variable/, :dart_stack),
      rule(:dart_exc, /^UnimplementedError/, :dart_stack),
      rule(:dart_exc, /^Unsupported operation/, :dart_stack),
      rule(:dart_exc, /^Concurrent modification/, :dart_stack),
      rule(:dart_exc, /^Out of Memory/, :dart_stack),
      rule(:dart_exc, /^Stack Overflow/, :dart_stack),
      rule(:dart_exc, /^'.+?':.+?$/, :dart_type_err_line1),
      rule(:dart_type_err_line1, /^#\d+\s+.+?\(.+?\)$/, :dart_stack),
      rule(:dart_type_err_line1, /^.+?$/, :dart_type_err_line2),
      rule(:dart_type_err_line2, /^.*?\^.*?$/, :dart_type_err_line3),
      rule(:dart_type_err_line3, /^$/, :dart_type_err_line4),
      rule(:dart_type_err_line4, /^$/, :dart_stack),
      rule(:dart_exc, /^FormatException/, :dart_format_err_line1),
      rule(:dart_format_err_line1, /^#\d+\s+.+?\(.+?\)$/, :dart_stack),
      rule(:dart_format_err_line1, /^./, :dart_format_err_line2),
      rule(:dart_format_err_line2, /^.*?\^/, :dart_format_err_line3),
      rule(:dart_format_err_line3, /^$/, :dart_stack),
      rule(:dart_exc, /^NoSuchMethodError:/, :dart_method_err_line1),
      rule(:dart_method_err_line1, /^Receiver:/, :dart_method_err_line2),
      rule(:dart_method_err_line2, /^Tried calling:/, :dart_method_err_line3),
      rule(:dart_method_err_line3, /^Found:/, :dart_stack),
      rule(:dart_method_err_line3, /^#\d+\s+.+?\(.+?\)$/, :dart_stack),
      rule(:dart_stack, /^#\d+\s+.+?\(.+?\)$/, :dart_stack),
      rule(:dart_stack, /^<asynchronous suspension>$/, :dart_stack)
    ].freeze

    ALL_RULES = (
      JAVA_RULES + PYTHON_RULES + PHP_RULES + GO_RULES + RUBY_RULES + DART_RULES
    ).freeze

    RULES_BY_LANG = {
      java: JAVA_RULES,
      javascript: JAVA_RULES,
      js: JAVA_RULES,
      csharp: JAVA_RULES,
      py: PYTHON_RULES,
      python: PYTHON_RULES,
      php: PHP_RULES,
      go: GO_RULES,
      rb: RUBY_RULES,
      ruby: RUBY_RULES,
      dart: DART_RULES,
      all: ALL_RULES
    }.freeze

    DEFAULT_FIELDS = %w[message log].freeze
  end

  # State machine that consumes individual log lines and detects
  # multi-line stack traces.
  class ExceptionDetector
    def initialize(*languages)
      @state = :start_state
      @rules = Hash.new { |h, k| h[k] = [] }

      languages = [:all] if languages.empty?

      languages.each do |lang|
        rule_config =
          ExceptionDetectorConfig::RULES_BY_LANG.fetch(lang.downcase) do |_k|
            raise ArgumentError, "Unknown language: #{lang}"
          end

        rule_config.each do |r|
          target = ExceptionDetectorConfig::RuleTarget.new(r[:pattern],
                                                           r[:to_state])
          r[:from_states].each do |from_state|
            @rules[from_state] << target
          end
        end
      end

      @rules.each_value(&:uniq!)
    end

    # Updates the state machine and returns the trace detection status:
    # - no_trace: 'line' does not belong to an exception trace,
    # - start_trace: 'line' starts a detected exception trace,
    # - inside: 'line' is part of a detected exception trace,
    # - end: the detected exception trace ends after 'line'.
    def update(line)
      trace_seen_before = transition(line)
      # If the state machine fell back to the start state because there is no
      # defined transition for 'line', trigger another state transition because
      # 'line' may contain the beginning of another exception.
      transition(line) unless trace_seen_before
      new_state = @state
      trace_seen_after = new_state != :start_state

      case [trace_seen_before, trace_seen_after]
      when [true, true]
        :inside_trace
      when [true, false]
        :end_trace
      when [false, true]
        :start_trace
      else
        :no_trace
      end
    end

    def reset
      @state = :start_state
    end

    private

    # Executes a transition of the state machine for the given line.
    # Returns false if the line does not match any transition rule and the
    # state machine was reset to the initial state.
    def transition(line)
      @rules[@state].each do |r|
        next unless line =~ r.pattern

        @state = r.to_state
        return true
      end
      @state = :start_state
      false
    end
  end

  # Buffers and groups log records if they contain exception stack traces.
  class TraceAccumulator
    attr_reader :buffer_start_time

    # If message_field is nil, the instance is set up to accumulate
    # records that are plain strings (i.e. the whole record is concatenated).
    # Otherwise, the instance accepts records that are dictionaries (usually
    # originating from structured JSON logs) and accumulates just the
    # content of the given message field.
    # message_field may contain the empty string. In this case, the
    # TraceAccumulator 'learns' the field name from the first record by checking
    # for some pre-defined common field names of text logs.
    # The option parameter can be used to pass the following parameters:
    # force_line_breaks adds line breaks when combining exception stacks
    # max_lines and max_bytes limit the maximum amount
    # of data to be buffered. The default value 0 indicates 'no limit'.
    def initialize(message_field, languages, **options, &emit_callback)
      @exception_detector = Fluent::ExceptionDetector.new(*languages)
      @message_field = message_field
      @force_line_breaks = options[:force_line_breaks] || false
      @max_lines = options[:max_lines]           || 0
      @max_bytes = options[:max_bytes]           || 0
      @emit = emit_callback
      @messages = []
      @buffer_start_time = Time.now
      @buffer_size = 0
      @first_record = nil
      @first_timestamp = nil
    end

    def push(time_sec, record)
      message = extract_message(record)
      if message.nil?
        @exception_detector.reset
        detection_status = :no_trace
      else
        force_flush if @max_bytes.positive? &&
                       @buffer_size + message.length > @max_bytes
        detection_status = @exception_detector.update(message)
      end

      update_buffer(detection_status, time_sec, record, message)

      force_flush if @max_lines.positive? && @messages.length == @max_lines
    end

    def flush
      case @messages.length
      when 0
        return
      when 1
        @emit.call(@first_timestamp, @first_record)
      else
        combined_message = @messages.join
        if @message_field.nil?
          output_record = combined_message
        else
          output_record = @first_record
          output_record[@message_field] = combined_message
        end
        @emit.call(@first_timestamp, output_record)
      end
      @messages = []
      @first_record = nil
      @first_timestamp = nil
      @buffer_size = 0
    end

    def force_flush
      flush
      @exception_detector.reset
    end

    private

    def extract_message(record)
      if !@message_field.nil? && @message_field.empty?
        ExceptionDetectorConfig::DEFAULT_FIELDS.each do |f|
          if record.key?(f)
            @message_field = f
            break
          end
        end
      end
      @message_field.nil? ? record : record[@message_field]
    end

    def update_buffer(detection_status, time_sec, record, message)
      trigger_emit = %i[no_trace end_trace].include?(detection_status)
      if @messages.empty? && trigger_emit
        @emit.call(time_sec, record)
        return
      end

      case detection_status
      when :inside_trace
        add(time_sec, record, message)
      when :end_trace
        add(time_sec, record, message)
        flush
      when :no_trace
        flush
        add(time_sec, record, message)
        flush
      when :start_trace
        flush
        add(time_sec, record, message)
      end
    end

    def add(time_sec, record, message)
      if @messages.empty?
        @first_record = record unless @message_field.nil?
        @first_timestamp = time_sec
        @buffer_start_time = Time.now
      end
      return if message.nil?

      message_with_line_break =
        if @force_line_breaks && !@messages.empty? && !message.include?("\n")
          "\n#{message}"
        else
          message
        end
      @messages << message_with_line_break
      @buffer_size += message_with_line_break.length
    end
  end
end
