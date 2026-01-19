# frozen_string_literal: true

# External gems
require "version_gem"
require "set"

# Shared merge infrastructure
require "ast/merge"

# tree_haver provides unified markdown parsing via multiple backends
require "tree_haver"

# This gem - only require version
require_relative "merge/version"

module Markdown
  # Smart merging for Markdown files using AST-based parsers via tree_haver.
  #
  # Markdown::Merge provides intelligent Markdown merging with support for
  # multiple parsing backends (Commonmarker, Markly) through tree_haver:
  # - Standalone SmartMerger that works with any available backend
  # - Matching structural elements (headings, paragraphs, lists, etc.) between files
  # - Preserving frozen sections marked with HTML comments
  # - Resolving conflicts based on configurable preferences
  # - Node type normalization for portable merge rules across backends
  #
  # Can be used directly or through parser-specific wrappers
  # (commonmarker-merge, markly-merge) that provide hard dependencies
  # and backend-specific defaults.
  #
  # @example Direct usage with auto backend detection
  #   require "markdown/merge"
  #   merger = Markdown::Merge::SmartMerger.new(template, destination)
  #   result = merger.merge
  #
  # @example With specific backend
  #   merger = Markdown::Merge::SmartMerger.new(
  #     template,
  #     destination,
  #     backend: :markly,
  #     flags: Markly::DEFAULT,
  #     extensions: [:table, :strikethrough]
  #   )
  #   result = merger.merge
  #
  # @example Using via commonmarker-merge
  #   require "commonmarker/merge"
  #   merger = Commonmarker::Merge::SmartMerger.new(template, destination)
  #   result = merger.merge
  #
  # @see SmartMerger Main entry point for merging
  # @see FileAnalysis For parsing and analyzing Markdown files
  # @see NodeTypeNormalizer For type normalization across backends
  module Merge
    # Base error class for Markdown::Merge
    # Inherits from Ast::Merge::Error for consistency across merge gems.
    class Error < Ast::Merge::Error; end

    # Raised when a Markdown file has parsing errors.
    # Inherits from Ast::Merge::ParseError for consistency across merge gems.
    #
    # @example Handling parse errors
    #   begin
    #     analysis = FileAnalysis.new(markdown_content)
    #   rescue ParseError => e
    #     puts "Markdown syntax error: #{e.message}"
    #     e.errors.each { |error| puts "  #{error}" }
    #   end
    class ParseError < Ast::Merge::ParseError
      # @param message [String, nil] Error message (auto-generated if nil)
      # @param content [String, nil] The Markdown source that failed to parse
      # @param errors [Array] Parse errors from Markdown
      def initialize(message = nil, content: nil, errors: [])
        super(message, errors: errors, content: content)
      end
    end

    # Raised when the template file has syntax errors.
    #
    # @example Handling template parse errors
    #   begin
    #     merger = SmartMerger.new(template, destination)
    #     result = merger.merge
    #   rescue TemplateParseError => e
    #     puts "Template syntax error: #{e.message}"
    #     e.errors.each { |error| puts "  #{error.message}" }
    #   end
    class TemplateParseError < ParseError; end

    # Raised when the destination file has syntax errors.
    #
    # @example Handling destination parse errors
    #   begin
    #     merger = SmartMerger.new(template, destination)
    #     result = merger.merge
    #   rescue DestinationParseError => e
    #     puts "Destination syntax error: #{e.message}"
    #     e.errors.each { |error| puts "  #{error.message}" }
    #   end
    class DestinationParseError < ParseError; end

    # Autoload all components - base classes
    autoload :Cleanse, "markdown/merge/cleanse"
    autoload :DebugLogger, "markdown/merge/debug_logger"
    autoload :FreezeNode, "markdown/merge/freeze_node"
    autoload :FileAnalysisBase, "markdown/merge/file_analysis_base"
    autoload :FileAligner, "markdown/merge/file_aligner"
    autoload :ConflictResolver, "markdown/merge/conflict_resolver"
    autoload :MergeResult, "markdown/merge/merge_result"
    autoload :TableMatchAlgorithm, "markdown/merge/table_match_algorithm"
    autoload :TableMatchRefiner, "markdown/merge/table_match_refiner"
    autoload :CodeBlockMerger, "markdown/merge/code_block_merger"
    autoload :SmartMergerBase, "markdown/merge/smart_merger_base"
    autoload :LinkDefinitionNode, "markdown/merge/link_definition_node"
    autoload :GapLineNode, "markdown/merge/gap_line_node"
    autoload :OutputBuilder, "markdown/merge/output_builder"
    autoload :LinkDefinitionFormatter, "markdown/merge/link_definition_formatter"
    autoload :MarkdownStructure, "markdown/merge/markdown_structure"
    autoload :DocumentProblems, "markdown/merge/document_problems"
    autoload :WhitespaceNormalizer, "markdown/merge/whitespace_normalizer"
    autoload :LinkParser, "markdown/merge/link_parser"
    autoload :LinkReferenceRehydrator, "markdown/merge/link_reference_rehydrator"

    # Autoload concrete implementations (tree_haver-based)
    autoload :NodeTypeNormalizer, "markdown/merge/node_type_normalizer"
    autoload :FileAnalysis, "markdown/merge/file_analysis"
    autoload :SmartMerger, "markdown/merge/smart_merger"
    autoload :PartialTemplateMerger, "markdown/merge/partial_template_merger"
  end
end

# Register with ast-merge's MergeGemRegistry for RSpec dependency tags
# Note: markdown-merge requires a backend (markly or commonmarker) to instantiate,
# so we use skip_instantiation: true
# Only register if MergeGemRegistry is loaded (i.e., in test environment)
if defined?(Ast::Merge::RSpec::MergeGemRegistry)
  Ast::Merge::RSpec::MergeGemRegistry.register(
    :markdown_merge,
    require_path: "markdown/merge",
    merger_class: "Markdown::Merge::SmartMerger",
    test_source: "# Test\n\nParagraph",
    category: :markdown,
    skip_instantiation: true,
  )
end

Markdown::Merge::Version.class_eval do
  extend VersionGem::Basic
end
