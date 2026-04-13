# frozen_string_literal: true

require "spec_helper"
require "ast/merge/rspec/shared_examples"

RSpec.describe Markdown::Merge::SmartMerger, "comment behavior matrix", :markdown_parsing do
  extend Ast::Merge::RSpec::CommentBehaviorMatrixAdapters

  it_behaves_like "Ast::Merge::CommentBehaviorMatrix" do
    markdown_link_definition_comment_matrix_adapter(
      analysis_class: Markdown::Merge::FileAnalysis,
      merger_class: Markdown::Merge::SmartMerger,
    )
  end
end
