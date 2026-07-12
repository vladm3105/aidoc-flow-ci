# PLAN-007 — aidoc-flow-ci production hardening

**Goal:** move aidoc-flow-ci from "working workspace CI backbone" to
"hardened" — the state where a fresh reviewer would answer *"yes, production
ready"* without caveats. Sequences the five gaps identified in the 2026-07-12
readiness review into tracked, reviewable workstreams.

**Status:** ready (2 review passes, 1 independent). **Owning repo:** aidoc-flow-ci.
**Canon at plan time:** `ci/v1.9.5`.

## Scope (the five gaps — N workstreams for N gaps, no speculative scope)

| # | Workstream | Gap it closes | Founder-gated? |
| --- | --- | --- | --- |
| W1 | Automated test suite for the reusables + scripts | No `tests/` — verification is empirical only | no |
| W2 | Guardrail FT burn-down (FT-1, FT-2, FT-5, FT-6-residual) | Correctness/consistency debt in the canon | no |
| W3 | Graduate `markdown-lint`→blocking + `docs-sync`→live (FT-11) | Two workflows stuck in rollout stages | **partly** (docs-sync App) |
| W4 | Arm gates as required checks fleet-wide | Gates run but don't all enforce | partly (per-repo protection) |
| W5 | Green the canon repo's own CI (Dependabot noise) | aidoc-flow-ci main reads red | no |

