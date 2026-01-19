#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to investigate spurious blank lines being created during merge.
#
# The bug: When merging a template section into a destination, blank lines are
# being created that don't exist in either the template OR the destination.
#
# Run from anywhere:
#   ruby vendor/markdown-merge/examples/debug_spurious_newlines.rb

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

# Simple template with consecutive link reference definitions (no blank lines between)
TEMPLATE = <<~MD
  ### Test Section

  Some paragraph text.

  [link1]: https://example.com/1
  [link2]: https://example.com/2
  [link3]: https://example.com/3
MD

# Destination with the same section but different content
DESTINATION = <<~MD
  # Main Title

  Some intro text.

  ### Test Section

  Old paragraph text.

  [old-link]: https://old.example.com

  ## Next Section

  Content after.
MD

puts "=" * 80
puts "INVESTIGATING SPURIOUS BLANK LINES BUG"
puts "=" * 80

puts "\n--- TEMPLATE (#{TEMPLATE.lines.count} lines) ---"
puts TEMPLATE
puts "--- END TEMPLATE ---"

puts "\n--- DESTINATION (#{DESTINATION.lines.count} lines) ---"
puts DESTINATION
puts "--- END DESTINATION ---"

# First, let's analyze what nodes are created from the template
puts "\n" + "=" * 80
puts "STEP 1: Analyze Template Parsing"
puts "=" * 80

template_analysis = Markdown::Merge::FileAnalysis.new(TEMPLATE, backend: :markly)

puts "\nTemplate statements (#{template_analysis.statements.count} total):"
template_analysis.statements.each_with_index do |stmt, idx|
  pos = stmt.source_position
  type_info = if stmt.respond_to?(:merge_type)
    "merge_type=#{stmt.merge_type}"
  elsif stmt.respond_to?(:type)
    "type=#{stmt.type}"
  else
    "class=#{stmt.class.name}"
  end

  content_preview = if stmt.respond_to?(:content)
    stmt.content[0..50].inspect
  elsif stmt.respond_to?(:text)
    stmt.text[0..50].inspect
  else
    "(no content method)"
  end

  puts "  [#{idx}] #{type_info} @ line #{pos&.dig(:start_line) || '?'}: #{content_preview}"
end

# Now analyze destination
puts "\n" + "=" * 80
puts "STEP 2: Analyze Destination Parsing"
puts "=" * 80

dest_analysis = Markdown::Merge::FileAnalysis.new(DESTINATION, backend: :markly)

puts "\nDestination statements (#{dest_analysis.statements.count} total):"
dest_analysis.statements.each_with_index do |stmt, idx|
  pos = stmt.source_position
  type_info = if stmt.respond_to?(:merge_type)
    "merge_type=#{stmt.merge_type}"
  elsif stmt.respond_to?(:type)
    "type=#{stmt.type}"
  else
    "class=#{stmt.class.name}"
  end

  content_preview = if stmt.respond_to?(:content)
    stmt.content[0..50].inspect
  elsif stmt.respond_to?(:text)
    stmt.text[0..50].inspect
  else
    "(no content method)"
  end

  puts "  [#{idx}] #{type_info} @ line #{pos&.dig(:start_line) || '?'}: #{content_preview}"
end

# Now perform the partial merge
puts "\n" + "=" * 80
puts "STEP 3: Perform Partial Template Merge"
puts "=" * 80

merger = Markdown::Merge::PartialTemplateMerger.new(
  template: TEMPLATE,
  destination: DESTINATION,
  anchor: { type: :heading, text: /Test Section/ },
  boundary: { type: :heading, same_or_shallower: true },
  backend: :markly,
  replace_mode: true,  # Full replacement like the gem_family_section recipe
)

result = merger.merge

puts "\nMerge result:"
puts "  has_section: #{result.has_section}"
puts "  changed: #{result.changed}"
puts "  message: #{result.message}"

puts "\n--- MERGED CONTENT (#{result.content.lines.count} lines) ---"
result.content.each_line.with_index(1) do |line, num|
  # Show blank lines explicitly
  display = line.chomp.empty? ? "(blank)" : line.chomp
  puts "  #{num.to_s.rjust(3)}: #{display}"
end
puts "--- END MERGED CONTENT ---"

# Count blank lines in each
template_blanks = TEMPLATE.lines.count { |l| l.strip.empty? }
dest_blanks = DESTINATION.lines.count { |l| l.strip.empty? }
result_blanks = result.content.lines.count { |l| l.strip.empty? }

puts "\n" + "=" * 80
puts "ANALYSIS"
puts "=" * 80
puts "Template blank lines: #{template_blanks}"
puts "Destination blank lines: #{dest_blanks}"
puts "Result blank lines: #{result_blanks}"

# Check for consecutive blank lines (the bug symptom)
consecutive_blanks = result.content.scan(/\n{3,}/).map(&:length)
if consecutive_blanks.any?
  puts "\n⚠️  FOUND CONSECUTIVE BLANK LINES (3+ newlines in a row):"
  consecutive_blanks.each_with_index do |count, idx|
    puts "  Occurrence #{idx + 1}: #{count} consecutive newlines (#{count - 1} blank lines)"
  end
else
  puts "\n✅ No excessive consecutive blank lines found"
end

# Check for blank lines between link definitions
puts "\n" + "=" * 80
puts "CHECKING LINK DEFINITION SPACING"
puts "=" * 80

lines = result.content.lines
link_def_pattern = /^\[([^\]]+)\]:\s+/

lines.each_with_index do |line, idx|
  next unless line.match?(link_def_pattern)

  # Check previous line
  if idx > 0 && lines[idx - 1].strip.empty?
    prev_prev = idx > 1 ? lines[idx - 2] : nil
    if prev_prev&.match?(link_def_pattern)
      puts "⚠️  Line #{idx + 1}: Link def has blank line before it (prev link def on line #{idx - 1})"
      puts "    Prev: #{lines[idx - 2].chomp.inspect}" if prev_prev
      puts "    Blank: #{lines[idx - 1].inspect}"
      puts "    This: #{line.chomp.inspect}"
    end
  end
end

puts "\nDone."

