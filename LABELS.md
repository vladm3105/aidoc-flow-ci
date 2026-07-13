# LABELS.md — `aidoc-flow-ci` label conventions

This document defines the label conventions used by `aidoc-flow-ci`
across **two distinct namespaces**: GitHub **PR labels** (applied by
the ai-reviewer + labeler workflows) and GitHub **runner labels** (used
in `runs-on:` to select runner pools).

The namespaces have different behavior:

| Namespace | Allowed characters | Length | Aliasing |
|---|---|---|---|
| PR labels | User-facing issue/PR metadata; names may contain spaces, punctuation, and emoji | Descriptions are limited to 100 characters | n/a |
| Runner labels | Scheduling selectors; custom-label matching is case-insensitive | Use short lowercase ASCII names as a workspace convention | GitHub-hosted labels are fixed (`ubuntu-latest`, etc.); cannot be aliased to custom names |

The two namespaces therefore use different separator conventions
intentionally. Don't try to unify them; the constraints differ.

## PR labels — the canonical 16

`install/templates/labels.json` is the canonical set — **16 labels** in
three functional groups. `install/install.sh` creates them idempotently
on a consumer repo at bootstrap (fail-loud; prefetches existing, only
adds missing, never removes drift). The groups:

### 1. State / control labels (6)

The `ai:*` state labels are applied by `ai-review.yml`. The two `skip-*`
directives are applied by an authorized human/operator; workflows consume
them but do not create them automatically.

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
> would defeat the gate. Remove the label to request a fresh review.

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

## 2. Runner labels — composable scheduling convention

Used in the reusable workflow's `runs-on:` expressions (consumer
caller templates set the `runner_labels_*` inputs to one of these):

| Label | Dimension | Contract | Where it resolves |
|---|---|---|---|
| `self-hosted` | Runner class | GitHub-managed default label for self-hosted runners | Any registered self-hosted runner unless configured without default labels |
| `ci-runner` | Purpose | General CI workload with standard tools and a LiteLLM network route | Any conforming CI pool |
| `single-use` | Lifecycle | Accept exactly one job, then de-register and destroy the runner | JIT/single-use supervisor |
| `project-<name>` | Optional isolation | Restrict a job to a deliberately project-specific pool | Only runners registered for that project |
| `ubuntu-latest` | GitHub-hosted selector | GitHub-managed Ubuntu image; public LiteLLM reachability is still required for AI jobs | GitHub-hosted runner pool |

### Naming convention

Runner labels describe independent scheduling dimensions:

- **Purpose:** `ci-runner` says what workload the pool accepts.
- **Lifecycle:** `single-use` guarantees one job per runner registration.
- **Optional isolation:** `project-<name>` is appended only when a project
  must not share the general pool. It is not part of the default selector.
- **Provider/origin is intentionally omitted** from the canonical selector.
  Moving the pool between hosts or clouds must not require caller changes.
- **GitHub's fixed labels** (`ubuntu-latest`, `ubuntu-22.04`,
  `windows-latest`, `macos-latest`, …) — used as-is. We cannot
  alias a GitHub-hosted runner to a custom label name.

The canonical private selector is therefore:

```json
["self-hosted", "ci-runner", "single-use"]
```

Do not add `aidoc`, a repository name, host name, cloud provider, or model name
to the default selector. Add `project-<name>` only when isolation is an
explicit requirement and the matching runner registration already exists.

Custom labels are case-insensitive. Register them in lowercase so workflow
YAML, operational tooling, and UI output remain consistent. GitHub deletes
unused custom labels automatically after 24 hours, so runner registration—not
a separately pre-created label record—is the source of truth.

### Routing rule (per repo visibility)

Per-visibility defaults in `install/templates/workflows/`:

| Visibility | Default `runner_labels_*` value |
|---|---|
| PRIVATE | `'["self-hosted", "ci-runner", "single-use"]'` |
| PUBLIC | `'"ubuntu-latest"'` |

> Pre-`ci/v1.9.0` the PRIVATE templates shipped a `'"runner-self"'` placeholder
> (a non-registered label → jobs queued forever, FT-9). v1.9.0+ ship the real
> retired `ci-ephemeral` array directly. `ci/v2.0.0` replaces that combined
> label with the separate purpose/lifecycle labels `ci-runner` + `single-use`.

Rationale:

- Per `aidoc-flow-operations` `ops/DECISIONS.md` `OPS-0049`,
  private repos have no GitHub-hosted Actions minutes available;
  self-hosted is the only practical path.
- Per
  [GitHub Docs](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security),
  self-hosted runners are NOT recommended for public repos
  (untrusted fork PRs could execute arbitrary code on the runner).
  Public consumers default to `ubuntu-latest` accordingly.

Consumers can override the relevant `runner_labels` input in their caller
workflow. `ai-review` exposes separate `runner_labels_routine` and
`runner_labels_review` inputs, but private templates intentionally set both to
the same unified selector.

### Adding a specialized pool

1. Decide which capability or isolation property the shared pool lacks.
2. Choose a descriptive lowercase label, normally `project-<name>` for
   isolation or a capability such as `gpu`.
3. Register the runner with the base labels plus the specialized label.
4. Override only the callers that require that pool; general callers retain
   `["self-hosted", "ci-runner", "single-use"]`.
5. Add the label contract to this table if it becomes workspace-wide.
6. **PATCH-tag** `aidoc-flow-ci` per `CHANGELOG.md` semver rules
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
