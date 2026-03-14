# frozen_string_literal: true

RSpec.describe "SmartMerger standalone HTML comment fixture", :markdown_parsing do
  let(:fixture_dir) { File.expand_path("../fixtures/04_full_document_comment_gap", __dir__) }
  let(:template) { File.read(File.join(fixture_dir, "template.md")) }
  let(:destination) { File.read(File.join(fixture_dir, "destination.md")) }
  let(:expected) { File.read(File.join(fixture_dir, "expected.md")) }

  it "preserves a destination standalone HTML comment-only section during template-preferred fuzzy paragraph replacement" do
    result = Markdown::Merge::SmartMerger.new(
      template,
      destination,
      backend: :auto,
      preference: :template,
      match_refiner: Ast::Merge::ContentMatchRefiner.new(
        threshold: 0.8,
        node_types: [:paragraph],
      ),
    ).merge

    expect(result).to eq(expected)
  end

  it "preserves destination-owned link reference definitions when template-preferred fuzzy paragraph replacement keeps destination docs" do
    template = <<~MARKDOWN
      # Title

      This is the canonical project description with [Docs][docs].
    MARKDOWN

    destination = <<~MARKDOWN
      # Title

      <!-- Destination docs -->

      [docs]: https://example.test/docs

      This is the canoncal project description with [Docs][docs].
    MARKDOWN

    result = Markdown::Merge::SmartMerger.new(
      template,
      destination,
      backend: :auto,
      preference: :template,
      match_refiner: Ast::Merge::ContentMatchRefiner.new(
        threshold: 0.8,
        node_types: [:paragraph],
      ),
    ).merge_result

    expect(result.content).to eq(<<~MARKDOWN)
      # Title

      <!-- Destination docs -->

      [docs]: https://example.test/docs

      This is the canonical project description with [Docs][docs].
    MARKDOWN
    expect(result.stats).to include(nodes_modified: 1)
  end

  it "preserves destination-owned consumed link reference definitions when a kept template-only paragraph still needs them after removal mode deletes legacy content" do
    template = <<~MARKDOWN
      # Title

      This is the canonical project description with [Docs][docs].
    MARKDOWN

    destination = <<~MARKDOWN
      # Title

      ## Legacy

      Legacy notes.

      [docs]: https://example.test/docs
    MARKDOWN

    result = Markdown::Merge::SmartMerger.new(
      template,
      destination,
      backend: :auto,
      preference: :template,
      add_template_only_nodes: true,
      remove_template_missing_nodes: true,
    ).merge_result

    expect(result.content).to eq(<<~MARKDOWN)
      # Title

      [docs]: https://example.test/docs

      This is the canonical project description with [Docs][docs].
    MARKDOWN
    expect(result.stats).to include(
      nodes_added: 1,
      nodes_removed: 2,
      nodes_modified: 0,
    )
  end
end
