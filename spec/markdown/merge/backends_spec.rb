# frozen_string_literal: true

RSpec.describe Markdown::Merge::Backends do
  describe "constants" do
    it "defines COMMONMARKER" do
      expect(described_class::COMMONMARKER).to eq(:commonmarker)
    end

    it "defines MARKLY" do
      expect(described_class::MARKLY).to eq(:markly)
    end

    it "defines AUTO" do
      expect(described_class::AUTO).to eq(:auto)
    end

    it "defines VALID_BACKENDS" do
      expect(described_class::VALID_BACKENDS).to contain_exactly(:commonmarker, :markly, :auto)
    end

    it "freezes VALID_BACKENDS" do
      expect(described_class::VALID_BACKENDS).to be_frozen
    end
  end

  describe ".validate!" do
    it "returns the backend when valid" do
      expect(described_class.validate!(:commonmarker)).to eq(:commonmarker)
      expect(described_class.validate!(:markly)).to eq(:markly)
      expect(described_class.validate!(:auto)).to eq(:auto)
    end

    it "raises ArgumentError for invalid backend" do
      expect { described_class.validate!(:invalid) }.to raise_error(
        ArgumentError,
        /Unknown backend: :invalid/,
      )
    end

    it "includes valid backends in error message" do
      expect { described_class.validate!(:foo) }.to raise_error(
        ArgumentError,
        /Valid backends:.*:commonmarker.*:markly.*:auto/,
      )
    end
  end

  describe ".valid?" do
    it "returns true for valid backends" do
      expect(described_class.valid?(:commonmarker)).to be true
      expect(described_class.valid?(:markly)).to be true
      expect(described_class.valid?(:auto)).to be true
    end

    it "returns false for invalid backends" do
      expect(described_class.valid?(:invalid)).to be false
      expect(described_class.valid?(nil)).to be false
      expect(described_class.valid?("commonmarker")).to be false
    end
  end
end

