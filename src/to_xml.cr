require "json"
require "yaml"
require "xml"

class Object
  def to_xml(*, root : String = "root") : String
    String.build do |str|
      to_xml str, root: root
    end
  end

  def to_xml(io : IO, *, root : String?) : Nil
    XML.build(io, indent: "  ", encoding: "utf-8") do |builder|
      builder.element root do
        to_xml builder
      end
    end
  end

  def to_xml(builder : XML::Builder) : Nil
    builder.text self.to_s
  end
end

class Array
  def to_xml(builder : XML::Builder, key : String? = nil) : Nil
    each do |v|
      builder.element key || "item" do
        v.to_xml(builder)
      end
    end
  end
end

class Hash
  def to_xml(builder : XML::Builder) : Nil
    each do |key, value|
      case key
      when .starts_with? '@' then builder.attribute key.lchop('@'), value; next
      when "#text"           then value.to_xml builder; next
      end

      if value.is_a?(Array) || ((value.is_a?(JSON::Any)) && (value = value.as_a?))
        value.to_xml builder, key
      else
        builder.element(key) do
          value.to_xml(builder)
        end
      end
    end
  end
end

struct Set
  def to_xml(builder : XML::Builder, key : String? = nil) : Nil
    each do |v|
      builder.element key || "item" do
        v.to_xml(builder)
      end
    end
  end
end

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

struct NamedTuple
  def to_xml(builder : XML::Builder) : Nil
    to_h.transform_keys(&.to_s).to_xml builder
  end
end

struct JSON::Any
  def to_xml(builder : XML::Builder) : Nil
    raw.to_xml(builder)
  end
end

struct YAML::Any
  def to_xml(builder : XML::Builder) : Nil
    raw.to_xml(builder)
  end
end
