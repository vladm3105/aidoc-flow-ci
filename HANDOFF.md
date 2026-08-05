# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

## What the last session did (2026-08-05)

**PLAN-021 PR-A landed** — [#382](https://github.com/vladm3105/aidoc-flow-ci/pull/382),
merged first attempt, 6/6 green; [#352](https://github.com/vladm3105/aidoc-flow-ci/issues/352)
auto-closed. `doc-maintainer`'s dry-run patch renderer now works for the first
time in any release that carried it (`ci/v2.0.0`–`ci/v2.16.0`).

What shipped beyond the one-line `set +e` fix, because it changes what PR-B/C/D
must assume:

- **`REPO_STANDARDS` §24 exists and is declared a CONTAINER.** §24.1 is the
  `-e`-scoping rule. **§24.2 (PR-B), §24.3 (PR-C), §24.4 (PR-D) are reserved and
  their rule text is already written into §24's preamble** — do not re-decide
  the structure, and do not put a rule in the H2. **§24 is claimed in full by
  PLAN-021, so PLAN-023 PR-1 takes §25**, not §24.5.
- **Step 9 now reads `.pr_number` from the plan JSON**, and the guard is
  **split**, deviating from plan §4 PR-A point 1 on purpose: `[ -n "$PR" ]` is
  an **exit-1 fault gate**, `[ "$PR" = null ]` the **exit-0** branch. Point 1's
  literal `[ -z "$PR" ] || [ "$PR" = null ]` was written when `-z` meant "gh api
  fault"; once the read comes from the plan, empty means a *truncated plan* — a
  fault — so the literal guard would violate point 2, the governing requirement.
  **Plan §4:302 still states the superseded text and was not edited** (OPS-0061
  3-surface cap). The reasoning is in #382's body. **Do not "restore" it.**
- **Two marker-fenced regions now exist in the workflow** —
  `CI0027-DRYRUN-PATCH` and `CI0027-PR-RESOLVE` — extracted and driven by
  `tests/test_scripts.sh` under `bash -euo pipefail`. 23 assertions. Both
  mutations are asserted in-suite, not just recorded.

**The review found real defects, and so did the review of the fold.** Five
diff-class-matched agents, 2 of 5 NOT READY, 11 findings folded; an adversarial
re-verify of the fold then found 3 more. Load-bearing ones: an empty-`$PR`
silent miss; a mutation assertion a syntax error would have satisfied; the D12
`::error::` branch having zero coverage; and **two false claims already written
into canon prose** ("present in every tag that shipped the file" — false, 17
tags shipped it with no renderer; "the only comments that could post were the
ones with nothing to say" — false, `low_count=0, high_count>0` posts a
substantive one). **Fourth consecutive fold on this plan to need correction —
budget for it.**

⚠️ **`check_plan.py` now FAILs on PLAN-021 for THREE reasons, two of them new
and caused by PR-A succeeding.** Ledger **rows 8 and 9 cite the two defective
`(no -e)` comments PR-A corrected**, so those symbols no longer exist. That is
the plan describing a defect that is fixed — **not breakage, and not a
regression to revert.** Row 81 (`echo ""`) is worse in a quieter way: it now
matches only a *comment* about the deleted code, so it passes vacuously. The
third cause is the pre-existing "final pass does not state zero findings".
**Fixing rows 8/9/81 is a PLAN-021 edit owed with PR-B.**

**Two findings filed rather than left to die:**
[#383](https://github.com/vladm3105/aidoc-flow-ci/issues/383) (`test_resolver.sh`
drives two `FT28-PEEL-VERIFY` blocks under one flag set; only the `:667` one
really runs with `-o pipefail`, because only its step sets `shell: bash` — §24.1
is what made this visible) and
[#384](https://github.com/vladm3105/aidoc-flow-ci/issues/384) (`planner.py:133`
can emit `pr_number: null` with a non-empty `low_risk_set`, giving a misnamed
red).

## Current state — re-derive, do not trust

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` (PR-A is unreleased) |
| Open issues | `gh issue list --state open --limit 200` | **14** — #347–#349, #351, #353–#355, #358, #360, #363, #372, #378, #383, #384 |
| Open PRs | `gh pr list --state open` | **0** |
| `## Unreleased` | `sed -n '/^## Unreleased/,/^## ci/p' CHANGELOG.md \| grep -c '^### '` | **10** sections |
| Legacy queue | `wc -l < plans/FRAMEWORK-TODO.md` | 1,968 |
| Fleet pins | `bash sync/check-pin-currency.sh --fleet vladm3105/aidoc-flow-{operations,framework,iplanic,engramory,iplan-standard,interlog,business} vladm3105/iplan-runner` | **7/8 repos stale**; oldest `@ci/v1.9.5` |
| Suite | `bash tests/run.sh` | **1,058 passed, 0 failed** |
| PLAN-021 gate | `python3 ~/.claude/skills/verified-planning/check_plan.py plans/PLAN-021_doc-maintainer-dry-run-cluster.md --root ../framework --root ../operations` | **FAIL**, 3 causes — see the ⚠️ above |

## What to do next

1. **PLAN-021 PR-B ([#353](https://github.com/vladm3105/aidoc-flow-ci/issues/353))**
   — de-conflate, then record duplicates. Top item; 4 merges, tied with PR-D for
   the largest bucket. **Read §4 PR-B in the plan, not the issue body** — it
   changed in the fourth review pass. The trap it names: **both branches must
   `continue`**; recording without it re-creates the conflated-message defect
   353a exists to fix, because the remaining per-entry validation then runs on a
   rejected entry and `Path(path).is_file()` (`planner.py:189`) reports one
   condition as another. 353b must be **record-then-fail** (write the plan, then
   exit non-zero, collecting all violations), never record-and-skip. Its canon
   rule is **§24.2**, whose text is already fixed in §24's preamble.
   **Fold the PLAN-021 ledger rows 8/9/81 fix into this PR** — same plan, and it
   clears two of the gate's three FAIL causes.

2. **Then PR-C ([#354](https://github.com/vladm3105/aidoc-flow-ci/issues/354))
   and PR-D ([#360](https://github.com/vladm3105/aidoc-flow-ci/issues/360)).**
   PR-D lands **with** the cluster, not after. PR-D owes two things its own
   landed CI-0027 imposes: D-1 must disclose its narrowing in the inventory
   block's label (§20.2 rule 5), and **§24.4 extends §20 — §20.2 gains a rule 8
   with the normative text, §24.4 cross-references it opening "Extends §20.2."**
   Do not state the rule twice. PR-C is the only one tripping the 🔴 FT-30
   cold-start gate: a cut after PR-0+A+B+D needs no founder step, but once PR-C
   lands the founder-executed `scripts/ft30-dry-run.sh` is owed before
   `ci/v2.17.0`.

3. **Optional, founder's call: a fifth independent pass over PLAN-021.** Still
   unresolved and still not blocking. The trend across independent passes is
   10 → 9 → 6 → 7, and PR-A's own cycle is another data point that the plan's
   prose carries errors its gate cannot see. Against it: PR-by-PR review is the
   declared mitigation and it worked here — the per-PR agents caught all four
   defects. A fifth pass is well past OPS-0066's cap and needs founder sign-off.

4. **PLAN-023 PR-0** — `DECISIONS.md` **CI-0031** (next free; CI-0030 is highest
   taken, IDs never reused). Records the conformance floor incl. M4a, the
   declared-deviation rule, the §5c PR-code-on-pool extension, the §3c ruleset
   arming model, the opt-in-vs-Allstar divergence, **and the PLAN-020 Phase 3
   supersession** — PLAN-020 still prescribes `apply_rulesets()` in
   `apply-standards.sh`, which PLAN-023 §9e rejects, so a session reading
   PLAN-020 alone implements the wrong thing. **PR-1 now takes `REPO_STANDARDS`
   §25, not §24.** Before writing it, measure: run `ruff` + `mypy` over canon's
   ten Python modules; PR-1 puts those under a *required* lint context and the
   clean-up is unbounded until counted.

5. **Wire the governance check**
   ([#355](https://github.com/vladm3105/aidoc-flow-ci/issues/355)). Small, and it
   closes the hole that let the governance table stay false for weeks: nothing in
   `.github/workflows/` invokes `apply-standards.sh`.

6. **The other open issues:** #383/#384 (filed this session, above), #378
   (dependabot bumps bypassed OPS-0069 — decide the disposition and fix the
   `labeler.yml:27` comment either way), #363 (11-job fan-out pays a full
   ephemeral-runner provisioning cycle per job, ~13% of wall clock), #347/#348
   (doc accuracy), #349 (`sast-scan` cannot install semgrep — the image HAS
   python3; it lacks `python3-venv`/`ensurepip`), #351, #358, #372.

7. **Founder-gated 🔴 — do not execute as an AI:** arming the gates as required
   checks across the fleet (`docs/FLEET_BRANCH_PROTECTION_ARMING.md`); taking
   `docs-sync` from dry-run to live; **CI-0030's org migration**, decided but
   unscheduled and needing its own plan; **PLAN-023 §9f**; and the **PLAN-021
   resume**, which is what makes any of the cluster observable — sequence: PRs
   merge → tag `ci/v2.17.0` → framework re-pins → framework sets
   `kill_switch: false`. That landing also owes two consumer edits:
   `operations`' **`auto_merge.low_risk_paths`** (not `allowed_paths` — the
   `"*.md"` catch-all makes that a no-op), and framework's stale
   `RESUME REQUIRES #352 AND #353` note, which is **now doubly stale**: #352 is
   closed, and §3 shows the condition also needs #360 and #354.

## Open threads

- **Not now:** PLAN-023 S3–S7/X1 deferrals (§16 — S3 is blocked because the
  ephemeral runner has no Docker socket); PLAN-003 rollout waves (status lives in
  operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D, never hardcoded here).
