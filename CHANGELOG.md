# Changelog

[![SemVer 2.0.0][📌semver-img]][📌semver] [![Keep-A-Changelog 1.0.0][📗keep-changelog-img]][📗keep-changelog]

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][📗keep-changelog],
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html),
and [yes][📌major-versions-not-sacred], platform and engine support are part of the [public API][📌semver-breaking].
Please file a bug if you notice a violation of semantic versioning.

[📌semver]: https://semver.org/spec/v2.0.0.html
[📌semver-img]: https://img.shields.io/badge/semver-2.0.0-FFDD67.svg?style=flat
[📌semver-breaking]: https://github.com/semver/semver/issues/716#issuecomment-869336139
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html
[📗keep-changelog]: https://keepachangelog.com/en/1.0.0/
[📗keep-changelog-img]: https://img.shields.io/badge/keep--a--changelog-1.0.0-FFDD67.svg?style=flat

## [Unreleased]

### Added

- More tests

### Changed

- Upgrade to [ast-merge v4.0.5](https://github.com/kettle-rb/ast-merge/releases/tag/v4.0.5)
- Upgrade to [tree_haver v5.0.3](https://github.com/kettle-rb/tree_haver/releases/tag/v5.0.3)

### Deprecated

### Removed

### Fixed

### Security

## [1.0.1] - 2026-01-20

- TAG: [v1.0.1][1.0.1t]
- COVERAGE: 93.12% -- 1611/1730 lines in 25 files
- BRANCH COVERAGE: 81.52% -- 525/644 branches in 25 files
- 96.92% documented

### Changed

- Upgrade to [ast-merge v4.0.3](https://github.com/kettle-rb/ast-merge/releases/tag/v4.0.3)

## [1.0.0] - 2026-01-19

- TAG: [v1.0.0][1.0.0t]
- COVERAGE: 91.43% -- 1803/1972 lines in 29 files
- BRANCH COVERAGE: 79.10% -- 579/732 branches in 29 files
- 96.92% documented

### Added

- **Cleanse Module**: New namespace for document cleansing/repair utilities
  - `Cleanse::CondensedLinkRefs` - Fixes condensed link reference definitions caused by previous merge bugs
    - Parslet-based PEG parser (linear-time, ReDoS-safe) for detecting and expanding `[label]: url[label2]: url2` → separate lines
    - Detects two corruption patterns: (1) multiple definitions on same line, (2) content before definition without newline
    - Methods: `#condensed?`, `#expand`, `#definitions`, `#count`
  - `Cleanse::CodeFenceSpacing` - Fixes malformed code fence language tags
    - Fixes ` ``` console` → ` ```console` (removes space between backticks and language)
    - Parslet-based PEG parser (linear-time, ReDoS-safe) for detecting code blocks and their info strings
    - Supports any indentation level (handles code blocks nested in lists)
    - Methods: `#malformed?`, `#malformed_count`, `#code_blocks`, `#fix`
  - `Cleanse::BlockSpacing` - Fixes missing blank lines between block elements
    - Detects and fixes missing blank lines after thematic breaks (`---`)
    - Detects and fixes missing blank lines between list items and headings
    - Detects and fixes missing blank lines between markdown and HTML blocks
    - Detects and fixes missing blank lines before HTML when preceded by markdown
    - Special handling for markdown container closing tags (e.g., `</details>`) - adds blank lines before them even when inside HTML blocks, since their content may be markdown
    - Methods: `#malformed?`, `#issue_count`, `#issues`, `#fix`
  - **Security Note**: `CondensedLinkRefs` and `CodeFenceSpacing` use PEG parsers instead of regex to eliminate ReDoS vulnerabilities. Both process untrusted Markdown input safely in O(n) time.
- **LinkParser tree-based nesting detection**:
  - `#find_all_link_constructs(content)` - Returns tree structure with `:children` for nested items
  - `#build_link_tree(links, images)` - Detects containment and builds parent-child relationships
  - `#flatten_leaf_first(items)` - Flattens tree in post-order (children before parents) for safe replacement
  - Properly handles linked images like `[![alt](img-url)](link-url)` as parent link with child image
- **`bin/fix_readme_formatting`**: Updated to include `BlockSpacing` cleanse fix
  - Now fixes missing blank lines between block elements (thematic breaks, lists, headings, HTML)
  - Runs as Phase 1c after CondensedLinkRefs and CodeFenceSpacing
- **MergeGemRegistry Integration**: Registers with `Ast::Merge::RSpec::MergeGemRegistry`
  - Enables automatic RSpec dependency tag support
  - Registers as category `:markdown` with `skip_instantiation: true` (requires backend)
- **TestableNode-based spec helpers**: New helper methods using `TreeHaver::RSpec::TestableNode`
  for creating real node instances in tests instead of fragile mocks
  - `create_test_node(type, text:, start_line:, ...)` - Create any node type
  - `create_test_table_node(rows:, text:)` - Create table nodes
  - `create_test_row_node(cells:, start_line:)` - Create table row nodes
  - `create_test_cell_node(content:, start_line:)` - Create table cell nodes
  - `create_test_paragraph_node(content:, start_line:)` - Create paragraph nodes
  - `create_test_heading_node(level:, content:, start_line:)` - Create heading nodes
  - `create_test_code_block_node(content:, language:, start_line:)` - Create code block nodes
  - `create_test_list_node(items:, ordered:, start_line:)` - Create list nodes
  - `create_test_block_quote_node(content:, start_line:)` - Create block quote nodes
  - `create_test_thematic_break_node(start_line:)` - Create thematic break nodes
  - `create_test_html_block_node(content:, start_line:)` - Create HTML block nodes
- **LinkParser**: New Parslet-based PEG parser for markdown link structures
  - Properly handles emoji in labels (e.g., `[🖼️galtzo-discord]`)
  - Handles multi-byte UTF-8 characters without regex limitations
  - Handles nested brackets (for linked images like `[![alt][ref]](url)`)
  - Parses link reference definitions: `[label]: url` and `[label]: url "title"`
  - Parses inline links: `[text](url)` and `[text](url "title")`
  - Parses inline images: `![alt](url)` and `![alt](url "title")`
  - Methods: `#parse_definitions`, `#parse_definition_line`, `#find_inline_links`, `#find_inline_images`, `#build_url_to_label_map`
- **DocumentProblems**: New class for tracking document issues found during merge
  - Categories: `:duplicate_link_definition`, `:excessive_whitespace`, `:link_has_title`, `:image_has_title`, `:link_ref_spacing`
  - Severity levels: `:info`, `:warning`, `:error`
  - Methods: `#add`, `#by_category`, `#by_severity`, `#warnings`, `#errors`, `#infos`, `#merge!`, `#summary_by_category`, `#summary_by_severity`
  - Accessible via `MergeResult#problems` after merge
- **WhitespaceNormalizer**: New class for normalizing excessive whitespace
  - Supports multiple normalization modes:
    - `:basic` (or `true`) - Collapse excessive blank lines (3+ → 2)
    - `:link_refs` - Basic + remove blank lines between consecutive link reference definitions
    - `:strict` - All normalizations (same as :link_refs currently)
  - Class method: `WhitespaceNormalizer.normalize(content, mode: :basic)`
  - Instance usage tracks problems for introspection
  - New `:link_ref_spacing` problem category for tracking removed blank lines between link refs
- **LinkReferenceRehydrator**: New class for converting inline links to reference style
  - Converts inline links `[text](url)` to `[text][label]` when matching definition exists
  - Converts inline images `![alt](url)` to `![alt][label]` when matching definition exists
  - Skips links/images with titles (would lose title information)
  - Tracks duplicate definitions and title conflicts in problems
  - Prefers shortest label when multiple labels point to same URL
- **SmartMergerBase options**:
  - `normalize_whitespace: false | true | :basic | :link_refs | :strict` - whitespace normalization mode
  - `rehydrate_link_references: false` - convert inline links to reference style
- **PartialTemplateMerger options**:
  - `normalize_whitespace: false | true | :basic | :link_refs | :strict` - whitespace normalization mode
  - `rehydrate_link_references: false` - convert inline links to reference style
- **MergeResult#problems**: Access `DocumentProblems` instance for introspection
- **OutputBuilder**: New class for building markdown output from merge operations
  - Consolidates all output assembly logic in one place
  - Handles node source extraction, link definition reconstruction, gap lines
  - Replaces manual string concatenation with clean builder pattern
  - Public methods: `add_node_source`, `add_link_definition`, `add_gap_line`, `add_raw`, `to_s`, `empty?`, `clear`
- **LinkDefinitionFormatter**: New module for formatting link reference definitions
  - Reconstructs link definitions that parsers consume during parsing
  - Methods: `format(node)`, `format_all(nodes)`
- **Position-based signature generator for PartialTemplateMerger**:
  - Tables (and other elements) at the same relative position in their sections now match
  - Fixes the "duplicate tables" bug where tables with different column structures weren't merged
  - Template table replaces destination table when both are at the same position within the section
  - Position counters reset for each document, ensuring template and destination tables match
- **PartialTemplateMerger**: Markdown-specific implementation for partial template merging
  - Extends `Ast::Merge::PartialTemplateMergerBase` with markdown-specific logic
  - Heading-level-aware section boundaries (finds next heading of same or higher level)
  - Source-based text extraction via `analysis.source_range` to preserve:
    - Link reference definitions (no conversion to inline links)
    - Table column padding/alignment
    - Original formatting exactly as written
  - Supports both Markly and Commonmarker backends via tree_haver
- **SmartMergerBase**: `add_template_only_nodes` now accepts a callable filter
  - Boolean `true`/`false` still works as before (add all or none)
  - Callable (Proc/Lambda) receives `(node, entry)` and returns truthy to add the node
  - Enables selective addition of template-only nodes based on signature, type, or content
  - Useful for partial template merging where only specific template nodes should be added

### Changed

- Upgrade to [ast-merge v4.0.2](https://github.com/kettle-rb/ast-merge/releases/tag/v4.0.2)
- Upgrade to [tree_haver v5.0.2](https://github.com/kettle-rb/tree_haver/releases/tag/v5.0.2)
- **WhitespaceNormalizer refactored to use LinkParser**
  - Removed `LINK_REF_PATTERN` regex constant
  - Now uses `LinkParser#parse_definition_line` for link definition detection
  - Supports all link definition formats that LinkParser handles:
    - Angle-bracketed URLs: `[label]: <url>`
    - Emoji in labels: `[🎨logo]: url`
    - Definitions with titles in any quote style
  - Completely regex-free implementation
- **LinkDefinitionNode**: Now uses `LinkParser` (Parslet-based) instead of regex for parsing
  - Properly handles emoji in labels (e.g., `[🖼️galtzo-discord]`)
  - More robust parsing of multi-byte UTF-8 characters
- **LinkReferenceRehydrator**: Rewritten to use `LinkParser` (Parslet-based) for all parsing
  - Uses `LinkParser#parse_definitions` to parse link reference definitions
  - Uses `LinkParser#find_inline_links` and `#find_inline_images` to find inline constructs
  - Properly handles linked images (e.g., `[![alt][ref]](url)`)
  - Properly handles emoji in link text and URLs
  - No regex used - all parsing via PEG grammar
- **PartialTemplateMerger#find_section_end**: For headings, now always uses heading-level-aware logic, ignoring tree-depth-based boundary from `InjectionPointFinder`
  - Fixes duplicate H4 section bug where nested headings (e.g., H4 inside H3) were incorrectly treated as section boundaries
  - In Markdown, all headings are siblings at the same tree depth regardless of level (H2, H3, H4), so tree depth cannot determine section boundaries
  - Heading level semantics require comparing actual heading level numbers (H3 < H4 means H4 is nested)
- **SmartMergerBase**: Refactored to use OutputBuilder throughout
  - `process_alignment` now returns OutputBuilder instead of array
  - New methods: `process_match_to_builder`, `process_template_only_to_builder`, `process_dest_only_to_builder`
  - Old methods deprecated but kept for compatibility
  - Inner merge for code blocks now uses `try_inner_merge_code_block_to_builder`
- **OutputBuilder**: Enhanced node extraction to handle `source_position` method
  - Supports nodes with `source_position` hash
  - Falls back to `to_commonmark` if position unavailable
  - Handles FreezeNode, LinkDefinitionNode, GapLineNode, and parser nodes
- **FileAnalysisBase**: Added `@errors` instance variable and `errors` attr_reader
  - `valid?` now checks both `@errors.empty?` and `!@document.nil?`
  - Consistent with bash-merge, json-merge, jsonc-merge, and toml-merge patterns
- **FileAnalysis error handling**: Now rescues `TreeHaver::Error` in `parse_document`
  - `TreeHaver::Error` inherits from `Exception`, not `StandardError`
  - `TreeHaver::NotAvailable` is a subclass of `TreeHaver::Error`, so it's also caught
  - Stores error in `@errors` and returns nil, so `valid?` returns false
  - `SmartMergerBase#parse_and_analyze` then raises the appropriate parse error
- **Dependency tags**: Refactored to use shared `TreeHaver::RSpec::DependencyTags` from tree_haver gem
  - All dependency detection is now centralized in tree_haver
  - Use `require "tree_haver/rspec"` for shared RSpec configuration
  - `MarkdownMergeDependencies` is now an alias to `TreeHaver::RSpec::DependencyTags`
  - Enables `MARKDOWN_MERGE_DEBUG=1` for dependency summary output
  - Inner-merge dependencies (`:toml_merge`, `:json_merge`, `:prism_merge`, `:psych_merge`) now available
- **CodeBlockMerger**: Refactored class methods to remove redundant error handling
  - Removed duplicate `rescue` blocks from `merge_with_prism`, `merge_with_psych`, `merge_with_json`, `merge_with_toml`
  - Error handling is now consolidated in `merge_code_blocks` instance method
  - Class methods now raise exceptions which are caught by `merge_code_blocks`
  - Updated specs to test through `merge_code_blocks` (the intended API) instead of class methods directly

### Fixed

- **CondensedLinkRefs false positive**: Fixed bug where reference-style links followed by colon
  (e.g., `**[Floss-Funding.dev][🖇floss-funding.dev]:**`) were incorrectly detected as condensed
  link reference definitions
  - The pattern `][label]:` was matching, but this is a reference link with punctuation, not a link def
  - Now requires URL-like content after `]:` to confirm it's a real link def
  - Supports both full URLs (`https://...`) and relative paths (`CONTRIBUTING.md`, `LICENSE.txt`)
  - The relative path pattern matches `UPPERCASE.ext` format common in repo files
  - Prevents incorrect newline insertion inside markdown links
- **LinkReferenceRehydrator content corruption**: Fixed critical bug where rehydrating linked images
  like `[![alt](img-url)](link-url)` would corrupt document content
  - The parser was finding both the outer link and inner image as separate items
  - Replacing both overlapping items corrupted the content, losing significant portions of documents
  - Now uses tree-based approach: builds parent-child relationships for nested constructs
  - Processes replacements recursively: children are processed first, then parent text is updated
    to include child replacements before parent is processed
  - Single pass now handles all nested structures (no more multi-pass workaround needed)
  - Test fixture showed 68 lines lost (1023 → 955) before fix, now preserves all content
- **OutputBuilder**: Fixed link definitions being concatenated without newlines
  - `extract_source` for `LinkDefinitionNode` now includes trailing newline
  - Link definitions are now properly output on separate lines
- **OutputBuilder**: Fixed auto-spacing to properly handle link_definition transitions
  - Removed `link_definition` from the skip list for auto-spacing
  - Now correctly adds blank lines when transitioning FROM link_definition TO other content (e.g., headings)
  - `MarkdownStructure.needs_blank_between?` now handles contiguous types properly
- **MarkdownStructure**: Added support for contiguous node types
  - New `CONTIGUOUS_TYPES` constant for node types that should not have blank lines between consecutive instances
  - `link_definition` is now a contiguous type - consecutive link definitions won't have blank lines inserted
  - Added `link_definition` to `NEEDS_BLANK_AFTER` - link definition blocks get blank line after when followed by other content
  - New `contiguous_type?` method to check if a type is contiguous
  - `needs_blank_between?` now returns `false` for consecutive nodes of the same contiguous type
- **PartialTemplateMerger#node_to_text**: Fixed double blank line bug
  - `source_range` already adds trailing newlines, so adding another `"\n"` caused double blank lines
  - Removed the extra `+ "\n"` that was causing excessive blank lines in merged output
- **Lint cleanup**: Fixed RSpec/ReceiveMessages cops by combining multiple `receive` stubs
- **Style fixes**: Fixed Style/ClassMethodsDefinitions in `LinkDefinitionNode` using `class << self`
- **Layout fixes**: Removed extra blank lines in `mock_helpers.rb`
- **Freeze block detection**: Fixed `find_freeze_markers` to handle both raw parser types
  (`:html`) and TreeHaver normalized types (`"html_block"`, `:html_block`). Previously,
  freeze markers were not detected when using TreeHaver backends because the node type
  check only looked for `:html`.
- **Freeze marker content extraction**: Now uses a three-tier fallback for extracting
  HTML comment content:
  1. `string_content` (raw Markly/Commonmarker nodes)
  2. `to_commonmark` on the wrapper node
  3. `inner_node.to_commonmark` (TreeHaver Commonmarker wrapper)
  This fixes freeze block detection for Commonmarker where the TreeHaver wrapper's
  content methods return empty but the inner node has the actual content.

[Unreleased]: https://github.com/kettle-rb/markdown-merge/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/kettle-rb/markdown-merge/compare/v1.0.0...v1.0.1
[1.0.1t]: https://github.com/kettle-rb/markdown-merge/releases/tag/v1.0.1
[1.0.0]: https://github.com/kettle-rb/markdown-merge/compare/76f2230840b236dd10fdd7baf322c082762dddb0...v1.0.0
[1.0.0t]: https://github.com/kettle-rb/markdown-merge/tags/v1.0.0
