# PLAN-026 — `ci/v3.0.0` remaining phases: local layer, documentation set, context migration, rollback

**Status:** Draft — no phase executed. **NOT READY**, and the reason narrowed:
§C0's blocker has a proposed resolution (implemented, mutation-tested, awaiting
a founder merge at the tag cut — see #438), but the OPS-0066 three-pass review
cap is spent on this plan, so the plan itself still needs a waiver rather than a
fourth pass.
**Owner:** canon (aidoc-flow-ci)
**Scope:** PLAN-025's unstarted phases — P4 (local layer), P5 (documentation
set), P7 (required-context migration), P9 (rollback), and the P8 remainder
(`deploy-ci-wizard.sh`). Nothing in PLAN-025 P1–P3a, P6 or the P8 core is
re-opened here.
**Semver:** none of its own. These phases land inside the `ci/v3.0.0` MAJOR that
PLAN-025 P6 cuts.

## 1. Why this plan exists rather than a fourth pass on PLAN-025

`PLAN-025 §8` records that the OPS-0066 three-pass cap is **spent**, and offers
two ways forward: a founder waiver for a fifth pass, or — in its own words —
"better — a fresh plan for the remaining phases, reviewed on its own budget."
This is that plan. It carries its own Claim ledger and its own review budget, so
the remaining phases can be reviewed without asking anyone to waive a cap.

**It does not supersede PLAN-025.** P1–P3a, P6 and the P8 core stay there, done
and reviewed. This plan takes only what is unstarted.

**Where the ledger cites PLAN-025, it cites SOURCE for the same fact wherever
source exists.** An earlier draft claimed the ledger "re-verifies rather than
imports"; that was false for 7 of 15 rows, and the rows in question were exactly
the ones defining what each phase *is* — importing scope from a document whose
review budget is spent is the thing this plan exists to avoid. Rows that can be
grounded in the tree now are (P4's unstarted state in `pre_push_check.sh`'s live
skip paths, the absent `docs/v3/`, the absent rollback script, secret-scan's
unchanged context in the migration guide). Rows 1, 6 and 10 remain PLAN-025
citations because the *intent* is what is being cited, and intent has no other
home.

**What changed under PLAN-025 while it sat at "not started"** — each of these
narrows a phase below, and each was measured, not assumed:

- The **install path exists** (Claim 12). P8's `auto_install` half is closed by
  `install.sh --add-surface`; only `deploy-ci-wizard.sh` remains, and it is
  convenience rather than a blocker.
- The **runner image builds again** and `#349` is closed **at build time**
  (Claim 16) — semgrep installs, PyYAML imports on the system interpreter.
  **The delivery caveat survives and C depends on it:** the image is built per
  host with no registry push, so until each runner host rebuilds, `scanners` is
  red on arrival. That makes the rebuild a **precondition of C2**, not a footnote.
- **`litellm-smoke` has passed** (Claim 17), so P6's MAJOR gate is met.
- `?non-call` is **retired** (Claim 11) — but read what that buys, because an
  earlier draft overstated it into a contradiction with §C. The retirement makes
  the map detect a **template-named** bare context with no canon producer. It
  still **cannot** see a context armed live but named in no template (Claim 21),
  which is canon's permanent state and every consumer's state mid-migration.
  **So it is not C's acceptance** — see §C.

## 2. Phases

Ordered by dependency, not by PLAN-025's numbering. **P4 before P5** because the
local layer is what P5's `LOCAL.md` documents; **P9 before P7** because P7 is the
only irreversible phase and P9 is its undo.

### A. Local layer (PLAN-025 P4)

New hook block, marker bumped, fail-closed `pre_push_check.sh`, cli2 parity
(Claim 1).

**A1 — bump the hook-block marker.** The trailing `vN` is the **refresh key**
(Claim 4): bootstrap re-merges the block only when a consumer's marker version
is lower than canon's. A fragment change that does not bump it cannot reach an
already-adopted repo — `--update` excludes the file and `--apply` writes no
content. **Bumping is not optional cleanup; it is the delivery mechanism.**

