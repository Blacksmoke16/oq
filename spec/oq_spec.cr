require "./spec_helper"

SIMPLE_JSON_OBJECT = <<-JSON
{
  "name": "Jim"
}
JSON

NESTED_JSON_OBJECT = <<-JSON
{"foo":{"bar":{"baz":5}}}
JSON

describe Oq do
  describe "when given a filter file" do
    it "should return the correct output" do
      run_binary(input: SIMPLE_JSON_OBJECT, args: ["-f", "spec/assets/test_filter"]) do |output|
        output.should eq %("Jim"\n)
      end
    end
  end

  describe "with a simple filter" do
    it "should return the correct output" do
      run_binary(input: SIMPLE_JSON_OBJECT, args: [".name"]) do |output|
        output.should eq %("Jim"\n)
      end
    end
  end

  describe "with a filter to get nested values" do
    it "should return the correct output" do
      run_binary(input: NESTED_JSON_OBJECT, args: [".foo.bar.baz"]) do |output|
        output.should eq "5\n"
      end
    end
  end

  describe "with a filter to get nested values and YAML input" do
    it "should return the correct output" do
      run_binary(input: "---\nfoo:\n  bar:\n    baz: 5", args: ["-i", "yaml", ".foo.bar.baz"]) do |output|
        output.should eq "5\n"
      end
    end
  end

  describe "with YAML output" do
    it "should return the correct output" do
      run_binary(input: NESTED_JSON_OBJECT, args: ["-o", "yaml", "."]) do |output|
        output.should eq "---\nfoo:\n  bar:\n    baz: 5\n"
      end
    end
  end

  describe "with XML output" do
    it "should return the correct output" do
      run_binary(input: NESTED_JSON_OBJECT, args: ["-o", "xml", "."]) do |output|
        output.should eq "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>\n  <foo>\n    <bar>\n      <baz>5</baz>\n    </bar>\n  </foo>\n</root>\n"
      end
    end
  end

  describe "with YAML input" do
    it "should return the correct output" do
      run_binary(input: "---\nfoo:\n  bar:\n    baz: 5\n", args: ["-c", "-i", "yaml", "."]) do |output|
        output.should eq "#{NESTED_JSON_OBJECT}\n"
      end
    end
  end

  describe "with a JSON file input" do
    it "should return the correct output" do
      run_binary(input: "", args: [".", "spec/assets/data1.json"]) do |output|
        output.should eq "#{SIMPLE_JSON_OBJECT}\n"
      end
    end
  end

  describe "with multiple JSON file input" do
    it "should return the correct output" do
      run_binary(input: "", args: ["-c", ".", "spec/assets/data1.json", "spec/assets/data2.json"]) do |output|
        output.should eq %({"name":"Jim"}\n{"name":"Bob"}\n)
      end
    end
  end

  describe "with multiple JSON file input and slurp" do
    it "should return the correct output" do
      run_binary(input: "", args: ["-c", "--slurp", ".", "spec/assets/data1.json", "spec/assets/data2.json"]) do |output|
        output.should eq %([{"name":"Jim"},{"name":"Bob"}]\n)
      end
    end
  end

  describe "with multiple YAML file input" do
    it "should return the correct output" do
      run_binary(input: "", args: ["-c", "-i", "yaml", ".", "spec/assets/data1.yml", "spec/assets/data2.yml"]) do |output|
        output.should eq %({"name":"Jim"}\n{"age":17}\n)
      end
    end
  end

  describe "with multiple YAML file input and slurp" do
    it "should return the correct output" do
      run_binary(input: "", args: ["-c", "-i", "yaml", "-s", ".", "spec/assets/data1.yml", "spec/assets/data2.yml"]) do |output|
        output.should eq %([{"name":"Jim"},{"age":17}]\n)
      end
    end
  end

  describe "with STDIN YAML input and slurp" do
    it "should return the correct output" do
      run_binary(input: "---\nname: Jim", args: ["-c", "-i", "yaml", "-s", "."]) do |output|
        output.should eq %([{"name":"Jim"}]\n)
      end
    end
  end

  describe "with YAML input and XML output" do
    it "should convert between formats" do
      run_binary(input: "---\nfoo:\n  bar:\n    baz: 5\n", args: ["-i", "yaml", "-o", "xml", "."]) do |output|
        output.should eq "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>\n  <foo>\n    <bar>\n      <baz>5</baz>\n    </bar>\n  </foo>\n</root>\n"
      end
    end
  end

  describe "with raw output" do
    it "should return the correct output" do
      run_binary(input: "", args: ["-R", "-o", "yaml", ".", "spec/assets/data1.json"]) do |output|
        output.should eq %(--- '{"name": "Jim"}'\n)
      end
    end
  end

  describe "with the -c options" do
    it "should return the correct output" do
      run_binary(input: NESTED_JSON_OBJECT, args: ["-c", "."]) do |output|
        output.should eq %({"foo":{"bar":{"baz":5}}}\n)
      end
    end
  end

  describe "without the -c options" do
    it "should return the correct output" do
      run_binary(input: NESTED_JSON_OBJECT, args: ["."]) do |output|
        output.should eq %({\n  "foo": {\n    "bar": {\n      "baz": 5\n    }\n  }\n}\n)
      end
    end
  end

  describe "with null input option" do
    describe "with a scalar value" do
      it "should return the correct output" do
        run_binary(input: nil, args: ["-n", "0"]) do |output|
          output.should eq "0\n"
        end
      end

      it "should return the correct output" do
        run_binary(input: nil, args: ["--null-input", "0"]) do |output|
          output.should eq "0\n"
        end
      end
    end

    describe "with a JSON object string" do
      it "should return the correct output" do
        run_binary(input: nil, args: ["-cn", %([{"foo":"bar"},{"foo":"baz"}])]) do |output|
          output.should eq %([{"foo":"bar"},{"foo":"baz"}]\n)
        end
      end
    end

    describe "with input from STDIN" do
      it "should return the correct output" do
        run_binary(input: "foo", args: ["-n"]) do |output|
          output.should eq "null\n"
        end
      end
    end
  end

  describe "with a custom indent value with JSON" do
    it "should return the correct output" do
      run_binary(input: SIMPLE_JSON_OBJECT, args: ["--indent", "1", "."]) do |output|
        output.should eq %({\n "name": "Jim"\n}\n)
      end
    end
  end

  describe "with the --tab option" do
    it "should return the correct output" do
      run_binary(input: SIMPLE_JSON_OBJECT, args: ["--tab", "."]) do |output|
        output.should eq %({\n\t"name": "Jim"\n}\n)
      end
    end
  end

  describe "with a custom indent value with XML" do
    it "should return the correct output" do
      run_binary(input: SIMPLE_JSON_OBJECT, args: ["--indent", "3", "-o", "xml", "."]) do |output|
        output.should eq "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root>\n   <name>Jim</name>\n</root>\n"
      end
    end
  end

  describe "with a custom XML root" do
    it "should return the correct output" do
      run_binary(input: SIMPLE_JSON_OBJECT, args: ["--xml-root", "friends", "-o", "xml", "."]) do |output|
        output.should eq "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<friends>\n  <name>Jim</name>\n</friends>\n"
      end
    end
  end

  describe "when streaming input" do
    it "should return the correct output" do
      run_binary(input: %({"a": [1, 2.2, true, "abc", null]}), args: ["-nc", "--stream", "fromstream( 1|truncate_stream(inputs) |  select(length>1) | .[0] |= .[1:] )"]) do |output|
        output.should eq %(1\n2.2\ntrue\n"abc"\nnull\n)
      end
    end
  end

  describe "with XML input" do
    it "should return not implemented" do
      run_binary(input: "", args: ["-i", "xml", "."]) do |output, status|
        output.should eq "Not Implemented\n"
        status.exit_code.should eq 1
      end
    end
  end
end
