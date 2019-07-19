module OQ::Converters::Xml
  @@at_root : Bool = true

  def self.serialize(input : IO, output : IO, **args) : Nil
    json = JSON::PullParser.new(input)
    builder = XML::Builder.new(output)
    indent, prolog, root = self.parse_args(args)

    builder.indent = indent

    builder.start_document "1.0", "UTF-8" if prolog
    builder.start_element root unless root.blank?

    loop do
      emit builder, json
      break if json.kind == :EOF
    end

    builder.end_element unless root.blank?
    builder.end_document if prolog
    builder.flush unless prolog
  end

  def self.deserialize(input : IO, output : IO, **args)
    raise "Not Implemented"
  end

  private def self.parse_args(args : NamedTuple) : Tuple(String, Bool, String)
    {
      args["indent"],
      args["xml_prolog"],
      args["xml_root"],
    }
  end

  private def self.emit(builder : XML::Builder, json : JSON::PullParser, key : String? = nil, array_key : String? = nil) : String
    case json.kind
    when :null   then json.read_null
    when :string then builder.text json.read_string
    when :int    then builder.text json.read_int.to_s
    when :float  then builder.text json.read_float.to_s
    when :bool   then builder.text json.read_bool.to_s
    when :begin_object
      @@at_root = false
      json.read_object do |key|
        if key.starts_with?('@')
          builder.attribute key.lchop('@'), json.read_string
        elsif json.kind == :begin_array || key == "#text"
          emit builder, json, key, key
        else
          builder.element key do
            emit builder, json, key
          end
        end
      end
    when :begin_array
      json.read_begin_array
      array_key = array_key || "item"

      if json.kind == :end_array
        builder.element(array_key) { } unless @@at_root
      else
        while json.kind != :end_array
          builder.element array_key do
            emit builder, json, key
          end
        end
      end

      json.read_end_array
    end
    ""
  end
end
