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
require 'fluent/plugin/exception_detector'

class ExceptionDetectorTest < Test::Unit::TestCase
  JAVA_EXC_PART1 = <<END.freeze
Jul 09, 2015 3:23:29 PM com.google.devtools.search.cloud.feeder.MakeLog: RuntimeException: Run from this message!
  at com.my.app.Object.do$a1(MakeLog.java:50)
  at java.lang.Thing.call(Thing.java:10)
END

  JAVA_EXC_PART2 = <<END.freeze
  at com.my.app.Object.help(MakeLog.java:40)
  at sun.javax.API.method(API.java:100)
  at com.jetty.Framework.main(MakeLog.java:30)
END

  JAVA_EXC = (JAVA_EXC_PART1 + JAVA_EXC_PART2).freeze

  COMPLEX_JAVA_EXC = <<END.freeze
javax.servlet.ServletException: Something bad happened
    at com.example.myproject.OpenSessionInViewFilter.doFilter(OpenSessionInViewFilter.java:60)
    at org.mortbay.jetty.servlet.ServletHandler$CachedChain.doFilter(ServletHandler.java:1157)
    at com.example.myproject.ExceptionHandlerFilter.doFilter(ExceptionHandlerFilter.java:28)
    at org.mortbay.jetty.servlet.ServletHandler$CachedChain.doFilter(ServletHandler.java:1157)
    at com.example.myproject.OutputBufferFilter.doFilter(OutputBufferFilter.java:33)
    at org.mortbay.jetty.servlet.ServletHandler$CachedChain.doFilter(ServletHandler.java:1157)
    at org.mortbay.jetty.servlet.ServletHandler.handle(ServletHandler.java:388)
    at org.mortbay.jetty.security.SecurityHandler.handle(SecurityHandler.java:216)
    at org.mortbay.jetty.servlet.SessionHandler.handle(SessionHandler.java:182)
    at org.mortbay.jetty.handler.ContextHandler.handle(ContextHandler.java:765)
    at org.mortbay.jetty.webapp.WebAppContext.handle(WebAppContext.java:418)
    at org.mortbay.jetty.handler.HandlerWrapper.handle(HandlerWrapper.java:152)
    at org.mortbay.jetty.Server.handle(Server.java:326)
    at org.mortbay.jetty.HttpConnection.handleRequest(HttpConnection.java:542)
    at org.mortbay.jetty.HttpConnection$RequestHandler.content(HttpConnection.java:943)
    at org.mortbay.jetty.HttpParser.parseNext(HttpParser.java:756)
    at org.mortbay.jetty.HttpParser.parseAvailable(HttpParser.java:218)
    at org.mortbay.jetty.HttpConnection.handle(HttpConnection.java:404)
    at org.mortbay.jetty.bio.SocketConnector$Connection.run(SocketConnector.java:228)
    at org.mortbay.thread.QueuedThreadPool$PoolThread.run(QueuedThreadPool.java:582)
Caused by: com.example.myproject.MyProjectServletException
    at com.example.myproject.MyServlet.doPost(MyServlet.java:169)
    at javax.servlet.http.HttpServlet.service(HttpServlet.java:727)
    at javax.servlet.http.HttpServlet.service(HttpServlet.java:820)
    at org.mortbay.jetty.servlet.ServletHolder.handle(ServletHolder.java:511)
    at org.mortbay.jetty.servlet.ServletHandler$CachedChain.doFilter(ServletHandler.java:1166)
    at com.example.myproject.OpenSessionInViewFilter.doFilter(OpenSessionInViewFilter.java:30)
    ... 27 common frames omitted
END

  NESTED_JAVA_EXC = <<END.freeze
java.lang.RuntimeException: javax.mail.SendFailedException: Invalid Addresses;
  nested exception is:
com.sun.mail.smtp.SMTPAddressFailedException: 550 5.7.1 <[REDACTED_EMAIL_ADDRESS]>... Relaying denied

	at com.nethunt.crm.api.server.adminsync.AutomaticEmailFacade.sendWithSmtp(AutomaticEmailFacade.java:236)
	at com.nethunt.crm.api.server.adminsync.AutomaticEmailFacade.sendSingleEmail(AutomaticEmailFacade.java:285)
	at com.nethunt.crm.api.server.adminsync.AutomaticEmailFacade.lambda$sendSingleEmail$3(AutomaticEmailFacade.java:254)
	at java.util.Optional.ifPresent(Optional.java:159)
	at com.nethunt.crm.api.server.adminsync.AutomaticEmailFacade.sendSingleEmail(AutomaticEmailFacade.java:253)
	at com.nethunt.crm.api.server.adminsync.AutomaticEmailFacade.sendSingleEmail(AutomaticEmailFacade.java:249)
	at com.nethunt.crm.api.email.EmailSender.lambda$notifyPerson$0(EmailSender.java:80)
	at com.nethunt.crm.api.util.ManagedExecutor.lambda$execute$0(ManagedExecutor.java:36)
	at com.nethunt.crm.api.util.RequestContextActivator.lambda$withRequestContext$0(RequestContextActivator.java:36)
	at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1149)
	at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:624)
	at java.base/java.lang.Thread.run(Thread.java:748)
Caused by: javax.mail.SendFailedException: Invalid Addresses;
  nested exception is:
com.sun.mail.smtp.SMTPAddressFailedException: 550 5.7.1 <[REDACTED_EMAIL_ADDRESS]>... Relaying denied

	at com.sun.mail.smtp.SMTPTransport.rcptTo(SMTPTransport.java:2064)
	at com.sun.mail.smtp.SMTPTransport.sendMessage(SMTPTransport.java:1286)
	at com.nethunt.crm.api.server.adminsync.AutomaticEmailFacade.sendWithSmtp(AutomaticEmailFacade.java:229)
	... 12 more
Caused by: com.sun.mail.smtp.SMTPAddressFailedException: 550 5.7.1 <[REDACTED_EMAIL_ADDRESS]>... Relaying denied
END

  NODE_JS_EXC = <<END.freeze
ReferenceError: myArray is not defined
  at next (/app/node_modules/express/lib/router/index.js:256:14)
  at /app/node_modules/express/lib/router/index.js:615:15
  at next (/app/node_modules/express/lib/router/index.js:271:10)
  at Function.process_params (/app/node_modules/express/lib/router/index.js:330:12)
  at /app/node_modules/express/lib/router/index.js:277:22
  at Layer.handle [as handle_request] (/app/node_modules/express/lib/router/layer.js:95:5)
  at Route.dispatch (/app/node_modules/express/lib/router/route.js:112:3)
  at next (/app/node_modules/express/lib/router/route.js:131:13)
  at Layer.handle [as handle_request] (/app/node_modules/express/lib/router/layer.js:95:5)
  at /app/app.js:52:3
END

  CLIENT_JS_EXC = <<END.freeze
