# PLAN-019 — pre-prod review closure + `ci/v2.12.0` cut readiness

> Status: **READY — 2026-07-23** (verified-planning: 3 passes, 2 independent,
> zero load-bearing findings; citation gate green). Owning repo: `aidoc-flow-ci`.
> Target release: **`ci/v2.12.0`** (MINOR).
>
> **Goal:** close the gaps a five-lens pre-prod review (2026-07-23) found in the
> `ci/v2.11.0..main` release candidate so the next tag can be cut *honestly*,
> then execute the 🔴 FT-30 cold-start dry-run against `aidoc-flow-feedback-desk`
> — a genuine not-yet-onboarded adopter, so the dry-run doubles as its real
> onboarding.

## 0. Provenance — the review this plan closes

A `ci-preprod-review` run (5 lenses: security, correctness, docs, portability,
governance) on the candidate returned **BLOCKER**. Findings were verified
against source before landing here; two agent claims were downgraded on
verification (the label-bypass is not a *both-checks-green* blocker because
`APP_REVIEWER_1_BOT_ID` is set on all 9 adopted repos — verified live; and the
FT-28 security claim is narrower than stated). The surviving items, by the
review's severity, seed the FT ledger entries FT-39…FT-52 and drive this plan.

The plan is **not** "PLAN-018 was wrong." PLAN-018's headline (FT-32 refresh,
the CHANGELOG, the FT ledger) verified correct. These are the residuals a fresh
adversarial pass surfaced on top of it.

## 1. Sequencing — four gates

The tag cut and the rollout are different bars. Items are assigned to the
earliest gate they must clear.

| Gate | Meaning | Items |
| --- | --- | --- |
| **G1 — tag-cut blockers** | must land on `main` *before* the prep PR | FT-39, FT-40, FT-41, FT-42 (Workstream A) |
| **G2 — the 🔴 dry-run** | founder-executed on feedback-desk, pinned to the G1 merge SHA; gates the actual `git tag` | §6 runbook |
| **G3 — ship with the tag** | land in `ci/v2.12.0` but not blocking the cut's *honesty* | FT-43…FT-48 (Workstreams B, C partial) |
| **G4 — before/with fleet rollout** | not gating the tag; gating the 7-consumer rollout | FT-49…FT-52 (Workstreams D, E), governance-currency edits |

Rationale: G1 items are either a fleet-bricking correctness hole in the tool the
rollout drives (FT-39) or a green-suite-hides-a-disabled-gate test gap (FT-40,
FT-41) or the library's largest standing secret-trust risk (FT-42). Everything
downstream of the tag can ride G3/G4 because canon's own CI never exercises the
cold-start or macOS paths — which is exactly why the review, not CI, found them.

## 2. Workstream A — G1 tag-cut blockers

### FT-39 — `fetch_template` writes whatever the transport returns; `--update` infers non-interactive from a missing TTY

**Fix (`install/install.sh`):**

1. In `fetch_template` (the `curl -fsSL … -o "$dst"` body), after a successful
   fetch add `test -s "$dst"` and reject a body whose first non-space byte is
   `<` (an HTML error page served 200). Fail loud, `return 1`.
2. For the pre-commit fragment specifically, after fetch assert the body carries
   a `^# CANON: aidoc-flow-ci pre_push_check v[0-9]+` line before it is used for
   the version compare — otherwise an empty/HTML fetch makes `marker_version`
   return `1` and silently freezes every legacy consumer's refresh (FT-32 fails
   open).
3. Make `--update`'s destructive replace require an explicit `--non-interactive`
   / `--yes` flag rather than inferring it from `[ ! -t 0 ]`; a piped run with
   no flag must default to keep-local, not replace.
4. Add teeth: extract the fetch-and-validate as a driven block (marker pattern,
   like `>>> PRECOMMIT-MERGE >>>`) and add a `tests/test_install.sh` case that a
   0-byte / `<`-leading fetch is rejected; a mutation removing the `test -s` must
   go red.

