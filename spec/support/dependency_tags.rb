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
