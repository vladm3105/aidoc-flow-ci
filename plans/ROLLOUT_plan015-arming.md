# ROLLOUT — PLAN-015 fleet arming + B2 deployment (🔴 founder-executed)

> **Status: PREPARED, NOT EXECUTED.** Authored in `aidoc-flow-ci/plans/` per
> PLAN-015 Task 8. Every step here writes to consumer repos or changes
> branch protection — 🔴 per the operations autonomy tiers — so the FOUNDER runs
> it. AI does not execute any step below in-session (writes-to-other-repos →
> ops/inbox-first). Describe the ops/inbox handoff; do not perform it.

## What this closes

PLAN-015's canon-side work is merged (PRs #209–#216). What remains is the
per-repo deployment that the AI cannot do:

- **B2-arm** — arm branch protection so the (now-honest) gates actually BLOCK.
- **B2-detect deploy** — install the new `standards-drift` consumer caller per
  repo (canon shipping the reusable ≠ consumers running it — the capability is
  live, adoption is this runbook).
- **B2-verify** — confirm each repo with `install.sh --verify-standards`.
- **CI-0011 (M1)** — carry the `verified_allowed` decision, if changed.
- **FT-13** — fix the broken private standards-drift pins (iplanic annotated-tag
  SHA; business/interlog had no caller).

## Prerequisite — Phase 0: cut `ci/v2.8.0`

Nothing below runs until `ci/v2.8.0` exists (the consumer `standards-drift`
templates require the `workflow_call` reusable that first ships in v2.8.0, and
the fleet re-pins TO v2.8.0). The release cut is a distinct decision — see
`docs/RELEASE_CHECKLIST.md`. Mechanically:

1. `VERSION` → `ci/v2.8.0`; run `scripts/sync-version-refs.sh` (bumps every
   template `@ci/v*` pin, incl. the new `standards-drift` templates, to v2.8.0).
2. Open + merge the release PR (green).
3. `git tag ci/v2.8.0 <merge-sha>` + `gh release create ci/v2.8.0`.
4. Confirm `tests/test_version_sync.sh` passes (VERSION == CI_TAG_FALLBACK ==
   latest published tag).

After the tag exists, the `standards-drift` caller templates resolve and the
fleet target is real.

## Phase 1 — per repo (🔴 founder), one at a time, verify before proceeding

Fleet (from PLAN-009): **public** = framework, engramory, iplan-standard,
iplan-runner · **private** = business, iplanic, interlog · operations (armed).
Tiers per REPO_STANDARDS §1 (governance = iplan-standard; product = most; ops =
operations).

For each repo:

1. **Re-pin to `ci/v2.8.0`** — version-only:
   `CI_TAG=ci/v2.8.0 bash install/install.sh <owner/repo> --repin`.
   NOT `--update` (FT-9: clobbers runner_labels). **NOT a drop-in for public
   repos** — the PLAN-013 uniform model runs the ai-review *review* job on the
   self-hosted pool on public repos too, so a public consumer needs a
   `ci-runner,single-use` pool registered first (PLAN-009 Phase 0).

2. **Install the `standards-drift` caller** (B2-detect deploy) — via the wizard:
   `bash install/deploy-ci-wizard.sh scaffold <owner/repo> <dir> standards-drift`
   then set its `tier:` to the repo's tier, commit on a branch, open the adoption
   PR with the OPS-0069 phrase. Warning-only; do NOT add it to branch protection.

3. **Arm branch protection** (B2-arm) — follow the existing runbook
   `docs/FLEET_BRANCH_PROTECTION_ARMING.md` (arm the check-name the repo ACTUALLY
   emits; per-tier required-contexts table + verify + rollback are there).
   `aidoc-flow-ci` itself, `engramory`, `iplan-standard` currently have NO branch
   protection; `business` + `iplanic` carry only the phantom bare
   `Lint / format / security hooks` context (FT-12) — fix per that runbook.

4. **Set `vars.APP_REVIEWER_1_BOT_ID`** where composition is still inert:
   `gh variable set APP_REVIEWER_1_BOT_ID --repo <owner/repo> --body 294948438`.

5. **Verify** (B2-verify) — with an admin-scoped `gh` token:
   `bash install/install.sh <owner/repo> --verify-standards --tier <tier>`.
   Expect exit 0 (clean). Exit 1 = drift/absent (re-check steps 3–4); exit 2 =
   token lacks admin scope (re-run with an admin PAT).

## Phase 2 — FT-13 consumer-pin fixes (🔴)

The private standards-drift detection was broken pre-PLAN-015 (FT-13): iplanic's
old `standards-drift` caller pinned an unresolvable annotated-tag-object SHA, and
business/interlog had no caller. Installing the new caller (Phase 1 step 2) with
a `@ci/v2.8.0` tag pin supersedes the broken pins — verify each private repo's
caller resolves (the reusable's fetch logs the pin it derived). Then close FT-13
in `plans/FRAMEWORK-TODO.md`.

## Phase 3 — CI-0011 (`verified_allowed`) decision (🔴 founder)

Resolve DECISIONS CI-0011 (OPEN): keep `verified_allowed: true` (verified
marketplace admitted fleet-wide) OR drop it (three-pattern boundary only). If
DROP: edit `install/templates/actions-permissions.json`, re-tag canon, apply the
new `actions/permissions/selected-actions` per repo via `apply-standards.sh
--apply`, and expect any verified-creator action a consumer still calls to then
`startup_failure`. Record the resolution as a new CI-NNNN citing CI-0011.

## Done when

- All fleet repos pinned `@ci/v2.8.0`, running `standards-drift` (warning-only),
  branch protection armed + verified (`--verify-standards` exit 0), bot-id set.
- FT-13 closed; CI-0011 resolved (new CI-NNNN).
- HANDOFF "What remains" updated to reflect the completed rollout.

## Handoff

Stage this as the ops/inbox runbook for the founder (do not execute in-session).
Cross-repo writes + branch-protection changes are 🔴 per the operations autonomy
tiers; verbal "run it" does not override the inbox-first requirement.
