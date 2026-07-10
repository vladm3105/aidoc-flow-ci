# PLAN-005 — AI-review pipeline hardening (pre-prod review gap closure)

| Field | Value |
|---|---|
| **Status** | DRAFT — 2026-07-09 EST |
| **Owner** | aidoc-flow-ci (canon) |
| **Trigger** | 2026-07-09 five-lens pre-prod review of the ai-review pipeline (security / correctness / docs / portability / governance) |
| **Relationship to PLAN-004** | Extends PLAN-004 (company-default elevation). B1 **deepens** PLAN-004 BL-3; B2 is **new** (not in PLAN-004); B3 is a release-ordering gate for PLAN-004 BL-4. Overlaps are cross-referenced, not duplicated. |
| **Exit** | B1/B2/B3 closed + verified on a real consumer (interlog); HIGH items closed; each PR ≤3 governance surfaces |

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development
> or superpowers:executing-plans. Steps use `- [ ]` checkboxes.

**Goal:** Close the pre-prod review's BLOCKER + HIGH findings in the ai-review
pipeline — the auth-model bypass (B1), the consumer `startup_failure` (B2), and
the unpublished-tag install break (B3) — plus the reviewer-engine and
external-adopter HIGH gaps, so the pipeline is safe to run on consumers and to
elevate to the company default.

**Architecture:** Seven PRs (PR-A…PR-G). PR-A is the security fix (auth model).
PR-B is the startup_failure fix (caller templates + a verify assertion). PR-C
is the release-tag ordering. PR-D/E close the reviewer-engine + external-adopter
HIGH items. PR-F is the branch-protection/bootstrap guard + decision log. PR-G
is docs. **The three BLOCKERs (PR-A, PR-B, PR-C) share no files and may land in
any order.** The follow-ons have real file overlaps and MUST be ordered: **PR-D
and PR-E both edit `ai-review-public.yml` that PR-B first adds a block to → run
after PR-B; PR-E's public-path step consumes PR-D's chosen `reviewer:` default →
PR-E after PR-D; PR-G edits `composition.yml:156` inside the region PR-A
reorders → PR-G after PR-A.** PR-F is independent.

**Tech Stack:** GitHub Actions YAML (reusable + caller templates); POSIX shell
(install/apply-standards/sync scripts); JSON config; Markdown docs. No app code.

## Global constraints

- **OPS-0061:** ≤3 governance doc surfaces per PR. Workflow YAML, JSON
  templates, and shell scripts are the artifacts under change; CHANGELOG /
  HANDOFF continuity edits per PR are not counted as governance surfaces (repo
  convention, `CLAUDE.md`).
- **Least privilege is a design invariant:** the canon deliberately sets
  `default_workflow_permissions: "read"` (`install/templates/actions-permissions.json:28`).
  B2's fix MUST preserve that and grant write only at the callers that need it
  — never flip the repo default, never drop the reusable to read.
- **Fail-closed is a design invariant:** every governance/trust decision must
  fail toward *block / human-merge*, never toward *pass / auto-merge*. New gates
  in PR-A inherit this.
- **No consumer-repo edits from this plan** beyond the one verification consumer
  (interlog) in PR-B step 6 — canon changes ship via templates + the drift
  checker; consumers re-adopt on their own cadence.
- **Language:** objective, factual; no promotional qualifiers.

## Decision record (durable decisions this plan encodes)

- **D1 — the enforcer owns its own governance floor.** `auto-merge-ai-prs.yml`
  currently has no governance-floor computation; it trusts that ai-review +
  composition already blocked gov PRs. Under `skip-ai-review` both pass green
  before their floors, so the enforcer MUST independently compute the floor and
  refuse to re-arm a gov-locked PR **unconditionally** — even under
  `skip-ai-review`. (Closes B1; PLAN-004 BL-3's "make composition required" is
  necessary but insufficient because composition itself honors the label first.)
- **D2 — `skip-ai-review` is advisory, not authorization.** Carry-forward
  (`composition.yml`, `auto-merge-ai-prs.yml`) MUST verify that ≥1 reviewer-App
  APPROVED review *ever* existed on the PR before honoring the skip; a PR that
  was never reviewed once cannot pass on the label alone. And the governance
  floor is evaluated **before** the carry-forward.
