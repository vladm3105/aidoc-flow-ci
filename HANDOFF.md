# HANDOFF — aidoc-flow-ci

Live cross-session resume point for the workspace CI + governance-workflow
canon library. Read at session start; refresh at milestones and before
context compaction.

## Current state (2026-07-09)

**PLAN-004 (company-default elevation) in progress.** A 5-agent pre-prod
review of this repo → SHIP-WITH-FIXES; the fix plan
(`plans/PLAN-004_company-default-elevation.md`, merged #82) sequences PRs
A1–A6 (docs, `ci/v1.7.0`) → B (correctness) → C (security) → D (de-brand +
trust-root) → E (install `--update`). **A-series docs landed:**

- PR-A1 (#83) — `VERSION` single-source + `install.sh` tag precedence +
  `scripts/sync-version-refs.sh` + README/install-README rewrites.
- PR-A2 (#84) — `check-drift.sh` per-caller pin fix; all template pins →
  `@ci/v1.7.0`; sync enforces docs + template pins.
- PR-A3 (#85) — `LABELS.md` parity (16 labels); NEW docs
  `REVIEWER_APP_ONBOARDING.md`, `BRANCH_PROTECTION.md`,
  `plans/FRAMEWORK-TODO.md`; fast-follow #86 resolved the "forthcoming" refs.

Earlier canon layers SHIPPED: **PLAN-003** (governance-file canon, #73–#75 +
follow-ups #76–#80) and **PLAN-002** (workspace standards + self-review
enforcement, PR-U1/U2/U3/U4, 2026-07-08).

## Open threads

- **PLAN-004 remaining** — PR-A4 (governance-state: this HANDOFF + PLAN-002
  status + DECISIONS CI-0004) + A4b (CHANGELOG restructure) → A5/A6
  (overrides/docs-README/local-pre-push; runners) → **B** (doc-maintainer
  schedule bug, composition author fallback, fork-safety) → **C** (auto-merge
  composition-armed gate, SHA-pins, env-var indirection) → **D** (de-brand
  templates + parameterize the hardcoded operations trust root) → **E**
  (`install.sh --update` + manifest drift-check). Each via: implement → 2
  pre-push reviewers (OPS-0065) → fold → merge-on-green.
- **`plans/FRAMEWORK-TODO.md`** — FT-1 (branch-protection templates lag
  REPO_STANDARDS §2 on `call / verify`), FT-2 (verify `pre-commit`/`secret-scan`
  emitted context names), FT-3 (`labels.json` `skip-ai-review` description
  contradicts behavior). Surfaced by PR-A3 review; resolve before elevation.
- **PLAN-003 per-repo rollout waves** — one PR per non-paused repo per
  PLAN-003 §5.5 / operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D. Wave status
  is tracked there (do not hardcode a "next wave" here — it drifts). Validation
  gate: zero drift via the curl-piped `apply-standards.sh --check` (see
  `docs/PLAYBOOK_governance-canon-rollout.md`).

## Next-session start-here

1. Read this `Current state` + `plans/PLAN-004_company-default-elevation.md`
   §5 for the A–E deliverable sequence + Claim ledger.
2. Resume at the next unmerged PLAN-004 PR (A4b or A5 if A4 landed; else
   the next in sequence). Each PR ≤3 doc surfaces per OPS-0061.
3. For PLAN-003 rollout work, read `docs/PLAYBOOK_governance-canon-rollout.md`
   then defer to operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D for
   authoritative per-wave scope.
4. `docs/REPO_STANDARDS.md` is the durable canon consumers follow.

## Recent decisions

See `DECISIONS.md` for the full CI-NNNN record. Latest:

- **CI-0004** (2026-07-09) — workflow-policy delegation table: this repo's
  workflow behaviors implement OPS-0062/0065/0066/0067/0061/0069; change
  policy in operations, implementation here.
- **CI-0003** (2026-07-08) — 3-cycle review circuit-breaker (OPS-0066)
  confirmed canonical for this repo's plan review.
- **CI-0002** (2026-07-08) — bundle PR-V1 canon with Wave 0 self-adoption.
- **CI-0001** (2026-07-08) — flexible-canonical (Option B) governance files.

Recent merges: PLAN-003 PR-V1/V2/V4 (#73/#74/#75) + canon follow-ups
(#76 template row / #77 parser suffix / #78 rubric / #79 canonical-source
disambiguation / #80 REPO_STANDARDS §17 auto-merge canon); PLAN-004 #82
(plan) + #83–#86 (A-series).

---

**Maintenance protocol:**

- Update `Current state` on every PR that changes what this repo is
  actively working on. Never leave a "(this PR)" self-reference — name the
  PR number, or phrase it as upcoming.
- Move resolved `Open threads` to `Recent decisions` (with CI-NNNN ID)
  or to git commit history.
- Prune `Recent decisions` — entries older than 4 weeks belong only in
  `DECISIONS.md`.
