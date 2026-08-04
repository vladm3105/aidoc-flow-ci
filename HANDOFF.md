# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

## What the last session did (2026-08-04)

**#350 fixed and shipped** — [#375](https://github.com/vladm3105/aidoc-flow-ci/pull/375),
merged first attempt, 6/6 green. `install/set-litellm-secrets.sh` can no longer
silently overwrite a working secret; `tests/test_litellm_secrets.sh` is new (121
assertions) and the exerciser-inventory row that called this script "low risk;
`accepted-no-FT`" is corrected.

**A standing claim was retired as false: framework's `ai-review` is GREEN.** Three
handoffs and `plans/PLAN-021_*.md` §7 said its gate was red and owed a founder
key re-provision. Measured instead: the last 8 `ai-review` runs on
`aidoc-flow-framework` all concluded **success** through 2026-08-03T00:11Z; in
the most recent one `Run review through LiteLLM → verdict file` succeeded with
~16 s of model latency while the infra-failure and skip steps were both
*skipped*; `LITELLM_REVIEW_API_KEY` was last written 2026-07-30T00:04:43Z, i.e.
**before** those green runs; and framework has 0 open PRs. **No re-provision is
owed — do not `--overwrite` that secret.** Re-derive before believing otherwise:
`gh run list --repo vladm3105/aidoc-flow-framework --workflow ai-review --limit 6 --json event,conclusion,createdAt`.
The claim survived because it was the one line carrying no re-derive command.
Corrected on #350; PLAN-021 §7 still states it and is next to fix.

## Current state — re-derive, do not trust

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` |
| Open issues | `gh issue list --state open --limit 200` | **12** — #347–#349, #351–#355, #358, #360, #363, #372 |
| Open PRs | `gh pr list --state open` | **0** |
| `## Unreleased` | `sed -n '/^## Unreleased/,/^## ci/p' CHANGELOG.md \| grep -c '^### '` | **8** sections |
| Legacy queue | `wc -l < plans/FRAMEWORK-TODO.md` | 1,968 |
| Fleet pins | `bash sync/check-pin-currency.sh --fleet vladm3105/aidoc-flow-{operations,framework,iplanic,engramory,iplan-standard,interlog,business} vladm3105/iplan-runner` | **7/8 repos stale**; oldest `@ci/v1.9.5` vs `ci/v2.16.0` |

## What to do next

1. **Correct `plans/PLAN-021_doc-maintainer-dry-run-cluster.md` §7**, which still
   asserts framework's `ai-review` is red and blocks the resume. It is the
   source the retired claim above propagated from, and any session reading the
   plan will re-adopt it. Smallest task on this list; do it before §10's review
   pass reads the same file.

