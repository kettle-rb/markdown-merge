# AGENTS.md - markdown-merge Development Guide

## 🎯 Project Overview

`markdown-merge` is a **format-specific implementation of the `*-merge` gem family** for Markdown files with multi-backend support. It provides intelligent Markdown file merging using AST analysis and delegates to Markly or Commonmarker backends.

**Core Philosophy**: Intelligent Markdown merging that preserves structure, formatting, and links while applying updates from templates, with automatic backend selection.

**Repository**: https://github.com/kettle-rb/markdown-merge
**Current Version**: 1.0.3
**Required Ruby**: >= 3.2.0 (currently developed against Ruby 4.0.1)

## ⚠️ AI Agent Terminal Limitations

### Terminal Output Is Available, but Each Command Is Isolated

**CRITICAL**: AI agents can reliably read terminal output when commands run in the background and the output is polled afterward. However, each terminal command should be treated as a fresh shell with no shared state.

### Use `mise` for Project Environment

**CRITICAL**: The canonical project environment now lives in `mise.toml`, with local overrides in `.env.local` loaded via `dotenvy`.

⚠️ **Watch for trust prompts**: After editing `mise.toml` or `.env.local`, `mise` may require trust to be refreshed before commands can load the project environment. That interactive trust screen can masquerade as missing terminal output, so commands may appear hung or silent until you handle it.

**Recovery rule**: If a `mise exec` command in this repo goes silent, appears hung, or terminal polling stops returning useful output, assume `mise trust` is needed first and recover with:

```bash
mise trust -C /home/pboling/src/kettle-rb/markdown-merge
mise exec -C /home/pboling/src/kettle-rb/markdown-merge -- bundle exec rspec
```

Do this before spending time on unrelated debugging; in this workspace, silent `mise` commands are usually a trust problem.

```bash
mise trust -C /home/pboling/src/kettle-rb/markdown-merge
```

✅ **CORRECT**:
```bash
mise exec -C /home/pboling/src/kettle-rb/markdown-merge -- bundle exec rspec
```

✅ **CORRECT**:
```bash
eval "$(mise env -C /home/pboling/src/kettle-rb/markdown-merge -s bash)" && bundle exec rspec
```

❌ **WRONG**:
```bash
cd /home/pboling/src/kettle-rb/markdown-merge
bundle exec rspec
```

❌ **WRONG**:
```bash
cd /home/pboling/src/kettle-rb/markdown-merge && bundle exec rspec
```

### Prefer Internal Tools Over Terminal

Use `read_file`, `list_dir`, `grep_search`, `file_search` instead of terminal commands for gathering information. Only use terminal for running tests, installing dependencies, and git operations.

### Workspace layout

This repo is a sibling project inside the `/home/pboling/src/kettle-rb` workspace, not a vendored dependency under another repo.

### NEVER Pipe Test Commands Through head/tail

Run the plain command and inspect the full output afterward. Do not truncate test output.

## 🏗️ Architecture: Multi-Backend Adapter

### What markdown-merge Provides

- **`Markdown::Merge::SmartMerger`** – Markdown-specific SmartMerger with backend delegation
- **`Markdown::Merge::FileAnalysis`** – Markdown file analysis with backend detection
- **`Markdown::Merge::NodeWrapper`** – Wrapper that delegates to backend-specific wrappers
- **`Markdown::Merge::PartialTemplateMerger`** – Section-level partial merges
- **`Markdown::Merge::MergeResult`** – Markdown-specific merge result
- **`Markdown::Merge::BackendSelector`** – Automatic backend selection (Markly → Commonmarker)
- **`Markdown::Merge::DebugLogger`** – Markdown-specific debug logging

### Key Dependencies

| Gem | Role |
|-----|------|
| `ast-merge` (~> 4.0) | Base classes and shared infrastructure |
| `tree_haver` (~> 5.0) | Unified parser adapter |
| `markly` (~> 0.15) | Preferred Markdown parser (optional) |
| `commonmarker` | Fallback Markdown parser (optional) |
| `version_gem` (~> 1.1) | Version management |

### Backend Selection Strategy

markdown-merge automatically selects the best available backend:

| Priority | Backend | Parser | Notes |
|----------|---------|--------|-------|
| 1 | `:markly` | Markly | Preferred; fast, MRI only |
| 2 | `:commonmarker` | Commonmarker | Fallback; also MRI only |
| Error | - | - | Raises error if neither available |

## 📁 Project Structure

```
lib/markdown/merge/
├── smart_merger.rb              # Multi-backend SmartMerger
├── partial_template_merger.rb   # Section-level merging
├── file_analysis.rb             # Backend-aware file analysis
├── node_wrapper.rb              # Backend delegation wrapper
├── merge_result.rb              # Merge result object
├── backend_selector.rb          # Backend selection logic
├── debug_logger.rb              # Debug logging
└── version.rb

spec/markdown/merge/
├── smart_merger_spec.rb
├── partial_template_merger_spec.rb
├── file_analysis_spec.rb
├── backend_selector_spec.rb
└── integration/
```

## 🔧 Development Workflows

### Running Tests

