require "spec"
require "../src/oq"

# Runs the the binary with the given *name* and *args*.
def run_binary(input : String? = nil, name : String = "bin/oq", args : Array(String) = [] of String, &block : String, Process::Status -> Nil)
  buffer = IO::Memory.new
  in = IO::Memory.new
  in << input if input
  status = Process.run(name, args, output: buffer, input: in.rewind, error: STDERR)
  yield buffer.to_s, status
end
