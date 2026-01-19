# frozen_string_literal: true

# Shared test helpers for markdown-merge specs
#
# These helpers create properly configured test nodes using TreeHaver::RSpec::TestableNode.
# This provides real TreeHaver::Node behavior instead of fragile mocks.

require "tree_haver/rspec/testable_node"

module MarkdownMergeSpecHelpers
  # Creates a test node using TestableNode.
  #
  # This creates a real TreeHaver::Node with controlled data, which is more
  # reliable than mocks because it uses the actual TreeHaver::Node implementation.
  #
  # @param type [Symbol] The node type (e.g., :table, :paragraph, :heading)
  # @param text [String] The text content of the node
  # @param start_line [Integer] 1-based start line number
  # @param options [Hash] Additional options passed to TestableNode.create
  # @return [TreeHaver::RSpec::TestableNode] A real node with controlled data
  def create_test_node(type, text: "", start_line: 1, **options)
    TestableNode.create(type: type, text: text, start_line: start_line, **options)
  end

  # Creates a test table node with proper type and structure
  #
  # @param rows [Array<Hash>] Row specifications for child nodes
  # @param text [String] The table text content
  # @return [TreeHaver::RSpec::TestableNode] A test table node
  def create_test_table_node(rows: [], text: "")
    TestableNode.create(
      type: :table,
      text: text,
      start_line: 1,
      children: rows.map.with_index do |row, idx|
        {type: :table_row, text: row[:text] || "", start_row: idx}
      end,
    )
  end

  # Creates a test table row node
  #
  # @param cells [Array<String>] Cell text contents
  # @param start_line [Integer] 1-based start line
  # @return [TreeHaver::RSpec::TestableNode] A test table row node
  def create_test_row_node(cells: [], start_line: 1)
    TestableNode.create(
      type: :table_row,
      text: cells.join(" | "),
      start_line: start_line,
      children: cells.map.with_index do |cell_text, idx|
        {type: :table_cell, text: cell_text, start_column: idx * 10}
      end,
    )
  end

  # Creates a test table cell node
  #
  # @param content [String] The cell text content
  # @param start_line [Integer] 1-based start line
  # @return [TreeHaver::RSpec::TestableNode] A test table cell node
  def create_test_cell_node(content: "", start_line: 1)
    TestableNode.create(
      type: :table_cell,
      text: content,
      start_line: start_line,
      children: [{type: :text, text: content, start_row: 0}],
    )
  end

  # Creates a test paragraph node
  #
  # @param content [String] The paragraph text content
  # @param start_line [Integer] 1-based start line
  # @return [TreeHaver::RSpec::TestableNode] A test paragraph node
  def create_test_paragraph_node(content: "", start_line: 1)
    TestableNode.create(
      type: :paragraph,
      text: content,
      start_line: start_line,
      children: [{type: :text, text: content, start_row: 0}],
    )
  end

  # Creates a test heading node
  #
  # @param level [Integer] The heading level (1-6)
  # @param content [String] The heading text content
  # @param start_line [Integer] 1-based start line
  # @return [TreeHaver::RSpec::TestableNode] A test heading node
  def create_test_heading_node(level: 1, content: "", start_line: 1)
    prefix = "#" * level
    TestableNode.create(
      type: :heading,
      text: "#{prefix} #{content}",
      start_line: start_line,
      children: [{type: :text, text: content, start_row: 0}],
    )
  end

  # Creates a test code block node
  #
  # @param content [String] The code content
  # @param language [String, nil] The fence info/language
  # @param start_line [Integer] 1-based start line
  # @return [TreeHaver::RSpec::TestableNode] A test code block node
  def create_test_code_block_node(content: "", language: nil, start_line: 1)
    text = language ? "```#{language}\n#{content}\n```" : "```\n#{content}\n```"
    TestableNode.create(
      type: :code_block,
      text: text,
      start_line: start_line,
    )
  end

  # Creates a test list node
  #
  # @param items [Array<String>] List item contents
  # @param ordered [Boolean] Whether the list is ordered
  # @param start_line [Integer] 1-based start line
  # @return [TreeHaver::RSpec::TestableNode] A test list node
  def create_test_list_node(items: [], ordered: false, start_line: 1)
    marker = ordered ? "1." : "-"
    text = items.map { |item| "#{marker} #{item}" }.join("\n")
    TestableNode.create(
      type: :list,
      text: text,
      start_line: start_line,
      children: items.map.with_index do |item, idx|
        {type: :list_item, text: "#{marker} #{item}", start_row: idx}
      end,
    )
  end

  # Creates a test block quote node
  #
  # @param content [String] The quote content
  # @param start_line [Integer] 1-based start line
  # @return [TreeHaver::RSpec::TestableNode] A test block quote node
  def create_test_block_quote_node(content: "", start_line: 1)
    text = content.lines.map { |line| "> #{line}" }.join
    TestableNode.create(
      type: :block_quote,
      text: text,
      start_line: start_line,
      children: [{type: :paragraph, text: content, start_row: 0}],
    )
  end

  # Creates a test thematic break node
  #
  # @param start_line [Integer] 1-based start line
  # @return [TreeHaver::RSpec::TestableNode] A test thematic break node
  def create_test_thematic_break_node(start_line: 1)
    TestableNode.create(
      type: :thematic_break,
      text: "---",
      start_line: start_line,
    )
  end

  # Creates a test HTML block node
  #
  # @param content [String] The HTML content
  # @param start_line [Integer] 1-based start line
  # @return [TreeHaver::RSpec::TestableNode] A test HTML block node
  def create_test_html_block_node(content: "", start_line: 1)
    TestableNode.create(
      type: :html_block,
      text: content,
      start_line: start_line,
    )
  end

  # ============================================================
  # Legacy mock helpers (deprecated - use create_test_* methods)
  # ============================================================
  # These are kept for backward compatibility but should be migrated
  # to TestableNode-based helpers.

  # @deprecated Use create_test_node instead
  def create_mock_node(type, name: "MockNode", **options)
    node = double(name)

    allow(node).to receive_messages(
      type: type,
      merge_type: type,
      children: options.fetch(:children, []),
      first_child: options.fetch(:first_child, nil),
      string_content: options.fetch(:string_content, nil),
      source_position: options.fetch(:source_position, {start_line: 1, end_line: 1, start_column: 0, end_column: 0}),
    )

    known_methods = [:type, :merge_type, :children, :first_child, :string_content, :source_position]
    allow(node).to receive(:respond_to?) do |method_name, *|
      known_methods.include?(method_name) || options.key?(method_name)
    end

    node
  end

  # @deprecated Use create_test_table_node instead
  def create_mock_table_node(rows: [])
    create_mock_node(:table, name: "TableNode", children: rows, first_child: rows.first)
  end

  # @deprecated Use create_test_row_node instead
  def create_mock_row_node(cells: [])
    create_mock_node(:table_row, name: "TableRowNode", children: cells)
  end

  # @deprecated Use create_test_cell_node instead
  def create_mock_cell_node(content: "")
    text_node = create_mock_node(:text, name: "TextNode", string_content: content)
    create_mock_node(:table_cell, name: "TableCellNode", children: [text_node], string_content: content)
  end

  # @deprecated Use create_test_paragraph_node instead
  def create_mock_paragraph_node(content: "")
    text_node = create_mock_node(:text, name: "TextNode", string_content: content)
    create_mock_node(:paragraph, name: "ParagraphNode", children: [text_node], string_content: content)
  end

  # @deprecated Use create_test_heading_node instead
  def create_mock_heading_node(level: 1, content: "")
    node = create_mock_node(:heading, name: "HeadingNode", string_content: content)
    allow(node).to receive_messages(heading_level: level, level: level)
    allow(node).to receive(:respond_to?) do |method_name, *|
      [:type, :merge_type, :children, :first_child, :string_content, :source_position, :heading_level, :level].include?(method_name)
    end
    node
  end

  # Creates a mock wrapper node (typed_node? returns true)
  # This simulates Ast::Merge::NodeTyping::Wrapper
  #
  # @param inner_node [Object] The wrapped inner node
  # @param merge_type [Symbol] The canonical merge type
  # @return [RSpec::Mocks::Double] A mock wrapper node
  def create_mock_wrapper_node(inner_node, merge_type:)
    wrapper = double("WrapperNode")

    allow(wrapper).to receive_messages(
      typed_node?: true,
      merge_type: merge_type,
      node: inner_node,
      inner_node: inner_node,
    )

    allow(wrapper).to receive(:type).and_return(inner_node.type) if inner_node.respond_to?(:type)

    allow(wrapper).to receive(:respond_to?) do |method_name, *|
      [:typed_node?, :merge_type, :type, :node, :inner_node].include?(method_name)
    end

    wrapper
  end
end

RSpec.configure do |config|
  config.include MarkdownMergeSpecHelpers
end
