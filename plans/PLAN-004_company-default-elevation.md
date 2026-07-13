# PLAN-004 — Company-default elevation (pre-prod gap closure)

**Owner:** `aidoc-flow-ci` maintainer (vladm3105 + AI Crew)
**Origin:** founder direction 2026-07-09 — pre-production multi-agent review of
`aidoc-flow-ci` for elevation to the company-wide default CI standard for all
projects/repos. Five parallel review agents (security-auditor, code-reviewer,
documentation-specialist, system-architect, general-purpose governance-audit)
returned unanimous SHIP-WITH-FIXES verdicts converging on 5 BLOCKER clusters +
supporting HIGH findings that must close before elevation.
**Status:** SHIPPED — 2026-07-10 (ci/v1.7.0). A–E slices merged; tag + GitHub release cut. See `CHANGELOG.md` `## ci/v1.7.0`.
**Depends on:** PLAN-002 (workspace standards rollout — SHIPPED), PLAN-003
(project-governance-canon — SHIPPED / rollout in-progress). Neither is blocked
by this plan; this plan extends the canon-source dogfooding surface.
**Supersedes:** none. Complements PLAN-002 §5.5 (workflow rollout) + PLAN-003
§5.5 (governance-file rollout) with a canon-source hardening cycle.

## 1. Purpose

Close every gap identified in the 2026-07-09 pre-prod review so
`aidoc-flow-ci` can be marketed honestly as **"the company-wide default CI
standard for all projects/repos"** rather than "the aidoc-flow workspace CI
standard, adoptable by aidoc-flow-shaped projects." Five well-scoped PRs
sequenced from lowest-blast-radius (adopter docs) to highest-blast-radius
(breaking template placeholder substitution + update-path introduction).

**Goal statement (verifiable):** a company team unfamiliar with the
`aidoc-flow` workspace can bootstrap a fresh repo (Go, Terraform, docs-only,
or Python) from `install/install.sh` alone, get a working reviewer App + CI
pipeline, and stay current across `ci/vX.Y.Z` bumps without hand-editing
templates or losing local overrides.

## 2. Findings summary (from the 2026-07-09 pre-prod review)

Five review agents ran in parallel over the canonical files
(`.github/workflows/*.yml`, `install/**`, `sync/**`, `docs/**`, governance
surfaces). Verdict convergence:

| Agent | Verdict | BLOCKERs | HIGHs |
|---|---|---|---|
| security-auditor | SHIP-WITH-FIXES | 0 | 5 |
| code-reviewer (correctness) | SHIP-WITH-FIXES | 1 | 3 |
| documentation-specialist | SHIP-WITH-FIXES leaning BLOCKING externally | 6 | 8 |
| system-architect (portability) | SHIP-WITH-FIXES leaning BLOCKING for "company default" | 4 | 5 |
| general-purpose (governance-consistency) | SHIP-WITH-FIXES | 2 | 6 |

Deduplicated, the findings cluster into **5 BLOCKERs** (BL-1..BL-5) covering
de-branding, correctness, auto-merge bypass, adopter cold-start docs, and
update path — plus supporting HIGH-tier hardening.

### 2.1 BLOCKER clusters (must close before elevation)

- **BL-1 — De-brand templates.** `@vladm3105` hardcoded in 9 places in
  `install/templates/CODEOWNERS.template` + `install/templates/config.json.template:10`.
  `install/templates/CLAUDE.md.template` references canon via `../operations/*`
  + `../aidoc-flow-ci/*` relative paths at 8 places — only resolve inside
  the umbrella working tree. A company project cloned outside the umbrella
  gets dead canon links + broken CODEOWNERS the moment
  `require_code_owner_reviews: true` fires.
- **BL-2 — `doc-maintainer.yml` schedule bug.** `.github/workflows/doc-maintainer.yml:141-155`.
  Step 0 (reconcile) `exit 0` ends the STEP, not the JOB. Step 1 (dedup) is
  `if: github.event_name != 'schedule'` → skipped on cron → dedup output
  unset → `'' != 'true'` is TRUE → Steps 2+ all execute on every cron tick.
  Verified against source. Result: duplicate LLM cost per merge + duplicate
  bot PR proposals.
- **BL-3 — Auto-merge bypass when `composition` is INERT.** `composition.yml`
  exits SUCCESS when `vars.APP_REVIEWER_1_BOT_ID` is unset;
  `auto-merge-ai-prs.yml` treats `mergeStateStatus=CLEAN` as sufficient. On
  a consumer that installs `auto-merge-ai-prs.yml` before arming
  `composition` + adding it to required branch-protection checks (realistic
  install-order window), a collaborator can hand-apply `ai:review-passed`
  → CLEAN → enforcer re-arms merge without App approval.
- **BL-4 — Adopter cold-start docs stale + inconsistent.** README pins
  `ci/v1.1.3`; `install/README.md` pins `ci/v1.0.6`; `install.sh` defaults
  to `ci/v1.6.0`. `install/README.md` "What it does" omits the governance
  bootstrap + `.pre-commit-config.yaml` merge that hard-depends on
  `ruamel.yaml`|`pyyaml`. `multi-project-guide.md` still documents the
  removed claude-CLI pre-push pattern. `LABELS.md §3` documents
  `area: ci` / `area: governance` (colon-space) as canonical while
  `labels.json` ships unprefixed `governance`/`docs`/`workflows`/…;
  `labeler` fails cold. `skip-audit-trail` label used in 15+ places in
  `audit-trail-check.yml` but undocumented in `LABELS.md`.
  `PLAYBOOK_governance-canon-rollout.md` tells adopters to run
  `bash install/apply-standards.sh --check` from consumer root, but that
  script lives in `aidoc-flow-ci`, not consumers.
- **BL-5 — No update path.** `install.sh` copies templates via curl and
  `preserve`s existing files. `sync/check-drift.sh` is warning-only + only
  covers 2 of the 12 workflows (hardcoded loop). No documented
  `install.sh --update` or `apply-standards.sh --sync` that re-fetches at
  a new `ci/vX.Y.Z` tag. `check-drift.sh:57` still has an open
  `TODO ci/v1.0.1: add --force`. Consumers get frozen at install-time tag.

### 2.2 HIGH-tier hardening (bundled with corresponding BLOCKER PR)

**Security:**
- Two unpinned actions: `actions/create-github-app-token@v1`
  (`ai-review.yml:509` + `auto-merge-ai-prs.yml:95`), `actions/checkout@v7`
  (`ai-review.yml:105` — trust job).
- Consumer-input shell interpolation without env-var indirection:
  `codeql.yml:100` `run: ${{ inputs.build-command }}`;
  `pre-commit.yml:77` `pip install pre-commit ${{ inputs.extra-deps }}`;
  `pre-commit.yml:82` `--hook-stage "${{ inputs.run-stage }}"`;
  `links.yml:96` `${{ inputs.paths }}`.
- Unpinned `npm install -g @anthropic-ai/claude-code` in `doc-maintainer.yml`.

**Correctness:**
- `composition.yml:76` — PR-author fallback uses
  `github.event.workflow_run.actor.login` (the label-applier). Correct is
  `github.event.workflow_run.pull_requests[0].user.login`.
- Consumer templates `install/templates/workflows/labeler.yml`,
  `secret-scan.yml`, `codeql.yml` use `on: pull_request` while needing
  write perms — fork PRs get read-only GITHUB_TOKEN → SARIF upload +
  labeler fail.
- `sync/check-drift.sh:20` (+ `apply-standards.sh:183` +
  `check-standards-drift.sh:79`) use `sort -Vu | tail -1` — picks the
  HIGHEST-semver pin across workflow files, false-positive drift warnings
  mid-migration.

**Portability:**
- Template caller versions pinned inconsistently across
  `install/templates/workflows/` (v1.0.6, v1.3.0, v1.5.1, v1.4.0, and one
  `v1.1.0-alpha.2`).
- `pre_push_check.sh:38-39` `exit 2`s on `BASH_VERSINFO[0] < 4` — undocumented in
  install/README (macOS `/bin/bash` 3.2 breaks cold).
- `CHANGELOG.md` has 25 tags but only 8 `##` headers; most releases live
  under `## Unreleased`.

