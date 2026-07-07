# Workflow registry — `aidoc-flow-ci`

Canonical enumeration of every reusable workflow shipped by `aidoc-flow-ci`,
what each does, which workspace repos should adopt it, and legitimate
reasons to skip. This is the source-of-truth for CI-library capabilities —
if a workflow doesn't appear here, it doesn't exist in the library.

> **Companion docs.** [`architecture.md`](architecture.md) covers the
> reusable-workflow model + trust flow. [`multi-project-guide.md`](multi-project-guide.md)
> covers how a new company project onboards. [`overrides.md`](overrides.md)
> covers the 3 override modes. This doc is the workflow-catalog layer.

## 1. Complete workflow catalog (11 reusables)

Every workflow ships as `workflow_call` at
`vladm3105/aidoc-flow-ci/.github/workflows/<name>.yml@ci/vX.Y.Z`.
Pin at a released tag; never `@main` in a consumer.

| # | Workflow | Purpose | Runtime | Origin |
|---|---|---|---|---|
| 1 | `ai-review.yml` | AI code-review gate. Two-job split (trust → reviewer) — safe-by-design for public repos. Submits a formal `--approve`/`--request-changes` review as the reviewer App, sets `ai:review-*` label, arms auto-merge when appropriate. | ~1-5 min | IPLAN-0011 (operations pilot) |
| 2 | `composition.yml` | Authoritative identity gate for **counting** AI approvals. A GitHub App can approve a PR but cannot be a CODEOWNER; composition is the required check that composes the App's approval with human approvals per branch-protection rules. | ~10-30 s | IPLAN-0016 §2a-v3 (A4) |
| 3 | `auto-merge-ai-prs.yml` | Server-side enforcer for AI-opened PRs — detects stuck-green PRs (`ai:review-passed` + `mergeStateStatus:CLEAN` + `autoMergeRequest:null` + `updatedAt > 2 min`) and re-arms `gh pr merge --auto --merge` under the reviewer App's token. | ~15 s | IPLAN-0030 (operations 2026-06-30) |
| 4 | `pre-commit.yml` | Standard `pre-commit run --all-files` runner. Consumer supplies `.pre-commit-config.yaml`; the workflow provides caching + Python setup + pinned pre-commit version. | ~30-90 s | Framework + operations pattern |
| 5 | `codeql.yml` | CodeQL static analysis. Wraps `github/codeql-action@v4`. Language-configurable via `languages:` input; supports `push`/`pull_request`/`schedule` triggers. | ~2-5 min | GitHub-standard code scanning |
| 6 | `secret-scan.yml` | Secret scanning via gitleaks. Wraps `gacts/gitleaks` (MIT, no license key) — deliberately NOT the official `gitleaks/gitleaks-action` (org-license requirement). Scans full history + PR diff. | ~30-60 s | Standard secret-scan pattern |
| 7 | `markdown-lint.yml` | Markdown lint. Wraps `DavidAnson/markdownlint-cli2-action` (first-party successor to `markdownlint-cli`). Consumer supplies `.markdownlint*` config. | ~15-45 s | Standard doc-quality gate |
| 8 | `links.yml` | Link checking via lychee. Wraps `lycheeverse/lychee-action` — Rust-based, async, offline-mode support. Two modes: blocking (offline / internal-only) + weekly (external / soft-fail). | ~30-90 s (offline); ~2-5 min (external) | Standard doc-quality gate |
| 9 | `labeler.yml` | Path-based PR labeling. Reads consumer's `.github/labeler.yml` (v5+ format: `changed-files: any-glob-to-any-file:`) and applies labels. Labels must pre-exist. | ~10 s | Framework `labeler.yml` pattern |
| 10 | `docs-sync.yml` | Mechanical post-merge doc fixer. Runs deterministic transformations (version-reference propagation, structural bump propagation) + commits + opens PR if changes are made. | ~30-60 s | IPLAN-0018 (operations 2026-06-25) |
| 11 | `doc-maintainer.yml` | AI-driven post-merge doc-of-record maintainer. **Supersedes** `docs-sync.yml` at the end of Phase 3 (`ci/v2.0.0`). Uses Claude Code sub-agent dispatch to catch semantic drift `docs-sync.yml`'s deterministic transformations miss. | ~2-5 min | IPLAN-0025 (operations 2026-06-28) |

## 2. Per-repo applicability matrix

Rows = workspace repos. Columns = the 11 workflows. Cell values:

- **✅** — should adopt / adopted
- **⏸ skip** — skippable with rationale (see § "3. Skip guidance" below)
- **N/A** — genuinely not applicable (no matching surface)

