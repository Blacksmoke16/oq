require "./spec_helper"

SIMPLE_JSON_OBJECT = <<-JSON
{
  "name": "Jim"
}
JSON

NESTED_JSON_OBJECT = <<-JSON
{"foo":{"bar":{"baz":5}}}
JSON

ARRAY_JSON_OBJECT = <<-JSON
{"names":[1,2,3]}
JSON

describe OQ do
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

  describe "with a file input" do
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
        output.should eq(<<-JSON
          {
            "foo": {
              "bar": {
                "baz": 5
              }
            }
          }\n
          JSON
        )
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

      describe "with a JSON object string" do
        it "should return the correct output" do
          run_binary(input: nil, args: ["-cn", %([{"foo":"bar"},{"foo":"baz"}])]) do |output|
            output.should eq %([{"foo":"bar"},{"foo":"baz"}]\n)
          end
        end
      end

      describe "with input from STDIN" do
        it "should return the correct output" do
          run_binary(input: "foo", args: ["-n", "."]) do |output|
            output.should eq "null\n"
          end
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

  describe "when streaming input" do
    it "should return the correct output" do
      run_binary(input: %({"a": [1, 2.2, true, "abc", null]}), args: ["-nc", "--stream", "fromstream( 1|truncate_stream(inputs) |  select(length>1) | .[0] |= .[1:] )"]) do |output|
        output.should eq %(1\n2.2\ntrue\n"abc"\nnull\n)
      end
    end
  end

  describe "when using 'input'" do
    it "should return the correct output" do
      run_binary(args: ["-cnf", "spec/assets/stream-filter", "spec/assets/stream-data.json"]) do |output|
        output.should eq %({"possible_victim01":{"total":3,"evildoers":{"evil.com":2,"soevil.com":1}},"possible_victim02":{"total":1,"evildoers":{"bad.com":1}},"possible_victim03":{"total":1,"evildoers":{"soevil.com":1}}}\n)
      end
    end
  end

  describe "with the -L option" do
    it "should be passed correctly" do
      run_binary(input: SIMPLE_JSON_OBJECT, args: ["-L", "'/home/'", "."]) do |output|
        output.should eq %({\n  "name": "Jim"\n}\n)
      end
    end
  end

  describe "when there is a jq error" do
    it "should return the error and correct exit code" do
      run_binary(input: ARRAY_JSON_OBJECT, args: [".names | .[] | .name"]) do |_, run, error|
        error.should eq %(jq: error (at <stdin>:0): Cannot index number with string "name"\n)
        run.exit_code.should eq 1
      end
    end
  end
end
