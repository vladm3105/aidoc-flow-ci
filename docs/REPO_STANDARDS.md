# Repo standards — `aidoc-flow-ci`

Canonical rules for every repository in the aidoc-flow workspace.
Complements [`WORKFLOWS.md`](WORKFLOWS.md) (workflow-side compliance) and
`aidoc-flow-operations/docs/REPO_ONBOARDING.md` (CI activation steps).

This doc codifies the **static settings** side: branch protection, GitHub
security settings, labels, dependabot, CODEOWNERS, PR template, Actions
permissions, merge/cleanup, `.gitignore`/`.gitattributes`. The workflow-
adoption side lives in `WORKFLOWS.md`; the activation checklist for a new
repo lives in `REPO_ONBOARDING.md`. All three docs together are the
complete rulebook.

## 1. Tier taxonomy (6 tiers)

Every workspace repo belongs to exactly one tier. Tier drives every
per-repo requirement below.

| Tier | Repos (2026-07-07) | Signal |
| --- | --- | --- |
| **Governance** | `aidoc-flow-framework`, `aidoc-flow-iplan-standard` | Public spec/schema repo; human-merge only |
| **Product code** | `iplan-runner`, `aidoc-flow-engramory`, `aidoc-flow-ci` | Public runtime/library repo |
| **Ops-private** | `aidoc-flow-operations`, `aidoc-flow-business`, `aidoc-flow-iplanic` | Private operations/docs repo |
| **Umbrella** | `aidoc-flow` | Multi-repo umbrella; submodule-pointer PRs only; `--admin` merge |
| **Bootstrap** | `aidoc-flow-interlog` | New repo pending CI adoption |
| **Paused** | `aidoc-flow-knowledge-rag`, `aidoc-flow-site` | Frozen per founder direction 2026-07-04 |

Tier is not property of the repo file — it's a canonical assignment
maintained here. When a new repo enters the workspace, its tier is
declared before any settings apply (see §11 Rollout).

## 2. Branch protection

All non-paused repos protect `main`. Tier drives the profile.

| Setting | Governance | Product code | Ops-private | Umbrella | Bootstrap |
| --- | --- | --- | --- | --- | --- |
| Required PR before merge | ✅ | ✅ | ✅ | ✅ | ✅ |
| Required approving reviews | 1 human | 0 | 0 | 0 | 0 |
| Dismiss stale reviews on push | ✅ | ✅ | ✅ | ✅ | ✅ |
| Require review from CODEOWNERS | ✅ | ⏸ v2 | ⏸ v2 | ✅ | ⏸ v2 |
| Required status checks (baseline) | `call / ai-review`, `call / composition`, `Lint / format / security hooks` + tier-specific | `call / ai-review`, `call / composition`, `Lint / format / security hooks`, `Secret scan (gitleaks)` + tier-specific | `call / ai-review`, `call / composition`, `Lint / format / security hooks`, `Secret scan (gitleaks)` + tier-specific | (no required checks — submodule-pointer only) | `Lint / format / security hooks` + tier-specific |
| Require branches up-to-date before merge | ⏸ (adds re-run round-trips; deferred) | ⏸ | ⏸ | ⏸ | ⏸ |
| Require signed commits | ⏸ v2 | ⏸ v2 | ⏸ v2 | ✅ (unsigned AI commits blocked; `--admin` per OPS-0062) | ⏸ v2 |
| Include administrators | ✅ | ✅ | ✅ | ⏸ (`--admin` merge is the intentional bypass) | ✅ |
| Allow force pushes | ❌ | ❌ | ❌ | ❌ | ❌ |
| Allow deletion | ❌ | ❌ | ❌ | ❌ | ❌ |

**Rationale — required approving reviews:**
- **Governance** requires ≥1 human because spec/schema changes carry the
  highest downstream blast radius (regeneration of tests, plugin
  templates, etc.).
