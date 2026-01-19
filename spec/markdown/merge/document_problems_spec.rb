# frozen_string_literal: true

RSpec.describe Markdown::Merge::DocumentProblems do
  subject(:problems) { described_class.new }

  describe "#add" do
    it "adds a problem with default severity" do
      problems.add(:duplicate_link_definition, label: "example", url: "https://example.com")

      expect(problems.count).to eq(1)
      expect(problems.all.first).to include(
        category: :duplicate_link_definition,
        severity: :warning,
        label: "example",
        url: "https://example.com",
      )
    end

    it "adds a problem with custom severity" do
      problems.add(:excessive_whitespace, severity: :info, line: 42)

      expect(problems.all.first[:severity]).to eq(:info)
    end

    it "raises on invalid category" do
      expect { problems.add(:invalid_category) }.to raise_error(ArgumentError, /Invalid category/)
    end

    it "raises on invalid severity" do
      expect { problems.add(:excessive_whitespace, severity: :critical) }.to raise_error(ArgumentError, /Invalid severity/)
    end
  end

  describe "#by_category" do
    before do
      problems.add(:duplicate_link_definition, label: "a")
      problems.add(:excessive_whitespace, line: 1)
      problems.add(:duplicate_link_definition, label: "b")
    end

    it "filters by category" do
      result = problems.by_category(:duplicate_link_definition)

      expect(result.size).to eq(2)
      expect(result.map { |p| p.details[:label] }).to contain_exactly("a", "b")
    end
  end

  describe "#by_severity" do
    before do
      problems.add(:duplicate_link_definition, severity: :warning)
      problems.add(:link_has_title, severity: :info)
      problems.add(:excessive_whitespace, severity: :warning)
    end

    it "filters by severity" do
      expect(problems.by_severity(:warning).size).to eq(2)
      expect(problems.by_severity(:info).size).to eq(1)
    end
  end

  describe "#warnings, #errors, #infos" do
    before do
      problems.add(:duplicate_link_definition, severity: :warning)
      problems.add(:link_has_title, severity: :info)
      problems.add(:excessive_whitespace, severity: :error)
    end

    it "returns warnings" do
      expect(problems.warnings.size).to eq(1)
      expect(problems.warnings.first.category).to eq(:duplicate_link_definition)
    end

    it "returns errors" do
      expect(problems.errors.size).to eq(1)
      expect(problems.errors.first.category).to eq(:excessive_whitespace)
    end

    it "returns infos" do
      expect(problems.infos.size).to eq(1)
      expect(problems.infos.first.category).to eq(:link_has_title)
    end
  end

  describe "#empty?" do
    it "returns true when no problems" do
      expect(problems).to be_empty
    end

    it "returns false when problems exist" do
      problems.add(:excessive_whitespace, line: 1)
      expect(problems).not_to be_empty
    end
  end

  describe "#count" do
    before do
      problems.add(:duplicate_link_definition, severity: :warning)
      problems.add(:link_has_title, severity: :info)
      problems.add(:duplicate_link_definition, severity: :warning)
    end

    it "returns total count with no filters" do
      expect(problems.count).to eq(3)
    end

    it "returns count filtered by category" do
      expect(problems.count(category: :duplicate_link_definition)).to eq(2)
    end

    it "returns count filtered by severity" do
      expect(problems.count(severity: :info)).to eq(1)
    end

    it "returns count with both filters" do
      expect(problems.count(category: :duplicate_link_definition, severity: :warning)).to eq(2)
    end
  end

  describe "#merge!" do
    let(:other) { described_class.new }

    before do
      problems.add(:duplicate_link_definition, label: "a")
      other.add(:excessive_whitespace, line: 1)
      other.add(:link_has_title, text: "click")
    end

    it "merges problems from another instance" do
      problems.merge!(other)

      expect(problems.count).to eq(3)
    end

    it "returns self for chaining" do
      expect(problems.merge!(other)).to eq(problems)
    end
  end

  describe "#clear" do
    before do
      problems.add(:duplicate_link_definition, label: "a")
      problems.add(:excessive_whitespace, line: 1)
    end

    it "removes all problems" do
      problems.clear
      expect(problems).to be_empty
    end
  end

  describe "#summary_by_category" do
    before do
      problems.add(:duplicate_link_definition, label: "a")
      problems.add(:duplicate_link_definition, label: "b")
      problems.add(:excessive_whitespace, line: 1)
    end

    it "returns counts by category" do
      expect(problems.summary_by_category).to eq({
        duplicate_link_definition: 2,
        excessive_whitespace: 1,
      })
    end
  end

  describe "#summary_by_severity" do
    before do
      problems.add(:duplicate_link_definition, severity: :warning)
      problems.add(:link_has_title, severity: :info)
      problems.add(:excessive_whitespace, severity: :warning)
    end

    it "returns counts by severity" do
      expect(problems.summary_by_severity).to eq({
        warning: 2,
        info: 1,
      })
    end
  end

  describe "Problem struct" do
    let(:problem) { problems.add(:duplicate_link_definition, severity: :warning, label: "test") }

    it "has helper methods for severity" do
      expect(problem).to be_warning
      expect(problem).not_to be_error
      expect(problem).not_to be_info
    end

    it "converts to hash" do
      expect(problem.to_h).to eq({
        category: :duplicate_link_definition,
        severity: :warning,
        label: "test",
      })
    end
  end
end
