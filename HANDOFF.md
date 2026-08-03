# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

## What the last session did (2026-08-03)

**PLAN-021 PR-0 shipped** — [#373](https://github.com/vladm3105/aidoc-flow-ci/pull/373),
merged first attempt, 6/6 green. Doc-only; no code, no consumer action.
`DECISIONS.md` **CI-0027** now exists, filling the ID slot CI-0028 reserved for
it, so PR-A..PR-D can cite it. **PLAN-021 is `In Progress`.**

Two things the record establishes that were not in the plan as drafted:

- **Resuming on the consumer's own condition would leave the pilot two-thirds
  red, not a third.** `RESUME REQUIRES #352 AND #353` omits both `#360` and
  `#354`; the still-red union is **8 of the 12 merges**. PR-0's first draft said
  a third — that is `#360`'s contribution *alone*, and it understated the number
  carrying the record's own conclusion by ~2×. Caught by review, not by a gate.
- **[#372](https://github.com/vladm3105/aidoc-flow-ci/issues/372) filed** — the
  30 %-deletion guard reds the whole run instead of dropping the entry, the same
  blast-radius shape as 353b one stage later, folding in the identical 400-line
  ceiling. **No PR in the cluster fixes it.** Do not cite PLAN-021 as making the
  pilot green.

**PLAN-021 itself was corrected where it had drifted**, in the same PR: the
Pass-5 log reported the *retracted* 11-merge figure inside the entry documenting
its correction to 12; §8 still required CI-0027 to record a superseded "1-of-11"
founder acceptance (the figure that erred toward acceptance); §9's census table
had its headers swapped against its own data.

**The review pattern held again — PR-0's own review found a defect in the
immediately preceding draft**, as PLAN-021's Passes 2–4 each did. **Budget a
review pass for any fold here.** This was *not* the §10 pass, which is still
owed — see task 2.

## Current state — re-derive, do not trust

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` |
| Open issues | `gh issue list --state open --limit 200` | **13** — #347–#355, #358, #360, #363, **#372** (new) |
| Open PRs | `gh pr list --state open` | **0** |
| `## Unreleased` | `sed -n '/^## Unreleased/,/^## ci/p' CHANGELOG.md \| grep -c '^### '` | **7** sections |
| Legacy queue | `wc -l < plans/FRAMEWORK-TODO.md` | 1,968 |
| Fleet pins | `bash sync/check-pin-currency.sh --fleet vladm3105/aidoc-flow-{operations,framework,iplanic,engramory,iplan-standard,interlog,business} vladm3105/iplan-runner` | **not measured this session** |

## What to do next

1. **[#350](https://github.com/vladm3105/aidoc-flow-ci/issues/350) is more urgent
   than everything below, in wall-clock terms** — it has **framework's required
   `ai-review` gate red** (PLAN-021 §7 says so explicitly). It is unrelated to
   the cluster and needs a **founder key re-provision**, so the AI action here is
   to escalate, not to fix. Do this first even though the rest of the list is
   what you can execute alone.

2. **PLAN-021 §10's scoped fourth review pass — before PR-A.** Always owed; its
   precondition ("after the founder answers §9") is now met, both §9 items being
   closed. Scope is the **Pass-4 fold only**: §1's warnings, §3's countability
   correction, §4 PR-A's `null` guard, §4 PR-D's D-2. CI-0027 records that per-PR
   review does **not** discharge it. Dispatch `verified-planning-reviewer` with
   fresh context. Two known inputs for it: Claim-ledger **row 16** was corrected
   this session (it told PR-A to mirror Step 10's guard, which §4 PR-A forbids),
   and §9's Pass-5 log still narrates superseded figures by design — §3 and §9 M2
   carry the live ones.

3. **PLAN-021 PR-A (#352)** — scope `-e` off around Step 9's tolerated `diff`.
   Smallest bucket (1 merge) and still the graduation blocker: its loop reads
   `.low_risk_set[]`, so no plan containing a low-risk edit can complete a dry
   run, which is what the P4 gate exercises. **PR-A is what creates
   `REPO_STANDARDS` §24 (as §24.1), and §24 is claimed by both PLAN-021 and
   PLAN-023 PR-1 — PLAN-021 has priority and PLAN-023 renumbers.** Read §4 PR-A
   in full before writing: the `[ -z "$PR" ]` guard is **dead code today**
   (`jq -r '.[0].number'` on `[]` prints the literal string `null`), and the fix
   is to read `.pr_number` from the plan as Step 11 already does, **not** to
   mirror Step 10 — a bare `exit 1` there would red every PR-less main SHA. Do
   **not** "fix" the artifact race by creating `$PATCH` earlier; that converts a
   misnamed red into a silent green.

4. **Then PR-B (#353), PR-C (#354), PR-D (#360).** PR-D must land **with** the
   cluster, not after it — co-equal with PR-B at 4 merges each. PR-D's §24.4 must
   be written as an **extension of `REPO_STANDARDS` §20**, not beside it: D-1
   narrows a model-facing input, so §20.2 rule 5 ("a filtered input is a lying
   input", CI-0022) applies and the inventory's label must state it is scoped to
   `allowed_paths`. PR-C is the only one tripping the 🔴 FT-30 cold-start gate —
   a cut after PR-0+A+B+D needs no founder step; once PR-C lands, the
   founder-executed `scripts/ft30-dry-run.sh` is owed before `ci/v2.17.0`.

5. **PLAN-023 PR-0** — `DECISIONS.md` **CI-0031** (reserved; CI-0027 is now
   taken, IDs are never reused). Records the conformance floor incl. M4a, the
   declared-deviation rule, the §5c PR-code-on-pool extension, the §3c ruleset
   arming model, the opt-in-vs-Allstar divergence, **and the PLAN-020 Phase 3
   supersession** — PLAN-020 still prescribes `apply_rulesets()` in
   `apply-standards.sh`, the design PLAN-023 §9e rejects, so a session reading
   PLAN-020 alone implements the wrong thing. **Before writing PR-1, measure
   it:** run `ruff` + `mypy` over canon's ten Python modules; PR-1 puts those
   hooks under a *required* lint context and the clean-up is unbounded until
   counted.

6. **Wire the governance check**
   ([#355](https://github.com/vladm3105/aidoc-flow-ci/issues/355)). Small, and it
   closes the hole that let the governance table stay false for weeks: nothing in
   `.github/workflows/` invokes `apply-standards.sh`.

7. **The other open issues:** #363 (the 11-job fan-out pays a full
   ephemeral-runner provisioning cycle per job, ~13% of wall clock on a green
   run), #347/#348 (doc accuracy), #349 (`sast-scan` cannot install semgrep — the
   image HAS python3; it lacks `python3-venv`/`ensurepip`), #351, #358, #372.

8. **Founder-gated 🔴 — do not execute as an AI:** arming the gates as required
   checks across the fleet (`docs/FLEET_BRANCH_PROTECTION_ARMING.md`); taking
   `docs-sync` from dry-run to live; **CI-0030's org migration**, decided but
   unscheduled and needing its own plan; **PLAN-023 §9f**, a design decision on a
   🔴 write path; and the **PLAN-021 resume**, which is what makes any of the
   cluster observable — sequence: PRs merge → tag `ci/v2.17.0` → framework
   re-pins → framework sets `kill_switch: false`. That landing also owes two
   consumer edits: `operations`' **`auto_merge.low_risk_paths`** (not
   `allowed_paths` — the `"*.md"` catch-all makes that a no-op), and framework's
   stale `RESUME REQUIRES #352 AND #353` note.

## Open threads

- **Retroactive review of `28631e4` / `08d5cb5`** (two dependabot bumps). Raised
  two wraps ago *conditionally* — they already have the local suite, a two-mutant
  check and the upstream release notes behind them, and the open question is only
  whether that substitutes for the OPS-0065 pass. Dispose of it in one read:
  either accept that evidence and drop this line, or run the pass. It has now
  been lost twice by living only here.
- **Not now:** PLAN-023 S3–S7/X1 deferrals (§16 — S3 is blocked because the
  ephemeral runner has no Docker socket); PLAN-003 rollout waves (status lives in
  operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D, never hardcoded here).
