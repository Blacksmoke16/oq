# Converter for the `OQ::Format::JSON` format.
module OQ::Converters::JSON
  def self.deserialize(input : IO, output : IO) : Nil
    IO.copy input, output
  end

  def self.serialize(input : IO, output : IO) : Nil
    IO.copy input, output
  end
end
