# frozen_string_literal: true

RSpec.describe Markdown::Merge::LinkDefinitionNode do
  describe ".parse" do
    it "parses a simple link definition" do
      line = "[example]: https://example.com"
      node = described_class.parse(line, line_number: 5)

      expect(node).to be_a(described_class)
      expect(node.label).to eq("example")
      expect(node.url).to eq("https://example.com")
      expect(node.title).to be_nil
    end

    it "parses a link definition with double-quoted title" do
      line = '[example]: https://example.com "Example Title"'
      node = described_class.parse(line, line_number: 10)

      expect(node.label).to eq("example")
      expect(node.url).to eq("https://example.com")
      expect(node.title).to eq("Example Title")
    end

    it "parses a link definition with single-quoted title" do
      line = "[example]: https://example.com 'Example Title'"
      node = described_class.parse(line, line_number: 10)

      expect(node.label).to eq("example")
      expect(node.url).to eq("https://example.com")
      expect(node.title).to eq("Example Title")
    end

    it "parses a link definition with parenthesized title" do
      line = "[example]: https://example.com (Example Title)"
      node = described_class.parse(line, line_number: 10)

      expect(node.label).to eq("example")
      expect(node.url).to eq("https://example.com")
      expect(node.title).to eq("Example Title")
    end

    it "parses a link definition with angle-bracketed URL" do
      line = "[example]: <https://example.com>"
      node = described_class.parse(line, line_number: 15)

      expect(node.label).to eq("example")
      expect(node.url).to eq("https://example.com")
    end

    it "parses a link definition with leading whitespace" do
      line = "   [example]: https://example.com"
      node = described_class.parse(line, line_number: 20)

      expect(node).to be_a(described_class)
      expect(node.label).to eq("example")
    end

    it "returns nil for non-link-definition lines" do
      expect(described_class.parse("Just some text", line_number: 1)).to be_nil
      expect(described_class.parse("# Heading", line_number: 1)).to be_nil
      expect(described_class.parse("", line_number: 1)).to be_nil
      expect(described_class.parse("[link](url)", line_number: 1)).to be_nil
    end

    it "preserves original content" do
      line = "[ref]: https://example.com"
      node = described_class.parse(line, line_number: 1)

      expect(node.content).to eq("[ref]: https://example.com")
    end

    it "strips trailing newline from content" do
      line = "[ref]: https://example.com\n"
      node = described_class.parse(line, line_number: 1)

      expect(node.content).to eq("[ref]: https://example.com")
    end
  end

  describe ".link_definition?" do
    it "returns true for link definitions" do
      expect(described_class.link_definition?("[ref]: https://example.com")).to be true
      expect(described_class.link_definition?('[ref]: https://example.com "Title"')).to be true
      expect(described_class.link_definition?("  [ref]: https://example.com")).to be true
    end

    it "returns false for non-link-definitions" do
      expect(described_class.link_definition?("Regular text")).to be false
      expect(described_class.link_definition?("# Heading")).to be false
      expect(described_class.link_definition?("[link](url)")).to be false
      expect(described_class.link_definition?("")).to be false
    end
  end

  describe "#type" do
    it "returns :link_definition" do
      node = described_class.parse("[ref]: https://example.com", line_number: 1)
      expect(node.type).to eq(:link_definition)
    end
  end

  describe "#signature" do
    it "returns signature with lowercase label" do
      node = described_class.parse("[MyRef]: https://example.com", line_number: 1)
      expect(node.signature).to eq([:link_definition, "myref"])
    end

    it "matches case-insensitively" do
      node1 = described_class.parse("[REF]: https://example.com", line_number: 1)
      node2 = described_class.parse("[ref]: https://other.com", line_number: 2)

      expect(node1.signature).to eq(node2.signature)
    end
  end

  describe "#source_position" do
    it "returns position hash with line info" do
      node = described_class.parse("[ref]: https://example.com", line_number: 42)
      pos = node.source_position

      expect(pos[:start_line]).to eq(42)
      expect(pos[:end_line]).to eq(42)
      expect(pos[:start_column]).to eq(0)
      expect(pos[:end_column]).to eq(26)
    end
  end

  describe "#children" do
    it "returns empty array" do
      node = described_class.parse("[ref]: https://example.com", line_number: 1)
      expect(node.children).to eq([])
    end
  end

  describe "#text" do
    it "returns the content" do
      node = described_class.parse("[ref]: https://example.com", line_number: 1)
      expect(node.text).to eq("[ref]: https://example.com")
    end
  end

  describe "#to_commonmark" do
    it "returns content with trailing newline" do
      node = described_class.parse("[ref]: https://example.com", line_number: 1)
      expect(node.to_commonmark).to eq("[ref]: https://example.com\n")
    end
  end

  describe "#inspect" do
    it "returns descriptive string" do
      node = described_class.parse("[ref]: https://example.com", line_number: 1)
      expect(node.inspect).to include("LinkDefinitionNode")
      expect(node.inspect).to include("[ref]")
      expect(node.inspect).to include("https://example.com")
    end
  end
end
