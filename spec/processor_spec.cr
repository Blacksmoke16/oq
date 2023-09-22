require "./spec_helper"

describe OQ::Processor do
  describe "custom IOs" do
    it "works with \"STDIN\" input" do
      input_io = IO::Memory.new %({"name":"Jim"})
      output_io = IO::Memory.new

      OQ::Processor.new.process input_args: [".name"], input: input_io, output: output_io

      output_io.to_s.should eq %("Jim"\n)
    end

    it "works with custom error output" do
      input_io = IO::Memory.new %({"name:"Jim"})
      output_io = IO::Memory.new
      error_io = IO::Memory.new

      expect_raises RuntimeError do
        OQ::Processor.new.process input_args: [".name"], input: input_io, output: output_io, error: error_io
      end

      output_io.to_s.should be_empty
      error_io.to_s.should contain "parse error: Invalid numeric literal at line 1, column 12\n"
    end

    describe "file input" do
      it "single file" do
        output_io = IO::Memory.new

        OQ::Processor.new.process input_args: [".", "-c", "spec/assets/data1.json"], output: output_io

        output_io.to_s.should eq %({"name":"Jim"}\n)
      end

      it "single file, standard input IO" do
        input_io = IO::Memory.new
        output_io = IO::Memory.new

        OQ::Processor.new.process input_args: [".", "-c", "spec/assets/data1.json"], input: input_io, output: output_io

        output_io.to_s.should eq %({"name":"Jim"}\n)
      end

      it "multiple file" do
        output_io = IO::Memory.new

        OQ::Processor.new.process input_args: [".", "-c", "spec/assets/data1.json", "spec/assets/data2.json"], output: output_io

        output_io.to_s.should eq %({"name":"Jim"}\n{"name":"Bob"}\n)
      end

      it "multiple files and --slurp" do
        output_io = IO::Memory.new

        OQ::Processor.new.process input_args: [".", "-c", "-s", "spec/assets/data1.json", "spec/assets/data2.json"], output: output_io

        output_io.to_s.should eq %([{"name":"Jim"},{"name":"Bob"}]\n)
      end
    end
  end
end
