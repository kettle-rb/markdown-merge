# frozen_string_literal: true

RSpec.describe Markdown::Merge::MergeResult do
  describe "#initialize" do
    it "sets content" do
      result = described_class.new(content: "merged content")
      expect(result.content).to eq("merged content")
    end

    it "defaults conflicts to empty array" do
      result = described_class.new(content: "merged")
      expect(result.conflicts).to eq([])
    end

    it "defaults frozen_blocks to empty array" do
      result = described_class.new(content: "merged")
      expect(result.frozen_blocks).to eq([])
    end

    it "defaults stats with zeros" do
      result = described_class.new(content: "merged")
      expect(result.stats[:nodes_added]).to eq(0)
      expect(result.stats[:nodes_removed]).to eq(0)
      expect(result.stats[:nodes_modified]).to eq(0)
      expect(result.stats[:merge_time_ms]).to eq(0)
    end

    it "accepts custom conflicts" do
      conflicts = [{location: "line 5"}]
      result = described_class.new(content: "merged", conflicts: conflicts)
      expect(result.conflicts).to eq(conflicts)
    end

    it "accepts custom frozen_blocks" do
      frozen = [{start_line: 1, end_line: 5}]
      result = described_class.new(content: "merged", frozen_blocks: frozen)
      expect(result.frozen_blocks).to eq(frozen)
    end

    it "merges custom stats with defaults" do
      result = described_class.new(content: "merged", stats: {nodes_added: 5})
      expect(result.stats[:nodes_added]).to eq(5)
      expect(result.stats[:nodes_removed]).to eq(0)
    end
  end

  describe "#content" do
    it "returns the merged content" do
      result = described_class.new(content: "# Title\n\nParagraph.")
      expect(result.content).to eq("# Title\n\nParagraph.")
    end

    it "returns nil when content is nil" do
      result = described_class.new(content: nil)
      expect(result.content).to be_nil
    end
  end

  describe "#content?" do
    it "returns true when content is set" do
      result = described_class.new(content: "merged")
      expect(result.content?).to be true
    end

    it "returns false when content is nil" do
      result = described_class.new(content: nil)
      expect(result.content?).to be false
    end

    it "returns true for empty string content" do
      result = described_class.new(content: "")
      expect(result.content?).to be true
    end
  end

  describe "#content_string" do
    it "returns content as string" do
      result = described_class.new(content: "merged content")
      expect(result.content_string).to eq("merged content")
    end
  end

  describe "#success?" do
    it "returns true when no conflicts and content present" do
      result = described_class.new(content: "merged")
      expect(result.success?).to be true
    end

    it "returns false when conflicts exist" do
      result = described_class.new(content: "merged", conflicts: [{location: "line 5"}])
      expect(result.success?).to be false
    end

    it "returns false when content is nil" do
      result = described_class.new(content: nil)
      expect(result.success?).to be false
    end
  end

  describe "#conflicts?" do
    it "returns false when no conflicts" do
      result = described_class.new(content: "merged")
      expect(result.conflicts?).to be false
    end

    it "returns true when conflicts exist" do
      result = described_class.new(content: "merged", conflicts: [{location: "line 5"}])
      expect(result.conflicts?).to be true
    end
  end

  describe "#has_frozen_blocks?" do
    it "returns false when no frozen blocks" do
      result = described_class.new(content: "merged")
      expect(result.has_frozen_blocks?).to be false
    end

    it "returns true when frozen blocks exist" do
      result = described_class.new(content: "merged", frozen_blocks: [{start_line: 1}])
      expect(result.has_frozen_blocks?).to be true
    end
  end

  describe "#nodes_added" do
    it "returns 0 by default" do
      result = described_class.new(content: "merged")
      expect(result.nodes_added).to eq(0)
    end

    it "returns value from stats" do
      result = described_class.new(content: "merged", stats: {nodes_added: 3})
      expect(result.nodes_added).to eq(3)
    end
  end

  describe "#nodes_removed" do
    it "returns 0 by default" do
      result = described_class.new(content: "merged")
      expect(result.nodes_removed).to eq(0)
    end

    it "returns value from stats" do
      result = described_class.new(content: "merged", stats: {nodes_removed: 2})
      expect(result.nodes_removed).to eq(2)
    end
  end

  describe "#nodes_modified" do
    it "returns 0 by default" do
      result = described_class.new(content: "merged")
      expect(result.nodes_modified).to eq(0)
    end

    it "returns value from stats" do
      result = described_class.new(content: "merged", stats: {nodes_modified: 4})
      expect(result.nodes_modified).to eq(4)
    end
  end

  describe "#frozen_count" do
    it "returns 0 when no frozen blocks" do
      result = described_class.new(content: "merged")
      expect(result.frozen_count).to eq(0)
    end

    it "returns count of frozen blocks" do
      frozen = [{start_line: 1}, {start_line: 10}]
      result = described_class.new(content: "merged", frozen_blocks: frozen)
      expect(result.frozen_count).to eq(2)
    end
  end

  describe "#merge_time_ms" do
    it "returns default value" do
      result = described_class.new(content: "merged")
      expect(result.merge_time_ms).to eq(0)
    end

    it "returns value from stats" do
      result = described_class.new(content: "merged", stats: {merge_time_ms: 15.5})
      expect(result.merge_time_ms).to eq(15.5)
    end
  end

  describe "#inspect" do
    it "includes class name" do
      result = described_class.new(content: "merged")
      expect(result.inspect).to include("Markdown::Merge::MergeResult")
    end

    it "includes success status" do
      result = described_class.new(content: "merged")
      expect(result.inspect).to include("success")
    end

    it "includes failed status when conflicts" do
      result = described_class.new(content: "merged", conflicts: [{location: "line 5"}])
      expect(result.inspect).to include("failed")
    end

    it "includes conflict count" do
      result = described_class.new(content: "merged", conflicts: [{a: 1}, {b: 2}])
      expect(result.inspect).to include("conflicts=2")
    end

    it "includes frozen count" do
      result = described_class.new(content: "merged", frozen_blocks: [{a: 1}])
      expect(result.inspect).to include("frozen=1")
    end
  end

  describe "#to_s" do
    it "returns content" do
      result = described_class.new(content: "merged content")
      expect(result.to_s).to eq("merged content")
    end

    it "returns empty string when content is nil" do
      result = described_class.new(content: nil)
      expect(result.to_s).to eq("")
    end
  end

  describe "unresolved review application" do
    it "rewrites string-backed content using output range metadata" do
      result = described_class.new(content: "# Destination\n")
      result.record_unresolved_choice(
        template_text: "# Template\n",
        destination_text: "# Destination\n",
        provisional_winner: :destination,
        case_id: "markdown-matched_block-1",
        metadata: {output_range: [0, "# Destination\n".bytesize]},
      )

      result.apply_unresolved_resolutions!("markdown-matched_block-1" => :template)

      expect(result.to_s).to eq("# Template\n")
      expect(result.review_required?).to be(false)
    end

    it "raises when post-processing changed markdown output after range capture" do
      result = described_class.new(content: "# Destination", raw_content: "# Destination\n")
      result.record_unresolved_choice(
        template_text: "# Template\n",
        destination_text: "# Destination\n",
        provisional_winner: :destination,
        case_id: "markdown-matched_block-1",
        metadata: {output_range: [0, "# Destination\n".bytesize]},
      )

      expect {
        result.apply_unresolved_resolutions!("markdown-matched_block-1" => :template)
      }.to raise_error(ArgumentError, /post-processing transformed markdown output/)
    end

    it "applies multiple output-range resolutions in one call without shifting later ranges" do
      content = "# Destination One\n\n# Destination Two\n"
      first_destination = "# Destination One\n"
      second_destination = "# Destination Two\n"
      first_template = "# Template One Extended\n"
      second_template = "# Template Two\n"
      second_start = content.index(second_destination)

      result = described_class.new(content: content)
      result.record_unresolved_choice(
        template_text: first_template,
        destination_text: first_destination,
        provisional_winner: :destination,
        case_id: "markdown-matched_block-1",
        metadata: {output_range: [0, first_destination.bytesize]},
      )
      result.record_unresolved_choice(
        template_text: second_template,
        destination_text: second_destination,
        provisional_winner: :destination,
        case_id: "markdown-matched_block-2",
        metadata: {output_range: [second_start, second_start + second_destination.bytesize]},
      )

      result.apply_unresolved_resolutions!(
        "markdown-matched_block-1" => :template,
        "markdown-matched_block-2" => :template,
      )

      expect(result.to_s).to eq("#{first_template}\n#{second_template}")
      expect(result.review_required?).to be(false)
    end

    it "rejects persisted review state when the selected case is no longer present" do
      result = described_class.new(content: "# Destination\n")
      result.record_unresolved_choice(
        template_text: "# Template\n",
        destination_text: "# Destination\n",
        provisional_winner: :destination,
        case_id: "markdown-matched_block-1",
        metadata: {output_range: [0, "# Destination\n".bytesize], match_kind: :matched_block},
      )

      state = Ast::Merge::UnresolvedReviewState.new(
        cases: result.unresolved_cases,
        selections: {"markdown-matched_block-2" => :template},
      )

      expect {
        result.apply_unresolved_review_state!(state)
      }.to raise_error(ArgumentError, /case markdown-matched_block-2 is not present/)
    end

    it "rejects persisted review state when the saved case identity no longer matches" do
      result = described_class.new(content: "# Destination\n")
      result.record_unresolved_choice(
        template_text: "# Template\n",
        destination_text: "# Destination\n",
        provisional_winner: :destination,
        case_id: "markdown-matched_block-1",
        surface_path: "document[0] > matched_block[line=1]",
        metadata: {output_range: [0, "# Destination\n".bytesize], match_kind: :matched_block},
      )

      state = Ast::Merge::UnresolvedReviewState.new(
        cases: [
          Ast::Merge::Runtime::ResolutionCase.new(
            case_id: "markdown-matched_block-1",
            reason: :conflict,
            candidates: {template: "# Different Template\n", destination: "# Destination\n"},
            provisional_winner: :destination,
            surface_path: "document[0] > matched_block[line=1]",
            metadata: {match_kind: :matched_block, review_identity: "stale-identity"},
          ),
        ],
        selections: {"markdown-matched_block-1" => :template},
        metadata: {markdown_review_state: {selection_identities: {"markdown-matched_block-1" => "stale-identity"}}},
      )

      expect {
        result.apply_unresolved_review_state!(state)
      }.to raise_error(ArgumentError, /no longer matches the current unresolved surface/)
    end

    it "rejects persisted review state before mutating when post-processing changed markdown output" do
      result = described_class.new(content: "# Destination", raw_content: "# Destination\n")
      result.record_unresolved_choice(
        template_text: "# Template\n",
        destination_text: "# Destination\n",
        provisional_winner: :destination,
        case_id: "markdown-matched_block-1",
        metadata: {output_range: [0, "# Destination\n".bytesize], match_kind: :matched_block},
      )

      state = result.to_unresolved_review_state(selections: {"markdown-matched_block-1" => :template})

      expect {
        result.apply_unresolved_review_state!(state)
      }.to raise_error(ArgumentError, /review state.*post-processing transformed markdown output/)
      expect(result.to_s).to eq("# Destination")
      expect(result.review_required?).to be(true)
    end
  end

  describe "inheritance" do
    it "inherits from Ast::Merge::MergeResultBase" do
      expect(described_class.ancestors).to include(Ast::Merge::MergeResultBase)
    end
  end
end
