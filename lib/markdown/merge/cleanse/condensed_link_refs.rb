# frozen_string_literal: true

require "parslet"

module Markdown
  module Merge
    module Cleanse
      # Parslet-based parser for fixing condensed Markdown link reference definitions.
      #
      # A previous bug in ast-merge caused link reference definitions at the bottom
      # of Markdown files to be merged together into a single line without newlines
      # or whitespace between them.
      #
      # @example Condensed (buggy) input
      #   "[⛳liberapay-img]: https://example.com/img.svg[⛳liberapay]: https://example.com"
      #
      # @example Expanded (fixed) output
      #   "[⛳liberapay-img]: https://example.com/img.svg\n[⛳liberapay]: https://example.com"
      #
      # == How It Works
      #
      # The parser uses a PEG grammar (via Parslet) to recognize the pattern where
      # a URL ends and a new link reference definition begins without whitespace.
      # It parses the condensed string into individual definitions, then reconstructs
      # them with proper newlines.
      #
      # The grammar extends the pattern from {LinkParser::DefinitionGrammar} but
      # handles the case where definitions are concatenated without separators.
      #
      # @example Basic usage
      #   parser = Markdown::Merge::Cleanse::CondensedLinkRefs.new(condensed_text)
      #   fixed_text = parser.expand
      #
      # @example Check if text contains condensed refs
      #   parser = Markdown::Merge::Cleanse::CondensedLinkRefs.new(text)
      #   parser.condensed? # => true/false
      #
      # @example Process a file
      #   content = File.read("README.md")
      #   parser = Markdown::Merge::Cleanse::CondensedLinkRefs.new(content)
      #   if parser.condensed?
      #     File.write("README.md", parser.expand)
      #   end
      #
      # @example Get parsed definitions
      #   parser = Markdown::Merge::Cleanse::CondensedLinkRefs.new(condensed_text)
      #   parser.definitions.each do |defn|
      #     puts "#{defn[:label]} => #{defn[:url]}"
      #   end
      #
      # @see LinkParser For parsing properly-formatted link definitions
      # @api public
      class CondensedLinkRefs
        # Pattern to detect condensed link refs: URL immediately followed by [
        # This catches patterns like: ...svg[next-label]: http://... or ...com[next-label]: CONTRIBUTING.md
        # We look for a non-whitespace char (end of URL) followed by [ (start of next ref)
        # The lookbehind ensures we're at the end of a URL, and the lookahead confirms
        # this is the start of a link reference definition (must have URL after ]:).
        #
        # Key: We require the lookahead to see `[label]: URL` where URL is either:
        # - A full URL (starts with http, https, /, <, or .)
        # - A relative path/filename (word chars, may contain ., -, _, no spaces)
        #
        # We distinguish from `[text][label]: description` by requiring the "URL" part
        # to NOT start with emoji or be followed immediately by a space and more text.
        # Real URLs/filenames are continuous non-space sequences.
        #
        # The negative lookahead `(?!\s)` after the URL pattern ensures we're matching
        # a real URL (no space after the first URL-like segment).
        CONDENSED_PATTERN = /(?<=[^\s\[])\[(?=[^\]]+\]:\s*(?:https?:\/\/|<|\/|\.|[A-Z][A-Za-z0-9_.-]*\.[a-z]{1,5}(?:[#?]|\[|$)))/

        # Grammar for parsing multiple condensed link reference definitions.
        #
        # This grammar handles the specific bug pattern where link definitions
        # are concatenated without newlines or whitespace between them.
        #
        # Key insight: A bare URL ends at any character that's not valid in a URL.
        # The `[` character that starts the next definition is NOT valid in a bare URL,
        # so we can use it as the delimiter.
        #
        # @api private
        class CondensedDefinitionsGrammar < Parslet::Parser
          rule(:space) { match('[ \t]') }
          rule(:spaces) { space.repeat(1) }
          rule(:spaces?) { space.repeat }
          rule(:newline) { match('[\r\n]') }
          rule(:newlines?) { newline.repeat }

          # Bracket content: handles nested brackets recursively
          # Same as LinkParser::DefinitionGrammar
          rule(:bracket_content) {
            (
              str("[") >> bracket_content.maybe >> str("]") |
              str("]").absent? >> any
            ).repeat
          }

          rule(:label) { str("[") >> bracket_content.as(:label) >> str("]") }

          # URL characters - everything except whitespace, >, and [
          # The [ is excluded because it signals the start of the next definition
          rule(:url_char) { match('[^\s>\[]') }
          rule(:bare_url) { url_char.repeat(1) }

          # Angled URLs can contain [ since they're delimited by <>
          rule(:angled_url_char) { match("[^>]") }
          rule(:angled_url) { str("<") >> angled_url_char.repeat(1) >> str(">") }

          rule(:url) { (angled_url | bare_url).as(:url) }

          # Title handling (same as LinkParser)
          rule(:title_content_double) { (str('"').absent? >> any).repeat }
          rule(:title_content_single) { (str("'").absent? >> any).repeat }
          rule(:title_content_paren) { (str(")").absent? >> any).repeat }

          rule(:title_double) { str('"') >> title_content_double.as(:title) >> str('"') }
          rule(:title_single) { str("'") >> title_content_single.as(:title) >> str("'") }
          rule(:title_paren) { str("(") >> title_content_paren.as(:title) >> str(")") }
          rule(:title) { title_double | title_single | title_paren }

          # A single definition
          rule(:definition) {
            spaces? >>
              label >>
              str(":") >>
              spaces? >>
              url >>
              (spaces >> title).maybe >>
              spaces?
          }

          # Multiple definitions, possibly with or without newlines between them
          rule(:definitions) {
            (definition.as(:definition) >> newlines?).repeat(1)
          }

          root(:definitions)
        end

        # @return [String] the input text to parse
        attr_reader :source

        # Create a new parser for the given text.
        #
        # @param source [String] the text that may contain condensed link refs
        def initialize(source)
          @source = source.to_s
          @grammar = CondensedDefinitionsGrammar.new
          @parsed = nil
          @definitions = nil
        end

        # Check if the source contains condensed link reference definitions.
        #
        # Detects the pattern where a URL character is immediately followed by `[`
        # which indicates the start of a new link reference definition without
        # proper newline separation.
        #
        # Key: We require the pattern to see `[label]: URL` where URL starts with
        # a URL-like character (http, /, <, etc.) to distinguish from reference-style
        # links like `[text][label]:` where the `:` is just punctuation.
        #
        # @return [Boolean] true if condensed refs are detected
        def condensed?
          # Pattern: non-whitespace char (end of URL) followed by [ (start of next ref)
          # The ref must be followed by ]: and a URL-like start character
          source.match?(CONDENSED_PATTERN)
        end

        # Parse the source into individual link reference definitions that are condensed.
        #
        # This finds only the link refs that are part of condensed sequences
        # (i.e., where multiple refs are on the same line without newlines).
        #
        # @return [Array<Hash>] Array of { label:, url:, title: (optional) }
        def definitions
          return @definitions if @definitions

          @definitions = []

          # Find all condensed sequences and parse them
          # A condensed sequence starts with a link ref and has more refs immediately following
          source.scan(/\[[^\]]+\]:\s*[^\[\s]+(?:\[[^\]]+\]:\s*[^\[\s]+)+/) do |match|
            # Parse each definition in the condensed sequence
            match.scan(/\[([^\]]+)\]:\s*([^\[\s]+)/) do |label, url|
              @definitions << {
                label: label,
                url: clean_url(url),
              }
            end
          end

          @definitions
        end

        # Expand condensed link reference definitions to separate lines.
        #
        # Fixes only the condensed patterns (where a URL is immediately followed
        # by a new link ref definition without a newline). All other content
        # is preserved exactly as-is.
        #
        # @return [String] the source with condensed link refs expanded to separate lines
        def expand
          return source unless condensed?

          # Use regex substitution to insert newlines before each condensed link ref
          # Pattern: end of URL (non-whitespace, non-[) followed by [ starting a new ref
          # We insert a newline between them
          source.gsub(CONDENSED_PATTERN, "\n[")
        end

        # Count the number of link reference definitions in the source.
        #
        # @return [Integer] number of link ref definitions found
        def count
          definitions.size
        end

        private

        # Clean a URL (strip angle brackets if present).
        #
        # @param url [String] the URL to clean
        # @return [String] cleaned URL
        def clean_url(url)
          url = url.strip
          (url.start_with?("<") && url.end_with?(">")) ? url[1..-2] : url
        end
      end
    end
  end
end