**Non-goals:** new reusable workflows; multi-org/external-adopter GA (flow-ci
stays an internal workspace layer per its charter); rewriting working reusables
whose only issue is missing tests (add tests, don't rewrite).

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | The reusables declare a `workflow_call` contract but ship no test asserting it (no `tests/` dir; verified 2026-07-12) | `workflow_call` | .github/workflows/ai-review.yml:40 |
| 2 | `--update` re-applies template bodies over `safe_to_replace` callers (FT-9 added the safe `--repin` path; residual: `--update` still overwrites per-repo `permissions:`/triggers, not just `runner_labels`) | `update_mode` | install/install.sh:202 |
| 3 | `--update` mode is reachable from the CLI | `MODE_UPDATE` | install/install.sh:65 |
| 4 | `composition` reads its trust allowlist from the CONSUMER repo's own `.github/ai-review/config.json` (not `trust_config_repo`) — the residual FT-6 gap (PR-data reads at :68 are correct-by-design; the `?ref=main` half was fixed PLAN-005 PR-G) | `config.json` | .github/workflows/composition.yml:189 |
| 5 | `ai-review` reads trust config from a configurable `trust_config_repo` input (default main) | `trust_config_repo` | .github/workflows/ai-review.yml:66 |
| 6 | `markdown-lint` `fail-on-findings` defaults to `true`; graduation report-only→blocking = removing each caller's explicit `false` override | `fail-on-findings` | .github/workflows/markdown-lint.yml:57 |
| 7 | `docs-sync` live mode (`dry_run: false`) requires `AIDOC_FLOW_BOT_ID`/`AIDOC_FLOW_BOT_KEY` secrets → founder-gated | `AIDOC_FLOW_BOT_ID` | .github/workflows/docs-sync.yml:52 |
| 8 | Per-tier branch-protection payloads define the required-check set to arm | `required_status_checks` | install/templates/branch-protection-product.json:4 |
| 9 | The REPO_STANDARDS §2 matrix defines the required-check set per tier | `## 2. Branch protection` | docs/REPO_STANDARDS.md:74 |
| 10 | FT-2 (unverified emitted check-names for pre-commit/secret-scan) blocks correct arming | FT-2 | plans/FRAMEWORK-TODO.md:33 |
| 11 | FT-5 (standards-drift can't read branch-protection without `administration: read`) limits arming verification | FT-5 | plans/FRAMEWORK-TODO.md:87 |
| 12 | A dependabot config drives the failing "Update" runs on the canon repo | `version: 2` | .github/dependabot.yml:12 |
| 13 | Settings-drift is warning-only + now chains pin-currency (the 3rd dimension) | `check-standards-drift` | sync/check-standards-drift.sh:2 |
| 14 | REPO_STANDARDS §2 baseline lists `call / verify` but the branch-protection templates omit it (FT-1) — W4 must reconcile §2⇄templates first | FT-1 | plans/FRAMEWORK-TODO.md:11 |
| 15 | docs-sync live-mode Apply is an **alpha.1 stub** — even with the App+secrets+`dry_run:false`, it commits nothing | `alpha.1 stub` | .github/workflows/docs-sync.yml:167 |

## Workstreams

### W1 — Automated test suite for the reusables + scripts  *(the top gap)*

**Problem:** every reusable + script is verified only by fleet dogfooding.
A regression (e.g. the composition permissions-block omission, or the `--repin`
SHA-pin gap) ships silently until a consumer hits it.

**Deliverables:**
1. `tests/` harness runnable locally + in CI:
   - **Static:** `actionlint` + `yamllint` over every `.github/workflows/*.yml`
     and `install/templates/workflows/*.yml`; `shellcheck` over `install/*.sh`
     + `sync/*.sh` + `scripts/*.sh`.
   - **Workflow-contract tests:** assert each reusable declares
     `on: workflow_call`, a `permissions:` block, SHA-or-tag-pinned `uses:`
     only on the allowlist (`actions/*`, `github/*`, `vladm3105/aidoc-flow-ci/*`),
     and no third-party marketplace action (the startup_failure class).
   - **Script unit tests** (`bats` or plain-shell fixtures) for the logic-heavy
     scripts: `install.sh --repin` (tag + SHA pins, idempotency, non-aidoc-flow-ci
     lines untouched), `check-pin-currency.sh` (ver_cmp, stale detection),
     `deploy-ci-wizard.sh scaffold` (variant selection, private label injection,
     fail-closed on unreadable visibility), `check-drift.sh` / `check-standards-drift.sh`.
2. A `tests.yml` workflow running the suite on every aidoc-flow-ci PR; add
   `Tests` to aidoc-flow-ci's own required checks.

**Acceptance:** suite green on main; a deliberately-broken reusable
(third-party action, missing permissions block, invalid `runner_labels` JSON)
is caught by the suite, not by a consumer.

**Semver:** none (test infra).

### W2 — Guardrail FT burn-down (FT-1, FT-2, FT-5, FT-6-residual)

- **FT-1 (§2 ⇄ template mismatch):** REPO_STANDARDS §2 baseline lists
  `call / verify` (Claim 14) but the `branch-protection-*.json` templates omit
  it. Reconcile the two (add `call / verify` to the templates, or correct §2)
  BEFORE W4 — W4's "match §2" acceptance is ambiguous while they disagree.
- **FT-9 is already RESOLVED** (ci/v1.9.0 added `--repin`); NOT re-opened here.
  Residual only: `--update` still overwrites per-repo `permissions:`/triggers.
  Add a per-file diff preview + confirmation to `update_mode` ONLY if that
  residual bites in practice — do not build it speculatively (out of scope
  unless a real incident opens a new FT).
- **FT-6 (trust-config source):** reconcile `composition`'s `GH_REPO`-based
  reads with the `trust_config_repo` model ai-review uses, OR document why
  composition legitimately keys off the consumer repo (it evaluates the
  consumer's PR). Add a test asserting the two stay consistent.
- **FT-2 (emitted check-names):** capture the real emitted context strings for
  `pre-commit` + `secret-scan` from a live run; record them in
  `docs/REPO_STANDARDS.md` §2 + the branch-protection templates so W4 arms the
  correct names.
- **FT-5 (drift admin:read):** document the `administration: read` requirement
  for full standards-drift coverage; either request it on the drift token or
  mark branch-protection drift as best-effort in the script output.

**Acceptance:** each FT closed or explicitly re-scoped in FRAMEWORK-TODO;
W2 changes covered by W1 tests where testable.

**Semver:** patch (guardrails, no consumer-surface change) except any
`--update` flag change (minor).

### W3 — Graduate `markdown-lint`→blocking + `docs-sync`→live (FT-11)

- **markdown-lint → blocking (per repo):** run `markdownlint-cli2 --fix`,
  commit the fixes, adopt the tuned `.markdownlint.json`, flip the caller to
  `fail-on-findings: true` (Claim 6 — remove the caller's `false` override),
  arm the check (W4). Sequence cleanest-first. Per-consumer directive: scope
  the caller globs to EXCLUDE `examples/**` before `--fix` so system-under-test
  corpora are never hand-edited (this is a directive to implement, not a
  current property).
- **docs-sync → live:** ⚠️ a `dry_run: false` flip alone does NOTHING — the
  Apply step is an **alpha.1 stub** (Claim 15, docs-sync.yml:167). Real options:
  (i) implement the alpha.2 commit logic (a separate, unplanned workstream), or
  (ii) **skip straight to `doc-maintainer.yml`** (its planned supersession at
  `ci/v2.0.0`). Recommend (ii); the App/secrets (Claim 7) are still the 🔴
  founder prerequisite for whichever lands. Do NOT present the config flip as
  the graduation.

**Acceptance:** markdown-lint blocking + green on ≥ the ops-private + product
tiers; docs-sync live on ≥ ci + operations (or explicit deferral to
doc-maintainer recorded).

**Semver:** none (per-repo config), but the markdown-lint remediation is the
labor-heavy item.

### W4 — Arm gates as required checks fleet-wide

**Problem:** deployed gates run but don't all enforce. Using the per-tier
branch-protection payloads (Claim 8) + the §2 required-check set (Claim 9) +
the FT-2-verified names (W2), add each repo's applicable checks to
`required_status_checks`, per tier, only after each is confirmed green.

**Acceptance:** every non-paused repo's branch protection matches its tier row
in REPO_STANDARDS §2; `check-standards-drift.sh` reports 0 branch-protection
drift (given FT-5).

**Semver:** none (per-repo settings). **Depends on:** W2 (FT-2 verified
 check-names + FT-1 §2⇄template reconciliation), W1 (green gates).

**Status — runbook prepared; founder executes (🔴).** Arming branch protection
across the fleet is a write to other repos + a branch-protection rule change =
🔴 per the autonomy tiers + OPS-0062 exceptions; it is **not** AI-autonomous
under verbal authorization (memory `feedback_writes_to_other_repos_inbox_first`,
2026-07-09). A read-only survey (2026-07-12) found the arming is **not** a
template sweep: 2 repos unprotected (iplan-standard, engramory), 3 repos carry a
**phantom** bare `Lint / format / security hooks` required-context while they
emit the canon `call / …` name (framework, business, iplanic — likely merging
via `--admin`), iplan-runner's canon adoption is broken (`call / ai-review`
skipped, `call / gitleaks` failing), and interlog arms a possibly-conditional
`call / composition`. The exact per-repo target contexts + `gh api` commands +
mandatory per-repo verification + rollback are captured in the founder-executable
runbook: **`docs/FLEET_BRANCH_PROTECTION_ARMING.md`**. Follow-ups (iplan-runner
canon repair, interlog composition conditionality, `--admin`-dependence) logged
as FT-12.

### W5 — Green the canon repo's own CI (Dependabot noise)

**Problem:** aidoc-flow-ci main shows red from failing Dependabot "Update" jobs
(Claim 12), not gate failures — but a red canon repo undermines the
"production ready" signal. Diagnose (missing manifests? ecosystem misconfig?),
fix or scope the `dependabot.yml` so the update jobs pass or aren't spuriously
red.

**Root cause (confirmed):** `.github/dependabot.yml` enables `pip`/`npm`/
`docker`/`gitsubmodule` ecosystems the repo has NO manifests for → orphan
update errors. Fix per the template's own comment: prune to `github-actions`
only. (Note: Dependabot update failures surface in the Actions/Dependabot view;
they don't set a red commit-status on `main` — "reads red" is imprecise.)

**Acceptance:** no failing Dependabot runs; aidoc-flow-ci's actual self-CI
(`audit-trail` + the new W1 `tests` workflow; note there is currently NO
pre-commit CI *caller* in this repo — only local hooks) green.

**Semver:** none.

## Sequencing

```
W5 (quick green)  ─┐
W1 (test suite)   ─┼─►  W2 (guardrails, FT-2 needed by W4)  ─►  W4 (arm gates)
                   │                                            
W3 markdown-lint ──┘  (parallel; --fix remediation, labor-heavy)
W3 docs-sync-live ─────────────────────►  (🔴 founder App; or defer to doc-maintainer)
```

W1 + W5 first (foundation + clean signal). W2 next (its FT-2 output feeds W4).
W4 arms once gates verified green + names confirmed. W3 runs in parallel
(markdown-lint remediation is independent; docs-sync-live waits on the founder).

## Definition of done (production-ready)

- ✅ W1 test suite green + required on aidoc-flow-ci; a planted regression is caught.
- ✅ FT-1/2/5/6 closed or re-scoped.
- ✅ markdown-lint blocking on product + ops-private tiers; docs-sync live (or deferred to doc-maintainer, recorded).
- ✅ Every non-paused repo's required checks match REPO_STANDARDS §2.
- ✅ aidoc-flow-ci main reads green.
- Then re-run the readiness review; target verdict: "yes, hardened."

## Execution log

- **2026-07-12 — W5 DONE** (#137): pruned `.github/dependabot.yml` to
  `github-actions` only (4 orphan ecosystems removed) — canon repo's Dependabot
  runs green.
- **2026-07-12 — W2 (FT-1/FT-2) DONE**: corrected branch-protection template +
  §2 check-names to the verified `call / …` emitted strings (added `call / verify`;
  fixed pre-commit + secret-scan names) + `tests/test_checknames.sh` guard. This
  unblocks W4 arming (a mismatched required name would have bricked every gate).
  W2 FT-5 DONE (drift distinguishes 403 from absent). W2 FT-6 VERIFIED
  not-an-enforcement-gap (composition fails-closed to ENFORCE when no local
  config; downgraded to a consistency nit). **W2 COMPLETE.**
- **2026-07-12 — W1 DONE**: `tests/` suite + `tests.yml` shipped (103
  assertions: lint + workflow-contract + script-logic + negative). Surfaced +
  fixed 2 over-strict checks during authoring. NEXT for W1: add `Tests` to
  aidoc-flow-ci's required checks (deferred with W4 arming).

## Review log

### Pass 1 — 2026-07-12 — author (self)
Drafted the 5 workstreams (N-for-N with the readiness-review gaps) + a 13-row
Claim ledger with `file:line` citations verified against source. Ran the
verified-planning gate; fixed 5 non-`path:line` citations (absence/multi-file
rows re-anchored to concrete symbols). No design change; citation-form only.

### Pass 2 — 2026-07-12 — independent (general-purpose, fresh context)
Adversarial review against real source. Confirmed all 13 citations mechanically
accurate; surfaced **4 load-bearing** findings, all folded:
- **LB-1:** FT-9 was already RESOLVED (ci/v1.9.0 `--repin`); W2 double-counted
  it + proposed speculative `--i-understand-clobber` scope. → Dropped FT-9 from
  W2 (kept only the genuine residual: `--update` still overwrites
  `permissions:`/triggers), Claim 2 reworded.
- **LB-2:** docs-sync live-mode Apply is an **alpha.1 stub** (docs-sync.yml:167)
  — a `dry_run:false` flip commits nothing. → W3 rewritten: config flip is
  insufficient; realistic path = `doc-maintainer.yml` (or unplanned alpha.2
  impl). Added Claim 15.
- **LB-3:** FT-6 mis-located — PR-data reads at `GH_REPO`:68 are correct-by-
  design; the real residual is the trust-allowlist read at composition.yml:189
  (consumer's own config vs `trust_config_repo`), and the `?ref=main` half was
  already fixed (PLAN-005 PR-G). → Claim 4 re-pointed + reframed.
- **LB-4:** W4 depends on **FT-1** (§2 lists `call / verify`; templates omit it)
  — untracked. → Added FT-1 to W2 as a W4 prerequisite; added Claim 14; W4
  Depends-on updated.
3 minor findings (Claim 6 phrasing, markdown-lint example-exclusion is a
directive not a fact, no pre-commit CI *caller* on this repo) also folded.

### Pass 3 — 2026-07-12 — independent (general-purpose, fresh context)
Confirmation pass on the folded plan. Verified all 4 LB folds correct against
source (FT-9 resolved at FRAMEWORK-TODO:239; docs-sync stub at docs-sync.yml:167;
FT-6 locus at composition.yml:189; FT-1 at FRAMEWORK-TODO:11). One residual
found + fixed: DoD listed the pre-fold FT set (`FT-2/5/6/9`) → corrected to
`FT-1/2/5/6`. No other new findings.

**Result:** ready — Pass 3 returns zero remaining load-bearing findings after the
one-line DoD fix; scope is N-for-N with the readiness gaps; no speculative workstreams.
