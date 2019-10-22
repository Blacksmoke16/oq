require "option_parser"

require "./oq"

module OQ
  processor = Processor.new

  OptionParser.parse do |parser|
    parser.banner = "Usage: oq [--help] [oq-arguments] [jq-arguments] jq_filter [file [files...]]"
    parser.on("-h", "--help", "Show this help message.") do
      output = IO::Memory.new
      version = IO::Memory.new

      Process.run("jq", ["-h"], output: output)
      Process.run("jq", ["--version"], output: version)

      puts "oq version: #{OQ::VERSION}, jq version: #{version}", parser, output.to_s.lines.map(&.gsub('\t', "    ")).tap(&.delete_at(0..1)).join('\n')
      exit
    end
    parser.on("-V", "--version", "Returns the current versions of oq and jq.") do
      output = IO::Memory.new

      Process.run("jq", ["--version"], output: output)

      puts "jq: #{output}", "oq: #{OQ::VERSION}"
      exit
    end
    parser.on("-i FORMAT", "--input FORMAT", "Format of the input data. Supported formats: #{Format.to_s}") { |format| (f = Format.parse?(format)) ? processor.input_format = f : abort "Invalid input format: '#{format}'" }
    parser.on("-o FORMAT", "--output FORMAT", "Format of the output data. Supported formats: #{Format.to_s}") { |format| (f = Format.parse?(format)) ? processor.output_format = f : abort "Invalid output format: '#{format}'" }
    parser.on("--indent NUMBER", "Use the given number of spaces for indentation (JSON/XML only).") { |n| processor.indent = n.to_i; processor.args << "--indent"; processor.args << n }
    parser.on("--xml-root ROOT", "Name of the root XML element if converting to XML.") { |r| processor.xml_root = r }
    parser.on("--no-prolog", "Whether the XML prolog should be emitted if converting to XML.") { processor.xml_prolog = false }
    parser.on("--xml-item NAME", "The name for XML array elements without keys.") { |i| processor.xml_item = i }
    parser.invalid_option do |flag|
      case flag
      when "--tab" then processor.tab = true
      when "-L"
        processor.args << flag
        idx = ARGV.index(flag).not_nil!
        processor.args << ARGV[idx + 1]
        ARGV.delete_at idx..(idx + 1)
        next
      end

      processor.args << flag
    end
  end

  processor.process
end
