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
`main` is **10 commits above the tag**, tree clean, **46** open issues, **0** open
PRs. **None of the ten reaches a consumer on `ci/v3.0.0`.** Re-derive with
`git log --oneline ci/v3.0.0..origin/main`.

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v3.0.0` |
| Tag points at | `git ls-remote --tags origin 'refs/tags/ci/v3.0.0^{}'` | `6d68b26` |
| Release is Latest | `gh api repos/vladm3105/aidoc-flow-ci/releases/latest --jq .tag_name` — **not** `--json isLatest`, which is not a field | `ci/v3.0.0` |
| Suite | `bash tests/run.sh \| sed 's/\x1b\[[0-9;]*m//g' \| grep -oE '[0-9]+ passed, [0-9]+ failed' \| awk '{p+=$1;f+=$3} END{print NR" suites, "p" passed, "f" failed"}'` | **18 suites, 1620 passed, 0 failed** |
| pre-commit | `pre-commit run --all-files` | exit 0 |
| Governance table | `python3 install/parse-governance-table.py CLAUDE.md --repo-root .` | PASS |
| markdownlint | `git ls-files '*.md' \| xargs npx markdownlint-cli2` — use `git ls-files`, **never** a `**/*.md` glob, which reaches the gitignored bootstrap scratch trees | 71 files, 0 errors |
| Ledger gate baseline | `bash scripts/pre_push_check_ci.sh --ledger-only` | **79 failing rows, 14 of 15 gated plans** |
| Open issues | `gh issue list --state open --limit 200 --json number --jq 'length'` | **46** |
| Open PRs | `gh pr list --state open --json number --jq 'length'` | **0** |
| Stale in-progress markers | `gh issue list --state closed --label status:in-progress --json number --jq 'length'` | **0** |

**`pre_push_check.sh` is not in that table on purpose.** Run it on `main` and it
exits **1** — `origin/main..HEAD` is empty, so it reports a false OPS-0069 failure
**and silently skips every mechanical linter**. That is
[#432](https://github.com/vladm3105/aidoc-flow-ci/issues/432), not a red repo; the
tell is `no changed files vs base — skipping mechanical linters`. It is only
meaningful on a branch with commits ahead of `main`, where it exited 0 this
session. **An OPS-0069 failure on a branch whose range is non-empty is a real
one, not this.**

## What this session did

**One merge: [#479](https://github.com/vladm3105/aidoc-flow-ci/pull/479), closing
[#474](https://github.com/vladm3105/aidoc-flow-ci/issues/474).** Four surfaces
told consumers to build their `pre_push_check_<repo>.sh` wrapper by **sourcing**
canon; canon ends in `exit "$rc"`, so such a wrapper runs none of its extras and
exits 0. All four corrected to the subprocess form. The three ledger-pinned files
are **line-count-neutral** (267/260/74 unchanged), so no plan's Claim ledger
drifted — verified: no failing row cites any file the change touched.

**Two review findings mattered more than the original fix, and both reproduced
the defect class being fixed.** Kept here only as a pointer; the lessons are in
auto-memory:

- The first draft replaced the rc-accumulator requirement with a
  `REPO_STANDARDS §14.1` pointer. That file exists in **1** workspace repo; the
  script ships to **8**. The requirement is now stated in-file.
- §14.1's skeleton omitted its `set` line. Measured: `set -euo pipefail` aborts
  the wrapper before any extra runs and exits with canon's status —
  indistinguishable from the `source` bug. The corrected skeleton was extracted
  verbatim and executed against a red canon stub before shipping.

**Three issues filed, none fixed:** [#477](https://github.com/vladm3105/aidoc-flow-ci/issues/477),
[#478](https://github.com/vladm3105/aidoc-flow-ci/issues/478),
[aidoc-flow-operations#298](https://github.com/vladm3105/aidoc-flow-operations/issues/298).

## What to do next

Open issues are the backlog — do not restate them here:

```sh
gh issue list --state open --limit 200      # the --limit 30 default truncates silently
```

1. **[#477](https://github.com/vladm3105/aidoc-flow-ci/issues/477) — needs a
   DECISION, not a mechanical fix, and it is the highest-value item.** Canon
   `scripts/pre_push_check.sh` and the shipped
   `install/templates/pre_push_check.sh` have diverged on `BASE=`: the template
   ships the **pre-PLAN-015-M3** behaviour, so consumers re-lint every
   pre-existing branch commit on every push. It does not resolve cleanly —
   `@{upstream}` is exactly what produces #432's empty-range false failure, so
   delivering M3 hands consumers #432. Decide the intended behaviour against
   #432 first, then make both copies match. The durable half is replacing the
   single-hunk drift guard (`tests/test_sigpipe_guard.sh:390-394`, whose comment
   claims a general no-drift invariant its `sed` range does not cover) with a
   whole-file one.
2. **[#478](https://github.com/vladm3105/aidoc-flow-ci/issues/478) — the
   pre-commit fragment's marker was not bumped, and a bump alone will not fix
   it.** The refresh round-trips the *consumer's* body and stamps only the marker
   line, so comment corrections reach cold-start adopters only; `engramory`,
   `interlog` and `iplan-standard` carry the stale #474 text today. **Read the
   ledger-impact section before bumping** — `PLAN-023:1200` pins the `v2` string
   verbatim as its symbol, and PLAN-023 is gated, so the bump is a hard
   `symbol not found` that `--fix` cannot repair.
3. **[#455](https://github.com/vladm3105/aidoc-flow-ci/issues/455) — mechanical,
   unstarted, still true.** `install/templates/manifest.json:185` asserts
   `auto_install=true` on the line directly above `"auto_install": false`, and
   ships that way; `REPO_STANDARDS` §16 still names `pre-commit` as the
   bootstrap-tier producer. **Not re-verified this session** — inherited.
4. **The 79-row ledger backlog has a reader but no repairs.** Run
   `bash scripts/pre_push_check_ci.sh --ledger-only`. Repair is per-plan and
   independent; `LEDGER_GATE_BLOCKING=1` enforces once a set is clean.
   **Re-pin drifted lines LAST, after code freeze** (#393).
5. **Wave 0 self-adoption.** Canon's pins are current but it runs the **v2
   architecture at a v3 pin** — `ls .github/workflows/ | grep -E 'quick-gates|scanners'`
   is empty and no caller invokes a composite action under `actions/`. Canon
   dogfoods before Wave 1 pulls, and no consumer has repinned. The two
   easy-to-get-wrong PLAN-021 edits are in `CLAUDE.md` § "The PLAN-021 consumer
   resume", not here. **Inherited, not re-verified this session.**

## Blockers

| Blocker | Why | What would clear it |
| --- | --- | --- |
| **Runner image is stale on every host but this one** | Until each rebuilds, `scanners` is red on arrival there | [#458](https://github.com/vladm3105/aidoc-flow-ci/issues/458); the `gh`-pin half is [#435](https://github.com/vladm3105/aidoc-flow-ci/issues/435). **Inherited, not re-verified this session** |
| **PLAN-025 P7 must not run** | Still the only irreversible phase; P9 (rollback) must exist first. **P4** and **P5** are also not started | P9 landing. `docs/MIGRATION_v3.0.0.md` is the migration path, not the P5 documentation set. **Inherited** |
| **The ledger gate cannot become a CI job** | `check_plan.py` ships with the verified-planning Claude skill, not this repo; the ephemeral runners have no `~/.claude` | Vendoring it — a separate decision with its own drift surface. Until then the pre-push hook is the only reader that can exist |

## What did NOT change

No consumer repo, no branch protection, no ruleset, no required context, no
workflow. `.github/workflows/*` untouched. **`install/templates/*` WAS touched** —
`pre_push_check.sh` (manifest-walked, reaches consumers on the next tag) and
`pre-commit-hook-block.yaml` (does **not** propagate to adopted consumers — see
issue #478). No `doc-maintainer` / `docs-sync` / `ai-review` / `secret-scan`
behaviour.
No plan file was edited, so every plan's ledger is undisturbed — the 79-row
baseline is unchanged from the previous wrap.

`doc-maintainer` live on `operations` and paused on `framework` — **inherited
from the previous wrap, not re-verified this session.** Re-derive with
`.github/doc-maintainer.json` in each.

Lessons went to auto-memory, which is **gitignored and machine-local**
(`~/.claude/.gitignore:5`) — safe on this host only, not backed up. Read them
there; they are not restated here.
