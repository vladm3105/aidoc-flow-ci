# PLAN-028 — `dev` → `staging` → `main` branching, and the surfaces that assume one branch

**Status:** In Progress — **Phase A EXECUTED** (#517); Phase B is the remaining
work; Phases C/D **deferred to a follow-on plan**. **RE-SCOPED 2026-08-23** under
`verified-planning` §3.1: three folds grew this plan 325 → 522 lines while
retiring findings, which is the defect signal, and the prescribed response is to
cut scope rather than fold a fourth time.

**The decision set** (§3.2 — the claims that change what gets built): which
bypass mechanism makes promotion possible (Claim 90, PROBE); whether `main` can
receive the release-prep merge (B4); which branch each runtime resolver should
anchor to (B2/B2b); what the non-adopting default must be (B0); **where the Code
Scanning baseline should live** (B5 — it decides which of the 19 trigger sites
move); and **the remedy shape for a pre-push gate that refuses every promotion**
(B3, upstream `#432`). Everything
else in this plan is evidence for those four.
**Owner:** canon (aidoc-flow-ci)
**Scope:** the branching standard, the enforcement surfaces that would silently
contradict it, post-merge branch hygiene, and canon's own Wave-0 self-adoption.
Consumer cutovers are **out of scope** — adoption is per-repo opt-in.
**Change level:** C3.
**Semver: UNRESOLVED — and it currently reads MINOR.** Two drafts have now given
a rationale their own phases contradict. B0 requires the non-adopting default to
reproduce today's behaviour, so B2 changes nothing an unopted consumer observes;
and `--repin` rewrites `uses:` tag strings only and **cannot** deliver a
caller-body change, so B5's trigger edits reach a re-pinning consumer not at all
— only one running `--update`. Under `CLAUDE.md`'s rule (breaking change to
consumer surfaces = MAJOR, additive = MINOR), an opt-in change with a
behaviour-preserving default is MINOR. **One reach path the earlier drafts missed:** a tag pin resolves the
**reusable** body, so any change to `.github/workflows/*.yml` reaches every
re-pinning consumer immediately — **and so does any script a reusable fetches at
that pin**: `standards-drift.yml` curls `sync/check-standards-drift.sh` from the
adopted tag at run time, which is the very file B2 and B2c edit — and §3 Class A rows 3 and 4 (`composition.yml`,
`ai-review.yml`) are reusables this plan assigns remediation. MINOR therefore
holds **only under an invariant the plan has never stated**: that every reusable
change defaults to today's `default_branch` behaviour. Without it, moving
composition's trust anchor is a merge-gate behaviour change delivered to
consumers who never opted in — which is the breaking surface. **State that
invariant in B0 alongside the protection default, then MINOR is defensible;
otherwise name the surface and ship MAJOR.** Do not assert either a third time
without resolving this.

## 1. The founder's decisions

Given, not re-litigated here (2026-08-23). Their *consequences* are what this
plan works out, and §3 shows two of them are more expensive than they look.

1. **`dev` is GitHub's `default_branch`.** `main` is the protected release
   branch; `ci/vX.Y.Z` tags are cut there.
2. **Promotion is FAST-FORWARD ONLY** (`dev` → `staging` → `main`).
3. **Canon defines the model; adoption is per-repo opt-in.**
4. **Plan first, then implement.**
5. **Post-merge hygiene** (2026-08-23): after a merge, delete the remote branch,
   delete the local branch, prune stale remote-tracking refs, switch to the
   default branch and fast-forward it. **Sync only — nothing is pushed.**

## 2. The two things that block this model — both now PROBE-gated

**(a) Fast-forward promotion is blocked by the profile canon ships.**
`required_pull_request_reviews` is non-null (Claim 8), which on the GitHub API
*is* "require a PR before merging" — so `git push origin dev:staging` is refused
for every non-bypass actor. No PR merge method fast-forwards
(`allow_merge_commit` and `allow_rebase_merge` are both false, Claim 7), so a
promotion PR would be **squashed**: a new SHA for identical content, the exact
divergence FF-only exists to prevent.

**Why one half is asserted and the other probed.** That a non-null
`required_pull_request_reviews` blocks direct pushes is documented GitHub
behaviour that three independent reviews agreed on. Which bypass *lifts* it on a
user-owned repo is where three drafts produced three different answers — that
disagreement, not the fact's category, is what makes it a probe.

**Which bypass works on a user-owned repo cannot be settled from source.** Three
drafts produced three different answers — `restrictions` (narrows rather than
exempts, and org-only per Claim 19), a ruleset `bypass_actors` (inert alongside
classic protection, Claim 32), `enforce_admins: false` (the incumbent, Claim 9,
but it exempts admins from *everything* on that branch). **This is Claim 90, a
PROBE.** It is the reason the earlier drafts churned: the process demanded prose
where only a measurement would do.

