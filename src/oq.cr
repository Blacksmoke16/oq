require "json"
require "xml"
require "yaml"

require "./converters/*"

# A performant, and portable jq wrapper that facilitates the consumption and output of formats other than JSON; using jq filters to transform the data.
module OQ
  VERSION = "1.3.4"

  # The support formats that can be converted to/from.
  enum Format
    # The [JSON](https://www.json.org/) format.
    JSON

    # Same as `YAML`, but does not support [anchors or aliases](https://yaml.org/spec/1.2/spec.html#id2765878);
    # thus allowing for the input conversion to be streamed, reducing the memory usage for large inputs.
    SimpleYAML

    # The [XML](https://en.wikipedia.org/wiki/XML) format.
    #
    # NOTE: Conversion to and from `JSON` uses [this](https://www.xml.com/pub/a/2006/05/31/converting-between-xml-and-json.html) spec.
    XML

    # The [YAML](https://yaml.org/) format.
    YAML

    # Returns the list of supported formats.
    def self.to_s(io : IO) : Nil
      self.names.join(io, ", ") { |str, join_io| str.downcase join_io }
    end

    # Maps a given format to its converter.
    def converter(processor : OQ::Processor)
      case self
      in .json?        then OQ::Converters::JSON
      in .simple_yaml? then OQ::Converters::SimpleYAML
      in .xml?         then OQ::Converters::XML
      in .yaml?        then OQ::Converters::YAML
      end.tap { |converter| converter.processor = processor if converter.is_a? OQ::Converters::ProcessorAware }
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
  #   # i.e. the filter and/or any other arguments that should be passed to `jq`.
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
    property? xml_prolog : Bool

    # The name for XML array elements without keys.
    property xml_item : String

    # The number of spaces to use for indentation.
    property indent : Int32

    # If a tab for each indentation level instead of spaces.
    property? tab : Bool

    # Do not read any input, using `null` as the singular input value.
    property? null : Bool

    # If XML namespaces should be parsed as well.
    # TODO: Remove this in oq 2.0 as it'll becomethe default.
    property? xmlns : Bool

    # Mapping to namespace aliases to their related namespace.
    protected getter xml_namespaces = Hash(String, String).new

    # Set of elements who should be force expanded to an array.
    protected getter xml_forced_arrays = Set(String).new

    # The args that'll be passed to `jq`.
    @args : Array(String) = [] of String

    # Keep a reference to the created temp files in order to delete them later.
    @tmp_files = Set(File).new

    def initialize(
      @input_format : Format = Format::JSON,
      @output_format : Format = Format::JSON,
      @xml_root : String = "root",
      @xml_prolog : Bool = true,
      @xml_item : String = "item",
      @indent : Int32 = 2,
      @tab : Bool = false,
      @null : Bool = false,
      @xmlns : Bool = false
    )
    end

    @[Deprecated("Use `Processor#tab?` instead.")]
    def tab : Bool
      self.tab?
    end

    @[Deprecated("Use `Processor#xml_prolog?` instead.")]
    def xml_prolog : Bool
      self.xml_prolog?
    end

    # Adds the provided *value* to the internal args array.
    def add_arg(value : String) : Nil
      @args << value
    end

    def add_xml_namespace(prefix : String, href : String) : Nil
      @xml_namespaces[href] = prefix
    end

    def add_forced_array(name : String) : Nil
      xml_forced_arrays << name
    end

    # Consumes `#input_format` data from the provided *input* `IO`, along with any *input_args*.
    # The data is then converted to `JSON`, passed to `jq`, and then converted to `#output_format` while being written to the *output* `IO`.
    # Any errors are written to the *error* `IO`.
    def process(input_args : Array(String) = ARGV, input : IO = ARGF, output : IO = STDOUT, error : IO = STDERR) : Nil
      # Register an at_exit handler to cleanup temp files.
      at_exit { @tmp_files.each &.delete }

      # Parse out --rawfile, --argfile, --slurpfile,-f/--from-file, and -L before processing additional args
      # since these options use a file that should not be used as input.
      self.consume_file_args input_args, "--rawfile", "--argfile", "--slurpfile"
      self.consume_file_args input_args, "-f", "--from-file", "-L", count: 1

      # Also parse out --arg, and --argjson as they may include identifiers that also exist as a directory/file
      # which would result in incorrect arg extraction.
      self.consume_file_args input_args, "--arg", "--argjson"

      # Extract `jq` arguments from `ARGV`.
      self.extract_args input_args, output

      # The --xml-namespace-alias option must be used with the --xmlns option.
      # TODO: Remove this in oq 2.x
      raise ArgumentError.new "The `--xml-namespace-alias` option must be used with the `--xmlns` option." if !@xmlns && !@xml_namespaces.empty?

      # Replace the *input* with a fake `ARGF` `IO` to handle both file and `IO` inputs in case `ARGV` is not being used for the input arguments.
      #
      # If using `null` input, set the input to an empty memory `IO` to essentially consume nothing.
      input = @null ? IO::Memory.new : IO::ARGF.new input_args, input

      input_read, input_write = IO.pipe
      output_read, output_write = IO.pipe

      channel = Channel(Bool | Exception).new

      # If the input format is not JSON and there is more than 1 file in ARGV,
      # convert each file to JSON from the `#input_format` and save it to a temp file.
      # Then replace ARGV with the temp files.
      if !@input_format.json? && input_args.size > 1
        input_args.replace(input_args.map do |file_name|
          File.tempfile ".#{File.basename file_name}" do |tmp_file|
            File.open file_name do |file|
              @input_format.converter(self).deserialize file, tmp_file
            end
          end
            .tap { |tf| @tmp_files << tf }
            .path
        end)

        # Conversion has already been completed by this point, so reset input format back to JSON.
        @input_format = :json
      end

      spawn do
        @input_format.converter(self).deserialize input, input_write
        input_write.close
        channel.send true
      rescue ex
        input_write.close
        channel.send ex
      end

      spawn do
        output_write.close
        @output_format.converter(self).serialize output_read, output
        channel.send true
      rescue ex
        channel.send ex
      end

      run = Process.run(
        "jq",
        @args,
        input: input_read,
        output: output_write,
        error: error
      )

      unless run.success?
        # Raise this to represent a jq error.
        # jq writes its errors directly to the *error* IO so no need to include a message.
        raise RuntimeError.new
      end

      2.times do
        case v = channel.receive
        when Exception then raise v
        end
      end
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
