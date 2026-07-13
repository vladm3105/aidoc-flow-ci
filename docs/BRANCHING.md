# Branching standard

Canonical branch naming, lifecycle, update, merge, and cleanup rules for
`aidoc-flow-ci` consumers. GitHub settings enforce the protected-default-branch
and merge rules; naming and feature-branch hygiene are reviewable conventions.

Organizational rationale and exceptional authority remain in
`aidoc-flow-operations` OPS decisions. This document defines the technical
repository contract encoded by flow-ci.

## 1. Default branch

- Every active repository has one protected default branch, normally `main`.
- All changes reach the default branch through a pull request. Do not push
  directly, including when an administrator bypass is technically available.
- The umbrella repository still requires a PR. Its explicit
  `gh pr merge --admin` flow is only the OPS-0062 merge-gate bypass; it never
  authorizes a direct push and is not a precedent for consumers.
- Never force-push or delete the protected default branch.

The tier profiles in `install/templates/branch-protection-*.json` enforce the
PR requirement, required checks/reviews, and force-push/deletion restrictions
for non-bypass actors. The umbrella administrator bypass remains constrained by
OPS-0062 and the no-direct-push convention above.

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
`renovate/...`. Actor names, ticket numbers, and project names are optional;
the branch name should primarily communicate intent.

`feature/<short-description>` is accepted as a legacy alias where an existing
cross-repository operations playbook already uses it. New work should prefer
the shorter `feat/` form; do not rename a shared in-flight branch solely for
style.

Do not reuse a merged branch for unrelated work. Do not create long-lived
personal, development, release, or environment branches unless an owning OPS
decision explicitly introduces that model.

## 3. Lifecycle

1. Start from the current remote default branch.
2. Create one working branch for one coherent change.
3. Commit in reviewable units using Conventional Commit subjects.
4. Before each push, run repository validation and the OPS-0065 matched review;
   include the OPS-0069 audit phrase in the commit body.
5. Open a PR into the default branch. Draft is appropriate while incomplete;
   mark it ready only when the described scope and validation are complete.
6. Address review on the same branch. Do not open replacement PRs merely to
   discard review history.
7. Merge only when the tier's required checks and approvals are satisfied.
8. Delete the head branch after merge. Repository settings do this
   automatically; remove a surviving branch manually after confirming merge.

Keep unrelated working-tree changes out of the branch and PR. Cross-repository
initiatives use one branch and PR per repository, coordinated by the operations
playbooks; never combine repositories into a shared Git history.

## 4. Updating a branch from the default branch

- Update when required to resolve conflicts, consume a dependency, or verify
  the actual combined result. Branch protection does not require every PR to be
  continuously current because that creates unnecessary CI/review churn.
- Before substantive review begins, either a normal rebase or merge from the
  default branch is acceptable if the branch has not been shared.
- After a PR is under review, prefer GitHub's **Update branch** action or merge
  the default branch into the working branch. Do not force-push reviewed
  history. Any update produces a new head SHA and must pass the gates again.
- Never resolve conflicts by weakening required checks, switching private CI to
  GitHub-hosted runners, or bypassing protection without the documented OPS
  exception.

`allow_update_branch: true` in `install/templates/repo-settings.json` enables
the safe server-side update path. `required_status_checks.strict: false` means
being behind the default branch alone does not block merge.

## 5. Merge strategy

- Squash merge is the canonical merge method.
- Merge commits and rebase merges through the GitHub merge UI are disabled.
- The squash title is the PR title and the squash body is the PR body.
- Auto-merge is allowed where OPS-0062 and repository risk rules permit it.
- Governance, specification, cross-repository, and other elevated-risk PRs
  follow their human/admin merge requirements even when checks are green.

Squash-only keeps the default branch linear and preserves one merged commit per
reviewed PR. Rebase merge is disabled because the reviewer verdict is anchored
to the PR head SHA.

## 6. Hotfixes and releases

A hotfix still uses `fix/<description>` and a PR. Urgency may shorten the
review timeline but does not silently remove validation, audit, or protection.
Use an administrative bypass only when an OPS decision explicitly authorizes
it, and record the reason.

Flow-ci releases are immutable `ci/vX.Y.Z` tags cut from accepted default-
branch commits. Tags are not working branches, and this standard does not use
long-lived release branches.

## 7. Enforcement map

| Rule | Enforcement |
| --- | --- |
| PR required for default branch | `branch-protection-<tier>.json` (non-bypass actors) |
| Required checks/reviews | `branch-protection-<tier>.json` |
| No force-push/default-branch deletion | `branch-protection-<tier>.json` |
| Squash-only, update-branch, auto-delete | `repo-settings.json` |
| Audit phrase | local pre-push hook + `audit-trail-check.yml` |
| Naming and single-purpose branch | Review convention documented here |
| Exceptional bypass authority | `aidoc-flow-operations` OPS decisions |

Apply enforceable settings with `install/apply-standards.sh --apply`. Verify
server-side settings with `sync/check-standards-drift.sh --strict`; the apply
script's `--check` mode checks file surfaces, not GitHub server settings. See
[`BRANCH_PROTECTION.md`](BRANCH_PROTECTION.md).
