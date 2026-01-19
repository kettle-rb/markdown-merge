# frozen_string_literal: true

module Markdown
  module Merge
    # Builds markdown output from merge operations.
    #
    # Handles markdown-specific concerns like:
    # - Extracting source from original nodes
    # - Reconstructing consumed link reference definitions
    # - Preserving gap lines (blank line spacing)
    # - Automatic structural spacing (blank lines between tables, headings, etc.)
    # - Assembling final merged content
    #
    # Unlike Emitter classes used in JSON/YAML/etc, OutputBuilder focuses on
    # source preservation and reconstruction rather than generation from scratch.
    #
    # @example Basic usage
    #   builder = OutputBuilder.new
    #   builder.add_node_source(node, analysis)
    #   builder.add_link_definition(link_def_node)
    #   builder.add_gap_line(count: 2)
    #   content = builder.to_s
    class OutputBuilder
      # Initialize a new OutputBuilder
      #
      # @param preserve_formatting [Boolean] Whether to preserve original formatting
      # @param auto_spacing [Boolean] Whether to automatically insert blank lines between structural elements
      def initialize(preserve_formatting: true, auto_spacing: true)
        @parts = []
        @preserve_formatting = preserve_formatting
        @auto_spacing = auto_spacing
        @last_node_type = nil  # Track previous node type for spacing decisions
      end

      # Add a node's source content
      #
      # Automatically inserts structural blank lines when transitioning between
      # certain node types (tables, headings, code blocks, etc.) if auto_spacing is enabled.
      #
      # @param node [Object] Node to add (can be parser node, FreezeNode, LinkDefinitionNode, etc.)
      # @param analysis [FileAnalysisBase] Analysis for accessing source
      def add_node_source(node, analysis)
        # Determine node type for spacing decisions
        current_type = MarkdownStructure.node_type(node)

        # Auto-spacing logic:
        # - Skip for gap_line and freeze_block (they handle their own spacing)
        # - Skip if last node was a gap_line (we already have spacing)
        # - Otherwise, check MarkdownStructure.needs_blank_between? which handles
        #   contiguous types (like link_definitions that shouldn't have blanks between them)
        unless [:gap_line, :freeze_block].include?(current_type) ||
               @last_node_type == :gap_line
          if @auto_spacing && @last_node_type && current_type
            if MarkdownStructure.needs_blank_between?(@last_node_type, current_type)
              # Only add spacing if we don't already have adequate blank lines
              # Check the last part to see if it already ends with blank line(s)
              unless @parts.empty? || @parts.last&.end_with?("\n\n")
                add_gap_line(count: 1)
              end
            end
          end
        end

        content = extract_source(node, analysis)
        if content && !content.empty?
          @parts << content
          # Update last node type (track all node types for proper spacing)
          @last_node_type = current_type
        end
      end

      # Add a reconstructed link definition
      #
      # @param node [LinkDefinitionNode] Link definition node
      def add_link_definition(node)
        formatted = LinkDefinitionFormatter.format(node)
        @parts << formatted if formatted && !formatted.empty?
      end

      # Add gap lines (blank line preservation)
      #
      # @param count [Integer] Number of blank lines to add
      def add_gap_line(count: 1)
        @parts << ("\n" * count) if count > 0
      end

      # Add raw text content
      #
      # @param text [String] Raw text to add
      def add_raw(text)
        @parts << text if text && !text.empty?
      end

      # Get final content
      #
      # @return [String] Assembled markdown content
      def to_s
        @parts.join
      end

      # Check if builder has any content
      #
      # @return [Boolean]
      def empty?
        @parts.empty?
      end

      # Clear all content
      def clear
        @parts.clear
      end

      private

      # Extract source content from a node
      #
      # @param node [Object] Node to extract from
      # @param analysis [FileAnalysisBase] Analysis for source access
      # @return [String, nil] Extracted content
      def extract_source(node, analysis)
        case node
        when LinkDefinitionNode
          # Link definitions need reconstruction with trailing newline
          "#{LinkDefinitionFormatter.format(node)}\n"
        when GapLineNode
          # Gap lines are single blank lines
          "\n"
        when Ast::Merge::FreezeNodeBase
          # Freeze blocks have their full text
          node.full_text
        else
          # Regular nodes - extract from source
          extract_parser_node_source(node, analysis)
        end
      end

      # Extract source from a parser-specific node
      #
      # @param node [Object] Parser node
      # @param analysis [FileAnalysisBase] Analysis for source access
      # @return [String, nil] Extracted content
      def extract_parser_node_source(node, analysis)
        # Try source_position method first (used by some nodes)
        if node.respond_to?(:source_position)
          pos = node.source_position
          start_line = pos&.dig(:start_line)
          end_line = pos&.dig(:end_line)

          if start_line && end_line
            return analysis.source_range(start_line, end_line)
          elsif node.respond_to?(:to_commonmark)
            # Fallback to commonmark rendering
            return node.to_commonmark
          end
        end

        # Try direct start_line/end_line attributes
        return nil unless node.respond_to?(:start_line) && node.respond_to?(:end_line)
        return nil unless node.start_line && node.end_line

        if @preserve_formatting
          # Extract original source range
          analysis.source_range(node.start_line, node.end_line)
        else
          # Could implement normalization here if needed
          analysis.source_range(node.start_line, node.end_line)
        end
      end
    end
  end
end

