# frozen_string_literal: true

module Markdown
  module Merge
    # Resolves conflicts between matching Markdown elements from template and destination.
    #
    # When two elements have the same signature but different content, the resolver
    # determines which version to use based on the configured preference.
    #
    # Inherits from Ast::Merge::ConflictResolverBase using the :node strategy,
    # which resolves conflicts on a per-node-pair basis.
    #
    # @example Basic usage
    #   resolver = ConflictResolver.new(
    #     preference: :destination,
    #     template_analysis: template_analysis,
    #     dest_analysis: dest_analysis
    #   )
    #   resolution = resolver.resolve(template_node, dest_node, template_index: 0, dest_index: 0)
    #   case resolution[:source]
    #   when :template
    #     # Use template version
    #   when :destination
    #     # Use destination version
    #   end
    #
    # @see SmartMergerBase
    # @see Ast::Merge::ConflictResolverBase
    class ConflictResolver < Ast::Merge::ConflictResolverBase
      # Initialize a conflict resolver
      #
      # @param preference [Symbol] Which version to prefer (:destination or :template)
      # @param template_analysis [FileAnalysisBase] Analysis of the template file
      # @param dest_analysis [FileAnalysisBase] Analysis of the destination file
      # @param options [Hash] Additional options for forward compatibility
      def initialize(preference:, template_analysis:, dest_analysis:, **options)
        super(
          strategy: :node,
          preference: preference,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
          **options
        )
      end

      protected

      # Resolve a conflict between template and destination nodes
      #
      # @param template_node [Object] Node from template
      # @param dest_node [Object] Node from destination
      # @param template_index [Integer] Index in template statements
      # @param dest_index [Integer] Index in destination statements
      # @return [Hash] Resolution with :source, :decision, and node references
      def resolve_node_pair(template_node, dest_node, template_index:, dest_index:)
        # Frozen blocks always win
        if freeze_node?(dest_node)
          return frozen_resolution(
            source: :destination,
            template_node: template_node,
            dest_node: dest_node,
            reason: dest_node.reason,
          )
        end

        if freeze_node?(template_node)
          return frozen_resolution(
            source: :template,
            template_node: template_node,
            dest_node: dest_node,
            reason: template_node.reason,
          )
        end

        # Check if content is identical
        if content_identical?(template_node, dest_node)
          return identical_resolution(
            template_node: template_node,
            dest_node: dest_node,
          )
        end

        # Use preference to decide
        preference_resolution(
          template_node: template_node,
          dest_node: dest_node,
        )
      end

      private

      # Check if two nodes have identical content
      #
      # @param template_node [Object] Template node
      # @param dest_node [Object] Destination node
      # @return [Boolean] True if content is identical
      def content_identical?(template_node, dest_node)
        template_text = node_to_text(template_node, @template_analysis)
        dest_text = node_to_text(dest_node, @dest_analysis)
        template_text == dest_text
      end

      # Convert a node to its source text
      #
      # @param node [Object] Node to convert
      # @param analysis [FileAnalysisBase] Analysis for source lookup
      # @return [String] Source text
      def node_to_text(node, analysis)
        # Check for any FreezeNode type (base class or subclass)
        if node.is_a?(Ast::Merge::FreezeNodeBase)
          node.full_text
        else
          pos = node.source_position
          start_line = pos&.dig(:start_line)
          end_line = pos&.dig(:end_line)

          if start_line && end_line
            analysis.source_range(start_line, end_line)
          else
            # :nocov: defensive - Markdown nodes typically have source positions
            node.to_commonmark
            # :nocov:
          end
        end
      end
    end
  end
end
