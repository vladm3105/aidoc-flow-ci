# PLAN-005 — AI-review pipeline hardening (pre-prod review gap closure)

| Field | Value |
|---|---|
| **Status** | SHIPPED — 2026-07-10 (ci/v1.7.1 → v1.8.1). 7/7 PRs complete; exit condition met. |
| **Owner** | aidoc-flow-ci (canon) |
| **Trigger** | 2026-07-09 five-lens pre-prod review of the ai-review pipeline (security / correctness / docs / portability / governance) |
| **Relationship to PLAN-004** | PLAN-004 (company-default elevation) is **SHIPPED** (`ci/v1.7.0`, 2026-07-10). This plan closes the ai-review *pipeline* gaps that elevation assumed but did not verify. Overlaps are cross-referenced, not duplicated. |
| **Exit** | PR-A/C/D/E/F/G closed + verified on ≥1 real consumer (interlog) AND ≥1 non-`main`-default-branch consumer; a `ci/v1.7.x`/`v1.8.0` cut per §Release; each PR ≤3 governance surfaces |

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development
> or superpowers:executing-plans. Steps use `- [ ]` checkboxes.

> **rev-2 re-baseline (2026-07-10):** A three-agent from-scratch review (security /
> correctness / architecture) ran against the shipped source. Result: SHIP-WITH-FIXES.
> This revision (a) marks **PR-B SHIPPED** (the B2 `startup_failure` fix landed as
> `ci/v1.7.1`, PR #106); (b) **redesigns D2** (the original was both a live bypass AND a
> break of the §15 recovery path); (c) **reverses PR-E's default flip** (it broke the
> enforcer and weakened the trust model); (d) collapses **PR-C** to a preventive guard
> (B3's break is resolved — the tag is cut) and fixes its snippet bugs; (e) corrects all
> stale PLAN-004 cross-references; (f) adds a **Release & propagation** section; (g) adds
> a governance-config-knobs finding (D7). See §Review log Pass 3 for the full disposition.

**Goal:** Make the ai-review pipeline safe to run + actually functional on consumers.
The `startup_failure` (B2) is FIXED (v1.7.1). Remaining: the enforcer governance-floor +
`skip-ai-review` carry-forward hardening (B1/D2), the reviewer-engine↔token mismatch, the
external-adopter onboarding gaps, and two MED items — plus getting the fixes propagated to
the ~9 already-adopted consumers.

**Architecture:** Six substantive PRs remain (PR-A, C, D, E, F, G — **PR-B is SHIPPED**).
After the re-baseline the net work compresses: **PR-C → preventive guard only**, **PR-E →
docs + public-path disposition only** (no default change). The remaining BLOCKER (PR-A)
shares no files with the others and may land any time. Real ordering deps:
**PR-D edits both `ai-review-{public,private}.yml` and PR-E edits `ai-review-public.yml` →
run after the v1.7.1 baseline (already merged); PR-E's public-path step consumes PR-D's
chosen `reviewer:` default → PR-E after PR-D; PR-G edits `composition.yml:156` inside the
region PR-A relocates → PR-G after PR-A.** PR-F is independent. (After the D6 reversal PR-E
no longer edits `auto-merge-ai-prs.yml`, so there is no PR-A∩PR-E overlap.)

**Tech Stack:** GitHub Actions YAML (reusable + caller templates); POSIX shell
(install/apply-standards/sync scripts); JSON config; Markdown docs. No app code.

## Global constraints

- **OPS-0061:** ≤3 governance doc surfaces per PR. Workflow YAML, JSON templates, and
  shell scripts are the artifacts under change; CHANGELOG / HANDOFF continuity edits per PR
  are not counted as governance surfaces (repo convention, `CLAUDE.md`).
- **Least privilege is a design invariant:** the canon sets `default_workflow_permissions:
  "read"` (`install/templates/actions-permissions.json:28`). Caller `permissions:` blocks
  elevate only their own workflow (as v1.7.1's ai-review fix did) — never flip the repo
  default, never drop a reusable to read.
- **Diff-only invariant (from the v1.7.1 fix):** the `ai-review` reusable is safe under
  `pull_request_target` + `contents: write` ONLY because it is diff-only — it fetches the
  PR diff via `curl`/`gh api` and never `actions/checkout`s the PR head into a
  write-capable job. Any PR that touches the reusable MUST preserve this.
- **Fail-closed is a design invariant:** every governance/trust decision must fail toward
  *block / human-merge*, never toward *pass / auto-merge*.
- **Trust root stays external (D1/BL-2):** auto-merge authorization reads the trust config
  from `trust_config_repo`@`trust_config_ref` (default operations) — a non-PR-mutable ref
  outside the gated repo. Do NOT default it to the consumer's own repo (see D6).
- **No consumer-repo edits from this plan** beyond the verification consumers (interlog +
  one non-`main`-default-branch repo) — canon changes ship via templates + `install.sh
  --update`; consumers re-adopt on their own cadence.
- **Language:** objective, factual; no promotional qualifiers.

## Decision record (durable decisions this plan encodes)

- **D1 — the enforcer owns its own governance floor.** `auto-merge-ai-prs.yml` has NO
  `GOV_LOCKED` computation (grep-confirmed) and trusts that ai-review + composition already
  blocked gov PRs. But under `skip-ai-review` the ai-review floor step is itself gated off
  (`ai-review.yml:423` `if: env.SKIP_REVIEW != '1'`) and composition carries forward
  (`composition.yml:122`), so both pass green before their floors bite. The enforcer MUST
  independently compute the floor and refuse to re-arm a gov-locked PR **unconditionally** —
  even under `skip-ai-review`. PLAN-004's shipped App-APPROVED-at-HEAD gate (`#98`,
  `auto-merge-ai-prs.yml:280-328`) closed the *single-label* hand-applied-`ai:review-passed`
  bypass but EXEMPTS the `skip-ai-review` branch (`:302-303`) — so it is necessary but
  insufficient. (Closes B1.)
- **D2 — `skip-ai-review` is advisory, not authorization — but the check must be
  HEAD-relative AND must not break §15 recovery.** (REDESIGNED in rev 2.) The original
  "≥1 App-APPROVED review *ever*" was wrong two ways: (i) too weak — an attacker can earn a
  benign approval at HEAD1, push malicious HEAD2, and the stale "ever approved" row still
  matches (GitHub does not auto-dismiss App reviews); (ii) too strong — a `§15
  label-cycle-recovered` PR (`docs/troubleshooting.md:458`) may legitimately hold NO
  APPROVED review, which "ever approved" would refuse forever (PLAN-004 §4.2 logged this as
  a *deliberate* residual). Correct design: the carry-forward honors `skip-ai-review` ONLY
  when **either** (a) an App-APPROVED review exists whose `commit_id` is an ancestor of HEAD
  **and** `git diff <approved>..HEAD` touches no review-material path (the legit
  rebase/lint/label-cycle case — no new code since approval), **or** (b) the PR is
  explicitly on the documented §15 recovery path. The **governance floor (D1) is evaluated
  BEFORE** the carry-forward regardless. Keep the residual note (do NOT remove it per the
  old PR-A Step 6) and correct its "make composition required = complete fix" claim.
- **D3 — write is granted at the caller (SHIPPED as v1.7.1).** The `ai-review` caller
  templates now ship a top-level `permissions:` block matching the reusable's scopes; the
  repo default stays `read`. This closed B2 (`startup_failure`). Nothing left to do here
  except propagate to consumers (see §Release).
- **D4 — VERSION never leads the *published* tag set (preventive).** Add a tag-existence
  assertion to `sync-version-refs.sh --check` — but check **remote** existence (consumers
  resolve `@ci/vX.Y.Z` from GitHub, so a local-only tag still breaks installs), and exempt
  the in-flight release-bump commit (else the guard deadlocks: the tag is cut *from* the
  bump commit). B3's immediate break is already resolved (`ci/v1.7.0`/`v1.7.1` are
  published); this is defense-in-depth only.
