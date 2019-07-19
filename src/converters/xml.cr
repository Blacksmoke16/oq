module OQ::Converters::Xml
  def self.serialize(input : IO, output : IO, **args) : Nil
    json = JSON::PullParser.new(input)
    builder = XML::Builder.new(output)
    indent, prlog, root = self.parse_args(args)

    builder.indent = indent

    builder.start_document "1.0", "UTF-8" if prlog
    builder.start_element root unless root.blank?

    loop do
      build builder, json
      break if json.kind == :EOF
    end

    builder.end_element unless root.blank?
    builder.end_document if prlog
    builder.flush unless prlog
  end

  def self.deserialize(input : IO, output : IO, **args)
    raise "Not Implemented"
  end

  private def self.parse_args(args : NamedTuple) : Nil
    {
      args["indent"],
      args["xml_prolog"],
      args["xml_root"],
    }
  end

  private def self.build(builder, json : JSON::PullParser, key : String? = nil) : String
    case json.kind
    when :null   then return json.read_null.to_s
    when :int    then return json.read_int.to_s
    when :float  then return json.read_float.to_s
    when :string then return json.read_string
    when :bool   then return json.read_bool.to_s
    when :begin_object
      json.read_object do |sub_key|
        builder.start_element sub_key if !sub_key.starts_with?('@') && sub_key != "#text" && json.kind != :begin_array
        if sub_key.starts_with?('@')
          builder.attribute sub_key.lchop('@'), build(builder, json, sub_key)
        else
          builder.text build(builder, json, sub_key)
        end
        builder.end_element if !sub_key.starts_with?('@') && sub_key != "#text" && json.kind != :begin_array
      end
    when :begin_array
      json.read_array do
        # case json.kind
        # when :begin_object then build builder, json
        # else
        builder.element(key || "item") do
          builder.text build builder, json, key
        end
        # end
      end
    end

    ""
  end
end
