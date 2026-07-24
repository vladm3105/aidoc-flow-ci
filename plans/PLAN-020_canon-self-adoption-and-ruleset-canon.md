# PLAN-020 — Canon self-adoption + ruleset canon (FT-55, FT-56)

**Status:** DRAFT — one open decision (see Pass 4); not ready
**Owner:** aidoc-flow-ci
**Opened:** 2026-07-24
**Closes:** FT-55, FT-56 (both filed by Phase 1 of this plan).
**Sequencing:** Phase 0 task 1 determines whether FT-5 blocks CI value — do not
assume it does.

## 1. Problem

Two gaps found 2026-07-24 while applying CI-0011 to canon and building FT-53.

### FT-55 — the tag ruleset is an act, not a standard

FT-52 applied an immutable `ci/v*` tag ruleset to canon (live: id `19687369`,
`enforcement: active`, rules `deletion` + `non_fast_forward`, `bypass_actors: []`).
It mitigates the fact that the **whole fleet pins canon by a mutable tag** — a
force-moved `ci/vX.Y.Z` reaches every consumer on its next run.

It exists only as a `gh api` snippet in a rollout runbook. No canon machinery knows
rulesets exist: not the templates, not `apply-standards.sh`, not
`check-standards-drift.sh`, not `REPO_STANDARDS.md`. (The manifest indexes only
template→consumer-*file* mappings, so server-side settings are absent by design —
rulesets need no entry there.) If it were
disabled or deleted, **nothing would detect it**. Branch protection is
drift-checked; the ruleset protecting the tags the fleet pins is not.

### FT-56 — canon's self-drift output is produced but never consumed

**The first draft of this plan got this wrong, and the correction changes the fix.**
The premise was "canon has no self-check". It has one:
`standards-drift-self.yml` already runs `check-standards-drift.sh` weekly against
canon, over exactly the surfaces in question.

What actually happened in each of the three instances:

| # | Instance | Why the existing gate did not stop it |
| - | -------- | ------------------------------------- |
| 1 | `actions-permissions.json` values unapplied (FT-46/FT-27) | **Blind.** These reads need repo-administration scope, which FT-5 proves the workflow token cannot have. Emits `warn_uncheckable`, verifies nothing. (Whether *ruleset* reads share that constraint is Phase 0 task 1.) |
| 2 | CI-0011 actions settings unapplied | Same blindness as 1. |
| 3 | 8 of 18 canonical labels absent | **Not blind — it fired.** Labels are readable with the ordinary token, and the check emits one warning per missing label. It ran weekly and was never acted on. |

So FT-56 is two distinct defects wearing one coat:

- **56a — blindness:** the highest-value comparisons cannot execute in CI at all
  (FT-5). A self-audit added under the same token is blind in the same way.
- **56b — unconsumed signal:** where the check *can* see, it emits `::warning::`
  into a scheduled run nobody reads. Instance 3 proves a warning-only gate does not
  change behaviour. This is the same disease as FT-54 (two permanent
  branch-protection warnings), and adding more warnings to that channel makes it
  worse, not better.

A third, smaller defect: even with a good token the comparison has **coverage
holes** — `can_approve_pull_request_reviews` is shipped in the template but never
compared, and label colour/description are written by `apply_labels()` but never
compared.

## 2. Non-goals

- **Not** deciding FT-54. But FT-54 is now a **prerequisite** of Phase 2, not a
  beneficiary: canon's branch protection deliberately deviates from product-tier,
  so until that deviation is modelled, a self-audit's output cannot mean
  "canon is correct".
- **Not** running `apply-standards.sh` wholesale against canon — that is forbidden
  and would clobber FT-52.
- **Not** changing the live `ci/v*` ruleset. It is correct.

## 3. Approach

### Phase 0 — verify the permission class, then 🔴 provision if needed

