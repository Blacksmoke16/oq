require "json"
require "xml"
require "yaml"

require "./converters/*"

# A performant and portable `jq` wrapper to support formats other than JSON.
module OQ
  VERSION = "0.2.1"

  # The support formats that can be converted to/from.
  enum Format
    Json
    Yaml
    Xml

    # Returns the list of supported formats.
    def self.to_s : String
      names.map(&.downcase).join(", ")
    end

    # Maps a given format to its converter.
    def converter
      {% begin %}
        case self
          {% for format in @type.constants %}
            when .{{format.downcase.id}}? then OQ::Converters::{{format.id}}
          {% end %}
        else
          raise "Unsupported format: '#{self}'."
        end
      {% end %}
    end
  end

  struct Processor
    # The format that the input data is in.
    property input_format : Format = Format::Json

    # The format that the output should be transcoded into.
    property output_format : Format = Format::Json

    # The args passed to the program.
    #
    # Non `oq` args are passed to `jq`.
    property args : Array(String) = [] of String

    # The root of the XML document when transcoding to XML.
    property xml_root : String = "root"

    # If the XML prolog should be emitted.
    property xml_prolog : Bool = true

    # The name for XML array elements without keys.
    property xml_item : String = "item"

    # The number of spaces to use for indentation.
    property indent : Int32 = 2

    # :nodoc:
    property tab : Bool = false

    # Consume the input, convert the input to JSON if needed, pass the input/args to `jq`, then convert the output if needed.
    def process : Nil
      ARGV.replace ARGV - @args

      # Shift off the filter from ARGV
      @args << ARGV.shift unless ARGV.empty?

      input_read, input_write = IO.pipe
      output_read, output_write = IO.pipe

      spawn do
        input_format.converter.deserialize(ARGF, input_write)
        input_write.close
      rescue ex
        handle_error ex
      end

      spawn do
        output_write.close
        output_format.converter.serialize(
          output_read,
          STDOUT,
          indent: ((tab ? "\t" : " ")*indent),
          xml_root: xml_root,
          xml_prolog: xml_prolog,
          xml_item: xml_item
        )
      rescue ex
        handle_error ex
      end

      run = Process.run(
        "jq",
        args,
        input: input_read,
        output: output_write,
        error: STDERR
      )

      exit(1) unless run.success?
    rescue ex
      handle_error ex
    end

    private def handle_error(ex : Exception)
      puts "oq error: #{ex.message}"
      exit(1)
    end
  end
end
