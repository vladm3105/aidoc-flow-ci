# Branching standard

Canonical branch naming, lifecycle, promotion, merge, and cleanup rules for
`aidoc-flow-ci` consumers. GitHub settings enforce the protected-branch and
merge rules; naming, promotion discipline and local hygiene are reviewable
conventions.

Organizational rationale and exceptional authority remain in
`aidoc-flow-operations` OPS decisions. This document defines the technical
repository contract encoded by flow-ci.

## 0. Two models, and which one applies to you

| | Single-branch (default) | Three-branch (opt-in) |
| --- | --- | --- |
| Branches | `main` only | `dev` → `staging` → `main` |
| GitHub `default_branch` | `main` | **`dev`** |
| Feature PRs target | `main` | `dev` |
| Releases cut from | `main` | `main` |
| Status | what every repo has today | **not yet adopted anywhere, including canon** |

**Adoption is per-repo and opt-in** (founder, 2026-08-23). A repo that has not
opted in follows the single-branch model unchanged, and every rule below that
names `dev` reads as "the default branch" for it.

> ### ⚠️ Declare the model — do not just flip the default branch
>
> The enforcement surfaces are **implemented** as of PLAN-028 Phase B. Every
> hazard the earlier draft of this box listed is closed, and each one is closed
> by a mechanism you can check:
>
> - **CodeQL and the 17 post-merge arms follow the model.** The 19 trigger sites
>   across 17 caller templates carry a `${INTEGRATION_BRANCH}` placeholder that
>   `install.sh` resolves at fetch time. `on.push.branches:` accepts no
>   expressions, so this is the only mechanism that can work — and it means the
>   change arrives via `install.sh --update`, **never** via `--repin`, which
>   rewrites `uses:` tag strings only.
> - **The Code Scanning baseline is populated**, because the substituted `push`
>   arm names the integration branch, which is also the default branch.
> - **Branch protection follows the declaration, not the default branch** —
>   `apply-standards.sh` protects every branch in `protected_branches` and
>   `check-standards-drift.sh` verifies every one of them.
> - **The two trust anchors do not move**, and §8 explains the invariant that
>   keeps that true.
>
> **What is still open** is canon's own adoption and the per-repo cutover path
> (PLAN-028 Phases C and D). No repo has adopted the model yet, including canon.
> The machinery is in place; the migrations are not.

## 1. Protected branches

**Single-branch model.** One protected default branch, normally `main`.

**Three-branch model.** All three are protected. They differ in what reaches
them and how:

| Branch | Role | Receives work by |
| --- | --- | --- |
| `dev` | development — where code and changes land; the `default_branch` | **squash-merged PR** from a working branch |
| `staging` | the **stable** dev deployment — what is deployed for the team to use | **fast-forward push** from `dev` |
| `main` | production release; `ci/vX.Y.Z` tags cut here | **fast-forward push** from `staging` |

**What each branch MEANS, because it decides what may promote** (founder,
2026-08-23): `dev` holds development code and changes; `staging` is the
**stable** dev deployment — the build the team actually runs; `main` is the
production release. "Stable" is the load-bearing word: a fast-forward from `dev`
to `staging` is an assertion that what is on `dev` is fit to be deployed, which
is why promotion is a deliberate act and not automatic on merge.

**`main` receives ONLY fast-forwards.** No human merge, no bot commit, no
release-prep merge. This is the rule the whole model rests on: the moment any
commit lands on `main` that `dev` does not have, `main` stops being a descendant
of `dev` and fast-forward promotion is impossible from then on — recoverable
only via a back-merge that itself needs a protection bypass.

All changes reach a protected branch through a pull request **or, for promotion
only, an authorized fast-forward push** (§5a). Never force-push or delete a
protected branch.

## 2. Working-branch names

Use a short lowercase kebab-case description under an intent prefix:

```text
<type>/<short-description>
```

