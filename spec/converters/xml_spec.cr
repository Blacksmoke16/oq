require "../spec_helper"

WITH_WHITESPACE = <<-XML
<item>
  <flagID>0</flagID>
  <itemID>0</itemID>
  <locationID>0</locationID>
  <ownerID>0</ownerID>
  <quantity>-1</quantity>
  <typeID>0</typeID>
</item>
XML

XML_SCALAR_ARRAY = <<-XML
<?xml version="1.0" encoding="utf-8"?>
<items>
  <number>1</number>
  <number>2</number>
  <number>3</number>
</items>
XML

XML_SCALAR_ARRAY_WITH_ATTRIBUTE = <<-XML
<?xml version="1.0" encoding="utf-8"?>
<items>
  <number>1</number>
  <number>2</number>
  <number foo="bar">3</number>
</items>
XML

XML_CDATA = <<-XML
<desc><![CDATA[<message>Some Description</message>]]></desc>
XML

XML_OBJECT_ARRAY = <<-XML
<?xml version="1.0" encoding="utf-8"?>
<items>
  <item>
    <flagID>0</flagID>
    <itemID>0</itemID>
    <locationID>0</locationID>
    <ownerID>0</ownerID>
    <quantity>-1</quantity>
    <typeID>0</typeID>
  </item>
  <item>
    <flagID>0</flagID>
    <itemID>1</itemID>
    <locationID>0</locationID>
    <ownerID>0</ownerID>
    <quantity>-1</quantity>
    <typeID>0</typeID>
  </item>
</items>
XML

XML_NESTED_OBJECT_ARRAY = <<-XML
<?xml version='1.0' ?>
<!DOCTYPE root SYSTEM "http://www.cs.washington.edu/research/projects/xmltk/xmldata/data/auctions/ebay.dtd">
<root>
 <listing>
   <seller_info>
       <seller_name> cubsfantony</seller_name>
       <seller_rating> 848</seller_rating>
   </seller_info>
   <payment_types>Visa/MasterCard, Money Order/Cashiers Checks, Personal Checks, See item description for payment methods accepted</payment_types>
</listing>
<listing>
   <seller_info>
       <seller_name> ct-inc</seller_name>
       <seller_rating> 403</seller_rating>
   </seller_info>
   <payment_types>Visa/MasterCard, Discover, Money Order/Cashiers Checks, Personal Checks, See item description for payment methods accepted</payment_types>
</listing>
</root>
XML

XML_INLINE_ARRAY = <<-XML
<article key="tr/ibm/RJ2144">
  <author>E. F. Codd</author>
  <author>Robert S. Arnold</author>
  <author>Jean-Marc Cadiou</author>
  <author>Chin-Liang Chang</author>
  <author>Nick Roussopoulos</author>
  <title>RENDEZVOUS Version 1: An Experimental English Language Query Formulation System for Casual Users of Relational Data Bases.</title>
  <journal>IBM Research Report</journal>
  <volume>RJ2144</volume>
  <month>January</month>
  <year>1978</year>
  <ee>db/labs/ibm/RJ2144.html</ee>
  <cdrom>ibmTR/rj2144.pdf</cdrom>
</article>
XML

XML_INLINE_ARRAY_WITHIN_ARRAY = <<-XML
<articles>
  <article key="tr/dec/SRC1997-018">
    <year>1997</year>
    <ee>db/labs/dec/SRC1997-018.html</ee>
    <ee>http://www.mcjones.org/System_R/SQL_Reunion_95/</ee>
  </article>
  <article key="tr/gte/TR-0263-08-94-165">
    <ee>db/labs/gte/TR-0263-08-94-165.html</ee>
    <year>1994</year>
  </article>
</articles>
XML

XML_DOCTYPE = <<-XML
<?xml version="1.0" encoding="ISO-8859-1"?>
<!DOCTYPE dblp SYSTEM "dblp.dtd">
<dblp>
  <mastersthesis key="ms/Brown92">
    <author>Kurt P. Brown</author>
    <title>PRPL: A Database Workload Specification Language, v1.3.</title>
    <year>1992</year>
    <school>Univ. of Wisconsin-Madison</school>
  </mastersthesis>
