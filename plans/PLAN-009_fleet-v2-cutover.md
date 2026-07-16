# PLAN-009 — Sync the aidoc-flow fleet to CI canon `ci/v2.0.1`

> Status: EXECUTING — **Phase 0 partially done**; `operations` advanced to
> `@ci/v2.0.1` + live-verified 2026-07-16 (PR #265; runbook
> `operations/ops/inbox/2026-07-16_founder_operations-ci-v2.0.1-advance-and-verify.md`,
> PR #264). Remaining 🔴 Phase-0 items (LiteLLM secrets on the 4 **public** repos;
> `ci-runner,single-use` pools on business/iplanic/interlog) are staged in
> `operations/ops/inbox/2026-07-14_founder_flow-ci-v2-fleet-cutover-prereqs.md`
> and gate Phase 1. Owning repo: `aidoc-flow-ci` (fleet
> CI canon). Per-consumer execution lands as `IPLAN-NNNN` in each consumer repo,
> mirroring `operations/ops/iplans/IPLAN-0033`. Verified against live files +
> live `gh` state (secrets/runners/vars, names only) 2026-07-16.
>
> **Retargeted to `ci/v2.0.1` (2026-07-15, commit
> `819d148e366f4f469f3645d1bfb249e3a1e9cf13`).** v2.0.1 is a patch superseding
> v2.0.0 that fixes 3 verified ai-review blockers from the pre-prod review — the
> `request_changes` jq-validation bug, the `pull_request_review` RED→GREEN bypass,
> and the `python3` preflight (`CHANGELOG.md` § ci/v2.0.1). The fleet now pins
> **`@ci/v2.0.1`**; v2.0.0 remains the breaking v1→v2 release (unchanged config
> schema / secrets / runner-label contract — v2.0.1 is a drop-in re-pin).

## Context

The workspace CI canon is **`aidoc-flow-ci`**; consumers pin
`uses: vladm3105/aidoc-flow-ci/.github/workflows/<file>.yml@ci/vX.Y.Z`.
The canon released **`ci/v2.0.0`** (2026-07-13) — a **breaking** release that
unifies all AI jobs behind one LiteLLM proxy (removes vendor-CLI paths),
introduces config-schema v2, adds a functional `doc-maintainer`, hardens
secret-scan/links/markdown-lint, and (for private repos) replaces the v1 runner
label `["self-hosted","aidoc","ci-ephemeral"]` with
`["self-hosted","ci-runner","single-use"]`.

