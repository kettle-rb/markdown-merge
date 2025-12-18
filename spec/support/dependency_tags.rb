# frozen_string_literal: true

# Dependency detection helpers for conditional test execution in markdown-merge
#
# This module detects which optional markdown parsing backends are available
# and configures RSpec to skip tests that require unavailable dependencies.
#
# Usage in specs:
#   it "requires markly", :markly do
#     # This test only runs when Markly is available
#   end
#
#   it "requires commonmarker", :commonmarker do
#     # This test only runs when Commonmarker is available
#   end
#
#   it "requires any markdown backend", :markdown_backend do
#     # This test only runs when at least one markdown backend is available
#   end
#
#   it "requires toml-merge", :toml_merge do
#     # This test only runs when toml-merge is fully functional
#   end
#
# Negated tags (for testing behavior when dependencies are NOT available):
#   it "only runs when markly is NOT available", :not_markly do
#     # This test only runs when Markly is NOT available
#   end

module MarkdownMergeDependencies
  class << self
    # Check if Markly gem is available
    # Markly uses MRI C extensions and won't work on JRuby/TruffleRuby
    def markly_available?
      return @markly_available if defined?(@markly_available)
      @markly_available = TreeHaver::Backends::Markly.available?
    end

    # Check if Commonmarker gem is available
    # Commonmarker uses Rust extensions
    def commonmarker_available?
      return @commonmarker_available if defined?(@commonmarker_available)
      @commonmarker_available = TreeHaver::Backends::Commonmarker.available?
    end

    # Check if at least one markdown backend is available
    def any_markdown_backend_available?
      markly_available? || commonmarker_available?
    end

    # ============================================================
    # Inner-merge dependencies for CodeBlockMerger
    # These check both gem availability AND backend functionality
    # ============================================================

    # Check if toml-merge is available and functional
    # Requires toml-merge gem + (tree-sitter-toml OR toml-rb/citrus)
    def toml_merge_available?
      return @toml_merge_available if defined?(@toml_merge_available)
      @toml_merge_available = begin
        require "toml/merge"
        # Test that we can actually create a merger (validates backend is working)
        Toml::Merge::SmartMerger.new("key = 'test'", "key = 'test'")
        true
      rescue LoadError, TreeHaver::Error, TreeHaver::NotAvailable, StandardError
        false
      end
    end

    # Check if json-merge is available and functional
    def json_merge_available?
      return @json_merge_available if defined?(@json_merge_available)
      @json_merge_available = begin
        require "json/merge"
        Json::Merge::SmartMerger.new('{"a":1}', '{"a":1}')
        true
      rescue LoadError, TreeHaver::Error, TreeHaver::NotAvailable, StandardError
        false
      end
    end

    # Check if prism-merge is available and functional
    def prism_merge_available?
      return @prism_merge_available if defined?(@prism_merge_available)
      @prism_merge_available = begin
        require "prism/merge"
        Prism::Merge::SmartMerger.new("puts 1", "puts 1")
        true
      rescue LoadError, TreeHaver::Error, TreeHaver::NotAvailable, StandardError
        false
      end
    end

    # Check if psych-merge is available and functional
    def psych_merge_available?
      return @psych_merge_available if defined?(@psych_merge_available)
      @psych_merge_available = begin
        require "psych/merge"
        Psych::Merge::SmartMerger.new("key: value", "key: value")
        true
      rescue LoadError, TreeHaver::Error, TreeHaver::NotAvailable, StandardError
        false
      end
    end

    # Check if running on JRuby
    def jruby?
      defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
    end

    # Check if running on TruffleRuby
    def truffleruby?
      defined?(RUBY_ENGINE) && RUBY_ENGINE == "truffleruby"
    end

    # Check if running on MRI (CRuby)
    def mri?
      defined?(RUBY_ENGINE) && RUBY_ENGINE == "ruby"
    end

    # Get a summary of available dependencies (for debugging)
    def summary
      {
        markly: markly_available?,
        commonmarker: commonmarker_available?,
        any_markdown_backend: any_markdown_backend_available?,
        toml_merge: toml_merge_available?,
        json_merge: json_merge_available?,
        prism_merge: prism_merge_available?,
        psych_merge: psych_merge_available?,
        ruby_engine: RUBY_ENGINE,
        jruby: jruby?,
        truffleruby: truffleruby?,
        mri: mri?,
      }
    end
  end