- **Product code / Ops-private** set required-approving-reviews to 0
  (a distinct branch-protection setting from auto-merge armament).
  Substantive review comes from allowlisted AI authors +
  `ai-review.yml` + `composition.yml` chain; the trust gate + verdict
  gate + auto-merge gate are the required CHECKS, not a reviewer
  count. Auto-merge itself is a PR-side mechanism armed by
  `auto-merge-ai-prs.yml` (per `auto_merge.repos` allowlist).

**Rationale — signed commits (deferred except umbrella):** AI commits are
unsigned; requiring signed commits everywhere would force every AI push
through `--admin`. Umbrella already has this constraint as a deliberate
governance layer; other tiers defer until the workspace adopts a signing
solution (`gitsign`, `gh api PATs with commit signing`, etc.) — tracked
as v2.

## 3. GitHub security settings

Each repo's GitHub-hosted security features (secret scanning, push
protection, dependabot alerts, code scanning). Availability depends on
visibility + license tier — settings that are unavailable on private
repos without Advanced Security are marked N/A.

| Setting | Governance (public) | Product code (public) | Ops-private (private) | Umbrella (private) | Bootstrap (any) |
| --- | --- | --- | --- | --- | --- |
| Secret scanning | ✅ | ✅ | N/A (no Advanced Security) | N/A | ✅ if public else N/A |
| Secret scanning push protection | ✅ | ✅ | N/A | N/A | ✅ if public else N/A |
| Dependabot security updates | ✅ | ✅ | ✅ | ✅ | ✅ |
| Dependabot version updates (via `dependabot.yml`) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Code scanning (CodeQL) | ✅ | ✅ (only when repo has runtime code) | N/A (Advanced Security) | N/A | ⏸ pending |

**Enforcement:** apply via `install/apply-standards.sh --apply` (PR-C).
Public repos should NEVER have secret_scanning + push_protection
disabled; that's a hard rule. Private repos accept the N/A because
GitHub Advanced Security is a paid tier we don't license.

## 4. Actions permissions (repo-level)

GitHub's `Settings → Actions → General → Workflow permissions` and
related knobs. These control what workflows can do with the default
`GITHUB_TOKEN`, whether fork PRs can run workflows, and which actions
are allowed.

| Setting | All tiers (default) | Rationale |
| --- | --- | --- |
| Actions permissions | Allow local + explicit-allowlist third-party | Blocks unreviewed action-from-anywhere |
| Fork pull request workflows from outside collaborators | Require approval for first-time contributors | Prevents unlimited-fork abuse |
| Send write tokens to workflows from fork PRs | ❌ Disabled | Fork PRs never get write tokens |
| Send secrets and variables to workflows from fork PRs | ❌ Disabled | Fork PRs never see secrets |
| Default workflow permissions | ⚠️ `read` (not `write`) | Least-privilege default; workflows that need write set it explicitly at job-level |
| Allow GitHub Actions to create and approve pull requests | ✅ (needed for `docs-sync.yml` + `doc-maintainer.yml`) | Required by IPLAN-0018/0025 workflows |

**Enforcement gap risk:** GitHub's default is `read-write` on new repos.
`apply-standards.sh` (PR-B) tightens to `read` and adds the fork-PR
constraints.

## 5. Labels — canonical taxonomy

The label taxonomy aligns with the **OPS-0065 diff-class dispatch table**
in `operations/CLAUDE.md`, so path-based labels reinforce which
sub-agents should be dispatched pre-push. Existing operations `.github/
labeler.yml` pattern + framework labeler config are the reference
shapes.

### 5.1 State labels (ai-review state machine — required)

| Label | Emitted by | Semantics |
| --- | --- | --- |
| `ai:review-passed` | `ai-review.yml` | verdict = APPROVED; auto-merge armed |
| `ai:review-changes` | `ai-review.yml` | verdict = CHANGES_REQUESTED; blocks merge |
| `ai:human-review-required` | `ai-review.yml` trust job | Fork PR or non-allowlisted author |
| `skip-ai-review` | Operator (manual) | Re-fire the gate; carry-forward safe |

