# TreeHaver needs to be loaded early, so we can make the DependencyTags available
require "tree_haver"
require "tree_haver/rspec"
require "ast-merge"
require "ast/merge/rspec"

# Register known gems that this test suite depends on
# This allows specs to use :commonmarker_merge and :markly_merge tags
# even when those gems aren't loaded
Ast::Merge::RSpec::MergeGemRegistry.register_known_gems(
  :commonmarker_merge,
  :markly_merge,
)
