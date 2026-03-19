# Blank Line Normalization Plan for `markdown-merge`

_Date: 2026-03-19_

## Role in the family refactor

`markdown-merge` is the source-of-truth repo for the Markdown-family blank-line normalization work.

It already contains meaningful gap and section-spacing logic, so it should be one of the first deep adopters of the shared `ast-merge` layout model.

## Current evidence files

Implementation files:

- `lib/markdown/merge/smart_merger_base.rb`
- `lib/markdown/merge/file_analysis_base.rb`
- `lib/markdown/merge/gap_line_node.rb`
- partial-template merger and related files under `lib/markdown/merge/`

Relevant specs:

- `spec/markdown/merge/smart_merger_spec.rb`
- `spec/markdown/merge/partial_template_merger_spec.rb`
- `spec/markdown/merge/removal_mode_compliance_spec.rb`
- `spec/integration/smart_merger_comment_preservation_spec.rb`

## Current pressure points

Markdown already has strong blank-line semantics around:

- paragraph/list/code-block boundaries
- top-level block separation
- preserved standalone HTML comment fragments
- link-reference ownership boundaries
- gap-line nodes and section recomposition
- partial-template normalization between before/section/after content

## Migration targets

### 1. Reconcile `gap_line_node` behavior with shared `ast-merge` layout abstractions

If the shared platform can express these gaps generically, repo-local gap nodes should narrow to Markdown-specific cases only.

### 2. Keep Markdown-family contract centralized here

`markdown-merge` should define the family’s concrete blank-line behavior; wrapper repos should follow rather than diverge.

### 3. Remove duplicated section-spacing heuristics where shared helpers suffice

Especially around partial-template and full-document block adjacency.

## Workstreams

- map current gap-node semantics to the shared `ast-merge` layout model
- migrate section recomposition and top-level block spacing first
- migrate standalone-comment / link-reference separator handling second
- keep wrapper parity tests in sync across `markly-merge` and `commonmarker-merge`

## Exit criteria

- Markdown-family blank-line behavior is defined here and backed by shared layout semantics where practical
- repo-local gap logic remains only for truly Markdown-specific behavior
- wrapper repos can rely on this repo as the family source of truth
