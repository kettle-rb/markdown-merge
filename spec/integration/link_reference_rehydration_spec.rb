# frozen_string_literal: true

# Integration tests for link reference rehydration
# Uses the 02_rehydrate fixture set

RSpec.describe "Link Reference Rehydration integration" do
  let(:fixtures_dir) { File.expand_path("../fixtures/02_rehydrate", __dir__) }
  let(:destination_file) { File.join(fixtures_dir, "destination.md") }
  let(:expected_file) { File.join(fixtures_dir, "expected.md") }

  describe "LinkReferenceRehydrator" do
    let(:destination_content) { File.read(destination_file) }

    it "rehydrates inline links to reference style" do
      rehydrator = Markdown::Merge::LinkReferenceRehydrator.new(destination_content)
      rehydrator.rehydrate

      expect(rehydrator.changed?).to be true
      expect(rehydrator.rehydration_count).to be > 0
    end

    it "converts inline URLs to reference labels" do
      rehydrator = Markdown::Merge::LinkReferenceRehydrator.new(destination_content)
      result = rehydrator.rehydrate

      # Before: [GitHub org](https://github.com/rubygems/)
      # After:  [GitHub org][rubygems-org]
      expect(result).to include("[GitHub org][rubygems-org]")
      expect(result).not_to include("[GitHub org](https://github.com/rubygems/)")
    end

    it "preserves line count (no content loss)" do
      rehydrator = Markdown::Merge::LinkReferenceRehydrator.new(destination_content)
      result = rehydrator.rehydrate

      # Rehydration should not change line count
      expect(result.lines.count).to eq(destination_content.lines.count)
    end

    it "preserves all document sections" do
      rehydrator = Markdown::Merge::LinkReferenceRehydrator.new(destination_content)
      result = rehydrator.rehydrate

      # Key sections must still be present
      expect(result).to include("# ☯️ Markdown::Merge")
      expect(result).to include("## 🌻 Synopsis")
      expect(result).to include("## ✨ Installation")
      expect(result).to include("## ⚙️ Configuration")
    end

    it "preserves link reference definitions" do
      rehydrator = Markdown::Merge::LinkReferenceRehydrator.new(destination_content)
      result = rehydrator.rehydrate

      # Link reference definitions should remain intact
      expect(result).to include("[rubygems-org]: https://github.com/rubygems/")
      expect(result).to include("[draper-security]: https://joel.drapper.me/p/ruby-central-security-measures/")
    end

    it "handles linked images correctly (no content corruption)" do
      rehydrator = Markdown::Merge::LinkReferenceRehydrator.new(destination_content)
      result = rehydrator.rehydrate

      # Linked images should not be corrupted
      # The tree-based approach should handle [![alt](img-url)](link-url) properly
      expect(result).to include("[![")
      expect(result).not_to match(/\]\[\]\[/)  # No empty brackets from corruption
    end

    it "is idempotent - single pass handles all rehydrations" do
      rehydrator1 = Markdown::Merge::LinkReferenceRehydrator.new(destination_content)
      first_pass = rehydrator1.rehydrate

      rehydrator2 = Markdown::Merge::LinkReferenceRehydrator.new(first_pass)
      second_pass = rehydrator2.rehydrate

      # Second pass should make no changes - tree-based approach handles nested
      # structures (like linked images) in a single pass
      expect(rehydrator2.changed?).to be false
      expect(rehydrator2.rehydration_count).to eq(0)
      expect(second_pass).to eq(first_pass)
    end

    it "matches expected output when comparing against expected.md" do
      skip "expected.md not yet generated" unless File.exist?(expected_file)

      # Single pass should produce the expected output
      rehydrator = Markdown::Merge::LinkReferenceRehydrator.new(destination_content)
      result = rehydrator.rehydrate

      expected_content = File.read(expected_file)
      expect(result).to eq(expected_content)
    end
  end

  describe "rehydration statistics" do
    let(:destination_content) { File.read(destination_file) }

    it "reports rehydration count" do
      rehydrator = Markdown::Merge::LinkReferenceRehydrator.new(destination_content)
      rehydrator.rehydrate

      # The fixture should have a significant number of rehydrations
      expect(rehydrator.rehydration_count).to be >= 100
    end

    it "identifies duplicate link definitions" do
      rehydrator = Markdown::Merge::LinkReferenceRehydrator.new(destination_content)
      rehydrator.rehydrate

      dups = rehydrator.duplicate_definitions
      # Check structure - may or may not have duplicates
      expect(dups).to be_a(Hash)
    end

    it "builds URL to label mapping" do
      rehydrator = Markdown::Merge::LinkReferenceRehydrator.new(destination_content)
      defs = rehydrator.link_definitions

      expect(defs).to be_a(Hash)
      expect(defs["https://github.com/rubygems/"]).to eq("rubygems-org")
    end
  end

  describe "full pipeline: Cleanse + Rehydrate", :markly do
    it "applies all fixes in sequence" do
      content = File.read(File.expand_path("../fixtures/01_cleanse/destination.md", __dir__))
      original_line_count = content.lines.count

      # Phase 1: Cleanse
      condensed_parser = Markdown::Merge::Cleanse::CondensedLinkRefs.new(content)
      content = condensed_parser.expand if condensed_parser.condensed?

      fence_parser = Markdown::Merge::Cleanse::CodeFenceSpacing.new(content)
      content = fence_parser.fix if fence_parser.malformed?

      block_parser = Markdown::Merge::Cleanse::BlockSpacing.new(content)
      content = block_parser.fix if block_parser.malformed?

      cleansed_line_count = content.lines.count

      # Phase 2: Rehydrate
      rehydrator = Markdown::Merge::LinkReferenceRehydrator.new(content)
      content = rehydrator.rehydrate

      final_line_count = content.lines.count

      # Cleansing should add lines (expanding condensed refs, adding blank lines)
      expect(cleansed_line_count).to be > original_line_count

      # Rehydration should not change line count
      expect(final_line_count).to eq(cleansed_line_count)

      # Document should still be valid
      analysis = Markdown::Merge::FileAnalysis.new(content, backend: :auto)
      expect(analysis.valid?).to be true
    end
  end
end