**(b) The release flow puts a commit on `main` that `dev` will not have.**
`release.sh prep` branches from `main` (Claim 21) and the checklist squash-merges
that PR back into `main` (Claim 22), after which `git push --ff-only origin
dev:main` fails — recoverable only via a back-merge needing the same bypass.
B4 owns it.

*(An earlier draft also claimed docs-sync writes to `main`. It does not — the
live-mode step is a stub, Claim 35. Retracted; the history is in the Review log.)*

## 3. What the flip breaks — TWO opposite classes, needing opposite fixes

Draft 2 listed ten surfaces under one premise ("they resolve the branch at
runtime, so they follow the flip"). That premise is **false for three of them**,
and the two classes need opposite remediation — so merging them is what let B5
under-scope.

**Class A — runtime resolvers.** These follow the flip with nobody editing them.
They need a **branch parameter** (B2).

| # | Surface | Claim | After the flip |
|---|---|---|---|
| 1 | `apply-standards.sh` protection PUT | 5 | Protects `dev`. `main`'s existing protection persists — a PUT to one branch removes nothing from another — so on an **existing** repo this never *unprotects* `main`, it **never protects** it; on a fresh adoption `main` is bare |
| 2 | `check-standards-drift.sh` | 6 | Verifies `dev`. With `dev` unprotected it emits `no protection on dev` and increments DRIFT — it reports **loudly, not clean** (draft 2 had this inverted). The load-bearing half stands: it never looks at `main` |
| 3 | **`composition.yml` trusted allowlist** | 24 | Reads the ai-review config from the default branch **because that base is protected and non-PR-mutable**. The trust anchor moves to the integration branch |
| 4 | **`ai-review.yml` FT-15 pin resolution** | 25 | `CALLER_REF` = default branch for non-`pull_request_target` events. `dev` and `main` legitimately hold *different* canon pins under a promotion model, so one repo resolves two canon versions depending on the event |
| 5 | `apply-standards.sh` pre-mutation backup | 26 | Snapshots `dev` while the operator believes it holds the release branch's pre-state |
| 6 | `check-pin-currency.sh` | 27 | Fleet currency reports `dev`'s pin while production runs `main`'s |
| 7 | `deploy-ci-wizard.sh` | 28 | Enumerates deployed workflows from `dev` |

Rows 3 and 4 are **trust boundaries**. Any claim that B1 is "the one place this
plan changes a security posture" is false while they stand.

**Class B — hardcoders.** These do **not** follow the flip; they go **dead**.
They need trigger/range edits (B3, B5).

| # | Surface | Claim | After the flip |
|---|---|---|---|
| 8 | 17 shipped caller templates, `push: branches: [main]` | 12, 13 | **Every post-merge arm stops firing**, because merges land on `dev`. Silent |
| 9 | `codeql.yml` + `codeql-private.yml`, `pull_request: branches: [main]` | 35 | **Zero feature PRs** trigger CodeQL — `on.pull_request.branches` filters the **base** ref, and no check run is created at all |
| 10 | `pre_push_check.sh` ×2, `origin/main` fallback | 4 | Lints the `main..dev` delta plus the feature commits |

**Row 9's Code Scanning damage is the inverse of the obvious reading**, and both
earlier drafts got it wrong in different directions. Alerts anchor to the
**default** branch; after the flip there is **no `push: dev` run at all**, so the
default-branch baseline is never populated. `main` keeps receiving push runs,
uploading SARIF for a now-non-default ref that the default alert view does not
surface. Keeping the scanners on `main` does not fix that — it *is* that.

**Not in either class:** `docs-sync.yml`'s caller-ref (a row draft 2 listed) cites a
path the code **deliberately rejects** — it does not use `github.workflow_ref`
precisely because that is the caller's default branch (FT-15). The flip changes
nothing there. Removed.

## 4. Phases

### Phase A — the standard — **EXECUTED** (#517, 2026-08-23)

`docs/BRANCHING.md` rewritten for the model, `REPO_STANDARDS.md` §2, the
post-merge hygiene rule, and the CHANGELOG entries all shipped. The standard
states its own **unadopted** status, so nothing reads it as live.

Not carried forward as planned work; see the Review log for what the three
passes corrected in it before it shipped.

### Phase B — enforcement surfaces

- **B0. The declaration surface — FIRST.** B2 and B3 both assume "the branch set
  the repo opted in for" and no such declaration exists: both scripts take only
  `--tier`, and tier cannot express it (three repos share `product`, Claim 40).

  **The non-adopting default is "protect the repo's API-reported DEFAULT
  BRANCH", not "protect `main`."** Draft 2 wrote the latter, twice — which would
  **revert M4-sec**, a deliberate security fix that removed exactly that
  hardcoding (Claim 41), with consumers on `master`/`develop` a real handled
  case. The correct default is both today's behaviour and forward-compatible.
- **B1. 🔴 The bypass mechanism — PROBE FIRST (Claims 90, 91).** The cut deleted
  the section this used to point at, taking the deliverable with it; it lives
  here now. Three candidates, and **canon's own precedent is to trial on a
  throwaway private repo, never on canon** (`DECISIONS.md` records a probe
  created on `aidoc-flow-business`, read back, deleted):

  | Candidate | Status |
  |---|---|
  | `required_pull_request_reviews.bypass_pull_request_allowances` | semantically correct (exempts rather than narrows); acceptance on a **user-owned** repo is the unknown |
  | `enforce_admins: false` | the incumbent — canon already runs it (Claim 9) and B2 edits the field. Cost: exempts admins from *everything* on that branch |
  | ruleset `bypass_actors` | **refuted alongside classic protection** (Claim 70) — but *replacing* classic protection with a ruleset is unexamined |

  **Acceptance criterion:** a non-admin actor completes
  `git push --ff-only origin <src>:<dst>` against a branch carrying the
  candidate payload. Applying the payload is not the measurement — the push is.
  Record the payload that worked; it becomes B2's input.
- **B2. Protection targeting** — every declared branch, not `default_branch`.
  Covers §3 Class A rows 1-2 **only**.
- **B2c. The drift checker's blind spot (§6).** Conditional on B1's outcome: if
  B1 lands a field *inside* `required_pull_request_reviews`, extend
  `check-standards-drift.sh`'s four-field `review_filter` so the bypass is
  visible to drift detection. If B1 lands `enforce_admins: false`, no change is
  needed — that field is already compared directly. §6 identified this remedy
  and no phase owned it.
- **B2b. The other five Class A resolvers — rows 3-7, and TWO ARE TRUST
  BOUNDARIES.** The pass-2 fold assigned all of Class A to B2, whose text
  covers protection targeting alone; rows 3 (`composition.yml`'s allowlist),
  4 (`ai-review.yml`'s FT-15 pin), 5 (the backup), 6 (`check-pin-currency.sh`)
  and 7 (the wizard) had **no work item at all**, so an implementer completing
  B2 would believe Class A was discharged. Decide per row whether the default
  branch is still the right anchor after the flip — for rows 3 and 4 that is a
  security question, not a path question.
- **B3. `pre_push_check.sh` — the promotion push shape.** The `origin/main`
  fallback is the lesser half. A promotion push from a current `dev` yields an
  **empty** commit range, and the script treats empty as a **hard failure**
  (Claim 34b) — canon's own mandatory gate refuses every promotion, with a
  remedy that cannot clear it. Both copies ship, and are identical in the load-bearing respects (`install/templates/pre_push_check.sh`, Claim 92).
- **B4. Release flow — a CHANGE** (§2b). State which branch `prep` starts from
  and which its PR targets. `tag`'s `main` guard may stay; `prep`'s cannot.
- **B5. Triggers — 19 sites, not 2.** Draft 2 named CodeQL and "post-merge
  scanners"; the real count is `branches: [main]` **19 times across 17 files**
  (Claim 12) — 2 `pull_request` filters, 17 `push` arms.
  - **All 17 post-merge arms go silent** at the flip.
  - **CodeQL is the sharpest case:** an absent check, not a reduced one — and
    because `codeql` is in no tier's required contexts (Claim 42), it fails as a
    silently missing gate rather than a hung PR.
  - Where the Code Scanning baseline should live is a **real decision** (§3).
  - Still true: do not blanket-add `dev`/`staging`.

- **A4-residual. Decide the post-merge-hygiene pre-push warning.** Phase A
  shipped, but it left one decision open and **merged canon delegates to it by
  name**: `docs/BRANCHING.md` §7 says "a local pre-push warning is *available* at
  the same strength as the audit phrase above; **PLAN-028 A4 decides whether to
  take it**", and `CHANGELOG.md` repeats it. The cut removed Phase A as planned
  work and took the undecided decision with it, leaving two live dangling
  references. Decide it here — take the local hook, or decline it and say why —
  and update both surfaces in the same change.

- **B6. `docs/REPO_STANDARDS.md` update — MANDATORY, not optional.** `CLAUDE.md`
  requires that *every* canon-body change ships with a rulebook update, and
  B0/B2/B2b/B2c/B3/B5 all change canon bodies (`install/`, `sync/`, `scripts/`,
  `install/templates/workflows/`). B0 in particular introduces a new
  consumer-facing declaration contract. `standards-drift` is the check that
  detects the divergence if this is skipped.

### Phases C and D — DEFERRED to a follow-on plan

Canon self-adoption and the consumer opt-in path are both gated on Claim 62's
PROBE and on B3, and neither can be planned meaningfully until the bypass is
known. Planning them here is what grew this plan 60% across three folds while
retiring findings.

They move to their own plan, **reviewed on their own budget** — the pattern this
repo already used when PLAN-025's cap was spent and PLAN-026 took the remaining
phases. Two constraints carry forward so they are not rediscovered:

- Canon's protection must be applied by per-section `gh api` PUTs, **never**
  `apply-standards.sh --apply --tier product`, which `CLAUDE.md` forbids on canon
  (Claim 36) — it requires checks canon does not self-run and would hang every
  canon PR.
- Every shipped consumer profile sets `enforce_admins: true` (Claim 17), so a
  consumer has no promotion path until a template changes.

## 5. What this plan does NOT do

- Cut over any consumer.
- Change the squash-only rule for feature PRs.
- Blanket-add `dev`/`staging` triggers.
- Claim the post-merge hygiene rule is enforced (A4).

## 6. Known gap in the drift checker — corrected

Draft 2 claimed the checker "reads **neither** `restrictions` **nor**
`required_pull_request_reviews`". **The second half was false.** It *does*
compare `required_pull_request_reviews`, as a normalized four-field subset
(Claim 43), so a null-vs-object difference is detected. It also compares
`required_status_checks.strict`, a fifth comparison draft 2 omitted.

The conclusion survives **for a different reason**, and the difference changes
the fix: the filter is an **allowlist of four sub-fields**, so
`bypass_pull_request_allowances` is projected away and is invisible; `restrictions`
is genuinely unread; and rulesets are not read at all (relevant to B1's refuted
candidate). **But not for every candidate, and the pass-2 fold overstated this too.** If B1 lands `enforce_admins: false` — the candidate §3 calls the incumbent — drift detection **already catches it**: the checker compares `enforce_admins` directly, and `CLAUDE.md` records it firing on canon today. §6 is true only for `bypass_pull_request_allowances` and `restrictions`. So the remedy depends on which candidate B1 picks — extend the `review_filter` only if B1 lands a field inside `required_pull_request_reviews`.

Where a remedy IS needed it is **extend the `review_filter`**, not "make it read
`required_pull_request_reviews` at all". Folding a wrong statement about a gate
into a plan is the same failure this repo records as "assert the teeth".

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 62 | Before #517 the standard protected exactly one branch; it now protects the repo's DEFAULT branch, and all three under the opt-in model — which is why B0's non-adopting default must be 'the default branch', not 'main' | `All non-paused repos protect` | docs/REPO_STANDARDS.md:124 |
| 63 | `pre_push_check.sh` falls back to `merge-base HEAD origin/main` when there is no upstream | `git merge-base HEAD origin/main` | scripts/pre_push_check.sh:80 |
| 64 | `apply-standards.sh` PUTs branch protection to the API-reported default branch | `branches/${default_branch}/protection` | install/apply-standards.sh:710 |
| 65 | `check-standards-drift.sh` resolves the default branch from the API and verifies that branch | `DEFAULT_BRANCH=$(gh api` | sync/check-standards-drift.sh:166 |
| 66 | Shipped repo settings disable merge commits, leaving squash the only PR merge method | `"allow_merge_commit": false` | install/templates/repo-settings.json:6 |
| 67 | The shipped product profile sets `required_pull_request_reviews` — GitHub's "require a PR before merging" | `required_pull_request_reviews` | install/templates/branch-protection-product.json:15 |
| 68 | Canon's `main` sets `enforce_admins: false` as the deliberate FT-52 release-prep bypass | `enforce_admins: false` | docs/RELEASE_CHECKLIST.md:174 |
| 69 | `release.sh prep` refuses unless the current branch is `main` | `must be on main to prep` | scripts/release.sh:253 |
| 11 | `release.sh tag` refuses unless the current branch is `main` (the BRANCH guard; the separate VERSION assertion is at :424) | `must be on main to tag` | scripts/release.sh:418 |
| 12 | Code Scanning alerts anchor to the DEFAULT BRANCH, which is why the scanners need a post-merge run there | `anchored to the DEFAULT BRANCH` | install/templates/workflows/scanners.yml:38 |
| 13 | `docs-sync` is a post-merge flow gated on `push: main` | `POST-MERGE flow` | install/templates/workflows/docs-sync.yml:5 |
| 14 | Squash is the canonical merge method in the standard's prose | `Squash merge is the canonical merge method` | docs/BRANCHING.md:178 |
| 15 | The branch-protection templates are branch-agnostic payloads, so one profile can be applied to several | `required_status_checks` | install/templates/branch-protection-product.json:3 |
| 16 | The shipped enforcement map states the PR requirement binds non-bypass actors | `PR required for a protected branch` | docs/BRANCHING.md:235 |
| 17 | Every non-umbrella shipped profile sets `enforce_admins: true`, so consumers have no admin bypass | `"enforce_admins": true` | install/templates/branch-protection-product.json:14 |
| 18 | Branch protection and rulesets aggregate and the stricter wins; ruleset `bypass_actors` is scoped by threat model | `bypass_actors` | DECISIONS.md:1877 |
| 19 | `vladm3105` is a personal User account with no orgs, so org-only fields are unavailable | `personal **User** account` | DECISIONS.md:1973 |
| 20 | docs-sync's header DECLARES a required bypass scoped to the aidoc-flow-bot App — a design requirement in a `SAFETY` comment, NOT evidence that one is provisioned (see B1) | `bypass scoped to aidoc-flow-bot App only` | .github/workflows/docs-sync.yml:15 |
| 21 | `release.sh prep` creates the prep branch from the current checkout, which its guard forces to be `main` | `git checkout -q -b "$branch"` | scripts/release.sh:258 |
| 22 | The release checklist merges the prep PR into main with a squash + admin merge | `gh pr merge <N> --squash --delete-branch --admin` | docs/RELEASE_CHECKLIST.md:175 |
| 23 | The text "commit these changes directly to main" is the BODY OF A DRY-RUN PR COMMENT describing what live mode *would* do — it is not the behaviour, and citing it as such was the §4 overclaim (see Claim 35 for the actual stub) | `commit these changes directly to main` | .github/workflows/docs-sync.yml:337 |
| 24 | `composition.yml` reads its trusted allowlist from the default branch because that base is non-PR-mutable | `DEFAULT_BRANCH=$(gh api` | .github/workflows/composition.yml:204 |
| 25 | `ai-review.yml` resolves the caller ref from the default branch for non-`pull_request_target` events | `CALLER_REF="${CALLER_DEFAULT_BRANCH}"` | .github/workflows/ai-review.yml:637 |
| 26 | `apply-standards.sh`'s pre-mutation backup captures the default branch's protection | `local backup_dir slug ts backup_file default_branch` | install/apply-standards.sh:721 |
| 27 | `check-pin-currency.sh` reads each consumer's pins from its default branch | `default_branch="$($GH api` | sync/check-pin-currency.sh:65 |
| 28 | `deploy-ci-wizard.sh` enumerates deployed workflows from the default branch | `defbr="$($GH api` | install/deploy-ci-wizard.sh:160 |
| 29 | `docs-sync.yml` resolves the caller's entry ref as the consumer's default branch | `consumer's default branch` | .github/workflows/docs-sync.yml:130 |
| 30 | The shipped lifecycle requires cleanup on BOTH sides after a merge | `Clean up, remote` | docs/BRANCHING.md:113 |
| 31 | Shipped repo settings already automate remote branch deletion on merge | `"delete_branch_on_merge": true` | install/templates/repo-settings.json:9 |
| 32 | The enforcement map already has a row for rules that are review conventions rather than enforced settings | `Naming and single-purpose branch` | docs/BRANCHING.md:241 |
| 34 | `pre_push_check.sh` treats an EMPTY push range as a hard failure, not a pass | `EMPTY — NOTHING was verified` | scripts/pre_push_check.sh:282 |
| 35 | `codeql.yml` filters the `pull_request` trigger to `branches: [main]`, so a PR based elsewhere never triggers it | `pull_request:` | install/templates/workflows/codeql.yml:17 |
| 36 | `CLAUDE.md` forbids running `apply-standards.sh --apply --tier product` on canon | `Never run` | CLAUDE.md:444 |
| 70 | On an `enforce_admins: true` repo a ruleset bypass is INERT — protection and rulesets aggregate and the stricter wins | `the ruleset bypass is **inert**` | DECISIONS.md:1941 |
| 33 | The shipped standard states the invariant the whole model rests on: `main` takes only fast-forwards | `receives ONLY fast-forwards` | docs/BRANCHING.md:62 |
| 71 | `release.sh` prints "open the prep PR" as a HUMAN step — the script does not create it, so `gh pr create`'s `--base` default applies | `open the prep PR` | scripts/release.sh:362 |
| 34b | `pre_push_check.sh` treats an EMPTY push range as a hard failure | `EMPTY — NOTHING was verified` | scripts/pre_push_check.sh:282 |
| 72 | docs-sync's live-mode Apply is an alpha.1 STUB that echoes a notice and commits nothing | `alpha.1 stub` | .github/workflows/docs-sync.yml:317 |
| 36b | The shipped docs-sync config sets `dry_run: true`, so live mode is not armed | `"dry_run": true` | install/templates/docs-sync.json:6 |
| 37 | This repo's own gated ledger already records that a `dry_run: false` flip alone does nothing | `alpha.1 stub` | plans/PLAN-007_production-hardening.md:50 |
| 38 | `BRANCH_PROTECTION.md` instructs using the repo's ACTUAL default branch and keeping `enforce_admins: true` | `actual default branch` | docs/BRANCH_PROTECTION.md:103 |
| 39 | The enforcement map already counts a LOCAL pre-push hook as enforcement, not convention | `local pre-push hook` | docs/BRANCHING.md:240 |
| 40 | Three repos share the `product` tier, so tier cannot express per-repo opt-in | `Product code` | docs/REPO_STANDARDS.md:112 |
| 41 | The hardcoded-`main` protection target was deliberately REMOVED as defect M4-sec | `M4-sec: use the target's actual default branch` | install/apply-standards.sh:706 |
| 42 | `codeql` is in no tier's required status checks, so its absence is a missing gate rather than a hung PR | `required_status_checks` | install/templates/branch-protection-product.json:3 |
| 43 | The drift checker DOES compare `required_pull_request_reviews`, as a four-field subset — so the gap is the allowlist projecting away the bypass field | `review_filter=` | sync/check-standards-drift.sh:260 |

| 61 | `branches: [main]` appears 19 times across 17 shipped caller templates — 2 `pull_request` filters, 17 `push` arms | `branches: [main]` | install/templates/workflows/codeql.yml:16 |

| 90 | Which bypass permits a fast-forward push on a USER-OWNED repo whose branch has `required_pull_request_reviews` — **blocks B1, and through it Phases C and D** | `n/a` | PROBE: on a THROWAWAY private repo — apply candidate payload, then `git push --ff-only origin a:b` as a NON-admin and observe. Applying is not the measurement; the push is |
| 91 | Whether a branch RULESET on canon's `main` aggregates with classic protection and defeats `enforce_admins: false` — **blocks B1**, whose incumbent candidate is exactly that field. (Recorded prior, not a substitute for measuring: canon's rulesets were `[]` pre-FT-52 and FT-52 added one **tag** ruleset, so the expected answer is 'no branch ruleset' — confirm, do not assume) | `n/a` | PROBE: gh api repos/vladm3105/aidoc-flow-ci/rulesets --jq '.[].target' |

| 92 | The shipped consumer copy of the pre-push gate carries the identical empty-range refusal | `EMPTY — NOTHING was verified` | install/templates/pre_push_check.sh:282 |

## Review log

### Pass 1 - 2026-08-23 - independent

`verified-planning-reviewer`, fresh context. **10 load-bearing, 5 minor.** All
folded; each verified against source first. The three that changed the plan's
shape: the `restrictions` mechanism was wrong twice over (narrows rather than
exempts; org-only on a User account); FF-only collides with writers to `main`;
the "surfaces that follow the flip" table listed four of ten, two of the misses
being trust boundaries. Also: CodeQL runs on zero feature PRs; the Code Scanning
analysis was inverted; the promotion push trips canon's own pre-push gate; the
declaration surface B2/B3 assumed does not exist. My canon workflow count was 12
and is **7** — the grep counted commented-out blocks.

**Result:** revisions folded; re-dispatch required.

### Pass 2 - 2026-08-23 - independent

`verified-planning-reviewer`, fresh context. **9 load-bearing, 4 minor — and the
pass-1 FOLD introduced most of them.** The pattern PLAN-027 §A5 records held for
a third time.

The one that matters most is an **overclaim I committed inside the section that
invokes the rule against overclaiming**: §4 asserted docs-sync commits to `main`.
It does not — the live-mode Apply step is an alpha.1 **stub** (Claim 35), live
mode is unarmed (Claim 36b), and this repo's own ledger already said so
(Claim 37). I had cited the **body text of a dry-run PR comment** — "in live
mode, the bot *would* commit…" — as if it were behaviour. §4 now names **one**
writer to `main`, not two, and docs-sync's real exposure moves to §5 as a dead
trigger.

Also folded, all verified before acceptance:

- **§3's candidate set was wrong in both directions.** The ruleset candidate is
  **refuted** by CI-0029 — inert on an `enforce_admins: true` repo (Claim 32) —
  and `enforce_admins: false`, the mechanism canon **already runs**, was missing
  entirely. Consequence: "consumers have zero paths" was overstated, and Phase C
  is **not** blocked on B1.
- **The "aidoc-flow-bot bypass already works" lead was my own fold's invention** —
  Claim 20 cites a `SAFETY` header comment, a design requirement for the stubbed
  feature. Downgraded to unverified.
- **B0 would have reverted a security fix.** "Non-adopting default: protect
  `main`" — written twice — is exactly the hardcoding removed as M4-sec
  (Claim 41). It is now "protect the API-reported default branch".
- **§6 was false.** The checker *does* read `required_pull_request_reviews`
  (Claim 43). The gap is real but is the allowlist projecting away the bypass
  field — a different fix.
- **§5 merged two opposite classes.** Split: runtime resolvers (follow the flip,
  need a branch parameter) vs hardcoders (go dead, need trigger edits). Row 2's
  failure mode was inverted; docs-sync's caller-ref row cited a path the code
  deliberately rejects and is removed.
- **B5 was 2 sites; it is 19** across 17 files.
- **Phase A missed `BRANCHING.md` §1** — the section that most directly forbids
  this model — and `BRANCH_PROTECTION.md` entirely.
- **Semver is now UNRESOLVED and reads MINOR.** Two rationales have contradicted
  their own phases; the third will not be asserted without a real breaking
  surface.
- **A4's "unenforceable" gave up early** — canon ships a client-side gate the
  standard already counts as enforcement (Claim 39). Now an explicit decision.

Folded independently of the review, from executing A4 for real: **`git branch
--merged` is the wrong detector.** Measured on canon — it reported 0 merged
branches while 14 of 16 had merged PRs, because squash-merge rewrites the SHA.
A4 now names PR state as the detector and `-D` as the required flag.

**Result:** revisions folded; one dispatch remains under the OPS-0066 cap.

### Pass 3 - 2026-08-23 - independent (OPS-0066 CAP REACHED)

`verified-planning-reviewer`, fresh context. **9 load-bearing, 4 minor — and the
pass-2 fold introduced most of them. The pattern held a THIRD time.**

Its verdict on the question that matters: *"Not yet safe to hand over — but the
reason is not the marked unknowns."* B1 and the semver are honestly marked. The
problem was the **new certainties the pass-2 fold asserted while retracting the
old ones** — the same shape as the pass-1 fold's docs-sync overclaim: a
retraction that over-swings into a fresh unmeasured assertion.

Folded:

- **"Canon can promote today" was false** — the plan's own B3 says the pre-push
  gate refuses a promotion push. Now "after B3", and Phase C is sequenced on B3.
- **The unblocking inference had no ruleset measurement.** `enforce_admins:
  false` governs *classic* protection only; rulesets aggregate separately and §8
  confirms nothing reads them. Now marked UNMEASURED with the probe command.
- **§8's conclusion was false for the incumbent candidate** — the checker
  compares `enforce_admins` directly, so if B1 lands that, drift detection
  already catches it. Narrowed to the two fields it is actually true for.
- **§3 Class A rows 3–7 had no owning phase.** B2's text covers protection
  targeting only, so the two **trust boundaries** were the rows with no work
  item. B2b added.
- **A4's detector was unsound**: `.[0].state` takes an arbitrary element of an
  unordered set (a reused branch has several PRs), and `-D` was prescribed
  unguarded — removing the safety net `-d` exists for. Now `any(.[]; …)` plus a
  containment check.
- **The semver reach argument missed reusables** — a tag pin resolves the
  *reusable* body, so `.github/workflows/*.yml` changes reach every re-pinning
  consumer. MINOR now holds only under an invariant that must be stated in B0.
- **Ledger integrity**: four duplicate identifiers (32, 34, 35, 36) meant prose
  references resolved to the wrong rows; a blank line had terminated the table so
  every pass-2 row rendered as a paragraph. Both repaired.
- **Two ledger rows still asserted the retracted claims** (20, 23) after the
  prose retracted them — a reader checking the plan's own instrument of record
  still got both. Rewritten.
- **Claim 11's text contradicted its own citation.**
- **My markdownlint auto-fixer had corrupted API field names inside code spans**
  (`bypass*actors`, `enforce_admins` → `enforce*admins`). §3's deliverable is an
  API payload; copied, it would 422. A blind regex over a file it did not
  understand — the tooling equivalent of the same defect class.

**Not folded, recorded instead:** the reviewer notes "REFUTED" is stronger than
the evidence supports for the ruleset candidate. The refutation holds for a
ruleset *alongside* classic protection; **replacing** classic protection with a
branch ruleset carrying `bypass_actors` is unexamined, and this workspace runs
exactly that live on a user-owned repo (umbrella ruleset). It changes no action
while B1 stays open, but the probe should cover it.

**Result: NOT READY, and the OPS-0066 cap is spent.** Three dispatched passes;
no fourth. **This fold is therefore UNREVIEWED** — every previous fold introduced
defects, and there is no reason to believe this one is the exception. It was
written to be subtractive where possible (removing certainty rather than adding
claims), which bounds but does not eliminate the risk.

**Handed to the human with these open items:**

1. 🔴 **B1** — the promotion bypass. Three drafts, three different answers. It
   needs a live probe, not a fourth paper answer.
2. **The ruleset surface is unmeasured** on canon's `main` (§3).
3. **Semver** — state B0's reusable-invariant, or name the breaking surface.
4. **Whether FF-only is still wanted** now the cost is one writer (the release
   flow), not two.

### Re-scope - 2026-08-23 - `verified-planning` §3.1 applied

**Not a fourth fold.** The OPS-0066 cap was spent, and the skill's §3.1 — added
because *this plan* was the evidence — prescribes cutting scope rather than
folding again once growth is the signal. It was:

```text
lines:  325 -> 422 -> 522   (folds of passes 1, 2, 3)  ->  403  (cut)
```

Three folds grew the plan 60% while retiring findings. That is the defect the
new rule names.

**What the cut removed** (subtractive per §3.1 rule 1):

- **§2–§4 collapsed into one §2.** Three sections narrated the same two blockers
  and their retraction history; the Review log already holds the history.
- **Phases C and D deferred** to a follow-on plan, on the PLAN-025 → PLAN-026
  precedent this repo already set. Both are gated on the bypass probe, so
  planning them here was manufacturing surface that could not be decided. Two
  constraints carried forward so they are not rediscovered.
- **Phase A removed as planned work** — it EXECUTED in #517.
- **Two spent claims deleted**: they justified rewriting `BRANCHING.md` §2/§6,
  that rewrite shipped, and their cited text no longer exists by design. The
  gate caught them, which is the ledger doing its job.

**What the cut added, and why it is the point:**

Claims **90** and **91** are `PROBE` rows — the state added in the same skill
change. The bypass mechanism and the ruleset surface are **live facts**; source
cannot settle either. Under the old rules they had nowhere legitimate to sit, so
three consecutive drafts *guessed* and each fold retracted the last. They now
block the phases that depend on them and leave the rest of the plan free.

**Decision set named** (§3.2): the four claims that change what gets built.
Everything else is evidence for them.

**Result:** re-scoped; the reduced artifact is UNREVIEWED and one pass is owed
on it.

### Pass 4 - 2026-08-23 - independent (on the RE-SCOPED artifact)

`verified-planning-reviewer`, fresh context, reviewing the 403-line cut rather
than the 522-line plan the first three passes saw. **11 load-bearing, 5 minor.**

**Its verdict on the new PROBE mechanism, which is what this pass existed to
test: "Honest in kind, not yet honest in instrument."** Both rows are genuinely
unmeasurable from source — the mechanism is *not* being used to park work — but
its first use was executed badly in exactly the two ways that matter:

- **Claim 90's command could not produce the answer it was cited for.** It
  applied a protection payload and never attempted the push. Applying is not the
  measurement; the push is. Also targeted **canon** rather than a throwaway,
  against this repo's own probe precedent.
- **Claim 91 named a phase this same cut had deleted**, so it blocked nothing —
  and the fact it carries is really an input to **B1**, whose incumbent
  candidate is the very field a ruleset would defeat.

**That is a gap in the rule I wrote, not just in this plan.** §3.1 requires a
PROBE to name a command and a blocked phase; it does not require the command to
*settle* the claim, nor guard against the named phase being deleted out from
under it. Both are now fixed here; the rule should follow.

**And the failure mode MOVED, which is the other result worth recording.** The
reviewer found **no surviving semantic falsehood in the source-cited body** —
the place all three previous passes kept finding them. What broke instead was
the plan's **internal integrity under a mechanical cut**: the renumber collided
two ledger IDs with the new PROBEs and left nine prose references dangling or
resolving to the wrong row; B1 lost its entire body when §3 was deleted; and
**two decisions were orphaned while merged canon still delegated to them by
name** (`BRANCHING.md` pointed at "PLAN-028 §3" and "PLAN-028 A4"). So the
subtractive fold is safer on *facts* and more dangerous to *references* — a
trade the rule should state.

All folded, including three phases that owned nothing (B2c for §6's remedy, B6
for the mandatory rulebook update, A4-residual for the orphaned decision), the
semver reach path through scripts fetched at the pin, and B0's form constraint
imposed by an offline local hook.

**Result:** folded; the fold is unreviewed and the reduced plan is **In
Progress**, gated on Claims 90 and 91.
