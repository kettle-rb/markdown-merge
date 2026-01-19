# frozen_string_literal: true

# Diagnostic tests to verify markdown backends are available
# Uses :markdown_parsing tag - tests only run when commonmarker or markly is available
#
# These tests intentionally:
# - Use a string describe (not a class) because they test infrastructure, not a specific class
# - Use puts for diagnostic output visible in CI logs
# - Use expect([true, false]).to include() to verify boolean return without asserting which value
#
# rubocop:disable RSpec/DescribeClass -- diagnostic tests for infrastructure, not a specific class
# rubocop:disable RSpec/Output -- intentional diagnostic output for CI visibility
RSpec.describe "Backend Availability" do
  describe "Commonmarker backend" do
    it "reports availability status via BackendRegistry" do
      status = TreeHaver::BackendRegistry.available?(:commonmarker)
      puts "Commonmarker available: #{status}" # rubocop:disable RSpec/Output
      expect(status).to be(true).or be(false)
    end
  end

  describe "Markly backend" do
    it "reports availability status via BackendRegistry" do
      status = TreeHaver::BackendRegistry.available?(:markly)
      puts "Markly available: #{status}" # rubocop:disable RSpec/Output
      expect(status).to be(true).or be(false)
    end
  end

  describe "TreeHaver::RSpec::DependencyTags" do
    it "reports markdown backend availability" do
      status = TreeHaver::RSpec::DependencyTags.any_markdown_backend_available?
      puts "Any markdown backend available: #{status}" # rubocop:disable RSpec/Output
      expect(status).to be(true).or be(false)
    end
  end

  # These tests exercise the actual code with proper dependency tags
  describe Markdown::Merge::FileAnalysis, :markdown_parsing do
    let(:simple_markdown) { "# Hello\n\nWorld" }

    it "can be instantiated" do
      analysis = described_class.new(simple_markdown)
      expect(analysis).to be_a(described_class)
    end

    it "resolves a backend" do
      analysis = described_class.new(simple_markdown)
      expect(analysis.backend).to eq(:commonmarker).or eq(:markly)
    end

    it "parses statements" do
      analysis = described_class.new(simple_markdown)
      expect(analysis.statements).to be_an(Array)
      expect(analysis.statements).not_to be_empty
    end

    it "generates signatures for all node types" do
      complex_md = <<~MD
        # Heading

        Paragraph text.

        > Block quote

        - List item 1
        - List item 2

        ```ruby
        code
        ```

        ---

        <div>HTML</div>
      MD

      analysis = described_class.new(complex_md)
      analysis.statements.each do |stmt|
        sig = analysis.generate_signature(stmt)
        expect(sig).to be_an(Array), "Expected signature for #{stmt.merge_type}"
      end
    end
  end

  describe Markdown::Merge::SmartMerger, :markdown_parsing do
    let(:template) { "# Title\n\nTemplate content." }
    let(:dest) { "# Title\n\nDestination content." }

    it "can be instantiated" do
      merger = described_class.new(template, dest)
      expect(merger).to be_a(described_class)
    end

    it "can merge content" do
      merger = described_class.new(template, dest)
      result = merger.merge
      expect(result).to be_a(String)
    end

    it "returns merge_result with stats" do
      merger = described_class.new(template, dest)
      result = merger.merge_result
      expect(result).to be_a(Markdown::Merge::MergeResult)
      expect(result.stats).to be_a(Hash)
    end
  end
end
# rubocop:enable RSpec/DescribeClass, RSpec/Output
