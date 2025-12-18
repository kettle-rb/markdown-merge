# frozen_string_literal: true

# Shared test helpers for markdown-merge specs
#
# These helpers create properly configured mock nodes that work with
# the node type checking in ast-merge and markdown-merge.

module MarkdownMergeSpecHelpers
  # Creates a mock node that properly handles all respond_to? calls
  # and has the standard type/merge_type interface.
  #
  # @param type [Symbol] The node type (e.g., :table, :paragraph, :heading)
  # @param name [String] The double name for debugging
  # @param options [Hash] Additional options
  # @option options [Array<Object>] :children Child nodes to return
  # @option options [Object] :first_child First child node
  # @option options [String] :string_content String content for the node
  # @option options [Hash] :source_position Source position hash
  # @return [RSpec::Mocks::Double] A properly configured mock node
  def create_mock_node(type, name: "MockNode", **options)
    node = double(name)

    # Core type methods
    allow(node).to receive(:type).and_return(type)
    allow(node).to receive(:merge_type).and_return(type)

    # Handle respond_to? flexibly - return true for common methods
    known_methods = [:type, :merge_type, :children, :first_child, :string_content, :source_position]
    allow(node).to receive(:respond_to?) do |method_name, *|
      known_methods.include?(method_name) || options.key?(method_name)
    end

    # Optional methods with defaults
    allow(node).to receive(:children).and_return(options.fetch(:children, []))
    allow(node).to receive(:first_child).and_return(options.fetch(:first_child, nil))
    allow(node).to receive(:string_content).and_return(options.fetch(:string_content, nil))
    allow(node).to receive(:source_position).and_return(
      options.fetch(:source_position, {start_line: 1, end_line: 1, start_column: 0, end_column: 0})
    )

    node
  end

  # Creates a mock table node with proper type and structure
  #
  # @param rows [Array<Object>] Row nodes to include in the table
  # @return [RSpec::Mocks::Double] A mock table node
  def create_mock_table_node(rows: [])
    create_mock_node(:table, name: "TableNode", children: rows, first_child: rows.first)
  end

  # Creates a mock table row node
  #
  # @param cells [Array<Object>] Cell nodes to include in the row
  # @return [RSpec::Mocks::Double] A mock table row node
  def create_mock_row_node(cells: [])
    create_mock_node(:table_row, name: "TableRowNode", children: cells)
  end

  # Creates a mock table cell node
  #
  # @param content [String] The cell text content
  # @return [RSpec::Mocks::Double] A mock table cell node
  def create_mock_cell_node(content: "")
    text_node = create_mock_node(:text, name: "TextNode", string_content: content)
    create_mock_node(:table_cell, name: "TableCellNode", children: [text_node], string_content: content)
  end

  # Creates a mock paragraph node
  #
  # @param content [String] The paragraph text content
  # @return [RSpec::Mocks::Double] A mock paragraph node
  def create_mock_paragraph_node(content: "")
    text_node = create_mock_node(:text, name: "TextNode", string_content: content)
    create_mock_node(:paragraph, name: "ParagraphNode", children: [text_node], string_content: content)
  end

  # Creates a mock heading node
  #
  # @param level [Integer] The heading level (1-6)
  # @param content [String] The heading text content
  # @return [RSpec::Mocks::Double] A mock heading node
  def create_mock_heading_node(level: 1, content: "")
    node = create_mock_node(:heading, name: "HeadingNode", string_content: content)
    allow(node).to receive(:heading_level).and_return(level)
    allow(node).to receive(:level).and_return(level)
    # Update respond_to? to include heading_level
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

    # Wrapper-specific methods
    allow(wrapper).to receive(:typed_node?).and_return(true)
    allow(wrapper).to receive(:merge_type).and_return(merge_type)
    allow(wrapper).to receive(:node).and_return(inner_node)
    allow(wrapper).to receive(:inner_node).and_return(inner_node)

    # Delegate type to inner node
    allow(wrapper).to receive(:type).and_return(inner_node.type) if inner_node.respond_to?(:type)

    # Handle respond_to? - typed_node? is the key differentiator
    allow(wrapper).to receive(:respond_to?) do |method_name, *|
      [:typed_node?, :merge_type, :type, :node, :inner_node].include?(method_name)
    end

    wrapper
  end
end

RSpec.configure do |config|
  config.include MarkdownMergeSpecHelpers
end

