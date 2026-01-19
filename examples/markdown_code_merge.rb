#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Smart Markdown Merging with Inner Code Block Merging
#
# This demonstrates how markdown-merge can intelligently merge markdown files
# that contain fenced code blocks in various languages, delegating to
# language-specific *-merge gems for inner-merge of the code content.
#
# This example tests whether FencedCodeBlockDetector is needed, or if the
# native code block nodes in the Markdown AST (accessed via fence_info and
# string_content) are sufficient for inner-merging.
#
# markdown-merge: Base gem providing SmartMerger with CodeBlockMerger
# *-merge gems: prism-merge, psych-merge, json-merge, toml-merge, bash-merge

require "bundler/inline"

gemfile do
  source "https://gem.coop"

  # stdlib gems
  gem "benchmark"

  # Parser
  gem "commonmarker", ">= 0.23"

  # Load local gems for testing
  gem "ast-merge", path: File.expand_path("../../..", __dir__)
  gem "tree_haver", path: File.expand_path("../../tree_haver", __dir__)
  gem "markdown-merge", path: File.expand_path("..", __dir__)
  gem "commonmarker-merge", path: File.expand_path("../../commonmarker-merge", __dir__)

  # Language-specific merge gems
  gem "prism-merge", path: File.expand_path("../../prism-merge", __dir__)
  gem "psych-merge", path: File.expand_path("../../psych-merge", __dir__)
  gem "json-merge", path: File.expand_path("../../json-merge", __dir__)
  gem "toml-merge", path: File.expand_path("../../toml-merge", __dir__)
  gem "bash-merge", path: File.expand_path("../../bash-merge", __dir__)
end

require "tree_haver"
require "markdown-merge"
require "commonmarker-merge"

puts "=" * 80
puts "Markdown Code Block Inner-Merge Example"
puts "=" * 80
puts

# Template: Developer guide with code examples in various languages
template_markdown = <<~MARKDOWN
  # Developer Guide

  ## Configuration

  Configure your application using YAML:

  ```yaml
  app:
    name: MyApp
    port: 3000
    features:
      - logging
      - metrics
  ```

  Or use TOML if you prefer:

  ```toml
  [app]
  name = "MyApp"
  port = 3000
  features = ["logging", "metrics"]
  ```

  ## Setup Script

  Run this bash script to set up your environment:

  ```bash
  #!/bin/bash
  export APP_NAME="MyApp"
  export PORT=3000
  echo "Environment configured"
  ```

  ## Ruby Configuration

  Initialize your app with this Ruby code:

  ```ruby
  class App
    def initialize
      @name = "MyApp"
      @port = 3000
    end
  end
  ```

  ## API Response

  The API returns JSON:

  ```json
  {
    "name": "MyApp",
    "port": 3000,
    "status": "running"
  }
  ```

  ## Documentation

  See the README for more details.
MARKDOWN

# Destination: Same guide with customizations in each code block
destination_markdown = <<~MARKDOWN
  # Developer Guide (Production)

  ## Configuration

  Configure your application using YAML:

  ```yaml
  app:
    name: MyProductionApp
    port: 8080
    database:
      host: db.example.com
    features:
      - logging
  ```

  ## Setup Script

  Run this bash script to set up your environment:

  ```bash
  #!/bin/bash
  export APP_NAME="MyProductionApp"
  export PORT=8080
  export DATABASE_HOST="db.example.com"
  echo "Production environment configured"
  ```

  ## Ruby Configuration

  Initialize your app with this Ruby code:

  ```ruby
  class App
    def initialize
      @name = "MyProductionApp"
      @port = 8080
      @database_host = "db.example.com"
    end
  end
  ```

  ## API Response

  The API returns JSON:

  ```json
  {
    "name": "MyProductionApp",
    "port": 8080,
    "database": "postgres",
    "status": "running"
  }
  ```

  ## Deployment

  Custom deployment instructions here.
MARKDOWN

puts "Template (with standard code examples):"
puts "-" * 80
puts template_markdown
puts

puts "Destination (with production customizations in code blocks):"
puts "-" * 80
puts destination_markdown
puts

# Force Commonmarker backend
puts "Setting backend to Commonmarker..."
TreeHaver.backend = :commonmarker
puts "✓ Backend: #{TreeHaver.backend_module}"
puts

# Check availability
if Commonmarker::Merge::Backend.available?
  puts "✓ Commonmarker is available"
else
  puts "✗ Commonmarker not found - cannot run example"
  exit 1
end
puts

# Demonstrate without inner-merge first
puts "=" * 80
puts "1. Merge WITHOUT inner-merge (standard conflict resolution)"
puts "=" * 80
puts

