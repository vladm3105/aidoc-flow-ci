# HANDOFF — aidoc-flow-ci

Live cross-session resume point for the workspace CI + governance-workflow
canon library. Read at session start; refresh at milestones and before
context compaction.

## Current state (2026-07-09)

**PLAN-004 (company-default elevation) — A/B/C-series + D1 + D2 COMPLETE; CODEOWNERS de-brand (FT-7) + E next.**
A 5-agent pre-prod review of this repo → SHIP-WITH-FIXES; the fix plan
(`plans/PLAN-004_company-default-elevation.md`, merged #82) sequences A1–A6
(docs) → B (correctness) → C (security) → D (de-brand + trust-root) → E
(install `--update`). Merged so far:

- **A-series** (#83–#90, wrap #91): all adopter docs + governance + CHANGELOG,
  plus the drift-check per-caller fix.
- **B-series** (correctness): B1 #92 (doc-maintainer schedule bug — reconcile
  split into own job + dedup fall-through), B2 #93 (composition author via
  gh-api — `workflow_run.pull_requests[].user` is ABSENT), B3 #94 (fork-safety:
  labeler→pull_request_target, codeql/secret-scan skip-upload-on-fork), B4 #95
  (timeout-minutes on 12 reusables + apply-standards label %3A-encode +
  audit-trail fetch diag + troubleshooting §16-18).
- **C-series** (security): C1 #96 (SHA-pins + npm pin + curl|bash + drift
  permissions), C2 #97 (env-var indirection), C3 #98 (BL-3 auto-merge
  composition-armed gate — closes hand-applied-label bypass, preserves
  stuck-green recovery).
- **D1** #99 (BL-2 trust-root parameterization — trust_config_repo/ref inputs;
  defaults byte-identical).
- **D2** (de-brand install templates): `config.json.template`
  (`${CODEOWNER_HANDLE}`) + `CLAUDE.md.template` (`${CANON_OPERATIONS_URL}` ×7 /
  `${CANON_CI_URL}` ×1) parameterized; `install.sh` `--codeowner` /
  `--canon-operations-url` / `--canon-ci-url` flags + `python3` literal
  substitution (argv, not interpolated) + fail-closed post-sub assertion;
  defaults byte-identical (round-trip verified). REPO_STANDARDS §16.7.
  **Scope correction vs the pre-D2 HANDOFF/plan:** CLAUDE.md is NOT
  exact-match drift-checked (it's a structural governance-table parse) and
  config.json isn't drift-checked at all — so both parameterize with zero
  drift risk. The feared "drift-pipeline redesign" applies ONLY to
  `CODEOWNERS.template` (the only de-brand template that is exact-match
  drift-checked, and it is not install-written), so CODEOWNERS de-brand was
  split out to **FT-7** with the normalize-drift-check design.

⚠️ **No `ci/v1.7.0` tag exists yet** (latest is `ci/v1.6.0`). VERSION + all
docs target it; the `curl …/ci/v1.7.0/…` install URLs won't resolve until the
founder cuts the tag — after the remaining v1.x slices land.

Earlier canon layers SHIPPED: **PLAN-003** (governance-file canon, #73–#75 +
follow-ups #76–#80) and **PLAN-002** (workspace standards + self-review
enforcement, PR-U1/U2/U3/U4, 2026-07-08).

## Open threads

- **PLAN-004 CODEOWNERS de-brand (FT-7) + E remaining** (see PLAN-004 §5.4–§5.5).
  Each via: implement → pre-push reviewers (OPS-0065) → fold → merge-on-green.
  - **CODEOWNERS de-brand = FT-7** (was the "D2 complication"): `CODEOWNERS.template`
    is the only de-brand template that is exact-match drift-checked
    (`apply-standards.sh` `exact_match_check` ~L379 also covers a few
    non-branded files) AND is not written by `install.sh`, so a
    `${CODEOWNER_HANDLE}` placeholder there reads as permanent drift. De-branding it
    needs a handle-normalizing drift check FIRST (recommended: strip `@handle`
    tokens from both sides before diff — verifies path structure, ignores the
    consumer-specific owner) + a new install.sh CODEOWNERS install step reusing D2's
    `substitute_placeholders`. Full design in `plans/FRAMEWORK-TODO.md` FT-7.
    `@vladm3105` is correct for every current consumer, so this is not urgent.
  - **E** (`install.sh --update`): update mode + `manifest.json` unified drift.
  - Then the founder cuts the `ci/v1.7.0` tag (VERSION stays `ci/v1.7.0` — all
    A–E slices land under the first cut; the plan's per-slice `v1.8.0`/`v1.9.0`
    numbers were aspirational and D2 is additive/byte-identical, not breaking).
- **`plans/FRAMEWORK-TODO.md`** — FT-1 (branch-protection templates lag
  REPO_STANDARDS §2 on `call / verify`), FT-2 (verify `pre-commit`/`secret-scan`
  emitted context names), FT-3 (`labels.json` `skip-ai-review` description),
  FT-4 (CHANGELOG back-catalog per-tag cut), FT-5 (drift job needs
  `administration: read`), FT-6 (composition trust-source not parameterized —
  reads `$GH_REPO@main`; fails safe). Resolve before elevation.
- **PLAN-003 per-repo rollout waves** — one PR per non-paused repo per
  PLAN-003 §5.5 / operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D. Wave status
  is tracked there (do not hardcode a "next wave" here — it drifts). Validation
  gate: zero drift via the curl-piped `apply-standards.sh --check` (see
  `docs/PLAYBOOK_governance-canon-rollout.md`).

## Next-session start-here

1. **Pick up at FT-7 (CODEOWNERS de-brand) or PR-E** (A/B/C + D1 + D2 merged).
   FT-7 needs the drift-pipeline decision (recommended: normalize `@handle` out
   of the CODEOWNERS exact-match); PR-E is the `install.sh --update` +
   `manifest.json` unified drift. Read `plans/FRAMEWORK-TODO.md` FT-7 for the
   full CODEOWNERS design. Reuse D2's `install.sh` `substitute_placeholders`
   helper. Keep defaults byte-identical (round-trip test). Verify each change
   against the live `install.sh` + `apply-standards.sh` (grep the symbol; lines
   shift). Cap review/fix loops at 3 per OPS-0066. Then the founder cuts
   `ci/v1.7.0`.
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
