# PLAN-028 — `dev` → `staging` → `main` branching, and the surfaces that assume one branch

**Status:** Draft — no phase executed. **Phase B1 is 🔴 BLOCKED on a live probe**
(§3), and until it resolves, Phase D is undeliverable for consumers.
**Owner:** canon (aidoc-flow-ci)
**Scope:** the branching standard, the enforcement surfaces that would silently
contradict it, post-merge branch hygiene, and canon's own Wave-0 self-adoption.
Consumer cutovers are **out of scope** — adoption is per-repo opt-in.
**Change level:** C3.
**Semver:** MAJOR — because **B2 changes what `apply-standards.sh` protects** and
**B5 changes the CodeQL `pull_request` base filter** (§6 F4), both behavioural
changes in shipped surfaces. *Not* because post-merge triggers change; §5 keeps
them, and an earlier draft gave that as the reason while simultaneously making
it a non-goal.

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

## 3. 🔴 B1 — the bypass mechanism is UNRESOLVED, and the plan must not guess it

An earlier draft proposed a `restrictions` push allowlist. **That is wrong twice
over**, and both defeaters are recorded in this repo:

- **Wrong semantics.** `restrictions` *narrows* who may push; it does not exempt
  anyone from the PR requirement. The two controls aggregate and the stricter
  wins — the principle CI-0029 already records for the protection/ruleset pair
  (Claim 18). An allowlisted actor is still blocked by the PR requirement.
- **Unavailable on this account.** `restrictions` is org-only, and CI-0030
  records — measured — that `vladm3105` is a personal User account with no
  organizations and every workspace repo is user-owned (Claim 19). The
  `"restrictions":false` in the probe above is more likely *cannot* than
  *not yet*.

**Candidates, to be settled by a live probe and not on paper:**

| Candidate | Why it might work | What is unknown |
|---|---|---|
| `required_pull_request_reviews.bypass_pull_request_allowances` | The semantically correct classic-protection field — it exempts, rather than narrows | Whether it accepts a **user-owned** repo. Unresolved from source; needs the probe |
| A repository **ruleset** with `bypass_actors` | **Proven on a user-owned repo in this workspace** — CI-0029 governs how bypass actors are scoped (Claim 18) | Interaction with the existing classic protection, which aggregates |
| Whatever arms `aidoc-flow-bot` for `docs-sync` | `docs-sync` already ships "Branch protection bypass scoped to aidoc-flow-bot App only" (Claim 20) — that bypass exists and works today | Which mechanism backs it; it is founder-provisioned |

The third is the strongest lead and the plan's earlier drafts missed it entirely:
**a working bypass already exists in this repo.** Identify it before inventing
one.

**Nothing in Phase B ships until this resolves.** A3 makes the standard's
promotion rule depend on it, and a rule the shipped profile cannot execute is the
§4.3i defect class the standard itself now names.

## 4. FF-only collides with two things that WRITE to `main`

Decision (2) is not only a protection question. Two existing mechanisms put
commits on `main` that `dev` will never have, and each one **permanently** ends
fast-forward promotion the first time it runs.

**(a) Every release.** `release.sh prep` branches from `main` (Claim 21), writes
VERSION, retires forward-pin markers and promotes the CHANGELOG, and the
checklist merges that PR into `main` with `gh pr merge --squash --admin`
(Claim 22). The resulting squash commit exists on `main` and not on `dev`, so
`git push --ff-only origin dev:main` is impossible from that moment on, for
every subsequent release.

Stacked on it: `release.sh` does not create the PR — the checklist does, and
`gh pr create` defaults `--base` to `default_branch`, which is now `dev`. So the
prep PR silently retargets `dev`, and `tag`'s `VERSION on main reads …` guard
(Claim 11) then fails until someone promotes.

**(b) Every live docs-sync.** It does not merely read `main` — it **commits to
it** (Claim 23), using the bot's protection bypass. Same divergence, recurring
per-merge rather than per-release, made by automation that nothing stops.