| Prefix | Use | Example |
| --- | --- | --- |
| `feat/` | Consumer-visible capability | `feat/model-health-routing` |
| `fix/` | Defect or regression | `fix/doc-planner-path-guard` |
| `docs/` | Documentation or governance guidance only | `docs/branching-standard` |
| `chore/` | Dependencies, release, build, or maintenance | `chore/update-action-pins` |
| `refactor/` | Internal restructuring without intended behavior change | `refactor/litellm-adapter` |
| `test/` | Test-only change | `test/runner-label-contracts` |

Automation that requires an actor prefix may use `agent/<short-description>`.
Managed bots retain their generated namespaces, such as `dependabot/...` and
`renovate/...`.

`feature/<short-description>` is accepted as a legacy alias where an existing
cross-repository operations playbook already uses it.

Do not reuse a merged branch for unrelated work. **`dev` and `staging` are the
only long-lived non-default branches this standard permits**, and only under the
three-branch model; personal, release and other environment branches still
require an owning decision.

## 3. Lifecycle

1. Start from the current remote **default branch** (`main`, or `dev` under the
   three-branch model).
2. Create one working branch for one coherent change.
3. Commit in reviewable units using Conventional Commit subjects.
4. Before each push, run repository validation and the OPS-0065 matched review;
   include the OPS-0069 audit phrase in the commit body.
5. Open a PR into the **default branch**. Draft is appropriate while incomplete.
6. Address review on the same branch. Do not open replacement PRs merely to
   discard review history.
7. Merge only when the tier's required checks and approvals are satisfied.
8. **Clean up, remote *and* local** — see §3a.

Keep unrelated working-tree changes out of the branch and PR. Cross-repository
initiatives use one branch and PR per repository.

### 3a. After the merge — leave no trace, and leave the default branch current

Remote deletion is automatic (`delete_branch_on_merge: true` in
`repo-settings.json`). The local half is not, and nothing can automate it for
you:

```sh
git checkout <default> && git pull --ff-only   # sync; nothing is pushed
git branch -D <branch>                         # see the two warnings below
git fetch --prune                              # drop stale remote-tracking refs
```

> **`git branch --merged` is the WRONG detector, and it fails silently.**
> Squash merge rewrites the SHA, so a merged branch is **not** an ancestor of
> the default branch. Measured on canon 2026-08-23: `git branch --merged main`
> listed nothing but `main` itself while **14 of 16** local branches had merged
> PRs. A cleanup rule written against `--merged` deletes nothing and reports
> success.
>
> Determine merged-ness from **PR state**, and use `any()` — a reused or
> reopened branch has several PRs, so an arbitrary element can read `CLOSED`
> while a merged PR exists:
>
> ```sh
> gh pr list --head "<branch>" --state all --json state \
>   --jq 'any(.[]; .state == "MERGED")'
> ```
>
> **`-D` is required and it removes a safety net.** `-d` refuses precisely
> because the branch is not an ancestor, so `-D` is the only option — and it
> discards any commit made on that branch *after* the merge, without warning.
> Confirm containment first:
>
> ```sh
> test "$(git rev-parse "<branch>")" = "$(gh pr view <N> --json headRefOid --jq .headRefOid)"
> ```

**Nothing is pushed by this step.** It syncs and cleans; it does not publish.

**This is a review convention, not an enforced gate** — see §7.

## 4. Updating a branch from its base

- Update when required to resolve conflicts, consume a dependency, or verify
  the actual combined result. Branch protection does not require every PR to be
  continuously current, because that creates unnecessary CI/review churn.
- Before substantive review begins, a rebase or a merge from the base is
  acceptable if the branch has not been shared.
- After a PR is under review, prefer GitHub's **Update branch** action. Do not
  force-push reviewed history. Any update produces a new head SHA and must pass
  the gates again.
- Never resolve conflicts by weakening required checks, switching private CI to
  GitHub-hosted runners, or bypassing protection without a documented exception.

`allow_update_branch: true` enables the safe server-side update path.
`required_status_checks.strict: false` means being behind the base alone does
not block merge.

## 5. Merge strategy

- **Squash merge is the canonical merge method** for a working branch into the
  default branch.
- Merge commits and rebase merges through the GitHub merge UI are disabled.
- The squash title is the PR title and the squash body is the PR body.
- Auto-merge is allowed where OPS-0062 and repository risk rules permit it.
- Governance, specification, cross-repository and other elevated-risk PRs follow
  their human/admin merge requirements even when checks are green.

