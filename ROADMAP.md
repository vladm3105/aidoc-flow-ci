# ROADMAP — aidoc-flow-ci

Forward-looking view of the workspace CI + governance-workflow canon
library.

Sequenced by phase, not by month. Update in place when a phase closes;
deferred items belong in `plans/` or `HANDOFF.md` open threads.

---

## Current phase — PLAN-003 project governance file canon rollout

Ship the flexible-canonical rule (§16 of `docs/REPO_STANDARDS.md`) + 5
markdown templates + `--check-governance` parser + Wave 0-5 per-repo
rollout.

**In flight:**

- **Per-repo Wave 1-5 rollouts** — one PR per non-paused repo per
  PLAN-003 §5.5. Sequential; within-wave alphabetical. Wave 1 first
  = framework + iplan-standard.

**Recently landed:**

- 2026-07-08 — PLAN-003 canon layer SHIPPED. PR-V4 (this PR): status
  flip DRAFT → SHIPPED + `docs/PLAYBOOK_governance-canon-rollout.md`
  companion doc + inline HANDOFF/ROADMAP updates.
- 2026-07-08 — PR-V3 (operations #217): CROSS_REPO_PLAYBOOKS §T-D +
  `OPS-0070` ratification.
- 2026-07-08 — PR-V2 (this repo #74): `install/parse-governance-table.py`
  parser + `governance_check` in `install/apply-standards.sh` +
  `install/install.sh` CLAUDE.md bootstrap.
- 2026-07-08 — PR-V1 (this repo #73): 5 canon templates + REPO_STANDARDS
  §16 + Wave 0 self-adoption bundle (11 surfaces under explicit founder
  OK).
- 2026-07-08 — PLAN-003 plan document merged (this repo #72).
- 2026-07-08 — PLAN-002 workspace CI + governance-workflow canon
  rollout SHIPPED (7 waves completed; ci/v1.6.0 tagged; 5 consumer
  PRs merged in this session — business #39 + iplanic #232 remain
  pending founder `--admin`).

---

## Next phase — canon evolution + label sync

Once PLAN-003 rolls out, next phase evolves the canon based on
consumer feedback + closes the workspace-wide label sync work
deferred from PLAN-002.

**Planned initiatives:**

- **Canon label sync** — reconcile label taxonomies across the 9
  non-paused repos (some use `bug/enhancement/documentation`, others
  use `feat/fix/chore/docs`). Canon should ship a preferred set +
  install helper.
- **Reusable branch-protection auditor** — GHA workflow that reports
  drift between each consumer's actual branch-protection rules and
  the canonical templates (`branch-protection-*.json` in `install/`).
- **Umbrella backlog** — `auto-merge-ai-prs.yml` server-side enforcer
  per operations HANDOFF; covers OPS-0062 auto-merge cases where the
  AI session ends before checks settle.

---

## Deferred / parked

- **Multi-tier reusable AI-review** — different review depth per
  tier (governance = adversarial; ops-private = standard; product =
  light). Deferred: current single-tier flow works; multi-tier adds
  configuration complexity without clear pull.
- **Cross-repo dependency tracking** — auto-detect submodule pins vs
  latest tags across the workspace + surface staleness in a
  dashboard. Deferred: manual bumps work at current scale; automation
  is speculative until submodule velocity increases.
- **CI runtime metrics** — per-workflow duration + cost tracking.
  Deferred: no budget pressure.

---

**Maintenance protocol:**

- When PLAN-003 rollout closes, promote "Next phase" to "Current
  phase"; move landed items to git commit history (or DECISIONS.md if
  the phase outcome was itself a load-bearing decision).
- Do NOT accumulate — a roadmap that grows longer every quarter is a
  backlog in disguise.
