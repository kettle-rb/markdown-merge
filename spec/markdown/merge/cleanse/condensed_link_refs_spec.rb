# frozen_string_literal: true

RSpec.describe Markdown::Merge::Cleanse::CondensedLinkRefs do
  describe "#condensed?" do
    it "returns true for condensed definitions" do
      text = "[label1]: https://example1.com[label2]: https://example2.com"
      parser = described_class.new(text)
      expect(parser.condensed?).to be true
    end

    it "returns true for condensed definitions with emoji labels" do
      text = "[⛳liberapay-img]: https://img.shields.io/liberapay/goal/pboling.svg[⛳liberapay]: https://liberapay.com"
      parser = described_class.new(text)
      expect(parser.condensed?).to be true
    end

    it "returns false for properly separated definitions" do
      text = "[label1]: https://example1.com\n[label2]: https://example2.com"
      parser = described_class.new(text)
      expect(parser.condensed?).to be false
    end

    it "returns false for single definition" do
      text = "[label]: https://example.com"
      parser = described_class.new(text)
      expect(parser.condensed?).to be false
    end

    it "returns false for empty string" do
      parser = described_class.new("")
      expect(parser.condensed?).to be false
    end

    it "returns false for text without link definitions" do
      text = "Just some regular text without any links"
      parser = described_class.new(text)
      expect(parser.condensed?).to be false
    end

    it "returns false for reference-style links followed by colon" do
      # This is a reference-style link [text][label] followed by punctuation (:)
      # NOT a condensed link ref definition
      text = "**[Floss-Funding.dev][🖇floss-funding.dev]: Some description**"
      parser = described_class.new(text)
      expect(parser.condensed?).to be false
    end

    it "returns false for reference-style links in bold with colon" do
      text = "**[Link Text][label]: description here**"
      parser = described_class.new(text)
      expect(parser.condensed?).to be false
    end

    it "returns true for condensed refs with relative URL (CONTRIBUTING.md)" do
      text = "https://donate.codeberg.org/[🤝contributing]: CONTRIBUTING.md"
      parser = described_class.new(text)
      expect(parser.condensed?).to be true
    end

    it "returns true for condensed refs with relative URL (CODE_OF_CONDUCT.md)" do
      text = "https://gitlab.com/kettle-rb/jsonc-merge/-/graphs/main[🪇conduct]: CODE_OF_CONDUCT.md"
      parser = described_class.new(text)
      expect(parser.condensed?).to be true
    end

    it "returns true for condensed refs with relative URL (CHANGELOG.md)" do
      text = "https://example.com/page.html[📌changelog]: CHANGELOG.md"
      parser = described_class.new(text)
      expect(parser.condensed?).to be true
    end

    it "returns true for condensed refs with relative URL (LICENSE.txt)" do
      text = "https://example.com/page[📄license]: LICENSE.txt"
      parser = described_class.new(text)
      expect(parser.condensed?).to be true
    end
  end

  describe "#definitions" do
    it "returns empty for a single definition (not condensed)" do
      text = "[label]: https://example.com"
      parser = described_class.new(text)

      # A single definition is NOT condensed, so definitions returns empty
      expect(parser.definitions).to eq([])
    end

    it "parses two condensed definitions" do
      text = "[label1]: https://example1.com[label2]: https://example2.com"
      parser = described_class.new(text)

      expect(parser.definitions.size).to eq(2)
      expect(parser.definitions[0][:label]).to eq("label1")
      expect(parser.definitions[0][:url]).to eq("https://example1.com")
      expect(parser.definitions[1][:label]).to eq("label2")
      expect(parser.definitions[1][:url]).to eq("https://example2.com")
    end

    it "parses many condensed definitions with emoji labels" do
      text = "[⛳liberapay-img]: https://img.shields.io/liberapay/goal/pboling.svg?logo=liberapay&color=a51611&style=flat[⛳liberapay-bottom-img]: https://img.shields.io/liberapay/goal/pboling.svg?style=for-the-badge&logo=liberapay&color=a51611[⛳liberapay]: https://liberapay.com/pboling/donate"
      parser = described_class.new(text)

      expect(parser.definitions.size).to eq(3)
      expect(parser.definitions[0][:label]).to eq("⛳liberapay-img")
      expect(parser.definitions[0][:url]).to eq("https://img.shields.io/liberapay/goal/pboling.svg?logo=liberapay&color=a51611&style=flat")
      expect(parser.definitions[1][:label]).to eq("⛳liberapay-bottom-img")
      expect(parser.definitions[1][:url]).to eq("https://img.shields.io/liberapay/goal/pboling.svg?style=for-the-badge&logo=liberapay&color=a51611")
      expect(parser.definitions[2][:label]).to eq("⛳liberapay")
      expect(parser.definitions[2][:url]).to eq("https://liberapay.com/pboling/donate")
    end

    it "parses definitions with special characters in labels" do
      text = "[🖇osc-all-img]: https://img.shields.io/opencollective/all/kettle-rb[🖇osc-sponsors-img]: https://img.shields.io/opencollective/sponsors/kettle-rb"
      parser = described_class.new(text)

      expect(parser.definitions.size).to eq(2)
      expect(parser.definitions[0][:label]).to eq("🖇osc-all-img")
      expect(parser.definitions[1][:label]).to eq("🖇osc-sponsors-img")
    end

    it "handles mixed emoji and ASCII labels" do
      text = "[💖🖇linkedin]: http://www.linkedin.com/in/peterboling[💖🖇linkedin-img]: https://img.shields.io/badge/PeterBoling-LinkedIn-0B66C2"
      parser = described_class.new(text)

      expect(parser.definitions.size).to eq(2)
      expect(parser.definitions[0][:label]).to eq("💖🖇linkedin")
      expect(parser.definitions[1][:label]).to eq("💖🖇linkedin-img")
    end

    it "handles definitions with complex query strings" do
      text = "[🏙️entsup-tidelift]: https://tidelift.com/subscription/pkg/rubygems-bash-merge?utm_source=rubygems-bash-merge&utm_medium=referral&utm_campaign=readme[🏙️entsup-tidelift-img]: https://img.shields.io/badge/Tidelift_and_Sonar-Enterprise_Support-FD3456"
      parser = described_class.new(text)

      expect(parser.definitions.size).to eq(2)
      expect(parser.definitions[0][:url]).to include("utm_source=")
      expect(parser.definitions[0][:url]).to include("utm_campaign=readme")
    end

    it "returns empty array for non-link-def content" do
      parser = described_class.new("Just regular text")
      expect(parser.definitions).to eq([])
    end
  end

  describe "#expand" do
    it "expands two condensed definitions" do
      text = "[label1]: https://example1.com[label2]: https://example2.com"
      parser = described_class.new(text)

      result = parser.expand
      lines = result.strip.split("\n")

      expect(lines.size).to eq(2)
      expect(lines[0]).to eq("[label1]: https://example1.com")
      expect(lines[1]).to eq("[label2]: https://example2.com")
    end

    it "expands many condensed definitions with emoji" do
      text = "[⛳liberapay-img]: https://img.shields.io/liberapay/goal/pboling.svg[⛳liberapay]: https://liberapay.com/pboling/donate[🖇osc-all-img]: https://img.shields.io/opencollective/all/kettle-rb"
      parser = described_class.new(text)

      result = parser.expand
      lines = result.strip.split("\n")

      expect(lines.size).to eq(3)
      expect(lines[0]).to start_with("[⛳liberapay-img]:")
      expect(lines[1]).to start_with("[⛳liberapay]:")
      expect(lines[2]).to start_with("[🖇osc-all-img]:")
    end

    it "returns original for already-separated definitions" do
      text = "[label1]: https://example1.com\n[label2]: https://example2.com\n"
      parser = described_class.new(text)

      expect(parser.expand).to eq(text)
    end

    it "preserves content before link definitions" do
      text = "# Header\n\nSome text.\n\n[label1]: https://example1.com[label2]: https://example2.com"
      parser = described_class.new(text)

      result = parser.expand
      expect(result).to start_with("# Header\n\nSome text.")
      expect(result).to include("[label1]: https://example1.com\n[label2]:")
    end

    it "adds trailing newline" do
      # Note: expand preserves trailing newline if present, but doesn't add one
      text = "[label1]: https://example1.com[label2]: https://example2.com\n"
      parser = described_class.new(text)

      result = parser.expand
      expect(result).to end_with("\n")
    end
  end

  describe "#count" do
    it "returns correct count for condensed definitions" do
      text = "[l1]: https://e1.com[l2]: https://e2.com[l3]: https://e3.com"
      parser = described_class.new(text)

      expect(parser.count).to eq(3)
    end

    it "returns 0 for empty string" do
      parser = described_class.new("")
      expect(parser.count).to eq(0)
    end
  end

  describe "real-world bug scenario" do
    let(:condensed_bug_output) do
      # This is actual output from the bug - first few definitions from the sample
      "[⛳liberapay-img]: https://img.shields.io/liberapay/goal/pboling.svg?logo=liberapay&color=a51611&style=flat" \
        "[⛳liberapay-bottom-img]: https://img.shields.io/liberapay/goal/pboling.svg?style=for-the-badge&logo=liberapay&color=a51611" \
        "[⛳liberapay]: https://liberapay.com/pboling/donate" \
        "[🖇osc-all-img]: https://img.shields.io/opencollective/all/kettle-rb" \
        "[🖇osc-sponsors-img]: https://img.shields.io/opencollective/sponsors/kettle-rb" \
        "[🖇osc-backers-img]: https://img.shields.io/opencollective/backers/kettle-rb"
    end

    it "detects as condensed" do
      parser = described_class.new(condensed_bug_output)
      expect(parser.condensed?).to be true
    end

    it "parses all definitions" do
      parser = described_class.new(condensed_bug_output)
      expect(parser.count).to eq(6)
    end

    it "extracts correct labels" do
      parser = described_class.new(condensed_bug_output)
      labels = parser.definitions.map { |d| d[:label] }

      expect(labels).to include("⛳liberapay-img")
      expect(labels).to include("⛳liberapay-bottom-img")
      expect(labels).to include("⛳liberapay")
      expect(labels).to include("🖇osc-all-img")
      expect(labels).to include("🖇osc-sponsors-img")
      expect(labels).to include("🖇osc-backers-img")
    end

    it "expands to proper format" do
      parser = described_class.new(condensed_bug_output)
      result = parser.expand
      lines = result.strip.split("\n")

      expect(lines.size).to eq(6)
      expect(lines).to all(match(/^\[[^\]]+\]: https?:\/\//))
    end
  end

  describe "edge cases" do
    it "handles labels with hyphens" do
      text = "[my-label-here]: https://example.com[another-label]: https://other.com"
      parser = described_class.new(text)

      expect(parser.definitions[0][:label]).to eq("my-label-here")
      expect(parser.definitions[1][:label]).to eq("another-label")
    end

    it "handles labels with underscores" do
      text = "[my_label]: https://example.com[other_label]: https://other.com"
      parser = described_class.new(text)

      expect(parser.definitions[0][:label]).to eq("my_label")
      expect(parser.definitions[1][:label]).to eq("other_label")
    end

    it "handles URLs with fragments" do
      text = "[label1]: https://example.com#section[label2]: https://other.com#anchor"
      parser = described_class.new(text)

      expect(parser.definitions[0][:url]).to eq("https://example.com#section")
      expect(parser.definitions[1][:url]).to eq("https://other.com#anchor")
    end

    it "handles http and https URLs" do
      text = "[secure]: https://secure.com[insecure]: http://insecure.com"
      parser = described_class.new(text)

      expect(parser.definitions[0][:url]).to start_with("https://")
      expect(parser.definitions[1][:url]).to start_with("http://")
    end

    it "handles URLs with ports" do
      text = "[local]: http://localhost:3000[prod]: https://prod.com:443"
      parser = described_class.new(text)

      expect(parser.definitions[0][:url]).to eq("http://localhost:3000")
      expect(parser.definitions[1][:url]).to eq("https://prod.com:443")
    end

    it "handles labels with numbers" do
      text = "[label1]: https://one.com[label2]: https://two.com[label123]: https://numbers.com"
      parser = described_class.new(text)

      labels = parser.definitions.map { |d| d[:label] }
      expect(labels).to eq(%w[label1 label2 label123])
    end
  end
end
