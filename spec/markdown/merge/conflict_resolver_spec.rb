# frozen_string_literal: true

require "ast/merge/rspec/shared_examples"

RSpec.describe Markdown::Merge::ConflictResolver do
  it_behaves_like "Ast::Merge::ConflictResolverBase" do
    let(:conflict_resolver_class) { described_class }
    let(:strategy) { :node }
    let(:build_conflict_resolver) do
      ->(preference:, template_analysis:, dest_analysis:, **opts) {
        described_class.new(
          preference: preference,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
          **opts
        )
      }
    end
    let(:build_mock_analysis) do
      -> { double("MockAnalysis") }
    end
  end

  it_behaves_like "Ast::Merge::ConflictResolverBase node strategy" do
    let(:conflict_resolver_class) { described_class }
    let(:build_conflict_resolver) do
      ->(preference:, template_analysis:, dest_analysis:, **opts) {
        described_class.new(
          preference: preference,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
          **opts
        )
      }
    end
    let(:build_mock_analysis) do
      -> { double("MockAnalysis") }
    end
  end

  # Helper to create a properly stubbed mock node
  def create_mock_node(name, content: "content", frozen: false, reason: nil)
    node = double(name)
    allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(frozen)
    allow(node).to receive_messages(source_position: {start_line: 1, end_line: 1}, to_commonmark: content)

    # Flexible respond_to? that handles all method checks
    known_methods = [:source_position, :to_commonmark]
    known_methods << :freeze_node? if frozen
    known_methods << :reason if frozen
    known_methods << :full_text if frozen

    allow(node).to receive(:respond_to?) do |method_name, *|
      known_methods.include?(method_name)
    end

    if frozen
      allow(node).to receive_messages(freeze_node?: true, reason: reason, full_text: content)
    end

    node
  end

  # Create mock analysis objects
  let(:mock_template_analysis) do
    analysis = double("TemplateAnalysis")
    allow(analysis).to receive(:source_range).and_return("template content")
    analysis
  end

  let(:mock_dest_analysis) do
    analysis = double("DestAnalysis")
    allow(analysis).to receive(:source_range).and_return("dest content")
    analysis
  end

  let(:resolver) do
    described_class.new(
      preference: :destination,
      template_analysis: mock_template_analysis,
      dest_analysis: mock_dest_analysis,
    )
  end

  describe "#initialize" do
    it "accepts preference parameter" do
      r = described_class.new(
        preference: :template,
        template_analysis: mock_template_analysis,
        dest_analysis: mock_dest_analysis,
      )
      expect(r).to be_a(described_class)
    end

    it "stores template_analysis" do
      expect(resolver.instance_variable_get(:@template_analysis)).to eq(mock_template_analysis)
    end

    it "stores dest_analysis" do
      expect(resolver.instance_variable_get(:@dest_analysis)).to eq(mock_dest_analysis)
    end
  end

  describe "#resolve" do
    let(:template_node) { create_mock_node("TemplateNode", content: "template") }
    let(:dest_node) { create_mock_node("DestNode", content: "dest") }

    it "returns a hash with resolution info" do
      result = resolver.resolve(template_node, dest_node, template_index: 0, dest_index: 0)
      expect(result).to be_a(Hash)
      expect(result).to have_key(:source)
      expect(result).to have_key(:decision)
    end

    context "with destination preference" do
      it "prefers destination when content differs" do
        result = resolver.resolve(template_node, dest_node, template_index: 0, dest_index: 0)
        expect(result[:source]).to eq(:destination)
      end
    end

    context "with template preference" do
      let(:template_pref_resolver) do
        described_class.new(
          preference: :template,
          template_analysis: mock_template_analysis,
          dest_analysis: mock_dest_analysis,
        )
      end

      it "prefers template when content differs" do
        result = template_pref_resolver.resolve(template_node, dest_node, template_index: 0, dest_index: 0)
        expect(result[:source]).to eq(:template)
      end
    end

    context "with identical content" do
      let(:identical_analysis) do
        analysis = double("Analysis")
        allow(analysis).to receive(:source_range).and_return("same content")
        analysis
      end

      let(:identical_resolver) do
        described_class.new(
          preference: :destination,
          template_analysis: identical_analysis,
          dest_analysis: identical_analysis,
        )
      end

      it "marks as identical" do
        result = identical_resolver.resolve(template_node, dest_node, template_index: 0, dest_index: 0)
        expect(result[:decision]).to eq(described_class::DECISION_IDENTICAL)
      end
    end

    context "with frozen destination node" do
      let(:frozen_node) { create_mock_node("FrozenNode", content: "frozen content", frozen: true, reason: "Custom reason") }

      it "returns frozen decision" do
        result = resolver.resolve(template_node, frozen_node, template_index: 0, dest_index: 0)
        expect(result[:decision]).to eq(described_class::DECISION_FROZEN)
      end

      it "uses destination source for frozen" do
        result = resolver.resolve(template_node, frozen_node, template_index: 0, dest_index: 0)
        expect(result[:source]).to eq(:destination)
      end

      it "includes reason" do
        result = resolver.resolve(template_node, frozen_node, template_index: 0, dest_index: 0)
        expect(result[:reason]).to eq("Custom reason")
      end
    end

    context "with frozen template node" do
      let(:frozen_template) { create_mock_node("FrozenTemplate", content: "frozen template", frozen: true, reason: nil) }

      it "returns frozen decision" do
        result = resolver.resolve(frozen_template, dest_node, template_index: 0, dest_index: 0)
        expect(result[:decision]).to eq(described_class::DECISION_FROZEN)
      end

      it "uses template source for frozen template" do
        result = resolver.resolve(frozen_template, dest_node, template_index: 0, dest_index: 0)
        expect(result[:source]).to eq(:template)
      end
    end
  end

  describe "#node_to_text (private)" do
    context "with FreezeNodeBase instance" do
      it "returns full_text" do
        freeze_node = double("FreezeNode")
        allow(freeze_node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(true)
        allow(freeze_node).to receive(:full_text).and_return("<!-- freeze -->\nFrozen content\n<!-- unfreeze -->")

        result = resolver.send(:node_to_text, freeze_node, mock_template_analysis)
        expect(result).to eq("<!-- freeze -->\nFrozen content\n<!-- unfreeze -->")
      end
    end

    context "with regular node with source_position" do
      it "returns source_range from analysis" do
        node = double("Node")
        allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
        allow(node).to receive(:source_position).and_return({start_line: 1, end_line: 3})
        allow(mock_template_analysis).to receive(:source_range).with(1, 3).and_return("line1\nline2\nline3")

        result = resolver.send(:node_to_text, node, mock_template_analysis)
        expect(result).to eq("line1\nline2\nline3")
      end
    end

    context "with node missing start_line" do
      it "falls back to to_commonmark" do
        node = double("Node")
        allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
        allow(node).to receive_messages(source_position: {start_line: nil, end_line: 3}, to_commonmark: "fallback markdown")

        result = resolver.send(:node_to_text, node, mock_template_analysis)
        expect(result).to eq("fallback markdown")
      end
    end

    context "with node missing end_line" do
      it "falls back to to_commonmark" do
        node = double("Node")
        allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
        allow(node).to receive_messages(source_position: {start_line: 1, end_line: nil}, to_commonmark: "fallback markdown")

        result = resolver.send(:node_to_text, node, mock_template_analysis)
        expect(result).to eq("fallback markdown")
      end
    end

    context "with node with nil source_position" do
      it "falls back to to_commonmark" do
        node = double("Node")
        allow(node).to receive(:is_a?).with(Ast::Merge::FreezeNodeBase).and_return(false)
        allow(node).to receive_messages(source_position: nil, to_commonmark: "fallback markdown")

        result = resolver.send(:node_to_text, node, mock_template_analysis)
        expect(result).to eq("fallback markdown")
      end
    end
  end

  describe "decision constants" do
    it "has DECISION_IDENTICAL from base class" do
      expect(described_class::DECISION_IDENTICAL).to eq(:identical)
    end

    it "has DECISION_FROZEN from base class" do
      expect(described_class::DECISION_FROZEN).to eq(:frozen)
    end

    it "has DECISION_DESTINATION from base class" do
      expect(described_class::DECISION_DESTINATION).to eq(:destination)
    end

    it "has DECISION_TEMPLATE from base class" do
      expect(described_class::DECISION_TEMPLATE).to eq(:template)
    end
  end

  describe "inheritance" do
    it "inherits from Ast::Merge::ConflictResolverBase" do
      expect(described_class.ancestors).to include(Ast::Merge::ConflictResolverBase)
    end
  end
end
