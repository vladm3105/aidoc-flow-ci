# Changelog — aidoc-flow-ci

Notable releases of the shared CI library. SemVer per `ci/vX.Y.Z`
tags (independent of framework spec semver per IPLAN-0017 §6 Q2).

## Unreleased

### Added

- **`docs/overrides.md`** — consumer-facing guide to the 3 override
  modes: (1) parameter override via `with:` (preferred — smallest
  deviation); (2) full replacement (drop `uses:`, write own jobs);
  (3) add a custom workflow (additive; no override at all). Includes
  concrete examples per mode (PRIVATE consumer overriding runner
  labels; custom reviewer replacement; per-repo conformance check),
  a what-you-cannot-do list (no step insertion inside reusable
  workflows; no `@main` pinning; no colons in runner labels), and
  the conflict-resolution menu when canonical updates clash with
  local overrides (re-align / keep divergence / upstream the change).
- **`docs/runners.md`** — runner-pool operational guide. Covers
  the runner-label convention recap (with `runner-self` /
  `ubuntu-latest` / future origins), the reference
  `aidoc-flow-runner:latest` Docker image (with operations' build
  scripts as reference), org-level vs repo-level runner registration
  with `runner-self` as additive label, per-origin operational
  tradeoffs (cost / latency / CLI availability / fork-PR safety),
  pool scaling, and the process for adding a new runner origin
  (e.g., `runner-azure`). `docs/README.md` index updated.