### FT-40 — the FT-28 SHA-peel guard is untested; shipped code can be disabled with the suite green

Verified by mutation: `ai-review.yml:508` → `if false;` in both resolvers leaves
`tests/test_resolver.sh` at 62/0. The suite's `verify()` (`:151-159`)
re-implements the comparison rather than driving the shipped step; `:140-143`
are grep-presence assertions.

**Fix:** wrap the FT-28 resolver comparison in the two resolvers with an
extract-marker pair and drive the *shipped* block from `test_resolver.sh` with a
stubbed `curl` returning a mismatched SHA; assert the run hard-fails. The
`verify()` re-implementation is deleted. A `if false;` mutation must go red.

### FT-41 — `markdown-lint`'s blocking default is unasserted

Verified by mutation: `markdown-lint.yml:63` `default: true` → `false` leaves
`tests/test_contract.sh` at 271/0.

**Fix:** add to `test_contract.sh` the inverse of the three report-only-scanner
assertions already present — assert `markdown-lint.yml`'s `fail-on-findings`
input defaults to `true`. A one-char flip to `false` must go red.

### FT-42 — `ai-review`'s `secrets: inherit` is structurally forced, not deferred

The reusable declares `workflow_call:` with `inputs:` only and **no `secrets:`
block** while its body reads 8 secrets, so a caller *cannot* pass an explicit
map — which is why the FT-27 least-privilege pass could convert
`docs-sync`/`doc-maintainer`/`auto-merge` but not this one.

**Fix (`.github/workflows/ai-review.yml` + `install/templates/workflows/ai-review.yml`):**

1. Add a `secrets:` block to the reusable's `workflow_call` declaring all 8
   (`APP_REVIEWER_1_ID`, `APP_REVIEWER_1_KEY`, `APP_AUTOFIX_ID`,
   `APP_AUTOFIX_KEY`, `AI_REVIEW_TOKEN`, `LITELLM_BASE_URL`,
   `LITELLM_REVIEW_API_KEY`, `LITELLM_FIX_API_KEY`), each `required: false` (the
   flows already self-skip when unset).
2. Flip the caller template from `secrets: inherit` to an explicit map of those 8.
3. `test_contract.sh`: assert the template carries no `secrets: inherit` and that
   every secret the reusable references is declared in `workflow_call.secrets`
   (the same completeness check the other AI-flows already pass).
4. This is a schema change to the reusable's callable surface, but additive
   (`required: false`) — no consumer break. Note in CHANGELOG under `## Unreleased`.

> **Founder call available:** FT-42 is pre-existing debt, not a regression this
> candidate introduced. If the founder prefers to ride it on `ci/v2.13.0`, it
> moves to G3 — but it must not survive into the fleet rollout, because the
> rollout is what widens `inherit`'s blast radius to newly-armed consumers.

## 3. Workstream B — G3 rollout safety (ship with the tag)

### FT-43 — a label/draft event can supersede a RED `ai-review`

`ai-review.yml:93` (`trust`) and `:229` (`ai-review`) skip both jobs on any
`labeled`/`unlabeled` event whose label ≠ `skip-ai-review`, and on any draft PR;
the template (`:27`) subscribes to `labeled, unlabeled` and omits
`ready_for_review`. A skipped job satisfies the required context, so a label
applied after a `request_changes` flips `call / ai-review` green. FT-29 closed
only the `skip-ai-review` route; armed `composition` still blocks the others
today, so this is defence-in-depth loss plus real exposure on a not-yet-armed
adopter (feedback-desk before onboarding).

**Fix:** the naive move — from a job-level `if:` skip to a step-level guard that
concludes **SUCCESS** — does NOT work and re-opens the hole. A fresh SUCCESS at
the same HEAD *supersedes* a standing `request_changes` (branch protection keeps
the latest run for a required context — the workflow documents this exact hazard
at `ai-review.yml:295-300`), and on an unarmed adopter (`composition` INERT,
`ai-review` the only real gate) that flips `call / ai-review` green — the very
bypass this FT targets. A `skipped` and a `success` conclusion are equally
"satisfied" for branch protection; relocating the skip does not preserve the RED.