**Task 1 (AI, cheap, do first — it decides the sequencing).** FT-5 establishes the
admin-token constraint for *branch-protection* and *actions-permissions* reads. It
does **not** cover `GET /repos/{owner}/{repo}/rulesets`, and this plan must not
assume it does: if ruleset listing is readable with the default `GITHUB_TOKEN`,
Phase 0 does not gate Phase 1 and the sequencing below is wrong in the expensive
direction (a 🔴 founder task inserted ahead of deliverable work).

Verify empirically from an Actions context (or a contents-read-only fine-grained
token) and record the result as a ledger row with command + date.

Known so far: there is **no** non-admin read path for *tag* rules —
`GET /repos/{owner}/{repo}/rules/branches/{branch}` exists and returns data, but
the tag equivalent 404s (verified 2026-07-24). So if `/rulesets` is admin-class,
tag rulesets have no fallback.

**Task 2 (🔴 founder, only if Task 1 says admin-class).** Provision an App/PAT
secret carrying `administration: read`. Without it Phase 1 delivers *zero* CI value
and would emit an unconditional `warn_uncheckable` weekly while failing `--strict`
— manufacturing the exact poisoned channel this plan is about.

Phase 1's comparison is **opt-in** (see `--rulesets` below), so Phase 1 may land
before Phase 0 completes; it simply must not be *enabled* in the weekly job until
Task 1 (and if needed Task 2) is done.

### Phase 1 — ruleset canon + detection (FT-55)

**Template + selection — one mechanism solves both.** Add
`install/templates/rulesets-canon.json`, selected by a new **opt-in**
`--rulesets <template-name>` argument. The comparison runs **only** when that
argument is passed; no argument means no ruleset section at all.

This is deliberate, and tier-scoping cannot substitute for it: canon shares the
`product` tier with `iplan-runner` and `engramory`, canon's own job passes
`--tier product`, and the consumer reusable passes only `--tier`. A `${TIER}`-style
selector would therefore either reproduce fleet-wide ABSENT (tier=product) or never
be selected at all (a pseudo-tier nobody passes). And "compare only if the repo has
≥1 ruleset" is worse — it would report zero drift in exactly the FT-55 scenario
where canon's ruleset was *deleted*.

Opt-in also supplies the Phase-0 gate a mechanism: the script currently has **no**
per-section flags (its arg loop accepts only `--tier/--repo/--ci-tag/--strict`),
so without this, any ruleset code added would run in canon's weekly job by
construction and "do not wire before Phase 0" would be unenforceable.

**Identity.** Match on `target` + normalized `conditions.ref_name.include` — *what
the ruleset protects* — never on `name`. Names are free text and mutable; a rename
changes zero protection, so name-keying would report ABSENT and assert "the
protection is gone" when it is not. That is precisely the false-alarm class FT-53
spent a release removing (glob subsumption). Report a name mismatch, if at all, as
a notice.

**Fetch shape.** The list endpoint returns only
`id, name, target, enforcement, source, source_type, …` — **`rules`,
`conditions` and `bypass_actors` come only from the per-ruleset detail GET**
(verified against the live API). So: list → filter `source_type == "Repository"`
(the list includes inherited org rulesets) → detail GET per candidate, each with
its own named uncheckable path. Price the N+1.

**Conditions.**

- **ABSENT** — no live ruleset protects the required ref pattern.
- **WEAKENED** — present but `enforcement != active`, a required rule type absent,
  or `bypass_actors` non-empty. Bypass is load-bearing: immutability with an admin
  bypass is not immutability.
- **EXTRA** — emitted as `::notice::`, **no** `DRIFT` increment, no `--strict`
  effect. Rationale is *security*, not noise: rulesets only add restrictions and
  bypass actors exempt only their own ruleset, so an attacker-added ruleset cannot
  loosen an existing control. But extras are not harmless in the *availability*
  direction — the umbrella's `--admin` requirement really does come from a
  **ruleset**, not branch protection: ruleset `17136252` carries
  `required_signatures` while the umbrella's `branch-protection.required_signatures`
  is `false` (verified live 2026-07-24), and the FT-52 runbook warns against
  acquiring one. A notice keeps that visible without manufacturing yellow.

