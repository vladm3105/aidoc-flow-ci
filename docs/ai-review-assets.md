# Reviewer assets (`ai-review/`)

How the shared `ai-review/` directory is structured + consumed + when
consumers should consider overriding (future).

For the consumer-facing intro see [`../README.md`](../README.md). For
the architecture see [`architecture.md`](architecture.md). For per-project
framing see [`multi-project-guide.md`](multi-project-guide.md).

## 1. What lives here

[`aidoc-flow-ci/ai-review/`](../ai-review/) holds the reviewer assets that
the `.github/workflows/ai-review.yml` reusable workflow consumes at
review-time:

| File | Role |
|---|---|
| `review-prompt.md` | The system prompt for the reviewer LLM — defines the rubric (severity scale, review dimensions, doc-currency rule, governance-PR discipline, anti-injection guidance) |
| `verdict.schema.json` | JSON Schema for the structured verdict; downstream parser depends on this shape |
| `README.md` | What's here + pointers |

Per [IPLAN-0022](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0022_source-of-truth-migration.md)
these assets moved here from `aidoc-flow-operations/.github/ai-review/` as
of `ci/v1.1.0`+. Before IPLAN-0022 the reusable workflow checked out
operations@main for the assets; that path is now removed.

## 2. How the workflow consumes them

```yaml
# In aidoc-flow-ci/.github/workflows/ai-review.yml
- name: Resolve aidoc-flow-ci pinned ref from workflow_ref
  id: pin
  env:
    GITHUB_WORKFLOW_REF: ${{ github.workflow_ref }}
  run: |
    # github.workflow_ref looks like:
    # vladm3105/aidoc-flow-ci/.github/workflows/ai-review.yml@ci/v1.1.0
    REF="${GITHUB_WORKFLOW_REF##*@}"
    echo "ref=$REF" >> "$GITHUB_OUTPUT"

- name: Checkout reviewer assets from aidoc-flow-ci (at pinned tag)
  uses: actions/checkout@<sha>
  with:
    repository: vladm3105/aidoc-flow-ci
    ref: ${{ steps.pin.outputs.ref }}
    path: ./reviewer-assets
    sparse-checkout: ai-review
    sparse-checkout-cone-mode: false
```

**Subsequent steps** read:

- Rubric: `$GITHUB_WORKSPACE/reviewer-assets/ai-review/review-prompt.md`
- Schema: `$GITHUB_WORKSPACE/reviewer-assets/ai-review/verdict.schema.json`

**Pin semantics:** the assets are versioned with the rest of the library
via `ci/vX.Y.Z` tags. A consumer pinned at `@ci/v1.0.6` gets the OLD assets
(via the legacy operations@main path on workflow versions before
IPLAN-0022). A consumer pinned at `@ci/v1.1.0` or newer gets the assets
from this directory at that tag.

**Sparse-checkout** keeps the clone small (only `ai-review/`, not the
whole aidoc-flow-ci tree).

## 3. Per-consumer override (future; not shipped today)

Per IPLAN-0022 §3.3, per-consumer override is **explicitly deferred** to a
future IPLAN. Today every consumer uses the shared rubric here.

When a real consumer demands a different rubric (e.g., business wanting
non-technical framing; framework wanting SDD-spec-compliance focus), a
future IPLAN can add the runtime path-existence check:

- Consumer ships `.github/ai-review/review-prompt.md` → workflow uses it
  INSTEAD of the shared aidoc-flow-ci default
- Matches IPLAN-0017 §3.1a's "local always wins" philosophy applied to
  asset files (similar pattern, different mechanism — workflow files
  get the override for free via GitHub Actions; asset files need
  engineering)

Until that future IPLAN ships, consumers can fork + override at the
workflow level (custom workflow consuming a different rubric path) — but
this is heavy-handed and rarely justified.

## 4. Editing the assets

Changes to `review-prompt.md` or `verdict.schema.json`:

1. Open PR on `aidoc-flow-ci` (this repo) with the change
2. PR goes through normal CI (lint + ai-review on the change itself)
3. After merge, ship as a new `ci/vX.Y.Z` tag
4. Consumers consume at their next pin-bump (per-consumer decision)

**Verdict schema changes** require extra care — downstream parser (in the
reusable workflow's gate / comment / label / merge step) depends on the
shape. A breaking schema change requires `ci/v2.X.Y` (major bump) +
coordinated rollout.

## 5. Why these assets aren't in `.github/`

`aidoc-flow-ci/.github/` is for **this repo's own GitHub config** (its
workflows, issue templates, etc.). The reviewer assets are **library
content** that consumers fetch via the reusable workflow — distinct
purpose, so they live at the top level next to other library content
(`scripts/`, `install/`, `docs/`).

Same precedent: `aidoc-flow-ci/scripts/docs-sync/` (per IPLAN-0018; top-level)
+ this `ai-review/` directory.

## 6. References

- [`../ai-review/README.md`](../ai-review/README.md) — directory contents pointer
- [IPLAN-0022](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0022_source-of-truth-migration.md) — the migration plan
- [`architecture.md`](architecture.md) — three-layer CI architecture
- [`multi-project-guide.md`](multi-project-guide.md) — multi-project framing
- [`local-pre-push.md`](local-pre-push.md) — pre-push self-check (uses the same rubric locally)