**The rule this forces, and it must be stated in the standard:** `main` receives
**only** fast-forwards. No human merge, no bot commit, no release prep. Every
writer to `main` is then audited against it — which is what turns B4 and B5 from
"verify" into "change".

## 5. What silently follows the default-branch flip

Ten surfaces resolve the branch at runtime rather than hardcoding it, which makes
them *more* dangerous, not less: they follow the flip with nobody editing them.
An earlier draft listed four and presented that as exhaustive.

| # | Surface | Claim | After the flip, with no other change |
|---|---|---|---|
| 1 | `apply-standards.sh` protection PUT | 5 | Protects **`dev`**. `main`'s existing protection persists (a PUT to one branch removes nothing from another) — so for an **existing** repo this never *unprotects* main, it **never protects** it; for a fresh adoption `main` is bare |
| 2 | `check-standards-drift.sh` | 6 | Verifies `dev`, reports clean, never looks at `main` |
| 3 | `scanners.yml` Code Scanning | 12 | **The damage is inverted from the obvious reading.** Alerts anchor to the *default* branch, and after the flip there is **no `push: dev` run at all** — so the default-branch baseline is never populated. `main` keeps getting push runs, uploading SARIF for a non-default ref that the default alert view does not surface |
| 4 | `pre_push_check.sh` ×2 fallback | 4 | Lints the `main..dev` delta plus the feature commits (an earlier draft wrote this range backwards) |
| 5 | **`composition.yml` trusted allowlist** | 24 | Reads the ai-review config from the default branch **because it is the protected, non-PR-mutable base**. The trust anchor moves from the release branch to the integration branch |
| 6 | **`ai-review.yml` FT-15 pin resolution** | 25 | `CALLER_REF` = default branch for non-`pull_request_target` events. Under a promotion model `dev` and `main` legitimately hold *different* canon pins, so one repo resolves two canon versions depending on the event |
| 7 | `apply-standards.sh` pre-mutation backup | 26 | Snapshots `dev`'s protection while the operator believes it holds the release branch's pre-state |
| 8 | `check-pin-currency.sh` | 27 | Fleet currency reports `dev`'s pin while production runs `main`'s |
| 9 | `deploy-ci-wizard.sh` | 28 | Enumerates deployed workflows from `dev` |
| 10 | `docs-sync.yml` caller-ref | 29 | Resolves the consumer's entry ref from `dev` |

Rows 5 and 6 are **trust boundaries**, not conveniences. Any claim that B1 is
"the one place this plan changes a security posture" is false while they stand.

## 6. Phases

### Phase A — the standard

- **A1.** Rewrite `docs/BRANCHING.md` for the model. Re-derive the section list
  from the file rather than assuming: §2 currently **forbids** long-lived
  environment branches (Claim 1) and §6 says the standard "does not use
  long-lived release branches" (Claim 2) — both are superseded and must be
  rewritten, not appended to. §4 ("Updating a branch from the default branch")
  is default-branch-framed throughout and needs work an earlier draft omitted.
  §3 items 1 and 5 ("start from / open a PR into the default branch") stay
  **true** — the default branch is now `dev`.
- **A2.** `docs/REPO_STANDARDS.md` §2 — "All non-paused repos protect `main`"
  (Claim 3) becomes a per-branch table.
- **A3.** Promotion is a fast-forward **push**, not a merge — so §5's squash rule
  is untouched for feature PRs. State the bypass requirement (§3) in the same
  breath, and the `main`-receives-only-fast-forwards rule (§4).
- **A4. Post-merge hygiene** (decision 5), as a new §3 lifecycle step. Remote
  deletion is **already covered** (Claim 30) and automated by
  `delete_branch_on_merge` (Claim 31), so this adds only the local half:

  ```sh
  git checkout <default> && git pull --ff-only
  git branch -d feat/x        # local branch
  git fetch --prune           # stale origin/feat/x
  ```

  **Unenforceable, and the standard must say so.** `delete_branch_on_merge` is a
  server setting; nothing can make anyone prune their own clone. It joins §7's
  "Review convention documented here" row (Claim 32) and the enforcement map
  states plainly that it is convention — not a gate. Claiming otherwise is the
  §4.3i class this repo just spent a release closing.
