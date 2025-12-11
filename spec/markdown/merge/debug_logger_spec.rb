# frozen_string_literal: true

RSpec.describe Markdown::Merge::DebugLogger do
  describe ".enabled?" do
    context "when MARKDOWN_MERGE_DEBUG is set" do
      around do |example|
        original = ENV.fetch("MARKDOWN_MERGE_DEBUG", nil)
        ENV["MARKDOWN_MERGE_DEBUG"] = "1"
        example.run
        ENV["MARKDOWN_MERGE_DEBUG"] = original
      end

      it "returns true" do
        expect(described_class.enabled?).to be true
      end
    end

    context "when MARKDOWN_MERGE_DEBUG is not set" do
      around do |example|
        original = ENV.fetch("MARKDOWN_MERGE_DEBUG", nil)
        ENV.delete("MARKDOWN_MERGE_DEBUG")
        example.run
        ENV["MARKDOWN_MERGE_DEBUG"] = original if original
      end

      it "returns false" do
        expect(described_class.enabled?).to be false
      end
    end
  end

  describe ".debug" do
    context "when disabled" do
      around do |example|
        original = ENV.fetch("MARKDOWN_MERGE_DEBUG", nil)
        ENV.delete("MARKDOWN_MERGE_DEBUG")
        example.run
        ENV["MARKDOWN_MERGE_DEBUG"] = original if original
      end

      it "does not output anything" do
        expect { described_class.debug("test message") }.not_to output.to_stderr
      end
    end

    context "when enabled" do
      around do |example|
        original = ENV.fetch("MARKDOWN_MERGE_DEBUG", nil)
        ENV["MARKDOWN_MERGE_DEBUG"] = "1"
        example.run
        ENV["MARKDOWN_MERGE_DEBUG"] = original
      end

      it "outputs message to stderr" do
        expect { described_class.debug("test message") }.to output(/test message/).to_stderr
      end

      it "includes prefix in output" do
        expect { described_class.debug("test") }.to output(/\[markdown-merge\]/).to_stderr
      end

      it "includes context if provided" do
        expect { described_class.debug("test", {key: "value"}) }.to output(/key.*value/).to_stderr
      end
    end
  end

  describe ".time" do
    it "returns block result" do
      result = described_class.time("operation") { 42 }
      expect(result).to eq(42)
    end

    it "yields to block" do
      yielded = false
      described_class.time("operation") { yielded = true }
      expect(yielded).to be true
    end

    context "when enabled" do
      around do |example|
        original = ENV.fetch("MARKDOWN_MERGE_DEBUG", nil)
        ENV["MARKDOWN_MERGE_DEBUG"] = "1"
        example.run
        ENV["MARKDOWN_MERGE_DEBUG"] = original
      end

      it "outputs timing information" do
        expect { described_class.time("test_op") { sleep(0.001) } }.to output(/test_op/).to_stderr
      end
    end
  end

  describe "module configuration" do
    it "has env_var_name set" do
      expect(described_class.env_var_name).to eq("MARKDOWN_MERGE_DEBUG")
    end

    it "has log_prefix set" do
      expect(described_class.log_prefix).to eq("[markdown-merge]")
    end
  end
end