Every tier that adopts `ai-review.yml` MUST create these 4 labels first
(the workflow does not create them).

### 5.2 Diff-class labels (path-based, from OPS-0065 table)

Labels aggregate ≥1 diff class from the canonical diff-class-map at
`operations/.claude/agents/review-prompts/diff-class-map.json`. Path
globs may overlap by design — a diff touching `.claude/agents/*.md`
gets both `governance` (diff-class: governance-docs-root +
agents-and-skills; dispatch = governance-docs review) and `agents`
(dispatch = agents-and-skills review); both diff-class agent sets fire
per OPS-0065.

| Label | Path glob | OPS-0065 diff class(es) |
| --- | --- | --- |
| `governance` | `CLAUDE.md`, `ops/DECISIONS.md`, `.claude/agents/*.md`, `.claude/skills/*.md`, `.github/ai-review/**` | governance-docs-root + agents-and-skills + ai-review-config |
| `docs` | `docs/**`, `README.md`, `CHANGELOG.md`, `ops/HANDOFF.md` | docs |
| `workflows` | `.github/workflows/**` | workflow-yaml |
| `scripts` | `scripts/**` | scripts |
| `agents` | `.claude/agents/**`, `.claude/skills/**`, `.claude/workflows/**` | agents-and-skills + workflow-js |
| `tests` | `tests/**` | tests |
| `config` | `Dockerfile`, `pyproject.toml`, `requirements*.txt`, `package*.json`, `uv.lock`, `.pre-commit-config.yaml` | deps-config |
| `plans` | `ops/iplans/IPLAN-*.md`, `plans/PLAN-*.md` | plans (verified-planning) |

Tier ignores diff-class label existence — every non-paused repo should
have them. Adoption via `labeler.yml` reusable + `.github/labeler.yml`
config maps the paths above.

### 5.3 Area labels (tier-specific; optional)

- `platform: hermes`, `platform: claude` — framework-specific
- `sub-plan: PLAN-XXX` — iplan-runner / iplanic
- `dependencies` — Dependabot PRs
- `security` — security-tagged issues/PRs

## 6. Dependabot (`.github/dependabot.yml`)

Every non-paused repo ships `.github/dependabot.yml`. Ecosystems declared
based on repo content:

| Ecosystem | When applicable | Schedule | Group |
| --- | --- | --- | --- |
| `github-actions` | Every repo | weekly | `github-actions` |
| `pip` | Any Python code | weekly | `python-runtime` (patch+minor) |
| `npm` | Any Node/JS code | weekly | `javascript-runtime` (patch+minor) |
| `docker` | Any Dockerfile | weekly | `docker-baseimages` |
| `gitsubmodule` | Umbrella only | weekly | `submodules` |

**Auto-merge policy** — Dependabot PRs pass through the standard
`ai-review.yml` + `composition.yml` chain and auto-merge on green per
`auto_merge.repos` allowlist (opt-in per repo). Governance-tier repos
do NOT auto-merge dependabot PRs (human-merge only).

**Grouping** batches minor/patch bumps into single PRs to reduce CI
churn; major bumps get individual PRs (breaking-change scrutiny).

Template ships in `install/templates/dependabot.yml` (PR-B).

## 7. CODEOWNERS

Every non-paused repo ships `.github/CODEOWNERS` mapping path patterns
to reviewer routing. Canonical shape:

```
# Global default: founder
*                                       @vladm3105

# Security-sensitive paths (double-review)
.github/**                              @vladm3105
.github/workflows/**                    @vladm3105
.github/ai-review/**                    @vladm3105

# Governance surfaces
CLAUDE.md                               @vladm3105
ops/DECISIONS.md                        @vladm3105
docs/REPO_STANDARDS.md                  @vladm3105

# Docs (tier-specific override — product-code repos let AI-review own docs)
docs/**                                 @vladm3105
```

