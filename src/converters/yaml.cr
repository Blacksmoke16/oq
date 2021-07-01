# Converter for the `OQ::Format::YAML` format.
module OQ::Converters::YAML
  extend self

  def deserialize(input : IO, output : IO, **args) : Nil
    ::YAML.parse(input).to_json output
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def serialize(input : IO, output : IO, **args) : Nil
    json = ::JSON::PullParser.new input
    yaml = ::YAML::Builder.new output

    # Return early is there is no JSON to be read.
    return if json.kind.eof?

    yaml.stream do
      yaml.document do
        loop do
          case json.kind
          when .null?
            yaml.scalar nil
          when .bool?
            yaml.scalar json.bool_value
          when .int?
            yaml.scalar json.int_value
          when .float?
            yaml.scalar json.float_value
          when .string?
            if ::YAML::Schema::Core.reserved_string? json.string_value
              yaml.scalar json.string_value, style: :double_quoted
            else
              yaml.scalar json.string_value
            end
          when .begin_array?
            yaml.start_sequence
          when .end_array?
            yaml.end_sequence
          when .begin_object?
            yaml.start_mapping
          when .end_object?
            yaml.end_mapping
          when .eof?
            break
          end
          json.read_next
        end
      end
    end
  end
end
