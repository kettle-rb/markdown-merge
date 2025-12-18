# frozen_string_literal: true

module Markdown
  module Merge
    # Normalizes backend-specific node types to canonical markdown types.
    #
    # Uses Ast::Merge::NodeTyping::Wrapper to wrap nodes with canonical
    # merge_type, allowing portable merge rules across backends.
    #
    # ## Extensibility
    #
    # New backends can be registered at runtime:
    #
    # @example Registering a new backend
    #   NodeTypeNormalizer.register_backend(:tree_sitter_markdown, {
    #     atx_heading: :heading,
    #     setext_heading: :heading,
    #     fenced_code_block: :code_block,
    #     indented_code_block: :code_block,
    #     paragraph: :paragraph,
    #     bullet_list: :list,
    #     ordered_list: :list,
    #     block_quote: :block_quote,
    #     thematic_break: :thematic_break,
    #     html_block: :html_block,
    #     pipe_table: :table,
    #   })
    #
    # ## Canonical Types
    #
    # The following canonical types are used for portable merge rules:
    # - `:heading` - Headers/headings (H1-H6)
    # - `:paragraph` - Text paragraphs
    # - `:code_block` - Fenced or indented code blocks
    # - `:list` - Ordered or unordered lists
    # - `:block_quote` - Block quotations
    # - `:thematic_break` - Horizontal rules
    # - `:html_block` - Raw HTML blocks
    # - `:table` - Tables (GFM extension)
    # - `:footnote_definition` - Footnote definitions
    # - `:custom_block` - Custom/extension blocks
    #
    # @see Ast::Merge::NodeTyping::Wrapper
    module NodeTypeNormalizer
      # Default backend type mappings (extensible via register_backend)
      # Maps backend-specific type symbols to canonical type symbols.
      #
      # Includes both top-level block types and child node types (table rows, cells, etc.)
      # to enable consistent type checking across the entire AST.
      @backend_mappings = {
        commonmarker: {
          # Block types (top-level statements)
          heading: :heading,
          paragraph: :paragraph,
          code_block: :code_block,
          list: :list,
          block_quote: :block_quote,
          thematic_break: :thematic_break,
          html_block: :html_block,
          table: :table,
          footnote_definition: :footnote_definition,
          # Table child types
          table_row: :table_row,
          table_cell: :table_cell,
          table_header: :table_header,  # Some parsers distinguish header rows
          # List child types
          list_item: :list_item,
          item: :list_item,             # Alias
          # Inline types (usually not top-level, but map them anyway)
          text: :text,
          softbreak: :softbreak,
          linebreak: :linebreak,
          code: :code,
          code_inline: :code,           # Alias used by some parsers
          html_inline: :html_inline,
          emph: :emph,
          strong: :strong,
          link: :link,
          image: :image,
        }.freeze,
        markly: {
          # Block types - note different names from commonmarker
          header: :heading,           # markly uses :header, not :heading
          paragraph: :paragraph,
          code_block: :code_block,
          list: :list,
          blockquote: :block_quote,   # markly uses :blockquote, not :block_quote
          hrule: :thematic_break,     # markly uses :hrule, not :thematic_break
          html: :html_block,          # markly uses :html, not :html_block
          table: :table,
          footnote_definition: :footnote_definition,
          custom_block: :custom_block,
          # Table child types
          table_row: :table_row,
          table_cell: :table_cell,
          table_header: :table_header,
          # List child types
          list_item: :list_item,
          item: :list_item,
          # Inline types
          text: :text,
          softbreak: :softbreak,
          linebreak: :linebreak,
          code: :code,
          code_inline: :code,
          html_inline: :html_inline,
          emph: :emph,
          strong: :strong,
          link: :link,
          image: :image,
        }.freeze,
      }

      class << self
        # Register type mappings for a new backend.
        #
        # This allows extending markdown-merge to support additional
        # markdown parsers beyond commonmarker and markly.
        #
        # @param backend [Symbol] Backend identifier (e.g., :tree_sitter_markdown)
        # @param mappings [Hash{Symbol => Symbol}] Backend type → canonical type
        # @return [Hash{Symbol => Symbol}] The frozen mappings
        #
        # @example
        #   NodeTypeNormalizer.register_backend(:my_parser, {
        #     h1: :heading,
        #     h2: :heading,
        #     para: :paragraph,
        #   })
        def register_backend(backend, mappings)
          @backend_mappings[backend] = mappings.freeze
        end

        # Get the canonical type for a backend-specific type.
        #
        # If no mapping exists, returns the original type unchanged.
        # This allows backend-specific types to pass through for
        # backend-specific merge rules.
        #
        # @param backend_type [Symbol] The backend's node type
        # @param backend [Symbol] The backend identifier
        # @return [Symbol] Canonical type (or original if no mapping)
        #
        # @example
        #   NodeTypeNormalizer.canonical_type(:header, :markly)
        #   # => :heading
        #
        #   NodeTypeNormalizer.canonical_type(:heading, :commonmarker)
        #   # => :heading
        #
        #   NodeTypeNormalizer.canonical_type(:unknown_type, :markly)
        #   # => :unknown_type (passthrough)
        def canonical_type(backend_type, backend)
          return backend_type if backend_type.nil?

          # Convert to symbol for lookup since tree_haver returns string types
          type_sym = backend_type.to_sym
          @backend_mappings.dig(backend, type_sym) || type_sym
        end

        # Wrap a node with its canonical type as merge_type.
        #
        # Uses Ast::Merge::NodeTyping.with_merge_type to create a wrapper
        # that delegates all methods to the underlying node while adding
        # a canonical merge_type attribute.
        #
        # @param node [Object] The backend node to wrap
        # @param backend [Symbol] The backend identifier
        # @return [Ast::Merge::NodeTyping::Wrapper] Wrapped node with canonical merge_type
        #
        # @example
        #   # Markly node with type :header becomes wrapped with merge_type :heading
        #   wrapped = NodeTypeNormalizer.wrap(markly_node, :markly)
        #   wrapped.type        # => :header (original)
        #   wrapped.merge_type  # => :heading (canonical)
        #   wrapped.unwrap      # => markly_node (original node)
        def wrap(node, backend)
          canonical = canonical_type(node.type, backend)
          Ast::Merge::NodeTyping.with_merge_type(node, canonical)
        end

        # Get all registered backends.
        #
        # @return [Array<Symbol>] Backend identifiers
        def registered_backends
          @backend_mappings.keys
        end

        # Check if a backend is registered.
        #
        # @param backend [Symbol] Backend identifier
        # @return [Boolean]
        def backend_registered?(backend)
          @backend_mappings.key?(backend)
        end

        # Get the mappings for a specific backend.
        #
        # @param backend [Symbol] Backend identifier
        # @return [Hash{Symbol => Symbol}, nil] The mappings or nil if not registered
        def mappings_for(backend)
          @backend_mappings[backend]
        end

        # Get all canonical types across all backends.
        #
        # @return [Array<Symbol>] Unique canonical type symbols
        def canonical_types
          @backend_mappings.values.flat_map(&:values).uniq
        end
      end
    end
  end
end