- **D3 — write is granted at the caller, not the repo.** The `ai-review` caller
  templates gain an explicit `permissions:` block (matching the auto-merge
  caller that already ships one), which elevates above the `read` repo default
  without loosening any other workflow. This is the startup_failure fix (B2).
- **D4 — VERSION never leads the published tag set.** `sync-version-refs.sh
  --check` gains a tag-existence assertion so a template pin can never reference
  an uncut tag (B3).
- **D5 — reviewer engine and its key are chosen together.** The onboarding doc
  and the caller templates must agree on `reviewer:` ↔ the engine secret; the
  default combo must be a documented, CI-verified working pair.
- **D6 — external adopters get a working default.** `trust_config_repo` defaults
  to the consumer's own repo (`${{ github.repository }}`) so an external adopter
  is not blocked reading a private vladm3105 repo.

## Sequencing & finding disposition

| PR | Closes (review id) | Depends on | PLAN-004 relation |
|----|--------------------|-----------|-------------------|
| PR-A | **B1** (F1/F2 auth bypass) | — | deepens BL-3 |
| PR-B | **B2** (caller-permissions startup_failure) | — | NEW |
| PR-C | **B3** (unpublished v1.7.0 tag) | — | gates BL-4 release |
| PR-D | HIGH: reviewer-engine token mismatch (docs D1) | PR-B | overlaps BL-4 |
| PR-E | HIGH: `trust_config_repo` default; HIGH: public-path verification | PR-B, PR-D | overlaps BL-1 |
| PR-F | MED: bootstrap+auto-merge guard (F4); MED: trust-policy decision log (G2) | — | — |
| PR-G | MED: cold-start doc gaps (D2/D3/D4); `composition ?ref=main` (FT-6) | PR-A | overlaps BL-4/FT-6 |

Explicitly **deferred to PLAN-004 / FRAMEWORK-TODO** (not silently dropped):
BL-5 install-upgrade path (my MED "install can't bump the pin") → PLAN-004 BL-5;
FT-3 labels.json contradiction (my LOW) → FRAMEWORK-TODO FT-3; IPLAN-ref
anchoring + CHANGELOG back-catalog headers (my LOW) → FRAMEWORK-TODO;
create-github-app-token SHA↔tag confirmation (my LOW) → folded into PR-C's
pre-tag checklist.

---

### Task PR-A: Enforcer governance floor + carry-forward approval check (B1)

**Files:**
- Modify: `.github/workflows/auto-merge-ai-prs.yml` (add a governance-floor step before the re-arm; gate the `skip-ai-review` branch on it)
- Modify: `.github/workflows/composition.yml` (evaluate the governance floor before the `skip-ai-review` carry-forward; require a prior App approval)

**Interfaces:**
- Consumes: the reviewer-App identity (`vars.APP_REVIEWER_1_BOT_ID`) and the reviews API already used at `auto-merge-ai-prs.yml:317-319`.
- Produces: the invariant "a gov-locked PR is never auto-merged, under any label combination."

- [ ] **Step 1 — reproduce the bypass (red).** In a scratch/test PR on this
  repo touching `.github/workflows/**`, hand-apply `ai:review-passed` +
  `skip-ai-review` and confirm the enforcer path reaches the re-arm step
  (`auto-merge-ai-prs.yml:359`) without any App-approval check firing (the
  `skip-ai-review` branch at `:302-303` audits "App-at-HEAD check skipped"). Do
  NOT actually let it merge — observe the audit log only.
- [ ] **Step 2 — add a governance-floor computation to `auto-merge-ai-prs.yml`**,
  reusing the exact glob + fail-closed logic from `ai-review.yml:448-464`:
  retry the changed-file list, require the listing provably complete (else
  LOCK), `grep -qE '(^|/)governance/|(^|/)\.github/|(^|/)templates/ai-review/'`,
  and `case "$GH_REPO" in */aidoc-flow-framework) LOCKED=true;; esac`. Place it
  BEFORE the `skip-ai-review` branch (`:302`).
- [ ] **Step 3 — refuse the re-arm when locked, unconditionally.** If
  `GOV_LOCKED=true`: `audit "governance-locked PR → human-merge only; refusing
  to re-arm"; exit 0` — reached even when `skip-ai-review` is present (the label
  branch no longer short-circuits past it).
