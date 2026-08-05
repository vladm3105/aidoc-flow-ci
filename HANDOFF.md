# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

## What the last session did (2026-08-04)

**PLAN-021 §10's owed scoped fourth review pass ran** —
[#380](https://github.com/vladm3105/aidoc-flow-ci/pull/380), merged first
attempt, 6/6 green. It was owed since the 2026-07-31 founder release and is not
an OPS-0066 breach: the cap's escape is escalation to the founder, that
escalation resolved, and §10 recorded the scoped fourth as its resolution.

**Verdict NOT READY — 7 load-bearing findings, all verified against source
before folding.** Three change the shipping diff, so **read §4 before writing
PR-B or PR-D**; the plan you would have built from last week is wrong in three
places:

- **PR-D lacked two obligations the landed `CI-0027` already imposes** — D-1
  must disclose its narrowing in the inventory block's label (`REPO_STANDARDS`
  §20.2 rule 5), and §24.4 must **extend** §20, not sit beside it. §24.4's
  landing site is now concrete in §8 so PR-D does not re-decide it: §20.2 gains
  rule 8 with the normative text, §24.4 cross-references it.
- **D-2 had no test** — the half the plan calls load-bearing was deletable with
  CI green, against §5's own mutation obligation. §5 now has the row.
- **PR-B's non-allowlisted branch omitted `continue`**, re-creating the
  conflated-message defect 353a exists to fix.

**PR-A was confirmed sound** — along with §3's countability correction and D-2's
diagnosis. The one correction touching it is to its *rationale*, not its design:
**"`[ -z "$PR" ]` is dead code" was false.** `|| echo ""` inside the
substitution (`doc-maintainer.yml:408`) empties `$PR` on any `gh` non-zero exit,
so the guard fires on exactly one class — the API fault — and reports it as "no
PR found" with **exit 0**. A silent miss scoring clean against P4(e), and a
stronger argument for PR-A than the plan was making.

