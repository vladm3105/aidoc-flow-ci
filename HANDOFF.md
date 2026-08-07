# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**State:** `main` carries **#414**, which closed #360 — the PLAN-021 cluster's
last code PR · **nothing deployed**: canon ships by tag and everything since
`ci/v2.16.0` is unreleased · tree clean · local checks **3/3 exit 0** (commands
in the table below) · CI green on the merge.

## What the last session did (2026-08-06)

**PLAN-021 PR-D landed as [#414](https://github.com/vladm3105/aidoc-flow-ci/pull/414),
closing [#360](https://github.com/vladm3105/aidoc-flow-ci/issues/360).** Both
halves shipped as §4 PR-D specifies — **verified** against the merged diff:

- **D-1** — `scripts/doc-maintainer/planner.py` filters the documentation
  inventory through `matches(path, allowed)` **before** the `MAX_DOC_INVENTORY`
  slice, and relabels the block `Documentation inventory (allowed_paths only):`
  (`REPO_STANDARDS` §20.2 rule 5).
- **D-2**, the load-bearing half — the prompt carries an imperative binding the
  model to the allowlist, naming both blocks by their labels.
- Canon: **§20.2 rule 8** (normative) + **§24.4** (the case, "Extends §20.2.").

**D-2 is ADVISORY — do not record the bucket as closed.** The only enforcement
point is the planner's allowlist branch. IPLAN-0025 P4(d) ("zero
allowlist-violation rejections") must be **re-measured after resume**. D-1 is an
exact no-op on `operations` (its `allowed_paths` ends in a `"*.md"` catch-all);
the consumer that gains is `framework`, **paused at `kill_switch: true`**, so the
gain is real and **unmeasured**.

**Three OPS-0065 review cycles ran and every one changed the shipped artifact** —
the full account is in the plan's §4 PR-D LANDED note and #414's body. **Cycle 3
hit the OPS-0066 cap; a fourth pass needs founder authorization.**

**Filed rather than folded** — all three pre-existing, none introduced by #414:
[#408](https://github.com/vladm3105/aidoc-flow-ci/issues/408) (the inventory's
exclusion set is tested against the **absolute** path's parts, so a checkout under
a directory named `vendor`/`node_modules`/`.venv`/`.git` blanks the inventory),
[#409](https://github.com/vladm3105/aidoc-flow-ci/issues/409) (PR title, body and
conventions are interpolated **raw**, so a PR body can forge a block label —
bounded to a failed run, never a bypass) and
[#413](https://github.com/vladm3105/aidoc-flow-ci/issues/413) (the planner prompt
satisfies §20.2 rules 5 and 8 but **not** 1, 4, 6 and 7). A fourth finding — the
citation gate's silent ±3-line tolerance — is a comment on
[#393](https://github.com/vladm3105/aidoc-flow-ci/issues/393).

**What did NOT change:** no workflow file, no template, no installer, no
`DECISIONS.md` entry, no release. #414 touched `planner.py`, two test files,
`REPO_STANDARDS`, `CHANGELOG.md` and the PLAN-021 plan.

## Current state — re-derive, do not trust

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` — PR-A…PR-D, §5.4, §25 **all unreleased** |
| Open issues | `gh issue list --state open --limit 200` | **29** |
| Open PRs | `gh pr list --state open` | **1** — #415, this handoff |
| `## Unreleased` | `sed -n '/^## Unreleased/,/^## ci/p' CHANGELOG.md \| grep -c '^### '` | **15** sections |
| Suite | `bash tests/run.sh \| sed 's/\x1b\[[0-9;]*m//g' \| grep -oE '[0-9]+ passed, [0-9]+ failed' \| awk '{p+=$1;f+=$3} END{print NR" suites, "p" passed, "f" failed"}'` — the SGR strip is required | **1,110 passed, 0 failed across 15 suites** |
| Governance table | `python3 install/parse-governance-table.py CLAUDE.md --repo-root .` | `"errors": []` |
| Standards drift | `bash sync/check-standards-drift.sh --tier product` | **2 warnings** — the deliberate FT-52 profile |
| PLAN-021 gate | `python3 ~/.claude/skills/verified-planning/check_plan.py plans/PLAN-021_doc-maintainer-dry-run-cluster.md --root ../framework --root ../operations` | **FAIL**, 1 cause (declared), **0 drift** |
| PLAN-023 gate | same, with `plans/PLAN-023_build-test-canon-and-conformance.md` | **not re-run this session** |
| Fleet pins | `bash sync/check-pin-currency.sh --fleet …` | **not measured this session** |

PLAN-021's single FAIL is *"final Pass does not state a zero-findings result"* —
the declared survivor past OPS-0066's cap, a **founder call**. Note the gate's
`0 drift` is **not** evidence the ledger is line-exact (#393).

## What to do next

1. **The three issues #414 filed**, each with a full fix shape in its body and
   none of them large: **#408** (one expression — test the relative path's
   parts), **#409** (`json.dumps` the three raw prompt fields; it changes the
   prompt's shape, so it wants its own §20.2 review) and **#413** (rules 4 and 7
   are the cheap half — a sentinel for a missing conventions file and a
   truncation marker). **#409 and #413 edit the same three prompt fields** — do
   them together, or #409 first, or each rewrites the other.

2. **Wire the governance check
   ([#355](https://github.com/vladm3105/aidoc-flow-ci/issues/355)).** Small, and
   it closes the hole that let the governance table stay false for weeks:
   nothing in `.github/workflows/` invokes `apply-standards.sh`.

3. **PLAN-023 PR-0** — `DECISIONS.md` **CI-0031**, still reserved for it. **PR-1
   takes §26** (§24 is PLAN-021's, §25 went to #387). Before writing PR-0,
   measure `ruff` + `mypy` over canon's Python modules — and read
   [#401](https://github.com/vladm3105/aidoc-flow-ci/issues/401) first, which
   owns the **inverted mypy correction**.

4. **The rest of the open list:** `gh issue list --state open --limit 200` — the
   `--limit 30` default truncates silently. Read
   [#390](https://github.com/vladm3105/aidoc-flow-ci/issues/390) first
   (`apply.py` trusts the plan artifact).

5. **Founder-gated 🔴 — do not execute as an AI:** arming the gates as required
   checks across the fleet; taking `docs-sync` from dry-run to live; **CI-0030's
   org migration**; **PLAN-023 §9f**; the **next independent PLAN-021 review pass** (the log ends at Pass 6; §10 counts it as the fourth independent one); and the
   **PLAN-021 resume** — sequence in plan **§6**: PRs merge → tag `ci/v2.17.0` →
   framework re-pins → framework sets `kill_switch: false`.

## Blockers

- **`ci/v2.17.0` cannot be tagged until the founder runs
  `scripts/ft30-dry-run.sh`.** **Two** files in `coldstart_surface` changed since
  `ci/v2.16.0`, not one: `install/templates/doc-maintainer.json` (#405, a manifest
  template) and `install/templates/labels.json` (#397), which is named explicitly
  in `scripts/release.sh` rather than walked from the manifest. `release.sh tag`
  refuses without `--dry-run-verified`. Re-derive with
  `git diff --name-only ci/v2.16.0..origin/main` against `coldstart_surface()`.
- **The founder confirmation owed on PR-C's deviation is still open** and is due
  before `ci/v2.17.0`. #405 shipped the demotion only, not the de-allowlisting
  §4 PR-C item 1 called for; §9 item 2 records acceptance of *"PR-C ships as
  specified, both halves"*, which is the shape that did **not** ship. Reasoning:
  plan §4 PR-C LANDED note.
- **The whole cluster is merged but unreleased** — unexecuted, not tested. The
  pilot stays paused behind `kill_switch: true`. Cleared by the founder-gated §6
  sequence.
- **The resume owes two consumer edits**, both easy to get wrong: `operations`
  must edit **`auto_merge.low_risk_paths`**, *not* `allowed_paths` (its `"*.md"`
  catch-all makes that a no-op) and must answer **`[k]`** at any interactive
  `--update` drift prompt; and framework's stale `RESUME REQUIRES #352 AND #353`
  note needs **#354 and #360** added (plan §6 and §3 respectively).

## Open threads

- **PR #414's checks were cancelled without ever being assigned a runner**, at
  ~15 minutes with `runner_name: ""` and zero steps, across two attempts
  (17:53Z and 18:09Z batches; last job ended 18:37:08Z). The next batch, on a new
  head SHA at 23:51Z, ran green and the PR merged. **Whether the new SHA or
  elapsed time cleared it is NOT established** — nothing was re-run in between,
  so the data cannot distinguish the two. `audit-trail` run `31124428688` is
  still `queued` and was never re-attempted. Signature and diagnosis:
  `CLAUDE.md` § "Gates that measure the wrong thing".
- **The three §5.4 labels provision nothing on consumers until each re-runs
  `install/install.sh`** — expect `::warning::labels: canon label missing: …`
  until then; warning-only.
- **Not now:** PLAN-023 S4-S7/X1 deferrals — **§10 Non-goals**, S3's blocker is
  **§11 Risks** ([#402](https://github.com/vladm3105/aidoc-flow-ci/issues/402)
  owns the cross-reference that regeneration keeps reverting).