**Remediation in the message.** The warning must name the exact fix command and
template path. The only existing remediation artifact is a snippet under a header
reading "EXECUTED — do not re-run", so a bare pointer would send the operator to a
do-not-run page. Either ship `rulesets-canon.json` with **no** `_`-prefixed keys — unlike every
sibling template, which carries `_comment`/`_apply_note` that GitHub 422s on — or
make the cited command include the `jq walk` strip `strip_meta` already uses.
Otherwise the "exact fix command" 422s: the same failure class as the do-not-run
pointer it replaces.

**Rulebook, in this phase not Phase 3.** Canon discipline is that every canon-body
change ships with a `REPO_STANDARDS.md` update. Ship in Phase 1: the §2
tag-immutability rule, and a §4.3 **coverage** update (drift now compares rulesets).

**Do NOT write the §4.3 token-class sentence until Phase 0 task 1 has a recorded
ledger row.** §4.3 currently names branch protection as *the* admin-token-only
control. Whether rulesets join it is exactly what task 1 determines, and Phase 1 is
permitted to land first — so writing it now would put an unverified token-class
claim into the canon rulebook, which propagates to every consumer.

**Also in Phase 1:** file FT-55 and FT-56 in `plans/FRAMEWORK-TODO.md` (they do not
exist yet; without them the IDs can collide and nothing tracks the gap if this plan
stalls), and correct `branch-protection-product.json`'s `_comment`, which still
lists `aidoc-flow-ci` as product-tier — wrong for branch protection since FT-52,
and required by FT-54 which Phase 2 depends on.

**Also correct FT-54's own Effect paragraph.** As filed it says the *weekly* run
reports the two branch-protection drift lines "forever". It cannot: the job grants
only `contents: read`, so that read 403s into `warn_uncheckable`. Those lines were
observed from a local **admin-PAT** run and wrongly generalised to CI. This matters
because FT-54 is a founder decision whose option 3 is "accept and annotate the two
expected lines" — a choice that would be made on a false premise. Restate as: a
local/admin-token run reports these two lines; the weekly CI run reports
`warn_uncheckable` instead, and the lines materialise only after Phase 0.

### Phase 2 — make the signal consumed, and close the coverage holes (FT-56)

Not a new mode. A delta plus a consumption mechanism.

1. **Consume the output (56b).** A `::warning::` in a scheduled run is not a gate —
   instance 3 proves it. Make the weekly canon run either fail the job, or
   open/refresh a tracking issue (note: the latter needs `issues: write`, which
   neither the workflow nor the job currently grants).

   **The ordering is Phase 0 → FT-54 → consumption, and the reason matters.**
   Today the weekly job's permanent noise is *not* FT-54's two branch-protection
   drift lines — under the default token that read never happens; it is
   `warn_uncheckable`, i.e. `FETCH_ERRORS`. FT-54's `enforce_admins`/`contexts`
   lines can only materialise **after** Phase 0 grants an admin token. So: fix the
   blindness first, which surfaces FT-54's deviation, which must then be modelled
   before the job can be made failing — otherwise consumption turns a permanent
   yellow straight into a permanent red.
2. **Close the coverage holes.** Compare `can_approve_pull_request_reviews`, and
   label colour/description.
3. **Only then** consider a `--self-audit` convenience wrapper. Note it cannot be
   defined as "what `apply-standards.sh` would apply": running that wholesale on
   canon is forbidden precisely because it would impose the wrong branch-protection
   profile.

### Phase 3 — optional apply path

