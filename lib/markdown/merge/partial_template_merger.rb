# frozen_string_literal: true

module Markdown
  module Merge
    # Markdown-specific implementation of PartialTemplateMerger.
    #
    # Merges a partial template into a specific section of a destination markdown document.
    # This class extends the parser-agnostic base with markdown-specific logic for:
    # - Heading-level-aware section boundaries
    # - Source-based text extraction to preserve link references and table formatting
    # - Backend-specific parser initialization (Markly, Commonmarker)
    #
    # @example Basic usage
    #   merger = Markdown::Merge::PartialTemplateMerger.new(
    #     template: template_content,
    #     destination: destination_content,
    #     anchor: { type: :heading, text: /Gem Family/ },
    #     backend: :markly
    #   )
    #   result = merger.merge
    #   puts result.content
    #
    # @example With boundary
    #   merger = Markdown::Merge::PartialTemplateMerger.new(
    #     template: template_content,
    #     destination: destination_content,
    #     anchor: { type: :heading, text: /Installation/ },
    #     boundary: { type: :heading },  # Stop at next heading
    #     backend: :markly
    #   )
    #
    class PartialTemplateMerger < Ast::Merge::PartialTemplateMergerBase
      # Re-export Result class from base for convenience
      Result = Ast::Merge::PartialTemplateMergerBase::Result

      class << self
        def default_backend
          :markly
        end

        def file_analysis_class
          FileAnalysis
        end

        def smart_merger_class
          SmartMerger
        end
      end

      # @return [Symbol] Backend to use (:markly, :commonmarker)
      attr_reader :backend

      # Initialize a markdown PartialTemplateMerger.
      #
      # @param template [String] The template content (the section to merge in)
      # @param destination [String] The destination content
      # @param anchor [Hash] Anchor matcher: { type: :heading, text: /pattern/ }
      # @param boundary [Hash, nil] Boundary matcher (defaults to same type as anchor)
      # @param backend [Symbol] Backend to use (:markly, :commonmarker)
      # @param preference [Symbol, Hash] Which content wins (:template, :destination, or per-type hash)
      # @param add_missing [Boolean, Proc] Whether to add template nodes not in destination
      # @param when_missing [Symbol] What to do if section not found (:skip, :append, :prepend)
      # @param replace_mode [Boolean] If true, template replaces section entirely (no merge)
      # @param signature_generator [Proc, nil] Custom signature generator for SmartMerger
      # @param node_typing [Hash, nil] Node typing configuration for per-type preferences
      # @param match_refiner [Object, nil] Match refiner for fuzzy matching (e.g., ContentMatchRefiner)
      # @param normalize_whitespace [Boolean] If true, collapse excessive blank lines. Default: false
      # @param rehydrate_link_references [Boolean] If true, convert inline links to reference style. Default: false
      def initialize(
        template:,
        destination:,
        anchor:,
        boundary: nil,
        backend: self.class.default_backend,
        preference: :template,
        add_missing: true,
        when_missing: :skip,
        replace_mode: false,
        signature_generator: nil,
        node_typing: nil,
        match_refiner: nil,
        normalize_whitespace: false,
        rehydrate_link_references: false
      )
        validate_backend!(backend)
        @backend = backend
        @normalize_whitespace = normalize_whitespace
        @rehydrate_link_references = rehydrate_link_references
        super(
          template: template,
          destination: destination,
          anchor: anchor,
          boundary: boundary,
          preference: preference,
          add_missing: add_missing,
          when_missing: when_missing,
          replace_mode: replace_mode,
          signature_generator: signature_generator,
          node_typing: node_typing,
          match_refiner: match_refiner,
        )
      end

      # Perform the partial template merge with post-processing.
      #
      # @return [Result] The merge result
      def merge
        result = super

        # Apply post-processing if enabled
        if result.changed && (@normalize_whitespace || @rehydrate_link_references)
          content = result.content
          problems = DocumentProblems.new

          if @normalize_whitespace
            normalizer = WhitespaceNormalizer.new(content)
            content = normalizer.normalize
            problems.merge!(normalizer.problems)
          end

          if @rehydrate_link_references
            rehydrator = LinkReferenceRehydrator.new(content)
            content = rehydrator.rehydrate
            problems.merge!(rehydrator.problems)
          end

          # Return new result with transformed content and problems
          Result.new(
            content: content,
            has_section: result.has_section,
            changed: result.changed,
            stats: result.stats.merge(problems: problems.all),
            injection_point: result.injection_point,
            message: result.message,
          )
        else
          result
        end
      end

      protected

      def merge_section_content(section_content)
        return super unless replace_mode?

        template_analysis = create_analysis(template)
        preserved_comment_insertions = standalone_comment_insertions(create_analysis(section_content))

        return [template, {mode: :replace}] if preserved_comment_insertions.empty?
        return [template, {mode: :replace}] unless standalone_comment_insertions(template_analysis).empty?

        [
          render_template_with_comment_insertions(template_analysis, preserved_comment_insertions),
          {
            mode: :replace,
            preserved_destination_comment_fragments: preserved_comment_insertions.values.sum(&:size),
          },
        ]
      end

      # Validate the backend parameter.
      #
      # @param backend [Symbol] The backend to validate
      # @raise [ArgumentError] If backend is not supported
      def validate_backend!(backend)
        valid_backends = [:auto, :markly, :commonmarker]
        return if valid_backends.include?(backend.to_sym)

        raise ArgumentError, "Unknown backend: #{backend}. Supported: #{valid_backends.join(", ")}"
      end

      # Create a FileAnalysis for the given content.
      #
      # @param content [String] The content to analyze
      # @return [FileAnalysis] A FileAnalysis instance
      def create_analysis(content)
        self.class.file_analysis_class.new(content, backend: backend)
      end

      # Create a SmartMerger for merging the section.
      #
      # @param template_content [String] The template content
      # @param destination_content [String] The destination section content
      # @return [SmartMerger] A SmartMerger instance
      def create_smart_merger(template_content, destination_content)
        # Build options hash, only including non-nil values
        options = {
          preference: preference,
          add_template_only_nodes: add_missing,
          backend: backend,
        }

        # Use custom signature generator if provided, otherwise use position-based
        # table matching to ensure tables with different structures still match
        # within a section merge context.
        options[:signature_generator] = signature_generator || build_position_based_signature_generator

        options[:node_typing] = node_typing if node_typing
        options[:match_refiner] = match_refiner if match_refiner

        self.class.smart_merger_class.new(template_content, destination_content, **options)
      end

      # Build a signature generator that uses type-based matching for tables.
      #
      # This ensures that tables within a section are matched by type alone,
      # allowing template tables to replace destination tables regardless of
      # their exact structure (different headers, columns, etc.).
      #
      # In the context of partial template merging, this is the desired behavior:
      # - Sections typically contain one table of each logical role
      # - Template table should replace the destination table
      # - Different table structures should still match by ordinal position
      #
      # The algorithm uses a stateless approach that assigns the same signature
      # to all tables. Since PartialTemplateMerger merges **one section at a time**,
      # each section typically has few tables, and the first table in template
      # will match and replace the first table in destination.
      #
      # For more precise control over multiple tables within a section, provide
      # a custom signature_generator.
      #
      # @return [Proc] A signature generator proc
      def build_position_based_signature_generator
        # Simple stateless approach: all tables get the same base signature.
        # When preference is :template, this causes template table to replace
        # destination table, which is the desired behavior.
        #
        # NOTE: If a section has multiple tables, they will ALL match each other,
        # potentially causing unexpected behavior. For such cases, users should
        # provide a custom signature_generator.
        lambda do |node|
          type_str = node.type.to_s
          if type_str == "table"
            # All tables within a section merge get the same signature.
            # This ensures template table replaces destination table.
            [:table, :section_table]
          else
            # Return node for default signature computation
            node
          end
        end
      end

      # Find where the section ends.
      #
      # For headings, finds the next heading of same or higher level.
      # For other node types, finds the next node of the same type.
      #
      # NOTE: For headings, we ALWAYS use heading-level-aware logic, ignoring
      # any boundary from InjectionPointFinder. This is because InjectionPointFinder
      # uses tree_depth for boundary detection, but in Markdown all headings are
      # siblings at the same tree depth regardless of their level (H2, H3, H4 etc).
      # Heading level semantics require comparing the actual heading level numbers.
      #
      # @param statements [Array<Navigable::Statement>] All statements
      # @param injection_point [Navigable::InjectionPoint] The injection point
      # @return [Integer] Index of the last statement in the section
      def find_section_end(statements, injection_point)
        anchor = injection_point.anchor
        anchor_type = anchor.type

        # For headings, ALWAYS use heading-level-aware logic
        # This overrides any boundary from InjectionPointFinder because tree_depth
        # doesn't reflect heading level semantics in Markdown
        if heading_type?(anchor_type)
          anchor_level = get_heading_level(anchor)

          ((anchor.index + 1)...statements.length).each do |idx|
            stmt = statements[idx]
            if heading_type?(stmt.type)
              stmt_level = get_heading_level(stmt)
              if stmt_level && anchor_level && stmt_level <= anchor_level
                # Found next heading of same or higher level - section ends before it
                return idx - 1
              end
            end
          end

          # No boundary heading found - section extends to end of document
          return statements.length - 1
        end

        # For non-headings, use boundary if specified and found
        if injection_point.boundary
          return injection_point.boundary.index - 1
        end

        # Otherwise, find next node of same type
        ((anchor.index + 1)...statements.length).each do |idx|
          stmt = statements[idx]
          if stmt.type == anchor_type
            return idx - 1
          end
        end

        # Section extends to end of document
        statements.length - 1
      end

      # Convert a node to its source text.
      #
      # Prefers source-based extraction to preserve original formatting
      # (link references, table padding, etc.). Falls back to to_commonmark.
      #
      # @param node [Object] The node to convert
      # @param analysis [FileAnalysis, nil] The analysis object for source lookup
      # @return [String] The source text
      def node_to_text(node, analysis = nil)
        # Unwrap if needed
        inner = node
        while inner.respond_to?(:inner_node) && inner.inner_node != inner
          inner = inner.inner_node
        end

        # Prefer source-based extraction to preserve original formatting
        # (link references, table padding, etc.)
        if analysis&.respond_to?(:source_range)
          pos = inner.source_position if inner.respond_to?(:source_position)
          if pos
            start_line = pos[:start_line]
            end_line = pos[:end_line]
            if start_line && end_line && start_line > 0
              source_text = analysis.source_range(start_line, end_line)
              # source_range already adds trailing newlines, don't add another
              return source_text unless source_text.empty?
            end
          end
        end

        # Fallback to to_commonmark (for nodes without source position)
        if inner.respond_to?(:to_commonmark)
          inner.to_commonmark.to_s
        elsif inner.respond_to?(:to_s)
          inner.to_s
        else
          ""
        end
      end

      private

      def standalone_comment_insertions(analysis)
        insertions = Hash.new { |hash, key| hash[key] = [] }
        structural_index = 0

        analysis.statements.each do |statement|
          if standalone_comment_statement?(statement, analysis)
            insertions[structural_index] << node_to_text(statement, analysis).sub(/\n+\z/, "")
          elsif structural_statement?(statement, analysis)
            structural_index += 1
          end
        end

        insertions.reject { |_index, fragments| fragments.empty? }
      end

      def render_template_with_comment_insertions(template_analysis, insertions)
        result = +""
        structural_index = 0
        statements = template_analysis.statements
        index = 0

        while index < statements.length
          statement = statements[index]

          if gap_line_statement?(statement) && insertions.key?(structural_index) && next_structural_statement_after?(statements, index, template_analysis)
            index += 1 while index < statements.length && gap_line_statement?(statements[index])
            result = append_comment_fragments(result, insertions.delete(structural_index))
            next
          end

          result << node_to_text(statement, template_analysis)
          structural_index += 1 if structural_statement?(statement, template_analysis)
          index += 1
        end

        if insertions.key?(structural_index)
          result = append_comment_fragments(result, insertions.delete(structural_index))
        end

        result
      end

      def append_comment_fragments(content, fragments)
        result = content.sub(/\n+\z/, "\n")

        unless result.empty?
          if result.end_with?("\n")
            result << "\n" unless result.end_with?("\n\n")
          else
            result << "\n\n"
          end
        end

        result << fragments.join("\n\n")
        result << "\n"
        result << "\n" unless result.end_with?("\n\n")
        result
      end

      def next_structural_statement_after?(statements, start_index, analysis)
        statements[(start_index + 1)..]&.any? { |statement| structural_statement?(statement, analysis) }
      end

      def structural_statement?(statement, analysis)
        !gap_line_statement?(statement) && !standalone_comment_statement?(statement, analysis)
      end

      def gap_line_statement?(statement)
        statement.respond_to?(:merge_type) && statement.merge_type == :gap_line
      end

      def standalone_comment_statement?(statement, analysis)
        return false unless statement.respond_to?(:merge_type) && statement.merge_type == :html_block

        node_to_text(statement, analysis).strip.match?(CommentTracker::STANDALONE_HTML_COMMENT_REGEX)
      end

      # Check if a type represents a heading node.
      #
      # @param type [Symbol, String] The node type
      # @return [Boolean] true if this is a heading type
      def heading_type?(type)
        type.to_s == "heading" || type == :heading || type == :header
      end

      # Get the heading level from a statement.
      #
      # @param stmt [NavigableStatement] The statement
      # @return [Integer, nil] The heading level (1-6) or nil
      def get_heading_level(stmt)
        inner = stmt.respond_to?(:unwrapped_node) ? stmt.unwrapped_node : stmt.node

        if inner.respond_to?(:header_level)
          inner.header_level
        elsif inner.respond_to?(:level)
          inner.level
        end
      end
    end
  end
end
