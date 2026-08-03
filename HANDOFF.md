# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

## What the last session did (2026-08-03)

Founder direction: turn this repo into the company CI/CD standard covering
public + private repos, labelling, scanners and security. A survey found the
**gates** half mature (21 reusables) and the **delivery** half absent — **no
canon reusable builds, tests, packages or deploys anything.** Decomposed into
nine subsystems; specified the first.

| PR | Ground truth |
|---|---|
| [#367](https://github.com/vladm3105/aidoc-flow-ci/pull/367) | `plans/PLAN-023` (Draft, NOT READY), `DECISIONS.md` **CI-0029** + **CI-0030**, CHANGELOG |

**PLAN-023 is deliberately narrow.** `pre-commit.yml` already runs whatever hooks
a repo declares, so lint/typecheck are reused, not reimplemented; the new
surfaces are install → build → test → measure only. The unit of conformance is
**evidence, not implementation** — a repo may replace the workflow entirely and
stay conformant if it emits the same JUnit + coverage + structured evidence.
That is what lets "each repo adds its own flows" hold without dissolving the
standard.

Things discovered that change the picture:

- **A skipped job satisfies a required check.** Canon's own `ai-review` records
  it (`.github/workflows/ai-review.yml`, "a skipped-job green would SUPERSEDE a
  prior `request_changes`"). So `fork-strategy: skip` on a
  required gate is a **bypass**, not a safety setting. Floor rule M4a (an
  always-running gate job) exists because of this, and it applies to **any**
  canon flow that becomes a required context — not just the test gate.
- **Rulesets are a surface canon does not touch.** Zero `ruleset` references in
  `apply-standards.sh`, `install.sh`, `sync/*.sh`. A required check placed in a
  repo ruleset therefore survives the branch-protection PUT that clobbers
  hand-added contexts. Verified by probe on a private repo — no plan gating.
  Details and the exact bypass payload: `DECISIONS.md` **CI-0029**.
- **`GET /rulesets` is not admin-class** — returns data on `actions/checkout`.
  This closes an open question PLAN-020 flagged as unverified.
- **PLAN-020 Phase 1 / FT-55 already owns ruleset canon.** Do not build a second
  template family; PLAN-023 PR-4 extends it.
- **`enforce_admins: false` is not fleet-wide**, so a ruleset admin bypass is
  inert on some repos — commands and measurements in PLAN-023 §15.

## Current state — re-derive, do not trust

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` |
| Open issues | `gh issue list --state open --limit 200` | **12** — #347–#355, #358, #360, #363 |
| Open PRs | `gh pr list --state open` | **3** — all dependabot (#364, #365, #366) |
| `## Unreleased` | `sed -n '/^## Unreleased/,/^## ci/p' CHANGELOG.md` | **non-empty** — CI-0028, CI-0029, CI-0030 |
| Legacy queue | `wc -l plans/FRAMEWORK-TODO.md` | 1,968 |
| Fleet pins | `bash sync/check-pin-currency.sh --fleet vladm3105/aidoc-flow-{operations,framework,iplanic,engramory,iplan-standard,interlog,business} vladm3105/iplan-runner` | **not measured this session** — the flag needs the explicit repo list; with none it audits nothing and prints `0/0` |

`gh issue list` defaults to `--limit 30` and truncates silently.

## What to do next

1. **Clear the three dependabot PRs.** **Two are majors — read their changelogs
   before merging, do not batch them:** #366 `actions/labeler` 6.2.0 → 7.0.0, and
   #365 `actions/upload-artifact` 4.6.2 → **7.0.1** (three majors, with live call
   sites in `ai-review.yml` and `doc-maintainer.yml`). **#364 alone is routine**
   (codeql-action group, 4.37.3 → 4.37.4).

2. **PLAN-023 is NOT READY — close its 2 items before starting PR-0.** Both are
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

3. **PLAN-021 (`plans/PLAN-021_doc-maintainer-dry-run-cluster.md`) — the top
   *executable* task; items 1-2 are ordered ahead of it only because they are
   cheap or gate their own plan.** READY, five PRs, start at PR-0. It is a **founder release** under OPS-0066's escape, not a converged
   review, so PR-by-PR review carries more weight than usual. The consumer's
   resume condition (`#352 AND #353`) is **insufficient** — `#360` must be added. #354 (the 200 KB refusal against a
   changelog that only grows) is part of this cluster.
   Resuming the pilot needs `kill_switch` flipped in **framework** (cross-repo,
   not owned by that plan).

4. **Wire the governance check** ([#355](https://github.com/vladm3105/aidoc-flow-ci/issues/355)).
   Small, and it closes the hole that let the governance table stay false for
   weeks: nothing in `.github/workflows/` invokes `apply-standards.sh`.

5. **The other open issues:** #363 (new — the 11-job fan-out pays a full
   ephemeral-runner provisioning cycle per job, ~13% of wall clock on a green
   run), #347/#348 (doc accuracy), #349 (`sast-scan` cannot install semgrep — the image HAS
   python3; it lacks `python3-venv`/`ensurepip`, so `python3 -m venv` fails), #350, #351, #358.

6. **Founder-gated 🔴 — do not execute as an AI:** arming the gates as required
   checks across the fleet (`docs/FLEET_BRANCH_PROTECTION_ARMING.md`); taking
   `docs-sync` from dry-run to live; and **CI-0030's org migration**, decided
   but unscheduled — it needs its own plan. Scope and price: `DECISIONS.md`
   CI-0030.

## Open threads

- **PLAN-023's deferred subsystems** — S3 database/service-container gate (blocked:
  the ephemeral runner has no Docker socket, so `services:` cannot work), S4
  release automation, S5 publish, S6 container build, S7 deploy, X1 provenance.
- **PLAN-008** — 29 findings from the 5-lens `ci/v2.0.0` review, grouped into 5 PRs.
- **PLAN-003 per-repo rollout waves** — wave status lives in operations
  `docs/CROSS_REPO_PLAYBOOKS.md` §T-D; do not hardcode a "next wave" here.
