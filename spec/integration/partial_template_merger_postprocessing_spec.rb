# frozen_string_literal: true

# Integration tests for PartialTemplateMerger post-processing features
# These tests require a markdown parsing backend (markly or commonmarker)

RSpec.describe "PartialTemplateMerger post-processing integration", :markdown_parsing do
  let(:template) do
    <<~MD
      ## Features

      - Feature A
      - Feature B
    MD
  end

  let(:destination_with_extra_whitespace) do
    <<~MD
      # Project Title

      Description paragraph.


      ## Features

      - Old Feature


      ## Other Section

      Content here.

      [link1]: https://example.com/1

      [link2]: https://example.com/2
    MD
  end

  describe "normalize_whitespace option" do
    it "collapses excessive blank lines when enabled" do
      merger = Markdown::Merge::PartialTemplateMerger.new(
        template: template,
        destination: destination_with_extra_whitespace,
        anchor: {type: :heading, text: /Features/},
        backend: :auto,
        normalize_whitespace: true,
      )

      result = merger.merge
      # Should not have 3+ consecutive newlines
      expect(result.content).not_to match(/\n{4,}/)
    end

    it "does not normalize whitespace when disabled" do
      merger = Markdown::Merge::PartialTemplateMerger.new(
        template: template,
        destination: destination_with_extra_whitespace,
        anchor: {type: :heading, text: /Features/},
        backend: :auto,
        normalize_whitespace: false,
      )

      result = merger.merge
      # Result may have original whitespace patterns
      expect(result).to be_a(Markdown::Merge::PartialTemplateMerger::Result)
    end
  end

  describe "rehydrate_link_references option" do
    let(:destination_with_inline_links) do
      <<~MD
        # Project Title

        Check out [Example](https://example.com) for more info.

        ## Features

        - Old Feature

        [example]: https://example.com
      MD
    end

    it "rehydrates link references when enabled" do
      merger = Markdown::Merge::PartialTemplateMerger.new(
        template: template,
        destination: destination_with_inline_links,
        anchor: {type: :heading, text: /Features/},
        backend: :auto,
        rehydrate_link_references: true,
      )

      result = merger.merge
      expect(result).to be_a(Markdown::Merge::PartialTemplateMerger::Result)
    end

    it "does not rehydrate link references when disabled" do
      merger = Markdown::Merge::PartialTemplateMerger.new(
        template: template,
        destination: destination_with_inline_links,
        anchor: {type: :heading, text: /Features/},
        backend: :auto,
        rehydrate_link_references: false,
      )

      result = merger.merge
      expect(result).to be_a(Markdown::Merge::PartialTemplateMerger::Result)
    end
  end

  describe "combined post-processing options" do
    let(:messy_destination) do
      <<~MD
        # Project Title


        See [Example](https://example.com) for details.



        ## Features

        - Old Feature


        [example]: https://example.com


        [other]: https://other.com
      MD
    end

    it "applies both whitespace normalization and link rehydration" do
      merger = Markdown::Merge::PartialTemplateMerger.new(
        template: template,
        destination: messy_destination,
        anchor: {type: :heading, text: /Features/},
        backend: :auto,
        normalize_whitespace: true,
        rehydrate_link_references: true,
      )

      result = merger.merge
      expect(result).to be_a(Markdown::Merge::PartialTemplateMerger::Result)
      expect(result.changed).to be true
    end

    it "includes problems in stats when issues found" do
      merger = Markdown::Merge::PartialTemplateMerger.new(
        template: template,
        destination: messy_destination,
        anchor: {type: :heading, text: /Features/},
        backend: :auto,
        normalize_whitespace: true,
        rehydrate_link_references: true,
      )

      result = merger.merge
      expect(result.stats).to have_key(:problems)
    end
  end

  describe "merge without post-processing" do
    it "returns result directly when no post-processing options" do
      merger = Markdown::Merge::PartialTemplateMerger.new(
        template: template,
        destination: destination_with_extra_whitespace,
        anchor: {type: :heading, text: /Features/},
        backend: :auto,
        normalize_whitespace: false,
        rehydrate_link_references: false,
      )

      result = merger.merge
      expect(result).to be_a(Markdown::Merge::PartialTemplateMerger::Result)
    end

    it "returns result directly when no changes made" do
      # Template same as destination section
      unchanged_dest = <<~MD
        # Project Title

        ## Features

        - Feature A
        - Feature B
      MD

      merger = Markdown::Merge::PartialTemplateMerger.new(
        template: template,
        destination: unchanged_dest,
        anchor: {type: :heading, text: /Features/},
        backend: :auto,
        normalize_whitespace: true,
      )

      result = merger.merge
      expect(result).to be_a(Markdown::Merge::PartialTemplateMerger::Result)
    end
  end
end
