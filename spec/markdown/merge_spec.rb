# frozen_string_literal: true

RSpec.describe Markdown::Merge do
  it "has a version number" do
    expect(Markdown::Merge::VERSION).not_to be_nil
  end

  describe "Error" do
    it "inherits from Ast::Merge::Error" do
      expect(described_class::Error.ancestors).to include(Ast::Merge::Error)
    end

    it "can be raised" do
      expect { raise described_class::Error, "test" }.to raise_error(described_class::Error, "test")
    end

    it "is a StandardError" do
      expect(described_class::Error.ancestors).to include(StandardError)
    end
  end

  describe "ParseError" do
    it "inherits from Ast::Merge::ParseError" do
      expect(described_class::ParseError.ancestors).to include(Ast::Merge::ParseError)
    end

    it "can be raised with errors array" do
      errors = [StandardError.new("parse error")]
      error = described_class::ParseError.new(errors: errors)
      expect(error.errors).to eq(errors)
    end

    it "builds message from class name" do
      errors = [StandardError.new("test")]
      error = described_class::ParseError.new(errors: errors)
      expect(error.message).to include("markdown")
      expect(error.message).to include("merge")
      expect(error.message).to include("parseerror")
    end
  end

  describe "TemplateParseError" do
    it "inherits from ParseError" do
      expect(described_class::TemplateParseError.superclass).to eq(described_class::ParseError)
    end

    it "can be raised" do
      expect { raise described_class::TemplateParseError }.to raise_error(described_class::TemplateParseError)
    end
  end

  describe "DestinationParseError" do
    it "inherits from ParseError" do
      expect(described_class::DestinationParseError.superclass).to eq(described_class::ParseError)
    end

    it "can be raised" do
      expect { raise described_class::DestinationParseError }.to raise_error(described_class::DestinationParseError)
    end
  end

  describe "autoloaded classes" do
    it "autoloads DebugLogger" do
      expect(described_class::DebugLogger).to be_a(Module)
    end

    it "autoloads FreezeNode" do
      expect(described_class::FreezeNode).to be_a(Class)
    end

    it "autoloads FileAnalysisBase" do
      expect(described_class::FileAnalysisBase).to be_a(Class)
    end

    it "autoloads FileAligner" do
      expect(described_class::FileAligner).to be_a(Class)
    end

    it "autoloads ConflictResolver" do
      expect(described_class::ConflictResolver).to be_a(Class)
    end

    it "autoloads MergeResult" do
      expect(described_class::MergeResult).to be_a(Class)
    end

    it "autoloads TableMatchAlgorithm" do
      expect(described_class::TableMatchAlgorithm).to be_a(Class)
    end

    it "autoloads TableMatchRefiner" do
      expect(described_class::TableMatchRefiner).to be_a(Class)
    end

    it "autoloads CodeBlockMerger" do
      expect(described_class::CodeBlockMerger).to be_a(Class)
    end

    it "autoloads SmartMergerBase" do
      expect(described_class::SmartMergerBase).to be_a(Class)
    end

    # Concrete implementations (tree_haver-based)
    it "autoloads NodeTypeNormalizer" do
      expect(described_class::NodeTypeNormalizer).to be_a(Module)
    end

    it "autoloads FileAnalysis" do
      expect(described_class::FileAnalysis).to be_a(Class)
    end

    it "autoloads SmartMerger" do
      expect(described_class::SmartMerger).to be_a(Class)
    end
  end
end
