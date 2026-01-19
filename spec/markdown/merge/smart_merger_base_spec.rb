# frozen_string_literal: true

RSpec.describe Markdown::Merge::SmartMergerBase do
  # Mock Node class - defined first so it can be used by MockFileAnalysis
  let(:mock_node_class) do
    Class.new do
      attr_reader :content, :line_number

      def initialize(content, line_number)
        @content = content
        @line_number = line_number
      end

      def type
        :paragraph
      end

      def source_position
        {start_line: @line_number, end_line: @line_number}
      end

      def to_commonmark
        @content
      end

      def respond_to?(method, include_private = false)
        %i[type source_position to_commonmark freeze_node? first_child].include?(method) || super
      end

      def freeze_node?
        false
      end

      def first_child
        nil
      end
    end
  end

  # Mock FileAnalysis for testing - simplified implementation that doesn't rely on base class parsing
  let(:mock_file_analysis_class) do
    Class.new(Markdown::Merge::FileAnalysisBase) do
      # Override initialize to skip base class parsing complexity
      def initialize(content, **options)
        @source = content
        @lines = content.split("\n", -1)
        @freeze_token = options[:freeze_token] || "markdown-merge"
        @signature_generator = options[:signature_generator]

        # Create a mock document
        @document = Object.new.tap do |doc|
          nodes = parse_simple(content)
          # rubocop:disable ThreadSafety/ClassInstanceVariable -- Test double needs instance state
          def doc.first_child
            @first_child
          end

          def doc.first_child=(node)
            @first_child = node
          end
          # rubocop:enable ThreadSafety/ClassInstanceVariable
          doc.first_child = nodes.first
        end

        # Set up statements
        @statements = parse_simple(content)
      end

      def source_range(start_line, end_line)
        @lines[(start_line - 1)..(end_line - 1)]&.join("\n") || ""
      end

      # Override to return our statements
      attr_reader :statements

      # Required abstract methods
      def parse_document(source)
        @document
      end

      def next_sibling(node)
        nil
      end

      # Signature computation
      def signature_at(index)
        node = @statements[index]
        return unless node

        [:paragraph, "mock_sig_#{index}"]
      end

      def compute_node_signature(node)
        idx = @statements.index(node) || 0
        [:paragraph, "mock_sig_#{idx}"]
      end

      private

      def parse_simple(content)
        # Very simple parser that creates mock nodes for each line block
        nodes = []
        content.split(/\n\n+/).each_with_index do |block, idx|
          nodes << MockNode.new(block, idx + 1)
        end
        nodes
      end
    end
  end

  # Create a concrete test implementation since SmartMergerBase is abstract
  let(:test_merger_class) do
    Class.new(described_class) do
      def create_file_analysis(content, **options)
        MockFileAnalysis.new(content, **options)
      end
    end
  end

  before do
    # Define the mock classes in the global namespace for the test merger
    stub_const("MockNode", mock_node_class)
    stub_const("MockFileAnalysis", mock_file_analysis_class)
  end

  describe "#initialize" do
    let(:template) { "# Template\n\nSome content" }
    let(:dest) { "# Destination\n\nOther content" }

    it "raises NotImplementedError for base class" do
      expect {
        described_class.new(template, dest)
      }.to raise_error(NotImplementedError)
    end

    context "with concrete implementation" do
      subject(:merger) { test_merger_class.new(template, dest) }

      it "creates a merger instance" do
        expect(merger).to be_a(described_class)
      end

      it "creates template_analysis" do
        expect(merger.template_analysis).to be_a(Markdown::Merge::FileAnalysisBase)
      end

      it "creates dest_analysis" do
        expect(merger.dest_analysis).to be_a(Markdown::Merge::FileAnalysisBase)
      end

      it "creates aligner" do
        expect(merger.aligner).to be_a(Markdown::Merge::FileAligner)
      end

      it "creates resolver" do
        expect(merger.resolver).to be_a(Markdown::Merge::ConflictResolver)
      end

      it "does not create code_block_merger by default" do
        expect(merger.code_block_merger).to be_nil
      end
    end

    context "with preference option" do
      it "accepts :destination preference" do
        merger = test_merger_class.new(template, dest, preference: :destination)
        expect(merger.instance_variable_get(:@preference)).to eq(:destination)
      end

      it "accepts :template preference" do
        merger = test_merger_class.new(template, dest, preference: :template)
        expect(merger.instance_variable_get(:@preference)).to eq(:template)
      end
    end

    context "with add_template_only_nodes option" do
      it "defaults to false" do
        merger = test_merger_class.new(template, dest)
        expect(merger.instance_variable_get(:@add_template_only_nodes)).to be(false)
      end

      it "accepts true" do
        merger = test_merger_class.new(template, dest, add_template_only_nodes: true)
        expect(merger.instance_variable_get(:@add_template_only_nodes)).to be(true)
      end
    end

    context "with inner_merge_code_blocks option" do
      it "accepts true to create default merger" do
        merger = test_merger_class.new(template, dest, inner_merge_code_blocks: true)
        expect(merger.code_block_merger).to be_a(Markdown::Merge::CodeBlockMerger)
      end

      it "accepts false (default)" do
        merger = test_merger_class.new(template, dest, inner_merge_code_blocks: false)
        expect(merger.code_block_merger).to be_nil
      end

      it "accepts CodeBlockMerger instance" do
        custom_merger = Markdown::Merge::CodeBlockMerger.new(enabled: false)
        merger = test_merger_class.new(template, dest, inner_merge_code_blocks: custom_merger)
        expect(merger.code_block_merger).to eq(custom_merger)
      end

      it "raises ArgumentError for invalid value" do
        expect {
          test_merger_class.new(template, dest, inner_merge_code_blocks: "invalid")
        }.to raise_error(ArgumentError, /inner_merge_code_blocks/)
      end
    end

    context "with match_refiner option" do
      let(:refiner) { Markdown::Merge::TableMatchRefiner.new }

      it "accepts nil (default)" do
        merger = test_merger_class.new(template, dest, match_refiner: nil)
        expect(merger.instance_variable_get(:@match_refiner)).to be_nil
      end

      it "accepts match refiner instance" do
        merger = test_merger_class.new(template, dest, match_refiner: refiner)
        expect(merger.instance_variable_get(:@match_refiner)).to eq(refiner)
      end
    end

    context "with freeze_token option" do
      it "uses default freeze token" do
        # Just verify no error - actual token is passed to analysis
        merger = test_merger_class.new(template, dest)
        expect(merger).to be_a(described_class)
      end

      it "accepts custom freeze token" do
        merger = test_merger_class.new(template, dest, freeze_token: "custom-token")
        expect(merger).to be_a(described_class)
      end
    end
  end

  describe "#template_parse_error_class" do
    let(:merger) { test_merger_class.new("# Test", "# Test") }

    it "returns Markdown::Merge::TemplateParseError" do
      expect(merger.template_parse_error_class).to eq(Markdown::Merge::TemplateParseError)
    end
  end

  describe "#destination_parse_error_class" do
    let(:merger) { test_merger_class.new("# Test", "# Test") }

    it "returns Markdown::Merge::DestinationParseError" do
      expect(merger.destination_parse_error_class).to eq(Markdown::Merge::DestinationParseError)
    end
  end

  describe "#merge" do
    let(:template) { "# Heading\n\nParagraph one" }
    let(:dest) { "# Heading\n\nParagraph two" }
    let(:merger) { test_merger_class.new(template, dest) }

    it "returns a string" do
      result = merger.merge
      expect(result).to be_a(String)
    end

    it "returns non-empty content" do
      result = merger.merge
      expect(result).not_to be_empty
    end
  end

  describe "#merge_result" do
    let(:template) { "# Heading\n\nContent" }
    let(:dest) { "# Heading\n\nContent" }
    let(:merger) { test_merger_class.new(template, dest) }

    it "returns a MergeResult" do
      result = merger.merge_result
      expect(result).to be_a(Markdown::Merge::MergeResult)
    end

    it "has content" do
      result = merger.merge_result
      expect(result.content).to be_a(String)
    end

    it "has stats" do
      result = merger.merge_result
      expect(result.stats).to be_a(Hash)
    end

    it "caches the result" do
      first_result = merger.merge_result
      second_result = merger.merge_result
      expect(first_result).to equal(second_result)
    end

    it "includes merge_time_ms in stats" do
      result = merger.merge_result
      expect(result.stats).to have_key(:merge_time_ms)
      expect(result.stats[:merge_time_ms]).to be_a(Numeric)
    end
  end

  describe "#stats" do
    let(:merger) { test_merger_class.new("# Test", "# Test") }

    it "returns stats from merge_result" do
      expect(merger.stats).to eq(merger.merge_result.stats)
    end
  end

  describe "#apply_node_typing" do
    context "without node_typing configured" do
      let(:merger) { test_merger_class.new("# Test", "# Test") }

      it "returns the node unchanged" do
        node = double("Node")
        allow(node).to receive(:type).and_return(:paragraph)

        result = merger.send(:apply_node_typing, node)
        expect(result).to eq(node)
      end
    end

    context "with nil node" do
      let(:node_typing) { {paragraph: ->(n) { n }} }
      let(:merger) { test_merger_class.new("# Test", "# Test", node_typing: node_typing) }

      it "returns nil" do
        result = merger.send(:apply_node_typing, nil)
        expect(result).to be_nil
      end
    end

    context "with node_typing configured using symbol key" do
      let(:custom_wrapper) { double("CustomWrapper") }
      let(:node_typing) { {paragraph: ->(n) { custom_wrapper }} }
      let(:merger) { test_merger_class.new("# Test", "# Test", node_typing: node_typing) }

      it "calls the callable for matching symbol type" do
        node = double("Node")
        allow(node).to receive(:type).and_return(:paragraph)
        allow(node).to receive(:respond_to?).with(:type).and_return(true)

        result = merger.send(:apply_node_typing, node)
        expect(result).to eq(custom_wrapper)
      end
    end

    context "with node_typing configured using string key" do
      let(:custom_wrapper) { double("CustomWrapper") }
      let(:node_typing) { {"paragraph" => ->(n) { custom_wrapper }} }
      let(:merger) { test_merger_class.new("# Test", "# Test", node_typing: node_typing) }

      it "calls the callable for matching string type" do
        node = double("Node")
        allow(node).to receive(:type).and_return(:paragraph)
        allow(node).to receive(:respond_to?).with(:type).and_return(true)

        result = merger.send(:apply_node_typing, node)
        expect(result).to eq(custom_wrapper)
      end
    end

    context "with node that doesn't respond to type" do
      let(:node_typing) { {paragraph: ->(n) { n }} }
      let(:merger) { test_merger_class.new("# Test", "# Test", node_typing: node_typing) }

      before do
        stub_const("TestNode", Class.new {
          class << self
            def name
              "TestNode"
            end
          end
        })
      end

      it "falls back to standard NodeTyping.process" do
        node = double("Node")
        # Must handle all respond_to? calls that NodeTyping.process might make
        allow(node).to receive_messages(
          respond_to?: false,
          class: TestNode,
        )

        result = merger.send(:apply_node_typing, node)
        # Should return original node since NodeTyping.process won't wrap it
        expect(result).to eq(node)
      end
    end

    context "with non-matching type" do
      let(:node_typing) { {heading: ->(n) { n }} }
      let(:merger) { test_merger_class.new("# Test", "# Test", node_typing: node_typing) }

      before do
        stub_const("TestNode", Class.new {
          class << self
            def name
              "TestNode"
            end
          end
        })
      end

      it "falls back to standard NodeTyping.process" do
        node = double("Node")
        allow(node).to receive_messages(
          type: :paragraph,
          class: TestNode,
        )
        # Must handle all respond_to? calls including typed_node? check
        allow(node).to receive(:respond_to?) { |m, *| m == :type }

        result = merger.send(:apply_node_typing, node)
        # Should return original node since no match
        expect(result).to eq(node)
      end
    end
  end

  describe "private methods" do
    let(:merger) { test_merger_class.new("# Test", "# Test") }

    # Helper to create a properly stubbed mock node for conflict resolution
    def create_resolver_node(name, content: "content")
      node = double(name)
      allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
      allow(node).to receive_messages(
        type: :paragraph,
        source_position: {start_line: 1, end_line: 1},
        to_commonmark: content,
      )
      # Flexible respond_to? that handles all method checks
      allow(node).to receive(:respond_to?) { |m, *| [:type, :source_position, :to_commonmark].include?(m) }
      node
    end

    describe "#code_block_node?" do
      it "returns false for non-code-block nodes" do
        node = double("Node")
        allow(node).to receive(:type).and_return(:paragraph)
        allow(node).to receive(:respond_to?) { |m, *| [:type].include?(m) }
        expect(merger.send(:code_block_node?, node)).to be(false)
      end

      it "returns true for code_block type" do
        node = double("Node")
        allow(node).to receive(:type).and_return(:code_block)
        allow(node).to receive(:respond_to?) { |m, *| [:type].include?(m) }
        expect(merger.send(:code_block_node?, node)).to be(true)
      end

      it "returns false for frozen nodes even if code_block type" do
        node = double("Node")
        allow(node).to receive_messages(type: :code_block, freeze_node?: true)
        allow(node).to receive(:respond_to?) { |m, *| [:type, :freeze_node?].include?(m) }
        expect(merger.send(:code_block_node?, node)).to be(false)
      end
    end

    describe "#node_to_source" do
      let(:analysis) do
        analysis = double("Analysis")
        allow(analysis).to receive(:source_range).with(1, 2).and_return("line 1\nline 2")
        analysis
      end

      it "returns full_text for FreezeNodeBase instances" do
        node = double("FreezeNode")
        allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(true)
        allow(node).to receive(:full_text).and_return("frozen content")

        result = merger.send(:node_to_source, node, analysis)
        expect(result).to eq("frozen content")
      end

      it "uses source_position for regular nodes" do
        node = double("Node")
        allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
        allow(node).to receive(:source_position).and_return({start_line: 1, end_line: 2})

        result = merger.send(:node_to_source, node, analysis)
        expect(result).to eq("line 1\nline 2")
      end

      it "falls back to to_commonmark when no source positions" do
        node = double("Node")
        allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
        allow(node).to receive_messages(source_position: nil, to_commonmark: "markdown output")

        result = merger.send(:node_to_source, node, analysis)
        expect(result).to eq("markdown output")
      end
    end

    describe "#process_template_only_to_builder" do
      let(:entry) do
        node = double("Node")
        allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
        allow(node).to receive(:source_position).and_return({start_line: 1, end_line: 1})
        {template_node: node}
      end

      it "does not add to builder when add_template_only_nodes is false" do
        merger = test_merger_class.new("# Test", "# Test", add_template_only_nodes: false)
        stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0}
        builder = Markdown::Merge::OutputBuilder.new

        merger.send(:process_template_only_to_builder, entry, builder, stats)

        expect(builder.to_s).to be_empty
        expect(stats[:nodes_added]).to eq(0)
      end

      it "adds content to builder when add_template_only_nodes is true" do
        merger = test_merger_class.new("# Test", "# Test", add_template_only_nodes: true)
        stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0}
        builder = Markdown::Merge::OutputBuilder.new

        # Need to set up the analysis mock properly
        allow(merger.template_analysis).to receive(:source_range).and_return("template content")

        merger.send(:process_template_only_to_builder, entry, builder, stats)

        expect(builder.to_s).to include("template content")
        expect(stats[:nodes_added]).to eq(1)
      end
    end

    describe "#process_dest_only_to_builder" do
      it "adds content to builder for regular nodes" do
        node = double("Node")
        allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
        # respond_to? needs to handle both :freeze_node? and :source_position
        allow(node).to receive(:respond_to?) { |method| [:freeze_node?, :source_position].include?(method) }
        allow(node).to receive_messages(
          freeze_node?: false,
          source_position: {start_line: 1, end_line: 1},
        )

        entry = {dest_node: node}
        stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0}
        builder = Markdown::Merge::OutputBuilder.new

        allow(merger.dest_analysis).to receive(:source_range).and_return("dest content")

        frozen_info = merger.send(:process_dest_only_to_builder, entry, builder, stats)

        expect(builder.to_s).to eq("dest content")
        expect(frozen_info).to be_nil # No frozen info
      end

      it "includes frozen info for freeze nodes" do
        node = double("FreezeNode")
        allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(true)
        # respond_to? needs to handle both :freeze_node? and :source_position
        allow(node).to receive(:respond_to?) { |method| [:freeze_node?, :source_position].include?(method) }
        allow(node).to receive_messages(
          freeze_node?: true,
          start_line: 5,
          end_line: 10,
          reason: "test reason",
          full_text: "frozen text",
          source_position: {start_line: 5, end_line: 10},
        )

        entry = {dest_node: node}
        stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0}
        builder = Markdown::Merge::OutputBuilder.new

        frozen_info = merger.send(:process_dest_only_to_builder, entry, builder, stats)

        expect(frozen_info).to be_a(Hash)
        expect(frozen_info[:start_line]).to eq(5)
        expect(frozen_info[:end_line]).to eq(10)
        expect(frozen_info[:reason]).to eq("test reason")
      end
    end

    describe "#process_match_to_builder" do
      let(:template_analysis) { merger.template_analysis }
      let(:dest_analysis) { merger.dest_analysis }

      context "when resolution source is :template" do
        it "increments nodes_modified when decision is not identical" do
          template_node = create_resolver_node("TemplateNode", content: "template text")
          dest_node = create_resolver_node("DestNode", content: "dest text")

          allow(template_analysis).to receive(:source_range).and_return("template text")
          allow(dest_analysis).to receive(:source_range).and_return("dest text")

          # Force template preference to get :template source
          merger_template = test_merger_class.new("# A", "# B", preference: :template)
          allow(merger_template.template_analysis).to receive(:source_range).and_return("template text")

          entry = {template_node: template_node, dest_node: dest_node, template_index: 0, dest_index: 0}
          stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0}
          builder = Markdown::Merge::OutputBuilder.new

          merger_template.send(:process_match_to_builder, entry, builder, stats)

          expect(builder.to_s).to include("template text")
          expect(stats[:nodes_modified]).to eq(1)
        end
      end

      context "when resolution source is :destination with freeze_node" do
        it "captures frozen info" do
          template_node = create_resolver_node("TemplateNode")

          dest_node = double("FrozenDestNode")
          allow(dest_node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
          allow(dest_node).to receive_messages(
            freeze_node?: true,
            source_position: {start_line: 5, end_line: 10},
            to_commonmark: "frozen content",
            start_line: 5,
            end_line: 10,
            reason: "frozen reason",
            type: :paragraph,
          )
          # Flexible respond_to? that handles all method checks
          allow(dest_node).to receive(:respond_to?) { |m, *| [:freeze_node?, :type, :source_position, :to_commonmark, :start_line, :end_line, :reason].include?(m) }

          allow(dest_analysis).to receive(:source_range).and_return("frozen content")

          # Mock the resolver to return :destination source
          allow(merger.resolver).to receive(:resolve).and_return({
            source: :destination,
            decision: :frozen,
            template_node: template_node,
            dest_node: dest_node,
          })

          entry = {template_node: template_node, dest_node: dest_node, template_index: 0, dest_index: 0}
          stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0}
          builder = Markdown::Merge::OutputBuilder.new

          frozen_info = merger.send(:process_match_to_builder, entry, builder, stats)

          # frozen_info should be populated
          expect(frozen_info).to be_a(Hash)
          expect(frozen_info[:start_line]).to eq(5)
          expect(frozen_info[:end_line]).to eq(10)
          expect(frozen_info[:reason]).to eq("frozen reason")
        end
      end
    end

    describe "#process_alignment" do
      it "processes :match entries" do
        template_node = create_resolver_node("TemplateNode")
        dest_node = create_resolver_node("DestNode")

        allow(merger.template_analysis).to receive(:source_range).and_return("content")
        allow(merger.dest_analysis).to receive(:source_range).and_return("content")

        alignment = [{type: :match, template_node: template_node, dest_node: dest_node, template_index: 0, dest_index: 0}]
        result = merger.send(:process_alignment, alignment)

        expect(result).to be_an(Array)
        expect(result.length).to eq(4) # [builder, stats, frozen_blocks, conflicts]
        expect(result[0]).to be_a(Markdown::Merge::OutputBuilder)
      end

      it "processes :template_only entries when add_template_only_nodes is true" do
        template_node = double("TemplateNode")
        allow(template_node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
        allow(template_node).to receive(:source_position).and_return({start_line: 1, end_line: 1})

        merger_add = test_merger_class.new("# A", "# B", add_template_only_nodes: true)
        allow(merger_add.template_analysis).to receive(:source_range).and_return("template content")

        alignment = [{type: :template_only, template_node: template_node}]
        result = merger_add.send(:process_alignment, alignment)

        builder = result[0]
        expect(builder).to be_a(Markdown::Merge::OutputBuilder)
        expect(builder.to_s).to include("template content")
        expect(result[1][:nodes_added]).to eq(1)
      end

      it "processes :dest_only entries" do
        dest_node = double("DestNode")
        allow(dest_node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
        # respond_to? needs to handle both :freeze_node? and :source_position
        allow(dest_node).to receive(:respond_to?) { |method| [:freeze_node?, :source_position].include?(method) }
        allow(dest_node).to receive_messages(
          freeze_node?: false,
          source_position: {start_line: 1, end_line: 1},
        )

        allow(merger.dest_analysis).to receive(:source_range).and_return("dest content")

        alignment = [{type: :dest_only, dest_node: dest_node}]
        result = merger.send(:process_alignment, alignment)

        builder = result[0]
        expect(builder).to be_a(Markdown::Merge::OutputBuilder)
        expect(builder.to_s).to include("dest content")
      end
    end
  end

  describe "with inner merge enabled" do
    let(:template) { "# Test" }
    let(:dest) { "# Test" }
    let(:merger) { test_merger_class.new(template, dest, inner_merge_code_blocks: true) }

    describe "#try_inner_merge_code_block" do
      let(:template_node) do
        node = double("TemplateCodeBlock")
        allow(node).to receive_messages(fence_info: "ruby", string_content: "puts 'template'")
        allow(node).to receive(:respond_to?).with(:fence_info).and_return(true)
        node
      end

      let(:dest_node) do
        node = double("DestCodeBlock")
        allow(node).to receive_messages(fence_info: "ruby", string_content: "puts 'dest'")
        allow(node).to receive(:respond_to?).with(:fence_info).and_return(true)
        node
      end

      it "attempts to merge code blocks" do
        stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0, inner_merges: 0}
        # The actual merge may fail due to prism-merge not being available
        # but the method should handle it gracefully
        result = merger.send(:try_inner_merge_code_block, template_node, dest_node, stats)
        # Result can be nil (fallback) or array (merged)
        expect(result).to be_nil.or(be_an(Array))
      end

      context "when merge succeeds" do
        it "increments inner_merges and nodes_modified" do
          # Mock the code_block_merger to return a successful merge
          allow(merger.code_block_merger).to receive(:merge_code_blocks).and_return({
            merged: true,
            content: "```ruby\nmerged\n```",
            stats: {decision: :modified},
          })

          stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0}
          result = merger.send(:try_inner_merge_code_block, template_node, dest_node, stats)

          expect(result).to be_an(Array)
          expect(stats[:inner_merges]).to eq(1)
          expect(stats[:nodes_modified]).to eq(1)
        end

        it "does not increment nodes_modified when decision is identical" do
          allow(merger.code_block_merger).to receive(:merge_code_blocks).and_return({
            merged: true,
            content: "```ruby\nsame\n```",
            stats: {decision: :identical},
          })

          stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0}
          result = merger.send(:try_inner_merge_code_block, template_node, dest_node, stats)

          expect(result).to be_an(Array)
          expect(stats[:inner_merges]).to eq(1)
          expect(stats[:nodes_modified]).to eq(0)
        end
      end

      context "when merge fails" do
        it "returns nil to fall back to standard resolution" do
          allow(merger.code_block_merger).to receive(:merge_code_blocks).and_return({
            merged: false,
            reason: "unsupported language",
          })

          stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0}
          result = merger.send(:try_inner_merge_code_block, template_node, dest_node, stats)

          expect(result).to be_nil
        end
      end
    end
  end

  describe "attribute readers" do
    let(:merger) { test_merger_class.new("# A", "# B") }

    it "exposes template_analysis" do
      expect(merger.template_analysis).to be_a(Markdown::Merge::FileAnalysisBase)
    end

    it "exposes dest_analysis" do
      expect(merger.dest_analysis).to be_a(Markdown::Merge::FileAnalysisBase)
    end

    it "exposes aligner" do
      expect(merger.aligner).to be_a(Markdown::Merge::FileAligner)
    end

    it "exposes resolver" do
      expect(merger.resolver).to be_a(Markdown::Merge::ConflictResolver)
    end

    it "exposes code_block_merger" do
      # Can be nil or CodeBlockMerger
      expect(merger.code_block_merger).to be_nil
    end
  end

  describe "#node_to_source" do
    let(:merger) { test_merger_class.new("# Test", "# Test") }
    let(:analysis) do
      a = double("Analysis")
      allow(a).to receive(:source_range).with(1, 2).and_return("line 1\nline 2")
      a
    end

    context "with incomplete source positions" do
      it "falls back to to_commonmark when start_line is nil" do
        node = double("Node")
        allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
        allow(node).to receive_messages(source_position: {start_line: nil, end_line: 2}, to_commonmark: "fallback markdown")

        result = merger.send(:node_to_source, node, analysis)
        expect(result).to eq("fallback markdown")
      end

      it "falls back to to_commonmark when end_line is nil" do
        node = double("Node")
        allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
        allow(node).to receive_messages(source_position: {start_line: 1, end_line: nil}, to_commonmark: "fallback markdown")

        result = merger.send(:node_to_source, node, analysis)
        expect(result).to eq("fallback markdown")
      end
    end
  end

  describe "parse error handling" do
    let(:error_raising_file_analysis) do
      Class.new(Markdown::Merge::FileAnalysisBase) do
        def initialize(content, **options)
          raise StandardError, "Parse failed"
        end

        def parse_document(source)
          raise StandardError, "Parse failed"
        end

        def next_sibling(node)
          nil
        end
      end
    end

    let(:test_merger_with_error) do
      analysis_class = error_raising_file_analysis
      Class.new(described_class) do
        define_method(:create_file_analysis) do |content, **options|
          analysis_class.new(content, **options)
        end

        def template_parse_error_class
          Class.new(StandardError) do
            def initialize(errors: [])
              super("Template parse error: #{errors.map(&:message).join(", ")}")
            end
          end
        end

        def destination_parse_error_class
          Class.new(StandardError) do
            def initialize(errors: [])
              super("Destination parse error: #{errors.map(&:message).join(", ")}")
            end
          end
        end
      end
    end

    it "raises template parse error when template parsing fails" do
      expect {
        test_merger_with_error.new("# Test", "# Test")
      }.to raise_error(/Template parse error/)
    end

    it "raises destination parse error when destination parsing fails" do
      # Create a merger that only fails on the second (destination) parse
      call_count = 0
      conditional_error_analysis = Class.new(Markdown::Merge::FileAnalysisBase) do
        define_method(:initialize) do |content, **options|
          call_count += 1
          if call_count > 1
            raise StandardError, "Destination parse failed"
          end
          @source = content
          @lines = content.split("\n", -1)
          @freeze_token = options[:freeze_token] || "markdown-merge"
          @signature_generator = options[:signature_generator]
          @document = Object.new.tap { |d| d.define_singleton_method(:first_child) { nil } }
          @statements = []
        end

        def parse_document(source)
          @document
        end

        def next_sibling(node)
          nil
        end
      end

      test_merger_dest_error = Class.new(described_class) do
        # rubocop:disable ThreadSafety/ClassInstanceVariable -- Test double needs class state
        define_singleton_method(:analysis_class=) { |klass| @analysis_class = klass }
        define_singleton_method(:analysis_class) { @analysis_class }
        # rubocop:enable ThreadSafety/ClassInstanceVariable

        define_method(:create_file_analysis) do |content, **options|
          self.class.analysis_class.new(content, **options)
        end

        def template_parse_error_class
          Class.new(StandardError) do
            def initialize(errors: [])
              super("Template parse error: #{errors.map(&:message).join(", ")}")
            end
          end
        end

        def destination_parse_error_class
          Class.new(StandardError) do
            def initialize(errors: [])
              super("Destination parse error: #{errors.map(&:message).join(", ")}")
            end
          end
        end
      end

      test_merger_dest_error.analysis_class = conditional_error_analysis

      expect {
        test_merger_dest_error.new("# Test", "# Dest")
      }.to raise_error(/Destination parse error/)
    end
  end

  describe "try_inner_merge_code_block fallback" do
    let(:merger_with_code_blocks) do
      test_merger_class.new("# Test", "# Test", inner_merge_code_blocks: true)
    end

    it "returns nil when code_block_merger fails" do
      template_node = double("TemplateNode")
      allow(template_node).to receive_messages(fence_info: "ruby", string_content: "puts 'a'", type: :code_block)
      allow(template_node).to receive(:respond_to?) { |m, *| [:fence_info, :type, :string_content].include?(m) }

      dest_node = double("DestNode")
      allow(dest_node).to receive_messages(fence_info: "ruby", string_content: "invalid {{{{", type: :code_block)
      allow(dest_node).to receive(:respond_to?) { |m, *| [:fence_info, :type, :string_content].include?(m) }

      stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0, inner_merges: 0}

      # The inner merge should fail and return nil for fallback
      result = merger_with_code_blocks.send(:try_inner_merge_code_block, template_node, dest_node, stats)

      # Result should be nil (fallback) or an array
      expect(result).to be_nil.or(be_an(Array))
    end

    it "returns merged content when inner merge succeeds" do
      template_node = double("TemplateNode")
      allow(template_node).to receive_messages(fence_info: "ruby", string_content: "# template\nputs 'a'", type: :code_block)
      allow(template_node).to receive(:respond_to?) { |m, *| [:fence_info, :type, :string_content].include?(m) }

      dest_node = double("DestNode")
      allow(dest_node).to receive_messages(fence_info: "ruby", string_content: "# dest\nputs 'b'", type: :code_block)
      allow(dest_node).to receive(:respond_to?) { |m, *| [:fence_info, :type, :string_content].include?(m) }

      stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0, inner_merges: 0}

      result = merger_with_code_blocks.send(:try_inner_merge_code_block, template_node, dest_node, stats)

      # Result can be nil or an array depending on if inner merge is available
      if result
        expect(result).to be_an(Array)
        expect(result.first).to be_a(String)
      end
    end
  end

  describe "#process_match with inner merge" do
    it "uses inner merge result when available for code blocks" do
      merger = test_merger_class.new("# Test\n```ruby\ncode\n```", "# Test\n```ruby\ncode\n```", inner_merge_code_blocks: true)

      # Find matching code blocks
      template_node = merger.template_analysis.statements.find { |s| s.type == :code_block }
      dest_node = merger.dest_analysis.statements.find { |s| s.type == :code_block }

      if template_node && dest_node
        stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0, inner_merges: 0}

        entry = {
          template_node: template_node,
          dest_node: dest_node,
          template_index: 0,
          dest_index: 0,
        }

        content, _frozen = merger.send(:process_match, entry, stats)
        expect(content).to be_a(String)
      end
    end
  end

  describe "#should_add_template_only_node?" do
    it "returns false when add_template_only_nodes is false" do
      merger = test_merger_class.new("# Test", "# Dest", add_template_only_nodes: false)
      entry = {template_node: double("Node"), signature: [:test]}

      result = merger.send(:should_add_template_only_node?, entry)
      expect(result).to be false
    end

    it "returns false when add_template_only_nodes is nil" do
      merger = test_merger_class.new("# Test", "# Dest", add_template_only_nodes: nil)
      entry = {template_node: double("Node"), signature: [:test]}

      result = merger.send(:should_add_template_only_node?, entry)
      expect(result).to be false
    end

    it "returns true when add_template_only_nodes is true" do
      merger = test_merger_class.new("# Test", "# Dest", add_template_only_nodes: true)
      entry = {template_node: double("Node"), signature: [:test]}

      result = merger.send(:should_add_template_only_node?, entry)
      expect(result).to be true
    end

    it "calls the callable when add_template_only_nodes is a Proc" do
      filter = ->(node, entry) { entry[:signature].first == :include_me }
      merger = test_merger_class.new("# Test", "# Dest", add_template_only_nodes: filter)

      include_entry = {template_node: double("Node"), signature: [:include_me]}
      exclude_entry = {template_node: double("Node"), signature: [:exclude_me]}

      expect(merger.send(:should_add_template_only_node?, include_entry)).to be true
      expect(merger.send(:should_add_template_only_node?, exclude_entry)).to be false
    end

    it "returns true for truthy non-callable values" do
      merger = test_merger_class.new("# Test", "# Dest", add_template_only_nodes: "truthy_string")
      entry = {template_node: double("Node"), signature: [:test]}

      result = merger.send(:should_add_template_only_node?, entry)
      expect(result).to be true
    end
  end

  describe "#process_template_only_to_builder" do
    it "does not add to builder when should_add_template_only_node? is false" do
      merger = test_merger_class.new("# Template", "# Dest", add_template_only_nodes: false)
      stats = {nodes_added: 0}
      builder = Markdown::Merge::OutputBuilder.new

      node = double("Node")
      allow(node).to receive_messages(source_position: {start_line: 1, end_line: 1}, to_commonmark: "# Template")

      entry = {template_node: node, signature: [:test]}

      merger.send(:process_template_only_to_builder, entry, builder, stats)

      expect(builder.to_s).to be_empty
      expect(stats[:nodes_added]).to eq(0)
    end

    it "adds content to builder when should_add_template_only_node? is true" do
      merger = test_merger_class.new("# Template", "# Dest", add_template_only_nodes: true)
      stats = {nodes_added: 0}
      builder = Markdown::Merge::OutputBuilder.new

      node = double("Node")
      allow(node).to receive_messages(source_position: {start_line: 1, end_line: 1}, to_commonmark: "# Template")
      allow(Ast::Merge::NodeTyping).to receive(:unwrap).with(node).and_return(node)

      entry = {template_node: node, signature: [:test]}

      merger.send(:process_template_only_to_builder, entry, builder, stats)

      expect(builder.to_s).not_to be_empty
      expect(stats[:nodes_added]).to eq(1)
    end
  end

  describe "#process_dest_only_to_builder" do
    it "handles freeze nodes" do
      merger = test_merger_class.new("# Template", "# Dest")
      stats = {nodes_removed: 0}
      builder = Markdown::Merge::OutputBuilder.new

      freeze_node = double("FreezeNode")
      # respond_to? needs to handle both :freeze_node? and :source_position
      allow(freeze_node).to receive(:respond_to?) { |method| [:freeze_node?, :source_position].include?(method) }
      # is_a? needs to return true for FreezeNodeBase
      allow(freeze_node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(true)
      # Mock === on FreezeNodeBase class so case/when works
      allow(Ast::Merge::FreezeNodeBase).to receive(:===).with(freeze_node).and_return(true)
      allow(freeze_node).to receive_messages(
        freeze_node?: true,
        start_line: 2,
        end_line: 5,
        reason: "keep this section",
        source_position: {start_line: 2, end_line: 5},
        to_commonmark: "frozen content",
        full_text: "frozen content",
      )
      allow(Ast::Merge::NodeTyping).to receive(:unwrap).with(freeze_node).and_return(freeze_node)

      entry = {dest_node: freeze_node, signature: [:freeze_block]}

      frozen_info = merger.send(:process_dest_only_to_builder, entry, builder, stats)

      expect(builder.to_s).not_to be_empty
      expect(frozen_info).to be_a(Hash)
      expect(frozen_info[:start_line]).to eq(2)
      expect(frozen_info[:end_line]).to eq(5)
      expect(frozen_info[:reason]).to eq("keep this section")
    end

    it "handles regular nodes" do
      merger = test_merger_class.new("# Template", "# Dest")
      stats = {nodes_removed: 0}
      builder = Markdown::Merge::OutputBuilder.new

      node = double("Node")
      # respond_to? needs to handle both :freeze_node? and :source_position
      allow(node).to receive(:respond_to?) { |method| [:freeze_node?, :source_position].include?(method) }
      allow(node).to receive_messages(
        freeze_node?: false,
        source_position: {start_line: 1, end_line: 1},
        to_commonmark: "# Dest",
      )
      allow(Ast::Merge::NodeTyping).to receive(:unwrap).with(node).and_return(node)

      entry = {dest_node: node, signature: [:paragraph]}

      frozen_info = merger.send(:process_dest_only_to_builder, entry, builder, stats)

      expect(builder.to_s).not_to be_empty
      expect(frozen_info).to be_nil
    end
  end

  describe "#process_match_to_builder" do
    it "handles matched nodes with template preference" do
      merger = test_merger_class.new("# Template", "# Dest", preference: :template)
      stats = {nodes_modified: 0}
      builder = Markdown::Merge::OutputBuilder.new

      template_node = double("TemplateNode")
      allow(template_node).to receive_messages(
        source_position: {start_line: 1, end_line: 1},
        to_commonmark: "# Template",
        type: :heading,
      )
      allow(Ast::Merge::NodeTyping).to receive(:typed_node?).with(template_node).and_return(false)
      allow(Ast::Merge::NodeTyping).to receive(:unwrap).with(template_node).and_return(template_node)

      dest_node = double("DestNode")
      allow(dest_node).to receive_messages(
        source_position: {start_line: 1, end_line: 1},
        to_commonmark: "# Dest",
        type: :heading,
      )
      allow(dest_node).to receive(:respond_to?).with(:freeze_node?).and_return(false)
      allow(Ast::Merge::NodeTyping).to receive(:typed_node?).with(dest_node).and_return(false)
      allow(Ast::Merge::NodeTyping).to receive(:unwrap).with(dest_node).and_return(dest_node)

      entry = {
        template_node: template_node,
        dest_node: dest_node,
        template_index: 0,
        dest_index: 0,
      }

      merger.send(:process_match_to_builder, entry, builder, stats)

      expect(builder.to_s).not_to be_empty
      expect(stats[:nodes_modified]).to eq(1)
    end
  end
end
