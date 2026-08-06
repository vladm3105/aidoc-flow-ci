# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**State:** `main` carries #394, #397, #398, #399 · **nothing deployed** — canon
ships by tag, and everything since `ci/v2.16.0` is unreleased · repo checks
**3/3 pass** — `bash tests/run.sh`, `python3 install/parse-governance-table.py
CLAUDE.md --repo-root .`, `bash sync/check-standards-drift.sh --tier product`.
⚠️ The drift check **needs `--tier`**: bare, it warns `--tier required`, verifies
**0/4** control families and still exits 0.

## What the last session did (2026-08-05/06)

**Both handoff tasks landed.** #386 and #387 are closed by their PRs.

- **#397 — the issue-label namespace** (`REPO_STANDARDS` §5.4, `LABELS.md` §4).
  The canonical set named no issue *role*; it is now **21 labels in four
  groups**: `handoff`, `todo`, `status:in-progress`. Canon **self-adopted**
  them — they exist on this repo and are in use.
- **#398 — `REPO_STANDARDS` §25 + `DECISIONS.md` CI-0032**, multi-agent fleet
  coordination. Carrier rule (issue body = last-write-wins, comments =
  append-only, a git file = *refuses* the write), claim-before-start, one
  worktree per issue. **§25 is a no-op for a single writer.**
- **#394** — the previous session's handoff commit, which was sitting
  **committed but unpushed**, so `main` described the state before #392.
- **#399** — the Claim-ledger re-pin the two canon PRs drifted.

**Of #387's five proposed rules, two are DECLINED — read §25.5 before
re-proposing either.** A `flock`-serialized deploy (no repo canon governs
deploys a running service from a shell, so it would bind nothing) and making
`CLAUDE.md` a symlink to `AGENTS.md`. Reopening needs **new evidence**, not a
re-reading. **The problem behind the symlink decline is real and open as #395**:
rules living in `CLAUDE.md` and Claude-only skills are never seen by Codex or
DeepSeek.

**§5.4 did NOT migrate this repo's handoff.** It stays `HANDOFF.md`, per the §16
governance table. Provisioning `handoff` implies no migration — §5.4 says so
explicitly, and §25.2 defers to §16 rather than deciding it.

### What the reviews caught, because it is the reason to keep running them

Four OPS-0065 dispatches, **three returned NOT READY**, ~29 findings folded.
Every one of these shipped only because a review ran:

- **#394's mypy datum said "12 errors, all the same shape". Measured: 13, in
  four families, 2 of that shape.** It is the number PLAN-023 PR-1 would size a
  **required** lint gate on, and it was wrong in the direction that
  under-scopes. A `NoReturn` annotation clears **2 of 13**.
- **#397 asserted `labeler.yml` runs on `pull_request` only.** It is
  `pull_request_target`; `install/templates/workflows/labeler.yml:17-23` exists
  to say why. Canon would have contradicted itself in three places and taught
  adopters to break fork labeling.
- **#398's `AGENTS.md` decline rested on a 2-of-2 convergence that is 1-of-2.**
  `engramory`'s `CLAUDE.md` says "see **AGENTS.md** … **Both files apply**" and
  its §16 table declares `AGENTS.md` an Engineering agreement — co-equal, split
  by topic, *not* an orientation file. The decline survives on its mechanical
  legs and the corrected reading makes the symlink **weaker**.
- **#398 cited §16 for a rule §16 does not state** ("a gated artifact is a
  file"). That sentence is from the global `~/.claude/CLAUDE.md` — a personal
  convention, not canon.

