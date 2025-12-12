# frozen_string_literal: true

require "digest"

module Markdown
  module Merge
    # Base class for file analysis for Markdown files.
    #
    # Parses Markdown source code and extracts:
    # - Top-level block elements (headings, paragraphs, lists, code blocks, etc.)
    # - Freeze blocks marked with HTML comments
    # - Structural signatures for matching elements between files
    #
    # Subclasses must implement parser-specific methods:
    # - #parse_document(source) - Parse source and return document node
    # - #next_sibling(node) - Get next sibling of a node
    # - #compute_parser_signature(node) - Compute signature for parser-specific nodes
    # - #node_type_name(type) - Map canonical type names if needed
    #
    # Freeze blocks are marked with HTML comments:
    #   <!-- markdown-merge:freeze -->
    #   ... content to preserve ...
    #   <!-- markdown-merge:unfreeze -->
    #
    # @example Basic usage (subclass)
    #   class FileAnalysis < Markdown::Merge::FileAnalysisBase
    #     def parse_document(source)
    #       Markly.parse(source, flags: @flags)
    #     end
    #
    #     def next_sibling(node)
    #       node.next
    #     end
    #   end
    #
    # @abstract Subclass and implement parser-specific methods
    class FileAnalysisBase
      include Ast::Merge::FileAnalyzable

      # Default freeze token for identifying freeze blocks
      # @return [String]
      DEFAULT_FREEZE_TOKEN = "markdown-merge"

      # @return [Object] The root document node
      attr_reader :document

      # Note: :source is inherited from Ast::Merge::FileAnalyzable

      # Initialize file analysis
      #
      # @param source [String] Markdown source code to analyze
      # @param freeze_token [String] Token for freeze block markers
      # @param signature_generator [Proc, nil] Custom signature generator
      def initialize(source, freeze_token: DEFAULT_FREEZE_TOKEN, signature_generator: nil, **parser_options)
        @source = source
        @lines = source.split("\n", -1)
        @freeze_token = freeze_token
        @signature_generator = signature_generator
        @parser_options = parser_options

        # Parse the Markdown source - subclasses implement this
        @document = DebugLogger.time("FileAnalysisBase#parse") do
          parse_document(source)
        end

        # Extract and integrate all nodes including freeze blocks
        @statements = extract_and_integrate_all_nodes

        DebugLogger.debug("FileAnalysisBase initialized", {
          signature_generator: signature_generator ? "custom" : "default",
          document_children: count_children(@document),
          statements_count: @statements.size,
          freeze_blocks: freeze_blocks.size,
        })
      end

      # Parse the source document.
      #
      # @abstract Subclasses must implement this method
      # @param source [String] Markdown source to parse
      # @return [Object] Root document node
      def parse_document(source)
        raise NotImplementedError, "#{self.class} must implement #parse_document"
      end

      # Get the next sibling of a node.
      #
      # Different parsers use different methods (next vs next_sibling).
      #
      # @abstract Subclasses must implement this method
      # @param node [Object] Current node
      # @return [Object, nil] Next sibling or nil
      def next_sibling(node)
        raise NotImplementedError, "#{self.class} must implement #next_sibling"
      end

      # Check if parse was successful
      # @return [Boolean]
      def valid?
        !@document.nil?
      end

      # Get all statements (block nodes outside freeze blocks + FreezeNode instances)
      # @return [Array<Object, FreezeNode>]
      attr_reader :statements

      # Compute default signature for a node
      # @param node [Object] The parser node or FreezeNode
      # @return [Array, nil] Signature array
      def compute_node_signature(node)
        case node
        when Ast::Merge::FreezeNodeBase
          node.signature
        else
          compute_parser_signature(node)
        end
      end

      # Override to detect parser nodes for signature generator fallthrough
      # @param value [Object] The value to check
      # @return [Boolean] true if this is a fallthrough node
      def fallthrough_node?(value)
        value.is_a?(Ast::Merge::FreezeNodeBase) || parser_node?(value) || super
      end

      # Check if value is a parser-specific node.
      #
      # @param value [Object] Value to check
      # @return [Boolean] true if this is a parser node
      def parser_node?(value)
        # Default: check if it responds to :type (common for AST nodes)
        value.respond_to?(:type)
      end

      # Compute signature for a parser-specific node.
      #
      # @abstract Subclasses should override this method
      # @param node [Object] The parser node
      # @return [Array, nil] Signature array
      def compute_parser_signature(node)
        type = node.type
        case type
        when :heading, :header
          # Content-based: Match headings by level and text content
          [:heading, node.header_level, extract_text_content(node)]
        when :paragraph
          # Content-based: Match paragraphs by content hash (first 32 chars of digest)
          text = extract_text_content(node)
          [:paragraph, Digest::SHA256.hexdigest(text)[0, 32]]
        when :code_block
          # Content-based: Match code blocks by fence info and content hash
          content = safe_string_content(node)
          fence_info = node.respond_to?(:fence_info) ? node.fence_info : nil
          [:code_block, fence_info, Digest::SHA256.hexdigest(content)[0, 16]]
        when :list
          # Structure-based: Match lists by type and item count (content may differ)
          list_type = node.respond_to?(:list_type) ? node.list_type : nil
          [:list, list_type, count_children(node)]
        when :block_quote, :blockquote
          # Content-based: Match block quotes by content hash
          text = extract_text_content(node)
          [:blockquote, Digest::SHA256.hexdigest(text)[0, 16]]
        when :thematic_break, :hrule
          # Structure-based: All thematic breaks are equivalent
          [:hrule]
        when :html_block, :html
          # Content-based: Match HTML blocks by content hash
          content = safe_string_content(node)
          [:html, Digest::SHA256.hexdigest(content)[0, 16]]
        when :table
          # Content-based: Match tables by structure and header content
          header_content = extract_table_header_content(node)
          [:table, count_children(node), Digest::SHA256.hexdigest(header_content)[0, 16]]
        when :footnote_definition
          # Name/label-based: Match footnotes by name or label
          label = node.respond_to?(:name) ? node.name : safe_string_content(node)
          [:footnote_definition, label]
        when :custom_block
          # Content-based: Match custom blocks by content hash
          text = extract_text_content(node)
          [:custom_block, Digest::SHA256.hexdigest(text)[0, 16]]
        else
          # Unknown type - use type and position
          pos = node.source_position
          [:unknown, type, pos&.dig(:start_line)]
        end
      end

      # Safely get string content from a node
      # @param node [Object] The node
      # @return [String] String content or empty string
      def safe_string_content(node)
        node.string_content.to_s
      rescue TypeError
        # Some node types don't support string_content
        extract_text_content(node)
      end

      # Extract all text content from a node and its children
      # @param node [Object] The node
      # @return [String] Concatenated text content
      def extract_text_content(node)
        text_parts = []
        node.walk do |child|
          if child.type == :text
            text_parts << child.string_content.to_s
          elsif child.type == :code
            text_parts << child.string_content.to_s
          end
        end
        text_parts.join
      end

      # Get the source text for a range of lines
      # @param start_line [Integer] Start line (1-indexed)
      # @param end_line [Integer] End line (1-indexed)
      # @return [String] Source text
      def source_range(start_line, end_line)
        return "" if start_line < 1 || end_line < start_line

        @lines[(start_line - 1)..(end_line - 1)].join("\n")
      end

      protected

      # Extract header content from a table node
      # @param node [Object] The table node
      # @return [String] Header row content
      def extract_table_header_content(node)
        # First row of a table is typically the header
        first_row = node.first_child
        return "" unless first_row

        extract_text_content(first_row)
      end

      # Count children of a node
      # @param node [Object] The node
      # @return [Integer] Child count
      def count_children(node)
        count = 0
        child = node.first_child
        while child
          count += 1
          child = next_sibling(child)
        end
        count
      end

      private

      # Extract all nodes and integrate freeze blocks
      # @return [Array<Object>] Integrated list of nodes and freeze blocks
      def extract_and_integrate_all_nodes
        freeze_markers = find_freeze_markers
        return collect_top_level_nodes if freeze_markers.empty?

        # Build freeze blocks from markers
        freeze_blocks = build_freeze_blocks(freeze_markers)
        return collect_top_level_nodes if freeze_blocks.empty?

        # Integrate nodes with freeze blocks
        integrate_nodes_with_freeze_blocks(freeze_blocks)
      end

      # Collect top-level nodes from document
      # @return [Array<Object>]
      def collect_top_level_nodes
        nodes = []
        child = @document.first_child
        while child
          nodes << child
          child = next_sibling(child)
        end
        nodes
      end

      # Find freeze markers in source
      # @return [Array<Hash>] Marker information
      def find_freeze_markers
        markers = []
        pattern = Ast::Merge::FreezeNodeBase.pattern_for(:html_comment, @freeze_token)

        @lines.each_with_index do |line, index|
          match = line.match(pattern)
          next unless match

          marker_type = match[1] # "freeze" or "unfreeze"
          reason = match[2]      # optional reason

          markers << {
            line: index + 1,
            type: marker_type.to_sym,
            text: line,
            reason: reason,
          }
        end

        DebugLogger.debug("Found freeze markers", {count: markers.size})
        markers
      end

      # Build freeze blocks from markers
      # @param markers [Array<Hash>] Marker information
      # @return [Array<FreezeNode>] Freeze blocks
      def build_freeze_blocks(markers)
        blocks = []
        stack = []

        markers.each do |marker|
          case marker[:type]
          when :freeze
            stack.push(marker)
          when :unfreeze
            if stack.any?
              start_marker = stack.pop
              blocks << create_freeze_block(start_marker, marker)
            else
              DebugLogger.debug("Unmatched unfreeze marker", {line: marker[:line]})
            end
          end
        end

        # Warn about unclosed freeze blocks
        stack.each do |unclosed|
          DebugLogger.debug("Unclosed freeze marker", {line: unclosed[:line]})
        end

        blocks.sort_by(&:start_line)
      end

      # Create a freeze block from start and end markers.
      #
      # Subclasses may override to provide parser-specific FreezeNode subclass.
      #
      # @param start_marker [Hash] Start marker info
      # @param end_marker [Hash] End marker info
      # @return [FreezeNode]
      def create_freeze_block(start_marker, end_marker)
        start_line = start_marker[:line]
        end_line = end_marker[:line]

        # Content is between the markers (exclusive)
        content_start = start_line + 1
        content_end = end_line - 1

        content = if content_start <= content_end
          source_range(content_start, content_end)
        else
          ""
        end

        # Parse the content to get nodes (for nested analysis)
        parsed_nodes = parse_freeze_block_content(content)

        freeze_node_class.new(
          start_line: start_line,
          end_line: end_line,
          content: content,
          start_marker: start_marker[:text],
          end_marker: end_marker[:text],
          nodes: parsed_nodes,
          reason: start_marker[:reason],
        )
      end

      # Returns the FreezeNode class to use.
      #
      # Subclasses should override this to return their own FreezeNode class.
      #
      # @return [Class] FreezeNode class
      def freeze_node_class
        Ast::Merge::FreezeNodeBase
      end

      # Parse content within a freeze block.
      #
      # Subclasses should override this to use their parser.
      #
      # @param content [String] Content to parse
      # @return [Array<Object>] Parsed nodes
      def parse_freeze_block_content(content)
        return [] if content.empty?

        begin
          content_doc = parse_document(content)
          nodes = []
          child = content_doc.first_child
          while child
            nodes << child
            child = next_sibling(child)
          end
          nodes
        rescue StandardError => e
          # :nocov: defensive - parser rarely fails on valid markdown subset
          DebugLogger.debug("Failed to parse freeze block content", {error: e.message})
          []
          # :nocov:
        end
      end

      # Integrate nodes with freeze blocks
      # @param freeze_blocks [Array<FreezeNode>] Freeze blocks
      # @return [Array<Object>] Integrated list
      def integrate_nodes_with_freeze_blocks(freeze_blocks)
        result = []
        freeze_index = 0
        current_freeze = freeze_blocks[freeze_index]

        top_level_nodes = collect_top_level_nodes

        top_level_nodes.each do |node|
          node_start = node.source_position&.dig(:start_line) || 0
          node_end = node.source_position&.dig(:end_line) || node_start

          # Add any freeze blocks that come before this node
          while current_freeze && current_freeze.start_line < node_start
            result << current_freeze
            freeze_index += 1
            current_freeze = freeze_blocks[freeze_index]
          end

          # Skip nodes that are inside a freeze block
          inside_freeze = freeze_blocks.any? do |fb|
            node_start >= fb.start_line && node_end <= fb.end_line
          end

          result << node unless inside_freeze
        end

        # Add remaining freeze blocks
        while freeze_index < freeze_blocks.size
          result << freeze_blocks[freeze_index]
          freeze_index += 1
        end

        result
      end
    end
  end
end
