module OQ::Converters::Xml
  @@at_root : Bool = true

  def self.serialize(input : IO, output : IO, **args) : Nil
    json = JSON::PullParser.new(input)
    builder = XML::Builder.new(output)
    indent, prolog, root, xml_item = self.parse_args(args)

    builder.indent = indent

    builder.start_document "1.0", "UTF-8" if prolog
    builder.start_element root unless root.blank?

    loop do
      emit builder, json, xml_item: xml_item
      break if json.kind == :EOF
    end

    builder.end_element unless root.blank?
    builder.end_document if prolog
    builder.flush unless prolog
  end

  def self.deserialize(input : IO, output : IO, **args)
    raise "Not Implemented"
  end

  private def self.parse_args(args : NamedTuple) : Tuple(String, Bool, String, String)
    {
      args["indent"],
      args["xml_prolog"],
      args["xml_root"],
      args["xml_item"],
    }
  end

  private def self.emit(builder : XML::Builder, json : JSON::PullParser, key : String? = nil, array_key : String? = nil, *, xml_item : String) : Nil
    case json.kind
    when :null                        then json.read_null
    when :string, :int, :float, :bool then builder.text get_value json
    when :begin_object                then handle_object builder, json, key, array_key, xml_item: xml_item
    when :begin_array                 then handle_array builder, json, key, array_key, xml_item: xml_item
    end
  end

  private def self.handle_object(builder : XML::Builder, json : JSON::PullParser, key : String? = nil, array_key : String? = nil, *, xml_item : String) : Nil
    @@at_root = false
    json.read_object do |k|
      if k.starts_with?('@')
        builder.attribute k.lchop('@'), get_value json
      elsif json.kind == :begin_array || k == "#text"
        emit builder, json, k, k, xml_item: xml_item
      else
        builder.element k do
          emit builder, json, k, xml_item: xml_item
        end
      end
    end
  end

  private def self.handle_array(builder : XML::Builder, json : JSON::PullParser, key : String? = nil, array_key : String? = nil, *, xml_item : String) : Nil
    json.read_begin_array
    array_key = array_key || xml_item

    if json.kind == :end_array
      builder.element(array_key) { } unless @@at_root
    else
      while json.kind != :end_array
        builder.element array_key do
          emit builder, json, key, xml_item: xml_item
        end
      end
    end

    json.read_end_array
  end

  private def self.get_value(json : JSON::PullParser) : String
    case json.kind
    when :string then json.read_string
    when :int    then json.read_int.to_s
    when :float  then json.read_float.to_s
    when :bool   then json.read_bool.to_s
    else
      ""
    end
  end
end