**Adoption:** governance + umbrella tiers require CODEOWNERS review
(branch-protection setting §2); product-code + ops-private tiers ship
CODEOWNERS but do not gate merges on it (defer to `ai-review.yml` +
`composition.yml` for the substantive review). v2 evaluation: enforce
CODEOWNERS review on all tiers.

**Single-owner phase:** all patterns currently route to `@vladm3105` —
the workspace is a single-owner phase. v2 will fan out per-domain
reviewers (e.g., docs → docs-savvy, workflows → security-savvy) as the
team grows.

Template ships in `install/templates/CODEOWNERS.template` (PR-B).

## 8. PR template

Every non-paused repo ships `.github/pull_request_template.md`.

Contents (canonical):
- Summary section
- Files touched (self-check for OPS-0061 ≤3-surface rule)
- Multi-agent review section (naming dispatched sub-agents + verdict — OPS-0069 audit-trail phrase belongs in the COMMIT MESSAGE, not the PR body; PR template reminds authors)
- Cross-references (OPS-NNNN, IPLAN-NNNN, related PRs)
- Test plan (checkboxes)
- Governance-tier callout (🟡/🔴 exceptions per OPS-0062)

Template ships in `install/templates/pull_request_template.md` (PR-B).

## 9. Merge & branch-cleanup settings

Repo-level `Settings → General → Pull Requests` block. Uniform across
all tiers.

| Setting | All tiers |
| --- | --- |
| Allow merge commits | ❌ Disabled |
| Allow squash merging | ✅ Enabled (default) |
| Allow rebase merging | ❌ Disabled |
| Automatically delete head branches | ✅ Enabled |
| Allow auto-merge | ✅ Enabled |
| Squash commit title | PR title |
| Squash commit message | PR body |

**Umbrella note:** the umbrella tier additionally requires `--admin`
merge and enforces signed commits via the branch-protection layer (§2),
independent of the merge-settings block above.

**Rationale:** squash-only keeps `main` linear; delete-on-merge prevents
stale-branch accumulation. Rebase-merge is disabled because it rewrites
PR commits onto base after review — the App's APPROVED review is
anchored to the pre-merge HEAD SHA (verified in `ai-review.yml`
`github.event.pull_request.head.sha` + `composition.yml`'s
`commit_id == HEAD_SHA` filter), and rebase-merge splits one PR into
multiple main-branch commits that dissociate from that review anchor,
complicating traceability. Squash-merge keeps one merge commit per PR
= one-to-one with the reviewed HEAD.

## 10. `.gitignore` + `.gitattributes` baseline

Every non-paused repo ships baseline versions.

### 10.1 `.gitignore` baseline

Workspace-common ignores. Repo-specific ignores extend (never replace)
the baseline.

```gitignore
# AI-workspace scratch
.claude/
.review/

# Transient
tmp/
scratch/

# Env / secrets
.env
.env.*
!.env.example

# Python
__pycache__/
*.pyc
.venv/
.pytest_cache/
.mypy_cache/
.ruff_cache/
dist/
build/
*.egg-info/

# Node
node_modules/

# OS / editors
.DS_Store
.vscode/
.idea/
Thumbs.db
```

### 10.2 `.gitattributes` baseline

Enforce LF line endings across contributors (Windows contributors get
platform-native on checkout via `text=auto`; committed content is LF).

```gitattributes
* text=auto eol=lf
*.png binary
*.jpg binary
*.pdf binary
```

Templates ship in `install/templates/.gitignore.template` +
`install/templates/.gitattributes.template` (PR-B).

## 11. Rollout — coordinated-merge-window pattern

Rolling out the canon to 10 workspace repos is exactly the T-C
coordinated-merge-window pattern from
`operations/docs/CROSS_REPO_PLAYBOOKS.md`. Sequence:

