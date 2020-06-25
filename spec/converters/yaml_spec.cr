require "../spec_helper"

LITERAL_BLOCK = <<-YAML
---
literal_block: |
    This entire block of text will be the value of the 'literal_block' key,
    with line breaks being preserved.

    The literal continues until de-dented, and the leading indentation is
    stripped.

        Any lines that are 'more-indented' keep the rest of their indentation -
        these lines will be indented by 4 spaces.
YAML

FOLDED_BLOCK = <<-YAML
folded_style: >
    This entire block of text will be the value of 'folded_style', but this
    time, all newlines will be replaced with a single space.

    Blank lines, like above, are converted to a newline character.

        'More-indented' lines keep their newlines, too -
        this text will appear over two lines.
YAML

NESTED_OBJECT = <<-YAML
a_nested_map:
  key: value
  another_key: Another Value
  another_nested_map:
    hello: hello
YAML

COMPLEX_MAPPING_KEY = <<-YAML
? |
  This is a key
  that has multiple lines
: and this is its value
YAML

COMPLEX_SEQUENCE_KEY = <<-YAML
? - Manchester United
  - Real Madrid
: [2001-01-01, 2002-02-02]
YAML

NESTED_ARRAY = <<-YAML
a_sequence:
  - Item 1
  - Item 2
  - 0.5  # sequences can contain disparate types.
  - Item 4
  - key: value
    another_key: another_value
  -
    - This is a sequence
    - inside another sequence
  - - - Nested sequence indicators
      - can be collapsed
YAML

ANCHORS = <<-YAML
base: &base
  name: Everyone has same name
foo: &foo
  <<: *base
  age: 10
bar: &bar
  <<: *base
  age: 20
YAML

