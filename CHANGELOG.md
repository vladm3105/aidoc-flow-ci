# Changelog — aidoc-flow-ci

Notable releases of the shared CI library. SemVer per `ci/vX.Y.Z`
tags (independent of framework spec semver per IPLAN-0017 §6 Q2).

## Unreleased

(empty — see `ci/v1.0.6` below for everything just shipped)

## ci/v1.0.6 — 2026-06-24 — caller-template backport + docs hardening (post-framework-Phase-A)

Patch release **completing the framework Phase A activation
loop**. Backports the local-only template fixes that framework had
to apply during PR #168 + documents the two undocumented consumer-
side prerequisites discovered during activation.

### Template fixes (backport from framework PR #168 commit `caed708`)

All 4 caller templates (`ai-review-{public,private}.yml` +
`composition-{public,private}.yml`) updated:

1. **yamllint colons** — removed alignment double-space after
   `runner_labels_review:`; default yamllint rules flag as
   `[colons] too many spaces after colon`.
2. **detect-secrets pragma** — appended `# pragma: allowlist secret`
   to all `secrets: inherit` lines (Yelp/detect-secrets flags the
   word "secrets" as high-entropy).

These were applied locally on framework's bootstrap to pass its
pre-commit hooks. Backporting means future consumers don't need
the same manual intervention. PR #20 originally drafted these fixes
(closed per founder direction during the `ci/v1.0.4` misplaced-tag
incident); re-shipped properly now that v1.0.5 is stable.

### Caller-pin bumps (all 10 templates)

All `install/templates/workflows/*.yml` pins bumped from `@ci/v1.0.2`
→ `@ci/v1.0.6`. Reusable workflow bodies functionally identical to
v1.0.5; v1.0.6 is templates + docs only.

### `install.sh` default `CI_TAG`

Bumped `ci/v1.0.2` → `ci/v1.0.6`.

### Docs hardening — 2 new troubleshooting sections

[`docs/troubleshooting.md`](docs/troubleshooting.md) gains
**§13 + §14**, both surfaced by framework Phase A activation:

- **§13 — `startup_failure` from Actions allowlist.** Consumer
  in `selected actions` mode must add `vladm3105/aidoc-flow-ci/*`
  to `patterns_allowed` (or the reusable workflow is silently
  blocked at workflow-load). Includes diagnose + fix commands.