Only if a second repo needs rulesets: `apply_rulesets()` in `apply-standards.sh`.
Note the existing per-section convention is `--skip-*` (default-ON), which on the
*write* side would POST canon's `ci/v*` template to every repo it runs against —
the write-side twin of the blast radius Phase 1 fixed on the read side. If Phase 3
is reached, make it opt-in, not skip-able.
(The `branch-protection-product.json` `_comment` correction moved to Phase 1 — it
is also required by FT-54, which is a Phase-2 prerequisite, so it must not sit
behind an optional phase that may never run.)

## 4. Risks

| Risk | Mitigation |
| ---- | ---------- |
| Phase 1 wired to CI before the permission class is known → weekly `warn_uncheckable` + unconditional `--strict` failure | Phase 0 task 1's recorded result gates it; the `--rulesets` opt-in means Phase 1 can land un-enabled. |
| A non-scoped template fires ABSENT fleet-wide and reds adoption gates | Scope the template; add a test that a repo with no rulesets produces zero *ruleset* drift. |
| Name-keyed identity turns a harmless rename into "protection is gone" | Key on `target` + `conditions.ref_name.include`. |
| Detail-GET N+1 introduces new per-ruleset failure paths | Named uncheckable per ruleset, routed through `warn_uncheckable`. |
| More warnings into an already-ignored channel (the FT-54 disease) | Phase 2 makes the channel consumed *before* Phase 1 is wired weekly. |
| A future ruleset field silently ignored | Compare declared fields only; test that an unknown field does not crash. |

## 5. Acceptance

Fixture-driven, per the FT-53 precedent — canon's live protection must not be
mutated to test a checker, and reverting an FT-56 instance would mean re-widening
canon's live supply-chain boundary.

- Canned `rulesets` payloads in `tests/test_scripts.sh` covering: absent /
  `enforcement: disabled` / required rule removed / `bypass_actors` non-empty /
  renamed-but-equivalent / an unrelated extra ruleset / inherited
  (`source_type: Organization`).
- Renamed-but-equivalent → **zero** drift. Extra → a `::notice::` and zero drift.
  Inherited → ignored. The other three → drift, and `--strict` non-zero.
- A consumer fixture with **no** rulesets, run **without** `--rulesets` → zero
  ruleset drift (it may have other drift; scope the assertion). Run *with* the flag,
  the same fixture must report ABSENT — the two together prove the opt-in works.
