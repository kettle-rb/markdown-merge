# frozen_string_literal: true

module Markdown
  module Merge
    # Merges fenced code blocks using language-specific *-merge gems.
    #
    # When two code blocks with the same signature are matched, this class
    # delegates the merge to the appropriate language-specific merger:
    # - Ruby code → prism-merge
    # - YAML code → psych-merge
    # - JSON code → json-merge
    # - TOML code → toml-merge
    #
    # @example Basic usage
    #   merger = CodeBlockMerger.new
    #   result = merger.merge_code_blocks(template_node, dest_node, preference: :destination)
    #   if result[:merged]
    #     puts result[:content]
    #   else
    #     # Fall back to standard resolution
    #   end
    #
    # @example With custom mergers
    #   merger = CodeBlockMerger.new(
    #     mergers: {
    #       "ruby" => ->(template, dest, pref) { MyCustomRubyMerger.merge(template, dest, pref) },
    #     }
    #   )
    #
    # @see SmartMergerBase
    # @api public
    class CodeBlockMerger
      # Default language-to-merger mapping
      # Each merger is a lambda that takes (template_content, dest_content, preference)
      # and returns { merged: true/false, content: String, stats: Hash }
      # :nocov: integration - DEFAULT_MERGERS lambdas require external gems
      DEFAULT_MERGERS = {
        # Ruby code blocks
        "ruby" => ->(template, dest, preference, **opts) {
          require "prism/merge"
          CodeBlockMerger.merge_with_prism(template, dest, preference, **opts)
        },
        "rb" => ->(template, dest, preference, **opts) {
          require "prism/merge"
          CodeBlockMerger.merge_with_prism(template, dest, preference, **opts)
        },

        # YAML code blocks
        "yaml" => ->(template, dest, preference, **opts) {
          require "psych/merge"
          CodeBlockMerger.merge_with_psych(template, dest, preference, **opts)
        },
        "yml" => ->(template, dest, preference, **opts) {
          require "psych/merge"
          CodeBlockMerger.merge_with_psych(template, dest, preference, **opts)
        },

        # JSON code blocks
        "json" => ->(template, dest, preference, **opts) {
          require "json/merge"
          CodeBlockMerger.merge_with_json(template, dest, preference, **opts)
        },

        # TOML code blocks
        "toml" => ->(template, dest, preference, **opts) {
          require "toml/merge"
          CodeBlockMerger.merge_with_toml(template, dest, preference, **opts)
        },
      }.freeze
      # :nocov:

      # @return [Hash<String, Proc>] Language to merger mapping
      attr_reader :mergers

      # @return [Boolean] Whether inner-merge is enabled
      attr_reader :enabled

      # Creates a new CodeBlockMerger.
      #
      # @param mergers [Hash<String, Proc>] Custom language-to-merger mapping.
      #   Mergers are merged with defaults, allowing selective overrides.
      # @param enabled [Boolean] Whether to enable inner-merge (default: true)
      def initialize(mergers: {}, enabled: true)
        @mergers = DEFAULT_MERGERS.merge(mergers)
        @enabled = enabled
      end

      # Check if inner-merge is available for a language.
      #
      # @param language [String] The language identifier from fence_info
      # @return [Boolean] true if a merger exists for this language
      def supports_language?(language)
        return false unless @enabled
        return false if language.nil? || language.empty?

        @mergers.key?(language.downcase)
      end

      # Merge two code blocks using the appropriate language-specific merger.
      #
      # @param template_node [Object] Template code block node
      # @param dest_node [Object] Destination code block node
      # @param preference [Symbol] :destination or :template
      # @param opts [Hash] Additional options passed to the merger
      # @return [Hash] { merged: Boolean, content: String, stats: Hash }
      def merge_code_blocks(template_node, dest_node, preference:, **opts)
        return not_merged("inner-merge disabled") unless @enabled

        language = extract_language(template_node) || extract_language(dest_node)
        return not_merged("no language specified") unless language

        merger = @mergers[language.downcase]
        return not_merged("no merger for language: #{language}") unless merger

        template_content = extract_content(template_node)
        dest_content = extract_content(dest_node)

        # If content is identical, no need to merge
        if template_content == dest_content
          return {
            merged: true,
            content: rebuild_code_block(language, dest_content, dest_node),
            stats: {decision: :identical},
          }
        end

        begin
          result = merger.call(template_content, dest_content, preference, **opts)
          if result[:merged]
            {
              merged: true,
              content: rebuild_code_block(language, result[:content], dest_node),
              stats: result[:stats] || {},
            }
          else
            not_merged(result[:reason] || "merger declined")
          end
        rescue LoadError => e
          not_merged("merger gem not available: #{e.message}")
        rescue TreeHaver::Error => e
          # TreeHaver::NotAvailable and TreeHaver::Error inherit from Exception (not StandardError)
          # for safety reasons related to backend conflicts. We catch them here to handle
          # gracefully when a backend isn't properly configured.
          not_merged("backend not available: #{e.message}")
        rescue StandardError => e
          # :nocov: defensive - Prism::Merge::ParseError handling when prism/merge is loaded
          # Check for Prism::Merge::ParseError if prism/merge is loaded
          if defined?(::Prism::Merge::ParseError) && e.is_a?(::Prism::Merge::ParseError)
            not_merged("Ruby parse error: #{e.message}")
          else
            not_merged("merge failed: #{e.class}: #{e.message}")
          end
          # :nocov:
        end
      end

      private

      # Extract language from a code block node.
      #
      # @param node [Object] The code block node
      # @return [String, nil] The language identifier
      def extract_language(node)
        return unless node.respond_to?(:fence_info)

        info = node.fence_info
        return if info.nil? || info.empty?

        # fence_info may contain additional info after the language (e.g., "ruby linenos")
        info.split(/\s+/).first
      end

      # Extract content from a code block node.
      #
      # @param node [Object] The code block node
      # @return [String] The code content
      def extract_content(node)
        node.string_content || ""
      end

      # Rebuild a fenced code block with merged content.
      #
      # @param language [String] The language identifier
      # @param content [String] The merged content
      # @param reference_node [Object] Node to copy fence style from
      # @return [String] The reconstructed code block
      def rebuild_code_block(language, content, reference_node)
        # Ensure content ends with newline for proper fence closing
        content = content.chomp + "\n" unless content.end_with?("\n")

        # Use backticks as default fence
        fence = "```"

        "#{fence}#{language}\n#{content}#{fence}"
      end

      # Return a not-merged result.
      #
      # @param reason [String] Why merge was not performed
      # @return [Hash] Not-merged result hash
      def not_merged(reason)
        {merged: false, reason: reason}
      end

      class << self
        # Merge Ruby code using prism-merge.
        #
        # @param template [String] Template Ruby code
        # @param dest [String] Destination Ruby code
        # @param preference [Symbol] :destination or :template
        # @return [Hash] Merge result
        def merge_with_prism(template, dest, preference, **opts)
          merger = ::Prism::Merge::SmartMerger.new(
            template,
            dest,
            preference: preference,
            add_template_only_nodes: opts.fetch(:add_template_only_nodes, false),
          )

          {
            merged: true,
            content: merger.merge,
            stats: merger.stats,
          }
        rescue ::Prism::Merge::ParseError => e
          {merged: false, reason: "Ruby parse error: #{e.message}"}
        end

        # Merge YAML code using psych-merge.
        #
        # @param template [String] Template YAML code
        # @param dest [String] Destination YAML code
        # @param preference [Symbol] :destination or :template
        # @return [Hash] Merge result
        def merge_with_psych(template, dest, preference, **opts)
          merger = ::Psych::Merge::SmartMerger.new(
            template,
            dest,
            preference: preference,
            add_template_only_nodes: opts.fetch(:add_template_only_nodes, false),
          )

          {
            merged: true,
            content: merger.merge,
            stats: merger.stats,
          }
        rescue ::Psych::Merge::ParseError => e
          {merged: false, reason: "YAML parse error: #{e.message}"}
        end

        # Merge JSON code using json-merge.
        #
        # @param template [String] Template JSON code
        # @param dest [String] Destination JSON code
        # @param preference [Symbol] :destination or :template
        # @return [Hash] Merge result
        def merge_with_json(template, dest, preference, **opts)
          merger = ::Json::Merge::SmartMerger.new(
            template,
            dest,
            preference: preference,
            add_template_only_nodes: opts.fetch(:add_template_only_nodes, false),
          )

          {
            merged: true,
            content: merger.merge,
            stats: merger.stats,
          }
        # :nocov: integration - requires json/merge gem
        rescue ::Json::Merge::ParseError => e
          {merged: false, reason: "JSON parse error: #{e.message}"}
          # :nocov:
        end

        # Merge TOML code using toml-merge.
        #
        # @param template [String] Template TOML code
        # @param dest [String] Destination TOML code
        # @param preference [Symbol] :destination or :template
        # @return [Hash] Merge result
        def merge_with_toml(template, dest, preference, **opts)
          merger = ::Toml::Merge::SmartMerger.new(
            template,
            dest,
            preference: preference,
            add_template_only_nodes: opts.fetch(:add_template_only_nodes, false),
          )

          {
            merged: true,
            content: merger.merge,
            stats: merger.stats,
          }
        rescue ::Toml::Merge::ParseError => e
          {merged: false, reason: "TOML parse error: #{e.message}"}
        end
      end
    end
  end
end
