# frozen_string_literal: true

require "spec_helper"
require "ast/merge/rspec/shared_examples"

RSpec.describe Markdown::Merge::SmartMerger, :markdown_parsing do
  it_behaves_like "Ast::Merge::RemovalModeCompliance" do
    let(:merger_class) { described_class }

    let(:removal_mode_leading_comments_case) do
      {
        template: <<~MARKDOWN,
          # Title
        MARKDOWN
        destination: <<~MARKDOWN,
          # Title

          <!-- keep removed docs -->

          ## Legacy

          Legacy content.
        MARKDOWN
        expected: <<~MARKDOWN,
          # Title

          <!-- keep removed docs -->
        MARKDOWN
      }
    end

    let(:removal_mode_separator_blank_line_case) do
      {
        template: <<~MARKDOWN,
          Intro
        MARKDOWN
        destination: <<~MARKDOWN,
          Intro

          Legacy content.

          <!-- trailing docs -->
        MARKDOWN
        expected: <<~MARKDOWN,
          Intro

          <!-- trailing docs -->
        MARKDOWN
      }
    end

    let(:unsupported_removal_mode_case_reasons) do
      {
        removal_mode_inline_comments_case: "Markdown full-document smart merge does not define generic inline comment promotion semantics",
        removal_mode_recursive_case: "Markdown full-document removal mode is currently top-level only",
      }
    end
  end
end
