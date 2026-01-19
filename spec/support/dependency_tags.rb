# frozen_string_literal: true

# Load shared dependency tags from tree_haver
#
# This file follows the standard spec/support/ convention. The actual
# implementation is in tree_haver so it can be shared across all gems
# in the TreeHaver/ast-merge family.
#
# @see TreeHaver::RSpec::DependencyTags

require "tree_haver/rspec"
require "ast/merge/rspec"

# Alias for convenience in existing specs
MarkdownMergeDependencies = TreeHaver::RSpec::DependencyTags

# Define stub backend tags for cases where the *-merge gems aren't loaded yet
# These will be overridden by the real tags when commonmarker-merge/markly-merge are loaded
RSpec.configure do |config|
  # Stub for :commonmarker_backend tag
  # Checks if Commonmarker::Merge is defined (i.e., commonmarker-merge gem is loaded)
  config.before(:each, :commonmarker_backend) do |example|
    unless defined?(Commonmarker::Merge)
      skip "Commonmarker backend not available (commonmarker-merge gem not loaded)"
    end
  end

  # Stub for :markly_backend tag
  # Checks if Markly::Merge is defined (i.e., markly-merge gem is loaded)
  config.before(:each, :markly_backend) do |example|
    unless defined?(Markly::Merge)
      skip "Markly backend not available (markly-merge gem not loaded)"
    end
  end

  # Stub for :markdown_parsing tag - requires at least one markdown backend
  # Will be skipped if neither commonmarker nor markly backends are available
  config.before(:each, :markdown_parsing) do |example|
    unless defined?(Commonmarker::Merge) || defined?(Markly::Merge)
      skip "No markdown backend available (neither commonmarker-merge nor markly-merge loaded)"
    end
  end
end