</dblp>
XML

XML_ATTRIBUTE_IN_ARRAY = <<-XML
<jobs>
  <ad>
    <salary currency="CAD">80000</salary>
    <working_hours>full-time</working_hours>
  </ad>
  <ad>
    <working_hours>full-time</working_hours>
  </ad>
</jobs>
XML

XML_ATTRIBUTE_IN_ARRAY_ROOT_ELEMENT = <<-XML
<?xml version="1.0" encoding="ISO-8859-1"?>
<!DOCTYPE dblp SYSTEM "dblp.dtd">
<dblp>
  <mastersthesis key="ms/Brown92">
    <author>Kurt P. Brown</author>
  </mastersthesis>
  <mastersthesis key="ms/Yurek97">
    <author>Tolga Yurek</author>
  </mastersthesis>
</dblp>
XML

XML_ALL_EMPTY = <<-XML
<root>
  <one> </one>
  <two>
  </two>
  <three/>
  <four></four>
</root>
XML

XML_NAMESPACE_ARRAY = <<-XML
<?xml version="1.0" encoding="utf-8"?>
<items xmlns:n="http://n">
  <n:number>1</n:number>
  <n:number>2</n:number>
  <number xmlns="http://default">3</number>
</items>
XML

XML_NAMESPACE_ARRAY_SCALAR_VALUE_PREFIX = <<-XML
<?xml version="1.0" encoding="utf-8"?>
<items xmlns:n="http://n">
  <n:number>1</n:number>
  <n:number>2</n:number>
  <n:number xmlns="http://default">3</n:number>
</items>
XML

XML_NAMESPACE_PREFIXES = <<-XML
<?xml version="1.0" ?>
<root xmlns:a="https://a">
  <foo>foo</foo>
  <a:bar>bar</a:bar>
</root>
XML

XML_NESTED_NAMESPACES = <<-XML
<?xml version="1.0" ?>
<root xmlns:a="https://a" xmlns="https://b">
  <a:foo>herp</a:foo>
  <foo>
    <bar xmlns="https://c">
      <baz xmlns="https://d"/>
    </bar>
  </foo>
</root>
XML