Squash-only keeps the default branch linear and preserves one merged commit per
reviewed PR. Rebase merge is disabled because the reviewer verdict is anchored
to the PR head SHA.

### 5a. Promotion is a PUSH, not a merge

`dev` → `staging` → `main` moves by **fast-forward push**:

```sh
git push origin dev:staging
git push origin staging:main
```

**No `--ff-only` flag** — `git push` has none, and using it fails `rc=129` with a
usage dump. It is a `merge`/`pull` option. A plain `git push` is *already*
fast-forward-only: the server refuses a non-fast-forward update unless you force
it. (Measured while running the CI-0048 probe, which is how this was caught.)

**This does not contradict §5.** Squash governs how a *working branch* enters
`dev`. Promotion is not a merge at all, so no merge method applies and the three
branches stay **identical by SHA** — which is what makes "is this commit in
production?" answerable exactly.

Promoting by PR would defeat the model: with merge commits and rebase disabled,
GitHub would **squash** the promotion, giving identical content a new SHA and
permanently diverging the branches.

> **A fast-forward push requires an admin, and on a user-owned account that is
> the only mechanism there is.** Measured 2026-08-23 (PLAN-028 B1), not inferred:
>
> | Mechanism | Result |
> |---|---|
> | baseline — PR required, `enforce_admins: true` | push **rejected**: *"Changes must be made through a pull request"* |
> | `bypass_pull_request_allowances` | **HTTP 422** — *"Only organization repositories can have users and team restrictions"* |
> | `restrictions` | org-only, same class |
> | `enforce_admins: false` | **push succeeds** — for an admin |
>
> **So promotion is an ADMIN action.** Every aidoc-flow repo is owned by a
> personal User account, so no per-actor bypass can be granted; the only lever
> is exempting admins from the branch's rules wholesale.
>
> **And be clear about what that costs.** On a repo whose sole collaborator is
> the owner, `enforce_admins: false` makes the PR requirement on that branch
> **advisory rather than enforced** — the only actor who exists is exempt.
> Protecting `staging` and `main` this way buys process discipline, not a
> control GitHub applies. Enforcing it would require an **organization**, which
> is a larger decision than a branching model.

## 6. Hotfixes and releases

A hotfix still uses `fix/<description>` and a PR into the default branch, then
promotes. Urgency may shorten the review timeline but does not silently remove
validation, audit, or protection.

Releases are immutable `ci/vX.Y.Z` tags cut from `main`. Tags are not working
branches.

**Under the three-branch model the release flow itself changes, and it has**
(PLAN-028 B4). `release.sh prep` used to branch from `main` and have its PR
squashed back into `main` — which puts a commit on `main` that `dev` does not
have and ends fast-forward promotion permanently. `prep` now starts from, and
its PR targets, the **integration branch**; the release commit reaches `main` by
promotion like everything else. `release.sh tag` still requires `main`, on
purpose: tags are cut on the release branch, and by then `main` carries that
same commit.

One thing `prep` cannot do for you: `gh pr create`'s default base is the repo's
default branch. That is the integration branch under this model, so the default
is right — but `prep` prints the explicit `--base` anyway, because relying on a
default that is only coincidentally correct is how §5a's invariant gets broken
once and then permanently.

## 7. Enforcement map

Read this column honestly — several rules below are conventions, and saying so
is the point.