```bash
# Full suite
mise exec -C /home/pboling/src/kettle-rb/markdown-merge -- bundle exec rspec

# Single file (disable coverage threshold check)
mise exec -C /home/pboling/src/kettle-rb/markdown-merge -- env K_SOUP_COV_MIN_HARD=false bundle exec rspec spec/markdown/merge/smart_merger_spec.rb

# Specific backend tests
mise exec -C /home/pboling/src/kettle-rb/markdown-merge -- bundle exec rspec --tag markly
mise exec -C /home/pboling/src/kettle-rb/markdown-merge -- bundle exec rspec --tag commonmarker
```

### Coverage Reports

```bash
mise exec -C /home/pboling/src/kettle-rb/markdown-merge -- bin/rake coverage
mise exec -C /home/pboling/src/kettle-rb/markdown-merge -- bin/kettle-soup-cover -d
```

## 📝 Project Conventions

### API Conventions

#### SmartMerger API
- `merge` – Returns a **String** (the merged Markdown content)
- `merge_result` – Returns a **MergeResult** object
- Backend is auto-selected unless explicitly specified

**Explicit Backend Selection**:
```ruby
# Auto-select (Markly → Commonmarker)
merger = Markdown::Merge::SmartMerger.new(template, dest)

# Force specific backend
merger = Markdown::Merge::SmartMerger.new(template, dest, backend: :markly)
merger = Markdown::Merge::SmartMerger.new(template, dest, backend: :commonmarker)
```

#### Markdown-Specific Features

**Heading-Based Sections**:
```markdown
# Section 1
Content for section 1

## Subsection 1.1
Nested content

# Section 2
Content for section 2
```

**Freeze Blocks**:
```markdown
<!-- markdown-merge:freeze -->
Custom content that should not be overridden
<!-- markdown-merge:unfreeze -->

Standard content that merges normally
```

## 🧪 Testing Patterns

### TreeHaver Dependency Tags

**Available tags**:
- `:any_markdown_merge` – Requires any Markdown backend (Markly or Commonmarker)
- `:markly` – Requires Markly backend specifically
- `:commonmarker` – Requires Commonmarker backend specifically
- `:markdown_parsing` – Requires Markdown parser

✅ **CORRECT**:
```ruby
RSpec.describe Markdown::Merge::SmartMerger, :any_markdown_merge do
  # Skipped if no Markdown parser available
end

context "with Markly backend", :markly do
  # Only runs when Markly available
end

context "with Commonmarker backend", :commonmarker do
  # Only runs when Commonmarker available
end
```

❌ **WRONG**:
```ruby
before do
  skip "Requires Markdown parser" unless markdown_available?  # DO NOT DO THIS
end
```

## 💡 Key Insights

1. **Backend auto-selection**: Prefers Markly, falls back to Commonmarker automatically
2. **Backend delegation**: NodeWrapper and FileAnalysis delegate to backend-specific implementations
3. **Cross-backend compatibility**: Same API works with both backends
4. **`.text` strips formatting**: When matching by text, backticks and other formatting are removed (both backends)
5. **Freeze blocks use HTML comments**: `<!-- markdown-merge:freeze -->`
6. **MRI only**: Both Markly and Commonmarker require MRI

## 🚫 Common Pitfalls

1. **markdown-merge requires MRI**: Neither backend works on JRuby or TruffleRuby
2. **NEVER use manual skip checks** – Use dependency tags (`:any_markdown_merge`, `:markly`, `:commonmarker`)
3. **Backend must be available**: Raises error if neither Markly nor Commonmarker installed
4. **Text matching strips formatting** – Match on plain text, not markdown syntax
5. **Do NOT load vendor gems** – They are not part of this project; they do not exist in CI
6. **Use `tmp/` for temporary files** – Never use `/tmp` or other system directories
7. **Do NOT expect `cd` to persist** – Every terminal command is isolated; use a self-contained `mise exec -C ... -- ...` invocation.
8. **Do NOT rely on prior shell state** – Previous `cd`, `export`, aliases, and functions are not available to the next command.

## 🔧 Markdown-Specific Notes

### Backend Selection
```ruby
# Check available backends
Markdown::Merge::BackendSelector.available_backends
# => [:markly] or [:commonmarker] or [:markly, :commonmarker]

# Get preferred backend
Markdown::Merge::BackendSelector.select_backend
# => :markly (if available), else :commonmarker

# Force backend
Markdown::Merge::BackendSelector.select_backend(prefer: :commonmarker)
# => :commonmarker (if available)
```

### Node Types (both backends)
```markdown
document         # Root node
heading          # # Heading
paragraph        # Regular text
code_block       # ```code```
list             # - item or 1. item
link             # [text](url)
image            # ![alt](src)
```

### Merge Behavior
- **Headings**: Matched by heading text (stripped of formatting)
- **Sections**: Content from heading to next same-level heading
- **Backend delegation**: FileAnalysis and NodeWrapper delegate to markly-merge or commonmarker-merge
- **Freeze blocks**: Protect customizations from template updates
- **Auto-fallback**: Uses Markly if available, else Commonmarker

### Testing Multi-Backend Code
```ruby
# Test with all available backends
[:markly, :commonmarker].each do |backend|
  context "with #{backend} backend", backend do
    it "merges correctly" do
      merger = described_class.new(template, dest, backend: backend)
      expect(merger.merge).to eq(expected)
    end
  end
end
```
