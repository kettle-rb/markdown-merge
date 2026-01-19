# frozen_string_literal: true

RSpec.describe Markdown::Merge::Cleanse::BlockSpacing do
  describe "#malformed?" do
    it "returns false for empty string" do
      parser = described_class.new("")
      expect(parser.malformed?).to be false
    end

    it "returns false for well-formed content" do
      content = <<~MD
        # Heading

        Some text.

        - List item

        ## Another Heading
      MD
      parser = described_class.new(content)
      expect(parser.malformed?).to be false
    end

    it "returns true when thematic break lacks following blank line" do
      content = <<~MD
        Some text

        ---
        More text
      MD
      parser = described_class.new(content)
      expect(parser.malformed?).to be true
    end

    it "returns true when list item is followed by heading without blank line" do
      content = <<~MD
        - List item 1
        - List item 2
        ### Heading
      MD
      parser = described_class.new(content)
      expect(parser.malformed?).to be true
    end

    it "returns true when markdown is followed by HTML without blank line" do
      content = <<~MD
        - List item
        </details>
      MD
      parser = described_class.new(content)
      expect(parser.malformed?).to be true
    end

    it "returns true when HTML close tag is followed by markdown without blank line" do
      content = <<~MD
        </details>
        ## Next Section
      MD
      parser = described_class.new(content)
      expect(parser.malformed?).to be true
    end
  end

  describe "#issue_count" do
    it "returns 0 for well-formed content" do
      content = "# Heading\n\nSome text.\n"
      parser = described_class.new(content)
      expect(parser.issue_count).to eq(0)
    end

    it "counts multiple issues" do
      content = <<~MD
        - Item
        ### Heading

        ---
        Text

        </details>
        ## Another
      MD
      parser = described_class.new(content)
      expect(parser.issue_count).to eq(3)
    end
  end

  describe "#issues" do
    it "includes line numbers (1-based)" do
      content = <<~MD
        - Item
        ### Heading
      MD
      parser = described_class.new(content)

      expect(parser.issues.size).to eq(1)
      expect(parser.issues.first[:line]).to eq(1)
      expect(parser.issues.first[:type]).to eq(:list_before_heading)
    end

    it "includes descriptions" do
      content = "---\nText\n"
      parser = described_class.new(content)

      expect(parser.issues.first[:description]).to include("blank line")
    end
  end

  describe "#fix" do
    it "returns original content when no issues" do
      content = "# Heading\n\nSome text.\n"
      parser = described_class.new(content)
      expect(parser.fix).to eq(content)
    end

    it "adds blank line after thematic break" do
      content = "---\nText\n"
      parser = described_class.new(content)
      result = parser.fix

      expect(result).to eq("---\n\nText\n")
    end

    it "adds blank line between list and heading" do
      content = <<~MD
        - Item 1
        - Item 2
        ### Heading
      MD
      parser = described_class.new(content)
      result = parser.fix

      expect(result).to include("- Item 2\n\n### Heading")
    end

    it "adds blank line after HTML close tag" do
      content = "</details>\n## Section\n"
      parser = described_class.new(content)
      result = parser.fix

      expect(result).to eq("</details>\n\n## Section\n")
    end

    it "adds blank line before HTML when preceded by markdown" do
      content = "- List item\n</details>\n"
      parser = described_class.new(content)
      result = parser.fix

      expect(result).to eq("- List item\n\n</details>\n")
    end

    it "adds blank line before HTML open tag when preceded by markdown" do
      content = "Some text\n<details>\n"
      parser = described_class.new(content)
      result = parser.fix

      expect(result).to eq("Some text\n\n<details>\n")
    end

    it "handles nested list items before headings" do
      content = <<~MD
        - Item
            - Nested item
        ### Heading
      MD
      parser = described_class.new(content)
      result = parser.fix

      expect(result).to include("    - Nested item\n\n### Heading")
    end

    it "fixes multiple issues in one pass" do
      content = <<~MD
        - Item
        ### Heading 1

        ---
        Text

        </details>
        ## Heading 2
      MD
      parser = described_class.new(content)
      result = parser.fix

      # All three issues should be fixed
      expect(result).to include("- Item\n\n### Heading 1")
      expect(result).to include("---\n\nText")
      expect(result).to include("</details>\n\n## Heading 2")
    end

    it "does not add blank line when one already exists" do
      content = <<~MD
        - Item

        ### Heading
      MD
      parser = described_class.new(content)

      # No issues, so no changes
      expect(parser.malformed?).to be false
      expect(parser.fix).to eq(content)
    end

    it "is idempotent" do
      content = <<~MD
        - Item
        ### Heading
      MD
      parser1 = described_class.new(content)
      first_pass = parser1.fix

      parser2 = described_class.new(first_pass)
      second_pass = parser2.fix

      expect(second_pass).to eq(first_pass)
    end
  end

  describe "thematic break variants" do
    it "detects --- variant" do
      parser = described_class.new("---\nText\n")
      expect(parser.malformed?).to be true
    end

    it "detects *** variant" do
      parser = described_class.new("***\nText\n")
      expect(parser.malformed?).to be true
    end

    it "detects ___ variant" do
      parser = described_class.new("___\n Text\n")
      expect(parser.malformed?).to be true
    end

    it "detects longer variants" do
      parser = described_class.new("-----\nText\n")
      expect(parser.malformed?).to be true
    end
  end

  describe "list item variants" do
    it "detects - bullet" do
      parser = described_class.new("- Item\n# Heading\n")
      expect(parser.malformed?).to be true
    end

    it "detects * bullet" do
      parser = described_class.new("* Item\n# Heading\n")
      expect(parser.malformed?).to be true
    end

    it "detects + bullet" do
      parser = described_class.new("+ Item\n# Heading\n")
      expect(parser.malformed?).to be true
    end

    it "detects numbered lists" do
      parser = described_class.new("1. Item\n# Heading\n")
      expect(parser.malformed?).to be true
    end

    it "detects indented list items" do
      parser = described_class.new("    - Nested\n# Heading\n")
      expect(parser.malformed?).to be true
    end
  end

  describe "HTML close tags" do
    it "detects </details>" do
      parser = described_class.new("</details>\n# Heading\n")
      expect(parser.malformed?).to be true
    end

    it "detects </summary>" do
      parser = described_class.new("</summary>\nText\n")
      expect(parser.malformed?).to be true
    end

    it "detects markdown before </details>" do
      parser = described_class.new("- Item\n</details>\n")
      expect(parser.malformed?).to be true
    end

    it "does not flag HTML followed by link ref" do
      # Link reference definitions are technically markdown but often
      # appear right after HTML blocks
      content = "</details>\n\n[ref]: https://example.com\n"
      parser = described_class.new(content)
      expect(parser.malformed?).to be false
    end

    it "does not flag HTML followed by more HTML" do
      content = "</details>\n</div>\n"
      parser = described_class.new(content)
      expect(parser.malformed?).to be false
    end

    it "does not insert blank lines inside HTML blocks" do
      content = <<~HTML
        <ul>
            <li>
                Copyright (c) 2025-2026 Peter H. Boling, of
                <a href="https://example.com">
                    Example
                    <picture>
                      <img src="https://example.com/logo.png" alt="Logo">
                    </picture>
                </a>, and contributors.
            </li>
        </ul>
      HTML
      parser = described_class.new(content)
      expect(parser.malformed?).to be false
    end

    it "does not modify content inside nested HTML blocks" do
      content = <<~HTML
        <ul>
            <li>
                Some text
                <a href="url">Link</a>
            </li>
        </ul>
      HTML
      parser = described_class.new(content)
      result = parser.fix

      # Content should be unchanged
      expect(result).to eq(content)
    end

    it "inserts blank line before </details> when preceded by markdown" do
      content = <<~MD
        - List item
        </details>
      MD
      parser = described_class.new(content)
      expect(parser.malformed?).to be true

      result = parser.fix
      expect(result).to eq("- List item\n\n</details>\n")
    end
  end
end
