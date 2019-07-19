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
end
