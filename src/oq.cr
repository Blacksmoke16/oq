require "json"
require "xml"
require "yaml"

require "./converters/*"

# A performant, and portable jq wrapper thats facilitates the consumption and output of formats other than JSON; using jq filters to transform the data.
module OQ
  VERSION = "1.2.1"

  # The support formats that can be converted to/from.
  enum Format
    # The [JSON](https://www.json.org/) format.
    JSON

    # Same as `YAML`, but does not support [anchors or aliases](https://yaml.org/spec/1.2/spec.html#id2765878);
    # thus allowing for the input conversion to be streamed, reducing the memory usage for large inputs.
    SimpleYAML

    # The [XML](https://en.wikipedia.org/wiki/XML) format.
    #
    # NOTE: Conversion two and from `JSON` uses [this](https://www.xml.com/pub/a/2006/05/31/converting-between-xml-and-json.html) spec.
    XML

    # The [YAML](https://yaml.org/) format.
    YAML

    # Returns the list of supported formats.
    def self.to_s(io : IO) : Nil
      self.names.join(io, ", ") { |str, join_io| str.downcase join_io }
    end

    # Maps a given format to its converter.
    def converter
      {% begin %}
        case self
          {% for format in @type.constants %}
            in .{{format.underscore.downcase.id}}? then OQ::Converters::{{format.id}}
          {% end %}
        end
      {% end %}
    end
  end

  # Handles the logic of converting the input format (if needed),
  # processing it via [jq](https://stedolan.github.io/jq/),
  # and converting the output format (if needed).
  #
  # ```
  # require "oq"
  #
  # # This could be any `IO`, e.g. an `HTTP` request body, etc.
  # input_io = IO::Memory.new %({"name":"Jim"})
  #
  # # Create a processor, specifying that we want the output format to be `YAML`.
  # processor = OQ::Processor.new output_format: :yaml
  #
  # File.open("./out.yml", "w") do |file|
  #   # Process the data using our custom input and output IOs.
  #   # The first argument represents the input arguments;
  #   # i.g. the filter and/or any other arguments that should be passed to `jq`.
  #   processor.process ["."], input: input_io, output: file
  # end
  # ```
  class Processor
    # The format that the input data is in.
    property input_format : Format

    # The format that the output should be transcoded into.
    property output_format : Format

    # The root of the XML document when transcoding to XML.
    property xml_root : String

    # If the XML prolog should be emitted.
    property xml_prolog : Bool

    # The name for XML array elements without keys.
    property xml_item : String

    # The number of spaces to use for indentation.
    property indent : Int32

    # If a tab for each indentation level instead of spaces.
    property tab : Bool

    # The args that'll be passed to `jq`.
    @args : Array(String) = [] of String

    def initialize(
      @input_format : Format = Format::JSON,
      @output_format : Format = Format::JSON,
      @xml_root : String = "root",
      @xml_prolog : Bool = true,
      @xml_item : String = "item",
      @indent : Int32 = 2,
      @tab : Bool = false
    )
    end

    # Adds the provided *value* to the internal args array.
    def add_arg(value : String) : Nil
      @args << value
    end

    # Keep a reference to the created temp files in order to delete them later.
    @tmp_files = Set(File).new

    # Consumes `#input_format` data from the provided *input* `IO`, along with any *input_args*.
    # The data is then converted to `JSON`, passed to `jq`, and then converted to `#output_format` while being written to the *output* `IO`.
    # Any errors are written to the *error* `IO`.
    def process(input_args : Array(String) = ARGV, input : IO = ARGF, output : IO = STDOUT, error : IO = STDERR) : Nil
      # Register an at_exit handler to cleanup temp files.
      at_exit { @tmp_files.each &.delete }

      # Parse out --rawfile, --argfile, --slurpfile, and -f/--from-file before processing additional args
      # since these options use a file that should not be used as input.
      self.consume_file_args input_args, "--rawfile", "--argfile", "--slurpfile"
      self.consume_file_args input_args, "-f", "--from-file", count: 1

      # Also parse out --arg, and --argjson as they may include identifiers that also exist as a directory/file
      # which would result in incorrect arg extraction.
      self.consume_file_args input_args, "--arg", "--argjson"

      # Extract `jq` arguments from `ARGV`.
      self.extract_args input_args, output

      # Replace the *input* with a fake `ARGF` `IO` to handle both file and `IO` inputs
      # in case `ARGV` is not being used for the input arguments.
      input = IO::ARGF.new input_args, input

      input_buffer = IO::Memory.new
      output_buffer = IO::Memory.new

      # If the input format is not JSON and there is more than 1 file in ARGV,
      # convert each file to JSON from the `#input_format` and save it to a temp file.
      # Then replace ARGV with the temp files.
      if !@input_format.json? && input_args.size > 1
        input_args.replace(input_args.map do |file_name|
          File.tempfile ".#{File.basename file_name}" do |tmp_file|
            File.open file_name do |file|
              @input_format.converter.deserialize file, tmp_file
            end
          end
            .tap { |tf| @tmp_files << tf }
            .path
        end)

        # Conversion has already been completed by this point, so reset input format back to JSON.
        @input_format = :json
      end

      @input_format.converter.deserialize input, input_buffer
      input_buffer.rewind

      run = Process.run(
        "jq",
        @args,
        input: input_buffer,
        output: output_buffer,
        error: error
      )

      unless run.success?
        # Raise this to represent a jq error.
        # jq writes its errors directly to the *error* IO so no need to include a message.
        raise RuntimeError.new
      end

      output_buffer.rewind
      @output_format.converter.serialize(
        output_buffer,
        output,
        indent: ((@tab ? "\t" : " ")*@indent),
        xml_root: @xml_root,
        xml_prolog: @xml_prolog,
        xml_item: @xml_item
      )
    end

    # Parses the *input_args*, extracting `jq` arguments while leaving files
    private def extract_args(input_args : Array(String), output : IO) : Nil
      # Add color option if *output* is a tty
      # and the output format is JSON
      # (Since it will go straight to *output* and not converted)
      input_args.unshift "-C" if output.tty? && @output_format.json? && !input_args.includes? "-C"

      # If the -C option was explicitly included
      # and the output format is not JSON;
      # remove it from *input_args* to prevent
      # conversion errors
      input_args.delete("-C") if !@output_format.json?

      # If there are any files within the *input_args*, ignore "." as it's both a valid file and filter
      idx = if first_file_idx = input_args.index { |a| a != "." && File.exists? a }
              # extract everything else
              first_file_idx - 1
            else
              # otherwise just take it all
              -1
            end

      @args.concat input_args.delete_at 0..idx
    end

    # Extracts *arg_name* from the provided *input_args* if it exists;
    # concatenating the result to the internal arg array.
    private def consume_file_arg(input_args : Array(String), arg_name : String, count : Int32 = 2) : Nil
      input_args.index(arg_name).try { |idx| @args.concat input_args.delete_at idx..(idx + count) }
    end

    private def consume_file_args(input_args : Array(String), *arg_names : String, count : Int32 = 2) : Nil
      arg_names.each { |name| consume_file_arg input_args, name, count }
    end
  end
end
