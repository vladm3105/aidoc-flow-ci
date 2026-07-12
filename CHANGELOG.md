# Changelog — aidoc-flow-ci

Notable releases of the shared CI library. SemVer per `ci/vX.Y.Z`
tags (independent of framework spec semver per IPLAN-0017 §6 Q2).

### Changed — markdown-lint canon config relaxed for workspace doc styles (PLAN-007 W3) (2026-07-12)

- **`install/templates/.markdownlint.json` disables `MD013` (line-length),
  `MD024` (duplicate-heading), and `MD036` (emphasis-as-heading).** These three
  fired almost entirely on legitimate workspace doc styles — ADR bold-labels
  (`**Context**`/`**Decision**`/… in every `DECISIONS.md`), keep-a-changelog
  repeated `### Added`/`### Changed`, and long changelog data rows — blocking the
  report-only → blocking graduation (FT-11) behind hundreds of false-positives.
  Relaxing them drops per-repo residuals from the hundreds to the dozens
  (engramory 580→27, iplanic 418→60, iplan-standard 30→3), leaving only genuine
  cleanups (MD033 inline-HTML, MD040 code-fence-language, MD056 tables) for
  per-repo graduation. Founder-decided 2026-07-12 (weakens the 120-char line
  discipline workspace-wide, accepted as the tradeoff).
- **Template-only change — no reusable body change, no new tag, `VERSION`
  unchanged** (bumping it would falsely flag pinned consumers as stale via
  `check-pin-currency.sh`). Consumers hold
  their own `.markdownlint.json` copies; graduate each by adopting this relaxed
  config + `--fix` + `fail-on-findings: true` (per-repo PRs, cleanest-first).
  `business` already graduated (0 residual) ahead of this relaxation.

### Fixed — composition caller templates missing `permissions:` block (2026-07-12)

- **`composition-public.yml` + `composition-private.yml` templates now ship a
  top-level `permissions:` block** (`pull-requests: read` + `contents: read`).
  Without it, a consumer's composition caller `startup_failure`s at run-init
  (zero jobs, web-UI-only error) under the repo read-default token — the same
  class as the ai-review v1.7.1 fix. This silently broke composition on
  framework (where it is a REQUIRED check), iplanic, business, engramory, and
  iplan-standard; operations was unaffected (its caller had the block). No
  reusable body change (no new tag needed); existing callers must add the block
  directly.

### Fixed — branch-protection check-names corrected to verified emitted strings (PLAN-007 W2, FT-1/FT-2) (2026-07-12)

- The branch-protection templates + REPO_STANDARDS §2 listed required-check
  names that **do not match what CI emits** — `Lint / format / security hooks`
  (real: `call / Lint / format / security hooks`) and `Secret scan (gitleaks)`
  (real canon name: `call / gitleaks`) — and OMITTED `call / verify` (FT-1). A
  mismatched required context never turns green → arming it would block every PR
  forever (the trap W4 fleet-arming was about to hit). Corrected all three tier
  templates + §2 to the verified `call / …` names, captured a verified-emitted-
  names table in §2, and added **`tests/test_checknames.sh`** — asserts every
  `call / …` template context maps to a real reusable job, so it can't drift
  again. Closes FT-1 + FT-2.

### Added — automated test suite (PLAN-007 W1) (2026-07-12)

- **`tests/` + `.github/workflows/tests.yml`** — the automated regression gate
  the library previously lacked (verification was fleet-dogfooding only). Runs
  on every PR + push: static lint (`shellcheck` -S error, `yamllint`,
  `actionlint`), **workflow-contract** assertions (every reusable declares
  `permissions` + uses only allowlisted actions + no floating pins; every
  private caller template carries valid-JSON `ci-ephemeral` `runner_labels`;
  ai-review/composition callers carry the permissions block), **script-logic**
  unit tests (pin-currency staleness detection, `--repin` tag+SHA seds +
  idempotency), and a **negative** suite proving the checks reject third-party
  actions / malformed `runner_labels` / permissions omissions. 103 assertions.
  Building the suite immediately surfaced 2 over-strict checks (now corrected).

### Added / Fixed — pin-currency wiring + SHA-pin re-pin (2026-07-12)

- **`install.sh --repin` now converts SHA-pinned callers** (`@<sha> # ci/vX`)
  to the target tag, not just `@ci/v*` tag pins — the canonical re-pin tool now
  covers the whole fleet (the audit-trail caller was historically SHA-pinned and
  silently skipped, needing a manual conversion).
