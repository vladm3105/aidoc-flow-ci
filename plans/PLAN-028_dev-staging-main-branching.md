# PLAN-028 — `dev` → `staging` → `main` branching, and the surfaces that assume one branch

**Status:** Draft — no phase executed. **Phase B1 is 🔴 BLOCKED on a live probe**
(§3), and until it resolves, Phase D is undeliverable for consumers.
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
re-pinning consumer immediately — and §5 Class A rows 3 and 4 (`composition.yml`,
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

## 2. FF-only promotion is blocked by the profile canon ships

`install/templates/branch-protection-product.json` sets
`required_pull_request_reviews` to a non-null object (Claim 8). On the GitHub API
that object *is* "Require a pull request before merging", so a direct
`git push origin dev:staging` is refused for every non-bypass actor —
`docs/BRANCHING.md` states the same in its own enforcement map (Claim 16).

No PR merge method fast-forwards: `allow_merge_commit` and `allow_rebase_merge`
are both `false` (Claim 7), so a promotion PR would be **squashed** — a new SHA
for identical content, permanently diverging the branches, which is the outcome
decision (2) exists to prevent. The two SHA-preserving API alternatives
(`POST /repos/{o}/{r}/merges`, `PATCH /git/refs/heads/{b}`) do not escape: both
are ref updates subject to the same protection, and `/merges` creates a merge
commit regardless.

**Consumers have no promotion path at all — not even a narrow one.** All four
non-umbrella profiles set `enforce_admins: true` (Claim 17); only the umbrella
is `false`. Canon's live `main` is `false`, but that is an **FT-52 exception to
canon's own template** (Claim 9), not the fleet default. So an adopting consumer
gets a `main` with the PR requirement and no admin bypass: zero paths.

Measured on canon 2026-08-23 — a server-side fact, so it carries its
re-derivation command rather than a ledger citation:

```sh
gh api repos/vladm3105/aidoc-flow-ci/branches/main/protection \
  --jq '{pr_required: (.required_pull_request_reviews != null),
         restrictions: (.restrictions != null),
         enforce_admins: .enforce_admins.enabled}'
# -> {"pr_required":true,"restrictions":false,"enforce_admins":false}
```

## 3. 🔴 B1 — the bypass mechanism is UNRESOLVED, and two drafts have now guessed it wrong

**Draft 1 proposed a `restrictions` push allowlist.** Wrong twice: `restrictions`
*narrows* who may push rather than exempting anyone from the PR requirement, and
it is org-only while CI-0030 records — measured — that every workspace repo is
user-owned (Claims 18, 19).

**Draft 2 then over-corrected**, and pass 2 caught both halves:

| Candidate | Status |
|---|---|
| `required_pull_request_reviews.bypass_pull_request_allowances` | **The semantically correct field** — it exempts rather than narrows. Whether it accepts a **user-owned** repo is genuinely unresolved from source; this is what the probe is for |
| A repository **ruleset** with `bypass_actors` | **REFUTED, by this repo's own decision.** CI-0029 states that on an `enforce_admins: true` repo the ruleset bypass is **inert** — protection and rulesets aggregate and the stricter wins (Claim 32). It cannot exempt anyone from a PR requirement imposed by *classic* protection. Draft 2 listed its interaction as "unknown" when the cited decision answers it |
| `enforce_admins: false` | **The incumbent, and draft 2 omitted it entirely.** It is what canon already runs on its own `main` (Claim 9), it is not org-gated, and it is a field in the tier templates **B2 is already editing** (Claim 17). Cost: it exempts admins from *everything* on that branch, and `docs/BRANCHING.md` §1 separately forbids pushing directly "including when an administrator bypass is technically available" (Claim 33) |
| The `aidoc-flow-bot` App bypass | **Downgraded from "strongest lead" to "unverified".** Draft 2 claimed a working bypass already exists. Claim 20 cites a **`SAFETY` header comment** — a design *requirement* for a feature whose commit path is the stub in §4. A repo-wide grep finds no `bypass_actors`/`bypass_pull_request_allowances` configuration anywhere. Whether it was ever provisioned is itself part of the probe |

**⚠️ This inference is UNMEASURED on the aggregating surface.** `enforce_admins: false` governs *classic* protection only. Rulesets are a separate surface that aggregates, and `enforce_admins: false` has **no effect on a ruleset** (CI-0029). §8 confirms nothing here reads rulesets. Canon carries at least one live ruleset (tag-scoped), so the conclusion is *probably* right — but §2 carries a re-derivation command precisely because it is a server-side fact, and this overturns §2 carrying none. **Before relying on it, run:**

```sh
gh api repos/vladm3105/aidoc-flow-ci/rulesets --jq '.[] | {id, name, target}'
gh api repos/vladm3105/aidoc-flow-ci/rules/branches/main
```

**Consequence for §2's conclusion.** "Consumers have zero paths" was overstated:
`enforce_admins: false` is a path. Canon can promote **after B3** — not today: the mandatory local pre-push gate refuses a promotion push outright (B3, Claim 34b), so "today" was itself an overclaim added by the pass-2 fold. What is true
is that every shipped consumer profile sets `enforce_admins: true` (Claim 17), so
an adopting consumer has no path **until this plan changes a template** — which
is B2's job, not an immovable property of the world. Phase C is therefore **not**
blocked on B1; Phase D is.

## 4. FF-only collides with the release flow — and NOT with docs-sync

**(a) Every release. This half verifies.** `release.sh prep` branches from `main`
(Claim 21), writes VERSION, retires forward-pin markers and promotes the
CHANGELOG; the checklist merges that PR back into `main` with
`gh pr merge --squash --admin` (Claim 22). The squash commit exists on `main` and
not on `dev`, so `git push --ff-only origin dev:main` fails from then on.

"Permanently" is defensible **only with its condition stated**: squash-only plus
the PR requirement means a back-merge of `main` into `dev` cannot restore
ancestry without the same bypass B1 is blocked on. Say that rather than asserting
bare impossibility.

Two precision points draft 2 got wrong: the PR is opened by a **human step**
`release.sh` prints (Claim 34), not by the checklist — which is exactly what
makes `gh pr create`'s `--base` default bite once `dev` is default. And the
VERSION assertion is at `release.sh:424` (Claim 11); `:418` is the branch guard.

**(b) docs-sync does NOT write to `main`, and draft 2's claim that it does was
false.** The "Apply changes (live mode only)" step is an **alpha.1 stub** that
echoes a notice and commits nothing (Claim 35). Draft 2 cited
`docs-sync.yml:337` — which is the **body text of the dry-run PR comment**
("in live mode, the bot *would* commit…"), a conditional description of
unimplemented behaviour quoted as behaviour. Live mode is not armed anywhere:
both the canon and shipped configs set `"dry_run": true` (Claim 36), and this
repo's own gated ledger already records that a `dry_run: false` flip alone does
nothing (Claim 37).

**This is the plan's own §4.3i defect class**, committed inside the section that
invokes it: an unimplemented, unarmed, founder-gated hazard promoted to an active
one, driving a phase that prescribed changing code that does not exist.

docs-sync's **real** exposure after the flip is its **trigger**, not a write —
`push: branches: [main]` (Claim 13) stops firing when merges land on `dev`. That
belongs in §5/B5 with the other seventeen. The alpha.2 commit logic, when
written, must target the branch model — a constraint on future work.

## 5. What the flip breaks — TWO opposite classes, needing opposite fixes

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

## 6. Phases

### Phase A — the standard

- **A1. `docs/BRANCHING.md`, re-derived against the file** (draft 2 claimed to
  have done this and missed two sections):
  - **§1 is the section that most directly contradicts the model** and was
    untouched: "one protected default branch, normally `main`" (Claim 33), "Do
    not push directly, **including when an administrator bypass is technically
    available**", and the umbrella `--admin` flow "never authorizes a direct push
    and is **not a precedent for consumers**". A3 makes promotion exactly that
    shape; §1 pre-emptively denies the precedent.
  - **§7's enforcement map** — its row 1 ("PR required for default branch")
    silently becomes a statement about `dev`, and the map gains no row for
    promotion or the other protected branches.
  - §2 (Claim 1) and §6 (Claim 2) forbid the model outright — rewrite, not append.
  - §4 is default-branch-framed throughout.
  - §3 items 1 and 5 stay **true** — the default branch is now `dev`.
- **A2.** `docs/REPO_STANDARDS.md` §2 (Claim 3) → per-branch table.
- **A2b. `docs/BRANCH_PROTECTION.md`** — omitted from draft 2 entirely, and it is
  linked from `BRANCHING.md`. It instructs "use the repo's **actual default
  branch** (not hardcoded `main`) … keep `enforce_admins: true` unless you have a
  documented reason to diverge" (Claim 38). Post-adoption that runbook
  contradicts A2's per-branch table and B1's bypass in the same breath.
- **A3.** Promotion is a fast-forward **push**, not a merge — squash-only is
  untouched for feature PRs. State the bypass requirement (§3) and the
  `main`-receives-only-fast-forwards rule (§4) together.
- **A4. Post-merge hygiene** (decision 5), as a new §3 lifecycle step. Remote
  deletion is already covered (Claim 30) and automated (Claim 31); this adds the
  local half.

  **Probing it surfaced the rule's real content: `git branch --merged` is the
  WRONG detector.** Measured on canon 2026-08-23 — `git branch --merged main`
  listed no branch other than `main` itself while **14 of 16** local branches
  had merged PRs. (`--merged main` always lists `main`; the substantive point is
  that it found none of the 14.) Squash-merge rewrites the SHA, so ancestry-based detection finds nothing
  and a naive "delete merged branches" rule silently does nothing while
  reporting success. The same squash-defeats-ancestry trap this workspace
  already records elsewhere. So the rule must name its detector:

  ```sh
  git checkout <default> && git pull --ff-only
  # Merged-ness comes from PR STATE, not ancestry. Use any(), NOT .[0]:
  #   a reused or reopened branch has SEVERAL PRs, and .[0] is an arbitrary
  #   element of an unordered set — it can read CLOSED while a merged PR exists.
  #   A branch never PR'd yields null and must be treated as NOT merged.
  gh pr list --head "<branch>" --state all --json state \
    --jq 'any(.[]; .state == "MERGED")'
  # -d REFUSES (squash means it is not an ancestor), so -D is required — which
  # removes the safety net -d exists for. Guard on CONTAINMENT first: any commit
  # on the branch after the merge would be lost silently.
  test "$(git rev-parse "<branch>")" = "$(gh pr view <N> --json headRefOid --jq .headRefOid)" \
    && git branch -D "<branch>"
  git fetch --prune
  ```

  **Not server-enforceable — but do not stop there** (draft 2 wrote it off as
  simply "unenforceable"). Canon ships a client-side gate into every adopting
  clone, and this standard already counts that as *enforcement*, not convention:
  §7 lists the audit phrase as "local pre-push hook + `audit-trail-check.yml`"
  (Claim 39). A pre-push warning for merged-but-undeleted local branches is
  available at exactly the strength of the OPS-0069 phrase check, with the same
  `--no-verify` escape. **Decide it explicitly: take the local hook, or decline
  it and say why.** Do not record "unenforceable" as if no option existed.
- **A5.** `DECISIONS.md` **CI-0048** — decision of record. (CI-0047 was taken by
  the agent-config decision that landed first.)

### Phase B — enforcement surfaces

- **B0. The declaration surface — FIRST.** B2 and B3 both assume "the branch set
  the repo opted in for" and no such declaration exists: both scripts take only
  `--tier`, and tier cannot express it (three repos share `product`, Claim 40).

  **The non-adopting default is "protect the repo's API-reported DEFAULT
  BRANCH", not "protect `main`."** Draft 2 wrote the latter, twice — which would
  **revert M4-sec**, a deliberate security fix that removed exactly that
  hardcoding (Claim 41), with consumers on `master`/`develop` a real handled
  case. The correct default is both today's behaviour and forward-compatible.
- **B1. 🔴 Probe, then write** — see §3.
- **B2. Protection targeting** — every declared branch, not `default_branch`.
  Covers §5 Class A rows 1-2 **only**.
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
  remedy that cannot clear it. Both copies ship.
- **B4. Release flow — a CHANGE** (§4a). State which branch `prep` starts from
  and which its PR targets. `tag`'s `main` guard may stay; `prep`'s cannot.
- **B5. Triggers — 19 sites, not 2.** Draft 2 named CodeQL and "post-merge
  scanners"; the real count is `branches: [main]` **19 times across 17 files**
  (Claim 12) — 2 `pull_request` filters, 17 `push` arms.
  - **All 17 post-merge arms go silent** at the flip.
  - **CodeQL is the sharpest case:** an absent check, not a reduced one — and
    because `codeql` is in no tier's required contexts (Claim 42), it fails as a
    silently missing gate rather than a hung PR.
  - Where the Code Scanning baseline should live is a **real decision** (§5).
  - Still true: do not blanket-add `dev`/`staging`.

### Phase C — canon self-adoption (Wave 0)

**Not blocked on B1** — canon's `main` already carries `enforce_admins: false`
(§3). It IS blocked on **B3**: the pre-push gate refuses the promotion push.
Sequence C after B3, not after B1. Drive one real change through
`feat/… → dev → staging → main` before offering the model to anyone.

**Protection by per-section `gh api` PUTs, NOT `apply-standards.sh`** —
`CLAUDE.md` forbids that command on canon (Claim 36): it PUTs a profile requiring
`ai-review` and `composition`, which canon does not self-run, hanging every canon
PR, and it clobbers the FT-52 profile the release path depends on.

### Phase D — consumer opt-in path

Documented, not executed. **Blocked on B1**: every shipped consumer profile sets
`enforce_admins: true` (Claim 17), so an adopting consumer has no promotion path
until a template changes.

## 7. What this plan does NOT do

- Cut over any consumer.
- Change the squash-only rule for feature PRs.
- Decide the promotion actor (🔴 B1).
- Blanket-add `dev`/`staging` triggers.
- Claim the post-merge hygiene rule is enforced (A4).

## 8. Known gap in the drift checker — corrected

Draft 2 claimed the checker "reads **neither** `restrictions` **nor**
`required_pull_request_reviews`". **The second half was false.** It *does*
compare `required_pull_request_reviews`, as a normalized four-field subset
(Claim 43), so a null-vs-object difference is detected. It also compares
`required_status_checks.strict`, a fifth comparison draft 2 omitted.

The conclusion survives **for a different reason**, and the difference changes
the fix: the filter is an **allowlist of four sub-fields**, so
`bypass_pull_request_allowances` is projected away and is invisible; `restrictions`
is genuinely unread; and rulesets are not read at all (relevant to §3's refuted
candidate). **But not for every candidate, and the pass-2 fold overstated this too.** If B1 lands `enforce_admins: false` — the candidate §3 calls the incumbent — drift detection **already catches it**: the checker compares `enforce_admins` directly, and `CLAUDE.md` records it firing on canon today. §8 is true only for `bypass_pull_request_allowances` and `restrictions`. So the remedy depends on which candidate B1 picks — extend the `review_filter` only if B1 lands a field inside `required_pull_request_reviews`.

Where a remedy IS needed it is **extend the `review_filter`**, not "make it read
`required_pull_request_reviews` at all". Folding a wrong statement about a gate
into a plan is the same failure this repo records as "assert the teeth".

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 60 | The standard currently FORBIDS long-lived development/release/environment branches absent an owning decision | `Do not create long-lived` | docs/BRANCHING.md:53 |
| 61 | The standard states it does not use long-lived release branches | `long-lived release branches` | docs/BRANCHING.md:116 |
| 62 | The standard protects exactly one branch, `main`, per tier | `All non-paused repos protect` | docs/REPO_STANDARDS.md:124 |
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
| 14 | Squash is the canonical merge method in the standard's prose | `Squash merge is the canonical merge method` | docs/BRANCHING.md:96 |
| 15 | The branch-protection templates are branch-agnostic payloads, so one profile can be applied to several | `required_status_checks` | install/templates/branch-protection-product.json:3 |
| 16 | The standard's own enforcement map states the PR requirement binds non-bypass actors | `PR required for default branch` | docs/BRANCHING.md:122 |
| 17 | Every non-umbrella shipped profile sets `enforce_admins: true`, so consumers have no admin bypass | `"enforce_admins": true` | install/templates/branch-protection-product.json:14 |
| 18 | Branch protection and rulesets aggregate and the stricter wins; ruleset `bypass_actors` is scoped by threat model | `bypass_actors` | DECISIONS.md:1877 |
| 19 | `vladm3105` is a personal User account with no orgs, so org-only fields are unavailable | `personal **User** account` | DECISIONS.md:1973 |
| 20 | docs-sync's header DECLARES a required bypass scoped to the aidoc-flow-bot App — a design requirement in a `SAFETY` comment, NOT evidence that one is provisioned (see §3) | `bypass scoped to aidoc-flow-bot App only` | .github/workflows/docs-sync.yml:15 |
| 21 | `release.sh prep` creates the prep branch from the current checkout, which its guard forces to be `main` | `git checkout -q -b "$branch"` | scripts/release.sh:258 |
| 22 | The release checklist merges the prep PR into main with a squash + admin merge | `gh pr merge <N> --squash --delete-branch --admin` | docs/RELEASE_CHECKLIST.md:175 |
| 23 | The text "commit these changes directly to main" is the BODY OF A DRY-RUN PR COMMENT describing what live mode *would* do — it is not the behaviour, and citing it as such was the §4 overclaim (see Claim 35 for the actual stub) | `commit these changes directly to main` | .github/workflows/docs-sync.yml:337 |
| 24 | `composition.yml` reads its trusted allowlist from the default branch because that base is non-PR-mutable | `DEFAULT_BRANCH=$(gh api` | .github/workflows/composition.yml:204 |
| 25 | `ai-review.yml` resolves the caller ref from the default branch for non-`pull_request_target` events | `CALLER_REF="${CALLER_DEFAULT_BRANCH}"` | .github/workflows/ai-review.yml:637 |
| 26 | `apply-standards.sh`'s pre-mutation backup captures the default branch's protection | `local backup_dir slug ts backup_file default_branch` | install/apply-standards.sh:721 |
| 27 | `check-pin-currency.sh` reads each consumer's pins from its default branch | `default_branch="$($GH api` | sync/check-pin-currency.sh:65 |
| 28 | `deploy-ci-wizard.sh` enumerates deployed workflows from the default branch | `defbr="$($GH api` | install/deploy-ci-wizard.sh:160 |
| 29 | `docs-sync.yml` resolves the caller's entry ref as the consumer's default branch | `consumer's default branch` | .github/workflows/docs-sync.yml:130 |
| 30 | The standard already requires deleting the head branch after merge | `Delete the head branch after merge` | docs/BRANCHING.md:69 |
| 31 | Shipped repo settings already automate remote branch deletion on merge | `"delete_branch_on_merge": true` | install/templates/repo-settings.json:9 |
| 32 | The enforcement map already has a row for rules that are review conventions rather than enforced settings | `Naming and single-purpose branch` | docs/BRANCHING.md:127 |
| 34 | `pre_push_check.sh` treats an EMPTY push range as a hard failure, not a pass | `EMPTY — NOTHING was verified` | scripts/pre_push_check.sh:282 |
| 35 | `codeql.yml` filters the `pull_request` trigger to `branches: [main]`, so a PR based elsewhere never triggers it | `pull_request:` | install/templates/workflows/codeql.yml:17 |
| 36 | `CLAUDE.md` forbids running `apply-standards.sh --apply --tier product` on canon | `Never run` | CLAUDE.md:444 |
| 70 | On an `enforce_admins: true` repo a ruleset bypass is INERT — protection and rulesets aggregate and the stricter wins | `the ruleset bypass is **inert**` | DECISIONS.md:1941 |
| 33 | §1 requires ONE protected default branch and forbids direct pushes even where an admin bypass exists | `Every active repository has one protected default branch` | docs/BRANCHING.md:13 |
| 71 | `release.sh` prints "open the prep PR" as a HUMAN step — the script does not create it, so `gh pr create`'s `--base` default applies | `open the prep PR` | scripts/release.sh:362 |
| 34b | `pre_push_check.sh` treats an EMPTY push range as a hard failure | `EMPTY — NOTHING was verified` | scripts/pre_push_check.sh:282 |
| 72 | docs-sync's live-mode Apply is an alpha.1 STUB that echoes a notice and commits nothing | `alpha.1 stub` | .github/workflows/docs-sync.yml:317 |
| 36b | The shipped docs-sync config sets `dry_run: true`, so live mode is not armed | `"dry_run": true` | install/templates/docs-sync.json:6 |
| 37 | This repo's own gated ledger already records that a `dry_run: false` flip alone does nothing | `alpha.1 stub` | plans/PLAN-007_production-hardening.md:50 |
| 38 | `BRANCH_PROTECTION.md` instructs using the repo's ACTUAL default branch and keeping `enforce_admins: true` | `actual default branch` | docs/BRANCH_PROTECTION.md:103 |
| 39 | The enforcement map already counts a LOCAL pre-push hook as enforcement, not convention | `local pre-push hook` | docs/BRANCHING.md:126 |
| 40 | Three repos share the `product` tier, so tier cannot express per-repo opt-in | `Product code` | docs/REPO_STANDARDS.md:112 |
| 41 | The hardcoded-`main` protection target was deliberately REMOVED as defect M4-sec | `M4-sec: use the target's actual default branch` | install/apply-standards.sh:706 |
| 42 | `codeql` is in no tier's required status checks, so its absence is a missing gate rather than a hung PR | `required_status_checks` | install/templates/branch-protection-product.json:3 |
| 43 | The drift checker DOES compare `required_pull_request_reviews`, as a four-field subset — so the gap is the allowlist projecting away the bypass field | `review_filter=` | sync/check-standards-drift.sh:260 |

| 61 | `branches: [main]` appears 19 times across 17 shipped caller templates — 2 `pull_request` filters, 17 `push` arms | `branches: [main]` | install/templates/workflows/codeql.yml:16 |

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
- **§8 was false.** The checker *does* read `required_pull_request_reviews`
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
- **§5 Class A rows 3–7 had no owning phase.** B2's text covers protection
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
