# CLAUDE.md — aidoc-flow-ci

Persistent context for the aidoc-flow workspace **CI + governance-workflow
canon** library. Auto-loaded every session. Keep it short and current.

## What this repo is

The **canonical source** for the CI + governance-workflow rules the
aidoc-flow workspace shares. Ships reusable workflows (`ai-review`,
`composition`, `audit-trail-check`, `standards-drift`, `secret-scan`,
etc.), canonical config templates (CODEOWNERS, dependabot, branch
protection), canonical scripts (`pre_push_check.sh`, `apply-standards.sh`,
`parse-governance-table.py`), governance-file templates
(`CLAUDE.md.template`, `HANDOFF.md.template`, `DECISIONS.md.template`,
`ROADMAP.md.template`, `plans-README.md.template`), the ai-review rubric
+ verdict schema at `ai-review/`, and per-language + per-tier rulebooks
in `docs/REPO_STANDARDS.md`.

Semver-tagged (`ci/vX.Y.Z`); consumers pin via `uses:
vladm3105/aidoc-flow-ci/.github/workflows/<file>.yml@ci/vX.Y.Z`.

**This is the workspace CI layer** — not a product, not shipping to
customers. Its consumers are the sibling aidoc-flow repos
(operations, business, framework, iplanic, iplan-runner,
iplan-standard, engramory, interlog, umbrella).

**Canonical-source disambiguation (workspace has TWO canonical repos —
do not confuse):**

- **`aidoc-flow-ci` (this repo)** = CI reusable workflows + config
  templates + canonical scripts + governance-file templates + ai-review
  rubric + REPO_STANDARDS static-settings + workflow-adoption + tier
  rulebook. When a consumer
  cites a canonical CI/workflow/template/script source, point here.
