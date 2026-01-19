# Markdown Merge Architecture

## Overview

The markdown merge gems use a layered architecture with a shared base implementation and parser-specific wrappers.

## Architecture Layers

```
┌─────────────────────────────────────────────────────┐
│  Thin Wrappers (commonmarker-merge, markly-merge)  │
│  - Parser-specific defaults                         │
│  - Minimal subclasses                               │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│  Shared Implementation (markdown-merge)             │
│  - SmartMergerBase (orchestration)                  │
│  - OutputBuilder (output assembly)                  │
│  - FileAnalysisBase (parsing & analysis)            │
│  - FileAligner (node matching)                      │
│  - ConflictResolver (conflict resolution)           │
│  - LinkParser (PEG-based link parsing via Parslet)  │
│  - LinkReferenceRehydrator (inline→reference links) │
│  - LinkDefinitionFormatter (definition formatting)  │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│  Infrastructure (ast-merge, tree_haver, parslet)    │
│  - Parser backends                                  │
│  - AST traversal                                    │
│  - PEG parsing (via parslet gem)                    │
│  - Common utilities                                 │
└─────────────────────────────────────────────────────┘
```

## Core Components

### SmartMergerBase (markdown-merge)

Orchestrates the merge process:
1. Parses template and destination files
2. Aligns nodes between files
3. Resolves conflicts using OutputBuilder
4. Assembles final merged content

**Key Methods:**
- `initialize` - Set up analyses, aligner, resolver
- `merge` - Execute merge and return MergeResult
- `process_alignment` - Process aligned nodes via OutputBuilder

### OutputBuilder (markdown-merge)

Builds markdown output from merge operations:

**Purpose:**
- Consolidates all output assembly logic
- Handles markdown-specific output concerns
- Replaces manual string concatenation

**Key Methods:**
- `add_node_source(node, analysis)` - Extract and add node content
- `add_link_definition(node)` - Reconstruct link references
- `add_gap_line(count:)` - Preserve blank line spacing
- `add_raw(text)` - Add raw text content
- `to_s` - Get final assembled content
- `empty?` - Check if builder has content
- `clear` - Reset builder state

**Design Rationale:**
- Markdown uses `:node` strategy (node-by-node processing)
- Focuses on **source preservation** rather than generation
- Different from `:batch` strategy used in JSON/YAML/Bash/TOML
- Not a traditional "Emitter" because it extracts source rather than generates

### LinkParser (markdown-merge)

PEG-based parser for markdown link structures using Parslet:

**Purpose:**
- Parse link reference definitions from markdown content
- Find inline links and images with their positions
- Handle complex markdown link patterns robustly

**Why Parslet?**
- Handles emoji in labels (e.g., `[🖼️galtzo-discord]`)
- Supports nested brackets (for linked images like `[![alt][ref]](url)`)
- Multi-byte UTF-8 character support
- Recursive grammar for balanced bracket/paren matching
- No regex limitations or backtracking issues

**Grammar Classes:**
- `DefinitionGrammar` - Parses `[label]: url "title"` definitions
- `InlineLinkGrammar` - Parses `[text](url "title")` inline links
- `InlineImageGrammar` - Parses `![alt](url "title")` inline images

**Key Methods:**
- `parse_definitions(content)` - Extract all link definitions from content
- `parse_definition_line(line)` - Parse single definition line
- `find_inline_links(content)` - Find inline links with positions
- `find_inline_images(content)` - Find inline images with positions
- `build_url_to_label_map(definitions)` - Create URL→label mapping

**Example:**
```ruby
parser = LinkParser.new

# Parse definitions
defs = parser.parse_definitions("[example]: https://example.com\n[🎨logo]: https://logo.png")
# => [{ label: "example", url: "https://example.com" }, { label: "🎨logo", url: "https://logo.png" }]

# Find inline links
links = parser.find_inline_links("Check [here](https://example.com) for info")
# => [{ text: "here", url: "https://example.com", start_pos: 6, end_pos: 35 }]
```

### LinkReferenceRehydrator (markdown-merge)

Converts inline links back to reference-style links:

**Purpose:**
- cmark-based parsers convert `[text][label]` to `[text](url)` during `to_commonmark`
- This class reverses that transformation using {LinkParser}
- Preserves semantic meaning while maintaining reference definitions

