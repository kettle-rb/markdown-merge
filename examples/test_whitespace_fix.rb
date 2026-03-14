#!/usr/bin/env ruby
# frozen_string_literal: true

# Test the whitespace handling fix using fixtures.
#
# This tests that:
# 1. Link definitions are output with proper newlines (not concatenated)
# 2. Blank lines are preserved before headings
# 3. Blank lines are preserved after link definition blocks
# 4. Consecutive link definitions do NOT have blank lines between them
#
# Run from the markdown-merge directory:
#   ruby examples/test_whitespace_fix.rb

WORKSPACE_ROOT = File.expand_path("../..", __dir__)
ENV["KETTLE_RB_DEV"] = WORKSPACE_ROOT unless ENV.key?("KETTLE_RB_DEV")

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  require File.expand_path("nomono/lib/nomono/bundler", WORKSPACE_ROOT)

  gem "benchmark"
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

# Load fixtures
fixtures_dir = File.expand_path("../spec/fixtures/whitespace_bug", __dir__)
template = File.read(File.join(fixtures_dir, "template.md"))
destination = File.read(File.join(fixtures_dir, "destination.md"))
expected = File.read(File.join(fixtures_dir, "expected.md"))

puts "=" * 80
puts "TESTING WHITESPACE FIX WITH FIXTURES"
puts "=" * 80

puts "\n--- TEMPLATE ---"
puts template
puts "--- END TEMPLATE ---"

puts "\n--- DESTINATION ---"
puts destination
puts "--- END DESTINATION ---"

puts "\n--- EXPECTED ---"
puts expected
puts "--- END EXPECTED ---"

# Perform the partial merge
puts "\n" + "=" * 80
puts "PERFORMING PARTIAL TEMPLATE MERGE"
puts "=" * 80

merger = Markdown::Merge::PartialTemplateMerger.new(
  template: template,
  destination: destination,
  anchor: { type: :heading, text: /The \*-merge Gem Family/ },
  boundary: { type: :heading, same_or_shallower: true },
  backend: :markly,
  replace_mode: true,
)

result = merger.merge

puts "\n--- RESULT ---"
puts result.content
puts "--- END RESULT ---"

# Compare
puts "\n" + "=" * 80
puts "COMPARISON"
puts "=" * 80

if result.content == expected
  puts "✅ PASS: Result matches expected output!"
else
  puts "❌ FAIL: Result does NOT match expected output"

  # Show differences
  result_lines = result.content.lines
  expected_lines = expected.lines

  max_lines = [result_lines.length, expected_lines.length].max

  puts "\nLine-by-line comparison:"
  max_lines.times do |i|
    r_line = result_lines[i]&.chomp || "(missing)"
    e_line = expected_lines[i]&.chomp || "(missing)"

    if r_line == e_line
      # Only show context around differences
    else
      puts "  Line #{i + 1}:"
      puts "    Expected: #{e_line.inspect}"
      puts "    Got:      #{r_line.inspect}"
    end
  end
end

# Check specific requirements
puts "\n" + "=" * 80
puts "SPECIFIC CHECKS"
puts "=" * 80

lines = result.content.lines

# Check 1: Link definitions are on separate lines (not concatenated)
link_def_pattern = /^\[.+\]:\s/
concatenated = lines.any? { |l| l.scan(link_def_pattern).length > 1 }
if concatenated
  puts "❌ FAIL: Found concatenated link definitions"
else
  puts "✅ PASS: Link definitions are on separate lines"
end

# Check 2: Headings have blank line before them (except first line)
heading_issues = []
lines.each_with_index do |line, idx|
  next if idx == 0
  next unless line.match?(/^#+\s/)

  prev_line = lines[idx - 1]
  unless prev_line.strip.empty?
    heading_issues << "Line #{idx + 1}: Heading '#{line.chomp}' has no blank line before it"
  end
end

if heading_issues.empty?
  puts "✅ PASS: All headings have blank lines before them"
else
  puts "❌ FAIL: Some headings missing blank lines before:"
  heading_issues.each { |issue| puts "    #{issue}" }
end

# Check 3: Consecutive link definitions have no blank lines between them
link_def_lines = []
lines.each_with_index do |line, idx|
  link_def_lines << idx if line.match?(link_def_pattern)
end

gaps_between_link_defs = []
link_def_lines.each_cons(2) do |prev_idx, curr_idx|
  if curr_idx != prev_idx + 1
    # Check if there are only blank lines between them
    between = lines[(prev_idx + 1)...curr_idx]
    if between.all? { |l| l.strip.empty? }
      gaps_between_link_defs << "Gap between lines #{prev_idx + 1} and #{curr_idx + 1}"
    end
  end
end

if gaps_between_link_defs.empty?
  puts "✅ PASS: No blank lines between consecutive link definitions"
else
  puts "❌ FAIL: Found blank lines between link definitions:"
  gaps_between_link_defs.each { |gap| puts "    #{gap}" }
end

puts "\nDone."