describe OQ::Converters::XML do
  describe ".deserialize" do
    # See https://www.xml.com/pub/a/2006/05/31/converting-between-xml-and-json.html
    describe "conventions" do
      describe "an empty element" do
        it "self closing" do
          run_binary("<e/>", args: ["-i", "xml", "-c", "."]) do |output|
            output.should eq %({"e":null}\n)
          end
        end

        it "non self closing" do
          run_binary("<e></e>", args: ["-i", "xml", "-c", "."]) do |output|
            output.should eq %({"e":null}\n)
          end
        end
      end

      it "an element with pure text content" do
        run_binary("<e>text</e>", args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"e":"text"}\n)
        end
      end

      it "an empty element with attributes" do
        run_binary(%(<e name="value" />), args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"e":{"@name":"value"}}\n)
        end
      end

      it "an element with pure text content and attributes" do
        run_binary(%(<e name="value">text</e>), args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"e":{"@name":"value","#text":"text"}}\n)
        end
      end

      it "an element containing elements with different names" do
        run_binary(%(<e> <a>text</a> <b>text</b> </e>), args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"e":{"a":"text","b":"text"}}\n)
        end
      end

      it "an element containing elements with identical names" do
        run_binary(%(<e> <a>text</a> <a>text</a> </e>), args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"e":{"a":["text","text"]}}\n)
        end
      end

      it "an element containing elements and contiguous text" do
        run_binary(%(<e>text<a>text</a></e>), args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"e":{"#text":"text","a":"text"}}\n)
        end
      end
    end

    describe "should raise if invalid" do
      it "should output correctly" do
        run_binary(%(<root id="1<child/></root>), args: ["-i", "xml", "-c", "."], success: false) do |_, _, error|
          error.should eq "oq error: Couldn't find end of Start Tag root\n"
        end
      end
    end

    describe Object do
      it "a key/value pair" do
        run_binary(%(<person>Fred</person>), args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"person":"Fred"}\n)
        end
      end

      describe "that has only empty children elements" do
        it "should output an object with null values" do
          run_binary(XML_ALL_EMPTY, args: ["-i", "xml", "-c", "."]) do |output|
            output.should eq %({"root":{"one":" ","two":"\\n  ","three":null,"four":null}}\n)
          end
        end
      end

      it "with whitespace" do
        run_binary(WITH_WHITESPACE, args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"item":{"flagID":"0","itemID":"0","locationID":"0","ownerID":"0","quantity":"-1","typeID":"0"}}\n)
        end
      end

      it "with the prolog" do
        run_binary(%(<?xml version="1.0" encoding="utf-8"?><item><typeID>0</typeID></item>), args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"item":{"typeID":"0"}}\n)
        end
      end

      it "a simple object" do
        run_binary(%(<person><firstname>Jane</firstname><lastname>Doe</lastname></person>), args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"person":{"firstname":"Jane","lastname":"Doe"}}\n)
        end
      end

      it "attributes" do
        run_binary(%(<person id="1" foo="bar"><firstname>Jane</firstname><lastname>Doe</lastname></person>), args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"person":{"@id":"1","@foo":"bar","firstname":"Jane","lastname":"Doe"}}\n)
        end
      end

      it "nested objects" do
        run_binary(%(<person><firstname>Jane</firstname><lastname>Doe</lastname><location><zip>15061</zip><address>123 Foo Street</address></location></person>), args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"person":{"firstname":"Jane","lastname":"Doe","location":{"zip":"15061","address":"123 Foo Street"}}}\n)
        end
      end

      it "complex object" do
        run_binary(%(<root><x a="1"><a>2</a></x><y b="3">4</y></root>), args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"root":{"x":{"@a":"1","a":"2"},"y":{"@b":"3","#text":"4"}}}\n)
        end
      end

      it "with mixed content" do
        run_binary(%(<root>x<y>z</y></root>), args: ["-i", "xml", "-c", ".root"]) do |output|
          output.should eq %({"#text":"x","y":"z"}\n)
        end
      end

      it "with an inline array" do
        run_binary(XML_INLINE_ARRAY, args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"article":{"@key":"tr/ibm/RJ2144","author":["E. F. Codd","Robert S. Arnold","Jean-Marc Cadiou","Chin-Liang Chang","Nick Roussopoulos"],"title":"RENDEZVOUS Version 1: An Experimental English Language Query Formulation System for Casual Users of Relational Data Bases.","journal":"IBM Research Report","volume":"RJ2144","month":"January","year":"1978","ee":"db/labs/ibm/RJ2144.html","cdrom":"ibmTR/rj2144.pdf"}}\n)
        end
      end

      it "with a doctype" do
        run_binary(XML_DOCTYPE, args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"dblp":{"mastersthesis":{"@key":"ms/Brown92","author":"Kurt P. Brown","title":"PRPL: A Database Workload Specification Language, v1.3.","year":"1992","school":"Univ. of Wisconsin-Madison"}}}\n)
        end
      end

      it "with CDATA" do
        run_binary(XML_CDATA, args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"desc":"<message>Some Description</message>"}\n)
        end
      end

      it "with a prefixed key" do
        run_binary(%(<?xml version="1.0"?><a:foo>bar</a:foo>), args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"a:foo":"bar"}\n)
        end
      end

      describe "with namespaces" do
        describe "without --xmlns" do
          it "retains prefixes but strips namespace declarations of a prefixed namespace" do
            run_binary(%(<?xml version="1.0"?><a:foo xmlns:a="http://www.w3.org/1999/xhtml">bar</a:foo>), args: ["-i", "xml", "-c", "."]) do |output|
              output.should eq %({"a:foo":"bar"}\n)
            end
          end

          it "does not add pefix if none was already present but strips namespace declarations" do
            run_binary(%(<?xml version="1.0"?><foo xmlns="urn:oasis:names:tc:SAML:2.0:metadata" xmlns:a="http://www.w3.org/1999/xhtml">bar</foo>), args: ["-i", "xml", "-c", "."]) do |output|
              output.should eq %({"foo":"bar"}\n)
            end
          end

          it "adds namespace attribute properties only to declaring element and handles differentiating prefixed elements" do
            run_binary(XML_NESTED_NAMESPACES, args: ["-i", "xml", "-c", "."]) do |output|
              output.should eq %({"root":{"a:foo":"herp","foo":{"bar":{"baz":null}}}}\n)
            end
          end

          it "retains prefixes of scalar value elements" do
            run_binary(XML_NAMESPACE_PREFIXES, args: ["-i", "xml", "-c", "."]) do |output|
              output.should eq %({"root":{"foo":"foo","a:bar":"bar"}}\n)
            end
          end

          describe "with --namespace-alias" do
            it "should error" do
              run_binary(%(<?xml version="1.0"?><a:foo xmlns:a="https://a-namespace">bar</a:foo>), args: ["-i", "xml", "-c", "--namespace-alias", "aa=https://a-namespace", "."], success: false) do |_, _, error|
                error.should start_with "oq error:"
              end
            end
          end
        end

        describe "with --xmlns" do
          it "creates a namespace attribute property" do
            run_binary(%(<?xml version="1.0"?><a:foo xmlns:a="http://www.w3.org/1999/xhtml">bar</a:foo>), args: ["-i", "xml", "-c", "--xmlns", "."]) do |output|
              output.should eq %({"a:foo":{"@xmlns:a":"http://www.w3.org/1999/xhtml","#text":"bar"}}\n)
            end
          end

          it "does not add pefix if none was already present and creates multiple namespace attribute properties" do
            run_binary(%(<?xml version="1.0"?><foo xmlns="urn:oasis:names:tc:SAML:2.0:metadata" xmlns:a="http://www.w3.org/1999/xhtml">bar</foo>), args: ["-i", "xml", "-c", "--xmlns", "."]) do |output|
              output.should eq %({"foo":{"@xmlns":"urn:oasis:names:tc:SAML:2.0:metadata","@xmlns:a":"http://www.w3.org/1999/xhtml","#text":"bar"}}\n)
            end
          end

          it "treats prefixed & unprefixed elements as unique elements" do
            run_binary(XML_NESTED_NAMESPACES, args: ["-i", "xml", "-c", "--xmlns", "."]) do |output|
              output.should eq %({"root":{"@xmlns:a":"https://a","@xmlns":"https://b","a:foo":"herp","foo":{"bar":{"@xmlns":"https://c","baz":{"@xmlns":"https://d"}}}}}\n)
            end
          end

          it "retains prefixes of scalar value elements and adds a namespace attribute property" do
            run_binary(XML_NAMESPACE_PREFIXES, args: ["-i", "xml", "-c", "--xmlns", "."]) do |output|
              output.should eq %({"root":{"@xmlns:a":"https://a","foo":"foo","a:bar":"bar"}}\n)
            end
          end

          describe "with --namespace-alias" do
            it "normalizes the provided namespace" do
              run_binary(%(<?xml version="1.0"?><a:foo xmlns:a="https://a-namespace">bar</a:foo>), args: ["-i", "xml", "-c", "--xmlns", "--namespace-alias", "aa=https://a-namespace", "."]) do |output|
                output.should eq %({"aa:foo":{"@xmlns:aa":"https://a-namespace","#text":"bar"}}\n)
              end
            end

            it "normalizes the default namespace" do
              run_binary(%(<?xml version="1.0"?><foo xmlns="https://a-namespace">bar</foo>), args: ["-i", "xml", "-c", "--xmlns", "--namespace-alias", "aa=https://a-namespace", "."]) do |output|
                output.should eq %({"aa:foo":{"@xmlns:aa":"https://a-namespace","#text":"bar"}}\n)
              end
            end

            it "normalizes multiple namespaces" do
              run_binary(XML_NESTED_NAMESPACES, args: ["-i", "xml", "-c", "--xmlns", "--namespace-alias", "=https://a", "--namespace-alias", "bb=https://b", "."]) do |output|
                output.should eq %({"bb:root":{"@xmlns":"https://a","@xmlns:bb":"https://b","foo":"herp","bb:foo":{"bar":{"@xmlns":"https://c","baz":{"@xmlns":"https://d"}}}}}\n)
              end
            end
          end
        end
      end
    end

    describe Array do
      it "of scalar values" do
        run_binary(XML_SCALAR_ARRAY, args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"items":{"number":["1","2","3"]}}\n)
        end
      end

      it "of scalar values with attribute" do
        run_binary(XML_SCALAR_ARRAY_WITH_ATTRIBUTE, args: ["-i", "xml", "-c", "."]) do |output|
          output.should eq %({"items":{"number":["1","2",{"@foo":"bar","#text":"3"}]}}\n)
        end
      end

      describe "of objects" do
        describe "with no nested objects" do
          it "should output correctly" do
            run_binary(XML_OBJECT_ARRAY, args: ["-i", "xml", "-c", "."]) do |output|
              output.should eq %({"items":{"item":[{"flagID":"0","itemID":"0","locationID":"0","ownerID":"0","quantity":"-1","typeID":"0"},{"flagID":"0","itemID":"1","locationID":"0","ownerID":"0","quantity":"-1","typeID":"0"}]}}\n)
            end
          end
        end

        describe "with an inline array" do
          it "should output correctly" do
            run_binary(XML_INLINE_ARRAY_WITHIN_ARRAY, args: ["-i", "xml", "-c", "."]) do |output|
              output.should eq %({"articles":{"article":[{"@key":"tr/dec/SRC1997-018","year":"1997","ee":["db/labs/dec/SRC1997-018.html","http://www.mcjones.org/System_R/SQL_Reunion_95/"]},{"@key":"tr/gte/TR-0263-08-94-165","ee":"db/labs/gte/TR-0263-08-94-165.html","year":"1994"}]}}\n)
            end
          end
        end

        describe "with nested objects" do
          it "should output correctly" do
            run_binary(XML_NESTED_OBJECT_ARRAY, args: ["-i", "xml", "-c", ".root.listing"]) do |output|
              output.should eq %([{"seller_info":{"seller_name":" cubsfantony","seller_rating":" 848"},"payment_types":"Visa/MasterCard, Money Order/Cashiers Checks, Personal Checks, See item description for payment methods accepted"},{"seller_info":{"seller_name":" ct-inc","seller_rating":" 403"},"payment_types":"Visa/MasterCard, Discover, Money Order/Cashiers Checks, Personal Checks, See item description for payment methods accepted"}]\n)
            end
          end
        end
      end

      describe "with object that has an attribute" do
        it "should output correctly" do
          run_binary(XML_ATTRIBUTE_IN_ARRAY, args: ["-i", "xml", "-c", "."]) do |output|
            output.should eq %({"jobs":{"ad":[{"salary":{"@currency":"CAD","#text":"80000"},"working_hours":"full-time"},{"working_hours":"full-time"}]}}\n)
          end
        end
      end

      describe "where array object element has an attribute" do
        it "should output correctly" do
          run_binary(XML_ATTRIBUTE_IN_ARRAY_ROOT_ELEMENT, args: ["-i", "xml", "-c", "."]) do |output|
            output.should eq %({"dblp":{"mastersthesis":[{"@key":"ms/Brown92","author":"Kurt P. Brown"},{"@key":"ms/Yurek97","author":"Tolga Yurek"}]}}\n)
          end
        end
      end

      describe "with namespaces" do
        describe "without --xmlns" do
          it "treats prefixed & unprefixed elements as unique elements" do
            run_binary(XML_NAMESPACE_ARRAY, args: ["-i", "xml", "-c", "."]) do |output|
              output.should eq %({"items":{"n:number":["1","2"],"number":"3"}}\n)
            end
          end

          it "ignores the namespace declaration" do
            run_binary(XML_NAMESPACE_ARRAY_SCALAR_VALUE_PREFIX, args: ["-i", "xml", "-c", "."]) do |output|
              output.should eq %({"items":{"n:number":["1","2","3"]}}\n)
            end
          end
        end

        describe "with --xmlns" do
          it "treats prefixed & unprefixed elements as unique elements, adding namespace attribute property as needed" do
            run_binary(XML_NAMESPACE_ARRAY, args: ["-i", "xml", "-c", "--xmlns", "."]) do |output|
              output.should eq %({"items":{"@xmlns:n":"http://n","n:number":["1","2"],"number":{"@xmlns":"http://default","#text":"3"}}}\n)
            end
          end

          it "expands the scalar value to include a namespace attribute property" do
            run_binary(XML_NAMESPACE_ARRAY_SCALAR_VALUE_PREFIX, args: ["-i", "xml", "-c", "--xmlns", "."]) do |output|
              output.should eq %({"items":{"@xmlns:n":"http://n","n:number":["1","2",{"@xmlns":"http://default","#text":"3"}]}}\n)
            end
          end

          describe "with --namespace-alias" do
            it do
              run_binary(XML_NAMESPACE_ARRAY, args: ["-i", "xml", "-c", "--xmlns", "--namespace-alias", "num=http://n", "."]) do |output|
                output.should eq %({"items":{"@xmlns:num":"http://n","num:number":["1","2"],"number":{"@xmlns":"http://default","#text":"3"}}}\n)
              end
            end

            it do
              run_binary(XML_NAMESPACE_ARRAY, args: ["-i", "xml", "-c", "--xmlns", "--namespace-alias", "=http://n", "--namespace-alias", "d=http://default", "."]) do |output|
                output.should eq %({"items":{"@xmlns":"http://n","number":["1","2"],"d:number":{"@xmlns:d":"http://default","#text":"3"}}}\n)
              end
            end
          end
        end
      end
    end
  end

  describe ".serialize" do
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
                  <a/>
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

      describe "with HTML content" do
        it "should escape the HTMl content" do
          run_binary(%({"x":"<p>Hello World!</p>"}), args: ["-o", "xml", "."]) do |output|
            output.should eq(<<-XML
              <?xml version="1.0" encoding="UTF-8"?>
              <root>
                <x>&lt;p&gt;Hello World!&lt;/p&gt;</x>
              </root>\n
              XML
            )
          end
        end

        it "should be wrapped in CDATA if the json key starts with '!'" do
          run_binary(%({"!x":"<p>Hello World!</p>"}), args: ["-o", "xml", "."]) do |output|
            output.should eq(<<-XML
              <?xml version="1.0" encoding="UTF-8"?>
              <root>
                <x><![CDATA[<p>Hello World!</p>]]></x>
              </root>\n
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
                <a/>
              </root>\n
              XML
            )
          end
        end
      end

      it "object value mixed/nested array values" do
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

      it "object value array primitive values" do
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

    describe Object do
      it "simple key/value" do
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

      it "nested object" do
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

      it "with an attribute" do
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

      it "with an attribute and #text" do
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

      it "with attributes" do
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

      it "with attributes and #text" do
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

      it "with a prefixed key" do
        run_binary(%({"foo:name":"Jim"}), args: ["-o", "xml", "."]) do |output|
          output.should eq(<<-XML
            <?xml version="1.0" encoding="UTF-8"?>
            <root>
              <foo:name>Jim</foo:name>
            </root>\n
            XML
          )
        end
      end
    end
  end
end
