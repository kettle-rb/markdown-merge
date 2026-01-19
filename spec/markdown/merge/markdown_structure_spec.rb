# frozen_string_literal: true

RSpec.describe Markdown::Merge::MarkdownStructure do
  describe ".needs_blank_before?" do
    it "returns true for headings" do
      expect(described_class.needs_blank_before?(:heading)).to be true
    end

    it "returns true for tables" do
      expect(described_class.needs_blank_before?(:table)).to be true
    end

    it "returns true for code blocks" do
      expect(described_class.needs_blank_before?(:code_block)).to be true
    end

    it "returns true for thematic breaks" do
      expect(described_class.needs_blank_before?(:thematic_break)).to be true
    end

    it "returns true for lists" do
      expect(described_class.needs_blank_before?(:list)).to be true
    end

    it "returns true for block quotes" do
      expect(described_class.needs_blank_before?(:block_quote)).to be true
    end

    it "returns false for paragraphs" do
      expect(described_class.needs_blank_before?(:paragraph)).to be false
    end

    it "returns false for link definitions" do
      expect(described_class.needs_blank_before?(:link_definition)).to be false
    end

    it "accepts string argument" do
      expect(described_class.needs_blank_before?("heading")).to be true
    end
  end

  describe ".needs_blank_after?" do
    it "returns true for headings" do
      expect(described_class.needs_blank_after?(:heading)).to be true
    end

    it "returns true for tables" do
      expect(described_class.needs_blank_after?(:table)).to be true
    end

    it "returns true for link definitions" do
      expect(described_class.needs_blank_after?(:link_definition)).to be true
    end

    it "returns false for paragraphs" do
      expect(described_class.needs_blank_after?(:paragraph)).to be false
    end

    it "accepts string argument" do
      expect(described_class.needs_blank_after?("heading")).to be true
    end
  end

  describe ".contiguous_type?" do
    it "returns true for link definitions" do
      expect(described_class.contiguous_type?(:link_definition)).to be true
    end

    it "returns false for headings" do
      expect(described_class.contiguous_type?(:heading)).to be false
    end

    it "returns false for paragraphs" do
      expect(described_class.contiguous_type?(:paragraph)).to be false
    end

    it "accepts string argument" do
      expect(described_class.contiguous_type?("link_definition")).to be true
    end
  end

  describe ".needs_blank_between?" do
    context "with nil types" do
      it "returns false when prev_type is nil" do
        expect(described_class.needs_blank_between?(nil, :heading)).to be false
      end

      it "returns false when next_type is nil" do
        expect(described_class.needs_blank_between?(:heading, nil)).to be false
      end

      it "returns false when both types are nil" do
        expect(described_class.needs_blank_between?(nil, nil)).to be false
      end
    end

    context "with contiguous types" do
      it "returns false between consecutive link definitions" do
        expect(described_class.needs_blank_between?(:link_definition, :link_definition)).to be false
      end
    end

    context "with types needing blank lines" do
      it "returns true after heading" do
        expect(described_class.needs_blank_between?(:heading, :paragraph)).to be true
      end

      it "returns true before heading" do
        expect(described_class.needs_blank_between?(:paragraph, :heading)).to be true
      end

      it "returns true between heading and table" do
        expect(described_class.needs_blank_between?(:heading, :table)).to be true
      end

      it "returns true between table and paragraph" do
        expect(described_class.needs_blank_between?(:table, :paragraph)).to be true
      end
    end

    context "with types not needing blank lines" do
      it "returns false between consecutive paragraphs" do
        # Paragraphs don't need blank before or after by themselves
        # (they're normal content)
        expect(described_class.needs_blank_between?(:paragraph, :paragraph)).to be false
      end
    end

    context "with string arguments" do
      it "accepts string arguments" do
        expect(described_class.needs_blank_between?("heading", "paragraph")).to be true
      end
    end
  end

  describe ".node_type" do
    context "with nil node" do
      it "returns nil" do
        expect(described_class.node_type(nil)).to be_nil
      end
    end

    context "with node responding to merge_type" do
      it "returns merge_type as symbol" do
        node = double("Node")
        allow(node).to receive(:respond_to?).with(:merge_type).and_return(true)
        allow(node).to receive(:merge_type).and_return(:heading)

        expect(described_class.node_type(node)).to eq(:heading)
      end

      it "converts string merge_type to symbol" do
        node = double("Node")
        allow(node).to receive(:respond_to?).with(:merge_type).and_return(true)
        allow(node).to receive(:merge_type).and_return("paragraph")

        expect(described_class.node_type(node)).to eq(:paragraph)
      end
    end

    context "with node responding only to type" do
      it "returns type as symbol" do
        node = double("Node")
        allow(node).to receive(:respond_to?).with(:merge_type).and_return(false)
        allow(node).to receive(:respond_to?).with(:type).and_return(true)
        allow(node).to receive(:type).and_return(:code_block)

        expect(described_class.node_type(node)).to eq(:code_block)
      end
    end

    context "with node not responding to either" do
      it "returns nil" do
        node = double("Node")
        allow(node).to receive(:respond_to?).with(:merge_type).and_return(false)
        allow(node).to receive(:respond_to?).with(:type).and_return(false)

        expect(described_class.node_type(node)).to be_nil
      end
    end
  end
end