Error
    at bls (<anonymous>:3:9)
    at <anonymous>:6:4
    at a_function_name
    at Object.InjectedScript._evaluateOn (http://<anonymous>/file.js?foo=bar:875:140)
    at Object.InjectedScript.evaluate (<anonymous>)
END

  V8_JS_EXC = <<END.freeze
V8 errors stack trace
  eval at Foo.a (eval at Bar.z (myscript.js:10:3))
  at new Contructor.Name (native)
  at new FunctionName (unknown location)
  at Type.functionName [as methodName] (file(copy).js?query='yes':12:9)
  at functionName [as methodName] (native)
  at Type.main(sample(copy).js:6:4)
END

  PYTHON_EXC = <<END.freeze
Traceback (most recent call last):
  File "/base/data/home/runtimes/python27/python27_lib/versions/third_party/webapp2-2.5.2/webapp2.py", line 1535, in __call__
    rv = self.handle_exception(request, response, e)
  File "/base/data/home/apps/s~nearfieldspy/1.378705245900539993/nearfieldspy.py", line 17, in start
    return get()
  File "/base/data/home/apps/s~nearfieldspy/1.378705245900539993/nearfieldspy.py", line 5, in get
    raise Exception('spam', 'eggs')
Exception: ('spam', 'eggs')
END

  PHP_EXC = <<END.freeze
exception 'Exception' with message 'Custom exception' in /home/joe/work/test-php/test.php:5
Stack trace:
#0 /home/joe/work/test-php/test.php(9): func1()
#1 /home/joe/work/test-php/test.php(13): func2()
#2 {main}
END

  PHP_ON_GAE_EXC = <<END.freeze
PHP Fatal error:  Uncaught exception 'Exception' with message 'message' in /base/data/home/apps/s~crash-example-php/1.388306779641080894/errors.php:60
Stack trace:
#0 [internal function]: ErrorEntryGenerator::{closure}()
#1 /base/data/home/apps/s~crash-example-php/1.388306779641080894/errors.php(20): call_user_func_array(Object(Closure), Array)
#2 /base/data/home/apps/s~crash-example-php/1.388306779641080894/index.php(36): ErrorEntry->__call('raise', Array)
#3 /base/data/home/apps/s~crash-example-php/1.388306779641080894/index.php(36): ErrorEntry->raise()
#4 {main}
  thrown in /base/data/home/apps/s~crash-example-php/1.388306779641080894/errors.php on line 60
END

  GO_EXC = <<END.freeze
panic: my panic

goroutine 4 [running]:
panic(0x45cb40, 0x47ad70)
	/usr/local/go/src/runtime/panic.go:542 +0x46c fp=0xc42003f7b8 sp=0xc42003f710 pc=0x422f7c
main.main.func1(0xc420024120)
	foo.go:6 +0x39 fp=0xc42003f7d8 sp=0xc42003f7b8 pc=0x451339
runtime.goexit()
	/usr/local/go/src/runtime/asm_amd64.s:2337 +0x1 fp=0xc42003f7e0 sp=0xc42003f7d8 pc=0x44b4d1
created by main.main
	foo.go:5 +0x58

goroutine 1 [chan receive]:
runtime.gopark(0x4739b8, 0xc420024178, 0x46fcd7, 0xc, 0xc420028e17, 0x3)
	/usr/local/go/src/runtime/proc.go:280 +0x12c fp=0xc420053e30 sp=0xc420053e00 pc=0x42503c
runtime.goparkunlock(0xc420024178, 0x46fcd7, 0xc, 0x1000f010040c217, 0x3)
	/usr/local/go/src/runtime/proc.go:286 +0x5e fp=0xc420053e70 sp=0xc420053e30 pc=0x42512e
runtime.chanrecv(0xc420024120, 0x0, 0xc420053f01, 0x4512d8)
	/usr/local/go/src/runtime/chan.go:506 +0x304 fp=0xc420053f20 sp=0xc420053e70 pc=0x4046b4
runtime.chanrecv1(0xc420024120, 0x0)
	/usr/local/go/src/runtime/chan.go:388 +0x2b fp=0xc420053f50 sp=0xc420053f20 pc=0x40439b
main.main()
	foo.go:9 +0x6f fp=0xc420053f80 sp=0xc420053f50 pc=0x4512ef
runtime.main()
	/usr/local/go/src/runtime/proc.go:185 +0x20d fp=0xc420053fe0 sp=0xc420053f80 pc=0x424bad
runtime.goexit()
	/usr/local/go/src/runtime/asm_amd64.s:2337 +0x1 fp=0xc420053fe8 sp=0xc420053fe0 pc=0x44b4d1

goroutine 2 [force gc (idle)]:
runtime.gopark(0x4739b8, 0x4ad720, 0x47001e, 0xf, 0x14, 0x1)
	/usr/local/go/src/runtime/proc.go:280 +0x12c fp=0xc42003e768 sp=0xc42003e738 pc=0x42503c
runtime.goparkunlock(0x4ad720, 0x47001e, 0xf, 0xc420000114, 0x1)
	/usr/local/go/src/runtime/proc.go:286 +0x5e fp=0xc42003e7a8 sp=0xc42003e768 pc=0x42512e
runtime.forcegchelper()
	/usr/local/go/src/runtime/proc.go:238 +0xcc fp=0xc42003e7e0 sp=0xc42003e7a8 pc=0x424e5c
runtime.goexit()
	/usr/local/go/src/runtime/asm_amd64.s:2337 +0x1 fp=0xc42003e7e8 sp=0xc42003e7e0 pc=0x44b4d1
created by runtime.init.4
	/usr/local/go/src/runtime/proc.go:227 +0x35

goroutine 3 [GC sweep wait]:
runtime.gopark(0x4739b8, 0x4ad7e0, 0x46fdd2, 0xd, 0x419914, 0x1)
	/usr/local/go/src/runtime/proc.go:280 +0x12c fp=0xc42003ef60 sp=0xc42003ef30 pc=0x42503c
runtime.goparkunlock(0x4ad7e0, 0x46fdd2, 0xd, 0x14, 0x1)
	/usr/local/go/src/runtime/proc.go:286 +0x5e fp=0xc42003efa0 sp=0xc42003ef60 pc=0x42512e
runtime.bgsweep(0xc42001e150)
	/usr/local/go/src/runtime/mgcsweep.go:52 +0xa3 fp=0xc42003efd8 sp=0xc42003efa0 pc=0x419973
runtime.goexit()
	/usr/local/go/src/runtime/asm_amd64.s:2337 +0x1 fp=0xc42003efe0 sp=0xc42003efd8 pc=0x44b4d1
created by runtime.gcenable
	/usr/local/go/src/runtime/mgc.go:216 +0x58
END

  GO_ON_GAE_EXC = <<END.freeze
panic: runtime error: index out of range

goroutine 12 [running]:
main88989.memoryAccessException()
	crash_example_go.go:58 +0x12a
main88989.handler(0x2afb7042a408, 0xc01042f880, 0xc0104d3450)
	crash_example_go.go:36 +0x7ec
net/http.HandlerFunc.ServeHTTP(0x13e5128, 0x2afb7042a408, 0xc01042f880, 0xc0104d3450)
	go/src/net/http/server.go:1265 +0x56
net/http.(*ServeMux).ServeHTTP(0xc01045cab0, 0x2afb7042a408, 0xc01042f880, 0xc0104d3450)
	go/src/net/http/server.go:1541 +0x1b4
appengine_internal.executeRequestSafely(0xc01042f880, 0xc0104d3450)
	go/src/appengine_internal/api_prod.go:288 +0xb7
appengine_internal.(*server).HandleRequest(0x15819b0, 0xc010401560, 0xc0104c8180, 0xc010431380, 0x0, 0x0)
	go/src/appengine_internal/api_prod.go:222 +0x102b
reflect.Value.call(0x1243fe0, 0x15819b0, 0x113, 0x12c8a20, 0x4, 0xc010485f78, 0x3, 0x3, 0x0, 0x0, ...)
	/tmp/appengine/go/src/reflect/value.go:419 +0x10fd
reflect.Value.Call(0x1243fe0, 0x15819b0, 0x113, 0xc010485f78, 0x3, 0x3, 0x0, 0x0, 0x0)
	/tmp/ap
END

  GO_SIGNAL_EXC = <<END.freeze
panic: runtime error: invalid memory address or nil pointer dereference
[signal SIGSEGV: segmentation violation code=0x1 addr=0x0 pc=0x7fd34f]

goroutine 5 [running]:
panics.nilPtrDereference()
	panics/panics.go:33 +0x1f
panics.Wait()
	panics/panics.go:16 +0x3b
created by main.main
	server.go:20 +0x91
END

  GO_HTTP = <<END.freeze
2019/01/15 07:48:05 http: panic serving [::1]:54143: test panic
goroutine 24 [running]:
net/http.(*conn).serve.func1(0xc00007eaa0)
	/usr/local/go/src/net/http/server.go:1746 +0xd0
panic(0x12472a0, 0x12ece10)
	/usr/local/go/src/runtime/panic.go:513 +0x1b9
main.doPanic(0x12f0ea0, 0xc00010e1c0, 0xc000104400)
	/Users/ingvar/src/go/src/httppanic.go:8 +0x39
net/http.HandlerFunc.ServeHTTP(0x12be2e8, 0x12f0ea0, 0xc00010e1c0, 0xc000104400)
	/usr/local/go/src/net/http/server.go:1964 +0x44
net/http.(*ServeMux).ServeHTTP(0x14a17a0, 0x12f0ea0, 0xc00010e1c0, 0xc000104400)
	/usr/local/go/src/net/http/server.go:2361 +0x127
net/http.serverHandler.ServeHTTP(0xc000085040, 0x12f0ea0, 0xc00010e1c0, 0xc000104400)
	/usr/local/go/src/net/http/server.go:2741 +0xab
net/http.(*conn).serve(0xc00007eaa0, 0x12f10a0, 0xc00008a780)
	/usr/local/go/src/net/http/server.go:1847 +0x646
created by net/http.(*Server).Serve
	/usr/local/go/src/net/http/server.go:2851 +0x2f5
END
  CSHARP_EXC = <<END.freeze
System.Collections.Generic.KeyNotFoundException: The given key was not present in the dictionary.
  at System.Collections.Generic.Dictionary`2[System.String,System.Collections.Generic.Dictionary`2[System.Int32,System.Double]].get_Item (System.String key) [0x00000] in <filename unknown>:0
  at File3.Consolidator_Class.Function5 (System.Collections.Generic.Dictionary`2 names, System.Text.StringBuilder param_4) [0x00007] in /usr/local/google/home/Csharp/another file.csharp:9
  at File3.Consolidator_Class.Function4 (System.Text.StringBuilder param_4, System.Double[,,] array) [0x00013] in /usr/local/google/home/Csharp/another file.csharp:23
  at File3.Consolidator_Class.Function3 (Int32 param_3) [0x0000f] in /usr/local/google/home/Csharp/another file.csharp:27
  at File3.Consolidator_Class.Function3 (System.Text.StringBuilder param_3) [0x00007] in /usr/local/google/home/Csharp/another file.csharp:32
  at File2.Processor.Function2 (System.Int32& param_2, System.Collections.Generic.Stack`1& numbers) [0x00003] in /usr/local/google/home/Csharp/File2.csharp:19
  at File2.Processor.Random2 () [0x00037] in /usr/local/google/home/Csharp/File2.csharp:28
  at File2.Processor.Function1 (Int32 param_1, System.Collections.Generic.Dictionary`2 map) [0x00007] in /usr/local/google/home/Csharp/File2.csharp:34
  at Main.Welcome+<Main>c__AnonStorey0.<>m__0 () [0x00006] in /usr/local/google/home/Csharp/hello.csharp:48
  at System.Threading.Thread.StartInternal () [0x00000] in <filename unknown>:0
END

  CSHARP_NESTED_EXC = <<END.freeze
System.InvalidOperationException: This is the outer exception ---> System.InvalidOperationException: This is the inner exception
  at ExampleApp.NestedExceptionExample.LowestLevelMethod() in c:/ExampleApp/ExampleApp/NestedExceptionExample.cs:line 33
  at ExampleApp.NestedExceptionExample.ThirdLevelMethod() in c:/ExampleApp/ExampleApp/NestedExceptionExample.cs:line 28
  at ExampleApp.NestedExceptionExample.SecondLevelMethod() in c:/ExampleApp/ExampleApp/NestedExceptionExample.cs:line 18
  --- End of inner exception stack trace ---
  at ExampleApp.NestedExceptionExample.SecondLevelMethod() in c:/ExampleApp/ExampleApp/NestedExceptionExample.cs:line 22
  at ExampleApp.NestedExceptionExample.TopLevelMethod() in c:/ExampleApp/ExampleApp/NestedExceptionExample.cs:line 11
  at ExampleApp.Program.Main(String[] args) in c:/ExampleApp/ExampleApp/Program.cs:line 11
END

  CSHARP_ASYNC_EXC = <<END.freeze
System.InvalidOperationException: This is an exception
   at ExampleApp2.AsyncExceptionExample.LowestLevelMethod() in c:/ExampleApp/ExampleApp/AsyncExceptionExample.cs:line 36
   at ExampleApp2.AsyncExceptionExample.<ThirdLevelMethod>d__2.MoveNext() in c:/ExampleApp/ExampleApp/AsyncExceptionExample.cs:line 31
--- End of stack trace from previous location where exception was thrown ---
   at System.Runtime.CompilerServices.TaskAwaiter.ThrowForNonSuccess(Task task)
   at System.Runtime.CompilerServices.TaskAwaiter.HandleNonSuccessAndDebuggerNotification(Task task)
   at System.Runtime.CompilerServices.TaskAwaiter.GetResult()
   at ExampleApp2.AsyncExceptionExample.<SecondLevelMethod>d__1.MoveNext() in c:/ExampleApp/ExampleApp/AsyncExceptionExample.cs:line 25
--- End of stack trace from previous location where exception was thrown ---
   at System.Runtime.CompilerServices.TaskAwaiter.ThrowForNonSuccess(Task task)
   at System.Runtime.CompilerServices.TaskAwaiter.HandleNonSuccessAndDebuggerNotification(Task task)
   at System.Runtime.CompilerServices.TaskAwaiter.GetResult()
   at ExampleApp2.AsyncExceptionExample.<TopLevelMethod>d__0.MoveNext() in c:/ExampleApp/ExampleApp/AsyncExceptionExample.cs:line 14
END

  RUBY_EXC = <<END.freeze
 NoMethodError (undefined method `resursivewordload' for #<BooksController:0x007f8dd9a0c738>):
  app/controllers/books_controller.rb:69:in `recursivewordload'
  app/controllers/books_controller.rb:75:in `loadword'
  app/controllers/books_controller.rb:79:in `loadline'
  app/controllers/books_controller.rb:83:in `loadparagraph'
  app/controllers/books_controller.rb:87:in `loadpage'
  app/controllers/books_controller.rb:91:in `onload'
  app/controllers/books_controller.rb:95:in `loadrecursive'
  app/controllers/books_controller.rb:99:in `requestload'
  app/controllers/books_controller.rb:118:in `generror'
  config/error_reporting_logger.rb:62:in `tagged'
END

  RUBY_SEGFAULT_EXC = <<END.freeze
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/gitaly-14.6.0.pre.rc1/ruby/proto/gitaly/repository-service_pb.rb:362: [BUG] Segmentation fault at 0x0000000000000089
ruby 2.7.5p203 (2021-11-24 revision f69aeb8314) [x86_64-linux]

-- Control frame information -----------------------------------------------
c:0048 p:---- s:0264 e:000263 CFUNC  :lookup
c:0047 p:1416 s:0259 e:000258 CLASS  /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/gitaly-14.6.0.pre.rc1/ruby/proto/gitaly/repository-service_pb.rb:362
c:0046 p:0049 s:0256 e:000255 TOP    /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/gitaly-14.6.0.pre.rc1/ruby/proto/gitaly/repository-service_pb.rb:318 [FINISH]
c:0045 p:---- s:0253 e:000252 CFUNC  :require
c:0044 p:0007 s:0248 e:000247 BLOCK  /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/activesupport-6.1.4.4/lib/active_support/dependencies.rb:332
c:0043 p:0068 s:0245 e:000244 METHOD /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/activesupport-6.1.4.4/lib/active_support/dependencies.rb:299
c:0042 p:0010 s:0238 e:000237 METHOD /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/activesupport-6.1.4.4/lib/active_support/dependencies.rb:332
c:0041 p:0011 s:0232 e:000231 TOP    /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/gitaly-14.6.0.pre.rc1/ruby/proto/gitaly/repository-service_services_pb.rb:5 [FINISH]
c:0040 p:---- s:0229 e:000228 CFUNC  :require
c:0039 p:0007 s:0224 e:000223 BLOCK  /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/activesupport-6.1.4.4/lib/active_support/dependencies.rb:332
c:0038 p:0068 s:0221 e:000220 METHOD /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/activesupport-6.1.4.4/lib/active_support/dependencies.rb:299
c:0037 p:0010 s:0214 e:000213 METHOD /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/activesupport-6.1.4.4/lib/active_support/dependencies.rb:332
c:0036 p:0109 s:0208 e:000207 TOP    /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/gitaly-14.6.0.pre.rc1/ruby/proto/gitaly.rb:32 [FINISH]
c:0035 p:---- s:0205 e:000204 CFUNC  :require
c:0034 p:0032 s:0200 e:000199 BLOCK  /usr/local/lib/ruby/2.7.0/bundler/runtime.rb:74 [FINISH]
c:0033 p:---- s:0195 e:000194 CFUNC  :each
c:0032 p:0042 s:0191 e:000190 BLOCK  /usr/local/lib/ruby/2.7.0/bundler/runtime.rb:69 [FINISH]
c:0031 p:---- s:0184 e:000183 CFUNC  :each
c:0030 p:0026 s:0180 e:000179 METHOD /usr/local/lib/ruby/2.7.0/bundler/runtime.rb:58
c:0029 p:0013 s:0175 e:000174 METHOD /usr/local/lib/ruby/2.7.0/bundler.rb:174
c:0028 p:0016 s:0170 e:000169 BLOCK  /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/derailed_benchmarks-1.8.1/bin/derailed:53
c:0027 p:0006 s:0167 e:000166 METHOD /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/memory_profiler-0.9.14/lib/memory_profiler/reporter.rb:74
c:0026 p:0015 s:0162 e:000161 METHOD /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/memory_profiler-0.9.14/lib/memory_profiler/reporter.rb:33
c:0025 p:0021 s:0156 e:000155 METHOD /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/memory_profiler-0.9.14/lib/memory_profiler.rb:15
c:0024 p:0062 s:0150 e:000149 BLOCK  /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/derailed_benchmarks-1.8.1/bin/derailed:52 [FINISH]
c:0023 p:0054 s:0145 e:000144 METHOD /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/thor-1.1.0/lib/thor/command.rb:27
c:0022 p:0040 s:0137 e:000136 METHOD /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/thor-1.1.0/lib/thor/invocation.rb:127
c:0021 p:0235 s:0130 e:000129 METHOD /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/thor-1.1.0/lib/thor.rb:392
c:0020 p:0062 s:0117 e:000116 METHOD /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/thor-1.1.0/lib/thor/base.rb:485
c:0019 p:0144 s:0110 e:000109 TOP    /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/derailed_benchmarks-1.8.1/bin/derailed:93 [FINISH]
c:0018 p:---- s:0106 e:000105 CFUNC  :load
c:0017 p:0112 s:0101 e:000100 TOP    /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/bin/derailed:23 [FINISH]
c:0016 p:---- s:0096 e:000095 CFUNC  :load
c:0015 p:0107 s:0091 e:000090 METHOD /usr/local/lib/ruby/2.7.0/bundler/cli/exec.rb:63
c:0014 p:0071 s:0083 e:000082 METHOD /usr/local/lib/ruby/2.7.0/bundler/cli/exec.rb:28
c:0013 p:0024 s:0078 e:000077 METHOD /usr/local/lib/ruby/2.7.0/bundler/cli.rb:476
c:0012 p:0054 s:0073 e:000072 METHOD /usr/local/lib/ruby/2.7.0/bundler/vendor/thor/lib/thor/command.rb:27
c:0011 p:0040 s:0065 e:000064 METHOD /usr/local/lib/ruby/2.7.0/bundler/vendor/thor/lib/thor/invocation.rb:127
c:0010 p:0239 s:0058 e:000057 METHOD /usr/local/lib/ruby/2.7.0/bundler/vendor/thor/lib/thor.rb:399
c:0009 p:0008 s:0045 e:000044 METHOD /usr/local/lib/ruby/2.7.0/bundler/cli.rb:30
c:0008 p:0066 s:0040 e:000039 METHOD /usr/local/lib/ruby/2.7.0/bundler/vendor/thor/lib/thor/base.rb:476
c:0007 p:0008 s:0033 e:000032 METHOD /usr/local/lib/ruby/2.7.0/bundler/cli.rb:24
c:0006 p:0109 s:0028 e:000027 BLOCK  /usr/local/lib/ruby/gems/2.7.0/gems/bundler-2.1.4/libexec/bundle:46
c:0005 p:0002 s:0022 e:000021 METHOD /usr/local/lib/ruby/2.7.0/bundler/friendly_errors.rb:123
c:0004 p:0111 s:0017 E:001058 TOP    /usr/local/lib/ruby/gems/2.7.0/gems/bundler-2.1.4/libexec/bundle:34 [FINISH]
c:0003 p:---- s:0013 e:000012 CFUNC  :load
c:0002 p:0112 s:0008 E:002460 EVAL   /usr/local/bin/bundle:23 [FINISH]
c:0001 p:0000 s:0003 E:0023a0 (none) [FINISH]

-- Ruby level backtrace information ----------------------------------------
/usr/local/bin/bundle:23:in `<main>'
/usr/local/bin/bundle:23:in `load'
/usr/local/lib/ruby/gems/2.7.0/gems/bundler-2.1.4/libexec/bundle:34:in `<top (required)>'
/usr/local/lib/ruby/2.7.0/bundler/friendly_errors.rb:123:in `with_friendly_errors'
/usr/local/lib/ruby/gems/2.7.0/gems/bundler-2.1.4/libexec/bundle:46:in `block in <top (required)>'
/usr/local/lib/ruby/2.7.0/bundler/cli.rb:24:in `start'
/usr/local/lib/ruby/2.7.0/bundler/vendor/thor/lib/thor/base.rb:476:in `start'
/usr/local/lib/ruby/2.7.0/bundler/cli.rb:30:in `dispatch'
/usr/local/lib/ruby/2.7.0/bundler/vendor/thor/lib/thor.rb:399:in `dispatch'
/usr/local/lib/ruby/2.7.0/bundler/vendor/thor/lib/thor/invocation.rb:127:in `invoke_command'
/usr/local/lib/ruby/2.7.0/bundler/vendor/thor/lib/thor/command.rb:27:in `run'
/usr/local/lib/ruby/2.7.0/bundler/cli.rb:476:in `exec'
/usr/local/lib/ruby/2.7.0/bundler/cli/exec.rb:28:in `run'
/usr/local/lib/ruby/2.7.0/bundler/cli/exec.rb:63:in `kernel_load'
/usr/local/lib/ruby/2.7.0/bundler/cli/exec.rb:63:in `load'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/bin/derailed:23:in `<top (required)>'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/bin/derailed:23:in `load'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/derailed_benchmarks-1.8.1/bin/derailed:93:in `<top (required)>'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/thor-1.1.0/lib/thor/base.rb:485:in `start'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/thor-1.1.0/lib/thor.rb:392:in `dispatch'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/thor-1.1.0/lib/thor/invocation.rb:127:in `invoke_command'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/thor-1.1.0/lib/thor/command.rb:27:in `run'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/derailed_benchmarks-1.8.1/bin/derailed:52:in `block in <class:DerailedBenchmarkCLI>'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/memory_profiler-0.9.14/lib/memory_profiler.rb:15:in `report'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/memory_profiler-0.9.14/lib/memory_profiler/reporter.rb:33:in `report'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/memory_profiler-0.9.14/lib/memory_profiler/reporter.rb:74:in `run'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/derailed_benchmarks-1.8.1/bin/derailed:53:in `block (2 levels) in <class:DerailedBenchmarkCLI>'
/usr/local/lib/ruby/2.7.0/bundler.rb:174:in `require'
/usr/local/lib/ruby/2.7.0/bundler/runtime.rb:58:in `require'
/usr/local/lib/ruby/2.7.0/bundler/runtime.rb:58:in `each'
/usr/local/lib/ruby/2.7.0/bundler/runtime.rb:69:in `block in require'
/usr/local/lib/ruby/2.7.0/bundler/runtime.rb:69:in `each'
/usr/local/lib/ruby/2.7.0/bundler/runtime.rb:74:in `block (2 levels) in require'
/usr/local/lib/ruby/2.7.0/bundler/runtime.rb:74:in `require'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/gitaly-14.6.0.pre.rc1/ruby/proto/gitaly.rb:32:in `<top (required)>'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/activesupport-6.1.4.4/lib/active_support/dependencies.rb:332:in `require'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/activesupport-6.1.4.4/lib/active_support/dependencies.rb:299:in `load_dependency'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/activesupport-6.1.4.4/lib/active_support/dependencies.rb:332:in `block in require'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/activesupport-6.1.4.4/lib/active_support/dependencies.rb:332:in `require'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/gitaly-14.6.0.pre.rc1/ruby/proto/gitaly/repository-service_services_pb.rb:5:in `<top (required)>'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/activesupport-6.1.4.4/lib/active_support/dependencies.rb:332:in `require'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/activesupport-6.1.4.4/lib/active_support/dependencies.rb:299:in `load_dependency'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/activesupport-6.1.4.4/lib/active_support/dependencies.rb:332:in `block in require'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/activesupport-6.1.4.4/lib/active_support/dependencies.rb:332:in `require'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/gitaly-14.6.0.pre.rc1/ruby/proto/gitaly/repository-service_pb.rb:318:in `<top (required)>'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/gitaly-14.6.0.pre.rc1/ruby/proto/gitaly/repository-service_pb.rb:362:in `<module:Gitaly>'
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/gitaly-14.6.0.pre.rc1/ruby/proto/gitaly/repository-service_pb.rb:362:in `lookup'

-- Machine register context ------------------------------------------------
 RIP: 0x00007fd8f45f40a2 RBP: 0x00007fd8f3655000 RSP: 0x00007fff198dd030
 RAX: 0x0000000000000003 RBX: 0x00007fd8da7a2790 RCX: 0x0000000000000089
 RDX: 0x000000000000003d RDI: 0x00007fd8f3655000 RSI: 0xcccccccccccccccd
  R8: 0x0000000000000001  R9: 0x0000000000000000 R10: 0x00007fd8e238b680
 R11: 0x0000000000000082 R12: 0x000000000008ff3a R13: 0xcccccccccccccccd
 R14: 0x000000000000000d R15: 0x0003f134e098c94f EFL: 0x0000000000010202

-- C level backtrace information -------------------------------------------
/usr/local/lib/libruby.so.2.7(rb_vm_bugreport+0x555) [0x7fd8f4799605] vm_dump.c:755
[0x7fd8f45d6d17]
/usr/local/lib/libruby.so.2.7(sigsegv+0x4b) [0x7fd8f4704d2b] signal.c:946
/lib/x86_64-linux-gnu/libpthread.so.0(__restore_rt+0x0) [0x7fd8f42db730]
[0x7fd8f45f40a2]
/usr/local/lib/libruby.so.2.7(gc_marks_rest+0x80) [0x7fd8f45f9380] gc.c:5526
/usr/local/lib/libruby.so.2.7(gc_rest+0x7a) [0x7fd8f45fa09a] gc.c:7382
/usr/local/lib/libruby.so.2.7(garbage_collect_with_gvl+0x98) [0x7fd8f45fb7a8] gc.c:7514
/usr/local/lib/libruby.so.2.7(objspace_malloc_fixup+0x17) [0x7fd8f45ff449] gc.c:9854
/usr/local/lib/libruby.so.2.7(rb_st_init_table_with_size+0x89) [0x7fd8f470eac9] st.c:620
/usr/local/lib/libruby.so.2.7(rebuild_table+0x1df) [0x7fd8f470ed5f] st.c:801
/usr/local/lib/libruby.so.2.7(rb_st_insert+0x1d8) [0x7fd8f470f398] st.c:1163
/usr/local/lib/ruby/2.7.0/x86_64-linux/objspace.so(newobj_i+0x206) [0x7fd8f2c37276] object_tracing.c:112
/usr/local/lib/libruby.so.2.7(tp_call_trace+0x29) [0x7fd8f4799ff9] vm_trace.c:1111
/usr/local/lib/libruby.so.2.7(exec_hooks_body+0x86) [0x7fd8f479a6b6] vm_trace.c:301
[0x7fd8f479c29d]
[0x7fd8f45ee2f3]
[0x7fd8f45fcdc7]
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/google-protobuf-3.19.1-x86_64-linux/lib/google/2.7/protobuf_c.so(0x7fd8d98943c9) [0x7fd8d98943c9]
/usr/local/lib/libruby.so.2.7(rb_class_new_instance+0x36) [0x7fd8f467f1c6] object.c:2099
/builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/google-protobuf-3.19.1-x86_64-linux/lib/google/2.7/protobuf_c.so(0x7fd8d9895f84) [0x7fd8d9895f84]
[0x7fd8f47785c9]
[0x7fd8f479117c]
/usr/local/lib/libruby.so.2.7(vm_call_method+0x55) [0x7fd8f4791915] vm_insnhelper.c:3026
[0x7fd8f4783ae2]
[0x7fd8f47895fc]
[0x7fd8f46359a5]
/usr/local/lib/libruby.so.2.7(rb_require_string+0x23) [0x7fd8f4636113] load.c:1148
[0x7fd8f47785c9]
[0x7fd8f479117c]
/usr/local/lib/libruby.so.2.7(vm_call_method+0x55) [0x7fd8f4791915] vm_insnhelper.c:3026
[0x7fd8f478569a]
[0x7fd8f47895fc]
[0x7fd8f46359a5]
/usr/local/lib/libruby.so.2.7(rb_require_string+0x23) [0x7fd8f4636113] load.c:1148
[0x7fd8f47785c9]
[0x7fd8f479117c]
/usr/local/lib/libruby.so.2.7(vm_call_method+0x55) [0x7fd8f4791915] vm_insnhelper.c:3026
[0x7fd8f478569a]
[0x7fd8f47895fc]
[0x7fd8f46359a5]
/usr/local/lib/libruby.so.2.7(rb_require_string+0x23) [0x7fd8f4636113] load.c:1148
[0x7fd8f47785c9]
[0x7fd8f4783ae2]
[0x7fd8f47895fc]
/usr/local/lib/libruby.so.2.7(rb_yield+0x253) [0x7fd8f47953e3] vm.c:1044
/usr/local/lib/libruby.so.2.7(rb_ary_each+0x3c) [0x7fd8f45491ac] array.c:2135
[0x7fd8f47785c9]
[0x7fd8f4783ba0]
[0x7fd8f47895fc]
/usr/local/lib/libruby.so.2.7(rb_yield+0x253) [0x7fd8f47953e3] vm.c:1044
/usr/local/lib/libruby.so.2.7(rb_ary_each+0x3c) [0x7fd8f45491ac] array.c:2135
[0x7fd8f47785c9]
[0x7fd8f479117c]
/usr/local/lib/libruby.so.2.7(vm_call_method+0x55) [0x7fd8f4791915] vm_insnhelper.c:3026
[0x7fd8f4783ba0]
[0x7fd8f47895fc]
[0x7fd8f478a468]
[0x7fd8f4783ae2]
[0x7fd8f4789db5]
/usr/local/lib/libruby.so.2.7(rb_ec_exec_node+0xaa) [0x7fd8f45db70a] eval.c:278
/usr/local/lib/libruby.so.2.7(ruby_run_node+0x49) [0x7fd8f45e0999] eval.c:336
/usr/local/bin/ruby(main+0x5b) [0x55bc6cf0910b] ./main.c:50

-- Other runtime information -----------------------------------------------

* Loaded script: /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/bin/derailed

* Loaded features:

    0 enumerator.so
    1 thread.rb
    2 rational.so
    3 complex.so
    4 ruby2_keywords.rb
    5 /usr/local/lib/ruby/2.7.0/x86_64-linux/enc/encdb.so
    6 /usr/local/lib/ruby/2.7.0/x86_64-linux/enc/trans/transdb.so
    7 /usr/local/lib/ruby/2.7.0/x86_64-linux/rbconfig.rb
    8 /usr/local/lib/ruby/2.7.0/rubygems/compatibility.rb
    9 /usr/local/lib/ruby/2.7.0/rubygems/defaults.rb
   10 /usr/local/lib/ruby/2.7.0/rubygems/deprecate.rb
   11 /usr/local/lib/ruby/2.7.0/rubygems/errors.rb
   12 /usr/local/lib/ruby/2.7.0/rubygems/version.rb
   13 /usr/local/lib/ruby/2.7.0/rubygems/requirement.rb
   14 /usr/local/lib/ruby/2.7.0/rubygems/platform.rb
   15 /usr/local/lib/ruby/2.7.0/rubygems/basic_specification.rb
   16 /usr/local/lib/ruby/2.7.0/rubygems/stub_specification.rb
   17 /usr/local/lib/ruby/2.7.0/rubygems/util.rb
   18 /usr/local/lib/ruby/2.7.0/rubygems/text.rb
   19 /usr/local/lib/ruby/2.7.0/rubygems/user_interaction.rb
   20 /usr/local/lib/ruby/2.7.0/rubygems/specification_policy.rb
   21 /usr/local/lib/ruby/2.7.0/rubygems/util/list.rb
   22 /usr/local/lib/ruby/2.7.0/rubygems/specification.rb
   23 /usr/local/lib/ruby/2.7.0/rubygems/exceptions.rb
   24 /usr/local/lib/ruby/2.7.0/rubygems/bundler_version_finder.rb
   25 /usr/local/lib/ruby/2.7.0/rubygems/dependency.rb
   26 /usr/local/lib/ruby/2.7.0/rubygems/core_ext/kernel_gem.rb
   27 /usr/local/lib/ruby/2.7.0/x86_64-linux/monitor.so
   28 /usr/local/lib/ruby/2.7.0/monitor.rb
   29 /usr/local/lib/ruby/2.7.0/rubygems/core_ext/kernel_require.rb
   30 /usr/local/lib/ruby/2.7.0/rubygems/core_ext/kernel_warn.rb
   31 /usr/local/lib/ruby/2.7.0/rubygems.rb
   32 /usr/local/lib/ruby/2.7.0/rubygems/path_support.rb
   33 /usr/local/lib/ruby/2.7.0/did_you_mean/version.rb
   34 /usr/local/lib/ruby/2.7.0/did_you_mean/core_ext/name_error.rb
   35 /usr/local/lib/ruby/2.7.0/did_you_mean/levenshtein.rb
   36 /usr/local/lib/ruby/2.7.0/did_you_mean/jaro_winkler.rb
   37 /usr/local/lib/ruby/2.7.0/did_you_mean/spell_checker.rb
   38 /usr/local/lib/ruby/2.7.0/did_you_mean/spell_checkers/name_error_checkers/class_name_checker.rb
   39 /usr/local/lib/ruby/2.7.0/did_you_mean/spell_checkers/name_error_checkers/variable_name_checker.rb
   40 /usr/local/lib/ruby/2.7.0/did_you_mean/spell_checkers/name_error_checkers.rb
   41 /usr/local/lib/ruby/2.7.0/did_you_mean/spell_checkers/method_name_checker.rb
   42 /usr/local/lib/ruby/2.7.0/did_you_mean/spell_checkers/key_error_checker.rb
   43 /usr/local/lib/ruby/2.7.0/did_you_mean/spell_checkers/null_checker.rb
   44 /usr/local/lib/ruby/2.7.0/did_you_mean/formatters/plain_formatter.rb
   45 /usr/local/lib/ruby/2.7.0/did_you_mean/tree_spell_checker.rb
   46 /usr/local/lib/ruby/2.7.0/did_you_mean.rb
   47 /usr/local/lib/ruby/2.7.0/tsort.rb
   48 /usr/local/lib/ruby/2.7.0/rubygems/request_set/gem_dependency_api.rb
   49 /usr/local/lib/ruby/2.7.0/rubygems/request_set/lockfile/parser.rb
   50 /usr/local/lib/ruby/2.7.0/rubygems/request_set/lockfile/tokenizer.rb
   51 /usr/local/lib/ruby/2.7.0/rubygems/request_set/lockfile.rb
   52 /usr/local/lib/ruby/2.7.0/rubygems/request_set.rb
   53 /usr/local/lib/ruby/2.7.0/rubygems/resolver/molinillo/lib/molinillo/gem_metadata.rb
   54 /usr/local/lib/ruby/2.7.0/rubygems/resolver/molinillo/lib/molinillo/errors.rb
   55 /usr/local/lib/ruby/2.7.0/set.rb
   56 /usr/local/lib/ruby/2.7.0/rubygems/resolver/molinillo/lib/molinillo/dependency_graph/action.rb
   57 /usr/local/lib/ruby/2.7.0/rubygems/resolver/molinillo/lib/molinillo/dependency_graph/add_edge_no_circular.rb

* Process memory map:

55bc6cf08000-55bc6cf09000 r--p 00000000 08:01 2234292                    /usr/local/bin/ruby
55bc6cf09000-55bc6cf0a000 r-xp 00001000 08:01 2234292                    /usr/local/bin/ruby
55bc6cf0a000-55bc6cf0b000 r--p 00002000 08:01 2234292                    /usr/local/bin/ruby
55bc6cf0b000-55bc6cf0c000 r--p 00002000 08:01 2234292                    /usr/local/bin/ruby
55bc6cf0c000-55bc6cf0d000 rw-p 00003000 08:01 2234292                    /usr/local/bin/ruby
7fd8cdb83000-7fd8cdd41000 r--s 00000000 08:01 2089303                    /lib/x86_64-linux-gnu/libc-2.28.so
7fd8cdd41000-7fd8cdd72000 r--s 00000000 08:01 1068321                    /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/google-protobuf-3.19.1-x86_64-linux/lib/google/2.7/protobuf_c.so
7fd8cdd72000-7fd8cdda9000 r--s 00000000 08:01 2351143                    /usr/local/lib/ruby/2.7.0/x86_64-linux/objspace.so
7fd8cdda9000-7fd8cddcd000 r--s 00000000 08:01 2089362                    /lib/x86_64-linux-gnu/libpthread-2.28.so
7fd8cddcd000-7fd8ce760000 r--s 00000000 08:01 2234335                    /usr/local/lib/libruby.so.2.7.5
7fd8ce760000-7fd8ce791000 r--s 00000000 08:01 2234292                    /usr/local/bin/ruby
7fd8ce791000-7fd8d5f91000 rw-p 00000000 00:00 0
7fd8d5f91000-7fd8d5ff0000 r--p 00000000 08:01 1069884                    /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/grpc-1.42.0-x86_64-linux/src/ruby/lib/grpc/2.7/grpc_c.so
7fd8d5ff0000-7fd8d6411000 r-xp 0005f000 08:01 1069884                    /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/grpc-1.42.0-x86_64-linux/src/ruby/lib/grpc/2.7/grpc_c.so
7fd8d6411000-7fd8d6592000 r--p 00480000 08:01 1069884                    /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/grpc-1.42.0-x86_64-linux/src/ruby/lib/grpc/2.7/grpc_c.so
7fd8d6592000-7fd8d6593000 ---p 00601000 08:01 1069884                    /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/grpc-1.42.0-x86_64-linux/src/ruby/lib/grpc/2.7/grpc_c.so
7fd8d6593000-7fd8d65be000 r--p 00601000 08:01 1069884                    /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/grpc-1.42.0-x86_64-linux/src/ruby/lib/grpc/2.7/grpc_c.so
7fd8d65be000-7fd8d65c4000 rw-p 0062c000 08:01 1069884                    /builds/gitlab-org/gitlab/vendor/ruby/2.7.0/gems/grpc-1.42.0-x86_64-linux/src/ruby/lib/grpc/2.7/grpc_c.so
7fd8d65c4000-7fd8d65d3000 rw-p 00000000 00:00 0

END

  # The whitespace on the second line is significant.
  # rubocop:disable TrailingWhitespace
  RAILS_EXC = <<END.freeze
 ActionController::RoutingError (No route matches [GET] "/settings"):
  
  actionpack (5.1.4) lib/action_dispatch/middleware/debug_exceptions.rb:63:in `call'
  actionpack (5.1.4) lib/action_dispatch/middleware/show_exceptions.rb:31:in `call'
  railties (5.1.4) lib/rails/rack/logger.rb:36:in `call_app'
  railties (5.1.4) lib/rails/rack/logger.rb:24:in `block in call'
  activesupport (5.1.4) lib/active_support/tagged_logging.rb:69:in `block in tagged'
  activesupport (5.1.4) lib/active_support/tagged_logging.rb:26:in `tagged'
  activesupport (5.1.4) lib/active_support/tagged_logging.rb:69:in `tagged'
  railties (5.1.4) lib/rails/rack/logger.rb:24:in `call'
  actionpack (5.1.4) lib/action_dispatch/middleware/remote_ip.rb:79:in `call'
  actionpack (5.1.4) lib/action_dispatch/middleware/request_id.rb:25:in `call'
  rack (2.0.3) lib/rack/method_override.rb:22:in `call'
  rack (2.0.3) lib/rack/runtime.rb:22:in `call'
  activesupport (5.1.4) lib/active_support/cache/strategy/local_cache_middleware.rb:27:in `call'
  actionpack (5.1.4) lib/action_dispatch/middleware/executor.rb:12:in `call'
  rack (2.0.3) lib/rack/sendfile.rb:111:in `call'
  railties (5.1.4) lib/rails/engine.rb:522:in `call'
  puma (3.10.0) lib/puma/configuration.rb:225:in `call'
  puma (3.10.0) lib/puma/server.rb:605:in `handle_request'
  puma (3.10.0) lib/puma/server.rb:437:in `process_client'
  puma (3.10.0) lib/puma/server.rb:301:in `block in run'
  puma (3.10.0) lib/puma/thread_pool.rb:120:in `block in spawn_thread'
END

  DART_ERR = <<END.freeze
Unhandled exception:
Instance of 'MyError'
#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:15:20)
#1      printError (file:///path/to/code/dartFile.dart:37:13)
#2      main (file:///path/to/code/dartFile.dart:15:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_EXC = <<END.freeze
Unhandled exception:
Exception: exception message
#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:17:20)
#1      printError (file:///path/to/code/dartFile.dart:37:13)
#2      main (file:///path/to/code/dartFile.dart:17:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_ASYNC_ERR = <<END.freeze
Unhandled exception:
Bad state: oops
#0      handleFailure (file:///test/example/http/handling_an_httprequest_error.dart:16:3)
#1      main (file:///test/example/http/handling_an_httprequest_error.dart:24:5)
<asynchronous suspension>
#2      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#3      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_DIVIDE_BY_ZERO_ERR = <<END.freeze
Unhandled exception:
IntegerDivisionByZeroException
#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:27:20)
#1      printError (file:///path/to/code/dartFile.dart:42:13)
#2      main (file:///path/to/code/dartFile.dart:27:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_ARGUMENT_ERR = <<END.freeze
Unhandled exception:
Invalid argument(s): invalid argument
#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:23:20)
#1      printError (file:///path/to/code/dartFile.dart:42:13)
#2      main (file:///path/to/code/dartFile.dart:23:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_RANGE_ERR = <<END.freeze
Unhandled exception:
RangeError (index): Invalid value: Valid value range is empty: 1
#0      List.[] (dart:core-patch/growable_array.dart:151)
#1      main.<anonymous closure> (file:///path/to/code/dartFile.dart:31:23)
#2      printError (file:///path/to/code/dartFile.dart:42:13)
#3      main (file:///path/to/code/dartFile.dart:29:3)
#4      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#5      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_ASSERTION_ERR = <<END.freeze
Unhandled exception:
Assertion failed
#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:9:20)
#1      printError (file:///path/to/code/dartFile.dart:36:13)
#2      main (file:///path/to/code/dartFile.dart:9:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_ABSTRACT_CLASS_ERR = <<END.freeze
Unhandled exception:
Cannot instantiate abstract class LNClassName: _url 'null' line null
#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:12:20)
#1      printError (file:///path/to/code/dartFile.dart:36:13)
#2      main (file:///path/to/code/dartFile.dart:12:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_READ_STATIC_ERR = <<END.freeze
Unhandled exception:
Reading static variable 'variable' during its initialization
#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:28:20)
#1      printError (file:///path/to/code/dartFile.dart:43:13)
#2      main (file:///path/to/code/dartFile.dart:28:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_UNIMPLEMENTED_ERROR = <<END.freeze
Unhandled exception:
UnimplementedError: unimplemented
#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:38:20)
#1      printError (file:///path/to/code/dartFile.dart:61:13)
#2      main (file:///path/to/code/dartFile.dart:38:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_UNSUPPORTED_ERR = <<END.freeze
Unhandled exception:
Unsupported operation: unsupported
#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:36:20)
#1      printError (file:///path/to/code/dartFile.dart:61:13)
#2      main (file:///path/to/code/dartFile.dart:36:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_CONCURRENT_MODIFICATION_ERR = <<END.freeze
Unhandled exception:
Concurrent modification during iteration.
#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:35:20)
#1      printError (file:///path/to/code/dartFile.dart:61:13)
#2      main (file:///path/to/code/dartFile.dart:35:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_OOM_ERR = <<END.freeze
Unhandled exception:
Out of Memory
#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:34:20)
#1      printError (file:///path/to/code/dartFile.dart:61:13)
#2      main (file:///path/to/code/dartFile.dart:34:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_STACK_OVERFLOW_ERR = <<END.freeze
Unhandled exception:
Stack Overflow
#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:33:20)
#1      printError (file:///path/to/code/dartFile.dart:61:13)
#2      main (file:///path/to/code/dartFile.dart:33:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_FALLTHROUGH_ERR = <<END.freeze
Unhandled exception:
'null': Switch case fall-through at line null.
#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:39:20)
#1      printError (file:///path/to/code/dartFile.dart:51:13)
#2      main (file:///path/to/code/dartFile.dart:39:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_TYPE_ERR = <<END.freeze
Unhandled exception:
'file:///path/to/code/dartFile.dart': malformed type: line 7 pos 24: cannot resolve class 'NoType' from '::'
  printError( () { new NoType(); } );
                       ^


#0      _TypeError._throwNew (dart:core-patch/errors_patch.dart:82)
#1      main.<anonymous closure> (file:///path/to/code/dartFile.dart:7:24)
#2      printError (file:///path/to/code/dartFile.dart:36:13)
#3      main (file:///path/to/code/dartFile.dart:7:3)
#4      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#5      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_FORMAT_ERR = <<END.freeze
Unhandled exception:
FormatException: format exception
#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:25:20)
#1      printError (file:///path/to/code/dartFile.dart:42:13)
#2      main (file:///path/to/code/dartFile.dart:25:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_FORMAT_WITH_CODE_ERR = <<END.freeze
Unhandled exception:
FormatException: Invalid base64 data (at line 3, character 8)
this is not valid
       ^

#0      main.<anonymous closure> (file:///path/to/code/dartFile.dart:24:20)
#1      printError (file:///path/to/code/dartFile.dart:42:13)
#2      main (file:///path/to/code/dartFile.dart:24:3)
#3      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#4      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_NO_METHOD_ERR = <<END.freeze
Unhandled exception:
NoSuchMethodError: No constructor 'TypeError' with matching arguments declared in class 'TypeError'.
Receiver: Type: class 'TypeError'
Tried calling: new TypeError("Invalid base64 data", "invalid", 36)
Found: new TypeError()
#0      NoSuchMethodError._throwNew (dart:core-patch/errors_patch.dart:196)
#1      main.<anonymous closure> (file:///path/to/code/dartFile.dart:8:39)
#2      printError (file:///path/to/code/dartFile.dart:36:13)
#3      main (file:///path/to/code/dartFile.dart:8:3)
#4      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#5      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  DART_NO_METHOD_GLOBAL_ERR = <<END.freeze
Unhandled exception:
NoSuchMethodError: No top-level method 'noMethod' declared.
Receiver: top-level
Tried calling: noMethod()
#0      NoSuchMethodError._throwNew (dart:core-patch/errors_patch.dart:196)
#1      main.<anonymous closure> (file:///path/to/code/dartFile.dart:10:20)
#2      printError (file:///path/to/code/dartFile.dart:36:13)
#3      main (file:///path/to/code/dartFile.dart:10:3)
#4      _startIsolate.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:265)
#5      _RawReceivePortImpl._handleMessage (dart:isolate-patch/isolate_patch.dart:151)
END

  ARBITRARY_TEXT = <<END.freeze
This arbitrary text.
It sounds tympanic: a word which means like a drum.

I am glad it contains no exception.
END

  def check_multiline(detector, expected_first, expected_last, multiline)
    lines = multiline.lines
    lines.each_with_index do |line, index|
      action = detector.update(line)
      case index
      when 0
        assert_equal(expected_first, action,
                     "unexpected action on first line: #{line}")
      when lines.length - 1
        assert_equal(expected_last, action,
                     "unexpected action on last line: #{line}")
      else
        assert_equal(:inside_trace, action, "line not buffered: #{line}")
      end
    end
  end

  def check_no_multiline(detector, text)
    text.lines.each do |line|
      action = detector.update(line)
      assert_equal(:no_trace, action, "unexpected action on line: #{line}")
    end
  end

  def check_exception(exception, detects_end)
    detector = Fluent::ExceptionDetector.new
    after_exc = detects_end ? :end_trace : :inside_trace
    before_second_exc = detects_end ? :inside_trace : :start_trace
    check_multiline(detector, :no_trace, :no_trace, 'This is not an exception.')
    check_multiline(detector, :inside_trace, after_exc, exception)
    check_multiline(detector, :no_trace, :no_trace, 'This is not an exception.')
    check_multiline(detector, :inside_trace, after_exc, exception)
    check_multiline(detector, before_second_exc, after_exc, exception)
  end

  def test_java
    check_exception(JAVA_EXC, false)
    check_exception(COMPLEX_JAVA_EXC, false)
    check_exception(NESTED_JAVA_EXC, false)
  end

  def test_js
    check_exception(NODE_JS_EXC, false)
    check_exception(CLIENT_JS_EXC, false)
    check_exception(V8_JS_EXC, false)
  end

  def test_csharp
    check_exception(CSHARP_EXC, false)
    check_exception(CSHARP_NESTED_EXC, false)
    check_exception(CSHARP_ASYNC_EXC, false)
  end

  def test_python
    check_exception(PYTHON_EXC, true)
  end

  def test_php
    check_exception(PHP_EXC, false)
    check_exception(PHP_ON_GAE_EXC, true)
  end

  def test_go
    check_exception(GO_EXC, false)
    check_exception(GO_ON_GAE_EXC, false)
    check_exception(GO_SIGNAL_EXC, false)
    check_exception(GO_HTTP, false)
  end

  def test_ruby
    check_exception(RUBY_EXC, false)
    check_exception(RUBY_SEGFAULT_EXC, true)
    check_exception(RAILS_EXC, false)
  end

  def test_dart
    check_exception(DART_ERR, false)
    check_exception(DART_EXC, false)
    check_exception(DART_ASYNC_ERR, false)
    check_exception(DART_DIVIDE_BY_ZERO_ERR, false)
    check_exception(DART_ARGUMENT_ERR, false)
    check_exception(DART_RANGE_ERR, false)
    check_exception(DART_READ_STATIC_ERR, false)
    check_exception(DART_UNIMPLEMENTED_ERROR, false)
    check_exception(DART_UNSUPPORTED_ERR, false)
    check_exception(DART_CONCURRENT_MODIFICATION_ERR, false)
    check_exception(DART_OOM_ERR, false)
    check_exception(DART_STACK_OVERFLOW_ERR, false)
    check_exception(DART_FALLTHROUGH_ERR, false)
    check_exception(DART_TYPE_ERR, false)
    check_exception(DART_FORMAT_ERR, false)
    check_exception(DART_FORMAT_WITH_CODE_ERR, false)
    check_exception(DART_NO_METHOD_ERR, false)
    check_exception(DART_NO_METHOD_GLOBAL_ERR, false)
    check_exception(DART_ASSERTION_ERR, false)
    check_exception(DART_ABSTRACT_CLASS_ERR, false)
  end

  def test_mixed_languages
    check_exception(JAVA_EXC, false)
    check_exception(PYTHON_EXC, true)
    check_exception(COMPLEX_JAVA_EXC, false)
    check_exception(NODE_JS_EXC, false)
    check_exception(PHP_EXC, false)
    check_exception(PHP_ON_GAE_EXC, true)
    check_exception(CLIENT_JS_EXC, false)
    check_exception(GO_EXC, false)
    check_exception(GO_ON_GAE_EXC, false)
    check_exception(GO_SIGNAL_EXC, false)
    check_exception(CSHARP_EXC, false)
    check_exception(CSHARP_NESTED_EXC, false)
    check_exception(CSHARP_ASYNC_EXC, false)
    check_exception(V8_JS_EXC, false)
    check_exception(RUBY_EXC, false)
    check_exception(DART_ERR, false)
    check_exception(DART_EXC, false)
    check_exception(DART_ASYNC_ERR, false)
    check_exception(DART_DIVIDE_BY_ZERO_ERR, false)
    check_exception(DART_ARGUMENT_ERR, false)
    check_exception(DART_RANGE_ERR, false)
    check_exception(DART_READ_STATIC_ERR, false)
    check_exception(DART_UNIMPLEMENTED_ERROR, false)
    check_exception(DART_UNSUPPORTED_ERR, false)
    check_exception(DART_CONCURRENT_MODIFICATION_ERR, false)
    check_exception(DART_OOM_ERR, false)
    check_exception(DART_STACK_OVERFLOW_ERR, false)
    check_exception(DART_FALLTHROUGH_ERR, false)
    check_exception(DART_TYPE_ERR, false)
    check_exception(DART_FORMAT_ERR, false)
    check_exception(DART_FORMAT_WITH_CODE_ERR, false)
    check_exception(DART_NO_METHOD_ERR, false)
    check_exception(DART_NO_METHOD_GLOBAL_ERR, false)
    check_exception(DART_ASSERTION_ERR, false)
    check_exception(DART_ABSTRACT_CLASS_ERR, false)
  end

  def test_reset
    detector = Fluent::ExceptionDetector.new

    check_multiline(detector, :inside_trace, :inside_trace, JAVA_EXC_PART1)
    check_multiline(detector, :inside_trace, :inside_trace, JAVA_EXC_PART2)

    check_multiline(detector, :start_trace, :inside_trace, JAVA_EXC_PART1)
    detector.reset
    check_no_multiline(detector, JAVA_EXC_PART2)
  end

  def feed_lines(buffer, *messages)
    messages.each do |m|
      m.each_line do |line|
        buffer.push(0, line)
      end
      buffer.flush
    end
  end

  Struct.new('TestBufferScenario', :desc, :languages, :input, :expected)

  def buffer_scenario(desc, languages, input, expected)
    Struct::TestBufferScenario.new(desc, languages, input, expected)
  end

  def test_buffer
    [
      buffer_scenario('mixed languages',
                      [:all],
                      [JAVA_EXC, ARBITRARY_TEXT, PYTHON_EXC, GO_EXC],
                      [JAVA_EXC] + ARBITRARY_TEXT.lines + [PYTHON_EXC, GO_EXC]),
      buffer_scenario('single language',
                      [:go],
                      [JAVA_EXC, ARBITRARY_TEXT, GO_EXC],
                      JAVA_EXC.lines + ARBITRARY_TEXT.lines + [GO_EXC]),
      buffer_scenario('some exceptions from non-configured languages',
                      [:python],
                      [JAVA_EXC, PYTHON_EXC, GO_EXC],
                      JAVA_EXC.lines + [PYTHON_EXC] + GO_EXC.lines),
      buffer_scenario('all exceptions from non-configured languages',
                      [:ruby],
                      [JAVA_EXC, PYTHON_EXC, GO_EXC],
                      JAVA_EXC.lines + PYTHON_EXC.lines + GO_EXC.lines)
    ].each do |s|
      out = []
      buffer = Fluent::TraceAccumulator.new(nil,
                                            s.languages) { |_, m| out << m }
      feed_lines(buffer, *s.input)
      assert_equal(s.expected, out, s.desc)
    end
  end

  def feed_json(buffer, message_field, messages)
    messages.each do |m|
      m.each_line do |line|
        buffer.push(0, message_field => line)
      end
      buffer.flush
    end
  end

  def expected_json(message_field, messages)
    messages.collect { |m| { message_field => [m].flatten.join } }
  end

  Struct.new('TestJsonScenario',
             :desc, :configured_field, :actual_field, :input, :output)

  def json_scenario(desc, configured_field, actual_field, input, output)
    Struct::TestJsonScenario.new(desc, configured_field, actual_field,
                                 input, output)
  end

  def test_json_messages
    [
      json_scenario('User-defined message field', 'mydata', 'mydata',
                    [PYTHON_EXC, ARBITRARY_TEXT, GO_EXC],
                    [PYTHON_EXC] + ARBITRARY_TEXT.lines + [GO_EXC]),
      json_scenario('Default message field "message"', '', 'message',
                    [PYTHON_EXC, ARBITRARY_TEXT, GO_EXC],
                    [PYTHON_EXC] + ARBITRARY_TEXT.lines + [GO_EXC]),
      json_scenario('Default message field "log"', '', 'log',
                    [PYTHON_EXC, ARBITRARY_TEXT, GO_EXC],
                    [PYTHON_EXC] + ARBITRARY_TEXT.lines + [GO_EXC]),
      json_scenario('Wrongly defined message field', 'doesnotexist', 'mydata',
                    [PYTHON_EXC, ARBITRARY_TEXT, GO_EXC],
                    PYTHON_EXC.lines + ARBITRARY_TEXT.lines + GO_EXC.lines),
      json_scenario('Undefined message field', '', 'mydata',
                    [PYTHON_EXC, ARBITRARY_TEXT, GO_EXC],
                    PYTHON_EXC.lines + ARBITRARY_TEXT.lines + GO_EXC.lines)
    ].each do |s|
      out = []
      buffer = Fluent::TraceAccumulator.new(s.configured_field,
                                            [:all]) { |_, m| out << m }
      feed_json(buffer, s.actual_field, s.input)
      assert_equal(expected_json(s.actual_field, s.output), out, s.desc)
    end
  end

  def test_max_lines_limit
    # Limit is equal to the first part of the exception and forces it to be
    # flushed before the rest of the exception is processed.
    max_lines = JAVA_EXC_PART1.lines.length
    out = []
    buffer = Fluent::TraceAccumulator.new(nil,
                                          [:all],
                                          max_lines: max_lines) do |_, m|
      out << m
    end
    feed_lines(buffer, JAVA_EXC)
    assert_equal([JAVA_EXC_PART1] + JAVA_EXC_PART2.lines, out)
  end

  def test_high_max_bytes_limit
    # Limit is just too small to add one more line to the buffered first part of
    # the exception.
    max_bytes = JAVA_EXC_PART1.length + JAVA_EXC_PART2.lines[0].length - 1
    out = []
    buffer = Fluent::TraceAccumulator.new(nil,
                                          [:all],
                                          max_bytes: max_bytes) do |_, m|
      out << m
    end
    feed_lines(buffer, JAVA_EXC)
    # Check that the trace is flushed after the first part.
    assert_equal([JAVA_EXC_PART1] + JAVA_EXC_PART2.lines, out)
  end

  def test_low_max_bytes_limit
    # Limit is exceeded by the character that follows the buffered first part of
    # the exception.
    max_bytes = JAVA_EXC_PART1.length
    out = []
    buffer = Fluent::TraceAccumulator.new(nil,
                                          [:all],
                                          max_bytes: max_bytes) do |_, m|
      out << m
    end
    feed_lines(buffer, JAVA_EXC)
    # Check that the trace is flushed after the first part.
    assert_equal([JAVA_EXC_PART1] + JAVA_EXC_PART2.lines, out)
  end
end
