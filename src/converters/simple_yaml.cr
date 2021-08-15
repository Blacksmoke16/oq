require "./yaml"

# Converter for the `OQ::Format::SimpleYAML` format.
module OQ::Converters::SimpleYAML
  extend OQ::Converters::YAML
  extend self

  # ameba:disable Metrics/CyclomaticComplexity
  def deserialize(input : IO, output : IO) : Nil
    yaml = ::YAML::PullParser.new(input)
    json = ::JSON::Builder.new(output)

    yaml.read_stream do
      loop do
        case yaml.kind
        when .document_start?
          json.start_document
        when .document_end?
          json.end_document
          yaml.read_next
          break
        when .scalar?
          string = yaml.value

          if json.next_is_object_key?
            json.scalar(string)
          else
            scalar = ::YAML::Schema::Core.parse_scalar(yaml)
            case scalar
            when Nil
              json.scalar(scalar)
            when Bool
              json.scalar(scalar)
            when Int64
              json.scalar(scalar)
            when Float64
              json.scalar(scalar)
            else
              json.scalar(string)
            end
          end
        when .sequence_start?
          json.start_array
        when .sequence_end?
          json.end_array
        when .mapping_start?
          json.start_object
        when .mapping_end?
          json.end_object
        end
        yaml.read_next
      end
    end
  end
end
