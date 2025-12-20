# Converter for the `OQ::Format::XML` format.
module OQ::Converters::XML
  extend OQ::Converters::ProcessorAware

  # Streaming XML to JSON deserialization using XML::PullParser.
  # This implementation processes XML incrementally without building
  # a full DOM tree, reducing memory usage for large documents.
  def self.deserialize(input : IO, output : IO) : Nil
    builder = ::JSON::Builder.new output
    pull = ::XML::PullParser.new input

    # Advance to the first element, skipping prolog, DOCTYPE, etc.
    while pull.read != ::XML::PullParser::Kind::EOF
      break if pull.kind.start_element?
    end

    # Raise an error if no element was found
    # We check errors after processing, not before, to allow recovery mode to work
    if pull.kind.eof?
      # If we hit EOF without finding an element, check for errors
      if pull.errors.any?
        raise pull.errors.first
      end
      raise ::XML::Error.new("Document is empty or contains no elements", 0)
    end

    builder.document do
      builder.object do
        process_element pull, builder
      end
    end
  end

  # Represents a child's JSON value during streaming.
  # We buffer children to detect arrays (multiple children with same name).
  private record ChildValue, json : String, is_element : Bool

  # Process an element and emit it as a JSON field.
  private def self.process_element(pull : ::XML::PullParser, builder : ::JSON::Builder) : Nil
    element_name = normalize_name(pull)

    # Collect attributes
    attrs = collect_attributes(pull)
    xmlns_attrs = self.processor.xmlns? ? collect_xmlns_attributes(pull) : {} of String => String

    is_empty = pull.empty_element?

    if is_empty
      if attrs.empty? && xmlns_attrs.empty?
        # Empty scalar element like <name/>
        builder.field element_name, nil
      else
        # Empty element with attributes
        builder.field element_name do
          builder.object do
            emit_attributes attrs, xmlns_attrs, builder
          end
        end
      end
      pull.read # consume the element
      return
    end

    # Read children
    children = collect_children(pull)

    # Check if this node has nested element children (not just text)
    has_nested_elements = children.keys.any? { |k| k != "#text" }
    text_children = children["#text"]?

    # Determine if this is a scalar node:
    # - No nested element children (only text or empty)
    # - No attributes
    # - No xmlns attrs (when xmlns mode is on)
    is_scalar = !has_nested_elements && attrs.empty? && xmlns_attrs.empty?

    if is_scalar
      # Scalar node - emit just the text value
      if text_children && !text_children.empty?
        # Concatenate all text content
        text = text_children.map(&.json).join
        builder.field element_name, text
      else
        builder.field element_name, nil
      end
    else
      # Complex node - emit as object
      builder.field element_name do
        builder.object do
          emit_attributes attrs, xmlns_attrs, builder
          emit_children children, has_nested_elements, builder
        end
      end
    end
  end

  # Collect regular attributes (non-xmlns).
  private def self.collect_attributes(pull : ::XML::PullParser) : Hash(String, String)
    attrs = {} of String => String
    pull.each_attribute do |name, value|
      next if name.starts_with?("xmlns")
      attrs[name] = value
    end
    attrs
  end

  # Collect xmlns attributes.
  private def self.collect_xmlns_attributes(pull : ::XML::PullParser) : Hash(String, String)
    attrs = {} of String => String
    pull.each_attribute do |name, value|
      if name.starts_with?("xmlns")
        # Normalize xmlns prefix if custom mapping exists
        normalized_name = normalize_xmlns_attr_name(name, value)
        attrs[normalized_name] = value
      end
    end
    attrs
  end

  # Normalize xmlns attribute name using custom namespace mappings.
  private def self.normalize_xmlns_attr_name(attr_name : String, href : String) : String
    if custom_prefix = self.processor.xml_namespaces[href]?
      if custom_prefix.empty?
        "xmlns"
      elsif attr_name == "xmlns"
        "xmlns:#{custom_prefix}"
      else
        "xmlns:#{custom_prefix}"
      end
    else
      attr_name
    end
  end

  # Collect all children of an element, grouping by name.
  # Returns a hash mapping child names to their values.
  # Text content is stored under "#text".
  private def self.collect_children(pull : ::XML::PullParser) : Hash(String, Array(ChildValue))
    children = {} of String => Array(ChildValue)
    start_depth = pull.depth

    pull.read # move past start element

    while pull.kind != ::XML::PullParser::Kind::EOF
      # Check if we've reached the end of this element
      if pull.kind.end_element? && pull.depth == start_depth
        pull.read # consume end element
        break
      end

      case pull.kind
      when .start_element?
        child_name = normalize_name(pull)
        child_json = element_to_json(pull)
        children[child_name] ||= [] of ChildValue
        children[child_name] << child_json
      when .text?, .c_data?
        content = pull.value
        children["#text"] ||= [] of ChildValue
        children["#text"] << ChildValue.new(content, false)
        pull.read
      when .whitespace?
        # Treat significant whitespace as text
        content = pull.value
        children["#text"] ||= [] of ChildValue
        children["#text"] << ChildValue.new(content, false)
        pull.read
      else
        pull.read
      end
    end

    children
  end

  # Convert an element to its JSON representation, returning as a ChildValue.
  private def self.element_to_json(pull : ::XML::PullParser) : ChildValue
    # Collect attributes before processing children
    attrs = collect_attributes(pull)
    xmlns_attrs = self.processor.xmlns? ? collect_xmlns_attributes(pull) : {} of String => String

    is_empty = pull.empty_element?

    if is_empty
      if attrs.empty? && xmlns_attrs.empty?
        pull.read # consume element
        return ChildValue.new("null", true)
      else
        json = build_json_object(attrs, xmlns_attrs)
        pull.read # consume element
        return ChildValue.new(json, true)
      end
    end

    # Read children
    children = collect_children(pull)

    has_nested_elements = children.keys.any? { |k| k != "#text" }
    text_children = children["#text"]?
    is_scalar = !has_nested_elements && attrs.empty? && xmlns_attrs.empty?

    if is_scalar
      # Scalar - return just the text content
      if text_children && !text_children.empty?
        text = text_children.map(&.json).join
        return ChildValue.new(text.to_json, true)
      else
        return ChildValue.new("null", true)
      end
    end

    # Complex node - build JSON object
    json = build_json_object(attrs, xmlns_attrs, children, has_nested_elements)
    ChildValue.new(json, true)
  end

  # Build a JSON object string with attributes only.
  private def self.build_json_object(attrs : Hash(String, String), xmlns_attrs : Hash(String, String)) : String
    String.build do |io|
      ::JSON.build(io) do |builder|
        builder.object do
          emit_attributes attrs, xmlns_attrs, builder
        end
      end
    end
  end

  # Build a JSON object string with attributes and children.
  private def self.build_json_object(attrs : Hash(String, String), xmlns_attrs : Hash(String, String), children : Hash(String, Array(ChildValue)), has_nested_elements : Bool) : String
    String.build do |io|
      ::JSON.build(io) do |builder|
        builder.object do
          emit_attributes attrs, xmlns_attrs, builder
          emit_children children, has_nested_elements, builder
        end
      end
    end
  end

  # Emit attributes as JSON fields.
  private def self.emit_attributes(attrs : Hash(String, String), xmlns_attrs : Hash(String, String), builder : ::JSON::Builder) : Nil
    attrs.each do |name, value|
      builder.field "@#{name}", value
    end
    xmlns_attrs.each do |name, value|
      builder.field "@#{name}", value
    end
  end

  # Emit children as JSON fields, handling arrays.
  private def self.emit_children(children : Hash(String, Array(ChildValue)), has_nested_elements : Bool, builder : ::JSON::Builder) : Nil
    children.each do |name, values|
      # Handle #text specially
      if name == "#text"
        if has_nested_elements
          # In mixed content, emit #text with concatenated content
          # But only if there's non-whitespace content or it's the only meaningful content
          combined = values.map(&.json).join
          unless combined.blank?
            builder.field "#text", combined
          end
        else
          # Pure text content - shouldn't reach here for scalar nodes
          builder.field "#text", values.map(&.json).join
        end
        next
      end

      # Check if this should be an array
      is_array = values.size > 1 || self.processor.xml_forced_arrays.includes?(name)

      if is_array
        builder.field name do
          builder.array do
            values.each do |child|
              builder.raw child.json
            end
          end
        end
      else
        builder.field name do
          builder.raw values.first.json
        end
      end
    end
  end

  # Normalize element name with namespace prefix.
  private def self.normalize_name(pull : ::XML::PullParser) : String
    uri = pull.namespace_uri
    return pull.local_name if uri.empty?

    # Check for custom namespace mapping
    if custom_prefix = self.processor.xml_namespaces[uri]?
      custom_prefix.empty? ? pull.local_name : "#{custom_prefix}:#{pull.local_name}"
    elsif prefix = pull.prefix.presence
      "#{prefix}:#{pull.local_name}"
    else
      pull.local_name
    end
  end

  def self.serialize(input : IO, output : IO) : Nil
    json = ::JSON::PullParser.new input
    builder = ::XML::Builder.new output

    builder.indent = ((self.processor.tab? ? "\t" : " ")*self.processor.indent)

    builder.start_document "1.0", "UTF-8" if self.processor.xml_prolog?

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

    builder.end_document if self.processor.xml_prolog?
    builder.flush unless self.processor.xml_prolog?
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
    when .null?   then json.read_null
    else
      ""
    end.to_s
  end
end