- **A5.** `DECISIONS.md` CI-0047 — decision of record, including §3's unresolved
  bypass and §4's collision.

### Phase B — enforcement surfaces

- **B0. The declaration surface — build this FIRST.** B2 and B3 both say "the
  branch set the repo opted in for", and **no such declaration exists**:
  `apply-standards.sh` and `check-standards-drift.sh` take only `--tier`, and
  tier cannot express it — three repos share the `product` tier (Claim 33), a
  substitution PLAN-020 already worked through and rejected. Name the surface,
  say who writes it, and **define the non-adopting default as exactly today's
  behaviour**: protect `main`, base off `main`. Without that default, "fail
  closed" either reds every consumer or protects nothing.
- **B1. 🔴 The bypass mechanism** — see §3. Probe first, then write.
- **B2. Protection targeting** — protect every declared branch, not
  `default_branch` (Claims 5, 6).
- **B3. `pre_push_check.sh` — the promotion push shape.** The `origin/main`
  fallback is the *lesser* half. The real defect: a promotion push
  (`git push origin dev:staging` from a current `dev`) yields an **empty**
  commit range, and the script treats empty as a **hard failure** (Claim 34) —
  so canon's own mandatory pre-push gate refuses every promotion, with an error
  whose suggested remedy cannot clear it. Its scope note already records the
  cause (a multi-ref push is not described at all, #432). Both copies ship, so
  this reaches every adopting consumer.
- **B4. Release flow — a CHANGE, not a verification** (§4a). Decide and state
  which branch `prep` starts from and which its PR targets. `tag`'s `main` guard
  may stay; `prep`'s cannot.
- **B5. Triggers — classify by whether the flow WRITES, not by whether it is
  post-merge.**
  - `docs-sync` **writes** to `main` (§4b) — it must move to `dev` or open a PR
    instead of committing.
  - **CodeQL is the silent one:** `codeql.yml` and `codeql-private.yml` filter
    the **`pull_request`** trigger to `branches: [main]` (Claim 35). Every
    feature PR now targets `dev`, so **CodeQL runs on zero feature PRs** — not a
    reduced gate, an absent one, reporting no check at all. An earlier draft's
    "PR gates already fire on `pull_request` and need no change" was false as a
    class statement.
  - Post-merge scanners: §5 row 3 makes this a real decision (where should the
    Code Scanning baseline live?), not the no-op an earlier draft assumed.
  - Still true: do **not** blanket-add `dev`/`staging` to every trigger.

### Phase C — canon self-adoption (Wave 0)

Canon adopts before consumers, and drives one real change through
`feat/… → dev → staging → main` first. **A model canon has not itself promoted
through is not ready to ship** — this session's release found the v3 action layer
had never executed anywhere.

**Protection is applied by per-section `gh api` PUTs, NOT `apply-standards.sh`.**
`CLAUDE.md` forbids that command on canon (Claim 36): it PUTs a profile requiring
`ai-review` and `composition`, which canon does not self-run, hanging every canon
PR — and it clobbers the FT-52 profile the release path depends on. State which
profile `dev` and `staging` get, given canon's `main` deliberately does not match
its own tier template.

### Phase D — consumer opt-in path

Documented, not executed. **Undeliverable until B1 resolves** (§2): without a
bypass, an adopting consumer cannot promote at all.

## 7. What this plan does NOT do

- Cut over any consumer.
- Change the squash-only rule for feature PRs.
- Decide the promotion actor (🔴 B1).
- Blanket-add `dev`/`staging` triggers.
- Claim the post-merge hygiene rule is enforced (A4).

## 8. Known gap in the drift checker

`check-standards-drift.sh` compares four booleans plus
`required_status_checks.contexts` — it reads **neither** `restrictions` **nor**
`required_pull_request_reviews` (Claim 37). Whatever bypass B1 lands is
therefore invisible to drift detection: it can be removed, or added to a branch
it was never meant for, and the gate reports clean. B2's "fail closed" covers
branch *presence*, not bypass configuration. Say which is meant.

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | The standard currently FORBIDS long-lived development/release/environment branches absent an owning decision | `Do not create long-lived` | docs/BRANCHING.md:53 |
| 2 | The standard states it does not use long-lived release branches | `long-lived release branches` | docs/BRANCHING.md:116 |
| 3 | The standard protects exactly one branch, `main`, per tier | `All non-paused repos protect` | docs/REPO_STANDARDS.md:76 |
| 4 | `pre_push_check.sh` falls back to `merge-base HEAD origin/main` when there is no upstream | `git merge-base HEAD origin/main` | scripts/pre_push_check.sh:80 |
| 5 | `apply-standards.sh` PUTs branch protection to the API-reported default branch | `branches/${default_branch}/protection` | install/apply-standards.sh:710 |
| 6 | `check-standards-drift.sh` resolves the default branch from the API and verifies that branch | `DEFAULT_BRANCH=$(gh api` | sync/check-standards-drift.sh:166 |
| 7 | Shipped repo settings disable merge commits, leaving squash the only PR merge method | `"allow_merge_commit": false` | install/templates/repo-settings.json:6 |
| 8 | The shipped product profile sets `required_pull_request_reviews` — GitHub's "require a PR before merging" | `required_pull_request_reviews` | install/templates/branch-protection-product.json:15 |
| 9 | Canon's `main` sets `enforce_admins: false` as the deliberate FT-52 release-prep bypass | `enforce_admins: false` | docs/RELEASE_CHECKLIST.md:174 |
| 10 | `release.sh prep` refuses unless the current branch is `main` | `must be on main to prep` | scripts/release.sh:253 |
| 11 | `release.sh tag` asserts VERSION on main equals the version being cut | `must be on main to tag` | scripts/release.sh:418 |
| 12 | Code Scanning alerts anchor to the DEFAULT BRANCH, which is why the scanners need a post-merge run there | `anchored to the DEFAULT BRANCH` | install/templates/workflows/scanners.yml:38 |
| 13 | `docs-sync` is a post-merge flow gated on `push: main` | `POST-MERGE flow` | install/templates/workflows/docs-sync.yml:5 |
| 14 | Squash is the canonical merge method in the standard's prose | `Squash merge is the canonical merge method` | docs/BRANCHING.md:96 |
| 15 | The branch-protection templates are branch-agnostic payloads, so one profile can be applied to several | `required_status_checks` | install/templates/branch-protection-product.json:3 |
| 16 | The standard's own enforcement map states the PR requirement binds non-bypass actors | `PR required for default branch` | docs/BRANCHING.md:122 |
| 17 | Every non-umbrella shipped profile sets `enforce_admins: true`, so consumers have no admin bypass | `"enforce_admins": true` | install/templates/branch-protection-product.json:14 |
| 18 | Branch protection and rulesets aggregate and the stricter wins; ruleset `bypass_actors` is scoped by threat model | `bypass_actors` | DECISIONS.md:1877 |
| 19 | `vladm3105` is a personal User account with no orgs, so org-only fields are unavailable | `personal **User** account` | DECISIONS.md:1973 |
| 20 | A working branch-protection bypass already exists, scoped to the aidoc-flow-bot App | `bypass scoped to aidoc-flow-bot App only` | .github/workflows/docs-sync.yml:15 |
| 21 | `release.sh prep` creates the prep branch from the current checkout, which its guard forces to be `main` | `git checkout -q -b "$branch"` | scripts/release.sh:258 |
| 22 | The release checklist merges the prep PR into main with a squash + admin merge | `gh pr merge <N> --squash --delete-branch --admin` | docs/RELEASE_CHECKLIST.md:175 |
| 23 | `docs-sync` live mode COMMITS to main, it does not merely read it | `commit these changes directly to main` | .github/workflows/docs-sync.yml:337 |
| 24 | `composition.yml` reads its trusted allowlist from the default branch because that base is non-PR-mutable | `DEFAULT_BRANCH=$(gh api` | .github/workflows/composition.yml:204 |
| 25 | `ai-review.yml` resolves the caller ref from the default branch for non-`pull_request_target` events | `CALLER_REF="${CALLER_DEFAULT_BRANCH}"` | .github/workflows/ai-review.yml:637 |
| 26 | `apply-standards.sh`'s pre-mutation backup captures the default branch's protection | `local backup_dir slug ts backup_file default_branch` | install/apply-standards.sh:721 |
| 27 | `check-pin-currency.sh` reads each consumer's pins from its default branch | `default_branch="$($GH api` | sync/check-pin-currency.sh:65 |
| 28 | `deploy-ci-wizard.sh` enumerates deployed workflows from the default branch | `defbr="$($GH api` | install/deploy-ci-wizard.sh:160 |
| 29 | `docs-sync.yml` resolves the caller's entry ref as the consumer's default branch | `consumer's default branch` | .github/workflows/docs-sync.yml:130 |
| 30 | The standard already requires deleting the head branch after merge | `Delete the head branch after merge` | docs/BRANCHING.md:69 |
| 31 | Shipped repo settings already automate remote branch deletion on merge | `"delete_branch_on_merge": true` | install/templates/repo-settings.json:9 |
| 32 | The enforcement map already has a row for rules that are review conventions rather than enforced settings | `Naming and single-purpose branch` | docs/BRANCHING.md:127 |
| 33 | Tier cannot express per-repo opt-in — several repos share the `product` tier | `All non-paused repos protect` | docs/REPO_STANDARDS.md:76 |
| 34 | `pre_push_check.sh` treats an EMPTY push range as a hard failure, not a pass | `EMPTY — NOTHING was verified` | scripts/pre_push_check.sh:282 |
| 35 | `codeql.yml` filters the `pull_request` trigger to `branches: [main]`, so a PR based elsewhere never triggers it | `pull_request:` | install/templates/workflows/codeql.yml:17 |
| 36 | `CLAUDE.md` forbids running `apply-standards.sh --apply --tier product` on canon | `Never run` | CLAUDE.md:416 |
| 37 | The drift checker compares four booleans and the required contexts — not `restrictions`, not `required_pull_request_reviews` | `enforce_admins` | sync/check-standards-drift.sh:236 |

## Review log

### Pass 1 - 2026-08-23 - independent

`verified-planning-reviewer`, fresh context. **10 load-bearing findings, 5
minor.** All folded; every one verified against source before folding.

The three that changed the plan's shape rather than its wording:

1. **B1's mechanism was wrong twice over** — `restrictions` narrows who may push
   rather than exempting anyone from the PR requirement, *and* it is org-only on
   a User account (CI-0030). B1 is now an unresolved 🔴 with three candidates and
   a probe-first rule. The reviewer found the lead the author missed: a working
   bypass already ships for `aidoc-flow-bot`.
2. **FF-only collides with two writers to `main`** — the release flow's squash
   merge and docs-sync's direct commits each permanently end fast-forward
   promotion. New §4; B4 and B5 become changes rather than verifications.
3. **§5 was materially incomplete** — four surfaces listed, ten exist, and two of
   the six missed are trust boundaries (`composition.yml`'s allowlist,
   `ai-review.yml`'s FT-15 pin).

Also folded: CodeQL's `pull_request` base filter makes it run on **zero** feature
PRs after the flip (F4); §5 row 3's damage was inverted (F5); the promotion push
trips canon's own pre-push gate (F7); B0 added for the declaration surface both
B2 and B3 assumed (F8); consumers have no promotion path at all (F9); Phase C
called the one command `CLAUDE.md` forbids on canon (F10). Minors: the drift
checker cannot see the bypass fields (§8); the canon workflow count was 12 and is
**7** — the author's grep counted commented-out blocks; the MAJOR rationale cited
a change the plan does not make; two §5 precision errors; A1's section list was
wrong in both directions.

**Result:** revisions folded; re-dispatch required.
