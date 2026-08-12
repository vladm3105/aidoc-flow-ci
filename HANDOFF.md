# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**State:** `main` carries **#441** (bootstrap tier gate), squashed
2026-08-12 · tree clean · **nothing deployed** — canon ships by tag, the last tag
is still `ci/v2.16.0`, and **53 merged PRs** are unreachable by any consumer ·
**36** open issues · **0** open PRs — **[#441](https://github.com/vladm3105/aidoc-flow-ci/pull/441), which must NOT be merged before the tag** (see Blockers).

All gates green, **run on this merge commit, not carried forward**. Re-derive
every row; the commands are exact (see `CLAUDE.md` § Durable traps for why the
SGR strip and `--tier` are not optional):

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` |
| Unreleased **PRs** | `git log --oneline ci/v2.16.0..HEAD \| grep -cE '\(#[0-9]+\)$'` — count PRs, not commits; a wrap commit carries no `(#N)` and would inflate a `wc -l` | **41** |
| Suite | `bash tests/run.sh \| sed 's/\x1b\[[0-9;]*m//g' \| grep -oE '[0-9]+ passed, [0-9]+ failed' \| awk '{p+=$1;f+=$3} END{print NR" suites, "p" passed, "f" failed"}'` | **17 suites, 1,542 passed, 0 failed** |
| pre-commit | `pre-commit run --all-files` | exit 0 |
| pre-push | `bash scripts/pre_push_check.sh` | exit 0 |
| Governance table | `python3 install/parse-governance-table.py CLAUDE.md --repo-root .` | PASS |
| Standards drift | `bash sync/check-standards-drift.sh --tier product` | 4/4 families, **2 drift** = the deliberate FT-52 profile |
| Open issues | `gh issue list --state open --limit 200 --json number --jq 'length'` | **36** |
| Open PRs | `gh pr list --state open --json number --jq 'length'` | **0** |

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

### Two defects found by RUNNING things nothing else runs

**Asked to make the installer ready for first run, and it was not.**
`VISIBILITY` defaulted to `private` and only bootstrap trusted the flag —
`update_mode` and `add_surface_mode` both resolved from the live repo. So a
PUBLIC cold start without `--visibility public` installed the **private**
variants, and once `quick-gates` lands that is a self-hosted job running
`pre-commit` over the PR's own files: the D7 violation, via a flag nobody
passed. Present since the installer's first commit (`21b9068`, 2026-06-23).
Nothing exercises that path — canon is already adopted.

**FT-30 could not see what it installed** (#358, closed). Every criterion was a
`grep` over the installer's own log, so a stanza that silently never runs passed
the whole gate — the F1 shape, which shipped a cold start missing
`ai-review.yml` for nine releases. It now checks the tree against the manifest at
the ref under test.

**And running FT-30 before #441 lands would have produced a false green**, because
the script pins `CI_TAG` to `HEAD` and #441 changes the bootstrap path. That
reordering is in `docs/RELEASE_CHECKLIST.md` and in "What to do next".

### The pattern worth carrying, because it recurred three times

**A check I wrote could not fail for the case it existed to catch** — three
separate times, each caught by mutation or an independent reviewer, never by
reading. `assert_absent` matching the comment that explains a banned construct;
`grep -q 'self-hosted'` matching the public template's comment about the private
variant; PLAN-026's §C acceptance reading tier templates when the case it
guards is a live-armed context in no template. Durable form in auto-memory.

## What to do next

> ### ⏳ `main` is temporarily broken for ONE path — cut the tag to close it
>
> #441 merged on 2026-08-12 (founder instruction), so bootstrap now installs
> `quick-gates.yml` — which pins **`ci/v3.0.0`, a tag that does not exist yet**.
> A cold start from **raw `main`** therefore resolves templates at
> `CI_TAG_FALLBACK` (`ci/v2.16.0`), where that file is absent, and dies on
> `fetch_template … || exit 1`. Verified: `git show
> ci/v2.16.0:install/templates/workflows/quick-gates.yml` → absent.
>
> **Unaffected:** the documented adoption path (pins a released tag) and FT-30
> (pins a SHA). **The window closes when the tag is cut.** Do not widen it.

1. **Run FT-30** — `main` is now the tree that will be tagged, which is what
   makes the run meaningful (it validates whatever `CI_TAG` resolves to, and
   #441 changed the bootstrap path). `--check` first; it writes nothing. Use a
   **PUBLIC** throwaway — that is the path #445 fixed and the one public
   consumers take:
   `bash scripts/ft30-dry-run.sh --target <owner>/<public-throwaway>`.
   It now verifies the installed **file set**, not just the log (#358).
2. **`bash scripts/release.sh prep ci/v3.0.0`**, then merge the prep PR. It
   retires the forward-pin markers itself.
3. **`bash scripts/release.sh tag ci/v3.0.0 --dry-run-verified`.** This closes
   the window above.
4. **Rebuild `aidoc-flow-runner:latest` on every OTHER runner host.** This host
   is done and verified; nothing prompts the others, and until they rebuild
   `scanners` is red on arrival. The `gh` pin expires again at the next release
   ([#435](https://github.com/vladm3105/aidoc-flow-ci/issues/435)).
5. **Then** PLAN-026's phases. **§C0 still owes the template substitution** —
   the retiring context is in **four** tier templates (`bootstrap`, `product`,
   `ops`, `governance`), and #441 did not touch them.

Open issues are the backlog — do not restate them here:

```sh
gh issue list --state open --limit 200      # the --limit 30 default truncates silently
```

## Blockers

All founder-only. None moved this session, and #430 did not attempt to.

| Blocker | Why | What clears it |
| --- | --- | --- |
| **🔴 FT-30 cold-start dry run — PREFLIGHT IS CLEAN, only the real run remains** | `bash scripts/ft30-dry-run.sh --check` writes nothing and passes: gate owed (15 cold-start files changed), `CI_TAG` resolves and is pushed, `gh` authenticated. Run it yourself before asking the founder for anything | Founder runs `scripts/ft30-dry-run.sh --target <owner>/<throwaway>` — it CLONES and creates ~21 labels in another repo, which is why it is founder-owned. See `CLAUDE.md` § Durable traps for what it does **not** assert ([#358](https://github.com/vladm3105/aidoc-flow-ci/issues/358)) |
| ~~🔴 `litellm-smoke`~~ | ✅ **PASSED 2026-08-10** — run `31348751529`, both aliases. Was never an infra fault; a mis-dispatch onto `ubuntu-latest` (CI-0017). Canon is back to **0** registered runners, so **re-running it needs a pool again** | done |
| ~~🟡 #438~~ | ✅ **CLOSED — #441 merged 2026-08-12** on founder instruction, ahead of the tag. Verified on merged `main`: `quick-gates` `auto_install: true`, `pre-commit` `false`, `replaces`-aware skip present, 1,542 assertions green. The consequence is the ⏳ window above, not a defect | done — cut the tag to close the window |
| ~~🔴 PR-C deviation~~ | ✅ **CONFIRMED by the founder 2026-08-10 — `DECISIONS.md` CI-0035.** Shipped shape stands: demote `CHANGELOG.md` to high-risk, leave it allowlisted. De-allowlisting relocates the red run rather than removing it (measured: exit 1 vs exit 0). §9 item 2 superseded on point 1 only. **Do not re-open** | done |
| ~~🔴 OPS-0066~~ | ✅ **WAIVED by the founder 2026-08-10 — `DECISIONS.md` CI-0036.** Both of §8's routes were exercised; the fresh plan (PLAN-026) took 3 independent passes and did not converge. The waiver rests on a distinction §8 did not draw: **the tag depends on the CODE being reviewed, not on the PLAN converging** — and the merged surface had a 5-lens pre-prod review plus 2 OPS-0065 reviews. The caveat is **not retracted**: the finding rate held, and the waiver accepts it as tolerable with the migration sequence and rollback as containment | done |
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
