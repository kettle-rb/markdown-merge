#!/usr/bin/env ruby
# frozen_string_literal: true

# Test the normalize_whitespace and rehydrate_link_references options
# by merging an empty document with the corrupted destination.
#
# Run from ast-merge directory:
#   ruby vendor/markdown-merge/examples/test_cleanup_options.rb

require "bundler/inline"

gemfile do
  source "https://gem.coop"

  # stdlib gems
  gem "benchmark"

  # Parser
  gem "markly", "~> 0.12"

  # Load markdown-merge from local path
  gem "markdown-merge", path: File.expand_path("..", __dir__)

  # Load markly-merge from local path
  gem "markly-merge", path: File.expand_path("../../markly-merge", __dir__)

  # AST merging framework
  gem "ast-merge", path: File.expand_path("../../..", __dir__)

  # Tree parsing
  gem "tree_haver", path: File.expand_path("../../tree_haver", __dir__)
end

require "tree_haver"
require "markdown-merge"
require "markly-merge"

# Read the corrupted tree_haver README
ast_merge_root = File.expand_path("../../..", __dir__)
dest_path = File.join(ast_merge_root, "vendor/tree_haver/README.md")
destination = File.read(dest_path)

puts "=" * 80
puts "TESTING SmartMerger CLEANUP OPTIONS"
puts "=" * 80

puts "\nDestination: #{dest_path}"
puts "  Lines: #{destination.lines.count}"
puts "  Blank lines: #{destination.lines.count { |l| l.strip.empty? }}"

# Count consecutive blank lines (3+ newlines = bug)
consecutive = destination.scan(/\n{3,}/)
puts "  Excessive blank line runs: #{consecutive.count}"

# Empty template - we want to keep ALL destination content
# but apply cleanup transformations
template = ""

puts "\n" + "=" * 80
puts "MERGING WITH CLEANUP OPTIONS"
puts "=" * 80

# Use SmartMerger with the cleanup options
merger = Markdown::Merge::SmartMerger.new(
  template,
  destination,
  backend: :markly,
  preference: :destination,  # Keep all destination content
  add_template_only_nodes: false,  # Don't add anything from empty template
  normalize_whitespace: true,  # Collapse excessive blank lines
  rehydrate_link_references: true,  # Restore link references
)

result = merger.merge_result

puts "\nMerge result:"
puts "  Lines: #{result.content.lines.count}"
puts "  Blank lines: #{result.content.lines.count { |l| l.strip.empty? }}"

# Check for improvements
result_consecutive = result.content.scan(/\n{3,}/)
puts "  Excessive blank line runs: #{result_consecutive.count}"

# Check problems reported
if result.problems && !result.problems.empty?
  puts "\nProblems found during cleanup:"
  result.problems.all.first(10).each do |problem|
    puts "  #{problem[:category]}: #{problem.inspect}"
  end
  puts "  ... (#{result.problems.count - 10} more)" if result.problems.count > 10
end

# Show stats
puts "\n" + "=" * 80
puts "COMPARISON"
puts "=" * 80

original_lines = destination.lines.count
result_lines = result.content.lines.count
original_blanks = destination.lines.count { |l| l.strip.empty? }
result_blanks = result.content.lines.count { |l| l.strip.empty? }

puts "Lines: #{original_lines} -> #{result_lines} (#{original_lines - result_lines} removed)"
puts "Blank lines: #{original_blanks} -> #{result_blanks} (#{original_blanks - result_blanks} removed)"
puts "Excessive runs: #{consecutive.count} -> #{result_consecutive.count}"

# Check link definitions spacing
puts "\n" + "=" * 80
puts "CHECKING LINK DEFINITION SPACING IN RESULT"
puts "=" * 80

lines = result.content.lines
link_def_pattern = /^\[.+\]:\s/
prev_link_line = nil
gaps = 0

lines.each_with_index do |line, idx|
  next unless line.match?(link_def_pattern)
  line_num = idx + 1
  if prev_link_line && line_num != prev_link_line + 1
    gaps += 1
    if gaps <= 5
      puts "  Gap at lines #{prev_link_line}-#{line_num}:"
      puts "    #{lines[prev_link_line - 1].chomp[0..60]}"
      puts "    (blank)" if lines[prev_link_line].strip.empty?
      puts "    #{line.chomp[0..60]}"
    end
  end
  prev_link_line = line_num
end

if gaps > 0
  puts "\n  Total gaps between link definitions: #{gaps}"
else
  puts "\n✅ No gaps between consecutive link definitions"
end

puts "\nDone."

