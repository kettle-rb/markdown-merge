# frozen_string_literal: true

# External gems
require "version_gem"
require "set"

# Shared merge infrastructure
require "ast/merge"

# This gem - only require version
require_relative "merge/version"

module Markdown
  # Smart merging for Markdown files using AST-based parsers.
  #
  # Markdown::Merge provides a shared foundation for intelligent Markdown merging:
  # - Base classes for parser-specific implementations
  # - Matching structural elements (headings, paragraphs, lists, etc.) between files
  # - Preserving frozen sections marked with HTML comments
  # - Resolving conflicts based on configurable preferences
  #
  # This gem is typically not used directly. Instead, use a parser-specific
  # implementation like commonmarker-merge or markly-merge.
  #
  # @example Using with commonmarker-merge
  #   require "commonmarker/merge"
  #   merger = Commonmarker::Merge::SmartMerger.new(template, destination)
  #   result = merger.merge
  #
  # @see FileAnalysisBase Base class for file analysis
  # @see SmartMergerBase Base class for merge operations
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

    # Autoload all components
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
  end
end

Markdown::Merge::Version.class_eval do
  extend VersionGem::Basic
end
