module OQ::Converters::Mxml
  private def self.parse_args(args : NamedTuple) : Tuple(String, Bool)
    {
      args["indent"],
      args["xml_prolog"],
    }
  end

  def self.deserialize(input : IO, output : IO, **args) : Nil
    builder = JSON::Builder.new output
    xml = XML::Reader.new input

    # Set reader to first element
    xml.read

    # Raise an error if the document is invalid and could not be read
    raise XML::Error.new LibXML.xmlGetLastError if xml.node_type.none?

    builder.document do
      # Skip non element nodes, i.e. the prolog or DOCTYPE, etc.
      until xml.node_type.element?
        xml.read
      end

      process_element_node xml.expand, builder
    end
  end

  private def self.process_element_node(node : XML::Node, builder : JSON::Builder) : Nil
    # Otherwise process the node as a key/value pair
    builder.array do
      # Emit the node's name
      builder.string node.name

      # Emit an object of attributes
      process_attributes node.attributes, builder

      builder.array do
        # Processs the children
        node.children.each do |child|
          # If the child is a text node, emit a scalar value
          if child.text?
            builder.scalar node.content
          else
            # Otherwise process the child
            process_element_node child, builder
          end
        end
      end
    end
  end

  private def self.process_attributes(attributes : XML::Attributes, builder : JSON::Builder) : Nil
    builder.object do
      attributes.each do |attr|
        builder.field attr.name, attr.text
      end
    end
  end

  def self.serialize(input : IO, output : IO, **args) : Nil
    json = JSON::PullParser.new(input)
    builder = XML::Builder.new(output)
    indent, prolog = parse_args(args)

    builder.indent = indent

    builder.start_document "1.0", "UTF-8" if prolog

    build builder, json

    builder.end_document if prolog
    builder.flush unless prolog
  end

  private def self.build(builder : XML::Builder, json : JSON::PullParser) : Nil
    json.read_array do
      # Read the element's name
      element_name = json.read_string

      # Process the attributes if any
      attributes = Hash(String, String).new
      json.read_object do |key|
        attributes[key] = json.read_string
      end

      # Create an element, recursively handling children
      builder.element(element_name, attributes: attributes) do
        json.read_array do
          if value = get_value json
            builder.text value
          else
            build builder, json
          end
        end
      end
    end
  end

  private def self.get_value(json : JSON::PullParser) : String?
    case json.kind
    when .string? then json.read_string
    when .int?    then json.read_int.to_s
    when .float?  then json.read_float.to_s
    when .bool?   then json.read_bool.to_s
    when .null?   then ""
    end
  end
end
