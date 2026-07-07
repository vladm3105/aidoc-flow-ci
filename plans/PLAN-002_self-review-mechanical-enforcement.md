# PLAN-002 — Self-review mechanical enforcement (OPS-0065/0069 rollout)

**Status:** DRAFT — 2026-07-07 EST
**Related:** OPS-0065 (multi-agent review), OPS-0067 (aidoc-flow-standard),
OPS-0069 (mandatory pre-push audit-trail), PLAN-001 (repo standards canon).

## 1. Purpose

Close the workspace-wide gap in the OPS-0065/0069 self-review discipline:
**author-side pre-push mechanical enforcement is currently installed only
on `aidoc-flow-operations`.** All other non-paused repos have the
DISCIPLINE (CLAUDE.md language) but no mechanism blocking a `git push`
that lacks the OPS-0069 audit-trail phrase.

The umbrella `CLAUDE.md` "Multi-agent automated review" clause (OPS-0067)
declares the aidoc-flow-standard scope, but declaration is not
enforcement. A single missed pre-push dispatch — the exact failure mode
that triggered OPS-0069 (operations PR #208 review-loop cascade) — costs
7+ review cycles and is entirely preventable at the git-push boundary.

## 2. Current-state audit (2026-07-07)

| Repo | CLAUDE.md discipline | CI post-push review | `pre_push_check.sh` | Audit-trail commit-msg check |
| --- | --- | --- | --- | --- |
| `aidoc-flow-operations` | ✅ | ✅ | ✅ | ✅ |
| `aidoc-flow-framework` | ✅ + 5 gov docs | ✅ (ai-review, composition, doc-review) | ❌ | ❌ |
| `aidoc-flow-business` | ✅ | ✅ | ❌ | ❌ |
| `aidoc-flow-iplanic` | ✅ | ✅ | ❌ | ❌ |
| `iplan-runner` | ✅ | partial (ai-review only) | ❌ | ❌ |
| `aidoc-flow-iplan-standard` | ✅ | ✅ | ❌ | ❌ |
| `aidoc-flow-engramory` | ✅ | ✅ (adopted 2026-07) | ❌ | ❌ |
| `aidoc-flow-ci` (canon home) | (canon) | reusables, no self-CI | ❌ | ❌ |
| `aidoc-flow-knowledge-rag` | PAUSED — skip | | | |
| `aidoc-flow-site` | PAUSED — skip | | | |

**Gap:** 7 non-operations non-paused repos have no mechanical pre-push
enforcement of OPS-0069.

## 3. Non-goals (v1)

- Do NOT touch paused repos (`knowledge-rag`, `site`) — founder direction.
- Do NOT introduce a new pre-push agent that dispatches sub-agents
  itself. The pre-push script only VERIFIES that the author already ran
  the dispatch (via the audit-trail commit-message phrase). Dispatch
  remains author-tool responsibility (Claude Code `Agent(...)`, Codex,
  Gemini, etc.).
- Do NOT retrofit historical commits — enforcement kicks in on the next
  push after adoption.
- Do NOT block `--no-verify` overrides at the tool level (that's a git
  configuration decision; enforcement can be bypassed by determined
  author, mirroring `--admin` merge escape hatch).

## 4. Design constraints

- **Additive**: pre-push script is EXTRA discipline; existing per-repo
  hooks (pre-commit, linting) remain untouched.
- **Portable**: bash 4+ only; consumes `git log`, `grep`, standard
  utilities. No jq/gh required.
- **Idempotent installation**: applying to a repo that already has the
  hook is a no-op (or upgrade if canon has changed).
- **Skippable per-repo**: consumers can disable via
  `AIDOC_FLOW_SKIP_PREPUSH=1` env var (matches operations existing
  `SKIP_LOCAL_AI_REVIEW`-removal decision — OPS-0069 removed the
  toggle, but per-repo installation opt-out remains).
- **CI belt-and-suspenders**: pre-push script can be bypassed with
  `git push --no-verify`. Add a companion CI workflow that verifies
  the audit-trail phrase in every push range — the CI check is the
  authoritative gate.

## 5. Deliverable shape — 3 PRs

Mirrors PLAN-001 3-PR sequencing.

### 5.1 PR-D — canon `pre_push_check.sh` template + REPO_STANDARDS.md §15 addition

**Purpose:** canonical script + canon-doc anchor.

**Files created / touched:**

- `install/templates/pre_push_check.sh` (NEW) — the canonical pre-push
  hook script. Derived from `aidoc-flow-operations/scripts/pre_push_check.sh`
  (already-proven implementation), sanitized for consumer use:
  - Verifies the OPS-0069 audit-trail phrase (`Multi-agent self-review
    per OPS-0065` OR `Self-review skipped per founder OK`) is present
    in at least one commit message in the push range
    (`@{upstream}..HEAD`).
  - Reads `AIDOC_FLOW_SKIP_PREPUSH=1` env var to disable.
  - Prints clear guidance on failure (which agents to dispatch, how
    to add the audit-trail phrase, how to bypass with `--no-verify`
    + founder-OK).
- `docs/REPO_STANDARDS.md` §15 (NEW section) — canonical rule that
  every non-paused non-bootstrap repo ships `.git/hooks/pre-push`
  wired to `scripts/pre_push_check.sh` (or equivalent). Tier
  applicability: all tiers except paused. Bootstrap tier: ⏸ (adopt
  after first CI joins).
- `CHANGELOG.md` — [Unreleased] Added entry.

**3 surfaces** — OPS-0061 Rule 1 compliant.

**Rollout gate:** merges before D2/D3.

### 5.2 PR-D2 — installer wiring + apply-standards.sh coverage

**Purpose:** mechanical apply of the pre-push script.

**Files created / touched:**

- `install/install.sh` (edit) — extend to install
  `scripts/pre_push_check.sh` + wire git-hooks path
  (`git config core.hooksPath .githooks` + `.githooks/pre-push` symlink
  or copy).
- `install/apply-standards.sh` (edit) — add the pre-push script to the
  `exact_match_check` list for `--check` / `--dry-run` / `--report`
  modes. Extend `--apply` to install the pre-push hook when missing.
- `CHANGELOG.md` — [Unreleased] Added entry.

**3 surfaces** — Rule 1 compliant.

**Rollout gate:** merges after PR-D.

### 5.3 PR-D3 — CI-side belt-and-suspenders

**Purpose:** CI check that verifies OPS-0069 audit-trail phrase on
every push range (defense against `git push --no-verify`).

**Files created / touched:**

- `.github/workflows/audit-trail-check.yml` (NEW reusable) — runs on
  `push` + `pull_request`. For pull_request events: verifies the
  audit-trail phrase in any commit in `head_ref..base_ref`. For push
  events (protected branches): verifies phrase in
  `${{ github.event.before }}..${{ github.event.after }}`. Failure
  = blocking check (unless the push range is a merge commit created
  by GitHub during squash-merge, which is exempted).
- `docs/WORKFLOWS.md` (edit) — add the new workflow to the registry
  matrix. Applicability: all non-paused non-bootstrap tiers.
- `CHANGELOG.md` — [Unreleased] Added entry.

**3 surfaces** — Rule 1 compliant.

**Rollout gate:** merges after PR-D2.

### 5.4 Follow-up (out-of-plan rollout PRs)

After PR-D/D2/D3 canon lands, use CROSS_REPO_PLAYBOOKS.md §T-C
coordinated-merge-window pattern (same as PLAN-001 §5.4 rollout).
Per-repo compliance PRs adopt:

- Copy `scripts/pre_push_check.sh` (via `install.sh` or manual).
- Wire git-hooks (`git config core.hooksPath` OR install into
  `.git/hooks/pre-push`).
- Enable the `audit-trail-check.yml` workflow (add as caller in
  `.github/workflows/`).

Rollout order per tier priority (matches PLAN-001 §5.4):

1. **Governance** (`framework`, `iplan-standard`) — highest blast
   radius; framework already has 5 gov review docs, adds mechanical
   enforcement.
2. **Ops-private** (`business`, `iplanic`) — internal-only, safe;
   operations is already covered.
3. **Product code** (`iplan-runner`, `engramory`, `aidoc-flow-ci`) —
   most repos also need WORKFLOWS.md §2.1 workflow gaps closed
   alongside (per PLAN-001 §5.4).
4. **Bootstrap** (`interlog`) — apply after first CI adoption.
5. **Umbrella** (`aidoc-flow`) — apply last. Note: umbrella governance
   PRs (submodule pointer bumps) also need the discipline; script
   applies uniformly.

**Paused repos** (`knowledge-rag`, `site`): SKIP per founder direction.

## 6. Risks

| # | Risk | Severity | Mitigation |
| --- | --- | --- | --- |
| 1 | Pre-push hook rejects legitimate first push on a new branch (no upstream yet) | High | Handle no-upstream case with graceful fallback (`origin/main..HEAD` instead of `@{upstream}..HEAD`) — pattern already in operations `pre_push_check.sh`. |
| 2 | `git push --no-verify` bypasses hook entirely | Medium | PR-D3 CI check is the authoritative gate; hook is convenience. |
| 3 | Consumer forgot audit-trail phrase → push rejected → cascade of amendment commits | Low | Failure message includes exact phrase to append to a fresh commit or `git commit --amend`. |
| 4 | CI check flags GitHub-generated merge commits (they lack the phrase) | Medium | Exempt merge commits authored by `github-actions[bot]` or matching known merge-commit patterns; document in workflow. |
| 5 | Rollout to 7 repos in one merge-window causes cascade of amendment PRs | Medium | Roll out tier-by-tier per §5.4; each tier's adoption PR itself must carry the audit-trail phrase (self-hosting). |

## 7. Success criteria

- All 8 non-paused repos have `scripts/pre_push_check.sh` + wired
  git-hooks + CI `audit-trail-check.yml` workflow.
- `install/apply-standards.sh --check` on any non-paused repo returns
  OK for pre-push-hook surface.
- One randomly-chosen post-rollout push without the audit-trail phrase
  fails locally (pre-push hook) AND in CI (workflow gate).
- Zero regressions on existing OPS-0065/0069 operations enforcement.

## 8. Cross-references

- OPS-0065 (multi-agent automated review) — `aidoc-flow-operations/ops/DECISIONS.md`
- OPS-0067 (aidoc-flow-standard scope) — `aidoc-flow-operations/ops/DECISIONS.md`
- OPS-0069 (mandatory pre-push audit-trail) — `aidoc-flow-operations/ops/DECISIONS.md`
- PLAN-001 (repo standards canon) — this repo, `plans/PLAN-001_repo-standards-canon.md`
- Umbrella `CLAUDE.md` "Multi-agent automated review" clause
- Operations reference implementation — `aidoc-flow-operations/scripts/pre_push_check.sh`
- Cross-repo playbook — `aidoc-flow-operations/docs/CROSS_REPO_PLAYBOOKS.md` §T-C

## 9. Audit trail

- 2026-07-07 — Plan drafted (@vladm3105 direction, session-in-flight).
  Origin: workspace-wide audit surfaced 7/8 non-paused repos lack
  mechanical pre-push enforcement despite CLAUDE.md discipline. Fills
  the gap PLAN-001 did not address (PLAN-001 covered file surfaces +
  server-side settings; this plan covers author-side workflow
  discipline).
