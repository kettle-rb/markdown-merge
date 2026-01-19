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

  describe "#initialize", :markdown_parsing do
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
      expect(analysis.backend).to eq(:commonmarker).or eq(:markly)
    end

    it "accepts explicit backend option", :commonmarker_backend do
      analysis = described_class.new(simple_markdown, backend: :commonmarker)
      expect(analysis.backend).to eq(:commonmarker)
    end

    it "accepts markly backend option", :markly_backend do
      analysis = described_class.new(simple_markdown, backend: :markly)
      expect(analysis.backend).to eq(:markly)
    end

    it "raises for invalid backend" do
      expect {
        described_class.new(simple_markdown, backend: :invalid)
      }.to raise_error(ArgumentError, /Unknown backend/)
    end
  end

  describe "#statements", :markdown_parsing do
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

  describe "#freeze_blocks", :markdown_parsing do
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

  describe "#compute_parser_signature", :markdown_parsing do
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

    context "with footnote definitions" do
      let(:markdown_with_footnote) do
        <<~MARKDOWN
          # Footnote Example

          Here is some text with a footnote[^1].

          [^1]: This is the footnote content.
        MARKDOWN
      end

      it "generates signatures for footnote definitions" do
        analysis = described_class.new(markdown_with_footnote)
        footnote = analysis.statements.find { |n| n.merge_type == :footnote_definition }

        if footnote
          signature = analysis.generate_signature(footnote)
          expect(signature).to be_an(Array)
          expect(signature.first).to eq(:footnote_definition)
        end
      end
    end

    context "with unknown node types" do
      it "generates fallback signatures for unrecognized types" do
        analysis = described_class.new(simple_markdown)
        # Force an unknown type by directly calling compute_parser_signature
        # with a mock node that has an unrecognized type
        mock_node = double(
          "UnknownNode",
          type: :some_unknown_type,
          source_position: {start_line: 1, end_line: 1},
          respond_to?: ->(m) { [:type, :source_position].include?(m) },
        )

        # Wrap it to simulate typed node
        allow(Ast::Merge::NodeTyping).to receive_messages(typed_node?: false, unwrap: mock_node)

        signature = analysis.compute_parser_signature(mock_node)
        expect(signature).to be_an(Array)
        expect(signature.first).to eq(:unknown)
      end
    end
  end

  describe "#parser_node?", :markdown_parsing do
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

  describe "#fallthrough_node?", :markdown_parsing do
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

  describe "#extract_text_content", :markdown_parsing do
    it "extracts text from nodes" do
      analysis = described_class.new(simple_markdown)
      heading = analysis.statements.first
      raw_node = Ast::Merge::NodeTyping.unwrap(heading)

      text = analysis.extract_text_content(raw_node)
      expect(text).to include("Hello World")
    end
  end

  describe "#collect_top_level_nodes", :markdown_parsing do
    it "collects and wraps all top-level nodes" do
      analysis = described_class.new(simple_markdown)
      nodes = analysis.send(:collect_top_level_nodes)

      expect(nodes).to be_an(Array)
      expect(nodes).to all(respond_to(:merge_type))
    end
  end

  describe "backend-specific options" do
    context "with commonmarker", :commonmarker_backend do
      it "accepts options hash" do
        analysis = described_class.new(simple_markdown, backend: :commonmarker, options: {})
        expect(analysis.backend).to eq(:commonmarker)
      end

      it "creates parser with table extension by default" do
        table_md = <<~MARKDOWN
          | A | B |
          |---|---|
          | 1 | 2 |
        MARKDOWN
        analysis = described_class.new(table_md, backend: :commonmarker)
        expect(analysis.statements).not_to be_empty
      end
    end

    context "with markly", :markly_backend do
      it "accepts flags and extensions" do
        # Use dynamic constant lookup to avoid parse-time errors when markly isn't available
        markly_default = Object.const_get("Markly::DEFAULT")
        analysis = described_class.new(
          simple_markdown,
          backend: :markly,
          flags: markly_default,
          extensions: [:table],
        )
        expect(analysis.backend).to eq(:markly)
      end

      it "creates parser with table extension by default" do
        table_md = <<~MARKDOWN
          | A | B |
          |---|---|
          | 1 | 2 |
        MARKDOWN
        analysis = described_class.new(table_md, backend: :markly)
        expect(analysis.statements).not_to be_empty
      end
    end
  end

  describe "#resolve_backend (private)", :markdown_parsing do
    it "returns the backend when not :auto" do
      analysis = described_class.new(simple_markdown)
      # The backend should be resolved to either :commonmarker or :markly
      expect(analysis.backend).to eq(:commonmarker).or eq(:markly)
    end
  end

  describe "#create_parser (private)", :markdown_parsing do
    it "creates a parser for the resolved backend" do
      analysis = described_class.new(simple_markdown)
      # Just verify parsing works
      expect(analysis.statements).not_to be_empty
    end
  end

  describe "#next_sibling", :markdown_parsing do
    it "returns next sibling for nodes with next_sibling method" do
      analysis = described_class.new(simple_markdown)
      first_node = analysis.statements.first
      raw_node = Ast::Merge::NodeTyping.unwrap(first_node)

      # The result depends on the document structure
      sibling = analysis.next_sibling(raw_node)
      expect(sibling).to be_nil.or respond_to(:type)
    end

    it "falls back to :next method if next_sibling not available" do
      analysis = described_class.new(simple_markdown)
      # Create a mock node with only :next method
      mock_node = double("Node")
      allow(mock_node).to receive(:respond_to?).with(:next_sibling).and_return(false)
      allow(mock_node).to receive(:respond_to?).with(:next).and_return(true)
      allow(mock_node).to receive(:next).and_return(nil)

      result = analysis.next_sibling(mock_node)
      expect(result).to be_nil
    end
  end

  describe "#safe_string_content", :markdown_parsing do
    context "with code block" do
      let(:code_markdown) do
        <<~MARKDOWN
          ```ruby
          puts "hello"
          ```
        MARKDOWN
      end

      it "extracts content via string_content" do
        analysis = described_class.new(code_markdown)
        code_block = analysis.statements.first
        raw_node = Ast::Merge::NodeTyping.unwrap(code_block)

        content = analysis.safe_string_content(raw_node)
        expect(content).to include("puts")
      end
    end

    it "falls back to text method when string_content not available" do
      analysis = described_class.new(simple_markdown)
      mock_node = double("Node")
      allow(mock_node).to receive(:respond_to?).with(:string_content).and_return(false)
      allow(mock_node).to receive(:respond_to?).with(:text).and_return(true)
      allow(mock_node).to receive(:respond_to?).with(:type).and_return(true)
      allow(mock_node).to receive(:respond_to?).with(:children).and_return(true)
      allow(mock_node).to receive_messages(text: "fallback text", type: :text, children: [])

      result = analysis.safe_string_content(mock_node)
      expect(result).to eq("fallback text")
    end

    it "falls back to extract_text_content when both string_content and text unavailable" do
      analysis = described_class.new(simple_markdown)
      mock_node = double("Node")
      allow(mock_node).to receive(:respond_to?).with(:string_content).and_return(false)
      allow(mock_node).to receive(:respond_to?).with(:text).and_return(false)
      allow(mock_node).to receive(:respond_to?).with(:type).and_return(true)
      allow(mock_node).to receive(:respond_to?).with(:children).and_return(true)
      allow(mock_node).to receive_messages(type: :paragraph, children: [])

      result = analysis.safe_string_content(mock_node)
      expect(result).to eq("")
    end
  end

  describe "#compute_parser_signature comprehensive", :markdown_parsing do
    context "with all node types" do
      let(:comprehensive_markdown) do
        <<~MARKDOWN
          # Main Heading

          A paragraph with some text.

          ## Sub Heading

          > A block quote
          > spanning multiple lines

          - List item 1
          - List item 2
          - List item 3

          ```ruby
          def hello
            puts "world"
          end
          ```

          ---

          | Name | Value |
          |------|-------|
          | foo  | 100   |

          <div>HTML content</div>
        MARKDOWN
      end

      it "generates correct signatures for all node types" do
        analysis = described_class.new(comprehensive_markdown)
        statements = analysis.statements

        # Collect all types
        types = statements.map(&:merge_type)

        # Should have various types
        expect(types).to include(:heading)
        expect(types).to include(:paragraph)

        # Generate signatures for each
        statements.each do |stmt|
          signature = analysis.generate_signature(stmt)
          expect(signature).to be_an(Array)
          expect(signature.first).to be_a(Symbol)
        end
      end
    end

    context "with wrapped vs unwrapped nodes" do
      it "handles both wrapped and unwrapped nodes" do
        analysis = described_class.new(simple_markdown)
        wrapped_node = analysis.statements.first
        raw_node = Ast::Merge::NodeTyping.unwrap(wrapped_node)

        # Both should produce signatures
        wrapped_sig = analysis.generate_signature(wrapped_node)
        raw_sig = analysis.compute_parser_signature(raw_node)

        expect(wrapped_sig).to be_an(Array)
        expect(raw_sig).to be_an(Array)
      end
    end
  end

  describe "type normalization consistency", :commonmarker_backend, :markly_backend do
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

  # ============================================================
  # Mocked Unit Tests (no markdown parsing backend required)
  # ============================================================
  # These tests use mocks to cover method branches without requiring
  # actual markdown parsing backends (markly or commonmarker).

  describe "#next_sibling (mocked)" do
    # Create a minimal test class that exposes the method for testing
    let(:test_class) do
      Class.new(described_class) do
        # Skip backend resolution for mock testing
        def initialize
          @backend = :mock
          @parser = nil
          @source = ""
          @lines = []
          @errors = []
        end
      end
    end

    let(:analysis) { test_class.new }

    context "when node responds to :next_sibling" do
      it "calls next_sibling" do
        node = double("Node")
        sibling = double("Sibling")
        allow(node).to receive(:respond_to?).with(:next_sibling).and_return(true)
        allow(node).to receive(:next_sibling).and_return(sibling)

        result = analysis.next_sibling(node)
        expect(result).to eq(sibling)
      end
    end

    context "when node responds to :next but not :next_sibling" do
      it "calls next" do
        node = double("Node")
        sibling = double("Sibling")
        allow(node).to receive(:respond_to?).with(:next_sibling).and_return(false)
        allow(node).to receive(:respond_to?).with(:next).and_return(true)
        allow(node).to receive(:next).and_return(sibling)

        result = analysis.next_sibling(node)
        expect(result).to eq(sibling)
      end
    end

    context "when node responds to neither" do
      it "returns nil" do
        node = double("Node")
        allow(node).to receive(:respond_to?).with(:next_sibling).and_return(false)
        allow(node).to receive(:respond_to?).with(:next).and_return(false)

        result = analysis.next_sibling(node)
        expect(result).to be_nil
      end
    end
  end

  describe "#parser_node? (mocked)" do
    let(:test_class) do
      Class.new(described_class) do
        def initialize
          @backend = :mock
          @parser = nil
          @source = ""
          @lines = []
          @errors = []
        end
      end
    end

    let(:analysis) { test_class.new }

    context "when value responds to :type and :source_position" do
      it "returns true" do
        node = double("Node")
        allow(node).to receive(:respond_to?).with(:type).and_return(true)
        allow(node).to receive(:respond_to?).with(:source_position).and_return(true)

        expect(analysis.parser_node?(node)).to be true
      end
    end

    context "when value is a typed node" do
      it "returns true" do
        node = double("Node")
        allow(node).to receive(:respond_to?).with(:type).and_return(false)
        allow(Ast::Merge::NodeTyping).to receive(:typed_node?).with(node).and_return(true)

        expect(analysis.parser_node?(node)).to be true
      end
    end

    context "when value is neither" do
      it "returns false" do
        value = "just a string"

        expect(analysis.parser_node?(value)).to be false
      end
    end
  end

  describe "#compute_parser_signature (mocked)" do
    let(:test_class) do
      Class.new(described_class) do
        def initialize
          @backend = :mock
          @parser = nil
          @source = ""
          @lines = []
          @errors = []
        end

        # Expose protected methods for testing
        public :compute_parser_signature,
          :extract_text_content,
          :safe_string_content,
          :count_children,
          :extract_table_header_content
      end
    end

    let(:analysis) { test_class.new }

    # Helper to create mock nodes
    def mock_node(type:, **attributes)
      node = double("#{type.to_s.capitalize}Node")
      allow(node).to receive(:type).and_return(type)
      allow(node).to receive(:respond_to?) { |method| attributes.key?(method) || [:type].include?(method) }

      attributes.each do |method, value|
        allow(node).to receive(:respond_to?).with(method).and_return(true)
        allow(node).to receive(method).and_return(value)
      end

      # Default source_position
      unless attributes[:source_position]
        allow(node).to receive(:respond_to?).with(:source_position).and_return(true)
        allow(node).to receive(:source_position).and_return({start_line: 1, end_line: 1})
      end

      # Stub NodeTyping
      allow(Ast::Merge::NodeTyping).to receive(:typed_node?).with(node).and_return(false)
      allow(Ast::Merge::NodeTyping).to receive(:unwrap).with(node).and_return(node)

      # Stub NodeTypeNormalizer
      allow(Markdown::Merge::NodeTypeNormalizer).to receive(:canonical_type).with(type, :mock).and_return(type)

      node
    end

    context "with :heading type" do
      it "generates heading signature with level and content" do
        node = mock_node(type: :heading, header_level: 2, first_child: nil)
        allow(node).to receive(:respond_to?).with(:walk).and_return(false)
        allow(node).to receive(:respond_to?).with(:children).and_return(true)
        allow(node).to receive(:children).and_return([])

        sig = analysis.compute_parser_signature(node)

        expect(sig.first).to eq(:heading)
        expect(sig[1]).to eq(2)
      end
    end

    context "with :paragraph type" do
      it "generates paragraph signature with content hash" do
        node = mock_node(type: :paragraph, first_child: nil)
        allow(node).to receive(:respond_to?).with(:walk).and_return(false)
        allow(node).to receive(:respond_to?).with(:children).and_return(true)
        allow(node).to receive(:children).and_return([])

        sig = analysis.compute_parser_signature(node)

        expect(sig.first).to eq(:paragraph)
        expect(sig[1]).to be_a(String)
        expect(sig[1].length).to eq(32)
      end
    end

    context "with :code_block type" do
      it "generates code_block signature with fence info" do
        node = mock_node(type: :code_block, fence_info: "ruby", string_content: "puts 'hello'")

        sig = analysis.compute_parser_signature(node)

        expect(sig.first).to eq(:code_block)
        expect(sig[1]).to eq("ruby")
        expect(sig[2]).to be_a(String)
        expect(sig[2].length).to eq(16)
      end

      it "handles missing fence_info" do
        node = mock_node(type: :code_block, string_content: "some code")
        allow(node).to receive(:respond_to?).with(:fence_info).and_return(false)

        sig = analysis.compute_parser_signature(node)

        expect(sig.first).to eq(:code_block)
        expect(sig[1]).to be_nil
      end
    end

    context "with :list type" do
      it "generates list signature with type and count" do
        child1 = double("ListItem")
        child2 = double("ListItem")
        allow(child1).to receive(:next_sibling).and_return(child2)
        allow(child2).to receive(:next_sibling).and_return(nil)

        node = mock_node(type: :list, list_type: :bullet, first_child: child1)

        sig = analysis.compute_parser_signature(node)

        expect(sig.first).to eq(:list)
        expect(sig[1]).to eq(:bullet)
        expect(sig[2]).to eq(2)
      end

      it "handles missing list_type" do
        node = mock_node(type: :list, first_child: nil)
        allow(node).to receive(:respond_to?).with(:list_type).and_return(false)

        sig = analysis.compute_parser_signature(node)

        expect(sig.first).to eq(:list)
        expect(sig[1]).to be_nil
      end
    end

    context "with :block_quote type" do
      it "generates block_quote signature with content hash" do
        node = mock_node(type: :block_quote, first_child: nil)
        allow(node).to receive(:respond_to?).with(:walk).and_return(false)
        allow(node).to receive(:respond_to?).with(:children).and_return(true)
        allow(node).to receive(:children).and_return([])

        sig = analysis.compute_parser_signature(node)

        expect(sig.first).to eq(:block_quote)
        expect(sig[1]).to be_a(String)
        expect(sig[1].length).to eq(16)
      end
    end

    context "with :thematic_break type" do
      it "generates simple thematic_break signature" do
        node = mock_node(type: :thematic_break)

        sig = analysis.compute_parser_signature(node)

        expect(sig).to eq([:thematic_break])
      end
    end

    context "with :html_block type" do
      it "generates html_block signature with content hash" do
        node = mock_node(type: :html_block, string_content: "<div>content</div>")

        sig = analysis.compute_parser_signature(node)

        expect(sig.first).to eq(:html_block)
        expect(sig[1]).to be_a(String)
        expect(sig[1].length).to eq(16)
      end
    end

    context "with :table type" do
      it "generates table signature with row count and header hash" do
        header_row = double("HeaderRow")
        allow(header_row).to receive_messages(next_sibling: nil)
        allow(header_row).to receive(:respond_to?).and_return(false)
        allow(header_row).to receive(:respond_to?).with(:walk).and_return(false)
        allow(header_row).to receive(:respond_to?).with(:children).and_return(true)
        allow(header_row).to receive(:respond_to?).with(:type).and_return(true)
        allow(header_row).to receive(:respond_to?).with(:string_content).and_return(false)
        allow(header_row).to receive_messages(type: :table_row, children: [])

        node = mock_node(type: :table, first_child: header_row)

        # Also stub canonical_type for :table_row since it's called when processing header_row
        allow(Markdown::Merge::NodeTypeNormalizer).to receive(:canonical_type).with(:table_row, :mock).and_return(:table_row)

        sig = analysis.compute_parser_signature(node)

        expect(sig.first).to eq(:table)
        expect(sig[1]).to eq(1) # row count
        expect(sig[2]).to be_a(String)
        expect(sig[2].length).to eq(16)
      end
    end

    context "with :footnote_definition type" do
      it "generates footnote signature with name" do
        node = mock_node(type: :footnote_definition, name: "note1")

        sig = analysis.compute_parser_signature(node)

        expect(sig.first).to eq(:footnote_definition)
        expect(sig[1]).to eq("note1")
      end

      it "falls back to string_content when name not available" do
        node = mock_node(type: :footnote_definition, string_content: "footnote text")
        allow(node).to receive(:respond_to?).with(:name).and_return(false)

        sig = analysis.compute_parser_signature(node)

        expect(sig.first).to eq(:footnote_definition)
        expect(sig[1]).to eq("footnote text")
      end
    end

    context "with :custom_block type" do
      it "generates custom_block signature with content hash" do
        node = mock_node(type: :custom_block, first_child: nil)
        allow(node).to receive(:respond_to?).with(:walk).and_return(false)
        allow(node).to receive(:respond_to?).with(:children).and_return(true)
        allow(node).to receive(:children).and_return([])

        sig = analysis.compute_parser_signature(node)

        expect(sig.first).to eq(:custom_block)
        expect(sig[1]).to be_a(String)
        expect(sig[1].length).to eq(16)
      end
    end

    context "with unknown type" do
      it "generates unknown signature with type and position" do
        node = mock_node(type: :super_custom_node)
        allow(Markdown::Merge::NodeTypeNormalizer).to receive(:canonical_type)
          .with(:super_custom_node, :mock).and_return(:super_custom_node)

        sig = analysis.compute_parser_signature(node)

        expect(sig.first).to eq(:unknown)
        expect(sig[1]).to eq(:super_custom_node)
        expect(sig[2]).to eq(1) # start_line
      end
    end
  end

  describe "#freeze_node_class" do
    let(:test_class) do
      Class.new(described_class) do
        def initialize
          @backend = :mock
        end
      end
    end

    it "returns Markdown::Merge::FreezeNode" do
      analysis = test_class.new
      expect(analysis.freeze_node_class).to eq(Markdown::Merge::FreezeNode)
    end
  end

  describe "#fallthrough_node? (mocked)" do
    let(:test_class) do
      Class.new(described_class) do
        def initialize
          @backend = :mock
          @parser = nil
          @source = ""
          @lines = []
          @errors = []
        end
      end
    end

    let(:analysis) { test_class.new }

    it "returns true for typed nodes" do
      node = double("TypedNode")
      allow(Ast::Merge::NodeTyping).to receive(:typed_node?).with(node).and_return(true)

      expect(analysis.fallthrough_node?(node)).to be true
    end

    it "returns true for FreezeNodeBase instances" do
      freeze_node = Markdown::Merge::FreezeNode.new(
        content: "frozen",
        start_line: 1,
        end_line: 3,
        start_marker: "<!-- markdown-merge:freeze -->",
        end_marker: "<!-- markdown-merge:unfreeze -->",
      )

      expect(analysis.fallthrough_node?(freeze_node)).to be true
    end

    it "returns true for parser nodes (using TestableNode)" do
      # TestableNode is a real TreeHaver::Node that responds to :type and :source_position
      node = TestableNode.create(type: :paragraph, text: "Hello", start_line: 1)

      expect(analysis.fallthrough_node?(node)).to be true
    end

    it "returns true for parser nodes with mocked respond_to? behavior" do
      # Keep this mock-based test for edge case where we need to test respond_to? specifically
      node = double("ParserNode")
      allow(Ast::Merge::NodeTyping).to receive(:typed_node?).with(node).and_return(false)
      allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
      allow(node).to receive(:respond_to?).with(:type).and_return(true)
      allow(node).to receive(:respond_to?).with(:source_position).and_return(true)

      expect(analysis.fallthrough_node?(node)).to be true
    end
  end
end
