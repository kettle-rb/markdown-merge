# frozen_string_literal: true

RSpec.describe Markdown::Merge::LinkDefinitionFormatter do
  describe ".format" do
    context "when node has content" do
      let(:node) do
        Markdown::Merge::LinkDefinitionNode.new(
          "[example]: https://example.com",
          label: "example",
          url: "https://example.com",
          line_number: 1,
        )
      end

      it "returns the original content" do
        expect(described_class.format(node)).to eq("[example]: https://example.com")
      end
    end

    context "when node has empty content" do
      let(:node) do
        node = Markdown::Merge::LinkDefinitionNode.new(
          "",
          label: "test",
          url: "https://test.com",
          line_number: 1,
        )
        node
      end

      it "reconstructs from components" do
        result = described_class.format(node)
        expect(result).to eq("[test]: https://test.com")
      end
    end

    context "when node has title" do
      let(:node) do
        Markdown::Merge::LinkDefinitionNode.new(
          "",
          label: "example",
          url: "https://example.com",
          title: "Example Title",
          line_number: 1,
        )
      end

      it "includes the title in quotes" do
        result = described_class.format(node)
        expect(result).to eq('[example]: https://example.com "Example Title"')
      end
    end

    context "when node has empty title" do
      let(:node) do
        Markdown::Merge::LinkDefinitionNode.new(
          "",
          label: "example",
          url: "https://example.com",
          title: "",
          line_number: 1,
        )
      end

      it "excludes empty title" do
        result = described_class.format(node)
        expect(result).to eq("[example]: https://example.com")
      end
    end

    context "when node has nil title" do
      let(:node) do
        Markdown::Merge::LinkDefinitionNode.new(
          "",
          label: "example",
          url: "https://example.com",
          title: nil,
          line_number: 1,
        )
      end

      it "excludes nil title" do
        result = described_class.format(node)
        expect(result).to eq("[example]: https://example.com")
      end
    end
  end

  describe ".format_all" do
    let(:nodes) do
      [
        Markdown::Merge::LinkDefinitionNode.new(
          "[first]: https://first.com",
          label: "first",
          url: "https://first.com",
          line_number: 1,
        ),
        Markdown::Merge::LinkDefinitionNode.new(
          "[second]: https://second.com",
          label: "second",
          url: "https://second.com",
          line_number: 2,
        ),
      ]
    end

    it "formats all nodes with default separator" do
      result = described_class.format_all(nodes)
      expect(result).to eq("[first]: https://first.com\n[second]: https://second.com")
    end

    it "accepts custom separator" do
      result = described_class.format_all(nodes, separator: "\n\n")
      expect(result).to eq("[first]: https://first.com\n\n[second]: https://second.com")
    end

    it "handles empty array" do
      expect(described_class.format_all([])).to eq("")
    end
  end
end
