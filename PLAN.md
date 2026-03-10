# PLAN.md

## Goal
Integrate the shared Comment AST & Merge capability into `markdown-merge` in a way that preserves standalone comment-like regions without confusing normal Markdown/HTML content semantics.

`psych-merge` is the reference for shared comment behavior, but `markdown-merge` should remain the shared Markdown engine for wrapper gems rather than duplicating parser-specific logic everywhere.

## Current Status
- `markdown-merge` is the shared core for the Markdown-family wrapper gems and should be treated as the foundation before touching wrapper-specific plans.
- The gem has the standard merge-gem layout plus an `ARCHITECTURE.md`, which makes it the right place to land common Markdown comment behavior.
- Markdown comments are trickier than YAML comments because HTML comments are also content and not always metadata.
- The first implementation should be selective and conservative.

## Integration Strategy
- Expose shared comment capability from the Markdown analysis layer.
- Treat standalone HTML comments as comment regions first.
- Do not broadly reinterpret every HTML block/comment as merge metadata.
- Preserve document prelude/postlude comment regions and comment-only fragments where ownership is clear.
- Keep freeze markers and other existing Markdown-specific behaviors stable.

## First Slices
1. Add shared comment capability plumbing to the common Markdown analysis layer.
2. Preserve standalone top-of-file and trailing HTML comment regions.
3. Preserve standalone HTML comments between major block nodes when ownership is clear.
4. Keep template-preference merges from dropping destination comment-only sections.
5. Expand only after the core rules are stable across Markdown backends.

## First Files To Inspect
- `lib/markdown/merge/file_analysis_base.rb`
- `lib/markdown/merge/file_analysis.rb`
- `lib/markdown/merge/smart_merger.rb`
- `lib/markdown/merge/output_builder.rb`
- any section/partial merge helpers under `lib/markdown/merge/`

## Tests To Add First
- analysis specs for standalone HTML comment region detection
- smart merger specs for comment-only Markdown fragments
- specs for comment sections before headings and between blocks
- partial template merge regressions with standalone comments
- reproducible fixtures once wrapper expectations are clear

## Risks
- HTML comments are valid Markdown/HTML content, not always metadata.
- Backends may normalize or position HTML comments differently.
- Over-assigning comment ownership could damage normal Markdown content.
- Freeze-marker or code-block behavior must not regress.

## Success Criteria
- Shared comment capability exists in the Markdown core.
- Standalone HTML comment regions survive common merges when ownership is clear.
- Comment-only sections no longer disappear accidentally during merges.
- Behavior is conservative enough to avoid treating ordinary content as metadata.
- Wrapper gems can inherit the shared logic with minimal additional work.

## Rollout Phase
- Phase 3 target.
- This is the core dependency for the Markdown-family wrappers and should land before `commonmarker-merge` or `markly-merge` wrapper work.

## Execution Backlog

### Slice 1 — Conservative standalone comment regions
- Add `comment_capability`, `comment_augmenter`, and standalone HTML comment region support to the Markdown core.
- Preserve document prelude/postlude standalone comments and comment-only fragments.
- Add focused analysis and smart-merger specs for clearly standalone HTML comments.

### Slice 2 — Inter-block comment sections
- Preserve standalone HTML comment blocks between major Markdown block nodes where ownership is unambiguous.
- Keep template-preference merges from dropping destination comment-only sections.
- Add focused regressions for headings, sections, and partial template merges.

### Slice 3 — Wrapper-ready parity + fixtures
- Re-check backend parity and keep the implementation conservative.
- Promote the highest-value standalone-comment scenarios into reproducible fixtures.
- Document any intentionally unsupported HTML-comment-as-content cases so wrappers inherit clear boundaries.

## Dependencies / Resume Notes
- Start in `lib/markdown/merge/file_analysis_base.rb` and `lib/markdown/merge/file_analysis.rb`.
- Keep `ARCHITECTURE.md` aligned with any shared comment-region rules introduced here.
- Do not attempt wrapper-specific fixes until core behavior is stable.

## Exit Gate For This Plan
- The Markdown core supports standalone comment regions safely and conservatively.
- Wrapper gems can consume the behavior without reimplementing comment ownership.
