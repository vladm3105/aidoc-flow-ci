# PLAN-027 — `ci/v4.0.0` release readiness, and the deferred work the tracker no longer holds

**Status:** In Progress — Phase A EXECUTED and verified 2026-08-22 (suite
2037/0, every guard mutation-tested); Phase B is the release cut, not started;
Phase C is the carried-over deferred work, not started. Not `Completed` until B
lands — the tag is the deliverable, and A alone is a branch.
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

## 4. Phase B — the cut

- **B1 — `release.sh prep ci/v4.0.0`**, then merge the prep PR with `--admin`
  (the FT-21 chicken-and-egg makes it BLOCKED, not merely red), then
  `release.sh tag ci/v4.0.0`. The FT-30 gate **will** fire: Phase A changes
  `install/install.sh` and `install/templates/manifest.json`, both on the
  bootstrap write path. The 🔴 cold-start dry-run is therefore owed and must run
  against the **prep-merge SHA**, not against `main` before the prep lands.
- **B2 — the release notes.** `release.sh tag` publishes the promoted
  `## Unreleased` section verbatim. It is ~1000 lines of implementation
  forensics, inside which the two things an adopter must act on are one line
  each. Add a short **Breaking changes** block at the top of the promoted
  section pointing at `docs/MIGRATION_v4.0.0.md`, before the tag. This is a
  release-time step, not a codebase change.
- **B3 — `docs/UPDATE_GUIDE.md:303`.** Its v1.x→v2.0.0 quick-reference tells the
  operator to set `LLM_URL`/`LLM_API_KEY`, but the full guide it summarises
  (`docs/MIGRATION_v2.0.0.md`) requires `LITELLM_BASE_URL` /
  `LITELLM_REVIEW_API_KEY`, and the `LLM_URL` fallback did not exist at
  `ci/v2.0.0` — the frozen reusable at that pin cannot read it. An operator
  bringing a genuine v1.x consumer forward follows the quick-reference and the
  ai-review job cannot find its secret. Two docs, same step, mutually exclusive
  names. Correct the quick-reference to the names the pinned tag actually reads.
- **B4 — README / UPDATE_GUIDE v4 framing.** `README.md:38-40` says `ci/v3.0.0`
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
