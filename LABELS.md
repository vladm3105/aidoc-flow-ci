# LABELS.md — `aidoc-flow-ci` label conventions

This document defines the label conventions used by `aidoc-flow-ci`
across **two distinct namespaces**: GitHub **PR labels** (applied by
the ai-reviewer workflow) and GitHub **runner labels** (used in
`runs-on:` to select runner pools).

GitHub enforces different rules per namespace:

| Namespace | Allowed characters | Length | Aliasing |
|---|---|---|---|
| PR labels | Any UTF-8 (incl. `:`); GitHub recommends short readable names | ≤ 50 chars | n/a |
| Runner labels | Alphanumeric + `-` + `_` only — **no colons**; case-insensitive matching | ≤ 25 chars per label; multiple labels allowed via array | GitHub-hosted labels are fixed (`ubuntu-latest`, etc.); cannot be aliased to custom names |

The two namespaces therefore use different separator conventions
intentionally. Don't try to unify them; the constraints differ.

## 1. PR labels — canonical taxonomy (5)

Applied by the reusable `ai-review.yml` workflow:

| Label | Color | Type | When applied |
|---|---|---|---|
| `ai:review-passed` | green (`0e8a16`) | state — reviewer verdict | Reviewer App approved the PR |
| `ai:review-changes` | red (`d93f0b`) | state — reviewer verdict | Reviewer App requested changes |
| `ai:human-review-required` | yellow (`fbca04`) | state — trust-gate routing | Trust gate skipped the heavy reviewer (fork / non-allowlisted author / governance-locked path) |
| `ai:autofix-applied` | blue (`1d76db`) | action — fixer record | The autofix fixer (IPLAN-0014; default-off) applied a patch on this PR |
| `skip-ai-review` | purple (`5319e7`) | **control / directive** | Suppresses the reviewer on subsequent pushes; composition carries forward |

### Naming convention

Two sub-conventions, used intentionally to mark different label
purposes at a glance:

- **`ai:<noun>`** for AI-workflow **state** or **action-happened** labels
  (4 of the 5)
- **`<verb>-<noun>`** (no prefix) for user-facing **control / directive**
  labels (1: `skip-ai-review`)

Reading `ai:review-passed` vs `skip-ai-review` makes their roles
obvious without a separate legend: colon-form is "the workflow says
…", hyphen-form is "the user wants …".

### Canonical source-of-truth

`install/templates/labels.json` is the canonical 5-label set. It's
the source for `install/install.sh`, which idempotently creates the
labels on a consumer repo at bootstrap.

### Adding a new PR label

1. Edit `install/templates/labels.json` to add the new entry
   (`{name, color, description}`).
2. Document the label's purpose in this file (section 1's table +
   the appropriate convention).
3. Re-tag `aidoc-flow-ci` per `CHANGELOG.md` semver rules (a new
   label is additive; PATCH bump).
4. Consumers re-run `install/install.sh` to pick up the new label.
   The install loop is idempotent + fail-loud (PR #116 fix): it
   prefetches existing labels and only creates missing ones; real
   failures (auth/permission/network) exit nonzero rather than
   silently treating them as duplicates.

### Live drift from canonical (allowed, must be intentional)

A consumer repo may have labels not in `labels.json` (e.g.,
operations has `ai:review-escalated` + `ai:review-human-cleared`
not in the canonical taxonomy). The `install.sh` script does NOT
remove drifted labels — it only adds missing canonical ones.

To reconcile drift on a consumer:

- **If the extra labels are useful** — add them to
  `install/templates/labels.json` and PATCH-tag a new release.
- **If they're stale** — delete via `gh label delete <name> -R <repo>`.

### `skip-ai-review` semantics

- Applied **by a human** to a PR to suppress further AI review on
  subsequent pushes (e.g., a trivial doc-only follow-up after the
  reviewer has already approved an earlier head).
- The reusable `composition.yml` workflow's body checks for this
  label and carries forward the prior approval — `composition`
  stays green even though `ai-review` skipped.
- **Never apply automatically.** This is a deliberate human
  override; auto-applying would defeat the gate.

## 2. Runner labels — per-origin convention

Used in the reusable workflow's `runs-on:` expressions (consumer
caller templates set the `runner_labels_*` inputs to one of these):

