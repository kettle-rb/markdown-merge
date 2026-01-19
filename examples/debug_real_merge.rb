#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to test the actual gem_family_section merge scenario.
#
# This tests the exact scenario that's causing spurious blank lines
# in the vendor/*/README.md files.
#
# Run from ast-merge directory:
#   ruby vendor/markdown-merge/examples/debug_real_merge.rb

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

# Read the actual template
ast_merge_root = File.expand_path("../../..", __dir__)
template_path = File.join(ast_merge_root, "GEM_FAMILY_SECTION.md")
TEMPLATE = File.read(template_path)

# Read the tree_haver README as a destination test file
dest_path = File.join(ast_merge_root, "vendor/tree_haver/README.md")
DESTINATION = File.read(dest_path)

puts "=" * 80
puts "TESTING REAL GEM_FAMILY_SECTION MERGE"
puts "=" * 80

puts "\nTemplate: #{template_path}"
puts "  Lines: #{TEMPLATE.lines.count}"
puts "  Blank lines: #{TEMPLATE.lines.count { |l| l.strip.empty? }}"

puts "\nDestination: #{dest_path}"
puts "  Lines: #{DESTINATION.lines.count}"
puts "  Blank lines: #{DESTINATION.lines.count { |l| l.strip.empty? }}"

# Analyze template link definitions
puts "\n" + "=" * 80
puts "TEMPLATE LINK DEFINITIONS"
puts "=" * 80

template_analysis = Markdown::Merge::FileAnalysis.new(TEMPLATE, backend: :markly)
template_link_defs = template_analysis.statements.select do |stmt|
  stmt.respond_to?(:merge_type) && stmt.merge_type == :link_definition
end

puts "\nTemplate has #{template_link_defs.count} link definitions:"
template_link_defs.first(5).each do |link_def|
  pos = link_def.source_position
  puts "  Line #{pos[:start_line]}: #{link_def.content[0..60]}..."
end
puts "  ... (#{template_link_defs.count - 5} more)" if template_link_defs.count > 5

# Check if template link defs are consecutive
puts "\nChecking template link definition spacing:"
prev_line = nil
gaps_found = 0
template_link_defs.each do |link_def|
  pos = link_def.source_position
  current_line = pos[:start_line]
  if prev_line && current_line != prev_line + 1
    gap = current_line - prev_line - 1
    gaps_found += 1
    puts "  Gap of #{gap} line(s) between lines #{prev_line} and #{current_line}" if gaps_found <= 5
  end
  prev_line = current_line
end
puts "  Total gaps between link definitions: #{gaps_found}"

# Now perform the merge
puts "\n" + "=" * 80
puts "PERFORMING PARTIAL TEMPLATE MERGE"
puts "=" * 80

merger = Markdown::Merge::PartialTemplateMerger.new(
  template: TEMPLATE,
  destination: DESTINATION,
  anchor: { type: :heading, text: /The \*-merge Gem Family/ },
  boundary: { type: :heading, same_or_shallower: true },
  backend: :markly,
  replace_mode: true,
)

result = merger.merge

puts "\nMerge result:"
puts "  has_section: #{result.has_section}"
puts "  changed: #{result.changed}"
puts "  message: #{result.message}"
puts "  Result lines: #{result.content.lines.count}"
puts "  Result blank lines: #{result.content.lines.count { |l| l.strip.empty? }}"

# Check for excessive blank lines
consecutive_blanks = result.content.scan(/\n{3,}/)
if consecutive_blanks.any?
  puts "\n⚠️  FOUND #{consecutive_blanks.count} OCCURRENCES OF EXCESSIVE BLANK LINES"
  consecutive_blanks.first(5).each_with_index do |match, idx|
    puts "  Occurrence #{idx + 1}: #{match.length} consecutive newlines"
  end
else
  puts "\n✅ No excessive consecutive blank lines found"
end

# Analyze result link definitions
puts "\n" + "=" * 80
puts "RESULT LINK DEFINITION SPACING"
puts "=" * 80

# Find the merged section in the result
lines = result.content.lines
link_def_pattern = /^\[([^\]]+)\]:\s+/

# Find all link definitions and check for blank lines between them
link_def_lines = []
lines.each_with_index do |line, idx|
  if line.match?(link_def_pattern)
    link_def_lines << idx + 1  # 1-indexed
  end
end

puts "\nResult has #{link_def_lines.count} link definitions"

# Check for gaps
gaps_in_result = 0
prev_line = nil
link_def_lines.each do |line_num|
  if prev_line && line_num != prev_line + 1
    gap = line_num - prev_line - 1
    gaps_in_result += 1
    if gaps_in_result <= 10
      puts "  ⚠️  Gap of #{gap} blank line(s) between lines #{prev_line} and #{line_num}"
      puts "      Line #{prev_line}: #{lines[prev_line - 1].chomp[0..60]}"
      puts "      Line #{line_num}: #{lines[line_num - 1].chomp[0..60]}"
    end
  end
  prev_line = line_num
end

if gaps_in_result > 0
  puts "\n  Total: #{gaps_in_result} gaps found between consecutive link definitions"
  puts "  THIS IS THE BUG! Link definitions should not have blank lines between them."
else
  puts "\n✅ Link definitions are consecutive (no gaps)"
end

puts "\nDone."

