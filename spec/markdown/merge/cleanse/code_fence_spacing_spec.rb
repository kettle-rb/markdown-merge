# frozen_string_literal: true

RSpec.describe Markdown::Merge::Cleanse::CodeFenceSpacing do
  describe "#malformed?" do
    it "returns true for fence with space before language" do
      text = "``` ruby\nputs 'hello'\n```"
      parser = described_class.new(text)
      expect(parser.malformed?).to be true
    end

    it "returns true for fence with tab before language" do
      text = "```\truby\nputs 'hello'\n```"
      parser = described_class.new(text)
      expect(parser.malformed?).to be true
    end

    it "returns true for fence with multiple spaces before language" do
      text = "```   console\necho hello\n```"
      parser = described_class.new(text)
      expect(parser.malformed?).to be true
    end

    it "returns false for properly formatted fence" do
      text = "```ruby\nputs 'hello'\n```"
      parser = described_class.new(text)
      expect(parser.malformed?).to be false
    end

    it "returns false for fence without language" do
      text = "```\nsome code\n```"
      parser = described_class.new(text)
      expect(parser.malformed?).to be false
    end

    it "returns false for empty string" do
      parser = described_class.new("")
      expect(parser.malformed?).to be false
    end

    it "returns false for text without code fences" do
      text = "Just some regular text without any code blocks"
      parser = described_class.new(text)
      expect(parser.malformed?).to be false
    end

    it "returns true for tilde fence with space" do
      text = "~~~ bash\necho test\n~~~"
      parser = described_class.new(text)
      expect(parser.malformed?).to be true
    end

    it "returns false for tilde fence without space" do
      text = "~~~bash\necho test\n~~~"
      parser = described_class.new(text)
      expect(parser.malformed?).to be false
    end
  end

  describe "#code_blocks" do
    it "parses a single properly formatted code block" do
      text = "```ruby\nputs 'hello'\n```"
      parser = described_class.new(text)

      expect(parser.code_blocks.size).to eq(1)
      block = parser.code_blocks.first
      expect(block[:fence]).to eq("```")
      expect(block[:language]).to eq("ruby")
      expect(block[:malformed]).to be false
    end

    it "parses a malformed code block" do
      text = "``` console\necho hello\n```"
      parser = described_class.new(text)

      expect(parser.code_blocks.size).to eq(1)
      block = parser.code_blocks.first
      expect(block[:fence]).to eq("```")
      expect(block[:language]).to eq("console")
      expect(block[:spacing]).to eq(" ")
      expect(block[:malformed]).to be true
    end

    it "parses multiple code blocks" do
      text = <<~MD
        # Example

        ```ruby
        puts 'hello'
        ```

        Some text

        ``` bash
        echo world
        ```
      MD
      parser = described_class.new(text)

      expect(parser.code_blocks.size).to eq(2)
      expect(parser.code_blocks[0][:language]).to eq("ruby")
      expect(parser.code_blocks[0][:malformed]).to be false
      expect(parser.code_blocks[1][:language]).to eq("bash")
      expect(parser.code_blocks[1][:malformed]).to be true
    end

    it "handles fence without language" do
      text = "```\nsome code\n```"
      parser = described_class.new(text)

      expect(parser.code_blocks.size).to eq(1)
      block = parser.code_blocks.first
      expect(block[:language]).to be_nil
      expect(block[:malformed]).to be false
    end

    it "captures the full info string" do
      text = "```ruby linenos\ncode\n```"
      parser = described_class.new(text)

      block = parser.code_blocks.first
      expect(block[:language]).to eq("ruby")
      expect(block[:info_string]).to eq("ruby linenos")
    end

    it "records line numbers" do
      text = "# Header\n\n```ruby\ncode\n```"
      parser = described_class.new(text)

      block = parser.code_blocks.first
      expect(block[:line_number]).to eq(3)
    end
  end

  describe "#fix" do
    it "fixes a single malformed fence" do
      text = "``` ruby\nputs 'hello'\n```"
      parser = described_class.new(text)

      result = parser.fix
      expect(result).to eq("```ruby\nputs 'hello'\n```")
    end

    it "fixes multiple malformed fences" do
      text = <<~MD
        ``` ruby
        puts 'hello'
        ```

        ``` bash
        echo world
        ```
      MD
      parser = described_class.new(text)

      result = parser.fix
      expect(result).to include("```ruby\n")
      expect(result).to include("```bash\n")
      expect(result).not_to include("``` ruby")
      expect(result).not_to include("``` bash")
    end

    it "preserves properly formatted fences" do
      text = "```ruby\nputs 'hello'\n```"
      parser = described_class.new(text)

      result = parser.fix
      expect(result).to eq(text)
    end

    it "preserves content around code blocks" do
      text = <<~MD
        # Header

        Some intro text.

        ``` ruby
        puts 'hello'
        ```

        More text after.
      MD
      parser = described_class.new(text)

      result = parser.fix
      expect(result).to include("# Header")
      expect(result).to include("Some intro text.")
      expect(result).to include("```ruby\n")
      expect(result).to include("More text after.")
    end

    it "fixes tilde fences" do
      text = "~~~ bash\necho test\n~~~"
      parser = described_class.new(text)

      result = parser.fix
      expect(result).to eq("~~~bash\necho test\n~~~")
    end

    it "handles mixed fence types" do
      text = <<~MD
        ``` ruby
        code1
        ```

        ~~~bash
        code2
        ~~~

        ~~~ python
        code3
        ~~~
      MD
      parser = described_class.new(text)

      result = parser.fix
      expect(result).to include("```ruby\n")
      expect(result).to include("~~~bash\n")
      expect(result).to include("~~~python\n")
    end

    it "returns original content when no malformed fences" do
      text = "```ruby\ncode\n```"
      parser = described_class.new(text)

      expect(parser.fix).to eq(text)
    end
  end

  describe "#malformed_count" do
    it "returns correct count" do
      text = <<~MD
        ```ruby
        good
        ```

        ``` bash
        bad
        ```

        ``` python
        also bad
        ```
      MD
      parser = described_class.new(text)

      expect(parser.malformed_count).to eq(2)
    end

    it "returns 0 for no malformed fences" do
      text = "```ruby\ncode\n```"
      parser = described_class.new(text)

      expect(parser.malformed_count).to eq(0)
    end
  end

  describe "#count" do
    it "returns total code block count" do
      text = <<~MD
        ```ruby
        code1
        ```

        ```bash
        code2
        ```

        ```
        code3
        ```
      MD
      parser = described_class.new(text)

      expect(parser.count).to eq(3)
    end
  end

  describe "real-world bug scenario" do
    let(:malformed_readme) do
      <<~MD
        # My Gem

        ## Installation

        ``` console
        gem install my-gem
        ```

        ## Usage

        ``` ruby
        require 'my-gem'
        MyGem.do_something
        ```

        ## Contributing

        ``` bash
        bundle install
        rake test
        ```
      MD
    end

    it "detects as malformed" do
      parser = described_class.new(malformed_readme)
      expect(parser.malformed?).to be true
    end

    it "counts all malformed blocks" do
      parser = described_class.new(malformed_readme)
      expect(parser.malformed_count).to eq(3)
    end

    it "fixes all malformed blocks" do
      parser = described_class.new(malformed_readme)
      result = parser.fix

      expect(result).to include("```console\n")
      expect(result).to include("```ruby\n")
      expect(result).to include("```bash\n")
      expect(result).not_to include("``` console")
      expect(result).not_to include("``` ruby")
      expect(result).not_to include("``` bash")
    end

    it "preserves document structure" do
      parser = described_class.new(malformed_readme)
      result = parser.fix

      expect(result).to include("# My Gem")
      expect(result).to include("## Installation")
      expect(result).to include("gem install my-gem")
      expect(result).to include("## Usage")
      expect(result).to include("require 'my-gem'")
    end
  end

  describe "edge cases" do
    it "handles four-backtick fences" do
      text = "```` ruby\ncode\n````"
      parser = described_class.new(text)

      expect(parser.malformed?).to be true
      expect(parser.fix).to eq("````ruby\ncode\n````")
    end

    it "handles info string with attributes" do
      text = "``` ruby linenos title=\"Example\"\ncode\n```"
      parser = described_class.new(text)

      result = parser.fix
      expect(result).to start_with("```ruby linenos title=\"Example\"\n")
    end

    it "handles empty code block" do
      text = "```ruby\n```"
      parser = described_class.new(text)

      expect(parser.code_blocks.size).to eq(1)
      expect(parser.malformed?).to be false
    end

    it "handles closing fence on same indentation check" do
      # This tests that we only detect opening fences, not closing ones
      text = "```ruby\ncode with ``` inside\n```"
      parser = described_class.new(text)

      # Should detect only 1 opening fence (closing fence is not counted)
      # The middle line with ``` is content, not at line start
      expect(parser.code_blocks.size).to eq(1)
    end

    it "does not treat inline code as fence" do
      text = "Use `code` inline and ``` for blocks"
      parser = described_class.new(text)

      # The ``` at end of line is not at start of line
      expect(parser.code_blocks).to be_empty
    end

    it "handles Windows line endings" do
      text = "``` ruby\r\ncode\r\n```"
      parser = described_class.new(text)

      expect(parser.malformed?).to be true
    end
  end
end
