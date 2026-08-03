# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

## What the last session did (2026-08-03)

Cleared the dependabot queue. Three PRs, three merges, no decisions taken and no
plan advanced — the tracker is now empty of PRs.

| PR | Ground truth |
|---|---|
| [#364](https://github.com/vladm3105/aidoc-flow-ci/pull/364) | `codeql-action` 4.37.3 → 4.37.4 across 7 call sites. Merged as-is. |
| [#365](https://github.com/vladm3105/aidoc-flow-ci/pull/365) | `upload-artifact` 4.6.2 → **7.0.1**. Merged with a test fix + node24 floor docs. |
| [#366](https://github.com/vladm3105/aidoc-flow-ci/pull/366) | `labeler` 6.2.0 → **7.0.0**. Merged with the four docs that named `@v6`. |

Things discovered that change the picture:

- **A contract test was pinning an action version under a behaviour name.**
  `tests/test_contract.sh` asserted the literal `upload-artifact@.*# v4.6.2`
  under the name "doc-maintainer preserves dry-run patches as an artifact" — so
  it failed on a bump that changed nothing it claimed to cover, and it was the
  sole reason #365 was red. Rewritten to assert the step (one `upload-artifact`
  step, path `.doc-maintainer-proposed.patch`, `if-no-files-found: error`) and
  mutation-checked both ways. **This was a one-off, not a class** — verified with
  `grep -rnE '# v[0-9]+\.[0-9]+|@v[0-9]+' tests/*.sh`, whose only remaining hits
  are a fixture and a comment. Do not go hunting for more.
- **`actions/upload-artifact` v6+ now carries the node24 runner floor** and was
  on none of the three lists that enumerate it. Added to `docs/runners.md`,
  `install/templates/runner/README.md`, `docs/troubleshooting.md` §19. The floor
  itself (Actions Runner >= 2.327.1) is unchanged — `download-artifact` v7+
  already required it — but a pool below it now fails in `doc-maintainer` as
  well as `ai-review`.
- **The artifact backend is unchanged across upload-artifact v5–v7**, so the
  pairing with `download-artifact@v8` in `ai-review.yml` still holds. This is the
  FT-39/#222 asymmetry concern in the opposite direction; it was checked before
  merging, not after.
- **`labeler` v7 is an ESM migration and nothing else** — no input change, no
  config-format change. `.github/labeler.yml` stays on the v5+ shape, so no
  consumer edits anything.

**Both majors merged WITHOUT an OPS-0065 multi-agent review.** The session's
operating directive prohibited dispatching sub-agents, so the commits carry
`Self-review skipped per founder OK` naming that reason. Per `CLAUDE.md`, the
gate matches the phrase and not the work — these two have the local suite, a
two-mutant check and the upstream release notes behind them, and nothing
adversarial. If that is not good enough, re-review `28631e4` and `08d5cb5`.

## Current state — re-derive, do not trust

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` |
| Open issues | `gh issue list --state open --limit 200` | **12** — #347–#355, #358, #360, #363 (unchanged this session) |
| Open PRs | `gh pr list --state open` | **0** |
| `## Unreleased` | `sed -n '/^## Unreleased/,/^## ci/p' CHANGELOG.md` | **non-empty** — 5 sections: 2 dependency, CI-0028, CI-0029/0030, #355 docs |
| Legacy queue | `wc -l plans/FRAMEWORK-TODO.md` | 1,968 |
| Fleet pins | `bash sync/check-pin-currency.sh --fleet vladm3105/aidoc-flow-{operations,framework,iplanic,engramory,iplan-standard,interlog,business} vladm3105/iplan-runner` | **not measured this session** — the flag needs the explicit repo list; with none it audits nothing and prints `0/0` |

`gh issue list` defaults to `--limit 30` and truncates silently.

## What to do next

1. **PLAN-023 is NOT READY — close its 2 items before starting PR-0.** Both are
   authoring work, neither is a decision:
   - **§9d** — extend canon's F2 no-orphan self-check to ruleset-armed contexts.
     `required-context-map.py` enumerates only `branch-protection-*.json`, and
     the gate job's context is a *bare* name it classifies `?non-call` and does
     not resolve. §9d recommends extending the map over a standalone check.
   - Confirm the `ruleset-test-gate.json` meta-strip once PLAN-020's applier
     lands (a conditional close, not a close).

   **Before writing PR-1, measure it:** run `ruff` + `mypy` over canon's ten
   Python modules. PR-1 adds those hooks under a *required* lint context, and
   the clean-up is unbounded until counted. Split PR-1 if it is large.

   **`REPO_STANDARDS` §24 is claimed by both PLAN-023 (PR-1) and PLAN-021**,
   which is READY while PLAN-023 is not. PLAN-023 yields and renumbers — §13.

   **CI-0031 is reserved** by PLAN-023 PR-0 and not yet written. IDs are never
   reused.

2. **PLAN-021 (`plans/PLAN-021_doc-maintainer-dry-run-cluster.md`) — the top
   *executable* task; item 1 is ordered ahead of it only because it gates its own
   plan.** READY, five PRs, start at PR-0. It is a **founder release** under
   OPS-0066's escape, not a converged review, so PR-by-PR review carries more
   weight than usual. The consumer's resume condition (`#352 AND #353`) is
   **insufficient** — `#360` must be added. #354 (the 200 KB refusal against a
   changelog that only grows) is part of this cluster. Resuming the pilot needs
   `kill_switch` flipped in **framework** (cross-repo, not owned by that plan).

3. **Wire the governance check**
   ([#355](https://github.com/vladm3105/aidoc-flow-ci/issues/355)). Small, and it
   closes the hole that let the governance table stay false for weeks: nothing in
   `.github/workflows/` invokes `apply-standards.sh`.

4. **The other open issues:** #363 (the 11-job fan-out pays a full
   ephemeral-runner provisioning cycle per job, ~13% of wall clock on a green
   run), #347/#348 (doc accuracy), #349 (`sast-scan` cannot install semgrep — the
   image HAS python3; it lacks `python3-venv`/`ensurepip`, so `python3 -m venv`
   fails), #350, #351, #358.

5. **Founder-gated 🔴 — do not execute as an AI:** arming the gates as required
   checks across the fleet (`docs/FLEET_BRANCH_PROTECTION_ARMING.md`); taking
   `docs-sync` from dry-run to live; and **CI-0030's org migration**, decided but
   unscheduled — it needs its own plan. Scope and price: `DECISIONS.md` CI-0030.

## Open threads

- **PLAN-023's deferred subsystems** — S3 database/service-container gate (blocked:
  the ephemeral runner has no Docker socket, so `services:` cannot work), S4
  release automation, S5 publish, S6 container build, S7 deploy, X1 provenance.
- **PLAN-008** — 29 findings from the 5-lens `ci/v2.0.0` review, grouped into 5 PRs.
- **PLAN-003 per-repo rollout waves** — wave status lives in operations
  `docs/CROSS_REPO_PLAYBOOKS.md` §T-D; do not hardcode a "next wave" here.
