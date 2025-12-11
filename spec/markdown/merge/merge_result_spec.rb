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

  describe "inheritance" do
    it "inherits from Ast::Merge::MergeResultBase" do
      expect(described_class.ancestors).to include(Ast::Merge::MergeResultBase)
    end
  end
end
