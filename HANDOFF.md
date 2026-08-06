# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**State:** `main` carries #405 · **nothing deployed** — canon ships by tag, and
everything since `ci/v2.16.0` is unreleased · tree clean · repo checks
**3/3 exit 0** — `bash tests/run.sh`, `python3 install/parse-governance-table.py
CLAUDE.md --repo-root .`, `bash sync/check-standards-drift.sh --tier product`.
The drift check reports **2 known branch-protection drifts** (`enforce_admins`,
`contexts`) — the deliberate FT-52 canon profile, not a regression. Its `--tier`
trap and the suite-count traps now live in `CLAUDE.md` § "Gates that measure the
wrong thing".

## What the last session did (2026-08-06)

**PLAN-021 PR-C landed as [#405](https://github.com/vladm3105/aidoc-flow-ci/pull/405),
closing #354.** `apply.py` refused files over 200 KB while the install template
recommended `CHANGELOG.md` as a low-risk path; changelogs only grow, so the
recommended default was a guaranteed red run. Shipped: the template **demotes**
`CHANGELOG.md` to high-risk, `planner.py` pre-filters over-limit paths out of
the **low-risk set only** (after classification), `apply.py` exports
`MAX_APPLY_BYTES` and `planner.py` imports it, and `REPO_STANDARDS` **§24.3**
carries the rule. §24.4 stays reserved for PR-D.

**PR-C DEVIATED from the plan's §4 PR-C item 1, on purpose — do not "restore"
it.** Item 1 said drop `CHANGELOG.md` from `allowed_paths` **and**
`low_risk_paths`. Only the demotion shipped; the path stays allowlisted.
**De-allowlisting relocates the red run rather than removing it**: the planner's
inventory is an unfiltered `rglob("*.md")` until PR-D, and
`install/templates/doc-maintainer-conventions.md` — which canon installs
alongside the config — tells the model to use the changelog, so it is still
proposed, and a non-allowlisted proposal is a run-killing `return 1` where a
high-risk one is an issue body. Measured both ways against the shipped planner.
Full reasoning is in the plan's **§4 PR-C LANDED note** and ledger rows 40-41.

⚠️ **The founder has NOT been re-asked, and §9 item 2 does not say what a quick
read suggests.** Its headline is *"PR-C ships as specified, **both halves**"* and
it closes *"PR-C ships as specified"* — that is point 1, the shape that did not
ship. The *"Demoting `CHANGELOG.md` to high-risk"* sentence in the same item is
about the **cost on `operations`**, where de-allowlisting is a no-op anyway
because its allowlist ends in a `*.md` catch-all. So this deviation is a
**reviewer correction made after that acceptance**, not a restoration of it.
Put it to the founder before `ci/v2.17.0` is tagged.

### What the reviews caught, because it is the reason to keep running them

Four OPS-0065 agents dispatched; **all four returned NOT READY**. Three found
the de-allowlisting defect independently, two with reproductions — it would have
shipped a template whose first changelog-touching merge reds on a fresh adopter.
Also folded: **`--update` does replace a `safe_to_replace: false` file** when run
interactively and answered `[r]` (`install/install.sh:594-620`) — canon had
claimed it never rewrites; a "every one of them larger today" claim that was
**false for `operations`**, unchanged at 89,703 since its 2026-07-30 split; six
`MD049` errors that would have failed the gating lint; and a quoted "workspace
rule" that `grep` finds in **no repo** — it lives in the per-agent global
`CLAUDE.md`, so §24.3 now states the property instead of citing it.

**The test-engineer pass is the one that changed the shipped tests.** Five
mutations had been run and all five passed; it then demonstrated **three
surviving mutations** — `>=` for `>`, characters for bytes, and a second
declaration written `= 200000` (invisible to a grep for the literal `200_000`).
All five original mutations attacked *structure*; none attacked *measurement*.
Fixtures were added and the matrix is now **10 mutations, each red on a distinct
assertion**.

**Filed rather than folded:**
[#403](https://github.com/vladm3105/aidoc-flow-ci/issues/403) (the pre-filter
mirrors apply's **size** refusal but not its **symlink** refusal —
`planner.py`'s validation uses `Path(path).is_file()`, which follows symlinks)
and [#404](https://github.com/vladm3105/aidoc-flow-ci/issues/404)
(`.doc-maintainer-scripts/` is not cleared before the fetch loop, so a committed
package directory shadows `apply`/`litellm_client` at import time —
**pre-existing**, the same vector is already open for `litellm_client`, **not
fork-reachable**, and closed by one `rm -rf` that `Cleanup` already runs at the
wrong end).

**Not updated, deliberately:** `docs/EXERCISER_INVENTORY.md`'s
`.github/doc-maintainer.json` row now **understates** coverage — left out of
PR #405 to stay inside the OPS-0061 ≤3-doc cap, and filed as
[#406](https://github.com/vladm3105/aidoc-flow-ci/issues/406) so it survives
this file being regenerated.

## Current state — re-derive, do not trust

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` — **PR-A, PR-B, PR-C, §5.4, §25 all unreleased** |
| Open issues | `gh issue list --state open --limit 200` | **24** — #347–#349, #351, #355, #358, #360, #363, #372, #378, #383, #384, #388–#391, #393, #395, #396, #401–#404, #406 |
| Open PRs | `gh pr list --state open` | **0** |
| `## Unreleased` | `sed -n '/^## Unreleased/,/^## ci/p' CHANGELOG.md \| grep -c '^### '` | **14** sections |
| Suite | `bash tests/run.sh` | **1,093 passed, 0 failed across 15 suites** |
| PLAN-021 gate | `python3 ~/.claude/skills/verified-planning/check_plan.py plans/PLAN-021_doc-maintainer-dry-run-cluster.md --root ../framework --root ../operations` | **FAIL**, 1 cause (declared), **0 drift** |
| PLAN-023 gate | same, with `plans/PLAN-023_build-test-canon-and-conformance.md` | **FAIL**, 1 cause (unconverged), **0 drift** |
| Fleet pins | `bash sync/check-pin-currency.sh --fleet vladm3105/aidoc-flow-{operations,framework,iplanic,engramory,iplan-standard,interlog,business} vladm3105/iplan-runner` | 7/8 stale at last measure; **re-run** |

⚠️ **Counting the suite total has two traps, and both undercount silently** —
see `CLAUDE.md` § "Gates that measure the wrong thing", which now owns this.
Strip SGR first, then match, or you get **0**:

```sh
bash tests/run.sh | sed 's/\x1b\[[0-9;]*m//g' \
  | grep -oE '[0-9]+ passed, [0-9]+ failed' \
  | awk '{p+=$1;f+=$3} END{print NR" suites, "p" passed, "f" failed"}'
```

Both plan gates keep the **same single FAIL**: *"final Pass does not state a
zero-findings result."* On PLAN-021 that is the declared survivor past
OPS-0066's cap — a **founder call**, and it clears when a pass returns clean,
not when a citation moves.

## What to do next

1. **PLAN-021 PR-D ([#360](https://github.com/vladm3105/aidoc-flow-ci/issues/360))
   — the last of the cluster, and co-equal with PR-B by merge count.** **Read §4
   PR-D in the plan, not the issue body.** Two coupled halves and **D-1 alone
   leaves the bucket red**: D-1 filters the inventory through `allowed_paths`
   *before* the `MAX_DOC_INVENTORY` slice **and must relabel the block**
   (`Documentation inventory (allowed_paths only):`) per §20.2 rule 5; D-2 adds
   the missing imperative binding the model to the allowlist, referring to the
   datum **by its label, not by position**. **§24.4 extends §20** — §20.2 gains
   a rule 8 carrying the normative text, §24.4 cross-references it opening
   "Extends §20.2." Do not state the rule twice. D-1 is an **exact no-op on
   `operations`** (its allowlist ends in a `*.md` catch-all); it is `framework`
   that gains.

2. **Wire the governance check
   ([#355](https://github.com/vladm3105/aidoc-flow-ci/issues/355)).** Small, and
   it closes the hole that let the governance table stay false for weeks:
   nothing in `.github/workflows/` invokes `apply-standards.sh`.

3. **PLAN-023 PR-0** — `DECISIONS.md` **CI-0031**, still reserved for it.
   **PR-1 takes §26** (§24 is PLAN-021's, §25 went to #387); PLAN-023 carries
   **11 forward `§24` references across 9 lines** to renumber, and names the
   grep that excludes its own lines. Before writing PR-0, measure `ruff` +
   `mypy` over canon's Python modules — and see
   [#401](https://github.com/vladm3105/aidoc-flow-ci/issues/401) first, which
   owns the **inverted mypy correction**: use the measured figure from that
   issue, not any earlier handoff's.

4. **The two issues this session filed** — #403 (symlink pre-filter, has a full
   fix shape and fits beside the existing `#354` test block) and #404 (one-line
   `rm -rf` before the fetch, closes a pre-existing class).

5. **The rest of the open list:** #402 (handoff regeneration reverts fixes),
   #396 (label case-sensitivity — full fix shape), #395 (`AGENTS.md` as a §16
   surface), #393 (Claim-ledger traps into `CLAUDE.md`), #390 (**read this one
   first** — `apply.py` trusts the plan artifact), #389, #391, #388, #383/#384,
   #378, #372, #363, #358, #347–#349, #351.

6. **Founder-gated 🔴 — do not execute as an AI:** arming the gates as required
   checks across the fleet (`docs/FLEET_BRANCH_PROTECTION_ARMING.md`); taking
   `docs-sync` from dry-run to live; **CI-0030's org migration**, decided but
   unscheduled; **PLAN-023 §9f**; the **fifth PLAN-021 review pass** (the gate's
   remaining FAIL); and the **PLAN-021 resume** — sequence in plan **§6**
   (*Release and resume impact*; **not** §7, which is *Out of scope*): PRs merge
   → tag `ci/v2.17.0` → framework re-pins → framework sets `kill_switch: false`.

## Blockers

- **`ci/v2.17.0` cannot be tagged until the founder runs
  `scripts/ft30-dry-run.sh`.** PR-C put `install/templates/doc-maintainer.json`
  — a manifest template — into the diff, and `release.sh tag` refuses without
  `--dry-run-verified`. **Verified against the manifest, not assumed.** Note the
  script asserts the bootstrap *completed*, not that it installed the right file
  set ([#358](https://github.com/vladm3105/aidoc-flow-ci/issues/358)).
- **Nothing in the PLAN-021 cluster is observable until a release.** PR-A, PR-B
  and PR-C are **merged but unreleased** — unexecuted, not tested. The pilot
  stays paused behind `kill_switch: true`. Cleared by the founder-gated §6
  sequence.
- **The resume owes two consumer edits**, both easy to get wrong: `operations`
  must edit **`auto_merge.low_risk_paths`**, *not* `allowed_paths` (its `"*.md"`
  catch-all makes that a no-op) and must answer **`[k]`** at any interactive
  `--update` drift prompt, since `[r]` replaces the whole tuned file; and
  framework's stale `RESUME REQUIRES #352 AND #353` note needs **#354 and #360**
  added (plan §3).

## Open threads

- **The three §5.4 labels provision nothing on consumers until each re-runs
  `install/install.sh`.** Expect `::warning::labels: canon label missing: …`
  from `check-standards-drift.sh` on every consumer until then — warning-only;
  no consumer sets `strict: true`.
- **`operations` will hit the 200 KB refusal in LIVE mode** as its changelog
  grows (89,703 bytes, unchanged since 2026-07-30). PR-C protects new adopters
  only — `safe_to_replace: false` means `--update` never rewrites an existing
  consumer's config unattended.
- **Not now:** PLAN-023 S4–S7/X1 deferrals — **§10 Non-goals**, and S3's blocker
  is **§11 Risks** (the ephemeral runner attaches no Docker socket, so
  `services:` blocks are unavailable). **Not §16 — PLAN-023 has no §16.** That
  wrong cross-reference has now been reverted by regeneration twice, which is
  what [#402](https://github.com/vladm3105/aidoc-flow-ci/issues/402) exists to
  fix; check it before rewriting this line a third time. Also: PLAN-003 rollout
  waves (status lives in operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D, never
  hardcoded here).
