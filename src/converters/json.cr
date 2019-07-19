module OQ::Converters::Json
  def self.deserialize(input : IO, output : IO, **args)
    IO.copy input, output
  end

  def self.serialize(input : IO, output : IO, **args)
    IO.copy input, output
  end
end
