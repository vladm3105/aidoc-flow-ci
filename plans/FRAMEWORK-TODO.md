# FRAMEWORK-TODO — `aidoc-flow-ci`

Canon inconsistencies / bugs / improvement notes discovered while driving
the docs + workflows. Logged inline as found (per the framework-TODO
convention — examples/adoption ARE the system-under-test; their friction is
the framework's truth). Each item names the surfaces + a fix sketch; clear
when resolved.

## Open

### FT-1 — Branch-protection templates lag REPO_STANDARDS §2 on `call / verify`

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

### FT-3 — `labels.json` `skip-ai-review` description contradicts behavior

**Found:** 2026-07-09, PLAN-004 PR-A3 (`LABELS.md` rewrite).
**Surface:** `install/templates/labels.json` describes `skip-ai-review` as
"Operator override to re-fire ai-review", but the actual behavior
(`ai-review.yml` SKIP_REVIEW + `composition.yml:110-117` carry-forward) is
**suppress-and-carry-forward** — the label SUPPRESSES the reviewer on
subsequent pushes and carries the prior approval forward.
**Effect:** the terse description ships to consumers + is misleading.
`LABELS.md` documents the correct behavior + flags the discrepancy.
**Fix sketch:** update the `labels.json` description to
"Human override: suppress the reviewer on later pushes; composition
carries the prior approval forward" and PATCH-tag (label description
change is additive/cosmetic).

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

### FT-5 — `standards-drift` can't verify branch-protection / actions-permissions (needs `administration: read`)

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
**not registered on any runner** (real labels: `self-hosted,aidoc,ci-ephemeral`
[+ `ai-review`]).
**Effect:** a reader following runners.md registration steps would register a
`runner-self` label no caller targets. Educational drift, not a live break.
**Fix sketch:** reconcile the nickname — rewrite the reference docs to the real
`ci-ephemeral`/`ai-review` labels throughout (align docs to infra; preferred).
One focused docs PR; split to keep ≤3 surfaces.
