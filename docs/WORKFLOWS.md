# Workflow registry — `aidoc-flow-ci`

Canonical enumeration of every reusable workflow shipped by `aidoc-flow-ci`,
what each does, which workspace repos should adopt it, and legitimate
reasons to skip. This is the source-of-truth for CI-library capabilities —
if a workflow doesn't appear here, it doesn't exist in the library.

> **Companion docs.** [`architecture.md`](architecture.md) covers the
> reusable-workflow model + trust flow. [`multi-project-guide.md`](multi-project-guide.md)
> covers how a new company project onboards. [`overrides.md`](overrides.md)
> covers the 3 override modes. This doc is the workflow-catalog layer.

## 1. Complete workflow catalog (12 reusables)

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
| 12 | `audit-trail-check.yml` | OPS-0069 audit-trail phrase gate. Belt-and-suspenders CI check for the local pre-push hook (REPO_STANDARDS.md §14): verifies every non-exempt PR carries `Multi-agent self-review per OPS-0065` OR `Self-review skipped per founder OK` in some commit body. Exemptions: bot-authored range (dependabot/renovate/github-actions), revert-only range, two-signal `skip-audit-trail` label + body marker. Check-name renders as `call / verify`. `fetch-depth: 0` prevents fork-PR false-pass. | ~10-30 s | PLAN-002 PR-U3 (2026-07-08) |

## 2. Per-repo applicability matrix

Rows = workspace repos. Columns = the 12 workflows. Cell values:

- **✅** — should adopt / adopted
- **⏸ skip** — skippable with rationale (see § "3. Skip guidance" below)
- **N/A** — genuinely not applicable (no matching surface)

**Cell values (matrix legend):**

- **✅** — adopted (using the reusable at a pinned `@ci/vX.Y.Z` tag)
- **⚠️ GAP** — should adopt but missing (actionable follow-up)
- **🕳 custom** — local equivalent workflow shipped (not calling the reusable); consider migrating to the reusable for consistency
- **⏸ skip** — deliberately skipped with rationale
- **N/A** — not applicable (no matching surface)

Actual state audited 2026-07-07 via `gh api repos/*/contents/.github/workflows`
against every workspace repo.