- **D5 — reviewer engine and its key are chosen together.** The onboarding doc and the
  caller templates must agree on `reviewer:` ↔ the engine secret; the default combo must be
  a documented, CI-verified working pair.
- **D6 — external adopters use the EXISTING override, NOT a changed default.** (REVISED in
  rev 2.) `trust_config_repo`/`trust_config_ref` already ship (PLAN-004 D1) with the
  operations default and an external-adopter override already documented in the input
  description. Do **NOT** change the default to `${{ github.repository }}`: (i) it also
  applies to the enforcer (`auto-merge-ai-prs.yml:50`), removing operations as the
  auto-merge kill-switch (each repo would self-authorize from its own `repo@main`); (ii) it
  functionally BREAKS the enforcer — the installed `config.json.template` has no
  `auto_merge.repos` key (`:17` has `auto_merge` but no `repos`), so a self-referenced
  config fails the enforcer's schema check (`auto-merge-ai-prs.yml:195-199`) and disables
  it fail-closed; (iii) it contradicts the two-canonical-repo trust model (REPO_STANDARDS
  §0/§17). PR-E's valid remainder is surfacing the existing override in the onboarding doc
  + the public-path verification/EXPERIMENTAL disposition.
- **D7 — governance-config knobs are inert; either wire them or annotate.** (NEW in rev 2.)
  No workflow reads `governance.locked_paths`, `governance.require_human_review`,
  `governance.code_owners`, `auto_merge.spec_paths_blocked`, `auto_merge.enabled`,
  `composition.required`, or `composition.carry_forward_on_skip_label` — the gov globs are
  hardcoded in the workflows. A consumer who adds `spec/`/`infra/` to
  `governance.locked_paths` expecting human-merge protection gets ZERO. At company-default
  elevation this is a real governance gap. Decide per-field: wire it, or annotate it
  non-authoritative in `config.json.template` + REPO_STANDARDS. (PR-F.)
