# frozen_string_literal: true

# Direct coverage tests for smart_merger.rb
# Uses :markdown_backend tag - tests only run when commonmarker or markly is available

RSpec.describe Markdown::Merge::SmartMerger, "coverage", :markdown_parsing do
  let(:template_content) do
    <<~MD
      # Project Title

      Template description.

      ## Installation

      Install instructions here.

      ## Usage

      Usage instructions.
    MD
  end

  let(:dest_content) do
    <<~MD
      # Project Title

      Custom description for my fork.

      ## Installation

      Custom install instructions.

      ## Custom Section

      My custom content.
    MD
  end

  describe "#initialize coverage" do
    it "creates merger with default options" do
      merger = described_class.new(template_content, dest_content)
      expect(merger).to be_a(described_class)
      expect(merger.backend).to be_a(Symbol)
    end

    it "accepts preference option" do
      merger = described_class.new(template_content, dest_content, preference: :template)
      expect(merger).to be_a(described_class)
    end

    it "accepts add_template_only_nodes option" do
      merger = described_class.new(template_content, dest_content, add_template_only_nodes: true)
      expect(merger).to be_a(described_class)
    end

    it "accepts inner_merge_code_blocks option" do
      merger = described_class.new(template_content, dest_content, inner_merge_code_blocks: true)
      expect(merger).to be_a(described_class)
    end

    it "accepts freeze_token option" do
      merger = described_class.new(template_content, dest_content, freeze_token: "custom-freeze")
      expect(merger).to be_a(described_class)
    end

    it "accepts signature_generator option" do
      custom_sig = ->(node) { [:custom, node.object_id] }
      merger = described_class.new(template_content, dest_content, signature_generator: custom_sig)
      expect(merger).to be_a(described_class)
    end

    it "accepts explicit commonmarker backend", :commonmarker do
      merger = described_class.new(template_content, dest_content, backend: :commonmarker)
      expect(merger.backend).to eq(:commonmarker)
    end

    it "accepts explicit markly backend", :markly do
      merger = described_class.new(template_content, dest_content, backend: :markly)
      expect(merger.backend).to eq(:markly)
    end
  end

  describe "#merge coverage" do
    it "returns merged content as string" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge
      expect(result).to be_a(String)
    end

    it "preserves destination customizations" do
      merger = described_class.new(template_content, dest_content, preference: :destination)
      result = merger.merge
      expect(result).to include("Custom description")
    end

    it "handles template preference" do
      # With template preference, matching nodes use template version
      # Non-matching nodes from destination are preserved
      merger = described_class.new(template_content, dest_content, preference: :template)
      result = merger.merge
      # The result should still be valid markdown
      expect(result).to be_a(String)
      expect(result).to include("# Project Title")
    end
  end

  describe "#merge_result coverage" do
    it "returns MergeResult object" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge_result
      expect(result).to be_a(Markdown::Merge::MergeResult)
    end

    it "includes stats" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge_result
      expect(result.stats).to be_a(Hash)
    end

    it "includes content" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge_result
      expect(result.content).to be_a(String)
    end
  end

  describe "#create_file_analysis coverage" do
    it "creates FileAnalysis instances" do
      merger = described_class.new(template_content, dest_content)
      analysis = merger.send(:create_file_analysis, "# Test", freeze_token: "test-token")
      expect(analysis).to be_a(Markdown::Merge::FileAnalysis)
    end
  end

  describe "#node_to_source coverage" do
    it "converts nodes to source text" do
      merger = described_class.new(template_content, dest_content)
      node = merger.template_analysis.statements.first
      raw = Ast::Merge::NodeTyping.unwrap(node)
      source = merger.send(:node_to_source, raw, merger.template_analysis)
      expect(source).to be_a(String)
    end

    it "handles LinkDefinitionNode" do
      md_with_link = "# Title\n\n[ref]: https://example.com\n\nParagraph."
      merger = described_class.new(md_with_link, md_with_link)
      link_node = merger.template_analysis.statements.find { |s| s.is_a?(Markdown::Merge::LinkDefinitionNode) }
      if link_node
        source = merger.send(:node_to_source, link_node, merger.template_analysis)
        expect(source).to include("ref")
      end
    end

    it "handles GapLineNode" do
      md_with_gaps = "# Title\n\n\n\nParagraph."
      merger = described_class.new(md_with_gaps, md_with_gaps)
      gap_node = merger.template_analysis.statements.find { |s| s.is_a?(Markdown::Merge::GapLineNode) }
      if gap_node
        source = merger.send(:node_to_source, gap_node, merger.template_analysis)
        expect(source).to be_a(String)
      end
    end

    it "handles FreezeNode" do
      md_with_freeze = <<~MD
        # Title

        <!-- markdown-merge:freeze -->
        Frozen content here.
        <!-- markdown-merge:unfreeze -->

        Regular content.
      MD
      merger = described_class.new(md_with_freeze, md_with_freeze)
      freeze_node = merger.template_analysis.statements.find { |s| s.is_a?(Ast::Merge::FreezeNodeBase) }
      if freeze_node
        source = merger.send(:node_to_source, freeze_node, merger.template_analysis)
        expect(source).to include("Frozen content")
      end
    end

    it "handles nodes without position info by falling back to to_commonmark" do
      merger = described_class.new(template_content, dest_content)

      # Create a mock node that has no position info but has to_commonmark
      mock_node = double("MockNode")
      allow(mock_node).to receive(:source_position).and_return(nil)
      allow(mock_node).to receive(:to_commonmark).and_return("# Fallback Content\n")

      source = merger.send(:node_to_source, mock_node, merger.template_analysis)
      expect(source).to eq("# Fallback Content\n")
    end

    it "handles empty source by falling back to to_commonmark" do
      merger = described_class.new(template_content, dest_content)

      # Create a mock node that has position info but returns empty source
      mock_node = double("MockNode")
      allow(mock_node).to receive(:source_position).and_return({start_line: 1, end_line: 0})
      allow(mock_node).to receive(:respond_to?).with(:to_commonmark).and_return(true)
      allow(mock_node).to receive(:to_commonmark).and_return("# Fallback Content\n")

      # Mock the analysis to return empty string for the invalid range
      mock_analysis = double("MockAnalysis")
      allow(mock_analysis).to receive(:source_range).with(1, 0).and_return("")

      source = merger.send(:node_to_source, mock_node, mock_analysis)
      expect(source).to eq("# Fallback Content")
    end

    it "handles nodes with valid source_position" do
      merger = described_class.new(template_content, dest_content)
      # Get a real node with position info
      node = merger.template_analysis.statements.first
      raw = Ast::Merge::NodeTyping.unwrap(node)

      if raw.source_position && raw.source_position[:start_line]
        source = merger.send(:node_to_source, raw, merger.template_analysis)
        expect(source).not_to be_empty
      end
    end
  end

  describe "complex merge scenarios" do
    let(:complex_template) do
      <<~MD
        # Project

        Description.

        ## Features

        - Feature A
        - Feature B

        ## Installation

        ```bash
        gem install foo
        ```

        ---

        ## License

        MIT
      MD
    end

    let(:complex_dest) do
      <<~MD
        # Project

        My custom description.

        ## Features

        - Feature A
        - Feature C
        - Feature D

        ## Custom Section

        Custom content here.

        ## License

        Apache 2.0
      MD
    end

    it "handles complex documents" do
      merger = described_class.new(complex_template, complex_dest)
      result = merger.merge
      expect(result).to be_a(String)
      expect(result).to include("# Project")
    end

    it "preserves destination-only sections" do
      merger = described_class.new(complex_template, complex_dest)
      result = merger.merge
      expect(result).to include("Custom Section")
    end
  end

  describe "freeze block handling" do
    let(:frozen_dest) do
      <<~MD
        # Title

        <!-- markdown-merge:freeze -->
        ## Frozen Section

        This content is frozen and should not change.
        <!-- markdown-merge:unfreeze -->

        ## Regular Section

        This can change.
      MD
    end

    it "preserves frozen content" do
      merger = described_class.new(template_content, frozen_dest)
      result = merger.merge
      expect(result).to include("Frozen Section")
      expect(result).to include("frozen and should not change")
    end
  end
end
