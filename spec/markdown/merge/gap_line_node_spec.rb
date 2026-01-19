# frozen_string_literal: true

RSpec.describe Markdown::Merge::GapLineNode do
  describe "#initialize" do
    it "creates a gap line node" do
      node = described_class.new("some content", line_number: 5)

      expect(node).to be_a(described_class)
      expect(node.content).to eq("some content")
      expect(node.line_number).to eq(5)
    end

    it "strips trailing newline from content" do
      node = described_class.new("content\n", line_number: 1)
      expect(node.content).to eq("content")
    end

    it "handles empty content" do
      node = described_class.new("", line_number: 10)
      expect(node.content).to eq("")
    end

    it "handles whitespace-only content" do
      node = described_class.new("   ", line_number: 15)
      expect(node.content).to eq("   ")
    end
  end

  describe "#type" do
    it "returns :gap_line" do
      node = described_class.new("content", line_number: 1)
      expect(node.type).to eq(:gap_line)
    end
  end

  describe "#signature" do
    context "without preceding_node" do
      it "returns signature with line number and content" do
        node = described_class.new("some text", line_number: 42)
        expect(node.signature).to eq([:gap_line, 42, "some text"])
      end

      it "includes empty content in signature" do
        node = described_class.new("", line_number: 10)
        expect(node.signature).to eq([:gap_line, 10, ""])
      end
    end

    context "with preceding_node" do
      let(:preceding_node) do
        # Use TestableNode for real node behavior
        TestableNode.create(
          type: :heading,
          text: "# Heading",
          start_line: 1,
          end_line: 3,
        )
      end

      it "returns signature with offset and preceding type" do
        node = described_class.new("", line_number: 5)
        node.preceding_node = preceding_node
        # Offset is 5 - 3 = 2
        expect(node.signature).to eq([:gap_line_after, "heading", 2, ""])
      end

      it "includes content in offset-based signature" do
        node = described_class.new("some content", line_number: 4)
        node.preceding_node = preceding_node
        # Offset is 4 - 3 = 1
        expect(node.signature).to eq([:gap_line_after, "heading", 1, "some content"])
      end
    end

    context "with preceding_node without source_position (mock)" do
      let(:preceding_node) do
        # Use mock for testing edge case where source_position is not available
        mock_node = double("PrecedingNode")
        allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(false)
        mock_node
      end

      it "falls back to line number signature" do
        node = described_class.new("text", line_number: 10)
        node.preceding_node = preceding_node
        expect(node.signature).to eq([:gap_line, 10, "text"])
      end
    end

    context "with preceding_node with nil position (mock)" do
      let(:preceding_node) do
        # Use mock for testing edge case where source_position returns nil
        mock_node = double("PrecedingNode")
        allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(true)
        allow(mock_node).to receive(:source_position).and_return(nil)
        mock_node
      end

      it "falls back to line number signature" do
        node = described_class.new("text", line_number: 10)
        node.preceding_node = preceding_node
        expect(node.signature).to eq([:gap_line, 10, "text"])
      end
    end

    context "with preceding_node without type method (mock)" do
      let(:preceding_node) do
        # Use mock for testing edge case where type method is not available
        mock_node = double("PrecedingNode")
        allow(mock_node).to receive(:respond_to?).with(:source_position).and_return(true)
        allow(mock_node).to receive(:source_position).and_return({start_line: 1, end_line: 2})
        allow(mock_node).to receive(:respond_to?).with(:type).and_return(false)
        mock_node
      end

      it "uses :unknown as preceding type" do
        node = described_class.new("", line_number: 4)
        node.preceding_node = preceding_node
        # Offset is 4 - 2 = 2
        expect(node.signature).to eq([:gap_line_after, :unknown, 2, ""])
      end
    end
  end

  describe "#source_position" do
    it "returns position hash with line info" do
      node = described_class.new("content here", line_number: 25)
      pos = node.source_position

      expect(pos[:start_line]).to eq(25)
      expect(pos[:end_line]).to eq(25)
      expect(pos[:start_column]).to eq(0)
      expect(pos[:end_column]).to eq(12)
    end

    it "returns zero end_column for empty content" do
      node = described_class.new("", line_number: 5)
      pos = node.source_position

      expect(pos[:end_column]).to eq(0)
    end
  end

  describe "#children" do
    it "returns empty array" do
      node = described_class.new("content", line_number: 1)
      expect(node.children).to eq([])
    end
  end

  describe "#text" do
    it "returns the content" do
      node = described_class.new("the content", line_number: 1)
      expect(node.text).to eq("the content")
    end

    it "returns empty string for blank lines" do
      node = described_class.new("", line_number: 1)
      expect(node.text).to eq("")
    end
  end

  describe "#blank?" do
    it "returns true for empty content" do
      node = described_class.new("", line_number: 1)
      expect(node.blank?).to be true
    end

    it "returns true for whitespace-only content" do
      node = described_class.new("   ", line_number: 1)
      expect(node.blank?).to be true
    end

    it "returns true for tab content" do
      node = described_class.new("\t\t", line_number: 1)
      expect(node.blank?).to be true
    end

    it "returns false for content with text" do
      node = described_class.new("some text", line_number: 1)
      expect(node.blank?).to be false
    end

    it "returns false for content with mixed whitespace and text" do
      node = described_class.new("  text  ", line_number: 1)
      expect(node.blank?).to be false
    end
  end

  describe "#to_commonmark" do
    it "returns content with trailing newline" do
      node = described_class.new("some content", line_number: 1)
      expect(node.to_commonmark).to eq("some content\n")
    end

    it "returns just newline for empty content" do
      node = described_class.new("", line_number: 1)
      expect(node.to_commonmark).to eq("\n")
    end
  end

  describe "#inspect" do
    it "returns descriptive string" do
      node = described_class.new("text", line_number: 42)
      result = node.inspect

      expect(result).to include("GapLineNode")
      expect(result).to include("line=42")
      expect(result).to include('"text"')
    end

    it "handles empty content" do
      node = described_class.new("", line_number: 1)
      result = node.inspect

      expect(result).to include('""')
    end
  end
end