- **`docs/architecture.md`** — first focused design doc on
  `aidoc-flow-ci`. Covers: reusable-workflow model (consumer caller
  via `uses:`; runs in consumer's repo context); inventory of the 7
  shared workflows + what each does + typical triggers; trust + verdict
  flow connecting `ai-review` + `composition` (with Mermaid diagram);
  per-repo policy surfaces (the 6 config files consumers carry);
  inputs that vary per consumer (primarily `runner_labels`);
  versioning + tag scheme; local-overrides-shared rule pointer to
  `overrides.md`; drift detection (warning-only) pointer; and a
  pointer to operations governance for the deeper WHY (IPLAN-0017
  + charter + DECISIONS). `docs/README.md` updated to list it.

- **Reusable `secret-scan.yml` workflow** (`.github/workflows/secret-scan.yml`),
  caller template (`install/templates/workflows/secret-scan.yml`),
  and starter `.gitleaks.toml` allowlist
  (`install/templates/.gitleaks.toml`). Wraps **`gacts/gitleaks@v1.3.2`**
  (SHA-pinned `c9a0338361dc45a01aa7ebaaa5330179f3c62873`) — the
  **MIT-licensed** community wrapper. **Critical: NOT the official
  `gitleaks/gitleaks-action`** which switched to a proprietary EULA
  at v2.0.0 (May 2026); org-owned repos (including OSS) require a
  paid license. The CMS OSPO guide
  (`https://dsacms.github.io/ospo-guide/resources/gitleaks-action-license/`)
  explicitly points to `gacts/gitleaks` as the MIT wrapper for this
  use case. Same `gitleaks` binary underneath; no license key, no
  signup. Full-history scan (`fetch-depth: 0`) since `gitleaks
  detect` is the right shape for a PR gate. SARIF output uploaded
  to GitHub Code Scanning via `github/codeql-action/upload-sarif@v4.36.1`
  so findings appear in the PR's "Files changed" view via
  annotations. Inputs: `config-path` (optional `.gitleaks.toml`),
  `fail-on-findings` (default true — a PR gate that doesn't block
  isn't a gate), `runner_labels` (default `"ubuntu-latest"`).
  Starter `.gitleaks.toml` ships an allowlist for common test
  fixtures + docs examples + extends the default ruleset.
- **Reusable `links.yml` workflow** (`.github/workflows/links.yml`),
  caller template (`install/templates/workflows/links.yml`), and
  starter `.lychee.toml` config (`install/templates/.lychee.toml`).
  Wraps `lycheeverse/lychee-action@v2.6.1` (SHA-pinned
  `885c65f3dc543b57c898c8099f4e08c8afd178a2`) — the 2025-2026
  de-facto leader for link checking (Rust-based, async, fast).
  Chosen over the older `gaurav-nelson/github-action-markdown-link-check`
  (Node-based, slower, no built-in caching). Implements the mature
  **internal vs external split** pattern: internal mode is
  PR-blocking + uses `--offline` to skip http(s) URLs; external
  mode runs on cron + is non-blocking (rate-limited services flake;
  never gate PRs on them). Both share a `.lycheecache` cache via
  `actions/cache/restore` + `actions/cache/save@v4.2.0` with
  `if:always()` so cache persists even on failure. Starter
  `.lychee.toml` ships sensible defaults: 200/206/429 accept,
  fragment-checking, 14-concurrency, 1d cache age, excludes for
  loopback/private + bot-hostile hosts (twitter/x, linkedin) that
  403 on automated UA. Inputs: `mode` (internal|external), `paths`
  (default `.`), `config-file` (default `.lychee.toml`),
  `fail-on-error` (default true), `runner_labels` (default
  `"ubuntu-latest"`).
- **Reusable `markdown-lint.yml` workflow**
  (`.github/workflows/markdown-lint.yml`), caller template
  (`install/templates/workflows/markdown-lint.yml`), and starter
  `.markdownlint.json` config (`install/templates/.markdownlint.json`).
  Wraps `DavidAnson/markdownlint-cli2-action@v23.2.0` (SHA-pinned
  `fa0cd0f1a052f54da593c83860f2292982f5d142`) — the first-party
  successor to the legacy `markdownlint-cli`, recommended in
  2025-2026 over the older third-party wrappers
  (`nosborn/github-action-markdown-cli`,
  `igorshubovych/markdownlint-cli`). Uses cli2's built-in `github`
  outputFormatter so findings show as inline PR annotations (no
  separate problem-matcher action needed). Starter config relaxes
  the rules most projects override (MD013 line-length 120 with
  code-blocks/tables excluded; MD024 `siblings_only`; MD033 allows
  `br`/`details`/`summary`/`kbd`/`sup`/`sub`; MD041 disabled).
  Inputs: `globs` (default `**/*.md`), `config` (default empty —
  cli2 auto-resolves `.markdownlint.{json,yaml,…}` or
  `.markdownlint-cli2.*`), `fix` (default false), `runner_labels`
  (default `"ubuntu-latest"`).

- **Reusable `codeql.yml` workflow** (`.github/workflows/codeql.yml`),
  caller template (`install/templates/workflows/codeql.yml`). Wraps
  `github/codeql-action@v4.36.1` (SHA-pinned
  `21eb7f7842f33eafc83782b56fff2a2c43e9696f`) per GitHub's
  enterprise-scale code-scanning rollout pattern. Inputs: `languages`
  (JSON array, default `["actions"]`), `config-file` /
  `config` (inline alternative to file), `build-command` (override
  autobuild for compiled languages), `runner_labels` (default
  `"ubuntu-latest"`). Uses `category: /language:${{matrix.language}}`
  so multiple CodeQL workflows coexist without overwriting results.
  Matrix-driven explicit languages (not autodetect — autodetect
  breaks reproducibility on newly-added languages). Caller template
  triggers on push + PR + weekly cron (Mon 14:20 UTC) +
  workflow_dispatch per GitHub's recommended pattern. v3 enters
  deprecation Dec 2026; v4 is the supported major.

- **Reusable `labeler.yml` workflow** (`.github/workflows/labeler.yml`),
  caller template (`install/templates/workflows/labeler.yml`), and
  starter `.github/labeler.yml` config (`install/templates/labeler.yml`).
  Third reusable workflow shipped (after `ai-review` and `composition`).
  Auto-applies path-based PR labels via `actions/labeler@v6.1.0`
  (SHA-pinned `f27b608878404679385c85cfa523b85ccb86e213`). Consumer
  provides a per-repo `.github/labeler.yml` mapping paths to labels;
  the starter config maps common paths to the 4 canonical area
  labels added in the LABELS.md §3 area-namespace addition plus
  GitHub's built-in `documentation` label. Inputs: `runner_labels`
  (default `"ubuntu-latest"`; PRIVATE consumers override to
  `"runner-self"`), `config_path` (default `.github/labeler.yml`),
  `sync_labels` (default `false` — additive only; doesn't remove
  human-applied labels).

- **`LABELS.md` §3 + `install/templates/labels.json` — area-label
  namespace** (`area: <value>` colon-space, matching GitHub built-in
  style). Third PR-label sub-convention alongside `ai:<value>` (§1
  state) and `<verb>-<noun>` (§1 control). 4 canonical area labels
  added to the install taxonomy: `area: ci`, `area: governance`,
  `area: deps`, `area: tests` — auto-applied by the (forthcoming)
  reusable `labeler.yml` workflow when a consumer provides
  `.github/labeler.yml` mapping paths to label names. LABELS.md §3
  documents the three sub-conventions side-by-side with the
  rationale per form (programmatic vs semantic vs control directive).
  Sections 4-6 renumbered accordingly.
- **`docs/README.md`** — index for the `docs/` tree. Lists the
  available docs (`LABELS.md` today), the planned docs
  (`architecture` / `runners` / `overrides` / `security` /
  `troubleshooting` / `migration`) with their drafting triggers
  (drafted on demand, not preemptively), the contribution process,
  and cross-references to the operations governance tree
  (IPLAN-0017 + charter + DECISIONS).
- **`LABELS.md`** — first piece of CI documentation living on this
  repo (vs the operations governance tree). Defines conventions
  for the **two distinct label namespaces** used by `aidoc-flow-ci`:
  GitHub PR labels (the canonical 5-label taxonomy applied by
  `ai-review.yml`) and GitHub runner labels (per-origin convention:
  `runner-self` for our self-hosted pool; `ubuntu-latest` for
  GitHub-hosted; reserved `runner-azure`/`runner-aws`/… for future
  origins). Documents WHY the two namespaces use different separator
  conventions (PR labels can use `:`; runner labels cannot per
  GitHub Actions rules) and includes the routing rule by visibility
  (PRIVATE → `runner-self`, PUBLIC → `ubuntu-latest`).

## ci/v1.0.0 — 2026-06-23 — bootstrap MVP

Initial release. Unblocks IPLAN-0017 Phase A (framework migration)
and Phase B (operations migration).

### Added

- `.github/workflows/ai-review.yml` — reusable AI-review gate. Lifted
  from `aidoc-flow-operations/.github/workflows/ai-review.yml` with
  4 surgical patches: removed `pull_request_target` trigger;
  added `runner_labels_routine` + `runner_labels_review` inputs;
  parameterized both `runs-on:` lines. Existing inputs (`reviewer`,
  `model`, `max_budget_usd`, `tier`) preserved. Body unchanged.
- `.github/workflows/composition.yml` — reusable App-approval status
  check. Lifted from operations post-PR-#111 (conservative trigger
  shape — `pull_request_target [labeled/unlabeled]` +
  `pull_request_review`) with 3 surgical patches: removed both
  event-trigger blocks; added `workflow_call` with `runner_labels`
  input; parameterized `runs-on:`. Body unchanged. **Full
  `workflow_run` redesign per IPLAN-0017 §3.4 deferred to v1.X**
  (requires rewriting body to handle workflow_run event payload).
- `install/install.sh` — one-shot consumer bootstrap. Fetches
  templates via raw GitHub URLs (works under process-sub +
  local-clone modes). Idempotent. Preserves existing files (local
  override always wins). User-visible work dir; no auto-cleanup.
- `install/templates/workflows/{ai-review,composition}-{private,public}.yml`
  — 4 caller templates per visibility. Public ai-review ships
  `runner_labels_review` as `REPLACE-ME` placeholder (see Known
  Limitations).
- `install/templates/config.json.template` — default per-consumer
  `.github/ai-review/config.json` (trust allowlists, governance
  locked paths, composition / auto-merge / autofix toggles).
- `install/templates/labels.json` — canonical 5-label taxonomy
  (`ai:review-passed`, `ai:review-changes`,
  `ai:human-review-required`, `skip-ai-review`,
  `ai:autofix-applied`).
- `sync/check-drift.sh` — drift detector. Warning-only; **never
  blocks** (per IPLAN-0017 §3.1b locked rule). No `--strict` mode.
- `install/README.md` + repo-root `README.md` — consumer-facing
  intro + usage + v1.0.0 known limitations.

### Known limitations

- Public consumers need their own reviewer-equipped self-hosted
  runner; `ubuntu-latest` doesn't have `codex` / `claude` CLI.
- Secret names hardcoded; not parameterized.
- Composition trigger shape is conservative pre-Phase-B; full
  `workflow_run` redesign deferred.

### Provenance

Workflow content lifted from `aidoc-flow-operations` PRs #100-118
(the 2026-06-22→23 AI-reviewer Stage 1 activation arc + governance
discipline rules); patches verified locally via smoke tests before
shipping. Per-runbook references in
`aidoc-flow-operations` `ops/inbox/2026-06-23_cto-platform_aidoc-flow-ci-R-{a,b,c,d}-*.md`.
