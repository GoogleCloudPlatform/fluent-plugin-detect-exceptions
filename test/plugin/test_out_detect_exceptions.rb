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

require_relative '../helper'
require 'fluent/plugin/out_detect_exceptions'

class DetectExceptionsOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = <<END.freeze
remove_tag_prefix prefix
END

  DEFAULT_TAG = 'prefix.test.tag'.freeze

  ARBITRARY_TEXT = 'This line is not an exception.'.freeze

  JAVA_EXC = <<END.freeze
Exception: foo
  at bar
END

  PYTHON_EXC = <<END.freeze
Traceback (most recent call last):
  File "/base/data/home/runtimes/python27/python27_lib/versions/third_party/webapp2-2.5.2/webapp2.py", line 1535, in __call__
    rv = self.handle_exception(request, response, e)
Exception: ('spam', 'eggs')
END

  def create_driver(conf = '', tag = DEFAULT_TAG)
    d = Fluent::Test::OutputTestDriver.new(Fluent::DetectExceptionsOutput, tag)
    d.configure(CONFIG + conf)
    d
  end

  def log_entry(message, count, stream)
    log_entry = { 'message' => message, 'count' => count }
    log_entry['stream'] = stream unless stream.nil?
    log_entry
  end

  def feed_lines(driver, t, *messages, stream: nil)
    count = 0
    messages.each do |m|
      m.each_line do |line|
        driver.emit(log_entry(line, count, stream), t + count)
        count += 1
      end
    end
  end

  def run_driver(driver, *messages)
    t = Time.now.to_i
    driver.run do
      feed_lines(driver, t, *messages)
    end
  end

  def make_logs(t, *messages, stream: nil)
    count = 0
    logs = []
    messages.each do |m|
      logs << [t + count, log_entry(m, count, stream)]
      count += m.lines.count
    end
    logs
  end

  def test_configure
    assert_nothing_raised do
      create_driver
    end
  end

  def test_exception_detection
    d = create_driver
    t = Time.now.to_i
    messages = [ARBITRARY_TEXT, JAVA_EXC, ARBITRARY_TEXT]
    d.run do
      feed_lines(d, t, *messages)
    end
    assert_equal(make_logs(t, *messages), d.events)
  end

  def test_single_language_config
    cfg = 'languages java'
    d = create_driver(cfg)
    t = Time.now.to_i
    d.run do
      feed_lines(d, t, ARBITRARY_TEXT, JAVA_EXC, PYTHON_EXC)
    end
    expected = ARBITRARY_TEXT.lines + [JAVA_EXC] + PYTHON_EXC.lines
    assert_equal(make_logs(t, *expected), d.events)
  end

  def test_multi_language_config
    cfg = 'languages python, java'
    d = create_driver(cfg)
    t = Time.now.to_i
    d.run do
      feed_lines(d, t, ARBITRARY_TEXT, JAVA_EXC, PYTHON_EXC)
    end
    expected = ARBITRARY_TEXT.lines + [JAVA_EXC] + [PYTHON_EXC]
    assert_equal(make_logs(t, *expected), d.events)
  end

  def test_split_exception_after_timeout
    cfg = 'multiline_flush_interval 1'
    d = create_driver(cfg)
    t1 = 0
    t2 = 0
    d.run do
      t1 = Time.now.to_i
      feed_lines(d, t1, JAVA_EXC)
      sleep 2
      t2 = Time.now.to_i
      feed_lines(d, t2, "  at x\n  at y\n")
    end
    assert_equal(make_logs(t1, JAVA_EXC) +
                 make_logs(t2, "  at x\n", "  at y\n"),
                 d.events)
  end

  def test_do_not_split_exception_after_pause
    d = create_driver
    t1 = 0
    t2 = 0
    d.run do
      t1 = Time.now.to_i
      feed_lines(d, t1, JAVA_EXC)
      sleep 1
      t2 = Time.now.to_i
      feed_lines(d, t2, "  at x\n  at y\n")
      d.instance.before_shutdown
    end
    assert_equal(make_logs(t1, JAVA_EXC + "  at x\n  at y\n"), d.events)
  end

  def get_out_tags(remove_tag_prefix, original_tag)
    cfg = "remove_tag_prefix #{remove_tag_prefix}"
    d = create_driver(cfg, original_tag)
    run_driver(d, ARBITRARY_TEXT, JAVA_EXC, ARBITRARY_TEXT)
    d.emits.collect { |e| e[0] }.sort.uniq
  end

  def test_remove_tag_prefix
    tags = get_out_tags('prefix.plus', 'prefix.plus.rest.of.the.tag')
    assert_equal(['rest.of.the.tag'], tags)
    tags = get_out_tags('prefix.pl', 'prefix.plus.rest.of.the.tag')
    assert_equal(['prefix.plus.rest.of.the.tag'], tags)
    tags = get_out_tags('does.not.occur', 'prefix.plus.rest.of.the.tag')
    assert_equal(['prefix.plus.rest.of.the.tag'], tags)
  end

  def test_flush_after_max_lines
    cfg = 'max_lines 2'
    d = create_driver(cfg)
    t = Time.now.to_i
    d.run do
      feed_lines(d, t, PYTHON_EXC, JAVA_EXC)
    end
    # Expected: the first two lines of the exception are buffered and combined.
    # Then the max_lines setting kicks in and the rest of the Python exception
    # is logged line-by-line (since it's not an exception stack in itself).
    # Finally, the Java exception is logged in its entirety, since it only
    # has two lines.
    expected =
      [PYTHON_EXC.lines[0..1].join] + PYTHON_EXC.lines[2..-1] + [JAVA_EXC]
    assert_equal(make_logs(t, *expected), d.events)
  end

  def test_separate_streams
    cfg = 'stream stream'
    d = create_driver(cfg)
    t = Time.now.to_i
    d.run do
      feed_lines(d, t, JAVA_EXC.lines[0], stream: 'java')
      feed_lines(d, t, PYTHON_EXC.lines[0..1].join, stream: 'python')
      feed_lines(d, t, JAVA_EXC.lines[1..-1].join, stream: 'java')
      feed_lines(d, t, JAVA_EXC, stream: 'java')
      feed_lines(d, t, PYTHON_EXC.lines[2..-1].join, stream: 'python')
      feed_lines(d, t, 'something else', stream: 'java')
    end
    # Expected: the Python and the Java exceptions are handled separately
    # because they belong to different streams.
    # Note that the Java exception is only detected when 'something else'
    # is processed.
    expected = make_logs(t, JAVA_EXC, stream: 'java') +
               make_logs(t, PYTHON_EXC, stream: 'python') +
               make_logs(t, JAVA_EXC, stream: 'java') +
               make_logs(t, 'something else', stream: 'java')
    assert_equal(expected, d.events)
  end
end
