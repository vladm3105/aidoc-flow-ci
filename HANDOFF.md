# HANDOFF — aidoc-flow-ci

Live cross-session resume point for the workspace CI + governance-workflow
canon library. Read at session start; refresh at milestones and before
context compaction.

## Current state (2026-07-08)

**PLAN-003 PR-V1** in flight — this repo self-adopts the project-governance
file canon it just canonized. All 4 self-adoption files (this HANDOFF,
DECISIONS.md, ROADMAP.md, CLAUDE.md) are new + backfilled from PLAN-001
/ PLAN-002 / PLAN-003 history. PR-V1 flips to "shipped" via PR-V4's
status update.

Next milestone: **PLAN-003 PR-V2** — `install/apply-standards.sh
--check-governance` mode implementation. Then PR-V3 (operations
CROSS_REPO_PLAYBOOKS §T-D), PR-V4 (aidoc-flow-ci PLAN-003 completion
doc). Then per-repo Wave 1-5 rollout.

## Open threads

- **PLAN-003 PR-V2** — draft the `--check-governance` parser + wire
  it into the existing drift-matrix per REPO_STANDARDS §16.4.
  Blocked on: nothing; ready when a session picks it up.
- **PLAN-003 PR-V3** — new `OPS-0070` on operations ratifying PLAN-003
  canon + CROSS_REPO_PLAYBOOKS §T-D wave-scheduling entry.
  Blocked on: PR-V2 merged (`--check-governance` is what the wave
  playbook tells consumers to run).
- **PLAN-003 PR-V4** — aidoc-flow-ci PLAN-003 status flip to SHIPPED +
  `docs/PLAYBOOK_governance-canon-rollout.md`.
  Blocked on: PR-V2 + PR-V3.
- **Per-repo rollout waves 1-5** — one PR per non-paused repo per
  PLAN-003 §5.5. Wave 1 = framework, iplan-standard. Wave 2 = operations,
  business, iplanic. Wave 3 = iplan-runner, engramory. Wave 4 = interlog.
  Wave 5 = umbrella. Sequential; within-wave alphabetical.
  Blocked on: PR-V2 (parser is what wave PRs are tested against).
- **Deferred `auto-merge-ai-prs.yml` GHA workflow** — HANDOFF backlog
  from operations. Server-side enforcer for the OPS-0062 AI-agent
  auto-merge default (covers cases where the AI session ends mid-merge
  or hits API limits). Not on this repo's active roadmap; noted for
  cross-repo backlog visibility.

## Next-session start-here

1. Read `plans/PLAN-003_project-governance-canon.md` end-to-end —
   §4.5 parser contract + §5.2 PR-V2 scope define the immediate work.
2. Read `docs/REPO_STANDARDS.md` §16 for the durable canon consumers
   follow.
3. Check `ROADMAP.md` for the phase sequence.
4. If picking up PR-V2: read `install/apply-standards.sh` to
   understand the existing `--check` mode's drift-matrix architecture;
   the new `--check-governance` mode extends it.

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

---

**Maintenance protocol:**

- Update `Current state` on every PR that changes what this repo is
  actively working on.
- Move resolved `Open threads` to `Recent decisions` (with CI-NNNN ID)
  or to git commit history.
- Prune `Recent decisions` — entries older than 4 weeks belong only in
  `DECISIONS.md`.
