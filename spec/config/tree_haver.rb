# TreeHaver needs to be loaded early, so we can make the DependencyTags available
require "tree_haver"
require "tree_haver/rspec"
require "ast-merge"

# Load ONLY the registry and helper classes (not RSpec configuration yet)
# This allows us to register known gems before RSpec.configure runs
require "ast/merge/rspec/setup"

# Register known gems that this test suite depends on BEFORE loading RSpec config
# This allows specs to use :commonmarker_merge and :markly_merge tags
# even when those gems aren't loaded
Ast::Merge::RSpec::MergeGemRegistry.register_known_gems(
  :commonmarker_merge,
  :markly_merge
)

# Now load the RSpec configuration (which will see the registered gems)
require "ast/merge/rspec/dependency_tags_config"
require "ast/merge/rspec/shared_examples"
