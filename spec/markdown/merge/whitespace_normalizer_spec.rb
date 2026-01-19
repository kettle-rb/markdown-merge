# frozen_string_literal: true

RSpec.describe Markdown::Merge::WhitespaceNormalizer do
  describe ".normalize" do
    it "collapses triple newlines to double" do
      content = "Hello\n\n\nWorld"
      result = described_class.normalize(content)

      expect(result).to eq("Hello\n\nWorld")
    end

    it "collapses quadruple newlines to double" do
      content = "Hello\n\n\n\nWorld"
      result = described_class.normalize(content)

      expect(result).to eq("Hello\n\nWorld")
    end

    it "collapses many newlines to double" do
      content = "Hello\n\n\n\n\n\n\n\nWorld"
      result = described_class.normalize(content)

      expect(result).to eq("Hello\n\nWorld")
    end

    it "preserves single blank lines" do
      content = "Hello\n\nWorld"
      result = described_class.normalize(content)

      expect(result).to eq("Hello\n\nWorld")
    end

    it "preserves content with no blank lines" do
      content = "Hello\nWorld"
      result = described_class.normalize(content)

      expect(result).to eq("Hello\nWorld")
    end

    it "handles multiple occurrences" do
      content = "A\n\n\nB\n\n\n\nC\n\n\n\n\nD"
      result = described_class.normalize(content)

      expect(result).to eq("A\n\nB\n\nC\n\nD")
    end
  end

  describe "instance usage" do
    let(:content) { "Line 1\n\n\n\nLine 2\n\n\nLine 3" }
    let(:normalizer) { described_class.new(content) }

    describe "#normalize" do
      it "returns normalized content" do
        expect(normalizer.normalize).to eq("Line 1\n\nLine 2\n\nLine 3")
      end
    end

    describe "#problems" do
      before { normalizer.normalize }

      it "tracks whitespace issues" do
        expect(normalizer.problems.count).to eq(2)
      end

      it "records problem details" do
        problems = normalizer.problems.all
        expect(problems.first).to include(
          category: :excessive_whitespace,
          severity: :warning,
        )
      end

      it "records line numbers" do
        problems = normalizer.problems.all
        lines = problems.map { |p| p[:line] }
        # Line numbers are where the excessive newlines start
        # "Line 1\n\n\n\nLine 2\n\n\nLine 3"
        #         ^ line 1 (after Line 1)    ^ line 5 (after Line 2)
        expect(lines).to contain_exactly(1, 5)
      end

      it "records newline counts" do
        problems = normalizer.problems.all
        counts = problems.map { |p| p[:newline_count] }
        expect(counts).to contain_exactly(4, 3)
      end
    end

    describe "#changed?" do
      it "returns true when normalization occurred" do
        normalizer.normalize
        expect(normalizer).to be_changed
      end

      it "returns false when no normalization needed" do
        clean_normalizer = described_class.new("Hello\n\nWorld")
        clean_normalizer.normalize
        expect(clean_normalizer).not_to be_changed
      end
    end

    describe "#normalization_count" do
      it "returns number of normalizations" do
        normalizer.normalize
        expect(normalizer.normalization_count).to eq(2)
      end
    end
  end

  describe "mode validation" do
    it "accepts :basic mode" do
      normalizer = described_class.new("content", mode: :basic)
      expect(normalizer.mode).to eq(:basic)
    end

    it "accepts :link_refs mode" do
      normalizer = described_class.new("content", mode: :link_refs)
      expect(normalizer.mode).to eq(:link_refs)
    end

    it "accepts :strict mode" do
      normalizer = described_class.new("content", mode: :strict)
      expect(normalizer.mode).to eq(:strict)
    end

    it "converts true to :basic mode" do
      normalizer = described_class.new("content", mode: true)
      expect(normalizer.mode).to eq(:basic)
    end

    it "converts false to :basic mode" do
      normalizer = described_class.new("content", mode: false)
      expect(normalizer.mode).to eq(:basic)
    end

    it "raises ArgumentError for unknown symbol mode" do
      expect {
        described_class.new("content", mode: :unknown)
      }.to raise_error(ArgumentError, /Unknown mode.*unknown/)
    end

    it "raises ArgumentError for non-symbol, non-boolean mode" do
      expect {
        described_class.new("content", mode: "basic")
      }.to raise_error(ArgumentError, /Mode must be a Symbol or Boolean/)
    end
  end

  describe "link_refs mode" do
    let(:content_with_blank_between_refs) do
      "[link1]: https://example.com/1\n\n[link2]: https://example.com/2\n\n[link3]: https://example.com/3"
    end

    it "removes blank lines between consecutive link reference definitions" do
      normalizer = described_class.new(content_with_blank_between_refs, mode: :link_refs)
      result = normalizer.normalize

      expect(result).to eq("[link1]: https://example.com/1\n[link2]: https://example.com/2\n[link3]: https://example.com/3")
    end

    it "tracks link_ref_spacing problems" do
      normalizer = described_class.new(content_with_blank_between_refs, mode: :link_refs)
      normalizer.normalize

      problems = normalizer.problems.by_category(:link_ref_spacing)
      expect(problems.length).to eq(2)
    end

    it "records blank lines removed count in problem" do
      normalizer = described_class.new(content_with_blank_between_refs, mode: :link_refs)
      normalizer.normalize

      problem = normalizer.problems.by_category(:link_ref_spacing).first
      expect(problem.details[:blank_lines_removed]).to eq(1)
    end

    it "preserves blank lines when not between link refs" do
      content = "[link1]: https://example.com\n\nSome paragraph\n\n[link2]: https://example.com"
      normalizer = described_class.new(content, mode: :link_refs)
      result = normalizer.normalize

      expect(result).to include("\n\nSome paragraph\n\n")
    end

    it "handles multiple blank lines between link refs" do
      content = "[link1]: https://example.com/1\n\n\n[link2]: https://example.com/2"
      normalizer = described_class.new(content, mode: :link_refs)
      result = normalizer.normalize

      expect(result).to eq("[link1]: https://example.com/1\n[link2]: https://example.com/2")
    end

    it "handles 3+ blank lines between link refs" do
      content = "[link1]: https://example.com/1\n\n\n\n\n[link2]: https://example.com/2"
      normalizer = described_class.new(content, mode: :link_refs)
      result = normalizer.normalize

      # Excessive blanks are first collapsed to 2, then removed between link refs
      expect(result).to eq("[link1]: https://example.com/1\n[link2]: https://example.com/2")
    end

    it "handles exactly 2 blank lines between link refs" do
      # Two blank lines = 3 newlines between content
      content = "[link1]: https://example.com/1\n\n\n[link2]: https://example.com/2"
      normalizer = described_class.new(content, mode: :link_refs)
      result = normalizer.normalize

      expect(result).to eq("[link1]: https://example.com/1\n[link2]: https://example.com/2")
    end

    it "tracks multiple blank lines removed correctly" do
      # 4 blank lines = 5 newlines
      content = "[link1]: https://example.com/1\n\n\n\n\n[link2]: https://example.com/2"
      normalizer = described_class.new(content, mode: :link_refs)
      normalizer.normalize

      # The excessive whitespace is collapsed first (5 newlines -> 2)
      # Then the remaining blank line between link refs is removed
      problems = normalizer.problems.all
      expect(problems).not_to be_empty
    end

    it "handles link refs at end of document" do
      content = "# Title\n\n[link1]: https://example.com/1\n\n[link2]: https://example.com/2"
      normalizer = described_class.new(content, mode: :link_refs)
      result = normalizer.normalize

      expect(result).to include("[link1]: https://example.com/1\n[link2]: https://example.com/2")
    end

    it "handles non-link-ref content between link refs" do
      content = "[link1]: https://example.com/1\n\nNot a link ref\n\n[link2]: https://example.com/2"
      normalizer = described_class.new(content, mode: :link_refs)
      result = normalizer.normalize

      # Should preserve the blank lines because there's non-link-ref content
      expect(result).to include("\n\nNot a link ref\n\n")
    end
  end

  describe "strict mode" do
    it "collapses excessive blank lines" do
      normalizer = described_class.new("Hello\n\n\n\nWorld", mode: :strict)
      result = normalizer.normalize

      expect(result).to eq("Hello\n\nWorld")
    end

    it "also removes blank lines between link refs" do
      content = "[link1]: https://example.com/1\n\n[link2]: https://example.com/2"
      normalizer = described_class.new(content, mode: :strict)
      result = normalizer.normalize

      expect(result).to eq("[link1]: https://example.com/1\n[link2]: https://example.com/2")
    end
  end
end
