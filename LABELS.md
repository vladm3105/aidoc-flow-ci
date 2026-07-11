# LABELS.md — `aidoc-flow-ci` label conventions

This document defines the label conventions used by `aidoc-flow-ci`
across **two distinct namespaces**: GitHub **PR labels** (applied by
the ai-reviewer + labeler workflows) and GitHub **runner labels** (used
in `runs-on:` to select runner pools).

GitHub enforces different rules per namespace:

| Namespace | Allowed characters | Length | Aliasing |
|---|---|---|---|
| PR labels | Any UTF-8 (incl. `:`); GitHub recommends short readable names | ≤ 50 chars | n/a |
| Runner labels | Alphanumeric + `-` + `_` only — **no colons**; case-insensitive matching | ≤ 25 chars per label; multiple labels allowed via array | GitHub-hosted labels are fixed (`ubuntu-latest`, etc.); cannot be aliased to custom names |

The two namespaces therefore use different separator conventions
intentionally. Don't try to unify them; the constraints differ.

## PR labels — the canonical 16

`install/templates/labels.json` is the canonical set — **16 labels** in
three functional groups. `install/install.sh` creates them idempotently
on a consumer repo at bootstrap (fail-loud; prefetches existing, only
adds missing, never removes drift). The groups:

### 1. State / control labels (6)

Applied by the reusable `ai-review.yml` + `audit-trail-check.yml`
workflows (or by a human, for the two `skip-*` directives).

| Label | Color | Kind | Meaning |
|---|---|---|---|
| `ai:review-passed` | `0e8a16` | state (canon §5.1) | Reviewer App APPROVED the PR |
| `ai:review-changes` | `d93f0b` | state (canon §5.1) | Reviewer App requested CHANGES |
| `ai:human-review-required` | `fbca04` | state (canon §5.1) | Fork PR or non-allowlisted author — trust gate routed to human review |
| `ai:autofix-applied` | `1d76db` | action (IPLAN-0014; optional) | The autofix fixer applied a patch on this PR (not a canon §5.1 required label) |
| `skip-ai-review` | `5319e7` | **control / directive** | Human override: suppress the reviewer on subsequent pushes; `composition` carries the prior approval forward |
| `skip-audit-trail` | `d876e3` | **control / directive** | Two-signal override for the OPS-0069 audit-trail CI check — MUST be paired with `[skip-audit-trail]` in a commit body (per REPO_STANDARDS §14.2 / PLAN-002 §4.6). One signal alone does not skip. |

> **Note on `skip-ai-review` semantics.** Its behavior is
> **suppress-and-carry-forward**: with the label present, `ai-review.yml`
> does not re-run the heavy reviewer on subsequent pushes and
> `composition.yml` carries the prior APPROVED verdict forward so the
> gate stays green. Apply it **only by hand** after a clean review, for a
> trivial follow-up that doesn't change reviewed code — auto-applying
> would defeat the gate. (The terse `labels.json` description is being
> reconciled to this wording.)

### 2. Diff-class labels (8) — auto-applied by `labeler.yml`

The OPS-0065 diff-class labels. The reusable `labeler.yml`
(`actions/labeler@v6`) applies them from the file paths a PR touches,
per the consumer's `.github/labeler.yml`. The **canonical path→label map
and diff-class mapping live in `docs/REPO_STANDARDS.md` §5.2** — that is
the source of truth; the table below is the label reference.

| Label | Color | Applied when the PR touches |
|---|---|---|
| `governance` | `8b6914` | `CLAUDE.md`, `ops/DECISIONS.md`, `.claude/agents/`, `.claude/skills/`, `.github/ai-review/` |
| `docs` | `0075ca` | `docs/`, `README.md`, `CHANGELOG.md`, `ops/HANDOFF.md` |
| `workflows` | `5319e7` | `.github/workflows/` |
| `scripts` | `c5def5` | `scripts/` |
| `agents` | `d4c5f9` | `.claude/agents/`, `.claude/skills/`, `.claude/workflows/` |
| `tests` | `bfd4f2` | `tests/` |
| `config` | `fef2c0` | `Dockerfile`, `pyproject.toml`, `requirements*.txt`, `package*.json`, `uv.lock`, `.pre-commit-config.yaml` |
| `plans` | `e99695` | `ops/iplans/IPLAN-*.md`, `plans/PLAN-*.md` |

