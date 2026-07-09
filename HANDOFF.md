# HANDOFF — aidoc-flow-ci

Live cross-session resume point for the workspace CI + governance-workflow
canon library. Read at session start; refresh at milestones and before
context compaction.

## Current state (2026-07-09)

**PLAN-004 (company-default elevation) — A/B/C-series + D1 COMPLETE; D2 + E next.**
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

⚠️ **No `ci/v1.7.0` tag exists yet** (latest is `ci/v1.6.0`). VERSION + all
docs target it; the `curl …/ci/v1.7.0/…` install URLs won't resolve until the
founder cuts the tag — after the remaining v1.x slices land.

Earlier canon layers SHIPPED: **PLAN-003** (governance-file canon, #73–#75 +
follow-ups #76–#80) and **PLAN-002** (workspace standards + self-review
enforcement, PR-U1/U2/U3/U4, 2026-07-08).

## Open threads

- **PLAN-004 D2 + E remaining** (see PLAN-004 §5.4–§5.5). Each via: implement →
  pre-push reviewers (OPS-0065) → fold → merge-on-green.
  - **D2** (`ci/v1.8.0` breaking): de-brand templates — `${CODEOWNER_HANDLE}` in
    `CODEOWNERS.template` (9) + `config.json.template` (`ai_review`+`code_owners`);
    `${CANON_OPERATIONS_URL}` (7) + `${CANON_CI_URL}` (1) in `CLAUDE.md.template`;
    `install.sh --codeowner @handle` + `--canon-source-url <url>` flags +
    fetch-time substitution + a post-sub assertion (grep ONLY the declared
    placeholder names; NO pwd-heuristic per Pass-4). Defaults byte-identical
    (`--codeowner` defaults `@vladm3105`; omitting `--canon-source-url` keeps the
    `../operations` relative shape). **⚠️ COMPLICATION (mapped, not yet solved):**
    `apply-standards.sh --check` ALSO fetches these templates (`fetch_canon`;
    CODEOWNERS exact-match ~L379, CLAUDE.md ~L282) to detect drift by exact-match
    vs the consumer's files. Placeholders → install.sh substitutes (`@theirhandle`)
    but apply-standards fetches RAW (`${CODEOWNER_HANDLE}`) → CODEOWNERS/CLAUDE.md
    flagged as drifted on EVERY `--check`. The fix must make the drift check
    handle-aware (pass `--codeowner` to apply-standards + substitute before
    compare) OR normalize the handle out of the exact-match OR make CODEOWNERS a
    structural check. **This is a drift-pipeline design decision — do it fresh,
    carefully.** (FT-details in memory.)
  - **E** (`ci/v1.9.0`): `install.sh --update` + `manifest.json` unified drift.
  - Then the founder cuts the `ci/v1.7.0` tag.
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

1. **Start PR-D2** (A/B/C + D1 are merged). Read PLAN-004 §5.4 + the D2 bullet
   in `Open threads` above — ESPECIALLY the apply-standards drift-check
   COMPLICATION (placeholders vs exact-match drift). Decide the drift
   reconciliation FIRST (handle-aware / normalize / structural check), then
   implement install.sh substitution. Keep defaults byte-identical. Verify each
   change against the live install.sh + apply-standards.sh (lines shift; grep
   the symbol). Cap review/fix loops at 3 per OPS-0066. Then E, then the founder
   cuts `ci/v1.7.0`.
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