**Key Methods:**
- `rehydrate` - Convert inline links/images to reference style
- `link_definitions` - Get parsed link definitions
- `duplicate_definitions` - Get URLs with multiple labels
- `changed?` - Check if rehydration made changes

**Example:**
```ruby
content = <<~MD
  Check out [Example](https://example.com) for more info.

  [example]: https://example.com
MD

result = LinkReferenceRehydrator.rehydrate(content)
# => "Check out [Example][example] for more info.\n\n[example]: https://example.com\n"
```

**Integration:**
- Used by `SmartMergerBase` when `rehydrate_link_references: true`
- Records duplicate definition problems in `DocumentProblems`
- Works with both markly and commonmarker backends

### LinkDefinitionFormatter (markdown-merge)

Formats link reference definitions for output:

**Purpose:**
- Reconstructs link definitions consumed by parsers
- cmark-based parsers resolve link refs during parsing
- Need to reconstruct them for output

**Key Methods:**
- `format(node)` - Format single link definition
- `format_all(nodes, separator:)` - Format multiple definitions

**Example:**
```ruby
# Input: LinkDefinitionNode
# Output: "[ref]: https://example.com \"Title\""
LinkDefinitionFormatter.format(node)
```

### FileAnalysisBase (markdown-merge)

Parses and analyzes markdown files:
- Extracts top-level block elements
- Identifies freeze blocks
- Generates structural signatures
- Provides source range access

### FileAligner (markdown-merge)

Finds matches and differences between files:
- Signature-based matching
- Optional fuzzy matching via TableMatchRefiner
- Produces alignment entries (match, template_only, dest_only)

### ConflictResolver (markdown-merge)

Resolves conflicts using `:node` strategy:
- Per-node-pair decisions
- Configurable preference (destination vs template)
- Returns resolution with source and decision

## Merge Workflow

```
1. Parse Files
   ├─ Create FileAnalysis for template
   ├─ Create FileAnalysis for destination
   └─ Extract nodes and signatures

2. Align Nodes
   ├─ Match nodes by signature
   ├─ Apply fuzzy matching (optional)
   └─ Produce alignment entries

3. Process Alignment (via OutputBuilder)
   ├─ For each alignment entry:
   │  ├─ Match: Resolve conflict, add chosen node
   │  ├─ Template-only: Conditionally add template node
   │  └─ Dest-only: Add destination node
   └─ Build OutputBuilder content

4. Post-Processing (optional)
   ├─ Link Reference Rehydration (if enabled):
   │  ├─ Parse link definitions via LinkParser
   │  ├─ Find inline links/images via LinkParser
   │  ├─ Replace inline URLs with reference labels
   │  └─ Track duplicate definitions as problems
   └─ Whitespace normalization

5. Assemble Output
   ├─ Get content from OutputBuilder
   ├─ Create MergeResult (with problems)
   └─ Return to caller
```

## Backend Architecture

### TreeHaver Backends

TreeHaver backends provide the parsing infrastructure. They are located in different gems depending on their purpose:

#### Built-in Backends (in tree_haver)

Located in `tree_haver/lib/tree_haver/backends/`:
- `mri.rb` - ruby_tree_sitter gem (C extension, MRI only)
- `rust.rb` - tree_stump gem (Rust, MRI only)
- `ffi.rb` - FFI backend with libtree-sitter
- `java.rb` - jtreesitter (JRuby only)
- `prism.rb` - Prism parser (Ruby code)
- `psych.rb` - Psych parser (YAML)
- `citrus.rb` - Citrus PEG parser
- `parslet.rb` - Parslet PEG parser

#### Markdown Backends (in *-merge gems)

Markdown backends are located in their respective merge gems because they integrate tightly with the merge functionality:

- `markly-merge/lib/markly/merge/backend.rb` - Markly backend (cmark-gfm C library)
- `commonmarker-merge/lib/commonmarker/merge/backend.rb` - Commonmarker backend (comrak Rust parser)

These ARE TreeHaver backends - they implement the TreeHaver backend protocol with:
- `Backend::Language` - Language configuration
- `Backend::Parser` - Parser wrapper
- `Backend::Tree` - Parse tree wrapper
- `Backend::Node` - Node wrapper with TreeHaver::Node protocol

They register with `TreeHaver::BackendRegistry` for tag support and availability checking.

## Parser Integration

### Commonmarker-Merge

Thin wrapper around markdown-merge:
- Forces `:commonmarker` backend
- Sets commonmarker-specific defaults
- Exposes commonmarker options hash

