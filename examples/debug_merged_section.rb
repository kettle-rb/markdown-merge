#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to isolate where blank lines are being inserted.
#
# This tests the exact scenario and examines ONLY the merged section.
#
# Run from ast-merge directory:
#   ruby vendor/markdown-merge/examples/debug_merged_section.rb

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

# Create a clean minimal destination that doesn't have pre-existing corruption
DESTINATION = <<~MD
# Test README

Some intro content.

### The `*-merge` Gem Family

Old content that will be replaced.

| Old | Table |
|-----|-------|
| a   | b     |

[old-link]: https://old.example.com

## Next Section

Content after the gem family section.

[after-link]: https://after.example.com
MD

puts "=" * 80
puts "TESTING WITH CLEAN MINIMAL DESTINATION"
puts "=" * 80

puts "\nTemplate: #{template_path}"
puts "  Lines: #{TEMPLATE.lines.count}"
puts "  Link definitions: #{TEMPLATE.lines.count { |l| l.match?(/^\[.+\]:\s/) }}"

puts "\nDestination:"
puts "  Lines: #{DESTINATION.lines.count}"
puts "  Link definitions: #{DESTINATION.lines.count { |l| l.match?(/^\[.+\]:\s/) }}"

# Check template link def spacing
puts "\n" + "=" * 80
puts "TEMPLATE LINK DEFINITION LINES"
puts "=" * 80

template_lines = TEMPLATE.lines
link_def_pattern = /^\[.+\]:\s/
prev_link_line = nil
template_gaps = 0

template_lines.each_with_index do |line, idx|
  next unless line.match?(link_def_pattern)
  line_num = idx + 1
  if prev_link_line && line_num != prev_link_line + 1
    template_gaps += 1
    puts "  Gap at line #{line_num} (prev was #{prev_link_line})" if template_gaps <= 3
  end
  prev_link_line = line_num
end

puts "Template link definition gaps: #{template_gaps}"

# Perform merge
puts "\n" + "=" * 80
puts "PERFORMING MERGE"
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

# Analyze result
puts "\n" + "=" * 80
puts "RESULT ANALYSIS"
puts "=" * 80

result_lines = result.content.lines
puts "Result lines: #{result_lines.count}"

# Find the gem family section in result
gem_section_start = nil
gem_section_end = nil

result_lines.each_with_index do |line, idx|
  if line.include?("The `*-merge` Gem Family")
    gem_section_start = idx
  elsif gem_section_start && line.match?(/^##\s/) && !line.include?("*-merge")
    gem_section_end = idx - 1
    break
  end
end

gem_section_end ||= result_lines.count - 1

puts "\nGem Family section: lines #{gem_section_start + 1} to #{gem_section_end + 1}"

# Check link defs in the merged section only
section_lines = result_lines[gem_section_start..gem_section_end]
prev_link_line = nil
section_gaps = 0
gap_examples = []

section_lines.each_with_index do |line, idx|
  next unless line.match?(link_def_pattern)
  line_num = idx + 1  # 1-indexed within section
  absolute_line = gem_section_start + idx + 1  # absolute line in result

  if prev_link_line && line_num != prev_link_line + 1
    gap = line_num - prev_link_line - 1
    section_gaps += 1
    if gap_examples.length < 5
      gap_examples << {
        gap: gap,
        prev_line: gem_section_start + prev_link_line,
        curr_line: absolute_line,
        prev_content: section_lines[prev_link_line - 1].chomp[0..50],
        curr_content: line.chomp[0..50],
        between: section_lines[prev_link_line..(line_num - 2)].map(&:chomp)
      }
    end
  end
  prev_link_line = line_num
end

if section_gaps > 0
  puts "\n⚠️  FOUND #{section_gaps} GAPS in merged section's link definitions!"
  gap_examples.each_with_index do |ex, i|
    puts "\n  Example #{i + 1}: #{ex[:gap]} blank line(s) between lines #{ex[:prev_line]} and #{ex[:curr_line]}"
    puts "    Prev: #{ex[:prev_content]}"
    puts "    Between: #{ex[:between].map(&:inspect).join(', ')}"
    puts "    Curr: #{ex[:curr_content]}"
  end
else
  puts "\n✅ No gaps in merged section's link definitions"
end

# Also show the first 20 lines of link defs in the merged section
puts "\n" + "=" * 80
puts "FIRST 20 LINK DEFINITIONS IN MERGED SECTION"
puts "=" * 80

link_def_count = 0
section_lines.each_with_index do |line, idx|
  next unless line.match?(link_def_pattern)
  link_def_count += 1
  break if link_def_count > 20
  puts "  Line #{gem_section_start + idx + 1}: #{line.chomp[0..70]}"
end

puts "\nDone."