These are **unprefixed single words** — deliberately NOT `area:`-prefixed.
They map 1:1 to the OPS-0065 diff classes so a reviewer dispatching
diff-class agents can read the applied labels directly.

### 3. Area labels (2) — canon §5.3

| Label | Color | Applied when |
|---|---|---|
| `dependencies` | `0366d6` | Dependabot PR (matches Dependabot's own convention) |
| `security` | `b60205` | Security-tagged issue or PR |

### Naming conventions across the PR-label set

Three forms, each marking a different label purpose at a glance:

| Form | Used by | Why this form |
|---|---|---|
| `ai:<noun>` (colon, no space) | §1 AI **state** labels (programmatic) | Tight prefix the workflow code parses/matches; no-space avoids quoted-string label handling in shell loops |
| `<verb>-<noun>` (hyphenated, no prefix) | §1 `skip-ai-review`, `skip-audit-trail` (human directives) | Reads like a command; not part of a namespace |
| `<noun>` (unprefixed single word) | §2 diff-class + §3 area labels (semantic, path- or source-driven) | Maps 1:1 to an OPS-0065 diff class / a well-known area; kept short for the PR sidebar |

**Do NOT mix forms:** a state label MUST use `ai:<noun>`; a diff-class
label MUST be the bare word from §2. Consistency within each form is the
discipline.

### Canonical source-of-truth + adding a label

`install/templates/labels.json` is canonical (name/color/description);
`docs/REPO_STANDARDS.md` §5.2 owns the diff-class path map. To add one:

1. Edit `install/templates/labels.json` (`{name, color, description}`).
2. If it's a diff-class label, update `docs/REPO_STANDARDS.md` §5.2's
   path→label map; otherwise document it in the relevant table above.
3. PATCH-tag `aidoc-flow-ci` (a new label is additive) per `CHANGELOG.md`
   semver rules.
4. Consumers re-run `install/install.sh` to pick it up (idempotent +
   fail-loud, PR #116 fix — prefetches existing, adds only missing, exits
   nonzero on real auth/permission/network failures).

### Live drift from canonical (allowed, must be intentional)

A consumer may carry labels not in `labels.json` (e.g., operations has
`ai:review-escalated` + `ai:review-human-cleared`). `install.sh` does NOT
remove drifted labels — only adds missing canonical ones. To reconcile:
add useful extras to `labels.json` + PATCH-tag, or delete stale ones via
`gh label delete <name> -R <repo>`.

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
| PRIVATE | `'["self-hosted", "aidoc", "ci-ephemeral"]'` (+ `[…, "ai-review"]` heavy job) |
| PUBLIC | `'"ubuntu-latest"'` |

> Pre-`ci/v1.9.0` the PRIVATE templates shipped a `'"runner-self"'` placeholder
> (a non-registered label → jobs queued forever, FT-9). v1.9.0+ ship the real
> `ci-ephemeral` array directly.

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

## 4. References

- `install/templates/labels.json` — canonical 16-label taxonomy
  (name/color/description).
- `docs/REPO_STANDARDS.md` §5.2 — diff-class label path→label map
  (source of truth for §2 above); §5.3 — area labels.
- `install/install.sh` — idempotent install + fail-loud creation
  (handles drift between canonical and existing labels).
- `.github/workflows/ai-review.yml` — applies the §1 state labels.
- `.github/workflows/labeler.yml` — applies the §2 diff-class labels.
- `.github/workflows/composition.yml` — checks `skip-ai-review`
  for carry-forward semantics.
- `.github/workflows/audit-trail-check.yml` — honors `skip-audit-trail`
  (two-signal).
- Operations governance:
  `aidoc-flow-operations/ops/iplans/IPLAN-0017_unified-ci-flows.md`
  §3.1c (runner-label convention) + §3.3 (PR-label taxonomy);
  `ops/DECISIONS.md` `OPS-0049` (no GitHub-hosted minutes for
  private repos).
- GitHub docs: [About self-hosted runners — security](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security)