2. **PLAN-021 §10's scoped fourth review pass — before PR-A.** Still owed; its
   precondition ("after the founder answers §9") is met, both §9 items being
   closed. Scope is the **Pass-4 fold only**: §1's warnings, §3's countability
   correction, §4 PR-A's `null` guard, §4 PR-D's D-2. CI-0027 records that
   per-PR review does **not** discharge it. Dispatch `verified-planning-reviewer`
   with fresh context. Two known inputs: Claim-ledger **row 16** was corrected
   (it told PR-A to mirror Step 10's guard, which §4 PR-A forbids), and §9's
   Pass-5 log narrates superseded figures by design — §3 and §9 M2 carry the
   live ones.

3. **PLAN-021 PR-A (#352)** — scope `-e` off around Step 9's tolerated `diff`.
   Smallest bucket (1 merge) and still the graduation blocker: its loop reads
   `.low_risk_set[]`, so no plan containing a low-risk edit can complete a dry
   run, which is what the P4 gate exercises. **PR-A creates `REPO_STANDARDS`
   §24 (as §24.1), and §24 is claimed by both PLAN-021 and PLAN-023 PR-1 —
   PLAN-021 has priority and PLAN-023 renumbers.** Read §4 PR-A in full before
   writing: the `[ -z "$PR" ]` guard is **dead code today** (`jq -r
   '.[0].number'` on `[]` prints the literal string `null`), and the fix is to
   read `.pr_number` from the plan as Step 11 already does, **not** to mirror
   Step 10 — a bare `exit 1` there would red every PR-less main SHA. Do **not**
   "fix" the artifact race by creating `$PATCH` earlier; that converts a
   misnamed red into a silent green.

4. **Then PR-B (#353), PR-C (#354), PR-D (#360).** PR-D must land **with** the
   cluster, not after it — co-equal with PR-B at 4 merges each. PR-D's §24.4
   must be written as an **extension of `REPO_STANDARDS` §20**, not beside it:
   D-1 narrows a model-facing input, so §20.2 rule 5 ("a filtered input is a
   lying input", CI-0022) applies and the inventory's label must state it is
   scoped to `allowed_paths`. PR-C is the only one tripping the 🔴 FT-30
   cold-start gate — a cut after PR-0+A+B+D needs no founder step; once PR-C
   lands, the founder-executed `scripts/ft30-dry-run.sh` is owed before
   `ci/v2.17.0`.

5. **PLAN-023 PR-0** — `DECISIONS.md` **CI-0031** (next free; CI-0030 is the
   highest taken, and IDs are never reused). Records the conformance floor incl. M4a, the
   declared-deviation rule, the §5c PR-code-on-pool extension, the §3c ruleset
   arming model, the opt-in-vs-Allstar divergence, **and the PLAN-020 Phase 3
   supersession** — PLAN-020 still prescribes `apply_rulesets()` in
   `apply-standards.sh`, the design PLAN-023 §9e rejects, so a session reading
   PLAN-020 alone implements the wrong thing. **Before writing PR-1, measure
   it:** run `ruff` + `mypy` over canon's ten Python modules; PR-1 puts those
   hooks under a *required* lint context and the clean-up is unbounded until
   counted.

6. **Wire the governance check**
   ([#355](https://github.com/vladm3105/aidoc-flow-ci/issues/355)). Small, and
   it closes the hole that let the governance table stay false for weeks:
   nothing in `.github/workflows/` invokes `apply-standards.sh`.

7. **The other open issues:** #363 (the 11-job fan-out pays a full
   ephemeral-runner provisioning cycle per job, ~13% of wall clock on a green
   run), #347/#348 (doc accuracy), #349 (`sast-scan` cannot install semgrep —
   the image HAS python3; it lacks `python3-venv`/`ensurepip`), #351, #358,
   #372.

8. **Founder-gated 🔴 — do not execute as an AI:** arming the gates as required
   checks across the fleet (`docs/FLEET_BRANCH_PROTECTION_ARMING.md`); taking
   `docs-sync` from dry-run to live; **CI-0030's org migration**, decided but
   unscheduled and needing its own plan; **PLAN-023 §9f**, a design decision on
   a 🔴 write path; and the **PLAN-021 resume**, which is what makes any of the
   cluster observable — sequence: PRs merge → tag `ci/v2.17.0` → framework
   re-pins → framework sets `kill_switch: false`. That landing also owes two
   consumer edits: `operations`' **`auto_merge.low_risk_paths`** (not
   `allowed_paths` — the `"*.md"` catch-all makes that a no-op), and framework's
   stale `RESUME REQUIRES #352 AND #353` note.

## Open threads

- **Retroactive review of `28631e4` / `08d5cb5`** (two dependabot bumps). Raised
  three wraps ago *conditionally* — they already have the local suite, a
  two-mutant check and the upstream release notes behind them, and the open
  question is only whether that substitutes for the OPS-0065 pass. Dispose of it
  in one read: either accept that evidence and drop this line, or run the pass.
  It has now been lost three times by living only here; if it survives another
  wrap, file it as an issue instead.
- **Not now:** PLAN-023 S3–S7/X1 deferrals (§16 — S3 is blocked because the
  ephemeral runner has no Docker socket); PLAN-003 rollout waves (status lives
  in operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D, never hardcoded here).
