# frozen_string_literal: true

module Markdown
  module Merge
    # Represents the result of a Markdown merge operation.
    #
    # Inherits from Ast::Merge::MergeResultBase to provide consistent result
    # handling across all merge gems. Contains the merged content along
    # with metadata about conflicts, frozen sections, and changes made.
    #
    # @example Successful merge
    #   result = SmartMerger.merge(source_a, source_b)
    #   if result.success?
    #     File.write("merged.md", result.content)
    #   end
    #
    # @example Handling conflicts
    #   result = SmartMerger.merge(source_a, source_b)
    #   if result.conflicts?
    #     result.conflicts.each do |conflict|
    #       puts "Conflict at: #{conflict[:location]}"
    #     end
    #   end
    #
    # @see Ast::Merge::MergeResultBase Base class
    class MergeResult < Ast::Merge::MergeResultBase
      # Initialize a new MergeResult
      #
      # @param content [String, nil] Merged content (nil if merge failed)
      # @param conflicts [Array<Hash>] Conflict descriptions
      # @param frozen_blocks [Array<Hash>] Preserved frozen block info
      # @param stats [Hash] Merge statistics
      # @param options [Hash] Additional options for forward compatibility
      def initialize(content:, conflicts: [], frozen_blocks: [], stats: {}, **options)
        super(
          conflicts: conflicts,
          frozen_blocks: frozen_blocks,
          stats: default_stats.merge(stats),
          **options
        )
        @content_raw = content
      end

      # Get the merged content as a string.
      # Overrides base class to return string content directly.
      #
      # @return [String, nil] The merged Markdown content
      def content
        @content_raw
      end

      # Check if content has been set (not nil).
      # Overrides base class for string-based content.
      #
      # @return [Boolean]
      def content?
        !@content_raw.nil?
      end

      # Get content as a string (alias for content in this class).
      #
      # @return [String, nil] The merged content
      def content_string
        @content_raw
      end

      # Check if merge was successful (no unresolved conflicts)
      #
      # @return [Boolean] True if merge succeeded
      def success?
        conflicts.empty? && content?
      end

      # Check if there are unresolved conflicts
      #
      # @return [Boolean] True if conflicts exist
      def conflicts?
        !conflicts.empty?
      end

      # Check if any frozen blocks were preserved
      #
      # @return [Boolean] True if frozen blocks were preserved
      def has_frozen_blocks?
        !frozen_blocks.empty?
      end

      # Get count of nodes added during merge
      #
      # @return [Integer] Number of nodes added
      def nodes_added
        stats[:nodes_added] || 0
      end

      # Get count of nodes removed during merge
      #
      # @return [Integer] Number of nodes removed
      def nodes_removed
        stats[:nodes_removed] || 0
      end

      # Get count of nodes modified during merge
      #
      # @return [Integer] Number of nodes modified
      def nodes_modified
        stats[:nodes_modified] || 0
      end

      # Get merge duration in milliseconds
      #
      # @return [Float, nil] Merge time in milliseconds
      def merge_time_ms
        stats[:merge_time_ms]
      end

      # Get count of frozen blocks preserved
      #
      # @return [Integer] Number of frozen blocks
      def frozen_count
        frozen_blocks.size
      end

      # String representation for debugging
      #
      # @return [String] Debug representation
      def inspect
        status = success? ? "success" : "failed"
        "#<#{self.class.name} #{status} conflicts=#{conflicts.size} frozen=#{frozen_blocks.size} " \
          "added=#{nodes_added} removed=#{nodes_removed} modified=#{nodes_modified}>"
      end

      # Convert to string (returns merged content)
      #
      # @return [String] The merged content or empty string
      def to_s
        content || ""
      end

      private

      # Default statistics structure
      #
      # @return [Hash] Default stats hash
      def default_stats
        {
          nodes_added: 0,
          nodes_removed: 0,
          nodes_modified: 0,
          merge_time_ms: 0,
        }
      end
    end
  end
end
