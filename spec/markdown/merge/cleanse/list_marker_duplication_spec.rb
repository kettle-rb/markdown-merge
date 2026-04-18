# frozen_string_literal: true

RSpec.describe Markdown::Merge::Cleanse::ListMarkerDuplication do
  describe "#malformed?" do
    it "returns true for ordered-over-dash corruption" do
      parser = described_class.new("1. - gem_checksums\n")

      expect(parser.malformed?).to be(true)
    end

    it "returns true for ordered-over-asterisk corruption" do
      parser = described_class.new("2. * Demonstrating empathy\n")

      expect(parser.malformed?).to be(true)
    end

    it "returns false for a normal ordered list" do
      parser = described_class.new("1. Install dependencies\n")

      expect(parser.malformed?).to be(false)
    end

    it "returns false for a normal unordered list" do
      parser = described_class.new("- gem_checksums\n")

      expect(parser.malformed?).to be(false)
    end
  end

  describe "#issues" do
    it "reports the line number for each corrupted line" do
      parser = described_class.new("1. - one\n2. - two\n")

      expect(parser.issues.map { |issue| issue[:line] }).to eq([1, 2])
      expect(parser.issues.map { |issue| issue[:type] }.uniq).to eq([:duplicated_list_marker])
    end
  end

  describe "#fix" do
    it "restores the original dash bullet marker" do
      content = <<~MD
        1. - gem_checksums
        2. - kettle-changelog
      MD

      expect(described_class.new(content).fix).to eq(<<~MD)
        - gem_checksums
        - kettle-changelog
      MD
    end

    it "restores the original asterisk bullet marker and wrapped continuation" do
      content = <<~MD
        4. * Accepting responsibility and apologizing to those affected by our mistakes,
          and learning from the experience
      MD

      expect(described_class.new(content).fix).to eq(<<~MD)
        * Accepting responsibility and apologizing to those affected by our mistakes,
          and learning from the experience
      MD
    end

    it "preserves nested child bullets under repaired parent bullets" do
      content = <<~MD
        1. - **Check violations**
            - `bundle exec rake rubocop_gradual`
            - `bundle exec rake rubocop_gradual:check`
      MD

      expect(described_class.new(content).fix).to eq(<<~MD)
        - **Check violations**
            - `bundle exec rake rubocop_gradual`
            - `bundle exec rake rubocop_gradual:check`
      MD
    end

    it "is idempotent" do
      content = <<~MD
        1. - gem_checksums
        2. - kettle-changelog
      MD

      first_pass = described_class.new(content).fix
      second_pass = described_class.new(first_pass).fix

      expect(second_pass).to eq(first_pass)
    end
  end
end
