require "option_parser"

require "./omni_q"

module Oq
  processor = Processor.new

  OptionParser.parse! do |parser|
    parser.banner = "Usage: oq [--help] [oq-arguments] [jq-arguments] jq_filter [file [files...]]"
    parser.on("--help", "Show this help message.") { puts parser; exit }
    parser.on("-i FORMAT", "--input FORMAT", "Format of the input data. Supported formats: #{Format.names.map(&.downcase).join(", ")}.") { |format| (f = Format.parse?(format)) ? processor.input_format = f : (puts "Invalid input format: '#{format}'"; exit(1)) }
    parser.on("-o FORMAT", "--output FORMAT", "Format of the output data. Supported formats: #{Format.names.map(&.downcase).join(", ")}.") { |format| (f = Format.parse?(format)) ? processor.output_format = f : (puts "Invalid output format: '#{format}'"; exit(1)) }
    parser.on("--xml-root=ROOT", "Name of the root XML element if converting to XML.") { |r| processor.xml_root = r }
    parser.on("-s", "--slurp", "Read (slurp) all inputs into an array then apply filter to it.") { processor.slurp = true; processor.args << "-s" }
    parser.invalid_option do |flag|
      processor.args << flag
      ARGV.delete flag
    end
  end

  processor.process
end
