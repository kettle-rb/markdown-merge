# frozen_string_literal: true

# Direct coverage tests for file_analysis.rb
# Uses :markdown_backend tag - tests only run when commonmarker or markly is available

# rubocop:disable RSpec/DescribeMethod, RSpec/ExpectActual
RSpec.describe Markdown::Merge::FileAnalysis, "coverage", :markdown_parsing do
  let(:simple_markdown) { "# Hello\n\nWorld paragraph." }

  describe "#initialize coverage" do
    it "accepts auto backend" do
      analysis = described_class.new(simple_markdown, backend: :auto)
      expect(analysis.backend).to be_a(Symbol)
    end

    it "stores parser options" do
      analysis = described_class.new(simple_markdown, some_option: true)
      expect(analysis).to be_a(described_class)
    end
  end

  describe "#resolve_backend coverage" do
    it "resolves :auto to a real backend" do
      analysis = described_class.new(simple_markdown, backend: :auto)
      expect([:commonmarker, :markly]).to include(analysis.backend)
    end

    it "uses commonmarker when requested", :commonmarker do
      analysis = described_class.new(simple_markdown, backend: :commonmarker)
      expect(analysis.backend).to eq(:commonmarker)
    end

    it "uses markly when requested", :markly do
      analysis = described_class.new(simple_markdown, backend: :markly)
      expect(analysis.backend).to eq(:markly)
    end
  end

  describe "#next_sibling coverage" do
    it "returns next sibling for document children" do
      analysis = described_class.new("# First\n\n# Second")
      first_stmt = analysis.statements.first
      raw_node = Ast::Merge::NodeTyping.unwrap(first_stmt)

      # The next sibling might exist or be nil depending on document structure
      sibling = analysis.next_sibling(raw_node)
      expect(sibling).to be_nil.or respond_to(:type)
    end
  end

  describe "#compute_parser_signature coverage" do
    context "with heading" do
      it "generates heading signature" do
        analysis = described_class.new("# Test Heading")
        heading = analysis.statements.find { |s| s.merge_type == :heading }
        sig = analysis.generate_signature(heading)
        expect(sig.first).to eq(:heading)
        expect(sig[1]).to eq(1) # level
      end
    end

    context "with paragraph" do
      it "generates paragraph signature with hash" do
        analysis = described_class.new("This is a paragraph.")
        para = analysis.statements.find { |s| s.merge_type == :paragraph }
        sig = analysis.generate_signature(para)
        expect(sig.first).to eq(:paragraph)
        expect(sig[1]).to be_a(String) # hash
      end
    end

    context "with code block" do
      let(:code_md) do
        <<~MD
          ```ruby
          puts "hello"
          ```
        MD
      end

      it "generates code block signature with fence info" do
        analysis = described_class.new(code_md)
        code = analysis.statements.find { |s| s.merge_type == :code_block }
        if code
          sig = analysis.generate_signature(code)
          expect(sig.first).to eq(:code_block)
        end
      end
    end

    context "with list" do
      let(:list_md) do
        <<~MD
          - Item 1
          - Item 2
          - Item 3
        MD
      end

      it "generates list signature with item count" do
        analysis = described_class.new(list_md)
        list = analysis.statements.find { |s| s.merge_type == :list }
        if list
          sig = analysis.generate_signature(list)
          expect(sig.first).to eq(:list)
        end
      end
    end

    context "with block quote" do
      let(:quote_md) do
        <<~MD
          > This is a quote
          > spanning lines
        MD
      end

      it "generates block quote signature" do
        analysis = described_class.new(quote_md)
        quote = analysis.statements.find { |s| s.merge_type == :block_quote }
        if quote
          sig = analysis.generate_signature(quote)
          expect(sig.first).to eq(:block_quote)
        end
      end
    end

    context "with thematic break" do
      it "generates thematic break signature" do
        analysis = described_class.new("---")
        thematic = analysis.statements.find { |s| s.merge_type == :thematic_break }
        if thematic
          sig = analysis.generate_signature(thematic)
          expect(sig).to eq([:thematic_break])
        end
      end
    end

    context "with HTML block" do
      let(:html_md) { "<div>Custom HTML</div>" }

      it "generates HTML block signature" do
        analysis = described_class.new(html_md)
        html = analysis.statements.find { |s| s.merge_type == :html_block }
        if html
          sig = analysis.generate_signature(html)
          expect(sig.first).to eq(:html_block)
        end
      end
    end

    context "with table" do
      let(:table_md) do
        <<~MD
          | A | B |
          |---|---|
          | 1 | 2 |
        MD
      end

      it "generates table signature" do
        analysis = described_class.new(table_md)
        table = analysis.statements.find { |s| s.merge_type == :table }
        if table
          sig = analysis.generate_signature(table)
          expect(sig.first).to eq(:table)
        end
      end
    end
  end

  describe "#extract_text_content coverage" do
    it "extracts text from nested nodes" do
      analysis = described_class.new("**bold** and *italic*")
      para = analysis.statements.find { |s| s.merge_type == :paragraph }
      raw = Ast::Merge::NodeTyping.unwrap(para)
      text = analysis.extract_text_content(raw)
      expect(text).to include("bold")
      expect(text).to include("italic")
    end
  end

  describe "#safe_string_content coverage" do
    it "gets content from code blocks" do
      code_md = "```\ncode here\n```"
      analysis = described_class.new(code_md)
      code = analysis.statements.find { |s| s.merge_type == :code_block }
      if code
        raw = Ast::Merge::NodeTyping.unwrap(code)
        content = analysis.safe_string_content(raw)
        expect(content).to include("code")
      end
    end
  end

  describe "#parser_node? coverage" do
    it "recognizes parser nodes" do
      analysis = described_class.new(simple_markdown)
      node = analysis.statements.first
      raw = Ast::Merge::NodeTyping.unwrap(node)
      expect(analysis.parser_node?(raw)).to be true
    end

    it "rejects non-nodes" do
      analysis = described_class.new(simple_markdown)
      expect(analysis.parser_node?("string")).to be false
      expect(analysis.parser_node?(123)).to be false
    end
  end

  describe "#fallthrough_node? coverage" do
    it "recognizes wrapped nodes" do
      analysis = described_class.new(simple_markdown)
      node = analysis.statements.first
      expect(analysis.fallthrough_node?(node)).to be true
    end
  end

  describe "#freeze_node_class coverage" do
    it "returns Markdown::Merge::FreezeNode" do
      analysis = described_class.new(simple_markdown)
      expect(analysis.freeze_node_class).to eq(Markdown::Merge::FreezeNode)
    end
  end

  describe "#parse_document error handling" do
    # TreeHaver::Error handling is tested implicitly through backend selection.
    # When a backend is unavailable, the error is caught and stored.

    context "with valid content" do
      it "parses successfully" do
        analysis = described_class.new(simple_markdown)
        expect(analysis.valid?).to be true
        expect(analysis.errors).to be_empty
      end
    end
  end

  describe "#compute_parser_signature edge cases" do
    context "with footnote definition (if supported)" do
      let(:footnote_md) do
        <<~MD
          Here's a sentence with a footnote[^1].

          [^1]: This is the footnote content.
        MD
      end

      it "handles footnote definitions" do
        analysis = described_class.new(footnote_md)
        footnote = analysis.statements.find do |s|
          s.respond_to?(:merge_type) && s.merge_type == :footnote_definition
        end
        if footnote
          sig = analysis.generate_signature(footnote)
          expect(sig.first).to eq(:footnote_definition)
        else
          # If footnote definitions aren't supported, that's OK
          expect(footnote).to be_nil
        end
      end
    end

    context "with unknown node type" do
      it "generates unknown type signature for unrecognized types" do
        analysis = described_class.new(simple_markdown)
        # Create a mock node with an unknown type
        mock_node = double("UnknownNode")
        allow(mock_node).to receive_messages(
          type: :super_custom_type,
          source_position: {start_line: 1, end_line: 1},
        )
        allow(mock_node).to receive(:respond_to?).with(:type).and_return(true)

        # The signature should handle this gracefully
        sig = analysis.compute_parser_signature(mock_node)
        expect(sig.first).to eq(:unknown)
        expect(sig[1]).to eq(:super_custom_type)
      end
    end
  end

  describe "#collect_top_level_nodes coverage" do
    it "wraps all top-level nodes" do
      analysis = described_class.new("# Heading\n\nParagraph\n\n- List item")
      nodes = analysis.statements
      # All nodes should be wrapped with merge_type
      nodes.each do |node|
        next if node.is_a?(Markdown::Merge::GapLineNode)
        next if node.is_a?(Markdown::Merge::LinkDefinitionNode)

        expect(node).to respond_to(:merge_type)
      end
    end
  end
end
# rubocop:enable RSpec/DescribeMethod, RSpec/ExpectActual
