# frozen_string_literal: true

RSpec.describe Markdown::Merge::LinkReferenceRehydrator do
  describe ".rehydrate" do
    it "is a convenience class method" do
      content = <<~MD
        Check [here](https://example.com) for info.

        [here]: https://example.com
      MD

      result = described_class.rehydrate(content)
      expect(result).to include("[here][here]")
    end
  end

  describe "#rehydrate" do
    it "converts inline link to reference style" do
      content = <<~MD
        Check [here](https://example.com) for info.

        [here]: https://example.com
      MD

      rehydrator = described_class.new(content)
      result = rehydrator.rehydrate

      expect(result).to include("[here][here]")
      expect(result).not_to include("[here](https://example.com)")
    end

    it "converts inline image to reference style" do
      content = <<~MD
        See ![logo](https://example.com/logo.png) for branding.

        [logo]: https://example.com/logo.png
      MD

      rehydrator = described_class.new(content)
      result = rehydrator.rehydrate

      expect(result).to include("![logo][logo]")
      expect(result).not_to include("![logo](https://example.com/logo.png)")
    end

    it "preserves content when no definitions match" do
      content = <<~MD
        Check [here](https://example.com) for info.

        [other]: https://other.com
      MD

      rehydrator = described_class.new(content)
      result = rehydrator.rehydrate

      expect(result).to eq(content)
      expect(rehydrator.changed?).to be false
    end

    it "preserves content when no definitions exist" do
      content = "Check [here](https://example.com) for info."

      rehydrator = described_class.new(content)
      result = rehydrator.rehydrate

      expect(result).to eq(content)
    end

    it "preserves links with titles (cannot rehydrate)" do
      content = <<~MD
        Check [here](https://example.com "Example Site") for info.

        [here]: https://example.com
      MD

      rehydrator = described_class.new(content)
      result = rehydrator.rehydrate

      # Links with titles should be preserved as-is
      expect(result).to include('[here](https://example.com "Example Site")')
      expect(rehydrator.problems.all.count { |p| p[:category] == :link_has_title }).to eq(1)
    end

    it "preserves images with titles (cannot rehydrate)" do
      content = <<~MD
        See ![logo](https://example.com/logo.png "Company Logo") for branding.

        [logo]: https://example.com/logo.png
      MD

      rehydrator = described_class.new(content)
      result = rehydrator.rehydrate

      expect(result).to include('![logo](https://example.com/logo.png "Company Logo")')
      expect(rehydrator.problems.all.count { |p| p[:category] == :image_has_title }).to eq(1)
    end

    it "handles emoji in labels" do
      content = <<~MD
        Check [🎨 Art](https://example.com/art) for designs.

        [🎨logo]: https://example.com/art
      MD

      rehydrator = described_class.new(content)
      result = rehydrator.rehydrate

      expect(result).to include("[🎨 Art][🎨logo]")
    end

    it "handles multiple links in one line" do
      content = <<~MD
        Visit [foo](https://foo.com) and [bar](https://bar.com) for info.

        [foo]: https://foo.com
        [bar]: https://bar.com
      MD

      rehydrator = described_class.new(content)
      result = rehydrator.rehydrate

      expect(result).to include("[foo][foo]")
      expect(result).to include("[bar][bar]")
    end

    it "tracks rehydration count" do
      content = <<~MD
        [a](https://a.com) [b](https://b.com) [c](https://c.com)

        [a]: https://a.com
        [b]: https://b.com
        [c]: https://c.com
      MD

      rehydrator = described_class.new(content)
      rehydrator.rehydrate

      expect(rehydrator.rehydration_count).to eq(3)
      expect(rehydrator.changed?).to be true
    end
  end

  describe "overlapping replacements" do
    it "handles linked images without content loss" do
      content = <<~MD
        Click [![Logo](https://example.com/logo.png)](https://example.com) for more.

        [logo]: https://example.com/logo.png
        [example]: https://example.com
      MD

      rehydrator = described_class.new(content)
      result = rehydrator.rehydrate

      # Content should not be corrupted
      expect(result.lines.count).to eq(content.lines.count)
      expect(result).to include("Click")
      expect(result).to include("for more.")
    end

    it "prefers outermost replacement for linked images" do
      content = <<~MD
        [![Alt Text](https://example.com/img.png)](https://example.com/link)

        [img]: https://example.com/img.png
        [link]: https://example.com/link
      MD

      rehydrator = described_class.new(content)
      result = rehydrator.rehydrate

      # The outer link should be rehydrated, inner image stays inline
      # OR the image gets rehydrated but not both
      # Key: content is not corrupted
      expect(result).not_to be_empty
      expect(result.lines.count).to eq(content.lines.count)
    end

    it "handles multiple linked images in same line" do
      content = <<~MD
        [![A](https://a.com/img)](https://a.com) [![B](https://b.com/img)](https://b.com)

        [a]: https://a.com
        [a-img]: https://a.com/img
        [b]: https://b.com
        [b-img]: https://b.com/img
      MD

      rehydrator = described_class.new(content)
      result = rehydrator.rehydrate

      # Ensure no content loss
      expect(result.lines.count).to eq(content.lines.count)
      expect(result).to include("[![A")
      expect(result).to include("[![B")
    end

    it "does not corrupt document structure" do
      # This is the actual bug scenario from the fixture
      content = <<~MD
        # Title

        Some intro text.

        [![Logo](https://logos.example.com/logo.svg)](https://discord.example.com) [![Other](https://logos.example.com/other.svg)](https://github.example.com)

        ## Section

        More content here.

        [logo]: https://logos.example.com/logo.svg
        [discord]: https://discord.example.com
        [other]: https://logos.example.com/other.svg
        [github]: https://github.example.com
      MD

      rehydrator = described_class.new(content)
      result = rehydrator.rehydrate

      # Key sections must be preserved
      expect(result).to include("# Title")
      expect(result).to include("Some intro text.")
      expect(result).to include("## Section")
      expect(result).to include("More content here.")

      # Line count should not decrease dramatically
      expect(result.lines.count).to be >= content.lines.count - 2
    end
  end

  describe "#link_definitions" do
    it "builds URL to label mapping" do
      content = <<~MD
        [short]: https://example.com
        [longer-label]: https://example.com
      MD

      rehydrator = described_class.new(content)
      defs = rehydrator.link_definitions

      # Should prefer shorter label
      expect(defs["https://example.com"]).to eq("short")
    end
  end

  describe "#duplicate_definitions" do
    it "tracks duplicate labels for same URL" do
      content = <<~MD
        [a]: https://example.com
        [b]: https://example.com
        [c]: https://example.com
      MD

      rehydrator = described_class.new(content)
      rehydrator.rehydrate # triggers build

      dups = rehydrator.duplicate_definitions
      expect(dups["https://example.com"]).to contain_exactly("a", "b", "c")
    end

    it "records duplicate problems" do
      content = <<~MD
        [a]: https://example.com
        [b]: https://example.com
      MD

      rehydrator = described_class.new(content)
      rehydrator.rehydrate

      problems = rehydrator.problems.all
      dup_problems = problems.select { |p| p[:category] == :duplicate_link_definition }
      expect(dup_problems.count).to eq(1)
    end
  end

  describe "real-world fixture" do
    let(:fixture_path) { File.expand_path("../../fixtures/01_cleanse/destination.md", __dir__) }

    before do
      skip "Fixture not available" unless File.exist?(fixture_path)
    end

    it "does not lose content when rehydrating" do
      content = File.read(fixture_path)

      # Apply cleanse fixes first (as the pipeline does)
      condensed_parser = Markdown::Merge::Cleanse::CondensedLinkRefs.new(content)
      content = condensed_parser.expand if condensed_parser.condensed?

      fence_parser = Markdown::Merge::Cleanse::CodeFenceSpacing.new(content)
      content = fence_parser.fix if fence_parser.malformed?

      original_line_count = content.lines.count

      rehydrator = described_class.new(content)
      result = rehydrator.rehydrate

      # Line count should not decrease (rehydration shortens URLs but doesn't remove lines)
      expect(result.lines.count).to eq(original_line_count)

      # Key sections must be preserved
      expect(result).to include("## 🌻 Synopsis")
      expect(result).to include("## ✨ Installation")
      expect(result).to include("## ⚙️ Configuration")
    end
  end
end
