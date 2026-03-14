#!/usr/bin/env ruby
# frozen_string_literal: true

# Test the normalize_whitespace and rehydrate_link_references options
# by merging an empty document with the corrupted destination.
#
# Run from the markdown-merge directory:
#   ruby examples/test_cleanup_options.rb

WORKSPACE_ROOT = File.expand_path("../..", __dir__)
ENV["KETTLE_RB_DEV"] = WORKSPACE_ROOT unless ENV.key?("KETTLE_RB_DEV")

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  require File.expand_path("nomono/lib/nomono/bundler", WORKSPACE_ROOT)

  # stdlib gems
  gem "benchmark"

  # Parser
  gem "markly", "~> 0.12"

  eval_nomono_gems(
    gems: %w[markdown-merge markly-merge ast-merge tree_haver],
    prefix: "KETTLE_RB",
    path_env: "KETTLE_RB_DEV",
    vendored_gems_env: "VENDORED_GEMS",
    vendor_gem_dir_env: "VENDOR_GEM_DIR",
    debug_env: "KETTLE_DEV_DEBUG"
  )
end

require "tree_haver"
require "markdown-merge"
require "markly-merge"

# Read the sibling tree_haver README
dest_path = File.join(WORKSPACE_ROOT, "tree_haver", "README.md")
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
