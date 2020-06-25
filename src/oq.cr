require "json"
require "xml"
require "yaml"

require "./converters/*"

# A performant, and portable jq wrapper thats facilitates the consumption and output of formats other than JSON; using jq filters to transform the data.
module OQ
  VERSION = "1.1.2"

  # The support formats that can be converted to/from.
  enum Format
    Json
    Yaml
    Xml

    # Returns the list of supported formats.
    def self.to_s(io : IO) : Nil
      self.names.join(io, ", ") { |str, join_io| str.downcase join_io }
    end

    # Maps a given format to its converter.
    def converter
      {% begin %}
        case self
          {% for format in @type.constants %}
            in .{{format.downcase.id}}? then OQ::Converters::{{format.id}}
          {% end %}
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

    # If a tab for each indentation level instead of two spaces.
    setter tab : Bool = false

    # Consume the input, convert the input to JSON if needed, pass the input/args to `jq`, then convert the output if needed.
    def process : Nil
      # Parse out --rawfile, --argfile, --slurpfile, and -f/--from-file before processing additional args
      # since these options use a file that should not be used as input
      self.consume_file_args "--rawfile", "--argfile", "--slurpfile"
      self.consume_file_args "-f", "--from-file", count: 1

      # Extract `jq` arguments from `ARGV`
      self.extract_args

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

    # Parses `ARGV`, extracting `jq` arguments while leaving files
    private def extract_args : Nil
      # Add color option if STDOUT is a tty
      # and the output format is JSON
      # (Since it will go straight to STDOUT and not converted)
      ARGV.unshift "-C" if STDOUT.tty? && @output_format.json? && !ARGV.includes? "-C"

      # If the -C option was explicitly included
      # and the output format is not JSON;
      # remove it from the args to prevent
      # conversion errors
      ARGV.delete("-C") if !@output_format.json?

      # If there are any files within ARGV, ignore "." as it's both a valid file and filter
      idx = if first_file_idx = ARGV.index { |arg| arg != "." && File.exists? arg }
              # extract everything else
              first_file_idx - 1
            else
              # otherwise just take it all
              -1
            end

      @args.concat ARGV.delete_at 0..idx
    end

    # Extracts the provided *arg_name* from `ARGV` if it exists;
    # concatenating the result to the internal arg array.
    private def consume_file_arg(arg_name : String, count : Int32 = 2) : Nil
      ARGV.index(arg_name).try { |idx| @args.concat ARGV.delete_at idx..(idx + count) }
    end

    private def consume_file_args(*arg_names : String, count : Int32 = 2) : Nil
      arg_names.each { |name| consume_file_arg name, count }
    end
  end
end
