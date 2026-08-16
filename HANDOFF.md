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
`main` was **8 commits above the tag**, tree clean, **45** open issues, **0** open
PRs. **None of the eight reaches a consumer on `ci/v3.0.0`** — re-derive with
`git log --oneline ci/v3.0.0..origin/main`. This session's merge touched no
`install/templates/*` and no `.github/workflows/*`.

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v3.0.0` |
| Tag points at | `git ls-remote --tags origin 'refs/tags/ci/v3.0.0^{}'` | `6d68b26` |
| Release is Latest | `gh api repos/vladm3105/aidoc-flow-ci/releases/latest --jq .tag_name` — **not** `--json isLatest`, which is not a field | `ci/v3.0.0` |
| Suite | `bash tests/run.sh \| sed 's/\x1b\[[0-9;]*m//g' \| grep -oE '[0-9]+ passed, [0-9]+ failed' \| awk '{p+=$1;f+=$3} END{print NR" suites, "p" passed, "f" failed"}'` | **18 suites, 1620 passed, 0 failed** |
| pre-commit | `pre-commit run --all-files` | exit 0 |
| Governance table | `python3 install/parse-governance-table.py CLAUDE.md --repo-root .` | PASS |
| markdownlint | `git ls-files '*.md' \| xargs markdownlint-cli2` | 70 files, 0 errors |
| Open issues | `gh issue list --state open --limit 200 --json number --jq 'length'` | **45** |
| Open PRs | `gh pr list --state open --json number --jq 'length'` | **0** |
| Stale in-progress markers | `gh issue list --state closed --label status:in-progress --json number --jq 'length'` | **0** |

**Lint markdown via `git ls-files`, not a `**/*.md` glob.** The glob reaches the
gitignored `aidoc-flow-ci-bootstrap-*/` scratch trees and reports errors that are
not this repo's. Cost one false red at this wrap.

**`pre_push_check.sh` is not in that table on purpose.** Run it on `main` and it
exits **1** — `origin/main..HEAD` is empty, so it reports a false OPS-0069 failure
**and silently skips every mechanical linter**. That is
[#432](https://github.com/vladm3105/aidoc-flow-ci/issues/432), not a red repo; the
tell is `no changed files vs base — skipping mechanical linters`. It is only
meaningful on a branch with commits ahead of `main`, where it exited 0 this
session. **An OPS-0069 failure on a branch whose range is non-empty is a real
one, not this.**

## What this session did

**One merge: [#475](https://github.com/vladm3105/aidoc-flow-ci/pull/475), closing
[#469](https://github.com/vladm3105/aidoc-flow-ci/issues/469).** `check_plan.py`
now has a reader — `scripts/pre_push_check_ci.sh`, the
`pre_push_check_<repo>.sh` wrapper §14.1 has described since PLAN-002 §4.8 and
this repo never had. Wired as an **advisory** `pre-push` hook.

**The scoping decision, which #469 did not anticipate.** It framed the choice as
baseline-vs-repair. Re-deriving first found a third option, and that is what
shipped:

- **Part of "156 rows" was an invocation artifact.** `check_plan.py` takes a
  repeatable `--root`; without the workspace root, cross-repo citations cannot
  resolve. Passing it clears **23 rows** with no plan edited.
- **The live plans were already clean.** PLAN-024/025/026 — the plans governing
  remaining v3 work — have **zero** failing citation rows.

So: exempt plans whose `Status:` marks them finished, fail closed on everything
else, advisory first. **Unit is failing rows, not ledger size** (PLAN-004's
ledger alone is 61 rows): 23 ledger-bearing plans → 8 exempt / 15 gated; **14 of
15 gated fail** — 79 citation rows across 11, plus 6 review-log defects in 3.

**Pre-push review found that the gate reproduced #469 three times over**, and all
three are folded. Kept here only as a pointer, because the lesson is in
auto-memory and §14.1: an advisory hook without `verbose: true` prints one word
and discards its output; `LEDGER_GATE_BLOCKING=1` did not block; and `rc=0` from
`check_plan.py` also means *"not a gated plan; skipped"*.

**[#474](https://github.com/vladm3105/aidoc-flow-ci/issues/474) filed** — five
surfaces told consumers a wrapper should **`source`** canon. Canon ends in
`exit "$rc"`, so a wrapper built as documented runs **none** of its extras and
exits 0. `.pre-commit-config.yaml` is fixed in #475; **four remain**, two of them
canon body. PLAN-002 §4.8's reference block was always correct — only the prose
contradicted it.

## What to do next

Open issues are the backlog — do not restate them here:

```sh
gh issue list --state open --limit 200      # the --limit 30 default truncates silently
```

1. **[#474](https://github.com/vladm3105/aidoc-flow-ci/issues/474) — mechanical,
   and the highest-value thing left.** Four surfaces still prescribe the broken
   wrapper: `scripts/pre_push_check.sh:17`,
   `install/templates/pre_push_check.sh:17`,
   `install/templates/pre-commit-hook-block.yaml:38`, `docs/local-pre-push.md:90`.
   The middle two are **canon body** and ship on the next tag. Correct wording is
   in `REPO_STANDARDS` §14.1.
2. **[#455](https://github.com/vladm3105/aidoc-flow-ci/issues/455) — the rulebook
   half of #441.** Mechanical. `install/templates/manifest.json:185` still asserts
   `auto_install=true` on the line directly above `"auto_install": false`, and
   ships that way to consumers; `REPO_STANDARDS` §16 still names `pre-commit` as
   the bootstrap-tier producer.
3. **The 79-row ledger backlog now has a reader but no repairs.** Run
   `bash scripts/pre_push_check_ci.sh --ledger-only` for the current rows. Repair
   is per-plan and independent; `LEDGER_GATE_BLOCKING=1` enforces once a set is
   clean. **Re-pin drifted lines LAST, after code freeze** (#393).
4. **Wave 0 self-adoption.** Canon's pins are current but it runs the **v2
   architecture at a v3 pin** — `ls .github/workflows/ | grep -E
   'quick-gates|scanners'` is empty and no caller invokes a composite action under
   `actions/`. Canon dogfoods before Wave 1 pulls, and no consumer has repinned.
   The two easy-to-get-wrong PLAN-021 edits are in `CLAUDE.md` § "The PLAN-021
   consumer resume", not here.
5. **[#456](https://github.com/vladm3105/aidoc-flow-ci/issues/456)** — three docs
   still framed around the pre-tag state. Not re-verified this session.

## Blockers

| Blocker | Why | What would clear it |
| --- | --- | --- |
| **Runner image is stale on every host but this one** | Until each rebuilds, `scanners` is red on arrival there | [#458](https://github.com/vladm3105/aidoc-flow-ci/issues/458); the `gh`-pin half is [#435](https://github.com/vladm3105/aidoc-flow-ci/issues/435). **Inherited, not re-verified this session** |
| **PLAN-025 P7 must not run** | Still the only irreversible phase; P9 (rollback) must exist first. **P4** and **P5** are also not started | P9 landing. `docs/MIGRATION_v3.0.0.md` is the migration path, not the P5 documentation set |
| **The ledger gate cannot become a CI job** | `check_plan.py` ships with the verified-planning Claude skill, not this repo; the ephemeral runners have no `~/.claude` | Vendoring it — a separate decision with its own drift surface. Until then the pre-push hook is the only reader that can exist |

## What did NOT change

No consumer repo, no branch protection, no ruleset, no required context, no canon
workflow, template or script. `install/templates/*` and `.github/workflows/*` are
untouched, so **nothing this session reaches a consumer on the next tag** — the
one consumer-read surface edited is `docs/REPO_STANDARDS.md` §14.1. No
`doc-maintainer` / `docs-sync` / `ai-review` / `secret-scan` behaviour. No plan
file was edited, so every other plan's ledger is undisturbed.

`doc-maintainer` live on `operations` and paused on `framework` — **inherited
from the previous wrap, not re-verified this session.** Re-derive with
`.github/doc-maintainer.json` in each.

**#469's rows are unrepaired** — the issue is closed because it asked for a
reader, and the reader exists. The 79 rows are the follow-on work in item 3.

Lessons went to auto-memory, which is **gitignored and machine-local** — safe on
this host only, not backed up. Read them there; they are not restated here.
