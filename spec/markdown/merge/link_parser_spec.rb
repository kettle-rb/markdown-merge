# frozen_string_literal: true

RSpec.describe Markdown::Merge::LinkParser do
  subject(:parser) { described_class.new }

  describe "#find_all_link_constructs" do
    it "returns empty array for content with no links or images" do
      result = parser.find_all_link_constructs("Just some text")
      expect(result).to eq([])
    end

    it "finds a simple inline link" do
      content = "Click [here](https://example.com) for info"
      result = parser.find_all_link_constructs(content)

      expect(result.size).to eq(1)
      expect(result.first[:type]).to eq(:link)
      expect(result.first[:url]).to eq("https://example.com")
    end

    it "finds a simple inline image" do
      content = "See ![logo](https://example.com/logo.png)"
      result = parser.find_all_link_constructs(content)

      expect(result.size).to eq(1)
      expect(result.first[:type]).to eq(:image)
      expect(result.first[:url]).to eq("https://example.com/logo.png")
    end

    it "detects linked images as parent-child structure" do
      content = "[![Logo](https://img.com/logo.png)](https://example.com)"
      result = parser.find_all_link_constructs(content)

      # Should return one item (the link) with the image as a child
      expect(result.size).to eq(1)
      expect(result.first[:type]).to eq(:link)
      expect(result.first[:url]).to eq("https://example.com")
      expect(result.first[:children]).to be_an(Array)
      expect(result.first[:children].size).to eq(1)
      expect(result.first[:children].first[:type]).to eq(:image)
      expect(result.first[:children].first[:url]).to eq("https://img.com/logo.png")
    end

    it "handles multiple linked images in same content" do
      content = "[![A](a.png)](a.com) text [![B](b.png)](b.com)"
      result = parser.find_all_link_constructs(content)

      expect(result.size).to eq(2)
      expect(result[0][:children].size).to eq(1)
      expect(result[1][:children].size).to eq(1)
    end

    it "handles mixed links and images" do
      content = "[link](url1) ![image](url2) [![linked](url3)](url4)"
      result = parser.find_all_link_constructs(content)

      # 3 top-level items: link, image, linked image
      expect(result.size).to eq(3)
      expect(result[0][:type]).to eq(:link)
      expect(result[0][:children]).to be_nil
      expect(result[1][:type]).to eq(:image)
      expect(result[1][:children]).to be_nil
      expect(result[2][:type]).to eq(:link)
      expect(result[2][:children].size).to eq(1)
    end
  end

  describe "#build_link_tree" do
    it "returns empty array for empty inputs" do
      result = parser.build_link_tree([], [])
      expect(result).to eq([])
    end

    it "returns items unchanged when no nesting" do
      links = [
        { start_pos: 0, end_pos: 10, text: "a", url: "url1" },
        { start_pos: 20, end_pos: 30, text: "b", url: "url2" },
      ]
      result = parser.build_link_tree(links, [])

      expect(result.size).to eq(2)
      expect(result[0][:children]).to be_nil
      expect(result[1][:children]).to be_nil
    end

    it "nests image inside link when positions indicate containment" do
      links = [{ start_pos: 0, end_pos: 50, text: "![img](url1)", url: "url2" }]
      images = [{ start_pos: 1, end_pos: 20, alt: "img", url: "url1" }]

      result = parser.build_link_tree(links, images)

      expect(result.size).to eq(1)
      expect(result.first[:type]).to eq(:link)
      expect(result.first[:children].size).to eq(1)
      expect(result.first[:children].first[:type]).to eq(:image)
    end

    it "does not nest items that are not contained" do
      links = [{ start_pos: 0, end_pos: 20, text: "a", url: "url1" }]
      images = [{ start_pos: 25, end_pos: 40, alt: "b", url: "url2" }]

      result = parser.build_link_tree(links, images)

      expect(result.size).to eq(2)
      expect(result[0][:children]).to be_nil
      expect(result[1][:children]).to be_nil
    end
  end

  describe "#flatten_leaf_first" do
    it "returns empty array for empty input" do
      result = parser.flatten_leaf_first([])
      expect(result).to eq([])
    end

    it "returns items unchanged when no nesting" do
      items = [
        { type: :link, start_pos: 0, end_pos: 10 },
        { type: :image, start_pos: 20, end_pos: 30 },
      ]
      result = parser.flatten_leaf_first(items)

      expect(result.size).to eq(2)
      expect(result.map { |i| i[:type] }).to eq([:link, :image])
    end

    it "returns children before parents (leaf-first)" do
      items = [
        {
          type: :link,
          start_pos: 0,
          end_pos: 50,
          children: [
            { type: :image, start_pos: 1, end_pos: 20 },
          ],
        },
      ]
      result = parser.flatten_leaf_first(items)

      expect(result.size).to eq(2)
      # Child (image) should come before parent (link)
      expect(result[0][:type]).to eq(:image)
      expect(result[1][:type]).to eq(:link)
    end

    it "handles deeply nested structures" do
      # This is a hypothetical case - markdown doesn't actually support this
      items = [
        {
          type: :link,
          start_pos: 0,
          end_pos: 100,
          children: [
            {
              type: :link,
              start_pos: 1,
              end_pos: 50,
              children: [
                { type: :image, start_pos: 2, end_pos: 20 },
              ],
            },
          ],
        },
      ]
      result = parser.flatten_leaf_first(items)

      expect(result.size).to eq(3)
      # Deepest child first, then middle, then outermost
      expect(result.map { |i| i[:start_pos] }).to eq([2, 1, 0])
    end

    it "removes :children key from output" do
      items = [
        {
          type: :link,
          start_pos: 0,
          end_pos: 50,
          children: [{ type: :image, start_pos: 1, end_pos: 20 }],
        },
      ]
      result = parser.flatten_leaf_first(items)

      result.each do |item|
        expect(item).not_to have_key(:children)
      end
    end

    it "handles multiple top-level items with nesting" do
      items = [
        {
          type: :link,
          start_pos: 0,
          end_pos: 50,
          children: [{ type: :image, start_pos: 1, end_pos: 20 }],
        },
        { type: :link, start_pos: 60, end_pos: 80 },
        {
          type: :link,
          start_pos: 90,
          end_pos: 150,
          children: [{ type: :image, start_pos: 91, end_pos: 120 }],
        },
      ]
      result = parser.flatten_leaf_first(items)

      # 5 total items: 2 children + 3 parents
      expect(result.size).to eq(5)
      # Children should come before their parents
      expect(result.map { |i| i[:start_pos] }).to eq([1, 0, 60, 91, 90])
    end
  end

  describe "#parse_definitions" do
    it "parses simple link definition" do
      content = "[example]: https://example.com"
      result = parser.parse_definitions(content)

      expect(result.size).to eq(1)
      expect(result.first[:label]).to eq("example")
      expect(result.first[:url]).to eq("https://example.com")
    end

    it "parses definition with title" do
      content = '[example]: https://example.com "Example Site"'
      result = parser.parse_definitions(content)

      expect(result.first[:title]).to eq("Example Site")
    end

    it "parses multiple definitions" do
      content = <<~MD
        [a]: https://a.com
        [b]: https://b.com
        [c]: https://c.com
      MD
      result = parser.parse_definitions(content)

      expect(result.size).to eq(3)
    end

    it "handles emoji in labels" do
      content = "[🎨logo]: https://example.com/logo.png"
      result = parser.parse_definitions(content)

      expect(result.first[:label]).to eq("🎨logo")
    end
  end

  describe "#find_inline_links" do
    it "finds inline links with positions" do
      content = "Click [here](https://example.com) for info"
      result = parser.find_inline_links(content)

      expect(result.size).to eq(1)
      expect(result.first[:text]).to eq("here")
      expect(result.first[:url]).to eq("https://example.com")
      expect(result.first[:start_pos]).to eq(6)
      expect(result.first[:end_pos]).to eq(33)
    end

    it "skips image constructs" do
      content = "![image](url.png) [link](url.com)"
      result = parser.find_inline_links(content)

      # Should only find the link, not the image
      expect(result.size).to eq(1)
      expect(result.first[:text]).to eq("link")
    end
  end

  describe "#find_inline_images" do
    it "finds inline images with positions" do
      content = "See ![logo](https://example.com/logo.png) here"
      result = parser.find_inline_images(content)

      expect(result.size).to eq(1)
      expect(result.first[:alt]).to eq("logo")
      expect(result.first[:url]).to eq("https://example.com/logo.png")
    end
  end
end