| Repo (visibility) | ai-review | composition | auto-merge | pre-commit | codeql | secret-scan | markdown-lint | links | labeler | docs-sync | doc-maintainer |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `aidoc-flow-operations` (private) | ✅ | ✅ | ✅ | ✅ | ⏸ pending | ✅ | ✅ | ✅ | ⏸ pending | N/A (superseded) | ✅ pending |
| `aidoc-flow-framework` (public) | ✅ | ✅ | ⏸ (spec/governance tier — human-merge only) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | N/A | ⏸ per-need |
| `aidoc-flow-business` (private) | ✅ | ✅ | ✅ | ✅ | N/A (docs-only) | ✅ | ✅ | ✅ | ⏸ pending | ⏸ per-need | ⏸ per-need |
| `aidoc-flow-iplanic` (private) | ✅ | ✅ | ✅ | ✅ | ⏸ pending | ✅ | ✅ | ✅ | ⏸ pending | ⏸ per-need | ⏸ per-need |
| `iplan-runner` (public) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⏸ per-need | ⏸ per-need |
| `aidoc-flow-engramory` (public) | ✅ | ✅ | ✅ | ✅ | ⏸ pending (Python) | ✅ | ✅ | ✅ | ⏸ pending | ⏸ per-need | ⏸ per-need |
| `aidoc-flow` (umbrella; private) | ⏸ (submodule pointer PRs only) | ⏸ (same) | ⏸ (downstream of ai-review skip — no `ai:review-passed` label emitted; umbrella uses `gh pr merge --admin` per OPS-0062) | ✅ | N/A | ✅ | ✅ | ✅ | N/A | N/A | N/A |
| `aidoc-flow-iplan-standard` (private) | ✅ pending | ✅ pending | ⏸ (schema-tier — human-merge) | ✅ | N/A (docs-only) | ✅ | ✅ | ✅ | ⏸ pending | ⏸ per-need | ⏸ per-need |
| `aidoc-flow-ci` (public — this repo) | ⏸ (self-referencing) | ⏸ (self-referencing) | ⏸ (spec/governance tier) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | N/A | N/A |
| `aidoc-flow-knowledge-rag` (paused) | — | — | — | — | — | — | — | — | — | — | — |
| `aidoc-flow-site` (paused) | — | — | — | — | — | — | — | — | — | — | — |

**Paused repos** (`knowledge-rag`, `aidoc-flow-site` per founder direction
2026-07-04) — no adoption changes until unpaused.

## 3. Skip guidance — legitimate reasons per workflow

Adopting every workflow on every repo is not the goal. Below are the
canonical skip patterns:

### 3.1 `ai-review.yml` + `composition.yml`

- **Skip on:** submodule-pointer-only umbrella repos (`aidoc-flow`) where
  every PR is a pointer bump — human review of the bump is sufficient; the
  substantive review already ran on the submodule side.
- **Skip on:** the CI library repo itself (`aidoc-flow-ci`) — self-
  referencing bootstrap concern. Human review of CI changes is the
  intentional trust boundary.
- **Never skip on** a repo that opens AI-authored PRs and expects
  auto-merge.

### 3.2 `auto-merge-ai-prs.yml`

- **Skip on:** spec/governance-tier repos deliberately excluded from
  `operations/.github/ai-review/config.json` `auto_merge.repos` allowlist
  (currently `aidoc-flow-framework`, `aidoc-flow-iplan-standard`). Rationale:
  human merges spec/schema changes intentionally.
- **Skip on:** the CI library repo itself (governance tier).
- **Skip on:** the `aidoc-flow` umbrella — even though it IS in the
  `auto_merge.repos` allowlist, its ai-review is skipped (submodule
  pointer PRs only), so no `ai:review-passed` label is ever emitted
  and the enforcer's state filter would exit clean anyway. Umbrella
  merges use `gh pr merge --squash --delete-branch --admin` per
  umbrella `CLAUDE.md` OPS-0062 (unsigned AI commits vs. required-
  signatures ruleset on umbrella main).
- **Otherwise:** adopt — pairs with `ai-review.yml`. Not adopting means AI-
  opened PRs may stall on stuck-green (see IPLAN-0030 §1 failure modes).

### 3.3 `pre-commit.yml`

- **Skip on:** no known legitimate case. Every repo benefits from consistent
  hook execution in CI.

### 3.4 `codeql.yml`

- **Skip on:** docs-only repos with no Python/JavaScript/Go/Ruby/C++ code
  (`business`, `iplan-standard` currently).
- **Adopt on:** any repo with runtime code (`framework`, `iplan-runner`,
  `engramory` (once its Python matures), `operations` for its `scripts/*.py`
  and `.github/scripts/*.py`).

### 3.5 `secret-scan.yml`

- **Skip on:** no known legitimate case. Cost is trivial; blast radius of a
  leaked secret is high.

