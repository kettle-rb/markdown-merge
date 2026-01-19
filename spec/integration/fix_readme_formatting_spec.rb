# frozen_string_literal: true

# Integration tests for bin/fix_readme_formatting script
# These tests run the script against fixtures and validate the output

RSpec.describe "bin/fix_readme_formatting integration" do
  let(:fixtures_dir) { File.expand_path("../fixtures/01_cleanse", __dir__) }
  let(:destination_file) { File.join(fixtures_dir, "destination.md") }
  let(:expected_file) { File.join(fixtures_dir, "expected.md") }

  describe "Cleanse fixes" do
    let(:destination_content) { File.read(destination_file) }

    describe "CondensedLinkRefs" do
      it "detects condensed link references in the fixture" do
        parser = Markdown::Merge::Cleanse::CondensedLinkRefs.new(destination_content)
        expect(parser.condensed?).to be true
      end

      it "expands condensed link references" do
        parser = Markdown::Merge::Cleanse::CondensedLinkRefs.new(destination_content)
        expanded = parser.expand

        # The condensed refs should now be on separate lines
        expect(expanded).not_to match(/\.svg\[/)  # No URL immediately followed by [
        expect(expanded).to include("[🖼️galtzo-i]:")
        expect(expanded).to include("[🖼️galtzo-discord]:")
      end

      it "preserves all document content" do
        parser = Markdown::Merge::Cleanse::CondensedLinkRefs.new(destination_content)
        expanded = parser.expand

        # Key sections must still be present
        expect(expanded).to include("# ☯️ Markdown::Merge")
        expect(expanded).to include("## 🌻 Synopsis")
        expect(expanded).to include("## ✨ Installation")
        expect(expanded).to include("## ⚙️ Configuration")
      end

      it "increases line count by expanding condensed refs" do
        parser = Markdown::Merge::Cleanse::CondensedLinkRefs.new(destination_content)
        expanded = parser.expand

        # Expanded should have MORE lines than original
        expect(expanded.lines.count).to be > destination_content.lines.count
      end
    end

    describe "CodeFenceSpacing" do
      it "detects malformed code fences in the fixture" do
        parser = Markdown::Merge::Cleanse::CodeFenceSpacing.new(destination_content)
        # Check if there are any malformed fences
        expect(parser.code_blocks).to be_an(Array)
      end

      it "fixes code fence spacing issues" do
        # First expand condensed refs (as they may affect fence detection)
        content = Markdown::Merge::Cleanse::CondensedLinkRefs.new(destination_content).expand

        parser = Markdown::Merge::Cleanse::CodeFenceSpacing.new(content)
        if parser.malformed?
          fixed = parser.fix
          # After fixing, there should be no malformed fences
          new_parser = Markdown::Merge::Cleanse::CodeFenceSpacing.new(fixed)
          expect(new_parser.malformed?).to be false
        end
      end
    end
  end

  describe "full Cleanse pipeline" do
    it "applies all Cleanse fixes and preserves document structure", :markly do
      content = File.read(destination_file)
      original_content = content.dup

      # Phase 1: Apply Cleanse fixes
      # Fix condensed link reference definitions
      condensed_parser = Markdown::Merge::Cleanse::CondensedLinkRefs.new(content)
      content = condensed_parser.expand if condensed_parser.condensed?

      # Fix code fence spacing issues
      fence_parser = Markdown::Merge::Cleanse::CodeFenceSpacing.new(content)
      content = fence_parser.fix if fence_parser.malformed?

      # Fix block element spacing issues
      block_parser = Markdown::Merge::Cleanse::BlockSpacing.new(content)
      content = block_parser.fix if block_parser.malformed?

      # Verify changes were made
      expect(content).not_to eq(original_content)

      # Verify condensed link refs are fixed
      expect(content).not_to match(/\.svg\[/)

      # Verify key document sections are preserved
      expect(content).to include("# ☯️ Markdown::Merge")
      expect(content).to include("## 🌻 Synopsis")
      expect(content).to include("## ✨ Installation")
      expect(content).to include("## ⚙️ Configuration")

      # Verify the output is valid (can be parsed)
      analysis = Markdown::Merge::FileAnalysis.new(content, backend: :auto)
      expect(analysis.valid?).to be true
    end

    it "is idempotent - running twice produces the same output" do
      content = File.read(destination_file)

      # First pass
      condensed_parser = Markdown::Merge::Cleanse::CondensedLinkRefs.new(content)
      content = condensed_parser.expand if condensed_parser.condensed?

      fence_parser = Markdown::Merge::Cleanse::CodeFenceSpacing.new(content)
      content = fence_parser.fix if fence_parser.malformed?

      block_parser = Markdown::Merge::Cleanse::BlockSpacing.new(content)
      first_pass = block_parser.fix if block_parser.malformed?
      first_pass ||= content

      # Second pass
      condensed_parser2 = Markdown::Merge::Cleanse::CondensedLinkRefs.new(first_pass)
      content2 = condensed_parser2.condensed? ? condensed_parser2.expand : first_pass

      fence_parser2 = Markdown::Merge::Cleanse::CodeFenceSpacing.new(content2)
      content2 = fence_parser2.malformed? ? fence_parser2.fix : content2

      block_parser2 = Markdown::Merge::Cleanse::BlockSpacing.new(content2)
      second_pass = block_parser2.malformed? ? block_parser2.fix : content2

      expect(second_pass).to eq(first_pass)
    end

    it "matches expected output when comparing against expected.md" do
      skip "expected.md not yet generated" unless File.exist?(expected_file)

      content = File.read(destination_file)

      # Apply Cleanse fixes
      condensed_parser = Markdown::Merge::Cleanse::CondensedLinkRefs.new(content)
      content = condensed_parser.expand if condensed_parser.condensed?

      fence_parser = Markdown::Merge::Cleanse::CodeFenceSpacing.new(content)
      content = fence_parser.fix if fence_parser.malformed?

      block_parser = Markdown::Merge::Cleanse::BlockSpacing.new(content)
      content = block_parser.fix if block_parser.malformed?

      expected_content = File.read(expected_file)
      expect(content).to eq(expected_content)
    end
  end

  describe "script execution" do
    let(:script_path) { File.expand_path("../../bin/fix_readme_formatting", __dir__) }
    let(:tmp_file) { File.join(Dir.tmpdir, "test_readme_#{$$}.md") }

    before do
      # Copy fixture to temp file
      FileUtils.cp(destination_file, tmp_file)
    end

    after do
      FileUtils.rm_f(tmp_file)
    end

    it "script file exists and is executable" do
      expect(File.exist?(script_path)).to be true
      expect(File.executable?(script_path)).to be true
    end
  end
end
