# Changelog — aidoc-flow-ci

Notable releases of the shared CI library. SemVer per `ci/vX.Y.Z`
tags (independent of framework spec semver per IPLAN-0017 §6 Q2).

## Unreleased

### Fixed — ci/v1.4.1: doc-maintainer.yml step 3 warn-not-error on missing CLI (IPLAN-0025 alpha.1 hotfix; 2026-06-29)

- **`.github/workflows/doc-maintainer.yml` step 3 'Resolve LLM CLI'** —
  changed from fail-LOUD-on-missing-CLI to best-effort install + warn-
  not-error. Rationale: the alpha.1 stub `planner.py` does NOT invoke
  the LLM (emits empty plan; per IPLAN-0025 §3 alpha-stub note); the
  actual CLI requirement only kicks in v1.4.1+ when the real LLM call
  ships in `planner.py` apply-mode. D12 fail-LOUD discipline preserved
  but MOVED INSIDE planner.py / apply.py where the LLM is actually
  invoked. Step 3 is now a best-effort install for ubuntu-latest
  convenience.
- **Bug discovered on FIRST live fire** on operations' ci-ephemeral
  self-hosted runner pool — pool does NOT have `npm` installed →
  `npm install -g @anthropic-ai/claude-code` exits 127 → step 3
  `command -v claude || exit 1` fails LOUD → workflow fails. Two
  consecutive failures observed (push event 2026-06-28 23:35:35Z run
  28340559175 + schedule event 2026-06-29 00:06:18Z run 28340614376).
- **Defensive shape:** step 3 now branches on `command -v claude` →
  `command -v npm` → no-op path, each with appropriate `::notice::` or
  `::warning::` output. Operator visibility preserved.
