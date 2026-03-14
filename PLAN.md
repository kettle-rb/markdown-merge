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

## Latest `ast-merge` Comment Logic Checklist (2026-03-13)
- [x] Shared capability plumbing: `comment_capability`, `comment_augmenter`, normalized region/attachment access
- [x] Document boundary ownership: standalone prelude/postlude HTML comment regions
- [x] Matched-node fallback: preserve destination standalone comment-only sections when template-preferred fuzzy content wins, while keeping template comment sections when the template already documents the match
- [x] Removed-node preservation: keep/promote destination standalone comment regions when blocks disappear
- [x] Inter-block/fixture parity: conservative between-block ownership and reproducible Markdown fixtures

Current parity status: complete for the current conservative Markdown standalone-comment rollout shape; backend-local dev/test parity is restored, analysis-layer plumbing is in place, and document-boundary, matched-node, removed-node, conservative inter-block positioning, and reproducible fixture coverage are all green.
Next execution target: broaden ownership coverage only if a new backend-safe standalone-comment escape case is reproduced, or continue with Markdown-family consolidation above the core.

## Execution Backlog

## Progress
- 2026-03-13: Wrapper backend language/node helper consolidation landed.
- Extended `Markdown::Merge::BackendSupport` so `markly-merge` and `commonmarker-merge` now share markdown-only `Language.from_library` loading plus common backend-node navigation/link/heading/code-block accessors, leaving only parser-specific text, position, child traversal, and parse behavior in the wrapper backends.
- Revalidated the focused wrapper backend/file-analysis smoke batch plus the shared Markdown comment-preservation/core batch in sibling workspace mode under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`markly-merge`: `124 examples, 0 failures, 1 pending`; `commonmarker-merge`: `154 examples, 0 failures, 1 pending`; `markdown-merge`: `3 examples, 0 failures`).
- Revalidated both full wrapper suites and the full Markdown core suite in sibling workspace mode under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`markly-merge`: `528 examples, 0 failures, 1 pending`; `commonmarker-merge`: `436 examples, 0 failures, 1 pending`; `markdown-merge`: `1075 examples, 0 failures`).
- 2026-03-13: Wrapper backend-support consolidation landed.
- Added `Markdown::Merge::BackendSupport` to centralize wrapper-backend availability/reset/capability plumbing, shared tree wrappers, and TreeHaver registration/tag boilerplate; `markly-merge` and `commonmarker-merge` now keep only parser-specific `Language`, `Parser`, and `Node` behavior in their backend adapters.
- Revalidated the focused wrapper backend/file-analysis smoke batch plus the shared Markdown comment-preservation/core batch in sibling workspace mode under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`markly-merge`: `118 examples, 0 failures, 1 pending`; `commonmarker-merge`: `149 examples, 0 failures, 1 pending`; `markdown-merge`: `3 examples, 0 failures`).
- Revalidated both full wrapper suites and the full Markdown core suite in sibling workspace mode under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`markly-merge`: `522 examples, 0 failures, 1 pending`; `commonmarker-merge`: `431 examples, 0 failures, 1 pending`; `markdown-merge`: `1075 examples, 0 failures`).
- 2026-03-13: Wrapper subclass-configuration macro consolidation landed.
- Extended `Markdown::Merge::WrapperSupport` with shared subclass-configuration helpers so `markly-merge` and `commonmarker-merge` no longer repeat the same `default_backend` / parser-option / analysis-class / smart-merger-class / parse-error class methods across their thin wrapper classes.
- Revalidated the focused wrapper entry-point batch plus the shared Markdown comment-preservation/core batch in sibling workspace mode under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`markly-merge`: `217 examples, 0 failures, 1 pending`; `commonmarker-merge`: `133 examples, 0 failures, 1 pending`; `markdown-merge`: `3 examples, 0 failures`).
- Revalidated both full wrapper suites and the full Markdown core suite in sibling workspace mode under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`markly-merge`: `522 examples, 0 failures, 1 pending`; `commonmarker-merge`: `431 examples, 0 failures, 1 pending`; `markdown-merge`: `1075 examples, 0 failures`).
- 2026-03-13: Wrapper bootstrap/error/freeze-node consolidation landed.
- Added `Markdown::Merge::WrapperSupport` to centralize backend-wrapper bootstrap, shared class re-exports, merge-gem registration, debug-logger configuration, and wrapper error scaffolding; `markly-merge` and `commonmarker-merge` now reuse that helper and expose direct `FreezeNode` aliases to `Markdown::Merge::FreezeNode` instead of carrying separate empty subclasses.
- Revalidated focused wrapper entry/bootstrap/backend/freeze-node coverage plus the shared Markdown comment-preservation/core batch in sibling workspace mode under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`markly-merge`: `266 examples, 0 failures, 1 pending` focused including `freeze_node_spec` and backend/bootstrap coverage; `commonmarker-merge`: `182 examples, 0 failures, 1 pending` focused including `freeze_node_spec`; `markdown-merge`: `3 examples, 0 failures` focused comment/core batch).
- Revalidated both full wrapper suites and the full Markdown core suite in sibling workspace mode under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`markly-merge`: `522 examples, 0 failures, 1 pending`; `commonmarker-merge`: `431 examples, 0 failures, 1 pending`; `markdown-merge`: `1075 examples, 0 failures`).
- 2026-03-13: Wrapper backend-default consolidation landed.
- Moved wrapper-specific backend/default parser plumbing for `FileAnalysis`, `SmartMerger`, and `PartialTemplateMerger` into subclass-configurable hooks in `markdown-merge`, letting `markly-merge` and `commonmarker-merge` keep only thin entry-point declarations for backend defaults, wrapper analysis classes, and parse error classes.
- Revalidated the focused shared Markdown comment-preservation/core baseline plus focused wrapper smoke/file-analysis/partial-template/smart-merger batches in sibling workspace mode under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`markdown-merge`: `3 examples, 0 failures` focused comment/core batch; `markly-merge`: `217 examples, 0 failures, 1 pending` focused; `commonmarker-merge`: `133 examples, 0 failures, 1 pending` focused).
- Revalidated both full wrapper suites and the full Markdown core suite in sibling workspace mode under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`markly-merge`: `522 examples, 0 failures, 1 pending`; `commonmarker-merge`: `431 examples, 0 failures, 1 pending`; `markdown-merge`: `1075 examples, 0 failures`).
- 2026-03-13: Wrapper comment-support consolidation landed.
- Replaced duplicated wrapper-local standalone HTML comment tracker plumbing in `markly-merge` and `commonmarker-merge` with direct reuse of the shared `Markdown::Merge::CommentTracker`, inherited Markdown-core file-analysis comment helpers, and the shared Markdown `PartialTemplateMerger` replace-mode standalone-comment preservation path, keeping both wrappers thinner without changing behavior.
- Revalidated the minimal shared Markdown baseline plus the focused wrapper smoke/file-analysis/partial-template/smart-merger batches in sibling workspace mode under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`markdown-merge`: `1 example, 0 failures` focused baseline; `markly-merge`: `217 examples, 0 failures, 1 pending` focused; `commonmarker-merge`: `133 examples, 0 failures, 1 pending` focused).
- Revalidated both full wrapper suites and the full Markdown core suite in sibling workspace mode under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`markly-merge`: `522 examples, 0 failures, 1 pending`; `commonmarker-merge`: `431 examples, 0 failures, 1 pending`; `markdown-merge`: `1075 examples, 0 failures`).
- 2026-03-13: Full-document standalone-comment fixture coverage landed.
- Added `spec/fixtures/04_full_document_comment_gap/{template,destination,expected}.md` plus `spec/integration/smart_merger_comment_preservation_spec.rb` to lock template-preferred fuzzy paragraph replacement when a destination standalone HTML comment-only section sits between the heading and matched content.
- Revalidated the focused ownership / fixture batch and then revalidated the full `markdown-merge` suite under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`4 examples, 0 failures` focused; `1075 examples, 0 failures` full).
- 2026-03-13: Reproducible standalone-comment fixture coverage landed.
- Added `spec/fixtures/03_partial_replace_comments/{template,destination,expected}.md` plus `spec/integration/partial_template_comment_preservation_spec.rb` to lock the conservative inter-block partial-template replace-mode standalone-comment behavior to a reproducible end-to-end fixture.
- Revalidated the fixture-backed focused Markdown file-analysis / smart-merger / partial-template / integration set and then revalidated the full `markdown-merge` suite under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`170 examples, 0 failures` focused; `1074 examples, 0 failures` full).
- 2026-03-13: Conservative inter-block partial-template replace-mode coverage extended.
- Added focused `partial_template_merger_spec` regressions proving `replace_mode` preserves destination standalone HTML comment-only fragments between corresponding template blocks instead of collapsing them to the end of the replaced section.
- Refined `Markdown::Merge::PartialTemplateMerger` replace-mode reconstruction so preserved destination standalone HTML comment-only fragments are reinserted by their relative structural position inside the template replacement when the template itself does not already contain standalone comments.
- Revalidated focused Markdown file-analysis / smart-merger / partial-template specs and then revalidated the full `markdown-merge` suite under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`169 examples, 0 failures` focused; `1073 examples, 0 failures` full).
- 2026-03-13: Phase 3 / removed-node standalone-comment slice completed.
- Added focused `partial_template_merger_spec` regressions proving `replace_mode` preserves destination standalone HTML comment-only fragments when replacing a section, while still preferring template-owned standalone comment fragments when the replacement already documents the section.
- Taught `Markdown::Merge::PartialTemplateMerger` to preserve destination standalone HTML comment-only fragments during `replace_mode` section replacement when the template replacement does not already contain standalone comments.
- Revalidated focused Markdown file-analysis / smart-merger / partial-template specs and then revalidated the full `markdown-merge` suite under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`168 examples, 0 failures` focused; `1072 examples, 0 failures` full).
- 2026-03-13: Runtime/backend bootstrap and focused matched-node comment fallback revalidated.
- Added optional backend bootstrap in `lib/markdown/merge.rb` so installed/local `commonmarker-merge` and `markly-merge` backend adapters register before Markdown backend auto-resolution runs.
- Migrated `gemfiles/modular/tree_sitter.gemfile` and `gemfiles/modular/templating.gemfile` to the shared `nomono` local-path pattern with new `*_local.gemfile` companions, restoring sibling workspace development under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb`.
- Restored the explicit invalid-backend `ArgumentError` contract in `Markdown::Merge::SmartMerger` and allowed `PartialTemplateMerger` to accept `backend: :auto` like the full-document merger path.
- Added focused `smart_merger_spec` regressions proving template-preferred fuzzy paragraph matches preserve destination standalone HTML comment-only sections when the template lacks its own comment block, while keeping template comment blocks when they already exist.
- Revalidated focused Markdown file-analysis / smart-merger / partial-template specs and then revalidated the full `markdown-merge` suite under `KETTLE_RB_DEV=/home/pboling/src/kettle-rb` (`144 examples, 0 failures` focused; `1070 examples, 0 failures` full).
- 2026-03-11: Phase 3 / Slice 1 started.
- Added conservative `Markdown::Merge::CommentTracker` for standalone HTML comment line tracking.
- Wired shared comment capability plumbing into `Markdown::Merge::FileAnalysisBase` (`comment_capability`, `comment_nodes`, `comment_node_at`, `comment_region_for_range`, `comment_attachment_for`, `comment_augmenter`) so both Markdown backends share the same comment-analysis surface.
- Added focused `file_analysis_spec` coverage for standalone HTML comment node exposure, heading-leading attachment lookup, and current parser-native ownership behavior without duplicating html-block statements into synthetic preamble/postlude regions.

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
