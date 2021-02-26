require "./spec_helper"

describe OQ::Format do
  describe ".to_s" do
    it "returns a comma separated list of the formats" do
      OQ::Format.to_s.should eq "json, simpleyaml, xml, yaml"
    end
  end
end
