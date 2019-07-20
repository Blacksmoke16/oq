require "../spec_helper"

describe OQ::Converters::Xml do
  it "allows not emitting the xml prolog" do
    run_binary("1", args: ["-o", "xml", "--no-prolog", "."]) do |output|
      output.should eq(<<-XML
        <root>1</root>\n
        XML
      )
    end
  end

  describe "allows setting the root element" do
    describe "to another string" do
      it "should use the provided name" do
        run_binary("1", args: ["-o", "xml", "--xml-root", "foo", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <foo>1</foo>\n
            XML
          )
        end
      end
    end

    describe "to an empty string" do
      it "should not be emitted" do
        run_binary("1", args: ["-o", "xml", "--xml-root", "", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            1
            XML
          )
        end
      end
    end

    describe "it allows changing the array item name" do
      describe "with a single nesting level" do
        it "should emit item tags for non empty values" do
          run_binary(%(["x",{}]), args: ["-o", "xml", "--xml-item", "foo", "."]) do |output|
            output.should eq(<<-XML
              <?xml version="1.0" encoding="UTF-8"?>
              <root>
                <foo>x</foo>
                <foo/>
              </root>\n
              XML
            )
          end
        end
      end

      describe "with a larger nesting level" do
        it "should emit item tags for non empty values" do
          run_binary(%({"a":[[]]}), args: ["-o", "xml", "--xml-item", "foo", "."]) do |output|
            output.should eq(<<-XML
              <?xml version="1.0" encoding="UTF-8"?>
              <root>
                <a>
                  <foo/>
                </a>
              </root>\n
              XML
            )
          end
        end
      end
    end

    describe "it allows changing the indent" do
      describe "more spaces" do
        it "should emit the extra spaces" do
          run_binary(%({"name": "Jim", "age": 12}), args: ["-o", "xml", "--indent", "4", "."]) do |output|
            output.should eq(<<-XML
              <?xml version="1.0" encoding="UTF-8"?>
              <root>
                  <name>Jim</name>
                  <age>12</age>
              </root>\n
              XML
            )
          end
        end
      end

      describe "to tabs" do
        it "should emit the indent as tabs" do
          run_binary(%({"name": "Jim", "age": 12}), args: ["-o", "xml", "--indent", "3", "--tab", "."]) do |output|
            output.should eq(<<-XML
              <?xml version="1.0" encoding="UTF-8"?>
              <root>
              \t\t\t<name>Jim</name>
              \t\t\t<age>12</age>
              </root>\n
              XML
            )
          end
        end
      end
    end
  end

  describe String do
    describe "not blank" do
      it "should output correctly" do
        run_binary(%("Jim"), args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root>Jim</root>\n
            XML
          )
        end
      end
    end

    describe "blank" do
      it "should output correctly" do
        run_binary(%(""), args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root></root>\n
            XML
          )
        end
      end
    end
  end

  describe Bool do
    it "should output correctly" do
      run_binary(%(true), args: ["-o", "xml", "."]) do |output|
        output.should eq(<<-XML
          <?xml version="1.0" encoding="UTF-8"?>
          <root>true</root>\n
          XML
        )
      end
    end
  end

  describe Float do
    it "should output correctly" do
      run_binary(%("1.5"), args: ["-o", "xml", "."]) do |output|
        output.should eq(<<-XML
          <?xml version="1.0" encoding="UTF-8"?>
          <root>1.5</root>\n
          XML
        )
      end
    end
  end

  describe Nil do
    it "should output correctly" do
      run_binary("null", args: ["-o", "xml", "."]) do |output|
        output.should eq(<<-XML
          <?xml version="1.0" encoding="UTF-8"?>
          <root/>\n
          XML
        )
      end
    end
  end

  describe Array do
    describe "empty array on root" do
      it "should emit a self closing root tag" do
        run_binary("[]", args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root/>\n
            XML
          )
        end
      end
    end

    describe "array with values on root" do
      it "should emit item tags for non empty values" do
        run_binary(%(["x",{}]), args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root>
              <item>x</item>
              <item/>
            </root>\n
            XML
          )
        end
      end
    end

    describe "object with empty array/values" do
      it "should emit self closing tags for each" do
        run_binary(%({"a":[],"b":{},"c":null}), args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root>
              <a/>
              <b/>
              <c/>
            </root>\n
            XML
          )
        end
      end
    end

    describe "2D array object value" do
      it "should emit key name tag then self closing item tag" do
        run_binary(%({"a":[[]]}), args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root>
              <a>
                <item/>
              </a>
            </root>\n
            XML
          )
        end
      end
    end

    describe "object value mixed/nested array values" do
      it "should emit correctly" do
        run_binary(%({"x":[1,[2,[3]]]}), args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root>
              <x>1</x>
              <x>
                <item>2</item>
                <item>
                  <item>3</item>
                </item>
              </x>
            </root>\n
            XML
          )
        end
      end
    end

    describe "object value array primitive values" do
      it "should emit correctly" do
        run_binary(%({"x":[1,2,3]}), args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root>
              <x>1</x>
              <x>2</x>
              <x>3</x>
            </root>\n
            XML
          )
        end
      end
    end
  end

  describe Object do
    describe "simple key/value" do
      it "should output correctly" do
        run_binary(%({"name":"Jim"}), args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root>
              <name>Jim</name>
            </root>\n
            XML
          )
        end
      end
    end

    describe "nested object" do
      it "should output correctly" do
        run_binary(%({"name":"Jim", "city": {"street":"forbs"}}), args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root>
              <name>Jim</name>
              <city>
                <street>forbs</street>
              </city>
            </root>\n
            XML
          )
        end
      end
    end

    describe "with an attribute" do
      it "should output correctly" do
        run_binary(%({"name":"Jim", "city": {"@street":"forbs"}}), args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root>
              <name>Jim</name>
              <city street="forbs"/>
            </root>\n
            XML
          )
        end
      end
    end

    describe "with an attribute and #text" do
      it "should output correctly" do
        run_binary(%({"name":"Jim", "city": {"@street":"forbs", "#text": "Atlantic"}}), args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root>
              <name>Jim</name>
              <city street="forbs">Atlantic</city>
            </root>\n
            XML
          )
        end
      end
    end

    describe "with attributes" do
      it "should output correctly" do
        run_binary(%({"name":"Jim", "city": {"@street":"forbs", "@post": 123}}), args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root>
              <name>Jim</name>
              <city street="forbs" post="123"/>
            </root>\n
            XML
          )
        end
      end
    end

    describe "with attributes and #text" do
      it "should output correctly" do
        run_binary(%({"name":"Jim", "city": {"@street":"forbs", "@post": 123, "#text": "Atlantic"}}), args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root>
              <name>Jim</name>
              <city street="forbs" post="123">Atlantic</city>
            </root>\n
            XML
          )
        end
      end
    end
  end
end
