# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**State:** `main` carries PR-B ([#392](https://github.com/vladm3105/aidoc-flow-ci/pull/392))
· **nothing deployed** — canon ships by tag, and PR-A and PR-B are both
unreleased (resume sequence: item 6 below) · repo checks **3/3 pass** —
`bash tests/run.sh`, `python3 install/parse-governance-table.py CLAUDE.md
--repo-root .`, `bash sync/check-standards-drift.sh --tier product`. ⚠️ The
drift check **needs `--tier`**: bare, it warns `--tier required`, verifies
**0/4** control families and still exits 0. With the tier it verifies 4/4 and
reports **2 drift** — `enforce_admins` and `contexts`, both the deliberate
FT-52 canon profile, warning-only.

## What the last session did (2026-08-05)

**PLAN-021 PR-B landed** — [#392](https://github.com/vladm3105/aidoc-flow-ci/pull/392),
merged first attempt, 6/6 green; [#353](https://github.com/vladm3105/aidoc-flow-ci/issues/353)
auto-closed. `planner.py` no longer reports two conditions with one message, and
a duplicate no longer discards a completed planning call.

Two invariants PR-C/PR-D can get backwards. Both are enforced by
`tests/test_scripts.sh` and commented in `planner.py`; neither contradicts §4
PR-B, which specifies what shipped:

- **`allowlist_violations` is distinct by path, built inside the allowlist
  branch** (`planner.py:214-227`). §3 **quotes a naive per-entry comprehension
  at :196** and corrects it in place at :200 — read both lines, not the first.
- **`seen.add()` must stay below the allowlist check** (`planner.py:234`).
  Hoisting it relabels a repeat of a **rejected** path as `"duplicate"`.
- **`REPO_STANDARDS` §24.2 shipped.** §24.3 (PR-C) and §24.4 (PR-D) remain
  reserved with their text already fixed in §24's preamble. **§25 is still the
  next free section**, PLAN-023 included.

**PLAN-021's Claim ledger is now pinned to the current tree** — the gate went
from **three** failures to **one**, with zero drift warnings. The survivor is
the pre-existing *"final Pass does not state a zero-findings result"*: the plan
is genuinely unconverged (Pass 6 = NOT READY), and that clears when a pass
returns clean, not when the log is reworded. It is past OPS-0066's cap and is a
**founder call** — left red and declared.

⚠️ **Two Claim-ledger traps cost PR-B three cycles** — re-pin last, and `--fix`
never touches prose citations. Full text in
[#393](https://github.com/vladm3105/aidoc-flow-ci/issues/393), which moves them
to `CLAUDE.md` § "Durable traps".

**Three findings filed rather than folded** (§4 PR-B says "do not widen this"):
[#389](https://github.com/vladm3105/aidoc-flow-ci/issues/389) (three more
conflated messages in `planner.py`, one three lines below the guard PR-B split —
canon contradicting itself in the file it governs),
[#390](https://github.com/vladm3105/aidoc-flow-ci/issues/390) (`apply.py` trusts
the plan artifact; record-then-fail now leaves an apply-ready plan on disk after
a **rejected** run, contained only by GitHub's implicit `success()` across nine
consumer repos that demonstrably edit caller bodies) and
[#391](https://github.com/vladm3105/aidoc-flow-ci/issues/391) (`clean_path`
filters C0 only). **#390 is the one to read first.**

## Current state — re-derive, do not trust

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` (PR-A **and** PR-B unreleased) |
| Open issues | `gh issue list --state open --limit 200` | **20** — #347–#349, #351, #354, #355, #358, #360, #363, #372, #378, #383, #384, #386–#391, #393 |
| Open PRs | `gh pr list --state open` | **0** |
| `## Unreleased` | `sed -n '/^## Unreleased/,/^## ci/p' CHANGELOG.md \| grep -c '^### '` | **11** sections |
| Suite | `bash tests/run.sh` | **1,074 passed, 0 failed** |
| PLAN-021 gate | `python3 ~/.claude/skills/verified-planning/check_plan.py plans/PLAN-021_doc-maintainer-dry-run-cluster.md --root ../framework --root ../operations` | **FAIL**, 1 cause (declared — see above) |
| Fleet pins | `bash sync/check-pin-currency.sh --fleet vladm3105/aidoc-flow-{operations,framework,iplanic,engramory,iplan-standard,interlog,business} vladm3105/iplan-runner` | 7/8 stale at last measure; **re-run** |

## What to do next

1. **PLAN-021 PR-C ([#354](https://github.com/vladm3105/aidoc-flow-ci/issues/354))**
   — stop planning what apply will refuse. **Read §4 PR-C in the plan, not the
   issue body.** Two halves; half 2 depends on PR-B's plumbing, which is now in.
   Canon rule is **§24.3**, text already fixed in §24's preamble. PR-C is the
   only cluster PR tripping the 🔴 **FT-30 cold-start gate**: a tag cut after
   PR-0+A+B+D needs no founder step, but once PR-C lands the founder-executed
   `scripts/ft30-dry-run.sh` is owed before `ci/v2.17.0`.

2. **Then PR-D ([#360](https://github.com/vladm3105/aidoc-flow-ci/issues/360))**
   — lands **with** the cluster, not after. It owes two things CI-0027 imposes:
   D-1 must disclose its narrowing in the inventory block's label (§20.2 rule 5),
   and **§24.4 extends §20** — §20.2 gains a rule 8 carrying the normative text,
   §24.4 cross-references it opening "Extends §20.2." Do not state the rule twice.

3. **Wire the governance check**
   ([#355](https://github.com/vladm3105/aidoc-flow-ci/issues/355)). Small, and it
   closes the hole that let the governance table stay false for weeks: nothing in
   `.github/workflows/` invokes `apply-standards.sh`.

4. **PLAN-023 PR-0** — `DECISIONS.md` **CI-0031** (next free; CI-0030 is highest
   taken, IDs never reused). Records the conformance floor incl. M4a, the
   declared-deviation rule, the §5c PR-code-on-pool extension, the §3c ruleset
   arming model, the opt-in-vs-Allstar divergence, **and the PLAN-020 Phase 3
   supersession** — PLAN-020 still prescribes `apply_rulesets()` in
   `apply-standards.sh`, which PLAN-023 §9e rejects, so a session reading
   PLAN-020 alone implements the wrong thing. **PR-1 takes §25, not §24.**
   Before writing it, measure: `ruff` + `mypy` over canon's ten Python modules.
   Datum from PR-B (`python3 -m mypy scripts/doc-maintainer/planner.py`):
   `planner.py` is **ruff-clean** and carries **13 pre-existing mypy errors** in
   **four** families — only **2** are the `fail()`-is-not-`NoReturn`
   fall-through (`:25`, `:35`, both `Missing return statement`). The other 11 are
   1 × `import-not-found` (`litellm_client`, `:14`), 4 × `"object" has no
   attribute` on untyped `json.loads` returns, 6 × `Any | None` union-attr /
   arg-type. **A `NoReturn` annotation clears 2 of 13, not most of the fleet** —
   an earlier draft of this line said the opposite, and it is the number PR-1
   would size a **required** lint context on. Count per module before scoping.

5. **The other open issues:** [#393](https://github.com/vladm3105/aidoc-flow-ci/issues/393)
   (the two Claim-ledger traps belong in `CLAUDE.md` § "Durable traps";
   filed separately because `CLAUDE.md` is an OPS-0061 governance surface),
   #386 (no `handoff`/`todo` label namespace — until it lands the handoff stays
   this file), #387, #388 (branch-protection `"strict": false`), #383/#384,
   #378, #363, #347/#348, #349, #351, #358, #372.

6. **Founder-gated 🔴 — do not execute as an AI:** arming the gates as required
   checks across the fleet (`docs/FLEET_BRANCH_PROTECTION_ARMING.md`); taking
   `docs-sync` from dry-run to live; **CI-0030's org migration**, decided but
   unscheduled and needing its own plan; **PLAN-023 §9f**; the **fifth PLAN-021
   review pass** (the gate's remaining FAIL); and the **PLAN-021 resume**, which
   is what makes any of the cluster observable — sequence: PRs merge → tag
   `ci/v2.17.0` → framework re-pins → framework sets `kill_switch: false`. That
   landing also owes two consumer edits: `operations`' **`auto_merge.low_risk_paths`**
   (not `allowed_paths` — the `"*.md"` catch-all makes that a no-op), and
   framework's stale `RESUME REQUIRES #352 AND #353` note, which needs #360 and
   #354 added (§3).

## Blockers

- **Nothing in the PLAN-021 cluster is observable until a release.** PR-A and
  PR-B are merged but unreleased; the pilot stays paused behind
  `kill_switch: true`. Cleared by the founder-gated resume sequence in item 6
  (plan §6 `Release and resume impact` — **not** §7, which is `Out of scope`).
- **PR-C blocks the tag on a founder step** (FT-30 cold-start dry-run). Cleared
  by the founder running `scripts/ft30-dry-run.sh` — note the script asserts the
  bootstrap *completed*, not that it installed the right file set ([#358](https://github.com/vladm3105/aidoc-flow-ci/issues/358)).

## Open threads

- **Not now:** PLAN-023 S3–S7/X1 deferrals (§10 non-goals:926; S3 is blocked by
  §11:949 — the ephemeral runner attaches no Docker socket, so `services:` is
  unavailable. PLAN-023 has no §16); PLAN-003 rollout waves (status lives in
  operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D, never hardcoded here).
