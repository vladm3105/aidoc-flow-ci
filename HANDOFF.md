# HANDOFF — aidoc-flow-ci

Live cross-session resume point for the workspace CI + governance-workflow
canon library. Read at session start; refresh at milestones and before
context compaction.

## Current state (2026-07-09)

**PLAN-004 (company-default elevation) — A-series 100% COMPLETE; B–E next.**
A 5-agent pre-prod review of this repo → SHIP-WITH-FIXES; the fix plan
(`plans/PLAN-004_company-default-elevation.md`, merged #82) sequences PRs
A1–A6 (docs, `ci/v1.7.0`) → B (correctness) → C (security) → D (de-brand +
trust-root) → E (install `--update`). **All A-series PRs merged** (#83 A1
VERSION/install.sh precedence; #84 A2 check-drift per-caller fix + template
pins; #85 A3 LABELS 16-parity + reviewer-App/branch-protection docs +
FRAMEWORK-TODO, #86 fast-follow; #87 A4 HANDOFF/CI-0004/PLAN-002 SHIPPED;
A4b (#88) CHANGELOG dedup+staging; A5 (#89) overrides/README/local-pre-push
accuracy; A6 (#90) runners external-adopter de-leak). Every adopter-facing
doc, governance surface, CHANGELOG, and the drift-check correctness fix are
done.

⚠️ **No `ci/v1.7.0` tag exists yet** (latest is `ci/v1.6.0`). VERSION + all
docs target it; the `curl …/ci/v1.7.0/…` install URLs won't resolve until
the founder cuts the tag — a founder action after the v1.7.x slices (B/C)
land.

Earlier canon layers SHIPPED: **PLAN-003** (governance-file canon, #73–#75 +
follow-ups #76–#80) and **PLAN-002** (workspace standards + self-review
enforcement, PR-U1/U2/U3/U4, 2026-07-08).

## Open threads

- **PLAN-004 B–E remaining** (the substantive workflow-behavior slices; see
  PLAN-004 §5.2–§5.5 for full scope + Claim ledger). Each via: implement → 2
  pre-push reviewers (OPS-0065) → fold → merge-on-green.
  - **B** (`ci/v1.7.1` correctness): `doc-maintainer.yml` schedule bug (cron
    fires the whole pipeline — split reconcile into its own job, per PLAN-004
    §5.2.1); `composition.yml:76` author fallback (`workflow_run.actor.login`
    → `workflow_run.pull_requests[0].user.login`); per-file fork-safety
    (labeler + codeql → `pull_request_target`; secret-scan stays
    `pull_request` + doc); PR-B items 5-8 (apply-standards label URL-encode,
    audit-trail-check fetch diagnostics, `timeout-minutes` sweep on 9
    reusables, troubleshooting entries).
  - **C** (`ci/v1.7.2` security): auto-merge composition-armed gate (BL-3 —
    incl. the `skip-ai-review` carry-forward mirror + the double-label
    residual, both stated in §4.2); SHA-pin `create-github-app-token` +
    `checkout`; env-var indirection (codeql/pre-commit/links); npm + `curl|bash`
    pins; `standards-drift.yml` top-level `permissions`.
  - **D** (`ci/v1.8.0` breaking): de-brand templates (`${CODEOWNER_HANDLE}` /
    `${CANON_*_URL}` + `install.sh --codeowner/--canon-source-url`); **BL-2**
    parameterize the hardcoded operations trust root
    (`ai-review.yml:107/306/315`, `auto-merge-ai-prs.yml:168`) via
    `trust_config_repo`/`trust_config_ref` inputs.
  - **E** (`ci/v1.9.0`): `install.sh --update` + `manifest.json` unified drift.
  - Then the founder cuts the `ci/v1.7.0` tag.
- **`plans/FRAMEWORK-TODO.md`** — FT-1 (branch-protection templates lag
  REPO_STANDARDS §2 on `call / verify`), FT-2 (verify `pre-commit`/`secret-scan`
  emitted context names), FT-3 (`labels.json` `skip-ai-review` description
  contradicts behavior), FT-4 (CHANGELOG v1.1.0–v1.6.0 back-catalog not cut
  into per-tag `##` headers — deferred from A4b, needs git-log reconciliation).
  Resolve before elevation.
- **PLAN-003 per-repo rollout waves** — one PR per non-paused repo per
  PLAN-003 §5.5 / operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D. Wave status
  is tracked there (do not hardcode a "next wave" here — it drifts). Validation
  gate: zero drift via the curl-piped `apply-standards.sh --check` (see
  `docs/PLAYBOOK_governance-canon-rollout.md`).

## Next-session start-here

1. **Start PR-B** (the A-series is fully merged). Read
   `plans/PLAN-004_company-default-elevation.md` §5.2 (B scope) + its Claim
   ledger for the exact `file:line` anchors, and the `Open threads` B bullet
   above. B changes workflow behavior — verify each fix against the live
   workflow before + after (the plan's cited lines may have shifted; grep the
   symbol). Cap review/fix loops at 3 per OPS-0066.
2. For PLAN-003 rollout work, read `docs/PLAYBOOK_governance-canon-rollout.md`
   then defer to operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D for
   authoritative per-wave scope.
3. `docs/REPO_STANDARDS.md` is the durable canon consumers follow.

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
(plan) + #83–#90 (A-series A1–A6, complete).

---

**Maintenance protocol:**

- Update `Current state` on every PR that changes what this repo is
  actively working on. Never leave a "(this PR)" self-reference — name the
  PR number, or phrase it as upcoming.
- Move resolved `Open threads` to `Recent decisions` (with CI-NNNN ID)
  or to git commit history.
- Prune `Recent decisions` — entries older than 4 weeks belong only in
  `DECISIONS.md`.