merger_no_inner = Markdown::Merge::SmartMerger.new(
  template_markdown,
  destination_markdown,
  backend: :commonmarker,
  inner_merge_code_blocks: false,
  preference: :destination,
  add_template_only_nodes: true,
)

result_no_inner = merger_no_inner.merge_result

puts "Result (destination code blocks win entirely):"
puts "-" * 80
puts result_no_inner.content
puts

puts "Statistics:"
puts "  Nodes Added: #{result_no_inner.nodes_added}"
puts "  Nodes Modified: #{result_no_inner.nodes_modified}"
puts "  Nodes Removed: #{result_no_inner.nodes_removed}"
puts "  Merge Time: #{result_no_inner.merge_time_ms}ms"
puts

# Now demonstrate WITH inner-merge
puts "=" * 80
puts "2. Merge WITH inner-merge (language-specific smart merge)"
puts "=" * 80
puts

merger_with_inner = Markdown::Merge::SmartMerger.new(
  template_markdown,
  destination_markdown,
  backend: :commonmarker,
  inner_merge_code_blocks: true,  # Enable inner-merge!
  preference: :destination,
  add_template_only_nodes: true,
)

result_with_inner = merger_with_inner.merge_result

puts "Result (code blocks intelligently merged using *-merge gems):"
puts "-" * 80
puts result_with_inner.content
puts

puts "Statistics:"
puts "  Nodes Added: #{result_with_inner.nodes_added}"
puts "  Nodes Modified: #{result_with_inner.nodes_modified}"
puts "  Nodes Removed: #{result_no_inner.nodes_removed}"
puts "  Merge Time: #{result_with_inner.merge_time_ms}ms"
puts

# Demonstrate what happens at the code block level
puts "=" * 80
puts "3. Analysis: Code Block Inner-Merge Behavior"
puts "=" * 80
puts

puts "YAML Code Block:"
puts "  Template:    name: MyApp, port: 3000, features: [logging, metrics]"
puts "  Destination: name: MyProductionApp, port: 8080, database.host: db.example.com, features: [logging]"
puts "  With inner-merge: psych-merge combines both, preserving destination values"
puts

puts "Ruby Code Block:"
puts "  Template:    3 instance vars (@name, @port)"
puts "  Destination: 3 instance vars with production values + @database_host"
puts "  With inner-merge: prism-merge preserves @database_host from destination"
puts

puts "JSON Code Block:"
puts "  Template:    {name, port, status}"
puts "  Destination: {name, port, database, status} with different values"
puts "  With inner-merge: json-merge combines keys, destination values win"
puts

puts "Bash Code Block:"
puts "  Template:    Sets APP_NAME, PORT, basic echo"
puts "  Destination: Sets APP_NAME, PORT, DATABASE_HOST, custom echo"
puts "  With inner-merge: bash-merge preserves DATABASE_HOST export"
puts

puts "TOML Code Block:"
puts "  Only in template, not in destination"
puts "  With add_template_only_nodes: true, TOML section added to result"
puts

puts "=" * 80
puts "Key Findings: FencedCodeBlockDetector vs Native AST Nodes"
puts "=" * 80
puts

puts "Native AST Approach (used by CodeBlockMerger):"
puts "  ✓ Uses node.fence_info to get language identifier"
puts "  ✓ Uses node.string_content to get code content"
puts "  ✓ Works seamlessly with tree_haver's unified backend API"
puts "  ✓ Automatically handles both ``` and ~~~ fences"
puts "  ✓ Respects node boundaries from the parser"
puts "  ✓ No regex needed - parser handles all edge cases"
puts

puts "FencedCodeBlockDetector Approach:"
puts "  • Uses regex to find code blocks in raw text"
puts "  • Returns Region objects with line numbers"
puts "  • Useful for: Text-based analysis without parsing"
puts "  • Useful for: Operating on source text directly"
puts "  • Not needed for: AST-based merging (parser handles it)"
puts

puts "=" * 80
puts "Conclusion:"
puts "=" * 80
puts

puts "For markdown-merge's CodeBlockMerger:"
puts "  → Native AST nodes are SUFFICIENT and PREFERRED"
puts "  → FencedCodeBlockDetector is NOT needed for this use case"
puts "  → The markdown parser (commonmarker/markly) already identifies"
puts "     code blocks, extracts language, and provides content"
puts

puts "FencedCodeBlockDetector is useful for:"
puts "  → Text-based tools that don't parse markdown AST"
puts "  → Quick extraction from raw strings without full parsing"
puts "  → Custom processing that needs line-level precision"
puts "  → Tools that want to avoid parser dependencies"
puts

puts "Best practice:"
puts "  → When working with parsed markdown AST: use native nodes"
puts "  → When working with raw text: use FencedCodeBlockDetector"
puts "  → markdown-merge uses the former approach ✓"
puts "=" * 80
