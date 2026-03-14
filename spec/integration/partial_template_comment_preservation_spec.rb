# frozen_string_literal: true

RSpec.describe "PartialTemplateMerger standalone HTML comment fixture", :markdown_parsing do
  let(:fixture_dir) { File.expand_path("../fixtures/03_partial_replace_comments", __dir__) }
  let(:template) { File.read(File.join(fixture_dir, "template.md")) }
  let(:destination) { File.read(File.join(fixture_dir, "destination.md")) }
  let(:expected) { File.read(File.join(fixture_dir, "expected.md")) }

  it "preserves a between-block standalone HTML comment during replace_mode section replacement" do
    result = Markdown::Merge::PartialTemplateMerger.new(
      template: template,
      destination: destination,
      anchor: {type: :heading, text: /Description/},
      backend: :auto,
      preference: :template,
      replace_mode: true,
    ).merge

    expect(result.content).to eq(expected)
  end
end