| Rule | Enforcement |
| --- | --- |
| PR required for a protected branch | `branch-protection-<tier>.json` (non-bypass actors) |
| Required checks/reviews | `branch-protection-<tier>.json` |
| No force-push/deletion of a protected branch | `branch-protection-<tier>.json` |
| Squash-only, update-branch, auto-delete of the remote branch | `repo-settings.json` |
| Audit phrase | local pre-push hook + `audit-trail-check.yml` |
| Naming and single-purpose branch | **Review convention** documented here |
| **Promotion is fast-forward only** | **Local pre-push CHECK, on the hook path.** With no arguments — how `pre-commit` invokes it — the hook recognises a promotion-shaped push (a declaration exists *and* `HEAD` is exactly `origin/<integration>`) and passes it instead of failing on the empty range; anything else still hard-fails. `--promote <target>` additionally verifies the target is declared and that its tip is an ancestor of `HEAD`. **Server-side it is NOT enforceable**: to GitHub a fast-forward push and a force-push are the same call, and `enforce_admins: false` exempts the only actor who can make either. The local check is offline, so it reads the last-fetched `origin/<target>` |
| **The branch set a repo opted into** | `.github/aidoc-ci.json` (§8), applied by `apply-standards.sh --apply` and verified by `check-standards-drift.sh` |
| **The integration branch is the GitHub default branch** | `apply-standards.sh` WARNS, `check-standards-drift.sh` counts it as DRIFT (§8) |
| **Post-merge local cleanup (§3a)** | **Local pre-push WARNING** (`pre_push_check.sh` §6) + `delete_branch_on_merge` for the remote. Not server-enforceable — nothing can prune your clone — so the hook reports and never blocks. It detects merged-ness from **PR state**, not ancestry: squash merge rewrites the SHA, so `git branch --merged` finds nothing (measured: it listed only `main` while 14 of 16 local branches had merged PRs) |
| Exceptional bypass authority | `aidoc-flow-operations` OPS decisions |

Apply enforceable settings with `install/apply-standards.sh --apply`. Verify
server-side settings with `sync/check-standards-drift.sh --strict`. See
[`BRANCH_PROTECTION.md`](BRANCH_PROTECTION.md).

## 8. Declaring the model — `.github/aidoc-ci.json`

`--tier` cannot express a branch set: three repos share the `product` tier, so
which branches a repo protects is not derivable from it. The declaration lives
in `.github/aidoc-ci.json`, and it is **optional**.

**An absent file is a valid declaration.** It means the single-branch model
resolved against the repo's API-reported default branch — exactly the behaviour
that shipped before the file existed. That is deliberate: every surface PLAN-028
touched defaults to the pre-PLAN-028 behaviour, so a repo that never opts in
observes no change at all.

```jsonc
{
  "version": 1,
  "branching": {
    "model": "dev-staging-main",   // or "single-branch" (the default)
    "integration_branch": null,    // null = the repo's GitHub default_branch
    "protected_branches": null,    // null = [integration, "staging", "main"]
    "promotion_branches": null     // null = ["staging", "main"]
  }
}
```

`model` alone is enough; the three `null`s take the model's defaults. Set them
explicitly only to depart from those defaults.

Two rules about `null` that every reader of this file implements identically:

- **`integration_branch: null` resolves to the repo's GitHub `default_branch`,
  never to a literal `dev`.** The *model* is named `dev-staging-main`; the
  *branch* is whatever the repo actually uses. Inventing `dev` for a consumer on
  `develop` would write `branches: ["dev"]` into all 19 trigger sites — a branch
  that does not exist — killing every post-merge arm silently.
- **`null` and an explicit `[]` are different.** `null` takes the model default;
  `[]` is an opt-out and is honoured as one. Declaring
  `"promotion_branches": []` means no branch gets the `enforce_admins: false`
  overlay, and nothing overrides that.

**The two lists are not independent.** Every branch in `promotion_branches` must
also be in `protected_branches`, and the integration branch must be in neither
promotion list. `apply-standards.sh` refuses both violations rather than applying
a partial configuration — so narrowing `protected_branches` to `["dev"]` while
leaving `promotion_branches` at `null` is an error, because the model default
fills it with `staging` and `main`, which are then unprotected. Narrow both
together, or neither.

### 8a. The invariant: the integration branch MUST be the default branch

Four canon surfaces resolve the branch at **run time** from the GitHub API's
`default_branch`, and they **cannot** read this declaration:

| Surface | What it resolves | Why it cannot read the declaration |
| --- | --- | --- |
| `composition.yml` trusted allowlist | the ai-review config's base | a **trust** boundary — it runs against arbitrary consumers, so trusting a consumer-controlled file here would *add* a trust surface |
| `ai-review.yml` FT-15 pin resolution | the caller's adopted canon tag | same; also a **trust** boundary |
| `check-pin-currency.sh` | which branch's pins the fleet audit reports | runs against repos it has no checkout of |
| `deploy-ci-wizard.sh` | which branch's workflows are "deployed" | same |