**A2 — decide the zero-hook detector's severity, and record the decision.**
`check-precommit-hooks.sh` exits **1** at zero hooks (Claim 2), but
`install.sh` only prints a warning and continues (Claim 3) — so today it is
**advisory**. P4 rewrites the very file the detector inspects, which is the
argument for promoting it to fatal, and the argument against is that a
bootstrap that hard-fails on a pre-existing consumer config strands adoption.

> **This is a decision, not a task.** Whichever way it goes, it goes in
> `DECISIONS.md` with the reason. Do not leave it to be re-litigated per repo.

**A3 — cli2 parity, and the comparison is LOCAL-HOOK-to-CI.** An earlier draft
made it CI-to-CI (v2 reusable vs v3 action), which is the wrong axis: both
already pin cli2, so it passes while the local hook ships cli1. PLAN-025's rule
is that **local markdownlint must be cli2 with canon's `.markdownlint.json`**
(Claim 30) — the ecosystem's usual hook is cli1, with different ignore
semantics, so a mismatch means local passes and CI reds. `tests/test_actions.sh`
already asserts the CI half (Claim 31); the **hook half is unwritten, and P4
owns it.** Assert the fragment's markdownlint entry pins `markdownlint-cli2` at
the same version as `actions/markdownlint` and resolves canon's config, by
parsing both.

**Acceptance — one criterion per scope item; an earlier draft accepted two of
four.**

1. **A1** — a consumer at the previous marker version gets the new block on a
   re-bootstrap; one already at the new version is a no-op.
2. **A2** — the detector's severity matches what `DECISIONS.md` says, on **all
   three** outcomes (see below).
3. **A3** — the hook fragment and `actions/markdownlint` pin the same cli2
   version and the same config, asserted by parsing both.
4. **The fail-closed rewrite** — each of the four current skip paths exits
   non-zero with an install hint, mutation-tested by removing one tool from
   `PATH`.

> **Criterion 4 is a consumer-facing severity change and needs A2's treatment.**
> `scripts/pre_push_check.sh` is `auto_install: true` (Claim 32), so it reaches
> every adopted consumer on the next bootstrap — turning four "skip with notice"
> paths into hard failures on any machine lacking `markdownlint-cli2`,
> `yamllint`, `actionlint` or `shellcheck`. Route it through the same
> `DECISIONS.md` entry, or state why it does not need one.

### B. Rollback (PLAN-025 P9) — before C, and C cannot start without it

P9 is unstarted — `ls scripts/*rollback*` returns nothing, and PLAN-025 records
it as NOT STARTED (Claim 9) — and P7 is irreversible per repo. PLAN-025's condition
is that **P9 ships a dry-run-capable helper or P7 is not started**.

**B1 — `scripts/v3-rollback.sh`, `--dry-run` by default.** Restores the v2
callers from a given tag, re-adds the old contexts to live protection **and** to
any ruleset, removes the v3 contexts, deletes the v3 callers.

**It must restore all six callers explicitly.** A bare bootstrap restores
**one** — only `pre-commit.yml` is `auto_install: true`; the other five are
`false` (Claim 22). A rollback that re-arms six contexts having restored one
producer re-creates, mid-incident, the exact hang it exists to end. The
published procedure had this defect and is corrected in the same change as this
plan (`docs/MIGRATION_v3.0.0.md` rollback step 1 now enumerates all six via
`--add-surface`).

**B2 — it must read both surfaces.** `apply-standards.sh` never touches rulesets
(Claim 23), so a rollback that only repairs branch protection leaves a
ruleset-required v3 context armed against a deleted caller — with no `--admin`
escape.