The guard must instead **fail closed** in the dangerous case, mirroring the
existing FT-29 pattern (`ai-review.yml:1056-1058`, which `exit 1`s the
`skip-ai-review` path when `COMPOSITION_BOT_ID` is unset — "Passing the skip here
would merge with ZERO review"):

1. On a label/draft event, **do not conclude a fresh SUCCESS** while unarmed
   (`APP_REVIEWER_1_BOT_ID` unset) — either `exit 1` (fail closed) or fall
   through to a full review, exactly as the composition-INERT guard at
   `:295-300` already does for the `pull_request_review` route. Never emit a
   green that can supersede a prior `request_changes` at that HEAD.
2. When armed, a label/draft event may conclude SUCCESS on `call / ai-review`
   without re-running — this is safe because the standing `request_changes` is
   independently enforced by `composition` (the identity gate holds a separate
   required-context RED that a label event does not flip), exactly as the
   existing armed review-event skip relies on (`ai-review.yml:307-313`). The
   unarmed case (point 1) is the only one that must fail closed.
3. Add `ready_for_review` + `converted_to_draft` to the template trigger types so
   a draft→ready transition triggers a real review.
4. Exclude label events from `concurrency.cancel-in-progress` so a label cannot
   cancel an in-flight genuine review.
5. Cover with a `test_contract.sh` assertion on the trigger set AND a driven test
   that an unarmed label-after-`request_changes` does not conclude SUCCESS (the
   FT-29 test shape, extended to the label/draft route).

### FT-44 — FT-32 silently under-delivers a *modified* hook

`install/install.sh:807-822` (pseudo-repo path) filters canon `local` hooks by
`id`; a hook whose *body* changed produces empty `missing_hooks`, records no
collision, and prints the clean "canon block appended" at `:875`'s `else` — no
WARN, no `NOTE marker stamped`, marker stamped anyway. `:884` promises a changed
hook is "REPORTED"; it isn't. Most-likely future change: `aidoc-flow-pre-push`.

**Fix:** when a canon `local` hook id is present-but-not-identical in the
consumer, emit a distinct `SKIPPED-ID=` signal and route it to the same partial-
merge NOTE block (`:878-884`). Cover in `test_precommit_refresh.sh` — a modified-
body hook must produce the NOTE, not the clean summary.

### FT-45 — `required-context-map.py` discards the job-id half of the context

`install/required-context-map.py:102` does `_jobid, name = ctx.split(" / ", 1)`
and drops `_jobid`. Two shipped templates don't key on `call`:
`links.yml` → `internal`/`external`, `standards-drift-private.yml:38` → `drift`.
A wrong job-id in a branch-protection JSON validates as "producer installed" →
operator arms → every PR pins forever (verbatim the F2 hang this tool
generalizes).

**Fix:** validate `jobid` against the producing caller template's actual job
keys, not just `name`. Extend `test_required_contexts.sh` with a case that a
`call / check-drift` (wrong key for `drift / check-drift`) is flagged, not passed.

### FT-46 — canon has not applied its own FT-27 values; allowlist is wider than the rule

`install/templates/actions-permissions.json` sets `verified_allowed: true`
alongside the three-pattern allowlist — wider than REPO_STANDARDS §4.3 (the rule
that forced `gacts/gitleaks` → binary). Canon's live
`can_approve_pull_request_reviews` is `true` while the template ships `false`.

**Fix:** set `verified_allowed: false` in the template; add applying
`actions-permissions.json` to canon itself (via `apply-standards.sh --apply`) as
a G4 rollout step and a RELEASE_CHECKLIST post-release item. Note: FT-27 is a
template change until applied per-repo — the ledger entry is amended to say so.

### FT-47 — CI only ever exercises the fallback YAML backend

`.github/workflows/tests.yml:45` installs `python3-yaml` only, so
`install.sh:701-705` always takes the PyYAML path the docs tell operators not to
use; the marker-strip fix at `:857-861` is vacuously asserted in CI (red locally
under ruamel, green without).

**Fix:** `pip install ruamel.yaml` in `tests.yml`; run the merge/refresh tests
under both backends (matrix or a second invocation) so the ruamel round-trip's
comment-preservation property has coverage.

### FT-48 — `release.sh prep` has no on-main / up-to-date guard

`scripts/release.sh` `prep()` (`:50-58`) checks tag-absent, VERSION-differs,
tree-clean, branch-absent — but not `HEAD == origin/main`, while `tag()`
(`:148-151`) has both. A prep from a stale main promotes an incomplete CHANGELOG
that `tag`'s VERSION-match guard cannot catch.

**Fix:** add the same on-main + `origin/main`-up-to-date checks to `prep()`;
add a `test_release.sh` fixture asserting off-main prep is rejected.

## 4. Workstream C — governance & docs currency (G3 for docs on the rollout path; rest G4)

- **FT-49 (G3 — on the rollout path):** `docs/FLEET_BRANCH_PROTECTION_ARMING.md:65`
  imperatively instructs `CI_TAG=ci/v2.1.0` — a 10-release-backwards repin in a
  founder-executed runbook. Replace both hardcoded pins with "the current release
  tag (see `../VERSION`)".
- **G3:** `docs/architecture.md:84-86` describes `markdown-lint`/`links`/
  `secret-scan` as running via `markdownlint-cli2-action`/`lychee-action`/
  `gacts/gitleaks` — all install binaries; `secret-scan.yml:1-8` says
  `gacts/gitleaks` is *blocked*. Correct the three rows and the "11 shared
  workflows" header (16 ship); or delegate the table to `WORKFLOWS.md`.
- **G3:** this cycle's markdown autofix corrupted prose in 4 adopter docs by
  turning a wrapped-line leading `+` into a list bullet — `docs/security.md:293`,
  `docs/multi-project-guide.md:7`, `docs/AI_CI_DEPLOYMENT.md:309`,
  `docs/PLAYBOOK_governance-canon-rollout.md:18`. Reword to avoid a line-initial
  `+`/`-`.
- **G3:** `docs/REPO_STANDARDS.md:1368` says templates pin `@ci/v2.0.0` (actual
  `@ci/v2.11.0`); add it to `sync-version-refs.sh` TARGETS or reword as
  version-neutral. `docs/README.md` needs an `EXERCISER_INVENTORY.md` row.
- **G4 governance-currency (one small PR, ≤3 surfaces per OPS-0061):**
  `ROADMAP.md:11` (still headlines `ci/v2.10.0`, no PLAN-018), `PLAN-018:3`
  (`Status: DRAFT`), `HANDOFF.md:45` (FT-36 listed open vs ledger CLOSED).
- **FT-38 amend:** the `rev: v5.0.0` list is 5 repos, not 4 — `business`
  (`/opt/data/aidoc-flow/business/.pre-commit-config.yaml:7`) is the fifth and
  additionally has no `# CANON:` marker (first-adoption branch → same collision).

## 5. Workstream D + E — G4 (before/with fleet rollout)

- **FT-50 (portability):** GNU-only `sed -i` at `install/install.sh:449,454` and
  `deploy-ci-wizard.sh:257` — route through a portable form (`sed -i.bak … && rm`
  or a python3 rewrite, python3 already required). Add a `BASH_VERSINFO` guard at
  the top of `install.sh` (`:371` `mapfile` runs unguarded, unlike its siblings);
  correct `install/README.md:38` — the bash4 requirement is unconditional on
  `install.sh`, not avoidable by skipping the pre-push hook.
- **FT-51 (docs):** `docs/runners.md:149` leads with "Org-level registration
  (recommended)"; `vladm3105` is a personal account and `PLAN-009:137-140`
  already records org-level is impossible here. Demote to per-repo-primary.
- **FT-52 (canon self-governance, 🔴 founder):** canon `main` has no branch
  protection and no tag ruleset (verified live: `branches/main/protection` → 404,
  `rulesets` → `[]`), while its own `branch-protection-product.json:2` names
  `aidoc-flow-ci` as a product-tier repo. Apply `branch-protection-product.json`
  to canon; add an immutable `ci/v*` tag ruleset (this is the *actual* mitigation
  for the mutable-tag trust the whole fleet pins against). Prepare as an
  `ops/inbox` runbook — 🔴 write-to-canon-settings, founder-executed.
- **Also G4:** self-callers pin `@ci/v2.11.0`, so "5 of 16 self-run" never
  exercises the candidate body — correct `EXERCISER_INVENTORY.md:37`'s regression
  claim or add an `@main`-on-`pull_request` self-caller variant. `# gitleaks:allow`
  is PR-controllable on a required check — grep the diff for added
  `gitleaks:allow` and fail, or document as accepted residual in `security.md §3c`.

## 6. The 🔴 FT-30 cold-start dry-run runbook — `aidoc-flow-feedback-desk`

**This is G2 and it gates the `git tag`.** Canon cannot exercise its own cold
start; feedback-desk is a real not-yet-onboarded adopter (verified: no
`.github/workflows/`, no `.pre-commit-config.yaml`, canon not referenced), so a
cold-start `install.sh` against it is both the FT-30 proof *and* feedback-desk's
genuine onboarding.

**feedback-desk is PRIVATE** (verified: `isPrivate: true`), which splits the
readiness question into two separable parts:

- **Part A — the installer cold-start (what FT-30 / RELEASE_CHECKLIST gates the
  tag on).** `install.sh` fetches templates, writes CODEOWNERS/config/workflows,
  merges the pre-commit fragment, and creates 18 labels. This exercises F1/F2/F3
  and is visibility-independent for the *installer* itself. This is the tag gate.
- **Part B — arming feedback-desk's gates GREEN (true onboarding).** Because it
  is private, the CI *runs* need the fleet Phase-0 infra that does NOT exist for
  this repo yet: a registered `["self-hosted","ci-runner","single-use"]` pool
  (else every job queues forever — never `ubuntu-latest` on a private repo),
  per-repo LiteLLM secrets (`LITELLM_BASE_URL` + review/fix keys), and
  `APP_REVIEWER_1_BOT_ID` + the App secrets (verified UNSET — the one unarmed
  member; unset = the FT-43 window). Part B is a set of 🔴 founder actions and is
  NOT required for the tag cut — only Part A is.

**Preconditions for Part A (the tag gate):**

- Workstream A (G1) merged to `main` — the dry-run must exercise the *fixed*
  `install.sh`, not the candidate as it stands now.
- `export CI_TAG=<G1-merge-sha>` (below) — non-negotiable.

**The single most important line:** the runbook MUST `export CI_TAG=<G1-merge-sha>`
(or the tag once it exists). Without it `install.sh` resolves `CI_TAG` from
`VERSION`/the fallback and fetches the *previous* release's templates — validating
the pre-fix files, not the ones about to ship. This is the exact trap
`docs/RELEASE_CHECKLIST.md:46-56` calls out.

**Because this writes to another repo (clones it, creates 18 labels, opens an
onboarding PR), it is 🔴 — staged as an `operations/ops/inbox` runbook and
founder-executed, never run in-session** (per the writes-to-other-repos-inbox-first
rule). Deliverable of this plan: the runbook file, not its execution.

**Expected GREEN (Part A):** the run reaches "creating canonical labels" and the
final next-steps block with no `FAIL`/`404`; `composition-private.yml` and
`pre-commit.yml` both resolve (F1/F2 live); the fragment installs with a `v2`
marker (F3); the runner-pool probe + LiteLLM-HTTP note print without aborting. On
Part-A green, `release.sh tag ci/v2.12.0 --dry-run-verified` may proceed — the
tag does **not** wait on Part B.

**Executable runbook:** `plans/ROLLOUT_plan019-feedback-desk-coldstart.md` (this
repo) holds the exact founder commands for Parts A + B. The `operations/ops/inbox`
item is a short pointer to it (the established pattern — cf. the FLEET_BRANCH_
PROTECTION_ARMING inbox item). The runbook is a deliverable of this plan; its
execution is 🔴 founder-only.

## 7. Semver

**MINOR → `ci/v2.12.0`.** Additive surfaces (new tests, new validation branches,
the `ai-review` `secrets:` declaration `required: false`, guard additions) with
no consumer-input break. FT-42's `secrets:` block is the only callable-surface
change and it is backward-compatible.

## 8. Out of scope

The three report-only-scanner behaviours, the autofix separation-of-duties
design, and the public-repo fork-safety model all verified correct in the review
and are not touched. No change to the FT-32 core merge mechanism (verified
converged across all 8 siblings) beyond the FT-44 honesty signal.

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | `fetch_template` curls to `$dst` with no `test -s` / shape check | `fetch_template` | install/install.sh:281 |
| 2 | `--update` treats missing TTY as non-interactive and sets replace | `[ ! -t 0 ]` | install/install.sh:396 |
| 3 | empty fetched fragment ⇒ `marker_version` returns 1 (fails open) | `marker_version` | install/install.sh:677 |
| 4 | unversioned marker fallback regex when no `v[0-9]+` present | `CANON_MARK_LINE` | install/install.sh:682 |
| 5 | pseudo-repo merge filters canon `local` hooks by id only | `missing_hooks` | install/install.sh:817 |
| 6 | partial-merge NOTE block is the only honest-summary path | `NOTE  marker stamped` | install/install.sh:883 |
| 7 | clean "canon block appended" else-branch (no WARN) | `canon block appended` | install/install.sh:886 |
| 8 | `mapfile` in `--update` path with no BASH_VERSINFO guard | `mapfile -t lines` | install/install.sh:371 |
| 9 | GNU-only `sed -i -E` pin rewrites (two sites) | `sed -i -E` | install/install.sh:449 |
| 10 | second GNU `sed -i` SHA-form rewrite | `sed -i -E` | install/install.sh:454 |
| 11 | sibling scripts DO guard bash4; install.sh is the exception | `BASH_VERSINFO` | install/apply-standards.sh:84 |
| 12 | `ai-review` reusable `workflow_call` declares inputs, no `secrets:` block | `workflow_call:` | .github/workflows/ai-review.yml:39 |
| 13 | `permissions: {}` default; jobs re-grant | `permissions: {}` | .github/workflows/ai-review.yml:70 |
| 14 | `trust` job skips on non-skip label events + drafts | `github.event.label.name == 'skip-ai-review'` | .github/workflows/ai-review.yml:93 |
| 15 | `ai-review` job carries the same skip `if:` | `needs: trust` | .github/workflows/ai-review.yml:229 |
| 16 | `cancel-in-progress: true` on the ai-review concurrency group | `cancel-in-progress` | .github/workflows/ai-review.yml:72 |
| 17 | FT-28 SHA-peel guard both resolvers, gated `if [ -n "$CANON_SHA" ]…` | `CANON_SHA` | .github/workflows/ai-review.yml:508 |
| 18 | template still ships `secrets: inherit` | `secrets: inherit` | install/templates/workflows/ai-review.yml:68 |
| 19 | template triggers include labeled/unlabeled, omit ready_for_review | `types: [opened, synchronize, reopened, labeled, unlabeled]` | install/templates/workflows/ai-review.yml:27 |
| 20 | `markdown-lint` `fail-on-findings` defaults true (blocking) | `fail-on-findings` | .github/workflows/markdown-lint.yml:63 |
| 21 | `test_resolver.sh` re-implements `verify()` rather than driving shipped step | `verify()` | tests/test_resolver.sh:151 |
| 22 | resolver teeth are grep-presence assertions | `application/vnd.github.sha` | tests/test_resolver.sh:140 |
| 23 | `required-context-map.py` discards the job-id half | `_jobid, name = ctx.split` | install/required-context-map.py:102 |
| 24 | `links.yml` job keys are internal/external, not `call` | `internal:` | install/templates/workflows/links.yml:28 |
| 25 | `standards-drift` job key is `drift`, not `call` | `drift:` | install/templates/workflows/standards-drift-private.yml:38 |
| 26 | `actions-permissions.json` sets `verified_allowed: true` | `verified_allowed` | install/templates/actions-permissions.json:17 |
| 27 | template ships `can_approve_pull_request_reviews: false` | `can_approve_pull_request_reviews` | install/templates/actions-permissions.json:30 |
| 28 | `tests.yml` installs python3-yaml only (PyYAML path in CI) | `python3-yaml` | .github/workflows/tests.yml:45 |
| 29 | install.sh prefers ruamel, warns on PyYAML comment-strip | `ruamel.yaml` | install/install.sh:701 |
| 30 | marker-strip filter (the fix vacuously tested in CI) | `# CANON: aidoc-flow-ci pre_push_check` | install/install.sh:860 |
| 31 | `release.sh prep` guards: tag/VERSION/tree/branch — no on-main | `prep()` | scripts/release.sh:50 |
| 32 | `release.sh tag` DOES guard on-main + origin/main | `must be on main to tag` | scripts/release.sh:149 |
| 33 | `secret-scan.yml` installs gitleaks BINARY, wrapper blocked by §4.3 | `NOT a marketplace wrapper` | .github/workflows/secret-scan.yml:75 |
| 34 | `architecture.md` says secret-scan runs "via gacts/gitleaks" | `gacts/gitleaks` | docs/architecture.md:86 |
| 35 | `architecture.md` header says "11 shared workflows" (16 ship) | `11 shared workflows` | docs/architecture.md:69 |
| 36 | `FLEET_BRANCH_PROTECTION_ARMING` imperatively repins to v2.1.0 | `CI_TAG=ci/v2.1.0` | docs/FLEET_BRANCH_PROTECTION_ARMING.md:66 |
| 37 | `REPO_STANDARDS` says templates pin @ci/v2.0.0 | `@ci/v2.0.0` | docs/REPO_STANDARDS.md:1368 |
| 38 | `runners.md` leads with org-level "recommended" | `Org-level registration (recommended)` | docs/runners.md:149 |
| 39 | RELEASE_CHECKLIST FT-30 requires `CI_TAG=<merge-sha>` against throwaway repo | `COLD-START DRY-RUN` | docs/RELEASE_CHECKLIST.md:53 |
| 40 | ROADMAP still headlines ci/v2.10.0 as current | `Current release — ci/v2.10.0` | ROADMAP.md:11 |
| 41 | PLAN-018 status line still reads DRAFT | `Status: **DRAFT` | plans/PLAN-018_canon-completeness.md:3 |
| 42 | HANDOFF lists FT-36 as open | `Also open: FT-33, FT-35, FT-36, FT-37` | HANDOFF.md:99 |
| 43 | FRAMEWORK-TODO records FT-36 CLOSED | `Status:** CLOSED (PLAN-018 Workstream C / PR C4` | plans/FRAMEWORK-TODO.md:50 |
| 44 | `business` pins pre-commit-hooks rev v5.0.0 with no CANON marker | `rev: v5.0.0` | ../business/.pre-commit-config.yaml:7 |
| 45 | composition passes when APP_REVIEWER_1_BOT_ID unset (INERT) | `composition INERT` | .github/workflows/composition.yml:103 |
| 46 | a fresh SUCCESS supersedes a prior request_changes at the HEAD (the FT-43 hazard) | `SUPERSEDE a prior` | .github/workflows/ai-review.yml:297 |
| 47 | step-level skip concludes SUCCESS keeping the required check green | `job concludes` | .github/workflows/ai-review.yml:1022 |
| 48 | FT-29 pattern: skip path fails closed (exit 1) when unarmed — the model FT-43 must mirror | `merge with ZERO review (FT-29)` | .github/workflows/ai-review.yml:1057 |

## Review log

### Pass 1 — 2026-07-23 — author self-review

Adversarial self-pass by the author before dispatching the independent reviewer.
Focus: severity honesty, sequencing correctness, ledger completeness.

- **Downgrades held:** re-checked the two claims I overrode from the review.
  Label-bypass (FT-43) is genuinely *not* a both-checks-green blocker while
  `composition` is armed — `APP_REVIEWER_1_BOT_ID` verified set on all 9 adopted
  repos (row 45 cites the INERT branch it depends on). Correctly placed at G3, not
  G1. FT-42's severity framing (structurally forced, not a scheduling deferral) is
  load-bearing and cited (row 12).
- **Sequencing checked:** the FT-30 dry-run (§6) MUST run the G1-fixed
  `install.sh`, so G2 depends on G1 merge — captured as a precondition, and the
  `CI_TAG=<merge-sha>` requirement (row 39) is the named single-point-of-failure.
- **Fold:** dropped the un-citable "feedback-desk has no adopted canon" ledger row
  (an absence is not a `path:line`); the fact is verified by `git ls-files` and
  kept in §6 prose. Repointed 3 drifted citations via `--fix`.
- **Known soft spots for the independent pass to attack:** (a) is FT-42 safe to
  ship additively, or does adding a `workflow_call.secrets` block change resolution
  for consumers that today rely on `inherit`? (b) does the FT-43 step-level-skip fix
  actually make the job *conclude* on a required context, or just move where it
  skips? (c) is the G1/G3 line drawn correctly — is any G3 item actually
  tag-cut-blocking?

### Pass 2 — 2026-07-23 — independent (verified-planning-reviewer, fresh context)

Verified every prioritized ledger row against source (rows 1-7, 12, 14/15, 20,
26/27, 45 — all confirmed accurate). Soft spots (a) FT-42 additive-secrets safety
and (c) the G1/G3 gate line both cleared with evidence (GitHub forwards inherited
secrets by name regardless of a declared `secrets:` block; no G3/G4 item is
tag-cut-blocking; FT-43-at-G3 holds *contingent on* §6 arming feedback-desk).

**One load-bearing finding (soft spot b), folded:**

- **FT-43's fix was incorrect as written.** "Move the skip to a step-level guard
  so the job concludes on its own merits" — a step-level skip concluding
  **SUCCESS** (the pattern every existing skip step uses, `ai-review.yml:1022`)
  mints a fresh green that *supersedes* a standing `request_changes` at the same
  HEAD (`:297`), which on an unarmed adopter re-opens the identical bypass FT-43
  targets. A `skipped` and a `success` conclusion are equally "satisfied" for
  branch protection. **Fold:** rewrote the FT-43 fix to fail closed while unarmed
  (mirroring the FT-29 `exit 1` pattern at `:1057`), never minting a supersede-
  capable SUCCESS; added ledger rows 46-48 for the three symbols the corrected
  fix now rests on; added a driven-test requirement for the unarmed
  label-after-`request_changes` case. Verified the three new citations resolve.

### Pass 3 — 2026-07-23 — independent (verified-planning-reviewer, fresh context)

Narrow re-review of the FT-43 fold (independent pass #2 of ≤3, OPS-0066).
Verified the revised fix against source: `ai-review.yml:297` (SUPERSEDE hazard),
`:1022` (skip mints SUCCESS), `:1056-1059` (FT-29 `exit 1` model). Confirmed the
fix's fail-closed-when-unarmed requirement preserves the load-bearing property
(an unarmed label/draft event can never emit a green that supersedes a standing
`request_changes`), that the armed case is safe because `composition` holds the
gate independently, and that ledger rows 46-48 + the driven-test requirement are
accurate and cited. No regression to rows 1-45 or the gate table.

One non-load-bearing phrasing note (fix point 2 said "preserve the prior
conclusion" — GitHub concludes each run independently) folded for accuracy: point
2 now states the armed-case safety correctly (composition holds the RED). No
bypass either way.

**Result:** ready — zero load-bearing findings; ≥2 passes with ≥1 independent;
ledger fully cited (gate green).
