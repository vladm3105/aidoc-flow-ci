# HANDOFF — aidoc-flow-ci

Live cross-session resume point for the workspace CI + governance-workflow
canon library. Read at session start; refresh at milestones and before
context compaction.

## Current state (2026-07-08)

**PLAN-003 canon layer SHIPPED** — canon templates + parser +
ratification landed via PR-V1 (this repo #73), PR-V2 (this repo #74),
PR-V3 (operations #217), PR-V4 (this PR). Per-repo Wave 1-5 rollouts
proceed next per PLAN-003 §5.5 / operations `docs/CROSS_REPO_PLAYBOOKS.md`
§T-D.

## Open threads

- **Per-repo rollout waves 1-5** — one PR per non-paused repo per
  PLAN-003 §5.5. Wave 1 = framework, iplan-standard. Wave 2 = operations,
  business, iplanic. Wave 3 = iplan-runner, engramory. Wave 4 = interlog.
  Wave 5 = umbrella. Sequential; within-wave alphabetical. Validation
  gate: `bash install/apply-standards.sh --check` zero drift on every
  wave repo before advancing.
- **Deferred `auto-merge-ai-prs.yml` GHA workflow** — HANDOFF backlog
  from operations. Server-side enforcer for the OPS-0062 AI-agent
  auto-merge default (covers cases where the AI session ends mid-merge
  or hits API limits). Not on this repo's active roadmap; noted for
  cross-repo backlog visibility.

## Next-session start-here

1. Read `docs/PLAYBOOK_governance-canon-rollout.md` for the canon-source-
   side rollout summary; defer to `../operations/docs/CROSS_REPO_PLAYBOOKS.md`
   §T-D for authoritative per-wave scope.
2. Read `plans/PLAN-003_project-governance-canon.md` §5.5 + §5.4c for
   per-repo wave scope details.
3. Read `docs/REPO_STANDARDS.md` §16 for the durable canon consumers
   follow.
4. If picking up Wave 1: framework retrofit + iplan-standard biggest
   scope (all 4 governance files NEW). Each Wave PR ≤3 surfaces per
   OPS-0061 Rule 1; bundle only with explicit founder OK.

## Recent decisions

- **CI-0001** — Adopt the flexible-canonical (Option B) approach for
  project governance files (PLAN-003 §4.1). Each repo picks + declares
  paths in its `CLAUDE.md`; canon enforces presence + declaration +
  consistency.
- **CI-0002** — Bundle PR-V1 canon templates with aidoc-flow-ci Wave 0
  self-adoption (11 surfaces total). Per PLAN-002 §5.4 dogfood
  precedent + explicit per-PR founder OK 2026-07-08.
- **CI-0003** — Cap review/fix loops at 3 cycles per OPS-0066; PLAN-003
  Pass 4 → Pass 5 → Pass 6 hit exactly the 3-cycle limit. Pass 6
  APPROVED; canon-worthy.
- PR-V1 (this repo #73) 2026-07-08 — canon templates + Wave 0
  self-adoption.
- PR-V2 (this repo #74) 2026-07-08 — governance-table parser +
  install.sh bootstrap.
- PR-V3 (operations #217) 2026-07-08 — CROSS_REPO_PLAYBOOKS §T-D +
  OPS-0070 ratification.
- PR-V4 (this PR) 2026-07-08 — PLAN-003 status flip to SHIPPED +
  rollout playbook doc + HANDOFF/ROADMAP inline updates.

---

**Maintenance protocol:**

- Update `Current state` on every PR that changes what this repo is
  actively working on.
- Move resolved `Open threads` to `Recent decisions` (with CI-NNNN ID)
  or to git commit history.
- Prune `Recent decisions` — entries older than 4 weeks belong only in
  `DECISIONS.md`.
