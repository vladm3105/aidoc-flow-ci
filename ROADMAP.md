# ROADMAP — aidoc-flow-ci

Forward-looking view of the workspace CI + governance-workflow canon
library.

Sequenced by phase, not by month. Update in place when a phase closes;
deferred items belong in `plans/` or `HANDOFF.md` open threads.

---

## Current phase — v2.7.0 shipped (own-security-scanner suite); founder-gated rollout

`ci/v2.7.0` is the Latest release. On top of the uniform protected AI-flow model
(`ci/v2.2.0`, PLAN-013) and the ai-review autofix flow (`ci/v2.3.0`, PLAN-012), the
canon now ships the **own-security-scanner suite** (PLAN-014, "osv/trivy/semgrep, all
in, report-only first"): `dep-scan` (SCA, `ci/v2.4.0`), `trivy-scan` (IaC/misconfig,
`ci/v2.5.0`), `sast-scan` (SAST, `ci/v2.6.0`), + a deterministic `semgrep --autofix`
**preview** (no push, `ci/v2.7.0`). Each is opt-in, report-only, uniform-protected +
fork-guarded, installs its tool directly (no marketplace actions), and shipped with a
full OPS-0065 pre-push security review (4 HIGH + 2 MEDIUM + 1 LOW folded, several
verified by reproducing the exploit). `deploy-ci-wizard.sh` now knows the scanner
surfaces (opt-in). Remaining work is all **founder-gated** 🔴: the report-only pilot on
`operations` (runbook: `plans/ROLLOUT_plan014-operations-pilot.md`), then Phase 5
(`fail-on-findings` graduation, per scanner), propagation to pool-equipped repos, plus
the still-open autofix-App enablement + fleet re-pin. READ `HANDOFF.md` for live state.

