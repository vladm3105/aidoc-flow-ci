# ROADMAP — aidoc-flow-ci

Forward-looking view of the workspace CI + governance-workflow canon
library.

Sequenced by phase, not by month. Update in place when a phase closes;
deferred items belong in `plans/` or `HANDOFF.md` open threads.

---

## Current phase — ci/v2.1.0 fleet-readiness (pre-prod blockers closed)

`ci/v2.0.0` (LiteLLM unification) and `ci/v2.0.1` (ai-review v2 blocker fixes)
**shipped** (2026-07-13 / 07-15). The current phase is making the canon
production-ready as the company-default source of truth for all repos: a 5-lens
pre-prod review (2026-07-17) returned BLOCKER, and the **canon-side blockers are
now closed** on `main`, unreleased, awaiting the `ci/v2.1.0` cut. READ
`HANDOFF.md` for the live cut/rollout state.

| Milestone | Status |
|---|---|
| Pre-prod canon-side blockers (composition parse-bypass, backwards-repin, half-provisioned brick, `-private` variants, adopter docs) | DONE — on main (#175–#177), awaiting v2.1.0 cut |
| `ci/v2.1.0` tag cut | Founder go/no-go (sequencing vs PLAN-009's in-flight v2.0.1 cutover) |
| Server-side pre-prod blockers (composition-required on business/iplanic; branch protection on the 3 unprotected repos incl. canon) | Founder + ops/inbox (cross-repo) |
| PLAN-007 W4 fleet branch-protection arming | Founder-gated |
| PLAN-007 W3 docs-sync dry-run → live | Founder-gated (App provisioning or doc-maintainer supersession) |
| PLAN-008 pre-prod gap closure | COMPLETE (v2.0.0 cut) |
| PLAN-009 fleet v2 cutover | In flight (Phase 0 🔴-gated) |
| PLAN-010 adoption model | DRAFT — NOT READY (split recommended; see the plan) |

**Recently landed:**

- 2026-07-17 — pre-prod canon-side blockers closed (#175–#177): composition
  malformed-config bypass, `--repin`-backwards + version-sync guard,
  half-provisioned brick, 6 `-private` variants, adopter cold-start docs.
- 2026-07-15 — `ci/v2.0.1` cut: ai-review v2 blocker fixes (request_changes jq,
  review-event bypass, python3 preflight).
- 2026-07-13 — `ci/v2.0.0` cut: LiteLLM unification (breaking).
- 2026-07-12 — `feat/unified-litellm-agents` merged (#154): dependency-free
  LiteLLM adapter, config schema v2, real-proxy smoke workflow.
- 2026-07-12 — PLAN-007 W3 markdown-lint graduation: canon `.markdownlint.json`
  relaxed (MD013/MD024/MD036), all 6 consumers graduated to blocking.
- 2026-07-12 — PLAN-007 W1/W2/W5: test suite (#143), guardrails (#144/#145),
  Dependabot prune (#137).
- 2026-07-11 — PLAN-006 W4 content-check population COMPLETE across all active repos.
- 2026-07-10 — PLAN-004 SHIPPED (`ci/v1.7.0`): company-default elevation with
  A-series docs, B correctness, C security, D de-brand + trust-root, E
  install `--update`.
- 2026-07-10 — PLAN-005 SHIPPED (`ci/v1.7.1` → `v1.8.1`): governance floor,
  skip carry-forward, trust-root parameterization, App-native trust fetch.
- 2026-07-08 — PLAN-003 governance-canon SHIPPED: flexible-canonical rule +
  5 templates + parser + Wave 0 self-adoption.
- 2026-07-08 — PLAN-002 workspace standards + self-review enforcement SHIPPED.

---

## Next phase — post-v2.1.0 canon evolution

Once `ci/v2.1.0` is cut and the fleet is on it, next phase closes the
server-side pre-prod items (branch protection, required-check parity) and
evolves the canon based on consumer feedback.

**Planned initiatives:**

- **W4 fleet branch-protection arming** — arm the now-blocking checks as
  required across all consumers. Founder-executed; runbook at
  `docs/FLEET_BRANCH_PROTECTION_ARMING.md`.
- **W3 docs-sync dry-run → live** — provision `aidoc-flow-bot` App or fold
  into `doc-maintainer.yml` supersession.
- **Canon label sync** — reconcile label taxonomies across the 9
  non-paused repos (some use `bug/enhancement/documentation`, others
  use `feat/fix/chore/docs`). Canon should ship a preferred set +
  install helper.
- **Reusable branch-protection auditor** — GHA workflow that reports
  drift between each consumer's actual branch-protection rules and
  the canonical templates (`branch-protection-*.json` in `install/`).

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
