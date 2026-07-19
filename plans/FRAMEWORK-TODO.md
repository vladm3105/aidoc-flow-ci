# FRAMEWORK-TODO — `aidoc-flow-ci`

Canon inconsistencies / bugs / improvement notes discovered while driving
the docs + workflows. Logged inline as found (per the framework-TODO
convention — examples/adoption ARE the system-under-test; their friction is
the framework's truth). Each item names the surfaces + a fix sketch; clear
when resolved.

## Open

### FT-1 — Branch-protection templates lag REPO_STANDARDS §2 on `call / verify`

**RESOLVED (2026-07-12, PLAN-007 W2):** branch-protection templates + REPO_STANDARDS §2 corrected to the verified `call / …` emitted names (incl. `call / verify`); `tests/test_checknames.sh` guards against recurrence.

**Found:** 2026-07-09, during PLAN-004 PR-A3 (`BRANCH_PROTECTION.md` authoring).
**Surfaces:** `docs/REPO_STANDARDS.md` §2 (line ~84) lists `call / verify`
in the required-checks baseline for governance/product/ops; the shipped
`install/templates/branch-protection-{governance,product,ops}.json` omit
it (they predate the 2026-07-08 §2 amendment per §15 change log).
**Effect:** `apply-standards.sh --apply` produces protection WITHOUT
`call / verify`; a `--check` against §2 then reports it as drift; the doc
had to describe "§2 target vs template today" rather than one number.
**Constraint (why not a trivial template edit):** requiring `call / verify`
universally would block every PR on any tier repo that hasn't adopted the
`audit-trail` caller yet (per its §14.3 Wave). So the fix must couple the
template change to audit-trail adoption state, or keep `call / verify` a
per-repo post-adoption addition.
**Fix sketch:** decide the canonical position — either (a) §2 marks
`call / verify` as "add after audit-trail adoption" (matching current
templates + `BRANCH_PROTECTION.md`), or (b) ship the audit-trail caller
template + bump the three branch-protection templates together in a wave
that also flips required checks. Reconcile §2 ⇄ templates ⇄
`BRANCH_PROTECTION.md` so all three agree.

### FT-2 — Verify the real emitted context names for `pre-commit` + `secret-scan`

**RESOLVED (2026-07-12, PLAN-007 W2):** verified emitted check-names captured from live runs + recorded in REPO_STANDARDS §2 verified-names table; templates aligned; regression-tested.

**Found:** 2026-07-09, PLAN-004 PR-A3 (pre-push review L1).
**Surfaces:** `docs/REPO_STANDARDS.md` §2 + the `branch-protection-*.json`
templates require contexts `Lint / format / security hooks` and
`Secret scan (gitleaks)`. But `secret-scan.yml`'s job name is `gitleaks`
and both are consumed via a caller `jobs.call:` job, so GitHub likely
renders them as `call / gitleaks` and `call / Lint / format / security
hooks`. If the required context string doesn't match what the check
actually posts, the required check never turns green → PR blocked.
**Fix sketch:** on one live PR that runs both reusables, read the actual
posted context names (`gh api repos/<r>/commits/<sha>/check-runs --jq
'.check_runs[].name'` or the PR's status contexts). If they differ from
the canon strings, correct §2 + every `branch-protection-*.json`. Doc
(`BRANCH_PROTECTION.md`) currently mirrors canon faithfully, so it self-
corrects once canon is fixed.

### FT-3 — `labels.json` `skip-ai-review` description corrected \n\n**Found:** 2026-07-09, PLAN-004 PR-A3 (`LABELS.md` rewrite).\n**Status:** RESOLVED — 2026-07-12.\n**Resolution:** `install/templates/labels.json:20` now reads "Operator override:\nsuppress re-review and carry forward a valid prior approval" — matches the actual\nbehavior (`ai-review.yml` SKIP_REVIEW + `composition.yml:110-117` carry-forward).\n`LABELS.md` already documented the correct behavior; the stale description was\ncosmetic only.

### FT-4 — CHANGELOG back-catalog (v1.1.0–v1.6.0) not cut into per-tag `##` headers

**Found:** 2026-07-09, PLAN-004 PR-A4b (CHANGELOG restructure).
**Surface:** `CHANGELOG.md` — the 18 tags in the `ci/v1.1.0` … `ci/v1.6.0`
band (16 excluding the two `ci/v1.1.0-alpha.*` prereleases; note `ci/v1.1.4`
was never cut — a gap the executor should expect) have their entries under
`## Unreleased` as dated `###` sub-sections, not per-tag `## ci/vX.Y.Z`
headers. PR-A4b did the safe parts (deduped the
doubled `ci/v1.0.3` header; renamed `## Unreleased` → staging header for the
genuinely-unreleased post-v1.6.0 work; added the PLAN-004 A-series entry)
but did NOT promote the released back-catalog.
**Why deferred (PLAN-004 §6 R5):** PLAN-004 item 10 assumed every Unreleased
sub-section carried an inline tag — false: the ~20 top entries (2026-07-08
work) are untagged, and the interspersed doc-only entries don't map cleanly
to a tag. A sweep risks mislabeling release provenance. `ci/v1.0.6`↓ already
have correct `##` headers, so this is bounded to the v1.1.0–v1.6.0 band.
**Fix sketch:** reconcile against `git log --tags --oneline` (each tag →
its commit range → the entries in that range), promote each inline-tagged
`### … ci/vX.Y.Z …` to `## ci/vX.Y.Z — <date>`, and assign the untagged
doc-only entries to the release whose commit range contains them. Verify no
entry is dropped or duplicated (line-count + entry-count before/after).

### FT-5 — `standards-drift` can't verify branch-protection / actions-permissions — STILL OPEN (needs a PAT/App token, NOT a permissions line)

**STILL OPEN (re-checked 2026-07-17), and the "one-line fix" does not exist.**
PLAN-007 W2 (2026-07-12) was marked RESOLVED but only made the 403 *legible* —
it never granted the scope, so the gap stayed live and the banner hid it until
the pre-prod governance review. The obvious fix — add `administration: read` to
the drift job's `permissions:` — was **attempted 2026-07-17 and rejected by
actionlint**: `administration` is not a grantable `GITHUB_TOKEN` workflow-
permission scope at all (the enum is actions/attestations/checks/contents/
deployments/discussions/id-token/issues/packages/pages/pull-requests/
repository-projects/security-events/statuses). So `branches/*/protection` reads
**cannot** be authorized via the workflow token; they require a PAT or a GitHub
App installation token with `administration:read`, provided as a secret.

**Effect (still live):** `.github/workflows/standards-drift.yml` grants only
`contents: read`, so `check-standards-drift.sh`'s branch-protection +
actions-permissions reads `warn_uncheckable`-skip. The drift check does NOT
verify the exact server-side settings PLAN-001 governs. Load-bearing for
PLAN-010's detector.

**Fix (real):** mint an App installation token (or a fine-grained PAT) with
`administration:read` + `actions:read`, store it as a repo/org secret, and have
the workflow use it for the `gh api` reads instead of `GITHUB_TOKEN`. That is a
provisioning task (🔴, touches secrets), not a canon-code one-liner — which is
why it belongs with the PLAN-010 adoption-model work, not a drive-by.

**Lesson:** "made the error legible" ≠ "fixed the error"; and a fix sketch's own
caveat ("confirm GITHUB_TOKEN can read another repo's branch protection") is
worth executing before marking anything RESOLVED. actionlint caught the bad fix
in one run.

**Found:** 2026-07-09, PLAN-004 C1 review.
**Surface:** `.github/workflows/standards-drift.yml` job grants `contents: read`;
`sync/check-standards-drift.sh` makes `gh api` reads of `branches/*/protection`,
`actions/permissions*`, and repo settings — which need `administration: read`
(branch-protection needs admin). With only `contents: read` those calls
`warn_uncheckable`-skip, so the drift check emits `::warning::cannot check …`
instead of actually verifying those surfaces.
**Effect:** the scheduled drift check silently does NOT catch branch-protection
or actions-permissions drift — the exact settings PLAN-001 canon governs.
**Pre-existing** (not introduced by C1's `permissions: {}` addition).
**Fix sketch:** add `administration: read` (and `actions: read`) to the drift
job's `permissions:` so those checks run instead of warn-skipping. Confirm the
GITHUB_TOKEN can read another repo's branch protection, or document that it
requires a PAT/App token with admin:read for cross-repo drift.

### FT-6 — trust-config source inconsistency: `composition` reads `$GH_REPO@main`, ai-review/auto-merge read `trust_config_repo`

**VERIFIED not-an-enforcement-gap (2026-07-12, PLAN-007 W2):** re-read composition.yml — when a repo has no local `.github/ai-review/config.json`, the read falls to the `else` branch = **fail-closed, ENFORCE the App-approval requirement** (composition.yml ~213). The consumer-local config is read ONLY for the author-EXEMPTION path (exempt a non-trusted author as human-review-only); it fails safe. So composition enforces everywhere; the `GH_REPO`-vs-`trust_config_repo` difference is a low-priority consistency nit (unify the author-exemption source with ai-review's `trust_config_repo`), NOT a gate that silently passes. Downgraded from load-bearing.

**PARTIALLY RESOLVED:** 2026-07-10, PLAN-005 PR-G — the hardcoded `?ref=main` is
fixed: `composition.yml` now reads the config from the repo's **actual default
branch** (`gh api repos/$GH_REPO -q .default_branch`, fall back to `main`), so
`master`/`develop` consumers aren't degraded to always-enforce. STILL OPEN: the
*source-repo* half — composition reads the CONSUMER's own repo while
ai-review/auto-merge read `trust_config_repo` (they can still consult different
allowlists). The `trust_config_repo`/`trust_config_ref` inputs on composition
(fix sketch (a) below) remain a deliberate future decision.

**Found:** 2026-07-09, PLAN-004 D1 (trust-root parameterization).
**Surface:** after D1, `ai-review.yml` + `auto-merge-ai-prs.yml` read the trust
config (`.trust.ai_review` + `auto_merge.repos`) from `trust_config_repo` @
`trust_config_ref` (default `vladm3105/aidoc-flow-operations@main`). But
`composition.yml:156` reads `.trust.ai_review` from
`repos/$GH_REPO/contents/.github/ai-review/config.json?ref=main` — the
CONSUMER's own repo, hardcoded `?ref=main`.
**Effect:** the three gates can consult DIFFERENT allowlists. For aidoc-flow
(operations' central config vs a consumer's minimal `["vladm3105"]`) they may
diverge, so composition could exempt/enforce an author differently than
ai-review routed them. Not de-branded by D1 because composition has no hardcoded
operations ref (it's already consumer-relative), and switching it to
`trust_config_repo` is a BEHAVIOR change on a live security gate — deferred to a
deliberate decision, not a rushed breaking PR.
**Fix sketch:** decide the canonical trust-source model — either (a) composition
also reads `trust_config_repo`@`trust_config_ref` (aligning all three; a
behavior change for aidoc-flow that must be validated against the live gate), or
(b) document that composition intentionally uses the consumer's own config and
ai-review/auto-merge use the central one, with the reason. Reconcile + add the
`trust_config_repo`/`trust_config_ref` inputs to composition either way.

### FT-7 — `CODEOWNERS.template` still hardcodes `@vladm3105`; de-brand needs a handle-normalizing drift check

**RESOLVED:** 2026-07-09 — implemented approach (a) normalize. `CODEOWNERS.template`
owner routes → `@${CODEOWNER_HANDLE}`; `apply-standards.sh` gained
`codeowners_check` (`normalize_codeowners` maps every `@owner` → `@OWNER` on both
sides before diff, verifying path structure while ignoring handle identity);
`install.sh` now installs `.github/CODEOWNERS` (substituted, preserve-if-exists)
reusing D2's `substitute_placeholders`. Defaults byte-identical; existing
`@vladm3105` consumers keep passing. REPO_STANDARDS §7 + §16.7. Original entry
retained below for context.

**Found:** 2026-07-09, PLAN-004 D2 (de-brand install templates).
**Surface:** D2 parameterized `config.json.template` (`${CODEOWNER_HANDLE}`) and
`CLAUDE.md.template` (`${CANON_*_URL}`) because neither is exact-match
drift-checked (config.json is drift-exempt; CLAUDE.md drift is a structural
governance-table parse via `parse-governance-table.py`). `CODEOWNERS.template`
was deliberately LEFT branded: `apply-standards.sh` `exact_match_check`
(`.github/CODEOWNERS` vs `CODEOWNERS.template`) diffs byte-for-byte, so a
`${CODEOWNER_HANDLE}` placeholder in the template would read as permanent DRIFT
against a consumer's substituted `@handle` on every `--check`. It is also NOT
written by `install.sh` today (install.sh installs callers, config.json,
CLAUDE.md, pre_push_check, pre-commit, labels — no CODEOWNERS), and `@vladm3105`
is already correct for every current (vladm3105-owned) consumer, so leaving it
branded has zero impact on the live workspace.
**Effect:** a true external adopter must hand-edit `.github/CODEOWNERS` after
install; the handle there is not yet flag-parameterized.
**Fix sketch (drift-pipeline design decision — do deliberately):** pick one —
(a) **normalize** owner handles out of the CODEOWNERS comparison: strip
`@[\w/-]+` tokens (and map `${CODEOWNER_HANDLE}` on the template side) on BOTH
sides before `diff`, so the check verifies path-routing STRUCTURE (which is
canon) and ignores WHO owns (inherently consumer-specific) — needs no handle
plumbed into CI, and is semantically correct since the owner is not canon;
(b) **handle-aware:** thread `--codeowner` into `apply-standards.sh --check`
(read from a repo var or the consumer's own `* @handle` line) and substitute
before diff — more CI plumbing; (c) **structural:** downgrade CODEOWNERS from
exact to a presence/shape check. Recommended: (a). Then add a CODEOWNERS install
step to `install.sh` (fetch + `substitute_placeholders` + write
`.github/CODEOWNERS`) reusing the D2 substitution helper, and de-brand
`CODEOWNERS.template` to `${CODEOWNER_HANDLE}`. Defaults must stay byte-identical.

### FT-8 — migrate `sync/check-drift.sh` onto `manifest.json` (PLAN-004 PR-E2)

**RESOLVED (2026-07-16).** `sync/check-drift.sh` no longer hardcodes
`for wf in ai-review composition`. The loop is now driven by the consumer's own
pinned callers under `.github/workflows/*.yml` and resolved through
`manifest.json` **fetched at each caller's own pin** (preserving the PR-A2
per-caller pin frame — a mid-bump consumer must not be judged against a newer
caller's canon), with the warning-only contract intact. A newly-manifested canon
workflow is drift-checked without editing the script.

Verified against a simulated consumer: the old script reported **"no drift"** on
a consumer carrying three real drifts (`labeler` + `secret-scan` `concurrency`
block dropped, `pre-commit` `push:main` trigger dropped — the exact drifts the
filing reported as invisible); the new script flags all three by name.

**Coverage is the manifest's workflow surface, not "every canon workflow"** —
and the distinction was load-bearing: `audit-trail` shipped `-public`/`-private`
templates but had **no manifest entry**, so the OPS-0069 gate (deployed on 9/9
repos) resolved to nothing and was reported as an unknown caller. It was the only
such omission across the template set; `install/templates/manifest.json` now
manifests it, which also brings it into `install.sh --update`'s walk. Do not
restate coverage as complete without re-measuring against `manifest.json`.

The reporting contract was tightened in the same pass, because a drift tool that
reports a pass over files it never opened is the same defect class as the
secret-scan that greens while scanning nothing: every uncompared caller now
emits a `::warning::` and increments a skip counter, the verdict carries its
denominator (`compared N of M; S skipped`), and the words "no drift" are gated
on `SKIPPED == 0`. A canon caller pinned to a branch or bare SHA — previously
classified as consumer-owned and skipped in total silence — is now reported as
an unpinned canon caller. (This does not reach FT-13's unresolvable iplanic pin:
that is a `curl` in a `run:` step, not a `uses:`, so no `@ref` exists to scan.)

Scope limits are stated in the script header rather than left silent: non-pinned
canon surfaces (`.markdownlint.json`, `CODEOWNERS`, `CLAUDE.md`,
`scripts/pre_push_check.sh`, …) carry no tag for this per-pin tool to resolve
them at and are `apply-standards.sh --check`'s job; templates with `substitute`
placeholders are skipped (a raw diff would false-flag them); callers pinned
below `ci/v1.7.0` predate `manifest.json` and are reported as skipped, never as
clean.

**Found:** 2026-07-09, PLAN-004 PR-E (update path). PR-E shipped
`install/templates/manifest.json` + `install.sh --update` consuming it, but
scoped OUT the `sync/check-drift.sh` rewrite to keep the PR reviewable.
**Surface:** `sync/check-drift.sh:30` still uses a hardcoded
`for wf in ai-review composition` loop over the two auto-installed callers.
It should read the workflow surface from `manifest.json` (the same list
`install.sh --update` walks) so a newly-added canon workflow is drift-checked
without editing the script. The existing "bring back to canonical: remove the
local file + re-run install/install.sh" note (`sync/check-drift.sh:66`) can
point at `install.sh --update` as the reconciliation path.
**Effect:** drift-check coverage is limited to ai-review + composition;
optional adopted workflows (labeler, codeql, secret-scan, …) are not
drift-flagged by check-drift.sh (apply-standards.sh + check-standards-drift.sh
cover other surfaces). Non-breaking gap, not a correctness bug.
**Fix sketch:** replace the hardcoded loop with a `python3` walk of
`manifest.json` filtering to `.github/workflows/*` entries (visibility
resolved like `install.sh --update`), preserving the per-caller pin logic
(each caller compared against the tag IT is pinned to, per PR-A2) and the
warning-only/never-block contract. Reuse the manifest entry emission from
`install.sh update_mode`. Keep it a separate PR (E2) — it touches a live
CI drift-check script.

### FT-9 — 🔴 `install.sh --update` wholesale-replaces `safe_to_replace` callers, clobbering per-repo runner/permissions/trigger customizations

**Found:** 2026-07-10, during the PLAN-005 v1.8.1 consumer-sync sweep — a
fleet-wide gate-brick regression. Caught on operations #244 by that repo's own
ai-review (verdict: changes-requested); the identical regression had **already
merged** on iplanic (#247), business, and interlog before detection.
**Surface:** `install/install.sh` `update_mode()` (lines ~186-261): for any
manifest entry with `safe_to_replace: true` (all workflow callers except
`codeql.yml`), `--update` **overwrites the local caller file wholesale** with
the fetched generic template. The template ships the framework default
`runner_labels: '"runner-self"'` and omits per-repo caller `permissions:`
blocks, trigger customizations (`ready_for_review`, the `pull_request_review`
exclusion), and per-caller `runner_labels` overrides.
**Effect (critical):** running `--update` on a repo that has customized its
callers silently reverts those customizations. Concretely on the private
consumers, `runs-on: ${{ fromJSON(inputs.runner_labels_review) }}` became
`runs-on: runner-self` — a label no repo has registered (operations pool =
`self-hosted,aidoc,ci-ephemeral` + `…,ai-review`; iplanic = `…,ci-ephemeral`)
— so every required-check job (ai-review trust/review, composition,
doc-maintainer) queues indefinitely and **bricks the merge gate for every
subsequent PR**. Also drops docs-sync/links overrides → `ubuntu-latest`
fallback → OPS-0049 billing gate-down, and deletes doc-maintainer's
`permissions:` block → startup_failure.
**Root confusion:** `--update` conflates two distinct operations — "adopt a new
canon **template body**" vs "bump the **pin version**." A **re-pin is
version-only**: it must change only the `@ci/vX.Y.Z` string on each `uses:`
line and touch nothing else.
**Fix sketch:** split the two. Either (a) add a dedicated `--repin` path that
surgically rewrites `@ci/v*` → target tag on existing caller `uses:` lines,
preserving all customizations (the manual fix applied to operations #244 +
iplanic); or (b) mark all workflow callers `safe_to_replace: false` in
`manifest.json` so `--update` only reports body drift (never auto-replaces) and
handles the pin bump separately; or (c) make `update_mode` merge — preserve the
consumer's `with:` block (runner_labels/permissions/trigger overrides) while
adopting non-`with:` template changes. Requires a plan (canon change → semver
MINOR + `REPO_STANDARDS.md` update + verified-planning 2-cycle review). Until
shipped: **never run `install.sh --update` for a re-pin on a repo with a
customized caller — do a surgical `@ci/v*` sed instead.**
**RESOLVED (ci/v1.9.0, PLAN-006 W2):** `-private.yml` templates now ship the real
`ci-ephemeral` array (no more `runner-self` placeholder); `install.sh --repin`
(version-only pin bump) added — option (a). See CHANGELOG v1.9.0.

### FT-10 — `runner-self` still used as a pool-nickname across reference docs

**Found:** 2026-07-11, v1.9.0 doc-consistency review (documentation-specialist).
**Surface:** after v1.9.0 removed `runner-self` from the shipped templates, the
reference docs still use `runner-self` as the *nickname* for the self-hosted pool
in several places: `docs/runners.md` §0/§2 pool tables + registration steps
(~lines 91, 103, 122, 152-191), `docs/troubleshooting.md:95-96/286`,
`LABELS.md:121`. Not a contradiction with the template change (the genuine
"templates ship runner-self" claims were fixed in v1.9.0), but `runner-self` is
**not registered on any runner**. The **canonical label is
`["self-hosted","ci-runner","single-use"]`** (CI-0007, since v2.0.0 — see
`DECISIONS.md`). NB the older `aidoc,ci-ephemeral` nickname is ALSO retired; this
entry previously named it as "the real labels", which would have made this
doc-fix install a second wrong nickname — fix the docs to the CI-0007 labels.
**Effect:** a reader following runners.md registration steps would register a
`runner-self` label no caller targets. Educational drift, not a live break.
**Fix sketch:** reconcile the nickname — rewrite the reference docs to the real
`ci-ephemeral`/`ai-review` labels throughout (align docs to infra; preferred).
One focused docs PR; split to keep ≤3 surfaces.

### FT-11 — graduate `markdown-lint` (report-only → blocking) + `docs-sync` (dry-run → live)

**Found:** 2026-07-11, PLAN-006 W4 population. **Status: population DONE;
graduations remain.**
**Done:** the canon defect was fixed (`v1.9.4` binary-install for
`markdown-lint`+`links`; `v1.9.5` `markdown-lint` `fail-on-findings` toggle +
`.lychee.toml` `include_fragments` fix), and all content-check workflows are
now deployed on every active repo (see `docs/WORKFLOWS.md` §2):
- **`links`** — blocking (offline) on every repo (0 errors; debt repos ship a
  scoping `.lychee.toml`).
- **`markdown-lint`** — deployed **report-only** (`fail-on-findings: false`);
  operations/framework covered by own tooling.
- **`docs-sync`** — deployed **dry-run** (proposes doc-fixes as a PR comment;
  no App needed — the `aidoc-flow-bot` App is only for the live Apply step).

**Remaining (deliberate opt-in graduations, NOT dev gaps):**
- **`markdown-lint` report-only → blocking — DONE across all canon consumers
  (PLAN-007 W3, 2026-07-12).** Sequence: (1) founder chose to **relax the canon
  `.markdownlint.json`** (disable MD013/MD024/MD036 — workspace-legitimate
  false-positives on changelog data rows, keep-a-changelog headings, ADR
  `**Context**`/`**Decision**` bold-labels; ci #149, REPO_STANDARDS §4.4). (2)
  Per-repo graduation to `fail-on-findings: true`: **business #57, interlog #63,
  engramory #49, iplan-runner #89, iplanic #258, iplan-standard #30 all
  MERGED** (iplan-standard is governance tier — OPS-0062-excluded from AI
  auto-merge, so the founder merged it). operations + framework are covered-by-own-tooling (not the canon
  reusable). **Key lesson: a blind `markdownlint-cli2 --fix` is UNSAFE on these
  docs** — it corrupts prose (a literal `+`/`#` at line-start misread as a
  list/heading marker → MD004/MD001 cascades) and code identifiers
  (`__init__.py`→`**init**.py` via MD050). Every graduation reflowed the prose-`+`
  roots first, used `--fix` only for genuinely-structural rules, and ran a
  documentation-specialist to verify zero prose changed (it caught real MD050
  BLOCKERs on iplan-runner + iplanic; the pre-commit `check_plan` gate caught
  `--fix` breaking verified-planning ledger citations twice). engramory added a
  repo-local `MD025.front_matter_title:""` for its `sdd/**` frontmatter-titled
  docs. **Still pending: arming each as a required status check = the
  founder-executed W4 step** (`docs/FLEET_BRANCH_PROTECTION_ARMING.md`; FT-12).
- **`docs-sync` dry-run → live.** 🔴 founder provisions `aidoc-flow-bot` App +
  `AIDOC_FLOW_BOT_ID`/`KEY` secrets per repo, then set `dry_run: false`. Weigh
  against the pending `doc-maintainer.yml` supersession at `ci/v2.0.0` — the
  dry-run adoptions may migrate to `doc-maintainer` rather than each graduating.

Ties to [[reference_canon_workflow_hard_constraints]] #3.

### FT-12 — fleet branch-protection arming anomalies (PLAN-007 W4 survey)

**Found:** 2026-07-12, PLAN-007 W4 read-only survey. Runbook:
`docs/FLEET_BRANCH_PROTECTION_ARMING.md`. Arming itself is 🔴 (founder-executed).
Three sub-issues the survey surfaced that need canon/repo remediation
independent of the arming act:

- **Phantom required-context (framework, business, iplanic).** Each arms a
  **bare** `Lint / format / security hooks` required-check but emits the canon
  `call / Lint / format / security hooks` → the bare context never posts, so
  these repos have been merging via `--admin`. Fix = re-point the required
  context to the emitted name (in the runbook's step B).
- **iplan-runner canon adoption — RESOLVED (iplan-runner #88, 2026-07-12).**
  `call / gitleaks` was failing on a placeholder HMAC key in the
  `iplanic-vectors/` conformance vectors (the canon default allowlist matches a
  bare `vectors/` but not the compound dir name). Fixed consumer-side via
  `config-path: .gitleaks.toml` + a proper `[extend] useDefault=true` allowlist
  (which also un-broke the repo's previously rule-less, no-op standalone
  gitleaks). On the fix PR, `call / ai-review` + `call / composition` ran green —
  the earlier "skipped" was PR-specific, not a wiring defect. Its canon `call/…`
  gates are now armable.
  - _Canon observation (low-priority):_ the reusable's default gitleaks
    allowlist path `(^|/)(vectors|fixtures|testdata|examples)/` misses compound
    names like `*-vectors/`. The `config-path` escape hatch is the intended
    per-consumer fix, so leaving the canon default strict (opt-in) is defensible;
    broadening it fleet-wide risks over-suppression. No action unless a second
    consumer hits it.
- **interlog `call / composition` conditionality.** Armed but did not emit on
  its latest PR (path-filtered?). Confirm composition posts on every PR or
  reclassify it non-required.

### FT-13 — private-repo standards-drift callers are broken; one pins an unresolvable SHA

**Found:** 2026-07-16, triaging the `llm-router` flowci-feedback filing.
**Surfaces:** `.github/workflows/standards-drift.yml` (fleet pin-currency step);
the consumer-side callers in operations / business / iplanic / interlog.

**The mechanism exists.** `sync/check-standards-drift.sh` chains
`check-pin-currency.sh` itself (uses `sync/check-pin-currency.sh` if present
locally, else `curl`s it from `${CI_TAG}`), so a private repo running
standards-drift gets pin-currency transitively without naming it in the caller.
Canon's own fleet audit cannot cover the private repos — `GITHUB_TOKEN` cannot
read private repo contents — so the per-repo run is the intended path.

**Verified facts (2026-07-16). Only these; see the caution below.**

1. **`business` and `interlog` have no `standards-drift.yml` at all** — so they
   get no drift and no pin-currency signal from any source.
2. **`iplanic`'s caller pins a SHA that can never resolve.**
   `e15ec7d44234726195da316a740ad1684a2c5abd` is the **annotated tag object** of
   `ci/v1.6.0`, not a commit: `gh api repos/…/commits/e15ec7d…` returns `422 No
   commit found`, and raw.githubusercontent has never served it (HTTP 404). The
   commit the tag dereferences to is `e827ab8268917ea4a81a0b8ddbc59eace702f7ed`,
   which serves HTTP 200 today. So this is a **permanent authoring bug, not
   decay** — the caller has never worked, and "re-pin it to a live tag" is the
   wrong fix. The right one is to deref the tag
   (`gh api repos/<r>/git/refs/tags/<tag> --jq '.object.sha'` returns the TAG
   object for an annotated tag; dereference via `git/tags/<sha> --jq
   '.object.sha'`, or just pin the tag name).
3. **Every private standards-drift run on record has failed** (latest:
   2026-07-13). None is presently producing a signal.

**Caution — this entry has now been wrong three times; do not add a fourth
without measuring.** (a) The original comment claimed the private four were
"covered by their OWN weekly run, which chains check-pin-currency.sh in-repo" —
true for operations, false for the rest. (b) Its first correction over-swung to
"none of them chains pin-currency" — false for operations; that measurement
grepped only the caller YAML and missed the chain one level down, inside the
script the caller invokes. (c) Its second correction attributed operations'
2026-07-13 failure to its current checkout-based caller — but that caller was
authored **2026-07-16**, after the run. At the time of the failure operations
was `curl`-ing the same unresolvable `e15ec7d…` URL as iplanic, so the two had
the *same* bug, not different ones. **operations' current caller has never run**;
whether its chain works is unproven by inspection alone.

The checks each miss would have needed: grep the transitive path, not just the
caller; and confirm the cited run actually executed the caller you are
describing (`gh api "repos/<r>/commits?path=<workflow>"` vs the run's
`createdAt`).

**Why it matters:** a consumer that cannot fetch its drift script has no drift
signal and no indication that it has none — the same absent-feedback-loop shape
as the fleet-wide `enforce_admins` drift. Note this specific shape is NOT caught
by `sync/check-drift.sh`, even after the 2026-07-16 coverage work: iplanic
references canon via a `curl` inside a `run:` step, not a `uses:`, so there is no
`@ref` for the caller-scan to see. Reporting unresolvable canon references in
`run:` steps is unsolved.

**Fix sketch (needs a decision, hence a plan not a patch):** the filing proposed
adding `sync/*.sh` to `manifest.json` so every consumer gets a copy. Copying a
script into every consumer manufactures another drifting surface — and the
hand-rolled callers above are what that looks like in practice. The alternative
is a canon reusable + a thin caller template that resolves the scripts at the
consumer's pinned tag, matching how every other canon surface is consumed and
getting version-pinning (and drift-checking, now that callers are
manifest-resolved) for free — and removing the class of bug in (2) entirely,
since a `uses:` pin cannot be an unresolvable tag object. Choosing between them —
and deciding whether `install.sh` should apply server-side standards at all (🔴:
it mutates consumer repos) — is the scope of the adoption-model plan (next free
PLAN number). Consumer-side callers are cross-repo work and go through the
ops/inbox runbook, never a direct edit from a canon session.

### FT-14 — `pre_push_check.sh`'s yamllint is stricter than canon's own CI gate, so canon fails its own hook

**Found:** 2026-07-16, running `scripts/pre_push_check.sh` while closing the
flowci-feedback findings.
**Surfaces:** `scripts/pre_push_check.sh` §2 (yamllint); `tests/test_lint.sh:20-23`;
the absent `install/templates/.yamllint.yaml`.

**Two invocations of the same tool disagree:**

- `tests/test_lint.sh:22` — canon's **authoritative** gate (runs in `tests.yml`
  on every PR) invokes yamllint with an explicit relaxed profile:
  `line-length: disable, document-start: disable, truthy: disable, …`. Its own
  comment says *"yamllint relaxed (no line-length…)"*. It is green on `main`.
- `scripts/pre_push_check.sh:98-101` — falls back to a **bare `yamllint`** when
  no `.yamllint.yaml` exists. Canon has none, so the hook enforces line-length
  and every rule the CI gate deliberately disabled.

**Effect:** measured 2026-07-16 on pristine `main`, bare yamllint reports **172
issues** across `.github/workflows/`, so `pre_push_check.sh` **exits non-zero on
an unmodified canon checkout**. Anyone with yamllint installed who runs the hook
is told not to push work that canon's own CI accepts. The hook is not currently
installed as a git hook in every checkout, which is the only reason this has not
blocked anyone — i.e. the local gate is inert where it is wrong, and wrong where
it is not inert.

**Relation to the filing.** This is flowci-feedback's *"install.sh ships no
default `.yamllint.yaml`"* finding. That entry was assessed as **inert for
consumers** and that assessment holds — `install.sh` never installs yamllint, so
a fresh consumer's check 2 skips-with-notice and no consumer-facing CI runs
yamllint at all. But it is **not** inert for **canon**, which has yamllint
available and no config. The filing reasoned from consumer symptoms and reached
the right fix shape for the wrong repo.

**Fix sketch (a decision, not a patch — hence not done here):** the profile is
already chosen and proven; `tests/test_lint.sh:22` is the de-facto canon
yamllint config. Either (a) extract that inline `-d` profile into a repo-root
`.yamllint.yaml` and have both call sites read it — one source of truth, and
`pre_push_check.sh`'s existing `-f .yamllint.yaml` branch (dead code today,
never exercised in canon) starts working; or (b) leave canon's config absent and
make the hook's fallback match the relaxed profile. Prefer (a). Whether the same
file also ships to consumers via `install/templates/` + `manifest.json` is the
separable question the filing actually asked, and it should be settled with the
adoption-model plan rather than as a drive-by: shipping a lint config to repos
that do not run the linter adds a drift surface for no signal.

### FT-15 — audit fleet reusables (ai-review / doc-maintainer / docs-sync) for the `workflow_ref`-is-the-caller asset-fetch bug

**Status:** OPEN — investigation (do NOT blind-fix the four reusables).
**Priority ELEVATED 2026-07-19 → trust-blocker:** the value/standard-readiness
assessment (`plans/ASSESSMENT_flow-ci-value-and-standard-readiness.md`) makes this
gating — if the deployed ai-review fetches its rubric/client from `main` rather
than the pinned tag, the gate's "version-deterministic" guarantee has not held in
production. Confirm (a throwaway run logging `github.workflow_ref` from inside a
reusable) BEFORE trusting the pin story or widening deployment.

**Surfaced by:** PLAN-015 B2 pre-push review (2026-07-18, security + correctness
lenses, both CONFIRMED with GitHub-docs citations). While building the new
`standards-drift` reusable, two independent reviewers established that inside a
`workflow_call` reusable, **`github.workflow_ref` resolves to the CALLER's entry
workflow ref (the consumer's default branch), NOT the reusable's pinned tag.**
The reusable's own resolved commit is `github.job_workflow_sha`.

`standards-drift.yml` was fixed to use `job_workflow_sha` before merge. But the
**existing** fleet reusables parse `github.workflow_ref` to build their
cross-repo asset-fetch URLs:

- `ai-review.yml:427-447` — fetches rubric / schema / `litellm_client.py` from
  `…/aidoc-flow-ci/${REF}/…` where `REF="${GITHUB_WORKFLOW_REF##*@}"`.
- `doc-maintainer.yml:135,142,196,203,209` — same pattern for
  `reconcile.py` / `litellm_client.py`.
- `docs-sync.yml:109-117` — same.

**The claim to verify (NOT yet verified — this is why it's an investigation):**
if `REF` is really the caller's ref, these fetch assets from
`aidoc-flow-ci@<consumer-default-branch>` (e.g. `main`), NOT from the consumer's
adopted `@ci/vX.Y.Z` pin — so the pin does not control which rubric / client /
reconcile-script version actually runs. This "works" today only because
`main` ≈ the tagged asset for same-owner consumers, and it would silently track
`main` rather than the pinned release. It is a **determinism** regression, not a
cross-domain supply-chain break (host + repo path are hardcoded; only the ref is
wrong).

**Why not fixed here:** (1) these are in-production, security-reviewed reusables
that every consumer's AI gate depends on — a blind edit is high-risk; (2) it must
first be **confirmed live** (a throwaway run logging `github.workflow_ref` vs
`github.job_workflow_sha` from inside one of these reusables) rather than reasoned
from docs alone, because the "works in production" evidence is genuinely in
tension with the docs claim and one side is wrong; (3) the fix (switch to
`job_workflow_sha`) is mechanical once confirmed, but should land as its own
reviewed PR per reusable, not bundled into B2.

**Fix sketch (after confirmation):** `github.job_workflow_sha` is NOT
expression-accessible (verified 2026-07-18: actionlint rejects it and it is not
in the documented `github` context — the reviewer that suggested it conflated the
OIDC token claim with a context field), so the fix is NOT a drop-in swap. The
robust pattern (used by the fixed `standards-drift.yml`) is to **derive the
adopted `@ci/vX.Y.Z` tag from the consumer's OWN checked-out caller file** and
fetch from that tag + a hardcoded `vladm3105/aidoc-flow-ci` owner. For ai-review
this is more involved than standards-drift — the review job does not check out the
consumer's `.github/workflows/` the same way — so each reusable needs its own
analysis, which is why this stays an investigation, not a mechanical sweep.
Correct any "pinned tag" determinism wording in their comments/docs to match.