- **D8 — the fixes must reach the ~9 already-adopted consumers.** (NEW in rev 2.) Canon
  changes only take effect when a consumer re-pins its callers. The propagation path is
  `install.sh --update` (SHIPPED, PLAN-004 PR-E). Each substantive PR states its target
  `ci/vX.Y.Z`; a coordinated `--update` sweep + pin bump lands them on consumers (see
  §Release & propagation).

## Sequencing & finding disposition

| PR | Closes (review id) | Depends on | PLAN-004 relation |
|----|--------------------|-----------|-------------------|
| ~~PR-B~~ **SHIPPED** | ~~B2 (caller-permissions startup_failure)~~ | — | shipped as `ci/v1.7.1` (#106) |
| PR-A | **B1** (F1/F2 auth bypass) + D2 | — | extends the shipped BL-3 gate (#98) |
| PR-C | **B3** (guard only — break resolved) | — | preventive; VERSION single-source (BL-4, shipped) |
| PR-D | HIGH: reviewer-engine token mismatch | v1.7.1 baseline | — |
| PR-E | HIGH: onboarding override + public-path disposition | PR-D | uses shipped D1 inputs; NO default change |
| PR-F | MED: bootstrap+auto-merge guard; trust-policy decision log; **D7 gov-knobs** | — | — |
| PR-G | MED: cold-start doc gaps; `composition ?ref=main` (FT-6) | PR-A | overlaps FT-6 |

**Corrected PLAN-004 cross-references** (all were stale — PLAN-004 shipped):

- BL-3 (composition-armed auto-merge gate): **SHIPPED** (`#98`). PR-A *extends* it (adds the
  enforcer gov floor + reworks the skip carry-forward), not "deepens an INERT gate."
- BL-4 (VERSION single-source + cold-start docs): **SHIPPED**
  (`REVIEWER_APP_ONBOARDING.md`, `BRANCH_PROTECTION.md`, `VERSION`, `sync-version-refs.sh`
  all exist). PR-C adds only the tag-existence guard.
- BL-5 (install-upgrade path): **SHIPPED** as `install.sh --update [--non-interactive]`
  (`install/install.sh`). This is the propagation path (D8), not a deferral target.
- FT-6 (`composition ?ref=main` vs `trust_config_repo`): **OPEN** (`composition.yml:156`).
  PR-G Step 2 remains valid.
- create-github-app-token SHA↔tag pin: **SHIPPED** (PLAN-004 PR-C SHA-pinned it) — drop
  from this plan.

## Decision record → task mapping

---

### Task PR-A: Enforcer governance floor + HEAD-relative carry-forward (B1 + D2)

**Files:**
- Modify: `.github/workflows/auto-merge-ai-prs.yml` (add a `GOV_LOCKED` floor before the
  re-arm; gate the `skip-ai-review` branch on it; rework the carry-forward approval check
  per D2; KEEP + correct the residual note)
- Modify: `.github/workflows/composition.yml` (evaluate the gov floor before the
  `skip-ai-review` carry-forward exit; add the D2 HEAD-relative check to the carry-forward)

**Interfaces:**
- Consumes: the reviewer-App identity (`vars.APP_REVIEWER_1_BOT_ID`) + reviews API already
  used at `auto-merge-ai-prs.yml:315`.
- Produces: "a gov-locked PR is never auto-merged under any label combination, and
  `skip-ai-review` never carries a *stale* approval past new code."

- [ ] **Step 1 — reproduce both gaps (red).** On a scratch PR touching `.github/workflows/**`,
  hand-apply `ai:review-passed` + `skip-ai-review` and confirm the enforcer reaches the
  re-arm (`:359`) with the `skip-ai-review` branch (`:302-303`) skipping the App-at-HEAD
  check and NO `GOV_LOCKED` check firing (grep-confirm the enforcer has no gov floor).
  Separately, confirm the "approve-benign-then-push" gap: an approved HEAD1 + pushed HEAD2 +
  `skip-ai-review` carries forward today. Observe audit logs only; do not let it merge.
- [ ] **Step 2 — add a `GOV_LOCKED` floor to `auto-merge-ai-prs.yml`**, reusing the exact
  glob + fail-closed logic from `ai-review.yml:462` (retry the changed-file list, require
  it provably complete else LOCK, `grep -qE '(^|/)governance/|(^|/)\.github/|(^|/)templates/ai-review/'`,
  and `case "$GH_REPO" in */aidoc-flow-framework) LOCKED=true;; esac`). Place it BEFORE the
  `skip-ai-review` branch (`:302`).
- [ ] **Step 3 — refuse the re-arm when locked, unconditionally.** If `GOV_LOCKED=true`:
  `audit "governance-locked → human-merge only; refusing to re-arm"; exit 0` — reached even
  under `skip-ai-review`.
- [ ] **Step 4 — HEAD-relative carry-forward (D2), not "ever approved."** In the
  `skip-ai-review` branch, honor the skip ONLY when an App-APPROVED review's `commit_id` is
  an ancestor of HEAD AND the diff from that commit to HEAD touches no review-material path
  (reuse the gov glob + the broader review scope). This admits the legit rebase/lint/§15
  case (no new code since approval) and refuses the approve-then-inject case. If neither
  holds, `audit`+`exit 0` (refuse). Add an explicit §15 exemption branch if the recovery
  runbook needs a no-approval path.
- [ ] **Step 5 — mirror in `composition.yml`.** Move the gov-floor block (`:179`) to run
  BEFORE the carry-forward exit (`:122`), AND add the D2 HEAD-relative check to the
  carry-forward. NOTE: composition's floor exit and carry-forward exit are both PASS, so the
  *reorder alone* does not change composition's verdict — the real enforcement is the
  enforcer's floor (Step 2/3) + the D2 check here. State this in the PR body; do not present
  the reorder as independent enforcement.
- [ ] **Step 6 — KEEP + correct the residual note** (`auto-merge-ai-prs.yml:331-332`). Do
  NOT delete it. Update it to state precisely what remains after this PR (e.g. the TOCTOU
  window) and REMOVE the false "make composition a required check = complete fix" framing
  (with D2, a required composition still passes a stale approval unless the HEAD-relative
  check is in place).
- [ ] **Step 7 — verify (green).** Re-run Step 1: the gov-locked double-label PR hits
  "refusing to re-arm"; an approved-then-pushed PR under `skip-ai-review` is now REFUSED; a
  routine rebase/§15-recovered PR still carries forward. **Add a smoke test asserting a §15
  label-cycle-recovered PR (which may hold no APPROVED review) still merges** — the exact
  regression D2 must not cause.
- [ ] **Step 8 — OPS-0065 self-review (security-lens agent on the diff), commit, push, PR.**
  `fix(security): PLAN-005 PR-A — enforcer gov floor + HEAD-relative skip carry-forward`.

### Task PR-B: `ai-review` caller `permissions:` block — ✅ SHIPPED (ci/v1.7.1, PR #106)

Delivered 2026-07-10. Added the top-level `permissions:` block
(contents/pull-requests/issues: write) to `ai-review-{public,private}.yml`; gave the
private variant the secrets/`pull_request_target` header; `actions-permissions.json`
untouched. Security-verified diff-only-safe. Consumers propagate via `@ci/v1.7.1` re-pin /
`install.sh --update`. No further work.

### Task PR-C: Tag-existence guard (preventive — B3 break already resolved)

**Files:**
- Modify: `scripts/sync-version-refs.sh` (add a REMOTE tag-existence assertion to `--check`)

**Interfaces:**
- Produces: a shipped template pin always resolves to a *published* tag.

- [ ] **Step 1 — (context, not a red repro).** B3's immediate break is RESOLVED:
  `ci/v1.7.0` and `ci/v1.7.1` are published tags + releases; `VERSION` = `ci/v1.7.1`
  matches. This PR is preventive only. Do NOT revert `VERSION` (the old option (b) is now
  wrong).
- [ ] **Step 2 — add the guard, using the correct variable + remote check.** In
  `sync-version-refs.sh --check`, after `TAG` is read + validated (`:55-59`, NOT `:28`
  which is only a path assignment), assert the tag exists **on the remote** (consumers
  resolve from GitHub): `git ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1`.
  A local-only (unpushed) tag must NOT satisfy the guard.
- [ ] **Step 3 — exempt the in-flight release-bump commit (avoid the deadlock).** The next
  release bumps `VERSION` to `ci/vX.Y.Z` BEFORE that tag exists (the tag is cut from the
  bump commit). Handle this: run the remote-tag assertion in CI only (not the pre-commit
  `--check`), OR add a documented `--allow-unpublished` escape for the bump commit, OR gate
  on a marker. Document the chosen release procedure so the guard can't block the very
  commit that precedes the tag.
- [ ] **Step 4 — verify.** With a fabricated `VERSION=ci/v9.9.9` (unpublished),
  `--check` (CI mode) FAILS; with a published `VERSION`, PASSES; a local-only tag still
  FAILS.
- [ ] **Step 5 — OPS-0065 self-review, commit, push, PR.** `fix(release): PLAN-005 PR-C —
  remote tag-existence guard in sync-version-refs (preventive)`.

### Task PR-D: Reviewer-engine ↔ token reconciliation (HIGH — real, still present)

**Files:**
- Modify: `docs/REVIEWER_APP_ONBOARDING.md` (engine-token step)
- Modify: `install/templates/workflows/ai-review-public.yml` + `ai-review-private.yml`
  (header note tying `reviewer:` to its key; only if the chosen default changes)

**Interfaces:**
- Produces: an adopter cannot arm a reviewer engine whose key they didn't set.

- [ ] **Step 1 — the mismatch (verified present).** Onboarding lists/sets
  `CLAUDE_CODE_OAUTH_TOKEN` as "preferred", but both callers pin `reviewer: codex`, which
  needs `OPENAI_API_KEY`. An adopter following the doc arms codex with a Claude token →
  reviewer can't authenticate.
- [ ] **Step 2 — pick one coherent default and make everything agree.** Decide the shipped
  `reviewer:` default (recommend `claude` to match the doc's preferred token, OR keep
  `codex` and change the doc to set `OPENAI_API_KEY`). Update BOTH caller templates + the
  onboarding doc to the chosen pair; add: "the `reviewer:` input MUST match the engine
  secret (`claude`→`CLAUDE_CODE_OAUTH_TOKEN`/`ANTHROPIC_API_KEY`; `codex`→`OPENAI_API_KEY`)."
- [ ] **Step 3 — verify.** The `reviewer:` value in both templates, the onboarding secret,
  and the reusable's engine-auth step (`ai-review.yml:474`) name one consistent engine.
- [ ] **Step 4 — OPS-0065 self-review, commit, push, PR.** `fix(docs+ci): PLAN-005 PR-D —
  reconcile reviewer engine with its auth token`.

### Task PR-E: External-adopter onboarding + public-path disposition (HIGH — reduced)

**Files:**
- Modify: `docs/REVIEWER_APP_ONBOARDING.md` (surface the EXISTING `trust_config_repo`
  override for external adopters — no default change)
- Modify: `install/templates/workflows/ai-review-public.yml` (public-runner reviewer path
  caveat)

**Interfaces:**
- Produces: a documented, working external-adopter path — without decentralizing trust.

- [ ] **Step 1 — the real gap (post-D6).** The `trust_config_repo` override already exists
  and is described in the input; external adopters just aren't told to use it in the
  onboarding doc, and the public reviewer-install path is unverified-in-CI. Do NOT change
  the default (see D6 — it breaks the enforcer schema + the trust model).
- [ ] **Step 2 — document the override.** In the onboarding doc, add an "external adopters"
  note: set `trust_config_repo: your-org/your-ops-repo` (holding `.github/ai-review/config.json`
  with BOTH `.trust.ai_review` AND `.auto_merge.repos`) on the ai-review AND auto-merge
  callers. Call out that `config.json.template` ships WITHOUT `auto_merge.repos`, so an
  adopter enabling the enforcer must add that key (ties to D7).
- [ ] **Step 3 — public reviewer path disposition.** Either run the default public combo
  (`reviewer:` from PR-D + `ubuntu-latest` + the matching key) green in a real public test
  repo and drop the "unverified-in-CI" caveat, OR keep the caveat + mark the public path
  EXPERIMENTAL in the onboarding doc. Also verify no secret-bearing step precedes the trust
  gate on the public `pull_request_target` path before de-experimentalizing. Record which.
- [ ] **Step 4 — verify.** A fresh consumer that sets the override + ships a config with
  `auto_merge.repos` → both ai-review AND the enforcer resolve; a consumer that does NOT set
  it stays on the operations default (unchanged behavior).
- [ ] **Step 5 — OPS-0065 self-review, commit, push, PR.** `docs(ci): PLAN-005 PR-E —
  external-adopter trust override + public reviewer path disposition`.

### Task PR-F: Bootstrap/auto-merge guard + trust-policy log + governance-knobs (MED + D7)

**Files:**
- Modify: `install/apply-standards.sh` (guard)
- Modify: `DECISIONS.md` (CI-NNNN for the trust boundary)
- Modify: `install/templates/config.json.template` + `docs/REPO_STANDARDS.md` (D7:
  wire-or-annotate the inert governance knobs)

- [ ] **Step 1 — bootstrap guard.** `branch-protection-bootstrap.json` requires only
  `Lint / format / security hooks` (`:7`) — no ai-review/composition. Add a check in
  `apply-standards.sh` that refuses to install the `auto-merge-ai-prs` caller on a repo
  whose required checks lack `call / composition`, so a bootstrap-profile repo can't get
  auto-merge without a review gate. Document bootstrap as a pre-activation profile that MUST
  NOT coexist with auto-merge.
- [ ] **Step 2 — decision log.** Add `CI-NNNN` (or extend CI-0004) recording the
  trust-boundary policy (operations `auto_merge.repos` allowlist; reviewer-App approval
  identity; `skip-ai-review` semantics hardened by PR-A/D2; the enforcer gov floor
  D1). Reconcile the two allowlist sources: ai-review's `in_automerge()` reads the
  consumer-local config while the enforcer reads `trust_config_repo` (operations) — and the
  template lacks `auto_merge.repos` (FT-6 territory).
- [ ] **Step 3 — D7 governance knobs.** For each inert field
  (`governance.locked_paths`/`require_human_review`/`code_owners`,
  `auto_merge.spec_paths_blocked`/`enabled`, `composition.required`/`carry_forward_on_skip_label`):
  decide wire vs annotate. Minimum: annotate them non-authoritative in
  `config.json.template` (a `_note`) + REPO_STANDARDS so a consumer doesn't rely on
  phantom protection. Preferred for the highest-value one (`locked_paths` /
  `spec_paths_blocked`): wire it into the gov-floor glob computation.
- [ ] **Step 4 — verify + OPS-0065 self-review, commit, push, PR.** `fix(governance):
  PLAN-005 PR-F — bootstrap/auto-merge guard + trust log + governance-knob disposition`.

### Task PR-G: Cold-start docs + `composition ?ref=main` (MED)

**Files:**
- Modify: `docs/REVIEWER_APP_ONBOARDING.md` (repo-settings prerequisites — LAYER onto, do
  not duplicate, PLAN-004's version; PR-D also edits this file → coordinate)
- Modify: `.github/workflows/composition.yml` (parameterize the config ref)

- [ ] **Step 1 — repo-settings prerequisites in the onboarding checklist.** Pull the two
  `startup_failure` prerequisites (the caller `permissions:` block — now shipped in v1.7.1;
  the Actions-allowlist/`default_workflow_permissions` context) into the onboarding doc
  BEFORE its first-PR step, cross-linking `troubleshooting §13/§14` and warning against
  arming `call / ai-review` as required before the workflow can pass (install-order
  deadlock).
- [ ] **Step 2 — non-`main` default branch (FT-6).** `composition.yml:156` hardcodes
  `?ref=main`; read the config from the repo's actual default branch (`gh api
  repos/$GH_REPO --jq .default_branch`, or an input) so a `master`/`develop` consumer isn't
  hard-blocked. Cross-reference FRAMEWORK-TODO FT-6.
- [ ] **Step 3 — verify + OPS-0065 self-review, commit, push, PR.** `docs+fix(ci):
  PLAN-005 PR-G — cold-start prerequisites + default-branch-agnostic composition config`.

---

## Release & propagation (D8)

- **PR-A** is a security fix to reusables → **PATCH/MINOR `ci/v1.7.2` or `v1.8.0`** (no
  consumer-caller change, so a re-pin is optional for consumers but recommended).
- **PR-C/PR-D/PR-E/PR-F/PR-G** — bundle into the same cut where sensible. IF PR-D takes the
  branch that changes the `reviewer:` default in the caller templates (vs the docs-only
  branch that keeps `codex`), consumers must re-pin to pick it up.
- **Propagation to the ~9 adopted consumers is REQUIRED, not optional cadence** for the
  v1.7.1 caller fix (their ai-review is inert until re-pinned) — and for PR-D IF it changed
  the caller reviewer default. Use the shipped `install.sh --update` (interactive per-file
  diff, or
  `--non-interactive` which auto-replaces the workflow callers) + a caller pin bump. Track
  the sweep as a checklist in HANDOFF; verify on interlog first.
- **Rollback:** consumers can revert to their prior `@ci/vX.Y.Z` pin if a template change
  reddens their CI; canon PRs are revert-safe (each reusable change is independent).
- **Verification breadth:** verify on interlog (`main` default) AND ≥1 consumer with a
  non-`main` default branch (to actually exercise PR-G Step 2), not interlog alone.

## Claim ledger

Cite paths relative to this repo (`/opt/data/aidoc-flow/aidoc-flow-ci`). Line numbers are
advisory (symbol is authoritative); re-run `check_plan.py --fix` before execution to
re-point any drift.

| # | Claim | Symbol | Citation |
|---|-------|--------|----------|
| 1 | The reusable ai-review declares workflow-level write permissions | `contents: write        # auto-merge` | .github/workflows/ai-review.yml:76 |
| 2 | The canon sets the repo default token permission to read | `"default_workflow_permissions": "read"` | install/templates/actions-permissions.json:28 |
| 3 | The ai-review caller now ships a top-level permissions block (v1.7.1, D3 DONE) | `permissions:` | install/templates/workflows/ai-review-public.yml:37 |
| 4 | The reviewer input is pinned to codex in the public caller (PR-D mismatch) | `reviewer: codex` | install/templates/workflows/ai-review-public.yml:45 |
| 5 | The reviewer input is pinned to codex in the private caller | `reviewer: codex` | install/templates/workflows/ai-review-private.yml:36 |
| 6 | The public caller header maps OPENAI_API_KEY to reviewer codex | `OPENAI_API_KEY                           if reviewer: codex` | install/templates/workflows/ai-review-public.yml:11 |
| 7 | The ai-review floor step is itself gated off under skip-ai-review (D1 premise) | `if: env.SKIP_REVIEW` | .github/workflows/ai-review.yml:205 |
| 8 | The ai-review gate has a fail-closed governance floor locking .github/** etc. | `grep -qE '(^|/)governance/|(^|/)\.github/|(^|/)templates/ai-review/'` | .github/workflows/ai-review.yml:462 |
| 9 | The enforcer's skip-ai-review branch runs with no preceding GOV_LOCKED floor (D1 gap) | `index("skip-ai-review")` | .github/workflows/auto-merge-ai-prs.yml:302 |
| 10 | composition carries forward (exit-passes) on the skip-ai-review label | `composition carried forward` | .github/workflows/composition.yml:122 |
| 11 | composition's governance floor is AFTER the skip carry-forward exit | `GOVERNANCE FLOOR (same globs as the ai-review gate)` | .github/workflows/composition.yml:179 |
| 12 | composition reads the consumer config hardcoded at ?ref=main (FT-6) | `config.json?ref=main` | .github/workflows/composition.yml:156 |
| 13 | The enforcer skips the App-at-HEAD check under skip-ai-review (BL-3 insufficient) | `App-at-HEAD check skipped` | .github/workflows/auto-merge-ai-prs.yml:303 |
| 14 | The enforcer's residual note admits the double-label variant (KEEP + correct, not delete) | `the double-label variant` | .github/workflows/auto-merge-ai-prs.yml:332 |
| 15 | The enforcer re-arms native auto-merge | `retry gh pr merge "$PR" --auto --merge` | .github/workflows/auto-merge-ai-prs.yml:359 |
| 16 | The enforcer schema-validates auto_merge.repos as an array, fail-closed | `(.auto_merge.repos \| type == "array")` | .github/workflows/auto-merge-ai-prs.yml:195 |
| 17 | The enforcer disables fail-closed on schema-invalid config (PR-E break basis) | `config schema invalid — fail-closed` | .github/workflows/auto-merge-ai-prs.yml:199 |
| 18 | The enforcer default trust_config_repo (D6: do NOT flip) | `must match ai-review.yml` | .github/workflows/auto-merge-ai-prs.yml:50 |
| 19 | ai-review defaults trust_config_repo to the private operations repo | `default: 'vladm3105/aidoc-flow-operations'` | .github/workflows/ai-review.yml:69 |
| 20 | The installed config.json template's auto_merge block has NO repos key (PR-E enforcer break) | `"auto_merge": {` | install/templates/config.json.template:17 |
| 21 | The onboarding doc lists CLAUDE_CODE_OAUTH_TOKEN as preferred (PR-D mismatch) | `CLAUDE_CODE_OAUTH_TOKEN` | docs/REVIEWER_APP_ONBOARDING.md:26 |
| 22 | The reusable authenticates the reviewer engine from the vendor key exported to the CLI | `Export consumer-provided auth secrets to the CLI` | .github/workflows/ai-review.yml:474 |
| 23 | §15 label-cycle recovery is a documented path (D2 must not break it) | `Label-cycle retrigger` | docs/troubleshooting.md:31 |
| 24 | VERSION points at the current published tag ci/v1.7.1 (B3 resolved) | `ci/v1.7.1` | VERSION:1 |
| 25 | sync-version-refs reads the tag into $TAG (PR-C: use $TAG not $VERSION) | `TAG="$(tr -d '[:space:]' < "$VERSION_FILE")"` | scripts/sync-version-refs.sh:59 |
| 26 | The bootstrap branch-protection profile requires only the lint check (no review gate) | `Lint / format / security hooks` | install/templates/branch-protection-bootstrap.json:7 |
| 27 | install.sh --update is the shipped propagation path (D8; BL-5 SHIPPED) | `MODE_UPDATE` | install/install.sh:56 |
| 28 | config.json.template governance knobs exist but are read by no workflow (D7) | `"locked_paths"` | install/templates/config.json.template:9 |

## Review log

### Pass 1 - 2026-07-09 - author self-check

Plan assembled from the 2026-07-09 five-lens pre-prod review. Every ledger citation opened
and read; each BLOCKER/HIGH/MED mapped to a PR; LOW/overlap items deferred, not dropped.

### Pass 2 - 2026-07-09 - independent (fresh-context Agent)

Verified all citations against the workflow source and stress-tested the three headline
mechanisms; folded citation + sequencing findings. Result at the time: ready. (Superseded
by Pass 3 — Pass 2 validated the review-trust read for PR-E but NOT the enforcer's
`auto_merge.repos` schema, which Pass 3 found PR-E's default-flip would break.)

### Pass 3 - 2026-07-10 - independent three-agent from-scratch review + re-baseline

Three fresh-context agents (security / correctness / architecture) reviewed the DRAFT
against shipped source after `ci/v1.7.0`+`v1.7.1` cut. Disposition folded into this rev 2:

- **PR-B SHIPPED** as `ci/v1.7.1` (#106) — B2 confirmed real + fixed; removed from remaining work.
- **D2 REDESIGNED** — "≥1 App-APPROVED ever" is both a live bypass (approve-benign-then-push;
  stale App approvals persist) AND a break of the §15 no-approval recovery path (PLAN-004
  §4.2 deliberate residual). Now HEAD-relative + diff-scoped + §15 exemption + a mandatory
  §15 regression smoke test; the residual note is KEPT + corrected (old Step 6 deleted it).
- **PR-E REVERSED** — the `trust_config_repo`→self default flip (a) also hit the enforcer
  (`:50`), removing operations as the auto-merge kill-switch; (b) functionally broke the
  enforcer (template has no `auto_merge.repos` → schema fail-closed, `:195-199`); (c)
  contradicted the two-canonical-repo model. Reduced to documenting the existing override +
  public-path disposition.
- **PR-C COLLAPSED to preventive** — B3's break resolved (tag cut); fixed the guard bugs
  (`$VERSION`→`$TAG`; `:28` is a path not a read; check REMOTE not local; exempt the
  release-bump commit to avoid the deadlock).
- **Stale cross-refs corrected** — BL-3/BL-4/BL-5 all SHIPPED; BL-5 (install.sh --update) is
  now the propagation path, not a deferral target; row 24 (was "unpublished tag") re-based.
- **Added D7** (inert governance knobs — read by no workflow; real gap at company-default)
  and **D8 + §Release** (versioning + the required `install.sh --update` sweep to the ~9
  consumers whose ai-review is inert until re-pinned; rollback; non-`main`-branch verify).
- **Confirmed CORRECT (unchanged):** D1 core (enforcer genuinely lacks a gov floor),
  PR-D reviewer-engine mismatch (real, present), the sequencing file-overlaps on the caller
  templates (PR-D/PR-E on `ai-review-public.yml`; PR-G-after-PR-A on `composition.yml`), the
  least-privilege + diff-only invariants (now global constraints). (The rev-1 PR-A∩PR-E
  overlap on `auto-merge-ai-prs.yml` no longer exists — the D6 reversal removed PR-E's edit
  to that file.)

**Result:** ready for execution after this re-baseline. (Note: the `verified-planning` gate
`check_plan.py` is not wired into this repo — no `.claude/skills/`; run it from the global
copy, and consider adding the hook here as an exit-criterion improvement.)