| Milestone | Status |
|---|---|
| Pre-prod canon-side blockers (composition parse-bypass, backwards-repin, half-provisioned brick, `-private` variants, adopter docs) | DONE — shipped in `ci/v2.1.0` (#175–#177) |
| ai-review large-diff hardening (PLAN-011: `max_tokens` budget + honest `ai:review-infra-error` signal) | DONE — shipped in `ci/v2.1.1` (`max_tokens` 4096→8192) + `ci/v2.1.2` (→24576) |
| Fleet re-pin to `ci/v2.8.0` (target reconciled, PLAN-015 B1; forthcoming — cut when PLAN-015 lands; NOT a drop-in, public repos need pools) | Founder + ops/inbox (🔴 cross-repo; operations #268) |
| Server-side pre-prod blockers (composition-required on business/iplanic; branch protection on the 3 unprotected repos incl. canon) | Founder + ops/inbox (cross-repo) |
| PLAN-007 W4 fleet branch-protection arming | Founder-gated |
| PLAN-007 W3 docs-sync dry-run → live | Founder-gated (App provisioning or doc-maintainer supersession) |
| PLAN-008 pre-prod gap closure | COMPLETE (v2.0.0 cut) |
| PLAN-009 fleet v2 cutover | In flight (Phase 0 🔴-gated; target reconciled to `ci/v2.8.0`, PLAN-015 B1) |
| PLAN-010 adoption model | DRAFT — NOT READY (split recommended; see the plan) |
| PLAN-011 ai-review large-diff hardening | SHIPPED (`ci/v2.1.1` + `v2.1.2`) |
| PLAN-013 uniform protected AI-flow model (public+private, one self-hosted template, no visibility split) | SHIPPED (`ci/v2.2.0`) |
| PLAN-012 ai-review autofix flow (dedicated autofix App, public+private, default-off) | SHIPPED (`ci/v2.3.0`) — enabling is a separate 🔴 founder step |
| PLAN-014 own-security-scanner suite (osv/trivy/semgrep, report-only, uniform-protected) | SHIPPED Phases 1–4 (`ci/v2.4.0`–`ci/v2.7.0`) — deployment + Phase 5 graduation are 🔴 founder steps; pilot runbook prepared (`plans/ROLLOUT_plan014-operations-pilot.md`) |

**Recently landed:**

- 2026-07-18 — `ci/v2.7.0` cut: **sast-scan deterministic autofix PREVIEW (PLAN-014
  Phase 4)** — `semgrep --autofix` runs in the ephemeral workspace and surfaces the
  rule-provided patch in the job summary; nothing pushed (no App). Plus wizard support
  for the three scanner surfaces (no tag). Security-reviewed READY (LOW summary-fence nit folded).
- 2026-07-18 — `ci/v2.6.0` cut: **sast-scan (PLAN-014 Phase 3)** — semgrep SAST
  (version-pinned pip; covers private repos where CodeQL is N/A). Strips PR
  `.semgrepignore` (a `*`-ignore was a full gate-bypass — verified) + fail-loud on
  broken SARIF. 1 HIGH + 1 MEDIUM folded.
- 2026-07-18 — `ci/v2.5.0` cut: **trivy-scan (PLAN-014 Phase 2)** — IaC/misconfig
  (`trivy config`), SSRF-hardened to static scanners (terraform/helm fetch PR-controlled
  remote sources; `--tf-exclude-downloaded-modules` does NOT stop the fetch — verified). 1 HIGH + 1 MEDIUM folded.
- 2026-07-18 — `ci/v2.4.0` cut: **dep-scan (PLAN-014 Phase 1)** — dependency/SCA
  (osv-scanner binary); data-only (`--no-call-analysis=all`); no-manifests no longer
  silent-passes (`expect-manifests`). 2 HIGH folded.
- 2026-07-18 — `ci/v2.3.0` cut: **ai-review autofix (PLAN-012)** — gated,
  default-off fixer that (on request_changes) generates a diff, applies it under a
  governance deny-floor, and pushes via a dedicated ephemeral-token App to re-fire
  the gate. Security-reviewed (no blocker; 2 HIGH + MEDIUM/LOW folded).
- 2026-07-18 — `ci/v2.2.0` cut: **uniform protected AI-flow model (PLAN-013)** —
  AI-flows collapse to one self-hosted protected template each (public+private, no
  visibility split → flip is a no-op); generic fork-code lint flows stay
  GitHub-hosted. Fixed a wizard `startup_failure` bug caught in review.
- 2026-07-17 — `ci/v2.1.2` cut: ai-review verdict budget raised 8192→24576
  (PLAN-011 follow-up; live-verified headroom for reasoning-token spikes).
- 2026-07-17 — `ci/v2.1.1` cut: ai-review large-diff fix (PLAN-011) — verdict
  `max_tokens` 4096→8192 so reasoning tokens no longer truncate the verdict
  JSON, plus a new `ai:review-infra-error` label/comment so a residual reviewer
  failure surfaces honestly instead of as a fake `CHANGES_REQUESTED`.
- 2026-07-17 — `ci/v2.1.0` cut: pre-prod canon-side blockers closed (#175–#177):
  composition malformed-config bypass, `--repin`-backwards + version-sync guard,
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

## Next phase — deploy the shipped canon; server-side + consumer-feedback evolution

The canon capability is built through `ci/v2.7.0`; the next phase is founder-driven
**deployment** of what's shipped (scanners, autofix arming, fleet re-pin) plus the
server-side pre-prod items (branch protection, required-check parity) and
consumer-feedback-driven evolution.

**Planned initiatives:**

- **PLAN-014 scanner rollout** — report-only pilot on `operations`
  (`plans/ROLLOUT_plan014-operations-pilot.md`) → clean window → **Phase 5**
  (`fail-on-findings` false→true per scanner) → propagate to pool-equipped repos.
  Founder-executed (🔴 cross-repo); the Phase 4 autofix push-back subset batches with
  the PLAN-012 autofix-App enablement.
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
