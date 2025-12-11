# frozen_string_literal: true

RSpec.describe Markdown::Merge::FreezeNode do
  let(:basic_freeze_node) do
    described_class.new(
      start_line: 1,
      end_line: 5,
      content: "## Frozen Section\n\nFrozen content.",
      start_marker: "<!-- markdown-merge:freeze -->",
      end_marker: "<!-- markdown-merge:unfreeze -->",
      nodes: [],
      reason: nil,
    )
  end

  let(:freeze_node_with_reason) do
    described_class.new(
      start_line: 10,
      end_line: 15,
      content: "Custom content",
      start_marker: "<!-- markdown-merge:freeze Custom reason -->",
      end_marker: "<!-- markdown-merge:unfreeze -->",
      nodes: [],
      reason: "Custom reason",
    )
  end

  describe "#initialize" do
    it "sets start_line" do
      expect(basic_freeze_node.start_line).to eq(1)
    end

    it "sets end_line" do
      expect(basic_freeze_node.end_line).to eq(5)
    end

    it "sets content" do
      expect(basic_freeze_node.content).to eq("## Frozen Section\n\nFrozen content.")
    end

    it "sets start_marker" do
      expect(basic_freeze_node.start_marker).to eq("<!-- markdown-merge:freeze -->")
    end

    it "sets end_marker" do
      expect(basic_freeze_node.end_marker).to eq("<!-- markdown-merge:unfreeze -->")
    end

    it "sets nodes" do
      expect(basic_freeze_node.nodes).to eq([])
    end

    it "sets reason when provided" do
      expect(freeze_node_with_reason.reason).to eq("Custom reason")
    end

    it "sets reason to nil when not provided" do
      expect(basic_freeze_node.reason).to be_nil
    end
  end

  describe "#signature" do
    it "returns freeze_block signature" do
      sig = basic_freeze_node.signature
      expect(sig.first).to eq(:freeze_block)
    end

    it "includes content hash" do
      sig = basic_freeze_node.signature
      expect(sig.last).to be_a(String)
      expect(sig.last.length).to eq(16)
    end

    it "returns same signature for same content" do
      node1 = described_class.new(
        start_line: 1,
        end_line: 3,
        content: "Same content",
        start_marker: "<!-- markdown-merge:freeze -->",
        end_marker: "<!-- markdown-merge:unfreeze -->",
      )
      node2 = described_class.new(
        start_line: 10,
        end_line: 13,
        content: "Same content",
        start_marker: "<!-- markdown-merge:freeze -->",
        end_marker: "<!-- markdown-merge:unfreeze -->",
      )
      expect(node1.signature).to eq(node2.signature)
    end

    it "returns different signature for different content" do
      node1 = described_class.new(
        start_line: 1,
        end_line: 3,
        content: "Content A",
        start_marker: "<!-- markdown-merge:freeze -->",
        end_marker: "<!-- markdown-merge:unfreeze -->",
      )
      node2 = described_class.new(
        start_line: 1,
        end_line: 3,
        content: "Content B",
        start_marker: "<!-- markdown-merge:freeze -->",
        end_marker: "<!-- markdown-merge:unfreeze -->",
      )
      expect(node1.signature).not_to eq(node2.signature)
    end
  end

  describe "#full_text" do
    it "returns complete freeze block with markers" do
      full = basic_freeze_node.full_text
      expect(full).to include("<!-- markdown-merge:freeze -->")
      expect(full).to include("<!-- markdown-merge:unfreeze -->")
      expect(full).to include("Frozen content")
    end

    it "has markers on separate lines from content" do
      full = basic_freeze_node.full_text
      lines = full.split("\n")
      expect(lines.first).to eq("<!-- markdown-merge:freeze -->")
      expect(lines.last).to eq("<!-- markdown-merge:unfreeze -->")
    end
  end

  describe "#line_count" do
    it "returns correct line count" do
      expect(basic_freeze_node.line_count).to eq(5)
    end

    it "returns 1 for single-line block" do
      node = described_class.new(
        start_line: 5,
        end_line: 5,
        content: "",
        start_marker: "<!-- markdown-merge:freeze -->",
        end_marker: "<!-- markdown-merge:unfreeze -->",
      )
      expect(node.line_count).to eq(1)
    end
  end

  describe "#contains_type?" do
    let(:mock_node) { double("Node", type: :heading) }
    let(:node_with_nodes) do
      described_class.new(
        start_line: 1,
        end_line: 5,
        content: "Content",
        start_marker: "<!-- markdown-merge:freeze -->",
        end_marker: "<!-- markdown-merge:unfreeze -->",
        nodes: [mock_node],
      )
    end

    it "returns true when node type exists" do
      expect(node_with_nodes.contains_type?(:heading)).to be true
    end

    it "returns false when node type does not exist" do
      expect(node_with_nodes.contains_type?(:paragraph)).to be false
    end

    it "returns false when nodes is empty" do
      expect(basic_freeze_node.contains_type?(:heading)).to be false
    end
  end

  describe "#inspect" do
    it "includes class name" do
      result = basic_freeze_node.inspect
      expect(result).to include("Markdown::Merge::FreezeNode")
    end

    it "includes line range" do
      result = basic_freeze_node.inspect
      expect(result).to include("lines=1..5")
    end

    it "includes node count" do
      result = basic_freeze_node.inspect
      expect(result).to include("nodes=0")
    end

    it "includes reason" do
      result = freeze_node_with_reason.inspect
      expect(result).to include("Custom reason")
    end
  end

  describe "#freeze_node?" do
    it "returns true" do
      expect(basic_freeze_node.freeze_node?).to be true
    end
  end

  describe "inheritance" do
    it "inherits from Ast::Merge::FreezeNodeBase" do
      expect(described_class.ancestors).to include(Ast::Merge::FreezeNodeBase)
    end
  end

  describe ".pattern_for" do
    it "returns pattern for html_comment type" do
      pattern = described_class.pattern_for(:html_comment, "markdown-merge")
      expect(pattern).to be_a(Regexp)
    end

    it "matches freeze marker" do
      pattern = described_class.pattern_for(:html_comment, "markdown-merge")
      match = "<!-- markdown-merge:freeze -->".match(pattern)
      expect(match).not_to be_nil
      expect(match[1]).to eq("freeze")
    end

    it "matches unfreeze marker" do
      pattern = described_class.pattern_for(:html_comment, "markdown-merge")
      match = "<!-- markdown-merge:unfreeze -->".match(pattern)
      expect(match).not_to be_nil
      expect(match[1]).to eq("unfreeze")
    end

    it "captures reason" do
      pattern = described_class.pattern_for(:html_comment, "markdown-merge")
      match = "<!-- markdown-merge:freeze My reason -->".match(pattern)
      expect(match).not_to be_nil
      expect(match[2]).to eq("My reason")
    end
  end
end
