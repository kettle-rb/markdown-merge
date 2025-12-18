# frozen_string_literal: true

module Markdown
  module Merge
    # Backend constants for markdown parsing.
    #
    # Backend loading and availability is handled entirely by tree_haver.
    # If a backend fails to load, tree_haver raises the appropriate error.
    # markdown-merge simply passes the backend selection through.
    #
    # @example Using a specific backend
    #   merger = SmartMerger.new(template, dest, backend: Backends::COMMONMARKER)
    #
    # @example Using auto-detection
    #   merger = SmartMerger.new(template, dest, backend: Backends::AUTO)
    #
    # @see TreeHaver::Backends::Commonmarker
    # @see TreeHaver::Backends::Markly
    module Backends
      # Use the Commonmarker backend (comrak Rust parser)
      COMMONMARKER = :commonmarker

      # Use the Markly backend (cmark-gfm C library)
      MARKLY = :markly

      # Auto-select backend (tree_haver handles selection and fallback)
      AUTO = :auto

      # All valid backend identifiers
      VALID_BACKENDS = [COMMONMARKER, MARKLY, AUTO].freeze

      class << self
        # Validate backend is a known type (does not check availability)
        #
        # @param backend [Symbol] Backend identifier
        # @return [Symbol] The validated backend
        # @raise [ArgumentError] If backend is not recognized
        def validate!(backend)
          return backend if VALID_BACKENDS.include?(backend)

          raise ArgumentError, "Unknown backend: #{backend.inspect}. " \
            "Valid backends: #{VALID_BACKENDS.map(&:inspect).join(", ")}"
        end

        # Check if backend is a valid identifier (does not check availability)
        #
        # @param backend [Symbol] Backend identifier
        # @return [Boolean]
        def valid?(backend)
          VALID_BACKENDS.include?(backend)
        end
      end
    end
  end
end

