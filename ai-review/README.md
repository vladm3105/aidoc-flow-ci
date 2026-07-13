# `ai-review/` — shared reviewer assets

Per [IPLAN-0022](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0022_source-of-truth-migration.md)
this directory is the canonical home for the reviewer assets that
`aidoc-flow-ci/.github/workflows/ai-review.yml` consumes at review-time.

## What's here

| File | What | Notes |
|---|---|---|
| `review-prompt.md` | The system prompt the reviewer LLM uses (98 lines) — defines the rubric (severity scale, dimensions, doc-currency rule, governance-PR discipline, anti-injection guidance) | Generalized 2026-06-25 to address "the calling consumer repo" instead of `aidoc-flow-operations` specifically (1-line additive change vs the 97-line source on operations) |
| `verdict.schema.json` | JSON Schema for the structured verdict the reviewer emits | Downstream parsers depend on this shape; changes require careful coordination |
| `README.md` | This file | — |

## How it's consumed

The reusable `ai-review.yml` workflow checks out `aidoc-flow-ci` at the
**consumer's pinned tag** (parsed from `github.workflow_ref`) via
sparse-checkout (only this directory), then passes:

- `review-prompt.md` → instructions prepended to the LiteLLM request
- `verdict.schema.json` → downstream parser for the structured verdict

## Why aidoc-flow-ci instead of operations

Per [IPLAN-0017-CHARTER §1](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017-CHARTER_aidoc-flow-ci.md#1-purpose),
`aidoc-flow-ci` is the **single source-of-truth for CI infrastructure**
across all aidoc-flow consumers + future company projects. The reviewer
assets are CI infrastructure (not operations governance), so they belong
here. Before IPLAN-0022 they lived on `aidoc-flow-operations` as a
transitional hardcode; that's now legacy.

## Per-consumer override (future)

Per IPLAN-0022 §3.3, per-consumer override (consumer ships
`.github/ai-review/review-prompt.md` to override the shared default) is
**out of scope** for the initial migration — deferred to a future IPLAN
when a real consumer requests it. Today every consumer uses the shared
rubric here.

## Editing

Changes to `review-prompt.md` or `verdict.schema.json` ship as `aidoc-flow-ci`
PRs (this repo). They take effect for consumers on their **next pin-bump**
to a newer `ci/vX.Y.Z` tag — consumers pinned at older tags keep using the
older asset version (semver-honest).

## References

- [`docs/ai-review-assets.md`](../docs/ai-review-assets.md) — the canonical
  consumer-facing spec for these assets + override pattern future
- [IPLAN-0022 — the migration plan](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0022_source-of-truth-migration.md)
- [`docs/architecture.md`](../docs/architecture.md) — three-layer CI architecture
- [`docs/multi-project-guide.md`](../docs/multi-project-guide.md) — multi-project framing