**Acceptance — not a diff of the script against itself.** An earlier draft said
"the dry run's printed plan matches what the real run does, asserted by diffing
them", which compares the script's own stdout to its own stdout: it passes if
the real run prints the plan and then mutates something else, or nothing. CI-0034
in a new place — the printout records intent, only an assertion records
behaviour. Instead:

1. Assert the real run's **post-state** against an **independently specified
   fixture** — six v2 caller files present; the six v2 contexts present on
   branch protection *and* on each ruleset; `quick-gates`/`scanners` absent from
   both; the three v3 caller files gone. **Not against the dry run's own
   declaration** — that expected value is the script's own stdout, so an empty
   plan plus a real run that does nothing satisfies it. Separately assert the
   dry run's declaration equals the same fixture.
2. Assert the dry run mutated **nothing, on every surface it touches** — not
   just `gh`. B1 also restores and deletes FILES, so a dry run that deletes
   `quick-gates.yml` issues zero mutating `gh` calls and passes a gh-only check.
   Assert `git status --porcelain` is empty and the tree hash is unchanged, in
   addition to zero mutating `gh` argv (recorded, not stubbed-by-return-value).

### C. Required-context migration (PLAN-025 P7)

**C cannot start yet, and the blocker is not B.** The v3 callers pin a tag that
does not exist, so canon cannot invoke its own composite actions until
`ci/v3.0.0` is cut (Claim 18, FT-21). P6 is a non-goal of this plan and is
founder-gated, so C's state is **"cannot start"**, not "after B". B is C's undo
and must also exist first; both are preconditions, and the tag is the binding one.

**The arithmetic is add 2 / remove up to 6 — not "rename two".** An earlier
draft said "two context names migrate", which is the count of *new* contexts and
reads as a rename. `docs/MIGRATION_v3.0.0.md` already carries the authoritative
mapping (Claim 19): three v2 contexts collapse into `quick-gates`, three into
`scanners`. Getting this wrong leaves up to four old contexts armed after C4
deletes their callers.

**C0 and the per-repo edit are DIFFERENT LISTS, and conflating them is the trap.**
Only one of the six old contexts appears in any tier template —
`call / Lint / format / security hooks` (Claim 20). So:

- **C0 (templates):** substitute that context in **all four tier templates that
  carry it** — `bootstrap`, `product`, `ops`, `governance` (Claim 33); `umbrella`
  has `required_status_checks: null`. An earlier draft said "that one context"
  and cited one file, which would leave three tiers naming a retired context —
  and `apply-standards.sh` PUTs the tier file as one whole payload (Claim 8), so
  a later `--apply` restores it. The templates must be right *before* any live
  edit.
- **C1–C5 (per repo, live):** add 2, observe green, remove up to 6 from live
  protection **and** rulesets, delete the old callers, then verify.

> ### 🟡 RESOLUTION PROPOSED — see the PR that carries this edit; NOT yet merged
>
> **Substituting `quick-gates` into the tier templates arms a context that
> bootstrap does not install.** `quick-gates.yml` is `auto_install: false`
> (Claim 13); only `pre-commit.yml` is `true` (Claim 22). So after C0, a
> post-v3 **cold start** installs the v2 `pre-commit.yml`, and
> `apply-standards.sh --apply --tier bootstrap` arms `quick-gates` with **no
> producer** — a new repo bricked on arrival, and consumer tiers have no
> `--admin` escape. The same hazard hits any not-yet-migrated repo where someone
> runs `--apply` between the tag and their own C1–C5.
>
> Nothing catches it: `branch-protection-*.json` is deliberately outside the
> FT-30 gate's scope (Claim 34). PLAN-025 raised the question at `:577-578` and
> its blocker table closed it with `--add-surface`, which does not address the
> **tier gate**.
>
> Two options, and neither is free:
>
> 1. **Flip `quick-gates.yml` to `auto_install: true` at the tag** — then
>    bootstrap installs the producer. Cost: a re-bootstrap on a not-yet-migrated
>    repo installs v3 *alongside* v2, which is the double-install `--add-surface`
>    exists to avoid.
> 2. **Hold the template edit until the fleet is migrated** — accept that any
>    `--apply` in the interim restores the old contexts, and say so explicitly.
>
> **A third option removes option A's cost, and is implemented in the PR that
> carries this edit — deliberately UNMERGED.** Flip `quick-gates.yml` to
> `auto_install: true` and `pre-commit.yml` to `false` (the flag moves with the
> context), **and** make the bootstrap stanza skip `quick-gates` when any caller
> it `replaces` is still present. Cold start installs the producer, so the tier
> gate is honest; a re-bootstrap on a not-yet-migrated consumer skips, so there
> is no double-install. Both directions are driven by the shipped block in
> `tests/test_install.sh` and mutation-tested — removing the skip reds 3
> assertions, reverting the flag reds 2.
>
> **It must not merge before the `ci/v3.0.0` tag.** Pre-tag, `quick-gates.yml`
> pins a tag that does not exist, so flipping the flag today would make every
> cold start install a caller that `startup_failure`s while removing the
> producer the current templates require — the same brick, sooner. The PR states
> this; merging it is the founder's call and belongs at the tag cut.

