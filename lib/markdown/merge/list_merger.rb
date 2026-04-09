# frozen_string_literal: true

module Markdown
  module Merge
    # Merges two Markdown list nodes at the item level.
    #
    # When a template list and destination list are matched (e.g., via fuzzy matching
    # or a shared content fingerprint), this merger produces a result that is smarter
    # than simply picking one whole list as the winner:
    #
    #   - Items that appear in both lists are resolved by preference (template or dest).
    #   - Items that only appear in the destination are kept (project customisations).
    #   - Items that only appear in the template are added (new canonical steps).
    #
    # Item matching uses significant-token Jaccard overlap so minor wording differences
    # (e.g., "Commit changes" vs "Commit your changes") still produce a match.
    #
    # The merged list is emitted as plain Markdown text (ordered `1. …` lines) and
    # passed to the caller via `add_raw` on the OutputBuilder.
    #
    # @example Basic usage
    #   merger = ListMerger.new
    #   result = merger.merge_lists(template_node, dest_node,
    #                               preference: :template,
    #                               add_template_only_nodes: true,
    #                               template_analysis: t_analysis,
    #                               dest_analysis: d_analysis)
    #   if result[:merged]
    #     builder.add_raw(result[:content])
    #   end
    #
    # @see SmartMergerBase#try_inner_merge_list_to_builder
    class ListMerger
      include Ast::Merge::JaccardSimilarity

      # Minimum Jaccard token overlap to consider two list items as matching.
      ITEM_MATCH_THRESHOLD = 0.35

      # Merge two list nodes.
      #
      # @param template_node [Object] Template list node (tree_haver / Markly node)
      # @param dest_node [Object] Destination list node
      # @param preference [Symbol] :template or :destination — which wins for matched items
      # @param add_template_only_nodes [Boolean] Whether to append template-only items
      # @param template_analysis [FileAnalysisBase] Template file analysis (for source text)
      # @param dest_analysis [FileAnalysisBase] Destination file analysis (for source text)
      # @return [Hash] { merged: Boolean, content: String } or { merged: false, reason: String }
      def merge_lists(template_node, dest_node,
        preference:,
        add_template_only_nodes: true,
        template_analysis: nil,
        dest_analysis: nil)
        t_items = extract_items(template_node)
        d_items = extract_items(dest_node)

        return not_merged("empty list") if t_items.empty? && d_items.empty?

        alignment = align_items(t_items, d_items)
        lines = emit_lines(
          alignment,
          preference: preference,
          add_template_only: add_template_only_nodes,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
        )
        return not_merged("no lines emitted") if lines.empty?

        {merged: true, content: lines.join("\n") + "\n", stats: {decision: :merged}}
      end

      private

      # --- item extraction ---

      def extract_items(list_node)
        raw = list_node.respond_to?(:__getobj__) ? list_node.__getobj__ : list_node
        items = []
        raw.each do |item|
          items << item if item.respond_to?(:type) && item.type == :list_item
        end
        items
      end

      # --- alignment ---

      # Produce an ordered array of alignment entries, each one of:
      #   { type: :match,         template_item: …, dest_item: … }
      #   { type: :dest_only,     dest_item: … }
      #   { type: :template_only, template_item: … }
      def align_items(t_items, d_items)
        t_tokens = t_items.map { |i| item_tokens(i) }
        d_tokens = d_items.map { |i| item_tokens(i) }

        matched_t = Set.new
        matched_d = Set.new
        candidates = []

        t_items.each_with_index do |t_item, ti|
          d_items.each_with_index do |d_item, di|
            score = jaccard(t_tokens[ti], d_tokens[di])
            next if score < ITEM_MATCH_THRESHOLD

            candidates << {score: score, ti: ti, di: di}
          end
        end

        # Greedy best-first matching
        matches = {}        # ti => di
        reverse = {}        # di => ti
        candidates.sort_by { |c| -c[:score] }.each do |c|
          next if matched_t.include?(c[:ti]) || matched_d.include?(c[:di])

          matches[c[:ti]] = c[:di]
          reverse[c[:di]] = c[:ti]
          matched_t << c[:ti]
          matched_d << c[:di]
        end

        # Walk destination order, interleaving template-only items before the
        # dest item they were adjacent to in the template.
        result = []
        inserted_t = Set.new

        d_items.each_with_index do |d_item, di|
          # Before this dest item, insert any template-only items whose nearest
          # matched template neighbour falls before this point.
          t_items.each_with_index do |t_item, ti|
            next if matched_t.include?(ti) || inserted_t.include?(ti)
            # Find the first matched dest index for template items after ti
            next_matched_di = (ti + 1..t_items.size - 1).find { |k| matches.key?(k) }&.then { |k| matches[k] }
            insert_before = next_matched_di.nil? ? d_items.size : next_matched_di
            next if insert_before > di

            result << {type: :template_only, template_item: t_item}
            inserted_t << ti
          end

          if reverse.key?(di)
            ti = reverse[di]
            result << {type: :match, template_item: t_items[ti], dest_item: d_item}
          else
            result << {type: :dest_only, dest_item: d_item}
          end
        end

        # Append remaining template-only items that come after the last dest item
        t_items.each_with_index do |t_item, ti|
          next if matched_t.include?(ti) || inserted_t.include?(ti)

          result << {type: :template_only, template_item: t_item}
        end

        result
      end

      # --- emission ---

      def emit_lines(alignment, preference:, add_template_only:,
        template_analysis:, dest_analysis:)
        counter = 1
        lines = []

        alignment.each do |entry|
          case entry[:type]
          when :match
            node = (preference == :template) ? entry[:template_item] : entry[:dest_item]
            analysis = (preference == :template) ? template_analysis : dest_analysis
            text = item_bare_text(node, analysis)
            lines << "#{counter}. #{text}"
            counter += 1
          when :dest_only
            text = item_bare_text(entry[:dest_item], dest_analysis)
            lines << "#{counter}. #{text}"
            counter += 1
          when :template_only
            next unless add_template_only

            text = item_bare_text(entry[:template_item], template_analysis)
            lines << "#{counter}. #{text}"
            counter += 1
          end
        end

        lines
      end

      # Return the bare inline text of a list_item node (without the leading `1. ` marker).
      def item_bare_text(item, analysis)
        # Prefer source extraction for fidelity (preserves links, code spans, etc.)
        if analysis && item.respond_to?(:source_position)
          pos = item.source_position
          if pos
            raw = analysis.source_range(pos[:start_line], pos[:end_line]).strip
            # Strip the ordered-list marker: `1. `, `2. `, `123. ` etc.
            return raw.sub(/\A\d+\.\s+/, "")
          end
        end

        # Fallback: use .text and strip marker
        item.text.to_s.strip.sub(/\A\d+\.\s+/, "")
      end

      # --- token helpers ---

      def item_tokens(item)
        text = item.respond_to?(:text) ? item.text.to_s : ""
        extract_tokens(text)
      end

      def not_merged(reason)
        {merged: false, reason: reason}
      end
    end
  end
end
