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
    class FileAligner
      include ::Ast::Merge::TrailingGroups::AlignmentSort
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
      def initialize(template_analysis, dest_analysis, match_refiner: nil)
        @template_analysis = template_analysis
        @dest_analysis = dest_analysis
        @match_refiner = match_refiner
      end

      # Perform alignment between template and destination statements
      #
      # @return [Array<Hash>] Alignment entries with type, indices, and nodes
      def align
        template_statements = @template_analysis.statements
        dest_statements = @dest_analysis.statements

        # Build signature maps
        template_by_sig = build_signature_map(template_statements, @template_analysis)
        dest_by_sig = build_signature_map(dest_statements, @dest_analysis)

        # Track which indices have been matched
        matched_template = Set.new
        matched_dest = Set.new
        alignment = []

        # First pass: find matches by signature
        template_by_sig.each do |sig, template_indices|
          next unless dest_by_sig.key?(sig)

          dest_indices = dest_by_sig[sig]

          # Match indices pairwise (first template with first dest, etc.)
          template_indices.zip(dest_indices).each do |t_idx, d_idx|
            next unless t_idx && d_idx

            alignment << {
              type: :match,
              template_index: t_idx,
              dest_index: d_idx,
              signature: sig,
              template_node: template_statements[t_idx],
              dest_node: dest_statements[d_idx],
            }

            matched_template << t_idx
            matched_dest << d_idx
          end
        end

        # Apply match refiner to find additional fuzzy matches
        if @match_refiner
          unmatched_t_nodes = template_statements.each_with_index.reject { |_, i| matched_template.include?(i) }.map(&:first)
          unmatched_d_nodes = dest_statements.each_with_index.reject { |_, i| matched_dest.include?(i) }.map(&:first)

          unless unmatched_t_nodes.empty? || unmatched_d_nodes.empty?
            refiner_matches = @match_refiner.call(unmatched_t_nodes, unmatched_d_nodes, {
              template_analysis: @template_analysis,
              dest_analysis: @dest_analysis,
            })

            refiner_matches.each do |match|
              t_idx = template_statements.index(match.template_node)
              d_idx = dest_statements.index(match.dest_node)

              next unless t_idx && d_idx
              next if matched_template.include?(t_idx) || matched_dest.include?(d_idx)

              alignment << {
                type: :match,
                template_index: t_idx,
                dest_index: d_idx,
                signature: [:refined_match, match.score],
                template_node: match.template_node,
                dest_node: match.dest_node,
              }

              matched_template << t_idx
              matched_dest << d_idx
            end
          end
        end

        matched_entries_by_template_position = alignment
          .select { |entry| entry[:type] == :match }
          .sort_by { |entry| [entry[:template_index], entry[:dest_index]] }

        # Second pass: add template-only entries
        template_statements.each_with_index do |stmt, idx|
          next if matched_template.include?(idx)

          _previous_match, next_match = surrounding_matched_entries(matched_entries_by_template_position, idx)

          alignment << {
            type: :template_only,
            template_index: idx,
            dest_index: nil,
            signature: @template_analysis.signature_at(idx),
            template_node: stmt,
            dest_node: nil,
            anchor_dest_index: next_match&.[](:dest_index),
            anchor_position: next_match ? :before : :append,
          }
        end

        # Third pass: add dest-only entries
        dest_statements.each_with_index do |stmt, idx|
          next if matched_dest.include?(idx)

          alignment << {
            type: :dest_only,
            template_index: nil,
            dest_index: idx,
            signature: @dest_analysis.signature_at(idx),
            template_node: nil,
            dest_node: stmt,
          }
        end

        # Sort by appearance order (destination order for matched/dest-only, then template-only)
        sort_alignment_with_template_position(alignment, alignment.count { |e| e[:type] != :template_only })

        DebugLogger.debug("Alignment complete", {
          total: alignment.size,
          matches: alignment.count { |e| e[:type] == :match },
          template_only: alignment.count { |e| e[:type] == :template_only },
          dest_only: alignment.count { |e| e[:type] == :dest_only },
        })

        alignment
      end

      private

      # Override: 2-tuple keys for markdown — simpler than the default 4-tuple
      def match_sort_key(entry)
        [0, entry[:dest_index], 0, entry[:template_index] || 0]
      end

      def dest_only_sort_key(entry)
        [0, entry[:dest_index], 1, 0]
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

      # Build a map from signatures to statement indices
      #
      # @param statements [Array] List of statements
      # @param analysis [FileAnalysisBase] Analysis for signature generation
      # @return [Hash<Array, Array<Integer>>] Map from signature to indices
      def build_signature_map(statements, analysis)
        map = Hash.new { |h, k| h[k] = [] }

        statements.each_with_index do |_stmt, idx|
          sig = analysis.signature_at(idx)
          # :nocov: defensive - signature_at always returns a value for valid indices
          map[sig] << idx if sig
          # :nocov:
        end

        map
      end

      def surrounding_matched_entries(matched_entries, template_index)
        previous_match = nil
        next_match = nil

        matched_entries.each do |entry|
          if entry[:template_index] < template_index
            previous_match = entry
            next
          end

          if entry[:template_index] > template_index
            next_match = entry
            break
          end
        end

        [previous_match, next_match]
      end
    end
  end
end