- **`aidoc-flow-operations`** = OPS-NNNN durable business decisions
  (governance-PR discipline, auto-merge default, multi-agent review
  dispatch, circuit-breaker, aidoc-flow-standard scope, audit-trail
  phrase, project-governance-canon ratification), multi-agent review
  prompt templates at `.claude/agents/review-prompts/` (per OPS-0067),
  cross-repo playbooks (T-C, T-C', T-D), autonomy-tiers table, AI-
  employees team registry. When a consumer cites an OPS-NNNN business
  decision or multi-agent review prompt template, point at operations.

Full disambiguation table + rule of thumb in `docs/REPO_STANDARDS.md`
§0 "Canonical source authority".

## Where things are

- `docs/REPO_STANDARDS.md` — the canonical rulebook (§1-§16).
- `install/` — canonical config templates + `apply-standards.sh` +
  `install.sh` bootstrap.
- `install/templates/` — per-file canonical templates (workflows,
  CODEOWNERS, branch protection, dependabot, governance-file
  skeletons).
- `.github/workflows/` — reusable workflow definitions (called by
  consumers via `uses:`).
- `scripts/` + `.github/workflows/` — canonical scripts + drift-check
  workflow (`pre_push_check.sh` + `standards-drift.yml`, etc.).
- `plans/` — per-initiative canon-evolution plans (PLAN-001, PLAN-002,
  PLAN-003, ...).
- `docs/troubleshooting.md` — recovery patterns (label-cycle §15, etc.).

## Per-repo governance — this repo owns its own continuity

The `aidoc-flow` workspace is **multi-repo**. Each repo governs its own
activity tracking; cross-session continuity is per-repo. The durable
surfaces for **this** repo:

| Surface | Path (in this repo) |
| --- | --- |
| Live HANDOFF | `HANDOFF.md` |
| TODO / backlog | Not adopted — `plans/` per-initiative plans + GitHub issues serve as the backlog; no separate TODO.md needed for a small canon repo |
| Decisions log | `DECISIONS.md` |
| Plans | `plans/` |
| Changelog | `CHANGELOG.md` |
| Roadmap | `ROADMAP.md` |

Never in `tmp/` (transient). Never in the umbrella `aidoc-flow/`
(holds no dev). Cross-repo coordination captured here references
siblings by path (`../<repo>/`), never relocates their state.

## GitHub operations

Use the **GitHub CLI (`gh`)** as the default for all GitHub operations —
PRs, issues, reviews, releases, repo queries — not the GitHub MCP
servers (`github-tt`, `github-vl`) or raw API calls. If `gh` is
unauthenticated, run `gh auth login` rather than falling back to
MCP/API.

## Workspace standards (aidoc-flow canon — read the canonical rules directly)

Every workspace-standard rule below states (a) a one-sentence summary of
what it says + (b) the canonical file path to READ for the full rule.

- **OPS-0061 governance PR discipline** — ≤3 doc surfaces per governance
  PR + mandatory adversarial pre-push self-review on diff.
  → `../operations/CLAUDE.md` § "Governance PR discipline".
- **OPS-0062 AI-agent auto-merge default** — auto-watch + auto-merge
  green PRs the AI opens; 10-attempt cap; carve-outs for
  🟡/🔴/governance/cross-repo/spec.
  → `../operations/CLAUDE.md` § "AI agent auto-merge default".
- **OPS-0065 multi-agent automated review** — before every push, dispatch
  the diff-class-matched sub-agents in parallel.
  → `../operations/CLAUDE.md` — search `OPS-0065` (text landmark, lives
  under `## Autonomy tiers`)
  + `../operations/.claude/agents/review-prompts/INDEX.md`.
- **OPS-0066 3-cycle circuit-breaker** — cap review→fix→re-review loops
  at 3 cycles; escalate to founder if not converged.
  → `../operations/CLAUDE.md` — search `OPS-0066` (text landmark, lives
  under `## Autonomy tiers`).
- **OPS-0067 aidoc-flow-standard scope** — multi-agent review applies to
  ALL non-paused workspace repos.
  → `../operations/CLAUDE.md` — search `OPS-0067` (text landmark, lives
  under `## Autonomy tiers`).
- **OPS-0069 mandatory pre-push audit-trail phrase** — every push must
  carry either `Multi-agent self-review per OPS-0065 (<agents>): <verdict>`
  or `Self-review skipped per founder OK <reason>` in a commit message.
  Enforced locally by `scripts/pre_push_check.sh` (in this repo, canon
  source) + in CI by `.github/workflows/audit-trail.yml` → `call / verify`.
  → `../operations/CLAUDE.md` — search `OPS-0069` (text landmark, lives
  under `## Autonomy tiers`).
- **REPO_STANDARDS canonical rulebook** — this repo IS the canon source
  for CI + governance-workflow rules. Reference by section number.
  → `docs/REPO_STANDARDS.md`.

## Runner policy — private repos are self-hosted ONLY (no exceptions)

**Every private aidoc-flow repo (operations, business, iplanic, interlog)
MUST run CI on self-hosted runners — never `ubuntu-latest`.** GitHub-hosted
minutes on a private repo are OPS-0049 billing exposure and against workspace
policy (founder, 2026-07-11). The canonical private label is the verbose array
`["self-hosted", "aidoc", "ci-ephemeral"]` (plus `[…, "ai-review"]` for the
heavy reviewer job on repos with a second pool, e.g. operations).

- The literal `"runner-self"` in the `install/templates/workflows/*-private.yml`
  templates is a **placeholder**, NOT a real registered label. A caller left on
  `runner-self` (or on the reusable's `ubuntu-latest` default) queues forever —
  always resolve it to the real `["self-hosted","aidoc","ci-ephemeral"]` pool.
- **Never "fix" a bricked private-repo gate by falling back to `ubuntu-latest`.**
  If a private repo has no pool yet, the fix is to **register the pool**
  (`../operations/scripts/ci-runner/run-ephemeral.sh`, labels
  `self-hosted,aidoc,ci-ephemeral`), not to switch to GitHub-hosted.
- Public repos (engramory, framework, iplan-standard, iplan-runner) stay on
  `ubuntu-latest`. Full routing table + registration steps: `docs/runners.md`.

## Repo-specific rules (canon-source discipline)

**Canon changes are load-bearing across the workspace.** Every
change to `install/templates/*`, `.github/workflows/*.yml`, or
`docs/REPO_STANDARDS.md` propagates to every consumer that pins the
next `ci/vX.Y.Z` tag. Discipline:

- **Every canon-body change ships with a `docs/REPO_STANDARDS.md`
  update** — either amending an existing section or adding a new one.
  The rulebook + the template must stay in sync; the CI
  `standards-drift` check enforces detection.
- **Semver discipline:** breaking changes to workflow inputs / config
  schema / expected consumer surfaces = MAJOR bump. Additive
  changes = MINOR. Bug fixes without schema changes = PATCH.
  Tagged via `git tag ci/vX.Y.Z` + GitHub release.
- **Rollout waves apply to canon adoption.** Per PLAN-002 §5.5 for CI +
  governance-workflow canon; per PLAN-003 §5.5 for project-governance
  file canon. Wave 0 (this repo) self-adopts BEFORE Wave 1+ consumers
  pull. The canon-source dogfoods its own canon.

## Session handoff

Sessions run in ephemeral containers — **only committed + pushed work
survives**. Start each session by reading `HANDOFF.md`; refresh it at
milestones and before any context compaction. Commit messages must
not contain model identifiers.
