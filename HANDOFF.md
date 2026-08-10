# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**State:** `main` carries **#437** (PLAN-026), squashed
2026-08-10 · tree clean · **nothing deployed** — canon ships by tag, the last tag
is still `ci/v2.16.0`, and **44 merged PRs** are unreachable by any consumer ·
**38** open issues · **1** open PR — **[#441](https://github.com/vladm3105/aidoc-flow-ci/pull/441), which must NOT be merged before the tag** (see Blockers).

All gates green, **run on this merge commit, not carried forward**. Re-derive
every row; the commands are exact (see `CLAUDE.md` § Durable traps for why the
SGR strip and `--tier` are not optional):

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` |
| Unreleased **PRs** | `git log --oneline ci/v2.16.0..HEAD \| grep -cE '\(#[0-9]+\)$'` — count PRs, not commits; a wrap commit carries no `(#N)` and would inflate a `wc -l` | **41** |
| Suite | `bash tests/run.sh \| sed 's/\x1b\[[0-9;]*m//g' \| grep -oE '[0-9]+ passed, [0-9]+ failed' \| awk '{p+=$1;f+=$3} END{print NR" suites, "p" passed, "f" failed"}'` | **17 suites, 1,517 passed, 0 failed** |
| pre-commit | `pre-commit run --all-files` | exit 0 |
| pre-push | `bash scripts/pre_push_check.sh` | exit 0 |
| Governance table | `python3 install/parse-governance-table.py CLAUDE.md --repo-root .` | PASS |
| Standards drift | `bash sync/check-standards-drift.sh --tier product` | 4/4 families, **2 drift** = the deliberate FT-52 profile |
| Open issues | `gh issue list --state open --limit 200 --json number --jq 'length'` | **38** |
| Open PRs | `gh pr list --state open --json number --jq 'length'` | **1** (#441, held on purpose) |

## What this session did

**Cleared two blockers that were mislabelled founder-only, made v3 installable,
and failed to clear the third — that failure is the headline.**

Merged: **#430** (five pre-prod blockers + two release-mechanics traps),
**#433** (`--add-surface`), **#436** (runner image), **#437** (PLAN-026).

**Two "founder-only" labels did not survive being tested.** Both had been
carried across handoffs unexamined:

- **`litellm-smoke` PASSED** — run `31348751529`, both aliases, first time ever.
  The 2026-07-13 failures were a **mis-dispatch onto `ubuntu-latest`**, which
  per CI-0017 cannot reach the bridge proxy; the workflow's own default was
  already the pool.
- **The runner image had been unbuildable since `gh` 2.97.0** — `cli.github.com`
  keeps only the current release, so the exact pin expires on its own and no CI
  job builds the image. **#349's fix was undeliverable by anyone**, while the
  handoff said "founder rebuilds the image". Pin bumped; #349 now closed by
  measurement (venv, PyYAML, semgrep all verified in the rebuilt image).

**v3 was uninstallable and is not any more.** The v3 callers are
`auto_install: false`, so bootstrap skipped them and `--update` never introduces
a surface — there was **no supported install path at all** (#429). Closed by
`install.sh --add-surface`.

**PLAN-026 was written to discharge the OPS-0066 blocker and FAILED its own
review.** Three independent passes: 10 load-bearing findings, then 5 more —
**two introduced by the fold**. Fourteen folded, **one open** (#438). The cap is
spent on PLAN-026 too, so no fourth pass was dispatched, and `check_plan.py`
correctly **fails** the plan. It is committed as `NOT READY`.

**A live defect in a procedure written EARLIER THE SAME DAY.**
`docs/MIGRATION_v3.0.0.md`'s rollback step 1 said to bootstrap, which restores
**1 of 6** v2 callers before step 2 arms six contexts — re-creating, mid-incident,
the hang the procedure exists to end. Fixed; the independent pass verified the fix.

Filed: [#425](https://github.com/vladm3105/aidoc-flow-ci/issues/425)
[#426](https://github.com/vladm3105/aidoc-flow-ci/issues/426)
[#427](https://github.com/vladm3105/aidoc-flow-ci/issues/427)
[#428](https://github.com/vladm3105/aidoc-flow-ci/issues/428)
[#432](https://github.com/vladm3105/aidoc-flow-ci/issues/432)
[#435](https://github.com/vladm3105/aidoc-flow-ci/issues/435)
[#438](https://github.com/vladm3105/aidoc-flow-ci/issues/438) · **#429 was filed
and then fixed** — filing is not finishing.

### The pattern worth carrying, because it recurred three times

**A check I wrote could not fail for the case it existed to catch** — three
separate times, each caught by mutation or an independent reviewer, never by
reading. `assert_absent` matching the comment that explains a banned construct;
`grep -q 'self-hosted'` matching the public template's comment about the private
variant; PLAN-026's §C acceptance reading tier templates when the case it
guards is a live-armed context in no template. Durable form in auto-memory.

## What to do next

**Every remaining item on the critical path is a DECISION, not build work.** I
looked for build work and did not find any that moves the tag; PLAN-026 was the
last attempt and it is in Blockers, not here.

1. **Take the four decisions in Blockers.** Nothing below them moves. Two of
   them are new or newly-sharpened this session, so read them rather than
   assuming they are the same list as yesterday.
2. **[#438](https://github.com/vladm3105/aidoc-flow-ci/issues/438) is the one to
   read first** — it is the only load-bearing item that survived PLAN-026's three
   review passes, it blocks the migration phase, and both options hang a repo's
   `main` in some scenario. It has a recommendation and the evidence for it.
3. **Do NOT start PLAN-026's phases.** Its Status header says NOT READY,
   `check_plan.py` fails it, and §C0 carries a 🔴 block. Phases A (local layer)
   and B (rollback) are the only ones without an open precondition — but B's
   value is as C's undo, and C cannot start until the tag exists.
4. **If a v2.17.0 is still wanted**, it must be cut before PLAN-024 Phase A makes
   `main` a MAJOR. `docs/REPO_STANDARDS.md:355` rules out an RC tag entirely —
   validating v3 on a consumer branch needs a **SHA pin**.

Open issues are the backlog — do not restate them here:

```sh
gh issue list --state open --limit 200      # the --limit 30 default truncates silently
```

### One fact this wrap ROUTED OUT rather than carried

The previous wrap corrected *"`call / verify` will red every canon PR until a
tag containing CI-0033 exists"* — and wrote a section explaining that
regeneration would otherwise revert it. **The next regeneration reverted it
anyway.** That is #402's failure mode, committed one wrap after being warned
about, by the same author.

So it is no longer here. It is in `CLAUDE.md` § "Durable traps", where a
wholesale rewrite cannot reach it, now with 10-of-10 measurements. **A fact that
has to survive a regeneration is a fact in the wrong carrier** — if you find
yourself deliberately carrying something forward, move it instead.

## Blockers

All founder-only. None moved this session, and #430 did not attempt to.

| Blocker | Why | What clears it |
| --- | --- | --- |
| **🔴 FT-30 cold-start dry run — PREFLIGHT IS CLEAN, only the real run remains** | `bash scripts/ft30-dry-run.sh --check` writes nothing and passes: gate owed (15 cold-start files changed), `CI_TAG` resolves and is pushed, `gh` authenticated. Run it yourself before asking the founder for anything | Founder runs `scripts/ft30-dry-run.sh --target <owner>/<throwaway>` — it CLONES and creates ~21 labels in another repo, which is why it is founder-owned. See `CLAUDE.md` § Durable traps for what it does **not** assert ([#358](https://github.com/vladm3105/aidoc-flow-ci/issues/358)) |
| ~~🔴 `litellm-smoke`~~ | ✅ **PASSED 2026-08-10** — run `31348751529`, both aliases. Was never an infra fault; a mis-dispatch onto `ubuntu-latest` (CI-0017). Canon is back to **0** registered runners, so **re-running it needs a pool again** | done |
| **🟡 [#438](https://github.com/vladm3105/aidoc-flow-ci/issues/438) — RESOLVED IN CODE, awaiting a merge you must time** | Was: substituting `quick-gates` into the tier templates bricks a post-v3 cold start. [PR #441](https://github.com/vladm3105/aidoc-flow-ci/pull/441) removes the trade-off — the `auto_install` flag moves with the context AND a `replaces`-aware bootstrap skip prevents the double-install that was option A's whole cost. Mutation-tested both directions | **Merge #441 AT the tag cut, never before.** Pre-tag, `quick-gates.yml` pins a tag that does not exist, so merging early installs a `startup_failure`ing caller while removing the producer the current templates require — the same brick, sooner |
| **🔴 PR-C deviation confirmation** | Due before `ci/v2.17.0`. #405 shipped the demotion only, not the de-allowlisting §4 PR-C item 1 called for | Founder decision; reasoning in PLAN-021 §4 PR-C LANDED note |
| **🔴 OPS-0066 — and the fresh-plan route has now been TRIED AND FAILED** | PLAN-025's cap was spent; §8 offered "a fresh plan, reviewed on its own budget" as the better alternative. PLAN-026 is that plan: 3 independent passes, 15 load-bearing findings, 14 folded, 1 open (#438), and its own cap now spent. `check_plan.py` fails it | A founder **waiver** is now the remaining route; the alternative was attempted in good faith and did not converge |
| **The runner image must be REBUILT on EVERY OTHER runner host** | #436 fixed the `gh` pin (the image had been unbuildable since 2.97.0, so #349's fix was undeliverable) and **this host's image is rebuilt and verified** — venv, PyYAML and `semgrep==1.170.0` all confirmed. Other hosts still carry the old one, and nothing prompts them. Until each rebuilds, `scanners` is red on arrival | `cd install/templates/runner && bash build-image.sh` per host. It now *builds* a venv and imports yaml to verify. The pin will expire again at the next `gh` release — [#435](https://github.com/vladm3105/aidoc-flow-ci/issues/435) |

**PLAN-025 P7 must not run** — still the only irreversible phase; P9 (rollback)
must exist first. P4 and P5 (the full `docs/v3/` set) are also not started;
`docs/MIGRATION_v3.0.0.md` is the migration path but not the documentation set.

The **PLAN-021 consumer resume** owes two easy-to-get-wrong edits; they are
durable and live in `CLAUDE.md` § "The PLAN-021 consumer resume", not here.

## What did NOT change

No tag, no release, no consumer repo, no branch protection, no ruleset, no
required context, and no `VERSION` bump. No `doc-maintainer`, `docs-sync`,
`ai-review` or `secret-scan` behaviour.

**All five** v3 caller templates still pin `ci/v3.0.0`, a tag that does not
exist, behind `sync-version-refs:ignore` markers. `release.sh prep` now removes
them at the cut, so this is no longer a manual step — but count them rather than
trusting this line: `grep -rlF 'ci/v3.0.0' install/templates/workflows/`.

`doc-maintainer` remains **live on `operations`** and **paused on `framework`** —
not re-verified this session; re-derive with
`python3 -c "import json;[print(r, json.load(open(f'../{r}/.github/doc-maintainer.json'))['dry_run'], json.load(open(f'../{r}/.github/doc-maintainer.json'))['kill_switch']) for r in ('operations','framework')]"`.
