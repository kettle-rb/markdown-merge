# frozen_string_literal: true

require "parslet"

module Markdown
  module Merge
    module Cleanse
      # Parslet-based parser for fixing malformed fenced code blocks.
      #
      # A bug in ast-merge (or its dependencies) caused fenced code blocks to be
      # rendered with a space between the fence markers and the language identifier:
      #
      # @example Malformed (buggy) input
      #   "``` console\nsome code\n```"
      #
      # @example Fixed output
      #   "```console\nsome code\n```"
      #
      # == How It Works
      #
      # The parser uses a PEG grammar (via Parslet) to recognize fenced code blocks
      # and detect those with improper spacing. It then reconstructs them with
      # proper formatting (no space between fence and language).
      #
      # @example Basic usage
      #   parser = Markdown::Merge::Cleanse::CodeFenceSpacing.new(content)
      #   fixed_content = parser.fix
      #
      # @example Check if content has malformed fences
      #   parser = Markdown::Merge::Cleanse::CodeFenceSpacing.new(content)
      #   parser.malformed? # => true/false
      #
      # @example Process a file
      #   content = File.read("README.md")
      #   parser = Markdown::Merge::Cleanse::CodeFenceSpacing.new(content)
      #   if parser.malformed?
      #     File.write("README.md", parser.fix)
      #   end
      #
      # @example Get details about code blocks
      #   parser = Markdown::Merge::Cleanse::CodeFenceSpacing.new(content)
      #   parser.code_blocks.each do |block|
      #     puts "#{block[:fence]}#{block[:language]}: malformed=#{block[:malformed]}"
      #   end
      #
      # @api public
      class CodeFenceSpacing
        # Grammar for parsing fenced code blocks.
        #
        # Recognizes:
        # - Backtick fences (```) and tilde fences (~~~)
        # - Optional info string (language identifier)
        # - Properly handles spacing issues
        #
        # @api private
        class CodeFenceGrammar < Parslet::Parser
          # Fence markers - 3+ backticks or tildes
          rule(:backtick_fence) { str("`").repeat(3).as(:fence) }
          rule(:tilde_fence) { str("~").repeat(3).as(:fence) }
          rule(:fence) { backtick_fence | tilde_fence }

          # Space between fence and info string (the bug we're fixing)
          rule(:space) { match('[ \t]') }
          rule(:spaces) { space.repeat(1) }
          rule(:spaces?) { space.repeat }

          # Info string (language identifier + optional attributes)
          # Ends at newline, doesn't include the fence chars in the content
          rule(:info_char) { match('[^\r\n`]') }  # Backticks not allowed in info string per CommonMark
          rule(:info_string) { info_char.repeat(1).as(:info) }
          rule(:info_string?) { info_string.maybe }

          # The opening fence line: ```language or ``` language (with space = bug)
          rule(:opening_fence) {
            fence >> spaces?.as(:spacing) >> info_string? >> match('[\r\n]')
          }

          root(:opening_fence)
        end

        # Pattern to find opening code fences in content
        # Matches: ``` or ~~~ at start of line, followed by optional info string
        # Note: Closing fences (just ```) without info string match but have empty info
        # We distinguish opening fences by checking if there's an info string or if
        # this is the first fence we've seen
        FENCE_PATTERN = /^(```+|~~~+)([ \t]*)([^\r\n`]*)\r?$/

        # Pattern specifically for malformed fences (space between fence and language)
        # Language must start with a letter (not just any chars)
        MALFORMED_PATTERN = /^(```+|~~~+)[ \t]+([a-zA-Z][^\r\n`]*)\r?$/

        # @return [String] the input text to parse
        attr_reader :source

        # Create a new parser for the given text.
        #
        # @param source [String] the text that may contain malformed code fences
        def initialize(source)
          @source = source.to_s
          @grammar = CodeFenceGrammar.new
          @code_blocks = nil
        end

        # Check if the source contains malformed fenced code blocks.
        #
        # Detects the pattern where there's whitespace between the fence
        # markers and the language identifier.
        #
        # @return [Boolean] true if malformed fences are detected
        def malformed?
          source.match?(MALFORMED_PATTERN)
        end

        # Parse and return information about all fenced code blocks.
        #
        # Only returns opening fences (not closing fences).
        #
        # @return [Array<Hash>] Array of code block info
        #   - :fence [String] The fence markers (e.g., "```" or "~~~")
        #   - :language [String, nil] The language identifier
        #   - :spacing [String] Any spacing between fence and language
        #   - :malformed [Boolean] Whether this block has improper spacing
        #   - :line_number [Integer] Line number where block starts (1-based)
        #   - :original [String] The original opening fence line
        def code_blocks
          return @code_blocks if @code_blocks

          @code_blocks = []
          line_number = 0
          in_code_block = false
          current_fence = nil

          source.each_line do |line|
            line_number += 1
            match = line.match(FENCE_PATTERN)
            next unless match

            fence = match[1]
            spacing = match[2] || ""
            info = match[3] || ""

            # Determine if this is opening or closing fence
            # Closing fence: same fence type, no info string, and we're in a block
            if in_code_block && fence.start_with?(current_fence[0]) && info.strip.empty?
              # This is a closing fence - skip it
              in_code_block = false
              current_fence = nil
              next
            end

            # This is an opening fence
            in_code_block = true
            current_fence = fence

            # Extract just the language (first word of info string)
            language = info.strip.split(/\s+/).first
            language = nil if language&.empty?

            @code_blocks << {
              fence: fence,
              language: language,
              info_string: info.strip,
              spacing: spacing,
              malformed: !spacing.empty? && !language.nil? && !language.empty?,
              line_number: line_number,
              original: line.chomp,
            }
          end

          @code_blocks
        end

        # Fix malformed fenced code blocks by removing improper spacing.
        #
        # @return [String] the source with code fences fixed
        def fix
          return source unless malformed?

          result = source.dup

          # Process line by line, fixing malformed fences
          lines = result.lines
          fixed_lines = lines.map do |line|
            fix_fence_line(line)
          end

          fixed_lines.join
        end

        # Count the number of malformed code blocks.
        #
        # @return [Integer] number of malformed fences found
        def malformed_count
          code_blocks.count { |block| block[:malformed] }
        end

        # Count the total number of code blocks.
        #
        # @return [Integer] total number of fenced code blocks
        def count
          code_blocks.size
        end

        private

        # Fix a single line if it's a malformed fence.
        #
        # @param line [String] the line to potentially fix
        # @return [String] the fixed line (or original if not malformed)
        def fix_fence_line(line)
          match = line.match(MALFORMED_PATTERN)
          return line unless match

          fence = match[1]
          info = match[2]

          # Reconstruct without the space
          # Preserve any trailing content after language (attributes, etc.)
          "#{fence}#{info}\n"
        end
      end
    end
  end
end