- **Operators on npm-less runners** (e.g., operations' ci-ephemeral):
  warning notice points to pre-baking the CLI as the production
  remediation. The alpha.1 stub doesn't need this fix (no LLM call)
  but the production v1.4.1+ ship will need pre-baked CLIs.
- **Consumer impact:** consumers bump `uses:` pin `@ci/v1.4.0` →
  `@ci/v1.4.1` to receive the fix. Operations specifically: also flips
  its `.github/doc-maintainer.json#kill_switch` back to `false` to
  re-arm the dry-run pilot (kill_switch was set to `true` as the
  immediate hotfix per operations PR #171).
- **Plan:** [IPLAN-0025 §3](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0025_ai-doc-maintainer.md)
  — alpha.1 ship strategy + alpha.1 stub design.
- **Discovered observability win:** the alpha.1 ship strategy worked
  as designed — shipping the workflow wiring first surfaced this
  runner-environment-assumption bug BEFORE LLM cost was incurred.
  Validates the IPLAN-0018 "didn't fire" lesson + the IPLAN-0025
  alpha.1 staged-ship discipline.

### Added — ci/v1.4.0 (Phase 1 P1 PR-B): install templates + docs for `doc-maintainer.yml` (IPLAN-0025 P1 PR-B; 2026-06-28)

- **`install/templates/workflows/doc-maintainer-private.yml`** +
  **`install/templates/workflows/doc-maintainer-public.yml`** — new
  thin caller templates per IPLAN-0025 §2.4. Triggers: `push: branches:
  [main]` (primary, after every merge) + `schedule: cron '7,37 * * * *'`
  (backup reconciler — off-peak slots per IPLAN-0025 D9 / Pass-3 minor
  #3 calibration, addresses IPLAN-0018 "didn't fire" gap
  deterministically). Pin: `@ci/v1.4.0`. Private variant uses
  `runner-self`; public variant uses `ubuntu-latest`.
- **`docs/architecture.md` §2** updated: workflow inventory table
  expanded from 7 → 9 shared workflows; new `docs-sync` row
  (mechanical; deprecated by doc-maintainer at end of IPLAN-0025
  Phase 3) + new `doc-maintainer` row (AI-driven; supersedes
  mechanical at end of Phase 3).
- **Consumer install prerequisites** documented in template headers:
  P3a 🟡 governance PR (add `aidoc-flow-bot[bot]` to consumer's
  `.github/ai-review/config.json#trust.ai_review`) + P5a 🟡 founder
  runbook (expand App permissions to `Pull-requests: write` +
  `Issues: write`). Dry-run path does NOT need these — they gate live
  mode (P5 graduation per the plan).
- **Bundled with PR-A** ([PR #43](https://github.com/vladm3105/aidoc-flow-ci/pull/43))
  in the same `ci/v1.4.0` release. Tag pushed after both PRs land.

### Added — ci/v1.4.0 (Phase 1 P1 PR-A): new AI-driven `doc-maintainer.yml` reusable workflow + supporting scripts (IPLAN-0025 P1 PR-A; 2026-06-28)

- **`.github/workflows/doc-maintainer.yml`** — new reusable workflow
  (`workflow_call:` only). Post-merge AI-driven doc-of-record
  maintainer. Reads merge diff + per-consumer conventions doc + invokes
  `claude` (or `codex`) to PLAN which docs need updating; risk-tier
  partitions the plan; dry-run posts PR comment, live mode opens
  follow-up bot PR for low-risk edits + GitHub issue for high-risk
  edits. Per IPLAN-0025 §2.1 (12-step job structure with deterministic
  dedup before LLM cost, fail-LOUD on infrastructure errors per D12).
- **`scripts/doc-maintainer/planner.py`** — step 4-7 (inventory
  candidates + AI plan + validate against outer allowlist + tier-classify).
  alpha.1 status: emits empty plan; real LLM invocation in v1.4.1.
- **`scripts/doc-maintainer/apply.py`** — step 8 (apply low-risk edits
  in apply-mode; produces `.proposed` files). alpha.1 status: no-op
  pass-through; real apply-mode in v1.4.1.
- **`scripts/doc-maintainer/reconcile.py`** — scheduled-cron backup
  reconciler (per §2.4 cron + Pass-2 BLOCKER #2 fix). Scans main
  commits in the lookback window + reports any SHA without an
  associated doc-maintainer run. alpha.1 status: report-only; auto-
  dispatch in v1.4.1.
- **Job-level permissions:** `contents: write` + `pull-requests: write`
  + `issues: write` + `actions: read`. Last one required for the
  reconciler's `actions/runs` query per Pass-3 HIGH Finding #3.
- **Recursion guards** (belt-and-suspenders): `[skip ci]` in bot
  commit message + `if: github.actor != 'aidoc-flow-bot[bot]'`.
- **Concurrency:** `group: doc-maintainer-${{ github.ref }}` with
  `cancel-in-progress: false`.
- **alpha.1 ship strategy:** the workflow wiring + scripts ship NOW
  (v1.4.0) so the dry-run pilot on operations can observe trigger
  reliability empirically (addressing IPLAN-0018 "didn't fire" gap
  ahead of LLM cost kicking in). Real LLM invocation + bot-PR
  creation + issue creation + reconciler auto-dispatch all ship in
  v1.4.1 after dry-run validates the skeleton.
- **PR-B coming next:** install templates
  (`install/templates/workflows/doc-maintainer-{private,public}.yml`)
  + docs updates (architecture.md / security.md / troubleshooting.md).
- **Plan:** [IPLAN-0025](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0025_ai-doc-maintainer.md)
  P1 PR-A (Phase 1 mechanism-only ship; full functionality in v1.4.1).
- **Consumer impact:** consumers do NOT bump pin until v1.4.0 ships
  via PR-B + tag. This PR-A is the workflow + scripts foundation.

### Changed — ci/v1.3.0 (Phase 2 P7): drop `pull_request_target` from composition install templates (IPLAN-0026 P7; 2026-06-28)

- **`install/templates/workflows/composition-private.yml`** + **`install/templates/workflows/composition-public.yml`** triggers
  reduced to `pull_request_review` + `workflow_run` only — Phase-2
  drop of `pull_request_target` per IPLAN-0026 §2.3 + IPLAN-0017 §3.4.
  The kept trigger set covers all four real state-change scenarios
  (routine-approve / routine-reject / skip-ai-review-carry / ai-review-
  infra-failure) without the wasted early-fire `pull_request_target`
  run that created the stale-red FAILURE on every routine PR.
- **`uses:` pin bumped** from `@ci/v1.2.0` to `@ci/v1.3.0` in both
  templates — `install.sh`-onboarded consumers get the v1.3.0 install
  shape (no `pull_request_target`) at install time.
- **Phase-2 ships the friction-relief benefit.** Phase 1 (ci/v1.2.0)
  shipped the `workflow_run` mechanism alongside `pull_request_target`
  for safe migration; Phase 2 drops `pull_request_target` so every
  composition fire now corresponds to a real state change. The label-
  cycle merge-recovery pattern documented at `docs/troubleshooting.md`
  §15 should no longer be needed for routine PRs after consumers bump
  their caller pin to `@ci/v1.3.0` + drop `pull_request_target` from
  their caller composition.yml (IPLAN-0026 P8 — separate consumer PRs
  on operations + framework, bundled into the same `ci/v1.3.0` release
  cycle).
- **`docs/security.md` §5** updated: composition no longer uses
  `pull_request_target` (new "Composition no longer uses
  `pull_request_target` (ci/v1.3.0+)" subsection); ai-review continues
  to use it. Security analysis still applies — composition's
  `pull_request_review` + `workflow_run` triggers carry the same
  BASE-ref + secrets posture as `pull_request_target`, so the
  Phase-2 drop is about merge-friction relief, not changing the
  security model.
- **Existing consumers** can still locally re-add `pull_request_target`
  if they have a flow dependent on it (local always wins per
  `docs/overrides.md`). The Phase-2 install template just no longer
  inherits it as a default.
- **Bundled with IPLAN-0027 P1** (R3 ai-review early-exit + troubleshooting
  §15 update) in the same `ci/v1.3.0` release — both are Phase-2 friction-
  relief cleanups; consumers do ONE pin-bump cycle to get both benefits.
- **Plan:** [IPLAN-0026](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0026_composition-workflow-run-redesign.md)
  P7 (Phase-2 cleanup; promotes IPLAN-0017 §3.4 Phase-B target to
  active state).
- **Consumer impact:** consumers bump caller pin `@ci/v1.2.0` →
  `@ci/v1.3.0` + drop `pull_request_target` from their caller
  `composition.yml` (IPLAN-0026 P8 — operations PR + framework PR
  shipping next).

### Changed — ci/v1.3.0 (P1): R3 ai-review early-exit when App already APPROVED at HEAD (IPLAN-0027 P1; 2026-06-28)

- **`.github/workflows/ai-review.yml`** — new "R3 early-exit if App
  already APPROVED at HEAD" step inserted at the top of the
  `ai-review` job's `steps:` list (before "Fetch reviewer assets").
  Queries the same App-APPROVED-at-HEAD review set that
  `composition.yml` uses (matching `user.id == APP_REVIEWER_1_BOT_ID`
  + `user.type == "Bot"` + `state == "APPROVED"` + `commit_id == HEAD_SHA`).
  When match found: writes `SKIP_REVIEW=1` + `SKIP_REASON=r3` to
  `$GITHUB_ENV` → all heavy downstream steps (`Fetch reviewer assets`,
  rubric run, App-token mint, verdict post, etc.) skip via their
  existing `if: env.SKIP_REVIEW != '1'` guards. Saves ~$0.10-0.20 +
  ~2-3 min per redundant re-fire (typical case: label-cycle-
  retriggered ai-review after the App had already APPROVED the same
  HEAD).
- **Safety: fail-OPEN on persistent API failure** — 7-attempt retry
  with `n*3` backoff capped at 20s (symmetric with
  `composition.yml:187-200` enforcement query). On all-7-retries-
  failed, R3 emits `::warning::` + exits 0 → full review path takes
  over. NEVER silently skips a needed review.
- **Safety: HEAD-SHA-tied query** — only the App's APPROVED-at-current-
  HEAD review counts. Force-push to a new SHA → no match at the new
  SHA → full review runs. Force-fresh-at-same-HEAD path: dismiss the
  App's prior review via
  `gh api -X PUT repos/<repo>/pulls/<pr>/reviews/<id>/dismissals
  -f event=DISMISS`.
- **Safety: INERT-when-App-not-armed** — when `vars.APP_REVIEWER_1_BOT_ID`
  is unset, R3 emits `::notice::` + exits 0 → full review runs (same
  behavior as composition's INERT branch). Numeric-id validation
  enforced (composition's pattern reused).
- **New `SKIP_REASON` env field** alongside `SKIP_REVIEW` distinguishes
  the two skip paths in the final "ai-review skipped" step:
  - `SKIP_REASON=label` — set in the job env block when the
    `skip-ai-review` label is present. The notice references the
    label + posts a one-time PR comment (existing behavior).
  - `SKIP_REASON=r3` — set by the R3 step via `$GITHUB_ENV` when the
    App has already APPROVED at HEAD. The notice references R3 +
    points operators to the gh-api dismissal force-fresh path. **NO
    PR comment** (would spam every label-cycle on an approved PR).
- **Renamed final step** from "ai-review skipped (label)" → "ai-review
  skipped (label OR R3 pre-approved)" so workflow-log readers see the
  dual-purpose role at a glance.
- **`docs/troubleshooting.md` §15** updated: documents the v1.3.0+
  semantics (composition install template no longer listens on
  `pull_request_target`; R3 carries forward on already-approved-at-HEAD
  cycles; new gh-api dismissal force-fresh path replaces the
  pre-R3 "label-cycle-alone forces fresh" pattern). Decision matrix
  table refreshed for v1.3.0+ scenarios.
- **Cost saved (observed):** the 5 case-study operations PRs from
  2026-06-27 (#149, #150, #152, #154, #155) each used the label-cycle
  recovery → ai-review re-fired AFTER the App had APPROVED → ~$0.10-
  0.20 + ~2-3 min per re-fire. R3 eliminates the heavy CLI re-run;
  total session-equivalent savings ≈ ~$0.50-1.00 + ~10-15 min in
  observed wasted work. Scales linearly with PR volume.
- **Bundled with IPLAN-0026 P7** (drop `pull_request_target` from
  composition install templates) in the same `ci/v1.3.0` release —
  both are Phase-2 friction-relief cleanups; consumers do ONE
  pin-bump cycle to get both benefits.
- **Release coordination:** `ci/v1.3.0` will NOT be tagged until
  IPLAN-0026 P7 PR also merges. If P7 stalls, this PR's
  `docs/troubleshooting.md §15` description of composition's
  v1.3.0+ install-template triggers (no `pull_request_target`)
  requires a follow-up fix (the §15 wording is forward-looking
  and accurate only after P7 lands).
- **Plan:** [IPLAN-0027](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0027_r3-ai-review-early-exit.md)
  (READY status with 3 verified-planning review passes + check_plan.py
  gate GREEN; operations PR #161, merged 2026-06-27).
- **Consumer impact:** consumers bump caller pin `@ci/v1.2.0` →
  `@ci/v1.3.0` (operations + framework caller PRs shipping next).
  No caller-workflow shape change required for R3 (the new step lives
  inside the reusable; consumers benefit automatically after pin
  bump).
- **Backward compatibility:** R3 is additive — when the App hasn't
  approved at HEAD (first fire, new HEAD SHA, dismissed prior
  review), the query returns empty → full review runs identically
  to pre-v1.3.0 behavior.

### Changed — ci/v1.2.0 (Phase 1 P2): install templates add `workflow_run` trigger + pin bump (IPLAN-0026 P2; 2026-06-27)

- **`install/templates/workflows/composition-private.yml`** + **`install/templates/workflows/composition-public.yml`** triggers
  extended to add `workflow_run` (fires AFTER consumer's `ai-review`
  caller completes — any conclusion) ALONGSIDE the existing
  `pull_request_target` + `pull_request_review` triggers. Parallel-
  trigger transition for safety per IPLAN-0017 §3.4 + IPLAN-0026 §2.3 D2
  migration discipline.
- **`uses:` pin bumped** from `@ci/v1.0.6` to `@ci/v1.2.0` in both
  templates — `install.sh`-onboarded consumers now get the v1.2.0 body
  (which handles the new `workflow_run` event shape from P1) at install
  time. Existing consumers bump their caller pin via separate Phase-1
  P4/P5 PRs (operations + framework callers).
- **Phase 1 ships MECHANISM only.** During Phase 1 the early-fire stale-
  red still happens (kept `pull_request_target` fires composition before
  the App approves; FAILS legitimately; later re-fires SUCCESS via
  `pull_request_review` or now `workflow_run`; rollup still shows the
  stale FAILURE; label-cycle still needed). **Phase 2 (ci/v1.3.0,
  separate small IPLAN after empirical validation) drops
  `pull_request_target` from these install templates** and delivers the
  actual friction relief.
- **Phase-1 P3 next:** tag `ci/v1.2.0` against the most recent
  composition + install-template commits (P1 + P2 land together under
  the same minor version per IPLAN-0026 §3).

### Changed — ci/v1.2.0 (Phase 1): `composition.yml` body handles `workflow_run` event shape (IPLAN-0026 P1; 2026-06-27)

- **`.github/workflows/composition.yml`** body refactored to source PR
  data from EITHER event shape:
  - `pull_request_review` event → `github.event.pull_request.*` (the
    original shape; current consumer caller trigger)
  - `workflow_run` event → `github.event.workflow_run.pull_requests[0].*`
    (new path; consumer caller installs trigger in §2.3 install-
    templates change shipping next as Phase-1 P2)
  Each env field uses `||` fallback expression: LHS = pull_request_review
  shape; RHS = workflow_run shape. Concurrency group uses the same
  fallback so per-PR serialization works for both event shapes.
- **Job `if:` condition** extended to allow `workflow_run` events
  through unconditionally (workflow_run only fires from the ai-review
  workflow completing — exactly when composition should re-evaluate).
  Non-label events (pull_request_review, etc.) always run; label events
  still only run for `skip-ai-review` (unchanged contract).
- **SKIP_REVIEW resolution** moved from env-block expression (which
  required the `pull_request_review` payload's `labels` field) to a
  `gh-api` lookup in the body (shape-agnostic; works regardless of event
  type; default-empty + retry on transient failure).
- **Fork PR edge case:** `github.event.workflow_run.pull_requests[]`
  is empty when the source workflow ran from a fork; both `||` fallback
  expressions resolve to empty strings → body detects empty `$PR` +
  exits with `::notice::` (forks are HUMAN-REVIEW-ONLY per ai-review's
  trust gate; composition correctly exempts them via the IS_FORK branch
  for non-workflow_run events too — both paths land at the same
  behavior).
- **Reusable contract unchanged** — composition.yml is still
  `workflow_call:` only. Trigger declaration is on the consumer caller
  templates (composition-{private,public}.yml installed via
  `install.sh`); those get the `workflow_run` trigger in the next
  Phase-1 P2 PR.
- **Phase-1 ships MECHANISM only.** The early-fire stale-red friction
  is NOT yet eliminated — Phase 1 keeps `pull_request_target` in
  parallel for safety per IPLAN-0017 §3.4 migration discipline. Phase 2
  (ci/v1.3.0, separate small IPLAN after empirical validation) drops
  `pull_request_target` from install templates and delivers the actual
  friction relief. Set expectations accordingly.
- **Plan:** [IPLAN-0026](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0026_composition-workflow-run-redesign.md)
  (operations PR #156, merged 2026-06-27 commit `44f4b5b`; READY status
  with 3 verified-planning review passes + check_plan.py gate green).
- **Consumer impact:** consumers bump pin `@ci/v1.1.7` → `@ci/v1.2.0`
  to consume this body refactor. The `workflow_run` trigger declaration
  in install templates ships in a separate Phase-1 P2 PR (also targeting
  ci/v1.2.0; both land together).
- **Backward compatibility:** consumers on the current install
  templates (pull_request_target + pull_request_review triggers only)
  continue to work identically — the body's `||` fallback resolves to
  the LHS for those events; new workflow_run handling is dormant until
  the consumer adds the new trigger to their caller.

### Fixed — ci/v1.1.7: `ai-review.yml` auto-merge `bash -e` interaction bug (regression from v1.1.6; 2026-06-27)

- **`.github/workflows/ai-review.yml`** auto-merge App-token branch:
  the `merge_err=$(GH_TOKEN=$APP_TOKEN gh pr merge ... 2>&1)` shell
  pattern triggered immediate `set -e` exit under GitHub Actions'
  default `bash -e {0}` shell whenever the inner `gh pr merge` exited
  non-zero (e.g., auto-merge already enabled; permission denied;
  transient network blip) — bypassing both the `merge_rc=$?` capture
  AND the warning fallback. The whole gate step exited 1, blocking
  the required check on every auto-merge attempt where the App-path
  hit a non-zero exit.
- **Fix:** wrap the App-path merge call in the `if cmd; then ...;
  else ...; fi` form, which bash explicitly exempts from `set -e`
  (per documented behavior). Non-zero exits now flow into the else
  branch + fallback path cleanly:
  ```bash
  if merge_err=$(GH_TOKEN="$APP_TOKEN" gh pr merge "$PR" --auto --merge 2>&1); then
    merge_rc=0
  else
    merge_rc=$?
  fi
  ```
- **Why this wasn't caught pre-ship in v1.1.6:** the v1.1.6 self-
  review focused on logic + permission concerns (reviewer flagged
  `--auto` actor-attribution + stderr capture as MEDIUMs, both
  addressed). The `bash -e` + command-substitution interaction is
  documented bash arcana that the reviewer didn't flag and the
  shipped CHANGELOG only suggested "10-min empirical test on a
  throwaway PR" which wasn't executed. **First real-PR validation
  on operations PR #152 was where the bug surfaced** (gate step
  exited 1 after 3 seconds; no warning emitted; App's APPROVED
  review WAS posted earlier in the same step before the bug bit).
- **Validation:** v1.1.7 fix verified by inspection. Post-deploy
  validation: next auto-merged routine PR after operations + framework
  bump to `@ci/v1.1.7` must pass `call / ai-review` clean (the bug
  manifested as immediate 3-second gate-step failure with zero log
  output; success looks like the gate's full review/comment/merge
  sequence).
- **Consumer impact:** consumers bump pin `@ci/v1.1.6` → `@ci/v1.1.7`.
  v1.1.7 is a strict superset of v1.1.6 (App-token path + fallback);
  no schema or input changes.
- **Lesson recorded:** the auto-merge step deserves an end-to-end
  empirical test (a throwaway PR with the App configured) before
  tagging future v1.1.X releases — code review couldn't catch this;
  the failure shape is runtime-only.

### Fixed — ci/v1.1.6: `ai-review.yml` auto-merge uses reviewer App token (fixes silent docs-sync bypass on auto-merged PRs; 2026-06-27)

- **`.github/workflows/ai-review.yml`** "Gate · comment · label · merge"
  step's auto-merge branch: `gh pr merge "$PR" --auto --merge` now
  authenticated with the reviewer App's installation token (`APP_TOKEN`)
  instead of the default `GITHUB_TOKEN`. Graceful fallback: if
  `APP_TOKEN` is unavailable (App not configured) OR the App lacks
  `contents: write` permission, falls back to `GITHUB_TOKEN` and emits
  a `::warning::` so the missing-permission case is operator-visible.
- **Why:** per GitHub's documented anti-recursion rule, any merge
  commit authored by `GITHUB_TOKEN` does NOT trigger downstream `push:`
  workflows. Operations PRs that pass ai-review's auto-merge path were
  therefore silently bypassing `docs-sync.yml` (and any other consumer
  workflow listening on `push: branches: [main]`). Surfaced 2026-06-27
  during IPLAN-0018 docs-sync verification: operations PRs #149 + #150
  auto-merged by `github-actions[bot]` → zero downstream `push` runs
  fired on either merge commit. Only the previous merge (PR #148, which
  was governance-locked → human-merged) fired docs-sync.
- **Consumer requirement:** the reviewer App needs `contents: write`
  permission for the App-authored merge to succeed. operations +
  framework already have the App installed; verify the permission is
  granted via the App's settings page (`https://github.com/settings/
  apps/aidoc-reviewer` → Permissions → Repository permissions →
  Contents: Read and write). If the permission is missing, the fix
  gracefully falls back to GITHUB_TOKEN (same as today's behavior) +
  emits the `::warning::` — the merge still happens; only push:
  workflows stay suppressed until the permission is added.
- **Backward compatibility:** fully compatible. Consumers without the
  App (App-not-configured path) get the GITHUB_TOKEN fallback —
  identical to pre-v1.1.6 behavior. Consumers with the App + correct
  permissions get the fix automatically on pin bump to `@ci/v1.1.6`.
  No schema or input changes.
- **Consumer impact:** consumers bump caller pin `@ci/v1.1.5` →
  `@ci/v1.1.6` to consume the fix.
- **Validation (post-deploy verification required):** after operations
  + framework pin-bump to `@ci/v1.1.6`, the **first auto-merged routine
  PR** must be verified to:
  1. Have merge commit authored by `aidoc-reviewer[bot]` (not
     `github-actions[bot]`) — confirms the App-token arming carried
     through to merge author per documented GitHub behavior (verified
     empirically on PRs #149+#150 under the OLD code: arming actor →
     merge actor; this fix changes the arming actor to the App).
  2. Have `docs-sync.yml` trigger a `push` workflow run on the merge
     commit sha (verify via `gh run list -R vladm3105/aidoc-flow-
     operations --workflow docs-sync.yml --event push --limit 3`).
  If (1) holds but (2) doesn't, GitHub's anti-recursion behavior differs
  from the documented rule — investigate. If (1) fails (merge commit
  still by `github-actions[bot]`), the App permission may be missing
  (check the `::warning::` in the auto-merge step log) — grant
  `contents: write` per "Consumer requirement" above and retry.
- **Related work:** mechanical-scripts docs-sync (IPLAN-0018) is a
  narrow approach; AI-driven `doc-maintainer.yml` (TODO matrix row 6,
  formerly DEFERRED) is being promoted to an active IPLAN-0025 that
  supersedes IPLAN-0018's mechanical design. This v1.1.6 fix is the
  immediate symptom fix; IPLAN-0025 will be the structural fix.

### Fixed — ci/v1.1.5: replace `ai-review.yml` cross-repo `actions/checkout` with `curl` (eliminates v1.1.x bug class; 2026-06-27)

- **`.github/workflows/ai-review.yml`** "Resolve aidoc-flow-ci pinned ref",
  "Checkout trusted reviewer assets (aidoc-flow-ci@pinned tag)", and
  "Checkout per-consumer config (operations@main; transitional)" steps
  consolidated into a single "Fetch reviewer assets + per-consumer config"
  step using `curl` instead of `actions/checkout@v4`.
- **Why:** the 5-cycle v1.1.0→v1.1.3 saga (sparse-checkout pattern, cone-
  mode, full-clone, `clean: false`) + the v1.1.4 reorder attempt proved
  the `actions/checkout` interaction with workspace state, INIT-time
  content-delete, and runner-class differences was the failure mode
  itself. `curl` has none of those failure modes: writes bytes to a
  path; workspace state, runner class, and `pull_request_target` event
  semantics don't matter. Fetch either works (HTTP 200) or fails loudly
  (`--fail`).
- **What stays the same (intentionally):** trust gate's
  `actions/checkout` of operations@main (separate job; no second
  checkout to interact with; works today). `AI_REVIEW_TOKEN` secret
  (curl uses it for the PRIVATE operations@main fetch). All downstream
  paths (`./reviewer-assets/ai-review/{review-prompt.md,verdict.schema.json}`
  + workspace-root `.github/ai-review/config.json`). Workflow
  `workflow_call:` interface, inputs, runner_labels. Library pattern
  intact (IPLAN-0017 + IPLAN-0022 + IPLAN-0023 all unchanged).
- **Asset retrieval shape:** rubric + schema from
  `https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/<pinned-ref>/ai-review/{review-prompt.md,verdict.schema.json}`
  (PUBLIC; raw works unauth). Per-consumer config from
  `https://raw.githubusercontent.com/vladm3105/aidoc-flow-operations/main/.github/ai-review/config.json`
  (PRIVATE; `Authorization: Bearer ${AI_REVIEW_TOKEN}` then fallback to
  GitHub API contents endpoint with `Accept: application/vnd.github.raw`
  on raw failure). All fetches `--fail --silent --show-error --location
  --retry 3 --retry-delay 2`. `test -s` verifies every fetched file is
  non-empty (defense against silent HTTP-200-empty-body pathology).
- **R1 + R2 bundle-ins both DROPPED from this PR after self-review:**
  - **R1** (narrow trust/ai-review `if:` to fire on `labeled` only for
    `skip-ai-review`) would break the `docs/troubleshooting.md §15`
    label-cycle "force fresh review on stale verdict" path: removing
    the label is the documented way to re-fire ai-review on the
    latest commit after a rebase, and R1's drop of the `unlabeled`
    branch silently disables it. HANDOFF's "halves cost" rationale
    misanalyzed which branch does the work — the `labeled` half runs
    `SKIP_REVIEW=1` (cheap no-op skip step), the `unlabeled` half is
    the one that runs the full review. The real intent ("don't re-
    fire when verdict already APPROVED at HEAD") is what R3 (early-
    exit step, ~20 lines) addresses — tracked for its own small IPLAN.
  - **R2** (bare 1-line `workflow_dispatch:` on composition install
    templates) does not achieve its stated retrigger goal — the
    reusable composition.yml body depends on
    `github.event.pull_request.*` fields that are empty on
    `workflow_dispatch` events. Proper implementation needs
    `workflow_dispatch.inputs.pr_number:` + reusable workflow
    fallback logic. Tracked for its own small IPLAN.
- **Consumer impact:** consumers bump caller pin `@ci/v1.1.3` →
  `@ci/v1.1.5` to consume the fix. Existing `AI_REVIEW_TOKEN` secret +
  workflow inputs unchanged. No behavior change for `skip-ai-review`
  label workflows (R1 dropped).
- **Validation:** P3 (operations pin-bump) validates on self-hosted
  runner (the saga's KNOWN-GOOD class — operations works on v1.1.3
  today, so a regression on operations would be the first signal that
  curl introduced a NEW failure mode). P4 (framework pin-bump) is the
  CRITICAL validation — proves curl-replaces-checkout works on the
  GitHub-hosted runner class, the bug-class home that v1.1.0-v1.1.3
  couldn't escape.
- **Chicken-and-egg:** PRs that bump the pin can't pass ai-review at
  BASE main (still has the v1.1.3 workflow); ship via
  `skip-ai-review` label + admin-merge per `docs/troubleshooting.md §15`.
- **Plan reference:** IPLAN-0024 (operations PR #145; approved + merged 2026-06-26).

### Changed — README.md: refresh to current `ci/v1.1.3` (was stale at `ci/v1.0.6`; 2026-06-26)

- **`README.md`** "Who uses this" table, "What ships" section
  header, install URL, and "known limitations" section header all
  bumped from `@ci/v1.0.6` → `@ci/v1.1.3` matching the current
  consumer state on operations + framework.
- **Why:** README was the public-facing entry point + still cited
  v1.0.6 as current despite v1.1.0/v1.1.1/v1.1.2/v1.1.3 ships
  today (sparse-checkout saga + composition trigger Gap 2 + full-
  clone fix). New Phase C consumers reading the README would get
  the wrong version on install. Historical `v1.0.6` context (the
  pre-v1.1.0 secret-naming limitation note) preserved for
  reference.
- Doc-currency rule per `CLAUDE.md` "Keep docs current": every
  pin-bump session refreshes README references in the same batch.
  This entry closes today's saga.

### Fixed — ci/v1.1.3: second checkout step `clean: false` (silent killer of v1.1.2 full-clone; 2026-06-26)

- **`.github/workflows/ai-review.yml`** "Checkout per-consumer config
  (operations@main; transitional)" step: added `clean: false`.
- **Why:** default `clean: true` runs `git clean -ffdx` at workspace
  root before the second checkout fetches. That recursively wiped
  the prior "Checkout trusted reviewer assets" step's
  `./reviewer-assets/` subdirectory — which contained the rubric
  file needed by the reviewer adapter. Net effect: the rubric got
  fetched (by step 1) then immediately deleted (by step 2's clean)
  → `claude --append-system-prompt-file` failed with 'file not
  found' → ai-review verdict broken.
- **Validation evidence:** operations PR #142 (v1.1.2 validation
  smoke) ai-review log showed `Removing reviewer-assets/` IMMEDIATELY
  before `HEAD is now at e1e7b4e` (the operations@main config.json
  checkout) — the second checkout step removed the first's output.
- **Why this wasn't caught in earlier diagnostic rounds:** v1.1.0 +
  v1.1.1 attempts focused on sparse-checkout pattern theory; the
  `clean: true` interaction is a separate failure mode that became
  the proximate cause once sparse-checkout was correctly removed
  in v1.1.2 (the full-clone DID populate the directory; the second
  step then wiped it).
- **Consumer impact:** consumers bump caller pin `@ci/v1.1.2` →
  `@ci/v1.1.3` to consume the fix.
- **Chicken-and-egg:** SAME as v1.1.1 + v1.1.2 — PRs that bump the
  pin can't pass ai-review (BASE main has buggy v1.1.2 workflow);
  ship via `skip-ai-review` label + admin-merge.
- **Lesson recorded:** any multi-checkout workflow needs explicit
  `clean: false` on all but the first checkout, OR per-checkout
  path isolation, OR the multi-checkout pattern itself replaced
  with a single full clone + manual file copies. Future workflow
  changes adding additional `actions/checkout@vN` steps need
  this constraint codified.

### Fixed — install/templates/workflows/composition-{private,public}.yml: add `opened` trigger (Gap 2 propagation fix; 2026-06-26)

- **`install/templates/workflows/composition-private.yml`** triggers
  extended: `[synchronize, labeled, unlabeled]` →
  `[opened, synchronize, reopened, ready_for_review, labeled, unlabeled]`.
- **`install/templates/workflows/composition-public.yml`** triggers
  extended: `[synchronize, labeled, unlabeled]` →
  `[opened, synchronize, reopened, labeled, unlabeled]`.
- **Why:** the install templates had the same Gap 2 bug fixed in
  operations PR #140 + framework PR #175 — missing `opened` trigger
  meant freshly-opened PRs left composition pending (only ai-review
  fires on `opened`) → merge blocked until label-cycle / push woke
  composition. New consumers onboarded via `install.sh` would
  inherit the bug. This fix propagates the root-cause repair to
  future consumers.
- **Phase C consumers now safe:** iplan-runner, business, iplanic,
  iplan-standard, web-site, engramory can onboard via `install.sh`
  + get the correct triggers by default. Removes the per-consumer
  hand-copy friction noted in the readiness assessment.

### Fixed — ci/v1.1.2: full clone of aidoc-flow-ci reviewer assets (sparse-checkout deemed unfixable after 2 attempts; 2026-06-26)

- **`.github/workflows/ai-review.yml`** "Checkout trusted reviewer
  assets" step: removed sparse-checkout entirely; uses full clone.
  - **Why:** ci/v1.1.1 (cone-mode) STILL failed to populate
    `./reviewer-assets/ai-review/` on GitHub-hosted runner fresh
    clones (verified via framework PR #173 + operations PR #140
    ai-review failures with `Append system prompt file not found`
    error AFTER bumping to @ci/v1.1.1).
  - **Hypothesis:** `actions/checkout@v4` interaction between
    `path: ./reviewer-assets` parameter + sparse-checkout (any mode)
    doesn't populate sub-directory files reliably on fresh clones.
    Could be a `@v4` quirk; could need `@v5`; could be an undocumented
    constraint. Stopped iterating after 2 attempts per minimal-and-
    realistic rule.
  - **Trade-off accepted:** full clone of aidoc-flow-ci is a few
    seconds slower per ai-review fire vs sparse-checkout — acceptable
    cost for reliability. The repo is small (~tens of files); the
    runtime impact is negligible.
- **Validation:** consumers (operations + framework) bump caller pin
  `@ci/v1.1.1` → `@ci/v1.1.2`; next ai-review fire on either consumer
  validates the full-clone path end-to-end.
- **Chicken-and-egg context:** PRs that bump the pin can't pass
  ai-review (BASE main still has the buggy v1.1.1 workflow); they
  ship via the documented `skip-ai-review` label escape hatch +
  admin-merge. Same pattern as operations PR #140 / framework PR #175
  used for v1.1.1.

### Fixed — runner CLASS vs LABEL terminology cleanup + `docs/runners.md` §0 canonical reference (2026-06-26)

- **`docs/runners.md` §0** (NEW): canonical terminology reference —
  runners have two CLASSES (GitHub-hosted vs self-hosted; managed by
  GitHub vs operator) and many possible LABELS (`ubuntu-latest`,
  custom self-hosted pools); cites
  [GitHub Actions docs](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners).
  Includes a "common mistakes to AVOID" table + worked example.
- **`.github/workflows/ai-review.yml`** `runner_labels_review` input
  description: "(ubuntu-latest does NOT qualify)" → "(GitHub-hosted
  runners like ubuntu-latest do NOT qualify out-of-the-box — CLI is
  installed at workflow start per ci/v1.0.2+)" — gives reader the
  class context + the relevant ci/v1.0.2+ behavior in one place.
- **`docs/troubleshooting.md` §10**: "ubuntu-latest doesn't have the
  reviewer CLI" → "GitHub-hosted runners (including `ubuntu-latest`)
  don't have the reviewer CLI pre-installed" — class-first framing.
- **`install/templates/workflows/markdown-lint.yml`** header comment:
  "on ubuntu-latest" → "on GitHub-hosted runners (e.g. `ubuntu-latest`)".
- **Why this matters:** confusing class with label leads to bugs like
  the IPLAN-0022 sparse-checkout pattern (fixed in PR #29 / ci/v1.1.1)
  — the bug was masked on self-hosted because of cached state; only
  exposed on GitHub-hosted fresh clones. If we'd thought
  "ubuntu-latest is just a runner" we'd have assumed it behaves like
  the other runners; the class distinction makes the cached-state-vs-
  fresh-clone difference predictable.
- All historical/already-shipped CHANGELOG entries with "ubuntu-latest"
  framing are left as-is (ship-date-fixed); only NEW docs going forward
  use class-first framing per §0.
### Fixed — ci/v1.1.1: sparse-checkout pattern fix (IPLAN-0022 PR-A bug; 2026-06-26)

- **`.github/workflows/ai-review.yml`** "Checkout trusted reviewer
  assets" step: removed `sparse-checkout-cone-mode: false` so the
  step uses default cone-mode. The non-cone-mode pattern `ai-review`
  matched the literal filename (not the directory contents) →
  on fresh clones (GitHub-hosted runners, e.g. `ubuntu-latest`),
  the `ai-review/` directory wasn't populated →
  `review-prompt.md` not found → `claude --append-system-prompt-file`
  failed → ai-review verdict broken on every PUBLIC consumer using
  GitHub-hosted runners.
- **How operations passed despite the bug:** operations runs on a
  self-hosted runner with cached state from prior `actions/checkout`
  invocations that populated the full repo; sparse-checkout pattern
  issue was masked. GitHub-hosted runners do fresh clone per job →
  bug exposed on framework's PR.
- **Validation:** framework [PR #173](https://github.com/vladm3105/aidoc-flow-framework/pull/173)
  ai-review failed with:
  `Error: Append system prompt file not found: .../reviewer-assets/ai-review/review-prompt.md`
- After ci/v1.1.1 tag ships: consumers can bump caller pin
  `@ci/v1.1.0` → `@ci/v1.1.1` to consume the fix. Framework PR #173
  will re-fire ai-review with the new path-population behavior.
- This is the **first real-world cross-runner-class validation** of
  IPLAN-0022 PR-A — self-hosted (operations) masked a bug that
  GitHub-hosted (framework) exposed. Per GitHub Actions terminology:
  runners have two CLASSES (GitHub-hosted vs self-hosted); labels
  (`ubuntu-latest`, custom self-hosted labels) identify specific
  runner images within each class. Lesson: any new sparse-checkout
  pattern should be tested on BOTH classes before declaring success.

### Added — `docs/troubleshooting.md` §15: label-cycle retrigger pattern (2026-06-26)

- **`docs/troubleshooting.md`** new §15 "Stuck check — label-cycle
  retrigger": canonical guidance on the label-cycle pattern (add +
  remove `skip-ai-review` label to inject synthetic
  `pull_request_target` labeled/unlabeled events that re-fire
  workflows on the current commit state).
- Includes the `skip-ai-review` label mechanism explanation,
  when-to-use table, cost/risk warning (each cycle fires every
  workflow with labeled/unlabeled triggers), and the "rebase-only
  commit → add label PERMANENTLY (no remove)" pattern.
- TOC row added.
- Surfaced during IPLAN-0022 PR-B/PR-C rollout 2026-06-25/26:
  cycles became compounding-slow on the 2-runner self-hosted pool;
  documenting the pattern + its proper use prevents future reflexive
  cycling.

### Fixed — IPLAN-0022 §3.7 → §4 cross-ref correction (2026-06-26)

- **`CHANGELOG.md` line 28** (IPLAN-0022 PR-A entry): cited
  "IPLAN-0022 §3.7 P1" but the rollout phases moved to §4 when
  IPLAN-0022 Pass 2 collapsed 7→3 phases. Corrected to "§4 P1".
- Same bug exists in framework `CHANGELOG.md:18` — fixed in
  separate framework PR (different repo; can't bundle).
- Originally surfaced by operations PR #138's second ai-review
  re-fire (caught what the first fire missed; reviewer is
  non-deterministic between runs on the same commit).

### Added — IPLAN-0022 PR-A: reviewer assets moved to aidoc-flow-ci (ci/v1.1.0 target; 2026-06-25)

- **`ai-review/review-prompt.md`** (NEW; moved from
  `aidoc-flow-operations/.github/ai-review/`; 97 lines; opening
  paragraph generalized — "the calling consumer repo" instead of
  hardcoded `aidoc-flow-operations`).
- **`ai-review/verdict.schema.json`** (NEW; moved byte-identical
  from operations).
- **`ai-review/README.md`** (NEW; directory pointer + "how it's
  consumed" + per-consumer-override-future framing).
- **`.github/workflows/ai-review.yml`** "Checkout reviewer assets"
  step replaced: was `actions/checkout` of `aidoc-flow-operations@main`;
  now sparse-checkout of `aidoc-flow-ci@${{ github.workflow_ref }}`
  `ai-review/` directory only. Downstream `RUBRIC=` + `SCHEMA=` lines
  updated to `./reviewer-assets/ai-review/*` paths.
- **`docs/ai-review-assets.md`** (NEW; consumer-facing spec — what
  lives in `ai-review/`, how the workflow consumes it, per-consumer
  override future framing, schema-change discipline, why-not-in-`.github/`
  rationale matching IPLAN-0018 `scripts/docs-sync/` precedent).
- **Per IPLAN-0022 §4 P1:** ships as `ci/v1.1.0` after merge.
  Phase 2 (consumer pin-bumps on operations + framework) ships as
  separate per-consumer PRs after this lands. Phase 3 (legacy
  delete on operations) ships after 1 week of clean reviews on the
  new path.
- **Trust allowlist still on operations:** only the rubric + schema
  moved; the trust allowlist (`.github/ai-review/config.json`
  `trust.ai_review`) remains on `aidoc-flow-operations` per separate
  governance home (operations governance ≠ CI infrastructure).
- **Rule 1 EXCEPTION (6 surfaces):** atomic asset-move — splitting
  creates broken intermediate states where workflow checkout-source
  and asset-destination are inconsistent. Founder pre-approved per
  IPLAN-0022 §4 + chat direction 2026-06-25 "Start with #1 (IPLAN-0022
  PR-A implementation)".

### Added — `docs/local-pre-push.md`: canonical pre-push self-check pattern for consumers (2026-06-25)

- **`docs/local-pre-push.md`** (NEW; ~140 lines) — canonical pattern
  for consumer repos to ship a `scripts/pre_push_check.sh` that runs
  mechanical linters + a local AI self-review via `claude` CLI on
  the diff. Local pass is a MIRROR of CI's `ai-review.yml` gate
  (same rubric); catches issues earlier; CI remains authoritative.
- **Reference implementation:** operations PR #137 ships the
  pattern; this doc canonicalizes it for adoption by other
  consumers (framework + Phase C: iplan-runner, business, iplanic,
  iplan-standard, web-site, engramory) and future company projects.
- **Hardening principles documented:** 5-min `timeout` wrapper on
  claude call; verdict regex anchored to first-line `^VERDICT:`;
  model-drift fallback; diff truncation; `SKIP_LOCAL_AI_REVIEW=1`
  escape hatch; future hardening notes for diff fence-collision.
- **Adoption prerequisites enumerated:** claude CLI install +
  auth; `.github/ai-review/review-prompt.md` (IPLAN-0022 will move
  this to `aidoc-flow-ci/ai-review/`); pre-commit hook wiring.
- **`docs/multi-project-guide.md`** §8 added — references the new
  doc + summarizes the pattern as part of the canonical onboarding.
- **`docs/README.md`** — index updated.
- **Future enhancement noted:** ship `install/templates/scripts/
  pre_push_check.sh` so `install.sh` drops it automatically on new
  consumers; not blocking; tracked in §8 of the new doc.

### Fixed — `ci/v1.1.0-alpha.2`: docs-sync count step fails when no proposals (alpha.1 bug surfaced by operations Phase A first natural fire 2026-06-25)

- **`.github/workflows/docs-sync.yml`** "Count proposed changes" step:
  alpha.1 ran `find .docs-sync-proposed -maxdepth 1 ...` without first
  ensuring the directory exists. When ALL 3 operation scripts produced
  no proposals (the common case — operations' first natural fire on
  PR #134 merge had no triggers matching), `.docs-sync-proposed/`
  didn't exist, `find` exited 1, and `set -euo pipefail` killed the
  job. Net effect: every "no-changes" dry-run was reported as failure
  instead of clean "proposed=0".
- **Fix:** `mkdir -p .docs-sync-proposed` before the count step,
  guaranteeing the directory exists. `find` then returns 0 with an
  empty result; count = 0; workflow exits clean.
- **`install/templates/workflows/docs-sync.yml`** caller template pin
  bumped from `@ci/v1.1.0-alpha.1` → `@ci/v1.1.0-alpha.2`.
- **Validation:** confirmed via [actions/runs/28193174223](https://github.com/vladm3105/aidoc-flow-operations/actions/runs/28193174223)
  — operations docs-sync run from PR #134 merge: trigger ✓ auth ✓
  setup ✓ 3 op scripts ✓ "no proposals" detection ✓ → count step ✗
  (the bug this fix closes).
- This is the **first real-world validation of the alpha.1 skeleton**
  on a live consumer — exactly what Phase A dry-run pilots are for.
  Operations bumps its caller pin to `@ci/v1.1.0-alpha.2` in a
  follow-up PR; next natural fire will validate the fix.

### Added

- **`docs/multi-project-guide.md`** — explicit documentation of the
  three-layer architecture: `aidoc-flow-ci` as company-wide CI
  library; per-project governance repo (one per company project);
  per-consumer config + optional overrides. Onboarding flow for
  new company projects (create project's governance repo →
  bootstrap each consumer via `install.sh` → per-project overrides
  as needed). Per-project decision boundaries enumerated (what
  stays per-project vs what library owns). Documents the
  long-implicit "all future company projects" framing from
  [IPLAN-0017-CHARTER §1](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017-CHARTER_aidoc-flow-ci.md#1-purpose).
- **`docs/architecture.md` §0** — new "two-repo architecture
  (library vs project-governance)" section at the top of the doc.
  Concrete artifact-placement matrix for library / project-governance
  / consumer layers. Cross-references the new
  [`multi-project-guide.md`](docs/multi-project-guide.md).
- **`README.md`** "Who uses this" section — names current
  consumers (aidoc-flow-operations, aidoc-flow-framework on
  `@ci/v1.0.6`) + invites future company projects to use the
  onboarding flow in `docs/multi-project-guide.md`.
- **`docs/README.md`** — index updated to list the new
  `multi-project-guide.md`.

### Added

- **`.github/workflows/docs-sync.yml`** — new reusable workflow
  (alpha; first half of IPLAN-0018 implementation). Mechanical
  post-merge documentation fixer. Triggered by consumer caller on
  `push: branches: [main]`. Three operations (each disable-able
  via `.github/docs-sync.json`): CHANGELOG stub-entry on workflow
  changes; version-string propagation (alpha.1 stub — detection
  only; full regex-map in alpha.2); cross-ref dead-link repair
  (alpha.2). Belt-and-suspenders recursion guards (`[skip ci]` +
  `if: github.actor != 'aidoc-flow-bot[bot]'`). Dry-run mode by
  default (posts PR comment with proposed changes; no commits).
  Live-mode commit logic requires `AIDOC_FLOW_BOT_ID` +
  `AIDOC_FLOW_BOT_KEY` secrets + 🔴 founder-created `aidoc-flow-bot`
  App per IPLAN-0018 §3.4 (separate from `aidoc-reviewer` for
  separation of concerns). Concurrency-group serialized.
  SHA-pinned actions: `actions/checkout@v4.2.2`
  (`11bd71901bbe5b1630ceea73d27597364c9af683`) +
  `actions/setup-python@v6.2.0`
  (`a309ff8b426b58ec0e2a45f0f869d46889d02405`).
- **`install/templates/workflows/docs-sync.yml`** — caller template
  pinned at `@ci/v1.1.0-alpha.1`. Single template (works for both
  PRIVATE + PUBLIC). Documents prerequisites (founder creates App
  + sets secrets) + the rollout phases per IPLAN-0018 §3.7
  (operations pilot dry-run for 1 week → live → framework opts in
  → Phase C consumers).
- **`install/templates/docs-sync.json`** — per-consumer config
  template. Ships with `dry_run: true` by default (mandatory for
  first 1-2 weeks per §3.7 P3). Three operation kill-switches
  (`changelog_stub.enabled`, `version_sync.enabled`,
  `cross_ref_repair.enabled`). Allowlisted commit-target paths
  (`CHANGELOG.md`, `README.md`, `docs/**`, `*.md`) per the §3.5
  threat model commit-content allowlist.

### Targeting `ci/v1.1.0-alpha.1`

This release ships the IPLAN-0018 SKELETON — workflow body + caller
template + config template. Operations adopts in dry-run mode for
~1 week per the §3.7 P3 graduation criteria; live-mode commit
logic + full operation implementations land in `ci/v1.1.0-alpha.2`
after operations pilot validates the skeleton. Stable `ci/v1.1.0`
ships after operations pilot graduates to live mode (≥5 merges
with zero proposed-vs-applied file-set divergence).



## ci/v1.0.6 — 2026-06-24 — caller-template backport + docs hardening (post-framework-Phase-A)

Patch release **completing the framework Phase A activation
loop**. Backports the local-only template fixes that framework had
to apply during PR #168 + documents the two undocumented consumer-
side prerequisites discovered during activation.

### Template fixes (backport from framework PR #168 commit `caed708`)

All 4 caller templates (`ai-review-{public,private}.yml` +
`composition-{public,private}.yml`) updated:

1. **yamllint colons** — removed alignment double-space after
   `runner_labels_review:`; default yamllint rules flag as
   `[colons] too many spaces after colon`.
2. **detect-secrets pragma** — appended `# pragma: allowlist secret`
   to all `secrets: inherit` lines (Yelp/detect-secrets flags the
   word "secrets" as high-entropy).

These were applied locally on framework's bootstrap to pass its
pre-commit hooks. Backporting means future consumers don't need
the same manual intervention. PR #20 originally drafted these fixes
(closed per founder direction during the `ci/v1.0.4` misplaced-tag
incident); re-shipped properly now that v1.0.5 is stable.

### Caller-pin bumps (all 10 templates)

All `install/templates/workflows/*.yml` pins bumped from `@ci/v1.0.2`
→ `@ci/v1.0.6`. Reusable workflow bodies functionally identical to
v1.0.5; v1.0.6 is templates + docs only.

### `install.sh` default `CI_TAG`

Bumped `ci/v1.0.2` → `ci/v1.0.6`.

### Docs hardening — 2 new troubleshooting sections

[`docs/troubleshooting.md`](docs/troubleshooting.md) gains
**§13 + §14**, both surfaced by framework Phase A activation:

- **§13 — `startup_failure` from Actions allowlist.** Consumer
  in `selected actions` mode must add `vladm3105/aidoc-flow-ci/*`
  to `patterns_allowed` (or the reusable workflow is silently
  blocked at workflow-load). Includes diagnose + fix commands.
- **§14 — `startup_failure` from caller's `workflow_permissions:
  read`.** Reusable workflow's `contents: write` declaration can't
  elevate above the caller's grant; consumer must add an explicit
  `permissions:` block to the caller workflow. Both targeted
  (caller-level) + alternative (bump repo default) fixes shown.

Both sections reference the framework Phase A surface event with
the operations PR #122 runbook for full activation context.

### `README.md` + `install/README.md` known-limitations refresh

The `v1.0.2 known limitations` section dropped the "unverified-in-
CI" caveat (verified end-to-end on framework Phase A) + added the
two new per-consumer prerequisites (Actions allowlist + caller
permissions) with pointers to the §13-14 troubleshooting sections.
`README.md` "What ships" table updated to 8 workflows (pre-commit
was added in v1.0.2 but not surfaced in the README until now).

### Backward compatibility

- Consumers on `ci/v1.0.0..ci/v1.0.5` continue to work; this patch
  only changes templates + docs. The reusable workflows themselves
  are unchanged from v1.0.5.
- Already-bootstrapped consumers can re-run `install.sh` from
  `ci/v1.0.6` to pick up the template fixes + pin bump.

### Rule 1 EXCEPTION audit-trail

This PR touches **4 surface families** (caller templates +
install.sh + docs + README/CHANGELOG = 6 distinct files), over
the ≤3 limit. Atomic release-prep pattern (same precedent as
W4.1 + W4.4 + v1.0.5): splitting creates incomplete intermediate
states where some refs say "ci/v1.0.6" + others still say
"ci/v1.0.2". Founder pre-approved this session: "Option 2 now"
+ "Ship all of the above as v1.0.6".

## ci/v1.0.5 — 2026-06-24 — fix: export reviewer auth env to "Run review" step

Patch release fixing a real reviewer-auth bug in `ai-review.yml`'s
"Run review" step, surfaced by **framework Phase A migration's first
real ai-review run** (2026-06-24 PR #169 on
`vladm3105/aidoc-flow-framework`).

### Bug

The "Run review (selected vendor) → verdict file" step only declared
`MODEL_IN` + `BUDGET_IN` in its `env:` block. The auth env vars the
CLIs need (`CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_API_KEY`,
`OPENAI_API_KEY`) were NOT exported, so the CLIs ran without
credentials:

```text
Not logged in · Please run /login   ← claude CLI without CLAUDE_CODE_OAUTH_TOKEN
##[error]no parseable verdict — fail-closed
claude rc=1
```

`secrets: inherit` on the caller passes secret values into the
reusable workflow's `secrets` context, but they don't auto-export to
the step's process env — each step that uses a secret as env var
must explicitly declare it in `env:`.

### Fix

Added 3 env exports. Whichever auth secret the consumer set takes
effect; the others resolve to empty and are ignored by the
unselected CLI.

### Why operations dodged this

Operations runs the same workflow body as STANDALONE (not reusable),
so its `env:` block resolves `${{ secrets.X }}` against operations'
repo secrets directly — no inheritance hop. When the body was lifted
into a reusable workflow for v1.0.0, the env exports were omitted —
the inheritance hop made the bug invisible until the first real
consumer test (framework, 2026-06-24).

### Backward compatibility

Pure addition; no input/output changes. Consumers bump pin
`@ci/v1.0.X` → `@ci/v1.0.5`.

### Note on v1.0.4

`ci/v1.0.4` exists as a misplaced annotated tag (created in error
during PR #20 close; points at `ci/v1.0.3`'s commit). Skipping to
v1.0.5 avoids the broken tag.

## ci/v1.0.3 — 2026-06-24 — labels.json patch (`area: governance` description ≤100c)

Patch release fixing a content bug in

## ci/v1.0.3 — 2026-06-24 — labels.json patch (`area: governance` description ≤100c)

Patch release fixing a content bug in
`install/templates/labels.json`. The `area: governance` description
was 109 chars; GitHub's labels API caps descriptions at 100 chars
and returns `HTTP 422 Validation Failed: description is too long`
on creation. Surfaced by framework Phase A migration's first
`install.sh` run (2026-06-24): 8/9 canonical labels created
successfully on `vladm3105/aidoc-flow-framework`; the 9th
(`area: governance`) failed; per the v1.0.2 install.sh "fail-loud
on real failures" contract (OPS-#116 fix), the script exited
nonzero as designed.

### Fix

Trimmed `area: governance` description from 109 → 98 chars
(removed redundant trailing words; meaning preserved):

```text
before: "PR touches governance docs (CLAUDE.md, DECISIONS.md, IPLAN-*.md, governance/) or supersedes a locked decision"
after:  "PR touches governance docs (CLAUDE.md, DECISIONS.md, IPLAN-*.md, governance/) or a decision"
```

### Backward compatibility

- Consumers on `ci/v1.0.0` / `ci/v1.0.1` / `ci/v1.0.2` continue to
  work; this patch only fixes the install.sh label-bootstrap step
  for fresh adoptions.
- Consumers that already bootstrapped via earlier versions are
  unaffected (their `area: governance` label was never created
  because of the bug; they can re-run `install.sh` from `ci/v1.0.3`
  to pick it up, OR manually `gh label create` it with the fixed
  description).

### Lesson recorded

Added pre-commit-suitable validation pattern: any new label entry
in `labels.json` should fail-fast if `len(description) > 100`.
The validation is not enforced in v1.0.3 itself (would have caught
this; the labels.json was hand-edited without a check); v1.0.4+
may add a pre-commit hook + CI check.

## ci/v1.0.2 — 2026-06-24 — public-CLI unblock + pre-commit reusable

Patch release closing the v1.0.0/v1.0.1 public-CLI gap + adding a
reusable pre-commit workflow.

### Highlights

- **PUBLIC consumers unblocked** — `ai-review.yml` now installs
  codex + claude CLI at workflow start on `ubuntu-latest` (gated;
  no-op on self-hosted runners with pre-baked CLI). Public ai-review
  caller template REPLACE-ME placeholder removed; pinned to
  `@ci/v1.0.2`.
- **8th reusable workflow** — `pre-commit.yml` wraps the standard
  `pre-commit run --all-files` pattern used by framework +
  iplan-runner + operations.
- **All caller templates pinned to `@ci/v1.0.2`** — backward
  compatible (v1.0.0 + v1.0.1 callers continue to work).
- **`install.sh` default `CI_TAG` bumped to `ci/v1.0.2`**.
- **Honest framing on CLI install:** assembled from official upstream
  docs but unverified-in-CI as of v1.0.2 ship; first PUBLIC consumer
  adoption (likely framework Phase A migration) will validate;
  v1.0.3 may revise.

### Known limitations carried forward to v1.0.3

- **Public-consumer CLI install unverified-in-CI.** See
  `docs/troubleshooting.md` §10 for current state + how to report
  issues if the install step fails on your consumer repo.
- **Secret names hardcoded** to `APP_REVIEWER_1_ID` /
  `APP_REVIEWER_1_KEY` — v1.0.2 still doesn't parameterize.
- **Composition trigger shape** still the PR-#111 conservative
  pre-Phase-B shape; `workflow_run` redesign deferred per IPLAN-0017
  §3.4.

### Added

- **ubuntu-latest CLI install step in `ai-review.yml`** —
  PUBLIC consumers can now use `runner_labels_review: '"ubuntu-latest"'`
  and the workflow installs `codex` + `claude` CLI just-in-time
  before invoking them. **Closes the v1.0.0/v1.0.1 public-CLI gap.**
  Install step gated on `contains(inputs.runner_labels_review,
  'ubuntu-latest')` — no-op on self-hosted runners that have the CLI
  pre-baked (e.g., operations' `aidoc-flow-runner:latest` manually
  extended).
  - `codex` via `npm install -g @openai/codex@0.142.0` (pinned)
  - `claude` via `curl -fsSL https://claude.ai/install.sh | bash -s 2.1.89`
    + `echo "$HOME/.local/bin" >> "$GITHUB_PATH"` (native installer
    drops binary at `~/.local/bin`; not on default PATH)
  - `actions/setup-node@v5.0.0` (SHA-pinned
    `a0853c24544627f65ddf259abe73b1d18a591444` — verified via `gh api`)
    runs first since codex install uses npm
  - Required secrets on consumer side: `OPENAI_API_KEY` (codex) and/or
    `ANTHROPIC_API_KEY` (claude); `secrets: inherit` passes them
  - **Honest framing: unverified-in-CI as of v1.0.2 ship.** Install
    commands assembled from official docs ([openai/codex
    README](https://github.com/openai/codex) +
    [code.claude.com/docs/en/setup](https://code.claude.com/docs/en/setup))
    but not tested on a real consumer's CI run; first PUBLIC consumer
    adoption (likely framework's Phase A migration per
    `aidoc-flow-operations` IPLAN-0017 §4) will validate. Report
    issues at `vladm3105/aidoc-flow-ci`; v1.0.3 may revise based on
    real-world consumer feedback.
- **`install/templates/workflows/ai-review-public.yml`** updated:
  `runner_labels_review: '"REPLACE-ME-with-runner-having-reviewer-CLI"'`
  → `runner_labels_review: '"ubuntu-latest"'`. Pin bumped to
  `@ci/v1.0.2`. Header comment rewritten to document the new install
  step + the required secrets + the unverified-in-CI caveat.
- **Reusable `pre-commit.yml` workflow** (`.github/workflows/pre-commit.yml`)
  + caller template (`install/templates/workflows/pre-commit.yml`).
  Eighth reusable workflow shipped. Wraps the standard
  `pre-commit run --all-files` pattern used by framework +
  iplan-runner + operations (all three repos had nearly identical
  pre-commit workflow files; abstracted into one reusable). Inputs:
  `python-version` (default `"3.12"`), `extra-deps` (default empty;
  pip-install args for project-specific hook deps like
  `-r tests/conformance/requirements.txt`), `run-stage` (default
  empty; set `"manual"` for opt-in audits like pip-audit),
  `runner_labels` (default `"ubuntu-latest"`; PRIVATE consumers
  override to `"runner-self"`). Standard actions SHA-pinned per
  `feedback_verify_sha_pins` memory — both verified via `gh api`:
  `actions/checkout@v4.2.2` (`11bd71901bbe5b1630ceea73d27597364c9af683`)
  + `actions/setup-python@v6.2.0` (`a309ff8b426b58ec0e2a45f0f869d46889d02405`).

## ci/v1.0.1 — 2026-06-24 — origin-based labels + 5 new reusable workflows + docs tree

Minor release bundling the 5 new reusable workflows + 5 new docs +
the per-origin runner-label convention rename. **Backward
compatible** — v1.0.0 callers continue to work; the rename is in
the consumer caller templates only, not in the reusable workflow
inputs.

### Highlights

- **5 new reusable workflows** (`labeler` / `codeql` /
  `markdown-lint` / `links` / `secret-scan`) — see per-workflow
  entries below
- **Per-origin runner-label convention** — verbose v1.0.0 arrays
  (`'["self-hosted", "aidoc", "ci-ephemeral"]'`) replaced with
  clean `'"runner-self"'` in the per-visibility caller templates
- **5 new consumer-facing docs** under `docs/` (architecture +
  runners + overrides + security + troubleshooting) + docs index
  + LABELS.md area-namespace addition
- **All consumer caller templates pinned to `@ci/v1.0.1`**
  (existing v1.0.0 callers continue to work; consumers can
  optionally re-run `install.sh` to pick up the v1.0.1 templates)
- **`install.sh` default `CI_TAG` bumped to `ci/v1.0.1`**
- All SHA-pinned actions verified via
  `gh api repos/<owner>/<repo>/git/refs/tags/<tag>` per the
  `feedback_verify_sha_pins` lesson from the v1.0.1 prep

### Known limitations carried forward to v1.0.2

- **Public consumers using `ubuntu-latest` for `runner_labels_review`**
  still don't have a working reviewer-CLI install step. The
  `install/templates/workflows/ai-review-public.yml` keeps the
  `REPLACE-ME-with-runner-having-reviewer-CLI` placeholder
  pending v1.0.2. The original v1.0.1 plan was to add the
  install step in this release but it was deferred to keep
  v1.0.1 atomic + low-risk; v1.0.2 will ship verified install
  commands for `codex` / `claude` CLIs on ubuntu-latest.
- **Secret names hardcoded** to `APP_REVIEWER_1_ID` /
  `APP_REVIEWER_1_KEY` — v1.0.1 still doesn't parameterize.
  v1.0.2+ may add `app_id_secret_name` / `app_key_secret_name`
  inputs IF consumers actually need non-default names.
- **Composition trigger shape** is still the PR-#111
  conservative pre-Phase-B shape. The full `workflow_run`
  redesign per IPLAN-0017 §3.4 is the Phase-B target (requires
  rewriting the composition body to handle
  `github.event.workflow_run.pull_requests[0]`).

### Added

- **`docs/troubleshooting.md`** — 12-section troubleshooting guide
  drawn from operations PRs #100-118 + aidoc-flow-ci v1.0.0
  bootstrap + Wave-2 SHA-fix incident. Covers: composition
  pre-ai-review race; skip-ai-review carry-forward; runner not
  found (label mismatch / invalid chars / org-vs-repo); fabricated
  SHA pin (with `gh api` verify recipe); `gh: not found` (operations
  PR #101 root-cause); label install loop swallowing errors (PR
  #116); Azure SWA staging quota (memory `reference_azure_swa_staging_env_quota`);
  labeler "label does not exist" (consumer not bootstrapped); lychee
  flakes on bot-hostile hosts; v1.0.0 public-CLI gap; MD024
  duplicate-heading siblings_only fix; CHANGELOG rebase-conflict
  python recipe for stacked PRs. Per-section: symptom + cause +
  fix with concrete commands.
- **`docs/security.md`** — threat model + trust boundaries +
  fork-PR handling + secrets model + `pull_request_target`
  rationale + SHA-pinning + layered secret-scan defense. Honestly
  frames the self-hosted-on-public concern (the routing rule
  follows GitHub's recommendation: PRIVATE → `runner-self`,
  PUBLIC → `ubuntu-latest`; deviation is accepted-risk only).
  Covers the trust-gate semantics + how fork PRs route to
  HUMAN-REVIEW-ONLY, the App-identity model behind `composition`,
  the `v1.0.0` secret-name limitation, and the
  `gacts/gitleaks` vs `gitleaks/gitleaks-action` license choice.
  Documents the SHA-pinning verification workflow per
  `feedback_verify_sha_pins` memory entry.
- **`docs/overrides.md`** — consumer-facing guide to the 3 override
  modes: (1) parameter override via `with:` (preferred — smallest
  deviation); (2) full replacement (drop `uses:`, write own jobs);
  (3) add a custom workflow (additive; no override at all). Includes
  concrete examples per mode (PRIVATE consumer overriding runner
  labels; custom reviewer replacement; per-repo conformance check),
  a what-you-cannot-do list (no step insertion inside reusable
  workflows; no `@main` pinning; no colons in runner labels), and
  the conflict-resolution menu when canonical updates clash with
  local overrides (re-align / keep divergence / upstream the change).
- **`docs/runners.md`** — runner-pool operational guide. Covers
  the runner-label convention recap (with `runner-self` /
  `ubuntu-latest` / future origins), the reference
  `aidoc-flow-runner:latest` Docker image (with operations' build
  scripts as reference), org-level vs repo-level runner registration
  with `runner-self` as additive label, per-origin operational
  tradeoffs (cost / latency / CLI availability / fork-PR safety),
  pool scaling, and the process for adding a new runner origin
  (e.g., `runner-azure`). `docs/README.md` index updated.
- **`docs/architecture.md`** — first focused design doc on
  `aidoc-flow-ci`. Covers: reusable-workflow model (consumer caller
  via `uses:`; runs in consumer's repo context); inventory of the 7
  shared workflows + what each does + typical triggers; trust + verdict
  flow connecting `ai-review` + `composition` (with Mermaid diagram);
  per-repo policy surfaces (the 6 config files consumers carry);
  inputs that vary per consumer (primarily `runner_labels`);
  versioning + tag scheme; local-overrides-shared rule pointer to
  `overrides.md`; drift detection (warning-only) pointer; and a
  pointer to operations governance for the deeper WHY (IPLAN-0017
  + charter + DECISIONS). `docs/README.md` updated to list it.

- **Reusable `secret-scan.yml` workflow** (`.github/workflows/secret-scan.yml`),
  caller template (`install/templates/workflows/secret-scan.yml`),
  and starter `.gitleaks.toml` allowlist
  (`install/templates/.gitleaks.toml`). Wraps **`gacts/gitleaks@v1.3.2`**
  (SHA-pinned `c9a0338361dc45a01aa7ebaaa5330179f3c62873`) — the
  **MIT-licensed** community wrapper. **Critical: NOT the official
  `gitleaks/gitleaks-action`** which switched to a proprietary EULA
  at v2.0.0 (May 2026); org-owned repos (including OSS) require a
  paid license. The CMS OSPO guide
  (`https://dsacms.github.io/ospo-guide/resources/gitleaks-action-license/`)
  explicitly points to `gacts/gitleaks` as the MIT wrapper for this
  use case. Same `gitleaks` binary underneath; no license key, no
  signup. Full-history scan (`fetch-depth: 0`) since `gitleaks
  detect` is the right shape for a PR gate. SARIF output uploaded
  to GitHub Code Scanning via `github/codeql-action/upload-sarif@v4.36.1`
  so findings appear in the PR's "Files changed" view via
  annotations. Inputs: `config-path` (optional `.gitleaks.toml`),
  `fail-on-findings` (default true — a PR gate that doesn't block
  isn't a gate), `runner_labels` (default `"ubuntu-latest"`).
  Starter `.gitleaks.toml` ships an allowlist for common test
  fixtures + docs examples + extends the default ruleset.
- **Reusable `links.yml` workflow** (`.github/workflows/links.yml`),
  caller template (`install/templates/workflows/links.yml`), and
  starter `.lychee.toml` config (`install/templates/.lychee.toml`).
  Wraps `lycheeverse/lychee-action@v2.6.1` (SHA-pinned
  `885c65f3dc543b57c898c8099f4e08c8afd178a2`) — the 2025-2026
  de-facto leader for link checking (Rust-based, async, fast).
  Chosen over the older `gaurav-nelson/github-action-markdown-link-check`
  (Node-based, slower, no built-in caching). Implements the mature
  **internal vs external split** pattern: internal mode is
  PR-blocking + uses `--offline` to skip http(s) URLs; external
  mode runs on cron + is non-blocking (rate-limited services flake;
  never gate PRs on them). Both share a `.lycheecache` cache via
  `actions/cache/restore` + `actions/cache/save@v4.2.0` with
  `if:always()` so cache persists even on failure. Starter
  `.lychee.toml` ships sensible defaults: 200/206/429 accept,
  fragment-checking, 14-concurrency, 1d cache age, excludes for
  loopback/private + bot-hostile hosts (twitter/x, linkedin) that
  403 on automated UA. Inputs: `mode` (internal|external), `paths`
  (default `.`), `config-file` (default `.lychee.toml`),
  `fail-on-error` (default true), `runner_labels` (default
  `"ubuntu-latest"`).
- **Reusable `markdown-lint.yml` workflow**
  (`.github/workflows/markdown-lint.yml`), caller template
  (`install/templates/workflows/markdown-lint.yml`), and starter
  `.markdownlint.json` config (`install/templates/.markdownlint.json`).
  Wraps `DavidAnson/markdownlint-cli2-action@v23.2.0` (SHA-pinned
  `fa0cd0f1a052f54da593c83860f2292982f5d142`) — the first-party
  successor to the legacy `markdownlint-cli`, recommended in
  2025-2026 over the older third-party wrappers
  (`nosborn/github-action-markdown-cli`,
  `igorshubovych/markdownlint-cli`). Uses cli2's built-in `github`
  outputFormatter so findings show as inline PR annotations (no
  separate problem-matcher action needed). Starter config relaxes
  the rules most projects override (MD013 line-length 120 with
  code-blocks/tables excluded; MD024 `siblings_only`; MD033 allows
  `br`/`details`/`summary`/`kbd`/`sup`/`sub`; MD041 disabled).
  Inputs: `globs` (default `**/*.md`), `config` (default empty —
  cli2 auto-resolves `.markdownlint.{json,yaml,…}` or
  `.markdownlint-cli2.*`), `fix` (default false), `runner_labels`
  (default `"ubuntu-latest"`).

- **Reusable `codeql.yml` workflow** (`.github/workflows/codeql.yml`),
  caller template (`install/templates/workflows/codeql.yml`). Wraps
  `github/codeql-action@v4.36.1` (SHA-pinned
  `21eb7f7842f33eafc83782b56fff2a2c43e9696f`) per GitHub's
  enterprise-scale code-scanning rollout pattern. Inputs: `languages`
  (JSON array, default `["actions"]`), `config-file` /
  `config` (inline alternative to file), `build-command` (override
  autobuild for compiled languages), `runner_labels` (default
  `"ubuntu-latest"`). Uses `category: /language:${{matrix.language}}`
  so multiple CodeQL workflows coexist without overwriting results.
  Matrix-driven explicit languages (not autodetect — autodetect
  breaks reproducibility on newly-added languages). Caller template
  triggers on push + PR + weekly cron (Mon 14:20 UTC) +
  workflow_dispatch per GitHub's recommended pattern. v3 enters
  deprecation Dec 2026; v4 is the supported major.

- **Reusable `labeler.yml` workflow** (`.github/workflows/labeler.yml`),
  caller template (`install/templates/workflows/labeler.yml`), and
  starter `.github/labeler.yml` config (`install/templates/labeler.yml`).
  Third reusable workflow shipped (after `ai-review` and `composition`).
  Auto-applies path-based PR labels via `actions/labeler@v6.1.0`
  (SHA-pinned `f27b608878404679385c85cfa523b85ccb86e213`). Consumer
  provides a per-repo `.github/labeler.yml` mapping paths to labels;
  the starter config maps common paths to the 4 canonical area
  labels added in the LABELS.md §3 area-namespace addition plus
  GitHub's built-in `documentation` label. Inputs: `runner_labels`
  (default `"ubuntu-latest"`; PRIVATE consumers override to
  `"runner-self"`), `config_path` (default `.github/labeler.yml`),
  `sync_labels` (default `false` — additive only; doesn't remove
  human-applied labels).

- **`LABELS.md` §3 + `install/templates/labels.json` — area-label
  namespace** (`area: <value>` colon-space, matching GitHub built-in
  style). Third PR-label sub-convention alongside `ai:<value>` (§1
  state) and `<verb>-<noun>` (§1 control). 4 canonical area labels
  added to the install taxonomy: `area: ci`, `area: governance`,
  `area: deps`, `area: tests` — auto-applied by the (forthcoming)
  reusable `labeler.yml` workflow when a consumer provides
  `.github/labeler.yml` mapping paths to label names. LABELS.md §3
  documents the three sub-conventions side-by-side with the
  rationale per form (programmatic vs semantic vs control directive).
  Sections 4-6 renumbered accordingly.
- **`docs/README.md`** — index for the `docs/` tree. Lists the
  available docs (`LABELS.md` today), the planned docs
  (`architecture` / `runners` / `overrides` / `security` /
  `troubleshooting` / `migration`) with their drafting triggers
  (drafted on demand, not preemptively), the contribution process,
  and cross-references to the operations governance tree
  (IPLAN-0017 + charter + DECISIONS).
- **`LABELS.md`** — first piece of CI documentation living on this
  repo (vs the operations governance tree). Defines conventions
  for the **two distinct label namespaces** used by `aidoc-flow-ci`:
  GitHub PR labels (the canonical 5-label taxonomy applied by
  `ai-review.yml`) and GitHub runner labels (per-origin convention:
  `runner-self` for our self-hosted pool; `ubuntu-latest` for
  GitHub-hosted; reserved `runner-azure`/`runner-aws`/… for future
  origins). Documents WHY the two namespaces use different separator
  conventions (PR labels can use `:`; runner labels cannot per
  GitHub Actions rules) and includes the routing rule by visibility
  (PRIVATE → `runner-self`, PUBLIC → `ubuntu-latest`).

## ci/v1.0.0 — 2026-06-23 — bootstrap MVP

Initial release. Unblocks IPLAN-0017 Phase A (framework migration)
and Phase B (operations migration).

### Added

- `.github/workflows/ai-review.yml` — reusable AI-review gate. Lifted
  from `aidoc-flow-operations/.github/workflows/ai-review.yml` with
  4 surgical patches: removed `pull_request_target` trigger;
  added `runner_labels_routine` + `runner_labels_review` inputs;
  parameterized both `runs-on:` lines. Existing inputs (`reviewer`,
  `model`, `max_budget_usd`, `tier`) preserved. Body unchanged.
- `.github/workflows/composition.yml` — reusable App-approval status
  check. Lifted from operations post-PR-#111 (conservative trigger
  shape — `pull_request_target [labeled/unlabeled]` +
  `pull_request_review`) with 3 surgical patches: removed both
  event-trigger blocks; added `workflow_call` with `runner_labels`
  input; parameterized `runs-on:`. Body unchanged. **Full
  `workflow_run` redesign per IPLAN-0017 §3.4 deferred to v1.X**
  (requires rewriting body to handle workflow_run event payload).
- `install/install.sh` — one-shot consumer bootstrap. Fetches
  templates via raw GitHub URLs (works under process-sub +
  local-clone modes). Idempotent. Preserves existing files (local
  override always wins). User-visible work dir; no auto-cleanup.
- `install/templates/workflows/{ai-review,composition}-{private,public}.yml`
  — 4 caller templates per visibility. Public ai-review ships
  `runner_labels_review` as `REPLACE-ME` placeholder (see Known
  Limitations).
- `install/templates/config.json.template` — default per-consumer
  `.github/ai-review/config.json` (trust allowlists, governance
  locked paths, composition / auto-merge / autofix toggles).
- `install/templates/labels.json` — canonical 5-label taxonomy
  (`ai:review-passed`, `ai:review-changes`,
  `ai:human-review-required`, `skip-ai-review`,
  `ai:autofix-applied`).
- `sync/check-drift.sh` — drift detector. Warning-only; **never
  blocks** (per IPLAN-0017 §3.1b locked rule). No `--strict` mode.
- `install/README.md` + repo-root `README.md` — consumer-facing
  intro + usage + v1.0.0 known limitations.

### Known limitations

- Public consumers need their own reviewer-equipped self-hosted
  runner; `ubuntu-latest` doesn't have `codex` / `claude` CLI.
- Secret names hardcoded; not parameterized.
- Composition trigger shape is conservative pre-Phase-B; full
  `workflow_run` redesign deferred.

### Provenance

Workflow content lifted from `aidoc-flow-operations` PRs #100-118
(the 2026-06-22→23 AI-reviewer Stage 1 activation arc + governance
discipline rules); patches verified locally via smoke tests before
shipping. Per-runbook references in
`aidoc-flow-operations` `ops/inbox/2026-06-23_cto-platform_aidoc-flow-ci-R-{a,b,c,d}-*.md`.
