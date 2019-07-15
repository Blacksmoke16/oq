require "json"
require "yaml"
require "xml"

# :nodoc:
class Object
  def to_xml(*, root : String = "root", indent : String = "  ") : String
    String.build do |str|
      to_xml str, root: root, indent: indent
    end
  end

  def to_xml(io : IO, *, root : String?, indent : String) : Nil
    XML.build(io, indent: indent, encoding: "utf-8") do |builder|
      builder.element root do
        to_xml builder
      end
    end
  end

  def to_xml(builder : XML::Builder) : Nil
    builder.text self.to_s
  end
end

# :nodoc:
struct Nil
  def to_xml(builder : XML::Builder) : Nil
  end
end

# :nodoc:
class Array
  def to_xml(builder : XML::Builder, key : String? = nil) : Nil
    each do |v|
      builder.element key || "item" do
        v.to_xml(builder)
      end
    end
  end
end

# :nodoc:
class Hash
  def to_xml(builder : XML::Builder) : Nil
    each do |key, value|
      key = ((key.is_a?(JSON::Any) || key.is_a?(YAML::Any)) ? key.as_s : key)

      case key
      when .starts_with? '@' then builder.attribute key.lchop('@'), value; next
      when "#text"           then value.to_xml builder; next
      end

      if value.is_a?(Array)
        value.to_xml builder, key
      elsif (value.is_a?(JSON::Any) || value.is_a?(YAML::Any)) && (v = value.as_a?)
        v.to_xml builder, key
      else
        builder.element(key) do
          value.to_xml(builder)
        end
      end
    end
  end
end

# :nodoc:
struct Set
  def to_xml(builder : XML::Builder, key : String? = nil) : Nil
    each do |v|
      builder.element key || "item" do
        v.to_xml(builder)
      end
    end
  end
end

# :nodoc:
struct Tuple
  def to_xml(builder : XML::Builder, key : String? = nil) : Nil
    {% for i in 0...T.size %}
      builder.element key || "item" do
        value = self[{{i}}]
        case value
        when Tuple, Array then value.to_xml builder, key
        else
          value.to_xml builder
        end
      end
    {% end %}
  end
end

# :nodoc:
struct NamedTuple
  def to_xml(builder : XML::Builder) : Nil
    to_h.transform_keys(&.to_s).to_xml builder
  end
end

# :nodoc:
struct JSON::Any
  def to_xml(builder : XML::Builder) : Nil
    raw.to_xml(builder)
  end
end

# :nodoc:
struct YAML::Any
  def to_xml(builder : XML::Builder) : Nil
    raw.to_xml(builder)
  end
end
