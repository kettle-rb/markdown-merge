# frozen_string_literal: true

RSpec.describe Markdown::Merge::Cleanse::TemplatingCorruption do
  describe "#malformed?" do
    it "detects known templating list corruption" do
      content = <<~MD
        1. - gem_checksums
        2. - kettle-changelog
      MD

      expect(described_class.new(content).malformed?).to be(true)
    end

    it "returns false for well-formed markdown" do
      content = <<~MD
        - gem_checksums
        - kettle-changelog
      MD

      expect(described_class.new(content).malformed?).to be(false)
    end
  end

  describe "#fix" do
    it "repairs a representative real-world corruption sample" do
      content = <<~MD
        **Do not use** the standard RuboCop commands like:
        1. - `bundle exec rubocop`
        2. - `rubocop`

        ## Common Commands

        1. - **Check violations**
            - `bundle exec rake rubocop_gradual`
            - `bundle exec rake rubocop_gradual:check`
        2. - **(Safe) Autocorrect violations, and update lockfile if no new violations**
          - `bundle exec rake rubocop_gradual:autocorrect`
      MD

      expect(described_class.new(content).fix).to eq(<<~MD)
        **Do not use** the standard RuboCop commands like:
        - `bundle exec rubocop`
        - `rubocop`

        ## Common Commands

        - **Check violations**
            - `bundle exec rake rubocop_gradual`
            - `bundle exec rake rubocop_gradual:check`
        - **(Safe) Autocorrect violations, and update lockfile if no new violations**
          - `bundle exec rake rubocop_gradual:autocorrect`
      MD
    end

    it "chains with existing cleanse passes" do
      content = "1. - Item\n### Heading\n"

      expect(described_class.new(content).fix).to eq("- Item\n\n### Heading\n")
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
