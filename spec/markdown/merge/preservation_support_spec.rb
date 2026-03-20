# frozen_string_literal: true

RSpec.describe Markdown::Merge::PreservationSupport do
  subject(:host) { host_class.new }

  let(:host_class) do
    Class.new do
      include Markdown::Merge::PreservationSupport

      def node_to_source(node, _analysis)
        node.text
      end
    end
  end

  let(:region_class) do
    Struct.new(:start_line, :end_line, :text, keyword_init: true)
  end

  let(:node_class) do
    Struct.new(:source_position, :text, keyword_init: true)
  end

  let(:remove_plan_class) do
    Struct.new(:remove_start_line, :remove_end_line, :promoted_comment_regions, :trailing_boundary, keyword_init: true)
  end

  let(:comment_attachment_class) do
    Struct.new(:leading_region, keyword_init: true)
  end

  let(:boundary_class) do
    Struct.new(:comment_attachment, keyword_init: true)
  end

  let(:gap_class) do
    Struct.new(:blank_line_count, keyword_init: true)
  end

  let(:attachment_class) do
    Struct.new(:owner, :leading_region, :leading_gap, keyword_init: true)
  end

  describe "#normalized_preserved_fragment_text" do
    it "removes trailing newlines while preserving internal spacing" do
      expect(host.send(:normalized_preserved_fragment_text, "<!-- docs -->\n\n")).to eq("<!-- docs -->")
    end
  end

  describe "#standalone_comment_text?" do
    it "accepts standalone HTML comment text" do
      expect(host.send(:standalone_comment_text?, "<!-- docs -->\n")).to be(true)
    end

    it "rejects non-comment text" do
      expect(host.send(:standalone_comment_text?, "docs")).to be(false)
    end
  end

  describe "#standalone_comment_node?" do
    let(:analysis) do
      double(
        "Analysis",
        comment_tracker: Object.new,
        comment_node_at: :comment_node,
      )
    end

    it "accepts a single-line source-backed node tracked as a standalone comment" do
      node = node_class.new(source_position: {start_line: 7, end_line: 7}, text: "<!-- docs -->\n")

      expect(host.send(:standalone_comment_node?, node, analysis)).to be(true)
    end

    it "rejects a multi-line node even when the first line is tracked" do
      node = node_class.new(source_position: {start_line: 7, end_line: 8}, text: "<!-- docs -->\n")

      expect(host.send(:standalone_comment_node?, node, analysis)).to be(false)
    end
  end

  describe "#link_definition_node?" do
    it "accepts consumed Markdown link definition nodes" do
      link_definition = Markdown::Merge::LinkDefinitionNode.new(
        "[docs]: https://example.test/docs",
        line_number: 4,
        label: "docs",
        url: "https://example.test/docs",
      )

      expect(host.send(:link_definition_node?, link_definition)).to be(true)
    end

    it "accepts statement-like nodes with a link_definition merge_type" do
      node = double("Statement", merge_type: :link_definition)

      expect(host.send(:link_definition_node?, node)).to be(true)
    end
  end

  describe "#gap_line_node?" do
    it "accepts real gap line nodes" do
      expect(host.send(:gap_line_node?, Markdown::Merge::GapLineNode.new("", line_number: 3))).to be(true)
    end

    it "accepts statement-like nodes with a gap_line merge_type" do
      expect(host.send(:gap_line_node?, double("Statement", merge_type: :gap_line))).to be(true)
    end
  end

  describe "#blank_gap_line_node?" do
    it "accepts blank gap line nodes" do
      expect(host.send(:blank_gap_line_node?, Markdown::Merge::GapLineNode.new("   ", line_number: 3))).to be(true)
    end

    it "rejects non-blank gap line nodes" do
      expect(host.send(:blank_gap_line_node?, Markdown::Merge::GapLineNode.new("[docs]: https://example.test", line_number: 3))).to be(false)
    end
  end

  describe "#non_blank_gap_line_node?" do
    it "accepts a real GapLineNode with non-blank content" do
      node = Markdown::Merge::GapLineNode.new("[docs]: https://example.test", line_number: 3)

      expect(host.send(:non_blank_gap_line_node?, node)).to be(true)
    end

    it "rejects a blank GapLineNode" do
      node = Markdown::Merge::GapLineNode.new("", line_number: 4)

      expect(host.send(:non_blank_gap_line_node?, node)).to be(false)
    end

    it "rejects a whitespace-only GapLineNode" do
      node = Markdown::Merge::GapLineNode.new("   ", line_number: 5)

      expect(host.send(:non_blank_gap_line_node?, node)).to be(false)
    end

    it "accepts a statement-like node with gap_line merge_type when its content is non-blank" do
      node = double("Statement", merge_type: :gap_line, blank?: false)

      expect(host.send(:non_blank_gap_line_node?, node)).to be(true)
    end

    it "rejects a non-gap-line node" do
      node = double("Statement", merge_type: :paragraph)

      expect(host.send(:non_blank_gap_line_node?, node)).to be(false)
    end
  end

  describe "#structural_preservation_statement?" do
    let(:analysis) do
      double(
        "Analysis",
        comment_tracker: Object.new,
        comment_node_at: :comment_node,
      )
    end

    it "accepts ordinary structural statements" do
      statement = node_class.new(source_position: {start_line: 9, end_line: 10}, text: "Paragraph\n")

      expect(host.send(:structural_preservation_statement?, statement, analysis)).to be(true)
    end

    it "rejects gap lines, standalone comments, and link definitions" do
      gap_line = Markdown::Merge::GapLineNode.new("", line_number: 4)
      comment = node_class.new(source_position: {start_line: 7, end_line: 7}, text: "<!-- docs -->\n")
      link_definition = Markdown::Merge::LinkDefinitionNode.new(
        "[docs]: https://example.test/docs",
        line_number: 8,
        label: "docs",
        url: "https://example.test/docs",
      )

      expect(host.send(:structural_preservation_statement?, gap_line, analysis)).to be(false)
      expect(host.send(:structural_preservation_statement?, comment, analysis)).to be(false)
      expect(host.send(:structural_preservation_statement?, link_definition, analysis)).to be(false)
    end
  end

  describe "#preserved_comment_region_key" do
    it "normalizes trailing newlines in region text" do
      region = region_class.new(start_line: 3, end_line: 3, text: "<!-- docs -->\n")

      expect(host.send(:preserved_comment_region_key, region)).to eq([3, 3, "<!-- docs -->"])
    end
  end

  describe "#preserved_comment_node_key" do
    it "normalizes trailing newlines in node source text" do
      node = node_class.new(
        source_position: {start_line: 5, end_line: 5},
        text: "<!-- docs -->\n",
      )

      expect(host.send(:preserved_comment_node_key, node, nil)).to eq([5, 5, "<!-- docs -->"])
    end
  end

  describe "#region_within_removed_range?" do
    let(:remove_plan) { remove_plan_class.new(remove_start_line: 4, remove_end_line: 8) }

    it "accepts regions fully within the removed range" do
      region = region_class.new(start_line: 5, end_line: 5, text: "<!-- docs -->")

      expect(host.send(:region_within_removed_range?, region, remove_plan)).to be(true)
    end

    it "rejects regions outside the removed range" do
      region = region_class.new(start_line: 2, end_line: 2, text: "<!-- docs -->")

      expect(host.send(:region_within_removed_range?, region, remove_plan)).to be(false)
    end
  end

  describe "#comment_region_for_node" do
    it "builds a region for the node source-position range" do
      node = double("Node", source_position: {start_line: 7, end_line: 7})
      analysis = double("Analysis")
      expected_region = region_class.new(start_line: 7, end_line: 7, text: "<!-- docs -->")

      allow(analysis).to receive(:respond_to?).with(:comment_region_for_range).and_return(true)
      allow(analysis).to receive(:comment_region_for_range).with(7..7, kind: :orphan, full_line_only: true).and_return(expected_region)

      expect(host.send(:comment_region_for_node, node, analysis, kind: :orphan)).to eq(expected_region)
    end
  end

  describe "#remove_plan_preserved_comment_regions" do
    it "returns deduplicated standalone comment regions from promoted and trailing-boundary sources within range" do
      promoted_region = region_class.new(start_line: 5, end_line: 5, text: "<!-- docs -->\n")
      duplicate_trailing_region = region_class.new(start_line: 5, end_line: 5, text: "<!-- docs -->")
      out_of_range_region = region_class.new(start_line: 10, end_line: 10, text: "<!-- later -->")
      remove_plan = remove_plan_class.new(
        remove_start_line: 4,
        remove_end_line: 8,
        promoted_comment_regions: [promoted_region, out_of_range_region],
        trailing_boundary: boundary_class.new(
          comment_attachment: comment_attachment_class.new(leading_region: duplicate_trailing_region),
        ),
      )

      expect(host.send(:remove_plan_preserved_comment_regions, remove_plan)).to eq([promoted_region])
    end
  end

  describe "#remove_plan_preserved_comment_keys" do
    it "returns normalized keys for the deduplicated preserved regions" do
      promoted_region = region_class.new(start_line: 5, end_line: 5, text: "<!-- docs -->\n")
      remove_plan = remove_plan_class.new(
        remove_start_line: 4,
        remove_end_line: 8,
        promoted_comment_regions: [promoted_region],
        trailing_boundary: nil,
      )

      expect(host.send(:remove_plan_preserved_comment_keys, remove_plan)).to eq(Set[[5, 5, "<!-- docs -->"]])
    end
  end

  describe "#rebase_preserved_comment_keys" do
    it "converts document-global preserved comment keys into section-local coordinates" do
      keys = Set[[5, 5, "<!-- docs -->"]]

      expect(host.send(:rebase_preserved_comment_keys, keys, line_offset: 4)).to eq(Set[[1, 1, "<!-- docs -->"]])
    end
  end

  describe "#remove_plan_owns_comment_node?" do
    let(:region_by_lookup) { {} }

    let(:analysis) do
      Class.new do
        attr_reader :comment_tracker

        def initialize(region_by_lookup)
          @region_by_lookup = region_by_lookup
          @comment_tracker = Object.new
        end

        def comment_node_at(_line_number)
          :comment_node
        end

        def comment_region_for_range(range, kind:, full_line_only:)
          @region_by_lookup[[range, kind, full_line_only]]
        end
      end.new(region_by_lookup)
    end

    it "returns true when the remove plan already preserves that exact standalone comment node" do
      node = node_class.new(source_position: {start_line: 5, end_line: 5}, text: "<!-- docs -->\n")
      remove_plan = remove_plan_class.new(
        remove_start_line: 4,
        remove_end_line: 8,
        promoted_comment_regions: [region_class.new(start_line: 5, end_line: 5, text: "<!-- docs -->")],
        trailing_boundary: nil,
      )

      region_by_lookup[[5..5, :orphan, true]] = region_class.new(start_line: 5, end_line: 5, text: "<!-- docs -->")

      expect(host.send(:remove_plan_owns_comment_node?, node, analysis, remove_plan)).to be(true)
    end

    it "returns false when the standalone comment node is not represented by the remove plan" do
      node = node_class.new(source_position: {start_line: 6, end_line: 6}, text: "<!-- docs -->\n")
      remove_plan = remove_plan_class.new(
        remove_start_line: 4,
        remove_end_line: 8,
        promoted_comment_regions: [],
        trailing_boundary: nil,
      )

      region_by_lookup[[6..6, :orphan, true]] = region_class.new(start_line: 6, end_line: 6, text: "<!-- docs -->")

      expect(host.send(:remove_plan_owns_comment_node?, node, analysis, remove_plan)).to be(false)
    end
  end

  describe "#remove_plan_preserved_comment_keys_for_nodes" do
    let(:region_by_lookup) { {} }

    let(:analysis) do
      Class.new do
        attr_reader :comment_tracker

        def initialize(region_by_lookup)
          @region_by_lookup = region_by_lookup
          @comment_tracker = Object.new
        end

        def comment_node_at(_line_number)
          :comment_node
        end

        def comment_region_for_range(range, kind:, full_line_only:)
          @region_by_lookup[[range, kind, full_line_only]]
        end
      end.new(region_by_lookup)
    end

    it "extends remove-plan-owned keys with direct standalone removed comment nodes inside the removed range" do
      node = node_class.new(source_position: {start_line: 6, end_line: 6}, text: "<!-- direct docs -->\n")
      remove_plan = remove_plan_class.new(
        remove_start_line: 4,
        remove_end_line: 8,
        promoted_comment_regions: [],
        trailing_boundary: nil,
      )

      region_by_lookup[[6..6, :orphan, true]] = region_class.new(start_line: 6, end_line: 6, text: "<!-- direct docs -->")

      expect(host.send(:remove_plan_preserved_comment_keys_for_nodes, remove_plan, nodes: [node], analysis: analysis)).to eq(
        Set[[6, 6, "<!-- direct docs -->"]],
      )
    end
  end

  describe "#remove_plan_comment_insertion_specs" do
    it "builds deduplicated insertion specs for promoted and trailing-boundary standalone comment regions" do
      owner = Object.new
      promoted_region = region_class.new(start_line: 5, end_line: 5, text: "<!-- docs -->\n")
      trailing_region = region_class.new(start_line: 8, end_line: 8, text: "<!-- trailing -->")
      remove_plan = remove_plan_class.new(
        remove_start_line: 4,
        remove_end_line: 8,
        promoted_comment_regions: [promoted_region, trailing_region],
        trailing_boundary: boundary_class.new(
          comment_attachment: Struct.new(:leading_region, :leading_gap, keyword_init: true).new(
            leading_region: trailing_region,
            leading_gap: gap_class.new(blank_line_count: 2),
          ),
        ),
      )
      allow(remove_plan).to receive(:removed_attachments).and_return([
        attachment_class.new(
          owner: owner,
          leading_region: promoted_region,
          leading_gap: gap_class.new(blank_line_count: 1),
        ),
      ])

      expect(
        host.send(
          :remove_plan_comment_insertion_specs,
          remove_plan,
          insertion_index_by_owner: {owner.object_id => 3},
          final_insertion_index: 4,
        ),
      ).to eq([
        {
          insertion_index: 3,
          fragment: {kind: :standalone_comment, text: "<!-- docs -->"},
          gap_count: 1,
        },
        {
          insertion_index: 4,
          fragment: {kind: :standalone_comment, text: "<!-- trailing -->"},
          gap_count: 2,
        },
      ])
    end
  end

  describe "#preserved_fragment_for_node" do
    let(:empty_signature_set) { Set.new }

    it "builds a standalone comment fragment when the template does not already document the section" do
      node = node_class.new(source_position: {start_line: 7, end_line: 7}, text: "<!-- docs -->\n")
      analysis = double(
        "Analysis",
        comment_tracker: Object.new,
        comment_node_at: :comment_node,
      )

      expect(
        host.send(
          :preserved_fragment_for_node,
          node,
          analysis,
          template_has_standalone_comments: false,
          template_link_definition_signatures: empty_signature_set,
        ),
      ).to eq(kind: :standalone_comment, text: "<!-- docs -->")
    end

    it "builds a link definition fragment when the template does not already provide that signature" do
      link_definition = Markdown::Merge::LinkDefinitionNode.new(
        "[docs]: https://example.test/docs",
        line_number: 4,
        label: "docs",
        url: "https://example.test/docs",
      )

      expect(
        host.send(
          :preserved_fragment_for_node,
          link_definition,
          nil,
          template_has_standalone_comments: false,
          template_link_definition_signatures: empty_signature_set,
        ),
      ).to eq(kind: :link_definition, text: "[docs]: https://example.test/docs")
    end
  end

  describe "#preserved_fragment_separator" do
    it "keeps consecutive preserved link definitions single-spaced when there is no blank gap" do
      expect(
        host.send(
          :preserved_fragment_separator,
          gap_count: 0,
          previous_kind: :link_definition,
          current_kind: :link_definition,
        ),
      ).to eq("\n")
    end

    it "uses a blank line separator when a preserved gap is present" do
      expect(
        host.send(
          :preserved_fragment_separator,
          gap_count: 1,
          previous_kind: :standalone_comment,
          current_kind: :link_definition,
        ),
      ).to eq("\n\n")
    end
  end
end
