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
      # @param add_template_only_nodes [Boolean, #call] Controls whether to add nodes that only
      #   exist in template:
      #   - `false` (default) - Skip template-only nodes
      #   - `true` - Add all template-only nodes to result
      #   - Callable (Proc/Lambda) - Called with (node, entry) for each template-only node.
      #     Return truthy to add the node, falsey to skip it.
      #     @example Filter to only add gem family link refs
      #       add_template_only_nodes: ->(node, entry) {
      #         sig = entry[:signature]
      #         sig.is_a?(Array) && sig.first == :gem_family
      #       }
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
      # @param normalize_whitespace [Boolean, Symbol] Whitespace normalization mode:
      #   - `false` (default) - No normalization
      #   - `true` or `:basic` - Collapse excessive blank lines (3+ → 2)
      #   - `:link_refs` - Basic + remove blank lines between consecutive link reference definitions
      #   - `:strict` - All normalizations (same as :link_refs currently)
      #
      # @param rehydrate_link_references [Boolean] If true, convert inline links/images
      #   to reference-style when a matching link reference definition exists. Default: false
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
        normalize_whitespace: false,
        rehydrate_link_references: false,
        **parser_options
      )
        @preference = preference
        @add_template_only_nodes = add_template_only_nodes
        @match_refiner = match_refiner
        @node_typing = node_typing
        @normalize_whitespace = normalize_whitespace
        @rehydrate_link_references = rehydrate_link_references

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
          alignment = DebugLogger.time("SmartMergerBase#align") do
            @aligner.align
          end

          DebugLogger.debug("Alignment complete", {
            total_entries: alignment.size,
            matches: alignment.count { |e| e[:type] == :match },
            template_only: alignment.count { |e| e[:type] == :template_only },
            dest_only: alignment.count { |e| e[:type] == :dest_only },
          })

          # Process alignment using OutputBuilder
          builder, stats, frozen_blocks, conflicts = DebugLogger.time("SmartMergerBase#process") do
            process_alignment(alignment)
          end

          # Get content from OutputBuilder
          content = builder.to_s

          # Collect problems from post-processing
          problems = DocumentProblems.new

          # Apply post-processing transformations
          content, problems = apply_post_processing(content, problems)

          # Get final content from OutputBuilder
          MergeResult.new(
            content: content,
            conflicts: conflicts,
            frozen_blocks: frozen_blocks,
            stats: stats,
            problems: problems,
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

      # Apply post-processing transformations to merged content.
      #
      # @param content [String] The merged content
      # @param problems [DocumentProblems] Problems collector to add to
      # @return [Array<String, DocumentProblems>] [transformed_content, problems]
      def apply_post_processing(content, problems)
        # Apply whitespace normalization if enabled
        if @normalize_whitespace
          # Support both boolean and symbol modes
          mode = @normalize_whitespace == true ? :basic : @normalize_whitespace
          normalizer = WhitespaceNormalizer.new(content, mode: mode)
          content = normalizer.normalize
          problems.merge!(normalizer.problems)
        end

        # Apply link reference rehydration if enabled
        if @rehydrate_link_references
          rehydrator = LinkReferenceRehydrator.new(content)
          content = rehydrator.rehydrate
          problems.merge!(rehydrator.problems)
        end

        [content, problems]
      end

      # Process alignment entries and build result using OutputBuilder
      #
      # @param alignment [Array<Hash>] Alignment entries
      # @return [Array] [output_builder, stats, frozen_blocks, conflicts]
      def process_alignment(alignment)
        builder = OutputBuilder.new
        frozen_blocks = []
        conflicts = []
        stats = {nodes_added: 0, nodes_removed: 0, nodes_modified: 0}

        alignment.each do |entry|
          case entry[:type]
          when :match
            frozen = process_match_to_builder(entry, builder, stats)
            frozen_blocks << frozen if frozen
          when :template_only
            process_template_only_to_builder(entry, builder, stats)
          when :dest_only
            frozen = process_dest_only_to_builder(entry, builder, stats)
            frozen_blocks << frozen if frozen
          end
        end

        [builder, stats, frozen_blocks, conflicts]
      end

      # Process a matched node pair, adding to OutputBuilder
      #
      # @param entry [Hash] Alignment entry
      # @param builder [OutputBuilder] Output builder to add to
      # @param stats [Hash] Statistics hash to update
      # @return [Hash, nil] Frozen block info if applicable
      def process_match_to_builder(entry, builder, stats)
        template_node = apply_node_typing(entry[:template_node])
        dest_node = apply_node_typing(entry[:dest_node])

        # Try inner-merge for code blocks first
        if @code_block_merger && code_block_node?(template_node) && code_block_node?(dest_node)
          inner_result = try_inner_merge_code_block_to_builder(template_node, dest_node, builder, stats)
          return nil if inner_result
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

        case resolution[:source]
        when :template
          stats[:nodes_modified] += 1 if resolution[:decision] != :identical
          builder.add_node_source(raw_template_node, @template_analysis)
        when :destination
          if raw_dest_node.respond_to?(:freeze_node?) && raw_dest_node.freeze_node?
            frozen_info = {
              start_line: raw_dest_node.start_line,
              end_line: raw_dest_node.end_line,
              reason: raw_dest_node.reason,
            }
          end
          builder.add_node_source(raw_dest_node, @dest_analysis)
        end

        frozen_info
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

      # Try to inner-merge two code block nodes, adding to OutputBuilder
      #
      # @param template_node [Object] Template code block
      # @param dest_node [Object] Destination code block
      # @param builder [OutputBuilder] Output builder to add to
      # @param stats [Hash] Statistics hash to update
      # @return [Boolean] true if merged, false to fall back to standard resolution
      def try_inner_merge_code_block_to_builder(template_node, dest_node, builder, stats)
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
          builder.add_raw(result[:content])
          true
        else
          DebugLogger.debug("Inner-merge skipped", {reason: result[:reason]})
          false # Fall back to standard resolution
        end
      end

      # Try to inner-merge two code block nodes.
      #
      # @deprecated Use try_inner_merge_code_block_to_builder instead
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

      # Process a template-only node, adding to OutputBuilder
      #
      # @param entry [Hash] Alignment entry
      # @param builder [OutputBuilder] Output builder to add to
      # @param stats [Hash] Statistics hash to update
      # @return [void]
      def process_template_only_to_builder(entry, builder, stats)
        return unless should_add_template_only_node?(entry)

        stats[:nodes_added] += 1
        builder.add_node_source(entry[:template_node], @template_analysis)
      end

      # Determine if a template-only node should be added.
      #
      # Gap lines (blank lines/whitespace) represent formatting. Document-trailing gap lines
      # (at the very end with no more content after them) follow preference. Other gap lines
      # Determine if a template-only node should be added.
      #
      # Gap lines (blank lines) and all other nodes follow the add_template_only_nodes setting.
      # When false (default), template-only content is skipped.
      # When true, all template-only content including gap lines is included.
      #
      # @param entry [Hash] Alignment entry with :template_node and :signature
      # @return [Boolean] true if the node should be added
      def should_add_template_only_node?(entry)
        node = entry[:template_node]

        case @add_template_only_nodes
        when false, nil
          false
        when true
          true
        else
          # Callable filter
          if @add_template_only_nodes.respond_to?(:call)
            @add_template_only_nodes.call(node, entry)
          else
            true
          end
        end
      end

      # Process a destination-only node, adding to OutputBuilder.
      #
      # All dest-only nodes are included, including gap lines (formatting).
      #
      # @param entry [Hash] Alignment entry
      # @param builder [OutputBuilder] Output builder to add to
      # @param stats [Hash] Statistics hash to update
      # @return [Hash, nil] Frozen block info if applicable
      def process_dest_only_to_builder(entry, builder, stats)
        node = entry[:dest_node]


        frozen_info = nil

        if node.respond_to?(:freeze_node?) && node.freeze_node?
          frozen_info = {
            start_line: node.start_line,
            end_line: node.end_line,
            reason: node.reason,
          }
        end

        builder.add_node_source(node, @dest_analysis)
        frozen_info
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

      # Check if a gap line is document-trailing (no more content after it).
      #
      # A gap line is document-trailing if there are no more content nodes after it
      # in the statements list. We check all siblings after this gap line - if they're
      # all gap lines (no content), then this is document-trailing.
      #
      # @param gap_line [GapLineNode] The gap line to check
      # @param analysis [FileAnalysisBase] The analysis containing the gap line
      # @return [Boolean] true if the gap line is document-trailing
      def gap_line_is_document_trailing?(gap_line, analysis)
        # Find this gap line's index in the statements
        statements = analysis.statements
        gap_index = statements.index(gap_line)

        DebugLogger.debug("Checking if gap line is document-trailing", {
          gap_line_number: gap_line.line_number,
          gap_index: gap_index,
          total_statements: statements.length
        })

        return true if gap_index.nil? # Shouldn't happen, but treat as trailing if missing

        # Check all statements after this gap line
        # If they're ALL gap lines (no content nodes), then this is document-trailing
        (gap_index + 1...statements.length).each do |i|
          node = statements[i]
          # If we find a non-gap-line node, this gap line is NOT document-trailing
          unless node.is_a?(GapLineNode)
            DebugLogger.debug("Found content after gap line", {
              next_node_index: i,
              next_node_type: node.class.name
            })
            return false
          end
        end

        # All remaining nodes are gap lines (or no nodes after), so this is document-trailing
        DebugLogger.debug("Gap line IS document-trailing - no content after it")
        true
      end
    end
  end
end
