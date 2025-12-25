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

### Changed

- **ConflictResolver**: Added `**options` for forward compatibility
- **MergeResult**: Added `**options` for forward compatibility
- **CodeBlockMerger specs**: Updated to use dependency tags (`:prism_merge`, `:psych_merge`, `:json_merge`)
  instead of manual skip blocks, ensuring tests are properly skipped when backends aren't available

### Deprecated

### Removed

### Fixed

- `SmartMergerBase#apply_node_typing` now correctly calls custom `node_typing` lambdas
  even when nodes are pre-wrapped with canonical types by `NodeTypeNormalizer`.
  Previously, the method returned early when nodes were already typed, preventing
  custom lambdas from refining or overriding the canonical `merge_type`.
  This fix enables the `node_typing` + Hash `preference` pattern to work correctly
  for per-node-type merge preferences (e.g., `{ default: :destination, gem_family_table: :template }`).

### Security

## [1.0.0] - 2024-12-17

### Added

- Initial release of markdown-merge
- Central hub for markdown merging with tree_haver backends
- `Markdown::Merge::SmartMerger` - standalone merger supporting multiple backends
- `Markdown::Merge::FileAnalysis` - file analysis using tree_haver
- `Markdown::Merge::Backends` - backend constants (`:commonmarker`, `:markly`, `:auto`)
- `Markdown::Merge::NodeTypeNormalizer` - extensible node type normalization
  - Canonical types: `:heading`, `:paragraph`, `:code_block`, `:list`, `:block_quote`, `:thematic_break`, `:html_block`, `:table`, `:footnote_definition`
  - Register custom backends via `NodeTypeNormalizer.register_backend`
- Base classes for parser-specific implementations:
  - `Markdown::Merge::SmartMergerBase`
  - `Markdown::Merge::FileAnalysisBase`
  - `Markdown::Merge::FreezeNode`
- Freeze block support with configurable tokens
- Inner-merge support for fenced code blocks
- Table matching algorithms
- Comprehensive test suite

### Dependencies

- `ast-merge` (~> 1.0) - shared merge infrastructure
- `tree_haver` (~> 3.0) - unified markdown parsing
- `version_gem` (~> 1.1)

[Unreleased]: https://github.com/kettle-rb/markdown-merge/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/kettle-rb/markdown-merge/compare/76f2230840b236dd10fdd7baf322c082762dddb0...v1.0.0
[1.0.0t]: https://github.com/kettle-rb/markdown-merge/tags/v1.0.0