- **No live assertion in the suite.** `tests/test_scripts.sh` is hermetic ("No
  network / gh") and its drift stubs `exit 1` on any unexpected call, so a live
  `gh api` there fails by construction — and `suite` is a required check on canon
  `main`. The single live check (canon's ruleset satisfies the template) is a
  **manual one-off** run with an admin token, recorded in this plan's execution
  notes.
- Mutations confirmed red in both directions — a check that never fires and one
  that always fires are both broken.

## Claim ledger

| #   | Claim | Symbol | Citation |
| --- | ----- | ------ | -------- |
| 1 | The `ci/v*` ruleset exists only as a runbook snippet, not a template | `gh api -X POST repos/vladm3105/aidoc-flow-ci/rulesets` | plans/ROLLOUT_ft52-canon-self-governance.md:78 |
| 2 | That snippet declares exactly the `deletion` + `non_fast_forward` rules | `"type": "deletion"` | plans/ROLLOUT_ft52-canon-self-governance.md:87 |
| 3 | The runbook header marks it executed, so it cannot serve as remediation guidance | `EXECUTED 2026-07-24` | plans/ROLLOUT_ft52-canon-self-governance.md:3 |
| 4 | `apply-standards.sh` applies labels, repo-settings, actions-permissions, branch-protection — no ruleset path | `apply_labels()` | install/apply-standards.sh:574 |
| 5 | …the last apply_* section is branch protection | `apply_branch_protection()` | install/apply-standards.sh:700 |
| 6 | `apply_labels()` writes colour/description, which drift never compares (Phase 2 hole) | `color` | install/apply-standards.sh:577 |
| 7 | The drift script compares branch-protection, repo-settings, actions, labels — no rulesets | `# --- Branch protection tier profile ---` | sync/check-standards-drift.sh:124 |
| 8 | Only branch protection is tier-scoped; other templates are fetched for every repo | `branch-protection-${TIER}.json` | sync/check-standards-drift.sh:140 |
| 9 | The labels check already emits a per-label warning — it fired and was ignored (56b) | `canon label missing` | sync/check-standards-drift.sh:352 |
| 10 | The actions check compares only `default_workflow_permissions`, not `can_approve` | `default_workflow_permissions` | sync/check-standards-drift.sh:222 |
| 11 | …while the template ships `can_approve_pull_request_reviews` (uncompared) | `can_approve_pull_request_reviews` | install/templates/actions-permissions.json:32 |
| 12 | `warn_uncheckable` is the existing no-silent-green helper Phase 1 reuses | `warn_uncheckable()` | sync/check-standards-drift.sh:119 |
| 13 | `--strict` gates on DRIFT + FETCH_ERRORS + PIN_ERRORS | `PIN_ERRORS` | sync/check-standards-drift.sh:365 |
| 14 | `DRIFT` is the counter Phase 1 increments | `DRIFT=0` | sync/check-standards-drift.sh:110 |
| 15 | FT-5 is STILL OPEN: `administration` is not a grantable GITHUB_TOKEN scope | `### FT-5 —` | plans/FRAMEWORK-TODO.md:869 |
| 16 | The self-drift workflow sets a zero permissions default; the job adds only `contents: read` | `permissions: {}` | .github/workflows/standards-drift-self.yml:38 |
| 17 | Canon's self-drift already runs weekly with `--tier product` (the existing gate) | `args=(--tier product)` | .github/workflows/standards-drift-self.yml:55 |
| 18 | …on a cron, so a new permanent warning recurs weekly (the FT-54 hazard) | `schedule:` | .github/workflows/standards-drift-self.yml:26 |
| 19 | `install.sh` creates the canonical labels at bootstrap — the path canon never runs | `creating canonical labels` | install/install.sh:1039 |
| 20 | Running `apply-standards.sh` wholesale on canon is forbidden (would clobber FT-52) | `Never run` | HANDOFF.md:63 |
| 21 | FT-46 is the first recorded instance of canon not applying its own template values | `### FT-46 — canon has not applied its own FT-27 values; allowlist is wider than the rule` | plans/FRAMEWORK-TODO.md:172 |
| 22 | CI-0011 is the decision whose settings canon had not applied (instance 2) | `## CI-0011:` | DECISIONS.md:501 |
| 23 | `branch-protection-product.json` still names `aidoc-flow-ci` product-tier (Phase 1 fix) | `_comment` | install/templates/branch-protection-product.json:2 |
| 24 | Branch protection lives in REPO_STANDARDS §2 — where tag immutability belongs | `## 2. Branch protection` | docs/REPO_STANDARDS.md:74 |

## Review log

### Pass 1 - 2026-07-24 - author self-check

Verified each ledger citation by opening the file; the gate then confirmed every
symbol resolves. Checked the live ruleset config via the API rather than trusting
the runbook, and confirmed the fleet state Phase 1's EXTRA rule depends on:
`framework` carries an unrelated `Main Rules` branch ruleset (`disabled`),
`engramory` and `iplan-standard` have none.

Flagged two scope calls for the independent pass to challenge: FT-54 excluded
though Phase 2 may subsume it, and `apply_rulesets()` deferred leaving a
detect-but-cannot-fix window.

**Result:** ready for independent review.

### Pass 2 - 2026-07-24 - independent (verified-planning-reviewer)

**7 load-bearing + 5 minor findings. Phase 1's mechanism and Phase 2's premise
were both wrong.** Folded in full; the three most consequential were verified
against the live API and repo before folding rather than taken on trust:

1. **Non-scoped `rulesets.json` fires ABSENT fleet-wide** — only branch protection
   is tier-scoped (ledger 8); every other template is fetched for every repo, and
   adoption gates run `--strict`. → template scoped to `rulesets-canon.json`, with
   an explicit "consumer with no rulesets → zero ruleset drift" acceptance row.
2. **FT-5 makes Phase 1 blind in CI** (ledger 15, 16). `administration` is not a
   grantable token scope; the self-drift job grants none. Phase 1 as drafted would
   `warn_uncheckable` weekly *and* fail `--strict` unconditionally. → new **Phase 0**
   prerequisite; Phase 1 ships test/CLI-only until it lands.
3. **`bypass_actors`/`rules`/`conditions` are not on the list endpoint** — verified
   live: list returns `id, name, target, enforcement, source, source_type…` only.
   WEAKENED was uncomputable as written. → list → filter `source_type` → detail GET
   per ruleset, N+1 priced.
4. **Name-keyed identity turns a rename into a false ABSENT** — the FT-53
   false-alarm class. → key on `target` + `conditions.ref_name.include`.
5. **Phase 2's premise was false.** The gate exists and, for labels, *fired* weekly
   and was ignored (ledger 9). → FT-56 re-split into **56a blindness** (FT-5) and
   **56b unconsumed signal**; Phase 2 is now consumption + coverage holes, and
   FT-54 is promoted from beneficiary to prerequisite.
6. **Acceptance was untestable** — four of five criteria required 🔴 live mutation
   of canon's protection. → fixture-driven per FT-53, one read-only live assertion.
7. **Rulebook update belonged in Phase 1**, per the canon-body-change discipline;
   §4.3 currently names branch protection as the only admin-token control, which
   Phase 1 falsifies.

Minor folded: ledger 13 corrected (`--strict` also gates `PIN_ERRORS`); labels is
not the script's last section (a pin-currency tail follows), so the insertion point
is "before the pin-currency tail"; EXTRA rationale rewritten to the security
argument with the umbrella `required_signatures` availability counterexample;
FT-55/FT-56 filing made a Phase-1 deliverable since neither ID exists yet; the
"canon never runs its own machinery" premise corrected to "is forbidden to run it
wholesale" (ledger 20).

**Result:** folded — re-review required.

### Pass 3 - 2026-07-24 - independent (verified-planning-reviewer, fold verification)

Confirmed genuinely folded (not reworded): the list → `source_type` filter →
detail-GET shape, identity keyed on `target` + `conditions.ref_name.include`, the
56a/56b split with semantically-correct labels evidence, fixture-driven acceptance,
and that `::notice::` exists as a mechanism in the script.

**5 further load-bearing findings, all folded:**

1. **The scoping predicate was named but never specified**, and tier-scoping cannot
   supply it — canon shares `product` with two other repos. → resolved by a single
   mechanism: an **opt-in `--rulesets <template>` argument**.
2. **"Ships test/CLI-only" had no mechanism** — the script has no per-section flags,
   so any ruleset code would run in canon's weekly job by construction. → the same
   `--rulesets` opt-in supplies it.
3. **My Phase-0 pivot claim was UNVERIFIED.** FT-5 covers branch-protection and
   actions-permissions reads, *not* `/rulesets`. Asserting it would have inserted a
   🔴 founder task ahead of deliverable work on an assumption. → Phase 0 task 1 is
   now to *verify* the permission class; the header no longer asserts the block.
   Partial evidence gathered: no non-admin read path exists for **tag** rules
   (`/rules/branches/{branch}` works, the tag equivalent 404s).
4. **Internal contradiction on FT-54.** Its two drift lines cannot be today's
   weekly noise — under the default token that read never happens. Today's noise is
   `warn_uncheckable`/`FETCH_ERRORS`; FT-54's lines materialise only *after* Phase 0.
   → chain restated as Phase 0 → FT-54 → consumption.
5. **The live assertion had no runnable home** — the suite is hermetic and its stubs
   `exit 1` on unexpected calls, and `suite` is a required check. → suite stays
   fixture-only; the live check is a manual one-off.

Minor folded: the POST-able template vs the `_`-key convention (422 risk); ledger 16
wording; the manifest dropped as evidence; and the `branch-protection-product.json`
`_comment` fix moved out of optional Phase 3 into Phase 1, since FT-54 — a Phase-2
prerequisite — also needs it.

**One finding rebutted with evidence rather than folded.** The reviewer suggested
the umbrella's `required_signatures` comes from branch protection, making the EXTRA
counterexample mis-attributed. Verified live: umbrella ruleset `17136252` carries
`required_signatures` while its `branch-protection.required_signatures` is `false`.
The counterexample stands; the plan now cites the ruleset id.

**Result:** folded — re-review required (this is independent pass 2 of the 3-pass
OPS-0066 cap).

### Pass 4 - 2026-07-24 - independent (verified-planning-reviewer, final permitted pass)

Third and final independent pass under the OPS-0066 3-pass cap. Confirmed resolved:
the `--rulesets` opt-in coherently solves both the scoping predicate and the
"don't run before Phase 0" enforcement (consumers reach the script only via callers
that cannot pass the flag); Phase 0 verifies rather than asserts; the live assertion
is out of the hermetic suite; the `_comment` fix moved to Phase 1. The Pass-3
rebuttal was not contradicted — corroborated on-disk by `PLAN-001` naming it a
"Signed-commit ruleset" — though this pass had no Bash to re-execute the check.

**3 load-bearing findings. Two folded; one is an open decision — plan is NOT ready.**

- **FOLDED — the §4.3 rulebook deliverable hardcoded Phase 0 task 1's answer.** It
  told the implementer to amend the token-class sentence "which this phase
  falsifies", while Phase 1 may land before task 1 answers it. An unverified
  token-class claim would have entered the canon rulebook and propagated to every
  consumer. Now: §2 rule + §4.3 *coverage* in Phase 1; the token-class sentence
  waits on task 1's ledger row.
- **FOLDED — FT-54, a Phase-2 prerequisite, states as fact something this plan
  disproves.** As filed it says the weekly run reports two branch-protection drift
  lines "forever". It cannot — the job grants only `contents: read`, so that read
  403s into `warn_uncheckable`. The lines were observed from a local admin-PAT run
  and wrongly generalised to CI (author error, confirmed against
  `.github/workflows/standards-drift-self.yml:45-46` and
  `sync/check-standards-drift.sh:133-134`). Correcting FT-54's Effect paragraph is
  now a Phase-1 deliverable, because option 3 of that founder decision is "accept
  and annotate the two expected lines" — a choice that would otherwise be made on a
  false premise.
- **OPEN — conflicting preconditions for wiring `--rulesets` into the weekly job.**
  Phase 0 says "as soon as Task 1 (and if needed Task 2) is done"; the Risk table
  says "Phase 2 makes the channel consumed *before* Phase 1 is wired weekly" — which
  additionally implies the FT-54 founder decision. These are materially different
  schedules. **Not folded: this is a scheduling fork for the founder.** The plan's
  own 56b argument (a warning in an unconsumed channel is not a gate) favours
  Phase 0 → FT-54 → Phase 2 consumption → *then* wire; the counter-argument is that
  a ruleset-deletion warning is severe enough to be worth emitting even into an
  unconsumed channel.

Non-blocking nits folded alongside: stale ledger-23 phase annotation; the
consumer-fixture acceptance row now states the run is *without* `--rulesets` (and
adds the with-flag counterpart); Phase 3's `--skip-rulesets` sketch flagged as the
write-side twin of the read-side blast radius.

**Result:** 2 of 3 folded; 1 open decision. Circuit-breaker reached (3 independent
passes) — surfacing to the founder rather than dispatching a fourth.
