# frozen_string_literal: true

RSpec.describe "markdown comment behavior complements", :markdown_parsing do
  describe "link definition complement" do
    it "preserves destination-only link definitions even in removal mode" do
      template = <<~MARKDOWN
        [beta]: /two
      MARKDOWN
      destination = <<~MARKDOWN
        [alpha]: /one
        [beta]: /two
      MARKDOWN

      result = Markdown::Merge::SmartMerger.new(
        template,
        destination,
        remove_template_missing_nodes: true,
      ).merge

      expect(result).to eq(destination)
    end
  end

  describe "block node complement" do
    it "removes destination-only H2 headings in removal mode" do
      template = <<~MARKDOWN
        ## Beta
      MARKDOWN
      destination = <<~MARKDOWN
        ## Alpha
        ## Beta
      MARKDOWN

      result = Markdown::Merge::SmartMerger.new(
        template,
        destination,
        remove_template_missing_nodes: true,
      ).merge

      expect(result).to eq(template)
    end

    it "keeps the file preamble separate in the augmenter even when the first block attachment coalesces it" do
      source = <<~MARKDOWN
        <!-- Document header -->

        <!-- Alpha docs -->

        ## Alpha
      MARKDOWN
      analysis = Markdown::Merge::FileAnalysis.new(source)
      heading = analysis.statements.find { |statement| statement.merge_type == :heading }

      attachment = analysis.comment_attachment_for(heading)
      augmenter = analysis.comment_augmenter(owners: [heading])

      expect(augmenter.preamble_region&.normalized_content).to eq("Document header")
      expect(attachment.leading_region&.normalized_content).to eq("Document header\nAlpha docs")
      expect(attachment.leading_region).not_to be_floating
    end

    it "attaches later block-owner docs directly with their interstitial gap metadata" do
      source = <<~MARKDOWN
        ## Alpha

        <!-- Beta docs -->

        Paragraph beta.
      MARKDOWN
      analysis = Markdown::Merge::FileAnalysis.new(source)
      paragraph = analysis.statements.find { |statement| statement.merge_type == :paragraph }

      attachment = analysis.comment_attachment_for(paragraph)

      expect(attachment.leading_region&.normalized_content).to eq("Beta docs")
      expect(attachment.leading_region).not_to be_floating
      expect(attachment.leading_gap&.kind).to eq(:interstitial)
      expect(attachment.leading_gap&.start_line).to eq(4)
      expect(attachment.leading_gap&.end_line).to eq(4)
    end
  end
end
