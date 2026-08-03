# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

## What the last session did (2026-08-03)

Closed PLAN-023's two carried open items — [#370](https://github.com/vladm3105/aidoc-flow-ci/pull/370),
merged first attempt, 6/6 green. Doc-only; no code shipped.

**PLAN-023 is now ready for PR-0 through PR-3. PR-4 is half-ready.** That split
is the session's real output, and it is deliberate:

- **§9d closed and converged.** The F2 no-orphan self-check extension is decided
  as **option (a)** — extend `required-context-map.py` — and specified as four
  changes. The fourth is the one a fresh session would miss: `deploy-ci-wizard.sh`
  is the map's *other* consumer and filters rows on column 1 as a tier, so the
  ruleset glob would make it drop every ruleset row **while reporting "all
  producers installed"**. Iterate the *union* of branch-protection stems, ruleset
  stems and column-1 values — not column 1 alone, which drops `umbrella` instead.
- **§9e closed.** The meta-strip deferral was circular — PLAN-020's applier is its
  **Phase 3**, gated on "a second repo needing rulesets", which is PLAN-023. Closed
  by reusing the `jq walk` strip canon already ships.
- **§9f is NEW and deliberately OPEN — do not try to fold it.** The *shape* of the
  ruleset arming path changed answer twice under review and the second answer
  inherited most of what motivated the move. Its five questions (template source,
  safety contract, pre-arm sharing, create-vs-update, credential) are a design
  decision about a 🔴 cross-repo write, not authoring work. Nothing in PR-0..PR-3
  depends on them.

**The review pattern held for the third consecutive time on this plan.** Two
independent `verified-planning-reviewer` passes returned 17 load-bearing
findings, and **every one was a defect in the immediately preceding fold** — the
`CLAUDE.md` durable trap, reproduced. Both of *this* session's own folds were
caught: the first mis-specified bare-context resolution by job key (GitHub uses
`name:`) and broke the wizard; the second put the applier somewhere that has no
backup at all for a cross-repo write. **Budget a review pass for any fold here.**

Also corrected, because the closures orphaned them: §7 named branch protection as
M4's audit source *and required a PAT for the M4 row* two paragraphs after a
correction saying the opposite; §8 said `apply-standards.sh` takes "no change";
§13 said PR-4 extends PLAN-020 **Phase 1** (it extends Phase 3).

**One cross-plan edit is owed and NOT yet made:** `PLAN-020` Phase 3 still
prescribes `apply_rulesets()` in `apply-standards.sh`, the design §9e rejects. A
session reading PLAN-020 alone would implement it. PR-0 owns the supersession.

## Current state — re-derive, do not trust

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` |
| Open issues | `gh issue list --state open --limit 200` | **12** — #347–#355, #358, #360, #363 (unchanged) |
| Open PRs | `gh pr list --state open` | **0** |
| `## Unreleased` | `sed -n '/^## Unreleased/,/^## ci/p' CHANGELOG.md` | **non-empty** — 6 sections |
| Legacy queue | `wc -l plans/FRAMEWORK-TODO.md` | 1,968 |
| Fleet pins | `bash sync/check-pin-currency.sh --fleet vladm3105/aidoc-flow-{operations,framework,iplanic,engramory,iplan-standard,interlog,business} vladm3105/iplan-runner` | **not measured this session** — the flag needs the explicit repo list; with none it audits nothing and prints `0/0` |

`gh issue list` defaults to `--limit 30` and truncates silently.

## What to do next

1. **PLAN-021 (`plans/PLAN-021_doc-maintainer-dry-run-cluster.md`) — the top
   executable task.** READY, five PRs, start at PR-0. It is a **founder release**
   under OPS-0066's escape, not a converged review, so PR-by-PR review carries
   more weight than usual. The consumer's resume condition (`#352 AND #353`) is
   **insufficient** — `#360` must be added. #354 (the 200 KB refusal against a
   changelog that only grows) is part of this cluster. Resuming the pilot needs
   `kill_switch` flipped in **framework** (cross-repo, not owned by that plan).

2. **PLAN-023 PR-0** — `DECISIONS.md` **CI-0031** (reserved, not yet written; IDs
   are never reused). It records the conformance floor incl. M4a, the
   declared-deviation rule, the §5c PR-code-on-pool extension, the §3c ruleset
   arming model, the opt-in-vs-Allstar divergence — **and now the PLAN-020 Phase 3
   supersession above**.

   **Before writing PR-1, measure it:** run `ruff` + `mypy` over canon's ten
   Python modules. PR-1 adds those hooks under a *required* lint context, and the
   clean-up is unbounded until counted. Split PR-1 if it is large.

   **`REPO_STANDARDS` §24 is claimed by both PLAN-023 (PR-1) and PLAN-021.**
   PLAN-021 has priority; PLAN-023 yields and renumbers — §13.

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
   `docs-sync` from dry-run to live; **CI-0030's org migration**, decided but
   unscheduled — it needs its own plan; and **PLAN-023 §9f**, which is a design
   decision on a 🔴 write path rather than a coding task.

## Open threads

- **PLAN-023's deferred subsystems** — S3 database/service-container gate (blocked:
  the ephemeral runner has no Docker socket, so `services:` cannot work), S4
  release automation, S5 publish, S6 container build, S7 deploy, X1 provenance.
- **PLAN-008** — 29 findings from the 5-lens `ci/v2.0.0` review, grouped into 5 PRs.
- **PLAN-003 per-repo rollout waves** — wave status lives in operations
  `docs/CROSS_REPO_PLAYBOOKS.md` §T-D; do not hardcode a "next wave" here.
