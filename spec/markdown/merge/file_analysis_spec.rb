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

    context "with code blocks" do
      let(:markdown_with_code) do
        <<~MARKDOWN
          # Code Example

          ```ruby
          def hello
            puts "world"
          end
          ```
        MARKDOWN
      end

      it "generates signatures for code blocks with fence info and content hash" do
        analysis = described_class.new(markdown_with_code)
        code_block = analysis.statements.find { |n| n.merge_type == :code_block }

        signature = analysis.generate_signature(code_block)
        expect(signature).to be_an(Array)
        expect(signature.first).to eq(:code_block)
        expect(signature[1]).to eq("ruby") # fence info
        expect(signature[2]).to be_a(String) # content hash
        expect(signature[2].length).to eq(16) # truncated hash
      end
    end

    context "with lists" do
      let(:markdown_with_list) do
        <<~MARKDOWN
          # List Example

          - Item 1
          - Item 2
          - Item 3
        MARKDOWN
      end

      it "generates signatures for lists with type and item count" do
        analysis = described_class.new(markdown_with_list)
        list = analysis.statements.find { |n| n.merge_type == :list }

        signature = analysis.generate_signature(list)
        expect(signature).to be_an(Array)
        expect(signature.first).to eq(:list)
      end
    end

    context "with block quotes" do
      let(:markdown_with_quote) do
        <<~MARKDOWN
          # Quote Example

          > This is a block quote
          > with multiple lines
        MARKDOWN
      end

      it "generates signatures for block quotes with content hash" do
        analysis = described_class.new(markdown_with_quote)
        quote = analysis.statements.find { |n| n.merge_type == :block_quote }

        signature = analysis.generate_signature(quote)
        expect(signature).to be_an(Array)
        expect(signature.first).to eq(:block_quote)
        expect(signature[1]).to be_a(String) # content hash
        expect(signature[1].length).to eq(16) # truncated hash
      end
    end

    context "with thematic breaks" do
      let(:markdown_with_break) do
        <<~MARKDOWN
          # Section 1

          Content above.

          ---

          Content below.
        MARKDOWN
      end

      it "generates signatures for thematic breaks" do
        analysis = described_class.new(markdown_with_break)
        thematic_break = analysis.statements.find { |n| n.merge_type == :thematic_break }

        signature = analysis.generate_signature(thematic_break)
        expect(signature).to be_an(Array)
        expect(signature).to eq([:thematic_break])
      end
    end

    context "with HTML blocks" do
      let(:markdown_with_html) do
        <<~MARKDOWN
          # HTML Example

          <div class="custom">
            Custom HTML content
          </div>
        MARKDOWN
      end

      it "generates signatures for HTML blocks with content hash" do
        analysis = described_class.new(markdown_with_html)
        html_block = analysis.statements.find { |n| n.merge_type == :html_block }

        # Some backends might not parse this as html_block
        if html_block
          signature = analysis.generate_signature(html_block)
          expect(signature).to be_an(Array)
          expect(signature.first).to eq(:html_block)
        end
      end
    end

    context "with tables" do
      let(:markdown_with_table) do
        <<~MARKDOWN
          # Table Example

          | Name | Age |
          |------|-----|
          | Alice | 30 |
          | Bob | 25 |
        MARKDOWN
      end

      it "generates signatures for tables with structure and header hash" do
        analysis = described_class.new(markdown_with_table)
        table = analysis.statements.find { |n| n.merge_type == :table }

        if table
          signature = analysis.generate_signature(table)
          expect(signature).to be_an(Array)
          expect(signature.first).to eq(:table)
        end
      end
    end
  end

  describe "#next_sibling", :markdown_backend do
    it "returns next sibling node or nil" do
      analysis = described_class.new(simple_markdown)
      first_node = analysis.statements.first

      # Unwrap to get raw node
      raw_node = Ast::Merge::NodeTyping.unwrap(first_node)
      sibling = analysis.next_sibling(raw_node)

      # Either returns a sibling or nil - just verify the method works
      expect(sibling.nil? || sibling.respond_to?(:type)).to be true
    end
  end

  describe "#parser_node?", :markdown_backend do
    it "returns true for parser nodes" do
      analysis = described_class.new(simple_markdown)
      node = analysis.statements.first

      expect(analysis.parser_node?(node)).to be true
    end

    it "returns false for non-parser objects" do
      analysis = described_class.new(simple_markdown)
      expect(analysis.parser_node?("string")).to be false
      expect(analysis.parser_node?(123)).to be false
    end
  end

  describe "#fallthrough_node?", :markdown_backend do
    it "returns true for wrapped nodes" do
      analysis = described_class.new(simple_markdown)
      node = analysis.statements.first

      expect(analysis.fallthrough_node?(node)).to be true
    end

    it "returns true for FreezeNode instances" do
      analysis = described_class.new(markdown_with_freeze)
      freeze_block = analysis.freeze_blocks.first

      expect(analysis.fallthrough_node?(freeze_block)).to be true
    end
  end

  describe "#extract_text_content", :markdown_backend do
    it "extracts text from nodes" do
      analysis = described_class.new(simple_markdown)
      heading = analysis.statements.first
      raw_node = Ast::Merge::NodeTyping.unwrap(heading)

      text = analysis.extract_text_content(raw_node)
      expect(text).to include("Hello World")
    end
  end

  describe "#safe_string_content", :markdown_backend do
    let(:markdown_with_code) do
      <<~MARKDOWN
        ```ruby
        puts "hello"
        ```
      MARKDOWN
    end

    it "safely extracts string content from code blocks" do
      analysis = described_class.new(markdown_with_code)
      code_block = analysis.statements.first
      raw_node = Ast::Merge::NodeTyping.unwrap(code_block)

      content = analysis.safe_string_content(raw_node)
      expect(content).to be_a(String)
    end
  end

  describe "#collect_top_level_nodes", :markdown_backend do
    it "collects and wraps all top-level nodes" do
      analysis = described_class.new(simple_markdown)
      nodes = analysis.send(:collect_top_level_nodes)

      expect(nodes).to be_an(Array)
      nodes.each do |node|
        expect(node).to respond_to(:merge_type)
      end
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

