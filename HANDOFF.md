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
`main` was **3 commits above the tag**, tree clean, **46** open issues, **0** open
PRs. **None of the three reaches a consumer on `ci/v3.0.0`** — all three are docs
and plans, no canon body — re-derive with
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
| Open issues | `gh issue list --state open --limit 200 --json number --jq 'length'` | **46** |
| Open PRs | `gh pr list --state open --json number --jq 'length'` | **0** |

**Correction to the previous wrap's table, which said `pre_push_check.sh` exits
0.** Run it *on `main`* and it exits **1** — `origin/main..HEAD` is empty, so it
reports a false OPS-0069 failure **and silently skips every mechanical linter**.
That is [#432](https://github.com/vladm3105/aidoc-flow-ci/issues/432) reproducing,
not a red repo — the tell is `no changed files vs base — skipping mechanical
linters`. It is only meaningful on a branch with commits ahead of `main`; it
exited 0 on `docs/plan-023-mypy-datum` (PR #468). **Do not record "both exit 0"
again without naming the branch it was run on** — and note that an OPS-0069
failure on a branch whose range is *non-empty* is a real one, not this.

## What this session did

**A triage pass over the 49 open issues, and one merge.** Nothing shipped to
consumers; no canon body changed.

**Merged [#468](https://github.com/vladm3105/aidoc-flow-ci/pull/468)** — PLAN-023
§9g. §9 had said PR-1's `ruff`/`mypy` clean-up was "unbounded until measured" for
weeks; it is now measured whole-tree —
`python3 -m mypy $(git ls-files '*.py')` → **28 errors in 5 files**. (Canon
declares no `mypy` hook yet; that is the shape PR-1's will have.) Four modules
share one `fail() -> None` defect and four `NoReturn` annotations clear **28 → 13**;
the residual 13 is a separate cluster in the two `install/` modules. **PR-1 sizes
against 28, not 13.** Full record in `CHANGELOG.md` § Unreleased.

**Closed four issues as stale, each with the evidence in its close comment:**

- **#401** — its target (`HANDOFF.md`) had been regenerated away. Its datum is now
  PLAN-023 §9g, which is *why* #468 existed. Its own fix shape argued the issue
  was the durable carrier; that is the claim #468 disputes.
- **#402** — same shape; superseded by `CLAUDE.md` § Durable traps and #412.
- **#419** — duplicate of #432, same line, #432 strictly broader.
- **#378** — closed as accepted, **and its central premise corrected**: it claimed
  dependabot bypassing OPS-0069 was "a gap in the gate's coverage". It is an
  explicit exemption at both layers (`pre_push_check.sh` via `%an`,
  `audit-trail-check.yml:126-133` via GitHub-verified `user.type == 'Bot'`), with
  the asymmetry deliberate and documented at `audit-trail-check.yml:36-40`.

**Re-scoped #363** — its suggested fix 2 shipped in `ci/v3.0.0` (`quick-gates` and
`scanners` are exactly the consolidation it asked for). Only the doc sentence
survives, and its open question is answered: the autoscaler concurrency limit
belongs to `operations`, not here.

**Filed [#469](https://github.com/vladm3105/aidoc-flow-ci/issues/469) — the
biggest thing found.** Nothing in this repo *executes* `check_plan.py` — no hook,
no workflow, no wrapper; every mention of it is a comment or prose — and the
ledgers have decayed accordingly:
**21 of 23 plans fail the gate, 156 ledger rows hard-fail**. Same class as #355.
Re-derive with the loop in the issue's first comment.

**Cleared stale `status:in-progress` markers** from closed #450, #387, #360.

## What to do next

Open issues are the backlog — do not restate them here:

```sh
gh issue list --state open --limit 200      # the --limit 30 default truncates silently
```

1. **[#454](https://github.com/vladm3105/aidoc-flow-ci/issues/454) — record the
   release where its gates were declared.** Unchanged and re-verified this
   session: `plans/PLAN-025_v3-clean-rebuild.md:586` still reads
   `P6 — Release ci/v3.0.0. ⬜ NOT STARTED`, and the header at `:3` still says
   In Progress. **Correcting the previous wrap, which said the `litellm-smoke`
   run id "now survives only inside #454's body":** it is in `ROADMAP.md:39`,
   `plans/PLAN-025:1002` and `plans/PLAN-026:370` — `git grep -l 31348751529`.
   #454's real remainder is the `DECISIONS.md` record of the discharged founder
   gates, not the run id, and that is why it is still top.
2. **[#469](https://github.com/vladm3105/aidoc-flow-ci/issues/469) — decide the
   shape before touching a row.** At 156 failing rows this is not a repair task.
   The two decisions, both open: baseline the gate (fail only on new/edited rows)
   versus a repair campaign, and whether finished plans are re-pinned at all or
   exempted by a marker. Wiring it as a blocking hook today reds every
   plan-touching PR.
3. **[#455](https://github.com/vladm3105/aidoc-flow-ci/issues/455) — the rulebook
   half of #441.** Re-verified: `install/templates/manifest.json:185` still
   asserts `auto_install=true` on the line above `"auto_install": false`.
4. **Consumer adoption / Wave 0.** Canon's own pins are current
   (`bash sync/check-standards-drift.sh --tier product` → `pin-currency: all
   pins current ✅`; the exit code proves nothing here) but the v3
   surfaces are still not installed here — `ls .github/workflows/ | grep -E
   'quick-gates|scanners'` is empty. Canon dogfoods before Wave 1 pulls. The two
   easy-to-get-wrong PLAN-021 edits are in `CLAUDE.md` § "The PLAN-021 consumer
   resume", not here.

## Blockers

| Blocker | Why | What would clear it |
| --- | --- | --- |
| **Runner image is stale on every host but this one** | Until each rebuilds, `scanners` is red on arrival there | [#458](https://github.com/vladm3105/aidoc-flow-ci/issues/458); the `gh`-pin half is [#435](https://github.com/vladm3105/aidoc-flow-ci/issues/435) |
| **PLAN-025 P7 must not run** | Still the only irreversible phase; P9 (rollback) must exist first. **P4** and **P5** are also not started | P9 landing. `docs/MIGRATION_v3.0.0.md` is the migration path, not the documentation set |

No founder-gated blocker remains for the release itself (FT-30 passed 2026-08-12;
`litellm-smoke` run `31348751529`; OPS-0066 waived, `DECISIONS.md` CI-0036).

## What did NOT change

No consumer repo, no branch protection, no ruleset, no required context, no canon
workflow, template, script or `REPO_STANDARDS` section. No `doc-maintainer` /
`docs-sync` / `ai-review` / `secret-scan` behaviour. **The only tracked file this
session changed outside `plans/` and `CHANGELOG.md` is this one.**

**`#469`'s 156 failing rows were NOT repaired** — the issue is filed, nothing is
fixed, and PLAN-023's own ledger is still 3 of them.

`doc-maintainer` remains **live on `operations`** and **paused on `framework`** —
not re-verified this session; re-derive with
`python3 -c "import json;[print(r, json.load(open(f'../{r}/.github/doc-maintainer.json'))['dry_run'], json.load(open(f'../{r}/.github/doc-maintainer.json'))['kill_switch']) for r in ('operations','framework')]"`.

Two lessons went to auto-memory, which is **gitignored and machine-local** — they
are safe on this host only: pin a Claim on the behaviour a plan preserves rather
than the line it deletes, and this repo's lack of a `pyproject.toml` means bare
`ruff` inherits the umbrella's config.
