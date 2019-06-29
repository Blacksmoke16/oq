require "json"
require "yaml"

require "./to_xml"

module OmniQ
  enum Format
    Json
    Yaml
    Xml
  end

  struct Processor
    property input_format : Format = Format::Json
    property output_format : Format = Format::Json
    property args : Array(String) = [] of String
    property xml_root : String = "root"
    property slurp : Bool = false
    property read_raw : Bool = false

    def process
      input = IO::Memory.new
      output = IO::Memory.new
      err = IO::Memory.new

      # Shift off the filter from ARGV
      @args << ARGV.shift unless ARGV.empty?

      case @input_format
      when .json? then input << ARGF.gets_to_end
      when .yaml?
        ARGV.empty? ? (input << YAML.parse(STDIN).to_json) : (ARGV.join('\n', input) { |f, io| io << YAML.parse(File.open(f)).to_json })
      else
        puts "Not Implemented"
        exit(1)
      end

      run = Process.run("jq", args, input: input.rewind, output: output, error: err)

      unless run.success?
        puts err.to_s
        exit(1)
      end

      format_output output
    rescue ex
      puts "oq error: #{ex.message}"
      exit(1)
    end

    def format_output(io : IO)
      io.rewind
      case @output_format
      when .json? then print io
      when .yaml? then print JSON.parse(io).to_yaml
      when .xml?  then print JSON.parse(io).to_xml root: @xml_root
      end
    end
  end
end
