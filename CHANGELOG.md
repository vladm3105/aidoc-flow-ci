# Changelog — aidoc-flow-ci

Notable releases of the shared CI library. SemVer per `ci/vX.Y.Z`
tags (independent of framework spec semver per IPLAN-0017 §6 Q2).

## Unreleased

### Testing — `markdown-lint`'s blocking default is now asserted (PLAN-019 FT-41, G1 tag-cut blocker)

- The three report-only scanners (dep-scan / trivy / sast) assert their *callers*
  ship `fail-on-findings: false`, but the **inverse** invariant — the
  `markdown-lint` reusable blocks by **default** (`fail-on-findings` input
  `default: true`) — was unasserted. Flipping that default to `false` left
  `tests/test_contract.sh` at 271/0, so canon could silently turn every consumer's
  markdown gate report-only with the suite green.
- `test_contract.sh` now parses the reusable's `fail-on-findings` input default
  (via `yaml.safe_load`, handling PyYAML's bare-`on:`→`True` key) and asserts it is
  `True`. A flip to `false` goes red (`contract` 271 → 272 assertions).

### Testing — the FT-28 SHA-peel guard is now driven, not re-implemented (PLAN-019 FT-40, G1 tag-cut blocker)

- The FT-28 guard (both `ai-review.yml` resolvers verify a SHA-form pin's SHA IS
  the commit of its claimed tag, so a `@<fork-sha> # ci/vX.Y.Z` cannot fetch and
  execute never-merged code) was **untested**: `tests/test_resolver.sh` re-
  implemented the comparison in a local `verify()` and otherwise made grep-presence
  assertions, so mutating the shipped guard to `if false;` in both resolvers left
  the suite at 62/0 — the gate could be disabled undetected.
- Both guards are now wrapped in extractable `# >>> FT28-PEEL-VERIFY >>>` markers
  (comment-only — **no runtime behaviour change**) and driven from the test with
  `curl` stubbed to return a chosen tag-commit SHA: a matching SHA is accepted, a
  mismatched SHA and an unreachable tag (empty peel) are rejected, and a tag-only
  pin skips the peel — for **each** resolver (review + autofix). The `verify()`
  re-implementation is deleted.
- Teeth confirmed: `if false;` in both guards, and neutering the SHA equality
  check, each turn the suite red (`resolver` 62 → 70 assertions).

### Fixed — `install.sh` fetch validation + `--update` no-TTY consent (PLAN-019 FT-39, G1 tag-cut blocker)

- **`fetch_template` wrote whatever the transport returned.** `curl -f` rejects a
  4xx/5xx, but a proxy, CDN, or captive portal can answer 200 with an **empty** or
  **HTML** body — which was then written over a canon gate template, silently
  0-byting a required check. A new `validate_fetched` helper (in extractable
  `# >>> FETCH-VALIDATE >>>` markers) rejects an empty body or one that opens with
  an HTML-document tag (`<!doctype`/`<html`/`<head`/`<body`/`<title`, matched on a
  bounded whitespace-stripped prefix so a large body is never slurped whole, and
  narrow enough not to false-fire on a markdown template opening with `<!--`);
  every `fetch_template` call and the `--update` per-file fetch now validate once,
  fail loud, and abort/skip rather than commit garbage.
- **The pre-commit fragment's refresh could fail open (FT-32).** A truncated or
  pre-`v2` fragment passed the empty/HTML check but made `marker_version()` read
  `1`, silently freezing every legacy consumer's refresh. The fragment fetch now
  asserts the versioned `^# CANON: aidoc-flow-ci pre_push_check v[0-9]+` marker
  before the file is trusted for the version compare.
- **`--update` inferred consent to replace from a missing TTY.** `[ ! -t 0 ]` was
  read as `--non-interactive`, so a piped run (`bash <(curl …) --update`) silently
  overwrote every customized `safe_to_replace` caller with the canon body. A
  missing TTY now defaults to **keep-local**; the destructive auto-replace
  requires an explicit `--non-interactive`.
- `tests/test_install.sh` gains Part 5 (15 assertions): the validator is extracted
  from `install.sh` and driven against empty / HTML / leading-whitespace-HTML /
  `<!--`-markdown / marker-less bodies; three separate mutations (removing the
  empty/HTML checks, removing the marker check, reverting the no-TTY default) each
  turn the suite red.
  `tests/test_precommit_refresh.sh` stubs `validate_fetched` (defined outside the
  PRECOMMIT-MERGE markers) to keep isolating the version-compare decision.

### Docs — body-adoption reconciliation + the drift report as the rollout worklist (PLAN-018 Workstream D items 2-3)

- `docs/UPDATE_GUIDE.md` gains **"Body adoption vs re-pin"**. `--repin` and
  `--update` are not two strengths of one operation: `--repin` changes only the
  `@ci/vX.Y.Z` string, while `--update` replaces the **body** of all 16
  `safe_to_replace` surfaces (the 15 workflow callers + `dependabot.yml`) and
  discards every per-repo `runner_labels_*`, `permissions:`, trigger and tuned
  input. None of that fails at update time — it fails on the next PR, as a job
  stuck in `queued` or a `startup_failure` with zero jobs. Documents the live
  case (`framework` pins `runner_labels_*: '"ubuntu-latest"'` against canon's
  self-hosted array) and a reconciliation gate on the resulting diff.
- Corrects the `ci/v2.0.0` migration quick-reference, whose step 4 recommended
  `--repin` **then** `--update`. That migration is secrets + config + a pin bump
  and does not need body adoption; the unconditional `--update` was the exact
  hazard FT-9 already paid for once.
- `docs/UPDATE_GUIDE.md` gains **"Reading the drift report as the rollout
  worklist"** — per CI-0013 canon completes first and consumers roll out after,
  so pre-rollout `DRIFT` is expected signal. Sorts findings into deliverable /
  deliberate / not-yet-provisioned and names the four known permanent-drift
  members, so the next operator does not "fix" drift by weakening canon.
- Completes **PLAN-018 Workstream D** (item 1 shipped in #265).

### Fixed — the canon pre-commit fragment is refreshable in adopted consumers (PLAN-018 FT-32, Workstream D)

- An adopted consumer was **frozen forever**: bootstrap no-op'd on the `CANON:`
  marker, `--update` excludes `.pre-commit-config.yaml` from the manifest walk, and
  `--apply` writes no content files — so no canon path could deliver a fragment
  change, and `manifest.json`'s "re-run `install.sh` to refresh those" was **false**
  for that file. F3's commit-stage hooks reached new adopters only.
- The marker is now **versioned** (`# CANON: aidoc-flow-ci pre_push_check vN`,
  canon at **v2**). Bootstrap **re-merges** when a consumer's `vN` is older than
  canon's and stamps canon's version, so the next run no-ops. This makes the
  documented "re-run install.sh" path real rather than adding a second one
  (`--refresh-hooks` was the alternative and was rejected for that reason).
- The re-merge is additive and, for the `local` pseudo-repo, **de-duped by hook
  `id`**: a legacy consumer receives the canon hooks it lacks without a duplicate
  of one it already carries. (The first cut duplicated `aidoc-flow-pre-push` on
  every legacy consumer — caught by testing the refresh end-to-end.)
- **The refresh delivers ADDITIONS ONLY** — new repo entries and new hook ids in
  canon's `local` block. A `rev` bump, or a new hook id inside a repo the consumer
  already declares, is **reported as a `WARN` and left unapplied** so their entry
  is never clobbered; a partial merge still stamps `vN` (it must, to converge) and
  says on stdout that the named lines stay unapplied. Four fleet repos pin
  `pre-commit-hooks` at a mutable `rev: v5.0.0` that the refresh therefore cannot
  move to canon's SHA — per-repo items on the rollout worklist, not delivered.
  Full matrix in `docs/REPO_STANDARDS.md` §14.1a.
- **BUMP `vN` whenever the fragment changes**, or adopted consumers stay frozen.
  `tests/test_precommit_refresh.sh` (new) drives the decision block extracted from
  `install.sh` across the version matrix — no-marker, legacy, equal, newer,
  two-digit — plus convergence, wrapper preservation and the anchored marker
  parse; `test_precommit_merge.sh` continues to guard the merge output. The
  earlier suite passed with the freeze restored by mutation, which is why the
  decision now has its own cover.
- Canon dogfoods v2 in its own `.pre-commit-config.yaml` (CLAUDE.md Wave-0 rule).
- **This unblocks CI-0013's "drift report becomes the rollout worklist"** — the
  fleet-rollout phase now has a mechanism behind it.

### Triage — FT-10 (runner-self pool-nickname in docs) already resolved

- Verified the nickname-as-registration usage FT-10 was filed for is gone: every
  `runner-self` mention across `docs/` + `LABELS.md` now frames it as the retired
  placeholder to avoid (no doc tells a reader to register/target it), and the
  `["self-hosted","ci-runner","single-use"]` (CI-0007) labels are canonical. No
  change needed; ledger marked resolved. This closes **PLAN-018 Workstream B**.

### Fixed — adopter-facing gaps in the wizard + deployment docs (PLAN-018 FT-25, Workstream B)

- **labeler config was installable by no path.** The `labeler` caller uses
  `configuration-path: .github/labeler.yml`, but the starter `labeler.yml` template
  was never copied — a scaffolded labeler ran against a missing config. The wizard
  `scaffold` now drops the starter when labeler is chosen (operator customizes it).
- **`deploy-ci-wizard.sh preflight`** now surveys **all** canonical labels from
  `labels.json` (was a hardcoded 5 of 18), and reads `/actions/permissions` and
  branches on `allowed_actions` instead of masking a 409 from the selected-actions
  endpoint as `unreadable/all-allowed`. Because canon reusables use `actions/*` +
  `github/*` internally, "green" requires more than the aidoc-flow-ci reference
  being reachable: `local_only` (blocks GitHub-authored actions) and `selected`
  **without** `github_owned_allowed` both `startup_failure` and are now flagged
  🔴, not passed as OK — the one check guarding that mode.
- **`verify`** short-circuits when the caller is not yet on the default branch: the
  `pull_request_target` / `workflow_run` gates resolve their definition from the
  default branch, so on the PR that first *adds* them they do not run — the poll
  used to burn 24×25s matching nothing. It now names the two-PR adoption shape.
- **`AI_CI_DEPLOYMENT.md`** step 2 now tells private adopters to use the `-private`
  variant (naming the FT-9 brick) instead of the single-template advice that
  predates the `-private` variants.

### Fixed — `skip-ai-review` no longer opens a zero-review merge window (PLAN-018 FT-29, Workstream B)

- `composition` is INERT (passes green) until `vars.APP_REVIEWER_1_BOT_ID` is set,
  and the branch-protection templates pair `call / composition` with
  `required_approving_review_count: 0`. During partial provisioning (App secrets
  set, bot-id var pending) the `skip-ai-review` label made `ai-review` conclude
  SUCCESS while INERT `composition` also concluded SUCCESS — **both required
  checks green, zero review, zero approvals.**
- The `ai-review` skip-notice step's `label` branch now **fails closed** when
  `vars.APP_REVIEWER_1_BOT_ID` is unset: `skip-ai-review` carries a prior approval
  forward, but only `composition` can have counted one, and it is inert until the
  App is armed — so the skip is a fiction. `call / ai-review` goes red instead of
  green, closing the window regardless of how branch protection was armed. The R3
  and review-event skips are unaffected (they only fire when the App has approved
  at HEAD). `test_contract.sh` guards it.

### Fixed — `ai-review` now verifies a SHA-form pin against its claimed tag (PLAN-018 FT-28, Workstream B)

- Post-FT-15 the resolver accepts a `@<40-hex> # ci/vX.Y.Z` pin and fetched
  review/fixer assets from the SHA, but **never checked the trailing tag against
  it** — and `raw.githubusercontent` serves any commit reachable in the public
  canon repo, including never-merged fork-PR commits, while the comment reads as
  the released version in code review. Both resolvers (review + autofix) now peel
  the claimed tag via the commits API and **hard-fail on a SHA/tag mismatch**, so
  a misleading `# ci/vX.Y.Z` cannot execute code the tag does not point at. The
  notice prints the actual fetch ref + "(SHA verified against tag)".
- Inert for shipped consumers — the caller template pins tag-only, so the check
  only arms for the SHA-form pin. `test_resolver.sh` guards it (structure +
  accept/reject teeth).

### Changed — least-privilege on the AI-flow callers (PLAN-018 FT-27, Workstream B)

- The privileged callers handed a tag-referenced reusable **every** repo secret
  via `secrets: inherit`. Now each passes exactly what its reusable declares:
  `composition-{private,public}` drop the block entirely (composition reads only
  the automatic `GITHUB_TOKEN`); `doc-maintainer` / `docs-sync` /
  `auto-merge-ai-prs-{public,private}` pass explicit `secrets:` maps.
  `test_contract.sh` guards each, and documents the one deliberate exception —
  `ai-review`, whose reusable declares no `secrets:` block, so it still needs
  `inherit` (its explicit-map conversion is a tracked follow-up needing reusable
  changes + its own security review).
- `actions-permissions.json` defaults `can_approve_pull_request_reviews` to
  **false**. GitHub bundles create+approve into that one toggle; it is needed only
  by the opt-in bot-PR flows and is a standing bypass if
  `required_approving_review_count` is ever raised. Flip it in the bot-PR adoption
  runbook, not by default.

### Fixed — `codeql.yml` autobuild pinned the tag object, not the peeled commit (PLAN-018 FT-26, Workstream B)

- `autobuild` pinned the annotated **tag object** `21eb7f78…` (v4.36.1) while
  `init`/`analyze` correctly used the peeled **commit** `87557b9c…`. The tag
  object 422s on GitHub's commits API and trips the workspace's mandatory SHA
  audit — the canary that catches fabricated pins. Repinned to the commit
  (verified by peeling the tag ref via the git API). `test_lint.sh` now asserts
  all three `codeql-action` steps pin one commit, so the drift cannot recur.
- Documented that **private repos require GitHub Advanced Security** (in the
  reusable header and the wizard `plan` output) — without it `codeql-action/init`
  errors outright, and a hard error is the intended signal (no fork/GHAS guard).

### Triage — FT-14 (yamllint hook stricter than CI) already resolved

- Verified the `pre_push_check.sh` yamllint / CI-gate mismatch was fixed when a
  root `.yamllint.yaml` was added on `2026-07-17`; the hook now uses the same
  relaxed profile as `tests/test_lint.sh`. No change needed; the FT ledger entry
  is marked resolved.

### Added — `scripts/release.sh`: release sequencing tool (PLAN-018 FT-21, Workstream C)

- Encodes the prep → merge → dry-run → tag ordering that was tribal knowledge and
  that the `ci/v2.9.0` cut got wrong three ways. `release.sh prep <ci/vX.Y.Z>`
  creates the prep branch and does the VERSION bump (with a trailing newline —
  FT-36), `sync-version-refs.sh`, and CHANGELOG promotion; it runs the suite and
  distinguishes the **one expected-red** (version-sync's latest-tag assertion,
  which the tag will clear) from a real failure.
- `release.sh tag <ci/vX.Y.Z> --dry-run-verified` refuses to cut unless it is on
  up-to-date `main`, `VERSION` on the tree **already equals** the version (guards
  the v2.9.0 mistake of a tag pointing at the old version), and the
  `--dry-run-verified` flag is present — the 🔴 FT-30 cold-start dry-run gates the
  cut and the script cannot run it for you. It then tags `HEAD`, pushes, and
  `gh release create --latest` from the CHANGELOG section.
- Chicken-and-egg (the prep PR's self-pins reference a tag that cannot exist yet)
  handled per FT-21 **option (a)** — the expected one-red-run is documented, not
  worked around with a mutable `@main` pin. `tests/test_release.sh` drives every
  guard rejection; `docs/RELEASE_CHECKLIST.md` points at the tool.

### Added — canon dogfoods its own markdown-lint gate, blocking (PLAN-018 FT-34, Workstream C)

- `.github/workflows/self-markdown-lint.yml` runs canon's root `.markdownlint.json`
  through the `markdown-lint` reusable on every PR, **blocking** (`fail-on-findings`
  default true). Canon shipped the gate + the config template but ran neither on
  itself — the "no exerciser for canon's own output" root cause behind F1. Canon
  now self-runs **5** of its 16 reusables (was 4).
- Canon carries its own root `.markdownlint.json` (identical to the shipped
  template) and its docs were brought into **full conformance** with it in the
  same change: 347 findings under that config → 304 auto-fixed by
  `markdownlint-cli2 --fix`, 43 fixed by hand (code-fence languages, `|`
  escaped inside table-cell inline-code, `<placeholder>` tokens backticked,
  wrapped `#NNN` issue-refs that read as H1 rejoined, two malformed tables).
- **Shipped template change (consumer-facing):** `install/templates/.markdownlint.json`
  gains `"MD004": { "style": "dash" }`. Without a pinned style, `--fix` normalizes
  bullets to the unconventional `+`; pinning `dash` gives conventional `-` bullets
  for every consumer. This is a template-only change (no reusable body change, no
  `ci/` tag bump — §4.4).
- **Correction to an earlier measurement:** the "174 MD013 findings" cited when
  scoping this were measured against markdownlint's *default* config. Canon's
  actual shipped standard has `MD013` (line-length) **off**, so no line reflow was
  needed; the real work was structural.

### Added — canon self-runs its own `pre-commit` gate (PLAN-018 FT-36, Workstream C)

- `.github/workflows/self-pre-commit.yml` — a caller that runs canon's
  `.pre-commit-config.yaml` through the `pre-commit` **reusable** on every PR.
  Until now canon shipped the reusable but never ran it on itself — the "no
  exerciser for canon's own output" root cause behind F1/F3. Canon now self-runs
  4 of its 16 reusables (was 3).
- Dogfooding immediately found a non-conformance in canon's own tree: `VERSION`
  lacked a trailing newline (`end-of-file-fixer`). Fixed; all VERSION readers
  strip whitespace so it is inert to resolution, and the release checklist now
  says to write `VERSION` with a newline so a future prep does not reintroduce
  the failure.
- Public repo → `ubuntu-latest` (a fork-code lint flow must stay there, never the
  self-hosted pool). Pinned to the released tag; `sync-version-refs.sh` keeps the
  pin in step with `VERSION`.

### Added — required-context ↔ producer validator (PLAN-018 FT-18, Workstream C)

- `install/required-context-map.py` DERIVES, for every required status-check
  context in every branch-protection tier template, the CONSUMER caller that must
  be installed to produce it — the general form of F2 ("a required context has no
  producing workflow, so arming pins every PR forever"). The chain is derived,
  never hand-maintained (a hardcoded table is the F1 failure mode): context →
  reusable job-name → caller template `uses:` → manifest consumer path. It
  correctly resolves the non-obvious `call / verify` → `audit-trail.yml` (via the
  `audit-trail-check` reusable, a different basename).
- `deploy-ci-wizard.sh preflight` §6 diffs that map against the repo's installed
  workflows and reports, **per tier**, any required context whose producer is not
  installed — so an operator sees "arming at ops would hang: `call / gitleaks`
  needs `secret-scan.yml` (not installed)" *before* arming, not at first-PR time.
- `tests/test_required_contexts.sh` (21 assertions) asserts the **canon
  invariant** — every required context in every tier resolves to a producer, or
  the test is red (F2 latent in canon itself) — plus the non-obvious chains and
  teeth (removing the `secret-scan` caller templates orphans `call / gitleaks`).
  Complements `test_checknames.sh`, which checks the prior link (context → real
  reusable job).

### Added — zero-hook detector (PLAN-018 FT-31, Workstream C)

- `install/check-precommit-hooks.sh` — the general form of F3. It parses a
  `.pre-commit-config.yaml`, counts hooks that run at the stage the `pre-commit`
  reusable actually selects (the `pre-commit` default, when `run-stage` is empty),
  and **exits 1 when that count is zero** — the case where the required
  `call / Lint / format / security hooks` check passes while inspecting nothing.
  Exit 0 = real check; exit 2 = cannot determine (missing file / no PyYAML), never
  a false clean. Stage resolution follows pre-commit's own rules (per-hook
  `stages`, else top-level `default_stages`, else every stage), so both the
  explicit `stages: [pre-push]` and the `default_stages: [pre-push]` + stageless
  vacuous shapes are caught (the latter verified against pre-commit itself).
- **Operator-side only, by design.** It runs in `install.sh` (post-merge, as a
  prominent advisory that never aborts a working install), in
  `deploy-ci-wizard.sh preflight` (🔴 on a vacuous config), and as a
  `docs/RELEASE_CHECKLIST.md` pre-tag step. It is deliberately NOT on the
  `pre-commit` reusable's gating path: a detector there would flip any consumer
  running `run-stage: manual` with no `manual` hooks from pass to fail on re-pin,
  which CI-0013 does not authorize (§14.1a). Config-parsing, not the
  output-emptiness heuristic F3 rejected.
- `install.sh` **fetches** the detector (like a template) rather than assuming a
  local sibling, so it works under the `bash <(curl …)` one-liner too; a fetch
  failure silently skips the advisory rather than failing the install. One source,
  three call sites.
- `tests/test_precommit_stage.sh` drives it: exit 0/1/2 across the canon fragment,
  a pre-push-only (vacuous) config, an unstaged hook, the legacy `commit` stage,
  and missing/unparseable/non-mapping inputs; plus the reusable's default-stage
  behaviour extracted from the workflow so the detector's premise can't drift.

### Added — exerciser inventory + completeness guard (PLAN-018 Workstream C, contract 7)

- `docs/EXERCISER_INVENTORY.md` maps every consumer-facing surface canon ships —
  16 reusable workflows, the `manifest.json` config/governance surfaces, the
  canonical scripts, and the one third-party dependency — to the thing that
  **exercises** it: a self-caller, an offline test, or an explicit
  `unexercised — FT-NN` / `descoped — <reason>` record. F1 shipped broken for
  nine releases because a surface had no exerciser and the gap was silent; this
  makes the set explicit. Canon self-runs **3** of its 16 reusables today
  (`audit-trail-check`, `docs-sync`, `secret-scan`); the rest are covered offline
  or descoped, each with a reason.
- `tests/test_exerciser_inventory.sh` keeps it complete: **every `manifest.json`
  surface, every `workflow_call` reusable, and every canonical script must have a
  row**, and every `unexercised` row must name its closing FT (or be explicitly
  `accepted`). A new template added without a row fails the suite — the F1
  failure mode (an untracked surface) caught at introduction. Teeth verified: a
  phantom manifest surface and an orphan `unexercised` row each fail it.
- Records the founder scope decision (2026-07-22): the `ai-review` /
  `doc-maintainer` / `composition` self-callers are **descoped** for this library
  repo (they would need a self-hosted pool + reviewer App purely to dogfood); the
  resolver risk they would have covered live is carried offline by
  `test_resolver.sh`. FT-23 is scoped down accordingly.

## ci/v2.11.0 — 2026-07-22

PLAN-018 Workstream A — the cold-start onboarding path, broken for nine releases
and now fixed end-to-end (F1 → F7). MINOR: the bootstrap set gains the
`pre-commit` caller and the canon fragment gains commit-stage hooks (additive
consumer surfaces); no breaking input/schema changes.

### Fixed — `deploy-ci-wizard.sh` silently scaffolded callers 14 releases back (PLAN-018 F7)

- The wizard resolved its canon tag as
  `CI_TAG="$(cat …/VERSION 2>/dev/null | tr -d … || echo 'ci/v1.9.5')"`. That
  `|| echo` was **not** dead code: under `set -euo pipefail` a missing or
  unreadable `VERSION` makes `cat` exit 1, the pipeline exit 1, and the fallback
  **fire** — so the wizard scaffolded callers pinned to `ci/v1.9.5` while
  `VERSION` said `ci/v2.10.0`, green and silent. (Two prior reviews called this
  `||` dead because they read it and did not run it; execution is what corrected
  the diagnosis.)
- Now fails loud, carries no literal:
  `CI_TAG="$(tr -d '[:space:]' 2>/dev/null < …/VERSION)" || CI_TAG=""` then a
  `[ -n "$CI_TAG" ]` guard that exits 2. The `2>/dev/null` precedes the `<`
  redirection because under `set -e` the redirection failure is reported before
  the assignment's `2>/dev/null` would apply — the natural ordering dies before
  reaching its own guard.
- `tests/test_version_sync.sh` now covers the wizard too, by **executing** the
  shipped resolution block against missing / whitespace-only / good `VERSION`
  (not by re-reading its source), and asserts no literal `ci/v*` survives in the
  resolution. Teeth verified against the restored fallback.

### Fixed — the LiteLLM HTTP flag and the runner pool were missing from `install.sh` next-steps (PLAN-018 F4)

- The next-steps block listed secrets and branch protection but never the two
  prerequisites that hang or hard-fail a cold start:
  - **the runner pool** — probed now, **visibility-independently**. The ai-review
    template is visibility-uniform and pins the self-hosted pool for public repos
    too, so a public adopter with no pool gets permanently-queued jobs just like
    a private one; `timeout-minutes` starts at job *start*, so a never-started
    job never times out. Gating the probe on `VISIBILITY=private` would reproduce
    the anti-pattern the AI-flow routing avoids.
  - **`litellm_allow_insecure_http`** — `litellm_client.py` hard-fails unless the
    proxy is HTTPS or the flag is set, and it ships commented out. The workspace
    proxy is HTTP on the docker bridge, so adopters of it must uncomment it.
- **Output only.** `install.sh` does *not* uncomment the flag: `ai-review.yml` is
  `safe_to_replace`, so a later `--update --non-interactive` would re-comment it
  and the gate would go red — a breaking regression, not a silent weakening.
  Whether canon should ship the flag enabled by default is a security default for
  `DECISIONS.md`, not a side effect of this fix.

### Fixed — the wizard gave new public and private adopters different `markdown-lint` gates (PLAN-018 F6)

- The report-only injection (`fail-on-findings: false`) lived inside the wizard's
  `[ ! -f <variant> ]` branch, so a **public** adopter (no `markdown-lint-public.yml`)
  got report-only while a **private** adopter (a `-private.yml` exists) got a
  blocking gate — even though both templates ship the flag commented out and carry
  the same rollout recommendation. A pure wizard asymmetry driven by which variant
  files happen to exist.
- Fixed **in the wizard conditional**, scoped to `wf == markdown-lint`, so both
  visibilities get report-only and no other single-template workflow is affected.
  The shipped templates are untouched: uncommenting the flag in
  `markdown-lint-private.yml` would let `--update --non-interactive` silently flip
  `business` / `iplanic` / `interlog` — which deliberately graduated to blocking
  (PLAN-007 W3) — back to report-only. Graduating a repo stays FT-11's per-repo,
  deliberate act.

### Release note — `docs-sync` caller grants `pull-requests: write` (PLAN-018 F5)

- The `pull-requests: write` fix on `install/templates/workflows/docs-sync.yml`
  (its dry-run `gh pr comment` 403s with `read`) ships with this tag. It is **not**
  a cold-start fix — `docs-sync` is `auto_install: false` and the wizard flags it
  as legacy for new v2 adopters — but already-adopted repos have been hitting the
  403 silently. No new code; it is the release that carries the already-merged
  template change to a tag.

### Added — release checklist gains the 🔴 cold-start dry-run (PLAN-018 FT-30)

- `docs/RELEASE_CHECKLIST.md` pre-tag step: before cutting a tag that changes
  `install.sh`, the bootstrap set, or the pre-commit fragment, the founder runs
  `install.sh` against a throwaway repo and confirms it completes through labels.
  Canon cannot self-exercise a cold start — that is how F1 lived nine releases —
  so this is the gate that would have caught it. The runbook **must** export
  `CI_TAG=<merge-sha>`, or it validates the previous release's templates.

### Fixed — the required lint check had no producer (PLAN-018 F2, BLOCKER)

- `install.sh` auto-installed only `ai-review` + `composition`, but
  `call / Lint / format / security hooks` — emitted by the `pre-commit` caller —
  is a required status check on **every tier that has required checks at all**
  (all but umbrella, which deliberately has none) and is the bootstrap tier's
  **only** required context. Arming protection after a successful install
  therefore pinned every PR on *"Expected — Waiting for status to be reported"*
  forever. A required check with no producing workflow does not fail — it never
  reports, which is why this presents as a hang rather than a red check.
- **`pre-commit` is now bootstrapped unconditionally**, not gated on `--tier`.
  `TIER` defaults to empty and the documented one-liner passes none, so a
  tier-gated fix would leave the primary documented path without a producer.
  Because the context is required on every tier that requires anything,
  unconditional installation is the minimum that satisfies any of them; on
  umbrella the caller is simply advisory.
- Deliberately **narrow**: the installer does not become tier-aware, and the
  install set is not extended to the union each tier's protection template
  requires. `auto_install: false` remains the rule for every other non-bootstrap
  surface, with adoption via `deploy-ci-wizard`.
- **Doc surfaces this falsified, all corrected here** rather than left
  contradicting the code: `manifest.json`'s `auto_install` on the pre-commit
  entry; `install/README.md`'s "the additional caller templates … `pre-commit.yml`
  … are **not** bootstrapped automatically"; and its step 2 "Drops the default
  callers `ai-review.yml` + `composition.yml` (per-visibility templates)", which
  F2 falsifies on the caller list and F1 already falsified on "per-visibility".
- `--verify-standards` now names this class instead of folding it into generic
  drift: when a `branch-protection.contexts` difference is reported it adds a
  note that a required check may have no producing workflow. **Report string
  only** — the mode is standalone with no clone, so it cannot enumerate the
  consumer's installed workflows; the automated required-context ↔ emitted-check
  diff is the wizard validator (FT-18).

### Fixed — the canon pre-commit fragment yielded a green check that linted nothing (PLAN-018 F3, BLOCKER)

- The `pre-commit` reusable runs `pre-commit run --all-files` with **no**
  `--hook-stage` when `run-stage` is empty (its default), which selects the
  `pre-commit` stage. The canon fragment's only hook was `aidoc-flow-pre-push`
  with `stages: [pre-push]` — **zero hooks matched, and the run exited 0**. So a
  fresh adopter's only required gate passed while inspecting nothing, by
  construction. Repos with a pre-existing rich config (`operations`) masked it; a
  cold start could not.
- The fragment now ships commit-stage hooks — `check-yaml`, `end-of-file-fixer`,
  `trailing-whitespace` from `pre-commit/pre-commit-hooks`, **SHA-pinned** at
  `3e8a8703264a2f4a69428a0aa4dcb512790b2c8c  # frozen: v6.0.0` (SHA resolved from
  the upstream tag ref and all three hook ids confirmed present at it before
  pinning). A tag would have been mutable state on infrastructure this workspace
  does not control, and `pre-commit` `pip install`s the cloned tree — so the
  upstream build backend runs at install time, on developer machines and on the
  cold-every-run ephemeral CI pool. Canon SHA-pins every `uses:` for the same
  reason. Bump with `pre-commit autoupdate --freeze`; a plain `autoupdate`
  silently reverts it to a tag.
- **Two costs, stated rather than glossed.** (1) This is canon's first
  third-party `rev` — the fragment was `repo: local` only, with no network and no
  upstream to track. Accepted because the alternative is canon maintaining its own
  linters. The rev has no automated bump path (FT-35). (2) The merge now de-dups
  by **repo URL**, not whole-entry structural equality: an adopter already using
  `pre-commit-hooks` at a different `rev` was structurally unequal, so the old
  rule appended a second entry for the same repo. On a URL collision the
  consumer's entry and rev are **kept** and the collision is reported, naming any
  canon hook ids they lack.
- **A correction to the first draft of this entry:** it claimed `pre-commit`
  *rejects* duplicate entries. It does not — verified on 4.5.1, duplicate URLs at
  different revs and even duplicate hook ids all give `validate-config` rc=0 and
  run. Four sibling repos ship two `repo: local` blocks in production today. The
  de-dup is for coherence, not validity, and the false premise mattered: it made
  collapsing `repo: local` look correct when it silently dropped canon's own
  `aidoc-flow-pre-push` hook (see below).
- **`local` and `meta` are exempt from URL de-dup — they are pseudo-repos, not
  identities.** Keying on them treated a consumer's own `local` block as a
  collision and never installed `aidoc-flow-pre-push`, dropping the OPS-0069
  audit-trail check — permanently, since the `CANON:` marker makes every later
  run a no-op. Caught in pre-push review by two independent reviewers; 4 of 8
  workspace siblings would have hit it, including the only currently-unmarked
  consumer. Now covered by `tests/test_precommit_merge.sh`.
- **Wave-0 self-adoption, hand-applied.** This repo's `.pre-commit-config.yaml`
  already carries the `CANON:` marker, so `install.sh`'s merge no-ops here and
  would never deliver the hooks. Adding them immediately found real defects in
  canon's own files — 4 files carried trailing whitespace or a missing final
  newline (whitespace-only fixes, included here).
- **Already-adopted consumers do not receive these hooks**, and that is a known
  defect, not an oversight: bootstrap no-ops on the marker, `--update` excludes
  `.pre-commit-config.yaml`, and `--apply` writes no content files, so the
  fragment is un-upgradeable in an adopted repo (FT-32). Adding these lines flips
  those repos to `DRIFT` under `apply-standards.sh --check` — expected signal and
  the rollout worklist per CI-0013, not breakage. It is a report, not a gate; no
  workflow invokes `apply-standards.sh`. Until FT-32 lands, F3 reaches new
  adopters only.
- **Detecting this class in general stays OFF the gating path.** `pre-commit run`
  exits 0 and prints nothing whether zero hooks matched or all hooks passed, so
  the only in-reusable implementation is an output-emptiness heuristic — and it
  would flip any consumer running `run-stage: manual` with no `manual` hooks from
  pass to fail on re-pin. The detector belongs operator-side (FT-31).

### Added — `tests/test_install.sh` Part 4: the fragment must select hooks at the reusable's stage

- Asserts the **property**, not the hook ids: at least one hook in the canon
  fragment runs at the default `pre-commit` stage (a hook with no `stages:` key
  runs at every stage, so it counts). Counting lives in
  `tests/lib_count_stage_hooks.py`.
- Also asserts the premise it depends on, extracted from the workflow rather than
  restated: the reusable's empty-`run-stage` branch runs bare, with no
  `--hook-stage`. If that ever changes, this says so out loud.
- **Teeth verified:** restoring the pre-F3 fragment (pre-push hook only) fails
  the stage count; making the reusable's default branch pass `--hook-stage` fails
  the premise check.
- The manifest set-equality check added with F1 did the work it was built for —
  flipping `pre-commit`'s `auto_install` and adding the installer stanza had to
  land together, and the suite went 49 → 55 assertions with no edit to the test.

### Fixed — cold-start `install.sh` fetched a template deleted at `ci/v2.2.0` (PLAN-018 F1, BLOCKER)

- The bootstrap loop derived its caller templates as
  `workflows/<workflow>-<visibility>.yml`, so a private install requested
  `workflows/ai-review-private.yml` — a file removed when PLAN-013 unified the AI
  flows into one protected template. `fetch_template` returns 1 on a failed
  `curl` and the call site is `|| exit 1`, so **the documented one-liner died on
  its first fetch**, before `config.json`, CODEOWNERS, `CLAUDE.md`,
  `pre_push_check.sh`, the pre-commit merge, and all 18 labels. Every fleet
  consumer adopted before `ci/v2.2.0`, and canon (already adopted) never runs its
  own cold start — so it shipped undetected across nine releases.
- **Each template is now named explicitly**, not derived. Canon ships three
  naming shapes, not one convention: `ai-review` has no variants; `composition`
  suffixes both; `pre-commit` is **asymmetric** — its public variant is the bare
  name, so generalising from `composition` yields `pre-commit-public.yml`, which
  does not exist, and reproduces the same 404 for every public adopter. New
  `docs/REPO_STANDARDS.md` §16.9 records the table and the two constraints.
- Deliberately **not** manifest-driven: `manifest.json` is fetched only inside
  `update_mode`, which returns before bootstrap runs. Wiring it in would add a
  network fetch, a parse, and a new hard-failure mode to the cold-start path to
  replace a hardcoded string.

### Added — `tests/test_install.sh`: regression cover for cold-start template resolution

- **The obvious test would not have caught F1.** "Every `auto_install: true`
  manifest entry's template exists" passes — the ai-review entry resolves to
  `workflows/ai-review.yml`, which exists and always did. The manifest was never
  wrong; `install.sh` was. So this suite checks the *installer's own* resolution,
  then checks it against the manifest.
- Four parts: (0) every `fetch_template` template argument is a **literal** — the
  load-bearing form constraint, since a `TEMPLATES[$wf]` lookup would restore the
  derivation and disarm everything below; (1) every literal resolves under
  `install/templates/`; (2) the caller block is **extracted from `install.sh`
  between `BOOTSTRAP-CALLERS` markers and evaluated** under both visibilities with
  `fetch_template` stubbed, then checked against `manifest.json` **in both
  directions** — each resolved template equals the `visibility_variants`
  resolution for its consumer path, *and* the installed caller **set** equals the
  manifest's `auto_install: true` workflow entries; (3) the three naming shapes
  asserted against the template files. Containment (no `.github/workflows/`
  install outside the markers) is a numeric line-range test, and both markers must
  appear exactly once.
- **Both directions are load-bearing.** Name-matching catches an existing-but-
  *wrong* variant (a `-public` template on a private install) that file-existence
  alone does not. Set-matching catches a caller being **dropped** — deleting a
  stanza leaves nothing behind for a name check to inspect, so the first revision
  of this suite passed with zero failures when the whole `composition` install was
  removed. That is the shape of the sibling blocker F2 (the bootstrap set omits
  the `pre-commit` caller whose check is required on every tier but umbrella).
- **The block is evaluated, never re-implemented** — a test carrying its own copy
  of the naming table passes happily while the installer rots. It is sourced under
  the same `set -euo pipefail` as `install.sh`.
- **Teeth verified**, per this repo's `test_negative.sh` discipline. Each mutation
  below was applied and the suite confirmed to fail on it: the pre-fix derivation
  restored (part 0, plus part 2 naming `ai-review-private.yml`);
  `composition-public.yml` swapped into the private branch; the entire
  `composition` stanza deleted; a stray duplicate call outside the markers
  carrying a trailing comment; two calls sharing one line to hide a derived
  argument behind a greedy match; the end marker removed; a call outside the
  markers wrapped on a backslash continuation; a block statement failing *after*
  both installs. The rule documented in an `install.sh` comment must *not* trip
  containment — verified as a negative.
- **Forward-compatible with F2's fix, and verified so.** Adding a `pre-commit`
  stanza without flipping its manifest `auto_install` fails; flipping the manifest
  without adding the stanza fails; doing both together passes. The two halves of
  that change are coupled by construction.
- **Extraction is over logical lines, not physical**, and every occurrence on a
  line is examined. Both were live holes in the first revision: a greedy
  `sed` match let a second call on the same line hide a derived argument, and a
  backslash-wrapped call yielded a destination of `\` that skipped containment
  entirely while *adding* two green assertions.
- **The sandbox's exit status is asserted, not discarded.** Calling the evaluator
  as `if eval_block …; then` silently defeated its own `set -euo pipefail` —
  running a function in a condition disables `-e` for its entire body, the same
  trap `install.sh` documents for `update_mode`. The rc is now captured from a
  bare call.
- **Known limit, recorded in §16.9 rather than implied away:** containment sees
  only `fetch_template` calls with a literal `.github/workflows/…` destination. A
  variable destination, or a `curl -o`/`cp`, is invisible to it. Set-equality
  backstops only what is **inside** the markers — a caller installed outside them
  in either of those forms is caught by nothing. Two residual extractor evasions
  (a comment line ending in `\`; a trailing `\` on the file's last line) are
  logged in `plans/FRAMEWORK-TODO.md`.

### Added — `tests/test_resolver.sh`: regression cover for the canon-pin resolver

- The resolver is the mechanism **FT-15** broke, and it went undetected for months
  across every consumer. Canon cannot execute `ai-review`/`doc-maintainer` in its
  own CI (FT-23), so a regression there would ship unseen again. 55 assertions
  across all four reusables: plain and commented-SHA pin forms, foreign owner
  rejected, commented-out lines ignored, `*.yml.bak` leftovers unable to win the
  version sort, pre-release captured whole (not truncated), and filename-keying
  (one reusable's pattern never matches another's pin).
- **Patterns are extracted from the live workflows, never copied into the test** —
  a test carrying its own copy of the regex passes happily while the real one rots.
- **Teeth verified**, per this repo's `test_negative.sh` discipline: removing the
  owner anchor, and separately dropping the pre-release capture (the exact FT-15
  truncation bug), each make the suite fail.
- Records one deliberate asymmetry: `ai-review` is a **single-file** resolver (no
  checkout by design), so it has no directory scope and the `--include` property
  does not apply — asserted explicitly rather than cargo-culted.

### Fixed — `standards-drift` resolver brought to the §4.2a property list (FT-22)

- **`standards-drift.yml`** pioneered "resolve the tag from the consumer's own
  pin" but predated five of the rules that grew out of FT-15. It now matches
  `docs-sync`: `uses:`-line + `*.yml`/`*.yaml` scan scope (a `*.yml.bak` leftover
  could previously win the version sort), both pin forms, fail-closed on multiple
  distinct pins, pre-release rejected, `grep` exit ≥2 distinguished from no-match,
  and fetch-at-the-SHA. Its `--ci-tag` now follows the executed ref too — the
  script uses it purely as a raw-URL ref, so a SHA-pinned caller compares against
  the templates it actually ran.
- `docs/REPO_STANDARDS.md` §4.2a's "do not copy `standards-drift.yml` as-is"
  warning is removed — both resolvers are now conformant exemplars.
- **Owner-anchor applied across all 6 resolver sites** (`ai-review` ×2,
  `doc-maintainer` ×2, `docs-sync`, `standards-drift`). §4.2a documented this rule
  but no resolver implemented it: the pattern began at `aidoc-flow-ci/…`, so a pin
  naming a *different* owner's `aidoc-flow-ci` matched and resolved that fork's
  tag while the fetch hardcoded `vladm3105` — silently mixing sources. Now such a
  pin fails loud instead. Anchoring only some would have created fresh drift, so
  the sweep covers every site and the documented rule is finally true.

### Fixed — `docs-sync` caller template grants `pull-requests: write` (consumer-facing)

- **`install/templates/workflows/docs-sync.yml`** granted `pull-requests: read`,
  but the reusable's **dry-run** path posts its proposed edits as a PR comment
  (`gh pr comment`), which needs `write`. A callee cannot grant its own
  permissions. The job therefore failed 403 **exactly when it had something to
  report**, and was green only when idle. Every consumer inherited this; it went
  unnoticed because no consumer had yet produced a non-zero `proposed`.

### Added — canon self-adopts `docs-sync` (FT-23)

- **`.github/workflows/self-docs-sync.yml`** + **`.github/docs-sync.json`**
  (dry-run): canon ran none of the reusables it ships, so a change to them could
  not be exercised here at all — the blind spot that let FT-15 reach every
  consumer. The released reusable now runs on canon's own pushes and emits the
  resolved-pin `::notice::`. Per `CLAUDE.md`, Wave 0 self-adopts before Wave 1+
  consumers pull. **Scope:** verifies the *released* reusable post-merge, not a
  PR's own change — `uses:` forbids expressions, so that needs a local-path
  PR job (FT-23 follow-up). `version_sync` is deliberately disabled: canon
  already propagates VERSION via `scripts/sync-version-refs.sh`, wired to
  pre-commit and asserted by the suite — strictly stronger than a post-merge pass.

## ci/v2.10.0 — 2026-07-21

Minor: closes **FT-15** — the adopted `@ci/vX.Y.Z` pin now actually controls the
assets fetched by all three affected reusables (`docs-sync` → `doc-maintainer` →
`ai-review`). (`standards-drift` resolves from the caller pin already and never
floated, but its resolver predates the §4.2a property list — tracked as FT-22.) Confirmed live 2026-07-21 that it did **not**: a
consumer pinned `@ci/v2.0.1` logged `fetching assets from
vladm3105/aidoc-flow-ci@refs/heads/main`, because inside a `workflow_call`
reusable `github.workflow_ref` is the CALLER's ref — and its first path segment
is the CALLER's owner, so external adopters 404'd. Workflow *logic* was always
correctly pinned by GitHub; only the curl-fetched **assets** floated.

**Consumers must re-pin to get the fix**, and two caller-surface requirements are
new: a pin the resolver cannot read now hard-fails (instead of silently fetching
`main`), and **pre-release (`-rc.N`) pins are unsupported**. All current consumers
use plain semver pins, and none wraps a canon reusable inside its own
`workflow_call` (which would defeat `ai-review`'s locator — see §4.2a's install
constraint) — so there is no live impact. Rule: `docs/REPO_STANDARDS.md` §4.2a;
plan: `plans/PLAN-017_ft-15-pinned-asset-fetch.md`; verification runbook:
`plans/ROLLOUT_plan017-verify.md`.

### Fixed — `ai-review` resolves the adopted canon pin (FT-15 PR-C, PLAN-017)

- **`ai-review.yml`** — both sites (the `ai-review` review job and the `autofix`
  job) now resolve the canon tag from the consumer's adopted pin and hardcode
  `vladm3105/aidoc-flow-ci`, completing FT-15 across all three reusables.
- **This job has no `actions/checkout` by design** (IPLAN-0024 — a 5-cycle
  sparse-checkout saga proved checkout *was* the failure mode), so unlike
  `docs-sync`/`doc-maintainer` it cannot grep the caller's file from disk. It
  instead uses `github.workflow_ref` as a **locator only** (caller owner/repo/path)
  and reads that file over the **API contents endpoint** at a **trusted,
  event-selected ref**: `pull_request_target` → the PR's base branch;
  `pull_request_review` → the repo's default branch; any other event → default
  branch. Its `@<ref>` component is **discarded**, so no caller-controlled value
  is security-load-bearing.
- **`autofix` resolves from the same trusted ref, not its PR-head checkout** —
  reading the pin from PR-authored content would let a PR downgrade its own canon
  tag. That step also previously had no token of its own; it now takes
  `GITHUB_TOKEN` explicitly for the caller-file read.
- Same hardening as PR-A/PR-B (both pin forms, fetch-at-the-SHA, fail-closed on
  ambiguity, pre-release rejected). Step name "…from the pinned ref" corrected —
  it was false.
- **From the pre-push review, each verified:** the infra-failure signal (label +
  PR comment) now also fires for failures *before* the reviewer runs — previously
  a pin/asset failure produced a bare red `ai-review` with no explanation, which
  authors reasonably misread as "the AI rejected my code"; the fetched caller
  workflow gets the same empty-body/wrong-shape guards as every other asset, so a
  transport fault is no longer misreported as "caller not installed"; the
  `workflow_ref` split uses `%%@*` so a branch name containing `@` cannot corrupt
  the path; `?ref=` is URL-encoded (branch names may contain `& # % +`); and
  `pull_request_target` with an empty base ref now hard-fails instead of silently
  falling back to the default branch (which could resolve a pin the PR's target
  branch never adopted — the FT-15 class again).
- **Completes** `docs-sync` ✅ → `doc-maintainer` ✅ → `ai-review` ✅ per
  `plans/PLAN-017_ft-15-pinned-asset-fetch.md`. Next per §5: cut `ci/v2.10.0`,
  then pilot a consumer re-pin to verify live (🔴 cross-repo).

### Fixed — `doc-maintainer` resolves the adopted canon pin (FT-15 PR-B, PLAN-017)

- **`doc-maintainer.yml`** — both sites (the `reconcile` and `maintain` jobs) now
  resolve the canon tag from the consumer's own checked-out pin and hardcode
  `vladm3105/aidoc-flow-ci`, instead of deriving ref **and owner** from
  `github.workflow_ref` (FT-15). Fetch URLs are byte-identical to before.
- **Resolver hardened, and the hardening back-ported to `docs-sync.yml`** so the
  §4.2a exemplar stays authoritative for PR-C. Three additions, each from review
  and each verified in a fixture:
  - **SHA-pinned callers now fetch at the SHA**, not the trailing
    `# ci/vX.Y.Z` comment. GitHub executes the reusable at the SHA while the
    comment can lag it, so trusting the comment ran one version's workflow with
    another version's assets — FT-15's class through the other pin form.
  - **Ambiguity fails closed**: more than one distinct pin now errors and lists
    them, rather than silently taking the highest (which could fetch a version
    the repo never adopted).
  - **`grep` exit ≥2 is distinguished from "no match"**, so an unreadable
    `.github/workflows/` is no longer misreported as "caller not installed".
- Second of three (`docs-sync` ✅ → `doc-maintainer` ✅ → `ai-review`) per
  `plans/PLAN-017_ft-15-pinned-asset-fetch.md`.

### Fixed — `docs-sync` resolves the adopted canon pin (FT-15 PR-A, PLAN-017)

- **`docs-sync.yml`** no longer builds its script-fetch URL from
  `github.workflow_ref`. Inside a `workflow_call` reusable that value is the
  **CALLER's** ref, so the adopted `@ci/vX.Y.Z` pin controlled neither the
  version (assets silently came from canon `main`) nor the owner (its first
  segment is the *caller's* owner, so external adopters 404'd). Confirmed live
  2026-07-21 — see FT-15. It now resolves the tag from the consumer's own
  checked-out `docs-sync` pin (both plain and commented-SHA forms, keyed to the
  workflow filename) and **hardcodes** `vladm3105/aidoc-flow-ci`. A missing pin
  now fails loud + INFRASTRUCTURE-classed rather than falling back to `main`,
  and the resolved tag is echoed as a `::notice::`.
- **Resolver hardening** (from the pre-push review, each verified reproducible):
  the scan is limited to `*.yml`/`*.yaml` **and** real `uses:` lines — otherwise
  a `*.yml.bak`/`*.disabled` leftover or a commented-out example can supply the
  tag and *win* the version sort; **pre-release pins are rejected explicitly**
  rather than silently truncated (`ci/v2.10.0-rc.1` → `ci/v2.10.0` would be a
  real but different tag once it ships); and an unreadable
  `.github/workflows/` is reported distinctly so the error can't misdiagnose a
  correctly-installed caller. The script fetch also gained `--retry 3`
  (availability only, matching `standards-drift.yml`).
- **`docs/REPO_STANDARDS.md` §4.2a** codifies the rule for every reusable that
  fetches cross-repo assets.
- **Consumer-visible:** a caller whose pin the resolver cannot read now
  hard-fails instead of silently fetching `main`; **pre-release (`-rc.N`) pins
  are unsupported** (the pattern would prefix-match to a nonexistent tag). All
  current consumers use plain semver pins — no live impact.
- First of three (`docs-sync` → `doc-maintainer` → `ai-review`) per
  `plans/PLAN-017_ft-15-pinned-asset-fetch.md`. **Consumers must re-pin to get
  the fix.**

## ci/v2.9.0 — 2026-07-20

**PLAN-016: runner reference implementation in canon (CI-0012) + pre-tag
review fixes.** The implementation satisfying the
`[self-hosted, ci-runner, single-use]` label contract moves into this repo at
`install/templates/runner/` — digest-pinned image spec (**+`libatomic1`**,
root-fixes the markdownlint/node crash class), one-shot supervisor (+docker
preflight vs the orphan-JIT hot-loop; `GH_TOKEN_STRIP` knob), placeholder
systemd unit (`@RUNNER_HOME@`/`@DOCKER_BIN@`; `provision-runner.sh` is the
sole installer), canon-clean provisioning. Operations is the first vendored
consumer (re-stamps to this tag). Full 5-lens pre-tag `ci-preprod-review`
ran → SHIP-WITH-FIXES → all fixes landed (#230). Deferred hardening: FT-19
(container egress; founder risk-accept pending), FT-20 (defense-in-depth).
PRs #226/#227/#229/#230 + operations #277; decision CI-0012; plan
`plans/PLAN-016_runner-canon-templates.md`.

### Fixed — pre-tag ci-preprod-review fixes (5-lens review, SHIP-WITH-FIXES → fixed) (2026-07-20)

Pre-tag review (security / correctness / docs / portability / governance
lenses, all findings source-verified): `run-ephemeral.sh` gains a docker
preflight before JIT minting (a dead daemon previously hot-looped orphan
runner registrations every ~2s) and a `GH_TOKEN_STRIP` knob (default 1;
headless PAT-auth adopters set 0 — the strip was unconditional and silently
401'd them); `ci-runner@.service` `ExecStartPre` docker path is now
substituted at provision time (`@DOCKER_BIN@` — `/usr/bin/docker` broke
rootless installs); `provision-runner.sh` `--target-repo` flag un-deadened
(required-var assertion moved after arg parse) + docker-on-PATH fail-fast;
`build-image.sh` gains `GH_VERSION` override passthrough; docs: runners.md
digest-pinned prose corrected (claimed `:latest`), `ripgrep` documented,
root README ships-list gains the runner templates, env-knob table completed
(`RUNNER_WORKDIR`/`GH_HOST`/`GH_TOKEN_STRIP`), multi-checkout caveat.
Deferred with FT entries: FT-19 container-egress restriction (founder
risk-accept pending), FT-20 defense-in-depth (JITCONFIG via env → stdin,
job-container disk quota, provision preflight). NOTE: canon runner files
changed → operations re-pins at the W4 tag cut (headers already say
re-stamp).

### Docs — FT-16..18 automation weak layers recorded from the outage arc (2026-07-20)

`plans/FRAMEWORK-TODO.md` gains FT-16 (runner-fleet watchdog — wedged
supervisor queued 16 jobs ~3h with zero alerting), FT-17 (post-v2-cutover
verification of ai-review INFRA-class failures + bounded auto-recovery),
FT-18 (wizard required-context↔check-name validator; the guard for FT-12's
class). PR #229.

### Added — runner reference implementation in canon (PLAN-016 W1–W2) (2026-07-20)

- `install/templates/runner/` — the implementation that satisfies the
  `[self-hosted, ci-runner, single-use]` label contract, moved from the
  private operations repo (where the public adopter docs 404'd):
  digest-pinned `Dockerfile` (**adds `libatomic1`** — fixes the
  markdownlint/node crash class, business #63), `build-image.sh` (+ libatomic
  verification), `run-ephemeral.sh` (logic unchanged; comments genericized —
  same-directory paths, no operator LAN details in public canon),
  `ci-runner@.service`
  (**`@RUNNER_HOME@` ExecStart placeholder — raw `cp` no longer supported**),
  `provision-runner.sh` (canon-clean: `TARGET_REPO` required, final-label
  default, substitutes the placeholder at install; the only documented
  installer). `ci-network-monitor.*` deliberately NOT templatized
  (operations host diagnostics).
- `docs/runners.md` — every operations reference repointed in-repo (§2
  reframed, §7 routing table; two deliberate operations-side carve-outs:
  network monitor + activation log); wizard pool hint now names the template
  path; dependabot gains a `docker` watch on the canon Dockerfile
  (direction of truth: canon leads, consumers re-pin).
- Decision: `DECISIONS.md` CI-0012. Plan: `plans/PLAN-016_runner-canon-templates.md`
  (17-citation ledger, 7 independent review passes). Operations re-baselines
  as the first vendored consumer in its own follow-up PR (PLAN-016 W3).

### Docs — value + company-standard-readiness assessment (2026-07-19)

- `plans/ASSESSMENT_flow-ci-value-and-standard-readiness.md` — evidence-based
  pre-deployment evaluation: the AI-review core is the differentiated, proven
  value (caught a critical CI-bricking bug on operations #244); the rest is
  commodity/governance-overhead. Deploy the ~3 value flows selectively; **not yet**
  worth mandating as a company standard (5-gate readiness scorecard). No canon
  code change — assessment only.
- **FT-15 elevated to a trust-blocker** — confirm the deployed ai-review is
  actually version-pinned (not fetching from `main`) before widening deployment.

## ci/v2.8.0 — 2026-07-19

**PLAN-015 pre-prod review fix closure.** Closes the 5-lens pre-prod review's two
blockers — **B1** (fleet rollout-target reconciled to a single tag, `ci/v2.8.0`)
and **B2** (a consumer-installable `standards-drift` detector + `install.sh` that
honestly verifies server-side standards instead of a silent reminder) — plus the
M1–M5 / L-series follow-ups (decision-log closure, script hygiene, install
ergonomics, doc-count accuracy). Additive over `ci/v2.7.0`; consumers re-pin per
`plans/ROLLOUT_plan015-arming.md` (🔴 founder). PRs #209–#217.

### Fixed — doc counts match shipped reality (PLAN-015 Task 7 / M5, 2026-07-18)

- **`README.md`**: "12 reusable workflows" → **16** (added the `dep-scan` /
  `trivy-scan` / `sast-scan` scanner rows + the `standards-drift` detector to the
  catalog table — the count was stale by the PLAN-014 scanners and PLAN-015 B2).
- **Label count "16" → "18"** in `install/README.md` (enumeration gains the two
  omitted `ai:review-infra-error` + `ai:autofix-escalated`) and
  `docs/AI_CI_DEPLOYMENT.md` (×2). `LABELS.md` corrected: "canonical 17" → **18**
  (×2, incl. the References line), its group-1 header "(7)" → "(8)" (it already
  listed 8), and a new **workflow-provisioned labels** section documents
  `ai:enforcer-failed` (the auto-merge enforcer self-provisions it; NOT in the
  installer-created 18).
- **The rest of the reusable-count family** (the pre-push review's F2): `docs/WORKFLOWS.md`
  catalog header "14 reusables" → **16** and the missing `standards-drift.yml`
  row ADDED to the catalog (README pointed readers there); `docs/README.md`
  registry "12" → **16**; `docs/REPO_STANDARDS.md` registry "12" → **16**. The
  applicability-matrix "12 workflows" is kept (it genuinely covers the 12 **core**
  columns; the 4 opt-in scanners/detector aren't matrixed) and clarified as such.

### Added — install ergonomics (PLAN-015 Task 6, 2026-07-18)

- **`install/templates/.yamllint.yaml`** (M4): a consumer yamllint profile
  (120-char, prose-relaxed) — companion to the pre-push hook's yamllint check.
  `install.sh` copies it on bootstrap if absent (preserve-if-exists); manifested
  (`auto_install: false`, `safe_to_replace: false`) for `--update` coverage.
  Without it a consumer that has yamllint gets the 80-char default, which floods
  SDD prose YAML (~300 errors measured on a fresh consumer).
- **`install.sh` tool-presence note** (L2): flags missing `shellcheck` /
  `actionlint` at install time (non-fatal) — those two pre-push checks silently
  SKIP without the tools. `docs/local-pre-push.md` §5 gains per-platform install
  instructions (apt / brew / `go install`).
- **`install/templates/workflows/ai-review.yml`** (L5b): the caller comment's
  blanket "never checks out PR head" claim now notes the default-off autofix job
  exception (checks out head with a read-only token, `persist-credentials: false`,
  never executes PR code — CI-0009).
- **L1 dropped** (confirm-first): a `codeql-private.yml` variant is unnecessary —
  the `codeql.yml` reusable's `runner_labels` input already lets a private
  consumer pass the self-hosted pool, and CodeQL SARIF upload on private needs
  GitHub Advanced Security (absent on the fleet), so the variant would fix a path
  no private consumer reaches. `sast-scan` (CI-0010) is the private SAST substitute.

### Fixed — script hygiene (PLAN-015 Task 5, 2026-07-18)

- **`scripts/pre_push_check.sh`** (M3): the mechanical linters now scan the push
  range `@{upstream}..HEAD` (fall back to `origin/main` on the first push), not
  `merge-base(HEAD, main)...HEAD`. The old base re-linted every pre-existing branch
  commit on every push, so a push touching only file A was blocked by stale lint on
  files B/C from earlier commits (the audit-trail phrase check already used the push
  range; the file list now matches it).
- **`install/set-litellm-secrets.sh`** (L3): `--mint` no longer passes the LiteLLM
  master key (mints all others) via `curl -H` argv, where any local process-table
  reader could see it. It is written to a `0600` temp file with the `printf` builtin
  (never on an argv) and read via `curl -H @file`, honoring the script's STDIN-only
  contract.
- **`.github/workflows/audit-trail-check.yml`** (L5): removed the header comment's
  false "`pull_request_target` if a consumer knowingly wires it" claim — the job's
  `if:` runs only on `pull_request`, so a `pull_request_target` wiring silently
  SKIPS the gate; and since the job checks out the PR head sha, wiring it that way
  would be the classic untrusted-checkout RCE. Comment now matches the `if:`.
- L4 (a proposed "delete dead redaction helpers" in `litellm_client.py`) was
  investigated and **dropped as invalid**: `redact_secret_shaped` / `restore_redactions`
  are actively used by `scripts/doc-maintainer/{planner,apply}.py` (the review that
  flagged them only checked ai-review's `completion()`).

### Changed — `install.sh` verifies server-side standards instead of a silent reminder (PLAN-015 B2 Task 3, 2026-07-18)

- `install.sh` no longer just PRINTS "after CI green, apply branch protection." When
  given `--tier <t>`, a bootstrap now runs `check-standards-drift.sh` against the target
  repo at the end and reports the **actual** server-side state — `✅ clean` /
  `⚠️ NOT APPLIED (drift/absent)` / `⚠️ could not verify (token lacks admin scope)` — so
  "installed" never reads as "standards on." Closes the pre-prod review's B2-apply half
  (the silent-success gap).
- New standalone mode `install.sh <owner/repo> --verify-standards --tier <t>` (no install):
  exits `0` clean, `1` on genuine drift/absent branch protection, `2` when the `gh` token
  lacks admin scope to read protection. Usable as a founder/CI gate.
- `install.sh` still does NOT mutate consumer branch protection — that stays the
  🔴 founder arming step (Task 8 runbook); this task makes the *verification* honest.
- Live-verified against unprotected canon: correctly reported "no protection on main" →
  NOT APPLIED, exit 1.

### Added — consumer-installable `standards-drift` detector (PLAN-015 B2, 2026-07-18)

- `.github/workflows/standards-drift.yml` is now a **`workflow_call` reusable**: it
  fetches `sync/check-standards-drift.sh` from the **adopted canon tag** — read from
  the consumer's own checked-out caller pin, since inside a reusable
  `github.workflow_ref` is the caller's ref (not the pin) and `github.job_workflow_sha`
  is not expression-accessible — and runs the server-side drift check against the
  CALLER repo (branch protection, repo settings, actions permissions, labels vs the
  tier template). Warning-only by default (IPLAN-0017 §3.1b); `strict: true` for a
  release/adoption gate.
- Consumer caller templates `install/templates/workflows/standards-drift{,-private}.yml`
  (`auto_install: false`, opt-in via the wizard / the arming runbook), manifested with
  `visibility_variants`. Closes the pre-prod review's **B2** finding that no consumer
  ever ran drift detection — only canon did, against itself.
- Canon's own weekly self-check + the fleet pin audit moved to the new
  `.github/workflows/standards-drift-self.yml` (canon ships the script locally — no
  fetch path). `deploy-ci-wizard.sh` surveys `standards-drift` (opt-in, wave 8).
- Branch protection is only verifiable with an admin-scoped token (not a grantable
  `GITHUB_TOKEN` scope) → the default token reports it `warn_uncheckable`, never a
  false green.
- Additive from the consumer contract (no repo called the old non-reusable
  `standards-drift.yml`) → next MINOR, `ci/v2.8.0`.

### Changed — `deploy-ci-wizard` knows the PLAN-014 scanner surfaces (2026-07-18)

- `install/deploy-ci-wizard.sh` now surveys `dep-scan`/`trivy-scan`/`sast-scan` in its
  coverage report and documents them in the deployment `plan()` as **optional,
  report-only, opt-in** surfaces (deliberately NOT in `scaffold()`'s default list — the
  founder passes them explicitly, so adoption stays per-repo, not a force-sweep). The
  existing single-template scaffold path already handles them (pin normalized;
  `runner_labels`/`fail-on-findings` are baked, so the injector correctly skips).
- Preflight pool-check corrected for PUBLIC repos: the uniform-protected AI-flows
  (ai-review review job) + PLAN-014 scanners run self-hosted **even on public**, so a
  public repo adopting those surfaces needs a `ci-runner`/`single-use` pool too — the
  wizard no longer implies "PUBLIC → no self-hosted pool needed."
- Wizard-only change (no reusable/schema touched) → no new `ci/` tag; the wizard scaffolds
  scanner callers pinned at the current `VERSION` (`ci/v2.7.0`).

## ci/v2.7.0 — 2026-07-18

### Added — `sast-scan` deterministic autofix PREVIEW (semgrep `--autofix`, no push) (PLAN-014 Phase 4, 2026-07-18)

- **New `autofix-preview` input on `sast-scan.yml`** (default false) — when true, after
  the scan it ALSO runs `semgrep scan --autofix` in the ephemeral workspace and surfaces
  the resulting **deterministic, rule-provided** patch in the job summary. This is the
  one *safe* autofix path (PLAN-014 §4a): semgrep's fixes come from the rules (NO model),
  and they are applied only to the `--rm` workspace, which is **discarded after the job —
  nothing is pushed**. A human (or the armed PLAN-012 autofix App) applies the patch.
- **Preview-only by design.** Pushing a fix back to the PR head needs the dedicated
  autofix App (default-off, founder-gated — PLAN-012); this flow deliberately does NOT
  push, so it needs no App and is immediately usable. The step is `continue-on-error`
  (a preview must never fail the scan gate) and fork-guarded (inherits the job guard).
  The PR-controlled diff is rendered as a 4-space INDENTED block (not a ``` fence) so a
  crafted context line cannot break out and forge job-summary markdown (pre-push review nit).
- Caller template exposes `autofix-preview: false` (opt-in; a second semgrep pass roughly
  doubles the job time). WORKFLOWS.md, security.md §3c, and contract-test invariants.

Net semver MINOR — additive, opt-in, no push / no new credential. Completes PLAN-014
Phase 4 of 5 (remaining: Phase 5 — graduate each scanner's `fail-on-findings` false→true,
a per-scanner founder step after a clean window).

## ci/v2.6.0 — 2026-07-18

### Added — SAST gate `sast-scan.yml` (semgrep), report-only (PLAN-014 Phase 3, 2026-07-18)

- **New reusable `.github/workflows/sast-scan.yml`** — a SAST (static code analysis)
  gate via **semgrep**. semgrep is the OWN SAST complementing native CodeQL
  (`codeql.yml`) — CodeQL needs GitHub Advanced Security and is N/A on private repos,
  so this **gates PRIVATE repos too**. semgrep is PyPI-distributed (NOT a static
  binary, unlike gitleaks/osv-scanner/trivy — PLAN-014 §3), so it installs via a
  **VERSION-pinned pip** (`semgrep==1.170.0`) into an isolated venv (no marketplace
  action; canon allowlist §4.3).
- **Data-only, privacy-preserving:** semgrep is static AST analysis — it never
  executes the scanned code. **`--metrics off`** sends NO telemetry to semgrep.dev
  (important for private repos; note `--config auto` is incompatible with metrics-off,
  so an explicit ruleset is used). An **EXPLICIT `--config`** (default `p/default`,
  a `config` input) is used — never repo-local auto-discovery — so a PR **cannot
  inject its own rules**; the ruleset is fetched from the semgrep registry (trusted,
  not PR-controlled). semgrep exits 0 on a successful scan; findings come from the
  SARIF, and a non-zero exit is an infrastructure/tool error (fails loud), never a
  silent pass.
- **Gate-controls-coverage (folded from pre-push security review, verified):** semgrep
  ALWAYS honors a repo-root `.semgrepignore` independently of `--config`, so a PR
  committing `.semgrepignore` with `*` would cover zero files → a silent green →
  SAST-gate bypass (empirically confirmed). The scanned PR must not decide what the
  gate skips, so any PR-supplied `.semgrepignore`/`.semgreprc` is stripped before the
  scan (semgrep falls back to its built-in defaults). A missing or unparseable SARIF
  after a zero exit is likewise treated as an infrastructure error (fails loud via
  `jq -e`), never a false "no findings."
- **Uniform protected + fork-guarded (PLAN-013 / PLAN-014 §1a):** ONE self-hosted
  caller template — public AND private, no `-public`/`-private` split (a flip is a
  no-op); a fork PR skips the scan. Best-effort SARIF → Code scanning; ships
  report-only (`fail-on-findings: false`). No `secrets: inherit` (least privilege).
- Manifest entry (single template, no `visibility_variants`), WORKFLOWS.md catalog
  (15 reusables), security.md §3c, and contract-test invariants.

Net semver MINOR — additive, opt-in (`auto_install: false`), report-only. PLAN-014
Phase 3 of 5 (semgrep `--autofix` — the one safe autofix path — to follow).

## ci/v2.5.0 — 2026-07-18

### Added — IaC/misconfiguration gate `trivy-scan.yml` (trivy config mode), report-only (PLAN-014 Phase 2, 2026-07-18)

- **New reusable `.github/workflows/trivy-scan.yml`** — an IaC / Dockerfile
  **misconfiguration** gate via the **trivy binary** (SHA-256-verified tarball install
  per REPO_STANDARDS §4.3; NOT a marketplace action). Runs **`trivy config` mode
  ONLY** — deliberately not `trivy fs`, which would duplicate `dep-scan` (osv-scanner,
  deps) and `secret-scan` (gitleaks, secrets) (PLAN-014 §7 D-2).
- **Data-only, SSRF-hardened:** restricted to the STATIC misconfig scanners
  (`--misconfig-scanners dockerfile,kubernetes,cloudformation,azure-arm`). Trivy's
  terraform/helm/ansible scanners **fetch remote sources from PR-controlled fields**
  (a `.tf` `module { source = "https://…" }` makes the runner git-clone an
  attacker-chosen URL — SSRF/egress from the self-hosted pool); those are disabled.
  (`--tf-exclude-downloaded-modules` does NOT fix this — it only drops findings; trivy
  still fetches. Verified.) Findings are derived from the SARIF content; a non-zero
  trivy exit is an infrastructure/tool error (fails loud), never a silent pass.
- **Uniform protected + fork-guarded (PLAN-013 / PLAN-014 §1a):** ONE self-hosted
  caller template — public AND private, no `-public`/`-private` split (a flip is a
  no-op); a fork PR skips the scan. Best-effort SARIF → Code scanning; ships
  report-only (`fail-on-findings: false`). No `secrets: inherit` (least privilege).
- Manifest entry (single template, no `visibility_variants`), WORKFLOWS.md catalog
  (14 reusables), security.md §3c, and 13 contract-test invariants.

Net semver MINOR — additive, opt-in (`auto_install: false`), report-only. PLAN-014
Phase 2 of 5 (semgrep SAST + safe-autofix to follow).

## ci/v2.4.0 — 2026-07-18

### Added — dependency-vulnerability (SCA) gate `dep-scan.yml` (osv-scanner), report-only (PLAN-014 Phase 1, 2026-07-18)

- **New reusable `.github/workflows/dep-scan.yml`** — a Software Composition Analysis
  gate powered by the **osv-scanner binary** (SHA-256-verified `run:` install per
  REPO_STANDARDS §4.3; NOT a marketplace action). **Data-only, enforced** with
  `--no-call-analysis=all` (osv-scanner's Go call-analysis compiles source by
  default — it is opt-*out*), so the scan strictly reads manifests/lockfiles and
  never executes code. Emits SARIF; gates via `fail-on-findings` (default **false**
  — report-only). A zero-coverage scan (no manifests found) is a visible warning and
  fails a blocking gate unless `expect-manifests: false`.
- **Uniform protected + fork-guarded (PLAN-013 / PLAN-014 §1a):** ONE self-hosted
  caller template — public AND private, no `-public`/`-private` split (a visibility
  flip is a no-op). A fork PR **skips** the scan (forks are human-reviewed via
  ai-review; fork code never runs on the self-hosted pool); non-fork (collaborator)
  PRs + pushes to main scan on self-hosted.
- **Best-effort SARIF → GitHub Code scanning** (`continue-on-error`,
  `github/codeql-action/upload-sarif`) — lands on public repos with free GHAS,
  no-ops on private (compliance rides on the gate, not the Security tab). Dependency
  *remediation* is Dependabot's (isolated infra); dep-scan is the gate, not the fixer.
- Manifest entry (single template, no `visibility_variants`), WORKFLOWS.md catalog
  (13 reusables), security.md §3c, and 12 contract-test invariants.

Net semver MINOR — additive, opt-in (`auto_install: false`), report-only. First of
PLAN-014's phased scanners (trivy + semgrep + safe-autofix to follow).

## ci/v2.3.0 — 2026-07-18

### Added — ai-review autofix (PLAN-012): the reviewer can commit a fix and re-review, default-off (2026-07-18)

- **`.github/workflows/ai-review.yml`:** a new gated `autofix` job. When the reviewer
  returns `request_changes`, it asks the model for a unified diff, applies it with a
  hard governance deny-floor, and pushes it to the PR head via a **dedicated autofix
  GitHub App** (ephemeral installation token, `contents:write` — NOT a PAT). The push
  re-fires the gate → the reviewer re-reviews → converge or escalate at the round cap.
- **DEFAULT-OFF + heavily gated.** Runs only when: `auto_fix_ok` (author in
  `trust.auto_fix` AND not a fork — forks never reach it), `autofix.enabled` (resolved
  from the TRUSTED config, so a PR cannot self-enable), tier != spec, no
  governance-locked path changed, and the bot-commit round cap is not hit. Inert unless
  the dedicated App creds are set.
- **Security controls:** the model holds no push credential (model-call/apply and push
  are separate steps; the App token appears only in the push step); the deny-floor is
  checked both at diff-parse and post-apply (rejecting `.github/`, `governance/`,
  `*/governance/`, `framework/`, `templates/ai-review/`, and out-of-tree paths); the
  push is two-step (patch-export with no token → pristine clone + `git am` + push); any
  doubt escalates to a human (`ai:autofix-escalated`) — it never force-pushes a guess.
- **Config:** typed `autofix` schema (`enabled` bool, `max_fix_rounds` int 0–10,
  `max_budget_usd`); `autofix.enabled` + `autofix.max_fix_rounds` added to the
  trust-enforced set. New labels `ai:autofix-applied` + `ai:autofix-escalated` (18 total).
- **Secrets (opt-in):** `APP_AUTOFIX_ID`/`APP_AUTOFIX_KEY` (a SEPARATE App from the
  reviewer App — judge≠generator at the identity level), `LITELLM_FIX_API_KEY`, and the
  `LITELLM_FIXER_MODEL` repo var (default `ai-fixer`). Docs: `security.md §3b`.

Net semver MINOR — additive (new gated job, default-off; no consumer-facing break).

## ci/v2.2.0 — 2026-07-18

### Changed — uniform protected AI-flow model: AI-flows run self-hosted on public AND private, one template (PLAN-013, 2026-07-18)

- **`install/templates/workflows/`:** the AI-flow callers (`ai-review`,
  `doc-maintainer`, `docs-sync`) collapse their `-public`/`-private` variant pairs
  into **one protected template each** on `["self-hosted","ci-runner","single-use"]`
  — no visibility split, so a repo visibility flip (private↔public) is a **no-op**.
  Safe on public repos because a fork never reaches a job that executes PR code: the
  `ai-review` trust job checks out the trusted config repo (never the PR head) and
  runs zero PR code, the review job is `needs: trust`-gated and forks are never
  trusted, and `doc-maintainer`/`docs-sync` are post-merge. The **fork-code-running
  lint flows** (`markdown-lint`/`links`/`pre-commit`) deliberately KEEP their
  `-public`/`-private` split — they run fork PR files, so they must stay
  GitHub-hosted on public repos.
- **`install/templates/manifest.json`:** dropped `visibility_variants` for the three
  AI-flows (single protected template installs regardless of visibility).
- **`install/deploy-ci-wizard.sh`:** the label-injector now recognizes
  `runner_labels_routine`/`_review`, so it no longer injects a spurious bare
  `runner_labels:` into the single `ai-review` template (an undeclared reusable
  input → `startup_failure`).
- **Docs:** `security.md §3` rewritten (self-hosted-on-public is safe for the
  AI-flows; fork-code lint flows stay GitHub-hosted), `runners.md` routing table +
  §5a, `REPO_STANDARDS.md §4.1`, `CLAUDE.md` runner policy.
- **Tests:** flip-simulation (same template for both visibilities) +
  no-`visibility_variants`-on-AI-flows + wizard-injector regression assertions.

Net semver MINOR — template convergence + manifest; no consumer-facing interface
break (callers reference the reusable name, not the template filename).

## ci/v2.1.2 — 2026-07-17

### Changed — ai-review verdict budget raised 8192 → 24576 (PLAN-011 follow-up, 2026-07-17)

- **`scripts/litellm_client.py`:** the verdict-mode `max_tokens` default is now
  **24576** (was 8192). Live-probed: `deepseek-v4-pro` accepts far more (32768 and
  65536 both return HTTP 200), so the practical ceiling is this client's own
  32768 validator. A typical complex 45-file verdict uses only ~2.3k tokens, but
  reasoning-token counts spike non-deterministically — the extra headroom covers a
  heavy-reasoning spike on a near-400 KB diff. Costs nothing extra (per-actual-token
  billing; `finish_reason` is normally `stop`); `LITELLM_MAX_TOKENS` can still
  reach the 32768 cap. Verified end-to-end against the live model.

## ci/v2.1.1 — 2026-07-17

### Fixed — ai-review no longer fails opaquely on large diffs (PLAN-011, 2026-07-17)

Consumer bug: the required `ai-review` gate failed on large PRs with
`ResponseShapeError` → `exit 1`, blocking merge even when every other check was
green. Reviewer-infrastructure limitation, not a code finding. Two fixes (the
plan's independent review rejected two riskier ones — see below):

- **T1 — `scripts/litellm_client.py` + `ai-review.yml`:** the verdict `max_tokens`
  default was **4096** with no output-budget scaling, so a large diff's verdict
  JSON was truncated mid-object → parse failure. Verdict mode now defaults to
  **8192** (plain `--json` keeps 4096; `LITELLM_MAX_TOKENS` overrides both), and
  the verdict call passes `--timeout 900` as headroom for the longer completion.
  **Both numbers are PLACEHOLDERS gated on live pre-checks before the tag cut**
  (marked `PLAN-011 PC-1/PC-2` in the code): PC-1 confirms the model accepts 8192
  without a non-retryable HTTP 400 (which would red every PR); PC-2 measures the
  completion time. The strict parser is **unchanged**.
- **F4 — honest infra signal:** a `ResponseShapeError` used to surface as an
  opaque red check (the labelling Gate step is `success()`-gated, so it was
  skipped). A new step scoped to the verdict-client failure (via a step `id`, not
  a bare `if: failure()` that would double-post on asset/diff-fetch paths) now
  sets a new **`ai:review-infra-error`** label + an "infrastructure error, not a
  code finding, re-run" comment. The label is a **third mutually-exclusive**
  review-outcome state (`set_label` now cycles all three), so a re-review never
  shows `ai:review-passed` AND `ai:review-infra-error` at once. Fail-closed
  preserved — the required check stays red.
- **Rejected on security grounds (plan Pass-2 independent review):** mining
  `reasoning_content` (surfaces the model's draft chain-of-thought verdict) and
  first-balanced-object parsing (a prompt-injection surface — a diff-planted
  `{"decision":"approve"}` quoted before the real verdict would be extracted).
  `tests/test_scripts.sh` now LOCKS the strict parser: it fails red if anyone
  loosens `normalize_json_object` to accept prose-wrapped/multi-object output.
- **New label distribution:** `ai:review-infra-error` reaches a consumer on its
  next `install.sh` label step (or `gh label create`); until then the *comment*
  is the reliable infra signal (the label POST 422s silently on a repo missing
  it). Full design + the Claim ledger: `plans/PLAN-011_ai-review-large-diff-hardening.md`.

### Fixed — canon's pre-push hook now matches its CI yamllint profile (FT-14, 2026-07-17)

- **`.yamllint.yaml`** (new, repo root) + **`tests/test_lint.sh`**: canon's
  pre-push hook ran BARE `yamllint` (80-char default) and failed on canon's own
  `main` (179 line-length errors), while the CI gate runs a relaxed profile
  (`line-length: disable`, …). The hook already had a dead
  `if [ -f .yamllint.yaml ]` branch; this adds the file (activating it) and
  refactors `test_lint.sh` to read the same file instead of an inline `-d`
  duplicate — one source of truth for hook + CI. Canon-only (not shipped to
  consumers via the manifest); a consumer's own `.yamllint.yaml` remains its own
  concern.

### Fixed — remaining pre-prod correctness minors (M4 + L3, 2026-07-17)

- **M4 — `concurrency` added to the `audit-trail` + `codeql` callers.** They
  lacked it, so on the serial single-use private runner pool a stale run from a
  rapid re-push occupied a slot ahead of the live one. Added
  `group: ${{ github.workflow }}-${{ github.ref }}` + `cancel-in-progress: true`
  to the CALLERS (`.github/workflows/audit-trail.yml`,
  `install/templates/workflows/audit-trail-{public,private}.yml`, and the
  `codeql` consumer caller template) — **never the reusables**: a caller and its
  called workflow sharing a `concurrency.group` makes GitHub self-cancel the run
  (the pre-push review caught a first pass that wrongly put it on the `codeql`
  reusable). `audit-trail`'s reusable (`audit-trail-check.yml`) is untouched.
- **L3 — ai-review `tier` now fails CLOSED.** The auto-merge branch keyed on
  `tier == "spec"` exactly, so any other non-routine value (`Spec`, `governance`,
  a typo) fell through to auto-merge instead of human-merge. Changed to
  `tier != "routine"` — only `routine` auto-merges; everything else is
  human-merge. Latent today (no caller passes `tier`), armed the moment one does.

### Dogfooding — canon runs its own secret-scan gate (2026-07-17)

- **`.github/workflows/self-secret-scan.yml`** (new): canon now calls the
  `secret-scan` reusable on its own PRs, at the released `@ci/v2.1.0` tag. It
  shipped the gate to every consumer but never ran it on itself — the pre-prod
  G3 finding ("canon deploys 1 of 5 canon callers"). Separate filename because
  `secret-scan.yml` is the reusable; non-redundant with `tests.yml` (which lints
  but runs no gitleaks); verified clean at adoption (195 commits, no leaks). Also
  moves canon from 2 to 3 emitted checks, toward being safely self-protectable.

## ci/v2.1.0 — 2026-07-17

### Governance — repo records synced to reality; FT-5 correctly re-opened (2026-07-17)

- **`plans/FRAMEWORK-TODO.md` FT-5**: was marked RESOLVED (PLAN-007 W2) but the
  gap is live — `standards-drift.yml` grants only `contents: read`, so
  branch-protection/actions-permissions reads `warn_uncheckable`-skip and the
  drift check never verifies the settings PLAN-001 governs. The obvious fix
  (`administration: read` on the job) was attempted and **rejected by actionlint**:
  `administration` is not a grantable `GITHUB_TOKEN` scope, so those reads need a
  PAT/App token, not a permissions line. FT-5 re-opened with the real (🔴,
  secrets-provisioning) fix, folded into PLAN-010.
- **`ROADMAP.md`**: was ~4 releases stale ("Current phase — ci/v2.0.0", "before
  v2.0.0 is cut", PLAN-008 "In flight"). v2.0.0/v2.0.1 shipped; current phase is
  v2.1.0 fleet-readiness; PLAN-009/010 added to the milestone table.
- **`HANDOFF.md`**: described the merged `fix/flowci-feedback-canon-fixes` branch
  as "IN FLIGHT (unmerged)" and PLAN-010 as "NOT started". Rewritten to the real
  state (v2.1.0 staged + ready to cut; server-side blockers remain).
- **`plans/PLAN-008`**: `DRAFT` → `COMPLETE` (all 29 findings closed, v2.0.0 cut
  — it had been stale since 2026-07-13).
- **`plans/FRAMEWORK-TODO.md` FT-10**: named `aidoc,ci-ephemeral` as "the real
  labels" — that nickname is retired too; corrected to the CI-0007 canonical
  `["self-hosted","ci-runner","single-use"]` so the doc-fix TODO doesn't install
  a second wrong nickname.

### Docs — adopter cold-start was broken; fixed the on-ramp (2026-07-17)

- **`ROADMAP.md`**: was ~4 releases stale ("Current phase — ci/v2.0.0", "before
  v2.0.0 is cut", PLAN-008 "In flight"). v2.0.0/v2.0.1 shipped; current phase is
  v2.1.0 fleet-readiness; PLAN-009/010 added to the milestone table.
- **`HANDOFF.md`**: described the merged `fix/flowci-feedback-canon-fixes` branch
  as "IN FLIGHT (unmerged)" and PLAN-010 as "NOT started". Rewritten to the real
  state (v2.1.0 staged + ready to cut; server-side blockers remain).
- **`plans/PLAN-008`**: `DRAFT` → `COMPLETE` (all 29 findings closed, v2.0.0 cut
  — it had been stale since 2026-07-13).
- **`plans/FRAMEWORK-TODO.md` FT-10**: named `aidoc,ci-ephemeral` as "the real
  labels" — that nickname is retired too; corrected to the CI-0007 canonical
  `["self-hosted","ci-runner","single-use"]` so the doc-fix TODO doesn't install
  a second wrong nickname.

### Docs — adopter cold-start was broken; fixed the on-ramp (2026-07-17)

The reference docs were rigorous but the first ten minutes of adoption failed
three ways, disqualifying for a company-default. All from the pre-prod docs lens.

- **`install/README.md`**: added a "You must ALREADY have" block — a reachable
  LiteLLM proxy (yours to operate; `ai-review` `exit 1`s without it), the
  reviewer App, a private-repo runner pool, and the per-repo secrets + bot-id —
  before the install command. None of it was stated, so an adopter completed
  every documented step and ai-review was still permanently red with no doc
  naming the missing piece. Added the public-repo LiteLLM-reachability caveat.
- **`install/install.sh`** printed next-steps: reordered so **secrets come
  before the PR** (was: open PR → add secrets, guaranteeing a red first PR),
  added the three `LITELLM_*` secrets it omitted, set the bot-id directly
  (`294948438`, App-global) instead of "after first review" (waiting leaves
  `composition` INERT), and cited `docs/BRANCH_PROTECTION.md` (adopter-facing)
  instead of the private-sibling `IPLAN-0016 §2a-v3`.
- **`README.md`**: linked `docs/AI_CI_DEPLOYMENT.md` + `deploy-ci-wizard.sh
  preflight` as the **front door** (the real cold-start playbook was linked from
  nowhere); corrected the "after first review" bot-id timing; replaced two stale
  hardcoded counts ("15 caller templates" / "12 docs" — now 23 / 19 and
  drifting) with descriptions that don't rot.
- **`docs/README.md`**: indexed all 19 docs (was 9); promoted
  `AI_CI_DEPLOYMENT` / `REVIEWER_APP_ONBOARDING` / `BRANCH_PROTECTION` to a
  "Start here" section.
- **`CLAUDE.md`**: dropped `standards-drift` from the "ships reusable workflows"
  list — it has no `workflow_call` trigger, so an agent that believed it could
  `uses:` it would hit `startup_failure`.
- **`install/README.md`** dead link (`MIGRATION_v2.0.0.md` missing `../docs/`)
  and **`docs/troubleshooting.md`** machine-local `file:///home/...` link fixed.

### Fixed — every workflow surface now has a `-private` variant; `--update` is safe on private repos (2026-07-17)

- **`install/templates/workflows/{links,markdown-lint,pre-commit,secret-scan,labeler,docs-sync}-private.yml`** (new) + **`manifest.json`** `visibility_variants` + **`REPO_STANDARDS.md` §4.1**:
  6 of 11 manifest workflow surfaces were generic templates with no `-private`
  variant, carrying `runner_labels` only as a commented hint. `install.sh
  --update` resolves each surface through `visibility_variants`, so on a private
  consumer it re-applied the label-less generic → the reusable's `ubuntu-latest`
  default → jobs queue forever (OPS-0049). This is FT-9's live residual: the
  deploy wizard injected the labels at scaffold time, but `--update` reverted
  them, and `--repin` (the sanctioned path) can't touch a stale label. So the
  fleet cutover had no tool-supported way to migrate a private repo's runner
  labels — it was hand-editing 6 files per repo.
- Each variant bakes `["self-hosted","ci-runner","single-use"]` into every
  reusable-call job (verified: `links` gets both its jobs), mirroring the
  wizard's injection. `--update` on a private repo now writes a labeled file for
  all 6, so it is safe without hand-editing; the wizard path is now
  belt-and-suspenders. `check-drift.sh` drift-checks the variants automatically
  (manifest-driven since the FT-8 rewrite).

### Security — `composition`: a malformed trust config passed the gate for EVERY author (2026-07-17)

- **`.github/workflows/composition.yml`** + **`docs/REPO_STANDARDS.md` §4.3b**:
  the trust-gate exemption fired on **any** non-zero `jq` exit. `jq -e` exits 1
  when the query is false/null but **4** when the input does not parse — so a
  malformed `config.json` on the default branch, or one whose
  `.trust.ai_review` key was renamed, satisfied `! jq -e` and hit
  `exit 0`/"composition not enforced (pass)". Reproduced: `malformed → jq_rc=4
  → gate PASSES`, for trusted authors too.
- **Why it mattered:** `composition` is the *sole* App-approval enforcement, and
  the tier templates set `required_approving_review_count: 0` — so on every repo
  where it is a required check, one bad hand-edit to `config.json` silently
  removed the review gate fleet-wide, simultaneously, while staying green.
- The file's fail-closed contract covered a broken **read** (`[ -s "$CFG" ]` +
  a 7-attempt retry); the **parse** had no equivalent. It now schema-validates
  before trusting the parse and treats failure as fail-closed = ENFORCE,
  mirroring `auto-merge-ai-prs.yml`'s existing check. **Note the polarity
  differs between the two gates** (there fail-closed is `exit 0` = refuse to
  merge; here it is enforce = refuse to exempt) — §4.3b records this.
- **`jq`'s array `contains()` substring-matches** (§4.3c): `composition` used
  `contains(["skip-ai-review"])` while `auto-merge-ai-prs` used `index()`, so
  the two classified the same PR differently and a label named
  `skip-ai-review-exempt` set the skip flag with nobody applying the real label.
  Now `index()` in both. (Residual risk was narrow — the carry-forward branch
  still demands an App-approved tree-matching commit — but the divergence was
  real.)

### Fixed — release pointers named the wrong version of canon (2026-07-17)

- **`VERSION`** + **`install/install.sh`**: both said `ci/v2.0.0` while
  `ci/v2.0.1` was the live fleet target (operations pinned + verified). The
  v2.0.1 cut never bumped them. `install.sh` resolves `CI_TAG env > VERSION >
  CI_TAG_FALLBACK`, so **every documented `--repin` without an explicit
  `CI_TAG` wrote `ci/v2.0.0`** — pinning consumers *backwards* onto the three
  ai-review blockers v2.0.1 exists to fix, on the one armed live consumer, while
  PLAN-009 is actively re-pinning 7 repos. `sync-version-refs.sh --check`
  reported green throughout: it proves the refs agree with `VERSION`, not that
  `VERSION` is right.
- `CI_TAG_FALLBACK` was documented as "hand-bumped per release" — a release step
  that can be forgotten will be. **`scripts/sync-version-refs.sh` now rewrites
  it mechanically**, and **`tests/test_version_sync.sh`** asserts
  `VERSION == CI_TAG_FALLBACK == the latest published ci/v* tag`. Verified the
  guard fails on the pre-fix state and passes on the fixed one.
- **`sync-version-refs.sh` TARGETS coverage**: `docs/{overrides,architecture,
  security,MIGRATION_v2.0.0,UPDATE_GUIDE,AI_CI_DEPLOYMENT}.md` and
  `install/templates/config.json.template` carry the pin shapes the script
  rewrites but were outside its list — matching `VERSION` by coincidence and due
  to drift silently at the next bump. Now covered.
- **`tests/test_scripts.sh`** hardcoded `@ci/v2.0.0` — the same hand-bump class.
  It now reads `VERSION`, so it asserts the invariant ("the wizard scaffolds at
  the current release") instead of freezing a tag string.

### Fixed — half-provisioned repos, label triggers, bash-4 guard (2026-07-17)

- **`.github/workflows/ai-review.yml`**: `APP_KEY_PRESENT` tested only
  `APP_REVIEWER_1_KEY` in the review job while the trust job tested KEY **and**
  ID. A repo with KEY set and ID pending — exactly the state a fleet
  secret-provisioning sweep passes through, and PLAN-009 Phase 0 is doing that
  now — had the trust job skip the mint cleanly while the review job minted with
  `app-id: ''`, got an empty token, and hit the fail-closed "mint failed" exit:
  every routine PR deterministically blocked, with an error naming the wrong
  cause. Now symmetric.
- **`install/templates/workflows/audit-trail-{public,private}.yml`** +
  `.github/workflows/audit-trail.yml`: added `labeled, unlabeled` triggers. The
  reusable's documented escape hatch is the two-signal override
  (`skip-audit-trail` label + a commit-body marker), but applying the label
  fired no event, so the check never re-ran and the red check never cleared —
  the operator was told to apply a label that could not take effect. `ai-review`
  already had these; audit-trail was the outlier.
- **`sync/check-drift.sh`**: added the bash-4 guard its three sibling scripts
  already have. It uses `declare -A` under `set -uo pipefail` (no `-e`), so on
  bash 3.2 (macOS system bash) the `declare` error is non-fatal and every
  `MANIFEST_CACHE[$pin]` subscript arithmetic-evaluates to 0 — collapsing all
  pins into one slot, so a consumer mid-bump silently gets the wrong tag's
  manifest. That is precisely the per-caller pin frame the script exists to
  preserve.
- **`.github/workflows/secret-scan.yml`**: removed a no-op
  `sed -i 's/^          //'` whose comment claimed it stripped heredoc
  indentation — YAML's block scalar had already stripped it, so it matched
  nothing. The indentation itself is load-bearing (a column-0 line ends the
  block scalar) and is now documented as such.

### Security — `secret-scan` proves the consumer's gitleaks config can detect (2026-07-16)

- **`.github/workflows/secret-scan.yml`** + **`docs/REPO_STANDARDS.md` §4.3a**:
  `config-path` was passed straight to `gitleaks --config` with **no
  validation**. A consumer `.gitleaks.toml` declaring an `[allowlist]` but
  neither `[extend] useDefault = true` nor its own `[[rules]]` has **zero
  rules** — it finds zero secrets and exits 0: **a green required check that
  scans nothing**. The failure is silent and inverted: a consumer wires
  `config-path` to quiet a red gate, the gate goes green, and the repo ends up
  with *less* scanning than the default it replaced. Rule-less gitleaks configs
  do occur here — the iplan-runner note in `plans/FRAMEWORK-TODO.md` records a
  repo whose standalone gitleaks was already rule-less and no-op.
- **Fix:** before the real scan, `secret-scan` now runs the resolved config
  against a planted-credential canary and **fails the job if the config detects
  nothing**. New **`validate-config`** input (default `true`) opts out, for a
  repo whose custom `[[rules]]` deliberately don't cover AWS/GitHub credentials.
- **Scope of the claim:** this proves the ruleset is non-empty. It does NOT
  prove the scan covers the repo — real rules plus a broad `[allowlist] paths`
  can still hide a live secret, which is a deliberate consumer choice canon does
  not override. The pass message and §4.3a say so rather than implying the gate
  is proven to scan.
- **gitleaks' exit codes are ambiguous, so the canary reads the log too.** A
  missing or malformed config exits **1** — identical to "leaks found" — so
  treating any non-zero as success would report a broken config as a passing
  canary; that case is now a hard error quoting gitleaks' own message. And
  `rc=0` plus a `global allowlist` debug line means the consumer's allowlist
  matched the canary's own path: that proves nothing about the ruleset, so it is
  reported **INCONCLUSIVE** rather than failed. Red-gating a correct config
  would predictably drive consumers to `validate-config: false`, leaving them
  worse off than before this check existed.
- **Behaviour is validated, not TOML text.** Measured against gitleaks 8.30.1, a
  `grep -qE '^\[extend\]|^\[\[rules\]\]'` guard fails **both** ways: it rejects
  the valid inline form `extend = { useDefault = true }` (which detects fine) and
  admits `[extend]` + `disabledRules` with no `useDefault` (which detects
  nothing). Only executing the scanner separates them. Recorded in §4.3a so the
  cheaper-looking fix isn't re-proposed.
- **Canary fixtures must be verified-detectable:** `AKIA…7EXAMPLE` is allowlisted
  by gitleaks' *own* default ruleset and is NOT detected even under
  `useDefault` — a canary built from it silently passes rule-less configs. The
  shipped fixtures are built by runtime concatenation (so this workflow's source
  carries no matchable secret) and are verified to fire.
- Consumer impact: a repo passing `config-path` to a rule-less config sees
  `call / gitleaks` go **red** with a message naming the fix. That check was
  never scanning anything.

### Fixed — `check-drift.sh` covered 2 of 12 reusables (FT-8, 2026-07-16)

- **`sync/check-drift.sh`**: the loop was hardcoded to
  `for wf in ai-review composition`, so a consumer's `labeler`, `links`,
  `pre-commit`, `secret-scan`, `codeql`, `audit-trail`, `doc-maintainer`,
  `auto-merge-ai-prs`, `markdown-lint` and `docs-sync` callers were **never**
  compared against canon — drift was structurally invisible to the tool whose
  job is finding drift. The loop is now driven by the consumer's own pinned
  callers and resolved through `manifest.json` **fetched at each caller's own
  pin**, preserving the PR-A2 per-caller pin frame and the warning-only
  contract. A newly-added canon workflow needs no edit here.
- Verified: on a consumer carrying three real drifts, the old script reported
  **"no drift"**; the new one flags all three.
- **`install/templates/manifest.json`: `audit-trail` was never manifested.** It
  ships `-public`/`-private` templates and is deployed on every consumer (it is
  the OPS-0069 gate), but had no manifest entry — so manifest-driven tooling
  (`install.sh --update` and now `check-drift.sh`) skipped it entirely. It was
  the only such omission across the template set. Coverage is the manifest's
  workflow surface, **not** "every canon workflow"; the header says so rather
  than restating an unmeasured claim.
- **Skips are now loud.** A drift tool that reports a pass over files it never
  opened is the same defect class as a secret-scan that greens while scanning
  nothing, so: every uncompared caller emits a `::warning::` and increments a
  skip counter; the verdict carries its denominator
  (`compared N of M canon caller(s); S skipped`); and the words "no drift" are
  gated on `SKIPPED == 0`. Previously "no drift" printed even when zero files
  were compared — byte-identical to a healthy repo, under a green check.
- **A canon caller pinned to a branch or bare SHA is now reported**, not
  silently treated as consumer-owned, and the outer guard matches `@<anything>`
  so a repo whose callers are *all* branch-pinned no longer exits "nothing to
  check". No consumer is in that state today (every canon `uses:` across the
  fleet is clean semver) — this closes the path, it does not fix a live break.
  Note it does NOT cover iplanic's unresolvable pin (FT-13): that reference is a
  `curl` inside a `run:` step, not a `uses:`, so there is no `@ref` to scan.
- Scope limits now stated in the header instead of being silent: non-pinned
  surfaces (`CODEOWNERS`, `CLAUDE.md`, `pre_push_check.sh`, …) have no tag for a
  per-pin tool to resolve and are `apply-standards.sh --check`'s job; templates
  with `substitute` placeholders are skipped (a raw diff would false-flag them);
  callers pinned below `ci/v1.7.0` predate `manifest.json` and are reported as
  skipped, never as clean.

### Fixed — `audit-trail-check` bot exemption now precedes the git guard (2026-07-16)

- **`.github/workflows/audit-trail-check.yml`**: the `exit 1` on an unreachable
  `BASE_SHA` ran **before** the trusted-bot exemption, so a bot PR could fail a
  check it was meant to skip entirely. Bot identity comes purely from GitHub PR
  metadata (`pull_request.user.type`) and does not depend on git history, so the
  exemption now runs first — matching the documented priority ("trusted bot →
  skip check entirely"). Narrow in practice (it needs a bot PR *and* an
  unreachable base, and trusted bots open same-repo PRs), and the old behaviour
  was fail-closed with a diagnostic, not a hole.

### Docs — §4.3 allowed-actions rule corrected; two stale headers fixed (2026-07-16)

- **`docs/REPO_STANDARDS.md` §4.3**: stated that the three-pattern canon rule was
  "the same allowed-actions allowlist every consumer sets" and that a reusable
  wrapping **ANY** third-party action is "BLOCKED at run-init →
  `startup_failure`". Both are false against the template the same sentence
  cites: `install/templates/actions-permissions.json:17` also sets
  `verified_allowed: true`, so the **deployed** boundary is
  `github_owned_allowed + verified_allowed + patterns_allowed` — the whole
  GitHub-verified marketplace. A **non-verified** creator's action is blocked at
  run-init (web-UI-only, no logs); a **verified** creator's action is **admitted
  and runs**. The three incidents that produced the rule (`gacts/*`,
  `lycheeverse/*`, `DavidAnson/*`) are all non-verified, so the rule held by
  accident of which actions were tried. §4.3 now separates the **canon authoring
  rule** (deliberately stricter — keep it) from the **deployed boundary**, and
  warns that reasoning "third-party ⇒ startup_failure" misdiagnoses failures.
- **The same false universal is corrected everywhere it appeared**, not just in
  §4.3: `secret-scan.yml` + `markdown-lint.yml` headers, `docs/WORKFLOWS.md`,
  `docs/security.md`, `docs/AI_CI_DEPLOYMENT.md`, `docs/troubleshooting.md` §13.
- **`docs/troubleshooting.md` §13 prescribed a fix that drifts consumers OFF
  canon.** Its unblock command set `-F verified_allowed=false` while the shipped
  `actions-permissions.json` sets `true`, so following the runbook produced
  drift that `apply-standards.sh --check` would then flag. It also dropped
  `actions/*` + `github/*` from `patterns_allowed`. The command now matches the
  template exactly, and §13 explains that selected-actions fields are additive —
  a `startup_failure` means the action matched *none* of the three, not that
  third-party actions are blocked in general.
- **`sync/check-standards-drift.sh`**: header said it "ALWAYS exits 0",
  contradicting `--strict` and the §4.3 rule that adoption validation MUST use
  it. The stale line led a reader to conclude canon ships no way to gate on
  drift; it already does.
- **`install/apply-standards.sh`**: header still said "PR-B2 ships the
  NON-MUTATING modes only … PR-C adds `--apply`". PR-C landed; `--apply` is
  implemented.
- **`.github/workflows/standards-drift.yml`**: the fleet pin-currency step
  claimed private repos are "covered by their OWN weekly standards-drift run,
  which chains check-pin-currency.sh in-repo". That is true for `operations`
  (`check-standards-drift.sh` chains pin-currency itself, so a caller gets it
  transitively) and false for the other three: `business` + `interlog` have no
  caller, and `iplanic`'s pins `e15ec7d…` — the annotated TAG OBJECT of
  `ci/v1.6.0`, not a commit, which raw.githubusercontent has never served, so
  that caller has never worked. Measured 2026-07-16 —
  every private run has been failing since 2026-07-13, so none is presently
  producing a signal, for differing reasons. Comment now states the measurement;
  tracked as **FT-13**.

### Decision — runner-label naming deferred to a future major (CI-0007, 2026-07-16)

- **`DECISIONS.md` CI-0007** + a **`LABELS.md`** §2 pointer: a proposed rename of
  the canonical selector (`ci-runner` → `private-ci-runner`, `single-use` →
  `isolated-ci-runner`, plus a `sandbox-*` candidate) is **tracked and deferred**
  — no rename, no migration. `[self-hosted, ci-runner, single-use]` is unchanged;
  callers, templates, and the staged Phase-0 runbook are untouched. `private-*`
  is ruled out permanently (public repos *may* use this pool for the ai-review
  *review* job — PLAN-009 Edit F, not yet executed — so the label would become
  false; and it encodes visibility/origin, which the selector deliberately
  omits); `isolated-*` collides with the `project-<name>` isolation dimension;
  `sandbox-*` is accurate but names confinement, not lifecycle. Revisit at the
  next breaking release once the fleet is unified on v2.

### Docs — ephemeral-runner governance for AI sessions (2026-07-15)

- **`CLAUDE.md`** (Runner policy) + **`docs/runners.md`** §5/§5a: explain the
  ephemeral single-use runner model for a fresh AI session — no state carry-over,
  tools baked per-host, **one supervisor instance = serial jobs** (run N per repo,
  sized to peak PR job-count), and the LiteLLM bridge route (`172.17.0.1:4001`).
  Documents that **public repos MAY use the ephemeral self-hosted pool for the
  ai-review *review* job only** — safe (forks are gated off on the `ubuntu-latest`
  trust job; the review job runs no PR code) — which lets a **private-only**
  LiteLLM proxy serve public repos with no public endpoint. Wiring:
  `runner_labels_review: self-hosted`, trust job + all else on `ubuntu-latest`.

### Fixed — set-litellm-secrets.sh `--mint` endpoint (2026-07-15)

- **`install/set-litellm-secrets.sh`**: `--mint` posted to `$LITELLM_BASE_URL/key/generate`,
  but LiteLLM's management endpoint is at the **root**, not under `/v1` — so a
  canonical `…/v1` base URL minted against the wrong path. Now derives a root
  `MGMT_URL` (strips a trailing `/v1` + slash) and mints against
  `MGMT_URL/key/generate`. Verified against `…/v1`, `…/v1/`, root, and `…/api/v1`.

### Added — LiteLLM fleet secret-provisioning helper (2026-07-15)

- **`install/set-litellm-secrets.sh`** — batch-sets the repository-level LiteLLM
  Actions secrets (`LITELLM_BASE_URL`, `LITELLM_REVIEW_API_KEY`, optional
  `LITELLM_DOC_API_KEY`) across the PLAN-009 consumer fleet. Reads values from env
  (never argv), pipes to `gh secret set` via stdin, HTTPS-checks the URL. Flags:
  `--dry-run`, `--pilot` (engramory), `--repos "…"`, `--doc`, and `--mint` (mints a
  per-repo, revocable, review-scoped virtual key from the master key — the master
  key never lands in any repo). Referenced from `MIGRATION_v2.0.0.md` §1.

## ci/v2.0.1 — 2026-07-15

Patch: fixes the three verified ai-review-v2 blockers from the LiteLLM-switch
pre-prod review, plus the per-repo LiteLLM-secret governance instruction and the
PLAN-009 finalize / WORKFLOWS §2 docs that landed after `ci/v2.0.0`.

### Fixed — ai-review v2 blockers (2026-07-15)

From the pre-prod review of the LiteLLM switch. All fail-closed on the merge axis,
but each broke correct behaviour:

- **`ai-review.yml` — `request_changes` verdict validation (jq precedence).** The
  finding-fix predicate `((.severity==critical or medium) | not or (.fix|length>0))`
  parsed with `|` binding loosest, so `.fix` indexed a boolean and **errored on
  every `request_changes` verdict** → the verdict was mishandled as "malformed",
  discarding the findings comment + App review and inviting an operator
  `skip-ai-review` bypass. Parenthesized: `(((…)|not) or (.fix|length>0))`.
- **`ai-review.yml` — `pull_request_review` skip could flip RED→GREEN pre-arming.**
  The review-event early-exit concluded a fresh SUCCESS **before** the
  `EXPECTED_ID` (App-armed) check, so on an unarmed repo (composition inert) a
  comment-review superseded a prior `request_changes` at the same HEAD. Reordered
  so the unarmed guard runs first (full review on all events while unarmed); the
  skip now applies only when armed (composition is the real gate).
- **`ai-review.yml` — `python3` preflight.** Added a `command -v python3` guard
  that names the cause (rebuild the runner image) instead of a cryptic mid-heredoc
  127 — closing the recurrence of the "required binary missing from runner" class.
- **`MIGRATION_v2.0.0.md`** — removed the `install.sh --update` cutover step
  (clobbers `runner_labels`/permissions/triggers, FT-9); `--repin` is the correct,
  complete cutover.
- **`troubleshooting.md` §10** — fixed the dead TOC anchor and mapped the
  `reviewer CLI / codex not found on runner` symptom → cut over to ci/v2.0.0.

### Added — LiteLLM secret setup as a per-repo governance instruction (2026-07-15)

- **CLAUDE.md.template**: new "AI review — required repo secrets (LiteLLM
  gateway)" section — every repo's governance file now instructs setting the
  repository-level `LITELLM_BASE_URL` + `LITELLM_REVIEW_API_KEY` (plus the
  reviewer-App + `AI_REVIEW_TOKEN`), states the gate fails closed without them,
  and notes the runner-egress-to-proxy requirement. Makes the API-based LiteLLM
  gateway an explicit standing setup requirement, not just a migration-doc step.
- **REPO_STANDARDS.md §4.0b**: corrected "repository or organization secrets" →
  **repository-level, per-repo** (org secrets require an org account; unavailable
  on a personal-account owner) — matching the 2026-07-14 live-verification note.

### Changed — finalize PLAN-009 fleet v2 cutover + correct WORKFLOWS.md §2 (2026-07-14)

- **PLAN-009**: DRAFT → PLANNING-COMPLETE. Phase 0 founder runbook staged in
  `../operations/ops/inbox/`. Corrections from live verification: LiteLLM secrets
  are **per-repo** (no org inheritance — `vladm3105` is a personal account); the
  v2 `check-standards-drift.sh` `--tier` set is
  `{governance|product|ops|umbrella|bootstrap}`; runner-pool cutover uses the
  operations **hybrid-then-narrow** label transition; `ci/v2.0.0` SHA
  `d3f4b032…` pinned for the standards-drift curl edit.
- **docs/WORKFLOWS.md §2**: flipped stale `⚠️ GAP`/`inert` cells to ✅ — the
  ai-review/composition/pre-commit/audit-trail callers on iplan-runner,
  iplan-standard, engramory, business all exist live at `@ci/v1.9.5`
  (re-verified 2026-07-14); refreshed the audited note + §2.1/§2.2/§3.2 prose.

### Fixed — post-cutover documentation sync (2026-07-13)

- **BRANCH_PROTECTION.md**: `Secret scan (gitleaks)` → `call / gitleaks` across
  all tiers (matching the v2 reusable workflow output name).
- **MIGRATION_v2.0.0.md**: added LiteLLM virtual key generation examples with
  Docker bridge gateway note (consumer-facing cutover lesson).
- **branch-protection-bootstrap.json**: `Lint / format / security hooks` →
  `call / Lint / format / security hooks` (matching the v2 reusable output).
- **FLEET_BRANCH_PROTECTION_ARMING.md**: updated operations entry to reflect
  completed v2 cutover (all five canon checks armed and green).

## ci/v2.0.0 — 2026-07-13

### Added — canonical branching standard

- Added `docs/BRANCHING.md` as the technical contract for working-branch
  naming, lifecycle, safe updates, squash merges, cleanup, hotfixes, release
  tags, automation exceptions, and enforcement boundaries.
- Expanded strict standards-drift checks to detect missing PR protection and
  drift in update-branch and squash-title/body repository settings.

### Changed — unified LiteLLM gateway for all AI jobs

- `ai-review` and `doc-maintainer` now call one OpenAI-compatible LiteLLM
  proxy through a dependency-free Python adapter. Runners no longer install,
  authenticate, or select Claude/Codex CLIs.
- The consumer contract is `LITELLM_BASE_URL`, purpose-scoped
  `LITELLM_REVIEW_API_KEY` / `LITELLM_DOC_API_KEY`, and LiteLLM model aliases
  (`litellm.model` for review; caller `model` for doc-maintainer).
  Provider credentials, routing, fallback, and budgets stay behind LiteLLM.
- Adds a versioned AI-review config-v2 JSON Schema and a manual real-proxy smoke
  workflow that must exercise both canonical aliases before the tag is cut.
- Proxy errors, missing configuration, malformed JSON, and structurally invalid
  verdicts fail closed. This removes vendor-specific workflow inputs and is a
  breaking interface change.

### Added — fleet branch-protection arming runbook + markdown-lint graduation complete (PLAN-007 W3/W4) (2026-07-12)

- **`docs/FLEET_BRANCH_PROTECTION_ARMING.md`** (NEW) — founder-executable runbook
  for arming the canon CI gates as *required* status checks per repo (🔴 — a
  write to other repos + branch-protection change, reserved for the founder). A
  read-only fleet survey drives it: it reconciles each repo's actual emitted
  check-name (canon `call / …` vs standalone), flags the FT-12 phantom bare-lint
  contexts (framework/business/iplanic/iplanic forcing `--admin` merges), the two
  unprotected repos, and interlog's conditional composition, with exact `gh api`
  commands + per-repo verification + rollback. Tracked as FT-12.
- **markdown-lint report-only → blocking graduated across all 6 canon consumers**
  (enabled by the `.markdownlint.json` relaxation below): the per-repo
  `fail-on-findings: true` flips + residual cleanups shipped in each consumer's
  own repo (business/interlog/engramory/iplan-runner/iplanic/iplan-standard).
  Only the founder-executed W4 arming remains to make them merge-blocking.

### Added — functional doc-maintainer and production CI hardening

- Replaced the doc-maintainer planner/apply/reconciler stubs with a bounded AI
  documentation-impact planner, validated low-risk edit generation, bot PR
  creation, high-risk issue routing, prompt-injection/path/secret guards, daily
  caps, dry-run detail, and scheduled missed-run recovery. Added consumer config
  and conventions templates plus behavioral regression tests.
- Hash-verifies the pinned gitleaks and actionlint binaries, removes blanket
  secret-scan exclusions for tests/fixtures/examples, pins pre-commit, makes
  missing CI linters fatal, enables shellcheck for embedded workflow shell, and
  installs downloaded tools through the unified `$RUNNER_TEMP/bin` pattern.
- Adds strict standards-drift mode for release/adoption gates and fixes the
  markdown-lint private-runner example's duplicate `with:` block.

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
  - stale "Planned" section gutted; `local-pre-push.md` §8 (dropped "not yet
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
  `*(...)*` separator row.

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
  - "Not adopted [—-] `<rationale>`" prefix detected BEFORE any path
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
  - maintenance protocol.
- **`install/templates/plans-README.md.template`** (NEW) — content
  for consumer `plans/README.md` explaining per-repo plan naming
  convention (PLAN-NNNN default + IPLAN/TPLAN/DPLAN/MPLAN/RPLAN/
  CPLAN/SPLAN scoped prefixes) + verified-planning skill contract.
- **`docs/REPO_STANDARDS.md`** §16 (NEW section) — codifies the
  project governance file canon: 6 required surfaces + additional-
  row pattern + "Not adopted — `<rationale>`" cell format + template
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
  - Wave 0–5 rollout follow.

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
  - defense-in-depth at the call site.** composition.yml:189 filters on
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
  - `issues: write` + `actions: read`. Last one required for the
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
  - docs updates (architecture.md / security.md / troubleshooting.md).
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
  - `user.type == "Bot"` + `state == "APPROVED"` + `commit_id == HEAD_SHA`).
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
  - framework pin-bump to `@ci/v1.1.6`, the **first auto-merged routine
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
  - workspace-root `.github/ai-review/config.json`). Workflow
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
  - get the correct triggers by default. Removes the per-consumer
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
  - sets secrets) + the rollout phases per IPLAN-0018 §3.7
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

- "Ship all of the above as v1.0.6".

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
    - `echo "$HOME/.local/bin" >> "$GITHUB_PATH"` (native installer
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
  - caller template (`install/templates/workflows/pre-commit.yml`).
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
  - `actions/setup-python@v6.2.0` (`a309ff8b426b58ec0e2a45f0f869d46889d02405`).

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
  - LABELS.md area-namespace addition
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
  - charter + DECISIONS). `docs/README.md` updated to list it.

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
