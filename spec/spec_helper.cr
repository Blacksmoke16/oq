require "spec"
require "../src/oq"

# Asserts the built XML equals *expected*.
def assert_builder_output(expected : String, &block : XML::Builder -> Nil) : Nil
  io = IO::Memory.new
  builder = XML::Builder.new io
  yield builder
  builder.flush
  io.to_s.should eq expected
end

# Runs the the binary with the given *name* and *args*.
def run_binary(input : String?, name : String = "bin/oq", args : Array(String) = [] of String, &block : String, Process::Status -> Nil)
  buffer = IO::Memory.new
  in = IO::Memory.new
  in << input if input
  status = Process.run(name, args, error: buffer, output: buffer, input: in.rewind)
  yield buffer.to_s, status
end
