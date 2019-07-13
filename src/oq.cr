require "json"
require "yaml"

require "./to_xml"

# A performant and portable jq wrapper to support formats other than JSON.
module Oq
  # The support formats that can be converted to/from.
  enum Format
    Json
    Yaml
    Xml
  end

  struct Processor
    # The format that the input data is in.
    property input_format : Format = Format::Json

    # The format that the output should be transcoded into.
    property output_format : Format = Format::Json

    # The args passed to the program.
    #
    # Non `oq` args are just passed to `jq`.
    property args : Array(String) = [] of String

    # The root of the XML document when transcoding to XML.
    property xml_root : String = "root"

    # The number of spaces to use for indentation.
    property indent : Int32 = 2

    # :nodoc:
    property tab : Bool = false

    # :nodoc:
    property null_input : Bool = false

    @output : IO = IO::Memory.new

    # Consume the input, convert the input to JSON if needed, pass the input/args to `jq`, then convert the output if needed.
    def process : Nil
      ARGV.replace ARGV - @args

      # Shift off the filter from ARGV
      @args << ARGV.shift unless ARGV.empty?

      run_jq input: get_input, output: get_output

      format_output
    rescue ex
      puts "oq error: #{ex.message}"
      exit(1)
    end

    private def format_output
      @output.rewind
      case @output_format
      when .yaml? then print JSON.parse(@output).to_yaml
      when .xml?  then print JSON.parse(@output).to_xml root: @xml_root, indent: (@tab ? "\t" : " ")*@indent
      end
    end

    private def run_jq(input : Process::Stdio, output : Process::Stdio, error = STDERR) : Nil
      run = Process.run("jq", args, input: input, output: output, error: error)
      exit(1) unless run.success?
      exit if @input_format.json? && @output_format.json?
    end

    private def get_input : Process::Stdio
      if @null_input
        @args = @args + ARGV
        return Process::Redirect::Close
      end
      return ARGF if @input_format.json?
      input = IO::Memory.new

      ARGV.empty? ? YAML.parse(ARGF).to_json(input) : (ARGV.each { |f| YAML.parse(File.open(f)).to_json(input << '\n') })

      input.rewind
    end

    private def get_output : Process::Stdio
      return STDOUT if @output_format.json?
      @output
    end
  end
end