end

RSpec.configure do |config|
  # Define exclusion filters for optional dependencies
  # Tests tagged with these will be skipped when the dependency is not available

  config.before(:suite) do
    # Print dependency summary if MARKDOWN_MERGE_DEBUG is set
    if ENV["MARKDOWN_MERGE_DEBUG"]
      puts "\n=== Markdown::Merge Test Dependencies ==="
      MarkdownMergeDependencies.summary.each do |dep, available|
        status = case available
        when true then "✓ available"
        when false then "✗ not available"
        else available.to_s
        end
        puts "  #{dep}: #{status}"
      end
      puts "==========================================\n"
    end
  end

  # ============================================================
  # Positive tags: run when dependency IS available
  # ============================================================

  # Skip tests tagged :markly when Markly is not available
  config.filter_run_excluding markly: true unless MarkdownMergeDependencies.markly_available?

  # Skip tests tagged :commonmarker when Commonmarker is not available
  config.filter_run_excluding commonmarker: true unless MarkdownMergeDependencies.commonmarker_available?

  # Skip tests tagged :markdown_backend when no markdown backend is available
  config.filter_run_excluding markdown_backend: true unless MarkdownMergeDependencies.any_markdown_backend_available?

  # Skip tests tagged :toml_merge when toml-merge is not available
  config.filter_run_excluding toml_merge: true unless MarkdownMergeDependencies.toml_merge_available?

  # Skip tests tagged :json_merge when json-merge is not available
  config.filter_run_excluding json_merge: true unless MarkdownMergeDependencies.json_merge_available?

  # Skip tests tagged :prism_merge when prism-merge is not available
  config.filter_run_excluding prism_merge: true unless MarkdownMergeDependencies.prism_merge_available?

  # Skip tests tagged :psych_merge when psych-merge is not available
  config.filter_run_excluding psych_merge: true unless MarkdownMergeDependencies.psych_merge_available?

  # Skip tests tagged :mri when not running on MRI
  config.filter_run_excluding mri: true unless MarkdownMergeDependencies.mri?

  # Skip tests tagged :jruby when not running on JRuby
  config.filter_run_excluding jruby: true unless MarkdownMergeDependencies.jruby?

  # Skip tests tagged :truffleruby when not running on TruffleRuby
  config.filter_run_excluding truffleruby: true unless MarkdownMergeDependencies.truffleruby?

  # ============================================================
  # Negated tags: run when dependency is NOT available
  # Use these to test fallback/error behavior when deps are missing
  # ============================================================

  # Skip tests tagged :not_markly when Markly IS available
  config.filter_run_excluding not_markly: true if MarkdownMergeDependencies.markly_available?

  # Skip tests tagged :not_commonmarker when Commonmarker IS available
  config.filter_run_excluding not_commonmarker: true if MarkdownMergeDependencies.commonmarker_available?

  # Skip tests tagged :not_markdown_backend when any markdown backend IS available
  config.filter_run_excluding not_markdown_backend: true if MarkdownMergeDependencies.any_markdown_backend_available?

  # Skip tests tagged :not_toml_merge when toml-merge IS available
  config.filter_run_excluding not_toml_merge: true if MarkdownMergeDependencies.toml_merge_available?

  # Skip tests tagged :not_json_merge when json-merge IS available
  config.filter_run_excluding not_json_merge: true if MarkdownMergeDependencies.json_merge_available?

  # Skip tests tagged :not_prism_merge when prism-merge IS available
  config.filter_run_excluding not_prism_merge: true if MarkdownMergeDependencies.prism_merge_available?

  # Skip tests tagged :not_psych_merge when psych-merge IS available
  config.filter_run_excluding not_psych_merge: true if MarkdownMergeDependencies.psych_merge_available?

  # Skip tests tagged :not_mri when running on MRI
  config.filter_run_excluding not_mri: true if MarkdownMergeDependencies.mri?

  # Skip tests tagged :not_jruby when running on JRuby
  config.filter_run_excluding not_jruby: true if MarkdownMergeDependencies.jruby?

  # Skip tests tagged :not_truffleruby when running on TruffleRuby
  config.filter_run_excluding not_truffleruby: true if MarkdownMergeDependencies.truffleruby?
end