- [ ] **Step 4 — require a prior approval for the skip carry-forward (D2).** In
  the `skip-ai-review` branch (`auto-merge-ai-prs.yml:302-304`), before honoring
  the skip, query the reviews API for ANY historical
  `user.id==EXPECTED_ID and user.type=="Bot" and state=="APPROVED"` review on
  the PR (not tied to HEAD). If zero, `audit`+`exit 0` (refuse) — a never-
  reviewed PR cannot ride the label.
- [ ] **Step 5 — mirror both in `composition.yml`.** Move the governance-floor
  block (currently `:179-195`) to run BEFORE the `skip-ai-review` carry-forward
  exit (`:121-123`), so a `.github/**`/`governance/**` PR is never carried-
  forward green; and add the same "≥1 prior App-APPROVED review ever" check to
  the carry-forward branch.
- [ ] **Step 6 — remove the stale residual note.** Update the note at
  `auto-merge-ai-prs.yml:329-337` — the double-label variant is now closed by
  the enforcer's own floor; keep only the genuinely-remaining TOCTOU note.
- [ ] **Step 7 — verify (green).** Re-run the Step-1 scenario: the gov-locked
  double-label PR now hits `refusing to re-arm` and never merges; a routine
  (non-gov) `skip-ai-review` PR with a real prior App approval still carries
  forward. Confirm via the audit log.
- [ ] **Step 8 — OPS-0065 self-review (security-lens agent on the diff), commit,
  push, PR.** Commit `fix(security): PLAN-005 PR-A — enforcer governance floor +
  carry-forward approval check (closes the skip-ai-review double-label bypass)`.

### Task PR-B: `ai-review` caller `permissions:` block (B2 — the startup_failure)

**Files:**
- Modify: `install/templates/workflows/ai-review-public.yml` (add top-level `permissions:`)
- Modify: `install/templates/workflows/ai-review-private.yml` (add top-level `permissions:` + a header comment)

**Interfaces:**
- Consumes: the reusable's declared write scopes (`ai-review.yml:75-78`).
- Produces: a caller whose token ceiling ≥ the reusable's request, so the
  reusable loads under the canon `read` default.

- [ ] **Step 1 — confirm the mechanism.** The reusable declares `contents:
  write / pull-requests: write / issues: write` (`ai-review.yml:76-78`); the
  canon default is `read` (`actions-permissions.json:28`); both `ai-review`
  callers have **no** `permissions:` block (`grep -c permissions:` → 0 on both).
  A `workflow_call` reusable cannot exceed the caller's grant, so under `read`
  the write request is rejected at load → `startup_failure`, zero jobs.
- [ ] **Step 2 — add the block to both templates**, verbatim from the sibling
  that already ships it (`auto-merge-ai-prs-public.yml:41-44`), placed at
  top level (above `jobs:`):

```yaml
permissions:
  contents: write        # reusable auto-merge fallback (gh pr merge via GITHUB_TOKEN)
  pull-requests: write   # trust-job comment + verdict comments + label set
  issues: write          # gh api .../labels create+apply paths
```

  Give `ai-review-private.yml` a header comment matching the public template's
  (`ai-review-public.yml:9-12`) naming the required secrets + this block.
- [ ] **Step 3 — do NOT touch `actions-permissions.json`.** Confirm
  `default_workflow_permissions` stays `"read"` (`:28`) — the caller block
  elevates without loosening the repo default (least-privilege invariant).
- [ ] **Step 4 — regenerate any derived pins** if `sync-version-refs.sh` rewrites
  these templates (it edits `uses:` lines only, so the new `permissions:` block
  is untouched) — run `scripts/sync-version-refs.sh --check` and confirm clean.
- [ ] **Step 5 — static verify.** `grep -c '^permissions:'` on both templates →
  1 each; both list contents/pull-requests/issues write.
- [ ] **Step 6 — live verify on interlog.** Copy the updated
  `ai-review.yml` caller into `vladm3105/aidoc-flow-interlog` (a `.github/**`
  change — founder-gated; open as a normal PR there), open a test PR, and
  confirm `ai-review` now **schedules jobs** (no `startup_failure`) and that
  `composition` begins posting `call / composition` (the workflow_run chain
  restored). This is the acceptance proof for B2.