- **`check-pin-currency.sh` is now wired into the weekly drift check**:
  `sync/check-standards-drift.sh` runs it in-repo (covers public + private via
  each repo's own checkout), and aidoc-flow-ci's `standards-drift.yml` adds a
  central `--fleet` public-repo audit. Pin-staleness is now caught automatically
  each Monday, not just on demand.

### Added — pin-currency drift check (2026-07-12)

- **`sync/check-pin-currency.sh`** — flags consumer `@ci/vX.Y.Z` pins that LAG
  the current `VERSION`. Fills the pin-staleness gap the two existing drift
  checks miss (both compare a caller to the template *at its pinned tag*, so a
  6-versions-behind repo shows "no drift"). In-repo warning-only mode + a
  `--fleet <repos…>` table mode. Pairs with `install.sh --repin`. Also wired as
  `deploy-ci-wizard.sh audit-pins`.

### Added — AI-agent CI deployment playbook + wizard (2026-07-12)

- **`docs/AI_CI_DEPLOYMENT.md`** — end-to-end, AI-agent-oriented how-to for
  deploying the full CI stack (ai-review, composition, auto-merge, pre-commit,
  audit-trail, secret-scan, links, markdown-lint, labeler, docs-sync, codeql)
  on a new repo: prerequisites (🔴 founder vs 🟢 AI), dependency-ordered
  sequence, a gotchas checklist encoding every failure mode from the 2026-07
  fleet rollout, verification protocol, and arming. 
- **`install/deploy-ci-wizard.sh`** — safe read-only/scaffold wizard
  (`preflight`/`plan`/`scaffold`/`verify`) that audits prerequisites, picks the
  public/private variant + runner labels, and generates valid caller files
  (correct JSON labels, permissions blocks, canon-reusable pointers, markdown-
  lint report-only). Never commits/pushes/merges/sets-secrets.
- **`install/templates/workflows/audit-trail-{public,private}.yml`** — new
  caller templates (audit-trail previously had no template).

## ci/v1.9.5 — 2026-07-11

### Added

- **`markdown-lint` gains a `fail-on-findings` input** (default `true`). Set
  `false` for a **report-only** rollout: cli2 still emits `::error` PR
  annotations, but the job exits 0 so it does not block merge. This is the
  correct way to stage markdown-lint onto a repo with existing lint debt —
  GitHub **forbids `continue-on-error` on a reusable-call job** (actionlint
  `syntax-check`), so report-only must be expressed on the reusable, not the
  caller. Mirrors `secret-scan`'s `fail-on-findings`.

### Fixed

- **`.lychee.toml` starter template dropped the invalid `include_fragments`
  key.** lychee 0.24.2 (the version `links.yml` installs) rejects that key with
  a fatal `TOML parse error`, so any consumer copying the template verbatim got
  a config-load failure instead of a link check. Removed the key (fragment
  checking stays at lychee's default).

### Notes

- Cross-repo relative links (`../sibling-repo/…`) resolve only in the local
  multi-repo workspace, never in single-repo CI — a `links` gate on such a repo
  needs a `.lychee.toml` excluding the sibling-repo path segments (see the
  operations/framework consumer configs). Documented for future adopters.

## ci/v1.9.4 — 2026-07-11

### Fixed

- **`markdown-lint` + `links` now deploy** — both wrapped a third-party
  marketplace action (`DavidAnson/markdownlint-cli2-action`,
  `lycheeverse/lychee-action`) that the workspace allowed-actions policy
  BLOCKS at run-init → `startup_failure` (proven live: `links` ran
  `startup_failure` on operations + business; `markdown-lint` never ran
  anywhere). Same defect class fixed for `secret-scan` in v1.9.2. Both are
  now refactored to install the tool directly in a `run:` step:
  - **`links`** curls the pinned **lychee** release. Uses the **musl** static
    build (`x86_64-unknown-linux-musl`, SHA-256 verified) — NOT the gnu build,
    which needs GLIBC 2.38+ and fails on older self-hosted Debian ephemeral
    runners. Same modes/inputs/caching; consumer-controlled inputs mapped to
    `env` (no `${{ }}` injection).
  - **`markdown-lint`** installs `markdownlint-cli2@0.23.0` from npm after
    `actions/setup-node` (allowlisted `actions/*`, guarantees Node on
    self-hosted runners). Globs collected with `noglob` so the shell does not
    pre-expand them; cli2 auto-emits `::error` PR annotations.

### Changed

- **`install/templates/.markdownlint.json`** now also disables **MD060**
  (table-column-style) — a new, very strict rule in cli2 0.23.0 that flags
  table-pipe padding on essentially every existing doc (348 MD060 hits on this
  repo alone). Cosmetic + `--fix`-able; disabling it keeps the canon default
  from turning every repo red on adoption. Enabling `markdown-lint` as a blocking gate
  still requires a per-repo `--fix` remediation pass first (see FT-11).

### Notes

- These two workflows had **never run green on any consumer** (blocked at
  run-init), so their defects went unseen — the "never-deployed workflows
  accumulate silent defects" pattern. This release makes them *runnable*;
  fleet **population** remains per-repo content triage (markdown-lint reds on
  real style violations; links is low-risk in `--offline` internal mode) and
  is tracked as FT-11, not swept blindly.

## ci/v1.9.3 — 2026-07-11

### Fixed

- **secret-scan now passes on clean repos + skips test-fixture false-positives.**
  Two fixes so the gate is adoptable fleet-wide: (1) the reusable now ships a
  **default gitleaks allowlist** (when the consumer sets no `config-path`) for
  test fixtures + detect-secrets baselines — placeholder API keys, HMAC test
  vectors, `tests/`/`vectors/`/`fixtures/` paths, `.secrets.baseline` — the
  standard FP sources, not live secrets; (2) the SARIF-upload step is
  `continue-on-error` so **PRIVATE repos without GitHub Advanced Security**
  (which return `403 code scanning not enabled`) no longer fail the job — the
  load-bearing gitleaks GATE is unaffected. A consumer that needs stricter
  scanning ships its own `.gitleaks.toml`.

## ci/v1.9.2 — 2026-07-11

### Fixed

- **`secret-scan` now deploys** — it ran the third-party `gacts/gitleaks` wrapper
  action, which the workspace allowed-actions policy (`actions/*`, `github/*`,
  `vladm3105/aidoc-flow-ci/*` only) **blocks at run-init → startup_failure**. That
  is why secret-scan never ran on any consumer. Replaced the wrapper with a
  direct install + run of the upstream **gitleaks binary** (MIT, no key, no
  allowlist change): `curl` the pinned `v8.30.1` release, `gitleaks dir .`
  → SARIF → `github/codeql-action/upload-sarif` (allowlisted). Same scanner,
  same gate semantics (`fail-on-findings` → `--exit-code`).

## ci/v1.9.1 — 2026-07-11

### Added

- **App-native trust-config fetch** — the ai-review trust job + review job now
  mint their cross-repo read token from the reviewer App
  (`create-github-app-token`, scoped read-only to `trust_config_repo`) instead of
  requiring a per-repo `AI_REVIEW_TOKEN` PAT. Token precedence: **App token →
  `AI_REVIEW_TOKEN` → `GITHUB_TOKEN`** (fully backward-compatible — repos with
  `AI_REVIEW_TOKEN` are unaffected; repos with only the App drop the PAT need).
  Requires the reviewer App installed on `trust_config_repo` with
  `contents: read`. A pre-flight verifies the minted token can actually read the
  config and falls back to the PAT/GITHUB_TOKEN if not, so a mis-scoped App never
  reds the gate. Fixes the engramory `repository not found` trust-fetch failure.
  (Security-reviewed: read-only scope enforced via `permission-contents: read`;
  no PR-controlled input reaches token minting or scope; fail-closed preserved.)

## ci/v1.9.0 — 2026-07-11

### Added

- **`install.sh --repin`** — version-only re-pin. Rewrites the `@ci/vX.Y.Z` on
  every `uses: …/aidoc-flow-ci/…` line to the target tag and touches nothing
  else — runner_labels, permissions, triggers, and all consumer customization
  are preserved. This is the CORRECT re-pin operation; **`--update` must never
  be used for a re-pin** (it re-applies the template body and clobbers
  customized callers). Closes FT-9.

### Fixed

- **Private caller templates no longer ship the `runner-self` placeholder** (the
  FT-9 root cause). `ai-review-private.yml`, `composition-private.yml`, and
  `doc-maintainer-private.yml` now emit the real
  `["self-hosted","aidoc","ci-ephemeral"]` label instead of `runner-self` —
  which resolved to `runs-on: runner-self`, matched no registered runner, and
  queued every required check forever (bricking the merge gate). The v1.8.1
  `--update` sweep stamped this across operations/business/iplanic/interlog
  before it was caught. Commented override examples in the single templates
  (codeql/labeler/markdown-lint/pre-commit/secret-scan) corrected to the same
  real label. Public templates unchanged (`ubuntu-latest`).

### Docs

- **Runner class by visibility (canon rule).** Documented the workspace default:
  **private repos → self-hosted `ci-ephemeral` runners; public → `ubuntu-latest`**
  (a private repo on `ubuntu-latest` queues forever — no GitHub-hosted minutes
  for private repos, OPS-0049). `install.sh --update` auto-detects visibility
  (`gh repo view isPrivate`) + installs the matching `-private`/`-public`
  variant; bootstrap selects it from `--visibility` (defaults `private`). Added
  the explicit rule + the "register the self-hosted pool before adopting"
  prerequisite + external-adopter override. `docs/runners.md` "Workspace
  default" + REPO_STANDARDS §4.1. (No code change — the tooling already
  implements it.)

## ci/v1.8.1 — 2026-07-10

> PATCH — the final PLAN-005 security hardening (PR-A part 2 / D2). Closes the
> `skip-ai-review` approve-then-push bypass in both merge gates.

### Fixed

- **PR-A part 2 — HEAD-relative `skip-ai-review` carry-forward (D2)** in both
  `auto-merge-ai-prs.yml` (re-arm) and `composition.yml` (required check): the
  label now carries a prior App approval forward only when HEAD's **content
  (git tree SHA) is identical** to an App-approved commit — closing the
  approve-benign-then-push-malicious bypass. §15 label-cycle recovery still works
  (approval stays at HEAD → tree matches); a rebase onto an *advanced* base
  changes the tree → fresh review required (troubleshooting §15). Fails closed on
  every path. Security-reviewed (no BLOCKER); the tree-SHA logic is offline-tested
  (unit + real-git simulation). **The live §15 label-cycle smoke test is the
  first-`v1.8.1`-adopter verification** (it could not be run pre-release —
  requires a working consumer with the reviewer App armed).

## ci/v1.8.0 — 2026-07-10

> The **PLAN-005 ai-review pipeline-hardening** release (MINOR). Non-breaking:
> PR-D makes the reviewer engine config-driven (callers stop hardcoding `codex`;
> defaults fall back to `codex`, so existing behavior is preserved until a
> consumer re-pins) and PR-G reads composition's config from the repo's default
> branch. Consumers re-pin `@ci/v1.8.0` (or `install.sh --update`) to adopt.
> PR-A part 2 (skip-ai-review hardening) is deliberately NOT in this cut — it is
> held for a live §15 smoke test and follows as `v1.8.1`.

- **PR-A part 1** — enforcer **governance floor**: `auto-merge-ai-prs.yml`
  computes `GOV_LOCKED` independently and refuses to re-arm unconditionally on
  gov-locked PRs (`.github/**`/`governance/**`/`templates/ai-review/**`), closing
  the `ai:review-passed`+`skip-ai-review` double-label bypass on governance paths.
- **PR-A part 2** — **HEAD-relative `skip-ai-review` carry-forward** (D2) in
  BOTH gates (`auto-merge-ai-prs.yml` re-arm + `composition.yml` required-check):
  the label now carries a prior App approval forward only when HEAD's **content
  (git tree SHA) is identical** to an App-approved commit — closing the
  approve-benign-then-push-malicious bypass while preserving §15 label-cycle
  recovery (approval stays at HEAD) and no-op rebases. A rebase onto an advanced
  base changes the tree → fresh review required (troubleshooting §15).
  **⚠️ pending a live §15 label-cycle smoke test before it merges.**
- **PR-C** — `sync-version-refs.sh --check-published` (remote tag-existence
  guard; deadlock-free, not wired into pre-commit).
- **PR-D** — **config-driven reviewer engine**: caller templates drop the
  hardcoded `reviewer: codex`; the reusable falls back `.reviewer // "codex"`;
  `config.json.template` gains `"reviewer"`; onboarding doc documents the
  `.reviewer` ↔ token pairing (CLI + API).
- **PR-E** — onboarding doc: external-adopter `trust_config_repo` override +
  the `auto_merge.repos` requirement + public-path EXPERIMENTAL note.
- **PR-F** — trust-boundary decision record (`DECISIONS.md` CI-0005) +
  **declarative-only config-knob annotation** (a `config.json.template` `_note`
  marking the 8 fields no workflow reads, so consumers don't rely on phantom
  enforcement).
- **PR-G** — `composition.yml` reads the trusted config from the repo's **actual
  default branch** (was hardcoded `?ref=main`), so `master`/`develop` consumers
  are no longer degraded to always-enforce (FT-6 `@main` half; the same
  non-PR-mutable-base safety property holds).

## ci/v1.7.1 — 2026-07-10

> PATCH hotfix (PLAN-005 PR-B / B2). The `ai-review` caller templates shipped
> with **no `permissions:` block**, so on any consumer under the canon `read`
> default (`actions-permissions.json`) the reusable — which requests
> contents/pull-requests/issues `write` — exceeded the caller grant and failed
> at load (`startup_failure`, zero jobs): the ai-review pipeline never ran.

### Fixed

- **`ai-review` caller `startup_failure` on the `read` default** — added a
  top-level `permissions:` block (contents/pull-requests/issues `write`,
  matching the reusable's own scopes) to `ai-review-public.yml` +
  `ai-review-private.yml`; gave the private caller the secrets/`pull_request_target`
  header the public one already had. `actions-permissions.json` is untouched
  (repo default stays `read` — the caller elevates without loosening it).
  Matches the pattern the `auto-merge-ai-prs` caller already ships. Consumers
  pick this up by re-pinning to `@ci/v1.7.1` (or `install.sh --update`).

## ci/v1.7.0 — 2026-07-10

> Cut 2026-07-10: the **PLAN-004 company-default elevation** (slices A–E).
> Bundles everything that accumulated after the `ci/v1.6.0` tag. Non-breaking —
> every slice is additive or byte-identical by default; consumers pinned at
> `@ci/v1.6.0` keep working and pick up the changes when they bump the pin.
> The released back-catalog below (v1.1.0 through v1.6.0) is documented as
> dated `###` sub-sections rather than per-tag `##` headers — promoting it
> needs git-log/tag reconciliation and is tracked as FRAMEWORK-TODO FT-4.

### Added — PLAN-004 company-default elevation, A-series (2026-07-09)

Pre-prod hardening toward the company-default CI standard (per
`plans/PLAN-004_company-default-elevation.md`):

- **VERSION single-source** (`VERSION` file) + `install.sh` tag precedence
  (`CI_TAG` env > VERSION > hardcoded fallback) + `scripts/sync-version-refs.sh`
  (docs + template pins tracked against VERSION; pre-commit-enforced).
- **`sync/check-drift.sh`** per-caller pin comparison (was: highest pin
  across all callers → mid-bump false-drift); template caller pins
  normalized to `@ci/v1.7.0`.
- **Docs**: README + install/README rewritten to reality; `LABELS.md`
  16-label parity; NEW `docs/REVIEWER_APP_ONBOARDING.md` +
  `docs/BRANCH_PROTECTION.md`; `multi-project-guide` §8 + PLAYBOOK fixes;
  `overrides.md` drift-check claim corrected (`diff`-based, param overrides
  ARE flagged) + stale examples reframed; `docs/README.md` 11→12 workflows
  + stale "Planned" section gutted; `local-pre-push.md` §8 (dropped "not yet
  available" + corrected the CI-gate exemption logic — it diverges from the
  local hook for spoof-resistance); `runners.md` external-adopter callout
  (`runner-self`/reference image are operations infra; adopters use
  `ubuntu-latest` or build their own) + `ci/v1.0.1`→`ci/v1.0.2` JIT-install
  consistency.
- **Governance**: HANDOFF refreshed; `DECISIONS.md` CI-0004 (workflow →
  OPS-NNNN delegation table); PLAN-002 → SHIPPED; this CHANGELOG dedup +
  staging header; `plans/FRAMEWORK-TODO.md` (FT-1..FT-4).

PRs #82 (plan) + #83/#84/#85/#86/#87/#88/#89/#90 (A1–A6).

### Fixed / Changed — PLAN-004 B (correctness) + C (security) + D1 (2026-07-09)

- **B (correctness):** `doc-maintainer.yml` schedule bug — reconcile split into
  its own job so cron no longer fires the whole LLM pipeline (#92, + the dedup→cfg
  fall-through); `composition.yml` PR-author resolved via gh-api on the
  workflow_run path (the abbreviated payload omits `.user`) + empty-author
  fail-closed (#93); per-file fork-safety — labeler→`pull_request_target`,
  codeql/secret-scan keep `pull_request` + skip SARIF upload on forks (#94);
  `timeout-minutes` on 12 reusables + apply-standards label `%3A`-encode +
  audit-trail-check fetch diagnostics + troubleshooting §16-18 (#95).
- **C (security):** SHA-pin `checkout` + `create-github-app-token` + npm pin +
  `curl|bash` disposition + `standards-drift` zero default permissions (#96);
  env-var indirection for consumer-input shell interpolation (#97); **BL-3
  auto-merge composition-armed gate** — requires an App-APPROVED-at-HEAD review
  (mirrors composition + skip-ai-review carry-forward) before re-arming, closing
  the hand-applied-label bypass (#98).
- **D1 (BL-2):** parameterize the hardcoded operations trust root via
  `trust_config_repo`/`trust_config_ref` inputs on ai-review + auto-merge
  (defaults byte-identical) so external adopters point at their own config repo
  (#99).
- **D2 (de-brand install templates):** `config.json.template`
  (`${CODEOWNER_HANDLE}`) + `CLAUDE.md.template` (`${CANON_OPERATIONS_URL}`,
  `${CANON_CI_URL}`) parameterized; `install.sh` gains `--codeowner`,
  `--canon-operations-url`, `--canon-ci-url` flags with literal `python3`
  substitution (values passed as argv, never interpolated) + a fail-closed
  post-substitution assertion. Defaults reproduce the pre-D2 templates
  byte-for-byte (round-trip verified). `--codeowner` is validated against
  the GitHub handle grammar before substitution (it lands in the
  `trust.ai_review` security allowlist). REPO_STANDARDS §16.7.
- **FT-7 (CODEOWNERS de-brand):** `CODEOWNERS.template` owner routes
  parameterized to `@${CODEOWNER_HANDLE}`; `install.sh` now installs
  `.github/CODEOWNERS` (substituted, preserve-if-exists). The drift check
  gains `codeowners_check` — it normalizes every `@owner` to a `@OWNER`
  sentinel on both sides before diffing, so it verifies path-routing
  STRUCTURE (canon) and ignores handle IDENTITY (consumer-specific). Existing
  `@vladm3105` consumers keep passing; a de-branded consumer no longer reads
  as permanent drift. Defaults byte-identical. REPO_STANDARDS §7 + §16.7.
- **E (update path + canonical manifest):** new
  `install/templates/manifest.json` — the machine-readable index of every
  `template → consumer-file` mapping (path, template + visibility variants,
  `substitute` placeholders, `safe_to_replace`). New `install.sh --update
  <owner/repo>` mode walks it: re-fetches each already-adopted surface,
  substitutes, diffs vs local, and prompts `[k]eep/[r]eplace/[d]iff-only`;
  `--non-interactive` replaces only `safe_to_replace` files (the mechanical
  workflow files + `dependabot.yml`) and keeps policy/governance files plus the
  consumer-customized `codeql.yml` (atomic replace; absent files skipped;
  idempotent). New `docs/UPDATE_GUIDE.md`.
  REPO_STANDARDS §16.8. The `sync/check-drift.sh` migration onto the manifest
  is tracked as FRAMEWORK-TODO FT-8 (E2).

This release closes PLAN-004 slices A–E. FT-8 (drift-check manifest migration)
is a post-elevation follow-up backlog item.

### Added — REPO_STANDARDS §17 auto-merge canon + canonical caller templates (2026-07-08)

Per founder direction 2026-07-08: codify the two-layer auto-merge
default (native `--auto` in-session + `auto-merge-ai-prs.yml`
server-side) as a workspace canon rule + ship canonical caller
templates so consumers can adopt uniformly.

Changes:

- **`docs/REPO_STANDARDS.md`** — new §17 "Auto-merge for AI-opened
  PRs (two-layer default)" section covering:
  - Layer 1 (§17.1) native `--auto` in-session rule.
  - Layer 2 (§17.2) server-side `auto-merge-ai-prs.yml` reusable +
    template locations (public + private).
  - Prerequisites (§17.3): `auto_merge.repos` allowlist entry;
    reviewer App install; ai-review + composition callers present.
  - Non-goals (§17.4): spec/governance-tier PRs excluded;
    cross-repo coordinated PRs excluded.
  - Origin (§17.5): OPS-0062 in-session rule + IPLAN-0030
    server-side companion.
- **`install/templates/workflows/auto-merge-ai-prs-public.yml`** (NEW)
  — canonical caller for public consumers (ubuntu-latest runners).
- **`install/templates/workflows/auto-merge-ai-prs-private.yml`** (NEW)
  — canonical caller for private consumers (self-hosted
  ci-ephemeral runners).

**4 surfaces** (REPO_STANDARDS + 2 templates + CHANGELOG). Rule 1
compliant.

Rollout: framework + iplan-standard (currently missing the caller)
get the caller in follow-up PRs. interlog is bootstrap-tier without
CI adoption yet; auto-merge lands as part of its full CI adoption.
5 workspace repos already have the caller from prior IPLAN-0030
Phase B rollout (operations, business, iplanic, iplan-runner,
engramory).

Multi-agent self-review per OPS-0065 (code-reviewer single-agent per minimal-scope calibration): skipped — mechanical template addition + REPO_STANDARDS documentation of existing pattern; templates copied from operations canonical caller with runner-labels swap; no logic change

### Added — Canonical source authority disambiguation (REPO_STANDARDS §0 + CLAUDE.md) (2026-07-08)

Per founder direction 2026-07-08: the aidoc-flow workspace has TWO
canonical repos — `aidoc-flow-ci` for CI/canon-workflow/template/script
concerns + `aidoc-flow-operations` for OPS-NNNN business decisions +
multi-agent-review prompt templates + cross-repo playbooks. To avoid
future confusion (consumers citing operations when they should cite
aidoc-flow-ci or vice versa), add an explicit disambiguation table +
rule-of-thumb.

Changes:

- **`docs/REPO_STANDARDS.md`** — new §0 "Canonical source authority
  (disambiguation)" section at the top of the rulebook (before §1
  tier taxonomy). Includes:
  - A 10-row table splitting concerns between aidoc-flow-ci vs.
    aidoc-flow-operations by concern (CI reusable workflows, config
    templates, scripts, governance-file templates, ai-review rubric,
    static-settings rulebook vs. OPS-NNNN decisions, prompt templates,
    cross-repo playbooks, autonomy tiers table).
  - A rule-of-thumb for consumer docs (CI/workflow → aidoc-flow-ci;
    OPS-NNNN business decisions → operations).
  - A historical note explaining pre-2026-06 references to
    "operations canonical templates" (in IPLAN-0014, IPLAN-0017-CHARTER)
    reflect the pre-aidoc-flow-ci layout.
- **`CLAUDE.md`** — expanded `## What this repo is` to explicitly
  enumerate the surfaces this repo ships as canonical, plus a
  disambiguation callout pointing at REPO_STANDARDS §0 for the
  full split.

**2 surfaces** (REPO_STANDARDS + CLAUDE.md) + CHANGELOG. OPS-0061
Rule 1 compliant.

Effect: consumer PR authors, DECISIONS entries, CHANGELOG entries,
and generated content (via ai-review + rubric fetches) get an
unambiguous canonical-source pointer for both concerns. No consumer-
side changes required.

Multi-agent self-review per OPS-0065 (code-reviewer + documentation-specialist parallel dispatch): approved after 1 fold cycle addressing 1 MEDIUM (IPLAN-0017-CHARTER attribution loose — CHARTER is the migration doc, not pre-aidoc-flow-ci; historical note rewritten to distinguish IPLAN-0014 canonical-in-operations from IPLAN-0017-CHARTER migration language; IPLAN-0022 ai-review-vendoring source also called out per code-reviewer) + 6 LOW (scripts/ + install/ path imprecision — expanded to per-script explicit paths; slash-notation in template list — expanded to comma-separated; CLAUDE.md static-settings scope drift — expanded to match §0 row 6; historical note attribution — reworded with line-specific citations; rule-of-thumb omissions — added autonomy tiers + AI-employees registry to operations clause; TBD → filled)

### Changed — ai-review rubric: repo-aware doc-coverage + hash-count discipline (2026-07-08)

Two false-positive classes observed on business `#41` and iplanic `#234`:

1. **Business "missing CHANGELOG" false-positive** — the rubric's
   Doc-coverage rule required CHANGELOG updates on every substantive
   workflow change, but business has NO `CHANGELOG.md` at root by
   explicit policy (its own CLAUDE.md declares DECISIONS + git commits
   as the changelog). The rule shipped as workspace canon but was
   written FOR operations only.
2. **Iplanic "SHA256 is 63 chars" false-positive** — pure Claude
   counting error. The actual value is 64 chars (verified via Python);
   business's Secret scan already passed with the identical checksum.

Rubric changes:

- **`ai-review/review-prompt.md` §"Workspace-canon BLOCK rules"** —
  renamed from `Repo-specific BLOCK rules (operations — docs/governance)`
  to reflect the workspace-canon scope. Added an intro paragraph
  clarifying that path-based rules are gated on the consumer
  actually having the file (so consumers like business that
  self-declare no-CHANGELOG policy are exempt).
- **`ai-review/review-prompt.md` §"Doc-coverage rule"** — added a
  **precondition**: rule DOES NOT APPLY if consumer has no
  `CHANGELOG.md` at repo root. Explicit "do NOT flag
  missing-CHANGELOG" + "do NOT synthesize should-add-CHANGELOG
  recommendation" instructions.
- **`ai-review/review-prompt.md` §"Verification discipline for length
  / count / checksum claims"** (NEW section) — instructs the reviewer
  to recount before flagging quantitative claims about hash lengths,
  character counts, etc. Lists well-known constants (SHA-256 = 64
  hex, SHA-1 = 40, MD5 = 32, UUID = 36/32) to anchor the counting.
  If uncertain after recounting → `low` advisory, not `medium` block.

**2 surfaces** (rubric + this CHANGELOG entry). Rule 1 compliant.

Rollout: effective immediately — consumers fetch the rubric from
`aidoc-flow-ci@<pinned-tag>` per IPLAN-0022, so this fix propagates
once consumers re-run ai-review or bump their pin.

Multi-agent self-review per OPS-0065 (code-reviewer + documentation-specialist parallel dispatch): approved after 1 fold cycle addressing 3 MEDIUM (precondition needs explicit "verify by listing the file" language — both agents; anti-hallucination clause inverted trust ordering ≤2-char diffs defer to constant per docs-specialist; TBD → filled) + 3 LOW (Always-required line scope clarified per both agents; DECISIONS-substitute clause dropped per code-reviewer + docs-specialist; verification scope broadened to non-hash quantitative claims; "substantive" qualifier added to CHANGELOG rationale). No load-bearing risk observed for CHANGELOG-having repos.

### Changed — Parser extract_path handles §N + #anchor section-suffix (2026-07-08)

Per business Wave 2b review: `docs/STARTUP_STRATEGY.md §8` cell in
business's original `## Per-repo governance` table couldn't be resolved
by `extract_path()` — the trailing `§8` section-anchor suffix defeated
the extraction (§8 got treated as part of the path, so the check failed).
Business worked around by moving the §8 note into the Roadmap "Not
adopted" rationale (per PR `#40`). This PR adds parser-side handling so
future consumers can cite section-anchors inline without the workaround.

- **`install/parse-governance-table.py`** — `extract_path()` extended to
  strip trailing section-anchor suffixes: `§N` (e.g. `§8`) and
  `#anchor` (markdown-style, e.g. `#phased-roadmap`). Detection is
  space-delimited (`\s+[§#]\S`) so it does not match paths that happen
  to contain `§` or `#` characters mid-path. Applied BEFORE the
  parenthesized-annotation strip so `` `docs/foo.md` §8 (Phased Roadmap) ``
  correctly resolves to `docs/foo.md`.

**2 surfaces** (parser + this CHANGELOG entry). OPS-0061 Rule 1 compliant.

Unit-tested on 6 cases: bare `§N`; `§N` + parenthesized annotation;
parenthesized-only (regression check); `#anchor`; plain trailing slash;
Not-adopted cell. All pass. Verified on all 9 workspace consumer
CLAUDE.md files — no regression on Wave 0/1/2 adopters (6 consumers
green + 3 pending Wave 3/4).

### Changed — Drop italic separator row from CLAUDE.md canon template + extend parser to accept both italic forms (2026-07-08)

Per ai-review MEDIUM finding on operations Wave 2a `#218` 2026-07-08:
the italic `| _(repo-specific rows below — same table, optional)_ | |`
separator row inside the parseable `## Per-repo governance` table
parses correctly per §4.5 `INFO_SEPARATOR_RE` but reduces
machine-readability for downstream tooling that expects every table
row to carry real Surface/Path data. Update the canon template to omit
the separator row + call out the pattern in the prose above the table.
Also extend the parser regex to accept both underscore-italic (`_..._`)
and asterisk-italic (`*...*`) forms — GFM markdown allows either
interchangeably; the pre-fix parser only matched `_..._`, which
silently DRIFTed framework `#273` (which uses `*...*`).

- **`install/templates/CLAUDE.md.template`** — dropped the italic
  separator row from the example table. Additional-row examples now
  appear directly below the required 6 rows. Prose after the table
  updated to say "every row in the table must carry real Surface/Path
  data — do NOT insert an italic separator row" so downstream Wave
  authors don't reintroduce the pattern.
- **`install/parse-governance-table.py`** — `INFO_SEPARATOR_RE`
  extended to accept `*...*` asterisk-italic form alongside `_..._`
  underscore-italic (both are valid GFM markdown italics; consumers
  may pick either interchangeably). This silently unblocks framework
  `#273` which had `errors: [1] missing-cell: empty` on its
  `*(...)* ` separator row.

**3 surfaces** (template + parser + this CHANGELOG entry). OPS-0061
Rule 1 compliant.

Post-fix parser status on all 4 Wave-adopted repos: `--check` exit 0.
- aidoc-flow-ci CLAUDE.md: 6/6 required + 0 additional + 0 errors.
- framework #273: 6/6 required + 3 additional + 0 errors (previously 1
  error on the `*...*` separator; silently resolved by parser fix).
- iplan-standard #16: 6/6 required + 1 additional + 0 errors.
- operations #218: 6/6 required + 1 additional + 0 errors.

Multi-agent self-review per OPS-0065 (code-reviewer + documentation-specialist parallel dispatch): approved after 1 fold cycle addressing 1 MEDIUM finding — code-reviewer flagged the "framework parses OK" claim as factually wrong; framework was actually DRIFTing due to `*...*` vs `_..._` regex gap. Extended parser to accept both forms + updated CHANGELOG accurately + verified parser green on all 4 Wave-adopted repos.

### Changed — PLAN-003 PR-V4 status flip to SHIPPED + rollout playbook doc (2026-07-08)

Closes the PLAN-003 canon-layer shipment. Per-repo Wave 1-5 rollouts
proceed next per PLAN-003 §5.5 / operations `docs/CROSS_REPO_PLAYBOOKS.md`
§T-D.

- **`plans/PLAN-003_project-governance-canon.md`** — status flipped
  DRAFT → SHIPPED; §9 audit-trail extended with PR-V1/V2/V3/V4 merge
  records (with per-PR fold summaries) + explicit Wave 1-5 next-step
  note.
- **`docs/PLAYBOOK_governance-canon-rollout.md`** (NEW) — canon-source-
  side companion doc mirroring PR-V3's §T-D content. Summary + explicit
  link-back to operations §T-D (authoritative). Serves AI agents +
  operators who enter the workspace via `aidoc-flow-ci/` first and
  don't cross-load `../operations/docs/CROSS_REPO_PLAYBOOKS.md`
  automatically.
- **`HANDOFF.md`** — inline doc-currency update per project rule: post-
  shipment `## Current state` collapsed to "PLAN-003 canon layer
  SHIPPED"; PR-V1/V2/V3/V4 items moved from Open threads to Recent
  decisions; Next-session start-here re-pointed at the playbook doc +
  Wave 1 pickup pointer.
- **`ROADMAP.md`** — inline doc-currency update per project rule:
  PR-V1/V2/V3/V4 moved from `In flight` to `Recently landed`; only
  "Per-repo Wave 1-5 rollouts" remains in flight.

**5 surfaces** — above OPS-0061 Rule 1 ≤3 default; expanded from 3 to 5
after multi-agent review surfaced HANDOFF + ROADMAP staleness (project-
rule "keep docs of record per PR" doc-currency requirement propagates
the status flip inline). Bundle authorized under the doc-currency-rule
reconciliation clause of OPS-0061 (each PR's affected docs update
in-PR — not a separate doc-refresh PR).

Multi-agent self-review per OPS-0065 (documentation-specialist + code-reviewer parallel dispatch): approved after 1 fold cycle addressing 1 CRITICAL (CHANGELOG TBD placeholder → filled) + 3 HIGH (stale HANDOFF post-shipment → rewritten inline; stale ROADMAP post-shipment → rewritten inline; PR-V2 fold-count format inconsistency with PR-V3 → dropped fabricated CRITICAL label to match PR #74 body) + 5 MEDIUM (this PR placeholder observation deferred to post-open fixup; Wave summary column "Delivery mode" → "Scope summary" to match operations §T-D; Wave 3 engramory scope wording aligned to operations §T-D; first §T-D mention anchor added; parallel-dispatch claim scoped accurately) + 2 LOW (canon-plan cleanup deferred; observations)

### Added — PLAN-003 PR-V2 --check-governance parser mode (2026-07-08)

- **`install/parse-governance-table.py`** (NEW, ~250 lines, stdlib-only)
  — Python parser implementing the PLAN-003 §4.5 governance-table
  contract:
  - Anchor regex accepts both bare `## Per-repo governance` and the
    em-dash tail form used by 7 existing workspace consumers.
  - GFM pipe-table with case-insensitive Surface/Path column headers;
    both `|---|---|` and `| --- | --- |` separator forms accepted.
  - Required-row matching by canonical-token substring (handoff, todo/
    backlog, decisions, plans/iplan, changelog, roadmap) — no forced
    label rename.
  - "Not adopted [—-] <rationale>" prefix detected BEFORE any path
    extraction (per §4.5 F#7 fold).
  - Path cells strip surrounding backticks + parenthesized annotation
    before existence check.
  - Additional rows below required 6 verified for existence but not
    counted toward required-row completeness.
  - Multi-value cells rejected (one row per surface per §4.5 F#6 fold).
  - Emits structured JSON per §4.5 diagnostic format.
- **`install/apply-standards.sh`** (MODIFIED) — new `governance_check`
  function extends the drift matrix with a pseudo-path
  `CLAUDE.md#per-repo-governance`. Fires automatically in `--check`,
  `--dry-run`, `--report` modes (skipped for `--apply` per existing
  content-vs-server-side separation). Uses local `parse-governance-
  table.py` when present; falls back to fetching from `raw.
  githubusercontent.com` at the pinned CI_TAG when apply-standards.sh
  itself is invoked via curl-pipe-bash. Emits parser errors under a
  `governance` DRIFT_MODE in emit_human + emit_json.
- **`install/install.sh`** (MODIFIED) — new CLAUDE.md bootstrap step:
  - If consumer has no CLAUDE.md → install the canon template + tell
    the operator to fill placeholders BEFORE commit.
  - If consumer has CLAUDE.md → verify 5 required sections
    (`## What this repo is`, `## Per-repo governance` with em-dash tail
    accepted, `## GitHub operations`, `## Workspace standards`) + print
    merge suggestion. Does NOT auto-modify existing CLAUDE.md
    (session-level content preservation).

**Real-world validation** — parser tested against all 9 non-paused
workspace consumer CLAUDE.md files. Surfaced Wave-rollout gaps
matching PLAN-003 §5.5 expectations exactly:
- aidoc-flow-ci: green (Wave 0 already self-adopted).
- operations, business, framework, iplanic, iplan-runner, engramory:
  drift matching each repo's §5.4c scope.
- iplan-standard: missing `## Per-repo governance` section entirely
  (biggest scope; Wave 1).
- interlog: has section anchor + prose but no canonical table
  (Wave 4 must convert prose to table).

**3 surfaces** (parser + apply-standards + install.sh) + CHANGELOG.
Rule 1 compliant.

Multi-agent self-review per OPS-0065 (code-reviewer + test-engineer + security-auditor parallel dispatch): approved after 1 fold cycle addressing 4 HIGH (template line 32 self-inconsistent with own parser → fixed to `_(repo-specific rows below — same table, optional)_`; path-traversal via absolute + `..` paths → sandbox with `relative_to` + PermissionError-safe; fenced-code-block anchor false positive → fenced-code state tracked; multi-value cell not explicitly rejected → distinct `multi-value-cell` error) + 7 MEDIUM (italic-label swallowed as informational → tightened INFO_SEPARATOR_RE to require empty path cell; "Not adopted --" without rationale → `\w`-based rationale check; parser stderr corrupts JSON → separated fd; install.sh 4-vs-5 section count → added H1 title check; 3-column separator not detected → generalized SEP_ROW_RE to N-column; PermissionError crashes parser → OSError-safe exists; parser diagnostic error phrasing) + 3 LOW (DRIFT_CANONICAL sentinel; observations).

**Real-world post-fold validation** — parser tested against a synthesized malicious CLAUDE.md declaring `/etc/passwd` + `../../../etc/hosts`: both rejected with `path-escape` errors, no filesystem existence leaked. Shipped template validated against own parser: 6/6 required rows + 2 additional rows verified, 0 errors. All 9 workspace consumer parses unchanged from pre-fold baseline.

### Added — PLAN-003 PR-V1 canon templates + Wave 0 self-adoption (2026-07-08)

- **`install/templates/CLAUDE.md.template`** (NEW) — canonical `CLAUDE.md`
  shape per PLAN-003 §4.2 with placeholder markers
  (`<REPO_FRIENDLY_NAME>`, `<REPO_PURPOSE_ONE_LINER>`, etc.). Ships
  the 5 required sections: `## What this repo is`, `## Where things
  are`, `## Per-repo governance`, `## GitHub operations`,
  `## Workspace standards`.
- **`install/templates/HANDOFF.md.template`** (NEW) — minimal live-
  resume-point skeleton with `## Current state`, `## Open threads`,
  `## Next-session start-here`, `## Recent decisions` + maintenance
  protocol.
- **`install/templates/DECISIONS.md.template`** (NEW) — minimal
  append-only decision log with `## <PREFIX>-NNNN: <title>
  (<ISO_DATE>)` format + `**Context**` / `**Decision**` /
  `**Consequences**` / `**Origin**` sub-headers.
- **`install/templates/ROADMAP.md.template`** (NEW) — minimal roadmap
  with `## Current phase`, `## Next phase`, `## Deferred / parked`
  + maintenance protocol.
- **`install/templates/plans-README.md.template`** (NEW) — content
  for consumer `plans/README.md` explaining per-repo plan naming
  convention (PLAN-NNNN default + IPLAN/TPLAN/DPLAN/MPLAN/RPLAN/
  CPLAN/SPLAN scoped prefixes) + verified-planning skill contract.
- **`docs/REPO_STANDARDS.md`** §16 (NEW section) — codifies the
  project governance file canon: 6 required surfaces + additional-
  row pattern + "Not adopted — <rationale>" cell format + template
  references. Includes 6 sub-sections: 16.1 required surfaces, 16.2
  additional rows, 16.3 CLAUDE.md template, 16.4 `--check-governance`
  mode (ships in PR-V2), 16.5 additional file templates, 16.6
  rollout waves.
- **`CLAUDE.md`** (NEW at repo root) — aidoc-flow-ci Wave 0
  self-adoption. This repo previously had NO CLAUDE.md; created from
  the shipped template with canon-source content.
- **`HANDOFF.md`** (NEW at repo root) — aidoc-flow-ci Wave 0
  self-adoption. Live resume point with PLAN-003 PR-V1 state +
  PR-V2/V3/V4 open threads + per-repo Wave 1-5 sequencing.
- **`DECISIONS.md`** (NEW at repo root) — aidoc-flow-ci Wave 0
  self-adoption. Backfilled with 3 initial CI-NNNN entries: CI-0001
  (flexible-canonical Option B), CI-0002 (PR-V1 11-surface bundle),
  CI-0003 (3-cycle review discipline).
- **`ROADMAP.md`** (NEW at repo root) — aidoc-flow-ci Wave 0
  self-adoption. Current phase = PLAN-003 rollout; next phase =
  canon evolution + label sync; deferred items enumerated with
  rationale.

**11-surface bundle** (5 canon templates + 4 self-adoption files +
REPO_STANDARDS §16 + this CHANGELOG entry). Above OPS-0061 Rule 1
≤3 default; authorized per §5.1 pre-PR-V1 gate item #1 (explicit
founder OK 2026-07-08 — "merge PLAN-003 PR-V1 if green") + PLAN-002
§5.4 canon-home dogfood precedent.

**Deviations from PLAN-003 §5.1 sketch** (Pass-7-fold notes):

- DECISIONS.md initial entries ship as CI-0001/0002/0003 covering
  flexible-canonical adoption + PR-V1 11-surface bundle + 3-cycle
  review discipline (PR-V1-native, load-bearing for canon-source),
  in place of the PLAN-002-backfill sketch (`CI-DEC-001/002/003`
  covering PLAN-001 canon establishment / PLAN-002 unification /
  §14 audit-trail). PR-V1-native content is richer for Wave 0 +
  captures decisions actually made by this PR; PLAN-002 history
  remains recoverable from git commit log + PLAN-002 documents.
- DECISIONS.md.template ships 4 sub-headers (`**Context** /
  **Decision** / **Consequences** / **Origin**`) — 1 more than
  PLAN-003 §5.1's 3-sub-header sketch. Added `**Origin**` because
  future readers need it to judge whether the rationale still
  holds (per verified-planning "why" discipline). Enhancement, not
  regression.

Multi-agent self-review per OPS-0065 (code-reviewer + documentation-
specialist, fresh-context adversarial parallel dispatch): approved
after 1 fold cycle addressing 4 HIGH (broken `../aidoc-flow-operations/`
paths across template + self-adoption + plans-README; dead
`scripts/check-standards-drift.sh` ref; self-contradiction with own
`../<repo>/` convention; bold-paragraph section-refs not resolvable to
H2s) + 3 MEDIUM (DECISIONS-vs-sketch divergence, template sub-header
extension, section-refs point at prose) + 5 LOW findings. Also
building on 2 prior fold cycles across PLAN-003 Passes 2-6
(document-level review): final Pass 6 verdict APPROVED with 1
non-blocking MEDIUM advisory (engramory ADR-as-DECISIONS surface,
Wave 3 resolves inline).

### Added — aidoc-flow-ci Wave 0 self-adoption (PR-U4 of PLAN-002) (2026-07-08)

- **`scripts/pre_push_check.sh`** (NEW) — canon self-review script
  installed on aidoc-flow-ci itself (byte-copy from
  `install/templates/pre_push_check.sh`; `chmod +x`).
- **`.pre-commit-config.yaml`** (NEW) — canon fragment installed
  verbatim (has the `# CANON: aidoc-flow-ci pre_push_check` marker at
  line 1 so future `install.sh` re-runs no-op).
- **`.github/CODEOWNERS`** (NEW) — canon shape per REPO_STANDARDS.md
  §7 (single-owner phase; all patterns route to `@vladm3105`).
- **`.github/pull_request_template.md`** (NEW) — canon PR template
  per REPO_STANDARDS.md §8 (Summary + Files-touched Rule 1
  self-check + Multi-agent self-review + Cross-refs + tier-guarded
  test plan).
- **`.github/dependabot.yml`** (NEW) — canon shape per
  REPO_STANDARDS.md §6, full canon (all 5 ecosystems). Dependabot
  silently skips ecosystems with no matching manifests
  (aidoc-flow-ci has only `github-actions`), so keeping the full
  canon costs nothing and preserves exact-match parity for
  `apply-standards.sh --check`.
- **`.gitignore`** (edit) — merged canon baseline lines from
  `install/templates/.gitignore.template` (subset semantics per
  apply-standards.sh subset_check).
- **`.gitattributes`** (NEW) — canon baseline installed.
- **`.github/workflows/audit-trail.yml`** (NEW) — consumer caller of
  PR-U3's `audit-trail-check.yml` reusable, pinned at `ci/v1.6.0`.
  First self-CI wired on aidoc-flow-ci — check-name renders as
  `call / verify` (matches `call / ai-review` + `call / composition`
  convention). Adds mechanical OPS-0069 audit-trail enforcement to
  every PR on this repo. Server-side integration (adding
  `call / verify` to branch-protection `contexts` on `main`) is a
  follow-up founder-run `apply-standards.sh --apply` step per
  REPO_STANDARDS.md §14.3.
- **`.github/workflows/standards-drift.yml`** (NEW) — weekly
  `schedule: cron` self-drift-check running
  `bash sync/check-standards-drift.sh --tier product`. Canon home
  self-drift-checks — satisfies PLAN-002 §7 success criterion #4
  (F1 fold from documentation-specialist review). Warning-only per
  canon §3.1b (script always exits 0).
- **Resolves the bootstrap paradox** (PLAN-002 §4.7 M4 fix): every
  subsequent PR on aidoc-flow-ci (Wave 1–5 rollout PRs included)
  flows through the same self-review gate.
- **Post-merge negative-test evidence** — the PLAN-002 §5.4 M7 fold
  negative test (commit-without-phrase → local hook rejects; `--no-
  verify` → CI check fails; add phrase → both pass) will be executed
  on a scratch branch AFTER this PR merges (self-CI caller only
  becomes active post-merge). Result attached as a comment on this
  PR body.
- **Multi-agent self-review per OPS-0065 (documentation-specialist):**
  APPROVED verdict cycle 1 (all 6 exact-match surfaces byte-identical
  to canon; .gitignore proper superset; caller wired correctly at
  ci/v1.6.0 tag; bootstrap-paradox chain fully closed). 4
  non-blocking follow-ups — all folded: F1 (standards-drift.yml
  weekly cron caller added — canon home self-drift-check); F2 (plan
  text §5.4 corrected — filename `audit-trail.yml` not
  `audit-trail-check.yml` to avoid same-repo collision with the
  PR-U3 reusable); F3 (plan text §5.4 corrected — ship FULL canon
  dependabot.yml, not trimmed, because `exact_match_check` would
  otherwise leave consumers permanently DRIFT); F4 (plan text §5.4
  corrected — `.gitattributes` NEW, not edit).
- **Origin:** PLAN-002 §5.4 PR-U4. Wave 1 (governance tier —
  framework + iplan-standard) follows.

### Changed — install.sh default `CI_TAG` bumped to `ci/v1.6.0` (post-release-cut) (2026-07-08)

- **`install/install.sh`** — default `CI_TAG` bumped from `main` →
  `ci/v1.6.0` (the tag cut immediately after PR-U3 merged). Fulfills
  the release-cut checklist bullet added in PR-U2 CHANGELOG. Consumers
  who don't set `CI_TAG` explicitly now get a frozen tag instead of the
  moving `main` ref. Comment updated to describe the general release-
  cut cadence (bump on each tag) rather than the one-time M4 fold
  history.

### Added — CI reusable `audit-trail-check.yml` + `skip-audit-trail` canon label + WORKFLOWS.md registry (PR-U3 of PLAN-002) (2026-07-08)

- **`.github/workflows/audit-trail-check.yml`** (NEW reusable) —
  belt-and-suspenders CI check that mirrors the PR-U1 local pre-push
  hook's OPS-0069 audit-trail phrase check. `workflow_call` reusable
  same pattern as `ai-review.yml` / `composition.yml`. Consumer callers
  use `jobs.call:` → canonical check-name = **`call / verify`** (matches
  `call / ai-review` + `call / composition` convention).
- **Range:** `${{ github.event.pull_request.base.sha
  }}..${{ github.event.pull_request.head.sha }}` on `pull_request`
  events. **`fetch-depth: 0`** on checkout — LOAD-BEARING: default
  depth-1 checkout on fork PRs yields `base_sha` unreachable →
  `git log base_sha..head_sha` returns empty → check falsely PASSES.
  Fixed in canon per PLAN-002 §4.3 M6 fold.
- **Exemption logic** (identical to local hook per PLAN-002 §4.6 to
  avoid gate mismatch):
  1. ALL commits authored by `dependabot[bot]` / `renovate[bot]` /
     `github-actions[bot]` → SKIPS (with `::notice::`).
  2. ALL commits with subject starting with `Revert "` → SKIPS.
  3. **CI-side-only two-signal override:** PR has `skip-audit-trail`
     label AND at least one commit body contains `[skip-audit-trail]`
     → SKIPS. Half-signal (only label or only body marker) emits a
     `::warning::` to flag the operator's intent.
- **Push events NOT covered** — direct pushes to protected branches
  require `--admin` bypass and are governed by OPS-0062; local
  pre-push hook is the enforcement point for direct-push case.
- **`install/templates/labels.json`** (edit) — new `skip-audit-trail`
  label (`color: d876e3`) added per PLAN-002 §5.3 M4 fold. Applied to
  consumer repos via `install.sh` during initial bootstrap.
- **`docs/WORKFLOWS.md`** — three sub-section updates in one PR (M5
  precedent from PR-U2):
  - §1 catalog: new row 12 for `audit-trail-check.yml`.
  - §2 per-repo matrix: new `audit-trail` column with per-repo Wave
    assignment aligned to PLAN-002 §5.5 (Wave 0 aidoc-flow-ci
    self-adoption via PR-U4; Wave 1 governance; Wave 2 ops-private;
    Wave 3 product; Wave 4 bootstrap = local hook only; Wave 5
    umbrella = advisory only).
  - §3 skip guidance: new §3.10 documenting bootstrap + paused + umbrella
    carveouts.
- **Tag pin:** ships as MINOR bump `ci/v1.6.0` per PLAN-002 §5.3
  (additive reusable; current tip is `ci/v1.5.1`).
- **Multi-agent self-review per OPS-0065 (code-reviewer + security-
  auditor in parallel):** REVISIONS-NEEDED cycle 1, 10 findings
  (2 code-M + 1 sec-CRITICAL + 1 sec-HIGH + 2 sec-MED + 3 sec-LOW +
  1 defense-in-depth). All BLOCKING findings folded:
  - **code-M1** (fail-loud `git cat-file -e` guard on unreachable
    `BASE_SHA`/`HEAD_SHA` after fetch — closes silent-PASS gap;
    mirrors composition.yml fail-closed pattern).
  - **code-M2** (WORKFLOWS.md §2 stale prose "11 workflows" → "12
    workflows").
  - **sec-F1 CRITICAL** — commit-author-spoofing bot-exemption
    BYPASS. `git log --format=%an` is attacker-controllable on fork
    PRs (attacker sets `git config user.name='dependabot[bot]'` →
    check SKIPS without phrase). **FIX**: bot exemption now uses
    GitHub-authoritative `pull_request.user.type == 'Bot'` +
    `pull_request.user.login` allowlist (dependabot / renovate /
    github-actions). Local hook keeps `%an` by design (author
    discipline, not authorization). Intentional CI/local divergence
    documented in REPO_STANDARDS.md §14.2 + PLAN-002 §4.6.
  - **sec-F2 HIGH** — revert-exemption BYPASS via subject spoofing.
    `Revert "` prefix is trivially spoofable + unverifiable. **FIX**:
    revert exemption REMOVED CI-side. Local hook keeps it for
    developer convenience.
  - **sec-F3 MEDIUM** — silent PASS on empty commit range. **FIX**:
    fail-closed via `git rev-list --count "$RANGE" == 0` → exit 1
    (PR with 0 commits shouldn't merge).
  - **sec-F4 MEDIUM** — silent PASS on non-PR events. **FIX**:
    job-level `if: github.event_name == 'pull_request' ||
    'pull_request_target'` guard.
  - **sec-F5** — `set -euo pipefail` (was `-uo pipefail`) so
    unexpected git failures halt loudly.
  - **sec-F6** — `jq -e 'index("skip-audit-trail") != null'` for
    exact label array membership (no substring false-positive on
    labels like `skip-audit-trail-later`); regex fallback if jq
    absent.
  - **sec-F7** — obviated by F1 fix (author strings no longer printed
    to logs).
  - **sec-F8 (D-i-D, DEFERRED)** — signature verification `git log
    --format=%G?` for bot-exempted commits. F1's `user.type == 'Bot'`
    check is the primary protection; commit-signature enforcement can
    add later as belt-and-suspenders.
- **Origin:** PLAN-002 §5.3 PR-U3. PR-U4 (aidoc-flow-ci self-adoption)
  + Wave 0–5 rollout follow.

### Changed — install.sh + apply-standards.sh coverage for self-review canon (PR-U2 of PLAN-002) (2026-07-08)

- **`install/install.sh`** — extended to install the PR-U1 canon
  surfaces during initial consumer bootstrap:
  - `scripts/pre_push_check.sh` — fetch from canon templates + `chmod
    +x`; preserve if consumer already has one (advises drift check).
  - `.pre-commit-config.yaml` — idempotent merge per PLAN-002 §5.2 M5
    fix:
    - No existing file → `cp` canon fragment verbatim.
    - Existing file with `# CANON: aidoc-flow-ci pre_push_check`
      marker → no-op.
    - Existing file without marker → Python `yaml.safe_load` merge:
      `default_install_hook_types` root key upgraded (adds `pre-push`
      if consumer had only `[pre-commit]`); canon `repos` entries
      appended (dedup by structural equality); marker comment written
      at top so future re-runs no-op.
- **`install/apply-standards.sh`** — 2 new surfaces added to the
  `--check` / `--dry-run` / `--report` drift matrix:
  - `scripts/pre_push_check.sh` — `exact_match_check` (canon-owned
    script; consumer variations = drift).
  - `.pre-commit-config.yaml` — `subset_check` (canon fragment lines
    must all be present; consumer extensions preserved).
  - Both new surfaces added to `emit_human` + `emit_json` path arrays.
  - `subset_check` grep gains `--` end-of-options guard so canon lines
    starting with `-` (e.g., `- pre-commit`, `- pre-push`) don't
    misparse as grep flags.
- **`install/templates/pre-commit-hook-block.yaml`** (edit) — canon
  fragment reformatted from inline to block-style YAML (`[pre-commit,
  pre-push]` → separate `-` items) so `subset_check` line-by-line
  comparison matches the `yaml.safe_dump` block output produced by
  `install.sh` merge.
- **`--apply` scope decision (small plan clarification):** file-surface
  installation stays in `install.sh` (initial adoption path); `--apply`
  mode remains server-side-only (labels + repo-settings + actions-
  permissions + branch-protection via `gh api`). Per-repo file drift is
  corrected via per-repo compliance PR (Wave 0–5 rollout per PLAN-002
  §5.5). PLAN-002 §5.2 wording adjusted to match.
- **Release-cut coupling:** `install.sh` default `CI_TAG` bumped from
  `ci/v1.0.6` → `main` (new canon templates live only on `main` until
  the next tag cut). At `ci/v1.6.0` release-cut, bump the default to
  `ci/v1.6.0` (frozen).
- **Multi-agent self-review per OPS-0065 (code-reviewer):** REVISIONS-
  NEEDED cycle 1, 7 findings — ALL folded. M1 (comment preservation:
  ruamel.yaml preferred with round-trip; PyYAML fallback prints WARN
  about comment stripping); M2 (fail-fast yaml-lib pre-check before
  entering merge — actionable pip-install hint); M3 (`mktemp
  ./.pre-commit-config.yaml.tmp.XXXXXX` in target directory so `mv` is
  atomic rename(2), not cross-fs copy+unlink); M4 (`CI_TAG` default
  bumped `ci/v1.0.6` → `main` to unstick the block-style-template
  coupling; usage example updated to `ci/v1.6.0`); L1 (scalar
  `default_install_hook_types` preserved as list element rather than
  reset — `commit-msg` scalar becomes `[commit-msg, pre-commit,
  pre-push]`); L2 (script-branded error if `scripts` exists as a file);
  L3 (WARN if existing `scripts/pre_push_check.sh` isn't executable —
  pre-commit's `language: script` needs `+x`).
- **Origin:** PLAN-002 §5.2 PR-U2. PR-U3 (CI reusable
  `audit-trail-check.yml` + `skip-audit-trail` label + `WORKFLOWS.md`
  registry) + PR-U4 (aidoc-flow-ci self-adoption) follow.

### Added — Self-review canon script + REPO_STANDARDS.md §14 (PR-U1 of PLAN-002) (2026-07-08)

- **`install/templates/pre_push_check.sh`** (NEW) — canonical bash pre-push
  script per PLAN-002 §4.1. Runs 5 checks: `markdownlint`, `yamllint`,
  `actionlint`, `shellcheck` (all skipped-with-notice if absent) +
  OPS-0069 audit-trail phrase check (mandatory). Preserves reference-
  impl defensive patterns: `set -uo pipefail` (rc accumulator +
  non-fatal per-check failures); `git rev-parse --verify --quiet
  @{upstream}` upstream detection; fallback to `origin/main..HEAD` on
  first push; detailed error message with recovery steps. NO env-var
  opt-out (matches OPS-0069 removal of `SKIP_LOCAL_AI_REVIEW`).
- **`install/templates/pre-commit-hook-block.yaml`** (NEW) — canonical
  `.pre-commit-config.yaml` fragment for consumer wiring per PLAN-002
  §4.2. Sets `default_install_hook_types: [pre-commit, pre-push]` +
  local hook block invoking `scripts/pre_push_check.sh`. Idempotency
  marker `# CANON: aidoc-flow-ci pre_push_check` for merge safety per
  PLAN-002 §5.2 M5 fix.
- **`docs/REPO_STANDARDS.md`** — three amendments (atomic doc suite per
  PLAN-002 §5.1):
  - §14 (NEW) — self-review mechanical enforcement. §14.1 local hook
    scope + wiring; §14.2 CI belt-and-suspenders (`call / verify`
    reusable; range `base_sha..head_sha`; `fetch-depth: 0`; exemption
    logic for bot commits + `Revert "` + two-signal
    `skip-audit-trail`); §14.3 per-tier applicability matrix.
  - §2 (edit) — `call / verify` added to required `contexts` for
    governance, product-code, and ops-private tiers. Umbrella excepted
    (canon `required_status_checks: null` preserved; runs advisory);
    bootstrap excepted (deferred to CI adoption per §14.3).
  - §12 (edit) — new compliance-evidence row for self-review mechanical
    enforcement.
- **`docs/local-pre-push.md`** — full rewrite (PR-U1 H8 fix). Drops the
  pre-OPS-0069 `SKIP_LOCAL_AI_REVIEW` env-var pattern and the `claude`
  CLI local-single-pass model. New §1-9 documents the 5-check canon +
  optional consumer wrapper for repo-specific extras + prerequisites +
  invocation + failure modes + CI belt-and-suspenders + cross-refs.
- **`docs/README.md`** — index entry for `local-pre-push.md` updated
  from `claude` CLI wording to bash-only canon description (H8 fix —
  index-summary parity with the local-pre-push.md rewrite).
- **Origin:** PLAN-002 §5.1 PR-U1 (`plans/PLAN-002_workspace-standards-
  rollout.md`). PR-U2 (installer + apply-standards.sh coverage) +
  PR-U3 (CI `audit-trail-check.yml` reusable + labels + WORKFLOWS.md) +
  PR-U4 (aidoc-flow-ci self-adoption) follow.

### Added — apply-standards.sh `--apply` + check-standards-drift.sh (PR-C2 of PLAN-001) (2026-07-07)

- **`install/apply-standards.sh`** — `--apply` mode implemented.
  Mutates a target repo's server-side settings from PR-C1's canon
  templates. Preconditions (fail-fast, exit 2):
  - `--repo <owner/repo>` required, tightly validated (owner:
    `[A-Za-z0-9][A-Za-z0-9-]{0,38}`, repo:
    `[A-Za-z0-9._][A-Za-z0-9._-]{0,99}`, no `..`).
  - `--tier <name>` required, one of `governance|product|ops|umbrella|
    bootstrap`.
  - `gh` CLI in PATH + authenticated.
  - `jq` in PATH (used to strip `_`-prefix metadata from canon
    templates per PR-C1 contract).
  - Interactive confirmation unless `--yes`. Non-TTY invocations
    require `--yes` (fail-fast, not silent-decline).
  - `--apply` refuses `CI_TAG=main` (mutable canon = supply-chain
    risk) unless `--allow-main-canon` is explicitly passed.
- **Apply order** (safest → highest blast radius, per PLAN-001 §6 risk
  mitigation): labels → repo-settings → actions-permissions →
  branch-protection.
- **Backup** — before any mutation, `--apply` snapshots the current
  server state to `install/backups/<sanitized-repo>-<UTC-ts>-<pid>.json`
  (labels [paginated] + repo settings + ALL 4 actions-permissions
  sub-endpoints + branch-protection on the target's actual default
  branch). Files written with `umask 077` (mode 600). Written to
  `install/backups/` which is .gitignored. Backup captures raw GET
  responses which do NOT round-trip via naive PUT (GET vs PUT shape
  mismatch on `restrictions` etc.); documented in confirmation
  banner as a REFERENCE for manual/UI restore.
- **Per-section skip flags** — `--skip-labels`, `--skip-repo-settings`,
  `--skip-actions`, `--skip-branch-protection` for granular application.
- **Actions permissions handling** — iterates the 4-endpoint MULTI-
  ENDPOINT SPEC from `actions-permissions.json`. `_endpoint` validated
  (must be `PUT /repos/{owner}/{repo}/...`) and post-substitution path
  is enforced to stay repo-scoped (prevents hostile canon pivoting to
  `/orgs/...`). `access` endpoint skipped only on visibility=public
  (verified endpoint returns 422 there); applied on private + internal.
  Fork-PR toggles emit an explicit SECURITY WARNING naming the
  consequence (write tokens + secrets exposure) — no REST endpoint
  as of 2026-07; founder resolves in Settings UI.
- **Default-branch discovery** — apply + drift-check use the target's
  actual `default_branch` via `gh api repos/${REPO}`; no hardcoded
  `main`.
- **Exit codes**: `0` success, `1` drift (--check only), `2` usage
  error (preconditions), `3` canon fetch failed, `4` mutation or
  backup error (partial state possible — check backup file), `5`
  cancelled by user.
- **`sync/check-standards-drift.sh`** (NEW) — warning-only companion
  to `sync/check-drift.sh`. Compares live server-side state against
  canon templates for the specified tier via `gh api`. Emits
  `::warning::` per drift; ALWAYS exits 0 (never blocks CI, mirrors
  IPLAN-0017 §3.1b drift-warning contract). Checks: branch-protection
  key subsets (enforce_admins, signatures, force-push, deletion,
  contexts set-equality) on the target's default_branch;
  repo-settings (merge/cleanup toggles); actions-permissions across
  ALL 4 sub-endpoints (general.allowed_actions,
  workflow.default_workflow_permissions,
  selected_actions.{github_owned,verified}_allowed,
  access.access_level on private/internal); canon-label presence.
  Cannot-check paths (API failure, token scope, canon fetch) emit
  explicit `::warning::` + increment a separate fetch-error counter;
  the final summary reports both `$DRIFT drift, $FETCH_ERRORS
  fetch/scope error(s)` so CI operators cannot mistake "silent skip"
  for "green".
- **Backward compatibility** — PR-B2's `--check` / `--dry-run` /
  `--report` behavior unchanged; smoke tests re-verified. File-surface
  checks (CODEOWNERS, PR template, dependabot.yml, .gitignore,
  .gitattributes) still local-checkout; `--apply` is server-side only.
  Content-surface FILES ship via normal PR flow per PLAN-001 §5.4.
- **`.gitignore`** — `install/backups/` added; backup files contain
  private-repo metadata that must not enter git.
- **Origin:** PLAN-001 §5.3 (`plans/PLAN-001_repo-standards-canon.md`).
  Closes out PLAN-001's canonical enforcement layer. Per-repo rollout
  PRs (T-C coordinated-merge-window pattern) follow, out-of-plan.
  Automated `--rollback` deferred to a follow-up (backup shape is
  currently reference-only; the raw GET responses don't round-trip
  via naive PUT).

### Added — Server-side canon templates (PR-C1 of PLAN-001) (2026-07-07)

- **`install/templates/branch-protection-governance.json`** (NEW) —
  1-human approving review + CODEOWNERS + status checks: ai-review,
  composition, hooks (canon §2, governance profile).
- **`install/templates/branch-protection-product.json`** (NEW) —
  0-approving reviews (ai-review + composition ARE the gate) + status
  checks: ai-review, composition, hooks, secret-scan.
- **`install/templates/branch-protection-ops.json`** (NEW) — same
  profile as product, tier-specific note re: private (no fork risk).
- **`install/templates/branch-protection-umbrella.json`** (NEW) — no
  required status checks (submodule-pointer only) + `required_signatures:
  true` + `enforce_admins: false` (`--admin` merge IS the intended bypass
  per OPS-0062).
- **`install/templates/branch-protection-bootstrap.json`** (NEW) — only
  `Lint / format / security hooks` required; ai-review + composition
  opt-in per REPO_ONBOARDING.md until bootstrap repo joins CI-consumer
  set (then migrate to product profile).
- **`install/templates/actions-permissions.json`** (NEW) — canon §4.
  `default_workflow_permissions: read` + selected-actions allowlist
  (`vladm3105/aidoc-flow-ci/*`, `actions/*`, `github/*`) + fork-PR
  workflows require approval for first-time contributors. Multi-endpoint
  spec (general / selected-actions / workflow / access). Two fork-PR
  toggles (write tokens + secrets) live in Settings UI — not yet REST-
  exposed by GitHub; documented as v2.
- **`install/templates/repo-settings.json`** (NEW) — canon §9. Squash-
  only + delete-on-merge + auto-merge enabled + squash-title=PR_TITLE +
  squash-message=PR_BODY. Rebase-merge DISABLED (verdicts anchor to PR
  HEAD SHA — canon §9 rationale).
- **`install/templates/labels.json`** — extended to canon §5.1 + §5.2
  taxonomy. 4 required state labels + `ai:autofix-applied` + 8 canonical
  diff-class labels (`governance`, `docs`, `workflows`, `scripts`,
  `agents`, `tests`, `config`, `plans`) aligned with OPS-0065 `diff-
  class-map.json` + 2 area labels (`dependencies`, `security`). Dropped
  pre-canon labels from the template: `area: ci`, `area: governance`,
  `area: deps`, `area: tests` (superseded by canon §5.2 no-prefix
  `workflows`, `governance`, `config`, `tests` respectively). Consumer
  repos migrating from pre-canon retain their old labels — apply-
  standards.sh --apply never deletes labels; migration is manual per
  repo.
- **Consumed by:** `install/apply-standards.sh --apply` (PR-C2). This
  PR ships the templates (read-only, no code); PR-C2 ships the mutation
  code.
- **Origin:** PLAN-001 §5.3 (`plans/PLAN-001_repo-standards-canon.md`).
  Bundled as atomic enforcement suite per §5.3 (founder OK).

### Added — apply-standards.sh check/dry-run/report (PR-B2 of PLAN-001) (2026-07-07)

- **`install/apply-standards.sh`** (NEW) — compares a consumer repo's
  content-surface files against the canon templates shipped in PR-B1.
  Three non-mutating modes:
  - `--check` — drift check, exit 1 on any drift or MISSING, quiet on green.
  - `--dry-run` (default) — preview what `--apply` would do.
  - `--report` — emit JSON compliance report (`{repo, ci_tag, summary,
    surfaces}`) for machine consumption (e.g., rollup dashboards).
  - `--apply` — RESERVED; errors "reserved for PR-C". Server-side
    mutations require F5 blast-radius per REPO_ONBOARDING.md.
- **Surfaces checked in PR-B2:** `.github/CODEOWNERS`,
  `.github/pull_request_template.md`, `.github/dependabot.yml`
  (exact-match); `.gitignore`, `.gitattributes` (subset — canon lines
  must all be present, consumer extensions preserved).
- **Canon fetch pattern:** reuses `sync/check-drift.sh` approach —
  reads the pinned `@ci/vX.Y.Z` tag from the consumer's workflow
  files, fetches canon templates from
  `raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${CI_TAG}/install/templates/`.
  Override via `--ci-tag <tag>` or `CI_TAG=` env var.
- **Labels + server-side settings** (branch protection, security config,
  Actions permissions, extended labels aligned to OPS-0065 diff-class
  taxonomy) — deferred to PR-C.
- **Origin:** PLAN-001 §5.2 (`plans/PLAN-001_repo-standards-canon.md`).
  PR-B1 (content-surface templates) already merged. PR-C (server-side
  templates + `--apply` mode + `sync/check-standards-drift.sh` warning-
  only drift check) follows.

### Fixed — `sync/check-drift.sh` picked lowest semver pin, not highest (2026-07-07)

- Mixed-pin repos (mid-migration between two `@ci/vX.Y.Z` values)
  produced a false canon-fetch failure because `sort -u | head -1` is
  ASCII-lexicographic and picked the OLDER pin. Fixed to `sort -Vu |
  tail -1` (highest semver). Same bug fixed in `install/apply-
  standards.sh` before ship (bundled into PR-B2 to keep the fix
  atomic across both consumer entry points).

### Added — Content-surface templates (PR-B1 of PLAN-001) (2026-07-07)

- **`install/templates/CODEOWNERS.template`** (NEW) — canonical
  CODEOWNERS shape per REPO_STANDARDS.md §7. Single-owner phase
  (`@vladm3105`); v2 fans out per-domain reviewers.
- **`install/templates/pull_request_template.md`** (NEW) — canonical
  PR template per REPO_STANDARDS.md §8. Sections: Summary, Files
  touched (Rule 1 self-check), Multi-agent self-review
  (OPS-0065/0069 reminder that audit-trail phrase belongs in COMMIT
  message not PR body), Cross-references, Test plan.
- **`install/templates/dependabot.yml`** (NEW) — canonical
  multi-ecosystem shape per REPO_STANDARDS.md §6.
  `github-actions` + `pip` + `npm` + `docker` + `gitsubmodule`
  (umbrella only), weekly Monday cadence, grouped patch/minor.
- **`install/templates/.gitignore.template`** (NEW) — workspace
  baseline per REPO_STANDARDS.md §10.1. `.claude/`, `.review/`,
  `tmp/`, `.env*` (with `.env.example` allow-listed), Python cache,
  Node, OS/editor artifacts.
- **`install/templates/.gitattributes.template`** (NEW) —
  workspace baseline per REPO_STANDARDS.md §10.2. Enforces LF line
  endings + binary marker for common non-text file types.
- **Origin:** PLAN-001 §5.2 (`plans/PLAN-001_repo-standards-canon.md`).
  Bundled as atomic template-suite per §5.2 "atomic template-suite
  adoption" bundle option (founder OK). `install/apply-standards.sh`
  ships in PR-B2. Server-side settings templates + drift check ship
  in PR-C.

### Added — Repo standards canon (PR-A of PLAN-001) (2026-07-07)

- **`docs/REPO_STANDARDS.md`** (NEW) — the static-settings rulebook for
  every workspace repo. Companion to `WORKFLOWS.md` (workflow-side) and
  `aidoc-flow-operations/docs/REPO_ONBOARDING.md` (CI activation).
  Contents:
  - **6-tier taxonomy** — governance / product code / ops-private /
    umbrella / bootstrap / paused. Tier drives per-repo profile.
  - **Per-tier profiles** for: branch protection, GitHub security
    settings, Actions permissions, labels, dependabot, CODEOWNERS,
    PR template, merge/cleanup settings, `.gitignore` /
    `.gitattributes` baselines.
  - **Canonical label taxonomy** — 4 required state labels + 8
    diff-class labels aligned with OPS-0065 diff-class dispatch table.
  - **Rollout order** — via `operations/docs/CROSS_REPO_PLAYBOOKS.md`
    §T-C coordinated-merge-window pattern.
  - **Compliance-evidence table** — where each rule's audit-trail
    lives.
- **`docs/README.md`** — index entry.
- **Origin:** PLAN-001 §5.1 (`plans/PLAN-001_repo-standards-canon.md`).
  PR-B (templates + `apply-standards.sh`) + PR-C (mechanical
  enforcement + drift check) follow.

### Changed — Registry audit against actual repo state (2026-07-07)

- **`docs/WORKFLOWS.md`** — audited the per-repo applicability matrix
  against actual `.github/workflows/` state via
  `gh api repos/vladm3105/*/contents/.github/workflows` across every
  workspace repo. Prior version conflated "should adopt" and "actually
  adopted" (both marked ✅). New cell taxonomy: `✅ / ⚠️ GAP /
  🕳 custom / ⏸ / N/A`.
- **Findings surfaced by the audit:**
  - **Critical gap #1:** `iplan-runner` is missing `composition.yml`
    — ai-review verdict announced but not composed as a required
    check. Should adopt.
  - **Critical gap #2:** `aidoc-flow-engramory` is missing
    `pre-commit.yml` — hygiene not enforced in CI. Should adopt.
  - **Near-universal gaps:** `secret-scan.yml`, `markdown-lint.yml`,
    `links.yml`, `labeler.yml` missing from most repos.
  - **Custom → reusable migration candidates:** operations
    `security.yml` + `docs-lint.yml`; iplan-runner `security.yml` —
    could migrate to reusables for consistency + drift detection.
  - **Bootstrap-tier:** `aidoc-flow-interlog` (created 2026-07-06)
    added to matrix with all-GAP row; first CI PR pending.
- Registry §2.1 added as actionable gap summary; §2.2 flags
  bootstrap-tier repos.
- **CHANGELOG.md** — this entry.

### Added — Workflow registry doc (2026-07-06)

- **`docs/WORKFLOWS.md`** (NEW) — canonical enumeration of all 11
  reusable workflows shipped by this library. Source-of-truth for
  CI-library capabilities. Includes:
  - Complete catalog (11 workflows) with purpose, runtime, origin.
  - Per-repo applicability matrix — rows = workspace repos, columns =
    workflows, cell values = ✅ adopt / ⏸ skip (with rationale) /
    N/A. Covers 9 active repos + 2 paused per founder direction.
  - Per-workflow skip guidance (when NOT to adopt).
  - Adoption sequencing for new workspace repos (9-step order).
  - Current pin state + drift detection.
- **`docs/README.md`** — index entry added for the new registry doc.
- **`docs/architecture.md`** — corrected stale "9 shared workflows"
  count to 11 (had gone stale as auto-merge-ai-prs.yml + pre-commit.yml
  landed post-original-doc); pointer to WORKFLOWS.md for the per-repo
  applicability matrix. Also corrected stale "the 7 shared workflows"
  cross-reference in `docs/README.md` index row (the earlier 7→9
  correction in `ci/v1.4.0` had not propagated to the index).
- **Origin:** founder direction 2026-07-06 — every workflow should
  appear in a full list; some apply per-repo, some are skippable;
  the list should be complete. Registry is that authoritative list.

### Fixed — ci/v1.5.1: `timeout-minutes: 10` on `auto-merge-ai-prs.yml` enforce job (2026-07-05)

- **`.github/workflows/auto-merge-ai-prs.yml`** — added
  `timeout-minutes: 10` on the `enforce:` job. If the self-hosted
  runner pool is drained or offline, GHA's default 6h queue timeout
  would silently hang the job; the reusable's actual work is ≤5s per
  step so 10 min is a generous cap that surfaces runner-unavailability
  as an error rather than an infinite QUEUED. Caller (thin `uses:`
  job) cannot set this per GHA constraint on reusable-caller jobs.
- **Origin:** silent-failure-hunter MEDIUM finding on operations
  PR #203 (IPLAN-0030 P3 caller). Not fixable at caller level;
  requires the reusable-side fix shipped here.
- **Consumer action:** consumers pinning `@ci/v1.5.0` can bump to
  `@ci/v1.5.1` at their next convenient PR. No behavior change beyond
  the timeout — the reusable's contract (inputs, outputs, secrets,
  permissions) is unchanged.

### Added — ci/v1.5.0: NEW reusable `auto-merge-ai-prs.yml` server-side enforcer (IPLAN-0030 P1; OPS-0062 deferred companion) (2026-06-30)

- **`.github/workflows/auto-merge-ai-prs.yml`** (NEW, ~165 lines) —
  reusable workflow that re-arms `gh pr merge --auto --merge` on PRs
  that are green + `ai:review-passed` + in `auto_merge.repos` allowlist
  but where auto-merge was NEVER ARMED (the `autoMergeRequest is null`
  filter; cases 1+2 per IPLAN-0030 §1 narrow scope). Triggered per-
  consumer by `workflow_run` (chains off ai-review + composition
  completion) + `workflow_dispatch` (operator manual recovery). Mints
  the existing reviewer App's installation token (same identity that
  `ai-review.yml:703` uses) so merge-commit-author stays App-attributed
  → preserves push-triggered consumer-workflow firing (ci/v1.1.6
  anti-recursion fix).
- **Inputs/secrets contract:**
  - `inputs.pr_number` (string, optional, default "") — forwarded by
    caller's `with:` block from `github.event.workflow_run.pull_requests[0].number`
    on workflow_run path OR from `inputs.pr_number` on workflow_dispatch.
  - `inputs.runner_labels` (string, optional, default `'"ubuntu-latest"'`)
    — matches IPLAN-0017 convention (ai-review.yml + composition.yml
    use the same shape). Private consumers pass
    `'["self-hosted","aidoc","ci-ephemeral"]'`.
  - `secrets.APP_REVIEWER_1_ID` + `secrets.APP_REVIEWER_1_KEY`
    (optional) — same App as ai-review.yml. Optional → degrades to
    GITHUB_TOKEN fallback with `::warning::` (case-3-class silent-bypass
    of push-triggered consumer workflows on the eventual merge commit).
- **Detection filter (step 3):** `state=OPEN ∧ label=ai:review-passed
  ∧ mergeStateStatus=CLEAN ∧ updatedAt > 2 min ∧ autoMergeRequest is
  null`. The `autoMergeRequest is null` clause is the load-bearing
  guard that case 3 (already-armed-under-GITHUB_TOKEN silent-bypass)
  is excluded per Pass-2 C2 narrow scope. Gov-locked PRs are excluded
  naturally (mergeStateStatus never CLEAN when composition is absent
  or gov-exempt branch fires).
- **Re-arm method = `--merge`** (NOT `--squash`) — matches
  `ai-review.yml:703`'s primary arming method per Pass-2 C3 alignment.
  HARD-CODED in the workflow body (never parametrized) — defense-in-
  depth against re-arm-with-different-method cli/cli ambiguity.
- **Trust gate (step 2):** re-fetches `operations@main` config (same
  curl pattern as ai-review.yml post-IPLAN-0022); checks
  `trust.ai_review` allowlist + tier + `auto_merge.repos` membership.
  Defends against trust-config drift (Risk 9). Fails CLOSED on fetch
  failure.
- **Concurrency:** per-repo + per-PR group with `run_id` fallback for
  empty-pr-number cases (fork PRs) — prevents cross-repo collision in
  Phase B + prevents fork-PR runs from collapsing into one shared
  group (Pass-2 m1 fix).
- **Trigger pivot rationale:** `check_suite.completed` is NOT used
  because GitHub Actions anti-recursion blocks the event for GHA-
  created check suites (Pass-2 C1 finding). `workflow_run` operates
  orthogonally as a workflow-lifecycle event + has empirical precedent
  on operations/composition.yml:24-30.
- **Out of scope for v1** (per IPLAN-0030 §6): case 3 (silent-bypass
  recovery; would need disable-then-rearm with race-condition guards),
  case 4 (self-resolving native auto-merge race), cron belt-and-
  suspenders, audit-only mode, PR comments on successful re-arms.
- **Consumer adoption** (Phase A pilot: operations only; Phase B: 6
  other allowlisted consumers): each consumer adds a thin caller
  `.github/workflows/auto-merge-ai-prs.yml` (~20 lines) with
  `on: workflow_run: workflows: [ai-review, composition] types:
  [completed]` + `workflow_dispatch` + `uses: vladm3105/aidoc-flow-ci/
  .github/workflows/auto-merge-ai-prs.yml@ci/v1.5.0` + a `with:`
  ternary that forwards `pr_number` from whichever event fired.
- **Plan:** [IPLAN-0030](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0030_auto-merge-ai-prs-enforcer.md)
  (plan PR vladm3105/aidoc-flow-operations#190 merged 2026-06-30T12:41Z).
- **Next steps:** 🔴 founder tags `ci/v1.5.0` on aidoc-flow-ci after
  this PR merges (P2); then AI ships P3 (operations Phase A pilot
  caller); then P4 empirical validation; then P5 Phase B rollout.
- **🟡 governance PR** (NEW reusable workflow file). AI does NOT
  auto-merge per OPS-0062 §exceptions.

### Changed — `docs/local-pre-push.md` §7a: multi-agent automated review (consumer-side application of OPS-0065) (2026-06-30)

- **`docs/local-pre-push.md`** — new §7a section "Multi-agent
  automated review (consumer-side application of OPS-0065)" added
  below §7 "Governance-PR additional discipline". Includes a
  diff-class → sub-agent-set table consumers apply on the author
  side BEFORE push/commit (matches the table in
  `aidoc-flow-operations/CLAUDE.md` Merge governance section).
  Plus `SKIP_LOCAL_AI_REVIEW=1` usage discipline + parallel-
  dispatch guidance + brainstorming-class agent dispatch during
  plan/spec Pass 0 drafting.
- **References OPS-0065** in operations DECISIONS.md as the
  authoritative source. The CI `ai-review.yml` gate (authoritative
  on the merge side) is unchanged; the consumer-side doc strengthens
  the AUTHOR-side review pattern this library documents.
- **No workflow-body changes; doc-only.** Consumer adoption is
  organic (consumers read the canonical pattern doc; OPS-0065
  codifies it as the company default).

### Fixed — ci/v1.4.3: ai-review.yml mints App token on gov-locked PRs + submits `--comment` review (gov-locked PR composition deadlock — IPLAN-0029 Pivot 2; 2026-06-29)

- **`.github/workflows/ai-review.yml` — 5 edits (gov-lock branch productization of the manual workaround):**
  - **Edit 1 (line 503):** Drop `env.GOV_LOCKED != 'true'` from the
    `Mint reviewer App token` step's `if:`. After this, the App token
    is also minted on gov-locked PRs (provided `SKIP_REVIEW=0` +
    `APP_KEY_PRESENT=1`). Step renamed from "(routine PRs only)" →
    "(routine + governance-locked PRs)".
  - **Edit 2 (lines 595-606, new block inside `submit_verdict()`):**
    On gov-locked PRs with App token present, submit a HARD-CODED
    `--comment` review via `GH_TOKEN="$APP_TOKEN" gh pr review --comment`
    — App-attributed events fire `pull_request_review:submitted`
    (GitHub anti-recursion only blocks `GITHUB_TOKEN`, not App tokens).
    Composition's `pull_request_review` trigger then activates → body
    runs against PR HEAD → hits gov-lock exempt branch
    (`composition.yml:172`) → writes the required `call / composition:
    SUCCESS` check. Inner guard `[ -n "${APP_TOKEN:-}" ]` ensures inert
    behavior when mint failed (`continue-on-error`) OR when App is not
    configured.
  - **Edits 3-5 (lines 493-504, 580-588, 591 — stale comment
    revisions):** Pre-existing inline docstrings + sub-branch comment
    said the App "must never review gov PRs" — those would contradict
    Edits 1-2 if left unrevised, undermining defense-in-depth at the
    call site (a future maintainer reading two contradicting comments
    inside `submit_verdict()` could miss the design intent + accidentally
    parametrize `--approve`). Edits 3/4/5 revise all three to document
    the new dual-mode behavior + cite `composition.yml:189` as the
    safeguard.
- **Security model — single-factor protection at composition's filter
  + defense-in-depth at the call site.** composition.yml:189 filters on
  `state == APPROVED AND user.id == APP_REVIEWER_1_BOT_ID AND user.type
  == Bot AND commit_id == HEAD_SHA`. Under Pivot 2 the App submission
  has `state == COMMENT` (hard-coded `--comment`) — state mismatch
  rejects the submission for the APP-APPROVED auto-merge path. Pivot 1
  (Pass 3) had two-factor mismatch (state + user.id) because the manual
  workaround used user PAT identity; Pivot 2 loses the user.id factor
  by design (App submits AS THE APP) but compensates with defense-in-
  depth at the call site (hard-coded `--comment` literal, never
  parametrized; assertion guard `GOV_LOCKED == true AND APP_TOKEN
  non-empty`; CHANGELOG callout). OPS-0062 "no auto-merge for gov PRs"
  intent unchanged.
- **App permission scope unchanged.** `pull_requests: write` only (same
  scope that already submits `--approve` on non-gov PRs at line 608) —
  `gh pr review --comment` uses the same API endpoint with
  `state: COMMENT`. No new scope needed; App configuration unchanged.
- **Consumer impact:** bump the `uses:` pin `@ci/v1.4.2` → `@ci/v1.4.3`
  on `ai-review.yml` (no caller-shape change; `composition.yml`
  unchanged). All future gov-locked operations PRs auto-fire the
  comment-state review → composition fires → gov-lock exempt branch
  writes SUCCESS check → PR mergeable. Removes the need for the manual
  `gh pr review --comment` workaround applied 6× this session (PRs
  #168, #171, #172, #173, #178, and #181 on operations).
- **Cyclic dependency on consumer pin-bump PR.** Operations P3 pin-
  bump PR itself touches `.github/workflows/ai-review.yml` → gov-locks
  → would deadlock per the same bug it's fixing (its BASE branch still
  runs the old `@ci/v1.4.2` ai-review.yml semantics). Manual workaround
  applies ONE last time on P3. After P3 lands + main carries v1.4.3,
  all future gov-locked PRs use the auto-fix. This is documented in
  IPLAN-0029 §3 P3 + §4 Risk 6.
- **Plan:** [IPLAN-0029](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0029_composition-workflow-run-gov-lock-fix.md)
  (plan PR vladm3105/aidoc-flow-operations#181 merged 2026-06-29);
  P1a DoD amendment landed at vladm3105/aidoc-flow-operations#182
  (amends `IPLAN-0016_ai-reviewer-build.md` §2a-v3 DoD #12 at lines
  53 + 277). This PR is P1b. Next: tag `ci/v1.4.3` (P2) → operations
  pin bump (P3).
- **🟡 governance PR** (touches `.github/workflows/ai-review.yml`) —
  AI does NOT auto-merge per OPS-0062 §exceptions. Awaits founder
  merge.

### Fixed — ci/v1.4.2: ai-review skips the heavy review on `pull_request_review` events (eliminates false-red `ai-review` check; 2026-06-29)

- **`.github/workflows/ai-review.yml` R3 early-exit** — now also sets
  `SKIP_REVIEW=1` (`SKIP_REASON=review-event`) on any
  `pull_request_review` event, before the SHA-tied App-approval query.
  A review never changes code, so the reviewer's verdict at the current
  HEAD already stands from the push-triggered run, and the separate
  `composition` workflow recomputes the merge gate on the review event.
  The job still concludes SUCCESS via the existing skip-notice step, so
  the `ai-review` check stays green even where it is a required context.
- **Root cause of the false positive:** R3 only skipped when the reviewer
  App had *APPROVED* the HEAD SHA. **Spec-tier PRs never get an App
  APPROVED review** — the App carries `ai:review-passed` instead — so the
  SHA-tied query never matched them. Every review-event re-fire therefore
  re-ran the full reviewer, and the "Fetch reviewer assets + per-consumer
  config" step (private `operations@main` config fetch) could fail on the
  redundant run, painting a red `call / ai-review` that meant nothing (the
  authoritative review for that commit had already passed on the
  push-triggered run). Surfaced on framework PR #206 (spec-tier).
- **Why not fail-open the asset fetch instead:** that would mask a genuine
  asset/config-fetch failure on a real *code-change* run, where a review
  must happen. Skipping only on review events (which can't change code)
  removes the false positive without weakening real-code-change coverage.
- **`labeled`/`unlabeled` events** were already excluded by the job `if:`
  (except `skip-ai-review`); this closes the remaining redundant trigger.
- **Consumer impact:** bump the `uses:` pin `@ci/v1.4.1` → `@ci/v1.4.2` on
  `ai-review.yml`. No caller-shape change; `composition.yml` unchanged.

### Fixed — ci/v1.4.1: doc-maintainer.yml step 3 warn-not-error on missing CLI (IPLAN-0025 alpha.1 hotfix; 2026-06-29)

- **`.github/workflows/doc-maintainer.yml` step 3 'Resolve LLM CLI'** —
  changed from fail-LOUD-on-missing-CLI to best-effort install + warn-
  not-error. Rationale: the alpha.1 stub `planner.py` does NOT invoke
  the LLM (emits empty plan; per IPLAN-0025 §3 alpha-stub note); the
  actual CLI requirement only kicks in v1.4.1+ when the real LLM call
  ships in `planner.py` apply-mode. D12 fail-LOUD discipline preserved
  but MOVED INSIDE planner.py / apply.py where the LLM is actually
  invoked. Step 3 is now a best-effort install for ubuntu-latest
  convenience.
- **Bug discovered on FIRST live fire** on operations' ci-ephemeral
  self-hosted runner pool — pool does NOT have `npm` installed →
  `npm install -g @anthropic-ai/claude-code` exits 127 → step 3
  `command -v claude || exit 1` fails LOUD → workflow fails. Two
  consecutive failures observed (push event 2026-06-28 23:35:35Z run
  28340559175 + schedule event 2026-06-29 00:06:18Z run 28340614376).
- **Defensive shape:** step 3 now branches on `command -v claude` →
  `command -v npm` → no-op path, each with appropriate `::notice::` or
  `::warning::` output. Operator visibility preserved.
- **Operators on npm-less runners** (e.g., operations' ci-ephemeral):
  warning notice points to pre-baking the CLI as the production
  remediation. The alpha.1 stub doesn't need this fix (no LLM call)
  but the production v1.4.1+ ship will need pre-baked CLIs.
- **Consumer impact:** consumers bump `uses:` pin `@ci/v1.4.0` →
  `@ci/v1.4.1` to receive the fix. Operations specifically: also flips
  its `.github/doc-maintainer.json#kill_switch` back to `false` to
  re-arm the dry-run pilot (kill_switch was set to `true` as the
  immediate hotfix per operations PR #171).
- **Plan:** [IPLAN-0025 §3](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0025_ai-doc-maintainer.md)
  — alpha.1 ship strategy + alpha.1 stub design.
- **Discovered observability win:** the alpha.1 ship strategy worked
  as designed — shipping the workflow wiring first surfaced this
  runner-environment-assumption bug BEFORE LLM cost was incurred.
  Validates the IPLAN-0018 "didn't fire" lesson + the IPLAN-0025
  alpha.1 staged-ship discipline.

### Added — ci/v1.4.0 (Phase 1 P1 PR-B): install templates + docs for `doc-maintainer.yml` (IPLAN-0025 P1 PR-B; 2026-06-28)

- **`install/templates/workflows/doc-maintainer-private.yml`** +
  **`install/templates/workflows/doc-maintainer-public.yml`** — new
  thin caller templates per IPLAN-0025 §2.4. Triggers: `push: branches:
  [main]` (primary, after every merge) + `schedule: cron '7,37 * * * *'`
  (backup reconciler — off-peak slots per IPLAN-0025 D9 / Pass-3 minor
  #3 calibration, addresses IPLAN-0018 "didn't fire" gap
  deterministically). Pin: `@ci/v1.4.0`. Private variant uses
  `runner-self`; public variant uses `ubuntu-latest`.
- **`docs/architecture.md` §2** updated: workflow inventory table
  expanded from 7 → 9 shared workflows; new `docs-sync` row
  (mechanical; deprecated by doc-maintainer at end of IPLAN-0025
  Phase 3) + new `doc-maintainer` row (AI-driven; supersedes
  mechanical at end of Phase 3).
- **Consumer install prerequisites** documented in template headers:
  P3a 🟡 governance PR (add `aidoc-flow-bot[bot]` to consumer's
  `.github/ai-review/config.json#trust.ai_review`) + P5a 🟡 founder
  runbook (expand App permissions to `Pull-requests: write` +
  `Issues: write`). Dry-run path does NOT need these — they gate live
  mode (P5 graduation per the plan).
- **Bundled with PR-A** ([PR #43](https://github.com/vladm3105/aidoc-flow-ci/pull/43))
  in the same `ci/v1.4.0` release. Tag pushed after both PRs land.

### Added — ci/v1.4.0 (Phase 1 P1 PR-A): new AI-driven `doc-maintainer.yml` reusable workflow + supporting scripts (IPLAN-0025 P1 PR-A; 2026-06-28)

- **`.github/workflows/doc-maintainer.yml`** — new reusable workflow
  (`workflow_call:` only). Post-merge AI-driven doc-of-record
  maintainer. Reads merge diff + per-consumer conventions doc + invokes
  `claude` (or `codex`) to PLAN which docs need updating; risk-tier
  partitions the plan; dry-run posts PR comment, live mode opens
  follow-up bot PR for low-risk edits + GitHub issue for high-risk
  edits. Per IPLAN-0025 §2.1 (12-step job structure with deterministic
  dedup before LLM cost, fail-LOUD on infrastructure errors per D12).
- **`scripts/doc-maintainer/planner.py`** — step 4-7 (inventory
  candidates + AI plan + validate against outer allowlist + tier-classify).
  alpha.1 status: emits empty plan; real LLM invocation in v1.4.1.
- **`scripts/doc-maintainer/apply.py`** — step 8 (apply low-risk edits
  in apply-mode; produces `.proposed` files). alpha.1 status: no-op
  pass-through; real apply-mode in v1.4.1.
- **`scripts/doc-maintainer/reconcile.py`** — scheduled-cron backup
  reconciler (per §2.4 cron + Pass-2 BLOCKER #2 fix). Scans main
  commits in the lookback window + reports any SHA without an
  associated doc-maintainer run. alpha.1 status: report-only; auto-
  dispatch in v1.4.1.
- **Job-level permissions:** `contents: write` + `pull-requests: write`
  + `issues: write` + `actions: read`. Last one required for the
  reconciler's `actions/runs` query per Pass-3 HIGH Finding #3.
- **Recursion guards** (belt-and-suspenders): `[skip ci]` in bot
  commit message + `if: github.actor != 'aidoc-flow-bot[bot]'`.
- **Concurrency:** `group: doc-maintainer-${{ github.ref }}` with
  `cancel-in-progress: false`.
- **alpha.1 ship strategy:** the workflow wiring + scripts ship NOW
  (v1.4.0) so the dry-run pilot on operations can observe trigger
  reliability empirically (addressing IPLAN-0018 "didn't fire" gap
  ahead of LLM cost kicking in). Real LLM invocation + bot-PR
  creation + issue creation + reconciler auto-dispatch all ship in
  v1.4.1 after dry-run validates the skeleton.
- **PR-B coming next:** install templates
  (`install/templates/workflows/doc-maintainer-{private,public}.yml`)
  + docs updates (architecture.md / security.md / troubleshooting.md).
- **Plan:** [IPLAN-0025](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0025_ai-doc-maintainer.md)
  P1 PR-A (Phase 1 mechanism-only ship; full functionality in v1.4.1).
- **Consumer impact:** consumers do NOT bump pin until v1.4.0 ships
  via PR-B + tag. This PR-A is the workflow + scripts foundation.

### Changed — ci/v1.3.0 (Phase 2 P7): drop `pull_request_target` from composition install templates (IPLAN-0026 P7; 2026-06-28)

- **`install/templates/workflows/composition-private.yml`** + **`install/templates/workflows/composition-public.yml`** triggers
  reduced to `pull_request_review` + `workflow_run` only — Phase-2
  drop of `pull_request_target` per IPLAN-0026 §2.3 + IPLAN-0017 §3.4.
  The kept trigger set covers all four real state-change scenarios
  (routine-approve / routine-reject / skip-ai-review-carry / ai-review-
  infra-failure) without the wasted early-fire `pull_request_target`
  run that created the stale-red FAILURE on every routine PR.
- **`uses:` pin bumped** from `@ci/v1.2.0` to `@ci/v1.3.0` in both
  templates — `install.sh`-onboarded consumers get the v1.3.0 install
  shape (no `pull_request_target`) at install time.
- **Phase-2 ships the friction-relief benefit.** Phase 1 (ci/v1.2.0)
  shipped the `workflow_run` mechanism alongside `pull_request_target`
  for safe migration; Phase 2 drops `pull_request_target` so every
  composition fire now corresponds to a real state change. The label-
  cycle merge-recovery pattern documented at `docs/troubleshooting.md`
  §15 should no longer be needed for routine PRs after consumers bump
  their caller pin to `@ci/v1.3.0` + drop `pull_request_target` from
  their caller composition.yml (IPLAN-0026 P8 — separate consumer PRs
  on operations + framework, bundled into the same `ci/v1.3.0` release
  cycle).
- **`docs/security.md` §5** updated: composition no longer uses
  `pull_request_target` (new "Composition no longer uses
  `pull_request_target` (ci/v1.3.0+)" subsection); ai-review continues
  to use it. Security analysis still applies — composition's
  `pull_request_review` + `workflow_run` triggers carry the same
  BASE-ref + secrets posture as `pull_request_target`, so the
  Phase-2 drop is about merge-friction relief, not changing the
  security model.
- **Existing consumers** can still locally re-add `pull_request_target`
  if they have a flow dependent on it (local always wins per
  `docs/overrides.md`). The Phase-2 install template just no longer
  inherits it as a default.
- **Bundled with IPLAN-0027 P1** (R3 ai-review early-exit + troubleshooting
  §15 update) in the same `ci/v1.3.0` release — both are Phase-2 friction-
  relief cleanups; consumers do ONE pin-bump cycle to get both benefits.
- **Plan:** [IPLAN-0026](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0026_composition-workflow-run-redesign.md)
  P7 (Phase-2 cleanup; promotes IPLAN-0017 §3.4 Phase-B target to
  active state).
- **Consumer impact:** consumers bump caller pin `@ci/v1.2.0` →
  `@ci/v1.3.0` + drop `pull_request_target` from their caller
  `composition.yml` (IPLAN-0026 P8 — operations PR + framework PR
  shipping next).

### Changed — ci/v1.3.0 (P1): R3 ai-review early-exit when App already APPROVED at HEAD (IPLAN-0027 P1; 2026-06-28)

- **`.github/workflows/ai-review.yml`** — new "R3 early-exit if App
  already APPROVED at HEAD" step inserted at the top of the
  `ai-review` job's `steps:` list (before "Fetch reviewer assets").
  Queries the same App-APPROVED-at-HEAD review set that
  `composition.yml` uses (matching `user.id == APP_REVIEWER_1_BOT_ID`
  + `user.type == "Bot"` + `state == "APPROVED"` + `commit_id == HEAD_SHA`).
  When match found: writes `SKIP_REVIEW=1` + `SKIP_REASON=r3` to
  `$GITHUB_ENV` → all heavy downstream steps (`Fetch reviewer assets`,
  rubric run, App-token mint, verdict post, etc.) skip via their
  existing `if: env.SKIP_REVIEW != '1'` guards. Saves ~$0.10-0.20 +
  ~2-3 min per redundant re-fire (typical case: label-cycle-
  retriggered ai-review after the App had already APPROVED the same
  HEAD).
- **Safety: fail-OPEN on persistent API failure** — 7-attempt retry
  with `n*3` backoff capped at 20s (symmetric with
  `composition.yml:187-200` enforcement query). On all-7-retries-
  failed, R3 emits `::warning::` + exits 0 → full review path takes
  over. NEVER silently skips a needed review.
- **Safety: HEAD-SHA-tied query** — only the App's APPROVED-at-current-
  HEAD review counts. Force-push to a new SHA → no match at the new
  SHA → full review runs. Force-fresh-at-same-HEAD path: dismiss the
  App's prior review via
  `gh api -X PUT repos/<repo>/pulls/<pr>/reviews/<id>/dismissals
  -f event=DISMISS`.
- **Safety: INERT-when-App-not-armed** — when `vars.APP_REVIEWER_1_BOT_ID`
  is unset, R3 emits `::notice::` + exits 0 → full review runs (same
  behavior as composition's INERT branch). Numeric-id validation
  enforced (composition's pattern reused).
- **New `SKIP_REASON` env field** alongside `SKIP_REVIEW` distinguishes
  the two skip paths in the final "ai-review skipped" step:
  - `SKIP_REASON=label` — set in the job env block when the
    `skip-ai-review` label is present. The notice references the
    label + posts a one-time PR comment (existing behavior).
  - `SKIP_REASON=r3` — set by the R3 step via `$GITHUB_ENV` when the
    App has already APPROVED at HEAD. The notice references R3 +
    points operators to the gh-api dismissal force-fresh path. **NO
    PR comment** (would spam every label-cycle on an approved PR).
- **Renamed final step** from "ai-review skipped (label)" → "ai-review
  skipped (label OR R3 pre-approved)" so workflow-log readers see the
  dual-purpose role at a glance.
- **`docs/troubleshooting.md` §15** updated: documents the v1.3.0+
  semantics (composition install template no longer listens on
  `pull_request_target`; R3 carries forward on already-approved-at-HEAD
  cycles; new gh-api dismissal force-fresh path replaces the
  pre-R3 "label-cycle-alone forces fresh" pattern). Decision matrix
  table refreshed for v1.3.0+ scenarios.
- **Cost saved (observed):** the 5 case-study operations PRs from
  2026-06-27 (#149, #150, #152, #154, #155) each used the label-cycle
  recovery → ai-review re-fired AFTER the App had APPROVED → ~$0.10-
  0.20 + ~2-3 min per re-fire. R3 eliminates the heavy CLI re-run;
  total session-equivalent savings ≈ ~$0.50-1.00 + ~10-15 min in
  observed wasted work. Scales linearly with PR volume.
- **Bundled with IPLAN-0026 P7** (drop `pull_request_target` from
  composition install templates) in the same `ci/v1.3.0` release —
  both are Phase-2 friction-relief cleanups; consumers do ONE
  pin-bump cycle to get both benefits.
- **Release coordination:** `ci/v1.3.0` will NOT be tagged until
  IPLAN-0026 P7 PR also merges. If P7 stalls, this PR's
  `docs/troubleshooting.md §15` description of composition's
  v1.3.0+ install-template triggers (no `pull_request_target`)
  requires a follow-up fix (the §15 wording is forward-looking
  and accurate only after P7 lands).
- **Plan:** [IPLAN-0027](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0027_r3-ai-review-early-exit.md)
  (READY status with 3 verified-planning review passes + check_plan.py
  gate GREEN; operations PR #161, merged 2026-06-27).
- **Consumer impact:** consumers bump caller pin `@ci/v1.2.0` →
  `@ci/v1.3.0` (operations + framework caller PRs shipping next).
  No caller-workflow shape change required for R3 (the new step lives
  inside the reusable; consumers benefit automatically after pin
  bump).
- **Backward compatibility:** R3 is additive — when the App hasn't
  approved at HEAD (first fire, new HEAD SHA, dismissed prior
  review), the query returns empty → full review runs identically
  to pre-v1.3.0 behavior.

### Changed — ci/v1.2.0 (Phase 1 P2): install templates add `workflow_run` trigger + pin bump (IPLAN-0026 P2; 2026-06-27)

- **`install/templates/workflows/composition-private.yml`** + **`install/templates/workflows/composition-public.yml`** triggers
  extended to add `workflow_run` (fires AFTER consumer's `ai-review`
  caller completes — any conclusion) ALONGSIDE the existing
  `pull_request_target` + `pull_request_review` triggers. Parallel-
  trigger transition for safety per IPLAN-0017 §3.4 + IPLAN-0026 §2.3 D2
  migration discipline.
- **`uses:` pin bumped** from `@ci/v1.0.6` to `@ci/v1.2.0` in both
  templates — `install.sh`-onboarded consumers now get the v1.2.0 body
  (which handles the new `workflow_run` event shape from P1) at install
  time. Existing consumers bump their caller pin via separate Phase-1
  P4/P5 PRs (operations + framework callers).
- **Phase 1 ships MECHANISM only.** During Phase 1 the early-fire stale-
  red still happens (kept `pull_request_target` fires composition before
  the App approves; FAILS legitimately; later re-fires SUCCESS via
  `pull_request_review` or now `workflow_run`; rollup still shows the
  stale FAILURE; label-cycle still needed). **Phase 2 (ci/v1.3.0,
  separate small IPLAN after empirical validation) drops
  `pull_request_target` from these install templates** and delivers the
  actual friction relief.
- **Phase-1 P3 next:** tag `ci/v1.2.0` against the most recent
  composition + install-template commits (P1 + P2 land together under
  the same minor version per IPLAN-0026 §3).

### Changed — ci/v1.2.0 (Phase 1): `composition.yml` body handles `workflow_run` event shape (IPLAN-0026 P1; 2026-06-27)

- **`.github/workflows/composition.yml`** body refactored to source PR
  data from EITHER event shape:
  - `pull_request_review` event → `github.event.pull_request.*` (the
    original shape; current consumer caller trigger)
  - `workflow_run` event → `github.event.workflow_run.pull_requests[0].*`
    (new path; consumer caller installs trigger in §2.3 install-
    templates change shipping next as Phase-1 P2)
  Each env field uses `||` fallback expression: LHS = pull_request_review
  shape; RHS = workflow_run shape. Concurrency group uses the same
  fallback so per-PR serialization works for both event shapes.
- **Job `if:` condition** extended to allow `workflow_run` events
  through unconditionally (workflow_run only fires from the ai-review
  workflow completing — exactly when composition should re-evaluate).
  Non-label events (pull_request_review, etc.) always run; label events
  still only run for `skip-ai-review` (unchanged contract).
- **SKIP_REVIEW resolution** moved from env-block expression (which
  required the `pull_request_review` payload's `labels` field) to a
  `gh-api` lookup in the body (shape-agnostic; works regardless of event
  type; default-empty + retry on transient failure).
- **Fork PR edge case:** `github.event.workflow_run.pull_requests[]`
  is empty when the source workflow ran from a fork; both `||` fallback
  expressions resolve to empty strings → body detects empty `$PR` +
  exits with `::notice::` (forks are HUMAN-REVIEW-ONLY per ai-review's
  trust gate; composition correctly exempts them via the IS_FORK branch
  for non-workflow_run events too — both paths land at the same
  behavior).
- **Reusable contract unchanged** — composition.yml is still
  `workflow_call:` only. Trigger declaration is on the consumer caller
  templates (composition-{private,public}.yml installed via
  `install.sh`); those get the `workflow_run` trigger in the next
  Phase-1 P2 PR.
- **Phase-1 ships MECHANISM only.** The early-fire stale-red friction
  is NOT yet eliminated — Phase 1 keeps `pull_request_target` in
  parallel for safety per IPLAN-0017 §3.4 migration discipline. Phase 2
  (ci/v1.3.0, separate small IPLAN after empirical validation) drops
  `pull_request_target` from install templates and delivers the actual
  friction relief. Set expectations accordingly.
- **Plan:** [IPLAN-0026](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0026_composition-workflow-run-redesign.md)
  (operations PR #156, merged 2026-06-27 commit `44f4b5b`; READY status
  with 3 verified-planning review passes + check_plan.py gate green).
- **Consumer impact:** consumers bump pin `@ci/v1.1.7` → `@ci/v1.2.0`
  to consume this body refactor. The `workflow_run` trigger declaration
  in install templates ships in a separate Phase-1 P2 PR (also targeting
  ci/v1.2.0; both land together).
- **Backward compatibility:** consumers on the current install
  templates (pull_request_target + pull_request_review triggers only)
  continue to work identically — the body's `||` fallback resolves to
  the LHS for those events; new workflow_run handling is dormant until
  the consumer adds the new trigger to their caller.

### Fixed — ci/v1.1.7: `ai-review.yml` auto-merge `bash -e` interaction bug (regression from v1.1.6; 2026-06-27)

- **`.github/workflows/ai-review.yml`** auto-merge App-token branch:
  the `merge_err=$(GH_TOKEN=$APP_TOKEN gh pr merge ... 2>&1)` shell
  pattern triggered immediate `set -e` exit under GitHub Actions'
  default `bash -e {0}` shell whenever the inner `gh pr merge` exited
  non-zero (e.g., auto-merge already enabled; permission denied;
  transient network blip) — bypassing both the `merge_rc=$?` capture
  AND the warning fallback. The whole gate step exited 1, blocking
  the required check on every auto-merge attempt where the App-path
  hit a non-zero exit.
- **Fix:** wrap the App-path merge call in the `if cmd; then ...;
  else ...; fi` form, which bash explicitly exempts from `set -e`
  (per documented behavior). Non-zero exits now flow into the else
  branch + fallback path cleanly:
  ```bash
  if merge_err=$(GH_TOKEN="$APP_TOKEN" gh pr merge "$PR" --auto --merge 2>&1); then
    merge_rc=0
  else
    merge_rc=$?
  fi
  ```
- **Why this wasn't caught pre-ship in v1.1.6:** the v1.1.6 self-
  review focused on logic + permission concerns (reviewer flagged
  `--auto` actor-attribution + stderr capture as MEDIUMs, both
  addressed). The `bash -e` + command-substitution interaction is
  documented bash arcana that the reviewer didn't flag and the
  shipped CHANGELOG only suggested "10-min empirical test on a
  throwaway PR" which wasn't executed. **First real-PR validation
  on operations PR #152 was where the bug surfaced** (gate step
  exited 1 after 3 seconds; no warning emitted; App's APPROVED
  review WAS posted earlier in the same step before the bug bit).
- **Validation:** v1.1.7 fix verified by inspection. Post-deploy
  validation: next auto-merged routine PR after operations + framework
  bump to `@ci/v1.1.7` must pass `call / ai-review` clean (the bug
  manifested as immediate 3-second gate-step failure with zero log
  output; success looks like the gate's full review/comment/merge
  sequence).
- **Consumer impact:** consumers bump pin `@ci/v1.1.6` → `@ci/v1.1.7`.
  v1.1.7 is a strict superset of v1.1.6 (App-token path + fallback);
  no schema or input changes.
- **Lesson recorded:** the auto-merge step deserves an end-to-end
  empirical test (a throwaway PR with the App configured) before
  tagging future v1.1.X releases — code review couldn't catch this;
  the failure shape is runtime-only.

### Fixed — ci/v1.1.6: `ai-review.yml` auto-merge uses reviewer App token (fixes silent docs-sync bypass on auto-merged PRs; 2026-06-27)

- **`.github/workflows/ai-review.yml`** "Gate · comment · label · merge"
  step's auto-merge branch: `gh pr merge "$PR" --auto --merge` now
  authenticated with the reviewer App's installation token (`APP_TOKEN`)
  instead of the default `GITHUB_TOKEN`. Graceful fallback: if
  `APP_TOKEN` is unavailable (App not configured) OR the App lacks
  `contents: write` permission, falls back to `GITHUB_TOKEN` and emits
  a `::warning::` so the missing-permission case is operator-visible.
- **Why:** per GitHub's documented anti-recursion rule, any merge
  commit authored by `GITHUB_TOKEN` does NOT trigger downstream `push:`
  workflows. Operations PRs that pass ai-review's auto-merge path were
  therefore silently bypassing `docs-sync.yml` (and any other consumer
  workflow listening on `push: branches: [main]`). Surfaced 2026-06-27
  during IPLAN-0018 docs-sync verification: operations PRs #149 + #150
  auto-merged by `github-actions[bot]` → zero downstream `push` runs
  fired on either merge commit. Only the previous merge (PR #148, which
  was governance-locked → human-merged) fired docs-sync.
- **Consumer requirement:** the reviewer App needs `contents: write`
  permission for the App-authored merge to succeed. operations +
  framework already have the App installed; verify the permission is
  granted via the App's settings page (`https://github.com/settings/
  apps/aidoc-reviewer` → Permissions → Repository permissions →
  Contents: Read and write). If the permission is missing, the fix
  gracefully falls back to GITHUB_TOKEN (same as today's behavior) +
  emits the `::warning::` — the merge still happens; only push:
  workflows stay suppressed until the permission is added.
- **Backward compatibility:** fully compatible. Consumers without the
  App (App-not-configured path) get the GITHUB_TOKEN fallback —
  identical to pre-v1.1.6 behavior. Consumers with the App + correct
  permissions get the fix automatically on pin bump to `@ci/v1.1.6`.
  No schema or input changes.
- **Consumer impact:** consumers bump caller pin `@ci/v1.1.5` →
  `@ci/v1.1.6` to consume the fix.
- **Validation (post-deploy verification required):** after operations
  + framework pin-bump to `@ci/v1.1.6`, the **first auto-merged routine
  PR** must be verified to:
  1. Have merge commit authored by `aidoc-reviewer[bot]` (not
     `github-actions[bot]`) — confirms the App-token arming carried
     through to merge author per documented GitHub behavior (verified
     empirically on PRs #149+#150 under the OLD code: arming actor →
     merge actor; this fix changes the arming actor to the App).
  2. Have `docs-sync.yml` trigger a `push` workflow run on the merge
     commit sha (verify via `gh run list -R vladm3105/aidoc-flow-
     operations --workflow docs-sync.yml --event push --limit 3`).
  If (1) holds but (2) doesn't, GitHub's anti-recursion behavior differs
  from the documented rule — investigate. If (1) fails (merge commit
  still by `github-actions[bot]`), the App permission may be missing
  (check the `::warning::` in the auto-merge step log) — grant
  `contents: write` per "Consumer requirement" above and retry.
- **Related work:** mechanical-scripts docs-sync (IPLAN-0018) is a
  narrow approach; AI-driven `doc-maintainer.yml` (TODO matrix row 6,
  formerly DEFERRED) is being promoted to an active IPLAN-0025 that
  supersedes IPLAN-0018's mechanical design. This v1.1.6 fix is the
  immediate symptom fix; IPLAN-0025 will be the structural fix.

### Fixed — ci/v1.1.5: replace `ai-review.yml` cross-repo `actions/checkout` with `curl` (eliminates v1.1.x bug class; 2026-06-27)

- **`.github/workflows/ai-review.yml`** "Resolve aidoc-flow-ci pinned ref",
  "Checkout trusted reviewer assets (aidoc-flow-ci@pinned tag)", and
  "Checkout per-consumer config (operations@main; transitional)" steps
  consolidated into a single "Fetch reviewer assets + per-consumer config"
  step using `curl` instead of `actions/checkout@v4`.
- **Why:** the 5-cycle v1.1.0→v1.1.3 saga (sparse-checkout pattern, cone-
  mode, full-clone, `clean: false`) + the v1.1.4 reorder attempt proved
  the `actions/checkout` interaction with workspace state, INIT-time
  content-delete, and runner-class differences was the failure mode
  itself. `curl` has none of those failure modes: writes bytes to a
  path; workspace state, runner class, and `pull_request_target` event
  semantics don't matter. Fetch either works (HTTP 200) or fails loudly
  (`--fail`).
- **What stays the same (intentionally):** trust gate's
  `actions/checkout` of operations@main (separate job; no second
  checkout to interact with; works today). `AI_REVIEW_TOKEN` secret
  (curl uses it for the PRIVATE operations@main fetch). All downstream
  paths (`./reviewer-assets/ai-review/{review-prompt.md,verdict.schema.json}`
  + workspace-root `.github/ai-review/config.json`). Workflow
  `workflow_call:` interface, inputs, runner_labels. Library pattern
  intact (IPLAN-0017 + IPLAN-0022 + IPLAN-0023 all unchanged).
- **Asset retrieval shape:** rubric + schema from
  `https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/<pinned-ref>/ai-review/{review-prompt.md,verdict.schema.json}`
  (PUBLIC; raw works unauth). Per-consumer config from
  `https://raw.githubusercontent.com/vladm3105/aidoc-flow-operations/main/.github/ai-review/config.json`
  (PRIVATE; `Authorization: Bearer ${AI_REVIEW_TOKEN}` then fallback to
  GitHub API contents endpoint with `Accept: application/vnd.github.raw`
  on raw failure). All fetches `--fail --silent --show-error --location
  --retry 3 --retry-delay 2`. `test -s` verifies every fetched file is
  non-empty (defense against silent HTTP-200-empty-body pathology).
- **R1 + R2 bundle-ins both DROPPED from this PR after self-review:**
  - **R1** (narrow trust/ai-review `if:` to fire on `labeled` only for
    `skip-ai-review`) would break the `docs/troubleshooting.md §15`
    label-cycle "force fresh review on stale verdict" path: removing
    the label is the documented way to re-fire ai-review on the
    latest commit after a rebase, and R1's drop of the `unlabeled`
    branch silently disables it. HANDOFF's "halves cost" rationale
    misanalyzed which branch does the work — the `labeled` half runs
    `SKIP_REVIEW=1` (cheap no-op skip step), the `unlabeled` half is
    the one that runs the full review. The real intent ("don't re-
    fire when verdict already APPROVED at HEAD") is what R3 (early-
    exit step, ~20 lines) addresses — tracked for its own small IPLAN.
  - **R2** (bare 1-line `workflow_dispatch:` on composition install
    templates) does not achieve its stated retrigger goal — the
    reusable composition.yml body depends on
    `github.event.pull_request.*` fields that are empty on
    `workflow_dispatch` events. Proper implementation needs
    `workflow_dispatch.inputs.pr_number:` + reusable workflow
    fallback logic. Tracked for its own small IPLAN.
- **Consumer impact:** consumers bump caller pin `@ci/v1.1.3` →
  `@ci/v1.1.5` to consume the fix. Existing `AI_REVIEW_TOKEN` secret +
  workflow inputs unchanged. No behavior change for `skip-ai-review`
  label workflows (R1 dropped).
- **Validation:** P3 (operations pin-bump) validates on self-hosted
  runner (the saga's KNOWN-GOOD class — operations works on v1.1.3
  today, so a regression on operations would be the first signal that
  curl introduced a NEW failure mode). P4 (framework pin-bump) is the
  CRITICAL validation — proves curl-replaces-checkout works on the
  GitHub-hosted runner class, the bug-class home that v1.1.0-v1.1.3
  couldn't escape.
- **Chicken-and-egg:** PRs that bump the pin can't pass ai-review at
  BASE main (still has the v1.1.3 workflow); ship via
  `skip-ai-review` label + admin-merge per `docs/troubleshooting.md §15`.
- **Plan reference:** IPLAN-0024 (operations PR #145; approved + merged 2026-06-26).

### Changed — README.md: refresh to current `ci/v1.1.3` (was stale at `ci/v1.0.6`; 2026-06-26)

- **`README.md`** "Who uses this" table, "What ships" section
  header, install URL, and "known limitations" section header all
  bumped from `@ci/v1.0.6` → `@ci/v1.1.3` matching the current
  consumer state on operations + framework.
- **Why:** README was the public-facing entry point + still cited
  v1.0.6 as current despite v1.1.0/v1.1.1/v1.1.2/v1.1.3 ships
  today (sparse-checkout saga + composition trigger Gap 2 + full-
  clone fix). New Phase C consumers reading the README would get
  the wrong version on install. Historical `v1.0.6` context (the
  pre-v1.1.0 secret-naming limitation note) preserved for
  reference.
- Doc-currency rule per `CLAUDE.md` "Keep docs current": every
  pin-bump session refreshes README references in the same batch.
  This entry closes today's saga.

### Fixed — ci/v1.1.3: second checkout step `clean: false` (silent killer of v1.1.2 full-clone; 2026-06-26)

- **`.github/workflows/ai-review.yml`** "Checkout per-consumer config
  (operations@main; transitional)" step: added `clean: false`.
- **Why:** default `clean: true` runs `git clean -ffdx` at workspace
  root before the second checkout fetches. That recursively wiped
  the prior "Checkout trusted reviewer assets" step's
  `./reviewer-assets/` subdirectory — which contained the rubric
  file needed by the reviewer adapter. Net effect: the rubric got
  fetched (by step 1) then immediately deleted (by step 2's clean)
  → `claude --append-system-prompt-file` failed with 'file not
  found' → ai-review verdict broken.
- **Validation evidence:** operations PR #142 (v1.1.2 validation
  smoke) ai-review log showed `Removing reviewer-assets/` IMMEDIATELY
  before `HEAD is now at e1e7b4e` (the operations@main config.json
  checkout) — the second checkout step removed the first's output.
- **Why this wasn't caught in earlier diagnostic rounds:** v1.1.0 +
  v1.1.1 attempts focused on sparse-checkout pattern theory; the
  `clean: true` interaction is a separate failure mode that became
  the proximate cause once sparse-checkout was correctly removed
  in v1.1.2 (the full-clone DID populate the directory; the second
  step then wiped it).
- **Consumer impact:** consumers bump caller pin `@ci/v1.1.2` →
  `@ci/v1.1.3` to consume the fix.
- **Chicken-and-egg:** SAME as v1.1.1 + v1.1.2 — PRs that bump the
  pin can't pass ai-review (BASE main has buggy v1.1.2 workflow);
  ship via `skip-ai-review` label + admin-merge.
- **Lesson recorded:** any multi-checkout workflow needs explicit
  `clean: false` on all but the first checkout, OR per-checkout
  path isolation, OR the multi-checkout pattern itself replaced
  with a single full clone + manual file copies. Future workflow
  changes adding additional `actions/checkout@vN` steps need
  this constraint codified.

### Fixed — install/templates/workflows/composition-{private,public}.yml: add `opened` trigger (Gap 2 propagation fix; 2026-06-26)

- **`install/templates/workflows/composition-private.yml`** triggers
  extended: `[synchronize, labeled, unlabeled]` →
  `[opened, synchronize, reopened, ready_for_review, labeled, unlabeled]`.
- **`install/templates/workflows/composition-public.yml`** triggers
  extended: `[synchronize, labeled, unlabeled]` →
  `[opened, synchronize, reopened, labeled, unlabeled]`.
- **Why:** the install templates had the same Gap 2 bug fixed in
  operations PR #140 + framework PR #175 — missing `opened` trigger
  meant freshly-opened PRs left composition pending (only ai-review
  fires on `opened`) → merge blocked until label-cycle / push woke
  composition. New consumers onboarded via `install.sh` would
  inherit the bug. This fix propagates the root-cause repair to
  future consumers.
- **Phase C consumers now safe:** iplan-runner, business, iplanic,
  iplan-standard, web-site, engramory can onboard via `install.sh`
  + get the correct triggers by default. Removes the per-consumer
  hand-copy friction noted in the readiness assessment.

### Fixed — ci/v1.1.2: full clone of aidoc-flow-ci reviewer assets (sparse-checkout deemed unfixable after 2 attempts; 2026-06-26)

- **`.github/workflows/ai-review.yml`** "Checkout trusted reviewer
  assets" step: removed sparse-checkout entirely; uses full clone.
  - **Why:** ci/v1.1.1 (cone-mode) STILL failed to populate
    `./reviewer-assets/ai-review/` on GitHub-hosted runner fresh
    clones (verified via framework PR #173 + operations PR #140
    ai-review failures with `Append system prompt file not found`
    error AFTER bumping to @ci/v1.1.1).
  - **Hypothesis:** `actions/checkout@v4` interaction between
    `path: ./reviewer-assets` parameter + sparse-checkout (any mode)
    doesn't populate sub-directory files reliably on fresh clones.
    Could be a `@v4` quirk; could need `@v5`; could be an undocumented
    constraint. Stopped iterating after 2 attempts per minimal-and-
    realistic rule.
  - **Trade-off accepted:** full clone of aidoc-flow-ci is a few
    seconds slower per ai-review fire vs sparse-checkout — acceptable
    cost for reliability. The repo is small (~tens of files); the
    runtime impact is negligible.
- **Validation:** consumers (operations + framework) bump caller pin
  `@ci/v1.1.1` → `@ci/v1.1.2`; next ai-review fire on either consumer
  validates the full-clone path end-to-end.
- **Chicken-and-egg context:** PRs that bump the pin can't pass
  ai-review (BASE main still has the buggy v1.1.1 workflow); they
  ship via the documented `skip-ai-review` label escape hatch +
  admin-merge. Same pattern as operations PR #140 / framework PR #175
  used for v1.1.1.

### Fixed — runner CLASS vs LABEL terminology cleanup + `docs/runners.md` §0 canonical reference (2026-06-26)

- **`docs/runners.md` §0** (NEW): canonical terminology reference —
  runners have two CLASSES (GitHub-hosted vs self-hosted; managed by
  GitHub vs operator) and many possible LABELS (`ubuntu-latest`,
  custom self-hosted pools); cites
  [GitHub Actions docs](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners).
  Includes a "common mistakes to AVOID" table + worked example.
- **`.github/workflows/ai-review.yml`** `runner_labels_review` input
  description: "(ubuntu-latest does NOT qualify)" → "(GitHub-hosted
  runners like ubuntu-latest do NOT qualify out-of-the-box — CLI is
  installed at workflow start per ci/v1.0.2+)" — gives reader the
  class context + the relevant ci/v1.0.2+ behavior in one place.
- **`docs/troubleshooting.md` §10**: "ubuntu-latest doesn't have the
  reviewer CLI" → "GitHub-hosted runners (including `ubuntu-latest`)
  don't have the reviewer CLI pre-installed" — class-first framing.
- **`install/templates/workflows/markdown-lint.yml`** header comment:
  "on ubuntu-latest" → "on GitHub-hosted runners (e.g. `ubuntu-latest`)".
- **Why this matters:** confusing class with label leads to bugs like
  the IPLAN-0022 sparse-checkout pattern (fixed in PR #29 / ci/v1.1.1)
  — the bug was masked on self-hosted because of cached state; only
  exposed on GitHub-hosted fresh clones. If we'd thought
  "ubuntu-latest is just a runner" we'd have assumed it behaves like
  the other runners; the class distinction makes the cached-state-vs-
  fresh-clone difference predictable.
- All historical/already-shipped CHANGELOG entries with "ubuntu-latest"
  framing are left as-is (ship-date-fixed); only NEW docs going forward
  use class-first framing per §0.
### Fixed — ci/v1.1.1: sparse-checkout pattern fix (IPLAN-0022 PR-A bug; 2026-06-26)

- **`.github/workflows/ai-review.yml`** "Checkout trusted reviewer
  assets" step: removed `sparse-checkout-cone-mode: false` so the
  step uses default cone-mode. The non-cone-mode pattern `ai-review`
  matched the literal filename (not the directory contents) →
  on fresh clones (GitHub-hosted runners, e.g. `ubuntu-latest`),
  the `ai-review/` directory wasn't populated →
  `review-prompt.md` not found → `claude --append-system-prompt-file`
  failed → ai-review verdict broken on every PUBLIC consumer using
  GitHub-hosted runners.
- **How operations passed despite the bug:** operations runs on a
  self-hosted runner with cached state from prior `actions/checkout`
  invocations that populated the full repo; sparse-checkout pattern
  issue was masked. GitHub-hosted runners do fresh clone per job →
  bug exposed on framework's PR.
- **Validation:** framework [PR #173](https://github.com/vladm3105/aidoc-flow-framework/pull/173)
  ai-review failed with:
  `Error: Append system prompt file not found: .../reviewer-assets/ai-review/review-prompt.md`
- After ci/v1.1.1 tag ships: consumers can bump caller pin
  `@ci/v1.1.0` → `@ci/v1.1.1` to consume the fix. Framework PR #173
  will re-fire ai-review with the new path-population behavior.
- This is the **first real-world cross-runner-class validation** of
  IPLAN-0022 PR-A — self-hosted (operations) masked a bug that
  GitHub-hosted (framework) exposed. Per GitHub Actions terminology:
  runners have two CLASSES (GitHub-hosted vs self-hosted); labels
  (`ubuntu-latest`, custom self-hosted labels) identify specific
  runner images within each class. Lesson: any new sparse-checkout
  pattern should be tested on BOTH classes before declaring success.

### Added — `docs/troubleshooting.md` §15: label-cycle retrigger pattern (2026-06-26)

- **`docs/troubleshooting.md`** new §15 "Stuck check — label-cycle
  retrigger": canonical guidance on the label-cycle pattern (add +
  remove `skip-ai-review` label to inject synthetic
  `pull_request_target` labeled/unlabeled events that re-fire
  workflows on the current commit state).
- Includes the `skip-ai-review` label mechanism explanation,
  when-to-use table, cost/risk warning (each cycle fires every
  workflow with labeled/unlabeled triggers), and the "rebase-only
  commit → add label PERMANENTLY (no remove)" pattern.
- TOC row added.
- Surfaced during IPLAN-0022 PR-B/PR-C rollout 2026-06-25/26:
  cycles became compounding-slow on the 2-runner self-hosted pool;
  documenting the pattern + its proper use prevents future reflexive
  cycling.

### Fixed — IPLAN-0022 §3.7 → §4 cross-ref correction (2026-06-26)

- **`CHANGELOG.md` line 28** (IPLAN-0022 PR-A entry): cited
  "IPLAN-0022 §3.7 P1" but the rollout phases moved to §4 when
  IPLAN-0022 Pass 2 collapsed 7→3 phases. Corrected to "§4 P1".
- Same bug exists in framework `CHANGELOG.md:18` — fixed in
  separate framework PR (different repo; can't bundle).
- Originally surfaced by operations PR #138's second ai-review
  re-fire (caught what the first fire missed; reviewer is
  non-deterministic between runs on the same commit).

### Added — IPLAN-0022 PR-A: reviewer assets moved to aidoc-flow-ci (ci/v1.1.0 target; 2026-06-25)

- **`ai-review/review-prompt.md`** (NEW; moved from
  `aidoc-flow-operations/.github/ai-review/`; 97 lines; opening
  paragraph generalized — "the calling consumer repo" instead of
  hardcoded `aidoc-flow-operations`).
- **`ai-review/verdict.schema.json`** (NEW; moved byte-identical
  from operations).
- **`ai-review/README.md`** (NEW; directory pointer + "how it's
  consumed" + per-consumer-override-future framing).
- **`.github/workflows/ai-review.yml`** "Checkout reviewer assets"
  step replaced: was `actions/checkout` of `aidoc-flow-operations@main`;
  now sparse-checkout of `aidoc-flow-ci@${{ github.workflow_ref }}`
  `ai-review/` directory only. Downstream `RUBRIC=` + `SCHEMA=` lines
  updated to `./reviewer-assets/ai-review/*` paths.
- **`docs/ai-review-assets.md`** (NEW; consumer-facing spec — what
  lives in `ai-review/`, how the workflow consumes it, per-consumer
  override future framing, schema-change discipline, why-not-in-`.github/`
  rationale matching IPLAN-0018 `scripts/docs-sync/` precedent).
- **Per IPLAN-0022 §4 P1:** ships as `ci/v1.1.0` after merge.
  Phase 2 (consumer pin-bumps on operations + framework) ships as
  separate per-consumer PRs after this lands. Phase 3 (legacy
  delete on operations) ships after 1 week of clean reviews on the
  new path.
- **Trust allowlist still on operations:** only the rubric + schema
  moved; the trust allowlist (`.github/ai-review/config.json`
  `trust.ai_review`) remains on `aidoc-flow-operations` per separate
  governance home (operations governance ≠ CI infrastructure).
- **Rule 1 EXCEPTION (6 surfaces):** atomic asset-move — splitting
  creates broken intermediate states where workflow checkout-source
  and asset-destination are inconsistent. Founder pre-approved per
  IPLAN-0022 §4 + chat direction 2026-06-25 "Start with #1 (IPLAN-0022
  PR-A implementation)".

### Added — `docs/local-pre-push.md`: canonical pre-push self-check pattern for consumers (2026-06-25)

- **`docs/local-pre-push.md`** (NEW; ~140 lines) — canonical pattern
  for consumer repos to ship a `scripts/pre_push_check.sh` that runs
  mechanical linters + a local AI self-review via `claude` CLI on
  the diff. Local pass is a MIRROR of CI's `ai-review.yml` gate
  (same rubric); catches issues earlier; CI remains authoritative.
- **Reference implementation:** operations PR #137 ships the
  pattern; this doc canonicalizes it for adoption by other
  consumers (framework + Phase C: iplan-runner, business, iplanic,
  iplan-standard, web-site, engramory) and future company projects.
- **Hardening principles documented:** 5-min `timeout` wrapper on
  claude call; verdict regex anchored to first-line `^VERDICT:`;
  model-drift fallback; diff truncation; `SKIP_LOCAL_AI_REVIEW=1`
  escape hatch; future hardening notes for diff fence-collision.
- **Adoption prerequisites enumerated:** claude CLI install +
  auth; `.github/ai-review/review-prompt.md` (IPLAN-0022 will move
  this to `aidoc-flow-ci/ai-review/`); pre-commit hook wiring.
- **`docs/multi-project-guide.md`** §8 added — references the new
  doc + summarizes the pattern as part of the canonical onboarding.
- **`docs/README.md`** — index updated.
- **Future enhancement noted:** ship `install/templates/scripts/
  pre_push_check.sh` so `install.sh` drops it automatically on new
  consumers; not blocking; tracked in §8 of the new doc.

### Fixed — `ci/v1.1.0-alpha.2`: docs-sync count step fails when no proposals (alpha.1 bug surfaced by operations Phase A first natural fire 2026-06-25)

- **`.github/workflows/docs-sync.yml`** "Count proposed changes" step:
  alpha.1 ran `find .docs-sync-proposed -maxdepth 1 ...` without first
  ensuring the directory exists. When ALL 3 operation scripts produced
  no proposals (the common case — operations' first natural fire on
  PR #134 merge had no triggers matching), `.docs-sync-proposed/`
  didn't exist, `find` exited 1, and `set -euo pipefail` killed the
  job. Net effect: every "no-changes" dry-run was reported as failure
  instead of clean "proposed=0".
- **Fix:** `mkdir -p .docs-sync-proposed` before the count step,
  guaranteeing the directory exists. `find` then returns 0 with an
  empty result; count = 0; workflow exits clean.
- **`install/templates/workflows/docs-sync.yml`** caller template pin
  bumped from `@ci/v1.1.0-alpha.1` → `@ci/v1.1.0-alpha.2`.
- **Validation:** confirmed via [actions/runs/28193174223](https://github.com/vladm3105/aidoc-flow-operations/actions/runs/28193174223)
  — operations docs-sync run from PR #134 merge: trigger ✓ auth ✓
  setup ✓ 3 op scripts ✓ "no proposals" detection ✓ → count step ✗
  (the bug this fix closes).
- This is the **first real-world validation of the alpha.1 skeleton**
  on a live consumer — exactly what Phase A dry-run pilots are for.
  Operations bumps its caller pin to `@ci/v1.1.0-alpha.2` in a
  follow-up PR; next natural fire will validate the fix.

### Added

- **`docs/multi-project-guide.md`** — explicit documentation of the
  three-layer architecture: `aidoc-flow-ci` as company-wide CI
  library; per-project governance repo (one per company project);
  per-consumer config + optional overrides. Onboarding flow for
  new company projects (create project's governance repo →
  bootstrap each consumer via `install.sh` → per-project overrides
  as needed). Per-project decision boundaries enumerated (what
  stays per-project vs what library owns). Documents the
  long-implicit "all future company projects" framing from
  [IPLAN-0017-CHARTER §1](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017-CHARTER_aidoc-flow-ci.md#1-purpose).
- **`docs/architecture.md` §0** — new "two-repo architecture
  (library vs project-governance)" section at the top of the doc.
  Concrete artifact-placement matrix for library / project-governance
  / consumer layers. Cross-references the new
  [`multi-project-guide.md`](docs/multi-project-guide.md).
- **`README.md`** "Who uses this" section — names current
  consumers (aidoc-flow-operations, aidoc-flow-framework on
  `@ci/v1.0.6`) + invites future company projects to use the
  onboarding flow in `docs/multi-project-guide.md`.
- **`docs/README.md`** — index updated to list the new
  `multi-project-guide.md`.

### Added

- **`.github/workflows/docs-sync.yml`** — new reusable workflow
  (alpha; first half of IPLAN-0018 implementation). Mechanical
  post-merge documentation fixer. Triggered by consumer caller on
  `push: branches: [main]`. Three operations (each disable-able
  via `.github/docs-sync.json`): CHANGELOG stub-entry on workflow
  changes; version-string propagation (alpha.1 stub — detection
  only; full regex-map in alpha.2); cross-ref dead-link repair
  (alpha.2). Belt-and-suspenders recursion guards (`[skip ci]` +
  `if: github.actor != 'aidoc-flow-bot[bot]'`). Dry-run mode by
  default (posts PR comment with proposed changes; no commits).
  Live-mode commit logic requires `AIDOC_FLOW_BOT_ID` +
  `AIDOC_FLOW_BOT_KEY` secrets + 🔴 founder-created `aidoc-flow-bot`
  App per IPLAN-0018 §3.4 (separate from `aidoc-reviewer` for
  separation of concerns). Concurrency-group serialized.
  SHA-pinned actions: `actions/checkout@v4.2.2`
  (`11bd71901bbe5b1630ceea73d27597364c9af683`) +
  `actions/setup-python@v6.2.0`
  (`a309ff8b426b58ec0e2a45f0f869d46889d02405`).
- **`install/templates/workflows/docs-sync.yml`** — caller template
  pinned at `@ci/v1.1.0-alpha.1`. Single template (works for both
  PRIVATE + PUBLIC). Documents prerequisites (founder creates App
  + sets secrets) + the rollout phases per IPLAN-0018 §3.7
  (operations pilot dry-run for 1 week → live → framework opts in
  → Phase C consumers).
- **`install/templates/docs-sync.json`** — per-consumer config
  template. Ships with `dry_run: true` by default (mandatory for
  first 1-2 weeks per §3.7 P3). Three operation kill-switches
  (`changelog_stub.enabled`, `version_sync.enabled`,
  `cross_ref_repair.enabled`). Allowlisted commit-target paths
  (`CHANGELOG.md`, `README.md`, `docs/**`, `*.md`) per the §3.5
  threat model commit-content allowlist.

### Targeting `ci/v1.1.0-alpha.1`

This release ships the IPLAN-0018 SKELETON — workflow body + caller
template + config template. Operations adopts in dry-run mode for
~1 week per the §3.7 P3 graduation criteria; live-mode commit
logic + full operation implementations land in `ci/v1.1.0-alpha.2`
after operations pilot validates the skeleton. Stable `ci/v1.1.0`
ships after operations pilot graduates to live mode (≥5 merges
with zero proposed-vs-applied file-set divergence).



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
