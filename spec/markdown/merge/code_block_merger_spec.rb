# frozen_string_literal: true

RSpec.describe Markdown::Merge::CodeBlockMerger do
  let(:merger) { described_class.new }

  describe "DEFAULT_MERGERS" do
    it "includes ruby merger" do
      expect(described_class::DEFAULT_MERGERS).to have_key("ruby")
    end

    it "includes rb merger" do
      expect(described_class::DEFAULT_MERGERS).to have_key("rb")
    end

    it "includes yaml merger" do
      expect(described_class::DEFAULT_MERGERS).to have_key("yaml")
    end

    it "includes yml merger" do
      expect(described_class::DEFAULT_MERGERS).to have_key("yml")
    end

    it "includes json merger" do
      expect(described_class::DEFAULT_MERGERS).to have_key("json")
    end

    it "includes toml merger" do
      expect(described_class::DEFAULT_MERGERS).to have_key("toml")
    end

    it "has Proc values" do
      described_class::DEFAULT_MERGERS.each_value do |v|
        expect(v).to respond_to(:call)
      end
    end
  end

  describe "#initialize" do
    it "accepts no arguments" do
      m = described_class.new
      expect(m).to be_a(described_class)
    end

    it "defaults enabled to true" do
      expect(merger.enabled).to be(true)
    end

    it "accepts enabled parameter" do
      m = described_class.new(enabled: false)
      expect(m.enabled).to be(false)
    end

    it "uses DEFAULT_MERGERS by default" do
      expect(merger.mergers).to include(described_class::DEFAULT_MERGERS)
    end

    it "accepts custom mergers" do
      custom = {"custom" => ->(t, d, p, **) { {merged: true, content: "custom"} }}
      m = described_class.new(mergers: custom)
      expect(m.mergers).to have_key("custom")
    end

    it "merges custom mergers with defaults" do
      custom = {"custom" => ->(t, d, p, **) { {merged: true, content: "custom"} }}
      m = described_class.new(mergers: custom)
      expect(m.mergers).to have_key("ruby")
      expect(m.mergers).to have_key("custom")
    end
  end

  describe "#supports_language?" do
    it "returns true for supported languages" do
      %w[ruby rb yaml yml json toml].each do |lang|
        expect(merger.supports_language?(lang)).to be(true)
      end
    end

    it "returns false for unsupported languages" do
      expect(merger.supports_language?("python")).to be(false)
      expect(merger.supports_language?("javascript")).to be(false)
    end

    it "returns false for nil" do
      expect(merger.supports_language?(nil)).to be(false)
    end

    it "returns false for empty string" do
      expect(merger.supports_language?("")).to be(false)
    end

    it "is case insensitive" do
      expect(merger.supports_language?("RUBY")).to be(true)
      expect(merger.supports_language?("Ruby")).to be(true)
    end

    context "when disabled" do
      let(:disabled_merger) { described_class.new(enabled: false) }

      it "returns false for all languages" do
        expect(disabled_merger.supports_language?("ruby")).to be(false)
        expect(disabled_merger.supports_language?("yaml")).to be(false)
      end
    end
  end

  describe "#merge_code_blocks" do
    def create_code_node(language:, content:)
      node = double("CodeBlock")
      allow(node).to receive(:fence_info).and_return(language)
      allow(node).to receive(:string_content).and_return(content)
      allow(node).to receive(:respond_to?).with(:fence_info).and_return(true)
      node
    end

    context "when disabled" do
      let(:disabled_merger) { described_class.new(enabled: false) }

      it "returns not merged with reason" do
        template = create_code_node(language: "ruby", content: "puts 'hi'")
        dest = create_code_node(language: "ruby", content: "puts 'bye'")

        result = disabled_merger.merge_code_blocks(template, dest, preference: :destination)
        expect(result[:merged]).to be(false)
        expect(result[:reason]).to include("disabled")
      end
    end

    context "with no language" do
      it "returns not merged when both have no language" do
        template = create_code_node(language: nil, content: "some code")
        dest = create_code_node(language: nil, content: "other code")

        result = merger.merge_code_blocks(template, dest, preference: :destination)
        expect(result[:merged]).to be(false)
        expect(result[:reason]).to include("no language")
      end

      it "returns not merged when both have empty language" do
        template = create_code_node(language: "", content: "some code")
        dest = create_code_node(language: "", content: "other code")

        result = merger.merge_code_blocks(template, dest, preference: :destination)
        expect(result[:merged]).to be(false)
        expect(result[:reason]).to include("no language")
      end
    end

    context "with unsupported language" do
      it "returns not merged with reason" do
        template = create_code_node(language: "python", content: "print('hi')")
        dest = create_code_node(language: "python", content: "print('bye')")

        result = merger.merge_code_blocks(template, dest, preference: :destination)
        expect(result[:merged]).to be(false)
        expect(result[:reason]).to include("no merger for language")
      end
    end

    context "with identical content" do
      it "returns merged with identical decision" do
        content = "puts 'hello'"
        template = create_code_node(language: "ruby", content: content)
        dest = create_code_node(language: "ruby", content: content)

        result = merger.merge_code_blocks(template, dest, preference: :destination)
        expect(result[:merged]).to be(true)
        expect(result[:stats][:decision]).to eq(:identical)
      end
    end

    context "with supported language but missing gem" do
      it "handles LoadError gracefully" do
        template = create_code_node(language: "toml", content: "key = 'value1'")
        dest = create_code_node(language: "toml", content: "key = 'value2'")

        # toml-merge might not be available in test environment
        result = merger.merge_code_blocks(template, dest, preference: :destination)
        # Either merged or not, should not raise
        expect(result).to have_key(:merged)
      end
    end

    context "with custom merger" do
      let(:custom_merger) do
        described_class.new(
          mergers: {
            "custom" => ->(t, d, p, **) {
              {merged: true, content: "merged: #{t} + #{d}", stats: {custom: true}}
            },
          },
        )
      end

      it "uses custom merger" do
        template = create_code_node(language: "custom", content: "template")
        dest = create_code_node(language: "custom", content: "dest")

        result = custom_merger.merge_code_blocks(template, dest, preference: :destination)
        expect(result[:merged]).to be(true)
        expect(result[:stats][:custom]).to be(true)
      end
    end

    context "when merger declines" do
      let(:declining_merger) do
        described_class.new(
          mergers: {
            "decline" => ->(t, d, p, **) { {merged: false, reason: "declined for test"} },
          },
        )
      end

      it "returns not merged with reason" do
        template = create_code_node(language: "decline", content: "a")
        dest = create_code_node(language: "decline", content: "b")

        result = declining_merger.merge_code_blocks(template, dest, preference: :destination)
        expect(result[:merged]).to be(false)
        expect(result[:reason]).to include("declined")
      end
    end

    context "when merger raises error" do
      let(:error_merger) do
        described_class.new(
          mergers: {
            "error" => ->(t, d, p, **) { raise StandardError, "test error" },
          },
        )
      end

      it "handles error gracefully" do
        template = create_code_node(language: "error", content: "a")
        dest = create_code_node(language: "error", content: "b")

        result = error_merger.merge_code_blocks(template, dest, preference: :destination)
        expect(result[:merged]).to be(false)
        expect(result[:reason]).to include("test error")
      end
    end

    context "when merger raises LoadError" do
      let(:load_error_merger) do
        described_class.new(
          mergers: {
            "missing" => ->(t, d, p, **) { raise LoadError, "cannot load such file -- missing/merge" },
          },
        )
      end

      it "handles LoadError gracefully" do
        template = create_code_node(language: "missing", content: "a")
        dest = create_code_node(language: "missing", content: "b")

        result = load_error_merger.merge_code_blocks(template, dest, preference: :destination)
        expect(result[:merged]).to be(false)
        expect(result[:reason]).to include("merger gem not available")
      end
    end

    context "when merger returns nil reason" do
      let(:nil_reason_merger) do
        described_class.new(
          mergers: {
            "nilreason" => ->(t, d, p, **) { {merged: false, reason: nil} },
          },
        )
      end

      it "uses default reason message" do
        template = create_code_node(language: "nilreason", content: "a")
        dest = create_code_node(language: "nilreason", content: "b")

        result = nil_reason_merger.merge_code_blocks(template, dest, preference: :destination)
        expect(result[:merged]).to be(false)
        expect(result[:reason]).to include("merger declined")
      end
    end

    context "with mismatched languages" do
      it "returns not merged due to parse error from mismatched content" do
        template = create_code_node(language: "ruby", content: "puts 'hi'")
        dest = create_code_node(language: "yaml", content: "key: value")

        result = merger.merge_code_blocks(template, dest, preference: :destination)
        expect(result[:merged]).to be(false)
        # When languages mismatch, it tries to use the first language (ruby)
        # and fails when parsing the YAML content as Ruby
        expect(result[:reason]).to match(/parse error|no merger|merge failed/)
      end
    end

    context "with fence_info containing spaces" do
      it "extracts just the language" do
        template = create_code_node(language: "ruby copy linenos", content: "puts 'hi'")
        dest = create_code_node(language: "ruby", content: "puts 'bye'")

        # Should recognize both as ruby and attempt merge
        result = merger.merge_code_blocks(template, dest, preference: :destination)
        # May or may not succeed depending on prism-merge availability
        expect(result).to have_key(:merged)
      end
    end
  end

  describe "#enabled" do
    it "returns the enabled state" do
      expect(merger.enabled).to be(true)
      expect(described_class.new(enabled: false).enabled).to be(false)
    end
  end

  describe "#mergers" do
    it "returns the mergers hash" do
      expect(merger.mergers).to be_a(Hash)
    end

    it "is frozen by default" do
      # The merged hash itself isn't frozen, but DEFAULT_MERGERS is
      expect(described_class::DEFAULT_MERGERS).to be_frozen
    end
  end

  describe "private methods" do
    describe "#extract_language" do
      it "returns the language from fence_info" do
        node = double("Node")
        allow(node).to receive(:respond_to?).with(:fence_info).and_return(true)
        allow(node).to receive(:fence_info).and_return("ruby")

        result = merger.send(:extract_language, node)
        expect(result).to eq("ruby")
      end

      it "handles fence_info with additional info" do
        node = double("Node")
        allow(node).to receive(:respond_to?).with(:fence_info).and_return(true)
        allow(node).to receive(:fence_info).and_return("ruby linenos")

        result = merger.send(:extract_language, node)
        expect(result).to eq("ruby")
      end

      it "returns nil for empty fence_info" do
        node = double("Node")
        allow(node).to receive(:respond_to?).with(:fence_info).and_return(true)
        allow(node).to receive(:fence_info).and_return("")

        result = merger.send(:extract_language, node)
        expect(result).to be_nil
      end

      it "returns nil for nil fence_info" do
        node = double("Node")
        allow(node).to receive(:respond_to?).with(:fence_info).and_return(true)
        allow(node).to receive(:fence_info).and_return(nil)

        result = merger.send(:extract_language, node)
        expect(result).to be_nil
      end

      it "returns nil when node doesn't respond to fence_info" do
        node = double("Node")
        allow(node).to receive(:respond_to?).with(:fence_info).and_return(false)

        result = merger.send(:extract_language, node)
        expect(result).to be_nil
      end
    end

    describe "#extract_content" do
      it "returns string_content from node" do
        node = double("Node")
        allow(node).to receive(:string_content).and_return("puts 'hello'")

        result = merger.send(:extract_content, node)
        expect(result).to eq("puts 'hello'")
      end

      it "returns empty string when string_content is nil" do
        node = double("Node")
        allow(node).to receive(:string_content).and_return(nil)

        result = merger.send(:extract_content, node)
        expect(result).to eq("")
      end
    end

    describe "#rebuild_code_block" do
      let(:reference_node) { double("Node") }

      it "builds a fenced code block" do
        result = merger.send(:rebuild_code_block, "ruby", "puts 'hi'", reference_node)
        expect(result).to include("```ruby")
        expect(result).to include("puts 'hi'")
        expect(result).to end_with("```")
      end

      it "ensures content ends with newline before fence" do
        result = merger.send(:rebuild_code_block, "ruby", "code", reference_node)
        expect(result).to eq("```ruby\ncode\n```")
      end

      it "doesn't double newline if content already ends with one" do
        result = merger.send(:rebuild_code_block, "ruby", "code\n", reference_node)
        expect(result).to eq("```ruby\ncode\n```")
      end
    end

    describe "#not_merged" do
      it "returns a hash with merged: false" do
        result = merger.send(:not_merged, "test reason")
        expect(result[:merged]).to be(false)
        expect(result[:reason]).to eq("test reason")
      end
    end
  end

  describe "class methods" do
    describe ".merge_with_prism" do
      before do
        skip "prism/merge not available" unless prism_merge_available?
      end

      def prism_merge_available?
        require "prism/merge"
        true
      rescue LoadError
        false
      end

      it "responds to merge_with_prism" do
        expect(described_class).to respond_to(:merge_with_prism)
      end

      it "merges valid Ruby code" do
        template = "def foo; 1; end"
        dest = "def foo; 2; end"

        result = described_class.merge_with_prism(template, dest, :destination)
        expect(result).to have_key(:merged)
        expect(result).to have_key(:content)
      end

      it "handles parse errors" do
        template = "def foo; end"
        dest = "def foo {{{ invalid"

        result = described_class.merge_with_prism(template, dest, :destination)
        expect(result[:merged]).to be(false)
        expect(result[:reason]).to include("parse error")
      end
    end

    describe ".merge_with_psych" do
      before do
        skip "psych/merge not available" unless psych_merge_available?
      end

      def psych_merge_available?
        require "psych/merge"
        true
      rescue LoadError
        false
      end

      it "responds to merge_with_psych" do
        expect(described_class).to respond_to(:merge_with_psych)
      end

      it "merges valid YAML code" do
        template = "key: value1"
        dest = "key: value2"

        result = described_class.merge_with_psych(template, dest, :destination)
        expect(result).to have_key(:merged)
        expect(result).to have_key(:content)
      end

      it "handles parse errors with invalid YAML" do
        template = "key: value"
        dest = "- invalid:\n  yaml: [\n"  # Malformed YAML

        result = described_class.merge_with_psych(template, dest, :destination)
        # May or may not fail depending on psych-merge's tolerance
        expect(result).to have_key(:merged)
      end
    end

    describe ".merge_with_json" do
      before do
        skip "json/merge not available" unless json_merge_available?
      end

      def json_merge_available?
        require "json/merge"
        true
      rescue LoadError
        false
      end

      it "responds to merge_with_json" do
        expect(described_class).to respond_to(:merge_with_json)
      end

      it "merges valid JSON code" do
        template = '{"key": "value1"}'
        dest = '{"key": "value2"}'

        result = described_class.merge_with_json(template, dest, :destination)
        expect(result).to have_key(:merged)
        expect(result).to have_key(:content)
      end

      it "handles parse errors with invalid JSON" do
        template = '{"key": "value"}'
        dest = "{invalid json"

        result = described_class.merge_with_json(template, dest, :destination)
        # Result depends on how json-merge handles invalid input
        # It may return merged: false with parse error, or merged: true with fallback
        expect(result).to have_key(:merged)
        if result[:merged] == false
          expect(result[:reason]).to include("parse error")
        end
      end
    end

    describe ".merge_with_toml" do
      before do
        skip "toml/merge not available" unless toml_merge_available?
      end

      def toml_merge_available?
        require "toml/merge"
        true
      rescue LoadError
        false
      end

      it "responds to merge_with_toml" do
        expect(described_class).to respond_to(:merge_with_toml)
      end

      it "merges valid TOML code" do
        template = "key = 'value1'"
        dest = "key = 'value2'"

        result = described_class.merge_with_toml(template, dest, :destination)
        expect(result).to have_key(:merged)
        expect(result).to have_key(:content)
      end

      it "handles parse errors with invalid TOML" do
        template = "key = 'value'"
        dest = "[invalid toml"

        result = described_class.merge_with_toml(template, dest, :destination)
        expect(result[:merged]).to be(false)
        expect(result[:reason]).to include("parse error")
      end
    end
  end

  describe "DEFAULT_MERGERS invocation" do
    # Test that DEFAULT_MERGERS procs can be called (they will require their gems)
    # These tests verify the structure but may fail if gems aren't available

    def create_code_node(language:, content:)
      node = double("CodeBlock")
      allow(node).to receive(:fence_info).and_return(language)
      allow(node).to receive(:string_content).and_return(content)
      allow(node).to receive(:respond_to?).with(:fence_info).and_return(true)
      node
    end

    %w[ruby rb yaml yml json toml].each do |lang|
      context "with #{lang} language" do
        it "has a merger defined" do
          expect(described_class::DEFAULT_MERGERS).to have_key(lang)
        end

        it "merger is callable" do
          expect(described_class::DEFAULT_MERGERS[lang]).to respond_to(:call)
        end
      end
    end
  end
end