- [ ] **Step 7 — OPS-0065 self-review (correctness-lens agent), commit, push,
  PR.** Commit `fix(ci): PLAN-005 PR-B — add permissions block to ai-review
  caller templates (fixes consumer startup_failure under the read default)`.

### Task PR-C: Release-tag ordering — publish `ci/v1.7.0` or hold VERSION (B3)

**Files:**
- Modify: `scripts/sync-version-refs.sh` (add a tag-existence assertion to `--check`)
- Possibly modify: `VERSION` (only if holding at v1.6.0 is chosen)

**Interfaces:**
- Produces: the guarantee that a shipped template pin always resolves.

- [ ] **Step 1 — confirm the break.** `VERSION` = `ci/v1.7.0`; `git tag
  --sort=-v:refname | head -1` and `git ls-remote --tags origin` top out at
  `ci/v1.6.0`; all caller templates pin `@ci/v1.7.0` (e.g.
  `ai-review-public.yml` `uses: …@ci/v1.7.0`). A fresh install references an
  unresolvable ref → startup_failure independent of B2.
- [ ] **Step 2 — choose the ordering fix (founder decision point):** either
  (a) cut + push `ci/v1.7.0` atomically with shipping these PRs, or (b) revert
  `VERSION` to `ci/v1.6.0` and re-run `sync-version-refs.sh` to re-pin templates
  until the cut. Record the choice in the PR body. Include the LOW-tier
  create-github-app-token@`d72941d…`/checkout@`9c091bb…` SHA↔tag confirmation
  (`gh api repos/actions/create-github-app-token/git/refs/tags/v1.12.0`) in the
  pre-tag checklist.
- [ ] **Step 3 — add the guard.** In `sync-version-refs.sh` `--check`, after
  reading `$VERSION` (`:28`), assert the tag exists:
  `git rev-parse --verify "refs/tags/$VERSION" >/dev/null 2>&1 || git ls-remote
  --exit-code --tags origin "$VERSION" >/dev/null 2>&1` — fail `--check` (and
  thus pre-commit + CI) if VERSION leads the published tags.
- [ ] **Step 4 — verify.** With `VERSION` ahead of tags, `sync-version-refs.sh
  --check` now FAILS; after the tag exists (or VERSION is reverted) it PASSES.
- [ ] **Step 5 — OPS-0065 self-review, commit, push, PR.** Commit
  `fix(release): PLAN-005 PR-C — tag-existence guard so VERSION never leads the
  published tag set (B3)`.

### Task PR-D: Reviewer-engine ↔ token reconciliation (HIGH)

**Files:**
- Modify: `docs/REVIEWER_APP_ONBOARDING.md` (engine-token step)
- Modify: `install/templates/workflows/ai-review-public.yml` + `ai-review-private.yml` (header note tying `reviewer:` to its key)

**Interfaces:**
- Produces: an adopter who cannot arm a reviewer engine whose key they didn't set.

- [ ] **Step 1 — the mismatch.** Onboarding step lists/sets
  `CLAUDE_CODE_OAUTH_TOKEN` as "preferred"
  (`REVIEWER_APP_ONBOARDING.md:26`, `:58`), but both callers pin `reviewer:
  codex` (`ai-review-public.yml:30`, `ai-review-private.yml:11`), which needs
  `OPENAI_API_KEY`. An adopter who follows the doc arms codex with a Claude
  token → reviewer can't authenticate (the interlog "App set, engine key wrong"
  state).
- [ ] **Step 2 — pick one coherent default and make everything agree.** Decide
  the shipped default `reviewer:` (recommend `claude` to match the doc's
  preferred `CLAUDE_CODE_OAUTH_TOKEN`, OR keep `codex` and change the doc to set
  `OPENAI_API_KEY`). Update BOTH caller templates and the onboarding doc to the
  chosen pair; add an explicit sentence: "the `reviewer:` input MUST match the
  engine secret you set (`claude`→`CLAUDE_CODE_OAUTH_TOKEN`/`ANTHROPIC_API_KEY`;
  `codex`→`OPENAI_API_KEY`)."
- [ ] **Step 3 — verify.** The `reviewer:` value in both templates, the secret
  the onboarding doc sets, and the reusable's engine-auth step
  (`ai-review.yml:474-482`) name a single consistent engine.