**Filed rather than folded:** [#395](https://github.com/vladm3105/aidoc-flow-ci/issues/395)
(`AGENTS.md` as a required §16 surface — the real fix behind #387's rule 5) and
[#396](https://github.com/vladm3105/aidoc-flow-ci/issues/396) (`install.sh`
matches labels **case-sensitively** while GitHub's namespace is not;
`b-local-privy` carries `TODO`, so a bootstrap there would 422 and **abort after
writing files**). #396 is pre-existing — the three new *generic English words*
are what make it reachable.

## Current state — re-derive, do not trust

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` — **PR-A, PR-B, §5.4 and §25 all unreleased** |
| Open issues | `gh issue list --state open --limit 200` | **20** — #347–#349, #351, #354, #355, #358, #360, #363, #372, #378, #383, #384, #388–#391, #393, #395, #396 |
| Open PRs | `gh pr list --state open` | **0** |
| `## Unreleased` | `sed -n '/^## Unreleased/,/^## ci/p' CHANGELOG.md \| grep -c '^### '` | **13** sections |
| Suite | `bash tests/run.sh` | **1,076 passed, 0 failed** |
| PLAN-021 gate | `python3 ~/.claude/skills/verified-planning/check_plan.py plans/PLAN-021_doc-maintainer-dry-run-cluster.md --root ../framework --root ../operations` | **FAIL**, 1 cause (declared), **0 drift** |
| PLAN-023 gate | same, with `plans/PLAN-023_build-test-canon-and-conformance.md` | **FAIL**, 1 cause (unconverged), **0 drift** |
| Issue labels | `gh label list --limit 200 \| grep -E "handoff\|todo\|status:"` | all 3 present on canon |
| Fleet pins | `bash sync/check-pin-currency.sh --fleet vladm3105/aidoc-flow-{operations,framework,iplanic,engramory,iplan-standard,interlog,business} vladm3105/iplan-runner` | 7/8 stale at last measure; **re-run** |

Both plan gates keep the **same single FAIL**: *"final Pass does not state a
zero-findings result."* On PLAN-021 that is the declared survivor past
OPS-0066's cap — a **founder call**, and it clears when a pass returns clean,
not when a citation moves.

## What to do next

1. **PLAN-021 PR-C ([#354](https://github.com/vladm3105/aidoc-flow-ci/issues/354))**
   — stop planning what apply will refuse. **Read §4 PR-C in the plan, not the
   issue body.** Two halves; half 2 depends on PR-B's plumbing, which is in.
   Canon rule is **§24.3**, text already fixed in §24's preamble. PR-C is the
   only cluster PR tripping the 🔴 **FT-30 cold-start gate**: once it lands, the
   founder-executed `scripts/ft30-dry-run.sh` is owed before `ci/v2.17.0`.

2. **Then PR-D ([#360](https://github.com/vladm3105/aidoc-flow-ci/issues/360))**
   — lands **with** the cluster. D-1 must disclose its narrowing in the
   inventory block's label (§20.2 rule 5), and **§24.4 extends §20** — §20.2
   gains a rule 8 with the normative text, §24.4 cross-references it opening
   "Extends §20.2." Do not state the rule twice.

3. **Wire the governance check**
   ([#355](https://github.com/vladm3105/aidoc-flow-ci/issues/355)). Small, and
   it closes the hole that let the governance table stay false for weeks:
   nothing in `.github/workflows/` invokes `apply-standards.sh`.

4. **PLAN-023 PR-0** — `DECISIONS.md` **CI-0031**, which is **still reserved for
   it**; #387 deliberately took CI-0032 rather than disturb the three places
   PLAN-023 already cites CI-0031. **PR-1 now takes §26, not §24 or §25.**
   PLAN-023 carries **11 forward `§24` references across 9 lines** that PR-1
   must renumber; the plan names them and gives the grep that excludes its own
   lines. Before writing PR-0, measure `ruff` + `mypy` over canon's ten Python
   modules — and see the mypy correction above before scoping.

5. **The other open issues:** #396 (label case-sensitivity — has a full fix
   shape), #395 (`AGENTS.md` as a §16 surface), #393 (Claim-ledger traps into
   `CLAUDE.md`), #390 (**read this one first** — `apply.py` trusts the plan
   artifact), #389, #391, #388, #383/#384, #378, #372, #363, #347–#349, #351,
   #358.

6. **Founder-gated 🔴 — do not execute as an AI:** arming the gates as required
   checks across the fleet (`docs/FLEET_BRANCH_PROTECTION_ARMING.md`); taking
   `docs-sync` from dry-run to live; **CI-0030's org migration**, decided but
   unscheduled; **PLAN-023 §9f**; the **fifth PLAN-021 review pass** (the gate's
   remaining FAIL); and the **PLAN-021 resume**, which is what makes any of the
   cluster observable — sequence in plan **§6** (*Release and resume impact*;
   **not** §7, which is *Out of scope*): PRs merge → tag `ci/v2.17.0` →
   framework re-pins → framework sets `kill_switch: false`. That landing also
   owes two consumer edits: `operations`' **`auto_merge.low_risk_paths`** (not
   `allowed_paths` — the `"*.md"` catch-all makes that a no-op), and
   framework's stale `RESUME REQUIRES #352 AND #353` note, which needs #360 and
   #354 added (§3).

## Blockers

- **Nothing in the PLAN-021 cluster is observable until a release.** PR-A and
  PR-B are merged but unreleased; the pilot stays paused behind
  `kill_switch: true`. Cleared by the founder-gated §6 resume sequence.
- **PR-C blocks the tag on a founder step** (FT-30 cold-start dry-run). Cleared
  by the founder running `scripts/ft30-dry-run.sh` — note the script asserts the
  bootstrap *completed*, not that it installed the right file set
  ([#358](https://github.com/vladm3105/aidoc-flow-ci/issues/358)).

## Open threads

- **The three new labels provision nothing on consumers until each re-runs
  `install/install.sh`.** Canon shipping a label does not create it anywhere
  else. Expect `::warning::labels: canon label missing: …` from
  `check-standards-drift.sh` on every consumer until then — warning-only; no
  consumer sets `strict: true`.
- **Not now:** PLAN-023 S3–S7/X1 deferrals (§16 — S3 is blocked because the
  ephemeral runner has no Docker socket); PLAN-003 rollout waves (status lives
  in operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D, never hardcoded here).
