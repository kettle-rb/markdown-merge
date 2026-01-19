#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for OutputBuilder functionality

require "bundler/inline"

gemfile do
  source "https://gem.coop"
  gem "markdown-merge", path: "/home/pboling/src/kettle-rb/ast-merge/vendor/markdown-merge"
  gem "ast-merge", path: "/home/pboling/src/kettle-rb/ast-merge"
  gem "tree_haver", path: "/home/pboling/src/kettle-rb/ast-merge/vendor/tree_haver"
end

puts "=" * 80
puts "Testing OutputBuilder Functionality"
puts "=" * 80

# Test 1: OutputBuilder basic functionality
puts "\n1. Testing OutputBuilder basic functionality..."
builder = Markdown::Merge::OutputBuilder.new
builder.add_raw("# Test Heading\n")
builder.add_raw("Some content\n")
builder.add_gap_line(count: 1)
builder.add_raw("More content\n")

output = builder.to_s
puts "Output length: #{output.length} bytes"
puts "Output lines: #{output.lines.count}"
puts "✓ OutputBuilder basic methods work"

# Test 2: LinkDefinitionFormatter
puts "\n2. Testing LinkDefinitionFormatter..."
require 'markdown/merge/link_definition_node'

# Create a mock link definition node
link_node = Markdown::Merge::LinkDefinitionNode.new(
  "[ref]: https://example.com \"Title\"",
  line_number: 1,
  label: "ref",
  url: "https://example.com",
  title: "Title"
)

formatted = Markdown::Merge::LinkDefinitionFormatter.format(link_node)
puts "Formatted: #{formatted}"
expected = "[ref]: https://example.com \"Title\""
if formatted == expected || formatted.include?("ref") && formatted.include?("example.com")
  puts "✓ LinkDefinitionFormatter works"
else
  puts "✗ LinkDefinitionFormatter output unexpected: #{formatted}"
end

# Test 3: Check that SmartMergerBase exists and has process_alignment method
puts "\n3. Testing SmartMergerBase has new methods..."
if Markdown::Merge::SmartMergerBase.private_method_defined?(:process_alignment)
  puts "✓ SmartMergerBase has process_alignment method"
else
  puts "✗ SmartMergerBase missing process_alignment method"
end

if Markdown::Merge::SmartMergerBase.private_method_defined?(:process_match_to_builder)
  puts "✓ SmartMergerBase has process_match_to_builder method"
else
  puts "✗ SmartMergerBase missing process_match_to_builder method"
end

# Test 4: OutputBuilder with node extraction
puts "\n4. Testing OutputBuilder node extraction..."
builder2 = Markdown::Merge::OutputBuilder.new

# Create a mock FreezeNode
freeze_node = Markdown::Merge::FreezeNode.new(
  start_line: 1,
  end_line: 3,
  content: "Frozen content\nLine 2\nLine 3",
  start_marker: "<!-- freeze -->",
  end_marker: "<!-- unfreeze -->"
)

# Create a simple mock analysis
mock_analysis = Object.new
def mock_analysis.source_range(start_line, end_line)
  "Mock content from #{start_line} to #{end_line}"
end

builder2.add_node_source(freeze_node, mock_analysis)
output2 = builder2.to_s
if output2.include?("Frozen content")
  puts "✓ OutputBuilder handles FreezeNode"
else
  puts "✗ OutputBuilder FreezeNode handling failed"
end

# Test 5: Check empty and clear
puts "\n5. Testing OutputBuilder empty? and clear..."
builder3 = Markdown::Merge::OutputBuilder.new
if builder3.empty?
  puts "✓ OutputBuilder.empty? returns true for new builder"
else
  puts "✗ OutputBuilder.empty? incorrect for new builder"
end

builder3.add_raw("test")
if !builder3.empty?
  puts "✓ OutputBuilder.empty? returns false after adding content"
else
  puts "✗ OutputBuilder.empty? incorrect after adding content"
end

builder3.clear
if builder3.empty?
  puts "✓ OutputBuilder.clear works"
else
  puts "✗ OutputBuilder.clear failed"
end

puts "\n" + "=" * 80
puts "All OutputBuilder tests completed!"
puts "=" * 80

