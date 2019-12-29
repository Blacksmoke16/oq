require "json"
require "xml"
require "yaml"

require "./converters/*"

# A performant and portable `jq` wrapper to support formats other than JSON.
module OQ
  VERSION = "1.0.0"

  # The support formats that can be converted to/from.
  enum Format
    # The JSON format.
    #
    # The body is not manipulated by `oq`; `oq` simply acts as a wrapper for `jq`.
    Json

    # The YAML format.
    Yaml

    # The primary XML format.
    #
    # It's converted JSON representation is based on [Goessner's "pragmatic XML"](https://www.xml.com/pub/a/2006/05/31/converting-between-xml-and-json.html).
    Xml

    # The MicroXML format.
    #
    # It's converted JSON represented is based on the [MicroXML](https://dvcs.w3.org/hg/microxml/raw-file/tip/spec/microxml.html) spec.
    Mxml

    # Returns the list of supported formats.
    def self.to_s : String
      names.map(&.downcase).join(", ")
    end

    # Maps `self` to its corresponding converter.
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
    setter input_format : Format = Format::Json

    # The format that the output should be transcoded into.
    setter output_format : Format = Format::Json

    # The args passed to the program.
    #
    # Non `oq` args are passed to `jq`.
    getter args : Array(String) = [] of String

    # The root of the XML document when transcoding to XML.
    setter xml_root : String = "root"

    # If the XML prolog should be emitted.
    setter xml_prolog : Bool = true

    # The name for XML array elements without keys.
    setter xml_item : String = "item"

    # The number of spaces to use for indentation.
    setter indent : Int32 = 2

    # :nodoc:
    setter tab : Bool = false

    # Consume the input, convert the input to JSON if needed, pass the input/args to `jq`, then convert the output if needed.
    def process : Nil
      ARGV.replace ARGV - @args

      # Add color option if STDOUT is a tty
      # and the output format is JSON
      # (Since it will go straight to STDOUT and not convertered)
      @args.unshift "-C" if STDOUT.tty? && @output_format.json?

      # If the -C option was explicially included
      # and the output format is not JSON;
      # remove it from the args to prevent
      # conversion errors
      @args.delete("-C") if !@output_format.json?

      # Shift off the filter from ARGV
      @args.unshift ARGV.shift unless ARGV.empty?

      input_read, input_write = IO.pipe
      output_read, output_write = IO.pipe

      channel = Channel(Bool).new

      spawn do
        @input_format.converter.deserialize(ARGF, input_write)
        input_write.close
        channel.send true
      rescue ex
        handle_error ex
      end

      spawn do
        output_write.close
        @output_format.converter.serialize(
          output_read,
          STDOUT,
          indent: ((@tab ? "\t" : " ")*@indent),
          xml_root: @xml_root,
          xml_prolog: @xml_prolog,
          xml_item: @xml_item
        )
        channel.send true
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

      exit 1 unless run.success?

      2.times do
        channel.receive
      end
    rescue ex
      handle_error ex
    end

    private def handle_error(ex : Exception)
      abort "oq error: #{ex.message}"
    end
  end
end
