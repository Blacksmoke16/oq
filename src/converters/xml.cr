# TODO: Remove this after https://github.com/crystal-lang/crystal/issues/11037 is released.
class ::XML::Node
  def namespace_definitions : Array(Namespace)
    namespaces = [] of Namespace

    return namespaces unless (ns = @node.value.ns_def)

    while ns
      namespaces << Namespace.new(document, ns)
      ns = ns.value.next
    end

    namespaces
  end
end

# Converter for the `OQ::Format::XML` format.
module OQ::Converters::XML
  extend OQ::Converters::ProcessorAware

  def self.deserialize(input : IO, output : IO) : Nil
    builder = ::JSON::Builder.new output
    xml = ::XML::Reader.new input

    # Set reader to first element
    xml.read

    # Raise an error if the document is invalid and could not be read
    raise ::XML::Error.new LibXML.xmlGetLastError if xml.node_type.none?

    builder.document do
      builder.object do
        # Skip non element nodes, i.e. the prolog or DOCTYPE, etc.
        until xml.node_type.element?
          xml.read
        end

        process_element_node xml.expand, builder
      end
    end
  end

  private def self.process_element_node(node : ::XML::Node, builder : ::JSON::Builder) : Nil
    # If the node doesn't have nested elements nor attributes nor a namespace (with --xmlns); just emit a scalar value
    if self.is_scalar_node? node
      return builder.field self.normalize_node_name(node), get_node_value node
    end

    # Otherwise process the node as a key/value pair
    builder.field self.normalize_node_name node do
      builder.object do
        process_children node, builder
      end
    end
  end

  private def self.process_array_node(name : String, children : Array(::XML::Node), builder : ::JSON::Builder) : Nil
    builder.field name do
      builder.array do
        children.each do |node|
          # If the node doesn't have nested elements nor attributes nor a namespace (with --xmlns); just emit a scalar value
          if self.is_scalar_node? node
            builder.scalar get_node_value node
          else
            # Otherwise process the node within an object
            builder.object do
              process_children node, builder
            end
          end
        end
      end
    end
  end

  private def self.process_children(node : ::XML::Node, builder : ::JSON::Builder) : Nil
    # Process node attributes
    node.attributes.each do |attr|
      builder.field "@#{attr.name}", attr.content
    end

    # Include attributes for namespaces defined on this node
    # TODO: Make this the default behavior in oq 2.x
    if self.processor.xmlns?
      node.namespace_definitions.each do |ns|
        key = ns.prefix ? "xmlns:#{ns.prefix}" : "xmlns"
        builder.field "@#{key}", ns.href
      end
    end

    # Determine how to process a node's children
    node.children.group_by(&->normalize_node_name(::XML::Node)).each do |name, children|
      # Skip non significant whitespace; Skip mixed character input
      if children.first.text? && has_nested_elements?(node)
        # Only emit text content if there is only one child
        if children.size == 1
          builder.field "#text", children.first.content
        end

        next
      end

      # Array
      if children.size > 1
        process_array_node name, children, builder
      else
        if children.first.text?
          # node content in attribute object
          builder.field "#text", children.first.content
        else
          # Element
          process_element_node children.first, builder
        end
      end
    end
  end

  private def self.has_nested_elements?(node : ::XML::Node) : Bool
    node.children.any? { |child| !child.text? && !child.cdata? }
  end

  # TODO: Make checking for namespaces the default behavior in oq 2.x
  private def self.is_scalar_node?(node : ::XML::Node) : Bool
    !self.has_nested_elements?(node) && node.attributes.empty? && ((self.processor.xmlns? && node.namespace_definitions.empty?) || !self.processor.xmlns?)
  end

  private def self.get_node_value(node : ::XML::Node) : String?
    node.children.empty? ? nil : node.children.first.content
  end

  private def self.normalize_node_name(node : ::XML::Node) : String
    (namespace = node.namespace) && (prefix = namespace.prefix.presence) ? "#{prefix}:#{node.name}" : node.name
  end

  def self.serialize(input : IO, output : IO) : Nil
    json = ::JSON::PullParser.new input
    builder = ::XML::Builder.new output

    builder.indent = ((self.processor.tab ? "\t" : " ")*self.processor.indent)

    builder.start_document "1.0", "UTF-8" if self.processor.xml_prolog

    if root = self.processor.xml_root.presence
      builder.start_element root
    end

    loop do
      emit builder, json
      break if json.kind.eof?
    end

    if self.processor.xml_root.presence
      builder.end_element
    end

    builder.end_document if self.processor.xml_prolog
    builder.flush unless self.processor.xml_prolog
  end

  private def self.emit(builder : ::XML::Builder, json : ::JSON::PullParser, key : String? = nil, array_key : String? = nil) : Nil
    case json.kind
    when .null?                           then json.read_null
    when .string?, .int?, .float?, .bool? then builder.text get_value json
    when .begin_object?                   then handle_object builder, json, key, array_key
    when .begin_array?                    then handle_array builder, json, key, array_key
    else
      nil
    end
  end

  private def self.handle_object(builder : ::XML::Builder, json : ::JSON::PullParser, key : String? = nil, array_key : String? = nil) : Nil
    json.read_object do |k|
      if k.starts_with?('@')
        builder.attribute k.lchop('@'), get_value json
      elsif k.starts_with?('!')
        builder.element k.lchop('!') do
          builder.cdata get_value json
        end
      elsif json.kind.begin_array? || k == "#text"
        emit builder, json, k, k
      else
        builder.element k do
          emit builder, json, k
        end
      end
    end
  end

  private def self.handle_array(builder : ::XML::Builder, json : ::JSON::PullParser, key : String? = nil, array_key : String? = nil) : Nil
    json.read_begin_array
    array_key = array_key || self.processor.xml_item

    if json.kind.end_array?
      # If the array is empty don't emit anything
    else
      until json.kind.end_array?
        builder.element array_key do
          emit builder, json, key
        end
      end
    end

    json.read_end_array
  end

  private def self.get_value(json : ::JSON::PullParser) : String
    case json.kind
    when .string? then json.read_string
    when .int?    then json.read_int
    when .float?  then json.read_float
    when .bool?   then json.read_bool
    else
      ""
    end.to_s
  end
end