**`operations` already cut over to v2.0.0** (PRs #258/#259/#260, IPLAN-0033) and
**advanced to `@ci/v2.0.1` on 2026-07-16** (PR #265) — **not** a version-only
`--repin`: its `check-ci-contract.sh` contract-lock hard-pinned v2.0.0, so the
lock + `standards-drift.yml` (`ref` + `--ci-tag`) + `config.json` `$schema` moved
in lockstep (see the note under Current state). The other
**seven** consumers are still on `@ci/v1.9.5`. "Sync them up with flow-ci" = bring
those seven to **v2.0.1** parity. Because the v1→v2 step is breaking, a
naive re-pin sweep would **brick every AI gate** (ai-review hard-exits with no
LiteLLM secret — `ai-review.yml:534`; private callers relabelled without a
registered pool queue forever). So the cutover sequences founder-gated (🔴)
prerequisites first, then pilots one repo to a **live-green** gate, then
propagates.

Decisions: **full v2.0.1 cutover**; **pilot one repo, verify live green, then
propagate**.

## What this migration is — and ISN'T (both drafts verified against live files)

The change per consumer is **NOT** "add missing callers + add config.json." A
live grep proved the WORKFLOWS.md §2 gap matrix (audited 2026-07-11) is **stale**:
every "missing" caller already exists as a `@ci/v1.9.5` caller
(engramory `pre-commit.yml:27`, iplan-runner `composition.yml:30`, iplan-standard
`ai-review.yml:43`/`composition.yml:30`/`pre-commit.yml:27`, business
`audit-trail.yml:11`). **There are no caller additions to do.** Likewise,
consumers need **no `.github/ai-review/config.json`** for the normal flow: the
reusable reads `litellm.model` + trust from **`operations@main`**; a missing
consumer config makes `composition` fail-closed→enforce, which our trusted-author
PRs clear via the App approval (`composition.yml:189,204`).

The real work is five mechanical edits, most of which **`install.sh --repin`
CANNOT do** (it only rewrites `uses:` lines, `install.sh:329-339`):

| Edit | Repos | `--repin` handles it? |
|---|---|---|
| A. Bump `uses:` pins `@ci/v1.9.5`→`@ci/v2.0.1` | all 7 | ✅ yes |
| B. Runner-label swap `aidoc,ci-ephemeral`→`ci-runner,single-use` (**two tokens**) | business, iplanic, interlog — **every** private caller (~9/14/9 files) | ❌ manual |
| C. `standards-drift` curl-URL source → v2.0.1 **SHA** (it's a `run:` curl, not `uses:`) | framework, iplanic (SHA `e15ec7d4`); engramory, iplan-runner, iplan-standard (**mutable** `ci/v1.6.0`) | ❌ manual |
| D. Add `litellm_allow_insecure_http: true` to private ai-review callers (HTTP Docker-bridge) | business, iplanic, interlog | ❌ manual |
| E. Add missing `permissions:` block to **interlog** `composition.yml` | interlog | ❌ manual |

## Current state

| Repo | Active `uses:` pin | Runner | Vis | Repo-specific edits |
|---|---|---|---|---|
| operations | `@ci/v2.0.1` ✅ | `ci-runner,single-use` | priv | reference impl; **advanced + live-verified 2026-07-16** (PR #265) — see note below |
| framework | `@ci/v1.9.5` | `ubuntu-latest` | pub | C (SHA); own md-lint tooling; server-side human-merge floor |
| business | `@ci/v1.9.5` | `aidoc,ci-ephemeral` | priv | B, D; phantom branch-protection context |
| iplanic | `@ci/v1.9.5` | `aidoc,ci-ephemeral` | priv | B, C (SHA), D; delete duplicate `standard-drift.yml`; phantom context |
| iplan-runner | `@ci/v1.9.5` | `ubuntu-latest` | pub | C (mutable tag→SHA) |
| iplan-standard | `@ci/v1.9.5` | `ubuntu-latest` | pub | C (mutable tag→SHA) |
| engramory | `@ci/v1.9.5` | `ubuntu-latest` | pub | C (mutable tag→SHA) — **pilot** |
| interlog | `@ci/v1.9.5` | `aidoc,ci-ephemeral` | priv | B, D, E; phantom context |

All active `uses:` pins are uniformly `@ci/v1.9.5` (no stragglers; the
`v1.9.4`/`v1.5.1`/`v1.6.0` strings are comment-only or the drift-curl URL).

> **operations v2.0.1 advance is NOT a mechanical re-pin.** Unlike the 7
> consumers (Edit A `--repin` touches only `uses:` lines), operations carries a
> pre-commit contract-lock `scripts/check-ci-contract.sh` that hard-pins the
> accepted flow-ci tag to **exactly `ci/v2.0.0`** (lines 37 + 61) — a naive
> caller re-pin fails the local guard. Advancing operations to `v2.0.1` requires
> editing the contract-lock + `standards-drift.yml` (`ref:` **and** `--ci-tag`)
> in lockstep with the caller pins — a governance change, budgeted as its own
> step. Runbook: `operations/ops/inbox/2026-07-16_founder_operations-ci-v2.0.1-advance-and-verify.md`
> (operations PR #264). **DONE 2026-07-16 — operations PR #265 merged** (12 pins +
> drift `ref`/`--ci-tag` + contract-lock + `config.json` `$schema`; OPS-0065
> 3-agent review SHIP). **The v2.0.1 armed-consumer live-verification is BANKED
> here, not deferred to the pilot** — throwaway PR #266 confirmed the v2.0.1
> reviewer posts a proper `CHANGES_REQUESTED` naming a `[critical]` finding
> (the v2.0.0 "verdict malformed" discard is gone).

Canon refs: `MIGRATION_v2.0.0.md` (the v1→v2 migration; still current for v2.0.1),
`install/install.sh` (`--repin`), `docs/runners.md`,
`docs/FLEET_BRANCH_PROTECTION_ARMING.md`, `CHANGELOG.md` (v2.0.0 + v2.0.1). Precedent:
`operations/.github/workflows/ai-review.yml` (v2 private caller) +
`operations/ops/iplans/IPLAN-0033`.

## Approach

### Phase 0 — 🔴 founder prerequisites (I prepare inbox runbooks; founder executes)

Nothing merges until these are confirmed live (`feedback_writes_to_other_repos_inbox_first`).

1. **LiteLLM proxy + keys (the only NEW v2 secrets).** Aliases `ai-reviewer`
   (+ `ai-doc-maintainer`, deferred); review-scoped virtual key. Set
   **`LITELLM_BASE_URL` + `LITELLM_REVIEW_API_KEY`** **per-repo on each of the 7
   consumers** — **org-level inheritance is NOT possible** (correction
   2026-07-14, supersedes the earlier "org-level recommended" note: `vladm3105`
   is a personal account, not an org; the org-secrets API 404s, so there is no
   org-level secret to inherit). `secrets: inherit` in the
   callers still works — it passes each calling repo's own repo-level secrets to
   the reusable. Live check **2026-07-16**: the **private trio has them**
   (business/iplanic/interlog — `LITELLM_BASE_URL` + `LITELLM_REVIEW_API_KEY`, set
   2026-07-15); the **4 public repos still have none** (engramory, framework,
   iplan-standard, iplan-runner) — plus operations + aidoc-flow-ci (2026-07-13).
   So this item is **3/7 done**; the remaining work is the 4 public repos. Set them
   **pilot-first** (engramory, then the rest after the pilot is green).
   `LITELLM_DOC_API_KEY` only when doc-maintainer is adopted (deferred).
   `AIDOC_FLOW_BOT_*` unchanged (docs-sync stays dry-run).
2. **Public-reachability — RESOLVED (2026-07-15): keep LiteLLM private; run each
   public repo's ai-review REVIEW job on the ephemeral self-hosted pool.** The
   proxy is host-local (`http://172.17.0.1:4001`, private per founder) — GitHub-
   hosted `ubuntu-latest` runners cannot reach it, but self-hosted runners on the
   proxy host can. So instead of exposing a public endpoint, each public repo sets
   **`runner_labels_review: '["self-hosted","ci-runner","single-use"]'`** and keeps
   the fork-facing `trust` job + every other check on `ubuntu-latest`. This is
   **safe** — forks are hard-set untrusted so the review job is skipped for them,
   and the review job runs **no PR code** (it curls the diff → LiteLLM). Rationale
   + wiring: `docs/runners.md` §5a + `CLAUDE.md` "Runner policy". **No public HTTPS
   endpoint or tunnel needed.** Consequence: the **engramory pilot stays a public
   repo** — it just needs a self-hosted *review* runner on the proxy host + its
   LiteLLM secret; the private tier can proceed in parallel once its pools exist.
3. **Verify pre-existing secrets/vars** didn't lapse: `APP_REVIEWER_1_ID`/`_KEY`,
   `APP_REVIEWER_1_BOT_ID` (var — also gates whether `composition` enforces),
   `AI_REVIEW_TOKEN`.
4. **v2 runner pools** for **business, iplanic, interlog** (+ a shared pool for
   the public review jobs, Edit F): register `self-hosted,ci-runner,single-use`
   (`operations/scripts/ci-runner/run-ephemeral.sh` + `provision-runner.sh`;
   `docs/runners.md` §3). Live check 2026-07-15: only `ci-runner@operations` +
   `ci-runner@llm-router` supervisors are up — the three private repos have **no**
   ci-runner pool. **Size for concurrency:** one supervisor instance runs jobs
   SERIALLY, and a private-repo PR fans out to ~8 jobs, so run **N instances per
   repo** (~6–8, `docs/runners.md` §5) or PR feedback serializes. All these
   runners must be on the **proxy host** (to reach `172.17.0.1:4001`). Use the
   operations **two-stage label transition** (C6): Stage A register a **hybrid** Use the operations
   **two-stage label transition** (C6): Stage A register a **hybrid**
   `self-hosted,aidoc,ci-ephemeral,ci-runner,single-use` pool during the migration
   PR so old-label (base) and new-label (PR) jobs both find a runner, then Stage B
   narrow to `self-hosted,ci-runner,single-use` after that repo's re-pin merges.
   Never fall back to `ubuntu-latest` on a private repo.
5. **Drop deprecated secrets** (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`,
   `CLAUDE_CODE_OAUTH_TOKEN`) post-cutover.
6. **Smoke:** private + (per #2) public `gh workflow run litellm-smoke.yml` both green.

### Phase 1 — Pilot (public **engramory**, pending Phase 0 #1)

On a feature branch:
- **A** — `install.sh --repin` bump all `uses:` → `@ci/v2.0.1` (FT-9-safe;
  never `--update`). The `reviewer:` input is already commented out in every
  caller, so no active removed-input trips the bump.
- **C** — hand-edit the `standards-drift.yml` curl URL from `ci/v1.6.0` (mutable
  tag) to the `ci/v2.0.1` **commit SHA `819d148e366f4f469f3645d1bfb249e3a1e9cf13`**.
  Confirm `sync/check-standards-drift.sh` exists at that SHA and that the
  consumer's `standards-drift.yml` still passes a **valid v2 `--tier`** — the v2
  interface is `--tier {governance|product|ops|umbrella|bootstrap}` + optional
  `--strict` (correction 2026-07-14: not an "expanded strict mode"; an
  invalid/removed tier name now triggers `stop_uncheckable`, so verify each
  consumer's invocation before bumping). The script stays warning-only (exit 0)
  unless `--strict`.
- Tidy obsolete `# reviewer:` / `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` header
  comments (cosmetic).
- **secret-scan fixture audit** — v2 removes the blanket `tests/`/`fixtures/`/
  `vectors/`/`.secrets.baseline` allowlist. Grep engramory for placeholder
  secrets under those paths; ship a repo-local `.gitleaks.toml` allowlist if any,
  else the re-pinned secret-scan flips **green→red**.
- **(recommended safety)** ship a minimal `.github/ai-review/config.json` with
  `trust.ai_review` so `composition`'s human-review exemption can evaluate a
  non-allowlisted **non-fork** author (fork PRs are already exempt). Low-risk for
  engramory but the pattern is needed on multi-collaborator private repos.
- Keep `docs-sync.yml` dry-run (doc-maintainer/live deferred to 🔴 W3).
- Pre-push OPS-0065 agents (code-reviewer + documentation-specialist min; add
  security-auditor / silent-failure-hunter for workflow+security diffs); 3-cycle
  cap (OPS-0066); OPS-0069 audit-trail phrase in the commit.
- Open PR; **watch to LIVE green** — ai-review v2 actually ran + passed (not just
  YAML parse). Go/no-go gate for propagation (6/6 criteria,
  `verify_one_layer_before_propagating`).
- **v2.0.1 residual verification — B1 DONE, B2 still open here.** Corrects an
  earlier premise: **operations, not the pilot, is the first armed consumer**, so
  the armed half was banked there on 2026-07-16.
  - ✅ **B1 verified LIVE on operations** (throwaway PR #266, closed): a synthetic
    auth-bypass diff drew a proper `CHANGES_REQUESTED` naming the `[critical]`
    finding + fix — no "verdict malformed" discard. The armed `request_changes`
    blocking path works.
  - ⚠️ **B2 — source-verified only; ACCEPTED-UNVERIFIED live, and NOT reachable at
    any PLAN-009 venue.** B2's bypass exists **only while UNARMED**: the v2.0.1
    guard (`ai-review.yml:277-286` @`819d148`) early-exits when
    `vars.APP_REVIEWER_1_BOT_ID` is empty, *before* the `pull_request_review` skip.
    **Live check 2026-07-16: every consumer is ARMED** (engramory, operations,
    framework, interlog all have `APP_REVIEWER_1_BOT_ID` set), so all take the
    armed early-exit and **never enter the B2 path**. Consequence: the obvious
    pilot test (land a RED → submit a COMMENT review → confirm no GREEN flip)
    would pass **vacuously via the armed skip** — it would have passed on buggy
    v2.0.0 too — so it must NOT be booked as B2's closure.
    **Disposition:** accepted-unverified. Residual risk is low *because* the
    bypass is unreachable while armed. To actually exercise it you need a
    deliberately **unarmed fixture** (unset `APP_REVIEWER_1_BOT_ID` on a throwaway
    repo/branch, land a RED, then comment-review). Do that only if a consumer is
    ever intentionally run unarmed.

### Phase 2 — Remaining public (framework, iplan-runner, iplan-standard)

Repeat A + C (+ secret-scan audit) per repo, plus the new **Edit F** below.
- **F — `runner_labels_review` → self-hosted** on the ai-review caller (Phase 0
  #2 resolution): set `runner_labels_review: '["self-hosted","ci-runner","single-use"]'`
  so the LiteLLM-facing review job reaches the private proxy; keep
  `runner_labels_routine: '"ubuntu-latest"'` (fork-facing trust job) and every
  other check on `ubuntu-latest`. Needs a self-hosted review runner registered on
  the proxy host (shared with the private tier's pool). Safe per `runners.md` §5a.
- framework: C is the SHA `e15ec7d4`→v2.0.1-SHA bump; F as above; human-merge is
  enforced server-side (`composition.yml:225` + omission from `auto_merge.repos`),
  so no `tier:` change needed.
- iplan-runner, iplan-standard: C is mutable-tag→SHA; F as above.

(Pre-requisite for F: the proxy-host self-hosted pool must have capacity for the
public review jobs on top of the private tier — size supervisor instances
accordingly, `runners.md` §5.)

### Phase 3 — Private (business, iplanic, interlog) — needs Phase 0 pools live

Per repo: A, then **B** (two-token label swap across **every** private caller
file — grep-verify no `aidoc`/`ci-ephemeral` remains and each array is a valid
`ci-runner`+`single-use` pair), then **D** (`litellm_allow_insecure_http: true`
on ai-review), plus:
- **iplanic** — C (SHA); **delete duplicate** `standard-drift.yml` (local
  `actions/checkout` vendored check, distinct from `standards-drift.yml`).
- **interlog** — **E** (add the `permissions: {contents: read, pull-requests: read}`
  block to `composition.yml` — currently missing → `startup_failure`; must land
  **before** composition is armed on interlog in Phase 4).
- `.lychee.toml` add for business + iplanic (absent) is optional (links uses a
  default) — include only if their `links` job needs cross-repo excludes.

### Phase 4 — Branch-protection correction + arming (🔴 founder, W4)

Per `docs/FLEET_BRANCH_PROTECTION_ARMING.md`: rename phantom bare contexts
(`Lint / format / security hooks` → `call / …`) and arm the `call / …` +
`call / composition` required checks. **Ordering:** because framework/business/
iplanic already carry phantom contexts that force `--admin` merges today, the
Phase 1–3 re-pin PRs on those repos will **not** auto-merge — either fold the
context-correction into their re-pin coordination or **explicitly plan `--admin`
merges** for them. Arm interlog `composition` only **after** edit E lands.

## Tracking / where plans live

`plans_live_in_owning_submodule`: this fleet tracker lives here in
`aidoc-flow-ci/plans/PLAN-009_fleet-v2-cutover.md`; per-consumer `IPLAN-NNNN`
mirroring operations' IPLAN-0033 with cutover evidence. Update each repo's
HANDOFF/CHANGELOG inline (`feedback_update_docs_per_pr`). Canon housekeeping
status (2026-07-14): **`docs/WORKFLOWS.md` §2 stale-cell fix — DONE this session**
(the "missing" ai-review/composition/pre-commit callers all exist live; cells
flipped to ✅). **operations IPLAN-0033 header reconciled `executing`→`completed`
— DONE this session** (matches the completed inbox runbook + verified live
ai-review/composition runs).

## Process guardrails

- ≤3 doc surfaces per governance PR; adversarial pre-push self-review
  (`governance_pr_discipline`).
- Auto-watch + auto-merge green PRs I open (OPS-0062); escalate at 10 attempts.
  Where a phantom context blocks (framework/business/iplanic), `--admin` merge
  is expected until Phase 4. Umbrella pointer-bump PRs merge `--admin`
  (required_signatures).
- Circuit-breaker: stop + surface to founder if a repo's gate doesn't converge
  in 3 cycles.
- Never hand-edit example artifacts; never switch a private repo to
  `ubuntu-latest` to unstick a gate.

## Verification (per repo, LIVE — not just parse)

1. `gh pr checks` shows ai-review v2 **ran + passed** (LiteLLM path, no
   startup_failure).
2. `composition` present; where `APP_REVIEWER_1_BOT_ID` is set it counts the App
   approval (else INERT-green).
3. `links` / `markdown-lint` / `pre-commit` / `secret-scan` green (secret-scan:
   confirm the fixture audit held).
4. Private repos: jobs pick up on `ci-runner,single-use` (not queued); `grep -rn
   'aidoc\|ci-ephemeral' <repo>/.github` empty.
5. `grep -rn '@ci/v1' <repo>/.github/workflows` empty AND the `standards-drift`
   curl URL is the v2 SHA; `sync/check-pin-currency.sh` reports current.
6. HANDOFF/CHANGELOG + IPLAN evidence updated.

Fleet-wide: re-run inventory (pins uniform v2.0.1; labels correct by visibility;
no duplicate/again-drifted drift workflows; WORKFLOWS.md §2 corrected).

## Follow-up (memory)

Update `feedback_private_repos_self_hosted_only`: canonical private label as of
`ci/v2.0.0` is **`["self-hosted","ci-runner","single-use"]`**, not the v1
`aidoc,ci-ephemeral` (per `aidoc-flow-ci/CLAUDE.md` Runner policy +
`docs/runners.md`).
