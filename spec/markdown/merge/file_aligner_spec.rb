# frozen_string_literal: true

RSpec.describe Markdown::Merge::FileAligner do
  # Create mock analysis objects for testing
  let(:mock_template_analysis) do
    analysis = double("TemplateAnalysis")
    allow(analysis).to receive(:statements).and_return([])
    allow(analysis).to receive(:signature_at).and_return(nil)
    analysis
  end

  let(:mock_dest_analysis) do
    analysis = double("DestAnalysis")
    allow(analysis).to receive(:statements).and_return([])
    allow(analysis).to receive(:signature_at).and_return(nil)
    analysis
  end

  describe "#initialize" do
    it "stores template_analysis" do
      aligner = described_class.new(mock_template_analysis, mock_dest_analysis)
      expect(aligner.template_analysis).to eq(mock_template_analysis)
    end

    it "stores dest_analysis" do
      aligner = described_class.new(mock_template_analysis, mock_dest_analysis)
      expect(aligner.dest_analysis).to eq(mock_dest_analysis)
    end

    it "accepts match_refiner option" do
      refiner = double("Refiner")
      aligner = described_class.new(mock_template_analysis, mock_dest_analysis, match_refiner: refiner)
      expect(aligner.match_refiner).to eq(refiner)
    end

    it "defaults match_refiner to nil" do
      aligner = described_class.new(mock_template_analysis, mock_dest_analysis)
      expect(aligner.match_refiner).to be_nil
    end
  end

  describe "#align" do
    context "with empty files" do
      it "returns empty array for empty template and destination" do
        aligner = described_class.new(mock_template_analysis, mock_dest_analysis)
        result = aligner.align
        expect(result).to eq([])
      end
    end

    context "with matching signatures" do
      let(:template_node) { double("TemplateNode") }
      let(:dest_node) { double("DestNode") }

      let(:matching_template_analysis) do
        analysis = double("TemplateAnalysis")
        allow(analysis).to receive(:statements).and_return([template_node])
        allow(analysis).to receive(:signature_at).with(0).and_return([:heading, 1, "Title"])
        analysis
      end

      let(:matching_dest_analysis) do
        analysis = double("DestAnalysis")
        allow(analysis).to receive(:statements).and_return([dest_node])
        allow(analysis).to receive(:signature_at).with(0).and_return([:heading, 1, "Title"])
        analysis
      end

      it "creates match entries for matching signatures" do
        aligner = described_class.new(matching_template_analysis, matching_dest_analysis)
        result = aligner.align

        expect(result.size).to eq(1)
        expect(result.first[:type]).to eq(:match)
        expect(result.first[:template_node]).to eq(template_node)
        expect(result.first[:dest_node]).to eq(dest_node)
      end
    end

    context "with template-only nodes" do
      let(:template_node) { double("TemplateNode") }

      let(:template_only_analysis) do
        analysis = double("TemplateAnalysis")
        allow(analysis).to receive(:statements).and_return([template_node])
        allow(analysis).to receive(:signature_at).with(0).and_return([:paragraph, "abc123"])
        analysis
      end

      it "creates template_only entries" do
        aligner = described_class.new(template_only_analysis, mock_dest_analysis)
        result = aligner.align

        expect(result.size).to eq(1)
        expect(result.first[:type]).to eq(:template_only)
        expect(result.first[:template_node]).to eq(template_node)
        expect(result.first[:dest_node]).to be_nil
      end
    end

    context "with dest-only nodes" do
      let(:dest_node) { double("DestNode") }

      let(:dest_only_analysis) do
        analysis = double("DestAnalysis")
        allow(analysis).to receive(:statements).and_return([dest_node])
        allow(analysis).to receive(:signature_at).with(0).and_return([:paragraph, "xyz789"])
        analysis
      end

      it "creates dest_only entries" do
        aligner = described_class.new(mock_template_analysis, dest_only_analysis)
        result = aligner.align

        expect(result.size).to eq(1)
        expect(result.first[:type]).to eq(:dest_only)
        expect(result.first[:template_node]).to be_nil
        expect(result.first[:dest_node]).to eq(dest_node)
      end
    end

    context "sorting" do
      let(:template_nodes) { [double("T1"), double("T2")] }
      let(:dest_nodes) { [double("D1"), double("D2"), double("D3")] }

      let(:complex_template_analysis) do
        analysis = double("TemplateAnalysis")
        allow(analysis).to receive(:statements).and_return(template_nodes)
        allow(analysis).to receive(:signature_at).with(0).and_return([:heading, 1, "Title"])
        allow(analysis).to receive(:signature_at).with(1).and_return([:paragraph, "template_only"])
        analysis
      end

      let(:complex_dest_analysis) do
        analysis = double("DestAnalysis")
        allow(analysis).to receive(:statements).and_return(dest_nodes)
        allow(analysis).to receive(:signature_at).with(0).and_return([:heading, 1, "Title"])
        allow(analysis).to receive(:signature_at).with(1).and_return([:paragraph, "dest_only1"])
        allow(analysis).to receive(:signature_at).with(2).and_return([:paragraph, "dest_only2"])
        analysis
      end

      it "sorts entries appropriately" do
        aligner = described_class.new(complex_template_analysis, complex_dest_analysis)
        result = aligner.align

        # Should have: 1 match, 2 dest_only, 1 template_only
        expect(result.size).to eq(4)

        # Matches and dest_only should come first, then template_only
        types = result.map { |e| e[:type] }
        template_only_index = types.index(:template_only)
        dest_only_indices = types.each_index.select { |i| types[i] == :dest_only }

        dest_only_indices.each do |idx|
          expect(idx).to be < template_only_index
        end
      end
    end
  end

  describe "with match_refiner" do
    let(:template_node) { double("TemplateNode", type: :table) }
    let(:dest_node) { double("DestNode", type: :table) }

    let(:template_analysis_with_table) do
      analysis = double("TemplateAnalysis")
      allow(analysis).to receive(:statements).and_return([template_node])
      allow(analysis).to receive(:signature_at).with(0).and_return([:table, 3, "abc"])
      analysis
    end

    let(:dest_analysis_with_table) do
      analysis = double("DestAnalysis")
      allow(analysis).to receive(:statements).and_return([dest_node])
      allow(analysis).to receive(:signature_at).with(0).and_return([:table, 3, "xyz"])
      analysis
    end

    it "applies match_refiner to unmatched nodes" do
      match_result = double("MatchResult", template_node: template_node, dest_node: dest_node, score: 0.8)
      refiner = double("Refiner")
      allow(refiner).to receive(:call).and_return([match_result])

      aligner = described_class.new(
        template_analysis_with_table,
        dest_analysis_with_table,
        match_refiner: refiner,
      )
      result = aligner.align

      # Should find a match via refiner
      matches = result.select { |e| e[:type] == :match }
      expect(matches.size).to eq(1)
    end
  end

  describe "#align edge cases" do
    context "with nil signature" do
      let(:node_with_nil_sig) { double("NodeWithNilSig") }

      let(:nil_sig_template_analysis) do
        analysis = double("TemplateAnalysis")
        allow(analysis).to receive(:statements).and_return([node_with_nil_sig])
        allow(analysis).to receive(:signature_at).with(0).and_return(nil)
        analysis
      end

      it "handles nodes with nil signatures" do
        aligner = described_class.new(nil_sig_template_analysis, mock_dest_analysis)
        result = aligner.align

        # Node with nil signature should still appear as template_only
        expect(result.size).to eq(1)
        expect(result.first[:type]).to eq(:template_only)
      end
    end

    context "with multiple matches for same signature" do
      let(:template_nodes) { [double("T1"), double("T2")] }
      let(:dest_nodes) { [double("D1"), double("D2")] }

      let(:duplicate_template_analysis) do
        analysis = double("TemplateAnalysis")
        allow(analysis).to receive(:statements).and_return(template_nodes)
        allow(analysis).to receive(:signature_at).with(0).and_return([:paragraph, "same"])
        allow(analysis).to receive(:signature_at).with(1).and_return([:paragraph, "same"])
        analysis
      end

      let(:duplicate_dest_analysis) do
        analysis = double("DestAnalysis")
        allow(analysis).to receive(:statements).and_return(dest_nodes)
        allow(analysis).to receive(:signature_at).with(0).and_return([:paragraph, "same"])
        allow(analysis).to receive(:signature_at).with(1).and_return([:paragraph, "same"])
        analysis
      end

      it "handles duplicate signatures" do
        aligner = described_class.new(duplicate_template_analysis, duplicate_dest_analysis)
        result = aligner.align

        # All nodes should be in the result
        expect(result.size).to be >= 2
      end
    end

    context "interleaved matching" do
      let(:template_nodes) { [double("T1"), double("T2"), double("T3")] }
      let(:dest_nodes) { [double("D1"), double("D2")] }

      let(:interleaved_template_analysis) do
        analysis = double("TemplateAnalysis")
        allow(analysis).to receive(:statements).and_return(template_nodes)
        allow(analysis).to receive(:signature_at).with(0).and_return([:heading, 1, "A"])
        allow(analysis).to receive(:signature_at).with(1).and_return([:paragraph, "new"])
        allow(analysis).to receive(:signature_at).with(2).and_return([:heading, 2, "B"])
        analysis
      end

      let(:interleaved_dest_analysis) do
        analysis = double("DestAnalysis")
        allow(analysis).to receive(:statements).and_return(dest_nodes)
        allow(analysis).to receive(:signature_at).with(0).and_return([:heading, 1, "A"])
        allow(analysis).to receive(:signature_at).with(1).and_return([:heading, 2, "B"])
        analysis
      end

      it "correctly identifies template_only nodes between matches" do
        aligner = described_class.new(interleaved_template_analysis, interleaved_dest_analysis)
        result = aligner.align

        types = result.map { |e| e[:type] }
        expect(types).to include(:match)
        expect(types).to include(:template_only)
        expect(types.count(:match)).to eq(2)
        expect(types.count(:template_only)).to eq(1)
      end
    end
  end

  describe "#build_signature_map (private)" do
    let(:node1) { double("Node1") }
    let(:node2) { double("Node2") }

    let(:multi_node_analysis) do
      analysis = double("Analysis")
      allow(analysis).to receive(:statements).and_return([node1, node2])
      allow(analysis).to receive(:signature_at).with(0).and_return([:heading, 1, "First"])
      allow(analysis).to receive(:signature_at).with(1).and_return([:paragraph, "second"])
      analysis
    end

    it "builds a hash mapping signatures to indices and nodes" do
      aligner = described_class.new(multi_node_analysis, mock_dest_analysis)
      statements = multi_node_analysis.statements
      sig_map = aligner.send(:build_signature_map, statements, multi_node_analysis)

      expect(sig_map).to be_a(Hash)
      expect(sig_map.keys).to include([:heading, 1, "First"])
      expect(sig_map.keys).to include([:paragraph, "second"])
    end
  end
end
