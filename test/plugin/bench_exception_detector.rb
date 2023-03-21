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

require 'benchmark'

require 'fluent/plugin/exception_detector'

size_in_m = 25
line_length = 50

size = size_in_m << 20

JAVA_EXC = <<~END_JAVA.freeze
  Jul 09, 2015 3:23:29 PM com.google.devtools.search.cloud.feeder.MakeLog: RuntimeException: Run from this message!
    at com.my.app.Object.do$a1(MakeLog.java:50)
    at java.lang.Thing.call(Thing.java:10)
    at com.my.app.Object.help(MakeLog.java:40)
    at sun.javax.API.method(API.java:100)
    at com.jetty.Framework.main(MakeLog.java:30)
END_JAVA

PYTHON_EXC = <<~END_PYTHON.freeze
  Traceback (most recent call last):
    File "/base/data/home/runtimes/python27/python27_lib/versions/third_party/webapp2-2.5.2/webapp2.py", line 1535, in __call__
      rv = self.handle_exception(request, response, e)
    File "/base/data/home/apps/s~nearfieldspy/1.378705245900539993/nearfieldspy.py", line 17, in start
      return get()
    File "/base/data/home/apps/s~nearfieldspy/1.378705245900539993/nearfieldspy.py", line 5, in get
      raise Exception('spam', 'eggs')
  Exception: ('spam', 'eggs')
END_PYTHON

chars = [('a'..'z'), ('A'..'Z')].map(&:to_a).flatten

random_text = (1..(size / line_length)).collect do
  (0...line_length).map { chars[rand(chars.length)] }.join
end

exceptions = {
  java: (JAVA_EXC * (size / JAVA_EXC.length)).lines,
  python: (PYTHON_EXC * (size / PYTHON_EXC.length)).lines
}

puts "Start benchmark. Input size #{size_in_m}M."
Benchmark.bm do |x|
  languages = Fluent::ExceptionDetectorConfig::RULES_BY_LANG.keys
  languages.each do |lang|
    buffer = Fluent::TraceAccumulator.new(nil, lang) {}
    x.report("#{lang}_detector_random_text") do
      random_text.each { |l| buffer.push(0, l) }
    end
  end
  %i[java python all].each do |detector_lang|
    buffer = Fluent::TraceAccumulator.new(nil, detector_lang) {}
    exc_languages = detector_lang == :all ? exceptions.keys : [detector_lang]
    exc_languages.each do |exc_lang|
      x.report("#{detector_lang}_detector_#{exc_lang}_stacks") do
        exceptions[exc_lang].each { |l| buffer.push(0, l) }
      end
    end
  end
end
