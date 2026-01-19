# frozen_string_literal: true

RSpec.describe Markdown::Merge::TableMatchAlgorithm do
  let(:algorithm) { described_class.new }

  describe "constants" do
    describe "DEFAULT_WEIGHTS" do
      it "has header_match weight" do
        expect(described_class::DEFAULT_WEIGHTS[:header_match]).to eq(0.25)
      end

      it "has first_column weight" do
        expect(described_class::DEFAULT_WEIGHTS[:first_column]).to eq(0.20)
      end

      it "has row_content weight" do
        expect(described_class::DEFAULT_WEIGHTS[:row_content]).to eq(0.25)
      end

      it "has total_cells weight" do
        expect(described_class::DEFAULT_WEIGHTS[:total_cells]).to eq(0.15)
      end

      it "has position weight" do
        expect(described_class::DEFAULT_WEIGHTS[:position]).to eq(0.15)
      end

      it "weights sum to 1.0" do
        total = described_class::DEFAULT_WEIGHTS.values.sum
        expect(total).to be_within(0.001).of(1.0)
      end
    end

    it "has FIRST_COLUMN_SIMILARITY_THRESHOLD" do
      expect(described_class::FIRST_COLUMN_SIMILARITY_THRESHOLD).to eq(0.7)
    end
  end

  describe "#initialize" do
    it "accepts no arguments" do
      alg = described_class.new
      expect(alg).to be_a(described_class)
    end

    it "accepts position_a parameter" do
      alg = described_class.new(position_a: 1)
      expect(alg.position_a).to eq(1)
    end

    it "accepts position_b parameter" do
      alg = described_class.new(position_b: 2)
      expect(alg.position_b).to eq(2)
    end

    it "accepts total_tables_a parameter" do
      alg = described_class.new(total_tables_a: 5)
      expect(alg.total_tables_a).to eq(5)
    end

    it "accepts total_tables_b parameter" do
      alg = described_class.new(total_tables_b: 3)
      expect(alg.total_tables_b).to eq(3)
    end

    it "enforces minimum of 1 for total_tables_a" do
      alg = described_class.new(total_tables_a: 0)
      expect(alg.total_tables_a).to eq(1)
    end

    it "enforces minimum of 1 for total_tables_b" do
      alg = described_class.new(total_tables_b: -1)
      expect(alg.total_tables_b).to eq(1)
    end

    it "accepts custom weights" do
      custom_weights = {header_match: 0.5}
      alg = described_class.new(weights: custom_weights)
      expect(alg.weights[:header_match]).to eq(0.5)
    end

    it "merges custom weights with defaults" do
      custom_weights = {header_match: 0.5}
      alg = described_class.new(weights: custom_weights)
      expect(alg.weights[:first_column]).to eq(0.20) # Default preserved
    end
  end

  describe "#call" do
    let(:mock_table_a) do
      # Create a simple table structure with header and rows
      create_mock_table([
        ["Name", "Age", "City"],     # Header
        ["Alice", "30", "New York"],
        ["Bob", "25", "Los Angeles"],
      ])
    end

    let(:mock_table_b) do
      create_mock_table([
        ["Name", "Age", "City"],     # Header
        ["Alice", "30", "New York"],
        ["Bob", "25", "Los Angeles"],
      ])
    end

    def create_mock_table(rows_data)
      table = double("Table")
      first_row = nil
      prev_row = nil

      rows_data.each_with_index do |cells_data, idx|
        row_type = (idx == 0) ? :table_header : :table_row
        row = create_mock_row(cells_data, row_type)

        if idx == 0
          first_row = row
        else
          allow(prev_row).to receive(:next_sibling).and_return(row)
        end
        prev_row = row
      end

      allow(prev_row).to receive(:next_sibling).and_return(nil) if prev_row
      allow(table).to receive(:first_child).and_return(first_row)
      table
    end

    def create_mock_row(cells_data, row_type)
      row = double("Row")
      allow(row).to receive_messages(type: row_type, merge_type: row_type)
      allow(row).to receive(:respond_to?) { |m, *| [:type, :merge_type, :next_sibling, :first_child].include?(m) }

      first_cell = nil
      prev_cell = nil

      cells_data.each do |text|
        cell = create_mock_cell(text)

        if first_cell.nil?
          first_cell = cell
        else
          allow(prev_cell).to receive(:next_sibling).and_return(cell)
        end
        prev_cell = cell
      end

      allow(prev_cell).to receive(:next_sibling).and_return(nil) if prev_cell
      allow(row).to receive(:first_child).and_return(first_cell)
      row
    end

    def create_mock_cell(text)
      # Create a text child node
      text_node = double("TextNode")
      allow(text_node).to receive_messages(type: :text, merge_type: :text, string_content: text, children: [], first_child: nil)
      allow(text_node).to receive(:respond_to?) { |m, *| [:type, :merge_type, :string_content, :children, :first_child, :next_sibling].include?(m) }

      cell = double("Cell")
      allow(cell).to receive_messages(type: :table_cell, merge_type: :table_cell, string_content: text, children: [text_node], first_child: text_node)
      allow(cell).to receive(:respond_to?) { |m, *| [:type, :merge_type, :next_sibling, :string_content, :walk, :children, :first_child].include?(m) }

      # Support both walk and children/first_child patterns for compatibility
      allow(cell).to receive(:walk).and_yield(text_node)
      allow(text_node).to receive(:next_sibling).and_return(nil)
      cell
    end

    context "with identical tables" do
      it "returns high score close to 1.0" do
        score = algorithm.call(mock_table_a, mock_table_b)
        expect(score).to be >= 0.9
      end
    end

    context "with empty tables" do
      let(:empty_table) do
        table = double("EmptyTable")
        allow(table).to receive(:first_child).and_return(nil)
        table
      end

      it "returns 0.0 when first table is empty" do
        score = algorithm.call(empty_table, mock_table_b)
        expect(score).to eq(0.0)
      end

      it "returns 0.0 when second table is empty" do
        score = algorithm.call(mock_table_a, empty_table)
        expect(score).to eq(0.0)
      end

      it "returns 0.0 when both tables are empty" do
        score = algorithm.call(empty_table, empty_table)
        expect(score).to eq(0.0)
      end
    end

    context "with different tables" do
      let(:different_table) do
        create_mock_table([
          ["Product", "Price", "Quantity"],
          ["Widget", "$10", "100"],
          ["Gadget", "$25", "50"],
        ])
      end

      it "returns lower score for different tables" do
        score = algorithm.call(mock_table_a, different_table)
        expect(score).to be < 0.5
      end
    end

    context "with similar tables" do
      let(:similar_table) do
        create_mock_table([
          ["Name", "Age", "Location"],  # City -> Location
          ["Alice", "31", "New York"],  # 30 -> 31
          ["Bob", "25", "LA"],          # Los Angeles -> LA
        ])
      end

      it "returns moderate score for similar tables" do
        score = algorithm.call(mock_table_a, similar_table)
        expect(score).to be_between(0.3, 0.9)
      end
    end

    context "with position information" do
      it "scores higher for tables at same position" do
        alg_same = described_class.new(position_a: 0, position_b: 0, total_tables_a: 3, total_tables_b: 3)
        alg_diff = described_class.new(position_a: 0, position_b: 2, total_tables_a: 3, total_tables_b: 3)

        score_same = alg_same.call(mock_table_a, mock_table_b)
        score_diff = alg_diff.call(mock_table_a, mock_table_b)

        expect(score_same).to be >= score_diff
      end
    end
  end

  describe "#levenshtein_distance (private)" do
    it "returns 0 for identical strings" do
      result = algorithm.send(:levenshtein_distance, "hello", "hello")
      expect(result).to eq(0)
    end

    it "returns length of other string when one is empty" do
      expect(algorithm.send(:levenshtein_distance, "", "hello")).to eq(5)
      expect(algorithm.send(:levenshtein_distance, "world", "")).to eq(5)
    end

    it "returns correct distance for simple substitution" do
      result = algorithm.send(:levenshtein_distance, "cat", "bat")
      expect(result).to eq(1)
    end

    it "returns correct distance for insertion" do
      result = algorithm.send(:levenshtein_distance, "cat", "cats")
      expect(result).to eq(1)
    end

    it "returns correct distance for deletion" do
      result = algorithm.send(:levenshtein_distance, "cats", "cat")
      expect(result).to eq(1)
    end

    it "handles complex differences" do
      result = algorithm.send(:levenshtein_distance, "kitten", "sitting")
      expect(result).to eq(3) # k->s, e->i, +g
    end
  end

  describe "#string_similarity (private)" do
    it "returns 1.0 for identical strings" do
      result = algorithm.send(:string_similarity, "hello", "hello")
      expect(result).to eq(1.0)
    end

    it "returns 1.0 for both empty strings" do
      result = algorithm.send(:string_similarity, "", "")
      expect(result).to eq(1.0)
    end

    it "returns 0.0 when only one string is empty" do
      expect(algorithm.send(:string_similarity, "", "hello")).to eq(0.0)
      expect(algorithm.send(:string_similarity, "world", "")).to eq(0.0)
    end

    it "returns high similarity for similar strings" do
      result = algorithm.send(:string_similarity, "Values", "Value")
      expect(result).to be > 0.8
    end

    it "returns low similarity for different strings" do
      result = algorithm.send(:string_similarity, "apple", "orange")
      expect(result).to be < 0.5
    end
  end

  describe "attribute readers" do
    let(:configured_algorithm) do
      described_class.new(
        position_a: 1,
        position_b: 2,
        total_tables_a: 5,
        total_tables_b: 6,
        weights: {header_match: 0.3},
      )
    end

    it "exposes position_a" do
      expect(configured_algorithm.position_a).to eq(1)
    end

    it "exposes position_b" do
      expect(configured_algorithm.position_b).to eq(2)
    end

    it "exposes total_tables_a" do
      expect(configured_algorithm.total_tables_a).to eq(5)
    end

    it "exposes total_tables_b" do
      expect(configured_algorithm.total_tables_b).to eq(6)
    end

    it "exposes weights" do
      expect(configured_algorithm.weights).to be_a(Hash)
      expect(configured_algorithm.weights[:header_match]).to eq(0.3)
    end
  end

  describe "#next_sibling (private)" do
    it "uses next_sibling method when available" do
      node = double("Node")
      sibling = double("Sibling")
      allow(node).to receive(:respond_to?).with(:next_sibling).and_return(true)
      allow(node).to receive(:next_sibling).and_return(sibling)

      result = algorithm.send(:next_sibling, node)
      expect(result).to eq(sibling)
    end

    it "falls back to next method when next_sibling not available" do
      node = double("Node")
      sibling = double("Sibling")
      allow(node).to receive(:respond_to?).with(:next_sibling).and_return(false)
      allow(node).to receive(:respond_to?).with(:next).and_return(true)
      allow(node).to receive(:next).and_return(sibling)

      result = algorithm.send(:next_sibling, node)
      expect(result).to eq(sibling)
    end

    it "returns nil when neither method available" do
      node = double("Node")
      allow(node).to receive(:respond_to?).and_return(false)

      result = algorithm.send(:next_sibling, node)
      expect(result).to be_nil
    end
  end

  describe "#table_row_type? (private)" do
    it "returns true for :table_row type" do
      node = double("Row")
      allow(node).to receive_messages(type: :table_row, merge_type: :table_row)
      allow(node).to receive(:respond_to?) { |m, *| [:type, :merge_type].include?(m) }

      expect(algorithm.send(:table_row_type?, node)).to be(true)
    end

    it "returns true for :table_header type" do
      node = double("Header")
      allow(node).to receive_messages(type: :table_header, merge_type: :table_header)
      allow(node).to receive(:respond_to?) { |m, *| [:type, :merge_type].include?(m) }

      expect(algorithm.send(:table_row_type?, node)).to be(true)
    end

    it "returns false for other types" do
      node = double("Cell")
      allow(node).to receive_messages(type: :table_cell, merge_type: :table_cell)
      allow(node).to receive(:respond_to?) { |m, *| [:type, :merge_type].include?(m) }

      expect(algorithm.send(:table_row_type?, node)).to be(false)
    end

    it "returns false when node doesn't respond to type" do
      node = double("Unknown")
      allow(node).to receive(:respond_to?).and_return(false)

      expect(algorithm.send(:table_row_type?, node)).to be(false)
    end
  end

  describe "#extract_cells (private)" do
    def create_mock_cell(text)
      text_node = double("TextNode")
      allow(text_node).to receive_messages(type: :text, merge_type: :text, string_content: text, children: [], first_child: nil, next_sibling: nil)
      allow(text_node).to receive(:respond_to?) { |m, *| [:type, :merge_type, :string_content, :children, :first_child, :next_sibling].include?(m) }

      cell = double("Cell")
      allow(cell).to receive_messages(type: :table_cell, merge_type: :table_cell, children: [text_node], first_child: text_node)
      allow(cell).to receive(:respond_to?) { |m, *| [:type, :merge_type, :next_sibling, :walk, :children, :first_child].include?(m) }
      allow(cell).to receive(:walk).and_yield(text_node)
      cell
    end

    it "extracts cells from a row" do
      cell1 = create_mock_cell("A")
      cell2 = create_mock_cell("B")
      allow(cell1).to receive(:next_sibling).and_return(cell2)
      allow(cell2).to receive(:next_sibling).and_return(nil)

      row = double("Row")
      allow(row).to receive(:first_child).and_return(cell1)

      result = algorithm.send(:extract_cells, row)
      expect(result).to eq(["A", "B"])
    end

    it "returns empty array for row with no children" do
      row = double("Row")
      allow(row).to receive(:first_child).and_return(nil)

      result = algorithm.send(:extract_cells, row)
      expect(result).to eq([])
    end

    it "skips non-cell children" do
      text_node = double("Text")
      allow(text_node).to receive_messages(type: :text, merge_type: :text, next_sibling: nil)
      allow(text_node).to receive(:respond_to?) { |m, *| [:type, :merge_type, :next_sibling].include?(m) }

      row = double("Row")
      allow(row).to receive(:first_child).and_return(text_node)

      result = algorithm.send(:extract_cells, row)
      expect(result).to eq([])
    end
  end

  describe "#compute_header_match (private)" do
    it "returns 1.0 for both empty" do
      result = algorithm.send(:compute_header_match, [[]], [[]])
      expect(result).to eq(1.0)
    end

    it "returns 0.0 when only one is empty" do
      result = algorithm.send(:compute_header_match, [["A", "B"]], [[]])
      expect(result).to eq(0.0)
    end

    it "returns high score for matching headers" do
      result = algorithm.send(:compute_header_match, [["Name", "Age"]], [["Name", "Age"]])
      expect(result).to eq(1.0)
    end

    it "handles mismatched header lengths" do
      result = algorithm.send(:compute_header_match, [["A", "B", "C"]], [["A", "B"]])
      expect(result).to be_between(0.5, 1.0)
    end
  end

  describe "#compute_first_column_match (private)" do
    it "returns 1.0 for both empty" do
      result = algorithm.send(:compute_first_column_match, [], [])
      expect(result).to eq(1.0)
    end

    it "returns 0.0 when only one is empty" do
      result = algorithm.send(:compute_first_column_match, [["A"]], [])
      expect(result).to eq(0.0)
    end

    it "returns high score for matching first columns" do
      rows_a = [["Name"], ["Alice"], ["Bob"]]
      rows_b = [["Name"], ["Alice"], ["Bob"]]
      result = algorithm.send(:compute_first_column_match, rows_a, rows_b)
      expect(result).to eq(1.0)
    end
  end

  describe "#compute_row_content_match (private)" do
    it "returns 0.0 when either is empty" do
      expect(algorithm.send(:compute_row_content_match, [], [["A"]])).to eq(0.0)
      expect(algorithm.send(:compute_row_content_match, [["A"]], [])).to eq(0.0)
    end

    it "handles nil first columns" do
      rows_a = [[nil, "B"]]
      rows_b = [["A", "B"]]
      result = algorithm.send(:compute_row_content_match, rows_a, rows_b)
      expect(result).to eq(0.0)
    end

    it "matches rows by first column similarity" do
      rows_a = [["Header"], ["Alice", "30"], ["Bob", "25"]]
      rows_b = [["Header"], ["Alice", "30"], ["Bob", "25"]]
      result = algorithm.send(:compute_row_content_match, rows_a, rows_b)
      expect(result).to be > 0.9
    end
  end

  describe "#row_match_score (private)" do
    it "returns 1.0 for empty rows" do
      result = algorithm.send(:row_match_score, [], [])
      expect(result).to eq(1.0)
    end

    it "returns 1.0 for identical rows" do
      result = algorithm.send(:row_match_score, ["A", "B"], ["A", "B"])
      expect(result).to eq(1.0)
    end

    it "handles mismatched lengths" do
      result = algorithm.send(:row_match_score, ["A", "B", "C"], ["A", "B"])
      expect(result).to be_between(0.5, 1.0)
    end

    it "handles nil values" do
      result = algorithm.send(:row_match_score, ["A", nil], ["A", "B"])
      expect(result).to be_between(0.0, 1.0)
    end
  end

  describe "#compute_total_cells_match (private)" do
    it "returns 1.0 for both empty" do
      result = algorithm.send(:compute_total_cells_match, [], [])
      expect(result).to eq(1.0)
    end

    it "returns 0.0 when only one is empty" do
      expect(algorithm.send(:compute_total_cells_match, [], [["A"]])).to eq(0.0)
      expect(algorithm.send(:compute_total_cells_match, [["A"]], [])).to eq(0.0)
    end

    it "returns high score for matching cells" do
      rows_a = [["A", "B"], ["C", "D"]]
      rows_b = [["A", "B"], ["C", "D"]]
      result = algorithm.send(:compute_total_cells_match, rows_a, rows_b)
      expect(result).to be >= 0.9
    end
  end

  describe "#compute_position_score (private)" do
    it "returns 1.0 when positions are nil" do
      alg = described_class.new(position_a: nil, position_b: nil)
      result = alg.send(:compute_position_score)
      expect(result).to eq(1.0)
    end

    it "returns 1.0 for same positions" do
      alg = described_class.new(position_a: 0, position_b: 0, total_tables_a: 5, total_tables_b: 5)
      result = alg.send(:compute_position_score)
      expect(result).to eq(1.0)
    end

    it "returns lower score for different positions" do
      alg = described_class.new(position_a: 0, position_b: 4, total_tables_a: 5, total_tables_b: 5)
      result = alg.send(:compute_position_score)
      expect(result).to be < 0.5
    end
  end

  describe "#normalize (private)" do
    it "strips whitespace" do
      result = algorithm.send(:normalize, "  hello  ")
      expect(result).to eq("hello")
    end

    it "downcases text" do
      result = algorithm.send(:normalize, "HELLO")
      expect(result).to eq("hello")
    end

    it "handles nil" do
      result = algorithm.send(:normalize, nil)
      expect(result).to eq("")
    end
  end

  describe "#weighted_average (private)" do
    it "computes weighted average correctly" do
      scores = {header_match: 1.0, first_column: 0.5, row_content: 0.5, total_cells: 0.5, position: 1.0}
      result = algorithm.send(:weighted_average, scores)
      expect(result).to be_between(0.5, 1.0)
    end

    it "returns 0.0 when weights sum to 0" do
      alg = described_class.new(weights: {header_match: 0, first_column: 0, row_content: 0, total_cells: 0, position: 0})
      result = alg.send(:weighted_average, {})
      expect(result).to eq(0.0)
    end
  end

  describe "#extract_text_content (private)" do
    it "extracts text from :text nodes" do
      text_node = double("TextNode")
      allow(text_node).to receive_messages(type: :text, merge_type: :text, string_content: "hello", children: [], first_child: nil)
      allow(text_node).to receive(:respond_to?) { |m, *| [:type, :merge_type, :string_content, :children, :first_child].include?(m) }

      node = double("Node")
      allow(node).to receive_messages(type: :paragraph, merge_type: :paragraph, children: [text_node])
      allow(node).to receive(:respond_to?) { |m, *| [:type, :merge_type, :children, :first_child].include?(m) }

      result = algorithm.send(:extract_text_content, node)
      expect(result).to eq("hello")
    end

    it "extracts text from :code nodes" do
      code_node = double("CodeNode")
      allow(code_node).to receive_messages(type: :code, merge_type: :code, string_content: "puts", children: [], first_child: nil)
      allow(code_node).to receive(:respond_to?) { |m, *| [:type, :merge_type, :string_content, :children, :first_child].include?(m) }

      node = double("Node")
      allow(node).to receive_messages(type: :paragraph, merge_type: :paragraph, children: [code_node])
      allow(node).to receive(:respond_to?) { |m, *| [:type, :merge_type, :children, :first_child].include?(m) }

      result = algorithm.send(:extract_text_content, node)
      expect(result).to eq("puts")
    end

    it "concatenates multiple text nodes" do
      text1 = double("Text1")
      allow(text1).to receive_messages(type: :text, merge_type: :text, string_content: "Hello ", children: [], first_child: nil)
      allow(text1).to receive(:respond_to?) { |m, *| [:type, :merge_type, :string_content, :children, :first_child].include?(m) }

      text2 = double("Text2")
      allow(text2).to receive_messages(type: :text, merge_type: :text, string_content: "World", children: [], first_child: nil)
      allow(text2).to receive(:respond_to?) { |m, *| [:type, :merge_type, :string_content, :children, :first_child].include?(m) }

      node = double("Node")
      allow(node).to receive_messages(type: :paragraph, merge_type: :paragraph, children: [text1, text2])
      allow(node).to receive(:respond_to?) { |m, *| [:type, :merge_type, :children, :first_child].include?(m) }

      result = algorithm.send(:extract_text_content, node)
      expect(result).to eq("Hello World")
    end

    it "falls back to text method when string_content not available" do
      text_node = double("TextNode")
      allow(text_node).to receive_messages(type: :text, merge_type: :text, text: "fallback text", children: [], first_child: nil)
      allow(text_node).to receive(:respond_to?) do |m, *|
        case m
        when :string_content then false
        when :text then true
        else [:type, :merge_type, :children, :first_child].include?(m)
        end
      end

      node = double("Node")
      allow(node).to receive_messages(type: :paragraph, merge_type: :paragraph, children: [text_node])
      allow(node).to receive(:respond_to?) { |m, *| [:type, :merge_type, :children, :first_child].include?(m) }

      result = algorithm.send(:extract_text_content, node)
      expect(result).to eq("fallback text")
    end

    it "uses first_child iteration when children not available" do
      text_node = double("TextNode")
      allow(text_node).to receive_messages(
        type: :text,
        merge_type: :text,
        string_content: "via first_child",
        next_sibling: nil,
        next: nil,
        first_child: nil,
      )
      allow(text_node).to receive(:respond_to?) do |m, *|
        [:type, :merge_type, :string_content, :next_sibling, :next, :first_child].include?(m)
      end

      node = double("Node")
      allow(node).to receive_messages(type: :paragraph, merge_type: :paragraph, first_child: text_node)
      allow(node).to receive(:respond_to?) do |m, *|
        case m
        when :children then false
        else [:type, :merge_type, :first_child].include?(m)
        end
      end

      result = algorithm.send(:extract_text_content, node)
      expect(result).to eq("via first_child")
    end

    it "handles nodes with neither string_content nor text" do
      text_node = double("TextNode")
      allow(text_node).to receive_messages(type: :text, merge_type: :text, children: [], first_child: nil)
      allow(text_node).to receive(:respond_to?) do |m, *|
        case m
        when :string_content, :text then false
        else [:type, :merge_type, :children, :first_child].include?(m)
        end
      end

      node = double("Node")
      allow(node).to receive_messages(type: :paragraph, merge_type: :paragraph, children: [text_node])
      allow(node).to receive(:respond_to?) { |m, *| [:type, :merge_type, :children, :first_child].include?(m) }

      result = algorithm.send(:extract_text_content, node)
      expect(result).to eq("")
    end
  end
end
