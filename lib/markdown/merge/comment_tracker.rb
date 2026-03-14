# frozen_string_literal: true

module Markdown
  module Merge
    # Conservatively tracks standalone HTML comment lines in Markdown sources.
    class CommentTracker
      STANDALONE_HTML_COMMENT_REGEX = /\A(?<indent>\s*)<!--\s?(?<text>.*?)\s?-->\s*\z/

      attr_reader :lines, :comments

      def initialize(lines)
        @lines = Array(lines)
        @comments = extract_comments
        @comments_by_line = @comments.group_by { |comment| comment[:line] }
      end

      def comment_at(line_num)
        @comments_by_line[line_num]&.first
      end

      def comment_nodes
        @comment_nodes ||= @comments.map { |comment| build_comment_node(comment) }
      end

      def comment_node_at(line_num)
        comment = comment_at(line_num)
        return unless comment

        build_comment_node(comment)
      end

      def comments_in_range(range)
        @comments.select { |comment| range.cover?(comment[:line]) }
      end

      def comment_region_for_range(range, kind:, full_line_only: false)
        selected = comments_in_range(range)
        selected = selected.select { |comment| comment[:full_line] } if full_line_only

        build_region(
          kind: kind,
          comments: selected,
          metadata: {
            range: range,
            full_line_only: full_line_only,
            source: :comment_tracker,
          },
        )
      end

      def leading_comments_before(line_num)
        leading = []
        current = line_num - 1

        current -= 1 while current >= 1 && blank_line?(current)

        while current >= 1
          comment = comment_at(current)
          break unless comment && comment[:full_line]

          leading.unshift(comment)
          current -= 1
          current -= 1 while current >= 1 && blank_line?(current)
        end

        leading
      end

      def leading_comment_region_before(line_num)
        selected = leading_comments_before(line_num)
        return if selected.empty?

        build_region(
          kind: :leading,
          comments: selected,
          metadata: {
            line_num: line_num,
            source: :comment_tracker,
          },
        )
      end

      def comment_attachment_for(owner, line_num: nil, **metadata)
        resolved_line_num = line_num || owner_line_num(owner)
        leading_region = resolved_line_num ? leading_comment_region_before(resolved_line_num) : nil

        build_attachment(
          owner: owner,
          leading_region: leading_region,
          inline_region: nil,
          metadata: metadata.merge(
            line_num: resolved_line_num,
            source: :comment_tracker,
          ),
        )
      end

      def blank_line?(line_num)
        return false if line_num < 1 || line_num > @lines.length

        @lines[line_num - 1].to_s.strip.empty?
      end

      def augment(owners: [], **options)
        if defined?(Ast::Merge::Comment::Augmenter)
          Ast::Merge::Comment::Augmenter.new(
            lines: @lines,
            comments: @comments,
            owners: owners,
            style: :html_comment,
            total_comment_count: @comments.size,
            **options,
          )
        else
          build_fallback_augmenter(owners: owners)
        end
      end

      private

      def extract_comments
        @lines.each_with_index.filter_map do |line, index|
          match = line.match(STANDALONE_HTML_COMMENT_REGEX)
          next unless match

          {
            line: index + 1,
            indent: match[:indent].length,
            text: match[:text].to_s,
            full_line: true,
            raw: line,
          }
        end
      end

      def owner_line_num(owner)
        pos = owner.respond_to?(:source_position) ? owner.source_position : nil
        return pos[:start_line] if pos && pos[:start_line]

        nil
      end

      def build_comment_node(comment)
        if defined?(Ast::Merge::Comment::TrackedHashAdapter)
          Ast::Merge::Comment::TrackedHashAdapter.node(comment, style: :html_comment)
        else
          Struct.new(:line_number, :text).new(comment[:line], comment[:text])
        end
      end

      def build_region(kind:, comments:, metadata: {})
        if defined?(Ast::Merge::Comment::TrackedHashAdapter)
          Ast::Merge::Comment::TrackedHashAdapter.region(
            kind: kind,
            comments: comments,
            style: :html_comment,
            metadata: metadata,
          )
        else
          Struct.new(:kind, :nodes, :metadata).new(kind, comments.map { |comment| build_comment_node(comment) }, metadata)
        end
      end

      def build_attachment(owner:, leading_region:, inline_region:, metadata: {})
        if defined?(Ast::Merge::Comment::Attachment)
          Ast::Merge::Comment::Attachment.new(
            owner: owner,
            leading_region: leading_region,
            inline_region: inline_region,
            metadata: metadata,
          )
        else
          Struct.new(:owner, :leading_region, :inline_region, :metadata).new(owner, leading_region, inline_region, metadata)
        end
      end

      def build_fallback_augmenter(owners:)
        attachment_lookup = owners.each_with_object({}) do |owner, result|
          result[owner] = comment_attachment_for(owner)
        end

        first_owner_line = owners.filter_map { |owner| owner_line_num(owner) }.min
        last_owner_line = owners.filter_map do |owner|
          pos = owner.respond_to?(:source_position) ? owner.source_position : nil
          pos ? pos[:end_line] : nil
        end.max

        preamble_comments = @comments.select { |comment| first_owner_line && comment[:line] < first_owner_line }
        postlude_comments = @comments.select { |comment| last_owner_line && comment[:line] > last_owner_line }

        capability = Struct.new(:source_augmented?).new(true)
        preamble = build_region(kind: :preamble, comments: preamble_comments, metadata: {source: :comment_tracker})
        postlude = build_region(kind: :postlude, comments: postlude_comments, metadata: {source: :comment_tracker})

        Struct.new(:capability, :preamble_region, :postlude_region, :orphan_regions) do
          def attachment_for(owner)
            @attachment_lookup[owner]
          end

          def with_attachment_lookup(lookup)
            @attachment_lookup = lookup
            self
          end
        end.new(capability, preamble, postlude, []).with_attachment_lookup(attachment_lookup)
      end
    end
  end
end
