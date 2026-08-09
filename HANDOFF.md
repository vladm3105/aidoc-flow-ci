# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**State:** `main` carries **#416** (PLAN-025 P1/P2/P3/P8-core), squashed
2026-08-09 · tree clean · **nothing deployed** — canon ships by tag, the last tag
is still `ci/v2.16.0`, and **37 merged PRs** are unreachable by any consumer ·
**32** open issues · **0** open PRs.

All checks green, **run on this merge commit, not carried forward**. Re-derive
every row; the commands are exact (see `CLAUDE.md` § Durable traps for why the
SGR strip and `--tier` are not optional):

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` |
| Unreleased **PRs** | `git log --oneline ci/v2.16.0..HEAD \| grep -cE '\(#[0-9]+\)$'` — count PRs, not commits; a wrap commit carries no `(#N)` and would inflate a `wc -l` | **37** |
| Suite | `bash tests/run.sh \| sed 's/\x1b\[[0-9;]*m//g' \| grep -oE '[0-9]+ passed, [0-9]+ failed' \| awk '{p+=$1;f+=$3} END{print NR" suites, "p" passed, "f" failed"}'` | **17 suites, 1,405 passed, 0 failed** |
| pre-commit | `pre-commit run --all-files` | 4 passed |
| Governance table | `python3 install/parse-governance-table.py CLAUDE.md --repo-root .` | PASS |
| Standards drift | `bash sync/check-standards-drift.sh --tier product` | 4/4 families, **2 drift** = the deliberate FT-52 profile |
| Open issues | `gh issue list --state open --limit 200 \| wc -l` | **32** |
| Open PRs | `gh pr list --state open \| wc -l` | **0** |

## What this session did

**Merged [#416](https://github.com/vladm3105/aidoc-flow-ci/pull/416)** — the v3
composite-action foundation, open since the previous session. It had gone
`CONFLICTING` when #420 and #421 landed. Merged with `--admin`; see Blockers for
why that was the only path.

**The merge itself produced the session's real finding, and neither PR could have
caught it.** §27 (CI-0033, never decide on a pipeline's exit status) landed on
`main` while `actions/` — v3's primary gate surface — was being built on the
branch. In one tree:

- `actions/sast-scan/action.yml`'s D23 post-condition, the verdict that refuses
  to scan when a PR-supplied `.semgrepignore` survives the strip, decided on
  `find … -print -quit | grep -q .`. **A reproduced fail-open** — not by EPIPE
  but by `find`'s own status: `-quit` returns non-zero when a traversal error is
  recorded before it quits, while still printing the match. Reachable, not
  certain; it turns on `readdir` order.
- The §27.2 scope named neither `actions/` nor most of what it did declare:
  `install/templates/**/*.sh` was globbed (4 files) while 31 `*.yml` consumer
  templates were not; `scripts/` was depth-1; `.github/workflows/` was `.yml`-only.

**The fix re-created its own defect three times before it held**, each attempt
reporting a fully green suite. The durable form is in auto-memory
(`a-check-must-not-derive-from-what-it-checks`): a check derived from the thing
it checks cannot detect that thing's truncation. Three overlapping anchors now
hold — a literal pin of the surface list, per-surface counts against `GUARDED`
itself, and an independent oracle requiring every action canon `uses:` to resolve
to a guarded file. Guard **60 → 120** assertions (baseline re-measured at
`354110c`; the `67` in the `CHANGELOG.md` entry was a mid-session figure and is
corrected there).

**Two claims I wrote into canon were corrected before push**, both caught by the
OPS-0066 cycle-2 review: a `1/1` reproduction ratio that was one observation in
the notation §27 reserves for repeated trials, and a §27.2 sentence claiming a
guard coverage that did not exist. §27 now carries the general rule that
`pipefail` is poisoned by the writer's **own** exit status too, so counting a
writer's `write(2)` calls is necessary and not sufficient.

Review: 3 agents, 2 OPS-0066 cycles. Cycle 1 found the fix had re-created its
defect class; cycle 2 found the cycle-1 fold had regressed it again.

Filed rather than folded: **[#422](https://github.com/vladm3105/aidoc-flow-ci/issues/422)**
(a pipeline wrapped after the `|` evades the guard's per-line match; the obvious
`sed` join false-positives on every `run: |`) and
**[#423](https://github.com/vladm3105/aidoc-flow-ci/issues/423)** (sast-scan's D23
post-condition checks `SCAN_PATH` only while the strip also clears the repo root;
latent while `scan-path` defaults to `.`).

## What to do next

The top item is actionable with no discovery.

1. **Take the founder decisions that gate everything else — nothing below moves
   without them.** Both are in Blockers with their reasons; both are founder-only,
   and one of them (FT-30) gates *every* tag, `v2.17.0` and `v3.0.0` alike. There
   is also an ordering call this session did not make and could not: **Phase A
   makes `main` a MAJOR**, so a `v2.17.0` carrying the CI-0033 fix must be cut
   **before** Phase A lands, or not at all. 37 merged PRs — CI-0033 among them, a
   *required* context on every workspace repo — are unreachable until one of them
   ships.
2. **PLAN-024 Phase A — unblocked by #416, but NOT ready to execute.** The plan
   reached `main` only with #416, so no earlier session could have started it.
   Read its header before anything else: `plans/PLAN-024_ci-flow-efficiency.md:3`
   is `**Status:** Draft — no phase executed`, and its own review log (`:759`)
   records *"Phase A carries two open 🔴/decision items for the human (§5 A4)"*.
   Treat it as prepare-and-propose, not execute.
   Phase A eliminates `doc-maintainer` from the library: 33 tracked files, 10 of
   the 11 open doc-maintainer defects closed as *not planned* (**#404 is carved
   out** — its defect survives verbatim in `docs-sync` and must be re-filed
   there), and a `ci/v3.0.0` MAJOR bump. **A4 is the trap:** the MAJOR-bump smoke
   gate requires `litellm-smoke.yml` to pass with the `ai-doc-maintainer` alias
   that A3 deletes, so `litellm-smoke.yml` must be edited *inside* the phase or
   the tag cannot be cut. `CHANGELOG.md`, `DECISIONS.md` and
   `docs/MIGRATION_v2.0.0.md` are append-only carve-outs and must not be scrubbed.
3. **PLAN-024's phase-level status is half-updated.** Its Status line already
   carries `superseded in part by PLAN-025 (D/E/F/G)` — #416 did that. What
   PLAN-025 §7 still owes is the marker on each `### Phase D/E/F/G` section
   (`:271, :293, :306, :316`) and the re-scoping of the surviving phases.

Open issues are the backlog — do not restate them here:

```sh
gh issue list --state open --limit 200      # the --limit 30 default truncates silently
```

## Blockers

Both release blockers are founder-only and unchanged from the last wrap.

| Blocker | Why | What clears it |
| --- | --- | --- |
| **🔴 FT-30 cold-start dry run** | `release.sh tag` refuses without `--dry-run-verified`, and the cold-start surface has changed. Re-derive: `git diff --name-only ci/v2.16.0..HEAD` against `coldstart_surface()` in `scripts/release.sh:91` | Founder runs `scripts/ft30-dry-run.sh` — see `CLAUDE.md` § Durable traps for what that script does and does not assert ([#358](https://github.com/vladm3105/aidoc-flow-ci/issues/358)) |
| **🔴 PR-C deviation confirmation still open** | Due before `ci/v2.17.0`. #405 shipped the demotion only, not the de-allowlisting §4 PR-C item 1 called for, while §9 item 2 records acceptance of *"both halves"* | Founder decision; reasoning in PLAN-021 §4 PR-C LANDED note |
| **PLAN-025 unreviewed since Pass 4** | OPS-0066 3-pass cap spent; P2/P3/P8 material never had an independent pass | Founder waiver, or a fresh plan for the remaining phases |
| **`semgrep` cannot install on the runner image** | No `python3-venv` ([#349](https://github.com/vladm3105/aidoc-flow-ci/issues/349)) — `sast-scan` is inert where it is the only SAST | Rebuild `aidoc-flow-runner:latest` |

**`call / verify` will red every canon PR until a tag containing CI-0033 exists.**
`.github/workflows/audit-trail.yml:39` pins `audit-trail-check.yml@ci/v2.16.0`,
the pre-fix copy, so the fix in `main`'s tree cannot reach the job that runs it —
verified in the #416 runner log as `line 103: echo: write error: Broken pipe`.
The documented `[skip-audit-trail]` override is inverted by the same defect and
does not help. `enforce_admins: false` exists for this; `--admin` is the path
until the tag. This is the FT-21 chicken-and-egg, not a defect in any branch.

**PLAN-025 P7 must not run** — unblocked by P8's core fix, but still the only
irreversible phase; P9 (rollback) must exist first.

The **PLAN-021 consumer resume** owes two easy-to-get-wrong edits; they are
durable and now live in `CLAUDE.md` § "The PLAN-021 consumer resume", not here.

## What did NOT change

No tag, no release, no consumer repo, no branch protection, no ruleset, no
`doc-maintainer` or `docs-sync` behaviour, and no `ai-review` behaviour.

**All four** new v3 caller templates (`quick-gates`, `quick-gates-private`,
`scanners`, `links-external`) still pin `ci/v3.0.0`, a tag that does not exist,
behind `sync-version-refs:ignore` markers that must be removed at the tag cut.
Count them, do not trust this line:
`grep -rlF 'ci/v3.0.0' install/templates/workflows/`.

`doc-maintainer` remains **live on `operations`** and **paused on `framework`** —
verified this wrap, re-derive with
`python3 -c "import json;[print(r, json.load(open(f'../{r}/.github/doc-maintainer.json'))['dry_run'], json.load(open(f'../{r}/.github/doc-maintainer.json'))['kill_switch']) for r in ('operations','framework')]"`.
Phase A deletes the library side of this regardless; the consumer-side removal is
each repo's own business.
