# frozen_string_literal: true

RSpec.describe Markdown::Merge::SmartMerger do
  let(:template_content) do
    <<~MARKDOWN
      # Project Title

      ## Description

      This is a template description.

      ## Installation

      ```bash
      npm install example
      ```

      ## Usage

      Use this library like so.
    MARKDOWN
  end

  let(:dest_content) do
    <<~MARKDOWN
      # Project Title

      ## Description

      This is my custom description that I wrote.

      ## Installation

      ```bash
      npm install example
      ```

      ## Custom Section

      This section only exists in destination.
    MARKDOWN
  end

  let(:content_with_freeze) do
    <<~MARKDOWN
      # Title

      <!-- markdown-merge:freeze -->
      ## Frozen Section
      Do not modify this content.
      <!-- markdown-merge:unfreeze -->

      ## Regular Section
    MARKDOWN
  end

  describe "#initialize", :markdown_backend do
    it "creates merger with auto backend" do
      merger = described_class.new(template_content, dest_content)
      expect(merger).to be_a(described_class)
    end

    it "resolves the backend" do
      merger = described_class.new(template_content, dest_content)
      expect([:commonmarker, :markly]).to include(merger.backend)
    end

    it "accepts explicit backend option", :commonmarker do
      merger = described_class.new(template_content, dest_content, backend: :commonmarker)
      expect(merger.backend).to eq(:commonmarker)
    end

    it "raises for invalid backend" do
      expect {
        described_class.new(template_content, dest_content, backend: :invalid)
      }.to raise_error(ArgumentError, /Unknown backend/)
    end

    it "accepts preference option" do
      merger = described_class.new(template_content, dest_content, preference: :template)
      expect(merger).to be_a(described_class)
    end

    it "accepts add_template_only_nodes option" do
      merger = described_class.new(template_content, dest_content, add_template_only_nodes: true)
      expect(merger).to be_a(described_class)
    end

    it "accepts inner_merge_code_blocks option" do
      merger = described_class.new(template_content, dest_content, inner_merge_code_blocks: true)
      expect(merger).to be_a(described_class)
    end

    it "accepts freeze_token option" do
      merger = described_class.new(template_content, dest_content, freeze_token: "custom-token")
      expect(merger).to be_a(described_class)
    end
  end

  describe "#merge", :markdown_backend do
    it "returns merged content as string" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge

      expect(result).to be_a(String)
    end

    it "preserves destination content by default" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge

      expect(result).to include("my custom description")
    end

    it "preserves destination-only sections" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge

      expect(result).to include("Custom Section")
    end
  end

  describe "#merge_result", :markdown_backend do
    it "returns MergeResult object" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge_result

      expect(result).to be_a(Markdown::Merge::MergeResult)
    end

    it "includes content in result" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge_result

      expect(result.content).to be_a(String)
    end

    it "includes stats in result" do
      merger = described_class.new(template_content, dest_content)
      result = merger.merge_result

      expect(result.stats).to be_a(Hash)
    end
  end

  describe "preference: :template", :markdown_backend do
    it "uses template content for matching nodes" do
      merger = described_class.new(template_content, dest_content, preference: :template)
      result = merger.merge

      expect(result).to include("template description")
    end
  end

  describe "add_template_only_nodes: true", :markdown_backend do
    it "adds nodes that only exist in template" do
      merger = described_class.new(template_content, dest_content, add_template_only_nodes: true)
      result = merger.merge

      expect(result).to include("Usage")
    end
  end

  describe "freeze blocks", :markdown_backend do
    let(:template_with_changed_freeze) do
      <<~MARKDOWN
        # Title

        <!-- markdown-merge:freeze -->
        ## Frozen Section
        Modified template content that should be ignored.
        <!-- markdown-merge:unfreeze -->

        ## Regular Section
      MARKDOWN
    end

    it "preserves destination freeze block content" do
      merger = described_class.new(template_with_changed_freeze, content_with_freeze)
      result = merger.merge

      expect(result).to include("Do not modify this content")
      expect(result).not_to include("Modified template content")
    end
  end

  describe "backend consistency", :commonmarker, :markly do
    it "produces similar results across backends" do
      cm_merger = described_class.new(template_content, dest_content, backend: :commonmarker)
      markly_merger = described_class.new(template_content, dest_content, backend: :markly)

      cm_result = cm_merger.merge
      markly_result = markly_merger.merge

      # Both should preserve destination description
      expect(cm_result).to include("my custom description")
      expect(markly_result).to include("my custom description")

      # Both should preserve destination-only section
      expect(cm_result).to include("Custom Section")
      expect(markly_result).to include("Custom Section")
    end
  end
end

