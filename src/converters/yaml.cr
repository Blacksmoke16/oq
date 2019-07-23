class JSON::Builder
  def next_is_object_key?
    state = @state.last
    state.is_a?(ObjectState) && state.name
  end
end

module OQ::Converters::Yaml
  # ameba:disable Metrics/CyclomaticComplexity
  def self.deserialize(input : IO, output : IO, **args) : Nil
    yaml = YAML::PullParser.new(input)
    json = JSON::Builder.new(output)

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
            scalar = YAML::Schema::Core.parse_scalar(yaml)
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

  # ameba:disable Metrics/CyclomaticComplexity
  def self.serialize(input : IO, output : IO, **args) : Nil
    json = JSON::PullParser.new(input)
    yaml = YAML::Builder.new(output)

    yaml.stream do
      yaml.document do
        loop do
          case json.kind
          when :null
            yaml.scalar(nil)
          when :bool
            yaml.scalar(json.bool_value)
          when :int
            yaml.scalar(json.int_value)
          when :float
            yaml.scalar(json.float_value)
          when :string
            if YAML::Schema::Core.reserved_string?(json.string_value)
              yaml.scalar(json.string_value, style: :double_quoted)
            else
              yaml.scalar(json.string_value)
            end
          when :begin_array
            yaml.start_sequence
          when :end_array
            yaml.end_sequence
          when :begin_object
            yaml.start_mapping
          when :end_object
            yaml.end_mapping
          when :EOF
            break
          end
          json.read_next
        end
      end
    end
  end
end
