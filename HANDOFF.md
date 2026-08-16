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
`main` is **12 commits above the tag**, tree clean, **46** open issues, **0** open
PRs. **None of the twelve reaches a consumer on `ci/v3.0.0`.** Re-derive with
`git log --oneline ci/v3.0.0..origin/main`.

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v3.0.0` |
| Tag points at | `git ls-remote --tags origin 'refs/tags/ci/v3.0.0^{}'` | `6d68b26` |
| Release is Latest | `gh api repos/vladm3105/aidoc-flow-ci/releases/latest --jq .tag_name` — **not** `--json isLatest`, which is not a field | `ci/v3.0.0` |
| Suite | `bash tests/run.sh \| sed 's/\x1b\[[0-9;]*m//g' \| grep -oE '[0-9]+ passed, [0-9]+ failed' \| awk '{p+=$1;f+=$3} END{print NR" suites, "p" passed, "f" failed"}'` | **19 suites, 1707 passed, 0 failed** |
| pre-commit | `pre-commit run --all-files` | exit 0 |
| Governance table | `python3 install/parse-governance-table.py CLAUDE.md --repo-root .` | PASS |
| markdownlint | `git ls-files '*.md' \| xargs npx markdownlint-cli2` — use `git ls-files`, **never** a `**/*.md` glob, which reaches the gitignored bootstrap scratch trees | 0 errors |
| Ledger gate baseline | `bash scripts/pre_push_check_ci.sh --ledger-only` | **79 failing rows, 14 of 15 gated plans** |
| Open issues | `gh issue list --state open --limit 200 --json number --jq 'length'` | **46** |
| Open PRs | `gh pr list --state open --json number --jq 'length'` | **0** |
| Stale in-progress markers | `gh issue view <N> --json labels` — **not** `gh issue list --label`, which reads a lagging search index and reported a label seconds after it was removed | **0** |

**`pre_push_check.sh` on `main` exits 1, and as of this session that is CORRECT
and no longer misleading.** The range is empty (`@{upstream}` IS `HEAD`), so it
prints `NOTHING VERIFIED — the push range is EMPTY`. It no longer claims an
OPS-0069 violation and no longer silently skips the linters behind a claim of
having run. **An OPS-0069 failure on a branch whose range is non-empty is a real
one, not this.**

## What this session did

**One merge: [#482](https://github.com/vladm3105/aidoc-flow-ci/pull/482) at
`cbe719b`, closing [#477](https://github.com/vladm3105/aidoc-flow-ci/issues/477).**
Canon and the shipped template had diverged on `BASE=`; the template carried the
pre-PLAN-015-M3 form, so any consumer adopting a tag installed a hook that
re-lints every pre-existing branch commit on every push. The copies are now
byte-for-byte identical, asserted with `cmp` by the new suite
`tests/test_pre_push_range.sh`, which executes **both** copies in scratch repos.
The `sed`-scoped hunk comparison in `test_sigpipe_guard.sh` that let the
divergence age is retired.

**The scope was deliberately CUT mid-session, and that is the part worth
knowing.** #432's fix was to make an empty push range exit 0. It was implemented
and withdrawn: two review cycles each **measured** an unreviewed commit reaching
a remote through it — once via `git push origin feat` from an up-to-date `main`,
once via multi-ref `git push origin a b`. What shipped is the message half only
(`NOTHING VERIFIED`, plus `GATE MALFUNCTION` for a failed `git diff`), with the
exit status left non-zero so no fail-open is reachable. Reasoning and the four
things a real fix needs are on
[#432](https://github.com/vladm3105/aidoc-flow-ci/issues/432), which stays open
and **keeps its `status:in-progress` marker** — it was advanced, not closed.

**One new issue, and it is the highest-value thing found:**
[#481](https://github.com/vladm3105/aidoc-flow-ci/issues/481).

## What to do next

Open issues are the backlog — do not restate them here:

```sh
gh issue list --state open --limit 200      # the --limit 30 default truncates silently
```

1. **[#481](https://github.com/vladm3105/aidoc-flow-ci/issues/481) — needs a
   DECISION and is the top item.** All four tier branch-protection templates
   require `call / Lint / format / security hooks`, whose only producer is
   `pre-commit.yml` — which #438's fix made `auto_install: false`. Bootstrap now
   installs `quick-gates.yml`, emitting the bare `quick-gates` context, which **no
   tier requires**. So a post-v3 cold start followed by
   `apply-standards.sh --apply` arms a context nothing installed produces: #438's
   brick, mirrored. #438 is closed COMPLETED and PLAN-026 §C0 documents the
   hazard in the **pre**-#438 direction (its Claims 13 and 22 are both now false),
   which is why it reads as handled. Decide whether §C0 is now a repair of the
   current state rather than a future phase. Re-derive:
   `python3 install/required-context-map.py .` and
   `grep -l 'quick-gates' install/templates/branch-protection-*.json` (no match).
2. **[#432](https://github.com/vladm3105/aidoc-flow-ci/issues/432) — a gate
   redesign, not a defect repair, and it needs a WIRING decision before code.**
   The multi-ref half **cannot be closed in canon** under the wiring consumers
   use: pre-commit consumes git's pre-push stdin itself and hands over only the
   first ref. Also needs branch deletions, tag pushes (`^{commit}`) and
   working-tree coverage. Full evidence in the issue.
3. **[#478](https://github.com/vladm3105/aidoc-flow-ci/issues/478) — the
   pre-commit fragment's marker was not bumped, and a bump alone will not fix
   it.** The refresh round-trips the *consumer's* body and stamps only the marker
   line, so comment corrections reach cold-start adopters only; `engramory`,
   `interlog` and `iplan-standard` carry the stale #474 text today. **Read the
   ledger-impact section before bumping** — `PLAN-023:1200` pins the `v2` string
   verbatim as its symbol, and PLAN-023 is gated, so the bump is a hard
   `symbol not found` that `--fix` cannot repair. Untouched this session:
   #482 changed `pre_push_check.sh`, not `pre-commit-hook-block.yaml`, so no
   marker bump was due. **Inherited, not re-verified this session.**
4. **[#455](https://github.com/vladm3105/aidoc-flow-ci/issues/455) — mechanical,
   still unstarted.** Its "nobody is broken today" claim is corrected in a comment
   (see #481). Its `manifest.json` `_note` half is safe now; land its
   `REPO_STANDARDS` §16 half **after** #481 settles, or it gets rewritten twice.
   **Not re-verified this session beyond the manifest read** — inherited.
5. **The 79-row ledger backlog has a reader but no repairs.** Run
   `bash scripts/pre_push_check_ci.sh --ledger-only`. Repair is per-plan and
   independent; `LEDGER_GATE_BLOCKING=1` enforces once a set is clean.
   **Re-pin drifted lines LAST, after code freeze** (#393).
6. **Wave 0 self-adoption.** Canon's pins are current but it runs the **v2
   architecture at a v3 pin** — `ls .github/workflows/ | grep -E 'quick-gates|scanners'`
   is empty and no caller invokes a composite action under `actions/`. The two
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
workflow. `.github/workflows/*` untouched. **`install/templates/pre_push_check.sh`
WAS touched** — manifest-walked, so it reaches consumers on the next tag; that is
the point of #477. No `doc-maintainer` / `docs-sync` / `ai-review` /
`secret-scan` behaviour. No plan file was edited, so the 79-row ledger baseline is
unchanged and no failing row cites a file this session touched.

`doc-maintainer` live on `operations` and paused on `framework` — **inherited from
the previous wrap, not re-verified this session.** Re-derive with
`.github/doc-maintainer.json` in each.

Lessons went to auto-memory, which is **gitignored and machine-local**
(`~/.claude/.gitignore:5`) — safe on this host only, not backed up. Read them
there; they are not restated here.