So the declaration does not move those anchors. **This invariant does:** the
integration branch must be the repo's GitHub `default_branch`. Hold it and all
four stay correct with no edits — `dev` is then the default branch, the base of
every feature PR (so a PR still cannot modify it), and protected with the full
tier profile. Break it and four surfaces silently anchor to a branch that no
longer receives merges, two of them trust anchors.

`apply-standards.sh` **warns** on divergence rather than failing, because the
adopter's flip is a two-step — create `dev`, then change the repo default — and
refusing to protect anything in between leaves them worse off than a loud
report. `check-standards-drift.sh` counts it as **drift**, because by the time
drift runs the two-step should be over.

### 8b. What a promotion branch costs

Every branch in `promotion_branches` is protected with the tier profile
**overlaid with `enforce_admins: false`** — measured in PLAN-028 B1 as the only
mechanism on a user-owned account that permits the promotion push at all.

That overlay exempts admins from **every** protection on that branch, not just
the PR requirement. Say it plainly: on `staging` and `main`, the gate is
**advisory for admins, not enforced**. That is an accepted trade (`DECISIONS.md`
CI-0049), not an oversight — enforcing it needs a GitHub organization. The
integration branch is *not* a promotion branch and keeps `enforce_admins: true`,
which is why it remains a sound trust anchor under §8a.

### 8c. Adopting

**Order matters, and three of these steps fail outright if taken out of order.**

1. **Create BOTH promotion branches and push them.** `apply-standards.sh` PUTs
   protection to every declared branch and a PUT to a branch that does not exist
   404s, aborting the run partway — after it has already protected the first one.

   ```sh
   git switch -c staging main && git push -u origin staging
   git switch -c dev     main && git push -u origin dev
   ```

2. **Set the repo's GitHub default branch to `dev`** (Settings → General).
   **Before step 3, not after.** Declaring the model while the default is still
   `main` makes `main` both the integration branch and a promotion branch, and
   `apply-standards.sh` refuses that outright — because the
   `enforce_admins: false` overlay would otherwise land on the branch
   `composition.yml` and `ai-review.yml` anchor their trust to (§8a, §8b).

3. **Add `.github/aidoc-ci.json`, and COMMIT AND PUSH it** to the new default
   branch:

   ```jsonc
   { "version": 1, "branching": { "model": "dev-staging-main" } }
   ```

   Steps 4-6 all read the **pushed** copy over the API, not your working tree —
   deliberately, so that what is enforced is what the repo declares rather than
   whatever the operator happens to have checked out.

4. **Apply protection** — `--repo` is REQUIRED with `--apply`:

   ```sh
   bash install/apply-standards.sh --repo <owner>/<repo> --tier <tier> --apply
   ```

   Protects all three, with the promotion overlay on `staging` and `main`.

5. **Rewrite the trigger arms** — `bash install/install.sh <owner>/<repo> --update`.
   **`--repin` will not do this**: it rewrites `uses:` tag strings only, never a
   caller body.

   **`codeql.yml` is `safe_to_replace: false`**, so `--update` preserves your
   copy rather than replacing it — correct, because its language matrix is
   consumer-customized, but it means **you must edit its two `branches:` filters
   by hand**. Skip this and CodeQL produces *no check run at all* on feature PRs
   and never populates the Code Scanning baseline. `sync/check-drift.sh` reports
   the file as drifted until you do.

6. **Verify**: `bash sync/check-standards-drift.sh --tier <tier> --strict` for
   server settings, and `bash sync/check-drift.sh` for the workflow bodies.

Promote with `git push origin dev:staging` — no `--ff-only` flag exists for
`push`, and it is fast-forward-only already (§5a).

The pre-push hook recognises a promotion-shaped push on its own, so the ordinary
`git push` runs it with no arguments and passes. To verify a specific target's
fast-forward explicitly before pushing:

```sh
scripts/pre_push_check.sh --promote staging
```