**C2's precondition is the runner-image rebuild** on every host serving that
repo (Claim 16). Arming `scanners` before the rebuild arms a context that is red
on arrival.

#### Canon is Wave 0, and its live set must be read, not assumed

An earlier draft named two of canon's required contexts from a comment inside a
workflow template. **Canon has five** (Claim 15), and a migration driven from a
two-name list deletes a caller whose context is still armed — every canon PR
then pins on "Expected — waiting for status to be reported", with
`enforce_admins: false` as the only escape.

Read them, do not cite a template:

```sh
# Resolve the DEFAULT BRANCH — apply-standards.sh does, and hardcoding `main`
# is wrong for any repo that does not use it.
b=$(gh api "repos/$R" --jq '.default_branch')
gh api "repos/$R/branches/$b/protection" --jq '.required_status_checks.contexts[]'
# Rulesets are the SECOND surface and apply-standards never touches them.
for id in $(gh api "repos/$R/rulesets" --jq '.[].id'); do
  gh api "repos/$R/rulesets/$id" \
    --jq '.rules[]?|select(.type=="required_status_checks")
          |.parameters.required_status_checks[]?.context'
done
```

Canon's live set at time of writing — **re-derive it, this list is a sample not
a spec**: `suite`, `call / verify`, `call / markdownlint`,
`call / Lint / format / security hooks`, `call / gitleaks`. Two of those fold
into `quick-gates`; `call / verify`, `call / gitleaks` and `suite` do not move.

**Acceptance — and the obvious criterion is the wrong one.** "Re-run
`required-context-map.py` and `tests/test_required_contexts.sh`" cannot serve as
C's acceptance: the set of contexts that tool **audits** comes only from the
tier templates (Claim 21) — it parses the workflows and manifest too, but it
never enumerates a live or ruleset context, so a context armed live but named in no template produces no row at
all — which is canon's permanent state and every consumer's state during C2–C3.
It would report PASS on the Wave-0 repo with canon's contexts unchecked. That is
this repo's own "a check derived from the thing it checks" pattern.

Acceptance is therefore the **live two-surface query above**, diffed against the
producer set, per repo. The suite run is still worth doing — it asserts the
*templates* — but it is a different claim and must not be reported as this one.

### D. Documentation set (PLAN-025 P5)

**P5 is all of PLAN-025 §4, not just §4.1.** An earlier draft covered §4.1 and
§4.4 and silently dropped two subsections whose whole purpose is preventing
destruction:

- **D1 — the new set:** seven documents under `docs/v3/` plus
  `docs/MIGRATION_v3.0.0.md`, which **already exists** and is not rewritten
  (Claim 5). So the build is **seven**, not eight.
