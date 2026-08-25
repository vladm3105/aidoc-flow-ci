# PLAN-027 — `ci/v4.0.0` release readiness, and the deferred work the tracker no longer holds

**Status:** In Progress.

- **Phase A** EXECUTED, verified 2026-08-22 at `8ccd168` (suite 2037/0, every
  guard mutation-tested).
- **Phase A2** EXECUTED 2026-08-23 — a SECOND review round over the post-`8ccd168`
  delta (PRs #516, #517, #518, #519). See §3a; suite 20 groups / 2252 assertions
  / 0 failures measured on the fold branch AFTER its own pre-push review round,
  every new guard mutation-tested. The earlier figure in this line read 2214 —
  measured before the last fix landed, which the fold review caught.
- **Phase B:** B2, B3, B4 EXECUTED. **B1 — the cut itself — NOT started**, and it
  is the only thing between this plan and `Completed`.
- **Phase C** carried-over deferred work, not started.

Not `Completed` until B1 lands — the tag is the deliverable, and A alone is a
branch. **The per-item status above is deliberate:** a single "Phase B not
started" line was carried while B3 and B4 were already correct on disk, which is
the same stale-status-line defect CI-0045 recorded against PLAN-024's header.

**Cross-plan dependency, added 2026-08-23:** PLAN-028 Phase B (#519) landed
AFTER this plan's Phase A verification and modified `scripts/release.sh`,
`install/apply-standards.sh`, `sync/check-standards-drift.sh` and both
`pre_push_check.sh` copies — the release mechanism this plan's B1 drives. Phase
A's 2037/0 figure therefore does not describe HEAD. Re-measured at HEAD as part
of A2; that is what B1 must be run against.
**Owner:** canon (aidoc-flow-ci)
**Scope:** closing the pre-production review of the v3 line, cutting
`ci/v4.0.0`, and holding the deferred items whose only record was a closed
GitHub issue. Consumer-side adoption is out of scope — that is
`docs/MIGRATION_v4.0.0.md`.
**Change level:** C3. It changes the surface every consumer adopts and cuts a
MAJOR.
**Decisions of record:** `DECISIONS.md` CI-0044 (v4, not a v3 re-cut), CI-0045
(the `doc-maintainer` execution record), CI-0046 (the backlog is deliberately
empty; this plan is the carrier).

## 1. Why this plan exists

Two reasons, and the second is the one that makes it a plan rather than a PR
description.

**(a) A pre-production review of the v3 line returned BLOCKER.** Five
independent read-only lenses (security, correctness, docs, portability,
governance) were run against `main` at `8ccd168` before deciding whether to
publish. Every BLOCKER and HIGH was verified against source before it was
accepted; two lens findings were narrowed on verification and one was dropped as
imprecise. Phase A folds them.

**(b) `plans/` is now the sole durable carrier for deferred work.** CI-0046
records the reasoning. Four disclosed-but-open items had a closed GitHub issue
as their only record; §C carries them.

## 2. What the review found, and where each finding went

Every finding is accounted for — a findings list that quietly drops entries
reads as "covered everything" when it did not.

| # | Finding | Severity | Disposition |
|---|---|---|---|
| 1 | Re-cutting `ci/v3.0.0` in place, justified by "zero adopters" — `framework` is a live adopter on 5 workflows | BLOCKER | CI-0044: cut `ci/v4.0.0`, leave v3 immutable |
| 2 | Wrong version number; no MAJOR migration guide; `release.sh` validates shape only | BLOCKER | `docs/MIGRATION_v4.0.0.md`; §B1 |
| 3 | `MIGRATION_v3.0.0.md` silent on 2 of 3 breaking changes | BLOCKER | superseded by the v4 guide (v3 is not being re-cut, so its guide is correct as-is for the tag it names) |
| 4 | SAST gate bypassable via a symlinked `.semgrepignore`; the D23 guard excluded both sast surfaces by construction | BLOCKER | §A1 — fixed, mutation-verified |
| 5 | The declared backlog and live handoff no longer exist | BLOCKER | CI-0046 + this plan |
| 6 | The v3 composite-action layer had never executed anywhere | HIGH | §A2 — `self-quick-gates`, `self-scanners` |
| 7 | `codeql` was the one generic surface with no private variant | HIGH | §A3 — variant ships; guard generalised |
| 8 | `release.sh prep` could re-pin the fleet backwards | HIGH | §A4 |
| 9 | `ft30-dry-run.sh` used `\s` in `grep -E` (BSD false all-clear) | HIGH | §A4 |
| 10 | `ft30-dry-run.sh` claimed to reuse `release.sh`'s definition and did not | HIGH | §A4 |
| 11 | `DECISIONS.md`/`PLAN-024` asserted `doc-maintainer` was not removed | HIGH | CI-0045 + PLAN-024 header |
| 12 | ai-review shipped the unredacted diff to the fixer and a 24h artifact | MEDIUM | §A1 |
| 13 | D26's "a PR cannot inject rules" was prose, not a guard | MEDIUM | §A1 |
| 13a | `scan-path` was the same coverage lever, unguarded on all six surfaces | MEDIUM | §A1 (found in cycle 2) |
| 14 | 4 of 16 checkouts persisted credentials, incl. the one untrusted-head checkout | MEDIUM | §A1 — 3 fixed, 1 is the D36 exemption |
| 14a | `sarif-path` is an unenforced report lever | LOW–MED | §C6 — disclosed in §4.3i, not fixed |
| 15 | `manifest.json` declared `actionlint.yaml` load-bearing with `auto_install: false` | MEDIUM | §A3 |
| 16 | `install.sh` documented 4 dependencies, checked 1, late | MEDIUM | §A3 |
| 17 | The zero-hook detector was fetched and executed without FT-39 validation | LOW | §A3 |
| 18 | `sort -V` let a pre-release hijack "latest published tag" | MEDIUM | §A4 |
| 19 | `prep`'s red-suite classifier had no test cover | MEDIUM | §A4 |
| 20 | ~994-line `## Unreleased` becomes the published release notes verbatim | MEDIUM | §B2 — deferred to the cut, not to a later release |
| 21 | `skip-audit-trail` two-signal override is single-principal | LOW | §C4 — accepted, reworded rather than re-engineered |
| 22 | `UPDATE_GUIDE.md` quick-reference gives anachronistic secret names for the v1→v2 step | HIGH (docs) | §B3 |

## 3. Phase A — the code fixes (EXECUTED 2026-08-22)

Landed together because they are one release-readiness change and because
several share a test surface. Full reasoning per fix is in `CHANGELOG.md`; this
is the index.

- **A1 — security.** D23 back-ported to both sast surfaces with the shared
  `d23_scan()` shape; the guard's surface list is now DERIVED from the tree; D26
  enforced as an **exact-value** ruleset allowlist (a `p/*|r/*` namespace prefix
  was the first attempt and takes coverage from zero rules to one); the same
  coverage rule applied to **`scan-path`** on all six surfaces, which was the
  identical lever one input away; ai-review's artifact and fixer moved to the
  redacted diff and the dead redaction helpers removed; `persist-credentials:
  false` at every checkout **except** `audit-trail-check.yml`, which runs a
  remote `git fetch` and needs it (D36).
- **A2 — canon exercises its own v3 actions.** `self-quick-gates.yml` and
  `self-scanners.yml`, using local `./actions/<name>` references, non-required,
  with a drift guard against the shipped templates.
- **A3 — installer.** `codeql-private.yml` + manifest routing; the
  private-variant guard generalised to callers that pass no `runner_labels` and
  inherit a `ubuntu-latest` reusable default; `.github/actionlint.yaml` pulled
  as an `--add-surface` dependency; a dependency preflight; FT-39 validation on
  the zero-hook detector.
- **A4 — release mechanism.** `prep` monotonicity guard; `ft30-dry-run.sh`
  delegates to `release.sh _coldstart-changed`; `[[:space:]]` for `\s`;
  `classify_suite` extracted and driven; the latest-tag derivation filtered.

**Verification.** Suite 20 groups / 2037 assertions / 0 failures (from 1821 at
`8ccd168`). Each new guard was mutation-tested by re-introducing the defect it
closes and confirming the suite reds; the mutations are named in `CHANGELOG.md`
so they can be re-run rather than taken on trust. The mutation results are the
evidence — a green suite over unmutated code is not.

### A5 — what the review cycles found in the FIXES (OPS-0066: 3 of 3 used)

Recorded because the pattern, not the individual defects, is the reusable
finding: **every cycle found a blocker inside the previous cycle's fold.**

| Cycle | Scope | Found |
|---|---|---|
| 1 | the artifact (5 lenses) | 5 BLOCKER, 6 HIGH, 11 MEDIUM/LOW |
| 2 | the cycle-1 fold (3 lenses) | 2 BLOCKER + 4 MAJOR + 12 MINOR, **all introduced by the fold** |
| 3 | the cycle-2 fold (2 lenses) | see the PR record |

The two blockers cycle 2 found are the ones worth carrying forward as lessons:

- **`persist-credentials: false` on `audit-trail-check.yml`.** A uniform sweep
  applied a rule to the one site the rule exempts. It reds `call / verify` on
  every private consumer and could not reproduce on canon's own PRs, because
  canon is public — so it would have shipped green. PLAN-025 D36 had already
  recorded the exemption. *A convention applied without reading the site is not
  the convention.*
- **`assert_ok "git diff --quiet -- VERSION"` in the monotonicity control.**
  `prep` rewrites VERSION and then runs the suite, before committing — so this
  assertion is false during every real cut, `classify_suite` would have read it
  as an UNEXPECTED red, and `release.sh prep ci/v4.0.0` would have aborted after
  mutating the tree. A test written against the repo's steady state, in a file
  whose own comments twice warn that it runs *inside* `prep`.

And the recurring class across all three cycles: **an assertion that passes by
covering nothing.** A quote-sensitive grep that silently matched zero shipped
templates; a derived row-set with no floor; an exemption justified by a comment
that mentioned the thing it was meant to prove; a guard driven against a
hand-retyped copy of itself. Every one of them was green.

## 3a. Phase A2 — the SECOND review round (EXECUTED 2026-08-23)

**Why there is a second round.** §3's review ran at `8ccd168`. Commits
PR #516, PR #517, PR #518 and PR #519 landed after it. #517–#519 are PLAN-028 Phase B — a C3
change to `apply-standards.sh`, `check-standards-drift.sh`, both
`pre_push_check.sh` copies, `release.sh`, and a new shipped template — heading
into the tag with **no lens coverage at all**. Five independent read-only lenses
were run over `ci/v3.0.0..HEAD` weighted to that delta; every BLOCKER and HIGH
was verified against source before acceptance.

**Findings and disposition — all accounted for.**

| # | Finding | Sev | Disposition |
|---|---|---|---|
| 1 | `release.sh` aborts rc=128 when a cold-start template is added/deleted; `_coldstart-changed` seam silently returns empty; the parity test asserts a false "unchanged surface" | HIGH | FIXED + 9 assertions driving both entry points |
| 2 | FT-28 pin-peel missing on `standards-drift.yml` + `docs-sync.yml`, which EXECUTE what they fetch | HIGH | FIXED; test derives the required set from the tree |
| 3 | Null-permissive fork guard on 7 v2 surfaces (+2 more found: `codeql`, `ai-review`) | HIGH | FIXED on 9; `composition.yml` deliberately NOT changed (its null fails closed) |
| 4 | `MIGRATION_v4.0.0.md` silent on PLAN-028 entirely | HIGH | FIXED |
| 5 | `BRANCH_PROTECTION.md` instructs keeping `enforce_admins: true`, which canon now inverts in two documented cases | HIGH | FIXED |
| 6 | `enforce_admins:false` can land on the API-default branch (FATAL guard compares two declaration-supplied values) | MED | FIXED in `apply-standards.sh` + mirrored in the verifier |
| 7 | `aidoc-ci.json` schema enforced by nobody; a key typo inverts an explicit opt-out | MED | FIXED in all 4 readers; key lists pinned to the schema by test |
| 8 | Drift: a fetched-but-undecodable declaration read as "absent", silently | MED | FIXED — warns + `FETCH_ERRORS` |
| 9 | `pre_push_check.sh` prints `PROMOTION OK` without checking target or fast-forward | MED | FIXED — reports the weaker fact it can justify; `rc=0` no longer clobbers an earlier failure |
| 10 | PLAN-027's own status line stale; no PLAN-028 cross-reference | MED | FIXED — this header |
| 11 | `docs/runners.md` describes the `gh` pin as self-expiring; #435 fixed it | MED | FIXED |
| 12 | `docs/README.md` index missing v4; "Planned" footer two MAJORs stale; 12-vs-15 workflow count | MED | FIXED |
| 13 | `composition.yml` cites `scripts/ci-runner/build-image.sh`, absent from this repo | LOW | FIXED (pre-existing at `ci/v3.0.0`, not a v4 regression) |
| 14 | `UPDATE_GUIDE.md` v4 table omits the trigger-arm requoting its own §3 documents | LOW | FIXED |
| 15 | `sarif-path` unconstrained | LOW | **NOT fixed** — already carried as §5 C6; unchanged by this round |
| 16 | No CI-side promotion verifier (nothing asserts a promotion push is a fast-forward) | HIGH-as-gap | **NOT fixed** — see C7 below. Zero blast radius today: no repo has adopted |
| 17 | 🔴 FT-30 cold-start dry-run owed and unexecuted | BLOCKER | **EXECUTED 2026-08-23/24 — PASSED, and it FOUND a defect.** Must be re-run against the final tag SHA; see below |
| 18 | 🔴 MAJOR-bump LLM smoke never run against the current workflow | BLOCKER | **PARTIALLY CLOSED** — substance verified against the live endpoint; the CI leg is still unrun. See below |

**Where the two 🔴 gates actually stand (updated 2026-08-24).** Recorded here
because no log artifact is committed. `DECISIONS.md` **CI-0037** ("`ci/v3.0.0`
is released — the three founder gates, discharged with their evidence") set the
precedent and names the weakness plainly: *"`ft30-dry-run.sh` writes nothing to
the scratch repo and no log artifact is committed, so `FT-30 DRY-RUN PASSED`
survives only as this record."* A gate result that lives only in a session
transcript is a gate result that did not happen — the CI-0050 defect applied to
this plan.

- **FT-30 (#17) — EXECUTED, PASSED, and it earned its keep.**
  - Run 1, against the prep-merge SHA `a2b5f96`, on a **fresh** throwaway:
    **PASSED**, all 11 criteria.
  - Run 2, against `aa55255` (after CI-0051 changed two bootstrap-path files),
    reusing the **same, now-populated** throwaway: **FAILED** —
    `gh label create todo failed … already exists`, `==> ABORT`. That is the
    truncated label prefetch, a defect present since the installer's first
    commit and shipped through `ci/v3.0.0`. Fixed in #524.
  - Run 3, against the fix, same populated target: **PASSED**, all 11 criteria.
  - **It must be RE-RUN against whatever SHA the tag will point at.** `main` has
    moved three times since run 1 (#522, #524), each touching the bootstrap
    path. Three invalidations so far; cut the tag promptly rather than
    accumulating more pre-tag changes.
  - **And it must be run TWICE against the same target** — see
    `docs/RELEASE_CHECKLIST.md`. A fresh throwaway has ~9 labels and can only
    prove the greenfield case; run 2 is the one that exercises idempotence, and
    is the only reason the defect above was ever seen. The throwaway used here
    was deleted 2026-08-24, so the next run starts fresh and needs the second
    pass to regain that coverage.
- **LLM smoke (#18) — substance PASSED, CI leg still unrun.**
  - **Verified 2026-08-23:** the smoke's exact command
    (`scripts/llm_client.py --json`, `LLM_MODEL=ai-reviewer`) run against the
    live endpoint returned `{"ok":true,"agent":"review"}` and satisfied the
    workflow's own `jq -e '.ok == true and .agent == "review"'` gate. The
    `ai-reviewer` alias is registered and responding. So the unified
    `LLM_URL`/`LLM_API_KEY` resolution that CI-0040 rewrote **does** work.
  - **What that does NOT establish**, and why #18 is not fully closed:
    authentication used the endpoint's master key read locally, **not** canon's
    stored repository secret, which is write-only and unreadable. If that secret
    is stale, this run would not have caught it. The Actions runner/secret
    plumbing is also untested.
  - **Blocker to the CI leg:** canon holds no `LLM_URL`/`LLM_API_KEY` (only the
    deprecated pair). Since CI-0051 removed the fallbacks, the smoke cannot
    authenticate until canon is provisioned:
    `install/set-llm-secrets.sh --mint --repos "vladm3105/aidoc-flow-ci"`.
    Note this does **not** affect canon's own PR gates — canon has no
    `ai-review` caller and `call / ai-review` is not a required context.
  - Re-derive the run count with:
    `gh api repos/vladm3105/aidoc-flow-ci/actions/workflows/.github%2Fworkflows%2Fllm-smoke.yml/runs --jq '.workflow_runs | length'`

**What this round confirms about the previous one.** §3's A5 recorded that every
cycle found a blocker inside the previous cycle's fold. This round extends it
one step further out: the defect that mattered most (#1) was introduced by
**PLAN-028 Phase B**, a change reviewed under its own plan and merged green,
into a file PLAN-027 depends on — and canon's own suite stayed green because the
one test covering it swallowed the crash with `2>/dev/null … || true`. *A plan's
verification does not survive another plan editing its files.*

## 4. Phase B — the cut

- **B1 — `release.sh prep ci/v4.0.0`**, then merge the prep PR with `--admin`
  (the FT-21 chicken-and-egg makes it BLOCKED, not merely red), then
  `release.sh tag ci/v4.0.0`. The FT-30 gate **will** fire: Phase A changes
  `install/install.sh` and `install/templates/manifest.json`, both on the
  bootstrap write path. The 🔴 cold-start dry-run is therefore owed and must run
  against the **prep-merge SHA**, not against `main` before the prep lands.
- **B2 — the release notes. EXECUTED 2026-08-23.** `release.sh tag` publishes
  the promoted `## Unreleased` section verbatim, and it is now ~1670 lines of
  implementation forensics. A **⚠️ Breaking changes** block now opens that
  section: the three things an adopter must act on, the two ordering rules, an
  explicit "not breaking, so you do not misread it" paragraph covering the LLM
  credential unification and the opt-in branching model, and a pointer to
  `docs/MIGRATION_v4.0.0.md`.
- **B3 — `docs/UPDATE_GUIDE.md`. EXECUTED (landed in #515).** Its v1.x→v2.0.0 quick-reference tells the
  operator to set `LLM_URL`/`LLM_API_KEY`, but the full guide it summarises
  (`docs/MIGRATION_v2.0.0.md`) requires `LITELLM_BASE_URL` /
  `LITELLM_REVIEW_API_KEY`, and the `LLM_URL` fallback did not exist at
  `ci/v2.0.0` — the frozen reusable at that pin cannot read it. An operator
  bringing a genuine v1.x consumer forward follows the quick-reference and the
  ai-review job cannot find its secret. Two docs, same step, mutually exclusive
  names. Correct the quick-reference to the names the pinned tag actually reads.
- **B4 — README / UPDATE_GUIDE v4 framing. EXECUTED (landed in #515).** `README.md:38-40` says `ci/v3.0.0`
  "is the latest tag"; `UPDATE_GUIDE.md` has a v2.x→v3.0.0 section and none for
  v4. Both must change in the same PR that cuts the tag — a tag that falsifies
  the README is not a shipped release.

## 5. Phase C — carried-over deferred work (unstarted)

These had a closed GitHub issue as their only record. They are carried here
under CI-0046, not re-filed.

- **C1 — 🔴 pool re-registration (was #513, from CI-0043).** ORDER-SENSITIVE:
  register `self-hosted,ci-runner,single-use,ci,ephemeral` first, confirm a job
  lands on the new labels, then narrow to `self-hosted,ci,ephemeral`. Affects
  `operations` (1 runner), `framework` (2), `iplanic` (1). Founder-executed and
  cross-repo — the pool default lives in `aidoc-flow-operations`. Getting the
  order wrong does not fail, it **hangs**. Procedure:
  `docs/MIGRATION_v4.0.0.md` §1.
- **C2 — HANDOFF/ROADMAP template coherence (was #509, carved out of CI-0042).**
  Canon retired its own `HANDOFF.md` and `ROADMAP.md` while still shipping
  `HANDOFF.md.template` and `ROADMAP.md.template`. Verified narrower than it
  reads: `manifest.json` references neither, and `CLAUDE.md.template` already
  ships the `Tracker — <descriptor>` / `Not adopted —` cell forms, so no adopter
  is *instructed* to use a form canon abandoned. The residue is two unreferenced
  templates. Decide: keep as an offered option for repos that want the file
  form, or delete. Not urgent; do not ship a half-answer.
- **C3 — the five forward items from the retired `ROADMAP.md` (was #508).**
  Recover them from the issue body (`gh issue view 508 --json body`) or from git
  history before that becomes archaeology, and fold each into the plan that owns
  it. CI-0042's honesty condition for deleting `ROADMAP.md` was that these
  survived; making that true again is the point of this item.
- **C4 — `skip-audit-trail` is a single-principal override.**
  `audit-trail-check.yml`'s skip-override branch requires the `skip-audit-trail` label **and**
  `[skip-audit-trail]` in a commit body. On a same-repo PR one principal
  controls both (write implies triage), so the second signal adds no independent
  authority. **Accepted as-is** — it is a discipline gate that logs its own use,
  and two signals still defeat an accidental skip. The fix is to stop describing
  it as defence-in-depth, not to re-engineer it.
- **C6 — `sarif-path` is an unenforced REPORT lever (disclosed, not fixed).**
  It cannot zero a findings count — that is computed from the file the scanner
  just wrote, and an unwritable or empty path trips the infrastructure-error arm.
  It can make one scanner overwrite another's SARIF: a PR setting the sast step's
  `sarif-path: osv.sarif` ships semgrep's results under `category: dep-scan`, and
  because Code Scanning keys an analysis by category, the `push: main` run
  replaces the dep-scan analysis with content holding none of its rule IDs —
  every open dep-scan alert auto-resolves as fixed, with the job fully green.
  Same harm as §4.3e's "outlives the PR" paragraph, reached through an input
  rather than a committed file. Fix shape: each action refuses a `sarif-path`
  that is not its own default, or that already exists when the step starts.
  Disclosed in §4.3i rule 3 rather than left to be rediscovered.

- **C7 — there is no CI-side promotion verifier (from A2 #16).** Nothing in
  `.github/workflows/` or `install/templates/workflows/` asserts that a push to
  a promotion branch is a fast-forward of the integration branch — `grep -rn
  'promot'` over both returns one comment and zero logic. Under the model,
  `main` carries `enforce_admins: false` (the only mechanism CI-0048 found that
  permits the promotion push at all), push-triggered callers are narrowed to the
  integration branch, and `audit-trail-check` is `pull_request`-only — so the
  local pre-push hook is the sole control, and `--no-verify` bypasses it by
  design. **Not urgent and deliberately deferred: no repo has adopted the model,
  canon included, so the blast radius today is zero.** It must be closed before
  Phase C/D adoption, not before the tag. Fix shape: a `promotion-check`
  reusable on `push: [staging, main]` asserting the pushed SHA is contained in
  `origin/<integration>`, made a required context — a server-side check that
  `enforce_admins: false` does not disable for non-force pushes.

- **C8 — the FT-30 gate's "empty means unchanged" shape (from the A2 fold
  review).** Three residues, none of them the crash that was fixed, all sharing
  one property: the surface computation reports "nothing changed" for every
  partial failure, and `tag` reads that as AUTO-WAIVE.
  1. `scripts/release.sh:210` — `done < <(git diff --name-only … 2>/dev/null)`
     discards the `git diff` exit status. A failure there yields zero loop
     iterations and an auto-waive.
  2. Same function — a template that is **empty or newline-only** on one side
     compares equal to an absent one, so adding or deleting such a file waives.
     (Both forms had this; the fix did not introduce it.)
  3. `tests/test_contract.sh` strips comments with `grep -vE`, where
     `tests/test_actions.sh:573-586` already has a YAML-parsed helper written
     precisely because a grep matched the comment explaining a banned spelling.
     The new assertions err toward a false RED, so this is hygiene, not a hole.
  **Fix shape for 1 and 2:** have `coldstart_material_changes` return non-zero
  or emit a sentinel when the diff itself is uncomputable, and have `tag` fail
  CLOSED on it — the gate should distinguish "nothing changed" from "could not
  tell". **Deferred deliberately:** the release-blocking crash is fixed and
  under test through both entry points, and changing the gate's waive contract
  is a change to the release mechanism itself, which is the wrong thing to do
  in the change that cuts the release. Do it first in the next cycle.

- **C5 — `install/templates/workflows/sast-scan.yml` vs `scanners.yml`.** Two
  live adoption paths reach SAST: the individual caller (pinning the reusable)
  and the v3 consolidated caller (pinning the composite action). Both are now
  hardened, so this is no longer a correctness gap — but two paths to one gate
  is a maintenance surface that produced exactly this class of divergence once.
  Consider retiring the individual callers once the fleet is on v3-shaped
  callers.

## 6. What this plan does NOT do

- It does not re-open PLAN-025 or PLAN-026. Their unstarted phases stay theirs.
- It does not re-file anything on the GitHub tracker. CI-0046 is the decision;
  §18/CI-0020 still applies to defects canon does **not** own, which is a
  different case.
- It does not claim the private runner path is verified. `self-scanners` runs on
  `ubuntu-latest` because canon has no pool of its own; the runner image remains
  covered only by `install/templates/runner/build-image.sh`.
