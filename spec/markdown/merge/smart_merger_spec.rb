# frozen_string_literal: true

RSpec.describe Markdown::Merge::SmartMerger do
  let(:template_content) do
    <<~MARKDOWN
      # Project Title

      ## Description

      This is a template description.

      ## Installation

      ```bash
      npm install example
      ```

      ## Usage

      Use this library like so.
    MARKDOWN
  end

  let(:dest_content) do
    <<~MARKDOWN
      # Project Title

      ## Description

      This is my custom description that I wrote.

      ## Installation

      ```bash
      npm install example
      ```

      ## Custom Section

      This section only exists in destination.
    MARKDOWN
  end

  let(:content_with_freeze) do
    <<~MARKDOWN
      # Title

      <!-- markdown-merge:freeze -->
      ## Frozen Section
      Do not modify this content.
      <!-- markdown-merge:unfreeze -->

      ## Regular Section
    MARKDOWN
  end

  describe "#initialize", :markdown_parsing do
    it "creates merger with auto backend" do
      merger = described_class.new(template_content, dest_content)
      expect(merger).to be_a(described_class)
    end

    it "resolves the backend" do
      merger = described_class.new(template_content, dest_content)
      expect(merger.backend).to eq(:commonmarker).or eq(:markly)
    end

    it "accepts explicit backend option", :commonmarker do
      merger = described_class.new(template_content, dest_content, backend: :commonmarker)
      expect(merger.backend).to eq(:commonmarker)
    end

    it "raises for invalid backend" do
      expect {
        described_class.new(template_content, dest_content, backend: :invalid)
      }.to raise_error(ArgumentError, /Unknown backend/)
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
      merger = described_class.new(template_content, dest_content, freeze_token: "custom-token")
      expect(merger).to be_a(described_class)
    end
  end

  describe "#merge", :markdown_parsing do
    it "returns merged content as string" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge

      expect(result).to be_a(String)
    end

    it "preserves destination content by default" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge

      expect(result).to include("my custom description")
    end

    it "preserves destination-only sections" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge

      expect(result).to include("Custom Section")
    end
  end

  describe "#merge_result", :markdown_parsing do
    it "returns MergeResult object" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge_result

      expect(result).to be_a(Markdown::Merge::MergeResult)
    end

    it "includes content in result" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge_result

      expect(result.content).to be_a(String)
    end

    it "includes stats in result" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge_result

      expect(result.stats).to be_a(Hash)
    end
  end

  describe "preference: :template", :markdown_parsing do
    # Preference determines which source to use when nodes MATCH.
    # - preference: :destination (default) - use destination's version of matched nodes
    # - preference: :template - use template's version of matched nodes
    #
    # For exact signature matches, content is identical so preference is moot.
    # Preference becomes meaningful when:
    # 1. A match_refiner allows fuzzy matching (e.g., TableMatchRefiner)
    # 2. Source formatting differs but signatures match

    context "with exact signature matches" do
      it "preserves destination content by default" do
        merger = described_class.new(template_content, dest_content, preference: :destination)
        result = merger.merge

        # Matched nodes use destination version, destination-only nodes preserved
        expect(result).to include("my custom description")
        expect(result).to include("Custom Section")
      end

      it "preserves matched heading structure with :template preference" do
        merger = described_class.new(template_content, dest_content, preference: :template)
        result = merger.merge

        # Headings match exactly, so "## Description" appears in result
        expect(result).to include("## Description")
      end
    end

    context "with fuzzy table matching via match_refiner" do
      let(:template_with_table) do
        <<~MARKDOWN
          # Data

          | Name | Value |
          |------|-------|
          | foo  | 100   |
          | bar  | 200   |
        MARKDOWN
      end

      let(:dest_with_similar_table) do
        <<~MARKDOWN
          # Data

          | Name | Value |
          |------|-------|
          | foo  | 150   |
          | baz  | 300   |
        MARKDOWN
      end

      it "uses destination table content with :destination preference" do
        refiner = Markdown::Merge::TableMatchRefiner.new(threshold: 0.3)
        merger = described_class.new(
          template_with_table,
          dest_with_similar_table,
          preference: :destination,
          match_refiner: refiner,
        )
        result = merger.merge

        # Tables fuzzy-match, preference: :destination uses destination's values
        expect(result).to include("150")
        expect(result).to include("baz")
      end

      it "uses template table content with :template preference" do
        refiner = Markdown::Merge::TableMatchRefiner.new(threshold: 0.3)
        merger = described_class.new(
          template_with_table,
          dest_with_similar_table,
          preference: :template,
          match_refiner: refiner,
        )
        result = merger.merge

        # Tables fuzzy-match, preference: :template uses template's values
        expect(result).to include("100")
        expect(result).to include("bar")
      end
    end

    context "with Hash preference for per-node-type control" do
      let(:template_with_mixed) do
        <<~MARKDOWN
          # Title

          Template paragraph.

          | Col1 | Col2 |
          |------|------|
          | T1   | T2   |
        MARKDOWN
      end

      let(:dest_with_mixed) do
        <<~MARKDOWN
          # Title

          Destination paragraph.

          | Col1 | Col2 |
          |------|------|
          | D1   | D2   |
        MARKDOWN
      end

      it "applies different preferences to different node types" do
        refiner = Markdown::Merge::TableMatchRefiner.new(threshold: 0.3)
        merger = described_class.new(
          template_with_mixed,
          dest_with_mixed,
          preference: {default: :destination, table: :template},
          match_refiner: refiner,
        )
        result = merger.merge

        # Headings use :destination (default), tables use :template
        # Heading "# Title" matches exactly - either source gives same result
        expect(result).to include("# Title")
        # Table should use template values with :template preference for tables
        expect(result).to include("T1")
      end
    end

    context "with ContentMatchRefiner for fuzzy paragraph matching" do
      let(:template_with_paragraph) do
        <<~MARKDOWN
          # Title

          This is a paragraph about the project description.
        MARKDOWN
      end

      let(:dest_with_similar_paragraph) do
        <<~MARKDOWN
          # Title

          This is a paragraph about the project desciption.
        MARKDOWN
      end

      it "matches paragraphs with minor differences using ContentMatchRefiner" do
        # Note: "description" vs "desciption" (typo)
        refiner = Ast::Merge::ContentMatchRefiner.new(
          threshold: 0.8,
          node_types: [:paragraph],
        )
        merger = described_class.new(
          template_with_paragraph,
          dest_with_similar_paragraph,
          preference: :template,
          match_refiner: refiner,
        )
        result = merger.merge

        # With :template preference, the template's correct spelling should be used
        expect(result).to include("description")
      end

      it "uses destination content with :destination preference" do
        refiner = Ast::Merge::ContentMatchRefiner.new(
          threshold: 0.8,
          node_types: [:paragraph],
        )
        merger = described_class.new(
          template_with_paragraph,
          dest_with_similar_paragraph,
          preference: :destination,
          match_refiner: refiner,
        )
        result = merger.merge

        # With :destination preference, the typo is preserved
        expect(result).to include("desciption")
      end
    end
  end

  describe "add_template_only_nodes: true", :markdown_parsing do
    it "adds nodes that only exist in template" do
      merger = described_class.new(template_content, dest_content, add_template_only_nodes: true)
      result = merger.merge

      expect(result).to include("Usage")
    end
  end

  describe "freeze blocks", :markdown_parsing do
    let(:template_with_changed_freeze) do
      <<~MARKDOWN
        # Title

        <!-- markdown-merge:freeze -->
        ## Frozen Section
        Modified template content that should be ignored.
        <!-- markdown-merge:unfreeze -->

        ## Regular Section
      MARKDOWN
    end

    it "preserves destination freeze block content" do
      merger = described_class.new(template_with_changed_freeze, content_with_freeze)
      result = merger.merge

      expect(result).to include("Do not modify this content")
      expect(result).not_to include("Modified template content")
    end
  end

  describe "#node_to_source", :markdown_parsing do
    it "extracts source text from nodes" do
      merger = described_class.new(template_content, dest_content)
      analysis = merger.template_analysis
      node = analysis.statements.first

      source = merger.send(:node_to_source, node, analysis)
      expect(source).to be_a(String)
      expect(source).not_to be_empty
    end

    it "handles FreezeNode instances" do
      merger = described_class.new(template_content, content_with_freeze)
      analysis = merger.dest_analysis
      freeze_node = analysis.freeze_blocks.first

      if freeze_node
        source = merger.send(:node_to_source, freeze_node, analysis)
        expect(source).to be_a(String)
        expect(source).to include("markdown-merge:freeze")
      end
    end

    it "handles LinkDefinitionNode" do
      merger = described_class.new(template_content, dest_content)
      analysis = merger.template_analysis

      link_node = Markdown::Merge::LinkDefinitionNode.new(
        "[ref]: https://example.com",
        line_number: 1,
        label: "ref",
        url: "https://example.com",
      )

      source = merger.send(:node_to_source, link_node, analysis)
      expect(source).to eq("[ref]: https://example.com")
    end

    it "handles GapLineNode" do
      merger = described_class.new(template_content, dest_content)
      analysis = merger.template_analysis

      gap_node = Markdown::Merge::GapLineNode.new("", line_number: 5)

      source = merger.send(:node_to_source, gap_node, analysis)
      expect(source).to eq("")
    end

    it "handles GapLineNode with content" do
      merger = described_class.new(template_content, dest_content)
      analysis = merger.template_analysis

      gap_node = Markdown::Merge::GapLineNode.new("some gap content", line_number: 5)

      source = merger.send(:node_to_source, gap_node, analysis)
      expect(source).to eq("some gap content")
    end
  end

  describe "#template_parse_error_class", :markdown_parsing do
    it "creates FileAnalysis with provided options" do
      merger = described_class.new(template_content, dest_content)

      analysis = merger.send(
        :create_file_analysis,
        template_content,
        freeze_token: "custom-token",
        signature_generator: nil,
      )

      expect(analysis).to be_a(Markdown::Merge::FileAnalysis)
    end

    it "uses requested backend" do
      merger = described_class.new(template_content, dest_content)

      analysis = merger.send(
        :create_file_analysis,
        template_content,
        backend: merger.backend,
        freeze_token: "markdown-merge",
        signature_generator: nil,
      )

      expect(analysis.backend).to eq(merger.backend)
    end
  end

  describe "#node_to_source edge cases", :markdown_parsing do
    it "falls back to to_commonmark when source_position is nil" do
      merger = described_class.new(template_content, dest_content)
      analysis = merger.template_analysis

      mock_node = double("Node")
      allow(mock_node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
      allow(mock_node).to receive(:is_a?).with(Markdown::Merge::LinkDefinitionNode).and_return(false)
      allow(mock_node).to receive(:is_a?).with(Markdown::Merge::GapLineNode).and_return(false)
      allow(mock_node).to receive_messages(source_position: nil, to_commonmark: "fallback content\n")
      allow(Ast::Merge::NodeTyping).to receive(:unwrap).with(mock_node).and_return(mock_node)

      source = merger.send(:node_to_source, mock_node, analysis)
      expect(source).to eq("fallback content\n")
    end

    it "falls back to to_commonmark when source_range is empty" do
      merger = described_class.new(template_content, dest_content)
      analysis = merger.template_analysis

      mock_node = double("Node")
      allow(mock_node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
      allow(mock_node).to receive(:is_a?).with(Markdown::Merge::LinkDefinitionNode).and_return(false)
      allow(mock_node).to receive(:is_a?).with(Markdown::Merge::GapLineNode).and_return(false)
      # Simulate Markly bug where end_line < start_line
      allow(mock_node).to receive_messages(
        source_position: {start_line: 5, end_line: 3},
        to_commonmark: "recovered content\n",
      )
      allow(mock_node).to receive(:respond_to?).with(:to_commonmark).and_return(true)
      allow(Ast::Merge::NodeTyping).to receive(:unwrap).with(mock_node).and_return(mock_node)

      source = merger.send(:node_to_source, mock_node, analysis)
      expect(source).to eq("recovered content")
    end

    it "returns empty string when source_range empty and to_commonmark not available" do
      merger = described_class.new(template_content, dest_content)
      analysis = merger.template_analysis

      mock_node = double("Node")
      allow(mock_node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
      allow(mock_node).to receive(:is_a?).with(Markdown::Merge::LinkDefinitionNode).and_return(false)
      allow(mock_node).to receive(:is_a?).with(Markdown::Merge::GapLineNode).and_return(false)
      allow(mock_node).to receive(:source_position).and_return({start_line: 5, end_line: 3})
      allow(mock_node).to receive(:respond_to?).with(:to_commonmark).and_return(false)
      allow(Ast::Merge::NodeTyping).to receive(:unwrap).with(mock_node).and_return(mock_node)

      source = merger.send(:node_to_source, mock_node, analysis)
      expect(source).to eq("")
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

  describe "initialization with all options", :markdown_parsing do
    it "accepts all configuration options" do
      custom_sig = ->(node) { [:custom, node.object_id] }

      merger = described_class.new(
        template_content,
        dest_content,
        signature_generator: custom_sig,
        preference: :template,
        add_template_only_nodes: true,
        inner_merge_code_blocks: true,
        freeze_token: "custom-freeze",
        match_refiner: nil,
        node_typing: nil,
      )

      expect(merger).to be_a(described_class)
      expect(merger.backend).to be_a(Symbol)
    end

    it "passes parser_options to FileAnalysis" do
      merger = described_class.new(
        template_content,
        dest_content,
        options: {strikethrough: true},
      )

      expect(merger.template_analysis).to be_a(Markdown::Merge::FileAnalysis)
    end
  end

  describe "merge with various node types", :markdown_parsing do
    let(:complex_template) do
      <<~MARKDOWN
        # Title

        Intro paragraph.

        ## Section A

        > A block quote

        - List item 1
        - List item 2

        ```ruby
        puts "hello"
        ```

        ---

        ## Section B

        Final paragraph.
      MARKDOWN
    end

    let(:complex_dest) do
      <<~MARKDOWN
        # Title

        Custom intro paragraph.

        ## Section A

        > Modified block quote

        - List item 1
        - List item 2
        - List item 3

        ```ruby
        puts "hello world"
        ```

        ---

        ## Custom Section

        New content.
      MARKDOWN
    end

    it "handles all node types during merge" do
      merger = described_class.new(complex_template, complex_dest)
      result = merger.merge

      expect(result).to be_a(String)
      expect(result).to include("# Title")
      expect(result).to include("Custom intro")
    end

    it "returns a MergeResult with stats" do
      merger = described_class.new(complex_template, complex_dest)
      result = merger.merge_result

      expect(result).to be_a(Markdown::Merge::MergeResult)
      expect(result.stats).to be_a(Hash)
      expect(result.content).to be_a(String)
    end

    it "preserves destination-only sections" do
      merger = described_class.new(complex_template, complex_dest)
      result = merger.merge
      expect(result).to include("Custom Section")
    end
  end

  describe "additional complex merge scenarios", :markdown_parsing do
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

    it "handles complex documents with different structures" do
      merger = described_class.new(complex_template, complex_dest)
      result = merger.merge
      expect(result).to be_a(String)
      expect(result).to include("# Project")
    end

    it "preserves destination-only sections in complex merges" do
      merger = described_class.new(complex_template, complex_dest)
      result = merger.merge
      expect(result).to include("Custom Section")
    end
  end

  describe "backend consistency", :commonmarker_merge, :markly_merge do
    it "produces similar results across backends" do
      cm_merger = described_class.new(template_content, dest_content, backend: :commonmarker)
      markly_merger = described_class.new(template_content, dest_content, backend: :markly)

      cm_result = cm_merger.merge
      markly_result = markly_merger.merge

      # Both should preserve destination description
      expect(cm_result).to include("my custom description")
      expect(markly_result).to include("my custom description")

      # Both should preserve destination-only section
      expect(cm_result).to include("Custom Section")
      expect(markly_result).to include("Custom Section")
    end
  end
end
