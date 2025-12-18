# frozen_string_literal: true

RSpec.describe Markdown::Merge::NodeTypeNormalizer do
  describe "default backend mappings" do
    describe "commonmarker" do
      it "is registered" do
        expect(described_class.backend_registered?(:commonmarker)).to be true
      end

      it "maps heading to heading (identity)" do
        expect(described_class.canonical_type(:heading, :commonmarker)).to eq(:heading)
      end

      it "maps block_quote to block_quote (identity)" do
        expect(described_class.canonical_type(:block_quote, :commonmarker)).to eq(:block_quote)
      end

      it "maps thematic_break to thematic_break (identity)" do
        expect(described_class.canonical_type(:thematic_break, :commonmarker)).to eq(:thematic_break)
      end

      it "maps html_block to html_block (identity)" do
        expect(described_class.canonical_type(:html_block, :commonmarker)).to eq(:html_block)
      end
    end

    describe "markly" do
      it "is registered" do
        expect(described_class.backend_registered?(:markly)).to be true
      end

      it "maps header to heading" do
        expect(described_class.canonical_type(:header, :markly)).to eq(:heading)
      end

      it "maps blockquote to block_quote" do
        expect(described_class.canonical_type(:blockquote, :markly)).to eq(:block_quote)
      end

      it "maps hrule to thematic_break" do
        expect(described_class.canonical_type(:hrule, :markly)).to eq(:thematic_break)
      end

      it "maps html to html_block" do
        expect(described_class.canonical_type(:html, :markly)).to eq(:html_block)
      end

      it "maps custom_block to custom_block (identity)" do
        expect(described_class.canonical_type(:custom_block, :markly)).to eq(:custom_block)
      end
    end
  end

  describe ".canonical_type" do
    it "returns the canonical type for known mappings" do
      expect(described_class.canonical_type(:header, :markly)).to eq(:heading)
    end

    it "passes through unknown types unchanged" do
      expect(described_class.canonical_type(:unknown_type, :markly)).to eq(:unknown_type)
    end

    it "passes through types for unregistered backends" do
      expect(described_class.canonical_type(:heading, :unknown_backend)).to eq(:heading)
    end
  end

  describe ".register_backend" do
    after do
      # Clean up test backend
      # Note: In real code we'd want a way to unregister, but for tests this is acceptable
    end

    it "registers a new backend" do
      described_class.register_backend(:test_backend, {foo: :bar})
      expect(described_class.backend_registered?(:test_backend)).to be true
    end

    it "freezes the mappings" do
      described_class.register_backend(:frozen_test, {foo: :bar})
      expect(described_class.mappings_for(:frozen_test)).to be_frozen
    end

    it "allows canonical type lookup for registered backend" do
      described_class.register_backend(:lookup_test, {custom_heading: :heading})
      expect(described_class.canonical_type(:custom_heading, :lookup_test)).to eq(:heading)
    end
  end

  describe ".wrap" do
    let(:mock_node) do
      double("Node", type: :header)
    end

    it "wraps a node with its canonical type" do
      wrapped = described_class.wrap(mock_node, :markly)

      expect(wrapped).to be_a(Ast::Merge::NodeTyping::Wrapper)
      expect(wrapped.merge_type).to eq(:heading)
    end

    it "delegates methods to the underlying node" do
      wrapped = described_class.wrap(mock_node, :markly)

      expect(wrapped.type).to eq(:header)
    end

    it "allows unwrapping to get original node" do
      wrapped = described_class.wrap(mock_node, :markly)

      expect(wrapped.unwrap).to eq(mock_node)
    end
  end

  describe ".registered_backends" do
    it "returns an array of backend symbols" do
      backends = described_class.registered_backends
      expect(backends).to be_an(Array)
      expect(backends).to include(:commonmarker, :markly)
    end
  end

  describe ".backend_registered?" do
    it "returns true for registered backends" do
      expect(described_class.backend_registered?(:commonmarker)).to be true
      expect(described_class.backend_registered?(:markly)).to be true
    end

    it "returns false for unregistered backends" do
      expect(described_class.backend_registered?(:nonexistent)).to be false
    end
  end

  describe ".mappings_for" do
    it "returns the mappings hash for a registered backend" do
      mappings = described_class.mappings_for(:commonmarker)
      expect(mappings).to be_a(Hash)
      expect(mappings[:heading]).to eq(:heading)
    end

    it "returns nil for unregistered backend" do
      expect(described_class.mappings_for(:nonexistent)).to be_nil
    end
  end

  describe ".canonical_types" do
    it "returns unique canonical types across all backends" do
      types = described_class.canonical_types
      expect(types).to be_an(Array)
      expect(types).to include(:heading, :paragraph, :code_block, :list, :block_quote)
    end

    it "removes duplicates" do
      types = described_class.canonical_types
      expect(types.uniq.size).to eq(types.size)
    end
  end
end