### Markly-Merge

Thin wrapper around markdown-merge:
- Forces `:markly` backend
- Sets markly-specific defaults (inner_merge_code_blocks: true)
- Exposes markly flags and extensions

## Output Assembly: OutputBuilder Pattern

### Why OutputBuilder Instead of Emitter?

**Different Strategy:**
- JSON/YAML/Bash/TOML use `:batch` strategy (process all at once, generate output)
- Markdown uses `:node` strategy (process pairs individually, preserve source)

**Source Preservation:**
- Emitter **generates** output from scratch
- OutputBuilder **extracts** source + **reconstructs** missing pieces

**Markdown Quirks:**
- Parser consumes link reference definitions
- Normalizes whitespace, table alignment
- OutputBuilder handles extraction and reconstruction
- LinkParser (Parslet-based) handles link definition parsing
- LinkReferenceRehydrator restores reference-style links

### OutputBuilder vs Manual Assembly

**Before:**
```ruby
merged_parts = []
merged_parts << node_to_source(node1, analysis)
merged_parts << node_to_source(node2, analysis)
content = merged_parts.join("\n")
```

**After:**
```ruby
builder = OutputBuilder.new
builder.add_node_source(node1, analysis)
builder.add_node_source(node2, analysis)
content = builder.to_s
```

**Benefits:**
- Centralized logic
- Handles special node types automatically
- Clean, testable interface
- Easier to extend

## Extension Points

### Adding New Parsers

To add support for a new markdown parser (e.g., kramdown):

1. Create a new gem: `kramdown-merge`
2. Subclass `Markdown::Merge::SmartMerger`
3. Implement parser-specific methods:
   - `create_file_analysis` - Create parser-specific FileAnalysis
   - `template_parse_error_class` - Parser-specific error class
   - `destination_parse_error_class` - Parser-specific error class
4. Override `initialize` to set parser-specific defaults
5. OutputBuilder integration is automatic (inherited)

### Custom Signature Generators

Provide custom node matching logic:

```ruby
sig_gen = ->(node) {
  if node.type == :heading
    [:heading, node.header_level]  # Match by level only
  else
    node  # Fall through to default
  end
}

merger = SmartMerger.new(
  template,
  destination,
  signature_generator: sig_gen
)
```

### Custom Match Refiners

Add fuzzy matching for unmatched nodes:

```ruby
refiner = TableMatchRefiner.new(similarity_threshold: 0.7)

merger = SmartMerger.new(
  template,
  destination,
  match_refiner: refiner
)
```

## Testing

### OutputBuilder Testing

```ruby
builder = OutputBuilder.new

# Add content
builder.add_raw("# Heading\n")
builder.add_gap_line(count: 1)
builder.add_node_source(node, analysis)

# Check state
builder.empty?  # => false

# Get output
content = builder.to_s

# Reset
builder.clear
```

### End-to-End Testing

```ruby
merger = SmartMerger.new(template, destination)
result = merger.merge

# Verify result
expect(result.success?).to be true
expect(result.content).to include("expected content")
```

## Performance Considerations

- Node-by-node processing (`:node` strategy) vs batch processing
- Source extraction preferred over re-generation
- Signature computation cached in FileAnalysis
- Alignment computed once, reused for resolution

## Future Enhancements

### Potential Improvements

1. **Streaming Output**: OutputBuilder could support streaming for large files
2. **Configurable Formatting**: Add options for whitespace normalization
3. **Enhanced Link Reference Validation**: Warn about unused link definitions
4. **Enhanced Backend Integration**: Expand merge-specific backend helpers
5. **Additional Parsers**: kramdown, markdown-it, etc.
6. **Link Definition Deduplication**: Automatically merge duplicate definitions

### Compatibility

The architecture is designed for extensibility:
- New parsers can be added without changing core logic
- OutputBuilder can be enhanced without breaking subclasses
- Backend helpers can be expanded as needed

## References

- [markdown-merge README](../markdown-merge/README.md)
- [commonmarker-merge README](../commonmarker-merge/README.md)
- [markly-merge README](../markly-merge/README.md)
- [Markdown Consolidation Investigation](../tmp/MARKDOWN_EMITTER_INVESTIGATION.md)
- [Implementation Progress](../tmp/MARKDOWN_CONSOLIDATION_PROGRESS.md)
