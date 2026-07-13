# PLAN-008 — Pre-production review gap closure (ci/v2.0.0)

**Owner:** `aidoc-flow-ci` maintainer
**Origin:** 2026-07-13 five-lens pre-prod review (security / correctness / docs /
portability / governance) of `aidoc-flow-ci` ahead of the `ci/v2.0.0` tag cut.
The LiteLLM unification implementation is complete; the 5-lens review returned
SHIP-WITH-FIXES with 29 findings (7 BLOCKER, 10 HIGH, 8 MEDIUM, 4 LOW).
**Status:** DRAFT — 2026-07-13 EST
**Depends on:** `feat/unified-litellm-agents` merged to main (PR #154).
**Exit:** All 29 findings closed across 5 governance/correction PRs +
LiteLLM smoke pass → `ci/v2.0.0` tag cut.

## Summary

The 5-lens pre-prod review found no systemic design flaws. Failures are
documentation staleness (PLAN statuses, ROADMAP phase, stale doc pins),
missing migration/release collateral (no MIGRATION_v2.0.0, no
RELEASE_CHECKLIST), and a handful of code-level corrections. Grouped into
5 PR batches below plus one founder-gated release step.

---

## PR #1 — Governance staleness

Close 2 BLOCKERs + 2 HIGH findings. Files: ROADMAP.md, PLAN-004, PLAN-005,
HANDOFF.md, FRAMEWORK-TODO.md.

### Changes

1. **ROADMAP.md:11** — Set "Current phase" to `ci/v2.0.0` LiteLLM unification +
   production hardening. Move "Recently landed" PLAN-002/003 items to git history.
   Remove shipped items from "Next phase."

2. **ROADMAP.md:59-60** — Remove "Umbrella backlog — auto-merge-ai-prs.yml
   server-side enforcer" from "Next phase" (shipped ci/v1.5.0, 2026-06-30).
   Replace with: W4 fleet arming, doc-maintainer supersession from HANDOFF
   open threads.

3. **plans/PLAN-004_company-default-elevation.md:10** — Status: DRAFT →
   `SHIPPED — 2026-07-10 (ci/v1.7.0)`. Add one-line execution-summary
   annotation in §Execution log confirming all A–E slices merged.

4. **plans/PLAN-005_ai-review-pipeline-hardening.md:5** — Status: DRAFT (rev 2)
   → `SHIPPED — 2026-07-10 (ci/v1.7.1 → v1.8.1)`. Add execution-summary
   annotation confirming 7/7 PRs complete.

5. **HANDOFF.md:274-289** — "Recent decisions" add CI-0005 (trust boundary,
   2026-07-10) and CI-0006 (LiteLLM unification, 2026-07-12). Keep CI-0001
   through CI-0004 (2026-07-08, ~5 days old — within the 4-week retention
   window). Only CI-0004 was listed; CI-0001/2/3 are recapped for completeness.

6. **plans/FRAMEWORK-TODO.md:54-67** — FT-3: mark RESOLVED (2026-07-12).
   The `labels.json` skip-ai-review description now reads "Operator override:
   suppress re-review and carry forward a valid prior approval" — verified at
   `install/templates/labels.json:20`. Remove fix sketch or annotate with
   resolution date.

---

## PR #2 — Documentation corrections

Close 3 BLOCKERs + 3 HIGH + 1 MEDIUM findings. Files: BRANCH_PROTECTION.md,
REPO_STANDARDS.md, security.md, README.md, architecture.md, overrides.md,
install/README.md.

### Changes

1. **docs/BRANCH_PROTECTION.md:19** — Add `call /` prefix: `Lint / format /
   security hooks` → `call / Lint / format / security hooks`. The doc's own
   intro (line 11-12) explains the `call / <job-name>` convention; line 19
   violates it. `REPO_STANDARDS.md:84` and `tests/test_checknames.sh` confirm
   the correct emitted name.

2. **docs/BRANCH_PROTECTION.md:36-38,40** — Tier tables: add `call /` prefix
   to all `Lint / format / security hooks` entries. Keep `Secret scan
   (gitleaks)` as-is (some repos use standalone gitleaks, not the reusable;
   `REPO_STANDARDS.md:122-123` documents this distinction).

3. **docs/REPO_STANDARDS.md:590** — "11 reusables" → "12 reusables."
   `audit-trail-check.yml` was added in PLAN-002 PR-U3.

4. **docs/REPO_STANDARDS.md:945** — `@ci/v1.5.1` → `@ci/v2.0.0`. The actual
   `auto-merge-ai-prs-{public,private}.yml` templates pin at `@ci/v2.0.0`.

5. **docs/REPO_STANDARDS.md:959-961** — Replace "Bootstrap-tier repos without
   CI adoption (interlog as of 2026-07-08)" with a note that interlog is
   now ops-private tier (fully CI-adopted per `WORKFLOWS.md:63`).

6. **docs/security.md:227-228,252,260-268** — Replace all `gacts/gitleaks`
   references with the direct-binary pattern. The `gacts/gitleaks` wrapper
   was removed in `ci/v1.9.2` (`secret-scan.yml` now installs the gitleaks
   binary directly + SHA-256 verify). Update line 227 example, line 252 table
   row, and the "Why gacts/gitleaks" §260-268 section to describe the binary-
   install model.

7. **docs/README.md:36-37** — Replace "a per-release migration guide will be
   added if/when a MAJOR (ci/v2.0.0) ships with breaking changes" with:
   `docs/MIGRATION_v2.0.0.md` covers migration from `ci/v1.x` to `ci/v2.0.0`.
   Link to the migration guide.

8. **docs/architecture.md:184** — Example pin `@ci/v1.0.0` → `@ci/v2.0.0`.

9. **docs/overrides.md:53,66,76** — Example pins `@ci/v1.0.0` → `@ci/v2.0.0`
   in all three Mode 1 examples.

10. **install/README.md:140-143** — "After install" table: add a third row for
    LiteLLM secrets (`LITELLM_BASE_URL`, `LITELLM_REVIEW_API_KEY`,
    `LITELLM_DOC_API_KEY`) with a note "required for ci/v2.0.0." Cross-
    reference `REVIEWER_APP_ONBOARDING.md` and the migration guide.

---

## PR #3 — Migration + release docs (NEW files + existing edits)

Close 1 HIGH + 2 HIGH from other lenses. Creates `docs/MIGRATION_v2.0.0.md`
and `docs/RELEASE_CHECKLIST.md`. Edits `CHANGELOG.md`, `docs/UPDATE_GUIDE.md`,
`docs/README.md`.

### Changes

1. **docs/MIGRATION_v2.0.0.md** (NEW) — Consumer migration guide from
   `ci/v1.x` to `ci/v2.0.0`. Sections:
   - *Secrets required:* `LITELLM_BASE_URL`, `LITELLM_REVIEW_API_KEY`,
     `LITELLM_DOC_API_KEY`
   - *Secrets removed:* old vendor CLI credentials (`OPENAI_API_KEY`,
     `CLAUDE_CODE_OAUTH_TOKEN`, `GITHUB_TOKEN_CLASSIC` for reviewer CLI)
   - *Inputs removed:* `reviewer:` input (replaced by `litellm.model` in
     `.github/ai-review/config.json`)
   - *Config change:* add `"litellm": {"model": "ai-reviewer"}` to consumer's
     `.github/ai-review/config.json`
   - *Caller template update:* run `install.sh --repin ci/v2.0.0` on each
     consumer
   - *Smoke test:* configure both LiteLLM aliases, run `litellm-smoke.yml`

2. **docs/UPDATE_GUIDE.md** — Add `## ci/v1.x → ci/v2.0.0 breaking-change
   migration` section referencing `MIGRATION_v2.0.0.md` with a checklist:
   repin, add LiteLLM secrets, drop vendor CLI secrets, verify.

3. **CHANGELOG.md:1-6** — Add `## Unreleased — targeting ci/v2.0.0` as the
   first H2 header. Nest all unreleased entries (`### Added — canonical
   branching standard`, `### Changed — unified LiteLLM gateway`, etc.) under
   it. Add `### Migration from ci/v1.x` subsection with: new required secrets,
   removed inputs, `install.sh --repin` command.

4. **docs/RELEASE_CHECKLIST.md** (NEW) — One-page checklist for cutting a
   release tag:
   - Schema validation (`python3 -m json.tool` on schema files)
   - `tests/run.sh` passes (147 assertions)
   - `sync-version-refs.sh` clean
   - OPS-0065 review complete (≤3 cycles)
   - LiteLLM smoke pass (both aliases)
   - Migration guide published for MAJOR bumps
   - VERSION bumped and matches tag
   - `install.sh` default `CI_TAG_FALLBACK` matches tag
   - GitHub Release cut with CHANGELOG excerpt
   - `install.sh --repin` test on one consumer

5. **docs/README.md** — Add `MIGRATION_v2.0.0.md` and `RELEASE_CHECKLIST.md`
   to "Available now" table. Drop the "if/when a MAJOR" hypothetical
   (already addressed in PR #2 change #7 above — this PR adds the actual
   docs).

---

## PR #4 — Code + config corrections

Close 1 BLOCKER + 2 MEDIUM + 2 LOW + 1 HIGH findings. Files: audit-trail-check.yml,
docs-sync.yml, auto-merge-ai-prs.yml, codeql.yml, links.yml, manifest.json,
ROADMAP.md.template.

### Changes

1. **.github/workflows/audit-trail-check.yml:74** — Remove
   `|| github.event_name == 'pull_request_target'` from the job-level `if:`.
   No shipped caller template uses `pull_request_target` for audit-trail;
   the reusable must not accept it. The `actions/checkout ref: ${{ github
   .event.pull_request.head.sha }}` (line 85) under `pull_request_target`
   would checkout fork code on a privileged runner.

2. **.github/workflows/docs-sync.yml:64** — Concurrency group `docs-sync`
   → `docs-sync-${{ github.ref }}`. Prevents global serialization across
   refs (today's push-to-main-only scope makes this effectively cosmetic,
   but a future `workflow_dispatch` on an arbitrary ref would queue behind
   the push run).

3. **.github/workflows/auto-merge-ai-prs.yml:193-196** — Add
   `and (.trust.auto_fix | type == "array")` to the config schema validation.
   The `trust.auto_fix` list is used by `ai-review.yml`'s trust gate but
   its type is not validated here.

4. **.github/workflows/codeql.yml:111** — Replace `eval "$BUILD_COMMAND"`
   with `bash -c "$BUILD_COMMAND"`. Removes the double-evaluation layer
   while preserving the ability to run multi-command build steps. `bash -c`
   launches a subprocess (unlike `eval` which runs in the calling shell); no
   consumer build-command depends on in-process eval semantics (the step's only
   purpose is build-command execution).

5. **.github/workflows/links.yml:131-136** — Remove the dead `set -e` after
   `exit "${rc}"`. The `set -e` on line 136 is evaluated dead (control has
   already transferred to exit handler). Harmless but misleading.

6. **install/templates/manifest.json** — Add entries for:
   - `.markdownlint.json`: template `.markdownlint.json`, `auto_install: false`,
     `safe_to_replace: false`
   - `.lychee.toml`: template `.lychee.toml`, `auto_install: false`,
     `safe_to_replace: false`
   - `.github/docs-sync.json`: template `docs-sync.json`, `auto_install: false`,
     `safe_to_replace: false`
   All three templates exist on disk at `install/templates/` and are installed
   by `deploy-ci-wizard.sh` / referenced by consumers. Without manifest entries,
   `--update` can't refresh them. `repo-settings.json` is intentionally excluded
   — it is an internal template for `apply-standards.sh`'s `gh api PATCH`, never
   written to consumer repos as a file.

7. **install/templates/ROADMAP.md.template** — Add a 3-line "OPS compliance"
   footer below the maintenance protocol, mirroring `CLAUDE.md.template`:
   - OPS-0065 multi-agent self-review
   - OPS-0069 audit-trail phrase requirement
   - OPS-0066 3-cycle review cap
   OPS-0067 (aidoc-flow-standard scope) intentionally omitted — agent dispatch
   scope rules are irrelevant to roadmap maintenance.

---

## PR #5 — Portability hardening

Close 3 HIGH findings. Files: check-pin-currency.sh, ai-review.yml,
doc-maintainer.yml, docs-sync.yml.

### Changes

1. **sync/check-pin-currency.sh:65,69** — Replace hardcoded `?ref=main`
   with dynamic default-branch resolution:
   ```bash
   default_branch=$(gh api "repos/$repo" -q '.default_branch' 2>/dev/null)
   [ -n "$default_branch" ] || default_branch=main
   ```
   Use `$default_branch` in the two `gh api ...?ref=$default_branch` calls.
   Same pattern as `composition.yml:177` and `auto-merge-ai-prs.yml:177`.

2. **.github/workflows/ai-review.yml:405,412,423** — De-hardcode
   `vladm3105` in `raw.githubusercontent.com` fetch URLs. Parse the owner
   from `github.workflow_ref` (format: `owner/repo/.github/workflows/...@ref`):
   ```bash
   CI_OWNER=$(echo "${GITHUB_WORKFLOW_REF}" | cut -d/ -f1)
   ```
   Then construct URLs as:
   ```bash
   "https://raw.githubusercontent.com/${CI_OWNER}/aidoc-flow-ci/${REF}/ai-review/${f}"
   ```
   Fork-based adopters can then use their own fork. Non-fork adopters get
   the same `vladm3105` by default from their caller's `uses:` line.

3. **.github/workflows/doc-maintainer.yml:141,201,207** — Same de-hardcoding
   as above. Extract `CI_OWNER` from `GITHUB_WORKFLOW_REF` and use in
   `reconcile.py`, `planner.py`/`apply.py`, and `litellm_client.py` fetch
   URLs.

4. **.github/workflows/docs-sync.yml:113-116** — Same de-hardcoding as
   above. Extract `CI_OWNER` and use in the `scripts/docs-sync/` fetch URL.

---

## PR #6 — Release gate (founder-executed)

The only remaining gate between main and the `ci/v2.0.0` tag. Documented
pre-requisites per `HANDOFF.md:20-25`.

1. **Configure LiteLLM aliases** — Create `ai-reviewer` and
   `ai-doc-maintainer` model aliases in the LiteLLM proxy.

2. **Run `litellm-smoke.yml`** — Manual `workflow_dispatch` smoke test.
   Must exercise both canonical aliases against the real proxy.

3. **Verify test suite** — `tests/run.sh` passes (147 assertions).

4. **Cut `ci/v2.0.0` tag** — On the merge commit for the
   `feat/unified-litellm-agents` branch (PR #154), plus the 5 gap-closure
   PRs above. Follow `docs/RELEASE_CHECKLIST.md`.

5. **Create GitHub Release** — With CHANGELOG `## ci/v2.0.0` excerpt.

6. **Post-release verification** — `install.sh --repin ci/v2.0.0` on one
   consumer (e.g., operations or interlog). Verify ai-review gates fire.

## Findings disposition

| Original finding | Severity | Plan PR # | Change item |
|---|---|---|---|
| B1: ROADMAP current phase stale | BLOCKER | PR #1 | 1 |
| B2: PLAN-004 status DRAFT | BLOCKER | PR #1 | 3 |
| B3: PLAN-005 status DRAFT | BLOCKER | PR #1 | 4 |
| B4: BRANCH_PROTECTION wrong check-name | BLOCKER | PR #2 | 1-2 |
| B5: REPO_STANDARDS "11 reusables" | BLOCKER | PR #2 | 3 |
| B6: REPO_STANDARDS @ci/v1.5.1 pin | BLOCKER | PR #2 | 4 |
| B7: audit-trail-check pull_request_target | BLOCKER | PR #4 | 1 |
| H1: No migration guide | HIGH | PR #3 | 1 |
| H2: CHANGELOG no ## Unreleased header | HIGH | PR #3 | 3 |
| H3: security.md gacts/gitleaks stale | HIGH | PR #2 | 6 |
| H4: docs/README v2.0.0 hypothetical | HIGH | PR #2 | 7 |
| H5: UPDATE_GUIDE no v2 migration | HIGH | PR #3 | 2 |
| H6: ROADMAP Next phase auto-merge-ai-prs shipped | HIGH | PR #1 | 2 |
| H7: manifest.json missing .markdownlint.json/.lychee.toml | HIGH | PR #4 | 6 |
| H8: check-pin-currency.sh ref=main | HIGH | PR #5 | 1 |
| H9: REPO_STANDARDS interlog bootstrap-tier | HIGH | PR #2 | 5 |
| H10: hardcoded vladm3105 in fetch URLs | HIGH | PR #5 | 2-4 |
| M1: architecture/overrides stale @ci/v1.0.0 pins | MEDIUM | PR #2 | 8-9 |
| M2: docs-sync concurrency group global | MEDIUM | PR #4 | 2 |
| M3: auto-merge missing trust.auto_fix validation | MEDIUM | PR #4 | 3 |
| M4: install/README missing LiteLLM secrets | MEDIUM | PR #2 | 10 |
| M5: ROADMAP.md.template missing OPS references | MEDIUM | PR #4 | 7 |
| M6: FRAMEWORK-TODO FT-3 not marked RESOLVED | MEDIUM | PR #1 | 6 |
| M7: HANDOFF missing CI-0005/CI-0006 | MEDIUM | PR #1 | 5 |
| M8: No RELEASE_CHECKLIST.md | MEDIUM | PR #3 | 4 |
| L1: codeql.yml eval anti-pattern | LOW | PR #4 | 4 |
| L2: links.yml dead set -e | LOW | PR #4 | 5 |
| L3: ai-review GITHUB_TOKEN fallback (doc fix) | LOW | Deferred — intentional design noted in security.md |
| L4: pre_push_check.sh hardcoded ops URL | LOW | Deferred — cosmetic, post-v2 cleanup |

## Claim ledger

| # | Claim | Symbol | Citation |
|---|---|---|---|
| 1 | ROADMAP Current phase shows PLAN-003 | `## Current phase — PLAN-003` | ROADMAP.md:11 |
| 2 | ROADMAP Next phase lists auto-merge-ai-prs | `auto-merge-ai-prs.yml` | ROADMAP.md:59 |
| 3 | PLAN-004 status is DRAFT despite ci/v1.7.0 shipped | `DRAFT — 2026-07-09` | plans/PLAN-004_company-default-elevation.md:10 |
| 4 | PLAN-005 status is DRAFT rev 2 despite ci/v1.8.1 shipped | `DRAFT (rev 2 — 2026-07-10` | plans/PLAN-005_ai-review-pipeline-hardening.md:5 |
| 5 | HANDOFF recent-decisions lists CI-NNNN record link | `full CI-NNNN record` | HANDOFF.md:276 |
| 6 | FT-3 description fix still listed as fix sketch | `Fix sketch` | plans/FRAMEWORK-TODO.md:64 |
| 7 | labels.json skip-ai-review has corrected description | `suppress re-review and carry forward` | install/templates/labels.json:20 |
| 8 | BRANCH_PROTECTION.md line 19 has bare Lint name | `Lint / format / security hooks` | docs/BRANCH_PROTECTION.md:19 |
| 9 | BRANCH_PROTECTION.md tier tables use bare Lint name | `Lint / format / security hooks` | docs/BRANCH_PROTECTION.md:36 |
| 10 | REPO_STANDARDS cross-ref says 11 reusables | `11 reusables` | docs/REPO_STANDARDS.md:590 |
| 11 | REPO_STANDARDS auto-merge pin references @ci/v1.5.1 | `ci/v1.5.1` | docs/REPO_STANDARDS.md:945 |
| 12 | REPO_STANDARDS says interlog is bootstrap-tier | `Bootstrap-tier repos without CI adoption` | docs/REPO_STANDARDS.md:960 |
| 13 | security.md §6 example shows gacts/gitleaks action | `gacts/gitleaks@` | docs/security.md:227 |
| 14 | security.md §7 table lists gacts/gitleaks | `gacts/gitleaks` | docs/security.md:252 |
| 15 | security.md §7 explains gacts/gitleaks choice | `gitleaks-action` | docs/security.md:262 |
| 16 | docs/README describes v2.0.0 migration as hypothetical | `per-release migration` | docs/README.md:36 |
| 17 | architecture.md example uses @ci/v1.0.0 | `@ci/v1.0.0` | docs/architecture.md:184 |
| 18 | overrides.md examples use @ci/v1.0.0 | `@ci/v1.0.0` | docs/overrides.md:53 |
| 19 | install/README After-install table shows 2-row header | `After install` | install/README.md:135 |
| 20 | No MIGRATION_v2.0.0.md file exists | `v2.0.0` | docs/README.md:37 |
| 21 | No RELEASE_CHECKLIST.md file exists | `Updating a consumer` | docs/UPDATE_GUIDE.md:1 |
| 22 | CHANGELOG lacks ## Unreleased header; entries at top level | `Added — canonical branching standard` | CHANGELOG.md:6 |
| 23 | UPDATE_GUIDE has install/repin content but no v2 migration | `bootstrap` | docs/UPDATE_GUIDE.md:5 |
| 24 | audit-trail-check accepts pull_request_target event | `pull_request_target` | .github/workflows/audit-trail-check.yml:74 |
| 25 | audit-trail-check checks out fork HEAD ref | `github.event.pull_request.head.sha` | .github/workflows/audit-trail-check.yml:85 |
| 26 | docs-sync concurrency group has no ref qualifier | `group: docs-sync` | .github/workflows/docs-sync.yml:64 |
| 27 | auto-merge schema validates trust.ai_review and repos arrays | `trust.ai_review` | .github/workflows/auto-merge-ai-prs.yml:194 |
| 28 | codeql.yml uses eval on build-command input | `eval` | .github/workflows/codeql.yml:111 |
| 29 | links.yml has dead set -e after exit | `set -e` | .github/workflows/links.yml:136 |
| 30 | manifest.json has no .markdownlint.json entry | `Canonical surface manifest` | install/templates/manifest.json:4 |
| 31 | manifest.json has no .lychee.toml entry | `Canonical surface manifest` | install/templates/manifest.json:4 |
| 32 | ROADMAP.md.template lacks OPS-0065/0069/0066 references | `ROADMAP — <REPO_FRIENDLY_NAME>` | install/templates/ROADMAP.md.template:1 |
| 33 | check-pin-currency.sh uses hardcoded ref=main | `?ref=main` | sync/check-pin-currency.sh:65 |
| 34 | ai-review.yml hardcodes vladm3105 in fetch URLs | `vladm3105/aidoc-flow-ci` | .github/workflows/ai-review.yml:412 |
| 35 | doc-maintainer.yml hardcodes vladm3105 in fetch URLs | `vladm3105/aidoc-flow-ci` | .github/workflows/doc-maintainer.yml:141 |
| 36 | docs-sync.yml hardcodes vladm3105 in fetch URL | `vladm3105/aidoc-flow-ci` | .github/workflows/docs-sync.yml:116 |
| 37 | composition.yml resolves default branch dynamically | `default_branch` | .github/workflows/composition.yml:177 |
| 38 | litellm-smoke.yml is workflow_dispatch only | `workflow_dispatch` | .github/workflows/litellm-smoke.yml:4 |
| 39 | VERSION file reads ci/v2.0.0 pre-release | `ci/v2.0.0` | VERSION:1 |
| 40 | ROADMAP.md maintenance protocol documents promotion cycle | `promote "Next phase"` | ROADMAP.md:82 |
| 41 | feat/unified-litellm-agents merged to main (PR #154) | `unified LiteLLM gateway` | CHANGELOG.md:14 |

## Review log

### Pass 1 - 2026-07-13

- Initial draft. All 40 claims cited with file:line from verified source reads.

### Pass 2 - 2026-07-13 - independent

- **Finding: HANDOFF pruning age incorrect (HIGH).** Plan said "prune CI-0001 through CI-0003 (5 weeks old)" but all three are dated 2026-07-08 — 5 days old on review date. Fixed: add CI-0005/CI-0006, keep CI-0001 through CI-0004.
- **Finding: docs-sync.json missing from manifest additions (MEDIUM).** `install/templates/docs-sync.json` exists on disk, is installed by `deploy-ci-wizard.sh`, and is referenced by `apply-standards.sh`. Without a manifest entry, `--update` can't refresh it. Fixed: added to PR #4 manifest.json additions. `repo-settings.json` intentionally excluded (internal template, never consumer-file).
- **Finding: feat merge uncited (LOW).** Plan exit depends on `feat/unified-litellm-agents` merged. Added claim #41 citing CHANGELOG.md:58.
- **Finding: OPS-0067 omission unstated (LOW).** ROADMAP.md.template OPS footer mirrors CLAUDE.md.template but omits OPS-0067. Added note confirming intentional (agent dispatch scope irrelevant to roadmap).
- **Finding: eval→bash -c behavior note (LOW).** Added subprocess note clarifying `bash -c` launches a subprocess unlike `eval`.
- **Finding: no findings-to-PR mapping (LOW).** Added findings disposition table mapping all 29 findings to plan PR numbers + change items. 4 LOW findings: L3/L4 intentionally deferred (cosmetic). L1/L2 closed in PR #4.

40 citations verified against source; no fabrication found. All cited symbols resolve at cited lines. Plan groupings generate no merge conflicts when PRs are applied sequentially. No fix introduces a security regression.

**Result:** ready — no further findings.

