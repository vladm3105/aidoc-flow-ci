# PLAYBOOK — project-governance file canon rollout

Canon-source-side summary of the PLAN-003 project-governance file canon
rollout. Serves AI agents + operators who enter the workspace via
`aidoc-flow-ci/` first and don't cross-load
`../operations/docs/CROSS_REPO_PLAYBOOKS.md` automatically.

**Authoritative operational playbook:**
`../operations/docs/CROSS_REPO_PLAYBOOKS.md` § "3. Project-governance-
canon rollout waves (T-D)". This document is a summary + link-back, not
a duplicate — always defer to §T-D for the load-bearing per-wave scope.

## What shipped

- **PR-V1** (this repo, 2026-07-08) — 5 canon templates in
  `install/templates/` + `docs/REPO_STANDARDS.md` §16 + Wave 0
  self-adoption (this repo's `CLAUDE.md` + `HANDOFF.md` + `DECISIONS.md`
  + `ROADMAP.md` created from templates).
- **PR-V2** (this repo, 2026-07-08) — `install/parse-governance-table.py`
  parser implementing §4.5 contract + `governance_check` in
  `install/apply-standards.sh` (fires in `--check` / `--dry-run` /
  `--report` modes) + `install/install.sh` CLAUDE.md bootstrap step.
- **PR-V3** (operations, 2026-07-08) — CROSS_REPO_PLAYBOOKS §T-D
  operational playbook + `OPS-0070` ratification decision.
- **PR-V4** (this repo) — status flip + this summary doc.

## Wave summary (see operations §T-D for full scope)

Waves execute sequentially — Wave N+1 does not start until Wave N is
FULLY green: all PRs merged, and zero drift on every wave repo. Run the
drift check from each consumer's repo root:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v1.9.1/install/apply-standards.sh) --check
```

`apply-standards.sh` lives in `aidoc-flow-ci`, not the consumer, so it is
fetched via `curl`; `--check` compares the consumer's files in the current
directory against canon. Within a wave, alphabetical order is fine.

| Wave | Repos | Scope summary |
| --- | --- | --- |
| 0 | `aidoc-flow-ci` | Self-adoption bundled with PR-V1 (2026-07-08 — shipped) |
| 1 | `aidoc-flow-framework`, `aidoc-flow-iplan-standard` | Per-repo Wave PRs; framework: retrofit + additional rows; iplan-standard: biggest scope (all 4 files NEW) |
| 2 | `aidoc-flow-operations`, `aidoc-flow-business`, `aidoc-flow-iplanic` | Per-repo Wave PRs; ops-private tier retrofits |
| 3 | `iplan-runner`, `aidoc-flow-engramory` | Per-repo Wave PRs; engramory: HANDOFF+DECISIONS+`## What this repo is` NEW; dual-ROADMAP consolidation |
| 4 | `aidoc-flow-interlog` | Per-repo Wave PR; `## Workspace standards` block NEW |
| 5 | `aidoc-flow` (umbrella) | Per-repo Wave PR; `## Per-repo governance` heading NEW |

Paused repos (`aidoc-flow-knowledge-rag`, `aidoc-flow-site`) skipped
per founder direction 2026-07-04.

## Wave PR shape

Each per-repo Wave PR touches ≤3 doc surfaces per OPS-0061 Rule 1:

- Consumer `CLAUDE.md` (updated / created).
- Newly created governance files (HANDOFF/DECISIONS/ROADMAP/plans-README
  as needed per per-repo scope).
- Consumer `CHANGELOG.md` `[Unreleased]` entry.

If scope exceeds 3 surfaces (e.g., iplan-standard biggest-scope Wave 1),
either split into sequential smaller PRs OR obtain explicit founder OK
per PLAN-002 §5.4 precedent + record via OPS-0069 audit-trail phrase.

## Wave validation gate

Before closing a wave:

1. `bash <(curl -fsSL https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v1.9.1/install/apply-standards.sh) --check`
   on every repo in the wave (run from each consumer's repo root — the
   script is fetched from `aidoc-flow-ci`, not present in the consumer).
   Zero drift required.
2. `gh pr view <n>` confirms each wave PR merged.
3. Update the plan-owning `HANDOFF.md` (`aidoc-flow-ci/HANDOFF.md`)
   `## Current state` + `## Open threads` to reflect wave close.

## Canonical surfaces to consult

For deeper context (in this repo unless noted):

- `plans/PLAN-003_project-governance-canon.md` — design (§4.1 flexible-
  canonical rule; §4.2 canon template shape; §4.5 parser contract;
  §5.4c per-repo delta table; §5.5 wave order).
- `docs/REPO_STANDARDS.md` §16 — durable rule text.
- `install/templates/CLAUDE.md.template` — canonical CLAUDE.md shape.
- `install/parse-governance-table.py` — parser implementing §4.5.
- `install/apply-standards.sh` — drift-check driver.
- `install/install.sh` — bootstrap installer.
- `../operations/docs/CROSS_REPO_PLAYBOOKS.md` §T-D — operational
  playbook (authoritative).
- `../operations/ops/DECISIONS.md` OPS-0070 — ratification decision.
