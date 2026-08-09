# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**State:** `main` carries **#420** (CI-0033), squashed 2026-08-08 · tree clean ·
**nothing deployed** — canon ships by tag, the last tag is still `ci/v2.16.0`,
and #405, #414, #415, #420 are all merged and unreachable by any consumer ·
**30** open issues.

All checks green, **run on this merge commit, not carried forward**:

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` |
| Suite | `bash tests/run.sh \| sed 's/\x1b\[[0-9;]*m//g' \| grep -oE '[0-9]+ passed, [0-9]+ failed' \| awk '{p+=$1;f+=$3} END{print NR" suites, "p" passed, "f" failed"}'` — the SGR strip is required | **16 suites, 1,170 passed, 0 failed** |
| pre-commit | `pre-commit run --all-files` | 4 passed |
| Governance table | `python3 install/parse-governance-table.py CLAUDE.md --repo-root .` | PASS |
| Standards drift | `bash sync/check-standards-drift.sh --tier product` — `--tier` is required or it verifies 0/4 and exits 0 | 4/4 families, **2 drift** = the deliberate FT-52 profile |
| Open issues | `gh issue list --state open --limit 200` | **30** |
| Open PRs | `gh pr list --state open` | **1** — #416 |

## What this session did

**Merged [#420](https://github.com/vladm3105/aidoc-flow-ci/pull/420) — the
OPS-0069 audit-trail gate was reporting a false negative, and eleven other
guards had the same defect failing the other way.** Closes #417 and #418.
Decision `DECISIONS.md` **CI-0033**; rule `docs/REPO_STANDARDS.md` **§27**.

`writer | grep -q` under `set -o pipefail` reports **not found** exactly when the
string **was** found: `grep -q` exits on match, the writer takes `EPIPE`, and
`pipefail` makes that 141 the pipeline's answer. **It is not a size threshold** —
what matters is whether the writer has finished issuing its writes. A `printf`
builtin is clean at 40 KB; a multi-write process inverts at 8 KB. That is why the
local reproduction in #417 was correct and proved nothing.

**The asymmetry is the finding worth keeping:** twelve decisions in canon rode a
pipeline's status; the reported one is the only one that failed *closed*, and the
only one anybody noticed. The other eleven fail *open* — including the
`ai-review` autofix symlink-escape guard (PLAN-012 §4.4), measured missing the
symlink 4/5 at 401 staged files. All twelve converted.

**§26 is deliberately skipped** — it stays reserved for PLAN-023 PR-1, whose
eleven `§24` forward references still renumber onto it. A note at §27 says so;
do not renumber to close the gap. `DECISIONS.md` **CI-0031** likewise stays
reserved for PLAN-023 PR-0.

Filed rather than folded: **#419** (`pre_push_check.sh` reports an unwalkable
range as "no OPS-0069 phrase found", so the remedy it prints cannot work).

## What to do next

The top item is actionable with no discovery.

1. **Cut the release — this is now the bottleneck for everything else.** Four
   merged PRs are unreachable by consumers, CI-0033 among them, and it fixes a
   *required* context on every workspace repo. Blockers below are all
   release-gating. `docs/RELEASE_CHECKLIST.md`; a release-prep PR shows
   **BLOCKED by design** (FT-21) and `--admin` is the documented path.
2. **PLAN-024 Phases A/B/C** (PLAN-025 §7): eliminate `doc-maintainer`, reduce
   `docs-sync`, cut `ci/v3.0.0`. Phase A carries a **release-gate circularity** —
   the MAJOR-bump LiteLLM smoke tests the `ai-doc-maintainer` alias Phase A
   deletes, so `litellm-smoke.yml` must be edited inside the phase.
3. **PR #416** (`feat/v3-composite-actions`, PLAN-025 P1/P2/P3/P8-core) is open
   and still red on `call / verify`. **Expected, not a defect in the branch:**
   that caller pins `audit-trail-check.yml@ci/v2.16.0`, the pre-fix copy, and its
   38 KB commit range is what trips it. It clears once the branch runs against a
   tag containing CI-0033. Until then `--admin`. Re-derive: `gh pr checks 416`.

Open issues are the backlog — do not restate them here:

```sh
gh issue list --state open --limit 200      # the --limit 30 default truncates silently
```

## Blockers

All four are release-gating; the first two are founder-only.

| Blocker | Why | What clears it |
| --- | --- | --- |
| **🔴 FT-30 cold-start dry run** | `release.sh tag` refuses without `--dry-run-verified`. The changed cold-start surface has **grown well past the two files the previous wrap named** — now at least five under `install/templates/` (`doc-maintainer.json`, `labeler.yml`, `labels.json`, `pre_push_check.sh`, `runner/README.md`), plus nine shipped workflow templates. Re-derive: `git diff --name-only ci/v2.16.0..HEAD` against `coldstart_surface()` in `scripts/release.sh:91` | Founder runs `scripts/ft30-dry-run.sh`. Note it asserts the bootstrap COMPLETED, not that it installed the right file set (#358) |
| **🔴 PR-C deviation confirmation still open** | Due before `ci/v2.17.0`. #405 shipped the demotion only, not the de-allowlisting §4 PR-C item 1 called for, while §9 item 2 records acceptance of *"both halves"* — the shape that did not ship | Founder decision; reasoning in PLAN-021 §4 PR-C LANDED note |
| **PLAN-025 unreviewed since Pass 4** | OPS-0066 3-pass cap spent; P2/P3/P8 material never had an independent pass | Founder waiver, or a fresh plan for the remaining phases |
| **`semgrep` cannot install on the runner image** | No `python3-venv` (#349) — `sast-scan` is inert where it is the only SAST | Rebuild `aidoc-flow-runner:latest` |

**PLAN-025 P7 must not run** — unblocked by P8's core fix, but still the only
irreversible phase; P9 (rollback) must exist first.

**The PLAN-021 resume owes two consumer edits**, both easy to get wrong:
`operations` must edit **`auto_merge.low_risk_paths`**, *not* `allowed_paths`
(its `"*.md"` catch-all makes that a no-op), and must answer **`[k]`** at any
interactive `--update` drift prompt; and `framework`'s stale
`RESUME REQUIRES #352 AND #353` note needs **#354 and #360** added.

## What did NOT change

No tag, no release, no consumer repo, no branch protection, no ruleset, no
`doc-maintainer` or `docs-sync` behaviour. PR #416 and its branch are untouched
by this session. `doc-maintainer` is still **live on `operations`**
(`dry_run: false`) and still **paused on `framework`** (`kill_switch: true`), and
that pause still cites #352/#353 as resume-blockers, **both of which are closed**
— so it remains stale, as the previous wrap also noted.

*Routed out of this file rather than re-derived, per CI-0028 and #402: the
`pre_push_check`-vs-`pre-commit` gap and the "a verification narrower than its
claim is a false claim" lesson now live in `CLAUDE.md` § Durable traps, where a
regeneration cannot drop them. The #414 cancelled-runner signature was already
routed there by the previous wrap and is not repeated.*