| Repo (visibility) | ai-review | composition | auto-merge | pre-commit | codeql | secret-scan | markdown-lint | links | labeler | docs-sync | doc-maintainer | audit-trail |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `aidoc-flow-operations` (private) | ✅ | ✅ | ✅ | ✅ | ⚠️ GAP (scripts/*.py + .github/scripts/*.py present) | 🕳 custom (`security.yml` — bare gitleaks) | 🕳 custom (`docs-lint.yml`) | ✅ | ⚠️ GAP | ✅ | ✅ | ⚠️ GAP (Wave 2 rollout) |
| `aidoc-flow-framework` (public) | ✅ | ✅ | ⏸ (spec/governance tier — human-merge only) | ✅ | ✅ | ⚠️ GAP | ⚠️ GAP (pre-commit local markdownlint may cover) | ⚠️ GAP | ✅ | N/A | ⏸ per-need | ⚠️ GAP (Wave 1 rollout) |
| `aidoc-flow-business` (private) | ✅ | ✅ | ✅ | ✅ | N/A (docs-only) | ⚠️ GAP | ⚠️ GAP | ✅ | ⚠️ GAP | ⏸ per-need | ⏸ per-need | ⚠️ GAP (Wave 2 rollout) |
| `aidoc-flow-iplanic` (private) | ✅ | ✅ | ✅ | ✅ | ⚠️ GAP (runtime Python) | ⚠️ GAP | ⚠️ GAP | ⚠️ GAP | ⚠️ GAP | ⏸ per-need | ⏸ per-need | ⚠️ GAP (Wave 2 rollout) |
| `iplan-runner` (public) | ✅ | **⚠️ GAP (missing composition.yml — ai-review verdict not authoritatively gated)** | ✅ | ✅ | ✅ | ⚠️ GAP (repo's `security.yml` is `pip-audit` dependency-audit, not gitleaks — orthogonal concern) | ⚠️ GAP | ⚠️ GAP | ✅ | ⏸ per-need | ⏸ per-need | ⚠️ GAP (Wave 3 rollout) |
| `aidoc-flow-engramory` (public) | ✅ | ✅ | ✅ | **⚠️ GAP** (only `ci.yml` — no pre-commit reusable) | ⚠️ GAP (Python maturing) | ⚠️ GAP | ⚠️ GAP | ⚠️ GAP | ⚠️ GAP | ⏸ per-need | ⏸ per-need | ⚠️ GAP (Wave 3 rollout) |
| `aidoc-flow` (umbrella; private) | ⏸ (submodule pointer PRs only) | ⏸ (same) | ⏸ (downstream of ai-review skip — no `ai:review-passed` label emitted; umbrella uses `gh pr merge --admin` per OPS-0062) | ⚠️ GAP (has 4 site-flavor workflows: `nightly-live.yml` / `post-deploy.yml` / `pr-checks.yml` / `release.yml` — no `pre-commit.yml`) | N/A | ⚠️ GAP | ⚠️ GAP | ⚠️ GAP | N/A | N/A | N/A | ⚠️ GAP (Wave 5 rollout; advisory only per REPO_STANDARDS.md §14.3 — umbrella has `required_status_checks: null`) |
| `aidoc-flow-iplan-standard` (private) | ⚠️ GAP (planned) | ⚠️ GAP (planned) | ⏸ (schema-tier — human-merge) | ⚠️ GAP | N/A (docs-only) | ⚠️ GAP | ⚠️ GAP | ⚠️ GAP | ⚠️ GAP | ⏸ per-need | ⏸ per-need | ⚠️ GAP (Wave 1 rollout) |
| `aidoc-flow-interlog` (private; new 2026-07-06) | ⚠️ GAP (planned; charter/discovery) | ⚠️ GAP (planned) | ⚠️ GAP (planned) | ⚠️ GAP | ⚠️ GAP (Python-planned) | ⚠️ GAP | ⚠️ GAP | ⚠️ GAP | ⚠️ GAP | ⏸ per-need | ⏸ per-need | ⏸ (bootstrap-tier — local hook only per REPO_STANDARDS.md §14.3; CI caller pending CI adoption) |
| `aidoc-flow-ci` (public — this repo) | ⏸ (self-referencing) | ⏸ (self-referencing) | ⏸ (spec/governance tier) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | N/A | N/A | ⚠️ GAP (Wave 0 self-adoption via PR-U4) |
| `aidoc-flow-knowledge-rag` (paused) | — | — | — | — | — | — | — | — | — | — | — | — |
| `aidoc-flow-site` (paused) | — | — | — | — | — | — | — | — | — | — | — | — |

**Paused repos** (`knowledge-rag`, `aidoc-flow-site` per founder direction
2026-07-04) — no adoption changes until unpaused.

### 2.1 Gap summary — actionable follow-up

Aggregated ⚠️ GAP cells above (paused repos + N/A excluded). Each row is a
potential single-PR consumer adoption; ordering is by adoption-sequence
step (§4) so `pre-commit` → `secret-scan` → `markdown-lint` etc.:

- **Critical gap:** `iplan-runner` MISSING `composition.yml`. The
  ai-review verdict is not authoritatively enforced without it — a
  reviewer-App approval is announced but not composed as a required
  check for merge.
- **Critical gap:** `aidoc-flow-engramory` MISSING `pre-commit.yml`. Only
  ships `ci.yml` locally; pre-commit hygiene not applied in CI.
- **Missing on ALL non-`aidoc-flow-ci` active repos** except operations
  (custom gitleaks-based `security.yml`): `secret-scan.yml`. Gitleaks
  secret scanning is high-value + trivial cost — should adopt.
  (iplan-runner ships `security.yml` too but it is `pip-audit`
  dependency-audit — a separate concern from secret-scan; no reusable
  `pip-audit.yml` exists in this library yet.)
- **Missing on most repos**: `markdown-lint.yml`. Operations has a
  local `docs-lint.yml`; framework's pre-commit stack has markdownlint;
  everyone else has nothing.
- **Missing on most repos**: `links.yml`. Adopted today by operations +
  business (plus aidoc-flow-ci itself, which ships the reusable).
  Blocking `links.yml (offline)` is a doc-quality floor.
- **Missing on most repos**: `labeler.yml`. Only framework + iplan-runner
  + aidoc-flow-ci adopt. Path-based labels reinforce OPS-0065 diff-class
  visibility — should adopt.
- **Missing on repos with Python code**: `codeql.yml`. Operations
  (`scripts/*.py`), iplanic (runtime Python), engramory (Python maturing),
  interlog (Python planned).
- **Migration candidate: custom → reusable**: operations
  `security.yml` (gitleaks) + `docs-lint.yml` — could migrate to
  `secret-scan.yml` + `markdown-lint.yml` reusables for consistency +
  drift detection. iplan-runner `security.yml` is `pip-audit` — separate
  category (no reusable target yet; potential future
  `pip-audit.yml` addition).

### 2.2 Bootstrap-tier repos

- `aidoc-flow-interlog` (created 2026-07-06 per GitHub `created_at`;
  project memory noted 2026-07-07 which was the update timestamp) is
  bootstrap-tier — no CI adopted yet. First CI PR should follow §4
  adoption sequencing.
- `aidoc-flow-iplan-standard` currently ships only `conformance.yml` (a
  local workflow, not the reusable). ai-review + composition + pre-commit
  + all doc-quality workflows planned per its Phase D onboarding (per
  operations `docs/REPO_ONBOARDING.md`).

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

### 3.10 `audit-trail-check.yml`

- **Skip on: bootstrap tier** (`aidoc-flow-interlog`) — local pre-push
  hook enforces OPS-0069 authoritatively; CI belt-and-suspenders adopts
  only when the repo joins the ai-review consumer set (per
  `REPO_STANDARDS.md` §14.3).
- **Skip on: paused repos** (`aidoc-flow-knowledge-rag`,
  `aidoc-flow-site`) — no adoption changes until unpaused.
- **Advisory-only on: umbrella tier** (`aidoc-flow`) — canon
  branch-protection has `required_status_checks: null` by design;
  workflow is installed but the check is NOT added to the (nonexistent)
  contexts array. `--admin` merges route around it anyway (OPS-0062
  governance layer). Local hook is the load-bearing enforcement point
  for umbrella submodule-pointer PRs.
- **Adopt everywhere else** (governance / product / ops-private tiers).
  Pin at `ci/v1.6.0` (first release including this reusable) per PLAN-002
  §5.3. Ensure the `skip-audit-trail` canon label is present in the
  consumer repo (added to `install/templates/labels.json` in PR-U3;
  `install/install.sh` creates it during initial bootstrap).

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
- 2026-07-07 — Registry audited against actual repo state via
  `gh api repos/*/contents/.github/workflows` across every workspace
  repo. Cell values expanded from `✅ / ⏸ / N/A` to `✅ / ⚠️ GAP /
  🕳 custom / ⏸ / N/A`. Prior version conflated "should adopt" and
  "actually adopted" — the audit surfaced 2 critical gaps
  (iplan-runner missing `composition.yml`; engramory missing
  `pre-commit.yml`), 4 near-universal gaps (`secret-scan`,
  `markdown-lint`, `links`, `labeler` missing from most repos), 3
  custom-vs-reusable migration candidates (operations
  `security.yml` + `docs-lint.yml`; iplan-runner `security.yml`),
  and 1 new bootstrap-tier repo (`aidoc-flow-interlog`). §2.1 added
  as actionable follow-up. §2.2 flags bootstrap-tier repos.

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
