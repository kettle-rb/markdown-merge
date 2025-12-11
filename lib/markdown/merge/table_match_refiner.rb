# frozen_string_literal: true

module Markdown
  module Merge
    # Match refiner for Markdown tables that didn't match by exact signature.
    #
    # This refiner uses the TableMatchAlgorithm to pair tables that have:
    # - Similar but not identical headers
    # - Similar structure (row/column counts)
    # - Similar content in key columns
    #
    # Tables are matched using a multi-factor scoring algorithm that considers:
    # - Header cell similarity
    # - First column (row label) similarity
    # - Overall content overlap
    # - Position in document
    #
    # @example Basic usage
    #   refiner = TableMatchRefiner.new(threshold: 0.5)
    #   matches = refiner.call(template_nodes, dest_nodes)
    #
    # @example With custom algorithm options
    #   refiner = TableMatchRefiner.new(
    #     threshold: 0.6,
    #     algorithm_options: {
    #       weights: { header_match: 0.4, position: 0.1 }
    #     }
    #   )
    #
    # @see Ast::Merge::MatchRefinerBase
    # @see TableMatchAlgorithm
    class TableMatchRefiner < Ast::Merge::MatchRefinerBase
      # @return [Hash] Options passed to TableMatchAlgorithm
      attr_reader :algorithm_options

      # Initialize a table match refiner.
      #
      # @param threshold [Float] Minimum score to accept a match (default: 0.5)
      # @param algorithm_options [Hash] Options for TableMatchAlgorithm
      def initialize(threshold: DEFAULT_THRESHOLD, algorithm_options: {}, **options)
        super(threshold: threshold, node_types: [:table], **options)
        @algorithm_options = algorithm_options
      end

      # Find matches between unmatched table nodes.
      #
      # @param template_nodes [Array] Unmatched nodes from template
      # @param dest_nodes [Array] Unmatched nodes from destination
      # @param context [Hash] Additional context (may contain :template_analysis, :dest_analysis)
      # @return [Array<MatchResult>] Array of table matches
      def call(template_nodes, dest_nodes, context = {})
        template_tables = extract_tables(template_nodes)
        dest_tables = extract_tables(dest_nodes)

        return [] if template_tables.empty? || dest_tables.empty?

        # Build position information for better matching
        total_template = template_tables.size
        total_dest = dest_tables.size

        greedy_match(template_tables, dest_tables) do |t_node, d_node|
          t_idx = template_tables.index(t_node) || 0
          d_idx = dest_tables.index(d_node) || 0

          compute_table_similarity(t_node, d_node, t_idx, d_idx, total_template, total_dest)
        end
      end

      private

      # Extract table nodes from a collection.
      #
      # @param nodes [Array] Nodes to filter
      # @return [Array] Table nodes
      def extract_tables(nodes)
        nodes.select { |n| table_node?(n) }
      end

      # Check if a node is a table.
      #
      # @param node [Object] Node to check
      # @return [Boolean]
      def table_node?(node)
        return true if node.respond_to?(:type) && node.type == :table
        return true if node.class.name.to_s.include?("Table")

        false
      end

      # Compute similarity score between two tables.
      #
      # @param t_table [Object] Template table
      # @param d_table [Object] Destination table
      # @param t_idx [Integer] Template table index
      # @param d_idx [Integer] Destination table index
      # @param total_t [Integer] Total template tables
      # @param total_d [Integer] Total destination tables
      # @return [Float] Similarity score (0.0-1.0)
      def compute_table_similarity(t_table, d_table, t_idx, d_idx, total_t, total_d)
        algorithm = TableMatchAlgorithm.new(
          position_a: t_idx,
          position_b: d_idx,
          total_tables_a: total_t,
          total_tables_b: total_d,
          **algorithm_options,
        )

        algorithm.call(t_table, d_table)
      end
    end
  end
end