- [ ] **Step 4 — OPS-0065 self-review, commit, push, PR.** Commit
  `fix(docs+ci): PLAN-005 PR-D — reconcile reviewer engine with its auth token`.

### Task PR-E: External-adopter defaults + public-path verification (HIGH)

**Files:**
- Modify: `.github/workflows/ai-review.yml` (`trust_config_repo` default) + `.github/workflows/auto-merge-ai-prs.yml` (matching default at `:50`)
- Modify: `install/templates/workflows/ai-review-public.yml` (public-runner reviewer path)

**Interfaces:**
- Produces: an external adopter whose own PRs are reviewable without read access to a vladm3105 private repo.

- [ ] **Step 1 — the block.** `trust_config_repo` defaults to
  `vladm3105/aidoc-flow-operations` (`ai-review.yml:69`); an external adopter's
  trust-job checkout of that private repo fails → their own PRs go red.
- [ ] **Step 2 — default to self.** Change the default to
  `${{ github.repository }}` in `ai-review.yml:69` and the matching
  `auto-merge-ai-prs.yml:50` description/default (the installer already writes a
  valid `config.json` into the consumer, so self-reference resolves). Keep the
  override input so a shared-ops adopter can still point elsewhere.
- [ ] **Step 3 — verify the public reviewer path (or gate it).** The public
  caller's CLI-install-at-workflow-start is "unverified-in-CI"
  (`ai-review-public.yml:1-7`). Either run the default public combo
  (`reviewer:` from PR-D + `ubuntu-latest` + the matching key) green in a real
  public test repo and drop the "unverified" caveat, OR keep the caveat and mark
  the public path EXPERIMENTAL in the onboarding doc until verified. Record which.
- [ ] **Step 4 — verify.** New consumer with no `trust_config_repo` override +
  its own `config.json` → trust job resolves against its own repo.
- [ ] **Step 5 — OPS-0065 self-review, commit, push, PR.** Commit
  `fix(ci): PLAN-005 PR-E — self-default trust_config_repo + public reviewer
  path disposition`.

### Task PR-F: Bootstrap+auto-merge guard + trust-policy decision log (MED)

**Files:**
- Modify: `install/apply-standards.sh` (guard)
- Modify: `DECISIONS.md` (CI-NNNN for the trust boundary)

- [ ] **Step 1 — guard.** `branch-protection-bootstrap.json` requires only
  `Lint / format / security hooks` (`:7`) — no ai-review/composition. Add a
  check in `apply-standards.sh` that refuses to install the `auto-merge-ai-prs`
  caller on a repo whose required checks lack `call / composition` (so a
  bootstrap-profile repo cannot get auto-merge without a review gate). Document
  bootstrap as a pre-activation profile that MUST NOT coexist with auto-merge.
- [ ] **Step 2 — decision log.** Add a `CI-NNNN` entry (or extend CI-0004) in
  `DECISIONS.md` recording the trust-boundary policy ("we trust only ourself" /
  `trust.ai_review` allowlist), the reviewer-App approval identity, the
  `skip-ai-review` semantics (now hardened by PR-A/D2), and the enforcer
  governance floor (PR-A/D1).
- [ ] **Step 3 — verify + OPS-0065 self-review, commit, push, PR.** Commit
  `fix(governance): PLAN-005 PR-F — bootstrap/auto-merge install guard + trust-
  policy decision log`.

### Task PR-G: Cold-start docs + `composition ?ref=main` (MED)

**Files:**
- Modify: `docs/REVIEWER_APP_ONBOARDING.md` (repo-settings prerequisites step)
- Modify: `.github/workflows/composition.yml` (parameterize the config ref)

- [ ] **Step 1 — repo-settings prerequisites in the onboarding checklist.** Pull
  the two startup_failure prerequisites (the caller `permissions:` block from
  PR-B; the Actions-allowlist/`default_workflow_permissions` context) into the
  onboarding doc BEFORE its first-PR step, cross-linking `troubleshooting §13/§14`
  and warning against arming `call / ai-review` as required before the workflow
  can pass (install-order deadlock).
- [ ] **Step 2 — non-`main` default branch (FT-6 overlap).** `composition.yml:156`
  hardcodes `?ref=main`; read the config from the repo's actual default branch
  (`gh api repos/$GH_REPO --jq .default_branch`, or an input) so a `master`/
  `develop` consumer isn't hard-blocked. Cross-reference FRAMEWORK-TODO FT-6.
