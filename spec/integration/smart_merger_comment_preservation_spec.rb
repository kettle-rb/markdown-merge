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
end
