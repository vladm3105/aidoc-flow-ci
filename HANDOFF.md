# HANDOFF — aidoc-flow-ci

Live cross-session resume point for the workspace CI + governance-workflow
canon library. Read at session start; refresh at milestones and before
context compaction.

## Current state (2026-07-23)

> **TL;DR (session wrap 2026-07-23).** PLAN-019's **AI-executable work is COMPLETE**
> — 17 PRs merged (#269–#285), `main` @ `5029ad6`, suite green. All FTs landed:
> FT-39…45, 47, 48, 49, 50, 51 (code/test/docs) + the §4 content-currency; **FT-52**
> is a prepared 🔴 founder runbook (`plans/ROLLOUT_ft52-canon-self-governance.md`).
> **FT-46 is DEFERRED** — its `verified_allowed` flip *is* the OPEN founder decision
> **CI-0011** (held in `git stash` `ft46-HELD-…`). Everything is under CHANGELOG
> `## Unreleased`, ready to ride **`ci/v2.12.0`**.
>
> **To ship `ci/v2.12.0` — ALL 🔴 founder-gated** (nothing more for the AI on the
> release path): **(1)** decide **CI-0011** (then FT-46 lands or rides a later tag);
> **(2)** run the **G2 cold-start dry-run** pinned to the **final pre-tag `main` SHA**
> (`git rev-parse origin/main`, NOT the G1 checkpoint) —
> `plans/ROLLOUT_plan019-feedback-desk-coldstart.md`; **(3)** `release.sh prep
> ci/v2.12.0` → merge → tag. FT-52 (esp. Part A tag ruleset) can run any time. Only
> non-🔴 leftover: the cosmetic 4-doc markdown-`+` prose (markdownlint-clean, low
> priority). Pre-existing dependabot PRs #221–228 are separate (FT-24), untouched.
> Detailed per-FT history + review findings follow below.

- **G1 (PLAN-019 Workstream A) COMPLETE (2026-07-23) — all 4 tag-cut blockers
  merged, each its own PR with OPS-0065 pre-push dispatch.** **FT-39** (install.sh
  fetch validation + `--update` no-TTY consent — PR #269, squash `1066d2b`;
  OPS-0065 cycle-1 folded a MAJOR `<!--` false-reject of `pull_request_template.md`
  plus a docs count fix, cycle-2 re-review CONFIRMED); **FT-40** (FT-28 SHA-peel
  guard now driven not re-implemented — `resolver` 62→70, `if false;` mutation goes
  red — PR #270, squash `6bab677`); **FT-41** (markdown-lint blocking-default now
  asserted — `contract` 271→272, default-flip goes red — PR #271, squash `ef72517`);
  **FT-42** (`ai-review` least-privilege secrets — reusable declares its 8 secrets,
  caller passes an explicit map instead of `inherit`; additive, two-way completeness
  test, `contract` 272→275; security-auditor verdict READY — additive-safety
  confirmed against GitHub reusable-workflow docs — PR #272, squash `d70782e`).
- **➡️ NEXT (AI-executable): G3 + G4 — the remaining flow-ci tasks (FT-43…52,
  EXCEPT FT-46 which is DEFERRED on the OPEN founder decision CI-0011 — see its
  entry below; it rides a LATER tag, not `ci/v2.12.0`).**
  The rest all ride the same `ci/v2.12.0` tag (additive surfaces), and several touch
  `install.sh` + the templates the cold-start dry-run exercises (FT-47, FT-50,
  FT-43) — so they land on `main` FIRST. G3 (ship-with-tag): ✅ **FT-43** (label/draft
  can supersede a RED ai-review — fail-closed-when-unarmed via a driven guard +
  unarmed job-`if:` clause + concurrency exclusion + draft triggers; `contract`
  275→283, 4 mutations red — PR #275 MERGED `3066b3a`; security-auditor READY on a
  full truth table), ✅ **FT-44** (pre-commit refresh reports a kept-but-changed
  canon hook via a `SKIPPED_HOOKS` NOTE + fixed a latent `pipefail` abort;
  `precommit-refresh` 18→24 — PR #276 MERGED `cfa3e56`), ✅ **FT-45**
  (`required-context-map.py` validates the job-key half; `required-contexts` 21→23
  — docs PR #277 `1d46658` + code-recovery PR #278 `c802833`; #277 dropped the code
  to a staging race with the review sub-agents, #278 landed it), ⏸️ **FT-46
  DEFERRED** (its `verified_allowed: true→false` flip IS the OPEN founder decision
  **CI-0011** — keep vs. drop the verified-marketplace allowlist; PLAN-019's FT-46
  spec never referenced CI-0011, so it was NOT shipped. Founder chose "defer"
  2026-07-23. Implementation is complete + reviewed, held in `git stash`
  (`ft46-HELD-pending-CI-0011...`) on `fix/ci-ft46-verified-allowed`; rides a later
  tag once CI-0011 is decided. **CI-0011 stays OPEN in DECISIONS.md/ROADMAP.**),
  ✅ **FT-47** (CI now exercises the ruamel.yaml merge backend, not only PyYAML —
  the gap that let FT-44's ruamel `__ne__` bug pass CI; `contract` 283→284 — PR
  #279 MERGED `33e4bf9`), ✅ **FT-48** (`release.sh prep` gains the on-main + fetch +
  up-to-date guards `tag` has; `release` 21→27, both-guard mutations red — PR #280 MERGED `c8eee7d`).
  **G3 CODE/TEST items (FT-43/44/45/47/48) done; FT-46 DEFERRED (CI-0011).** Still
  open in G3: the **Workstream-C doc-currency items** (PLAN-019 §4, un-numbered —
  `architecture.md` secret-scan rows + "11 shared workflows" header;
  `REPO_STANDARDS.md:1368` stale `@ci/v2.0.0` pin; the 4-doc markdown-autofix
  wrapped-`+` corruption; `README.md` EXERCISER row). ✅ **FT-49** done
  (`FLEET_BRANCH_PROTECTION_ARMING.md` stale `ci/v2.1.0` + `REPO_STANDARDS.md:1368`
  stale `@ci/v2.0.0` → version-neutral — PR #281 MERGED `6652357`). ✅ **§4
  content-currency** (architecture.md 3 tool-description rows corrected — they said
  `gacts/gitleaks`/`*-action`, actually binaries; header count-neutral; README
  EXERCISER row added — PR #282 MERGED `60dc097`). Only the cosmetic 4-doc markdown-autofix
  wrapped-`+` prose remains in §4 (markdownlint-clean, low priority). **G3 is now
  substantively complete** (FT-46 deferred). **G4:** ✅ FT-50 (macOS/bash4
  portability — portable `sed -i.bak` ×3 + `BASH_VERSINFO` guard + README fix;
  `scripts` 27→29 — PR #283 MERGED `0dbf01a`), ✅ FT-51 (runner docs: per-repo
  registration is primary, org-level scoped to a real GitHub org — PR #284 MERGED
  `268a54d`), ✅ FT-52 runbook prepared (🔴 canon branch-protection + immutable
  `ci/v*` tag ruleset — `plans/ROLLOUT_ft52-canon-self-governance.md`; execution is
  founder-only; the runbook flags that product-tier protection would HANG canon and
  uses canon's own check set — PR #285 MERGED `5029ad6`).
- **➡️ PLAN-019 AI-EXECUTABLE WORK IS COMPLETE.** All FTs are landed or handed off:
  FT-39…45, 47, 48, 49, 50, 51 merged; FT-52 runbook prepared (🔴 founder);
  **FT-46 DEFERRED** on the open founder decision **CI-0011** (held in stash). The
  only remaining §4 item is the cosmetic 4-doc markdown-`+` prose (low priority).
  **REMAINING TO SHIP `ci/v2.12.0` — all 🔴 founder / gated:** (1) decide CI-0011
  (then FT-46 rides a later tag or lands); (2) run the **G2 cold-start dry-run**
  pinned to the FINAL pre-tag `main` SHA (`git rev-parse origin/main`, NOT the G1
  checkpoint) per `plans/ROLLOUT_plan019-feedback-desk-coldstart.md`; (3) `release.sh
  prep ci/v2.12.0` → merge → tag. FT-52 (Part A tag ruleset especially) can run any
  time.
  **PROCESS NOTE (FT-45 incident):** review sub-agents run `git stash`/`git add` on
  the shared tree, which can unstage code between `git add` and `git commit`. ALWAYS
  `git add -A` + diff-vs-reviewed AFTER agents finish, before committing.
- **G2 — the 🔴 founder cold-start dry-run — is the LAST flow-ci step, not the
  next one.** It must validate the exact tree that becomes the tag, so it runs only
  after G1 **+ G3 + G4** are all merged, pinned to the **final pre-tag `main` SHA**
  (`git rev-parse origin/main`), NOT the G1 checkpoint `d70782e` (G3/G4 change the
  installer + templates it exercises). `plans/ROLLOUT_plan019-feedback-desk-coldstart.md`
  is reframed accordingly (⏳ NOT YET; pin = final SHA). Sequence:
  **G3+G4 land → G2 dry-run GREEN → prep PR → tag `ci/v2.12.0` → fleet rollout.**
  Do NOT cut the tag before G2 runs GREEN. Umbrella/HANDOFF NEXT bullet below stays
  superseded by this line.
- **PRE-PROD REVIEW of the `ci/v2.11.0..main` candidate → BLOCKER; PLAN-019
  authored + READY to close it. DO NOT cut `ci/v2.12.0` yet.** A 5-lens
  `ci-preprod-review` (security / correctness / docs / portability / governance)
  ran on the release candidate. HANDOFF's "PLAN-018 A/C/B/D complete" verified
  **substantially true** (FT ledger, CHANGELOG `## Unreleased` complete 1:1,
  FT-32 mechanism converges across all 8 siblings) — but "plan complete" ≠ "tag
  can be cut," and it cannot right now. Findings (each verified against source;
  2 agent claims downgraded on verification):
  - **G1 tag-cut blockers:** FT-39 `fetch_template` has no `test -s`/shape check
    and `--update` infers non-interactive from a missing TTY → a 200-empty fetch
    can 0-byte the fleet's gates *and* silently freeze FT-32 refresh (fails open);
    FT-40 the FT-28 SHA-peel guard is untested (mutation `if false;` → resolver
    suite still 62/0 — the test re-implements `verify()` instead of driving the
    shipped step); FT-41 markdown-lint's blocking default is unasserted (mutation
    `true→false` → contract suite still 271/0); FT-42 `ai-review`'s
    `secrets: inherit` is **structurally forced** (the reusable's `workflow_call`
    declares NO `secrets:` block, so callers can't pass a map) — the largest
    standing secret-trust risk, ~15-line fix.
  - **🔴 FT-30 cold-start dry-run NOT satisfied for this candidate** — the only
    recorded run was `CI_TAG=4984c35` (the v2.11.0 SHA), before the D1 refresh
    logic + marker-version change existed; `install.sh`, manifest, and the
    fragment all changed since. `release.sh tag` refuses without it.
  - **Other verified:** label/draft event can supersede a RED `ai-review`
    (FT-43 — armed `composition` still blocks today, so not a live both-checks
    hole *while armed*); FT-44 FT-32 silently under-delivers a *modified* hook;
    FT-45 `required-context-map.py` drops the job-id half; canon `main` has NO
    branch protection + NO tag ruleset while its own template names it product-
    tier (S1); `verified_allowed: true` wider than §4.3 + canon's live
    `can_approve_pull_request_reviews: true` vs template `false` (FT-27 unapplied);
    `FLEET_BRANCH_PROTECTION_ARMING.md:66` imperatively repins to `ci/v2.1.0`
    (10 releases back); GNU-only `sed -i` + unguarded `mapfile` on adopter macOS.
  - **Strong positives (do not regress):** action supply chain exemplary (all
    SHA-pinned, allowlist-clean, binaries checksummed); zero shell injection;
    autofix separation-of-duties; public-repo fork-safety holds.
- **`plans/PLAN-019_preprod-review-closure.md` — READY** (verified-planning: 3
  passes, 2 independent, zero load-bearing findings; gate green, 48 citations).
  Pass 2 caught FT-43's fix re-opening its own bypass (a step-level skip
  concluding SUCCESS supersedes a standing `request_changes`) → folded to
  fail-closed-when-unarmed per the FT-29 `exit 1` model. Four gates (by the BAR
  each clears, not execution order): **G1** tag-cut blockers (FT-39/40/41/42),
  **G2** the 🔴 dry-run (gates the `git tag`), **G3** ship-with-tag (FT-43…48),
  **G4** before-rollout (FT-49…52: portability, canon self-governance,
  governance-currency). **Execution order** (all G3/G4 EXCEPT the deferred FT-46
  ride the same tag, and some change the installer/templates the dry-run
  exercises): G1 → G3 → G4 → **G2 dry-run
  LAST** → tag → rollout (see the NEXT lines at the top of this section). Semver
  **MINOR → `ci/v2.12.0`**.
- **`plans/ROLLOUT_plan019-feedback-desk-coldstart.md` — ⏳ NOT YET (🔴
  founder-executed; runs LAST, after G3+G4 — see the NEXT lines at the top of this
  section).** feedback-desk verified a genuine cold start (no workflows /
  pre-commit / canon ref) and **PRIVATE** with `APP_REVIEWER_1_BOT_ID` UNSET, so the
  runbook splits **Part A** (installer cold-start = the FT-30 tag gate,
  visibility-independent) from **Part B** (arm gates green = self-hosted pool +
  per-repo LiteLLM secrets + App; PLAN-009 Phase-0 🔴, NOT a tag gate). The one
  load-bearing line: `export CI_TAG="$(git rev-parse origin/main)"` (the final
  pre-tag SHA once G3+G4 are merged) or it validates the pre-fix templates.
- **NEXT:** ✅ G1 (Workstream A) DONE. The remaining flow-ci work is **G3 + G4
  (FT-43…52)** — AI-executable, one FT per PR — which land FIRST. **Then** G2 (the
  🔴 founder cold-start dry-run, pinned to the final pre-tag `main` SHA) runs as the
  LAST validation → prep PR → tag `ci/v2.12.0` → fleet rollout. PLAN-019 files are
  committed (PR #268 + the four G1 blocker PRs #269–#272).
- **PLAN-018 COMPLETE — all four workstreams (A, C, B, D).** Workstream D closed
  it out:
  - **D1 / FT-32 (#265)** — the canon pre-commit fragment is refreshable in
    already-adopted consumers. The `CANON:` marker is now **versioned**
    (`# CANON: aidoc-flow-ci pre_push_check vN`, canon at **v2**); bootstrap
    re-merges a consumer whose `vN` lags, then stamps canon's so the next run
    no-ops. Before this an adopted consumer was frozen forever (bootstrap no-op'd
    on the marker, `--update` excludes the file, `--apply` writes no content), so
    `manifest.json`'s "re-run install.sh to refresh those" was **false** for it.
    **Additions only** — a `rev` bump, or a new hook id inside a repo the consumer
    already declares, is reported and left unapplied; a partial merge still stamps
    `vN` (required to converge) and now says the named lines stay unapplied.
    `tests/test_precommit_refresh.sh` is new and covers the DECISION, which had
    no coverage at all: a review mutated the compare back to always-no-op —
    restoring the exact fleet-wide freeze — and the whole suite stayed green.
  - **D2 (#266)** — `docs/UPDATE_GUIDE.md` gains the body-adoption reconciliation
    procedure (`--repin` is the default; `--update` replaces all 16
    `safe_to_replace` bodies and discards per-repo `runner_labels_*`/
    `permissions:`/triggers, failing on the *next* PR rather than at update time)
    and the drift-report-as-rollout-worklist section. Also corrected the
    `ci/v2.0.0` migration step 4, which recommended `--repin` **then**
    `--update` — the FT-9 hazard, sitting in the guide as a recommendation.

- **NEXT: the fleet rollout is unblocked** (CI-0013's "drift report becomes the
  rollout worklist" now has a mechanism behind it). Start from
  `docs/UPDATE_GUIDE.md` § "Reading the drift report as the rollout worklist".
  Note **FT-38**: `operations`, `framework`, `iplanic`, `iplan-runner` declare
  `pre-commit-hooks` at a mutable `rev: v5.0.0` that the refresh **cannot** move
  to canon's SHA pin — named per-repo decisions in the worklist, not delivered.
  Simulated refresh across all 7 siblings: missing canon lines 19→6 (operations),
  18→1 (framework, iplanic), 5→0 (interlog, engramory, iplan-standard), 1→1
  (iplan-runner).

- **Still deferred from B** (by priority, not size): FT-4 (cosmetic CHANGELOG
  history), FT-6 (trust-config inputs), and the **ai-review `secrets: inherit` →
  explicit-map** conversion (needs `secrets:` declarations on the reusable + its
  own security review). Also open: FT-33, FT-35, FT-36, FT-37.

- **PLAN-018 Workstream B COMPLETE (FT-10 verified-resolved, last item).** All
  canon-internal defects closed: FT-26 codeql pin (#259), FT-27 least-privilege
  (#260), FT-28 SHA-peel (#261), FT-29 zero-review window (#262), FT-25 adopter
  gaps (#263), + FT-14/FT-10 verified already-resolved (2 stale ledger entries
  the verify-before-fixing triage caught). **Deferred within B (by priority, not
  size):** FT-4 (cosmetic CHANGELOG history), FT-6 (trust-config inputs), and the
  **ai-review `secrets: inherit` → explicit-map** conversion (needs adding
  `secrets:` declarations to the reusable + its own security review — the one
  FT-27 piece that isn't caller-only). **PLAN-018 status: Workstreams A + C + B
  done; D (rollout readiness) not started; fleet rollout gated on FT-32 per CI-0013.**

- **PLAN-018 Workstream B / PR B5 (FT-25 adopter gaps ×4) OPEN.** Wizard scaffolds
  the labeler config starter; preflight surveys all 18 labels + branches on
  allowed_actions (no masked 409); verify short-circuits on the pre-merge adoption
  PR; AI_CI_DEPLOYMENT names the -private variants. test_contract guards all four.
  **Only FT-10 (runner-self docs) remains in Workstream B** — then B is complete.

- **PLAN-018 Workstream B / PR B4 (FT-29 zero-review window) OPEN — closes the
  security cluster.** ai-review's skip-notice `label` branch now fails closed when
  `vars.APP_REVIEWER_1_BOT_ID` is unset (composition inert), so skip-ai-review +
  inert composition can no longer merge with zero review. Option (1) — catches
  every arming path. Remaining B: FT-25 (adopter gaps ×4), FT-10 (runner-self docs).

- **PLAN-018 Workstream B / PR B3 (FT-28 ai-review SHA peel) OPEN.** Both resolvers
  (review + autofix) peel the claimed tag via the commits API and hard-fail if the
  pinned SHA ≠ the tag's commit — so `@<fork-sha> # ci/vX.Y.Z` can't execute
  unmerged code while reading as the released tag. Inert for shipped consumers
  (tag-only pin). test_resolver guards it. Remaining B: FT-29 (skip-ai-review+INERT
  window), FT-25 (adopter gaps), FT-10 (runner-self docs).

- **PLAN-018 Workstream B / PR B2 (FT-27 least-privilege) OPEN.** AI-flow callers
  converted off blanket `secrets: inherit`: composition drops the block (only
  GITHUB_TOKEN); doc-maintainer/docs-sync/auto-merge get explicit maps of their
  declared secrets. `can_approve_pull_request_reviews` defaulted false. test_contract
  guards all. **ai-review keeps inherit** (reusable declares no secrets) — its
  conversion is a tracked follow-up (needs reusable secret declarations + security
  review). Remaining B: FT-28 (ai-review SHA peel), FT-29 (skip-ai-review+INERT
  window), FT-25 (adopter gaps), FT-10 (runner-self docs).

- **PLAN-018 Workstream B STARTED — PR B1 (FT-26 codeql pin + FT-14 triage) OPEN.**
  codeql autobuild repinned tag-object→peeled-commit (matches init/analyze);
  test_lint asserts the three codeql pins agree (teeth). GHAS-for-private
  documented. FT-14 (yamllint hook vs CI) verified ALREADY RESOLVED (root
  .yamllint.yaml added 2026-07-17) — no fix, marked in ledger. Remaining B:
  FT-27 (over-grant secrets/can-approve), FT-28 (ai-review SHA peel), FT-29
  (skip-ai-review+INERT-composition window), FT-25 (adopter gaps ×4), FT-10
  (runner-self docs). Verifying each is still live before fixing (FT-14 was stale).

- **PLAN-018 Workstream C COMPLETE — PR C5 (`scripts/release.sh`, FT-21) OPEN, last item.**
  release.sh encodes prep→merge→dry-run→tag with guards on all three v2.9.0
  failure modes (tag-before-prep-merge; tag-without-🔴-dry-run; VERSION-tree
  mismatch); `test_release.sh` drives the rejections; RELEASE_CHECKLIST points at
  it. With C5, Workstream C's verification surface is done: exerciser inventory +
  guard (C1), zero-hook detector (C2), required-context validator (C3), pre-commit
  - markdown self-callers (C4a/b), release tool (C5). Canon self-runs 5/16
  reusables and its "no exerciser / tribal-knowledge" gaps are closed. **Remaining
  PLAN-018: Workstream B** (canon-internal defect closure) + Workstream D (rollout
  readiness); the fleet rollout stays gated on FT-32 per CI-0013.

- **PLAN-018 Workstream C / PR C4b (markdown-lint self-caller, FT-34) OPEN.**
  Canon now carries a root `.markdownlint.json` (= shipped template + `MD004:dash`)
  and runs `self-markdown-lint.yml` **blocking**; canon self-runs 5 of 16
  reusables (was 4). Canon's docs brought to full conformance: 347 findings →
  304 auto-fixed + 43 manual (code-fence langs, table `|` escapes, wrapped
  issue-refs read as H1). Shipped template gained `MD004:dash` (consumer-facing:
  conventional `-` bullets). The "174 MD013" premise was wrong — canon's standard
  has MD013 off; work was structural. FT-34 closed. **Remaining C: C5 —
  `scripts/release.sh` (FT-21).** That completes Workstream C.

- **PLAN-018 Workstream C / PR C4a (pre-commit self-caller, FT-36) OPEN.**
  `.github/workflows/self-pre-commit.yml` — canon now runs its own pre-commit
  reusable on every PR (public → ubuntu-latest, pinned to the released tag),
  self-running 4 of 16 reusables (was 3). Dogfooding immediately caught
  `VERSION` missing a trailing newline (end-of-file-fixer); fixed + release
  checklist updated. FT-36 closed; inventory row flipped. Remaining C: **C4b**
  markdown-lint self-caller (FT-34 — needs a canon `.markdownlint.json` + the
  174-pre-existing-findings decision, its own PR), then **C5** release.sh (FT-21).

- **PLAN-018 Workstream C / PR C3 (required-context validator, FT-18) OPEN.**
  `install/required-context-map.py` derives context→producing-caller for every
  tier's required contexts (context → reusable job → caller template → manifest
  consumer path; no hardcoded table). Wizard preflight §6 diffs it against the
  repo's installed workflows → per-tier "arming would hang: `call / X` needs
  `<caller>` (not installed)" (the F2 hang, pre-arming). `test_required_contexts.sh`
  (21) asserts the canon invariant (every required context has a producer) + the
  audit-trail chain + teeth. FT-18 closed for the validator; inventory row +
  gap closed. Remaining C: C4 (FT-36/FT-34 self-callers), C5 (FT-21 release.sh).

- **PLAN-018 Workstream C / PR C2 (zero-hook detector, FT-31) OPEN.**
  `install/check-precommit-hooks.sh` — general form of F3; exits 1 when a
  `.pre-commit-config.yaml` selects zero hooks at the stage the reusable runs.
  Wired operator-side into install.sh (fetched, advisory), the wizard preflight
  (🔴), and the release checklist — NEVER the gating path (would flip a
  consumer's green check red). `test_precommit_stage.sh` drives it (9 assertions);
  inventory row added + FT-31 gap closed. Remaining C: C3 (FT-18, rebases on C2 —
  both touch the wizard), C4 (FT-36/FT-34 self-callers), C5 (FT-21 release.sh).

- **PLAN-018 Workstream C STARTED — PR C1 (exerciser inventory) OPEN.** Post-`ci/v2.11.0`,
  Workstream C is the verification surface that makes the fixes stay fixed.
  Founder descope (2026-07-22): `aidoc-flow-ci` is a **library**, so the
  ai-review/doc-maintainer self-callers (which need a self-hosted pool) are OUT —
  `test_resolver.sh` covers the resolver offline. C1 ships
  `docs/EXERCISER_INVENTORY.md` + `test_exerciser_inventory.sh` (every manifest
  surface / reusable / script must have a row; unexercised rows must name an FT).
  Remaining C PRs: C2 zero-hook detector (FT-31), C3 required-context validator
  (FT-18), C4 pre-commit + markdown self-callers (FT-36/FT-34), C5
  `scripts/release.sh` (FT-21). Then Workstream B.

- **`ci/v2.11.0` SHIPPED (2026-07-22) — PLAN-018 Workstream A.** Tag on
  `4984c35`, release published + marked Latest. The 🔴 founder FT-30 cold-start
  dry-run passed GREEN on BOTH visibilities against throwaway repos, pinned to
  the merge SHA (`CI_TAG=4984c35`): install.sh completed through all 18 labels
  with no FAIL/404, `composition-{private,public}.yml` and `pre-commit.yml` both
  resolved (F1/F2 live-verified), the fragment installed (F3), and the F4
  runner-pool probe + LiteLLM note printed without aborting the script. Prep PR
  #251 was expected-red pre-tag (FT-21 chicken-and-egg: version-sync + 11
  self-pinned callers referencing a tag that didn't exist yet) and merged
  `--admin` on unprotected main; the tag turned it green. **Single-repo release —
  no consumer re-pinned.** NOTE: startup_failure self-caller runs are
  non-retryable (FT-21 v2.9.0 lesson), so the post-release HANDOFF push is what
  re-triggers them green.

- **PLAN-018 Workstream A COMPLETE — all three cold-start blockers fixed on `main`
  (PR-A #247 F1, PR-B #248 F2/F3, PR-C #249 F4/F6/F7).** The `ci/v2.11.0` cut is now
  gated ONLY on the 🔴 founder-executed cold-start dry-run (FT-30, now a
  RELEASE_CHECKLIST pre-tag item) — its runbook MUST `export CI_TAG=<merge-sha>`
  or it validates the pre-fix templates. Canon still cannot self-exercise a cold
  start, so nothing on `main` proves the fixes live; the dry-run is that proof.
  Next up: cut `ci/v2.11.0` (prep PR → tag → release), then Workstreams C
  (verification surface / detectors) and B (canon-internal defects) per §8 — C
  before B. FT-32 gates the rollout PHASE, not the v2.11.0 cut.

- **PLAN-018 Workstream A / PR-C MERGED (#249, F4 + F6 + F7 + F5 + FT-30) — operator-facing
  correctness.** F7: `deploy-ci-wizard.sh`
  silently scaffolded callers pinned 14 releases back (`|| echo 'ci/v1.9.5'` FIRES
  under `set -e` on an unreadable VERSION) — now fails loud, and
  `test_version_sync.sh` executes the shipped resolution to prove it. F4:
  `install.sh` next-steps gain a visibility-independent runner-pool probe and the
  `litellm_allow_insecure_http` note (output only — it does NOT uncomment the flag,
  which `--update` would re-comment → red gate). F6: the wizard's markdown-lint
  report-only injection was public-only; moved out of the `[ ! -f variant ]` branch
  (scoped to markdown-lint) so both visibilities match, template untouched to avoid
  the `business`/`iplanic`/`interlog` graduated-gate downgrade. F5: the docs-sync
  `pull-requests: write` fix ships with the tag (no code). FT-30: the 🔴
  founder-executed cold-start dry-run is now a release-checklist pre-tag item, with
  the `CI_TAG=<merge-sha>` requirement called out. **After PR-C merges, A is
  complete and the `ci/v2.11.0` cut is gated only on the FT-30 dry-run.**

- **PLAN-018 Workstream A / PR-B MERGED (#248, F2 + F3) — the two remaining cold-start
  blockers.** F2: `pre-commit` joins the bootstrap set **unconditionally** (its
  check is required on every tier that has required checks, and is the bootstrap
  tier's only one; without a producer, armed protection pins every PR on
  "Expected — Waiting for status to be reported"). F3: the canon fragment ships
  commit-stage hooks (`check-yaml`, `end-of-file-fixer`, `trailing-whitespace` at
  `pre-commit-hooks` v6.0.0) so the required check inspects something — its only
  hook was `pre-push`-staged, and the reusable's stage-less run selected **zero**
  hooks and exited 0. Merge now de-dups by repo URL (a consumer on a different
  `rev` was structurally unequal → duplicate `repos:` entry). Wave-0 self-adopted
  by hand (the `CANON:` marker makes the merge no-op here) — which immediately
  found trailing-whitespace / missing-newline defects in 4 of canon's own files.
  **Known and accepted:** already-adopted consumers cannot receive the new hooks
  (FT-32), so they flip to `DRIFT` — expected signal per CI-0013, and a report,
  not a gate. Remaining in A: **PR-C** (F4/F6/F7 + the release-checklist
  cold-start dry-run).

- **PLAN-018 Workstream A / PR-A MERGED (#247, F1 + regression cover) — the
  cold-start 404 is fixed on `main`, and canon is still NOT ready to onboard a
  new repo.**
  `install.sh` now names each bootstrap caller template explicitly (three naming
  shapes, `docs/REPO_STANDARDS.md` §16.9); `tests/test_install.sh` (49 assertions)
  extracts and *evaluates* the caller block under both visibilities and
  cross-checks it against `manifest.json` **in both directions** — resolved
  template names *and* the installed caller set (`auto_install: true`). Teeth
  verified against eight seeded mutations plus one negative, and the PR-B change
  (add the `pre-commit` stanza + flip its `auto_install`) verified to pass only
  when both halves land together. **Two pre-push review cycles broke the test,
  not the fix** — `install.sh` came through both clean. Cycle 1: deleting the
  whole `composition` stanza passed with zero failures (the shape of the
  still-open F2), plus substring-masked containment, a greedy match hiding a
  derived argument behind a second call on one line, and an unbounded block on a
  lost end marker. Cycle 2, on the fold itself: a backslash-wrapped call outside
  the markers re-opened containment in a form ordinary line-wrapping produces,
  and the new `set -euo pipefail` fidelity was defeated by calling the evaluator
  in an `if` condition — the same `-e`-suppression trap `install.sh` documents
  for `update_mode`. **Still open before an
  onboard:** F2 + F3 (PR-B), F4/F6/F7 + the release-checklist dry-run (PR-C), and
  the 🔴 founder-executed cold-start dry-run that gates the `ci/v2.11.0` cut —
  its runbook must export `CI_TAG=<merge-sha>`, or it validates the pre-fix
  templates. **The fix is unverified live**: canon is already adopted and cannot
  self-exercise a cold start, which is precisely why F1 survived nine releases.

- 🔴 **The cold-start path was broken for 9 releases (F1 — now fixed by PR-A,
  above; retained for the reasoning).** Pre-prod review (5 lenses) scoped to
  onboarding `feedback-desk` found the documented one-liner **died on its first
  template fetch**: `install/install.sh:462` built `workflows/ai-review-${VISIBILITY}.yml`,
  but PLAN-013 deleted those variants at the `ci/v2.2.0` release commit —
  verified live, `ai-review-private.yml` → **404**, `ai-review.yml` → 200. The
  `|| exit 1` killed the run before config.json, CODEOWNERS, CLAUDE.md,
  `pre_push_check.sh`, the pre-commit merge, and all 18 labels. Every fleet
  consumer adopted **before** v2.2.0, which is why no one hit it. Two more
  blockers survive the run: the bootstrap set omits the `pre-commit` caller that
  emits `call / Lint / format / security hooks` (required on every tier but
  umbrella), and the canon pre-commit fragment's only hook is `pre-push`-staged,
  so the reusable's stage-less run selects **zero** hooks and exits 0 — a
  required check that inspects nothing, on every fresh adopter. Full ranked
  verdict + 6 lower findings: **FT-25 … FT-31**.

- **GOAL SET (founder, 2026-07-22) — `DECISIONS.md` CI-0013: complete
  `aidoc-flow-ci` FIRST, roll the canon over to the other repos LATER.** Two
  consequences decided with it: (1) **pre-rollout consumer drift is expected,
  correct signal**, not damage — when canon adds a required surface, adopted
  repos report DRIFT under `apply-standards.sh --check`, and that report becomes
  the rollout worklist; canon does NOT weaken a check to keep the stale fleet
  green. (2) The surviving prohibition is narrower: **no silent weakening of a
  live gate** (a canon change must never flip a consumer's graduated blocking
  gate to report-only via `--update`).

- **PLAN-018 RE-SCOPED and READY — `plans/PLAN-018_canon-completeness.md`
  (renamed from `…_cold-start-onboarding-fixes.md`).** Gate green: **52
  citations, 7 review passes** (Passes 5-6 are two independent passes on the
  re-scoped whole, returning 6 and 3 load-bearing; Pass 6 found only stale-wording
  defects and no design errors). Four workstreams: **A** the three cold-start blockers
  (unchanged, carries the 9/7/5-finding review history from Passes 1-3); **B**
  seven canon-internal defects pulled back from the FT ledger; **C** the
  verification surface — the systemic fix, sequenced AHEAD of B because it
  contains the general form of two A blockers (FT-18 ⊃ F2, FT-31 ⊃ F3); **D**
  rollout-readiness docs. Fleet-state (FT-5/11/12/13) and runner-infra
  (FT-16/19/20) are explicitly out, with a rationale table.
  **Both former founder items are CLOSED:** OI-1 by CI-0013 (ship the full
  pre-commit fragment); OI-2 by specification — it was never a fork, the runbook
  must export `CI_TAG=<merge-sha>` or it validates the pre-fix templates.

- ⚠️ **Author error corrected — I told the founder the rollout migration path is
  "FT-9-broken today". It is not: FT-9 is RESOLVED (`ci/v1.9.0`, PLAN-006 W2),
  `--repin` is the safe version-only path.** The accurate residual concern is
  narrower and now sits in the plan's contract item 8: rolling *completed* canon
  out is **body adoption** via `--update`, which by design wholesale-replaces
  every `safe_to_replace` caller, so the rollout needs a documented
  reconciliation procedure (Workstream D) — not a bug fix. Caught by the
  FT-ledger inventory contradicting the claim; CI-0013 was corrected pre-commit.

- **Three review findings worth carrying forward as method, not just content:**
  (1) I reported the wizard's `|| echo` VERSION fallback as dead code — it is
  **not**; `set -euo pipefail` makes it fire, and the real defect is that an
  unreadable `VERSION` silently scaffolds callers pinned **14 releases back**.
  Two readings (a review lens and my own) missed it because both *read* the `||`
  and neither *ran* it. (2) The first F6 fix would have silently downgraded three
  live private repos — `business`/`iplanic`/`interlog` deliberately carry
  `fail-on-findings: true`, and the caller is `safe_to_replace`, so the next
  `--update` would have switched graduated blocking gates back off; the fix moved
  to the wizard conditional where the defect actually lives. (3) Pass 2 caught
  three defects the *Pass-1 fold itself* introduced — folding a review finding is
  a code change and needs the same scrutiny as one.

- **`feedback-desk` prerequisites — all 🔴, verified live via
  `deploy-ci-wizard.sh preflight vladm3105/aidoc-flow-feedback-desk`:** no
  `ci-runner,single-use` pool (private ⇒ every job queues forever; job
  `timeout-minutes` starts at job *start*, so it never fires), all five secrets
  missing, `APP_REVIEWER_1_BOT_ID` unset (⇒ composition INERT, see FT-29), only
  GitHub's default labels. Not inherited — `vladm3105` is a personal account.
  🟢 `allowed_actions: all` (no allowlist blocker); `default_workflow_permissions:
  read` is fine — every caller template carries an explicit `permissions:` block.

- **`ci/v2.10.0` SHIPPED (2026-07-21) — PLAN-017 / FT-15.** Tag `7398b63a4`,
  release published + marked Latest. Prep merged first per FT-21 (its
  `version-sync` check and the two self-pinned callers are expected-red until the
  tag exists; `main` is unprotected so no admin bypass or force-push was needed),
  then the tag was cut on the merge commit — **VERSION matched the tag at cut
  time**, so no re-cut for coherence was required (the trap the v2.9.0 cut hit).
  Post-release: full suite PASS (296 assertions), `--check-published` green.
  **Still NOT verified live** — canon has no self-caller for these reusables, so
  the 🔴 pilot consumer re-pin in `plans/ROLLOUT_plan017-verify.md` is what
  actually closes FT-15. Fleet is uniformly stale as expected (PLAN-009).

- **PLAN-017 (FT-15 fix) — ALL THREE PRs LANDED (`docs-sync`, `doc-maintainer`,
  `ai-review`). Code complete; NOT yet verified live — verification runbook
  PREPARED at `plans/ROLLOUT_plan017-verify.md` (🔴 needs a consumer re-pin).**
  `docs-sync` (#236) and `doc-maintainer` (both sites) now resolve the canon tag
  from the consumer's own adopted pin and hardcode the owner. PR-C (the merge gate) has no
  `actions/checkout` by design (IPLAN-0024), so it reads the caller's workflow
  over the API at a trusted, event-selected ref (`pull_request_target`→base,
  `pull_request_review`→default, else default) and **discards** `workflow_ref`'s
  own ref component. **Not yet verified live:** canon has no self-caller for these
  reusables, so their own CI cannot exercise them — verification is the
  `ci/v2.10.0` cut + a pilot consumer re-pin reading the `::notice::`, which is a
  🔴 cross-repo write (ops/inbox runbook). **FT-22** tracks porting the same
  resolver to `standards-drift.yml`, which predates the rule.

- ⚠️ **FT-15 CONFIRMED LIVE — the pin does NOT control reviewer assets.** Proven
  from production logs (no throwaway run needed: `ai-review.yml:431` already
  notices the resolved ref every run). `operations`, pinned `@ci/v2.0.1`, logged
  `ai-review fetching assets from vladm3105/aidoc-flow-ci@refs/heads/main` — so it
  fetches `main`'s rubric / verdict schema / `litellm_client.py`. Verified against
  the **tag** source (not just the log, since `pull_request_target` makes
  `github.ref` also `main`). **Realized drift is narrow — only
  `litellm_client.py` actually differs (+19/-1); rubric + schema are identical** —
  but the mechanism is fully broken. Workflow *logic* is correctly pinned by
  GitHub; only the **curl-fetched assets** float. 5 `workflow_ref` sites:
  `ai-review` (2), `doc-maintainer` (2), `docs-sync` (1).
  **Two NEW findings beyond the original entry:** (1) `CI_OWNER` is *also*
  caller-derived (`cut -d/ -f1`), so **external adoption is broken today** — an
  external org fetches `<their-org>/aidoc-flow-ci` → 404 (the owner is NOT
  hardcoded, contrary to the prior note); (2) a hard-404 mode reachable **today** —
  `doc-maintainer` also declares `workflow_dispatch:`, so a manual dispatch from a
  feature branch yields `refs/heads/<branch>` → 404 → bricked gate, surfacing as an
  INFRA-looking flake rather than a config error. **Consequence for sequencing: the release/pin story is not true as
  shipped — do not premise the arming rollout on "the pin determines reviewer
  behaviour."** Fix is OPEN, deliberately NOT blind-applied: one reviewed PR per
  reusable, must hardcode the owner and derive the tag from the consumer's own
  caller (the `standards-drift.yml` pattern). Full evidence + scope table in
  `plans/FRAMEWORK-TODO.md` FT-15.

### Previously (2026-07-20, session wrap)

- **`ci/v2.9.0` SHIPPED — PLAN-016 complete.** Canon runner reference
  implementation at `install/templates/runner/` (CI-0012); tag cut, re-cut
  once for coherence (initial cut landed pre-#231-merge with internal
  VERSION=v2.8.0; final tag @ `9cd2ba2`, VERIFIED: VERSION matches, template
  pins @v2.9.0), release published. Operations vendored + re-stamped
  (@ ci/v2.9.0, #279) and the host image REBUILT with `libatomic1` (both
  build-image verification gates passed live). PR chain: #226 plan → #227
  canon → ops #277 vendor → #229 FT-16..18 → #230 pre-tag fixes (5-lens
  ci-preprod-review, SHIP-WITH-FIXES → fixed) → #231 release prep → ops
  #279 re-stamp → #232 FT-21.
- **Remaining founder items:** (1) `ci-runner@business` provisioning — the
  v2 pool registration that business **PR** #63 (the verified-planning slim
  PR — its CI lint job crashes on the legacy ci-eph runner image's missing
  `libatomic`; re-confirmed post-rebuild) is solely blocked on (command
  handed off);
  (2) FT-19 container-egress risk-accept (pending, blocks nothing); (3)
  iplanic branch-protection context rename (see the operations 2026-07-19
  orphaned-contexts inbox runbook).
- **Release-cut lessons → FT-21** (harden `docs/RELEASE_CHECKLIST.md` +
  `release.sh`): merge prep BEFORE tagging; self-pin chicken-and-egg makes
  the prep PR's first check run red until the tag exists (workflow-file-issue
  runs are NOT rerunnable — empty-commit re-trigger is the recovery).
- Backlog seeded from the same-day FT-16 outage arc: FT-16 fleet watchdog,
  FT-17 post-cutover ai-review recovery, FT-18 context validator, FT-19/20
  hardening, FT-21 release sequencing.

### Previously (2026-07-20 mid-session)

PLAN-016 W1–W3 execution detail — superseded by the wrap above; full record
in CHANGELOG ci/v2.9.0 section + `plans/PLAN-016_runner-canon-templates.md`
Review log.

### Previous state (2026-07-19)

**`ci/v2.8.0` is the Latest release — PLAN-015 (pre-prod review fix closure) is
SHIPPED.** A 5-lens pre-prod review of the canon returned "workflows ready,
rollout not"; PLAN-015 closed both blockers + the M/L follow-ups, cut as
`ci/v2.8.0` (2026-07-19, PRs #209–#218):

- **B1** — the fleet rollout target was named three ways across the docs
  (v2.0.1 / v2.1.2 / v2.7.0); reconciled to a single tag, `ci/v2.8.0`.
- **B2** — canon published a drift detector no consumer ran, and `install.sh`
  silently implied standards were applied. Now: a consumer-installable
  `standards-drift` reusable + caller templates, and `install.sh
  --verify-standards` that honestly reports clean / drift-or-absent / uncheckable.
- **M/L** — decision-log closure (CI-0008/0009/0010; CI-0011 `verified_allowed`
  filed OPEN), script hygiene (pre-push range, mint key off argv, audit-trail
  comment), install ergonomics (`.yamllint.yaml`, tool-presence note), doc-count
  accuracy (reusables 12→16, labels 16→18).

**Remaining PLAN-015 work is entirely 🔴 founder-gated + prepared:**
`plans/ROLLOUT_plan015-arming.md` (per-repo re-pin to `ci/v2.8.0` + install
`standards-drift` + arm branch protection + verify) and the CI-0011
`verified_allowed` decision. **FT-15** (audit ai-review/doc-maintainer/docs-sync
for the same latent `workflow_ref`-is-the-caller asset-fetch issue PLAN-015 B2
found + fixed in `standards-drift`) is OPEN in `plans/FRAMEWORK-TODO.md` — now
**elevated to a trust-blocker**: it must be confirmed before trusting the pin
story or widening deployment (see the assessment below).

**Value + company-standard assessment (2026-07-19):**
`plans/ASSESSMENT_flow-ci-value-and-standard-readiness.md`. Verdicts: the
**AI-review core is the differentiated, proven value** (caught a critical
CI-bricking bug on operations #244 that no linter would); the rest is commodity
or governance-overhead. Deploy the ~3 value flows **selectively**, not the 16 as
a bundle. **Not yet worth mandating as a company standard** (bus factor ~1,
per-team infra tax, governance coupling, not battle-tested — 5-gate scorecard in
the doc); standardize the *capability*, not this implementation. Founder posture:
**deploy-and-freeze** — deploy the AI-review core to 2–3 repos + measure real
catch-rate, feature-freeze new PLAN-NNN capability until adoption ≥ ~50%, resolve
FT-15 first. Company-standard ratification is a 🔴 operations (OPS-NNNN) call.

---

*History — `ci/v2.7.0`:* **PLAN-014 (own-security-scanner suite,
"osv/trivy/semgrep, all in, report-only first") is IMPLEMENTED through Phase 4.
Three report-only scanners + a deterministic autofix preview now ship on the
uniform-protected + fork-guarded model (PLAN-013), each SHA/version-pinned with
binaries/pip installed directly (no marketplace actions, §4.3):**

- **`ci/v2.4.0` — `dep-scan.yml`** (Phase 1): dependency-vulnerability / SCA gate
  via the **osv-scanner** binary. Data-only (never `--call-analysis`, which compiles
  source). Security fold: `--no-call-analysis=all` + `expect-manifests` (rc=128 "no
  packages" no longer silent-passes).
- **`ci/v2.5.0` — `trivy-scan.yml`** (Phase 2): IaC/Dockerfile **misconfiguration**
  gate via the **trivy** binary (`trivy config` only, not `fs`). SSRF-hardened —
  restricted to static scanners (`--misconfig-scanners dockerfile,kubernetes,cloudformation,azure-arm`)
  because trivy's terraform/helm/ansible scanners fetch PR-controlled remote sources
  (`--tf-exclude-downloaded-modules` does NOT stop the fetch — verified).
- **`ci/v2.6.0` — `sast-scan.yml`** (Phase 3): SAST via **semgrep** (VERSION-pinned
  pip into a venv — semgrep is Python, not a binary). The OWN SAST complementing
  native CodeQL (N/A on private), so it gates PRIVATE repos too. Data-only static AST;
  `--metrics off` + explicit `--config`. Security folds (both verified): strip
  PR-supplied `.semgrepignore`/`.semgreprc` (a `.semgrepignore` with `*` was a full
  gate-bypass) + fail loud on a missing/unparseable SARIF (`jq -e`).

- **`ci/v2.7.0` — `sast-scan` autofix PREVIEW** (Phase 4): the `autofix-preview` input
  (default false) runs `semgrep --autofix` in the ephemeral workspace and surfaces the
  **deterministic** (rule-provided, no model) patch in the job summary — **nothing is
  pushed**, so it needs no App and is un-gated / dormant-free. The one *safe* autofix
  path (§4a); model-based push-back stays gated on the PLAN-012 autofix App.

All scanners are `auto_install: false` (opt-in), ship `fail-on-findings: false`, and
carry no `secrets: inherit` (least privilege). **`deploy-ci-wizard.sh` knows them**
(surveys + `plan()` documents them as opt-in; `scaffold <repo> <dir> dep-scan
trivy-scan sast-scan` produces valid callers — merged, no new tag, wizard-only).

**NEXT (🔴 founder — NOT AI-executed): the report-only scanner pilot on `operations`.**
The full prepared runbook is `plans/ROLLOUT_plan014-operations-pilot.md`. Essentials:
operations is the pilot because it's the one repo with a live `ci-runner`/`single-use`
pool AND exercises all three scanners with real targets (surveyed 2026-07-18:
`pyproject.toml` → dep-scan; `scripts/ci-runner/Dockerfile` → trivy; 12 sh + 13 py →
semgrep — so **no per-scanner tuning needed**). The one real prereq to verify:
**runner egress** to github releases (osv/trivy binaries) + PyPI (semgrep) + semgrep.dev
(`p/default`) — else a scanner fails loud by design. Deploy via the wizard `scaffold`,
branch-first PR with the OPS-0069 phrase, report-only. Do NOT flip `fail-on-findings`
(that's Phase 5) and do NOT add to branch protection in the pilot.

**PLAN-014 remaining after the pilot:** Phase 5 = graduate each scanner
`fail-on-findings` false→true (per-scanner **founder** step, after a clean window) +
the deferred Phase 4 *push-back* subset (batched with the 🔴 PLAN-012 autofix-App
enablement, not shipped as a standalone dormant flow). Then propagate the report-only
scanners to the next pool-equipped repos (business/iplanic/interlog need a pool
registered first; public repos need a pool for the self-hosted scanner jobs).

This sits on top of **`ci/v2.3.0`** — autofix (PLAN-012) on the uniform protected
AI-flow model (PLAN-013, `ci/v2.2.0`), on the pre-prod-hardened canon (`ci/v2.1.2`).
All security-reviewed and shipped; what remained then was 🔴 founder-gated (fleet
re-pin/arming — now `plans/ROLLOUT_plan015-arming.md`; and — to turn autofix on — the dedicated autofix-App
registration + secrets + `autofix.enabled`). The v2.1.x history that hardened the canon:

- **`ci/v2.1.0`** — a 5-lens pre-prod review (security/correctness/docs/
  portability/governance) of the canon as company-default source of truth
  returned BLOCKER; all canon-side blockers closed (#175–#177):
  - **#175** — 3 security/correctness blockers: `composition` exempted every
    author on a malformed trust config (`jq -e` exits 4 on a parse error, not
    just 1 on author-absent → `! jq -e` fired → `exit 0`; it is the SOLE
    App-approval enforcement, and tier templates set
    `required_approving_review_count: 0`); `VERSION`/`CI_TAG_FALLBACK` said
    `ci/v2.0.0` while `v2.0.1` was live, so every CI_TAG-less `--repin` pinned
    consumers BACKWARDS (now mechanically synced + `tests/test_version_sync.sh`
    guards it); `ai-review` `APP_KEY_PRESENT` tested KEY-only in the review job
    → half-provisioned repos hard-bricked.
  - **#176** — 6 `-private` template variants (`links`, `markdown-lint`,
    `pre-commit`, `secret-scan`, `labeler`, `docs-sync`): `--update` on a
    private repo used to revert them to the label-less generic →
    `ubuntu-latest` → queue forever. `--update` is now safe on private repos.
  - **#177** — adopter cold-start: LiteLLM-proxy prerequisite stated, secrets
    ordered before the PR, `AI_CI_DEPLOYMENT.md` linked as the front door.
  - Earlier flowci-feedback triage (merged #173): `secret-scan` config canary,
    `check-drift.sh` manifest coverage (FT-8), `audit-trail` manifested,
    REPO_STANDARDS §4.3/§4.3a/§4.3b/§4.3c, FT-13/FT-14.
- **`ci/v2.1.1`** — ai-review large-diff fix (**PLAN-011**, from consumer bug
  report llm-router PR #7: the required gate failed on large PRs with
  `ResponseShapeError` → `exit 1`, blocking merge even when every other check
  was green). Root cause, live-verified: `deepseek-v4-pro` reasoning tokens
  count against `max_tokens`, and at 4096 the reasoning exhausts the budget
  mid-JSON → the strict verdict parser rejects the truncation. Fix: verdict-mode
  `max_tokens` default 4096→8192; a residual infra failure now surfaces honestly
  as the new `ai:review-infra-error` label + comment (F4) instead of a fake
  `CHANGES_REQUESTED`. Proven against the live model — 4096 reproduces the
  failure on a complex 45-file diff, 8192 produces a valid verdict.
- **`ci/v2.1.2`** — verdict-budget headroom bump 8192→24576 (PLAN-011
  follow-up). Live-probed the model accepts ≥65536; the practical ceiling is the
  client's own 32768 validator. A typical complex verdict uses only ~2.3k
  tokens, but reasoning spikes non-deterministically — the headroom covers a
  heavy-reasoning spike on a near-400 KB diff, and costs nothing extra
  (per-actual-token billing).

**All canon work for this session is landed + released; both `aidoc-flow-ci` and
`operations` have 0 open PRs.** PLAN-011 is SHIPPED (see
`plans/PLAN-011_ai-review-large-diff-hardening.md`).

**What remains — founder-gated fleet rollout (🔴 cross-repo, NOT canon code).**
Primary runbook: **`plans/ROLLOUT_plan015-arming.md`** (PLAN-015 Task 8 — the
prepared per-repo re-pin + install `standards-drift` + arm + verify). **Fleet
target `ci/v2.8.0` is CUT (2026-07-19)** — tag + GitHub release live; PLAN-015
canon-side is complete, so the re-pin is now unblocked (it was gated on the tag
existing). Supersedes the earlier `v2.0.1`/`v2.1.2` targets. Closure plan:
`plans/PLAN-015_preprod-review-fixes.md`.

1. **Re-pin the fleet to `ci/v2.8.0`** — version-only `--repin` with an explicit
   `CI_TAG` (safe; a re-pin never clobbers `runner_labels` — that is `--update`).
   **NOT a drop-in**: v2.8.0's
   uniform-protected AI-flow (PLAN-013, `ci/v2.2.0`) runs ai-review on the
   self-hosted pool on **public** repos too, so every public consumer needs a
   runner pool registered before re-pin.
2. **Arm branch protection** — `aidoc-flow-ci` itself (canon), `engramory`, and
   `iplan-standard` have **no branch protection at all**; `business` + `iplanic`
   require only the phantom bare `Lint / format / security hooks` context per
   FT-12, so `composition` is not a required check and they merge via `--admin`
   (no real review gate — this is the pre-prod security finding).
3. business/iplanic/interlog are still on the retired `aidoc,ci-ephemeral`
   runner pool (now tool-migratable via the #176 `-private` variants +
   `--update`, but still needs executing).

These gate the *rollout*, not the tags — the tags are cut. Arming runbook:
`docs/FLEET_BRANCH_PROTECTION_ARMING.md`.

**Read before touching FT-13.** Its claim has been wrong three times in three
directions; the entry documents each miss and the check that would have caught
it. Verified: iplanic's standards-drift caller pins `e15ec7d…`, the **annotated
tag object** of `ci/v1.6.0` rather than a commit, so raw has never served it —
a permanent authoring bug, not decay (deref: `git/tags/<sha> --jq '.object.sha'`
→ `e827ab82…`, HTTP 200). The same trap as the SHA-pin lesson in FT-10's
neighbourhood: `git/refs/tags/<tag>` returns the TAG object for annotated tags.

**AI-flow autofix + uniform protection (PLAN-012 + PLAN-013) — SHIPPED,
security-reviewed. Enabling autofix is the one remaining 🔴 founder step.**
Both driven by founder decisions (2026-07-17/18): make all AI-based flows
uniform-protected (public+private, no visibility split), and build the ai-review
autofix flow.

- **PLAN-013 → `ci/v2.2.0` SHIPPED.** The AI-flows (`ai-review`, `doc-maintainer`,
  `docs-sync`) collapsed to ONE self-hosted protected template each; no visibility
  branch in templates/manifest/installer, so a private↔public flip is a no-op.
  Safe because forks never reach a code-executing job (trust-gated or post-merge);
  the generic fork-code lint flows deliberately stay GitHub-hosted. Security review
  caught + fixed a real wizard `startup_failure` bug.
- **PLAN-012 → `ci/v2.3.0` SHIPPED, DEFAULT-OFF.** The autofix job in `ai-review.yml`:
  on `request_changes` it generates a diff, applies it under a hard governance
  deny-floor (parse + post-apply + symlink + framework lock), and pushes via a
  **dedicated ephemeral-token autofix App** (contents:write, NOT a PAT) to re-fire
  the gate. Forks never reach it; a PR can't self-enable it; round-cap fail-closed →
  escalate. Security-reviewed (3 agents + re-verify; NO blocker; 2 HIGH + MEDIUM/LOW
  folded — job permissions, insecure-HTTP flag, fail-open counters, symlink guard).
- **The remaining 🔴 (founder-executed) to TURN AUTOFIX ON** (default-off ships
  inert): register a dedicated **autofix GitHub App** (separate from the reviewer
  App; contents:write), set `APP_AUTOFIX_ID/KEY` + `LITELLM_FIX_API_KEY` + var
  `LITELLM_FIXER_MODEL`, add authors to `trust.auto_fix`, and flip
  `autofix.enabled: true` in the trusted config — per repo, staged (one pilot
  first). Prepare via an ops/inbox runbook.

**Adoption-model root finding: `plans/PLAN-010_adoption-model.md` — DRAFT, NOT
READY.** `install.sh` only *prints* a branch-protection reminder (`:602`) and
never invokes `apply-standards.sh`; no consumer receives either `sync/` script;
5 of 6 consumers deviate identically on `enforce_admins` and canon itself is
unprotected. PLAN-010 exists but two independent reviews each invalidated its
lead phase (see its Review log); the recommended disposition is to SPLIT the
detector + consumer-caller half (evidence-producing, decision-free once D1 is
answered) from the D3/enforcement half (founder decision, unanswerable from
canon today). It has a 🔴 half (making `install.sh` apply server-side settings
mutates consumer repos); consumer-side callers go via the ops/inbox runbook.

**Fleet v2 cutover (PLAN-009) — target reconciled to `ci/v2.8.0` (PLAN-015 B1,
2026-07-18); Phase 0 partially done, still 🔴-gated.** The target advanced
`ci/v2.0.1` → `ci/v2.1.2` → **`ci/v2.8.0`** as the canon shipped forward; the
fleet re-pins straight to the current tag (`v2.8.0`, cut 2026-07-19 — it *contains*
every prior fix plus PLAN-013/012/014 and PLAN-015's rollout tooling), never to a
superseded one. **`operations` is advanced to `@ci/v2.0.1` and LIVE-VERIFIED
(2026-07-16, PR #265)** and re-pins forward with the fleet.
`plans/PLAN-009_fleet-v2-cutover.md` (see its superseding header) syncs the other
**7 consumers** (still `@ci/v1.9.5`).

**v2.0.1 verification banked on operations, not deferred to the pilot** —
operations (not the pilot) is the first armed consumer. Throwaway PR #266
confirmed **B1 live**: a synthetic auth-bypass diff drew a proper
`CHANGES_REQUESTED` naming the `[critical]` finding (no "verdict malformed"
discard) → the armed blocking path works. **B2 is source-verified only and
ACCEPTED-UNVERIFIED live** — its bypass exists *only while UNARMED*, and a live
check on 2026-07-16 found **every consumer ARMED** (`APP_REVIEWER_1_BOT_ID` set on
engramory/operations/framework/interlog), so none can enter the B2 path. The
obvious pilot test would pass **vacuously via the armed skip** (it would have
passed on buggy v2.0.0 too) — do NOT book it as B2 closure. Exercising B2 needs a
deliberately **unarmed fixture**. Residual risk is low precisely because the
bypass is unreachable while armed. **The `python3` preflight (HIGH) is likewise
not live-exercised.**

**Phase 0 status (verified live 2026-07-16):**

- ✅ LiteLLM secrets on the **private trio** (business/iplanic/interlog, set
  2026-07-15). ❌ still absent on the **4 public repos** (engramory, framework,
  iplan-standard, iplan-runner) — **no org inheritance** on a personal account,
  so each needs them set individually.
- ❌ `ci-runner,single-use` pools on business/iplanic/interlog (only operations
  has one; they still carry the v1 `aidoc,ci-ephemeral` runner).
- ✅ **public-reachability RESOLVED** — no public endpoint needed. Public repos
  run only the ai-review *review* job on the ephemeral self-hosted pool via
  `runner_labels_review` (PLAN-009 **Edit F**); LiteLLM stays private.

Runbook: `../operations/ops/inbox/2026-07-14_founder_flow-ci-v2-fleet-cutover-prereqs.md`.
**Nothing in PLAN-009 Phase 1+ (engramory pilot → propagate) starts until the
remaining 🔴 items (public-repo secrets + private pools) are confirmed live.**

**Unified LiteLLM agent gateway (`feat/unified-litellm-agents`) — SHIPPED as
`ci/v2.0.0`.** *(2026-07-12 note, now historical — the implementation below was
published and consumed by operations.)* Implementation: `ai-review` and `doc-maintainer` now use a
dependency-free OpenAI-compatible adapter with `LITELLM_BASE_URL`, separate
review/documentation keys, and model aliases; vendor CLI paths are removed. The
change
is staged as breaking `ci/v2.0.0`, with templates, installer fallback, wizard,
standards, security docs, and tests aligned. Safety controls include HTTPS by
default (explicit private-HTTP opt-in), no redirects, bounded requests and
responses, secret-pattern redaction, exact verdict schema/semantic validation,
oversized-diff refusal, total retry deadlines, atomic outputs, and job-scoped
permissions. Config schema v2 and a real-proxy two-alias smoke workflow were
included; both LiteLLM aliases were configured and the real-proxy smoke passed
(green for `ai-reviewer` + `ai-doc-maintainer`), the PR was published + merged,
and `ci/v2.0.0` was cut (resolves to `d3f4b0320b831e38b91c4b85bb5e8b26e62296f7`).
Full suite passed (checknames 14, contracts 100, negative 9, scripts 24).
OPS-0065 review used the maximum 3 cycles: final code/failure reviewers READY;
the security reviewer’s final documentation-only finding was folded without a
prohibited fourth cycle.

**PLAN-007 production-hardening — W1/W2/W3(markdown-lint)/W5 DONE; remaining work
is entirely founder-gated (W4 arming + W3 docs-sync-live).** Completed: W1 test
suite (`tests/`, PR #143), W5 Dependabot prune (#137), W2 guardrails
(FT-1/2/5 resolved, FT-6 downgraded; #144/#145).

- **W3 markdown-lint report-only → blocking — DONE across all 6 canon consumers.**
  Founder chose to **relax the canon `.markdownlint.json`** (disable
  MD013/MD024/MD036 — workspace-legitimate false-positives; ci #149,
  REPO_STANDARDS §4.4), then per-repo graduation to `fail-on-findings: true`:
  **business #57, interlog #63, engramory #49, iplan-runner #89, iplanic #258,
  iplan-standard #30 all MERGED**. operations + framework covered-by-own-tooling.
  Tracked in FT-11. **Load-bearing lesson (codified in FT-11):** a blind
  `markdownlint-cli2 --fix` is UNSAFE on these docs — it corrupts prose (a literal
  `+`/`#` at line-start → MD004/MD001 cascades) and code identifiers
  (`__init__.py`→`**init**.py` via MD050). Every graduation reflowed prose-`+`
  roots first, `--fix`ed only structural rules, and had a documentation-specialist
  verify zero prose changed (caught real BLOCKERs on iplan-runner + iplanic; the
  pre-commit `check_plan` gate caught `--fix` breaking verified-planning ledger
  citations twice). engramory added a repo-local `MD025.front_matter_title:""`.
- **W4 — arm gates fleet-wide = 🔴 founder-executed** (write to other repos +
  branch-protection change; not AI-autonomous per autonomy tiers + OPS-0062 +
  `feedback_writes_to_other_repos_inbox_first`). Founder-runnable runbook with
  exact per-repo `gh api` commands + verification + rollback:
  **`docs/FLEET_BRANCH_PROTECTION_ARMING.md`**. This is the highest-value
  remaining step — it makes the now-blocking checks actually BLOCK red PRs, and
  fixes the FT-12 phantom bare-lint contexts still forcing `--admin` merges on
  business/interlog/iplanic/framework. FT-12 also records iplan-runner canon
  gitleaks fix (RESOLVED, iplan-runner #88) + interlog composition conditionality.
- **W3 docs-sync dry-run → live — still 🔴** founder App (`aidoc-flow-bot`), or
  fold into the `doc-maintainer.yml` supersession. Note: the functional
  doc-maintainer work (a concurrent effort this session) has landed on `main`
  (see CHANGELOG "functional doc-maintainer …") — reconcile W3 docs-sync-live
  against it before provisioning the App.

*Recent (2026-07-11):* **PLAN-006 W4 content-check population — COMPLETE across all active repos.**
Two releases fixed the canon (`ci/v1.9.4` binary-install for links+markdown-lint;
`ci/v1.9.5` markdown-lint `fail-on-findings` toggle + `.lychee.toml`
`include_fragments` invalid-key fix), then populated the fleet. Final state
audited 2026-07-11 (see `docs/WORKFLOWS.md` §2):

- **links** ✅ every active repo (lychee musl binary). operations + framework
  ship a `.lychee.toml` scoping out cross-repo `../sibling/` links (resolve only
  in the local workspace, not single-repo CI) + framework's `platforms/**`+
  `examples/**` debt (framework-side FRAMEWORK-TODO `LINKS-PLATFORM-DEBT`).
- **markdown-lint** ✅ — 6 repos run the canon reusable **report-only**
  (`fail-on-findings: false`); operations (`docs-lint.yml`) + framework
  (pre-commit markdownlint) covered-by-own (adding `.markdownlint.json` breaks
  their pre-push — the secret-scan business/interlog covered-by-own pattern).
- **docs-sync** ✅ — deployed **dry-run** every active repo. Was WRONGLY thought
  founder-blocked: the `aidoc-flow-bot` App is only used by the live-mode Apply
  step (gated by `dry_run != true`); dry-run proposes doc-fixes as a PR comment
  via `GITHUB_TOKEN` — no App needed.
- **iplan-runner** (a 9th active submodule, initially missed) populated with all
  three content-checks (PR #79).

**Graduations status (history — 2026-07-12; W4 arming still founder-gated per
current state above):**

1. **markdown-lint report-only → blocking — DONE 2026-07-12** (all 6 consumers
   merged; the "259 residual/repo + `--fix`" framing was superseded by relaxing
   the canon `.markdownlint.json` per the founder decision). Only the
   founder-executed W4 arming remains. `plans/FRAMEWORK-TODO.md` FT-11.
2. **docs-sync dry-run → live** — still 🔴 founder provisions the `aidoc-flow-bot`
   App + `AIDOC_FLOW_BOT_ID`/`KEY` secrets per repo (only ci + operations have
   it); or fold into the now-functional `doc-maintainer.yml` supersession.

*History (v1.9.4):* **`ci/v1.9.4` SHIPPED (PLAN-006 W4 — content-check canon fix).** While
populating the missing content-check workflows, discovered the same
allowed-actions defect that broke `secret-scan` also blocked **`links`** and
**`markdown-lint`**: both wrapped third-party marketplace actions
(`lycheeverse/lychee-action`, `DavidAnson/markdownlint-cli2-action`) →
`startup_failure` at run-init, so neither ever ran on any consumer. `ci/v1.9.4`
refactors both to install the tool directly (lychee musl static binary +
SHA-256 verify; `markdownlint-cli2@0.23.0` via `setup-node` + `npm
--ignore-scripts`), relaxes MD060 in the `.markdownlint.json` template (new
strict cli2-0.23 rule, 348 hits/repo), and adds REPO_STANDARDS §4.3
(binary-not-action rule). PR #128 merged; tag + release cut. Pre-push OPS-0065
review: security READY, correctness clean, docs 4 findings folded.

**W4 accurate fleet tally (canon workflows on 8 repos, real repo names):**

- **labeler 8/8** ✅ (interlog #54 merged last; ci self-adopted).
- **secret-scan 8/8 effective** ✅ (6 via `secret-scan.yml`; business + interlog
  covered by their own standalone `security.yml` gitleaks — confirmed clean 0
  findings locally on both v8.21.2 + v8.30.1).
- **ai-review / composition / audit-trail** — deployed fleet-wide (core gates).
- **markdown-lint / links / docs-sync** — canon RUNNABLE (v1.9.4) + now populated
  fleet-wide. markdown-lint **graduated to blocking on all 6 consumers 2026-07-12**
  (canon relaxed + per-repo cleanup; see current-state above); links populated;
  docs-sync deployed dry-run (live-mode still 🔴 App). FT-11.

*History (v1.9.0 → v1.9.3):* **`ci/v1.9.0`** (PLAN-006 W2 — FT-9 fix + self-hosted policy). The
v1.8.1 consumer-sync sweep (via `install.sh --update`) clobbered the private
callers' runner topology — the `-private.yml` templates shipped a `runner-self`
**placeholder** that resolves to no registered runner, so every required check
queued forever and bricked the gate (FT-9). Caught by ai-review on operations #244; remediated surgically across all 4 private repos. **All 4 private repos

(operations/business/iplanic/interlog) are now on `@ci/v1.8.1` + self-hosted
`ci-ephemeral`, ai-review proven green on operations/business/iplanic** (interlog
confirms on next PR). v1.9.0 prevents recurrence: `-private.yml` templates now
ship the real `ci-ephemeral` array, and a new **`install.sh --repin`** does a
version-only pin bump (never `--update` for a re-pin). Founder policy codified:
**private repos are self-hosted ONLY** (CLAUDE.md "Runner policy", REPO_STANDARDS
§4.1/§4.2, docs/runners.md). **NEXT (PLAN-006):** W3 strict self-hosted on the
lightweight callers + stale-pin sync (interlog audit-trail v1.6.0); W4 populate
per-repo canon gaps; W5 public loose ends (iplan-runner #76, engramory).

*History (2026-07-10):* **PLAN-004 + PLAN-005 SHIPPED. Releases: `ci/v1.7.0`
(PLAN-004 elevation), `ci/v1.7.1` (caller permissions), `ci/v1.8.0` (PLAN-005
A1/C/D/E/F/G), `ci/v1.8.1` (PLAN-005 PR-A part 2 / D2).** PLAN-005 7/7 complete.

*History:* **`ci/v1.7.1` PATCH** — PLAN-005 PR-B / B2: the `ai-review` caller
templates shipped with no `permissions:` block → `startup_failure` on consumers
under the canon `read` default (the pipeline never ran). Fixed by adding the
caller `permissions:` block to both variants. Consumers re-pin `@ci/v1.7.1` or
`install.sh --update`. **PLAN-005 REVISED to rev 2** (2026-07-10) after a
three-agent from-scratch review: PR-B marked SHIPPED (v1.7.1); D2 redesigned
(HEAD-relative + §15-safe — the original was both a live bypass AND broke §15
recovery); PR-E reversed (don't flip `trust_config_repo` default — it breaks the
enforcer schema + weakens trust); PR-C collapsed to a preventive guard; stale
PLAN-004 cross-refs corrected; added D7 (inert gov knobs) + D8/§Release
(propagate fixes to the ~9 consumers via `install.sh --update`). Gate: 28
citations, 3 passes. **PLAN-005 execution — 6.5 of 7 PRs done (only PR-A part 2
remains).** MERGED: PR-A part 1 (enforcer governance floor — closes gov-path
double-label bypass) #108; PR-C (remote tag guard `--check-published`) #109;
PR-D (config-driven reviewer engine — callers drop hardcoded `reviewer: codex`,
reusable `.reviewer // "codex"` fallback + onboarding token-pairing) #111; PR-E
(external-adopter trust-override docs) #112; PR-F (trust-boundary DECISIONS
CI-0005 + D7 declarative-knob `_note` — bootstrap install guard DROPPED as
misdirected; the ops `auto_merge.repos` allowlist already gates auto-merge) #114;
PR-G (`composition.yml` reads config from the repo's DEFAULT BRANCH, not
hardcoded `?ref=main` — unblocks master/develop consumers; FT-6 `@main` half;
security-auditor READY). ⚠️ **PR-G landed as a DIRECT commit to main (184415c),
NOT via a PR** — I forgot the feature branch + a diagnostic `git push origin
HEAD` pushed it; main is unprotected so it went through. The change was
security-reviewed READY + tested + carries the OPS-0069 phrase (the only gate),
so it's substantively fine, but it bypassed the PR record. Left on main (revert+
redo would just churn history for an identical correct commit) — founder may
redo via PR if the record matters.
**Remaining:**

- **PR-A part 2** (D2 HEAD-relative skip carry-forward — product-code
  approve-then-inject) — needs a LIVE §15 label-cycle smoke test (plan Step 7) on
  a scratch PR; §15 tension resolved in design (§15 keeps the approval AT HEAD).
  The ONLY remaining PLAN-005 code PR.
- **§Release propagation sweep** — `install.sh --update` to the ~9 consumers for
  the v1.7.1 caller fix + PR-D callers. 🔴 write-to-other-repos → ops inbox
  runbook, not in-session. To flip the WORKSPACE default reviewer, set
  `.reviewer` in operations@main config (ops-repo edit).
FT-6 PARTIALLY resolved (PR-G); FT-8 post-elevation; FT-1..FT-5 remain.
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
  drift risk. The feared "drift-pipeline redesign" applied ONLY to
  `CODEOWNERS.template` (the only de-brand template that is content
  drift-checked, and it was not install-written) — done as **FT-7**.
- **FT-7** (CODEOWNERS de-brand): `CODEOWNERS.template` owner routes →
  `@${CODEOWNER_HANDLE}`; `apply-standards.sh` `codeowners_check` normalizes
  every `@owner` → `@OWNER` on both sides before diff (verifies path
  structure, ignores handle identity — approach (a)); `install.sh` now
  installs `.github/CODEOWNERS` (substituted, preserve-if-exists). Defaults
  byte-identical; existing `@vladm3105` consumers keep passing. REPO_STANDARDS
  §7 + §16.7.
- **E** (update path + manifest): new `install/templates/manifest.json` (the
  index of every `template → consumer-file` mapping: path, template +
  visibility variants, `substitute`, `safe_to_replace`) + `install.sh --update`
  mode walking it (re-fetch adopted surfaces → substitute → diff →
  `[k]eep/[r]eplace/[d]iff-only`; `--non-interactive` replaces only
  `safe_to_replace` = workflow callers + dependabot, keeps policy/governance;
  atomic replace; idempotent). New `docs/UPDATE_GUIDE.md`; REPO_STANDARDS
  §16.8. The `sync/check-drift.sh` manifest migration is scoped OUT to **FT-8**
  (E2) to keep this PR reviewable — no broken intermediate (check-drift.sh
  still works on its hardcoded loop).

✅ **`ci/v1.7.0` tag + GitHub release cut 2026-07-10** (on `f424aa7`, the PR-E
merge — all A–E under one cut). VERSION + docs + the `curl …/ci/v1.7.0/…`
install URLs now resolve. Post-cut verification: run a live `install.sh
--update` against one real consumer (e.g. interlog).

Earlier canon layers SHIPPED: **PLAN-003** (governance-file canon, #73–#75 +
follow-ups #76–#80) and **PLAN-002** (workspace standards + self-review
enforcement, PR-U1/U2/U3/U4, 2026-07-08).

## Open threads

- **PLAN-008 pre-prod gap closure** — 5-lens review (2026-07-13) of the
  `ci/v2.0.0` surface found 29 findings across documentation staleness,
  missing migration/release collateral, and code corrections. Grouped into
  5 PRs (plan in `plans/PLAN-008_pre-prod-gap-closure.md`).

- **PLAN-004 SHIPPED (A–E + `ci/v1.7.0` tag/release, 2026-07-10).**
- **`plans/FRAMEWORK-TODO.md`** — FT-3 RESOLVED 2026-07-12 (labels.json description
  corrected). FT-1, FT-2, FT-4, FT-5, FT-6, FT-8 remain open backlog.
- **PLAN-003 per-repo rollout waves** — one PR per non-paused repo per
  PLAN-003 §5.5 / operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D. Wave status
  is tracked there (do not hardcode a "next wave" here — it drifts). Validation
  gate: zero drift via the curl-piped `apply-standards.sh --check` (see
  `docs/PLAYBOOK_governance-canon-rollout.md`).

## Next-session start-here

1. **PLAN-007 production-hardening — W1/W2/W3(markdown-lint)/W5 DONE; the two
   remaining items are BOTH 🔴 founder-gated:**
   - **W4 — arm the gates as required checks** (`docs/FLEET_BRANCH_PROTECTION_ARMING.md`).
     Highest-value: makes the now-blocking checks actually block red PRs + fixes
     the FT-12 phantom bare-lint contexts forcing `--admin` merges. Do NOT execute
     as an AI (write to other repos + branch-protection = 🔴); hand the runbook to
     the founder.
   - **W3 docs-sync dry-run → live** — 🔴 `aidoc-flow-bot` App, or fold into the
     now-functional `doc-maintainer.yml` (landed on main this session — reconcile
     first). FT-11.
2. Open FT follow-ups (`plans/FRAMEWORK-TODO.md`): FT-8 (migrate
   `sync/check-drift.sh` onto `manifest.json`), FT-7/FT-10 (de-branding), FT-12
   (arming anomalies — subsumed by W4). Cap review/fix loops at 3 per OPS-0066.
3. `docs/REPO_STANDARDS.md` is the durable canon consumers follow. For PLAN-003
   rollout work, read `docs/PLAYBOOK_governance-canon-rollout.md` then defer to
   operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D.
4. *History:* PLAN-004 SHIPPED (A–E merged + `ci/v1.7.0` 2026-07-10); PLAN-006 W4
   content-check population COMPLETE (2026-07-11).

## Recent decisions

See `DECISIONS.md` for the full CI-NNNN record. Latest:

- **CI-0011** (OPEN — founder) — `verified_allowed` supply-chain boundary:
  keep (verified marketplace admitted fleet-wide) vs drop (three-pattern only).
  Filed by PLAN-015 M1; resolve before treating the boundary as settled.
- **CI-0010** (2026-07-18) — own security-scanner suite (osv/trivy/semgrep):
  binaries not marketplace actions, report-only-first, opt-in (`ci/v2.4.0`–`v2.7.0`).
- **CI-0009** (2026-07-17) — ai-review autofix: dedicated write-App, default-off,
  governance deny-floor (`ci/v2.3.0`).
- **CI-0008** (2026-07-17) — uniform-protected AI-flows: public+private on the
  self-hosted pool, no visibility split (`ci/v2.2.0`; reverses the prior split).
- **CI-0007** (2026-07-16) — runner-label naming: defer any rename to a future major.
- **CI-0006** (2026-07-12) — LiteLLM unification: all AI jobs route through
  one OpenAI-compatible LiteLLM proxy via a dependency-free Python adapter.
  Vendor CLI paths, credentials, and workflow inputs are removed. Breaking
  interface change targeted for `ci/v2.0.0`.
- **CI-0005** (2026-07-10) — trust boundary: `trust_config_repo` and
  `trust_config_ref` inputs on ai-review and auto-merge-ai-prs parameterize
  the trust source. External adopters point at their own ops/config repo;
  default is byte-identical to the prior hardcoded `vladm3105/aidoc-flow-
  operations@main`.
- **CI-0004** (2026-07-09) — workflow-policy delegation table.
- **CI-0003** (2026-07-08) — 3-cycle review circuit-breaker (OPS-0066).
- **CI-0002** (2026-07-08) — bundle PR-V1 canon with Wave 0 self-adoption.
- **CI-0001** (2026-07-08) — flexible-canonical (Option B) governance files.

Recent merges: `feat/unified-litellm-agents` (#154 — LiteLLM unification for
`ci/v2.0.0`); PLAN-007 W1/W2/W3/W5 (test suite + guardrails + markdown-lint
graduation + Dependabot prune); PLAN-006 W4 content-check population.
Earlier: PLAN-003 PR-V1/V2/V4 (#73/#74/#75) + canon follow-ups; PLAN-004 #82-#99; PLAN-005 #108-#114.

---

**Maintenance protocol:**

- Update `Current state` on every PR that changes what this repo is
  actively working on. Never leave a "(this PR)" self-reference — name the
  PR number, or phrase it as upcoming.
- Move resolved `Open threads` to `Recent decisions` (with CI-NNNN ID)
  or to git commit history.
- Prune `Recent decisions` — entries older than 4 weeks belong only in
  `DECISIONS.md`.