- [ ] **Step 3 — verify + OPS-0065 self-review, commit, push, PR.** Commit
  `docs+fix(ci): PLAN-005 PR-G — cold-start repo-settings prerequisites +
  default-branch-agnostic composition config read`.

---

## Claim ledger

All citations resolve against this repo (`/opt/data/aidoc-flow/aidoc-flow-ci`).

| # | Claim | Symbol | Citation |
|---|-------|--------|----------|
| 1 | The reusable ai-review declares workflow-level write permissions | `contents: write        # auto-merge` | .github/workflows/ai-review.yml:76 |
| 2 | The canon sets the repo default token permission to read | `"default_workflow_permissions": "read"` | install/templates/actions-permissions.json:28 |
| 3 | The auto-merge caller template already ships a top-level permissions block (the fix pattern) | `permissions:` | install/templates/workflows/auto-merge-ai-prs-public.yml:41 |
| 4 | The reviewer input is pinned to codex in the public caller | `reviewer: codex` | install/templates/workflows/ai-review-public.yml:30 |
| 5 | The reviewer input is pinned to codex in the private caller | `reviewer: codex` | install/templates/workflows/ai-review-private.yml:11 |
| 6 | The public caller header maps OPENAI_API_KEY to reviewer codex | `OPENAI_API_KEY                           if reviewer: codex` | install/templates/workflows/ai-review-public.yml:11 |
| 7 | pre-commit reusable requests only contents:read (the loads-fine contrast) | `contents: read` | .github/workflows/pre-commit.yml:58 |
| 8 | pre-commit caller grants contents:read (matched ceiling) | `contents: read` | install/templates/workflows/pre-commit.yml:19 |
| 9 | The ai-review gate has a fail-closed governance floor locking .github/** etc. | `grep -qE '(^|/)governance/|(^|/)\.github/|(^|/)templates/ai-review/'` | .github/workflows/ai-review.yml:462 |
| 10 | The ai-review gate exports GOV_LOCKED | `echo "GOV_LOCKED=$LOCKED"` | .github/workflows/ai-review.yml:464 |
| 11 | composition carries forward (exit-passes) on the skip-ai-review label | `composition carried forward` | .github/workflows/composition.yml:122 |
| 12 | composition's governance floor is AFTER the skip carry-forward exit | `GOVERNANCE FLOOR (same globs as the ai-review gate)` | .github/workflows/composition.yml:179 |
| 13 | composition's gov-lock grep is at line 191 (after the skip exit at 122) | `then LOCKED=true; fi` | .github/workflows/composition.yml:191 |
| 14 | The auto-merge enforcer skips the App-at-HEAD check under skip-ai-review | `App-at-HEAD check skipped` | .github/workflows/auto-merge-ai-prs.yml:303 |
| 15 | The enforcer's own residual note admits the double-label variant is open | `the double-label variant` | .github/workflows/auto-merge-ai-prs.yml:331 |
| 16 | The enforcer re-arms native auto-merge | `retry gh pr merge "$PR" --auto --merge` | .github/workflows/auto-merge-ai-prs.yml:359 |
| 17 | The enforcer re-checks trust.ai_review + tier + auto_merge.repos (trust gate) | `TRUST GATE (per §2.1 step 2)` | .github/workflows/auto-merge-ai-prs.yml:30 |
| 18 | The auto-merge caller default trust_config_repo (must match ai-review) | `must match ai-review.yml` | .github/workflows/auto-merge-ai-prs.yml:50 |
| 19 | ai-review defaults trust_config_repo to the private operations repo | `default: 'vladm3105/aidoc-flow-operations'` | .github/workflows/ai-review.yml:69 |
| 20 | composition reads the consumer config hardcoded at ?ref=main | `config.json?ref=main` | .github/workflows/composition.yml:156 |
| 21 | The onboarding doc lists CLAUDE_CODE_OAUTH_TOKEN as the preferred engine token | `CLAUDE_CODE_OAUTH_TOKEN` (Claude subscription — preferred | docs/REVIEWER_APP_ONBOARDING.md:26 |
| 22 | The onboarding doc's setup step sets CLAUDE_CODE_OAUTH_TOKEN | `gh secret set CLAUDE_CODE_OAUTH_TOKEN` | docs/REVIEWER_APP_ONBOARDING.md:58 |
| 23 | The reusable authenticates the reviewer engine from the vendor key exported to the CLI | `Export consumer-provided auth secrets to the CLI` | .github/workflows/ai-review.yml:474 |
| 24 | The public caller warns its CLI-install path is unverified-in-CI | `unverified-in-CI` | install/templates/workflows/ai-review-public.yml:6 |
| 25 | VERSION points at ci/v1.7.0 (which is not a published tag) | `ci/v1.7.0` | VERSION:1 |
| 26 | sync-version-refs propagates VERSION into template uses: pins | `uses: vladm3105/aidoc-flow-ci/.github/workflows/<wf>.yml@<TAG>` | scripts/sync-version-refs.sh:11 |
| 27 | The bootstrap branch-protection profile requires only the lint check (no ai-review/composition) | `Lint / format / security hooks` | install/templates/branch-protection-bootstrap.json:7 |
| 28 | PLAN-004 BL-3 frames the auto-merge bypass as "composition INERT" (this plan deepens it) | `is INERT` | plans/PLAN-004_company-default-elevation.md:65 |
| 29 | PLAN-004 BL-5 owns the install-upgrade-path gap (deferred there) | `No update path` | plans/PLAN-004_company-default-elevation.md:85 |
| 30 | FRAMEWORK-TODO FT-6 tracks composition reading $GH_REPO@main vs the trust_config_repo inputs | `trust-config source inconsistency` | plans/FRAMEWORK-TODO.md:104 |

## Review log

### Pass 1 - 2026-07-09 - author self-check

Plan assembled from the 2026-07-09 five-lens pre-prod review. Every ledger
citation opened and read in this session while gathering symbols. Spec-coverage:
each review BLOCKER maps to a PR (B1→PR-A, B2→PR-B, B3→PR-C); each HIGH maps
(engine-token→PR-D, trust_config_repo + public-path→PR-E); each MED maps
(bootstrap guard + decision log→PR-F, cold-start docs + composition ref→PR-G);
LOW/overlap items are explicitly deferred to PLAN-004 BL-5 / FRAMEWORK-TODO,
not dropped. Placeholder scan: no TBDs; the added `permissions:` block, the
governance-floor glob, and the tag-existence assertion are concrete. Type/label
consistency: `GOV_LOCKED`, `EXPECTED_ID`, `skip-ai-review`, `ai:review-passed`
match the workflow source. Overlap with PLAN-004 handled by cross-reference
(D1 deepens BL-3; B2 is new), not duplication.

### Pass 2 - 2026-07-09 - independent (fresh-context Agent)

Fresh-context adversarial reviewer verified all 30 ledger citations against the
real workflow source AND stress-tested the three headline fix mechanisms
(the highest risk for a canon fix that ships to ~9 consumers):

- **B2 (caller `permissions:` block) confirmed GitHub-Actions-correct** — the
  `read` default is a *default, not a hard cap*; an explicit caller block
  elevates the token, and a `workflow_call` reusable requesting above the
  caller's grant fails at load (`startup_failure`, no silent downgrade). The
  auto-merge sibling template proves the pattern; PR-B step 6's interlog
  verification de-risks it further. **Not the wrong-fix failure mode.**
- **B1 (enforcer gov floor) correctly directed** — all three premises verified:
  the enforcer computes no gov floor; composition's skip carry-forward precedes
  its floor; the ai-review gate has the floor. D2's prior-approval check doesn't
  break the legitimate routine skip flow.
- **B3 confirmed** — `ci/v1.7.0` genuinely unpublished; VERSION leads the tags.
- PR-E's "installer writes config.json → self-reference resolves" claim
  confirmed against `install/install.sh`.

Findings folded in this revision: (1) row 23's citation contradicted its claim
(pointed at the "no secret" line) → re-pointed to the engine-auth export step
(`ai-review.yml:474`); (2) rows 9/28/29 line-drift → re-pointed via
`check_plan.py --fix`; (3) the "the rest depend on none of each other" claim
understated real file overlaps → sequencing table gains a **Depends on** column
(PR-D→PR-B, PR-E→PR-B+PR-D, PR-G→PR-A) and the architecture paragraph states
them. No fix mechanism required change. **Result:** ready
