require "option_parser"

require "./oq"

processor = OQ::Processor.new

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
  parser.on("-i FORMAT", "--input FORMAT", "Format of the input data. Supported formats: #{OQ::Format}") { |format| (f = OQ::Format.parse?(format)) ? processor.input_format = f : abort "Invalid input format: '#{format}'" }
  parser.on("-o FORMAT", "--output FORMAT", "Format of the output data. Supported formats: #{OQ::Format}") { |format| (f = OQ::Format.parse?(format)) ? processor.output_format = f : abort "Invalid output format: '#{format}'" }
  parser.on("--indent NUMBER", "Use the given number of spaces for indentation (JSON/XML only).") { |n| processor.indent = n.to_i; processor.add_arg "--indent"; processor.add_arg n }
  parser.on("--tab", "Use a tab for each indentation level instead of two spaces.") { processor.tab = true; processor.add_arg "--tab" }
  parser.on("--no-prolog", "Whether the XML prolog should be emitted if converting to XML.") { processor.xml_prolog = false }
  parser.on("--xml-item NAME", "The name for XML array elements without keys.") { |i| processor.xml_item = i }
  parser.on("--xmlns", "If XML namespaces should be parsed.  NOTE: This will become the default in oq 2.x.") { processor.xmlns = true }
  parser.on("--namespace-alias NS", "") { |ns| k, v = ns.split('=', 2); processor.add_xml_namespace k, v }
  parser.on("--xml-root ROOT", "Name of the root XML element if converting to XML.") { |r| processor.xml_root = r }
  parser.invalid_option { }
end

begin
  processor.process
rescue ex : RuntimeError
  # ignore jq errors as it writes directly to error output.
  exit 1
rescue ex
  abort "oq error: #{ex.message}"
end
