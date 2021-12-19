require "spec"
require "../src/oq"

# Runs the the binary with the given *name* and *args*.
def run_binary(input : String | Process::Redirect | Nil = nil, name : String = "bin/oq", args : Array(String) = [] of String, *, success : Bool = true, file = __FILE__, line = __LINE__, & : String, Process::Status, String -> Nil)
  buffer_io = IO::Memory.new
  error_io = IO::Memory.new
  input_io = IO::Memory.new

  if input.is_a? Process::Redirect
    input_io = input
  else
    input_io << input if input
    input_io = input_io.rewind
  end

  status = Process.run(name, args, output: buffer_io, input: input_io, error: error_io)

  if success
    status.success?.should be_true, file: file, line: line
  else
    status.success?.should_not be_true, file: file, line: line
  end

  yield buffer_io.to_s, status, error_io.to_s
end