describe OQ::Converters::Yaml do
  describe ".deserialize" do
    describe String do
      describe "not blank" do
        it "should output correctly" do
          run_binary(%(--- Jim), args: ["-i", "yaml", "."]) do |output|
            output.should eq %("Jim"\n)
          end
        end
      end

      describe "blank" do
        it "should output correctly" do
          run_binary(%(--- ), args: ["-i", "yaml", "."]) do |output|
            output.should eq "null\n"
          end
        end
      end

      describe "with a tag" do
        it "should output correctly" do
          run_binary(%(--- !!str 0.5), args: ["-i", "yaml", "."]) do |output|
            output.should eq %("0.5"\n)
          end
        end
      end

      describe "that is single quoted" do
        it "should output correctly" do
          run_binary(%(---\nhowever: 'foobar'), args: ["-i", "yaml", "-c", "."]) do |output|
            output.should eq %({"however":"foobar"}\n)
          end
        end
      end

      describe "that is double quoted" do
        it "should output correctly" do
          run_binary(%(---\nhowever: "foobar"), args: ["-i", "yaml", "-c", "."]) do |output|
            output.should eq %({"however":"foobar"}\n)
          end
        end
      end

      describe "literal block" do
        it "should output correctly" do
          run_binary(LITERAL_BLOCK, args: ["-i", "yaml", "-c", "."]) do |output|
            output.should eq %({"literal_block":"This entire block of text will be the value of the 'literal_block' key,\\nwith line breaks being preserved.\\n\\nThe literal continues until de-dented, and the leading indentation is\\nstripped.\\n\\n    Any lines that are 'more-indented' keep the rest of their indentation -\\n    these lines will be indented by 4 spaces."}\n)
          end
        end
      end

      describe "folded block" do
        it "should output correctly" do
          run_binary(FOLDED_BLOCK, args: ["-i", "yaml", "-c", "."]) do |output|
            output.should eq %({"folded_style":"This entire block of text will be the value of 'folded_style', but this time, all newlines will be replaced with a single space.\\nBlank lines, like above, are converted to a newline character.\\n\\n    'More-indented' lines keep their newlines, too -\\n    this text will appear over two lines."}\n)
          end
        end
      end
    end

    describe Bool do
      it "should output correctly" do
        run_binary(%(--- true), args: ["-i", "yaml", "."]) do |output|
          output.should eq "true\n"
        end
      end
    end

    describe Float do
      it "should output correctly" do
        run_binary(%(--- 10.50), args: ["-i", "yaml", "."]) do |output|
          output.should eq "10.5\n"
        end
      end
    end

    describe Nil do
      it "should output correctly" do
        run_binary(%(--- ), args: ["-i", "yaml", "."]) do |output|
          output.should eq "null\n"
        end
      end
    end

    describe Object do
      describe "a simple object" do
        it "should output correctly" do
          run_binary(%(---\nname: Jim), args: ["-i", "yaml", "-c", "."]) do |output|
            output.should eq %({"name":"Jim"}\n)
          end
        end
      end

      describe "with spaces in the key" do
        it "should output correctly" do
          run_binary(%(---\nkey with spaces: value), args: ["-i", "yaml", "-c", "."]) do |output|
            output.should eq %({"key with spaces":"value"}\n)
          end
        end
      end

      describe "with a quoted key key" do
        it "should output correctly" do
          run_binary(%(---\n'Keys can be quoted too.': value), args: ["-i", "yaml", "-c", "."]) do |output|
            output.should eq %({"Keys can be quoted too.":"value"}\n)
          end
        end
      end

      describe "with nested object" do
        it "should output correctly" do
          run_binary(NESTED_OBJECT, args: ["-i", "yaml", "-c", "."]) do |output|
            output.should eq %({"a_nested_map":{"key":"value","another_key":"Another Value","another_nested_map":{"hello":"hello"}}}\n)
          end
        end
      end

      describe "with a non string key" do
        it "should output correctly" do
          run_binary(%(---\n0.25: a float key), args: ["-i", "yaml", "-c", "."]) do |output|
            output.should eq %({"0.25":"a float key"}\n)
          end
        end
      end

      describe "with JSON syntax" do
        describe "with quotes" do
          it "should output correctly" do
            run_binary(%(---\njson_seq: {"key": "value"}), args: ["-i", "yaml", "-c", "."]) do |output|
              output.should eq %({"json_seq":{"key":"value"}}\n)
            end
          end
        end

        describe "without quotes" do
          it "should output correctly" do
            run_binary(%(---\njson_seq: {key: value}), args: ["-i", "yaml", "-c", "."]) do |output|
              output.should eq %({"json_seq":{"key":"value"}}\n)
            end
          end
        end
      end

      describe "with a complex mapping key" do
        it "should output correctly" do
          run_binary(COMPLEX_MAPPING_KEY, args: ["-i", "yaml", "-c", "."]) do |output|
            output.should eq %({"This is a key\\nthat has multiple lines\\n":"and this is its value"}\n)
          end
        end
      end

      describe "with set notation" do
        it "should output correctly" do
          run_binary(%(---\nset:\n  ? item1\n  ? item2), args: ["-i", "yaml", "-c", "."]) do |output|
            output.should eq %({"set":{"item1":null,"item2":null}}\n)
          end
        end
      end

      pending "with a complex sequence key" do
        it "should output correctly" do
          run_binary(COMPLEX_SEQUENCE_KEY, args: ["-i", "yaml", "-c", "."]) do |output|
            output.should eq %({"["Manchester United", "Real Madrid"]":["2001-01-01T00:00:00Z","2002-02-02T00:00:00Z"]}\n)
          end
        end
      end

      describe "with anchors" do
        it "should output correctly" do
          run_binary(ANCHORS, args: ["-i", "yaml", "-c", "."]) do |output|
            output.should eq %({"base":{"name":"Everyone has same name"},"foo":{"name":"Everyone has same name","age":10},"bar":{"name":"Everyone has same name","age":20}}\n)
          end
        end
      end
    end

    describe Array do
      describe "with mixed/nested array values" do
        it "should output correctly" do
          run_binary(NESTED_ARRAY, args: ["-i", "yaml", "-c", "."]) do |output|
            output.should eq %({"a_sequence":["Item 1","Item 2",0.5,"Item 4",{"key":"value","another_key":"another_value"},["This is a sequence","inside another sequence"],[["Nested sequence indicators","can be collapsed"]]]}\n)
          end
        end
      end

      describe "with JSON syntax" do
        describe "with quotes" do
          it "should output correctly" do
            run_binary(%(---\njson_seq: [3, 2, 1, "takeoff"]), args: ["-i", "yaml", "-c", "."]) do |output|
              output.should eq %({"json_seq":[3,2,1,"takeoff"]}\n)
            end
          end
        end

        describe "without quotes" do
          it "should output correctly" do
            run_binary(%(---\njson_seq: [3, 2, 1, takeoff]), args: ["-i", "yaml", "-c", "."]) do |output|
              output.should eq %({"json_seq":[3,2,1,"takeoff"]}\n)
            end
          end
        end
      end
    end
  end

  describe ".serialize" do
    describe String do
      describe "not blank" do
        it "should output correctly" do
          run_binary(%("Jim"), args: ["-o", "yaml", "."]) do |output|
            output.should start_with <<-YAML
            --- Jim
            YAML
          end
        end
      end

      describe "blank" do
        it "should output correctly" do
          run_binary(%(""), args: ["-o", "yaml", "."]) do |output|
            output.should eq(<<-YAML
              --- ""\n
              YAML
            )
          end
        end
      end
    end

    describe Bool do
      it "should output correctly" do
        run_binary(%(true), args: ["-o", "yaml", "."]) do |output|
          output.should start_with <<-YAML
            --- true
            YAML
        end
      end
    end

    describe Float do
      it "should output correctly" do
        run_binary(%("1.5"), args: ["-o", "yaml", "."]) do |output|
          output.should eq(<<-YAML
            --- "1.5"\n
            YAML
          )
        end
      end
    end

    describe Nil do
      it "should output correctly" do
        run_binary("null", args: ["-o", "yaml", "."]) do |output|
          output.should start_with "---"
        end
      end
    end

    describe Array do
      describe "empty array on root" do
        it "should emit a self closing root tag" do
          run_binary("[]", args: ["-o", "yaml", "."]) do |output|
            output.should eq(<<-YAML
              --- []\n
              YAML
            )
          end
        end
      end

      describe "array with values on root" do
        it "should emit item tags for non empty values" do
          run_binary(%(["x",{}]), args: ["-o", "yaml", "."]) do |output|
            output.should eq(<<-YAML
              ---
              - x
              - {}\n
              YAML
            )
          end
        end
      end

      describe "object with empty array/values" do
        it "should emit self closing tags for each" do
          run_binary(%({"a":[],"b":{},"c":null}), args: ["-o", "yaml", "."]) do |output|
            output.should start_with <<-YAML
              ---
              a: []
              b: {}
              c:
              YAML
          end
        end
      end

      describe "2D array object value" do
        it "should emit key name tag then self closing item tag" do
          run_binary(%({"a":[[]]}), args: ["-o", "yaml", "."]) do |output|
            output.should eq(<<-YAML
              ---
              a:
              - []\n
              YAML
            )
          end
        end
      end

      describe "object value mixed/nested array values" do
        it "should emit correctly" do
          run_binary(%({"x":[1,[2,[3]]]}), args: ["-o", "yaml", "."]) do |output|
            output.should eq(<<-YAML
              ---
              x:
              - 1
              - - 2
                - - 3\n
              YAML
            )
          end
        end
      end

      describe "object value array primitive values" do
        it "should emit correctly" do
          run_binary(%({"x":[1,2,3]}), args: ["-o", "yaml", "."]) do |output|
            output.should eq(<<-YAML
              ---
              x:
              - 1
              - 2
              - 3\n
              YAML
            )
          end
        end
      end
    end

    describe Object do
      describe "simple key/value" do
        it "should output correctly" do
          run_binary(%({"name":"Jim"}), args: ["-o", "yaml", "."]) do |output|
            output.should eq(<<-YAML
              ---
              name: Jim\n
              YAML
            )
          end
        end
      end

      describe "nested object" do
        it "should output correctly" do
          run_binary(%({"name":"Jim", "city": {"street":"forbs"}}), args: ["-o", "yaml", "."]) do |output|
            output.should eq(<<-YAML
              ---
              name: Jim
              city:
                street: forbs\n
              YAML
            )
          end
        end
      end
    end
  end
end