**Governance:**
- `HANDOFF.md:60` leaks `(this PR)` for merged PR #75 + omits 5 subsequent
  merges (#76-#80).
- `plans/PLAN-002_workspace-standards-rollout.md:3` still `**Status:** DRAFT — 2026-07-07 EST`
  after all sub-PRs (U1/U2/U3/U4) merged 2026-07-08.
- `CHANGELOG.md:2025 + 2029` — duplicated `## ci/v1.0.3` H2 header
  (merge-conflict/copy-paste leak).
- No reviewer-App onboarding doc; no branch-protection required-context
  recipes doc.

## 3. Non-goals (v1)

Deferred to future plans / out of scope:

- **License bump / repo dual-licensing.** Company adoption may need
  contributor-license discipline; canon-source is MIT today (see LICENSE),
  keep unchanged.
- **Multi-owner CODEOWNERS distribution.** Template gains `${CODEOWNER_HANDLE}`
  substitution (single value), not a fan-out matrix per file glob. Multi-owner
  is a v2 concern.
- **Non-GitHub CI backends.** GitLab / Azure DevOps / Bitbucket portability
  is out of scope; company-default here means "company GitHub repos."
- **Rewriting workflow business logic.** BL-2 (doc-maintainer schedule),
  BL-3 (auto-merge gate), and correctness HIGHs are minimal targeted
  patches — not workflow redesigns.
- **Reviewer-vendor expansion.** LiteLLM proxy / provider routing already
  deferred per README known-limitations; not addressed here.
- **Retrofitting CHANGELOG entries pre-v1.0.0.** History under the
  bootstrap phase stays as-is; only `## Unreleased` accumulation is cut
  into proper per-tag headers.
- **Automating reviewer-App installation.** GitHub App install requires
  a human OAuth flow at github.com/apps — the onboarding doc adds walk-
  through steps, not automation.
- **Consumer-side pin-bump PRs on each `ci/vX.Y.Z` tag.** PR-A ships
  a new tag but does NOT open pin-bump PRs on consumer repos — that
  work lives under PLAN-002 §5.5 rollout waves. This plan's scope is
  the canon-source repo only.
- **Restructuring `docs/REPO_STANDARDS.md`.** PR-A adds NEW docs
  (REVIEWER_APP_ONBOARDING.md, BRANCH_PROTECTION.md, UPDATE_GUIDE.md)
  but does NOT reshape REPO_STANDARDS.md's §0-§16 structure. Cross-
  references stay in place.
- **Multi-agent elevation-readiness re-review dispatch.** Success
  criterion §7 item 10 references a re-run of the 5-agent pre-prod
  review as the elevation gate. That re-run is a POST-PR-E verification
  step, not a deliverable inside any of PR-A..PR-E.
- **Explicitly deferred/accepted review findings (Pass-4 traceability
  fold — deliberate dispositions, not silent drops):**
  - *Governance-surface mapping for non-code repos* (arch H4): PLAN-003
    §4.1 Option-B already permits "Not adopted — <rationale>" declared
    omissions per surface; a Terraform or docs-only repo declines
    surfaces via that mechanism. No new machinery in this plan.
  - *Parameterizing the repo/tier lists in `docs/REPO_STANDARDS.md` §1*
    (arch H5 + M5): tier CONCEPTS generalize; the repo-name columns
    stay aidoc-flow-specific in v1. A future plan splits concept vs
    assignment when a second workspace actually adopts.
  - *Reverse-direction drift detection + consumer opt-out ledger*
    (arch M1-half + M2): forward drift (consumer vs canon) is the v1
    contract; "which repo opted out of what" ledger is deferred —
    the warning-only drift check remains the operator's reconcile
    point.
  - *Rollback tooling for `apply-standards.sh --apply`* (arch M3):
    manual rollback from the captured backup JSON stays documented;
    scripted rollback is v2.
  - *Scripted secrets bootstrap* (arch M4): PR-A item 7 documents the
    secrets; automation of `gh secret set` fan-out across N repos is
    deferred with the App-install automation non-goal.
  - *`pre_push_check.sh` without `set -e`* (sec M4): documented
    intentional (rc-accumulator pattern); accepted as-is.
  - *Accepted LOW tail:* `retry()` stderr size bound (corr M3),
    `docs-sync.yml` global concurrency group, `install.sh` depth-1
    clone, `pre_push_check.sh` upstream-fallback edge (corr LOWs);
    docs contribute-workflow mismatch (docs L3), LABELS
    future-categories duplication (docs L4 — partially resolved by
    PR-A item 5's rewrite), ai-review-assets "old assets" phrasing
    (docs L5); CLAUDE.md search-landmark phrasing (gov LOW). Accepted
    for this cycle; revisit only if they surface in adopter feedback.

## 4. Design constraints

### 4.1 De-branding shape (BL-1)

Template placeholder substitution at `install.sh` fetch time:

- Introduce `${CODEOWNER_HANDLE}` (default `@vladm3105`) — replaces every
  `@vladm3105` occurrence in `CODEOWNERS.template` and `code_owners` in
  `config.json.template`.
- Introduce `${CANON_OPERATIONS_URL}` (default
  `https://github.com/vladm3105/aidoc-flow-operations`) +
  `${CANON_CI_URL}` (default
  `https://github.com/vladm3105/aidoc-flow-ci`).
- CLAUDE.md.template emits full URLs when `--canon-source-url` is set
  (default when the flag is passed); emits umbrella-relative paths
  (`../operations/CLAUDE.md`, `../aidoc-flow-ci/docs/REPO_STANDARDS.md`)
  when `--canon-source-url` is omitted, matching today's aidoc-flow
  sibling shape. **No pwd-based auto-detection heuristic** — Pass-2
  review flagged that `install.sh`'s `$(pwd)` at substitution time is
  ambiguous (may be a bootstrap clone dir, not the umbrella tree).
  Requiring the explicit flag is cheaper than getting the heuristic
  wrong.
- CLI flags: `install.sh --codeowner @handle`,
  `install.sh --canon-source-url <url>`. Both optional; sensible defaults
  preserve today's aidoc-flow behavior.
- **Post-substitution assertion (Pass-2 R9 fix; corrected per Pass-4 B1):**
  after fetching a file whose manifest entry declares substitutions,
  `install.sh` asserts only the DECLARED placeholder names are gone:
  `grep -qE '\$\{(CODEOWNER_HANDLE|CANON_OPERATIONS_URL|CANON_CI_URL)\}' <outfile>`
  → error LOUD. A bare `grep -q '\${'` is WRONG — fetched templates
  legitimately contain `${...}` bash expansions
  (`install/templates/pre_push_check.sh:39` `${BASH_VERSION:-unknown}`)
  and GHA `${{ }}` syntax (`install/templates/workflows/labeler.yml:24`),
  so the naive form would fail every install. The assertion runs ONLY
  on files whose manifest entry has a non-empty `substitute` list.
- `apply-standards.sh` must accept the same flags for `--apply` cycles so
  drift-check doesn't flag the substituted values as drift.

### 4.2 Auto-merge composition-armed gate (BL-3)

Symmetric with `composition.yml`'s INERT branch — but mirroring ALL of
composition's pass-paths, not only the reviews query (Pass-4 M1):

- `auto-merge-ai-prs.yml` step 2 (trust gate) reads `vars.APP_REVIEWER_1_BOT_ID`.
- If unset OR non-numeric → emit `::warning::` "composition not armed;
  auto-merge enforcement disabled — install-time misconfig" + `exit 0`.
- **Carry-forward branch first (Pass-4 M1):** if the PR carries the
  `skip-ai-review` label, the App deliberately did NOT re-approve the
  current HEAD — composition passes via its own carry-forward branch
  (`composition.yml:110-117`), which keys off the bare label (checked
  BEFORE the trust gate and with no prior-approval check). The enforcer
  must mirror that same label-keyed branch and allow re-arm, or every
  label-cycle-recovered PR (troubleshooting §15; standing workaround
  for the reviewer file-window issue, `aidoc-flow-ci#81`) becomes
  permanently un-re-armable. (Pass-5 F3 note: the
  `carry_forward_on_skip_label` key ships in
  `config.json.template:15`, but composition's carry-forward at
  `:110-117` reads the LABEL directly, not that key — so mirror the
  label behavior. If the config key is meant to gate the behavior,
  wiring composition + the enforcer to actually read it is a separate
  PR-C sub-item, not assumed here.)
- Otherwise query App-APPROVED-at-HEAD (double-quoted so
  `$EXPECTED_ID`/`$HEAD_SHA` expand, and `--paginate` so >30-review
  PRs don't false-refuse — both per `composition.yml:188-189`'s actual
  shape):
  `gh api "repos/$GH_REPO/pulls/$PR/reviews" --paginate -q ".[] | select(.user.id == ($EXPECTED_ID) and .user.type == \"Bot\" and .state == \"APPROVED\" and .commit_id == \"$HEAD_SHA\")"`.
  Zero matches → refuse re-arm, `::warning::` "no App-APPROVED review
  at HEAD" + `exit 0`.

This closes the **single-label** no-approval bypass (`ai:review-passed`
hand-applied with no App review at all → gate refuses re-arm).

**Two residuals stated explicitly — the gate is defense-in-depth, not a
complete fix (Pass-4 M2 + Pass-5 F2):**

1. **Arm-then-push TOCTOU.** Native auto-merge armed at HEAD1 survives a
   push and merges HEAD2 unreviewed when `composition` is not a required
   check.
2. **Double-label variant.** A collaborator applying BOTH
   `ai:review-passed` AND `skip-ai-review` gets: composition passes via
   the carry-forward branch (bare label, checked before the trust gate,
   no prior-approval-at-any-commit check) AND the mirrored enforcer
   re-arms → merge with zero App approvals. The mirror does not OPEN
   this — it is the same safe-by-intent label-trust contract composition
   already grants — and tightening the enforcer to require
   approval-at-any-commit would break the §15 label-cycle recovery
   (those PRs may hold NO approval, only a wrongly-REQUESTED_CHANGES
   review). So the design is defensible but bounded: it does not close
   the double-label path.

**The one true fix for BOTH residuals** is adding `composition` to
branch-protection required checks (and applying `skip-ai-review` /
triage permission discipline so labels aren't a self-service merge
button). `docs/BRANCH_PROTECTION.md` (PR-A) is the canonical remedy;
the enforcer gate is a cheap in-depth layer inside it, not a substitute.
Trade-off: on a consumer deliberately running without the reviewer App
(comment-only mode), the enforcer never fires — correct, since there is
no counting approval to enforce.

### 4.3 Update path (BL-5)

Two-mode `install.sh`:

- `install.sh <owner/repo>` (today's shape) — one-shot bootstrap; new
  files copied; existing files preserved.
- `install.sh --update <owner/repo>` — re-fetch every template at the
  new `$CI_TAG`; for each file, compute `diff -u <local> <fetched>`;
  print unified diff + prompt operator per file (`[k]eep local /
  [r]eplace with canon / [d]iff-only-print`). Idempotent: re-running
  with no changes prints "no drift."
- `--update --non-interactive` for scripted use: applies `[r]eplace`
  automatically for files matching a manifest-declared "safe-to-replace"
  set (workflows + labels.json + dependabot.yml); keeps `[k]eep`
  behavior for governance files (CLAUDE.md, DECISIONS.md).

Unified drift-check: retire the `for wf in ai-review composition` loop
at `sync/check-drift.sh:34`. Replace with a manifest-driven full-surface
walker that reads `install/templates/manifest.json` (new file, ships in
this PR).

`manifest.json` schema (Pass-2 finding — schema was under-specified):

```json
{
  "version": "1",
  "files": [
    {
      "path": ".github/workflows/ai-review.yml",
      "template": "workflows/ai-review-public.yml",
      "safe_to_replace": true,
      "substitute": ["CODEOWNER_HANDLE", "CANON_OPERATIONS_URL"],
      "visibility_variants": {"public": "workflows/ai-review-public.yml", "private": "workflows/ai-review-private.yml"}
    }
  ]
}
```

Each file entry declares: (a) where it lands in the consumer, (b) which
template ships it (with per-visibility variants where they exist), (c)
whether `--update --non-interactive` may replace it without prompting,
(d) which placeholders `install.sh` substitutes at fetch time. The
walker in `sync/check-drift.sh` iterates the same list; the
`install.sh --update` diff-print iterates it; both stay in sync.

**PR-D ↔ PR-E interaction (Pass-2 finding):** PR-D's `sed`-based
substitution in `fetch_template` continues to run under PR-E's
manifest-driven walker. The walker reads `substitute` from the manifest
entry and runs the same substitution pass; there is no separate
"unsubstituted re-fetch" mode. When `--update` proposes a replacement,
the diff shown reflects post-substitution content, so the operator sees
what will actually land.

### 4.4 Version-tag single source (BL-4)

Ship `VERSION` at repo root containing the current released tag
(`ci/v1.7.0` at PR-A merge). Docs pull the tag via a
`markdown-lint`-friendly reference (`<!-- @version -->` marker + tiny
substitute script in `scripts/`). `install.sh` reads `VERSION` when
`CI_TAG` unset. `sync-version-refs.sh` (already exists per project
memory) is extended to substitute the marker across README + install/README
+ multi-project-guide + PLAYBOOK.

**Precedence (Pass-2 R10 fix):** `CI_TAG` env var (if set)
> `VERSION` file > hardcoded fallback. `install.sh` logs the winning
source at the top of every run (`echo "==> using CI_TAG=$CI_TAG from
{env|VERSION|fallback}"`) so an operator debugging a stale-tag issue
sees immediately which source dominated. A stale env var in a consumer's
CI-based caller silently overriding VERSION is the failure mode this
log line catches.

**curl-pipe mode (Pass-4 M6):** when `install.sh` runs via
`bash <(curl …@tag/install/install.sh)` there is NO repo-local VERSION
file, and reading `./VERSION` from the operator's arbitrary cwd would
pick up unrelated projects' VERSION files. Rule: `install.sh` reads
VERSION **only from its own script directory** when running from a
checkout (`$(dirname "$0")/../VERSION`), validates it against
`^ci/v[0-9]+\.[0-9]+\.[0-9]+$`, and otherwise uses the hardcoded
release-bumped fallback (today's `install.sh:37` behavior). In
curl-pipe mode the fallback is the operative source; the VERSION file
serves repo-local dev, CI, and the docs-substitution script.

### 4.5 Bash 4+ + Python + ruamel.yaml prereqs (portability HIGH)

`install/README.md` gains a top-line "Prereqs" section listing:
- `bash >= 4.0` (macOS: `brew install bash` OR skip `pre_push_check.sh`
  installation)
- `python3` + one of `ruamel.yaml` | `pyyaml` (operator machine; not
  runners)
- `gh` (authenticated) + `jq` + `curl`

`install.sh` gains a preflight check that prints the missing prereqs
to stderr with install pointers and `exit 1` (currently the failure
is silent mid-install).

### 4.6 Non-breaking sequencing

- PR-A / PR-B / PR-C are MINOR / PATCH bumps (v1.7.x). Existing
  consumers pinned at `@ci/v1.6.0` continue working; when they bump
  pin they pick up the fixes.
- PR-D introduces `${CODEOWNER_HANDLE}` substitution. Consumers pinning
  through PR-A can still install without setting `--codeowner`
  (default `@vladm3105` preserves today's behavior). MAJOR-ish label
  (v1.8.0) signals to external adopters that the substitution feature
  is available.
- PR-E introduces `install.sh --update`. Non-breaking — adds a mode,
  doesn't change existing `install.sh <repo>` shape.

## 5. Deliverable shape — 5 PRs

Sequenced lowest-blast-radius first. Each PR respects the ≤3 doc-surface
rule from OPS-0061 (`feedback_governance_pr_discipline`); larger docs
refactors split across sub-PRs where needed.

### 5.1 PR-A — `ci/v1.7.0` — Adopter cold-start docs cluster (BL-4 + governance HIGHs)

Largest doc-touching PR; ships the version-single-source machinery so
subsequent PRs can bump the tag cleanly.

Scope:

1. **Add `VERSION` file** at repo root with `ci/v1.7.0`. Update
   `install.sh:37` to read `VERSION` when `CI_TAG` unset (fallback:
   hardcoded `ci/v1.7.0` for offline installs).
2. **Rewrite README.md** — headline + install command + "What ships in"
   table sourced from `docs/WORKFLOWS.md` (12 reusables). Delete stale
   "v1.1.3 known limitations" section — items are shipped in v1.4-v1.6.
3. **Rewrite install/README.md** — "What it does" bullets audited
   against actual `install.sh` behavior (adds: governance canon
   bootstrap, `.pre-commit-config.yaml` merge with `ruamel.yaml`|`pyyaml`
   dep, standards-drift workflow install). Add top-line "Prereqs"
   section per §4.5.
4. **Fix `docs/multi-project-guide.md`** — delete or rewrite §8 that
   references the removed claude-CLI pre-push. Point at
   `docs/local-pre-push.md` (already correct).
5. **Fix `LABELS.md`** — replace §3 area-label prose with the ground
   truth from `install/templates/labels.json` (unprefixed
   `governance`/`docs`/`workflows`/`scripts`/`agents`/`tests`/`config`/`plans`).
   Add `skip-audit-trail` row to §1. Add note referencing
   `docs/REPO_STANDARDS.md:181-189` §5.2 as the canonical diff-class
   label list.
6. **Rewrite `docs/PLAYBOOK_governance-canon-rollout.md`** — swap
   `bash install/apply-standards.sh --check` for the
   `curl … | bash -s -- --check` pattern that works from consumer roots.
7. **New doc `docs/REVIEWER_APP_ONBOARDING.md`** — walkthrough for
   installing the reviewer GitHub App, minting the private key,
   setting `APP_REVIEWER_1_ID` / `APP_REVIEWER_1_KEY` secrets +
   `APP_REVIEWER_1_BOT_ID` variable. Link from README + security.md.
8. **New doc `docs/BRANCH_PROTECTION.md`** — required-context recipes
   for adding `call / ai-review`, `call / composition`, `call / verify`
   as required checks via `gh api ... branch-protection` or
   `apply-standards.sh --apply`.
9. **Fix governance state:** flip `PLAN-002.md:3` status DRAFT →
   SHIPPED (with per-wave rollout addendum); update `HANDOFF.md:60`
   to replace `(this PR)` with `PR #75` + append PR #76-#80; fix
   `HANDOFF.md:17-22` Wave-1 stale claim (Waves 1-4 landed); fix
   `HANDOFF.md:23-27` deferred auto-merge claim.
10. **Fix CHANGELOG.md** — dedup the double `## ci/v1.0.3` header at
    line 2025+2029 (keep the second entry's body); cut `## Unreleased`
    into `## ci/v1.7.0 — 2026-07-09` with proper sub-sections.
    **CHANGELOG restructure scope (Pass-2 finding):** the ~1893 lines
    currently under `## Unreleased` cover ci/v1.0.7..v1.6.x. Each
    Unreleased sub-section already carries an inline `ci/vX.Y.Z` tag;
    the restructure promotes those to proper H2 headers by
    `git log --tags --format='%H %d %s'` reconciliation. No history is
    deleted; only re-parented. Pre-v1.0.0 bootstrap section (~lines
    2350+) stays as-is per §3 non-goals.
11. **New docs added to PLAN-003 §5.5 rollout matrix** (Pass-2 cross-
    plan interaction): REVIEWER_APP_ONBOARDING.md + BRANCH_PROTECTION.md
    + UPDATE_GUIDE.md are new canonical docs; their per-repo adoption
    (which repos need which doc surfaced in their `CLAUDE.md`) is
    an addendum to PLAN-003 §5.5 shipped in a follow-up PLAN-003
    revision, not in this plan. This PR just publishes them in
    aidoc-flow-ci.
12. **Drift-check per-file fix bundled here** (Pass-3 §5.2 sequencing
    resolution): the `sync/check-drift.sh:20` + `apply-standards.sh:185`
    + `check-standards-drift.sh:79` per-file semver fix (§5.2 PR-B
    item 4) lands in PR-A rather than PR-B so the PLAYBOOK redirect
    can safely point at the already-fixed drift-check tooling.
    PR-B's item 4 implementation ships with PR-A AND is logged in the
    CHANGELOG under PR-A's `ci/v1.7.0` (Pass-5 F4: this supersedes an
    earlier "stays under PR-B for CHANGELOG bookkeeping" phrasing, which
    contradicted §5.2's provenance rule — provenance follows where the
    code lands, so v1.7.0 it is).

Additional doc riders folded from Pass-4 traceability audit:

13. **`docs/overrides.md`** — fix the drift-check-semantics misstatement
    (parameter overrides ARE flagged by `diff -q`; docs H2) + the stale
    future-tense Phase-A reference (docs M6).
14. **`docs/README.md`** — remove the "Planned (drafted on demand)"
    entries that duplicate already-existing docs; fix the workflow-count
    mention (docs H3 + the docs/README instance of H1).
15. **`docs/local-pre-push.md`** — fix §8's "not yet available in this
    release" claim; `audit-trail-check.yml` shipped (docs H4).
16. **`docs/runners.md`** — mark the `runner-self` pre-baked-CLI pool as
    aidoc-flow-operations infrastructure; add a "build your own runner
    image" pointer for external adopters (docs M5).
17. **Template caller pin normalization** (Pass-4 M3 / arch H1): re-pin
    every `install/templates/workflows/*.yml` `uses:` line to the
    single release tag cut by this PR (today they span `@ci/v1.0.6`
    to `@ci/v1.5.1` plus one `@ci/v1.1.0-alpha.2` at
    `install/templates/workflows/docs-sync.yml:33`). Add a release-cut
    check (actionlint rule or `scripts/` lint) asserting all template
    pins equal VERSION.
18. **`DECISIONS.md` CI-0004 delegation-table entry** (gov M3): one
    entry citing which OPS-NNNN decision backs each shipped workflow
    policy (auto-merge → OPS-0062; ai-review dispatch → OPS-0065/0067;
    audit-trail → OPS-0069), closing the cross-repo traceability hop.

Item-2 README rewrite explicitly includes (Pass-4 ambiguity
resolution): the template/doc inventory counts (docs H5: 15 caller
templates, 12 docs), removing the check-drift-as-pre-commit-hook claim
(docs M2), and adding the REPO_STANDARDS.md pointer to the charter
section (gov LOW). Item-3 install/README rewrite explicitly includes
the corrected label counts (docs M4: 16 labels — 5 state/control + 8
diff-class + 2 area + 1 audit-trail).

Docs touched: `README.md`, `install/README.md`, `docs/multi-project-guide.md`,
`LABELS.md`, `docs/PLAYBOOK_governance-canon-rollout.md`,
`docs/REVIEWER_APP_ONBOARDING.md` (new), `docs/BRANCH_PROTECTION.md` (new),
`docs/overrides.md`, `docs/README.md`, `docs/local-pre-push.md`,
`docs/runners.md`, `HANDOFF.md`, `plans/PLAN-002_workspace-standards-rollout.md`,
`CHANGELOG.md`, `DECISIONS.md`, `VERSION` (new), `install.sh`, template
pins, drift-check scripts.

**Sub-PR split (Pass-4 M5 rework — every sub-PR ≤3 doc surfaces per
OPS-0061; mechanical files (VERSION, install.sh, scripts, template
pins) don't count as doc surfaces but are grouped where they belong):**

- **PR-A1** — `README.md` + `install/README.md` + VERSION + `install.sh`
  (items 1-3 + item-2/3 explicit inclusions).
- **PR-A2** — `docs/multi-project-guide.md` + PLAYBOOK + the item-12
  drift-check script fixes (`sync/check-drift.sh`,
  `install/apply-standards.sh`, `sync/check-standards-drift.sh`) +
  item-17 template-pin normalization (items 4, 6, 12, 17).
- **PR-A3** — `LABELS.md` + `docs/REVIEWER_APP_ONBOARDING.md` +
  `docs/BRANCH_PROTECTION.md` (items 5, 7, 8).
- **PR-A4** — `HANDOFF.md` + `plans/PLAN-002` + `DECISIONS.md` CI-0004
  (items 9, 10 governance-state, 18; 3 surfaces).
- **PR-A4b** — `CHANGELOG.md` restructure alone (item 10 CHANGELOG:
  dedup `ci/v1.0.3` + `## Unreleased` per-tag cut). Pre-split from
  PR-A4 (Pass-5 F8: OPS-0061's ≤3-surface rule is mandatory, not
  reviewer-contingent; a 4-surface PR-A4 with "split if pushed back"
  violated the plan's own R3 — so the split is unconditional).
- **PR-A5** — `docs/overrides.md` + `docs/README.md` +
  `docs/local-pre-push.md` (items 13-15).
- **PR-A6** — `docs/runners.md` (item 16; rides with PR-A5 if trivial).

Verification: `check_plan.py` on this plan; `apply-standards.sh --check`
on `aidoc-flow-ci` itself passes; adopter walkthrough (dry-run against a
scratch repo) reads cleanly.

### 5.2 PR-B — `ci/v1.7.1` — Correctness fixes (BL-2 + correctness HIGHs)

Small, targeted, high-signal fixes.

Scope:

1. **BL-2 doc-maintainer schedule bug fix.** Restructure
   `.github/workflows/doc-maintainer.yml` — **split `reconcile` into
   its own JOB** (`if: github.event_name == 'schedule'`), keep
   `maintain` job on push with `if: github.event_name != 'schedule'`.
   (Pass-2 decision: prefixing every step `if:` is less robust
   against future step additions and was rejected as option (b).)
   **Job-split checklist (Pass-4 minor):** the new reconcile job must
   replicate what it currently inherits from the `maintain` job —
   the fetch-scripts step (`doc-maintainer.yml:124-137`, which resolves
   the pinned tag from `github.workflow_ref`), the Python setup, and
   the job-level `GH_TOKEN`/`GH_REPO` env (`:102-104`).
   **Rider (Pass-4 / corr M4):** while restructuring, give the cron
   path its own `concurrency` group (or `cancel-in-progress: true` for
   schedule fires) so stacked cron runs don't queue behind a slow push
   run.
2. **composition.yml:76 PR-author fallback fix.** Change
   `github.event.workflow_run.actor.login` → `github.event.workflow_run.pull_requests[0].user.login`.
3. **Consumer template fork-safety** (Pass-2 decision: per-file, not
   option-menu):
   - `labeler.yml` → **switch to `pull_request_target`** with inline
     comment; labeler doesn't read PR code, only PR metadata.
   - `codeql.yml` → **keep `pull_request`; skip SARIF upload on fork
     PRs** (Pass-4 M7 re-decision, superseding the Pass-3
     `pull_request_target` direction). Rationale: the caller template
     already runs `push: branches [main]` + weekly cron
     (`install/templates/workflows/codeql.yml:14-20`), so a
     `pull_request_target` base-ref scan would duplicate existing
     coverage exactly while handing fork PRs a green CodeQL check that
     analyzed zero of their changes. Keeping `pull_request` preserves
     PR-diff analysis for same-repo PRs; the SARIF-upload step gains
     `if: ${{ !github.event.pull_request.head.repo.fork }}` so fork
     PRs (read-only token) don't fail the job — their diff is still
     analyzed and findings appear in the job log.
   - `secret-scan.yml` → **keep `pull_request`** (SARIF upload needs PR
     content); add a documented no-fork-write limitation in
     `docs/security.md`. Rationale: secret-scan MUST see PR code to
     detect leaks, and granting fork PRs write access via
     `pull_request_target` would defeat the safety boundary. Non-fork
     PRs still get the SARIF upload; fork PRs get the scan result
     inline in the job log only.
4. **`sync/check-drift.sh:20` + `apply-standards.sh:185` +
   `check-standards-drift.sh:79`** — replace `sort -Vu | tail -1` with
   per-file tag extraction (`grep -oE '@ci/v[0-9.]+' <file>` per-file
   loop). Compare each workflow against its own pinned tag.
   **Sequencing note (Pass-2):** this fix must land BEFORE PR-A's
   PLAYBOOK doc redirect ships to consumers (§5.1 item 6). Options:
   (a) bundle item 4 into PR-A instead of PR-B, or (b) land PR-B first
   and hold PR-A's PLAYBOOK doc item for a PR-A2 sub-PR sequenced after
   PR-B merge. Preferred: (a) — bundle the drift-check fix into PR-A
   since PR-A already touches PLAYBOOK, and check-drift/check-standards-drift
   are surface adopters immediately touch when running the redirected
   commands.

Additional items folded from Pass-4 traceability audit:

5. **`install/apply-standards.sh:537-547` label-name URL-encoding**
   (corr M1): the `gh api "repos/.../labels/${name}"` path interpolates
   a raw `ai:review-passed` — the `:` must be `%3A`-encoded or the GET
   404s and the label re-POSTs (422 WARN-noise) on every `--apply`. Add
   a `${name/:/%3A}` encode shim before every path interpolation of
   `name`. (Pass-5 F1 correction: an earlier draft claimed `install.sh`
   already uses this shim at `:141` — it does NOT; `install.sh` creates
   labels via `gh label create` (Python subprocess, `install.sh:245-262`),
   never a URL path, so there is no existing shim to copy. This is a
   net-new fix in apply-standards.sh.)
6. **`audit-trail-check.yml:106` git-fetch diagnostics** (corr M2):
   capture the fetch stderr and echo it in the `cat-file` error branch
   instead of the bare `2>/dev/null || true`.
7. **`timeout-minutes` sweep** (corr M5): add job-level
   `timeout-minutes` to the 9 reusables missing it (`ai-review` 45,
   `composition` 10, `codeql` 30, `links` 15, `pre-commit` 15,
   `secret-scan` 15, `markdown-lint` 10, `docs-sync` 15,
   `doc-maintainer` 30) — matching the pattern
   `auto-merge-ai-prs.yml:80` already ships.
8. **`docs/troubleshooting.md` new entries** (docs M3): failure modes
   for `standards-drift.yml`, `audit-trail-check.yml`, and the
   install-time "`ruamel.yaml`/`pyyaml` not installed" exit — the top-3
   support questions the current install generates.

Docs touched: CHANGELOG.md (entry), `docs/troubleshooting.md` (new
entries per items above + the doc-maintainer schedule change),
`docs/architecture.md` (update workflow-count from 11 to 12 — resolves
doc H1). **CHANGELOG bookkeeping (Pass-4 minor):** item 4's
drift-check fix ships with PR-A (`ci/v1.7.0`) and is logged under
v1.7.0 — not under this PR's v1.7.1 — so release provenance stays
accurate per R5.

### 5.3 PR-C — `ci/v1.7.2` — Security hardening (BL-3 + security HIGHs)

Concentrated security fixes. Small diff, big posture improvement.

Scope:

1. **BL-3 auto-merge composition-armed gate.** Per §4.2. Adds an
   `App_APPROVED_at_HEAD` query to `auto-merge-ai-prs.yml` step 2;
   fail-closed with `::warning::` on missing App approval or unset
   `vars.APP_REVIEWER_1_BOT_ID`.
2. **SHA-pin `actions/create-github-app-token@v1`** at
   `ai-review.yml:509` + `auto-merge-ai-prs.yml:95`. Resolve pin via
   `gh api repos/actions/create-github-app-token/git/refs/tags/v1 --jq '.object.sha'`
   per project memory rule (`feedback_verify_sha_pins`). **Verify SHA
   is real** — a fabricated SHA would clone as a startup_failure.
3. **SHA-pin `actions/checkout@v7`** at `ai-review.yml:105`. Use the
   same SHA already in use elsewhere in this repo
   (`9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0` per PR-D
   verification). **Same SHA-verification discipline applies**
   (`feedback_verify_sha_pins` in project memory — research subagents
   have fabricated Action SHAs before; verify via `gh api` before ship).
4. **Env-var indirection for consumer-input shell interpolation**:
   `codeql.yml:100`, `pre-commit.yml:77`, `pre-commit.yml:82`,
   `links.yml:96`. Pattern: `env: INPUT_FOO: ${{ inputs.foo }}` then
   `"$INPUT_FOO"` in `run:` block. Matches the pattern used correctly at
   `ai-review.yml:394` (REVIEWER_IN) + `ai-review.yml:451` (MODEL_IN,
   BUDGET_IN).
5. **Pin npm install** in `doc-maintainer.yml:226` — `CLAUDE_CODE_VERSION`
   env var pattern per `ai-review.yml:366-370`.
6. **Validate `TARGET_REPO` in `install.sh`** — apply the same regex
   `apply-standards.sh:143-149` uses (owner/repo shape) near
   `install.sh` top. Closes M2.
7. **`curl | bash` claude-CLI install disposition** (sec M1,
   `ai-review.yml:378`): if Anthropic publishes a checksummed release
   artifact, add SHA-256 verification before exec; otherwise document
   the accepted risk in `docs/security.md` (TLS-only, Anthropic-owned
   host, version-pinned arg) with a monitoring note. Either way the
   disposition is explicit, not silent.
8. **`docs/security.md` §4.3 historical-limitation cleanup** (docs H6
   security-half): the §4.3 "v1.0.0 limitation" prose describes
   shipped-and-fixed state; rewrite to current behavior. (README half
   already covered by PR-A item 2.)
9. **`standards-drift.yml` top-level `permissions: {}`** (sec LOW):
   one-line defense-in-depth addition; job-level `contents: read`
   already present.

Docs touched: CHANGELOG.md, `docs/security.md` (new §7 auto-merge
composition-armed gate + §4.3 cleanup + curl|bash risk note).

### 5.4 PR-D — `ci/v1.8.0` — De-brand templates (BL-1, breaking-ish)

MAJOR-ish (v1.8.0) to flag externally that template shape changed.
Existing consumers continue working (`@vladm3105` default preserves
today's behavior).

Scope:

1. **`install.sh` gains `--codeowner @handle` + `--canon-source-url <url>`
   flags** (both optional). Defaults preserve today's aidoc-flow behavior.
2. **Placeholder substitution at fetch time.** `install.sh` `fetch_template`
   function reads fetched bytes + performs `sed` substitution before
   writing to disk. Substitution surfaces:
   - `${CODEOWNER_HANDLE}` → all 9 occurrences in
     `install/templates/CODEOWNERS.template`.
   - `${CODEOWNER_HANDLE}` (without `@`) → `install/templates/config.json.template:5`
     `"ai_review": ["vladm3105"]` + `:10` `"code_owners": ["@vladm3105"]`.
   - `${CANON_OPERATIONS_URL}` → 7 occurrences in
     `install/templates/CLAUDE.md.template` `../operations/*` (Pass-5 F5:
     grep-verified 7, and no directory-detection — emit full URLs when
     `--canon-source-url` is passed, else keep today's relative shape,
     per §4.1 and item 3 below).
   - `${CANON_CI_URL}` → `install/templates/CLAUDE.md.template:104`
     `../aidoc-flow-ci/*`.
3. **No pwd-based umbrella-detection heuristic.** Per §4.1 Pass-2
   revision: an operator either passes `--canon-source-url` (produces
   full URLs) or omits it (preserves today's `../operations/` shape).
   Explicit-flag simplicity beats fragile `$(pwd)`-based detection.
4. **`apply-standards.sh` accepts the same flags** so `--apply` cycles
   preserve substitutions without flagging them as drift.
5. **Update `install/README.md`** to document `--codeowner` +
   `--canon-source-url` flags with examples.
6. **Parameterize the trust-config source in the reusables (Pass-4 B2).**
   The reusable workflows themselves — not just the templates — pin
   `vladm3105/aidoc-flow-operations@main` as the trust-allowlist +
   config source: `ai-review.yml:107` (trust-allowlist checkout),
   `ai-review.yml:306` + `:315` (config.json raw/API fetch),
   `auto-merge-ai-prs.yml:168` (`CONFIG_URL`). Without parameterizing
   these, a non-vladm3105 company org's authors can never enter
   `trust.ai_review` and its repos can never enter `auto_merge.repos` —
   ai-review + the enforcer stay permanently inert, making the §1 goal
   unattainable. Fix: add a `trust_config_repo` `workflow_call` input
   (default `vladm3105/aidoc-flow-operations`) + `trust_config_ref`
   (default `main`) to `ai-review.yml` + `auto-merge-ai-prs.yml` +
   `composition.yml`; derive checkout `repository:` and both fetch URLs
   from them. Caller templates gain the matching `with:` passthrough
   (defaulted, so existing consumers are untouched).

Docs touched: CHANGELOG.md, `install/README.md`,
`docs/multi-project-guide.md` (new §"Non-aidoc-flow adoption").

Non-goals within PR-D: multi-owner CODEOWNERS fan-out; renaming other
aidoc-flow-specific prose in CLAUDE.md.template (deferred).

### 5.5 PR-E — `ci/v1.9.0` — Update path + unified drift (BL-5)

Non-breaking additive PR. Introduces `install.sh --update` mode + unified
drift-check.

Scope:

1. **`install.sh --update <owner/repo>` mode.** Re-fetches every
   template at current `$CI_TAG`. For each file: computes `diff -u`
   against local; prints unified diff; interactive prompt
   (`[k]eep / [r]eplace / [d]iff-only`).
2. **`--update --non-interactive`** applies `[r]eplace` for files in
   the safe-to-replace manifest (workflows/*, labels.json,
   dependabot.yml); keeps `[k]eep` for governance files (CLAUDE.md,
   DECISIONS.md, HANDOFF.md, ROADMAP.md, CHANGELOG.md).
3. **New `install/templates/manifest.json`** enumerating every
   template file + a `safe_to_replace` flag. Referenced by `install.sh`,
   `apply-standards.sh`, and `sync/check-drift.sh`.
4. **Unified `sync/check-drift.sh` rewrite.** Retire the
   `for wf in ai-review composition` hardcoded loop at line 34. Read
   surface from `manifest.json`. Close the `TODO ci/v1.0.1: add --force`
   at line 57 (redirect to `install.sh --update`).
5. **Documentation**: new `docs/UPDATE_GUIDE.md` walking through
   `--update` mode + release-note-driven pin-bump flow.

Docs touched: CHANGELOG.md, `install/README.md`, `docs/UPDATE_GUIDE.md`
(new).

## 6. Risks

- **R1 — De-branding breaks in-flight consumer PRs.** Substitution logic
  shipping in PR-D + a consumer mid-install could get half-substituted
  templates. Mitigation: PR-D's `install.sh` performs substitution
  atomically per file (write to `.tmp` → rename). Also: consumers
  pinning through PR-A don't need PR-D immediately.
- **R2 — Auto-merge composition-armed gate breaks an existing consumer.**
  Consumers currently relying on the label-shortcut (deliberately or
  accidentally) will see their auto-merge stop firing. Mitigation:
  PR-C ships a `::warning::` message pointing at `vars.APP_REVIEWER_1_BOT_ID`
  as the missing config, so operators self-diagnose. Also: any consumer
  legitimately affected has an unarmed composition, which is a
  pre-existing security gap.
- **R3 — Doc rewrite scope creep.** PR-A touches ~18 surfaces; risks
  becoming a multi-week doc-refactor cycle. Mitigation: split into the
  A1–A6 sub-PRs enumerated in §5.1 per OPS-0061; hard-cap at ≤3 doc
  surfaces per sub-PR (unconditionally — see PR-A4/A4b).
- **R4 — `install.sh --update` clobbers local overrides.** A consumer
  answering `[r]eplace` accidentally overwrites a hand-authored
  workflow. Mitigation: mandatory `[d]iff-only` first pass in
  non-interactive mode when the file is not on the safe-to-replace
  list.
- **R5 — CHANGELOG restructuring loses release provenance.** Cutting
  `## Unreleased` into per-tag headers risks mislabelling which
  release contained which change. Mitigation: reconcile against
  `git log --oneline --tags` before the cut; each per-tag section
  cites the underlying merged PR#.
- **R6 — Manifest.json becomes canonical drift-check surface,
  duplicating REPO_STANDARDS.md §5.** Mitigation: manifest.json
  cites REPO_STANDARDS.md sections in a comment header; canon
  ownership stays in REPO_STANDARDS.md; manifest is a machine-readable
  index.
- **R7 — Bootstrap-order dependency: PR-A ships VERSION file, PR-B/C/D/E
  bump it.** If PR-A's VERSION mechanism has a bug, PR-B lands with a
  broken tag pipeline. Mitigation: PR-A includes a self-verification
  step (fresh clone → install.sh → assert VERSION reads correctly)
  before merge; PR-B ci-cross-checks VERSION content against its tag
  bump.
- **R8 — PR-C bump strands a consumer's stuck-green PR mid-flight.**
  Consumer has an open PR pre-dating App wiring, currently stuck-green
  under the label-hand-apply pattern. After PR-C's composition-armed
  gate ships, the enforcer refuses to re-arm merge → the PR sits open
  indefinitely. Operator perceives this as a regression. Mitigation:
  PR-C ships alongside a documented recovery step in `docs/troubleshooting.md`
  ("post-v1.7.2 stuck-PR recovery" — either wire the reviewer App +
  re-dispatch ai-review, or merge manually via `gh pr merge --admin`).
  PR-C's rollout to consumers via PLAN-002 §5.5 sequences the recovery
  ahead of the pin bump.
- **R9 — Un-substituted `${...}` placeholder ships to consumer tree.**
  PR-D's `sed`-based substitution missing a flag (e.g. operator
  forgets `--codeowner`) results in literal `${CODEOWNER_HANDLE}` in
  the fetched template. Markdownlint + labeler + branch protection all
  fail at consumer-CI first run. Mitigation: declared-placeholder-name
  assertion `grep -qE '\$\{(CODEOWNER_HANDLE|CANON_OPERATIONS_URL|CANON_CI_URL)\}'`
  fails LOUD, applied only to manifest entries with a `substitute` list
  (per §4.1 Pass-4 correction — a bare `\${` grep would false-positive
  on legitimate bash/GHA syntax in every template). Also: default
  `${CODEOWNER_HANDLE}` to `@vladm3105` (preserves today's shape when
  the flag is omitted).
- **R10 — Stale `CI_TAG` env var silently overrides VERSION file.**
  A consumer's CI-based caller has `CI_TAG=ci/v1.6.0` in workflow env;
  after PR-A ships VERSION=ci/v1.7.0, the env var still wins and the
  consumer keeps installing v1.6.0 assets. Mitigation: `install.sh`
  logs "using CI_TAG=$CI_TAG from {env|VERSION|fallback}" at top of
  every run (per §4.4). Post-elevation grep of consumer CI logs
  surfaces stale env vars.

## 7. Success criteria (verifiable)

At PR-E merge, the following must all hold:

1. **Adopter cold-start.** Running
   `bash <(curl -fsSL https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v1.9.0/install/install.sh) <fresh-repo> --codeowner @<handle> --canon-source-url https://github.com/<org>/<canon-source>`
   completes without hand-editing templates. Verified against a scratch
   repo owned by a non-vladm3105 GitHub handle (Pass-4 minor: the
   founder designates the tester account — a secondary org/personal
   account — before PR-D verification; criterion is blocked until
   designated).
2. **No hardcoded `@vladm3105` BRANDING in fetched templates** (scoped
   per Pass-4 B3): on a `--codeowner @otheruser` install,
   `grep 'vladm3105' <target>/CODEOWNERS <target>/CLAUDE.md <target>/.github/ai-review/config.json`
   returns zero matches. `uses: vladm3105/aidoc-flow-ci/...@ci/vX.Y.Z`
   lines in caller workflows are CANON COORDINATES, not branding — they
   are excluded (an unqualified `grep -r vladm3105 <target>/.github/`
   would be guaranteed-red on every install; see
   `install/templates/workflows/ai-review-public.yml:28`).
3. **Auto-merge cannot fire without App approval.** Manually applying
   `ai:review-passed` on a PR with no App-approved review → enforcer
   `::warning::`s + does not re-arm merge. Verified by test-repo scenario.
4. **doc-maintainer cron fires reconcile only.** On a
   `github.event_name == 'schedule'` run, the new `reconcile` JOB
   succeeds and the `maintain` JOB is `skipped` (Pass-4 correction:
   job-level assertion, since the fix is a job split). Verified by
   CI-run inspection after next cron tick.
5. **Version tag single-source** (scoped per Pass-4 M4): after PR-A
   merge, no INSTALL-COMMAND or PIN-INSTRUCTION reference carries a
   stale tag — the curl install lines in `README.md` +
   `install/README.md` + `docs/multi-project-guide.md` + the PLAYBOOK
   all cite the `<!-- @version -->`-managed current tag. Historical
   prose ("shipped in ci/v1.0.x", CHANGELOG provenance,
   troubleshooting war stories) is exempt — a blanket
   `grep -r 'ci/v1\.[0-6]\.' docs/` currently hits 38 legitimate
   historical mentions across 9 files and scrubbing them would violate
   the §3 history-preservation non-goal.
6. **LABELS.md matches labels.json ground truth.** `jq -r '.[].name' install/templates/labels.json | sort` matches the label names enumerated in `LABELS.md §1` + `§3` (after LABELS.md rewrite).
7. **`install.sh --update`** on a consumer pinned at `ci/v1.6.0` (or later)
   presents each changed template as a unified diff + preserves untouched
   files. Verified against a scratch consumer.
8. **PLAN-002 status is SHIPPED.** `head -5 plans/PLAN-002_workspace-standards-rollout.md`
   shows `**Status:** SHIPPED`. Similarly HANDOFF.md contains no `(this PR)` residue.
9. **Reviewer App onboarding doc walkthrough works.** A first-time adopter
   following `docs/REVIEWER_APP_ONBOARDING.md` end-to-end can produce a
   PR with a valid App-APPROVED review.
10. **Multi-agent pre-prod review re-run** (this same 5-agent dispatch shape,
    fresh context) returns zero BLOCKERs and zero HIGHs against the same
    5 clusters. Serves as the elevation-readiness gate.
11. **All `actions/*@vN` are SHA-pinned** (Pass-2 success-criterion gap):
    `grep -rE 'uses:\s+[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+@v[0-9]+\s*$' .github/workflows/ install/templates/workflows/ | wc -l` returns 0.
    Third-party actions all pin to 40-char SHA; first-party
    `actions/*` may retain tag form only where repo policy explicitly
    permits.
12. **composition.yml PR-author fallback** (Pass-2 gap): `github.event.workflow_run.pull_requests[0].user.login`
    is the correct fallback field. A test PR with maintainer-applied
    label on a bot-authored PR passes composition (correct author
    identity → correct trust-allowlist lookup).
13. **CHANGELOG structural cleanup** (Pass-2 gap):
    `grep -c '^## ci/v1\.0\.3' CHANGELOG.md` returns 1 (dedup);
    `grep -c '^## ci/v1\.[0-6]\.' CHANGELOG.md` returns ≥14 (each
    v1.0.x-v1.6.x tag has its own H2 header, not lumped under Unreleased);
    `grep -c '^## Unreleased' CHANGELOG.md` returns ≤1 (only for
    genuinely-unreleased staging entries).
14. **Consumer template fork-safety** (Pass-2 gap): a scratch fork PR
    against a test consumer running `labeler.yml`, `secret-scan.yml`,
    `codeql.yml` either succeeds (same-repo PRs get full analysis + SARIF
    upload) or, on fork PRs, analyzes the diff and skips only the SARIF
    upload via `if: !…head.repo.fork` without failing the job (Pass-5 F7:
    corrected from a stale `pull_request_target` framing — M7 re-decided
    codeql to stay on `pull_request`). `secret-scan.yml` emits a
    documented fork-write limitation.

## 8. Cross-references

- `docs/REPO_STANDARDS.md` — canonical rulebook (§0 canonical-source
  disambiguation; §1 tier taxonomy; §5.2 diff-class labels).
- `docs/WORKFLOWS.md` — workflow catalog (12 reusables). Ground truth
  for the README refresh.
- `plans/PLAN-001_repo-standards-canon.md` — parent canon plan
  (SHIPPED; historical record).
- `plans/PLAN-002_workspace-standards-rollout.md` — workspace-standards
  rollout (SHIPPED per this plan's PR-A).
- `plans/PLAN-003_project-governance-canon.md` — governance-file canon
  (SHIPPED / rollout in-progress).
- `../operations/ops/DECISIONS.md` (canonical) — OPS-0061 governance-PR
  discipline; OPS-0062 auto-merge default; OPS-0065 multi-agent review
  dispatch; OPS-0066 3-cycle circuit-breaker; OPS-0067 aidoc-flow-standard
  scope; OPS-0069 audit-trail phrase.
- Pre-prod review (2026-07-09) — the source of all 5 BLOCKER clusters +
  HIGH findings folded into this plan. Findings surfaced in-session
  by the 5 parallel agents; no separate document.

## Claim ledger

Every load-bearing file:line claim in this plan; symbol is authoritative,
line is a hint. Citations resolve against `/opt/data/aidoc-flow/aidoc-flow-ci/`.

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | `actions/create-github-app-token@v1` unpinned in ai-review | `actions/create-github-app-token@v1` | .github/workflows/ai-review.yml:509 |
| 2 | `actions/create-github-app-token@v1` unpinned in enforcer | `actions/create-github-app-token@v1` | .github/workflows/auto-merge-ai-prs.yml:95 |
| 3 | `actions/checkout@v7` tag-pinned in trust job | `actions/checkout@v7` | .github/workflows/ai-review.yml:105 |
| 4 | Consumer-input `${{ inputs.build-command }}` interpolated in run: | `${{ inputs.build-command }}` | .github/workflows/codeql.yml:100 |
| 5 | Consumer-input `${{ inputs.extra-deps }}` interpolated in run: | `${{ inputs.extra-deps }}` | .github/workflows/pre-commit.yml:77 |
| 6 | Consumer-input `${{ inputs.run-stage }}` interpolated in run: | `${{ inputs.run-stage }}` | .github/workflows/pre-commit.yml:82 |
| 7 | Consumer-input `${{ inputs.paths }}` interpolated in lychee args | `${{ inputs.paths }}` | .github/workflows/links.yml:96 |
| 8 | doc-maintainer Step 0 (reconcile) `exit 0` ends step not job | `Step 0 — Reconcile` | .github/workflows/doc-maintainer.yml:140 |
| 9 | doc-maintainer Step 1 (dedup) gated `if: github.event_name != 'schedule'` — skipped on cron | `Step 1 — Deterministic dedup check` | .github/workflows/doc-maintainer.yml:157 |
| 10 | doc-maintainer Step 2+ gated only on `steps.dedup.outputs.skip != 'true'` — TRUE on unset | `if: ${{ steps.dedup.outputs.skip != 'true' }}` | .github/workflows/doc-maintainer.yml:178 |
| 11 | composition.yml wrong PR-author fallback `workflow_run.actor.login` | `AUTHOR: ${{ github.event.pull_request.user.login \|\| github.event.workflow_run.actor.login }}` | .github/workflows/composition.yml:76 |
| 12 | check-drift.sh uses `sort -Vu \| tail -1` picking HIGHEST-semver pin | `sort -Vu \| tail -1` | sync/check-drift.sh:20 |
| 13 | check-drift.sh loop hardcodes 2 workflows only | `for wf in ai-review composition` | sync/check-drift.sh:34 |
| 14 | Open TODO for `--force` update path in check-drift.sh | `TODO ci/v1.0.1: add --force` | sync/check-drift.sh:57 |
| 15 | `@vladm3105` hardcoded in CODEOWNERS.template (9 occurrences) | `@vladm3105` | install/templates/CODEOWNERS.template:3,22,26,29,30,31,35,36,37 |
| 16 | `code_owners` hardcoded to `["@vladm3105"]` in config.json.template | `"code_owners"` | install/templates/config.json.template:10 |
| 17 | `ai_review` allowlist hardcoded to `["vladm3105"]` in config.json.template | `"ai_review"` | install/templates/config.json.template:5 |
| 18 | CLAUDE.md.template references canon via `../operations/*` relative paths (7 occurrences — verified via grep) | `../operations/CLAUDE.md` | install/templates/CLAUDE.md.template:75,79,83,85,88,92,99 |
| 19 | CLAUDE.md.template references `../aidoc-flow-ci/*` for REPO_STANDARDS | `../aidoc-flow-ci/docs/REPO_STANDARDS.md` | install/templates/CLAUDE.md.template:104 |
| 20 | `pre_push_check.sh` requires bash 4+; exits 2 otherwise | `BASH_VERSINFO[0] < 4` | scripts/pre_push_check.sh:38 |
| 21 | README pins `ci/v1.1.3` in headline + install command | `ci/v1.1.3` | README.md:13,21,46 |
| 22 | install/README.md pins `ci/v1.0.6` in install command + CI_TAG example | `ci/v1.0.6` | install/README.md:10,11,15 |
| 23 | install.sh default CI_TAG is `ci/v1.6.0` | `CI_TAG="${CI_TAG:-ci/v1.6.0}"` | install/install.sh:37 |
| 24 | CHANGELOG has duplicated `## ci/v1.0.3` H2 header | `## ci/v1.0.3 — 2026-06-24` | CHANGELOG.md:2025,2029 |
| 25 | PLAN-002 status is `DRAFT` despite sub-PRs merged | `**Status:** DRAFT — 2026-07-07 EST` | plans/PLAN-002_workspace-standards-rollout.md:3 |
| 26 | `skip-audit-trail` label defined in labels.json | `"name": "skip-audit-trail"` | install/templates/labels.json:80 |
| 27 | `skip-audit-trail` used in audit-trail-check workflow | `skip-audit-trail` | .github/workflows/audit-trail-check.yml:151,156,161,169,172,203,204 |
| 28 | audit-trail-check verifies bot identity via `pull_request.user.type == 'Bot'` (positive-note reference) | `github.event.pull_request.user.type` | .github/workflows/audit-trail-check.yml:94 |
| 29 | ai-review env-var indirection reference pattern (REVIEWER_IN) | `REVIEWER_IN: ${{ inputs.reviewer }}` | .github/workflows/ai-review.yml:394 |
| 30 | ai-review env-var indirection reference pattern (MODEL_IN + BUDGET_IN) | `MODEL_IN: ${{ inputs.model }}` | .github/workflows/ai-review.yml:451 |
| 31 | ai-review npm install pin pattern for doc-maintainer fix | `CODEX_VERSION: '0.142.0'` | .github/workflows/ai-review.yml:366 |
| 32 | apply-standards.sh regex validates owner/repo pattern (for install.sh symmetry) | `REPO_LABEL" =~ ^[A-Za-z0-9]` | install/apply-standards.sh:143 |
| 33 | composition.yml App-APPROVED-at-HEAD query shape (for auto-merge gate mirror) | `.commit_id == \"$HEAD_SHA\"` | .github/workflows/composition.yml:189 |
| 34 | composition.yml INERT branch when `vars.APP_REVIEWER_1_BOT_ID` unset (BL-3 upstream mechanism) | `INERT until armed` | .github/workflows/composition.yml:95 |
| 35 | auto-merge-ai-prs.yml state filter treats `mergeStateStatus=CLEAN` as sufficient (BL-3 downstream mechanism) | `mergeStateStatus=$MERGE_STATE` | .github/workflows/auto-merge-ai-prs.yml:237 |
| 36 | auto-merge-ai-prs.yml requires `ai:review-passed` label (BL-3 gating mechanism) | `HAS_LABEL=$(echo "$STATE" \| jq -r '(.labels // []) \| map(.name) \| index("ai:review-passed")` | .github/workflows/auto-merge-ai-prs.yml:225 |
| 37 | REPO_STANDARDS.md §5.2 canonical unprefixed diff-class label list | `OPS-0065 diff class` | docs/REPO_STANDARDS.md:180 |
| 38 | apply-standards.sh multi-file drift walker uses same HIGHEST-semver bug (BL-5 upstream fix location) | `sort -Vu` | install/apply-standards.sh:185 |
| 39 | check-standards-drift.sh mirrors the same HIGHEST-semver bug | `sort -Vu` | sync/check-standards-drift.sh:79 |
| 40 | HANDOFF.md leaks `(this PR)` for merged PR #75 | `(this PR)` | HANDOFF.md:60 |
| 41 | HANDOFF.md Wave-1 next-step claim stale (Waves 1-4 landed) | `Wave 1` | HANDOFF.md:17 |
| 42 | HANDOFF.md marks auto-merge as "Deferred" though workflow shipped in ci/v1.5.0 | `Deferred` | HANDOFF.md:23 |
| 43 | doc-maintainer.yml unpinned npm install of claude-code CLI | `npm install -g @anthropic-ai/claude-code` | .github/workflows/doc-maintainer.yml:226 |
| 44 | ai-review trust-allowlist checkout hardcodes operations repo (B2 locus) | `repository: vladm3105/aidoc-flow-operations` | .github/workflows/ai-review.yml:107 |
| 45 | ai-review config fetch hardcodes operations raw URL (B2 locus) | `config_url="https://raw.githubusercontent.com/vladm3105/aidoc-flow-operations` | .github/workflows/ai-review.yml:306 |
| 46 | enforcer trust-config fetch hardcodes operations raw URL (B2 locus) | `CONFIG_URL="https://raw.githubusercontent.com/vladm3105/aidoc-flow-operations` | .github/workflows/auto-merge-ai-prs.yml:168 |
| 47 | composition carry-forward pass-path on skip-ai-review label (M1 mirror target) | `CARRY-FORWARD` | .github/workflows/composition.yml:110 |
| 48 | template pre_push_check contains legitimate `${...}` bash expansion (B1 false-positive evidence) | `${BASH_VERSION:-unknown}` | install/templates/pre_push_check.sh:39 |
| 49 | caller templates contain GHA `${{ }}` syntax (B1 false-positive evidence) | `group: ${{ github.workflow }}-${{ github.ref }}` | install/templates/workflows/labeler.yml:24 |
| 50 | caller `uses:` lines necessarily contain vladm3105 canon coordinates (B3 criterion-scope evidence) | `uses: vladm3105/aidoc-flow-ci/.github/workflows/ai-review.yml@ci/v1.0.6` | install/templates/workflows/ai-review-public.yml:28 |
| 51 | codeql caller already runs push+PR+weekly cron (M7 re-decision evidence) | `- cron: '20 14 * * 1'` | install/templates/workflows/codeql.yml:20 |
| 52 | docs-sync template pinned at an alpha tag (M3/arch-H1 evidence) | `@ci/v1.1.0-alpha.2` | install/templates/workflows/docs-sync.yml:33 |
| 53 | doc-maintainer fetch-scripts step the reconcile job-split must replicate | `BASE="https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${TAG}/scripts/doc-maintainer"` | .github/workflows/doc-maintainer.yml:132 |
| 54 | apply-standards.sh label GET path interpolates un-encoded `${name}` (corr M1 fix locus) | `gh api "repos/${REPO_LABEL}/labels/${name}"` | install/apply-standards.sh:537 |
| 55 | install.sh creates labels via `gh label create` subprocess, NOT URL path (F1: no shim to copy) | `gh label create` | install/install.sh:262 |
| 56 | ai-review config API-fallback URL hardcodes operations (B2 locus, 3rd ref) | `api_url="https://api.github.com/repos/vladm3105/aidoc-flow-operations` | .github/workflows/ai-review.yml:315 |
| 57 | ai-review `curl \| bash` claude CLI install without checksum (sec M1 locus) | `curl -fsSL https://claude.ai/install.sh \| bash` | .github/workflows/ai-review.yml:378 |
| 58 | audit-trail-check silent-catches git fetch (corr M2 locus) | `git fetch --no-tags origin "$BASE_SHA" 2>/dev/null \|\| true` | .github/workflows/audit-trail-check.yml:106 |
| 59 | auto-merge-ai-prs sets job timeout (timeout-minutes-sweep reference pattern) | `timeout-minutes: 10` | .github/workflows/auto-merge-ai-prs.yml:80 |
| 60 | doc-maintainer job-level env the reconcile split must replicate | `GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` | .github/workflows/doc-maintainer.yml:103 |
| 61 | `carry_forward_on_skip_label` config key exists in template (F3: but composition reads the bare label) | `"carry_forward_on_skip_label"` | install/templates/config.json.template:15 |

## Review log

### Pass 1 — 2026-07-09 — author self-review

_Author's own re-read; does not count as independent per verified-planning
skill. Records intent to move to Pass 2._

Structure: matches PLAN-001/002/003 shape (Purpose → Findings audit →
Non-goals → Constraints → Deliverables → Risks → Success → Cross-refs).
Length ~500 lines is proportional to the 5 BLOCKER clusters + supporting
HIGH findings (per `feedback_plans_minimal_and_realistic`).

Claim ledger has 37 verified citations covering every load-bearing file:line
reference. Zero UNVERIFIED. Symbol-authoritative citations per skill rule.

Coverage check: every BLOCKER (BL-1..BL-5) is addressed by exactly one PR
in §5 (PR-D, PR-B, PR-C, PR-A, PR-E respectively). Every HIGH from §2.2
folds into the corresponding BLOCKER PR (security → PR-C; correctness →
PR-B; portability → PR-A + PR-D; governance → PR-A). No orphan finding.

Sequencing rationale: PR-A ships VERSION machinery + docs first because
subsequent PRs need it to bump tags cleanly. PR-B (correctness) before
PR-C (security) because BL-2 fix affects LLM cost every cron tick (impact
> waiting time for security PR-C). PR-D (breaking-ish) fourth so PR-C
security fixes land under today's template shape; consumers who want to
elevate to non-aidoc-flow adoption bump to v1.8.0. PR-E (update path) last
because it consumes PR-A's manifest work.

**Result:** superseded by Pass 2 fold — see Pass 2 below.

### Pass 2 — 2026-07-09 — independent (fresh-context Agent)

Dispatched a fresh-context general-purpose Agent with the full
adversarial review brief (Claim-ledger verification + load-bearing
gap hunt + wrong-assumption + sequencing + success-criteria +
under-specified deliverables + non-goals + risk-register + cross-plan +
repo-conventions + check_plan.py compliance). Returned verdict
**FINDINGS-TO-FOLD** with 1 gate-blocking ledger row + 6 load-bearing
claims missing from ledger + 3 wrong-assumption / under-specified /
missing-criteria/risk clusters.

**All findings folded in this revision:**

_Ledger (Part A):_
- Row 28 (`audit-trail-check.yml`) re-cited to `:94`
  (`PR_USER_TYPE: ${{ github.event.pull_request.user.type }}`) —
  was `:131` (proximity-fail).
- Row 18 occurrence count corrected `8 → 7` (grep-verified).
- Rows 38-43 added covering: `apply-standards.sh:185` +
  `check-standards-drift.sh:79` (drift-check per-file fix loci);
  `HANDOFF.md:60/17/23` (governance-consistency claims);
  `doc-maintainer.yml:226` (npm install pin locus).

_Design + deliverables (Part B):_
- §4.1 dropped the pwd-based umbrella-detection heuristic; explicit
  `--canon-source-url` flag is required for full-URL emission.
  Added post-substitution `grep -q '\${' <outfile>` assertion.
- §4.3 added `manifest.json` schema JSON + PR-D ↔ PR-E interaction
  note (substitution runs under the manifest walker; no separate
  unsubstituted-refetch mode).
- §4.4 added `CI_TAG env > VERSION > fallback` precedence + logged
  source at `install.sh` startup.
- §5.1 PR-A item 10 CHANGELOG restructure scope explicitly bounded
  (git-log-tags reconciliation; pre-v1.0.0 out per non-goal).
- §5.1 item 11 added: new docs are added to PLAN-003 §5.5 in a
  follow-up plan revision, not this PR.
- §5.2 PR-B item 1 chose option (a) — split reconcile into own JOB.
- §5.2 item 3 decided per-file: labeler+codeql `pull_request_target`;
  secret-scan `pull_request` read-only + documented limitation.
- §5.2 item 4 added sequencing note (drift-check fix must land before
  PR-A PLAYBOOK doc redirect; bundle into PR-A).
- §5.3 items 2+3 added SHA-verification discipline references
  (`feedback_verify_sha_pins`).
- §5.4 item 3 removed heuristic per §4.1 revision.

_Non-goals (added):_
- Consumer-side pin-bump PRs on tag bumps (PLAN-002 §5.5 scope).
- REPO_STANDARDS.md structural revision (add-only in PR-A).
- Multi-agent elevation-readiness re-run (post-PR-E, not a deliverable).

_Risks (added):_
- R8 — PR-C bump strands stuck-green PR mid-flight; docs recovery.
- R9 — unsubstituted `${...}` reaches consumer; grep-assertion mitigation.
- R10 — stale `CI_TAG` env silently overrides VERSION; startup-log
  mitigation.

_Success criteria (added):_
- Criterion 11: all `actions/*@vN` SHA-pinned (grep-verified).
- Criterion 12: composition.yml PR-author fallback correct.
- Criterion 13: CHANGELOG dedup + per-tag H2 shape.
- Criterion 14: consumer template fork-safety verified.

_Not-load-bearing / accepted:_
- Row 8 line-hint drift (`Step 0 — Reconcile` at :140; buggy `exit 0`
  at :155). Symbol matches exactly at :140; passes PROXIMITY=3 window
  is 15 lines. Keeping symbol-authoritative; line points at step name
  which is the anchor for §2.1 BL-2 discussion.
- Rows 31 + 34 in-bound drift (1 line off), passes gate; no fix.

**Result:** superseded by Pass 3 fold-verification — see Pass 3 below.

### Pass 3 — 2026-07-09 — independent fold-verification (fresh-context Agent)

Dispatched a second fresh-context general-purpose Agent to verify Pass 2
fold landed cleanly. Verdict: **ZERO-LOAD-BEARING-FINDINGS**. All 16
fold-verification checklist items passed ✓ (ledger rows 28 + 18 + 38-43;
design edits §4.1 + §4.3 + §4.4; PR-A CHANGELOG scope + PLAN-003 note;
PR-B options (a) + per-file fork-safety + sequencing note; PR-C SHA
discipline; PR-D heuristic removal; §3 3 new non-goals; §6 R8+R9+R10;
§7 criteria 11-14; `check_plan.py` prints ok).

Two non-blocking cleanups surfaced and folded in this same revision:

1. **Internal-inconsistency fix** — §5.1 item 12 added, explicitly
   bundling the drift-check per-file fix into PR-A (previously the
   §5.2 sequencing note said "bundle into PR-A" but PR-A scope items
   1-11 did not list it). PR-B item 4 retains the CHANGELOG bookkeeping.
2. **codeql semantic trade-off note** — §5.2 item 3 codeql bullet
   gained an explicit sentence on the `pull_request_target` fork-PR
   analysis limitation (base ref, not PR diff) + nightly-schedule
   mitigation.

**Result:** superseded by Pass 4 — founder requested a further gap
review; see Pass 4 below.

### Pass 4 — 2026-07-09 — independent (2 fresh-context Agents, founder-requested)

Founder asked for a further gap review. Dispatched TWO fresh-context
agents in parallel: (a) full-scope adversarial review re-challenging
the technical designs; (b) traceability audit mapping all ~60 findings
from the original 5-agent pre-prod review to plan dispositions.

**(a) Adversarial review — verdict FINDINGS-TO-FOLD (3 BLOCKER, 7 MAJOR):**

- **B1 (BLOCKER, folded):** the Pass-2 `grep -q '\${'` post-substitution
  assertion would fail EVERY install — templates legitimately contain
  bash `${...}` (`pre_push_check.sh:39`) and GHA `${{ }}` syntax
  (`labeler.yml:24`). §4.1 + R9 corrected to assert only declared
  placeholder names on manifest entries with a `substitute` list.
  Ledger rows 48-49 added.
- **B2 (BLOCKER, folded):** de-branding missed the hardcoded trust
  root — the reusables pin `vladm3105/aidoc-flow-operations@main` as
  trust-config source (`ai-review.yml:107,306,315`;
  `auto-merge-ai-prs.yml:168`), making the §1 company-default goal
  unattainable as scoped. PR-D item 6 added: `trust_config_repo` +
  `trust_config_ref` workflow inputs. Ledger rows 44-46 added.
- **B3 (BLOCKER, folded):** success criterion 2's unqualified
  `grep -r vladm3105 <target>/.github/` is guaranteed-red (caller
  `uses:` lines are canon coordinates). Criterion re-scoped to
  branding surfaces. Ledger row 50 added.
- **M1 (folded):** §4.2 gate must mirror composition's carry-forward
  branch (`composition.yml:110-117`) or label-cycle-recovered PRs
  become permanently un-re-armable. Gate design updated; ledger row 47.
- **M2 (folded):** §4.2 claims scoped — arm-then-push TOCTOU residual
  stated explicitly; jq snippet corrected (double quotes + --paginate).
- **M3 (folded):** template caller pin normalization added as PR-A
  item 17 (orphaned §2.2 finding; also traceability arch-H1). Row 52.
- **M4 (folded):** criterion 5 re-scoped to install-command/pin refs
  (blanket grep hits 38 legitimate historical mentions).
- **M5 (folded):** PR-A sub-split reworked to 6 sub-PRs (A1-A6), each
  ≤3 doc surfaces; item-12 script fixes explicitly assigned to PR-A2.
- **M6 (folded):** §4.4 VERSION curl-pipe mode defined (script-dir
  read + format guard; hardcoded fallback operative in curl-pipe).
- **M7 (folded):** codeql fork-safety RE-DECIDED — keep `pull_request`
  + fork-skip the SARIF upload; `pull_request_target` would duplicate
  existing push+cron coverage while green-lighting unanalyzed fork
  diffs. Supersedes the Pass-3 direction. Row 51 added.
- **Minors (folded):** reconcile job-split env/steps replication
  checklist (+ row 53); PR-B item-4 CHANGELOG provenance under
  v1.7.0; criterion-1 tester-account designation; criterion-4
  job-level assertion.

**(b) Traceability audit — verdict GAPS-FOUND (~23 silently dropped):**

All 5 BLOCKERs + 21/27 HIGHs traced clean. Folded dispositions for the
rest: docs H2/H3/H4/M5/M6 → PR-A items 13-16 (sub-PRs A5/A6); docs
H6-security-half → PR-C item 8; docs H5/M2/M4 + gov-LOW charter pointer
→ named explicitly in PR-A items 2-3; arch H1 → PR-A item 17; gov M3 →
PR-A item 18 (CI-0004 delegation entry); corr M1/M2/M4/M5 + docs M3 →
PR-B items 5-8 + item-1 rider; sec M1 + sec-LOW drift-permissions →
PR-C items 7 + 9; arch H4/H5/M1/M2/M3/M4/M5 + sec M4 + LOW tail →
explicit §3 deferred/accepted bullet with rationale.

**Convergence status per OPS-0066:** this is review cycle 3 (Pass 2,
Pass 3, Pass 4). Pass 4 surfaced material findings — all folded above —
but did NOT return zero findings, so the plan does NOT self-declare
ready. Per the 3-cycle circuit-breaker, further review passes are
founder-authorized only. All Pass-4 findings have been folded; the
founder decides: accept as final, or authorize a Pass 5
fold-verification.

**Result:** superseded by Pass 5 — founder authorized a fold-verification;
see Pass 5 below.

### Pass 5 — 2026-07-09 — independent fold-verification (fresh-context Agent, founder-authorized)

Founder authorized one fold-verification pass on the Pass-4 fold (the
OPS-0066 3-cycle cap having been reached at Pass 4). Verdict:
**FINDINGS-TO-FOLD** — 17/17 fold-checklist items verified present +
accurate against source (all four B2 hardcodings, `composition.yml:110-117`
carry-forward, the pin spread incl. the `docs-sync.yml:33` alpha, the
codeql triggers, rows 44-53) — BUT the adversarial re-check caught 2
load-bearing defects the fold itself introduced, plus 5 minors. All
folded here:

- **F1 (MAJOR — fabricated citation, folded):** PR-B item 5 had claimed
  `install.sh:141` already uses a `${name/:/%3A}` label-encode shim.
  Grep-falsified: no `%3A` anywhere; `install.sh:141` is a comment;
  install.sh creates labels via `gh label create` subprocess
  (`install.sh:245-262`), never a URL path. This is the exact
  hallucinated-citation failure mode the ledger exists to prevent — it
  slipped in during the Pass-4 fold prose (not a ledger row, so the gate
  didn't catch it). Corrected to a net-new apply-standards.sh fix;
  ledger rows 54-55 added to anchor the truth.
- **F2 (MAJOR — overbroad claim, folded):** §4.2's "closes the
  no-approval-at-all label bypass" was overbroad — it closes only the
  SINGLE-label variant. The DOUBLE-label variant (`ai:review-passed` +
  `skip-ai-review` together) still merges with zero App approvals via
  composition's carry-forward branch, and tightening the enforcer would
  break §15 label-cycle recovery. §4.2 now states BOTH residuals
  (arm-then-push TOCTOU + double-label) explicitly and names
  branch-protection + label-triage discipline as the true fix.
- **F3 (minor, folded):** `carry_forward_on_skip_label` exists in
  `config.json.template:15` but composition reads the bare label at
  `:110-117`, not the key — §4.2 clarified to mirror the label; wiring
  the key is flagged as a separate PR-C sub-item. Ledger row 61.
- **F4 (minor, folded):** §5.1 item 12 CHANGELOG-provenance phrasing
  reconciled with §5.2 — item-4 code + its CHANGELOG entry both land in
  v1.7.0.
- **F5 (minor, folded):** PR-D item 2 residual directory-detection
  parenthetical removed (contradicted §4.1/item 3); "8 occurrences" →
  "7" (grep + ledger row 18).
- **F6 (minor, folded):** fold-added load-bearing refs ledgered — rows
  54-61 (`apply-standards.sh:537`, `install.sh:262`, `ai-review.yml:315`,
  `:378`, `audit-trail-check.yml:106`, `auto-merge-ai-prs.yml:80`,
  `doc-maintainer.yml:103`, `config.json.template:15`).
- **F7 (minor, folded):** §7 criterion 14 codeql phrasing corrected
  from stale `pull_request_target` to the M7 `pull_request` + fork-skip
  SARIF decision.
- **F8 / checklist item 8 (minor, folded):** PR-A4 (4 surfaces)
  unconditionally pre-split into PR-A4 (3 surfaces) + PR-A4b (CHANGELOG
  alone) — OPS-0061's ≤3-surface rule is mandatory, not
  reviewer-contingent. R3's stale "A1/A2/A3" reference updated to A1–A6.
- **PR-D item 6 risk question (Pass-5, no fold needed):** parameterizing
  the trust root is NOT a new security boundary — a consumer's admin
  already controls its caller file and could remove the enforcer
  outright; the trust root was never a defense against the consumer
  itself. Noted in-plan as a governance caveat (overriding
  `trust_config_repo` makes the operations-stewarded central
  `auto_merge.repos` allowlist advisory for that consumer), not a
  vulnerability.

**Convergence status per OPS-0066:** this was review CYCLE 4 (Passes 2-5).
The 3-cycle circuit-breaker was already reached at Pass 4; Pass 5 ran
under explicit founder authorization. Pass 5 surfaced material
fold-introduced defects (F1 fabricated citation especially) — all now
folded — but by the circuit-breaker rule I do NOT self-authorize a
Pass 6. The plan is handed to the founder: accept as final, or authorize
one more verification of THIS fold (F1/F2 touched load-bearing prose).

**Founder decision (2026-07-09):** accept as final. Pass-5 findings all
folded (F1 fabricated-citation correction + F2 double-label residual
being the load-bearing two); the founder reviewed the convergence state
and accepted rather than authorizing a Pass 6. Recorded here per OPS-0066
(the ready declaration is the founder's, not a self-authorized pass).

**Result:** ready — founder-accepted 2026-07-09; gate green (61 citations,
5 review passes); no further review pass authorized. Plan may open its PR
(the A1–A6 / B / C / D / E sequence in §5).


