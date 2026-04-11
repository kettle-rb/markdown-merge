# frozen_string_literal: true

module Markdown
  module Merge
    # Aligns Markdown block elements between template and destination files.
    #
    # Uses structural signatures to match headings, paragraphs, lists, code blocks,
    # and other block elements. The alignment is then used by SmartMerger to
    # determine how to combine the files.
    #
    # @example Basic usage
    #   aligner = FileAligner.new(template_analysis, dest_analysis)
    #   alignment = aligner.align
    #   alignment.each do |entry|
    #     case entry[:type]
    #     when :match
    #       # Both files have this element
    #     when :template_only
    #       # Only in template
    #     when :dest_only
    #       # Only in destination
    #     end
    #   end
    #
    # @see FileAnalysisBase
    # @see SmartMergerBase
    class FileAligner < ::Ast::Merge::FileAlignerBase
      # @return [FileAnalysisBase] Template file analysis
      attr_reader :template_analysis

      # @return [FileAnalysisBase] Destination file analysis
      attr_reader :dest_analysis

      # @return [#call, nil] Optional match refiner for fuzzy matching
      attr_reader :match_refiner

      # Initialize a file aligner
      #
      # @param template_analysis [FileAnalysisBase] Analysis of the template file
      # @param dest_analysis [FileAnalysisBase] Analysis of the destination file
      # @param match_refiner [#call, nil] Optional match refiner for fuzzy matching
      def initialize(template_analysis, dest_analysis, match_refiner: nil, **options)
        super(template_analysis, dest_analysis, match_refiner: match_refiner, **options)
      end

      private

      def signature_for(analysis, index)
        signature = analysis.signature_at(index)
        return signature unless list_signature?(signature)

        contextual_list_signature(analysis, index, signature)
      end

      def template_only_entry_context(template_index:, matched_entries_by_template_position:, **)
        _previous_match, next_match = surrounding_matched_entries(matched_entries_by_template_position, template_index)

        {
          anchor_dest_index: next_match&.[](:dest_index),
          anchor_position: next_match ? :before : :append,
        }
      end

      def log_alignment(alignment)
        DebugLogger.debug("Alignment complete", {
          total: alignment.size,
          matches: alignment.count { |e| e[:type] == :match },
          template_only: alignment.count { |e| e[:type] == :template_only },
          dest_only: alignment.count { |e| e[:type] == :dest_only },
        })
      end

      def template_only_sort_key(entry, _dest_size)
        anchor_dest_index = entry[:anchor_dest_index]

        case entry[:anchor_position]
        when :before
          [0, anchor_dest_index, -1, entry[:template_index]]
        else
          [1, entry[:template_index], 0, 0]
        end
      end

      def list_signature?(signature)
        signature.is_a?(Array) && signature.first == :list
      end

      def contextual_list_signature(analysis, index, signature)
        statement = statements_for(analysis)[index]
        list_type = signature[1]
        preceding_context = nearest_list_context_signature(analysis, index)
        first_anchor = first_list_item_anchor(statement, analysis)
        [:list, list_type, preceding_context, first_anchor]
      end

      def heading_signature?(signature)
        signature.is_a?(Array) && signature.first == :heading
      end

      def nearest_list_context_signature(analysis, index)
        (index - 1).downto(0) do |current_index|
          candidate = analysis.signature_at(current_index)
          next unless contextual_predecessor_signature?(candidate)

          return candidate
        end

        nil
      end

      def contextual_predecessor_signature?(signature)
        signature.is_a?(Array) && %i[heading paragraph code_block].include?(signature.first)
      end

      def first_list_item_anchor(statement, analysis)
        raw = Ast::Merge::NodeTyping.unwrap(statement)
        first_item = nil

        raw.each do |child|
          next unless child.respond_to?(:type) && %w[list_item item].include?(child.type.to_s)

          first_item = child
          break
        end

        return "" unless first_item

        text = if analysis && first_item.respond_to?(:source_position) && first_item.source_position
          pos = first_item.source_position
          analysis.source_range(pos[:start_line], pos[:end_line]).to_s
        else
          first_item.respond_to?(:text) ? first_item.text.to_s : ""
        end

        text
          .strip
          .sub(/\A(?:[-*+]|\d+\.)\s+/, "")
          .gsub(/\s+/, " ")
          .downcase
      end
    end
  end
end