**The fold introduced three defects of its own, caught by the pre-push review**
and recorded in the plan's Pass-6 addendum rather than quietly fixed: an `awk`
range that terminated on the ID *above* its start (425 lines to EOF instead of
129 — `DECISIONS.md` is ID-ascending, and CI-0027's date is *later* than
CI-0028's because it filled a reserved slot); a header block left contradicting
the §10 the same fold had rewritten; and a ledger row naming silent-green where
the mechanism produces a hard red. **Third consecutive fold on this plan to need
one** — budget for it.

⚠️ **`DECISIONS.md` CI-0027 still reads "PLAN-021 §10's scoped fourth pass … is
still owed".** That is now historical and is deliberately not edited — the
record is append-only, and CI-0027 itself says the plan's status "lives in its
own header, not here". The plan header is authoritative.

## Current state — re-derive, do not trust

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` |
| Open issues | `gh issue list --state open --limit 200` | **13** — #347–#349, #351–#355, #358, #360, #363, #372, #378 |
| Open PRs | `gh pr list --state open` | **0** |
| `## Unreleased` | `sed -n '/^## Unreleased/,/^## ci/p' CHANGELOG.md \| grep -c '^### '` | **9** sections |
| Legacy queue | `wc -l < plans/FRAMEWORK-TODO.md` | 1,968 |
| Fleet pins | `bash sync/check-pin-currency.sh --fleet vladm3105/aidoc-flow-{operations,framework,iplanic,engramory,iplan-standard,interlog,business} vladm3105/iplan-runner` | **7/8 repos stale**; oldest `@ci/v1.9.5` vs `ci/v2.16.0` |
| PLAN-021 gate | `python3 ~/.claude/skills/verified-planning/check_plan.py plans/PLAN-021_doc-maintainer-dry-run-cluster.md --root ../framework --root ../operations` | 81 citations resolve, 0 `UNVERIFIED`; **FAIL** on "final pass does not state zero findings" — that is the truth, not a regression |

## What to do next

1. **PLAN-021 PR-A (#352)** — scope `-e` off around Step 9's tolerated `diff`.
   Now the top item: the review pass that blocked it is discharged, and PR-A's
   design was explicitly confirmed sound. Smallest bucket (1 merge) and still the
   graduation blocker: its loop reads `.low_risk_set[]`, so no plan containing a
   low-risk edit can complete a dry run, which is what the P4 gate exercises.
   **Read §4 PR-A in full before writing** — the guard must test `[ -z "$PR" ] ||
   [ "$PR" = null ]`, and the fix is to read `.pr_number` from the plan as Step
   11 already does, **not** to mirror Step 10 (a bare `exit 1` there would red
   every PR-less main SHA). Do **not** "fix" the artifact race by creating
   `$PATCH` earlier; that converts a misnamed red into a silent green.
   **PR-A creates `REPO_STANDARDS` §24 (as §24.1), and §24 is claimed by both
   PLAN-021 and PLAN-023 PR-1 — PLAN-021 has priority and PLAN-023 renumbers.**

2. **Then PR-B (#353), PR-C (#354), PR-D (#360).** PR-D must land **with** the
   cluster, not after it — co-equal with PR-B at 4 merges each. **Both PR-B and
   PR-D changed last session** (see above); their §4 entries are the spec, not
   the issue bodies. PR-C is the only one tripping the 🔴 FT-30 cold-start gate —
   a cut after PR-0+A+B+D needs no founder step; once PR-C lands, the
   founder-executed `scripts/ft30-dry-run.sh` is owed before `ci/v2.17.0`.

3. **Optional, your call: a fifth independent pass over PLAN-021.** The plan
   declares its residual honestly — no `verified-planning-reviewer` has seen it
   in its present state, and the trend across independent passes is 10 → 9 → 6 →
   7 (not converging). Against that: the pre-push review of the newest fold found
   its defects, and PR-by-PR review is the declared mitigation. A fifth pass is
   well past OPS-0066's cap and needs founder sign-off, exactly as the fourth
   did. **Not a blocker for PR-A.**

4. **PLAN-023 PR-0** — `DECISIONS.md` **CI-0031** (next free; CI-0030 is the
   highest taken, and IDs are never reused). Records the conformance floor incl.
   M4a, the declared-deviation rule, the §5c PR-code-on-pool extension, the §3c
   ruleset arming model, the opt-in-vs-Allstar divergence, **and the PLAN-020
   Phase 3 supersession** — PLAN-020 still prescribes `apply_rulesets()` in
   `apply-standards.sh`, the design PLAN-023 §9e rejects, so a session reading
   PLAN-020 alone implements the wrong thing. **Before writing PR-1, measure it:**
   run `ruff` + `mypy` over canon's ten Python modules; PR-1 puts those hooks
   under a *required* lint context and the clean-up is unbounded until counted.

5. **Wire the governance check**
   ([#355](https://github.com/vladm3105/aidoc-flow-ci/issues/355)). Small, and
   it closes the hole that let the governance table stay false for weeks:
   nothing in `.github/workflows/` invokes `apply-standards.sh`.

6. **The other open issues:** #378 (dependabot bumps bypassed OPS-0069 entirely
   — decide the disposition and fix the `labeler.yml:27` comment either way),
   #363 (the 11-job fan-out pays a full ephemeral-runner provisioning cycle per
   job, ~13% of wall clock on a green run), #347/#348 (doc accuracy), #349
   (`sast-scan` cannot install semgrep — the image HAS python3; it lacks
   `python3-venv`/`ensurepip`), #351, #358, #372.

7. **Founder-gated 🔴 — do not execute as an AI:** arming the gates as required
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

- **Not now:** PLAN-023 S3–S7/X1 deferrals (§16 — S3 is blocked because the
  ephemeral runner has no Docker socket); PLAN-003 rollout waves (status lives
  in operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D, never hardcoded here).
