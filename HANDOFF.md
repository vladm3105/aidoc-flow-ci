# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

## What the last session did (2026-07-31)

Implemented `plans/PLAN-022_doc-surface-governance.md` in two PRs.

| PR | Ground truth |
|---|---|
| [#356](https://github.com/vladm3105/aidoc-flow-ci/pull/356) | Landed PLAN-022 (**READY**) and PLAN-021 (**NOT READY** — a record, not an authorisation) |
| [#357](https://github.com/vladm3105/aidoc-flow-ci/pull/357) | `DECISIONS.md` **CI-0028**, the corrected `CLAUDE.md` governance table, a `CHANGELOG.md` entry |

**CI-0028 in one line:** a changelog is permanent and takes an *anchored insert*
under its Unreleased heading; a handoff is disposable and is *fully regenerated*,
with every volatile claim carrying its re-deriving command; the backlog is the
repo's open issues. Feedback is a direction of travel, not a class of issue — so
no `kind:*` label family.

What changed about this repo, not only about the rules:

- **The governance table stopped being false.** It declared the backlog surface
  *"Not adopted"* while `plans/FRAMEWORK-TODO.md` held 1,968 lines. It now names
  `plans/` + GitHub issues, plus a second row declaring the legacy queue still
  live — a table describes what *is*.
- **Governance rows are machine-parsed.** The row PLAN-022 originally prescribed
  was prose, and prose parses as a path: it took
  `install/parse-governance-table.py` from `errors: []` to `path-not-found`.
  Write rows as `` `path` (annotation) `` and verify before pushing.
- **Three defects were filed, not fixed** — see the next-steps list below for
  #355 and #358; the third is
  [aidoc-flow-operations#291](https://github.com/vladm3105/aidoc-flow-operations/issues/291),
  the intake contract's now-incomplete "(TODO file declined)" row for this repo.
- **This file went from 1,393 lines to this.** Its durable content was graduated
  to `CLAUDE.md` § "Durable traps"; its "Recent decisions" excerpt was deleted —
  it sat at CI-0011 while CI-0012..CI-0024 landed, contradicting the top of its
  own file.

## Current state — re-derive, do not trust

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0`, marked Latest |
| Open issues | `gh issue list --state open --limit 200` | **10** — #347–#355, #358 |
| Open PRs | `gh pr list --state open` | 0 |
| `## Unreleased` | `sed -n '/^## Unreleased/,/^## ci/p' CHANGELOG.md` | **non-empty** — holds CI-0028; a cut promotes it |
| Legacy queue | `wc -l plans/FRAMEWORK-TODO.md` | 1,968 |
| Fleet pins | `bash sync/check-pin-currency.sh --fleet vladm3105/aidoc-flow-{operations,framework,iplanic,engramory,iplan-standard,interlog,business} vladm3105/iplan-runner` | **7 of 8 stale.** `framework` alone is current (16/16 at `ci/v2.16.0`); `operations` is oldest-at-`ci/v2.0.1`, the other six oldest-at-`ci/v1.9.5` |

`gh issue list` defaults to `--limit 30` and truncates silently — pass
`--state all --limit 200` or the count above is not reproducible.

**No release is pending and nothing is owed.** A cut is optional. If you take
one, read `CLAUDE.md` § "Durable traps" first — a prep PR shows BLOCKED by
design, and `--repin` cannot deliver a caller-body change.

## What to do next

1. **`doc-maintainer` is broken and its pilot is paused.** Four defects converge
   on the dry-run path: [#352](https://github.com/vladm3105/aidoc-flow-ci/issues/352)
   (the patch renderer dies on the normal case),
   [#353](https://github.com/vladm3105/aidoc-flow-ci/issues/353) (a duplicate
   reports as an allowlist violation, naming a path that *is* allowlisted — 9 of
   the consumer's 23 recorded failures; the plan warns that count is
   retry-weighted and must be re-derived by distinct merge),
   [#354](https://github.com/vladm3105/aidoc-flow-ci/issues/354) (the 200 KB
   refusal against a changelog that only grows), plus one still to file (the
   planner inventory ignores `allowed_paths`).
   `plans/PLAN-021_doc-maintainer-dry-run-cluster.md` is the plan and reads
   **NOT READY**: it stopped at the OPS-0066 review cap with one founder item
   open (§9 item 2), and its own status line forbids implementation. Resolve
   that item, run the pass, then implement. `CI-0027` is reserved for it.
2. **Wire the governance check**
   ([#355](https://github.com/vladm3105/aidoc-flow-ci/issues/355)). Small, and it
   closes the hole that let the governance table stay false for weeks: nothing in
   `.github/workflows/` invokes `apply-standards.sh`, so `governance_check` runs
   only by hand. Fix shape is in the issue — have
   `sync/check-standards-drift.sh` reach it, warning-only per the drift contract.
3. **FT-58 — retire `plans/FRAMEWORK-TODO.md`.** Cut from PLAN-022 (§5) because
   its routing rule was not decidable from the data. One open decision: where a
   below-promotion-bar entry goes once the queue file is deleted. Do **not**
   reuse the earlier triage buckets — they were derived under a rule a `plans/`
   sweep falsified; the raw work is in git at `25912f9`.
4. **The other open issues:** #347 / #348 (doc accuracy — the `UPDATE_GUIDE`
   worked example and the #329 allowlist comment), #349 (`sast-scan` cannot
   install semgrep on the self-hosted pool — no python in the image), #350
   (`set-litellm-secrets.sh --doc` overwrites a working URL), #351
   (pin-currency's verdict is unreachable to consumers, and two paths in one
   script disagree), #358 (`ft30-dry-run.sh` asserts the bootstrap completed,
   not that it installed the right file set).
5. **Founder-gated — do not execute as an AI (🔴):** PLAN-007 W4, arming the
   gates as required checks across the fleet
   (`docs/FLEET_BRANCH_PROTECTION_ARMING.md`) — the highest-value remaining step,
   since it makes the blocking checks actually block; and W3, taking `docs-sync`
   from dry-run to live, which needs the `aidoc-flow-bot` App or a fold into
   `doc-maintainer.yml`.

## Open threads

- **PLAN-008 pre-prod gap closure** — 29 findings from the 5-lens review of the
  `ci/v2.0.0` surface, grouped into 5 PRs
  (`plans/PLAN-008_pre-prod-gap-closure.md`).
- **PLAN-003 per-repo rollout waves** — one PR per non-paused repo. Wave status
  lives in operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D; do not hardcode a
  "next wave" here, it drifts. Gate: zero drift from the curl-piped
  `apply-standards.sh --check`.
