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
def run_binary(input : String, name : String = "bin/oq", args : Array(String) = [] of String, &block : String -> Nil)
  buffer = IO::Memory.new
  input = IO::Memory.new input
  Process.run(name, args, error: buffer, output: buffer, input: input)
  yield buffer.to_s
  buffer.close
  input.close
end
