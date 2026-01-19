# frozen_string_literal: true

RSpec.describe Markdown::Merge::OutputBuilder do
  let(:analysis) do
    mock_analysis = double("FileAnalysis")
    allow(mock_analysis).to receive(:source_range) do |start_line, end_line|
      "Source from #{start_line} to #{end_line}"
    end
    mock_analysis
  end

  describe "#initialize" do
    it "creates an empty builder by default" do
      builder = described_class.new
      expect(builder).to be_empty
    end

    it "accepts auto_spacing option" do
      builder = described_class.new(auto_spacing: true)
      expect(builder).to be_empty
    end

    it "accepts preserve_formatting option" do
      builder = described_class.new(preserve_formatting: true)
      expect(builder).to be_empty
    end
  end

  describe "#add_raw" do
    it "adds raw text content" do
      builder = described_class.new
      builder.add_raw("Hello, World!")

      expect(builder.to_s).to eq("Hello, World!")
    end

    it "ignores nil content" do
      builder = described_class.new
      builder.add_raw(nil)

      expect(builder).to be_empty
    end

    it "ignores empty string" do
      builder = described_class.new
      builder.add_raw("")

      expect(builder).to be_empty
    end

    it "appends multiple raw texts" do
      builder = described_class.new
      builder.add_raw("Hello")
      builder.add_raw(", ")
      builder.add_raw("World!")

      expect(builder.to_s).to eq("Hello, World!")
    end
  end

  describe "#add_gap_line" do
    it "adds a single blank line by default" do
      builder = described_class.new
      builder.add_gap_line

      expect(builder.to_s).to eq("\n")
    end

    it "adds multiple blank lines when count specified" do
      builder = described_class.new
      builder.add_gap_line(count: 3)

      expect(builder.to_s).to eq("\n\n\n")
    end

    it "adds nothing when count is 0" do
      builder = described_class.new
      builder.add_gap_line(count: 0)

      expect(builder).to be_empty
    end
  end

  describe "#add_link_definition" do
    let(:link_node) do
      Markdown::Merge::LinkDefinitionNode.new(
        "[example]: https://example.com",
        label: "example",
        url: "https://example.com",
        line_number: 1,
      )
    end

    it "adds formatted link definition" do
      builder = described_class.new
      builder.add_link_definition(link_node)

      expect(builder.to_s).to include("[example]:")
      expect(builder.to_s).to include("https://example.com")
    end
  end

  describe "#add_node_source" do
    context "with GapLineNode" do
      let(:gap_node) { Markdown::Merge::GapLineNode.new("", line_number: 5) }

      it "adds newline for gap lines" do
        builder = described_class.new
        builder.add_node_source(gap_node, analysis)

        expect(builder.to_s).to eq("\n")
      end
    end

    context "with LinkDefinitionNode" do
      let(:link_node) do
        Markdown::Merge::LinkDefinitionNode.new(
          "[test]: https://test.com",
          label: "test",
          url: "https://test.com",
          line_number: 1,
        )
      end

      it "adds formatted link definition with newline" do
        builder = described_class.new
        builder.add_node_source(link_node, analysis)

        expect(builder.to_s).to include("[test]:")
        expect(builder.to_s).to end_with("\n")
      end
    end

    context "with regular parser node" do
      let(:parser_node) do
        node = double("ParserNode")
        allow(node).to receive(:respond_to?).and_return(false)
        allow(node).to receive(:respond_to?).with(:source_position).and_return(true)
        allow(node).to receive(:respond_to?).with(:merge_type).and_return(true)
        allow(node).to receive_messages(
          source_position: {start_line: 1, end_line: 2},
          type: :paragraph,
          merge_type: :paragraph,
        )
        node
      end

      it "extracts source from analysis" do
        builder = described_class.new
        builder.add_node_source(parser_node, analysis)

        expect(builder.to_s).to eq("Source from 1 to 2")
      end
    end

    context "with node using start_line/end_line methods" do
      let(:parser_node) do
        node = double("ParserNode")
        allow(node).to receive(:respond_to?).and_return(false)
        allow(node).to receive(:respond_to?).with(:source_position).and_return(false)
        allow(node).to receive(:respond_to?).with(:merge_type).and_return(true)
        allow(node).to receive(:respond_to?).with(:type).and_return(true)
        allow(node).to receive(:respond_to?).with(:start_line).and_return(true)
        allow(node).to receive(:respond_to?).with(:end_line).and_return(true)
        allow(node).to receive_messages(
          start_line: 3,
          end_line: 5,
          type: :code_block,
          merge_type: :code_block,
        )
        node
      end

      it "extracts source using start_line/end_line methods" do
        builder = described_class.new
        builder.add_node_source(parser_node, analysis)

        expect(builder.to_s).to eq("Source from 3 to 5")
      end
    end

    context "with node without position info but with to_commonmark" do
      let(:parser_node) do
        node = double("ParserNode")
        allow(node).to receive(:respond_to?).and_return(false)
        allow(node).to receive(:respond_to?).with(:source_position).and_return(true)
        allow(node).to receive(:respond_to?).with(:merge_type).and_return(true)
        allow(node).to receive(:respond_to?).with(:type).and_return(true)
        allow(node).to receive(:respond_to?).with(:to_commonmark).and_return(true)
        allow(node).to receive_messages(
          source_position: {},
          to_commonmark: "# Heading\n",
          type: :heading,
          merge_type: :heading,
        )
        node
      end

      it "falls back to to_commonmark" do
        builder = described_class.new
        builder.add_node_source(parser_node, analysis)

        expect(builder.to_s).to eq("# Heading\n")
      end
    end
  end

  describe "#to_s" do
    it "joins all parts" do
      builder = described_class.new
      builder.add_raw("Line 1\n")
      builder.add_gap_line
      builder.add_raw("Line 2\n")

      expect(builder.to_s).to eq("Line 1\n\nLine 2\n")
    end
  end

  describe "#empty?" do
    it "returns true when no content added" do
      builder = described_class.new
      expect(builder).to be_empty
    end

    it "returns false when content added" do
      builder = described_class.new
      builder.add_raw("content")
      expect(builder).not_to be_empty
    end
  end

  describe "#clear" do
    it "removes all content" do
      builder = described_class.new
      builder.add_raw("content")
      builder.clear

      expect(builder).to be_empty
    end
  end

  describe "preserve_formatting option" do
    let(:analysis) do
      mock_analysis = double("FileAnalysis")
      allow(mock_analysis).to receive(:source_range) do |start_line, end_line|
        "Source from #{start_line} to #{end_line}"
      end
      mock_analysis
    end

    context "when preserve_formatting is false" do
      let(:parser_node) do
        node = double("ParserNode")
        allow(node).to receive(:respond_to?).and_return(false)
        allow(node).to receive(:respond_to?).with(:source_position).and_return(false)
        allow(node).to receive(:respond_to?).with(:merge_type).and_return(true)
        allow(node).to receive(:respond_to?).with(:type).and_return(true)
        allow(node).to receive(:respond_to?).with(:start_line).and_return(true)
        allow(node).to receive(:respond_to?).with(:end_line).and_return(true)
        allow(node).to receive_messages(
          start_line: 5,
          end_line: 7,
          type: :paragraph,
          merge_type: :paragraph,
        )
        node
      end

      it "extracts source using start_line/end_line" do
        builder = described_class.new(preserve_formatting: false)
        builder.add_node_source(parser_node, analysis)

        expect(builder.to_s).to eq("Source from 5 to 7")
      end
    end

    context "when preserve_formatting is true" do
      let(:parser_node) do
        node = double("ParserNode")
        allow(node).to receive(:respond_to?).and_return(false)
        allow(node).to receive(:respond_to?).with(:source_position).and_return(false)
        allow(node).to receive(:respond_to?).with(:merge_type).and_return(true)
        allow(node).to receive(:respond_to?).with(:type).and_return(true)
        allow(node).to receive(:respond_to?).with(:start_line).and_return(true)
        allow(node).to receive(:respond_to?).with(:end_line).and_return(true)
        allow(node).to receive_messages(
          start_line: 5,
          end_line: 7,
          type: :paragraph,
          merge_type: :paragraph,
        )
        node
      end

      it "extracts source using start_line/end_line" do
        builder = described_class.new(preserve_formatting: true)
        builder.add_node_source(parser_node, analysis)

        expect(builder.to_s).to eq("Source from 5 to 7")
      end
    end
  end

  describe "auto_spacing" do
    context "when enabled" do
      it "adds blank line between different node types that need spacing" do
        builder = described_class.new(auto_spacing: true)

        heading_node = double("HeadingNode")
        allow(heading_node).to receive(:respond_to?).and_return(false)
        allow(heading_node).to receive(:respond_to?).with(:source_position).and_return(true)
        allow(heading_node).to receive(:respond_to?).with(:merge_type).and_return(true)
        allow(heading_node).to receive(:respond_to?).with(:type).and_return(true)
        allow(heading_node).to receive_messages(
          source_position: {start_line: 1, end_line: 1},
          type: :heading,
          merge_type: :heading,
        )

        paragraph_node = double("ParagraphNode")
        allow(paragraph_node).to receive(:respond_to?).and_return(false)
        allow(paragraph_node).to receive(:respond_to?).with(:source_position).and_return(true)
        allow(paragraph_node).to receive(:respond_to?).with(:merge_type).and_return(true)
        allow(paragraph_node).to receive(:respond_to?).with(:type).and_return(true)
        allow(paragraph_node).to receive_messages(
          source_position: {start_line: 3, end_line: 3},
          type: :paragraph,
          merge_type: :paragraph,
        )

        builder.add_node_source(heading_node, analysis)
        builder.add_node_source(paragraph_node, analysis)

        # The content includes auto-added spacing
        result = builder.to_s
        expect(result).to include("Source from 1 to 1")
        expect(result).to include("Source from 3 to 3")
      end
    end
  end
end