- **§14 — `startup_failure` from caller's `workflow_permissions:
  read`.** Reusable workflow's `contents: write` declaration can't
  elevate above the caller's grant; consumer must add an explicit
  `permissions:` block to the caller workflow. Both targeted
  (caller-level) + alternative (bump repo default) fixes shown.

Both sections reference the framework Phase A surface event with
the operations PR #122 runbook for full activation context.

### `README.md` + `install/README.md` known-limitations refresh

The `v1.0.2 known limitations` section dropped the "unverified-in-
CI" caveat (verified end-to-end on framework Phase A) + added the
two new per-consumer prerequisites (Actions allowlist + caller
permissions) with pointers to the §13-14 troubleshooting sections.
`README.md` "What ships" table updated to 8 workflows (pre-commit
was added in v1.0.2 but not surfaced in the README until now).

### Backward compatibility

- Consumers on `ci/v1.0.0..ci/v1.0.5` continue to work; this patch
  only changes templates + docs. The reusable workflows themselves
  are unchanged from v1.0.5.
- Already-bootstrapped consumers can re-run `install.sh` from
  `ci/v1.0.6` to pick up the template fixes + pin bump.

### Rule 1 EXCEPTION audit-trail

This PR touches **4 surface families** (caller templates +
install.sh + docs + README/CHANGELOG = 6 distinct files), over
the ≤3 limit. Atomic release-prep pattern (same precedent as
W4.1 + W4.4 + v1.0.5): splitting creates incomplete intermediate
states where some refs say "ci/v1.0.6" + others still say
"ci/v1.0.2". Founder pre-approved this session: "Option 2 now"
+ "Ship all of the above as v1.0.6".

## ci/v1.0.5 — 2026-06-24 — fix: export reviewer auth env to "Run review" step

Patch release fixing a real reviewer-auth bug in `ai-review.yml`'s
"Run review" step, surfaced by **framework Phase A migration's first
real ai-review run** (2026-06-24 PR #169 on
`vladm3105/aidoc-flow-framework`).

### Bug

The "Run review (selected vendor) → verdict file" step only declared
`MODEL_IN` + `BUDGET_IN` in its `env:` block. The auth env vars the
CLIs need (`CLAUDE_CODE_OAUTH_TOKEN`, `ANTHROPIC_API_KEY`,
`OPENAI_API_KEY`) were NOT exported, so the CLIs ran without
credentials:

```text
Not logged in · Please run /login   ← claude CLI without CLAUDE_CODE_OAUTH_TOKEN
##[error]no parseable verdict — fail-closed
claude rc=1
```

`secrets: inherit` on the caller passes secret values into the
reusable workflow's `secrets` context, but they don't auto-export to
the step's process env — each step that uses a secret as env var
must explicitly declare it in `env:`.

### Fix

Added 3 env exports. Whichever auth secret the consumer set takes
effect; the others resolve to empty and are ignored by the
unselected CLI.

### Why operations dodged this

Operations runs the same workflow body as STANDALONE (not reusable),
so its `env:` block resolves `${{ secrets.X }}` against operations'
repo secrets directly — no inheritance hop. When the body was lifted
into a reusable workflow for v1.0.0, the env exports were omitted —
the inheritance hop made the bug invisible until the first real
consumer test (framework, 2026-06-24).

### Backward compatibility

Pure addition; no input/output changes. Consumers bump pin
`@ci/v1.0.X` → `@ci/v1.0.5`.

### Note on v1.0.4

`ci/v1.0.4` exists as a misplaced annotated tag (created in error
during PR #20 close; points at `ci/v1.0.3`'s commit). Skipping to
v1.0.5 avoids the broken tag.

## ci/v1.0.3 — 2026-06-24 — labels.json patch (`area: governance` description ≤100c)

Patch release fixing a content bug in

## ci/v1.0.3 — 2026-06-24 — labels.json patch (`area: governance` description ≤100c)

Patch release fixing a content bug in
`install/templates/labels.json`. The `area: governance` description
was 109 chars; GitHub's labels API caps descriptions at 100 chars
and returns `HTTP 422 Validation Failed: description is too long`
on creation. Surfaced by framework Phase A migration's first
`install.sh` run (2026-06-24): 8/9 canonical labels created
successfully on `vladm3105/aidoc-flow-framework`; the 9th
(`area: governance`) failed; per the v1.0.2 install.sh "fail-loud
on real failures" contract (OPS-#116 fix), the script exited
nonzero as designed.

### Fix

Trimmed `area: governance` description from 109 → 98 chars
(removed redundant trailing words; meaning preserved):

```text
before: "PR touches governance docs (CLAUDE.md, DECISIONS.md, IPLAN-*.md, governance/) or supersedes a locked decision"
after:  "PR touches governance docs (CLAUDE.md, DECISIONS.md, IPLAN-*.md, governance/) or a decision"
```

### Backward compatibility

- Consumers on `ci/v1.0.0` / `ci/v1.0.1` / `ci/v1.0.2` continue to
  work; this patch only fixes the install.sh label-bootstrap step
  for fresh adoptions.
- Consumers that already bootstrapped via earlier versions are
  unaffected (their `area: governance` label was never created
  because of the bug; they can re-run `install.sh` from `ci/v1.0.3`
  to pick it up, OR manually `gh label create` it with the fixed
  description).

### Lesson recorded

Added pre-commit-suitable validation pattern: any new label entry
in `labels.json` should fail-fast if `len(description) > 100`.
The validation is not enforced in v1.0.3 itself (would have caught
this; the labels.json was hand-edited without a check); v1.0.4+
may add a pre-commit hook + CI check.

## ci/v1.0.2 — 2026-06-24 — public-CLI unblock + pre-commit reusable

Patch release closing the v1.0.0/v1.0.1 public-CLI gap + adding a
reusable pre-commit workflow.

### Highlights

- **PUBLIC consumers unblocked** — `ai-review.yml` now installs
  codex + claude CLI at workflow start on `ubuntu-latest` (gated;
  no-op on self-hosted runners with pre-baked CLI). Public ai-review
  caller template REPLACE-ME placeholder removed; pinned to
  `@ci/v1.0.2`.
- **8th reusable workflow** — `pre-commit.yml` wraps the standard
  `pre-commit run --all-files` pattern used by framework +
  iplan-runner + operations.
- **All caller templates pinned to `@ci/v1.0.2`** — backward
  compatible (v1.0.0 + v1.0.1 callers continue to work).
- **`install.sh` default `CI_TAG` bumped to `ci/v1.0.2`**.
- **Honest framing on CLI install:** assembled from official upstream
  docs but unverified-in-CI as of v1.0.2 ship; first PUBLIC consumer
  adoption (likely framework Phase A migration) will validate;
  v1.0.3 may revise.

### Known limitations carried forward to v1.0.3

- **Public-consumer CLI install unverified-in-CI.** See
  `docs/troubleshooting.md` §10 for current state + how to report
  issues if the install step fails on your consumer repo.
- **Secret names hardcoded** to `APP_REVIEWER_1_ID` /
  `APP_REVIEWER_1_KEY` — v1.0.2 still doesn't parameterize.
- **Composition trigger shape** still the PR-#111 conservative
  pre-Phase-B shape; `workflow_run` redesign deferred per IPLAN-0017
  §3.4.

### Added

- **ubuntu-latest CLI install step in `ai-review.yml`** —
  PUBLIC consumers can now use `runner_labels_review: '"ubuntu-latest"'`
  and the workflow installs `codex` + `claude` CLI just-in-time
  before invoking them. **Closes the v1.0.0/v1.0.1 public-CLI gap.**
  Install step gated on `contains(inputs.runner_labels_review,
  'ubuntu-latest')` — no-op on self-hosted runners that have the CLI
  pre-baked (e.g., operations' `aidoc-flow-runner:latest` manually
  extended).
  - `codex` via `npm install -g @openai/codex@0.142.0` (pinned)
  - `claude` via `curl -fsSL https://claude.ai/install.sh | bash -s 2.1.89`
    + `echo "$HOME/.local/bin" >> "$GITHUB_PATH"` (native installer
    drops binary at `~/.local/bin`; not on default PATH)
  - `actions/setup-node@v5.0.0` (SHA-pinned
    `a0853c24544627f65ddf259abe73b1d18a591444` — verified via `gh api`)
    runs first since codex install uses npm
  - Required secrets on consumer side: `OPENAI_API_KEY` (codex) and/or
    `ANTHROPIC_API_KEY` (claude); `secrets: inherit` passes them
  - **Honest framing: unverified-in-CI as of v1.0.2 ship.** Install
    commands assembled from official docs ([openai/codex
    README](https://github.com/openai/codex) +
    [code.claude.com/docs/en/setup](https://code.claude.com/docs/en/setup))
    but not tested on a real consumer's CI run; first PUBLIC consumer
    adoption (likely framework's Phase A migration per
    `aidoc-flow-operations` IPLAN-0017 §4) will validate. Report
    issues at `vladm3105/aidoc-flow-ci`; v1.0.3 may revise based on
    real-world consumer feedback.
- **`install/templates/workflows/ai-review-public.yml`** updated:
  `runner_labels_review: '"REPLACE-ME-with-runner-having-reviewer-CLI"'`
  → `runner_labels_review: '"ubuntu-latest"'`. Pin bumped to
  `@ci/v1.0.2`. Header comment rewritten to document the new install
  step + the required secrets + the unverified-in-CI caveat.
- **Reusable `pre-commit.yml` workflow** (`.github/workflows/pre-commit.yml`)
  + caller template (`install/templates/workflows/pre-commit.yml`).
  Eighth reusable workflow shipped. Wraps the standard
  `pre-commit run --all-files` pattern used by framework +
  iplan-runner + operations (all three repos had nearly identical
  pre-commit workflow files; abstracted into one reusable). Inputs:
  `python-version` (default `"3.12"`), `extra-deps` (default empty;
  pip-install args for project-specific hook deps like
  `-r tests/conformance/requirements.txt`), `run-stage` (default
  empty; set `"manual"` for opt-in audits like pip-audit),
  `runner_labels` (default `"ubuntu-latest"`; PRIVATE consumers
  override to `"runner-self"`). Standard actions SHA-pinned per
  `feedback_verify_sha_pins` memory — both verified via `gh api`:
  `actions/checkout@v4.2.2` (`11bd71901bbe5b1630ceea73d27597364c9af683`)
  + `actions/setup-python@v6.2.0` (`a309ff8b426b58ec0e2a45f0f869d46889d02405`).

## ci/v1.0.1 — 2026-06-24 — origin-based labels + 5 new reusable workflows + docs tree

Minor release bundling the 5 new reusable workflows + 5 new docs +
the per-origin runner-label convention rename. **Backward
compatible** — v1.0.0 callers continue to work; the rename is in
the consumer caller templates only, not in the reusable workflow
inputs.

### Highlights

- **5 new reusable workflows** (`labeler` / `codeql` /
  `markdown-lint` / `links` / `secret-scan`) — see per-workflow
  entries below
- **Per-origin runner-label convention** — verbose v1.0.0 arrays
  (`'["self-hosted", "aidoc", "ci-ephemeral"]'`) replaced with
  clean `'"runner-self"'` in the per-visibility caller templates
- **5 new consumer-facing docs** under `docs/` (architecture +
  runners + overrides + security + troubleshooting) + docs index
  + LABELS.md area-namespace addition
- **All consumer caller templates pinned to `@ci/v1.0.1`**
  (existing v1.0.0 callers continue to work; consumers can
  optionally re-run `install.sh` to pick up the v1.0.1 templates)
- **`install.sh` default `CI_TAG` bumped to `ci/v1.0.1`**
- All SHA-pinned actions verified via
  `gh api repos/<owner>/<repo>/git/refs/tags/<tag>` per the
  `feedback_verify_sha_pins` lesson from the v1.0.1 prep

### Known limitations carried forward to v1.0.2

- **Public consumers using `ubuntu-latest` for `runner_labels_review`**
  still don't have a working reviewer-CLI install step. The
  `install/templates/workflows/ai-review-public.yml` keeps the
  `REPLACE-ME-with-runner-having-reviewer-CLI` placeholder
  pending v1.0.2. The original v1.0.1 plan was to add the
  install step in this release but it was deferred to keep
  v1.0.1 atomic + low-risk; v1.0.2 will ship verified install
  commands for `codex` / `claude` CLIs on ubuntu-latest.
- **Secret names hardcoded** to `APP_REVIEWER_1_ID` /
  `APP_REVIEWER_1_KEY` — v1.0.1 still doesn't parameterize.
  v1.0.2+ may add `app_id_secret_name` / `app_key_secret_name`
  inputs IF consumers actually need non-default names.
- **Composition trigger shape** is still the PR-#111
  conservative pre-Phase-B shape. The full `workflow_run`
  redesign per IPLAN-0017 §3.4 is the Phase-B target (requires
  rewriting the composition body to handle
  `github.event.workflow_run.pull_requests[0]`).

### Added

- **`docs/troubleshooting.md`** — 12-section troubleshooting guide
  drawn from operations PRs #100-118 + aidoc-flow-ci v1.0.0
  bootstrap + Wave-2 SHA-fix incident. Covers: composition
  pre-ai-review race; skip-ai-review carry-forward; runner not
  found (label mismatch / invalid chars / org-vs-repo); fabricated
  SHA pin (with `gh api` verify recipe); `gh: not found` (operations
  PR #101 root-cause); label install loop swallowing errors (PR
  #116); Azure SWA staging quota (memory `reference_azure_swa_staging_env_quota`);
  labeler "label does not exist" (consumer not bootstrapped); lychee
  flakes on bot-hostile hosts; v1.0.0 public-CLI gap; MD024
  duplicate-heading siblings_only fix; CHANGELOG rebase-conflict
  python recipe for stacked PRs. Per-section: symptom + cause +
  fix with concrete commands.
- **`docs/security.md`** — threat model + trust boundaries +
  fork-PR handling + secrets model + `pull_request_target`
  rationale + SHA-pinning + layered secret-scan defense. Honestly
  frames the self-hosted-on-public concern (the routing rule
  follows GitHub's recommendation: PRIVATE → `runner-self`,
  PUBLIC → `ubuntu-latest`; deviation is accepted-risk only).
  Covers the trust-gate semantics + how fork PRs route to
  HUMAN-REVIEW-ONLY, the App-identity model behind `composition`,
  the `v1.0.0` secret-name limitation, and the
  `gacts/gitleaks` vs `gitleaks/gitleaks-action` license choice.
  Documents the SHA-pinning verification workflow per
  `feedback_verify_sha_pins` memory entry.
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
