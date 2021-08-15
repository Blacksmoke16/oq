# :nodoc:
#
# Denotes a converter exposes the related `OQ::Processor`
# instance in order to read configuration options off of it.
module OQ::Converters::ProcessorAware
  macro extended
    class_property! processor : OQ::Processor
  end
end
