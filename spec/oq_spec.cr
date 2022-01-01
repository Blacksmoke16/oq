require "./spec_helper"

private SIMPLE_JSON_OBJECT = <<-JSON
{
  "name": "Jim"
}
JSON

private NESTED_JSON_OBJECT = <<-JSON
{"foo":{"bar":{"baz":5}}}
JSON

private ARRAY_JSON_OBJECT = <<-JSON
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

  it "with a simple filter" do
    run_binary(input: SIMPLE_JSON_OBJECT, args: [".name"]) do |output|
      output.should eq %("Jim"\n)
    end
  end

  it "with a filter to get nested values" do
    run_binary(input: NESTED_JSON_OBJECT, args: [".foo.bar.baz"]) do |output|
      output.should eq "5\n"
    end
  end

  it "should colorize the output with the -C option" do
    run_binary(input: SIMPLE_JSON_OBJECT, args: ["-c", "-C", "."]) do |output|
      output.should eq %(\e[1;39m{\e[0m\e[34;1m"name"\e[0m\e[1;39m:\e[0m\e[0;32m"Jim"\e[0m\e[1;39m\e[1;39m}\e[0m\n)
    end
  end

  describe "with a non-JSON output format" do
    it "should convert the JSON to that format" do
      run_binary(input: SIMPLE_JSON_OBJECT, args: ["-o", "yaml", "."]) do |output|
        output.should eq "---\nname: Jim\n"
      end
    end

    describe "with the -C option" do
      it "should remove the -C option" do
        run_binary(input: SIMPLE_JSON_OBJECT, args: ["-o", "yaml", "-C", "."]) do |output|
          output.should eq "---\nname: Jim\n"
        end
      end
    end
  end

  describe "files" do
    describe "with a file input" do
      it "should return the correct output" do
        run_binary(args: [".", "spec/assets/data1.json"]) do |output|
          output.should eq "#{SIMPLE_JSON_OBJECT}\n"
        end
      end
    end

    describe "with multiple JSON file input" do
      it "raw data" do
        run_binary(args: ["-c", ".", "spec/assets/data1.json", "spec/assets/data2.json"]) do |output|
          output.should eq %({"name":"Jim"}\n{"name":"Bob"}\n)
        end
      end

      it "--slurp" do
        run_binary(args: ["-c", "--slurp", ".", "spec/assets/data1.json", "spec/assets/data2.json"]) do |output|
          output.should eq %([{"name":"Jim"},{"name":"Bob"}]\n)
        end
      end
    end

    describe "with multiple non JSON file input" do
      it "raw data" do
        run_binary(args: ["-i", "yaml", "-c", ".", "spec/assets/data1.yml", "spec/assets/data2.yml"]) do |output|
          output.should eq %({"name":"Jim"}\n{"age":17,"name":"Fred"}\n)
        end
      end

      it "--slurp" do
        run_binary(args: ["-i", "yaml", "-c", "--slurp", ".", "spec/assets/data1.yml", "spec/assets/data2.yml"]) do |output|
          output.should eq %([{"name":"Jim"},{"age":17,"name":"Fred"}]\n)
        end
      end
    end

    it "with multiple --arg" do
      run_binary(args: ["-c", "-r", "--arg", "chart", "stolon", "--arg", "version", "1.5.10", "$version", "spec/assets/data1.json"]) do |output|
        output.should eq %(1.5.10\n)
      end
    end
  end

  it "should minify the output with the -c option" do
    run_binary(input: NESTED_JSON_OBJECT, args: ["-c", "."]) do |output|
      output.should eq %({"foo":{"bar":{"baz":5}}}\n)
    end
  end

  it "should format the output without the -c option" do
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

  describe "with null input option" do
    describe "with a scalar value" do
      it "should return the correct output" do
        run_binary(args: ["-n", "0"]) do |output|
          output.should eq "0\n"
        end
      end

      it "should return the correct output" do
        run_binary(args: ["--null-input", "0"]) do |output|
          output.should eq "0\n"
        end
      end
    end

    describe "with a JSON object string" do
      it "should return the correct output" do
        run_binary(args: ["-cn", %([{"foo":"bar"},{"foo":"baz"}])]) do |output|
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

    it "should not block waiting for input" do
      run_binary(input: Process::Redirect::Inherit, args: ["-n", "."]) do |output|
        output.should eq "null\n"
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
      run_binary(args: ["-cn", "-f", "spec/assets/stream-filter", "spec/assets/stream-data.json"]) do |output|
        output.should eq %({"possible_victim01":{"total":3,"evildoers":{"evil.com":2,"soevil.com":1}},"possible_victim02":{"total":1,"evildoers":{"bad.com":1}},"possible_victim03":{"total":1,"evildoers":{"soevil.com":1}}}\n)
      end
    end
  end

  describe "with the -L option" do
    it "should be passed correctly without a space" do
      run_binary(args: ["-n", "-L#{__DIR__}/assets", %(import "test" as test; 9 | test::increment)]) do |output|
        output.should eq %(10\n)
      end
    end

    it "should be passed correctly with a space" do
      run_binary(args: ["-n", "-L", "#{__DIR__}/assets", %(import "test" as test; 9 | test::increment)]) do |output|
        output.should eq %(10\n)
      end
    end
  end

  describe "--arg" do
    it "single arg" do
      run_binary(args: ["-cn", "--arg", "foo", "bar", %({"name":$foo})]) do |output|
        output.should eq %({"name":"bar"}\n)
      end
    end

    it "multiple arg" do
      run_binary(args: ["-rcn", "-r", "--arg", "chart", "stolon", "--arg", "version", "1.5.10", "$version"]) do |output|
        output.should eq %(1.5.10\n)
      end
    end

    it "different option in between args" do
      run_binary(args: ["-rcn", "--arg", "chart", "stolon", "--arg", "version", "1.5.10", "$version"]) do |output|
        output.should eq %(1.5.10\n)
      end
    end

    it "when the arg name matches a directory name" do
      run_binary(args: ["-rcn", "--arg", "spec", "dir", "$spec"]) do |output|
        output.should eq %(dir\n)
      end
    end
  end

  describe "with the --argjson option" do
    it "should be passed correctly" do
      run_binary(args: ["-rcn", "--argjson", "foo", "123", %({"id":$foo})]) do |output|
        output.should eq %({"id":123}\n)
      end
    end

    it "when the arg name matches a directory name" do
      run_binary(args: ["-rcn", "--argjson", "spec", "123", "$spec"]) do |output|
        output.should eq %(123\n)
      end
    end
  end

  describe "with the --slurpfile option" do
    it "should be passed correctly" do
      run_binary(args: ["-rcn", "--slurpfile", "ids", "spec/assets/raw.json", %({"ids":$ids})]) do |output|
        output.should eq %({"ids":[1,2,3]}\n)
      end
    end
  end

  describe "with the --rawfile option" do
    it "should be passed correctly" do
      run_binary(args: ["-rcn", "--rawfile", "ids", "spec/assets/raw.json", %({"ids":$ids})]) do |output|
        output.should eq %({"ids":"1\\n2\\n3\\n"}\n)
      end
    end
  end

  describe "with the --args option" do
    it "should be passed correctly" do
      run_binary(args: ["-rcn", %({"ids":$ARGS.positional}), "--args", "1", "2", "3"]) do |output|
        output.should eq %({"ids":["1","2","3"]}\n)
      end
    end
  end

  describe "with the --jsonargs option" do
    it "should be passed correctly" do
      run_binary(args: ["-rcn", %({"ids":$ARGS.positional}), "--jsonargs", "1", "2", "3"]) do |output|
        output.should eq %({"ids":[1,2,3]}\n)
      end
    end
  end

  describe "when there is a jq error" do
    it "should return the error and correct exit code" do
      run_binary(input: ARRAY_JSON_OBJECT, args: [".names | .[] | .name"], success: false) do |_, _, error|
        error.should eq %(jq: error (at <stdin>:0): Cannot index number with string "name"\n)
      end
    end
  end

  describe "with an invalid input format" do
    it "should return the error and correct exit code" do
      run_binary(input: SIMPLE_JSON_OBJECT, args: ["-i", "foo"], success: false) do |_, _, error|
        error.should eq %(Invalid input format: 'foo'\n)
      end
    end
  end

  describe "with an invalid output format" do
    it "should return the error and correct exit code" do
      run_binary(input: SIMPLE_JSON_OBJECT, args: ["-o", "foo"], success: false) do |_, _, error|
        error.should eq %(Invalid output format: 'foo'\n)
      end
    end
  end
end
