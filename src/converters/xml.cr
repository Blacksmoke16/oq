struct XML::Node
  property is_array = false
end

module OQ::Converters::Xml
  @@at_root : Bool = true

  def self.deserialize(input : IO, output : IO, **args) : Nil
    builder = JSON::Builder.new(output)
    xml = XML::Reader.new(input)

    # Set reader to first element
    xml.read

    builder.document do
      builder.object do
        process_node xml.expand, builder
      end
    end
  end

  private def self.process_node(node : XML::Node?, builder : JSON::Builder) : Nil
    return unless node

    has_nested_elements = node.children.any? do |child|
      next if child.content.blank?
      !child.type.text_node?
    end

    # If the children all have the same name assume its an array
    if node.children.map { |c| next if c.content.blank?; c.name }.compact.uniq.size == 1 && node.children.size > 1
      builder.field node.name do
        builder.array do
          node.children.reject(&.content.blank?).each do |n|
            n.is_array = true
            process_node n, builder
          end
        end
      end
    elsif (has_nested_elements || !node.attributes.empty?)
      # Define an object field if this element does not
      # consist solely of text nodes or has attributes
      unless node.is_array
        builder.field node.name do
          builder.object do
            process_attributes node.attributes, builder
            process_elements node.children, builder, exclude_text_nodes: has_nested_elements
          end
        end
      else
        builder.object do
          process_attributes node.attributes, builder
          # Filter out mixed content nodes
          process_elements node.children, builder
        end
      end
    else
      # If the node is not part of an array output a field for an object
      unless node.is_array
        builder.field node.name, node.children.first.content
      else
        # Otherwise output a scalar for an array item
        builder.scalar node.children.first.content
      end
    end
  end

  private def self.process_elements(elements : XML::NodeSet, builder : JSON::Builder, *, exclude_text_nodes : Bool = false)
    elements.each do |el|
      next if exclude_text_nodes && el.type.text_node?
      next if el.content.blank?

      # If the element is just a text node wrapper define a JSON field
      if !el.attributes.empty?
        process_node el, builder
      elsif el.children.size == 1 && el.children.first.type.text_node?
        builder.field el.name, el.children.first.content
      elsif el.type.text_node?
        builder.field "#text", el.content
      else
        # Otherwise its a nested object
        process_node el, builder
      end
    end
  end

  private def self.process_attributes(attributes : XML::Attributes, builder : JSON::Builder)
    # Process node attributes
    attributes.each do |attr|
      builder.field "@#{attr.name}", attr.content
    end
  end

  def self.serialize(input : IO, output : IO, **args) : Nil
    json = JSON::PullParser.new(input)
    builder = XML::Builder.new(output)
    indent, prolog, root, xml_item = self.parse_args(args)

    builder.indent = indent

    builder.start_document "1.0", "UTF-8" if prolog
    builder.start_element root unless root.blank?

    loop do
      emit builder, json, xml_item: xml_item
      break if json.kind.eof?
    end

    builder.end_element unless root.blank?
    builder.end_document if prolog
    builder.flush unless prolog
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
    when .null?                           then json.read_null
    when .string?, .int?, .float?, .bool? then builder.text get_value json
    when .begin_object?                   then handle_object builder, json, key, array_key, xml_item: xml_item
    when .begin_array?                    then handle_array builder, json, key, array_key, xml_item: xml_item
    end
  end

  private def self.handle_object(builder : XML::Builder, json : JSON::PullParser, key : String? = nil, array_key : String? = nil, *, xml_item : String) : Nil
    @@at_root = false
    json.read_object do |k|
      if k.starts_with?('@')
        builder.attribute k.lchop('@'), get_value json
      elsif json.kind.begin_array? || k == "#text"
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

    if json.kind.end_array?
      builder.element(array_key) { } unless @@at_root
    else
      until json.kind.end_array?
        builder.element array_key do
          emit builder, json, key, xml_item: xml_item
        end
      end
    end

    json.read_end_array
  end

  private def self.get_value(json : JSON::PullParser) : String
    case json.kind
    when .string? then json.read_string
    when .int?    then json.read_int.to_s
    when .float?  then json.read_float.to_s
    when .bool?   then json.read_bool.to_s
    else
      ""
    end
  end
end