- **D2 — §4.2: the v2 docs are ARCHIVED to `docs/v2/` with a banner, not
  deleted** (Claim 24). Ten repos stay pinned to v2 through the migration and
  those documents are what they read.
- **D3 — §4.3: `CHANGELOG.md`, `DECISIONS.md` and `docs/MIGRATION_v2.0.0.md`
  are append-only and are NOT rewritten** (Claim 25) — they are the only
  surviving record of why the §2 defenses exist. Given §3's "adds none and drops
  none", dropping the guard that makes §2 auditable must not happen silently.
- **D4 — §4.4: `RULES.md`'s acceptance test** (Claim 6): every row of §2's
  46-defense inventory appears as a rule.

**D4's check needs a shape, or it degrades into a presence check.** A grep for
`D1`…`D46` passes on a file that lists the IDs and states no rules — CI-0034
again. Compare **extracted §2 row text against extracted rule text**, and
mutation-test it: delete one rule, the check must red.

### E. `deploy-ci-wizard.sh` (P8 remainder)

**The reason for deferring it had to change.** An earlier draft said the wizard
is "unmentioned by PLAN-025's tooling section" and cited the line where PLAN-025
*does* list it as a remaining gap (Claim 10).

The real position: the wizard **hardcodes the v2 roster** (Claim 26) and
`docs/AI_CI_DEPLOYMENT.md` fronts it as the cold-start "fast path" (Claim 27).
So after v3 ships, an adopter following the *documented* cold-start route
scaffolds superseded callers. `--add-surface` does not fix that — it is a
per-path operator flag, not the documented route. Nothing will catch it either:
the wizard sits deliberately outside the FT-30 gate (Claim 28).

Deferral is still defensible — it is ergonomics, not correctness, and no
consumer is blocked — but the deferral must be **paired with a doc change** that
stops `AI_CI_DEPLOYMENT.md` pointing v3 adopters at a v2 scaffolder. That pairing
is in scope here; the wizard rewrite is not.

## 3. Non-goals

- **No new defenses.** PLAN-025 §2 carries 46; this plan adds none and drops
  none.
- **No re-litigation of P1–P3a.** Those shipped and were reviewed.
- **P6 is not re-planned.** Its build side is discharged; FT-30's real run is a
  founder step and stays one.
- **No consumer rollout.** C is written as a procedure; executing it against the
  ten repos is a separate, founder-sequenced act.
- **PLAN-024 Phases A/B/C are NOT planned here, and that is a deferral, not an
  omission.** PLAN-025 §7 makes them a precondition for v3 (Claim 29) and
  PLAN-024 is still `Status: Draft` with open founder items. They bear directly
  on D: Phase A deletes `doc-maintainer`, which `FLOWS.md` and `ARCHITECTURE.md`
  would otherwise document as live. **D must not be executed before that
  question is settled**, or the new documentation set ships describing a flow
  being deleted — the waste §7 exists to prevent.

## 4. Ordering, stated as a dependency and not a preference

```text
A (local layer) ──────────────► D (docs: LOCAL.md documents A)
PLAN-024 A/B/C decision ──────► D (Phase A deletes doc-maintainer)
P6 (ci/v3.0.0 tag cut) ───┐
B (rollback helper) ──────┴───► C (migration)
E (wizard) + its doc pairing    off the critical path
```

