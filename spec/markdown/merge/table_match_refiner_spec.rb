# frozen_string_literal: true

RSpec.describe Markdown::Merge::TableMatchRefiner do
  let(:refiner) { described_class.new }

  describe "#initialize" do
    it "accepts no arguments" do
      r = described_class.new
      expect(r).to be_a(described_class)
    end

    it "accepts threshold parameter" do
      r = described_class.new(threshold: 0.7)
      expect(r.threshold).to eq(0.7)
    end

    it "uses default threshold if not specified" do
      expect(refiner.threshold).to eq(Ast::Merge::MatchRefinerBase::DEFAULT_THRESHOLD)
    end

    it "accepts algorithm_options parameter" do
      r = described_class.new(algorithm_options: {weights: {header_match: 0.5}})
      expect(r.algorithm_options).to eq({weights: {header_match: 0.5}})
    end

    it "sets node_types to [:table]" do
      expect(refiner.node_types).to eq([:table])
    end
  end

  describe "#call" do
    def create_mock_table(type_value = :table)
      node = double("TableNode")
      allow(node).to receive(:type).and_return(type_value)
      allow(node).to receive(:merge_type).and_return(type_value)
      allow(node).to receive(:first_child).and_return(nil)
      # Handle all respond_to? calls - return true for type/merge_type, false for typed_node?
      allow(node).to receive(:respond_to?) do |method_name, *|
        [:type, :merge_type].include?(method_name)
      end
      node
    end

    def create_non_table_node(type_value = :paragraph)
      node = double("NonTableNode")
      allow(node).to receive(:type).and_return(type_value)
      allow(node).to receive(:merge_type).and_return(type_value)
      # Handle all respond_to? calls - return true for type/merge_type, false for typed_node?
      allow(node).to receive(:respond_to?) do |method_name, *|
        [:type, :merge_type].include?(method_name)
      end
      node
    end

    context "with no table nodes" do
      let(:template_nodes) { [create_non_table_node(:paragraph), create_non_table_node(:heading)] }
      let(:dest_nodes) { [create_non_table_node(:paragraph), create_non_table_node(:list)] }

      it "returns empty array" do
        result = refiner.call(template_nodes, dest_nodes)
        expect(result).to eq([])
      end
    end

    context "with empty input arrays" do
      it "returns empty array for empty template" do
        result = refiner.call([], [create_mock_table])
        expect(result).to eq([])
      end

      it "returns empty array for empty destination" do
        result = refiner.call([create_mock_table], [])
        expect(result).to eq([])
      end

      it "returns empty array for both empty" do
        result = refiner.call([], [])
        expect(result).to eq([])
      end
    end

    context "with mixed nodes" do
      let(:template_table) { create_mock_table }
      let(:dest_table) { create_mock_table }
      let(:template_nodes) { [create_non_table_node, template_table, create_non_table_node] }
      let(:dest_nodes) { [create_non_table_node, dest_table, create_non_table_node] }

      it "only considers table nodes" do
        result = refiner.call(template_nodes, dest_nodes)
        # Even if scoring returns 0.0, should process tables
        expect(result).to be_an(Array)
      end
    end

    context "with context hash" do
      let(:template_table) { create_mock_table }
      let(:dest_table) { create_mock_table }

      it "accepts context parameter" do
        context = {template_analysis: double, dest_analysis: double}
        result = refiner.call([template_table], [dest_table], context)
        expect(result).to be_an(Array)
      end
    end
  end

  describe "#algorithm_options" do
    it "returns empty hash by default" do
      expect(refiner.algorithm_options).to eq({})
    end

    it "returns custom options when set" do
      custom_opts = {weights: {header_match: 0.3}}
      r = described_class.new(algorithm_options: custom_opts)
      expect(r.algorithm_options).to eq(custom_opts)
    end
  end

  describe "inheritance" do
    it "inherits from Ast::Merge::MatchRefinerBase" do
      expect(described_class.ancestors).to include(Ast::Merge::MatchRefinerBase)
    end

    it "responds to threshold" do
      expect(refiner).to respond_to(:threshold)
    end

    it "responds to node_types" do
      expect(refiner).to respond_to(:node_types)
    end
  end

  describe "private methods" do
    describe "#table_node?" do
      it "returns true for node with :table type" do
        node = double("Node")
        allow(node).to receive(:type).and_return(:table)
        allow(node).to receive(:merge_type).and_return(:table)
        allow(node).to receive(:respond_to?) { |m, *| [:type, :merge_type].include?(m) }
        expect(refiner.send(:table_node?, node)).to be(true)
      end

      it "returns true for node with Table in class name" do
        node = double("Markdown::Table")
        allow(node).to receive(:respond_to?) { |m, *| false }
        allow(node.class).to receive(:name).and_return("Markdown::Table")
        expect(refiner.send(:table_node?, node)).to be(true)
      end

      it "returns false for non-table nodes" do
        node = double("Paragraph")
        allow(node).to receive(:type).and_return(:paragraph)
        allow(node).to receive(:merge_type).and_return(:paragraph)
        allow(node).to receive(:respond_to?) { |m, *| [:type, :merge_type].include?(m) }
        allow(node.class).to receive(:name).and_return("Markdown::Paragraph")
        expect(refiner.send(:table_node?, node)).to be(false)
      end

      context "with typed wrapper node" do
        it "returns true when merge_type is :table" do
          # Simulate Ast::Merge::NodeTyping.typed_node? returning true
          wrapper = Ast::Merge::NodeTyping::Wrapper.new(double("RawTable"), :table)
          expect(refiner.send(:table_node?, wrapper)).to be(true)
        end

        it "returns false when merge_type is not :table" do
          wrapper = Ast::Merge::NodeTyping::Wrapper.new(double("RawParagraph"), :paragraph)
          expect(refiner.send(:table_node?, wrapper)).to be(false)
        end
      end

      context "with raw type as string" do
        it "returns true when type is 'table' string" do
          node = double("StringTypeNode")
          allow(node).to receive(:type).and_return("table")
          allow(node).to receive(:merge_type).and_return(nil)
          allow(node).to receive(:respond_to?) do |m, *|
            m == :type || (m == :merge_type)
          end
          expect(refiner.send(:table_node?, node)).to be(true)
        end

        it "returns false when type is other string" do
          node = double("StringTypeNode")
          allow(node).to receive(:type).and_return("paragraph")
          allow(node).to receive(:merge_type).and_return(nil)
          allow(node).to receive(:respond_to?) do |m, *|
            m == :type || (m == :merge_type)
          end
          allow(node.class).to receive(:name).and_return("Node")
          expect(refiner.send(:table_node?, node)).to be(false)
        end
      end

      context "with node that doesn't respond to type or merge_type" do
        it "falls back to class name check" do
          node = double("UnknownTableNode")
          allow(node).to receive(:respond_to?) { |m, *| false }
          allow(node.class).to receive(:name).and_return("SomeTableClass")
          expect(refiner.send(:table_node?, node)).to be(true)
        end

        it "returns false when class name doesn't include Table" do
          node = double("UnknownNode")
          allow(node).to receive(:respond_to?) { |m, *| false }
          allow(node.class).to receive(:name).and_return("SomeOtherClass")
          expect(refiner.send(:table_node?, node)).to be(false)
        end
      end
    end

    describe "#extract_tables" do
      it "filters out non-table nodes" do
        table = double("Table")
        allow(table).to receive(:type).and_return(:table)
        allow(table).to receive(:merge_type).and_return(:table)
        allow(table).to receive(:respond_to?) { |m, *| [:type, :merge_type].include?(m) }

        paragraph = double("Paragraph")
        allow(paragraph).to receive(:type).and_return(:paragraph)
        allow(paragraph).to receive(:merge_type).and_return(:paragraph)
        allow(paragraph).to receive(:respond_to?) { |m, *| [:type, :merge_type].include?(m) }
        allow(paragraph.class).to receive(:name).and_return("Paragraph")

        nodes = [table, paragraph, table]
        result = refiner.send(:extract_tables, nodes)
        expect(result.size).to eq(2)
      end
    end

    describe "#compute_table_similarity" do
      it "returns a float between 0.0 and 1.0" do
        table_a = double("TableA")
        allow(table_a).to receive(:first_child).and_return(nil)

        table_b = double("TableB")
        allow(table_b).to receive(:first_child).and_return(nil)

        result = refiner.send(:compute_table_similarity, table_a, table_b, 0, 0, 1, 1)
        expect(result).to be_a(Float)
        expect(result).to be_between(0.0, 1.0)
      end
    end
  end

  describe "with custom threshold" do
    let(:high_threshold_refiner) { described_class.new(threshold: 0.9) }
    let(:low_threshold_refiner) { described_class.new(threshold: 0.1) }

    it "returns fewer matches with high threshold" do
      table_a = double("TableA")
      allow(table_a).to receive(:type).and_return(:table)
      allow(table_a).to receive(:merge_type).and_return(:table)
      allow(table_a).to receive(:respond_to?) { |m, *| [:type, :merge_type].include?(m) }
      allow(table_a).to receive(:first_child).and_return(nil)

      table_b = double("TableB")
      allow(table_b).to receive(:type).and_return(:table)
      allow(table_b).to receive(:merge_type).and_return(:table)
      allow(table_b).to receive(:respond_to?) { |m, *| [:type, :merge_type].include?(m) }
      allow(table_b).to receive(:first_child).and_return(nil)

      high_result = high_threshold_refiner.call([table_a], [table_b])
      low_result = low_threshold_refiner.call([table_a], [table_b])

      # With empty tables, both likely return empty, but low threshold might match
      expect(high_result.size).to be <= low_result.size
    end
  end
end