1. **PR-A merges first** — this doc + index entry + CHANGELOG.
2. **PR-B merges second** — templates + `install/apply-standards.sh`.
3. **PR-C merges third** — server-side enforcement JSONs + drift check.
4. **Per-repo compliance PRs** — one PR per repo touching the doc-shipped
   surfaces (CODEOWNERS, PR template, dependabot.yml, .gitignore/
   .gitattributes, labels sync). Rolled out per tier priority:
   1. **Governance** (framework, iplan-standard) — highest blast radius.
   2. **Ops-private** (operations, business, iplanic) — internal-only.
   3. **Product code** (iplan-runner, engramory, aidoc-flow-ci) — most
      of these also need `WORKFLOWS.md` §2.1 gaps closed alongside.
   4. **Bootstrap** (interlog) — first CI adoption from the standard.
   5. **Umbrella** (aidoc-flow) — apply last; special-case per OPS-0062.
5. **Server-side settings** (branch protection, security, Actions
   permissions) apply via `--apply` mode as a SEPARATE pass AFTER each
   tier's per-repo compliance PR (step 4) has merged. The per-repo PR
   ships the content surfaces (CODEOWNERS, PR template, dependabot.yml,
   .gitignore/.gitattributes, labels-sync via `gh api`); the follow-up
   `--apply` invocation flips the server-side knobs. Founder runs
   `bash install/apply-standards.sh --apply <owner/repo>` per repo (F5
   blast-radius per REPO_ONBOARDING.md — server-side changes stay
   founder-manual).

## 12. Compliance evidence — where each rule's audit-trail lives

| Requirement | Evidence location |
| --- | --- |
| Workflow adoption | [`WORKFLOWS.md`](WORKFLOWS.md) §2 matrix |
| CI activation (reviewer App install, allowlist) | `operations/docs/REPO_ONBOARDING.md` Steps 1-4 |
| Branch protection | GitHub API — verify via `bash install/apply-standards.sh --check` (PR-B) |
| Security settings | Same as branch protection |
| Actions permissions | Same |
| Labels | Same |
| Dependabot | Presence of `.github/dependabot.yml` + `--check` verifies contents |
| CODEOWNERS | Presence of `.github/CODEOWNERS` + `--check` |
| PR template | Presence of `.github/pull_request_template.md` + `--check` |
| Merge/cleanup | GitHub API — `--check` |
| `.gitignore` / `.gitattributes` | Presence + `--check` compares against baseline |

## 13. Cross-references

- [`WORKFLOWS.md`](WORKFLOWS.md) — workflow registry (11 reusables +
  per-repo applicability matrix)
- [`architecture.md`](architecture.md) — reusable-workflow model + trust
  flow
- [`multi-project-guide.md`](multi-project-guide.md) — new-project
  onboarding flow
- [`overrides.md`](overrides.md) — 3 override modes
- [`security.md`](security.md) — threat model + secrets
- [`../LABELS.md`](../LABELS.md) — pre-existing label conventions
  (label separators + runner-label namespace)
- `aidoc-flow-operations/docs/REPO_ONBOARDING.md` — 4-step CI
  activation checklist
- `aidoc-flow-operations/docs/CROSS_REPO_PLAYBOOKS.md` — T-C
  coordinated-merge-window pattern (used by §11 rollout)
- `aidoc-flow-operations/.github/ai-review/config.json` — trust
  allowlist + `auto_merge.repos` allowlist
- `aidoc-flow-operations/ops/DECISIONS.md`:
  - OPS-0061 Rule-1 (≤3 doc surfaces per PR)
  - OPS-0062 (auto-merge default; umbrella `--admin`)
  - OPS-0065 (multi-agent diff-class dispatch — informs label taxonomy §5.2)
  - OPS-0068 (reviewer App install permissions)
  - OPS-0069 (mandatory pre-push audit trail)

## 14. Change log

- 2026-07-07 — Initial canon codified per PLAN-001 §5.1.
