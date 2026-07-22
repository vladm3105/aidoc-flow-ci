# Workflow registry — `aidoc-flow-ci`

Canonical enumeration of every reusable workflow shipped by `aidoc-flow-ci`,
what each does, which workspace repos should adopt it, and legitimate
reasons to skip. This is the source-of-truth for CI-library capabilities —
if a workflow doesn't appear here, it doesn't exist in the library.

> **Companion docs.** [`architecture.md`](architecture.md) covers the
> reusable-workflow model + trust flow. [`multi-project-guide.md`](multi-project-guide.md)
> covers how a new company project onboards. [`overrides.md`](overrides.md)
> covers the 3 override modes. This doc is the workflow-catalog layer.

## 1. Complete workflow catalog (16 reusables)

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
| 6 | `secret-scan.yml` | Secret scanning via gitleaks. Installs the pinned gitleaks **binary** directly in a `run:` step (MIT, no key) — NOT a marketplace wrapper (canon may `uses:` only `actions/*`, `github/*`, `vladm3105/aidoc-flow-ci/*` per REPO_STANDARDS §4.3, and the gitleaks wrappers are non-verified creators, so they are also blocked at run-init → `startup_failure`; fixed `ci/v1.9.2`). Ships a default test-fixture allowlist; SARIF upload is `continue-on-error` for private repos without Advanced Security. | ~30-60 s | Standard secret-scan pattern |
| 7 | `markdown-lint.yml` | Markdown lint via `markdownlint-cli2`, installed from npm after allowlisted `actions/setup-node` — NOT the `DavidAnson/markdownlint-cli2-action` wrapper (allowlist-blocked; fixed `ci/v1.9.4`). `fail-on-findings` input (default true) → set `false` for a **report-only** rollout (`ci/v1.9.5`; `continue-on-error` is illegal on reusable-call jobs). Consumer supplies `.markdownlint*` config. | ~15-45 s | Standard doc-quality gate |
| 8 | `links.yml` | Link checking via the lychee **musl static binary**, installed + SHA-256-verified in a `run:` step — NOT the `lycheeverse/lychee-action` wrapper (allowlist-blocked; fixed `ci/v1.9.4`; musl not gnu, which needs GLIBC 2.38+ and dies on older self-hosted Debian runners). Two modes: blocking (offline / internal-only) + weekly (external / soft-fail). Cross-repo `../sibling/` links need a `.lychee.toml` exclude (they resolve only in the local multi-repo workspace). | ~30-90 s (offline); ~2-5 min (external) | Standard doc-quality gate |
| 9 | `labeler.yml` | Path-based PR labeling. Reads consumer's `.github/labeler.yml` (v5+ format: `changed-files: any-glob-to-any-file:`) and applies labels. Labels must pre-exist. | ~10 s | Framework `labeler.yml` pattern |
| 10 | `docs-sync.yml` | Mechanical post-merge doc fixer. Runs deterministic transformations (version-reference propagation, structural bump propagation) + commits + opens PR if changes are made. | ~30-60 s | IPLAN-0018 (operations 2026-06-25) |
| 11 | `doc-maintainer.yml` | AI-driven post-merge doc-of-record maintainer. **Supersedes** `docs-sync.yml` in `ci/v2.0.0`. LiteLLM selects the documentation that a merged PR made stale, then proposes bounded edits under the repository's path/risk policy. | ~2-5 min | IPLAN-0025 (operations 2026-06-28) |
| 14 | `trivy-scan.yml` | IaC / misconfiguration gate via **trivy binary** (`trivy config` mode only — Dockerfile/IaC misconfig; NOT `trivy fs`, which would duplicate dep-scan + secret-scan). SHA-256-verified `run:` install (not `aquasecurity/trivy-action`, allowlist-blocked §4.3). **Uniform protected + fork-guarded** (PLAN-014). Data-only, **SSRF-hardened** — restricted to static scanners (`--misconfig-scanners dockerfile,kubernetes,cloudformation,azure-arm`) because trivy's terraform/helm/ansible scanners fetch PR-controlled remote sources. `fail-on-findings` (default false → report-only). Best-effort SARIF → Code scanning. | ~20-90 s | PLAN-014 (`ci/v2.5.0`) |
| 15 | `sast-scan.yml` | SAST (static code analysis) gate via **semgrep** (VERSION-pinned pip into an isolated venv — semgrep is Python, not a static binary; no third-party action, §4.3). Complements native CodeQL (which needs GHAS → N/A on private), so this gates PRIVATE repos too. **Uniform protected + fork-guarded** (PLAN-014). Data-only static AST analysis; `--metrics off` (no telemetry to semgrep.dev) + EXPLICIT `--config` (never repo-local auto-discovery, so a PR can't inject rules); strips PR-supplied `.semgrepignore` (gate owns coverage). `config` input (default `p/default`). `fail-on-findings` (default false → report-only). Optional `autofix-preview` (`ci/v2.7.0`, default false): surfaces semgrep's **deterministic** rule-provided `--autofix` patch in the job summary — **preview only, nothing pushed** (no App); model-based push-back is autofix (PLAN-012). Best-effort SARIF → Code scanning. | ~40-120 s (×2 w/ preview) | PLAN-014 (`ci/v2.6.0`, `ci/v2.7.0`) |
| 13 | `dep-scan.yml` | Dependency-vulnerability (SCA) gate via **osv-scanner binary** (SHA-256-verified `run:` install — NOT `google/osv-scanner-action`, allowlist-blocked §4.3). **Uniform protected** (PLAN-014): one self-hosted template, public+private, no visibility split (a flip is a no-op); **fork-guarded** (forks skip → human review; data-only, never `--call-analysis`). `fail-on-findings` (default false → report-only rollout). Best-effort SARIF → Code scanning (`continue-on-error`; no-ops on private w/o GHAS). | ~20-60 s | PLAN-014 (`ci/v2.4.0`) |
| 16 | `standards-drift.yml` | Consumer-installable server-side drift detector (PLAN-015 B2). `workflow_call` reusable: fetches `check-standards-drift.sh` from the adopted canon tag and runs it against the CALLER repo, comparing branch protection / repo settings / actions-permissions / labels against the tier template. Warning-only by default (IPLAN-0017 §3.1b); `strict: true` for a release/adoption gate. Opt-in (`auto_install: false`); `-private` variant for the self-hosted pool. Canon's own weekly self-check is `standards-drift-self.yml`. | ~20-60 s | PLAN-015 (`ci/v2.8.0`) |
| 12 | `audit-trail-check.yml` | OPS-0069 audit-trail phrase gate. Belt-and-suspenders CI check for the local pre-push hook (REPO_STANDARDS.md §14): verifies every non-exempt PR carries `Multi-agent self-review per OPS-0065` OR `Self-review skipped per founder OK` in some commit body. Exemptions: bot-authored range (dependabot/renovate/github-actions), revert-only range, two-signal `skip-audit-trail` label + body marker. Check-name renders as `call / verify`. `fetch-depth: 0` prevents fork-PR false-pass. | ~10-30 s | PLAN-002 PR-U3 (2026-07-08) |

## 2. Per-repo applicability matrix

Rows = workspace repos. Columns = the 12 **core** workflows (the 4 opt-in
surfaces — `dep-scan`, `trivy-scan`, `sast-scan`, `standards-drift` — are adopted
per-repo and are not matrixed). Cell values:

- **✅** — should adopt / adopted
- **⏸ skip** — skippable with rationale (see § "3. Skip guidance" below)
- **N/A** — genuinely not applicable (no matching surface)

**Cell values (matrix legend):**

- **✅** — adopted (using the reusable at a pinned `@ci/vX.Y.Z` tag)
- **⚠️ GAP** — should adopt but missing (actionable follow-up)
- **🕳 custom** — local equivalent workflow shipped (not calling the reusable); consider migrating to the reusable for consistency
- **⏸ skip** — deliberately skipped with rationale
- **N/A** — not applicable (no matching surface)

Actual state audited **2026-07-11** via `gh api repos/*/contents/.github/workflows`
+ `gh repo view --json visibility` against every workspace repo (post
content-check population; `ci/v1.9.5`). **The ai-review / composition / pre-commit /
audit-trail cells were re-verified live 2026-07-14** (PLAN-009 exploration): every
previously-flagged `⚠️ GAP`/`inert` caller now exists at `@ci/v1.9.5` — business
`audit-trail.yml`, iplan-runner `composition.yml`, engramory `pre-commit.yml`,
iplan-standard `ai-review.yml`/`composition.yml`/`pre-commit.yml` — so those cells
are now ✅. Remaining `⚠️ GAP` cells (e.g. engramory/iplanic/interlog `codeql`
Python-maturing) are genuine, not stale.

| Repo (visibility) | ai-review | composition | auto-merge | pre-commit | codeql | secret-scan | markdown-lint | links | labeler | docs-sync | doc-maintainer | audit-trail |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `aidoc-flow-operations` (private) | ✅ | ✅ | ✅ | ✅ | ⚠️ GAP (scripts/*.py) | ✅ | 🕳 custom (`docs-lint.yml`) | ✅ | ✅ | ✅ | ✅ | ✅ |
| `aidoc-flow-framework` (public) | ✅ | ✅ | ⏸ (spec tier — human-merge) | ✅ | ✅ | ✅ | 🕳 own (pre-commit markdownlint) | ✅ | ✅ | ✅ (dry-run) | ⏸ per-need | ✅ |
| `aidoc-flow-business` (private) | ✅ | ✅ | ✅ | ✅ | N/A (docs-only) | 🕳 custom (`security.yml`) | ✅ (report-only) | ✅ | ✅ | ✅ (dry-run) | ⏸ per-need | ✅ |
| `aidoc-flow-iplanic` (private) | ✅ | ✅ | ✅ | ✅ | ⚠️ GAP (runtime Python) | ✅ | ✅ (report-only) | ✅ | ✅ | ✅ (dry-run) | ⏸ per-need | ✅ |
| `iplan-runner` (public) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (report-only) | ✅ | ✅ | ✅ (dry-run) | ⏸ per-need | ✅ |
| `aidoc-flow-engramory` (public) | ✅ | ✅ | ✅ | ✅ | ⚠️ GAP (Python maturing) | ✅ | ✅ (report-only) | ✅ | ✅ | ✅ (dry-run) | ⏸ per-need | ✅ |
| `aidoc-flow-iplan-standard` (public) | ✅ | ✅ | ✅ | ✅ | N/A (docs-only) | ✅ | ✅ (report-only) | ✅ | ✅ | ✅ (dry-run) | ⏸ per-need | ✅ |
| `aidoc-flow-interlog` (private) | ✅ | ✅ | ✅ | ✅ | ⚠️ GAP (Python-planned) | 🕳 custom (`security.yml`) | ✅ (report-only) | ✅ | ✅ | ✅ (dry-run) | ⏸ per-need | ✅ |
| `aidoc-flow-ci` (public — ships the reusables) | ⏸ (self-ref) | ⏸ (self-ref) | ⏸ (gov tier) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ (ships) | ✅ (ships) | ✅ |
| `aidoc-flow` (umbrella; private) | ⏸ (pointer PRs only) | ⏸ (same) | ⏸ (admin-merge per OPS-0062) | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | ⏸ advisory (umbrella `required_status_checks: null`) |
| `aidoc-flow-knowledge-rag` (paused) | — | — | — | — | — | — | — | — | — | — | — | — |
| `aidoc-flow-site` (paused) | — | — | — | — | — | — | — | — | — | — | — | — |

**Content-check surface is COMPLETE** (`secret-scan` / `markdown-lint` /
`links` / `labeler` / `docs-sync`) across every active repo — via the canon
reusable, or a documented `🕳 custom`/`own` equivalent (operations
`docs-lint.yml`, framework pre-commit markdownlint, business/interlog
`security.yml` gitleaks). `markdown-lint` runs **report-only**
(`fail-on-findings: false`) on the canon adopters; `docs-sync` runs **dry-run**
on the repos populated 2026-07-11 (`ci` + `operations` predate this and set
their own mode via `.github/docs-sync.json`). Graduation to blocking / live is
opt-in per repo (see §2.1).

**Paused repos** (`knowledge-rag`, `aidoc-flow-site` per founder direction
2026-07-04) — no adoption changes until unpaused.

### 2.1 Gap summary — actionable follow-up

The content-check + labeler surface (`secret-scan` / `markdown-lint` /
`links` / `labeler` / `docs-sync`) is now **complete** across all active repos
(2026-07-11 population; `ci/v1.9.4`/`v1.9.5`). Remaining ⚠️ GAP cells and
open graduations:

**Graduations (deliberate opt-in, not dev gaps):**

- **`markdown-lint` report-only → blocking.** Runs everywhere with
  `fail-on-findings: false` (surfaces `::error` annotations, doesn't block).
  Graduating a repo to a blocking gate needs a `markdownlint-cli2 --fix`
  remediation pass (≈259 cosmetic residual/repo under the shipped
  `.markdownlint.json`) + adding the check to branch protection. Tracked in
  `plans/FRAMEWORK-TODO.md` (FT-11).
- **`docs-sync` dry-run → live.** Runs everywhere in dry-run (proposes
  doc-fixes as a PR comment; no push-back). Graduating to auto-commit needs
  the **`aidoc-flow-bot` App + `AIDOC_FLOW_BOT_ID`/`AIDOC_FLOW_BOT_KEY`
  secrets** provisioned per repo (🔴 founder action; only `ci` + `operations`
  have it). Note `docs-sync` is also slated for `doc-maintainer.yml`
  supersession at `ci/v2.0.0` (§3.8) — treat these dry-run adoptions as the
  interim mechanical layer.

**Remaining true gaps (non-content-check):**

> **Re-verified live 2026-07-14 (PLAN-009):** the ai-review / composition /
> pre-commit / audit-trail callers previously listed here as missing all now
> exist at `@ci/v1.9.5` — `iplan-runner composition.yml`, `aidoc-flow-iplan-standard`
> `ai-review.yml`/`composition.yml`/`pre-commit.yml`, `aidoc-flow-engramory
> pre-commit.yml`, `aidoc-flow-business audit-trail.yml`. Those gaps are CLOSED;
> only the `codeql` + custom→reusable-migration items below remain.

- `codeql.yml` missing on Python repos still lacking it: operations
  (`scripts/*.py`), iplanic, engramory, interlog.
- **Migration candidates (custom → reusable):** operations `docs-lint.yml`
  → `markdown-lint.yml`; business/interlog `security.yml` (gitleaks) →
  `secret-scan.yml`. Functionally covered today; migrate for drift-detection
  consistency. iplan-runner `security.yml` is `pip-audit` (separate concern;
  no reusable target yet).

### 2.2 Bootstrap-tier repos — none remaining

Both previously-bootstrap repos are now fully CI-adopted:

- `aidoc-flow-interlog` — adopted the full gate + content-check surface
  (ai-review, composition, auto-merge, pre-commit, audit-trail, links,
  markdown-lint, docs-sync, labeler; secret-scan via own `security.yml`).
- `aidoc-flow-iplan-standard` — now adopts the full gate: `ai-review`,
  `composition`, `pre-commit` callers all present at `@ci/v1.9.5` (verified
  2026-07-14), plus the content-check surface + audit-trail + the
  `auto-merge-ai-prs` caller (in the `auto_merge.repos` allowlist). Its
  auto-merge is functional now that `ai-review` emits the `ai:review-passed`
  label the enforcer keys off.

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
  `operations/.github/ai-review/config.json` `auto_merge.repos` allowlist —
  currently only `aidoc-flow-framework` (verified against the live config
  2026-07-11). Rationale: a human merges spec/schema changes intentionally.
  (`aidoc-flow-iplan-standard` IS in the allowlist + ships the caller, and its
  auto-merge is functional now that `ai-review` is present and emits the
  `ai:review-passed` label the enforcer keys off — see the §2 matrix.)
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

- **Deployed fleet-wide in DRY-RUN** (2026-07-11) as the interim mechanical
  doc-fixer — proposes CHANGELOG-stub / version-sync changes as a PR comment
  with **no push-back and no App required** (the `aidoc-flow-bot` App is only
  referenced by the live-mode "Apply" step, gated by `dry_run != true`).
- **Live-mode graduation** (`dry_run: false`) needs the `aidoc-flow-bot` App +
  secrets per repo (🔴 founder) — do this only where mechanical auto-commit
  earns its keep.
- **Superseded by `doc-maintainer.yml`** in `ci/v2.0.0` (IPLAN-0025 P8).
  Existing dry-run callers may remain during migration, but new consumers
  should adopt `doc-maintainer.yml`.

### 3.9 `doc-maintainer.yml`

- **Skip on:** repos where the maintenance burden isn't yet a real problem
  (small repos, low PR volume). Adopt when doc-of-record drift becomes a
  recurring theme in review cycles.
- **Behavior:** after a merged PR reaches the default branch, the workflow
  sends bounded, redacted PR metadata/patches, the repository's Markdown
  inventory, and `.github/doc-maintainer-conventions.md` to the configured
  LiteLLM alias (default `ai-doc-maintainer`). The model decides which docs
  require updates. Its JSON plan is schema/path/cap validated. In dry-run mode
  the proposed patch is retained as an artifact and the plan is posted to the
  merged PR. In live mode, allowlisted low-risk edits become a bot PR and
  high-risk edits become a `docs` issue for human judgment.
- **Required consumer files:** `.github/doc-maintainer.json` and
  `.github/doc-maintainer-conventions.md`; starter templates ship in
  `install/templates/`. Begin with `dry_run: true` and inspect at least five
  coherent plans before enabling live mode.

### 3.10 `audit-trail-check.yml`

- **Skip on: bootstrap tier** (any new repo before CI adoption — none
  currently; `aidoc-flow-interlog` has since graduated + adopted the CI
  caller) — the local pre-push hook enforces OPS-0069 authoritatively; CI
  belt-and-suspenders adopts
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

1. **`pre-commit.yml`** — **bootstrapped automatically** since PLAN-018 F2, so
   this step is already done on a fresh `install.sh` run; it is listed here for
   ordering context and for repos adopting workflows by hand. Its check is
   required on every tier that has required checks at all (REPO_STANDARDS
   §16.9), which is why it is no longer optional.
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

All consumer callers pin at `@ci/vX.Y.Z`; read the current release from
[`../VERSION`](../VERSION) rather than duplicating it here. The content-check
callers populated 2026-07-11 initially pinned `@ci/v1.9.4`/`v1.9.5`. Gate callers (ai-review / composition /
auto-merge / audit-trail) bump on each consumer's own cadence — read the
`@ci/vX.Y.Z` string in each repo's `.github/workflows/*.yml` (do NOT hardcode
a version here; it drifts). Re-pin with `install/install.sh <repo> --repin`
(version-string-only; never `--update`, which clobbers customizations).

The [`../CHANGELOG.md`](../CHANGELOG.md) is the source-of-truth for tag →
change mapping.

## 6. Drift detection

A third check, [`sync/check-pin-currency.sh`](../sync/check-pin-currency.sh),
flags callers whose `@ci/vX.Y.Z` pin LAGS the current `VERSION` (the
pin-staleness dimension the other two miss). Run `bash
sync/check-pin-currency.sh --fleet <repos…>` for a fleet audit, or in a
consumer repo for a warning-only in-repo check. Re-pin stale repos with
`install/install.sh <repo> --repin` (version-string-only).

The [`sync/check-drift.sh`](../sync/check-drift.sh) script compares each
consumer's `.github/workflows/*.yml` against the canonical template at the
pinned `ci/vX.Y.Z` tag and reports any diff as a `::warning::`. Warning-only,
never blocks. When a consumer legitimately deviates (parameter override,
full replacement, custom workflow — see [`overrides.md`](overrides.md)), the
warning is the operator's opportunity to reconcile intent.

A consumer can run `check-standards-drift.sh` against its OWN repo by installing
the reusable **`standards-drift`** caller (`install/templates/workflows/standards-drift.yml`,
opt-in, `-private` variant available) — a thin `workflow_call` over
[`.github/workflows/standards-drift.yml`](../.github/workflows/standards-drift.yml),
which fetches the script from the adopted canon tag (read from the consumer's own
checked-out caller pin) and runs it weekly (warning-only; `strict: true` via the
dispatch button for a release/adoption gate). This closes the gap where drift detection ran only inside canon. Canon's
own weekly self-check is [`standards-drift-self.yml`](../.github/workflows/standards-drift-self.yml).

## 7. Change log

- 2026-07-14 — **§2 stale ai-review/composition/pre-commit/audit-trail cells
  corrected (PLAN-009 exploration).** Live re-verification confirmed the callers
  flagged "missing/planned/inert" in the 2026-07-11 audit now all exist at
  `@ci/v1.9.5` — iplan-runner `composition.yml`, iplan-standard
  `ai-review.yml`/`composition.yml`/`pre-commit.yml`, engramory `pre-commit.yml`,
  business `audit-trail.yml`. Those cells flipped ✅ and §2.1/§2.2/§3.2 prose was
  reconciled. Remaining `⚠️ GAP` cells are the genuine `codeql` (Python-maturing)
  ones only.
- 2026-07-11 — **Content-check population complete + catalog corrected.**
  Re-audited all 12 columns × every repo (+ visibility). `secret-scan` /
  `markdown-lint` / `links` / `labeler` / `docs-sync` now cover every active
  repo (canon reusable or documented custom/own equivalent). Catalog §1
  descriptions for #6/#7/#8 corrected: all three install the tool as a
  **binary/npm package** in a `run:` step, NOT the marketplace wrappers that
  the allowed-actions policy blocks (`startup_failure`) — fixed in
  `ci/v1.9.2`/`v1.9.4`; `markdown-lint` gained a `fail-on-findings` report-only
  toggle (`v1.9.5`). `markdown-lint` deployed report-only + `docs-sync`
  dry-run fleet-wide; graduations tracked in §2.1. iplan-standard corrected to
  **public**; interlog + iplan-standard no longer bootstrap-tier.
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
- 2026-07-06 — Initial registry codified.

## 8. Cross-references

- [`AI_CI_DEPLOYMENT.md`](AI_CI_DEPLOYMENT.md) — **AI-agent playbook + wizard** for deploying the full stack on a new repo (prerequisites, sequence, gotchas, verification)
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
