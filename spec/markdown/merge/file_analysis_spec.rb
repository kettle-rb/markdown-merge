# frozen_string_literal: true

RSpec.describe Markdown::Merge::FileAnalysis do
  let(:simple_markdown) do
    <<~MARKDOWN
      # Hello World

      This is a paragraph.

      ## Section Two

      Another paragraph here.
    MARKDOWN
  end

  let(:markdown_with_freeze) do
    <<~MARKDOWN
      # Title

      <!-- markdown-merge:freeze -->
      ## Frozen Section
      This content is frozen.
      <!-- markdown-merge:unfreeze -->

      ## Regular Section
      This content is not frozen.
    MARKDOWN
  end

  describe "#initialize", :markdown_backend do
    it "creates analysis with auto backend" do
      analysis = described_class.new(simple_markdown)
      expect(analysis).to be_a(described_class)
    end

    it "stores the source" do
      analysis = described_class.new(simple_markdown)
      expect(analysis.source).to eq(simple_markdown)
    end

    it "resolves the backend" do
      analysis = described_class.new(simple_markdown)
      expect([:commonmarker, :markly]).to include(analysis.backend)
    end

    it "accepts explicit backend option", :commonmarker do
      analysis = described_class.new(simple_markdown, backend: :commonmarker)
      expect(analysis.backend).to eq(:commonmarker)
    end

    it "accepts markly backend option", :markly do
      analysis = described_class.new(simple_markdown, backend: :markly)
      expect(analysis.backend).to eq(:markly)
    end

    it "raises for invalid backend" do
      expect {
        described_class.new(simple_markdown, backend: :invalid)
      }.to raise_error(ArgumentError, /Unknown backend/)
    end
  end

  describe "#statements", :markdown_backend do
    it "returns an array of nodes" do
      analysis = described_class.new(simple_markdown)
      expect(analysis.statements).to be_an(Array)
    end

    it "wraps nodes with canonical types" do
      analysis = described_class.new(simple_markdown)
      first_node = analysis.statements.first

      expect(first_node).to respond_to(:merge_type)
      expect(first_node.merge_type).to eq(:heading)
    end

    it "extracts top-level block elements" do
      analysis = described_class.new(simple_markdown)
      types = analysis.statements.map(&:merge_type)

      expect(types).to include(:heading)
      expect(types).to include(:paragraph)
    end
  end

  describe "#freeze_blocks", :markdown_backend do
    it "detects freeze blocks" do
      analysis = described_class.new(markdown_with_freeze)
      expect(analysis.freeze_blocks).not_to be_empty
    end

    it "returns FreezeNode instances" do
      analysis = described_class.new(markdown_with_freeze)
      freeze_block = analysis.freeze_blocks.first

      expect(freeze_block).to be_a(Markdown::Merge::FreezeNode)
    end
  end

  describe "#compute_parser_signature", :markdown_backend do
    it "generates signatures for headings with level and content" do
      analysis = described_class.new(simple_markdown)
      heading = analysis.statements.first

      signature = analysis.generate_signature(heading)
      expect(signature).to be_an(Array)
      expect(signature.first).to eq(:heading)
    end

    it "generates signatures for paragraphs with content hash" do
      analysis = described_class.new(simple_markdown)
      paragraph = analysis.statements.find { |n| n.merge_type == :paragraph }

      signature = analysis.generate_signature(paragraph)
      expect(signature).to be_an(Array)
      expect(signature.first).to eq(:paragraph)
    end
  end

  describe "backend-specific options" do
    context "with commonmarker", :commonmarker do
      it "accepts options hash" do
        analysis = described_class.new(simple_markdown, backend: :commonmarker, options: {})
        expect(analysis.backend).to eq(:commonmarker)
      end
    end

    context "with markly", :markly do
      it "accepts flags and extensions" do
        analysis = described_class.new(
          simple_markdown,
          backend: :markly,
          flags: Markly::DEFAULT,
          extensions: [:table],
        )
        expect(analysis.backend).to eq(:markly)
      end
    end
  end

  describe "type normalization consistency", :commonmarker, :markly do
    it "produces same canonical types for same content across backends" do
      cm_analysis = described_class.new(simple_markdown, backend: :commonmarker)
      markly_analysis = described_class.new(simple_markdown, backend: :markly)

      cm_types = cm_analysis.statements.map(&:merge_type)
      markly_types = markly_analysis.statements.map(&:merge_type)

      # Both should have :heading and :paragraph in canonical form
      expect(cm_types).to include(:heading)
      expect(markly_types).to include(:heading)
      expect(cm_types).to include(:paragraph)
      expect(markly_types).to include(:paragraph)
    end
  end
end