| Label | Origin | What's installed | Where it resolves |
|---|---|---|---|
| `runner-self` | Our self-hosted runners | gh + codex + claude CLI pre-baked + authenticated | Operations' `aidoc-flow-runner:latest` Docker pool |
| `ubuntu-latest` | GitHub-hosted | gh CLI pre-installed; reviewer CLI installed at workflow start (`ci/v1.0.1`+) | GitHub's fixed `ubuntu-latest` runner image |
| Reserved: `runner-azure`, `runner-aws`, `runner-fargate`, … | Future origins | Per-provider | Per-provider runner pool |

### Naming convention

Asymmetric — driven by the underlying constraint (GitHub-hosted
labels are fixed):

- **`runner-<origin>`** — our custom labels for self-hosted runner
  pools we register and manage (alphanumeric + hyphen; **no colons**
  — GitHub Actions rejects them on runner labels)
- **GitHub's fixed labels** (`ubuntu-latest`, `ubuntu-22.04`,
  `windows-latest`, `macos-latest`, …) — used as-is. We cannot
  alias a GitHub-hosted runner to a custom label name.

### Why not `runner:self` (matching the PR-label `ai:*` style)?

Two reasons:

1. **Colons are invalid in GitHub Actions runner labels.** The
   allowed character set is alphanumeric + hyphen + underscore.
2. **GitHub-hosted runners cannot be aliased.** A workflow with
   `runs-on: runner-github` would queue indefinitely because no
   such runner label exists in GitHub's pool. We must use
   `ubuntu-latest` directly.

This was caught the hard way on operations PR #121 — an earlier
draft used `runner:self` / `runner:github` and would have shipped
unrunnable templates.

### Routing rule (per repo visibility)

Per-visibility defaults in `install/templates/workflows/`:

| Visibility | Default `runner_labels_*` value |
|---|---|
| PRIVATE | `'"runner-self"'` |
| PUBLIC | `'"ubuntu-latest"'` |

Rationale:

- Per `aidoc-flow-operations` `ops/DECISIONS.md` `OPS-0049`,
  private repos have no GitHub-hosted Actions minutes available;
  self-hosted is the only practical path.
- Per
  [GitHub Docs](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security),
  self-hosted runners are NOT recommended for public repos
  (untrusted fork PRs could execute arbitrary code on the runner).
  Public consumers default to `ubuntu-latest` accordingly.

Consumers can override either default via the
`runner_labels_routine` / `runner_labels_review` inputs in their
caller workflow (`with:` block).

### Adding a new runner origin

1. **Register the runner pool** with the appropriate label (e.g.,
   `runner-azure` for an Azure-hosted self-registered runner pool).
2. **Add a row** to the per-origin table in section 2 above with
   the install + capability notes.
3. **Update the routing rule** in section 2 if visibility coverage
   changes (e.g., a new origin becomes the default for a third
   visibility class).
4. **PATCH-tag** `aidoc-flow-ci` per `CHANGELOG.md` semver rules
   (additive — no consumer template changes needed unless the
   default routing rule changes).

## 3. Branch + commit naming (informal)

Conventional Commits — `<type>(<scope>):` or `<type>:`:

| Type | Use |
|---|---|
| `feat` | New feature (consumer-visible) |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `chore` | Maintenance, build, dependencies |
| `refactor` | Internal restructuring; no behavior change |
| `test` | Test-only changes |

Branch naming follows from commit type: `feat/...`, `fix/...`,
`docs/...`, etc.

## 4. Future label categories (anticipated, not yet adopted)

If `aidoc-flow-ci` ever needs additional label categories:

- **`ci:<directive>`** for CI-control labels beyond `skip-ai-review`
  (e.g., `ci:skip-lint` — currently no use case)
- **`area:<area>`** for area / component labels (consumer-local;
  not canonical)
- **`priority:<level>`** for priority labels — GitHub-conventional;
  consumer-local

These are NOT in the canonical taxonomy today. Add them only with
a documented use case + PATCH bump per the "Adding a new PR label"
process above.

## 5. References

- `install/templates/labels.json` — canonical 5-label taxonomy
- `install/install.sh` — idempotent install + fail-loud creation
  (handles drift between canonical and existing labels)
- `.github/workflows/ai-review.yml` — applies the 5 labels per
  workflow state
- `.github/workflows/composition.yml` — checks `skip-ai-review`
  for carry-forward semantics
- Operations governance:
  `aidoc-flow-operations/ops/iplans/IPLAN-0017_unified-ci-flows.md`
  §3.1c (runner-label convention) + §3.3 (PR-label taxonomy);
  `ops/DECISIONS.md` `OPS-0049` (no GitHub-hosted minutes for
  private repos)
- GitHub docs: [About self-hosted runners — security](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security)