**C has TWO preconditions and the binding one is not B.** The v3 callers pin a
tag that does not exist, so canon cannot invoke its own composite actions until
`ci/v3.0.0` is cut (Claim 18) — and P6 is a non-goal here and founder-gated. B
is C's undo and PLAN-025 conditions P7 on it (Claim 9). An earlier draft showed
only `B ──► C`, which reads as "C is next after B" when C cannot start at all.

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | PLAN-025 scopes P4 to hook block, marker bump, fail-closed pre_push_check, cli2 parity (INTENT — cited to the plan because intent has no other home) | `P4 — Local layer` | plans/PLAN-025_v3-clean-rebuild.md:489 |
| 1a | P4 is genuinely unstarted: pre_push_check still skips rather than fails closed | `not installed` | scripts/pre_push_check.sh:97 |
| 2 | The zero-hook detector exits non-zero when zero hooks are selected | `check-precommit-hooks: ZERO hooks run at the pre-commit stage` | install/check-precommit-hooks.sh:106 |
| 3 | install.sh treats that detector as ADVISORY — it warns and continues | `the required 'call / Lint / format / security hooks' check would inspect` | install/install.sh:1392 |
| 3a | The detector has a THIRD outcome, rc 2 = cannot determine, on which install.sh prints nothing | `never reports clean` | install/check-precommit-hooks.sh:22 |
| 4 | The hook-block marker's trailing vN is the refresh key that lets a fragment change reach an adopted repo | `REFRESH KEY` | install/templates/pre-commit-hook-block.yaml:3 |
| 5 | P5's new set is SEVEN documents under docs/v3/; MIGRATION_v3.0.0.md is the eighth row and already exists | `docs/v3/ARCHITECTURE.md` | plans/PLAN-025_v3-clean-rebuild.md:414 |
| 6 | RULES.md's acceptance test is that every §2 defense row appears as a rule | `docs/v3/RULES.md` | plans/PLAN-025_v3-clean-rebuild.md:440 |
| 7 | P7 step 0 is updating the branch-protection templates in the same release | `branch-protection-*.json` in the same release | plans/PLAN-025_v3-clean-rebuild.md:595 |
| 8 | apply-standards.sh PUTs the tier branch-protection file as one whole payload | `branch-protection-${TIER}.json` | install/apply-standards.sh:706 |
| 9 | PLAN-025 conditions P7 on a dry-run-capable rollback helper existing first, and records P9 NOT STARTED | `P9 — Rollback` | plans/PLAN-025_v3-clean-rebuild.md:580 |
| 10 | PLAN-025 P8 lists the wizard as a remaining, unaddressed v3 tooling gap | `install/deploy-ci-wizard.sh` | plans/PLAN-025_v3-clean-rebuild.md:570 |
| 11 | The `?non-call` label is retired, and the suite fails if it returns | `?non-call` | tests/test_required_contexts.sh:56 |
| 12 | An install path now exists for a surface the consumer lacks | `--add-surface) ADD_SURFACES+=` | install/install.sh:105 |
| 13 | The v3 caller templates are auto_install:false, which is why they needed that path | `"auto_install": false` | install/templates/manifest.json:222 |
| 14 | secret-scan keeps its existing context through the migration | `call / gitleaks` | docs/MIGRATION_v3.0.0.md:67 |
| 15 | Canon's main carries FIVE required checks, not two — so a two-name migration list strands three | `5 required checks` | docs/RELEASE_CHECKLIST.md:129 |
| 16 | The #349 image fix is delivered PER HOST with no registry push, so a host that has not rebuilt still reds `scanners` | `per host with no registry push` | docs/MIGRATION_v3.0.0.md:78 |
| 17 | litellm-smoke passed — run 31348751529, both aliases | `LiteLLM smoke PASSED` | plans/PLAN-025_v3-clean-rebuild.md:1002 |
| 18 | Canon cannot invoke its own composite actions until the ci/v3.0.0 tag exists (FT-21) — so C cannot start before P6 | `cannot call its own composite actions until` | docs/EXERCISER_INVENTORY.md:51 |
| 19 | The migration is add 2 / remove up to 6, not a two-name rename | `collapse into` | docs/MIGRATION_v3.0.0.md:52 |
| 20 | Only ONE of the six retiring contexts appears in a tier template, so C0 and the live edit are different lists | `call / Lint / format / security hooks` | install/templates/branch-protection-product.json:10 |
| 21 | required-context-map.py reads the TIER TEMPLATES only, so it cannot see a context armed live but named in no template | `install/templates/branch-protection-*.json` | install/required-context-map.py:124 |
| 22 | Of the six v2 callers only pre-commit.yml is auto_install:true, so a bare bootstrap restores one of six | `"auto_install": true` | install/templates/manifest.json:186 |
| 23 | apply-standards.sh never touches rulesets (CI-0029), so a rollback must repair both surfaces | `never touches rulesets` | docs/MIGRATION_v3.0.0.md:94 |
| 24 | §4.2 requires the v2 docs be ARCHIVED to docs/v2/ with a banner, not deleted | `docs/v2/` | plans/PLAN-025_v3-clean-rebuild.md:425 |
| 25 | §4.3 makes CHANGELOG / DECISIONS / MIGRATION_v2.0.0 append-only and never rewritten | `Untouchable — append-only` | plans/PLAN-025_v3-clean-rebuild.md:430 |
| 26 | deploy-ci-wizard.sh hardcodes the v2 caller roster | `ALL_WF=` | install/deploy-ci-wizard.sh:50 |
| 27 | AI_CI_DEPLOYMENT.md fronts the wizard as the cold-start fast path | `Fast path` | docs/AI_CI_DEPLOYMENT.md:15 |
| 28 | The wizard sits deliberately outside the FT-30 gate, so nothing catches a stale roster | `deploy-ci-wizard.sh` / `apply-standards.sh` (entry points a | docs/RELEASE_CHECKLIST.md:87 |
| 29 | PLAN-025 §7 makes PLAN-024 Phases A/B/C a precondition for v3 | `ship first and separately` | plans/PLAN-025_v3-clean-rebuild.md:634 |
| 30 | cli2 parity is a LOCAL-hook-to-CI rule: local markdownlint must be cli2 with canon's config | `Tool parity is mandatory` | plans/PLAN-025_v3-clean-rebuild.md:388 |
| 31 | The CI half of that parity is already asserted; the hook half is not | `does NOT use cli1` | tests/test_actions.sh:370 |
| 32 | pre_push_check.sh is auto_install:true, so a fail-closed rewrite reaches every adopted consumer | `scripts/pre_push_check.sh` | install/templates/manifest.json:314 |
| 33 | The retiring context appears in FOUR tier templates, not one | `call / Lint / format / security hooks` | install/templates/branch-protection-ops.json:10 |
| 34 | branch-protection templates are deliberately outside the FT-30 gate's scope | `deploy-ci-wizard.sh` / `apply-standards.sh` (entry points a | docs/RELEASE_CHECKLIST.md:87 |

## Review log

### Pass 1 - 2026-08-10 - author

Drafted against PLAN-025's unstarted phases. Four things changed the shape
versus a straight copy of PLAN-025's phase list, and all four were verified
rather than assumed: the install path now exists, the runner image builds, the
smoke gate has passed, and `?non-call` is retired. Each of those either shrinks
a phase (E) or makes one safe to attempt (C).

Two orderings are asserted as dependencies rather than preferences — A before D,
and **B before C** — the second because PLAN-025 conditions P7 on P9 existing
and that is the ordering a session under time pressure would break.

One item is deliberately written as a decision rather than a task (A2, the
detector's severity), because leaving it implicit is how it gets re-litigated
per repo.

### Pass 2 - 2026-08-10 - independent (`verified-planning-reviewer`)

**10 load-bearing findings, 8 minor. All folded.** The reviewer's verdict on the
central question — is this a re-skin of PLAN-025 that inherits its spent budget?
— was "not a re-skin" for the decisions, but it caught that the *scope* was
imported and that my §1 sentence claiming otherwise was false for 7 of 15 rows.

The three that would have caused real damage:

1. **§C named two of canon's five required contexts.** I derived them from a
   comment inside a workflow template. Canon's live set is five, verified by
   query: `suite`, `call / verify`, `call / markdownlint`,
   `call / Lint / format / security hooks`, `call / gitleaks` — and **two** of
   them fold into `quick-gates`, not one. Executing C from my list would have
   deleted a caller with its context still armed, hanging canon's `main` with
   `enforce_admins: false` as the only escape. §C now requires the live query and
   says the sample is not a spec.
2. **§C's acceptance could not fail for the case it exists to catch.**
   `required-context-map.py` reads the tier templates and nothing else
   (Claim 21), so a context armed live but named in no template yields no row —
   which is canon's permanent state. It would have reported PASS on the Wave-0
   repo with canon's contexts unchecked. This repo's own "a check derived from
   the thing it checks" pattern, in a plan that cites that pattern.
3. **§B would have transcribed a live defect.** `docs/MIGRATION_v3.0.0.md`'s
   rollback step 1 told the operator to bootstrap, which restores **one of six**
   v2 callers (Claim 22) before step 2 arms six contexts — re-creating,
   mid-incident, the hang the procedure exists to end. **Fixed in canon in the
   same change**, not just in this plan.

Also folded: C's binding precondition is the `ci/v3.0.0` tag, not B (Claim 18) —
the ordering graph said `B ──► C`, which reads as "C is next"; §B's acceptance
diffed the script's stdout against its own stdout and asserted nothing about
behaviour; §D covered §4.1/§4.4 and silently dropped §4.2 (archive v2 docs) and
§4.3 (the append-only three) — the two subsections that exist to prevent
destruction, in a plan whose non-goals say "drops none"; PLAN-024 A/B/C is now
an explicit deferral with its consequence for D stated; §E's justification was
resting on a misreading of its own citation, and the real position is that the
wizard hardcodes the v2 roster while being the documented cold-start path.

Ledger: 15 → 31 rows. Rows re-pointed to source where source exists (P4's
unstarted state, secret-scan's context, the migration mapping); rows 1, 6 and 10
remain PLAN-025 citations because what they cite is *intent*.

**Result:** findings folded; re-dispatching for an independent Pass 3.

### Pass 3 - 2026-08-10 - independent (`verified-planning-reviewer`)

**5 load-bearing, 8 minor. Four folded; ONE IS OPEN and blocks C0.** The three
targets I asked it to attack hardest — §C's arithmetic, Claim 20, and the canon
rollback fix — it verified as **correct**. The defects were beside them, and two
were introduced by the Pass-2 fold, which is this repo's recorded pattern
holding again.

Folded:

- **§A3 defined cli2 parity on the wrong axis** — CI-to-CI, where both sides
  already pin cli2, so it passes while the local hook ships cli1. PLAN-025's
  rule is local-hook-to-CI (Claim 30) and the hook half is unwritten. That is
  the failure P4 exists to prevent, in the phase that owns it.
- **§A accepted two of its four scope items.** The fail-closed rewrite had no
  criterion — and it is `auto_install: true` (Claim 32), so it reaches every
  adopted consumer and turns four skips into hard failures. Now has one, and is
  routed through A2's decision.
- **§1 contradicted §C about the same tool.** §1 said the `?non-call`
  retirement lets P7 step 5 detect an unproduced armed context; §C proves it
  cannot for the live case, which is the only case C operates in. §1 is what a
  resuming session reads for "why is C safe now".
- **§B's acceptance had two holes** — it measured only the `gh` surface while B1
  also mutates files, and its expected value was still the script's own stdout,
  so an empty plan plus a no-op run passed.
- **§C0 was scoped to one template; the context is in four** (Claim 33).

**Result: NOT READY. One load-bearing item is open, and OPS-0066's three-pass
cap is now spent on this plan.** Per the circuit-breaker I am not dispatching a
fourth pass. The open item is the 🔴 block in §C: substituting `quick-gates`
into the tier templates arms a context bootstrap does not install, bricking a
post-v3 cold start, and the two ways out have opposite costs. **It is a founder
decision and is surfaced rather than guessed.**
