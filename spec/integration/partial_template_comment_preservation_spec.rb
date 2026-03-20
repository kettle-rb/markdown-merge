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

  it "preserves destination-only link reference definitions during replace_mode section replacement" do
    template = <<~MARKDOWN
      ## Description

      Template intro.

      Template body with [Docs][docs] and [API][api].
    MARKDOWN

    destination = <<~MARKDOWN
      # Title

      ## Description

      Destination intro.

      <!-- Destination docs -->

      [docs]: https://example.test/docs
      [api]: https://example.test/api

      Destination body.

      ## After

      Keep me.
    MARKDOWN

    expected = <<~MARKDOWN
      # Title

      ## Description

      Template intro.

      <!-- Destination docs -->

      [docs]: https://example.test/docs
      [api]: https://example.test/api

      Template body with [Docs][docs] and [API][api].

      ## After

      Keep me.
    MARKDOWN

    result = Markdown::Merge::PartialTemplateMerger.new(
      template: template,
      destination: destination,
      anchor: {type: :heading, text: /Description/},
      backend: :auto,
      preference: :template,
      replace_mode: true,
    ).merge

    expect(result.content).to eq(expected)
    expect(result.stats).to include(
      mode: :replace,
      preserved_destination_comment_fragments: 1,
      preserved_destination_link_definitions: 2,
    )
  end

  it "preserves a trailing standalone HTML comment plus trailing destination-only link reference definitions during replace_mode section replacement" do
    template = <<~MARKDOWN
      ## Description

      Template body with [Docs][docs] and [API][api].
    MARKDOWN

    destination = <<~MARKDOWN
      # Title

      ## Description

      Destination body.

      <!-- Destination trailing docs -->

      [docs]: https://example.test/docs
      [api]: https://example.test/api

      ## After

      Keep me.
    MARKDOWN

    expected = <<~MARKDOWN
      # Title

      ## Description

      Template body with [Docs][docs] and [API][api].

      <!-- Destination trailing docs -->

      [docs]: https://example.test/docs
      [api]: https://example.test/api

      ## After

      Keep me.
    MARKDOWN

    result = Markdown::Merge::PartialTemplateMerger.new(
      template: template,
      destination: destination,
      anchor: {type: :heading, text: /Description/},
      backend: :auto,
      preference: :template,
      replace_mode: true,
    ).merge

    expect(result.content).to eq(expected)
    expect(result.stats).to include(
      mode: :replace,
      preserved_destination_comment_fragments: 1,
      preserved_destination_link_definitions: 2,
    )
  end

  it "does not duplicate a destination link reference definition already provided by the template section" do
    template = <<~MARKDOWN
      ## Description

      Template intro.

      Template body with [Docs][docs].

      [docs]: https://template.test/docs
    MARKDOWN

    destination = <<~MARKDOWN
      # Title

      ## Description

      [docs]: https://destination.test/docs

      Destination body.

      ## After

      Keep me.
    MARKDOWN

    expected = <<~MARKDOWN
      # Title

      ## Description

      Template intro.

      Template body with [Docs][docs].

      [docs]: https://template.test/docs

      ## After

      Keep me.
    MARKDOWN

    result = Markdown::Merge::PartialTemplateMerger.new(
      template: template,
      destination: destination,
      anchor: {type: :heading, text: /Description/},
      backend: :auto,
      preference: :template,
      replace_mode: true,
    ).merge

    expect(result.content).to eq(expected)
    expect(result.stats).to eq(mode: :replace)
  end
end
