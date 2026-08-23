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

> ### ⚠️ Do NOT flip a default branch on this document alone
>
> The three-branch model has prerequisites that are **not yet implemented**, and
> flipping the default branch without them breaks things **silently** — not
> loudly. `plans/PLAN-028` catalogues them; the ones that bite immediately:
>
> - **CodeQL stops running on every feature PR.** `codeql.yml` and
>   `codeql-private.yml` filter `pull_request:` to `branches: [main]`, and that
>   filter matches the PR's **base**. A PR into `dev` creates **no check run at
>   all** — an absent gate, not a failing one.
> - **All 17 post-merge `push: [main]` arms stop firing**, because merges land
>   on `dev`.
> - **The Code Scanning baseline is never populated.** Alerts anchor to the
>   *default* branch, and there is no `push: dev` run to populate it.
> - **Two trust anchors move**: `composition.yml` reads its allowlist from the
>   default branch *because that base is protected and non-PR-mutable*, and
>   `ai-review.yml` resolves its canon pin from it.
> - **Branch protection follows the flip** — `apply-standards.sh` protects the
>   API-reported default branch, so it would protect `dev` and never protect
>   `main`.
>
> Track PLAN-028 to completion before adopting.

## 1. Protected branches

**Single-branch model.** One protected default branch, normally `main`.

**Three-branch model.** All three are protected. They differ in what reaches
them and how:

| Branch | Role | Receives work by |
| --- | --- | --- |
| `dev` | development; the `default_branch` | **squash-merged PR** from a working branch |
| `staging` | dev deployment | **fast-forward push** from `dev` |
| `main` | production release; `ci/vX.Y.Z` tags cut here | **fast-forward push** from `staging` |

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
git push --ff-only origin dev:staging
git push --ff-only origin staging:main
```

**This does not contradict §5.** Squash governs how a *working branch* enters
`dev`. Promotion is not a merge at all, so no merge method applies and the three
branches stay **identical by SHA** — which is what makes "is this commit in
production?" answerable exactly.

Promoting by PR would defeat the model: with merge commits and rebase disabled,
GitHub would **squash** the promotion, giving identical content a new SHA and
permanently diverging the branches.

> **A fast-forward push requires an authorized bypass, and the mechanism is NOT
> yet settled.** "Require a pull request before merging" blocks direct pushes
> for every non-bypass actor, and it is set on every shipped profile. PLAN-028
> **B1** carries the open candidates and the probe that must decide between them.
> **Until that resolves, a consumer adopting this model cannot promote at all** —
> which is why §0 says do not adopt yet.

## 6. Hotfixes and releases

A hotfix still uses `fix/<description>` and a PR into the default branch, then
promotes. Urgency may shorten the review timeline but does not silently remove
validation, audit, or protection.

Releases are immutable `ci/vX.Y.Z` tags cut from `main`. Tags are not working
branches.

**Under the three-branch model the release flow itself must change**, and this
is not yet done: `release.sh prep` branches from `main` and its PR is squashed
back into `main`, which puts a commit on `main` that `dev` does not have and
ends fast-forward promotion permanently. PLAN-028 B4 owns it.

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
| **Promotion is fast-forward only** | **Convention** — nothing verifies that a push to `staging`/`main` was a fast-forward |
| **Post-merge local cleanup (§3a)** | **Convention — not server-enforceable.** `delete_branch_on_merge` handles the remote; nothing can prune your clone. A local pre-push warning is *available* at the same strength as the audit phrase above; PLAN-028 **A4-residual** decides whether to take it |
| Exceptional bypass authority | `aidoc-flow-operations` OPS decisions |

Apply enforceable settings with `install/apply-standards.sh --apply`. Verify
server-side settings with `sync/check-standards-drift.sh --strict`. See
[`BRANCH_PROTECTION.md`](BRANCH_PROTECTION.md).