### 3.6 `markdown-lint.yml` + `links.yml`

- **Skip on:** repos with negligible Markdown surface (rare in this
  workspace — every repo has README + CHANGELOG minimum).
- **`links.yml` weekly external mode** may be skipped on repos with only
  intra-repo links; adopt the offline/blocking mode.

### 3.7 `labeler.yml`

- **Skip on:** repos where PR-label taxonomy is unimportant or unmaintained.
  Adoption requires the consumer to pre-create the labels in the repo
  (actions/labeler does not create labels) + define
  `.github/labeler.yml` path→label map.

### 3.8 `docs-sync.yml`

- **Skip on:** all repos going forward — being **superseded** by
  `doc-maintainer.yml` at end of Phase 3 (`ci/v2.0.0`; per IPLAN-0025 P8).
  New adoptions should go directly to `doc-maintainer.yml`.

### 3.9 `doc-maintainer.yml`

- **Skip on:** repos where the maintenance burden isn't yet a real problem
  (small repos, low PR volume). Adopt when doc-of-record drift becomes a
  recurring theme in review cycles.

## 4. Adoption sequencing for a new workspace repo

When onboarding a new repo (per `multi-project-guide.md`), adopt in this
order — each step depends on the prior:

1. **`pre-commit.yml`** — cheap, low-risk, catches mechanical issues cheaply.
2. **`markdown-lint.yml`** + **`links.yml` (offline mode)** — doc-quality
   floor.
3. **`secret-scan.yml`** — defense-in-depth against accidental commit of
   credentials.
4. **`ai-review.yml`** + **`composition.yml`** (paired — composition is the
   authoritative identity gate for ai-review's App-submitted verdict). At
   this point the reviewer App must be installed on the target repo (F5
   blast-radius prerequisite per operations
   `docs/REPO_ONBOARDING.md` Step 2).
5. **`auto-merge-ai-prs.yml`** — server-side enforcer for the primary
   auto-merge path. Requires the repo be in `auto_merge.repos` allowlist.
6. **`labeler.yml`** — when the repo has meaningful path-based dispatch
   (e.g., `.claude/agents/**` → `governance`, `scripts/**` → `scripts`).
7. **`codeql.yml`** — when the repo has runtime code (Python/JS/etc.).
8. **`links.yml` weekly external mode** — when the repo has non-trivial
   external link surface.
9. **`doc-maintainer.yml`** — after 3-6 months when doc-drift is a
   recurring theme.

**Don't adopt** `docs-sync.yml` on new repos — it's being superseded.

## 5. Version pinning

All consumer callers pin at `@ci/vX.Y.Z`. Current pins in the workspace:

| Workflow | Current stable tag | Notes |
|---|---|---|
| `ai-review.yml` | `@ci/v1.4.3` (operations); `@ci/v1.5.1` (framework) | Consumers bump on their own cadence |
| `composition.yml` | `@ci/v1.3.0` (operations); `@ci/v1.5.1` (framework) | Consumers bump on their own cadence |
| `auto-merge-ai-prs.yml` | `@ci/v1.5.1` | Latest — added timeout-minutes: 10 fix |
| others | `@ci/v1.4.x` or newer per consumer | See individual repo caller pins |

The [`../CHANGELOG.md`](../CHANGELOG.md) is the source-of-truth for tag →
change mapping.

## 6. Drift detection

The [`sync/check-drift.sh`](../sync/check-drift.sh) script compares each
consumer's `.github/workflows/*.yml` against the canonical template at the
pinned `ci/vX.Y.Z` tag and reports any diff as a `::warning::`. Warning-only,
never blocks. When a consumer legitimately deviates (parameter override,
full replacement, custom workflow — see [`overrides.md`](overrides.md)), the
warning is the operator's opportunity to reconcile intent.

## 7. Change log

- 2026-07-06 — Initial registry codified.

## 8. Cross-references

- [`architecture.md`](architecture.md) — reusable-workflow model + trust flow
- [`multi-project-guide.md`](multi-project-guide.md) — new-project onboarding flow
- [`overrides.md`](overrides.md) — the 3 override modes
- [`security.md`](security.md) — threat model + secrets
- [`runners.md`](runners.md) — self-hosted runner labels + provisioning
- [`troubleshooting.md`](troubleshooting.md) — common issues + fixes
- [`ai-review-assets.md`](ai-review-assets.md) — reviewer App + rubric
- [`local-pre-push.md`](local-pre-push.md) — consumer-side pre-push pattern
- `aidoc-flow-operations` `docs/REPO_ONBOARDING.md` — canonical rules +
  activation checklist for adding a new repo to the workspace
- `aidoc-flow-operations` `.github/ai-review/config.json` — trust
  allowlist + `auto_merge.repos` allowlist
