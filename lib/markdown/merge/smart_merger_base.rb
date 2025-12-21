# frozen_string_literal: true

module Markdown
  module Merge
    # Base class for smart Markdown file merging.
    #
    # Orchestrates the smart merge process for Markdown files using
    # FileAnalysisBase, FileAligner, ConflictResolver, and MergeResult to
    # merge two Markdown files intelligently. Freeze blocks marked with
    # HTML comments are preserved exactly as-is.
    #
    # Subclasses must implement:
    # - #create_file_analysis(content, **options) - Create parser-specific FileAnalysis
    # - #node_to_source(node, analysis) - Convert a node to source text
    #
    # SmartMergerBase provides flexible configuration for different merge scenarios:
    # - Preserve destination customizations (default)
    # - Apply template updates
    # - Add new sections from template
    # - Inner-merge fenced code blocks using language-specific mergers (optional)
    #
    # @example Subclass implementation
    #   class SmartMerger < Markdown::Merge::SmartMergerBase
    #     def create_file_analysis(content, **options)
    #       FileAnalysis.new(content, **options)
    #     end
    #
    #     def node_to_source(node, analysis)
    #       case node
    #       when FreezeNode
    #         node.full_text
    #       else
    #         analysis.source_range(node.start_line, node.end_line)
    #       end
    #     end
    #   end
    #
    # @abstract Subclass and implement parser-specific methods
    # @see FileAnalysisBase
    # @see FileAligner
    # @see ConflictResolver
    # @see MergeResult
    class SmartMergerBase
      # @return [FileAnalysisBase] Analysis of the template file
      attr_reader :template_analysis

      # @return [FileAnalysisBase] Analysis of the destination file
      attr_reader :dest_analysis

      # @return [FileAligner] Aligner for finding matches and differences
      attr_reader :aligner

      # @return [ConflictResolver] Resolver for handling conflicting content
      attr_reader :resolver

      # @return [CodeBlockMerger, nil] Merger for fenced code blocks
      attr_reader :code_block_merger

      # @return [Hash{Symbol,String => #call}, nil] Node typing configuration
      attr_reader :node_typing

      # Creates a new SmartMerger for intelligent Markdown file merging.
      #
      # @param template_content [String] Template Markdown source code
      # @param dest_content [String] Destination Markdown source code
      #
      # @param signature_generator [Proc, nil] Optional proc to generate custom node signatures.
      #   The proc receives a node and should return one of:
      #   - An array representing the node's signature
      #   - `nil` to indicate the node should have no signature
      #   - The original node to fall through to default signature computation
      #
      # @param preference [Symbol, Hash] Controls which version to use when nodes
      #   have matching signatures but different content:
      #   - `:destination` (default) - Use destination version (preserves customizations)
      #   - `:template` - Use template version (applies updates)
      #   - Hash for per-type preferences: `{ default: :destination, gem_table: :template }`
      #
      # @param add_template_only_nodes [Boolean] Controls whether to add nodes that only
      #   exist in template:
      #   - `false` (default) - Skip template-only nodes
      #   - `true` - Add template-only nodes to result
      #
      # @param inner_merge_code_blocks [Boolean, CodeBlockMerger] Controls inner-merge for
      #   fenced code blocks:
      #   - `true` - Enable inner-merge using default CodeBlockMerger
      #   - `false` (default) - Disable inner-merge (use standard conflict resolution)
      #   - `CodeBlockMerger` instance - Use custom CodeBlockMerger
      #
      # @param freeze_token [String] Token to use for freeze block markers.
      #   Default: "markdown-merge"
      #
      # @param match_refiner [#call, nil] Optional match refiner for fuzzy matching of
      #   unmatched nodes. Default: nil (fuzzy matching disabled).
      #   Set to TableMatchRefiner.new to enable fuzzy table matching.
      #
      # @param node_typing [Hash{Symbol,String => #call}, nil] Node typing configuration
      #   for per-node-type merge preferences. Maps node type names to callables that
      #   can wrap nodes with custom merge_types for use with Hash-based preference.
      #   @example
      #     node_typing = {
      #       table: ->(node) {
      #         text = node.to_plaintext
      #         if text.include?("tree_haver")
      #           Ast::Merge::NodeTyping.with_merge_type(node, :gem_family_table)
      #         else
      #           node
      #         end
      #       }
      #     }
      #     merger = SmartMerger.new(template, dest,
      #       node_typing: node_typing,
      #       preference: { default: :destination, gem_family_table: :template })
      #
      # @param parser_options [Hash] Additional parser-specific options
      #
      # @raise [TemplateParseError] If template has syntax errors
      # @raise [DestinationParseError] If destination has syntax errors
      def initialize(
        template_content,
        dest_content,
        signature_generator: nil,
        preference: :destination,
        add_template_only_nodes: false,
        inner_merge_code_blocks: false,
        freeze_token: FileAnalysisBase::DEFAULT_FREEZE_TOKEN,
        match_refiner: nil,
        node_typing: nil,
        **parser_options
      )
        @preference = preference
        @add_template_only_nodes = add_template_only_nodes
        @match_refiner = match_refiner
        @node_typing = node_typing

        # Validate node_typing if provided
        Ast::Merge::NodeTyping.validate!(node_typing) if node_typing

        # Set up code block merger
        @code_block_merger = case inner_merge_code_blocks
        when true
          CodeBlockMerger.new
        when false
          nil
        when CodeBlockMerger
          inner_merge_code_blocks
        else
          raise ArgumentError, "inner_merge_code_blocks must be true, false, or a CodeBlockMerger instance"
        end

        # Parse template
        begin
          @template_analysis = create_file_analysis(
            template_content,
            freeze_token: freeze_token,
            signature_generator: signature_generator,
            **parser_options,
          )
        rescue StandardError => e
          raise template_parse_error_class.new(errors: [e])
        end

        # Parse destination
        begin
          @dest_analysis = create_file_analysis(
            dest_content,
            freeze_token: freeze_token,
            signature_generator: signature_generator,
            **parser_options,
          )
        rescue StandardError => e
          raise destination_parse_error_class.new(errors: [e])
        end

        @aligner = FileAligner.new(@template_analysis, @dest_analysis, match_refiner: @match_refiner)
        @resolver = ConflictResolver.new(
          preference: @preference,
          template_analysis: @template_analysis,
          dest_analysis: @dest_analysis,
        )
      end

      # Create a FileAnalysis instance for the given content.
      #
      # @abstract Subclasses must implement this method
      # @param content [String] Markdown content to analyze
      # @param options [Hash] Analysis options
      # @return [FileAnalysisBase] File analysis instance
      def create_file_analysis(content, **options)
        raise NotImplementedError, "#{self.class} must implement #create_file_analysis"
      end

      # Returns the TemplateParseError class to use.
      #
      # Subclasses should override to return their parser-specific error class.
      #
      # @return [Class] TemplateParseError class
      def template_parse_error_class
        TemplateParseError
      end

      # Returns the DestinationParseError class to use.
      #
      # Subclasses should override to return their parser-specific error class.
      #
      # @return [Class] DestinationParseError class
      def destination_parse_error_class
        DestinationParseError
      end

      # Perform the merge operation and return the merged content as a string.
      #
      # @return [String] The merged Markdown content
      def merge
        merge_result.content
      end

      # Perform the merge operation and return the full MergeResult object.
      #
      # @return [MergeResult] The merge result containing merged content and metadata
      def merge_result
        return @merge_result if @merge_result

        @merge_result = DebugLogger.time("SmartMergerBase#merge") do
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          alignment = DebugLogger.time("SmartMergerBase#align") do
            @aligner.align
          end

          DebugLogger.debug("Alignment complete", {
            total_entries: alignment.size,
            matches: alignment.count { |e| e[:type] == :match },
            template_only: alignment.count { |e| e[:type] == :template_only },
            dest_only: alignment.count { |e| e[:type] == :dest_only },
          })

          merged_parts, stats, frozen_blocks, conflicts = DebugLogger.time("SmartMergerBase#process") do
            process_alignment(alignment)
          end

          end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          stats[:merge_time_ms] = ((end_time - start_time) * 1000).round(2)

          MergeResult.new(
            content: merged_parts.join("\n\n"),
            conflicts: conflicts,
            frozen_blocks: frozen_blocks,
            stats: stats,
          )
        end
      end

      # Get merge statistics (convenience method).
      #
      # @return [Hash] Statistics from the merge result
      def stats
        merge_result.stats
      end

      private

      # Process alignment entries and build result
      #
      # @param alignment [Array<Hash>] Alignment entries
      # @return [Array] [merged_parts, stats, frozen_blocks, conflicts]
      def process_alignment(alignment)
        merged_parts = []
        frozen_blocks = []
        conflicts = []
        stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0}

        alignment.each do |entry|
          case entry[:type]
          when :match
            part, frozen = process_match(entry, stats)
            merged_parts << part if part
            frozen_blocks << frozen if frozen
          when :template_only
            part = process_template_only(entry, stats)
            merged_parts << part if part
          when :dest_only
            part, frozen = process_dest_only(entry, stats)
            merged_parts << part if part
            frozen_blocks << frozen if frozen
          end
        end

        [merged_parts, stats, frozen_blocks, conflicts]
      end

      # Process a matched node pair
      #
      # @param entry [Hash] Alignment entry
      # @param stats [Hash] Statistics hash to update
      # @return [Array] [content_string, frozen_block_info]
      def process_match(entry, stats)
        template_node = apply_node_typing(entry[:template_node])
        dest_node = apply_node_typing(entry[:dest_node])

        # Try inner-merge for code blocks first
        if @code_block_merger && code_block_node?(template_node) && code_block_node?(dest_node)
          inner_result = try_inner_merge_code_block(template_node, dest_node, stats)
          return inner_result if inner_result
        end

        resolution = @resolver.resolve(
          template_node,
          dest_node,
          template_index: entry[:template_index],
          dest_index: entry[:dest_index],
        )

        frozen_info = nil

        # Use unwrapped node for source extraction
        raw_template_node = Ast::Merge::NodeTyping.unwrap(template_node)
        raw_dest_node = Ast::Merge::NodeTyping.unwrap(dest_node)

        content = case resolution[:source]
        when :template
          stats[:nodes_modified] += 1 if resolution[:decision] != :identical
          node_to_source(raw_template_node, @template_analysis)
        when :destination
          if raw_dest_node.respond_to?(:freeze_node?) && raw_dest_node.freeze_node?
            frozen_info = {
              start_line: raw_dest_node.start_line,
              end_line: raw_dest_node.end_line,
              reason: raw_dest_node.reason,
            }
          end
          node_to_source(raw_dest_node, @dest_analysis)
        end

        [content, frozen_info]
      end

      # Apply node typing to a node if node_typing is configured.
      #
      # For markdown nodes, this supports matching by:
      # 1. Node class name (standard NodeTyping behavior)
      # 2. Canonical node type (e.g., :heading, :table, :paragraph)
      #
      # Note: Markdown nodes are pre-wrapped with canonical merge_type by
      # NodeTypeNormalizer during parsing. This method allows custom node_typing
      # to override or refine that canonical type.
      #
      # @param node [Object] The node to potentially wrap with merge_type
      # @return [Object] The node, possibly wrapped with NodeTyping::Wrapper
      def apply_node_typing(node)
        return node unless @node_typing
        return node unless node

        # For markdown nodes, check if there's a custom callable for the canonical type.
        # This takes precedence because nodes are pre-wrapped by NodeTypeNormalizer.
        if node.respond_to?(:type)
          canonical_type = node.type
          callable = @node_typing[canonical_type] ||
            @node_typing[canonical_type.to_s] ||
            @node_typing[canonical_type.to_sym]
          if callable
            # Call the custom lambda - it may return a refined typed node
            # or the original node unchanged
            return callable.call(node)
          end
        end

        # Fall back to standard class-name-based matching
        result = Ast::Merge::NodeTyping.process(node, @node_typing)
        return result if Ast::Merge::NodeTyping.typed_node?(result)

        node
      end

      # Check if a node is a code block.
      #
      # @param node [Object] Node to check
      # @return [Boolean] true if the node is a code block
      def code_block_node?(node)
        return false if node.respond_to?(:freeze_node?) && node.freeze_node?

        node.respond_to?(:type) && node.type == :code_block
      end

      # Try to inner-merge two code block nodes.
      #
      # @param template_node [Object] Template code block
      # @param dest_node [Object] Destination code block
      # @param stats [Hash] Statistics hash to update
      # @return [Array, nil] [content_string, nil] if merged, nil to fall back to standard resolution
      def try_inner_merge_code_block(template_node, dest_node, stats)
        result = @code_block_merger.merge_code_blocks(
          template_node,
          dest_node,
          preference: @preference,
          add_template_only_nodes: @add_template_only_nodes,
        )

        if result[:merged]
          stats[:nodes_modified] += 1 unless result.dig(:stats, :decision) == :identical
          stats[:inner_merges] ||= 0
          stats[:inner_merges] += 1
          [result[:content], nil]
        else
          DebugLogger.debug("Inner-merge skipped", {reason: result[:reason]})
          nil # Fall back to standard resolution
        end
      end

      # Process a template-only node
      #
      # @param entry [Hash] Alignment entry
      # @param stats [Hash] Statistics hash to update
      # @return [String, nil] Content string or nil
      def process_template_only(entry, stats)
        return unless @add_template_only_nodes

        stats[:nodes_added] += 1
        node_to_source(entry[:template_node], @template_analysis)
      end

      # Process a destination-only node
      #
      # @param entry [Hash] Alignment entry
      # @param stats [Hash] Statistics hash to update
      # @return [Array] [content_string, frozen_block_info]
      def process_dest_only(entry, stats)
        frozen_info = nil

        if entry[:dest_node].respond_to?(:freeze_node?) && entry[:dest_node].freeze_node?
          frozen_info = {
            start_line: entry[:dest_node].start_line,
            end_line: entry[:dest_node].end_line,
            reason: entry[:dest_node].reason,
          }
        end

        content = node_to_source(entry[:dest_node], @dest_analysis)
        [content, frozen_info]
      end

      # Convert a node to its source text.
      #
      # Default implementation uses source positions and falls back to to_commonmark.
      # Subclasses may override for parser-specific behavior.
      #
      # @param node [Object] Node to convert
      # @param analysis [FileAnalysisBase] Analysis for source lookup
      # @return [String] Source text
      def node_to_source(node, analysis)
        # Check for any FreezeNode type (base class or subclass)
        if node.is_a?(Ast::Merge::FreezeNodeBase)
          node.full_text
        else
          pos = node.source_position
          start_line = pos&.dig(:start_line)
          end_line = pos&.dig(:end_line)

          return node.to_commonmark unless start_line && end_line

          analysis.source_range(start_line, end_line)
        end
      end
    end
  end
end
