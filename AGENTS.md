# AGENTS.md - Development Guide

## 🎯 Project Overview

**Minimum Supported Ruby**: See the gemspec `required_ruby_version` constraint.
**Local Development Ruby**: See `.tool-versions` for the version used in local development (typically the latest stable Ruby).

This project is a **RubyGem** managed with the [kettle-rb](https://github.com/kettle-rb) toolchain.

**Repository**: https://github.com/kettle-rb/markdown-merge
**Current Version**: 1.0.3
**Required Ruby**: >= 3.2.0 (currently developed against Ruby 4.0.1)

## ⚠️ AI Agent Terminal Limitations

### Terminal Output Is Available, but Each Command Is Isolated

```bash
mise exec -C /path/to/project -- bundle exec rspec
```

✅ **CORRECT** — If you need shell syntax first, load the environment in the same command:

### Use `mise` for Project Environment

**CRITICAL**: The canonical project environment lives in `mise.toml`, with local overrides in `.env.local` loaded via `dotenvy`.

⚠️ **Watch for trust prompts**: After editing `mise.toml` or `.env.local`, `mise` may require trust to be refreshed before commands can load the project environment. Until that trust step is handled, commands can appear hung or produce no output, which can look like terminal access is broken.

**Recovery rule**: If a `mise exec` command goes silent or appears hung, assume `mise trust` is the first thing to check. Recover by running:

```bash
mise trust -C /home/pboling/src/kettle-rb/markdown-merge
mise exec -C /home/pboling/src/kettle-rb/markdown-merge -- bundle exec rspec
```

```bash
mise trust -C /path/to/project
mise exec -C /path/to/project -- bundle exec rspec
```

Do this before spending time on unrelated debugging; in this workspace pattern, silent `mise` commands are usually a trust problem first.

```bash
mise trust -C /home/pboling/src/kettle-rb/markdown-merge
```

✅ **CORRECT** — Run self-contained commands with `mise exec`:

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

```bash
eval "$(mise env -C /path/to/project -s bash)" && bundle exec rspec
```

❌ **WRONG** — Do not rely on a previous command changing directories:

```bash
cd /path/to/project
bundle exec rspec
```

❌ **WRONG** — A chained `cd` does not give directory-change hooks time to update the environment:

```bash
cd /path/to/project && bundle exec rspec
```

### Prefer Internal Tools Over Terminal

### Running Commands

Always make commands self-contained. Use `mise exec -C /home/pboling/src/kettle-rb/prism-merge -- ...` so the command gets the project environment in the same invocation.
If the command is complicated write a script in local tmp/ and then run the script.

### Workspace layout

## 🏗️ Architecture

### Toolchain Dependencies

This gem is part of the **kettle-rb** ecosystem. Key development tools:

### NEVER Pipe Test Commands Through head/tail

When you do run tests, keep the full output visible so you can inspect failures completely.

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

### Environment Variable Helpers

```ruby
before do
  stub_env("MY_ENV_VAR" => "value")
end

before do
  hide_env("HOME", "USER")
end
```

### Dependency Tags

Use dependency tags to conditionally skip tests when optional dependencies are not available:

| Priority | Backend | Parser | Notes |
|----------|---------|--------|-------|
| 1 | `:markly` | Markly | Preferred; fast, MRI only |
| 2 | `:commonmarker` | Commonmarker | Fallback; also MRI only |
| Error | - | - | Raises error if neither available |

| Tool | Purpose |
|------|---------|
| `kettle-dev` | Development dependency: Rake tasks, release tooling, CI helpers |
| `kettle-test` | Test infrastructure: RSpec helpers, stubbed_env, timecop |
| `kettle-jem` | Template management and gem scaffolding |

### Executables (from kettle-dev)

| Executable | Purpose |
|-----------|---------|
| `kettle-release` | Full gem release workflow |
| `kettle-pre-release` | Pre-release validation |
| `kettle-changelog` | Changelog generation |
| `kettle-dvcs` | DVCS (git) workflow automation |
| `kettle-commit-msg` | Commit message validation |
| `kettle-check-eof` | EOF newline validation |

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

```
lib/
├── <gem_namespace>/           # Main library code
│   └── version.rb             # Version constant (managed by kettle-release)
spec/
├── fixtures/                  # Test fixture files (NOT auto-loaded)
├── support/
│   ├── classes/               # Helper classes for specs
│   └── shared_contexts/       # Shared RSpec contexts
├── spec_helper.rb             # RSpec configuration (loaded by .rspec)
gemfiles/
├── modular/                   # Modular Gemfile components
│   ├── coverage.gemfile       # SimpleCov dependencies
│   ├── debug.gemfile          # Debugging tools
│   ├── documentation.gemfile  # YARD/documentation
│   ├── optional.gemfile       # Optional dependencies
│   ├── rspec.gemfile          # RSpec testing
│   ├── style.gemfile          # RuboCop/linting
│   └── x_std_libs.gemfile     # Extracted stdlib gems
├── ruby_*.gemfile             # Per-Ruby-version Appraisal Gemfiles
└── Appraisal.root.gemfile     # Root Gemfile for Appraisal builds
.git-hooks/
├── commit-msg                 # Commit message validation hook
├── prepare-commit-msg         # Commit message preparation
├── commit-subjects-goalie.txt # Commit subject prefix filters
└── footer-template.erb.txt    # Commit footer ERB template
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

Full suite spec runs:

```bash
mise exec -C /path/to/project -- bundle exec rspec
```

For single file, targeted, or partial spec runs the coverage threshold **must** be disabled.
Use the `K_SOUP_COV_MIN_HARD=false` environment variable to disable hard failure:

```bash
mise exec -C /path/to/project -- env K_SOUP_COV_MIN_HARD=false bundle exec rspec spec/path/to/spec.rb
```

### Coverage Reports

```bash
mise exec -C /home/pboling/src/kettle-rb/markdown-merge -- bin/rake coverage
mise exec -C /home/pboling/src/kettle-rb/markdown-merge -- bin/kettle-soup-cover -d
```

```bash
mise exec -C /path/to/project -- bin/rake coverage
mise exec -C /path/to/project -- bin/kettle-soup-cover -d
```

**Key ENV variables** (set in `mise.toml`, with local overrides in `.env.local`):
- `K_SOUP_COV_DO=true` – Enable coverage
- `K_SOUP_COV_MIN_LINE` – Line coverage threshold
- `K_SOUP_COV_MIN_BRANCH` – Branch coverage threshold
- `K_SOUP_COV_MIN_HARD=true` – Fail if thresholds not met

### Code Quality

```bash
mise exec -C /path/to/project -- bundle exec rake reek
mise exec -C /path/to/project -- bundle exec rubocop-gradual
```

### Releasing

```bash
bin/kettle-pre-release    # Validate everything before release
bin/kettle-release        # Full release workflow
```

## 📝 Project Conventions

### API Conventions

#### SmartMerger API

### Test Infrastructure

- Uses `kettle-test` for RSpec helpers (stubbed_env, block_is_expected, silent_stream, timecop)
- Uses `Dir.mktmpdir` for isolated filesystem tests
- Spec helper is loaded by `.rspec` — never add `require "spec_helper"` to spec files

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

### Freeze Block Preservation

Template updates preserve custom code wrapped in freeze blocks:

```markdown
<!-- markdown-merge:freeze -->
Custom content that should not be overridden
<!-- markdown-merge:unfreeze -->

Standard content that merges normally
```

```ruby
# kettle-jem:freeze
# ... custom code preserved across template runs ...
# kettle-jem:unfreeze
```

### Modular Gemfile Architecture

Gemfiles are split into modular components under `gemfiles/modular/`. Each component handles a specific concern (coverage, style, debug, etc.). The main `Gemfile` loads these modular components via `eval_gemfile`.

### Forward Compatibility with `**options`

**CRITICAL**: All constructors and public API methods that accept keyword arguments MUST include `**options` as the final parameter for forward compatibility.

## 🧪 Testing Patterns

### TreeHaver Dependency Tags

**Available tags**:
❌ **AVOID** when possible:

- `run_in_terminal` for information gathering

Only use terminal for:

- Running tests (`bundle exec rspec`)
- Installing dependencies (`bundle install`)
- Simple commands that do not require much shell escaping
- Running scripts (prefer writing a script over a complicated command with shell escaping)

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

```ruby
RSpec.describe SomeClass, :prism_merge do
  # Skipped if prism-merge is not available
end
```

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

✅ **PREFERRED** — Use internal tools:

- `grep_search` instead of `grep` command
- `file_search` instead of `find` command
- `read_file` instead of `cat` command
- `list_dir` instead of `ls` command
- `replace_string_in_file` or `create_file` instead of `sed` / manual editing

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

1. **NEVER pipe test output through `head`/`tail`** — Run tests without truncation so you can inspect the full output.
