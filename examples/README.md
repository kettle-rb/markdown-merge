# Markdown-Merge Examples

This directory contains **2 executable examples** demonstrating markdown-merge's intelligent template-to-destination Markdown merging with different tree_haver backends.

## Quick Start

All examples use bundler inline and are self-contained - no Gemfile needed! Just run:

```bash
ruby examples/commonmarker_merge_example.rb
```

---

## Examples

### Commonmarker Backend

**File:** `commonmarker_merge_example.rb`

Demonstrates smart template-to-destination merging using the Commonmarker backend (comrak Rust parser):

```bash
ruby examples/commonmarker_merge_example.rb
```

**What it shows:**
- Template-to-destination merge (template updates + destination customizations)
- Preserving destination customizations while applying template updates
- Structure-aware merging (preserves headers, sections, lists)
- Position API for precise node location tracking
- Merge statistics and warnings

**Use cases:**
- Update project READMEs from template while preserving customizations
- Maintain consistent documentation structure across projects
- Apply template updates without losing project-specific content

---

### Markly Backend (GitHub Flavored Markdown)

**File:** `markly_merge_example.rb`

Demonstrates smart GFM template-to-destination merging using the Markly backend (cmark-gfm C library):

```bash
ruby examples/markly_merge_example.rb
```

**What it shows:**
- GitHub Flavored Markdown support (tables, task lists, strikethrough)
- Merging GFM tables while preserving custom rows
- Task list checkbox state preservation
- GFM-specific node handling
- Position API with GFM extensions

**Use cases:**
- GitHub documentation template workflows
- API documentation updates with custom endpoints
- README template application with team-specific content
- Maintaining task lists with custom progress

---

## How Markdown-Merge Works

### Smart Template-to-Destination Merge

markdown-merge performs intelligent template-to-destination merging:

1. **Parse** - Parse template and destination using tree_haver
2. **Analyze** - Build AST representations with position tracking
3. **Match** - Match structural elements between template and destination
4. **Merge** - Apply template updates while preserving destination customizations
5. **Report** - Generate warnings for any issues

### Position API Integration

markdown-merge leverages tree_haver's Position API:

```ruby
node.start_line       # 1-based line number
node.end_line         # 1-based line number
node.source_position  # {start_line:, end_line:, start_column:, end_column:}
node.first_child      # Navigate structure
```

This enables:
- ✓ Precise node location tracking
- ✓ Line number tracking throughout merge
- ✓ Structure-aware section matching
- ✓ Better warning messages

### Merge Behavior

Default behavior (destination customizations preserved):
- Template structure is applied
- Destination content is preferred over template content
- New sections from template are added
- Destination-only sections are preserved
- Conflicts tracked for unresolvable situations

---

## Backend Comparison

### Commonmarker
- ✓ Fast Rust-based parser (comrak)
- ✓ Fully CommonMark compliant
- ✓ Excellent error tolerance
- ✓ Great for general Markdown

### Markly
- ✓ GitHub's official implementation (cmark-gfm)
- ✓ Full GFM extension support
- ✓ Tables, strikethrough, task lists, autolinks
- ✓ Perfect for GitHub workflows

Both backends use the same Position API and provide identical merge capabilities!

---

## Example Output

```
Merge Result:
--------------------------------------------------------------------------------
# My Awesome Project

## Overview

This is MY custom project description with extra details!

## Installation

# Custom installation steps
gem install my_project
bundle install

## Features

- Feature A
- Feature B
- My Custom Feature (keep this!)
- Feature C (new in template)

## Configuration

Configure using environment variables.

## Usage

Here's how I use it in my project...

Merge Statistics:
--------------------------------------------------------------------------------
  Success: true
  Nodes Added: 1
  Nodes Modified: 0
  Nodes Removed: 0
  Frozen Blocks: 0
  Merge Time: 12.5ms
```

---

## Integration with tree_haver

These examples demonstrate how markdown-merge integrates with tree_haver's multi-backend architecture:

1. **Backend Selection** - Choose Commonmarker or Markly based on needs
2. **Parser Creation** - tree_haver handles backend-specific parsing
3. **AST Navigation** - Unified Node API works across backends
4. **Position Tracking** - Consistent position information regardless of backend

---

## Related

- **tree_haver examples:** `../tree_haver/examples/` - Backend-specific parsing examples
- **ast-merge:** The underlying AST merging framework
- **markdown-merge gem:** https://github.com/kettle-rb/markdown-merge

---

## Requirements

- Ruby 3.2+
- tree_haver gem
- ast-merge gem
- Either:
  - commonmarker gem (>= 0.23) for Commonmarker backend
  - markly gem (~> 0.11) for Markly backend

All dependencies are automatically installed via bundler inline.

