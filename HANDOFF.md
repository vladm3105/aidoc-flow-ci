# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what the
last session did, and what to do next. **Regenerated wholesale at every wrap per
CI-0028** — nothing here is history, and every volatile claim carries the command
that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps"; the
decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**State:** **`ci/v3.0.0` is RELEASED** (2026-08-12) and published as Latest. The
deployable artifact is the **tag**, at `6d68b26` — canon ships by tag, so that is
the identifier that survives; `main`'s tip moves and is not it. At this wrap
`main` was **6 commits above the tag**, tree clean, **45** open issues, **0** open
PRs. **None of the six reaches a consumer on `ci/v3.0.0`** — all are docs, plans
and governance records, no canon body — re-derive with
`git log --oneline ci/v3.0.0..origin/main`.

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v3.0.0` |
| Tag points at | `git ls-remote --tags origin 'refs/tags/ci/v3.0.0^{}'` | `6d68b26` |
| Release is Latest | `gh api repos/vladm3105/aidoc-flow-ci/releases/latest --jq .tag_name` — **not** `--json isLatest`, which is not a field | `ci/v3.0.0` |
| Suite | `bash tests/run.sh \| sed 's/\x1b\[[0-9;]*m//g' \| grep -oE '[0-9]+ passed, [0-9]+ failed' \| awk '{p+=$1;f+=$3} END{print NR" suites, "p" passed, "f" failed"}'` | **17 suites, 1542 passed, 0 failed** |
| pre-commit | `pre-commit run --all-files` | exit 0 |
| Governance table | `python3 install/parse-governance-table.py CLAUDE.md --repo-root .` | PASS |
| Standards drift | `bash sync/check-standards-drift.sh --tier product` | `pin-currency: all pins current` · 4/4 families · 2 drift = the deliberate FT-52 profile. **Read the output, not the exit code** — warning-only without `--strict`, so it exits 0 on drift |
| Open issues | `gh issue list --state open --limit 200 --json number --jq 'length'` | **45** |
| Open PRs | `gh pr list --state open --json number --jq 'length'` | **0** |

**`pre_push_check.sh` is not in that table on purpose.** Run it on `main` and it
exits **1** — `origin/main..HEAD` is empty, so it reports a false OPS-0069 failure
**and silently skips every mechanical linter**. That is
[#432](https://github.com/vladm3105/aidoc-flow-ci/issues/432), not a red repo; the
tell is `no changed files vs base — skipping mechanical linters`. It is only
meaningful on a branch with commits ahead of `main`, where it exited 0 on all
three of this session's branches. **An OPS-0069 failure on a branch whose range is
non-empty is a real one, not this.**

## What this session did

**Two merges, both governance records. No canon body changed.**

**[#471](https://github.com/vladm3105/aidoc-flow-ci/pull/471) — `DECISIONS.md`
CI-0037, closing [#454](https://github.com/vladm3105/aidoc-flow-ci/issues/454).**
The v3 release and its three discharged gates now have a durable record: release
facts each with the command that re-derives them, FT-30, `litellm-smoke` and the
OPS-0066 waiver with their evidence. `PLAN-025`'s header, §5 phase table, P6, §7
**and §8's blocking-release table** record the release; `ROADMAP.md` cites
CI-0037. Three surfaces, at the OPS-0061 cap.

**Two things CI-0037 records against the convenient reading** — both matter to
whoever picks up PLAN-024 or PLAN-025:

- **The PLAN-024 §7 precondition was half satisfied, half deviated from.** Its
  *gate* half was discharged directly; its *waste* half was not — v3 was built
  around `doc-maintainer`, which Phase A proposes to delete and which is **still
  live on `operations`**. `PLAN-024:565` says *"A and B ship together or the
  release is worse than not cutting it."* Not met at the cut. **A/B/C are no
  longer release gates**, but A's question is open and now more expensive.
- **FT-30 is founder-attested with no re-derive path.** `ft30-dry-run.sh` writes
  nothing to the scratch repo and commits no log artifact, so
  `FT-30 DRY-RUN PASSED` survives only as that record.

**[#472](https://github.com/vladm3105/aidoc-flow-ci/pull/472) — re-pinned three
`PLAN-026` ledger rows, one of which #471 broke.** Row 17 pinned a symbol inside
the §8 row #471 rewrote, so it became a hard `symbol not found` that `--fix`
cannot repair. It now cites CI-0037. **This is the durable lesson, and it is in
auto-memory:** editing a plan breaks the ledgers of every *other* plan citing it,
and a gate's row **count** never tells you which row.

Earlier in the session (already recorded in the predecessor handoff, not repeated
here): the #468 PLAN-023 §9g measurement, four stale issues closed, #363
re-scoped, and [#469](https://github.com/vladm3105/aidoc-flow-ci/issues/469)
filed.

## What to do next

Open issues are the backlog — do not restate them here:

```sh
gh issue list --state open --limit 200      # the --limit 30 default truncates silently
```

1. **[#469](https://github.com/vladm3105/aidoc-flow-ci/issues/469) — needs a
   decision before any code.** Re-measured at this wrap, unchanged: **21 of 23
   plans fail `check_plan.py`, 156 hard-failing rows**, and nothing in the repo
   executes the gate. Two open decisions: baseline it (fail only on new/edited
   rows) versus a repair campaign; and whether finished plans are re-pinned at all
   or exempted by a marker. **Wiring it as a blocking hook today reds every
   plan-touching PR.** Top item because it is the largest open defect and the
   decision is cheap to make and expensive to defer.
2. **[#455](https://github.com/vladm3105/aidoc-flow-ci/issues/455) — the rulebook
   half of #441.** Mechanical. `install/templates/manifest.json:185` still asserts
   `auto_install=true` on the line directly above `"auto_install": false`, and
   ships that way to consumers; `REPO_STANDARDS` §16 still names `pre-commit` as
   the bootstrap-tier producer.
3. **Wave 0 self-adoption.** Canon's pins are current but it runs the **v2
   architecture at a v3 pin** — `ls .github/workflows/ | grep -E
   'quick-gates|scanners'` is empty and no caller invokes a composite action under
   `actions/`. Canon dogfoods before Wave 1 pulls, and no consumer has repinned.
   The two easy-to-get-wrong PLAN-021 edits are in `CLAUDE.md` § "The PLAN-021
   consumer resume", not here.
4. **[#456](https://github.com/vladm3105/aidoc-flow-ci/issues/456)** — three docs
   still framed around the pre-tag state. Verified still true at this wrap.

## Blockers

| Blocker | Why | What would clear it |
| --- | --- | --- |
| **Runner image is stale on every host but this one** | Until each rebuilds, `scanners` is red on arrival there | [#458](https://github.com/vladm3105/aidoc-flow-ci/issues/458); the `gh`-pin half is [#435](https://github.com/vladm3105/aidoc-flow-ci/issues/435) |
| **PLAN-025 P7 must not run** | Still the only irreversible phase; P9 (rollback) must exist first. **P4** and **P5** are also not started | P9 landing. `docs/MIGRATION_v3.0.0.md` is the migration path, not the P5 documentation set |

No founder-gated blocker remains for the release itself — all three are now
recorded in `DECISIONS.md` CI-0037 rather than in this file, which is why this
section no longer restates their evidence.

## What did NOT change

No consumer repo, no branch protection, no ruleset, no required context, no canon
workflow, template, script or `REPO_STANDARDS` section. No `doc-maintainer` /
`docs-sync` / `ai-review` / `secret-scan` behaviour. `PLAN-024` was deliberately
**not** edited — it stays `Status: Draft — no phase executed`, which is accurate
for all three of Phases A, B and C.

**#469's 156 rows are still unrepaired.** The count is unchanged rather than
improved: #471 broke one row and #472 fixed it, netting zero.

`doc-maintainer` remains **live on `operations`** and **paused on `framework`** —
verified this session via `.github/doc-maintainer.json` in each
(`operations` `dry_run:false kill_switch:false`; `framework` both `true`).

Lessons went to auto-memory, which is **gitignored and machine-local** — safe on
this host only, not backed up. Read them there; they are not restated here.
