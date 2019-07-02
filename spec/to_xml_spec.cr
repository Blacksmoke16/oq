require "./spec_helper"

describe "#to_xml" do
  describe String do
    it "should convert correctly" do
      assert_builder_output("foo") do |b|
        "foo".to_xml b
      end
    end
  end

  describe Nil do
    it "should convert correctly" do
      assert_builder_output("") do |b|
        nil.to_xml b
      end
    end
  end

  describe Bool do
    it "should convert correctly" do
      assert_builder_output("true") do |b|
        true.to_xml b
      end
    end
  end

  describe Number do
    describe Int do
      it "should convert correctly" do
        assert_builder_output("123") do |b|
          123.to_xml b
        end
      end
    end

    describe Float do
      it "should convert correctly" do
        assert_builder_output("3.14") do |b|
          3.14.to_xml b
        end
      end
    end
  end

  describe Array do
    describe "without a key" do
      it "should convert correctly" do
        assert_builder_output("<item>1</item><item>2</item><item>3</item>") do |b|
          [1, 2, 3].to_xml b
        end
      end
    end

    describe "with a key" do
      it "should convert correctly" do
        assert_builder_output("<key>1</key><key>2</key><key>3</key>") do |b|
          [1, 2, 3].to_xml b, "key"
        end
      end
    end
  end

  describe Set do
    describe "without a key" do
      it "should convert correctly" do
        assert_builder_output("<item>1</item><item>2</item><item>3</item>") do |b|
          Set{1, 2, 3}.to_xml b
        end
      end
    end

    describe "with a key" do
      it "should convert correctly" do
        assert_builder_output("<key>1</key><key>2</key><key>3</key>") do |b|
          Set{1, 2, 3}.to_xml b, "key"
        end
      end
    end
  end

  describe Tuple do
    describe "without a key" do
      it "should convert correctly" do
        assert_builder_output("<item>4</item><item>5</item><item>6</item>") do |b|
          {4, 5, 6}.to_xml b
        end
      end
    end

    describe "with a key" do
      it "should convert correctly" do
        assert_builder_output("<key>4</key><key>5</key><key>6</key>") do |b|
          {4, 5, 6}.to_xml b, "key"
        end
      end
    end

    describe "with a nested tuple" do
      it "should convert correctly" do
        assert_builder_output("<key>4</key><key>5</key><key><key>6</key><key>7</key><key>8</key></key>") do |b|
          {4, 5, {6, 7, 8}}.to_xml b, "key"
        end
      end
    end
  end

  describe Hash do
    describe "with standard values" do
      it "should convert correctly" do
        assert_builder_output("<name>Jim</name><age>12</age><foo></foo>") do |b|
          {"name" => "Jim", "age" => 12, "foo" => nil}.to_xml b
        end
      end
    end

    describe "with attribute object" do
      it "should convert correctly" do
        assert_builder_output("<name>Jim</name><age unit=\"years\">12</age>") do |b|
          {"name" => "Jim", "age" => {"@unit" => "years", "#text" => 12}}.to_xml b
        end
      end
    end

    describe "with multiple attribute objects" do
      it "should convert correctly" do
        assert_builder_output("<name>Jim</name><age unit=\"years\" some_key=\"-1\">12</age>") do |b|
          {"name" => "Jim", "age" => {"@unit" => "years", "@some_key" => -1, "#text" => 12}}.to_xml b
        end
      end
    end

    describe "with a nested attribute object" do
      it "should convert correctly" do
        assert_builder_output("<name>Jim</name><age><unit>years</unit>12</age>") do |b|
          {"name" => "Jim", "age" => {"unit" => "years", "#text" => 12}}.to_xml b
        end
      end
    end

    describe "with an array value" do
      it "should convert correctly" do
        assert_builder_output("<friends>Jim</friends><friends>Bob</friends><friends>Alice</friends>") do |b|
          {"friends" => ["Jim", "Bob", "Alice"]}.to_xml b
        end
      end
    end

    describe "with an JSON::Any value" do
      it "should convert correctly" do
        assert_builder_output("<friend>Jim</friend><friend>Bob</friend><friend>Alice</friend>") do |b|
          JSON.parse({"friend" => ["Jim", "Bob", "Alice"]}.to_json).to_xml b
        end
      end
    end

    describe "with an YAML::Any value" do
      it "should convert correctly" do
        assert_builder_output("<friend>Jim</friend><friend>Bob</friend><friend>Alice</friend>") do |b|
          YAML.parse({"friend" => ["Jim", "Bob", "Alice"]}.to_yaml).to_xml b
        end
      end
    end

    describe "with a nested array value" do
      it "should convert correctly" do
        assert_builder_output("<friends><friend>Jim</friend><friend>Bob</friend><friend>Alice</friend></friends>") do |b|
          {"friends" => {"friend" => ["Jim", "Bob", "Alice"]}}.to_xml b
        end
      end
    end
  end

  describe NamedTuple do
    describe "with standard values" do
      it "should convert correctly" do
        assert_builder_output("<name>Jim</name><age>12</age><foo></foo>") do |b|
          {name: "Jim", age: 12, foo: nil}.to_xml b
        end
      end
    end

    describe "with attribute object" do
      it "should convert correctly" do
        assert_builder_output("<name>Jim</name><age unit=\"years\">12</age>") do |b|
          {"name": "Jim", "age": {"@unit": "years", "#text": 12}}.to_xml b
        end
      end
    end

    describe "with multiple attribute objects" do
      it "should convert correctly" do
        assert_builder_output("<name>Jim</name><age unit=\"years\" some_key=\"-1\">12</age>") do |b|
          {"name": "Jim", "age": {"@unit": "years", "@some_key": -1, "#text": 12}}.to_xml b
        end
      end
    end
  end
end
