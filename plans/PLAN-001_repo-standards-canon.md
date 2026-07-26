# PLAN-001 — Repo standards canon (unified rules for all workspace repos)

**Owner:** `aidoc-flow-ci` maintainer (currently vladm3105 + AI Crew)
**Origin:** founder direction 2026-07-07 — "check also repo settings (including
protection rules, security settings) registry for public and private repos;
check repos labeling rules/strategy; check dependabot setting. The goal is
create unified rules for all repos (including new repos) using best practices
and our own experience to prevent security issues, redundant settings. Use
flow-ci as main repo for this documents, scripts, config files"
**Status:** Phases 1–5 SHIPPED 2026-07-07 (PRs #55, #56, #57, #58, #60).
Rollout scope (§5.4) SUPERSEDED by `plans/PLAN-002_workspace-standards-rollout.md`
— unified with self-review mechanical enforcement per founder direction
2026-07-07 ("revise PLAN-001 and PLAN-002 together"). This document remains
as historical record of the canon design; consult PLAN-002 for the
remaining per-tier rollout + self-review layer.

## 1. Purpose

Codify a single canonical standard for every workspace repo covering:

- Branch protection rules
- GitHub security settings (secret scanning, push protection, dependabot
  alerts, code scanning)
- Actions permissions (workflow default token scope, fork-PR-from-fork
  behavior)
- Labels (canonical taxonomy + adoption enforcement)
- Dependabot configuration
- CODEOWNERS routing
- PR template
- `.gitignore` + `.gitattributes` baseline
- Merge/branch-cleanup settings (squash-only + delete-on-merge)

Provide the mechanical templates + `apply-standards.sh` script that can
bring any repo up to compliance idempotently, in dry-run mode by default.

## 2. Empirical motivation (audit summary — 2026-07-07)

Cross-repo audit surfaced substantial drift:

- **3 of 10 active repos have NO branch protection on `main`**:
  engramory, iplan-standard, aidoc-flow-ci. Anyone with write can force-
  push. Fix in PR-C.
- **Required-checks lists ad-hoc per-repo** (2 to 8 required checks; no
  baseline). Standardize by tier.
- **GitHub security settings drift**: iplan-runner has `secret_scanning`
  - `push_protection` DISABLED (public repo); engramory + iplan-standard
  - aidoc-flow-ci have `dependabot_alerts` DISABLED. Standardize by
  visibility.
- **Dependabot adopted on only 3 of 10 repos** (framework, business,
  iplan-runner). No canonical config template.
- **Labels wildly inconsistent** — 9 to 28 per repo. No enforcement.
- **No workspace repo ships CODEOWNERS** — reviewer routing best practice
  entirely absent.
- **No workspace repo ships a PR template** — governance-Rule-1 checklist
  not enforced inline.

## 3. Non-goals (v1)

Defer to v2 or dedicated future plans:

- LICENSE requirement per tier
- SECURITY.md (`.github/SECURITY.md`) reporting policy
- Repo topics/description metadata sync
- Issue templates
- Environment protection rules
- Custom secret-scanning patterns beyond GitHub defaults
- `.gitleaks.toml` cross-repo sync (only relevant when we migrate
  operations `security.yml` to the reusable per WORKFLOWS.md §2.1
  migration candidates)

## 4. Tier taxonomy (richer than public/private)

6 tiers with distinct requirement profiles:

| Tier | Repos (current) | Auto-merge | Signed-commit ruleset | Human-approval count | Force-push | Delete-on-merge |
|---|---|---|---|---|---|---|
| **Governance** (public) | `aidoc-flow-framework`, `aidoc-flow-iplan-standard` | ⏸ (human-merge only) | Not required | ≥1 human | Blocked | ✅ |
| **Product code** (public) | `iplan-runner`, `aidoc-flow-engramory`, `aidoc-flow-ci` | ✅ (via ai-review) | Not required | 0 (allowlisted authors auto-merge) | Blocked | ✅ |
| **Ops/private** (private) | `aidoc-flow-operations`, `aidoc-flow-business`, `aidoc-flow-iplanic` | ✅ | Not required | 0 (allowlisted) | Blocked | ✅ |
| **Umbrella** (private) | `aidoc-flow` | ⏸ (via `gh pr merge --admin` per OPS-0062) | ✅ Required (unsigned AI commits blocked without --admin) | 0 | Blocked | ✅ |
| **Bootstrap** (any) | `aidoc-flow-interlog` | pending CI adoption | Not required | 0 | Blocked | ✅ |
| **Paused** (any) | `knowledge-rag`, `aidoc-flow-site` | frozen | frozen | frozen | frozen | frozen |

Per-tier profiles get codified in the canon (PR-A) + templates (PR-C).

## 5. Deliverable shape — 3 PRs

Split into 3 focused PRs per OPS-0061 governance discipline (each ≤3 doc
surfaces), and per CROSS_REPO_PLAYBOOKS.md T-C prereq-then-consumer pattern:

### 5.1 PR-A — `docs/REPO_STANDARDS.md` (the canon)

**Purpose:** Single source of truth for what "compliant" means.

**Contents:**

- Tier taxonomy (§4 above, expanded)
- Per-tier requirements table for: branch protection, security settings,
  labels, dependabot, CODEOWNERS, PR template, Actions permissions, merge
  settings, `.gitignore`/`.gitattributes`
- Integration table (which requirement's evidence lives where):
  - Workflow adoption → `WORKFLOWS.md` §2 matrix
  - CI activation → `operations/docs/REPO_ONBOARDING.md` Steps 1-4
  - Runtime settings (branch protection, security, dependabot, etc.) → THIS DOC
- Rollout order — cross-references `CROSS_REPO_PLAYBOOKS.md` §T-C
  coordinated-merge-window pattern for the multi-repo standards rollout
- Rationale per requirement (why we picked each control)

**Files touched:** `docs/REPO_STANDARDS.md` (NEW), `docs/README.md` (index
entry), `CHANGELOG.md`. **3 surfaces — Rule 1 compliant.**

**Rollout gate:** merges before B or C.

### 5.2 PR-B — templates + `install/apply-standards.sh`

**Purpose:** mechanical apply of the canon to any repo, idempotent + safe.

**Files created:**

- `install/templates/dependabot.yml` — canonical dependabot config
  (multi-ecosystem: GitHub Actions + npm + pip + docker; weekly cadence;
  grouped by ecosystem; auto-merges routine bumps via existing ai-review chain).
- `install/templates/CODEOWNERS.template` — canonical CODEOWNERS shape:
  - `.github/**` → security-savvy reviewers
  - `ops/DECISIONS.md`, `CLAUDE.md` → founder
  - `docs/**` → docs-savvy reviewers
- `install/templates/pull_request_template.md` — governance-Rule-1
  inline checklist + reminder of OPS-0069 audit-trail phrase requirement.
- `install/templates/.gitignore.template` — workspace baseline:
  `.claude/`, `.review/`, `tmp/`, generated files, `.env*`,
  `__pycache__/`, `.venv/`, `node_modules/`, `.DS_Store`.
- `install/templates/.gitattributes.template` — LF line endings + text
  attributes.
- `install/apply-standards.sh` — 4 modes:
  - `--check` — report drift vs canon, exit 1 if drift, no changes
  - `--dry-run` (default) — preview all mutations, no changes
  - `--apply` — execute mutations, backing up prior state to
    `install/backups/<owner-repo>-<timestamp>.json`
  - `--report` — emit a per-repo compliance report (JSON + human-readable
    table)

**Files touched:** 5 templates + 1 script + `CHANGELOG.md` = 7 surfaces.
Split B into B1 (dependabot + CODEOWNERS + PR template = 3 templates) and
B2 (`.gitignore` + `.gitattributes` + script = 2 templates + script) if
Rule-1 discipline requires — or bundle with founder OK given atomic
scope. Preferred: bundle with an explicit "atomic template-suite
adoption" audit-trail line.

**Rollout gate:** merges after A; provides mechanical apply for C.

### 5.3 PR-C — mechanical enforcement + drift check

**Purpose:** apply the runtime settings (branch protection, security,
labels, actions) via `gh api` from JSON templates.

**Files created:**

- `install/templates/branch-protection-{governance,product,ops,umbrella,bootstrap}.json`
  — 5 profile JSONs, one per non-paused tier.
- `install/templates/actions-permissions.json` — Actions security
  policy (`default_workflow_permissions: read`, no fork-PR-from-fork
  write, no third-party actions except approved).
- `install/templates/repo-settings.json` — merge settings + branch
  cleanup + delete-on-merge.
- `install/templates/labels.json` — extend existing template to a
  canonical set aligned with OPS-0065 diff-class taxonomy (governance,
  docs, workflows, scripts, agents, config, dependencies, tests) +
  ai-review state labels (`ai:review-*`).
- `install/apply-standards.sh` — extended to consume all templates.
- `sync/check-standards-drift.sh` — companion to existing
  `sync/check-drift.sh`. Warning-only, never blocks.

**Files touched:** 5 templates + 1 script edit + 1 script (NEW) +
`CHANGELOG.md` = 8 surfaces. Bundle as atomic enforcement suite with
audit-trail line per OPS-0069.

**Rollout gate:** merges after B.

### 5.4 Follow-up (out-of-plan rollout PRs)

After PR-A/B/C ship, use CROSS_REPO_PLAYBOOKS.md §T-C coordinated-merge-
window pattern to roll compliance to each workspace repo:

- Run `bash install/apply-standards.sh --check <owner/repo>` per repo to
  surface drift.
- Open per-repo PR that adopts the missing surfaces (CODEOWNERS, PR
  template, dependabot.yml, .gitignore/.gitattributes, labels sync via
  `gh api`).
- Server-side settings (branch protection, security, Actions) apply via
  `--apply` mode by the founder (F5 blast-radius — same as reviewer App
  install per REPO_ONBOARDING.md).

Rollout order per tier priority:

1. **Governance** (framework, iplan-standard) — highest blast radius on
   spec/schema drift; get canon first.
2. **Ops/private** (operations, business, iplanic) — internal-only, safe.
3. **Product code** (iplan-runner, engramory, aidoc-flow-ci) — most repos
   need the WORKFLOWS.md §2.1 gaps closed alongside.
4. **Bootstrap** (interlog) — first CI adoption from the standard.
5. **Umbrella** (aidoc-flow) — apply last; special-case per OPS-0062.

## 6. Risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| 1 | `apply-standards.sh --apply` mutates prod without warning if operator misuses | High | Default mode is `--dry-run`; `--apply` requires explicit flag; auto-backup prior state to `install/backups/`. |
| 2 | Rolling out CODEOWNERS to a repo where existing PRs are open causes review re-request confusion | Medium | Document in rollout playbook; time rollout during low-PR window per T-C coordinated-merge-window pattern. |
| 3 | Branch-protection changes lock out existing PR authors mid-flight | Medium | Rollout playbook: notify + verify no open PRs on the target repo before applying. |
| 4 | Dependabot config triggers PR flood on first adoption | Low | First-run PR flood is expected; groups + weekly cadence bound the volume. |
| 5 | Umbrella tier requires special-case handling (signed-commits ruleset) that generic templates don't cover | Low | Umbrella-specific branch-protection JSON template + rollout playbook flags the manual step. |
| 6 | Standards doc becomes stale as GitHub adds features (rulesets, workflow permissions, etc.) | Medium | Standard's own drift-check runs weekly via `sync/check-standards-drift.sh` GitHub Action (warning-only). |

## 7. Success criteria

- All 3 PRs merged to `aidoc-flow-ci` main.
- `bash install/apply-standards.sh --check <owner/repo>` returns 0 for
  every non-paused workspace repo (or the delta is explicitly documented
  as tier-appropriate).
- `docs/REPO_STANDARDS.md` referenced from operations `CLAUDE.md` and
  `docs/REPO_ONBOARDING.md` (Step 0 pointer).
- New-repo bootstrap flow (per REPO_ONBOARDING.md) includes running
  `apply-standards.sh --apply` as Step 5.

## 8. Cross-references

- `operations/docs/REPO_ONBOARDING.md` — Steps 1-4 activation checklist
  (this doc extends: Step 0 = adopt standards)
- `operations/docs/CROSS_REPO_PLAYBOOKS.md` — T-C coordinated-merge-
  window pattern (rollout sequencing)
- `docs/WORKFLOWS.md` — workflow registry (workflow-side compliance)
- `docs/multi-project-guide.md` — new-project onboarding entry point
- `docs/security.md` — trust boundaries + secrets model
- Operations `.github/ai-review/config.json` — `auto_merge.repos`
  allowlist (per-tier merge policy)
- Operations `ops/DECISIONS.md` OPS-0061 (Rule-1 governance),
  OPS-0062 (auto-merge default), OPS-0068 (reviewer App perms),
  OPS-0069 (mandatory pre-push audit trail)
- Operations `CLAUDE.md` § Multi-agent automated review — OPS-0065 diff-
  class dispatch (labels should align with the diff-class taxonomy)

## 9. Audit trail

- **Founder direction 2026-07-07** — 3-dimension audit request.
- **Audit performed 2026-07-07** — cross-repo state surveyed via
  `gh api repos/vladm3105/*/branches/main/protection`,
  `.../contents/.github/dependabot.yml`, `.../labels`, and repo-metadata
  security fields.
- **Gap analysis 2026-07-07** — surfaced 6 additional dimensions missing
  from the initial 3-dimension scope (CODEOWNERS, PR template, Actions
  permissions, merge/cleanup settings, `.gitignore`/`.gitattributes`,
  tier taxonomy richness).
- **Plan approved by founder 2026-07-07** with revised 3-PR sequencing.
