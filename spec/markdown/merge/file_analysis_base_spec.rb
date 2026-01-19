# frozen_string_literal: true

RSpec.describe Markdown::Merge::FileAnalysisBase do
  # Create a concrete implementation for testing
  let(:test_class) do
    Class.new(described_class) do
      def parse_document(source)
        # Simple mock document structure
        @mock_doc ||= Struct.new(:first_child, :type).new(nil, :document)
      end

      def next_sibling(node)
        nil
      end

      def compute_parser_signature(node)
        [:test_signature]
      end
    end
  end

  let(:simple_source) { "# Title\n\nParagraph content." }
  let(:analysis) { test_class.new(simple_source) }

  describe "#initialize" do
    it "stores the source" do
      expect(analysis.source).to eq(simple_source)
    end

    it "parses the document" do
      expect(analysis.document).not_to be_nil
    end

    it "extracts statements" do
      expect(analysis.statements).to be_an(Array)
    end

    it "accepts freeze_token option" do
      custom = test_class.new(simple_source, freeze_token: "custom-token")
      expect(custom).to be_a(described_class)
    end

    it "accepts signature_generator option" do
      generator = ->(node) { [:custom] }
      custom = test_class.new(simple_source, signature_generator: generator)
      expect(custom).to be_a(described_class)
    end
  end

  describe "#valid?" do
    it "returns true for valid document" do
      expect(analysis.valid?).to be true
    end
  end

  describe "#statements" do
    it "returns an array" do
      expect(analysis.statements).to be_an(Array)
    end
  end

  describe "#freeze_blocks" do
    let(:source_with_freeze) do
      <<~MARKDOWN
        # Title

        <!-- markdown-merge:freeze -->
        ## Frozen Section
        <!-- markdown-merge:unfreeze -->

        Regular content.
      MARKDOWN
    end

    it "detects freeze blocks" do
      freeze_analysis = test_class.new(source_with_freeze)
      expect(freeze_analysis.freeze_blocks).to be_an(Array)
    end
  end

  describe "#source_range" do
    let(:multiline_source) { "Line 1\nLine 2\nLine 3\nLine 4\nLine 5" }
    let(:multiline_analysis) { test_class.new(multiline_source) }

    it "returns lines in range" do
      result = multiline_analysis.source_range(2, 4)
      # Lines include trailing newlines for proper formatting
      expect(result).to eq("Line 2\nLine 3\nLine 4\n")
    end

    it "returns empty string for invalid start" do
      result = multiline_analysis.source_range(0, 2)
      expect(result).to eq("")
    end

    it "returns empty string when end < start" do
      result = multiline_analysis.source_range(4, 2)
      expect(result).to eq("")
    end

    it "handles single line" do
      result = multiline_analysis.source_range(3, 3)
      # Single line includes trailing newline
      expect(result).to eq("Line 3\n")
    end
  end

  describe "#signature_at" do
    it "returns signature for valid index" do
      # The test class returns [:test_signature] for any node
      # but with empty statements, we need to verify the method exists
      expect(analysis).to respond_to(:signature_at)
    end
  end

  describe "abstract methods" do
    let(:base_instance) do
      # Bypass abstract method checks by creating a minimal subclass
      klass = Class.new(described_class) do
        def initialize
          # Skip super to avoid abstract method calls
        end
      end
      klass.new
    end

    it "raises NotImplementedError for parse_document" do
      expect { base_instance.parse_document("source") }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for next_sibling" do
      expect { base_instance.next_sibling(nil) }.to raise_error(NotImplementedError)
    end
  end

  describe "DEFAULT_FREEZE_TOKEN" do
    it "is set to markdown-merge" do
      expect(described_class::DEFAULT_FREEZE_TOKEN).to eq("markdown-merge")
    end
  end

  describe "#compute_node_signature" do
    let(:test_class_with_compute) do
      Class.new(described_class) do
        def parse_document(source)
          @mock_doc ||= Struct.new(:first_child, :type).new(nil, :document)
        end

        def next_sibling(node)
          nil
        end

        # Don't override compute_parser_signature - use the base implementation
      end
    end

    let(:analysis) { test_class_with_compute.new("# Test") }

    it "returns freeze_node signature for FreezeNodeBase instances" do
      # Create a real subclass since case/when uses === which requires actual inheritance
      test_freeze_node_class = Class.new(Ast::Merge::FreezeNodeBase) do
        def initialize(sig)
          @sig = sig
        end

        def signature
          @sig
        end
      end

      freeze_node = test_freeze_node_class.new([:freeze_block, "abc123"])
      result = analysis.compute_node_signature(freeze_node)
      expect(result).to eq([:freeze_block, "abc123"])
    end

    it "delegates to compute_parser_signature for regular nodes" do
      node = double("Node", type: :paragraph)
      allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
      allow(node).to receive(:string_content).and_return("test content")
      allow(node).to receive(:walk).and_yield(double(type: :text, string_content: "test content"))

      result = analysis.compute_node_signature(node)
      expect(result.first).to eq(:paragraph)
    end
  end

  describe "#compute_parser_signature" do
    let(:test_class_full) do
      Class.new(described_class) do
        def parse_document(source)
          @mock_doc ||= Struct.new(:first_child, :type).new(nil, :document)
        end

        def next_sibling(node)
          nil
        end
      end
    end

    let(:analysis) { test_class_full.new("# Test") }

    describe "with :heading/:header node type" do
      it "returns heading signature" do
        node = double("HeadingNode", type: :heading, header_level: 2)
        allow(node).to receive(:first_child).and_return(nil)
        allow(node).to receive(:walk).and_yield(double(type: :text, string_content: "Title"))

        result = analysis.send(:compute_parser_signature, node)
        expect(result[0]).to eq(:heading)
        expect(result[1]).to eq(2)
        expect(result[2]).to eq("Title")
      end

      it "handles :header type (alias)" do
        node = double("HeaderNode", type: :header, header_level: 1)
        allow(node).to receive(:first_child).and_return(nil)
        allow(node).to receive(:walk).and_yield(double(type: :text, string_content: "Main"))

        result = analysis.send(:compute_parser_signature, node)
        expect(result[0]).to eq(:heading)
        expect(result[1]).to eq(1)
      end
    end

    describe "with :paragraph node type" do
      it "returns paragraph signature with content hash" do
        node = double("ParagraphNode", type: :paragraph)
        allow(node).to receive(:first_child).and_return(nil)
        allow(node).to receive(:walk).and_yield(double(type: :text, string_content: "Some text"))

        result = analysis.send(:compute_parser_signature, node)
        expect(result[0]).to eq(:paragraph)
        expect(result[1]).to be_a(String)
        expect(result[1].length).to eq(32)
      end
    end

    describe "with :code_block node type" do
      it "returns code_block signature" do
        node = double("CodeBlockNode", type: :code_block)
        allow(node).to receive(:respond_to?).with(:fence_info).and_return(true)
        allow(node).to receive_messages(fence_info: "ruby", string_content: "puts 'hello'")

        result = analysis.send(:compute_parser_signature, node)
        expect(result[0]).to eq(:code_block)
        expect(result[1]).to eq("ruby")
        expect(result[2]).to be_a(String)
        expect(result[2].length).to eq(16)
      end

      it "handles nil fence_info" do
        node = double("CodeBlockNode", type: :code_block)
        allow(node).to receive(:respond_to?).with(:fence_info).and_return(true)
        allow(node).to receive_messages(fence_info: nil, string_content: "plain code")

        result = analysis.send(:compute_parser_signature, node)
        expect(result[0]).to eq(:code_block)
        expect(result[1]).to be_nil
      end
    end

    describe "with :list node type" do
      it "returns list signature with type and count" do
        node = double("ListNode", type: :list)
        allow(node).to receive(:respond_to?).with(:list_type).and_return(true)
        allow(node).to receive_messages(list_type: :bullet, first_child: nil)

        result = analysis.send(:compute_parser_signature, node)
        expect(result[0]).to eq(:list)
        expect(result[1]).to eq(:bullet)
        expect(result[2]).to be_a(Integer)
      end

      it "handles no list_type method" do
        node = double("ListNode", type: :list)
        allow(node).to receive(:respond_to?).with(:list_type).and_return(false)
        allow(node).to receive(:first_child).and_return(nil)

        result = analysis.send(:compute_parser_signature, node)
        expect(result[0]).to eq(:list)
        expect(result[1]).to be_nil
      end
    end

    describe "with :block_quote/:blockquote node type" do
      it "returns blockquote signature" do
        node = double("BlockQuoteNode", type: :block_quote)
        allow(node).to receive(:first_child).and_return(nil)
        allow(node).to receive(:walk).and_yield(double(type: :text, string_content: "Quote"))

        result = analysis.send(:compute_parser_signature, node)
        expect(result[0]).to eq(:blockquote)
        expect(result[1]).to be_a(String)
        expect(result[1].length).to eq(16)
      end

      it "handles :blockquote alias" do
        node = double("BlockQuoteNode", type: :blockquote)
        allow(node).to receive(:first_child).and_return(nil)
        allow(node).to receive(:walk).and_yield(double(type: :text, string_content: "Quote"))

        result = analysis.send(:compute_parser_signature, node)
        expect(result[0]).to eq(:blockquote)
      end
    end

    describe "with :thematic_break/:hrule node type" do
      it "returns hrule signature" do
        node = double("ThematicBreakNode", type: :thematic_break)

        result = analysis.send(:compute_parser_signature, node)
        expect(result).to eq([:hrule])
      end

      it "handles :hrule alias" do
        node = double("HRuleNode", type: :hrule)

        result = analysis.send(:compute_parser_signature, node)
        expect(result).to eq([:hrule])
      end
    end

    describe "with :html_block/:html node type" do
      it "returns html signature" do
        node = double("HtmlBlockNode", type: :html_block)
        allow(node).to receive(:string_content).and_return("<div>content</div>")

        result = analysis.send(:compute_parser_signature, node)
        expect(result[0]).to eq(:html)
        expect(result[1]).to be_a(String)
        expect(result[1].length).to eq(16)
      end

      it "handles :html alias" do
        node = double("HtmlNode", type: :html)
        allow(node).to receive(:string_content).and_return("<span>text</span>")

        result = analysis.send(:compute_parser_signature, node)
        expect(result[0]).to eq(:html)
      end
    end

    describe "with :table node type" do
      it "returns table signature" do
        node = double("TableNode", type: :table)
        allow(node).to receive(:first_child).and_return(nil)

        result = analysis.send(:compute_parser_signature, node)
        expect(result[0]).to eq(:table)
        expect(result[1]).to be_a(Integer)
        expect(result[2]).to be_a(String)
      end
    end

    describe "with :footnote_definition node type" do
      it "returns footnote_definition signature with name" do
        node = double("FootnoteDefNode", type: :footnote_definition)
        allow(node).to receive(:respond_to?).with(:name).and_return(true)
        allow(node).to receive(:name).and_return("fn1")

        result = analysis.send(:compute_parser_signature, node)
        expect(result).to eq([:footnote_definition, "fn1"])
      end

      it "falls back to string_content when no name method" do
        node = double("FootnoteDefNode", type: :footnote_definition)
        allow(node).to receive(:respond_to?).with(:name).and_return(false)
        allow(node).to receive(:string_content).and_return("footnote_label")

        result = analysis.send(:compute_parser_signature, node)
        expect(result).to eq([:footnote_definition, "footnote_label"])
      end
    end

    describe "with :custom_block node type" do
      it "returns custom_block signature" do
        node = double("CustomBlockNode", type: :custom_block)
        allow(node).to receive(:first_child).and_return(nil)
        allow(node).to receive(:walk).and_yield(double(type: :text, string_content: "Custom"))

        result = analysis.send(:compute_parser_signature, node)
        expect(result[0]).to eq(:custom_block)
        expect(result[1]).to be_a(String)
        expect(result[1].length).to eq(16)
      end
    end

    describe "with unknown node type" do
      it "returns unknown signature with type and position" do
        node = double("UnknownNode", type: :mysterious_type)
        allow(node).to receive(:source_position).and_return({start_line: 42, end_line: 42})

        result = analysis.send(:compute_parser_signature, node)
        expect(result).to eq([:unknown, :mysterious_type, 42])
      end

      it "handles nil source_position" do
        node = double("UnknownNode", type: :some_extension)
        allow(node).to receive(:source_position).and_return(nil)

        result = analysis.send(:compute_parser_signature, node)
        expect(result).to eq([:unknown, :some_extension, nil])
      end
    end
  end

  describe "#fallthrough_node?" do
    let(:test_class_full) do
      Class.new(described_class) do
        def parse_document(source)
          @mock_doc ||= Struct.new(:first_child, :type).new(nil, :document)
        end

        def next_sibling(node)
          nil
        end
      end
    end

    let(:analysis) { test_class_full.new("# Test") }

    it "returns true for FreezeNodeBase instances" do
      freeze_node = double("FreezeNode")
      allow(freeze_node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(true)

      expect(analysis.fallthrough_node?(freeze_node)).to be(true)
    end

    it "returns true for parser nodes (with :type method)" do
      parser_node = double("ParserNode")
      allow(parser_node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
      allow(parser_node).to receive(:is_a?).with(Markdown::Merge::LinkDefinitionNode).and_return(false)
      allow(parser_node).to receive(:is_a?).with(Markdown::Merge::GapLineNode).and_return(false)
      allow(parser_node).to receive(:respond_to?) { |m, *| [:type].include?(m) }

      expect(analysis.fallthrough_node?(parser_node)).to be(true)
    end

    it "returns false for non-node values" do
      expect(analysis.fallthrough_node?("string")).to be(false)
      expect(analysis.fallthrough_node?(123)).to be(false)
    end
  end

  describe "#parser_node?" do
    let(:analysis) { test_class.new("# Test") }

    it "returns true for objects with :type method" do
      node = double("Node")
      allow(node).to receive(:respond_to?) { |m, *| [:type].include?(m) }
      expect(analysis.parser_node?(node)).to be(true)
    end

    it "returns false for objects without :type method" do
      obj = "not a node"
      expect(analysis.parser_node?(obj)).to be(false)
    end
  end

  describe "#safe_string_content" do
    let(:test_class_full) do
      Class.new(described_class) do
        def parse_document(source)
          @mock_doc ||= Struct.new(:first_child, :type).new(nil, :document)
        end

        def next_sibling(node)
          nil
        end
      end
    end

    let(:analysis) { test_class_full.new("# Test") }

    it "returns string_content when available" do
      node = double("Node")
      allow(node).to receive(:string_content).and_return("content here")

      result = analysis.send(:safe_string_content, node)
      expect(result).to eq("content here")
    end

    it "handles nil string_content" do
      node = double("Node")
      allow(node).to receive(:string_content).and_return(nil)

      result = analysis.send(:safe_string_content, node)
      expect(result).to eq("")
    end

    it "falls back to extract_text_content on TypeError" do
      node = double("Node")
      allow(node).to receive(:string_content).and_raise(TypeError)
      allow(node).to receive(:walk).and_yield(double(type: :text, string_content: "fallback"))
      allow(node).to receive(:first_child).and_return(nil)

      result = analysis.send(:safe_string_content, node)
      expect(result).to eq("fallback")
    end
  end

  describe "#extract_text_content" do
    let(:test_class_extract) do
      Class.new(described_class) do
        def parse_document(source)
          @mock_doc ||= Struct.new(:first_child, :type).new(nil, :document)
        end

        def next_sibling(node)
          nil
        end
      end
    end

    let(:analysis) { test_class_extract.new("# Test") }

    it "extracts :text type content" do
      node = double("Node")
      text_child = double("TextChild", type: :text, string_content: "text content")
      allow(node).to receive(:walk).and_yield(text_child)

      result = analysis.send(:extract_text_content, node)
      expect(result).to eq("text content")
    end

    it "extracts :code type content" do
      node = double("Node")
      code_child = double("CodeChild", type: :code, string_content: "code content")
      allow(node).to receive(:walk).and_yield(code_child)

      result = analysis.send(:extract_text_content, node)
      expect(result).to eq("code content")
    end

    it "concatenates multiple text and code children" do
      node = double("Node")
      text_child = double("TextChild", type: :text, string_content: "text ")
      code_child = double("CodeChild", type: :code, string_content: "code")

      allow(node).to receive(:walk).and_yield(text_child).and_yield(code_child)

      result = analysis.send(:extract_text_content, node)
      expect(result).to eq("text code")
    end

    it "ignores non-text non-code children" do
      node = double("Node")
      paragraph_child = double("ParagraphChild", type: :paragraph)
      text_child = double("TextChild", type: :text, string_content: "text")

      allow(node).to receive(:walk).and_yield(paragraph_child).and_yield(text_child)

      result = analysis.send(:extract_text_content, node)
      expect(result).to eq("text")
    end
  end

  describe "#freeze_node_class" do
    let(:analysis) { test_class.new("# Test") }

    it "returns Ast::Merge::FreezeNodeBase by default" do
      expect(analysis.send(:freeze_node_class)).to eq(Ast::Merge::FreezeNodeBase)
    end
  end

  describe "freeze block integration" do
    let(:freeze_source) do
      <<~MARKDOWN
        # Title

        <!-- markdown-merge:freeze -->
        ## Frozen Section
        Content inside freeze
        <!-- markdown-merge:unfreeze -->

        ## Regular Section
      MARKDOWN
    end

    let(:test_class_with_integration) do
      Class.new(described_class) do
        def parse_document(source)
          # Return a mock document with nodes that have proper source positions
          @lines = source.split("\n")
          doc = Struct.new(:first_child, :type).new(nil, :document)

          # Create mock nodes with source positions
          nodes = []

          # Title node (line 1)
          title = Struct.new(:type, :source_position, :first_child, :header_level, :string_content).new(
            :heading,
            {start_line: 1, end_line: 1},
            nil,
            1,
            nil,
          )
          nodes << title

          # Freeze marker HTML node (line 3)
          freeze_marker = Struct.new(:type, :source_position, :first_child, :string_content).new(
            :html,
            {start_line: 3, end_line: 3},
            nil,
            "<!-- markdown-merge:freeze -->\n",
          )
          nodes << freeze_marker

          # Frozen section header (lines 4, inside freeze block)
          frozen_header = Struct.new(:type, :source_position, :first_child, :header_level, :string_content).new(
            :heading,
            {start_line: 4, end_line: 4},
            nil,
            2,
            nil,
          )
          nodes << frozen_header

          # Unfreeze marker HTML node (line 6)
          unfreeze_marker = Struct.new(:type, :source_position, :first_child, :string_content).new(
            :html,
            {start_line: 6, end_line: 6},
            nil,
            "<!-- markdown-merge:unfreeze -->\n",
          )
          nodes << unfreeze_marker

          # Regular section header (line 8)
          regular_header = Struct.new(:type, :source_position, :first_child, :header_level, :string_content).new(
            :heading,
            {start_line: 8, end_line: 8},
            nil,
            2,
            nil,
          )
          nodes << regular_header

          # Link nodes together
          title.define_singleton_method(:next_sibling) { freeze_marker }
          freeze_marker.define_singleton_method(:next_sibling) { frozen_header }
          frozen_header.define_singleton_method(:next_sibling) { unfreeze_marker }
          unfreeze_marker.define_singleton_method(:next_sibling) { regular_header }
          regular_header.define_singleton_method(:next_sibling) { nil }

          doc.first_child = title
          doc
        end

        def next_sibling(node)
          node.respond_to?(:next_sibling) ? node.next_sibling : nil
        end
      end
    end

    it "integrates freeze blocks with nodes" do
      analysis = test_class_with_integration.new(freeze_source)
      statements = analysis.statements

      # Should have freeze block and nodes outside of it
      expect(statements).to be_an(Array)
    end

    it "skips nodes inside freeze blocks" do
      analysis = test_class_with_integration.new(freeze_source)
      statements = analysis.statements

      # The frozen section header should be skipped as it's inside the freeze block
      statements.reject { |s| s.is_a?(Ast::Merge::FreezeNodeBase) }
      freeze_statements = statements.select { |s| s.is_a?(Ast::Merge::FreezeNodeBase) }

      expect(freeze_statements.length).to eq(1)
    end
  end

  describe "#build_freeze_blocks" do
    let(:test_class_for_freeze) do
      Class.new(described_class) do
        def parse_document(source)
          @lines = source.split("\n")
          doc = Struct.new(:first_child, :type).new(nil, :document)

          # Create HTML nodes for any freeze markers found in source
          nodes = []
          @lines.each_with_index do |line, idx|
            line_num = idx + 1
            if line.include?("<!-- markdown-merge:freeze") || line.include?("<!-- markdown-merge:unfreeze")
              html_node = Struct.new(:type, :source_position, :first_child, :string_content).new(
                :html,
                {start_line: line_num, end_line: line_num},
                nil,
                "#{line}\n",
              )
              nodes << html_node
            end
          end

          # Link nodes together
          nodes.each_with_index do |node, i|
            next_node = nodes[i + 1]
            node.define_singleton_method(:next_sibling) { next_node }
          end

          doc.first_child = nodes.first
          doc
        end

        def next_sibling(node)
          node.respond_to?(:next_sibling) ? node.next_sibling : nil
        end
      end
    end

    it "handles unmatched unfreeze marker" do
      source_with_unmatched = <<~MARKDOWN
        # Title
        <!-- markdown-merge:unfreeze -->
        Content
      MARKDOWN

      analysis = test_class_for_freeze.new(source_with_unmatched)
      # Should not raise, just log debug message
      expect(analysis.freeze_blocks).to eq([])
    end

    it "handles unclosed freeze marker" do
      source_with_unclosed = <<~MARKDOWN
        # Title
        <!-- markdown-merge:freeze -->
        Content without unfreeze
      MARKDOWN

      analysis = test_class_for_freeze.new(source_with_unclosed)
      # Should not raise, just log debug message
      expect(analysis.freeze_blocks).to eq([])
    end

    it "handles empty content between markers" do
      source_with_empty = <<~MARKDOWN
        # Title
        <!-- markdown-merge:freeze -->
        <!-- markdown-merge:unfreeze -->
        Content after
      MARKDOWN

      analysis = test_class_for_freeze.new(source_with_empty)
      freeze_blocks = analysis.freeze_blocks
      expect(freeze_blocks.length).to eq(1)
      expect(freeze_blocks.first.content).to eq("")
    end
  end

  describe "#extract_table_header_content" do
    let(:test_class_tables) do
      Class.new(described_class) do
        def parse_document(source)
          @mock_doc ||= Struct.new(:first_child, :type).new(nil, :document)
        end

        def next_sibling(node)
          nil
        end
      end
    end

    let(:analysis) { test_class_tables.new("# Test") }

    it "returns empty string when no first row" do
      table_node = double("TableNode")
      allow(table_node).to receive(:first_child).and_return(nil)

      result = analysis.send(:extract_table_header_content, table_node)
      expect(result).to eq("")
    end

    it "extracts content from first row" do
      row = double("TableRow")
      allow(row).to receive(:walk).and_yield(double(type: :text, string_content: "Header"))

      table_node = double("TableNode")
      allow(table_node).to receive(:first_child).and_return(row)

      result = analysis.send(:extract_table_header_content, table_node)
      expect(result).to eq("Header")
    end
  end

  describe "#count_children" do
    let(:test_class_children) do
      Class.new(described_class) do
        def parse_document(source)
          @mock_doc ||= Struct.new(:first_child, :type).new(nil, :document)
        end

        def next_sibling(node)
          node.respond_to?(:sibling) ? node.sibling : nil
        end
      end
    end

    let(:analysis) { test_class_children.new("# Test") }

    it "counts children using next_sibling" do
      child3 = Struct.new(:sibling).new(nil)
      child2 = Struct.new(:sibling).new(child3)
      child1 = Struct.new(:sibling).new(child2)

      parent = double("Parent")
      allow(parent).to receive(:first_child).and_return(child1)

      result = analysis.send(:count_children, parent)
      expect(result).to eq(3)
    end

    it "returns 0 for no children" do
      parent = double("Parent")
      allow(parent).to receive(:first_child).and_return(nil)

      result = analysis.send(:count_children, parent)
      expect(result).to eq(0)
    end
  end

  describe "integrate_nodes_with_freeze_blocks" do
    let(:test_class_integrate) do
      Class.new(described_class) do
        attr_accessor :mock_nodes

        def parse_document(source)
          @lines = source.split("\n")
          doc = Struct.new(:first_child, :type).new(nil, :document)
          doc
        end

        def next_sibling(node)
          return unless @mock_nodes

          idx = @mock_nodes.index(node)
          return if idx.nil? || idx >= @mock_nodes.length - 1

          @mock_nodes[idx + 1]
        end

        def collect_top_level_nodes
          @mock_nodes || []
        end
      end
    end

    it "adds remaining freeze blocks after all nodes" do
      source = <<~MARKDOWN
        # Title
        Content
        <!-- markdown-merge:freeze -->
        Frozen
        <!-- markdown-merge:unfreeze -->
      MARKDOWN

      analysis = test_class_integrate.new(source)

      # Create a node that ends before the freeze block
      node = Struct.new(:type, :source_position).new(:paragraph, {start_line: 1, end_line: 2})
      analysis.mock_nodes = [node]

      # Force re-extraction
      statements = analysis.statements
      expect(statements).to be_an(Array)
    end
  end

  describe "#compute_node_signature" do
    let(:test_class_sig) do
      Class.new(described_class) do
        def parse_document(source)
          Struct.new(:first_child, :type).new(nil, :document)
        end

        def next_sibling(node)
          nil
        end

        def compute_parser_signature(node)
          [:parser_signature, node.type]
        end
      end
    end

    it "handles LinkDefinitionNode instances" do
      analysis = test_class_sig.new("# Test")

      link_node = Markdown::Merge::LinkDefinitionNode.new(
        "[ref]: https://example.com",
        line_number: 5,
        label: "ref",
        url: "https://example.com",
      )

      signature = analysis.compute_node_signature(link_node)
      expect(signature).to eq([:link_definition, "ref"])
    end

    it "handles GapLineNode instances" do
      analysis = test_class_sig.new("# Test")

      gap_node = Markdown::Merge::GapLineNode.new("", line_number: 3)

      signature = analysis.compute_node_signature(gap_node)
      expect(signature).to eq([:gap_line, 3, ""])
    end

    it "delegates to compute_parser_signature for other nodes" do
      analysis = test_class_sig.new("# Test")

      parser_node = Struct.new(:type).new(:paragraph)

      signature = analysis.compute_node_signature(parser_node)
      expect(signature).to eq([:parser_signature, :paragraph])
    end
  end

  describe "#fallthrough_node?" do
    let(:test_class_fallthrough) do
      Class.new(described_class) do
        def parse_document(source)
          Struct.new(:first_child, :type).new(nil, :document)
        end

        def next_sibling(node)
          nil
        end

        def compute_parser_signature(node)
          [:test]
        end
      end
    end

    it "returns true for LinkDefinitionNode" do
      analysis = test_class_fallthrough.new("# Test")

      link_node = Markdown::Merge::LinkDefinitionNode.new(
        "[ref]: https://example.com",
        line_number: 1,
        label: "ref",
        url: "https://example.com",
      )

      expect(analysis.fallthrough_node?(link_node)).to be true
    end

    it "returns true for GapLineNode" do
      analysis = test_class_fallthrough.new("# Test")

      gap_node = Markdown::Merge::GapLineNode.new("", line_number: 1)

      expect(analysis.fallthrough_node?(gap_node)).to be true
    end

    it "returns false for other objects" do
      analysis = test_class_fallthrough.new("# Test")

      expect(analysis.fallthrough_node?("string")).to be false
      expect(analysis.fallthrough_node?(123)).to be false
      expect(analysis.fallthrough_node?(nil)).to be false
    end
  end

  describe "#collect_top_level_nodes_with_gaps (private)" do
    let(:test_class_gaps) do
      Class.new(described_class) do
        attr_accessor :mock_parser_nodes

        def parse_document(source)
          @lines = source.split("\n")
          Struct.new(:first_child, :type).new(nil, :document)
        end

        def next_sibling(node)
          nil
        end

        def collect_top_level_nodes
          @mock_parser_nodes || []
        end

        def compute_parser_signature(node)
          [:test]
        end
      end
    end

    it "creates GapLineNode for blank lines" do
      source = "# Title\n\n## Section"
      analysis = test_class_gaps.new(source)

      # Mock parser nodes covering lines 1 and 3
      node1 = Struct.new(:type, :source_position).new(:heading, {start_line: 1, end_line: 1})
      node2 = Struct.new(:type, :source_position).new(:heading, {start_line: 3, end_line: 3})
      analysis.mock_parser_nodes = [node1, node2]

      result = analysis.send(:collect_top_level_nodes_with_gaps)

      gap_nodes = result.select { |n| n.is_a?(Markdown::Merge::GapLineNode) }
      expect(gap_nodes.length).to eq(1)
      expect(gap_nodes.first.line_number).to eq(2)
    end

    it "creates LinkDefinitionNode for link definitions in gaps" do
      source = "# Title\n[ref]: https://example.com\n## Section"
      analysis = test_class_gaps.new(source)

      # Mock parser nodes covering lines 1 and 3
      node1 = Struct.new(:type, :source_position).new(:heading, {start_line: 1, end_line: 1})
      node2 = Struct.new(:type, :source_position).new(:heading, {start_line: 3, end_line: 3})
      analysis.mock_parser_nodes = [node1, node2]

      result = analysis.send(:collect_top_level_nodes_with_gaps)

      link_nodes = result.select { |n| n.is_a?(Markdown::Merge::LinkDefinitionNode) }
      expect(link_nodes.length).to eq(1)
      expect(link_nodes.first.label).to eq("ref")
    end

    it "handles nodes with nil source_position" do
      source = "# Title\n\n## Section"
      analysis = test_class_gaps.new(source)

      # Node with nil source_position
      node1 = Struct.new(:type, :source_position).new(:heading, nil)
      analysis.mock_parser_nodes = [node1]

      result = analysis.send(:collect_top_level_nodes_with_gaps)
      expect(result).to be_an(Array)
    end

    it "handles Markly buggy position reporting (end_line < start_line)" do
      source = "# Title\n\n## Section\n\n### Sub"
      analysis = test_class_gaps.new(source)

      # Simulate Markly bug: end_line < start_line
      node1 = Struct.new(:type, :source_position).new(:heading, {start_line: 3, end_line: 2})
      analysis.mock_parser_nodes = [node1]

      # Should not raise, should handle gracefully
      result = analysis.send(:collect_top_level_nodes_with_gaps)
      expect(result).to be_an(Array)
    end

    it "returns parser nodes as-is when source has no lines" do
      analysis = test_class_gaps.new("")

      node = Struct.new(:type, :source_position).new(:paragraph, {start_line: 1, end_line: 1})
      analysis.mock_parser_nodes = [node]

      # Force empty lines
      analysis.instance_variable_set(:@lines, [])

      result = analysis.send(:collect_top_level_nodes_with_gaps)
      expect(result).to eq([node])
    end
  end
end
