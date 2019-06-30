require "json"
require "yaml"

require "./to_xml"

# A performant, and portable jq wrapper to support formats other than JSON.
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
    property slurp : Bool = false

    # :nodoc:
    property null_input : Bool = false

    # Consume the input, convert the input to JSON if needed, pass the input/args to `jq`, then convert the output if needed.
    def process
      input = IO::Memory.new
      output = IO::Memory.new
      error = IO::Memory.new

      ARGV.replace ARGV - @args

      # Shift off the filter from ARGV
      @args << ARGV.shift unless ARGV.empty?

      if !@null_input
        case @input_format
        when .json? then input << ARGF.gets_to_end
        when .yaml?
          ARGV.empty? ? (input << YAML.parse(STDIN).to_json) : (ARGV.join('\n', input) { |f, io| io << YAML.parse(File.open(f)).to_json })
        else
          puts "Not Implemented"
          exit(1)
        end
      else
        @args = @args | ARGV
        input << ARGF.gets_to_end
      end

      run = Process.run("jq", args, input: input.rewind, output: output, error: error)

      unless run.success?
        if output.empty? && @null_input
          puts "null"
          exit
        end

        STDERR.puts error.to_s
        exit(1)
      end

      format_output output
    rescue ex
      puts "oq error: #{ex.message}"
      exit(1)
    end

    private def format_output(io : IO)
      io.rewind

      case @output_format
      when .json? then print io
      when .yaml? then print JSON.parse(io).to_yaml
      when .xml?  then print JSON.parse(io).to_xml root: @xml_root, indent: (@tab ? "\t" : " ")*@indent
      end
    end
  end
end
