# PLAN-002 — Workspace standards rollout + self-review mechanical enforcement (UNIFIED)

**Status:** SHIPPED — canon + self-review mechanical enforcement landed
via PR-U1/U2/U3/U4 (2026-07-08); per-tier rollout to consumers is ongoing
per §5.5 (tracked alongside PLAN-003 §5.5 waves). Original draft 2026-07-07 EST.
**Supersedes:** PLAN-002 (2026-07-07 first draft; found 20 substantive gaps in
adversarial review, rewritten in place).
**Absorbs from PLAN-001:** §5.4 per-tier rollout scope (canon templates + apply
tooling are SHIPPED; rollout to consumers merges into this plan).
**Related:** OPS-0061 (governance PR discipline), OPS-0062 (auto-merge default),
OPS-0065 (multi-agent review), OPS-0067 (aidoc-flow-standard),
OPS-0069 (mandatory pre-push audit-trail), PLAN-001 (repo standards canon —
Phases 1–5 shipped).

## 0. Version + scope

This plan is the **unified successor** to two overlapping efforts:

- **PLAN-001** shipped the standards CANON (`REPO_STANDARDS.md`), content-
  surface templates (CODEOWNERS, PR template, dependabot.yml, .gitignore,
  .gitattributes), server-side canon JSONs (5 branch-protection tiers +
  actions-permissions + repo-settings + labels), and the apply tooling
  (`install/apply-standards.sh` with `--check`/`--dry-run`/`--report`/`--apply`
  - `sync/check-standards-drift.sh`). PRs #55, #56, #57, #58, #60 merged
  2026-07-07. PLAN-001 §5.4 rollout scope is absorbed into this plan.
- **PLAN-002 (v1)** proposed self-review mechanical enforcement. Adversarial
  gap review 2026-07-07 identified 20 substantive findings (5 HIGH shipping
  blockers, 10 MEDIUM, 5 LOW). This unified plan folds all fixes.

Result: ONE plan owns the remaining workspace-wide rollout of both surfaces
(standards + self-review).

## 1. Purpose

Complete the workspace-wide unified CI + governance surface across all
non-paused repos in two joint deliverables:

1. **Self-review mechanical enforcement** (author-side pre-push + CI belt-and-
   suspenders) — closes the gap that OPS-0069 was created to prevent (7-cycle
   review cascades on missed pre-push dispatch).
2. **Per-repo compliance with PLAN-001 canon** (content templates + server-side
   settings via `apply-standards.sh --apply`) — closes the drift between the
   canon rulebook and the real 8 non-paused workspace repos.

These land as a single coordinated rollout because both consume the same
`install/apply-standards.sh` infrastructure and target the same 8 repos.

## 2. Current-state audit (2026-07-07)

### 2.1 PLAN-001 canon adoption per repo

| Repo | Tier | CODEOWNERS | PR tmpl | dependabot | .gitignore | .gitattributes | canon labels | branch-prot per §2 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| operations | ops-private | partial | ✅ | ⚠ | partial | ⚠ | ⚠ | partial |
| framework | governance | ✅ | ✅ | ⚠ | ✅ | ⚠ | ⚠ | partial |
| business | ops-private | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | partial |
| iplanic | ops-private | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | partial |
| iplan-runner | product | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | partial |
| iplan-standard | governance | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | partial |
| engramory | product | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | partial |
| aidoc-flow-ci | product | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | partial | partial |

*(Exact per-cell state to be measured by `apply-standards.sh --check` +
`--report` on each repo as first step of each §5.5 wave PR.)*

### 2.2 Self-review enforcement per repo

| Repo | CLAUDE.md discipline | CI post-push review | Local pre-push hook | Audit-trail commit-msg check |
| --- | --- | --- | --- | --- |
| operations | ✅ | ✅ | ✅ (reference impl) | ✅ |
| framework | ✅ + 5 gov docs | ✅ (ai-review, composition, doc-review) | ❌ | ❌ |
| business | ✅ | ✅ | ❌ | ❌ |
| iplanic | ✅ | ✅ | ❌ | ❌ |
| iplan-runner | ✅ | partial (ai-review only) | ❌ | ❌ |
| iplan-standard | ✅ | ✅ | ❌ | ❌ |
| engramory | ✅ | ✅ (adopted 2026-07) | ❌ | ❌ |
| aidoc-flow-ci | (canon home) | reusables, no self-CI | ❌ | ❌ |

**Paused (skip both surfaces):** `knowledge-rag`, `site` (founder direction
2026-07-04).

## 3. Non-goals (v1)

- Do NOT touch paused repos (`knowledge-rag`, `site`) — founder direction.
- Do NOT retrofit historical commits — enforcement kicks in on next push
  after adoption.
- Do NOT introduce a new agent that dispatches sub-agents itself. The
  pre-push script VERIFIES the audit-trail commit-message phrase already
  set by the author; dispatch remains author-tool responsibility (Claude
  Code `Agent(...)`, Codex, Gemini, etc.).
- Do NOT introduce a runtime env-var opt-out (`AIDOC_FLOW_SKIP_PREPUSH`
  and similar) — **explicit reversal of the v1 draft**. Matches OPS-0069's
  removal of `SKIP_LOCAL_AI_REVIEW`. Only bypass path = `git push
  --no-verify` (git primitive; caught by CI belt-and-suspenders anyway).
  Not-installing-the-hook is NOT an opt-out path: all 8 non-paused repos
  install per §5.5; paused repos are the only excluded set (founder
  direction 2026-07-04, not a governance opt-out).
- Do NOT re-derive per push — the pre-push hook does the audit-trail check
  itself; CI is belt-and-suspenders for `--no-verify` bypass.

## 4. Design constraints (gap-review fixes folded)

### 4.1 Canon script scope (H2 fix from v1 review)

Reference impl `operations/scripts/pre_push_check.sh` runs SEVEN checks:

1. `markdownlint-cli2` (skips if not installed)
2. `yamllint` (skips if not installed)
3. `actionlint` on `.github/workflows/*.yml` (skips if not installed)
4. `shellcheck` (skips if not installed)
5. `check_plan.py` (verified-planning gate) — **operations-specific**
6. `classify-parity` (diff-class-map JSON/bash/JS parity) — **operations-specific**
7. OPS-0069 audit-trail phrase check

Canon template `install/templates/pre_push_check.sh` ships checks **1–4 + 7
only**. Operations-specific #5 + #6 stay in operations' own script (which
now consumes canon + adds its own suffix). Canon template preserves
reference impl's `set -uo pipefail` (NOT `-e`; the rc accumulator pattern
depends on non-fatal per-check failures — L4 fix).

### 4.2 Wiring: `.pre-commit-config.yaml` — pick-one (H7 fix)

Canon wiring is via `.pre-commit-config.yaml` with
`default_install_hook_types: [pre-commit, pre-push]` — mirrors operations
reference impl, matches `docs/local-pre-push.md` §5 prereqs, and is the ONE
git-hook wiring pattern that a checked-in file can enforce. Reject
alternatives: raw `.git/hooks/pre-push` (per-clone, not shared);
`.githooks/` + `core.hooksPath` (requires per-clone `git config`).

Consumers with an existing `.pre-commit-config.yaml` append the canon hook
block; consumers without one get the file created.

### 4.3 CI workflow shape (H3, H4, H5, M6, M9 fixes)

`.github/workflows/audit-trail-check.yml` reusable (`workflow_call`), same
pattern as `ai-review.yml` / `composition.yml`. Required-status-check
context name **fixed at `call / verify`** so REPO_STANDARDS.md §2
`contexts` arrays can reference it stably. Naming follows the aidoc-flow-
ci convention: consumer caller uses standard `jobs.call:` block; reusable
exposes `job.verify:`; rendered check-name = `call / verify` (matches
`call / ai-review` + `call / composition` naming already in canon §2).

**Triggers (in the CONSUMER caller, not the reusable):**

- `pull_request` — types: `[opened, synchronize, reopened]`. Runs on fork
  PRs with read-only token; no secrets required (only `git log`).
- `pull_request_target` — NOT used (secrets not needed; avoids fork-write
  attack surface).

**Range logic (H3 + H4 fixes):**

- For `pull_request` events: scan
  `${{ github.event.pull_request.base.sha }}..${{ github.event.pull_request.head.sha }}`
  (base..head, not head..base — v1 draft had this backwards).
- Push events: NOT covered by this reusable. Rationale: the local pre-push
  hook is the enforcement point for direct pushes; CI enforces at PR merge
  boundary. Direct pushes to protected branches require `--admin` bypass
  anyway. Removes the `before..after` edge cases (new-branch, force-push,
  squash-merge author confusion).
- **Checkout depth (fork-PR safety):** reusable's checkout step MUST use
  `fetch-depth: 0` (or explicitly `git fetch origin ${base_sha}:refs/
  remotes/origin/pr-base`) — default `actions/checkout@v4` uses depth-1
  which makes `git log base_sha..head_sha` return empty and the check
  falsely PASS. Load-bearing on fork PRs where OPS-0069 enforcement is
  most needed.

**Exemptions (H5 fix — explicit exemption list):**

Job SKIPS (with `::notice::` log) rather than fails when ALL commits in
the PR range are authored by:

- `dependabot[bot]`
- `renovate[bot]`
- `github-actions[bot]`

Individual commits in the range are exempt if commit message matches:

- Starts with `Revert "` (git revert templated message).
- Message body contains `[skip-audit-trail]` (explicit override; also
  requires a `skip-audit-trail` label on the PR — TWO signals prevent
  accidental override).

At least ONE non-exempt commit must carry the audit-trail phrase for the
check to pass.

### 4.4 Umbrella-tier semantics (M2 fix)

Umbrella `aidoc-flow` has TWO relevant constraints in the canon:
(a) `enforce_admins: false` in branch-protection (`--admin` merge is the
intended bypass); (b) `required_status_checks: null` — umbrella has NO
required status checks by design (submodule-pointer PRs have no code CI
to run). Consequence: `call / verify` is NOT added to umbrella's
contexts array (nothing to bypass; there's no contexts array).

The rollout PR still installs the local pre-push hook (enforces
audit-trail phrase in commit messages) AND ships the
`audit-trail-check.yml` caller in `.github/workflows/` for advisory PR-
comment visibility — but the workflow is NOT wired as a required
status check on umbrella. `--admin` merges bypass whatever advisory
signal exists. Plan accepts this as intentional per OPS-0062 governance
layer.

Submodule-pointer PRs authored by AI agents MUST still carry the audit-
trail phrase per OPS-0069; the trigger is `Multi-agent self-review per
OPS-0065 (documentation-specialist): submodule pointer bump — no logic
diff, verified downstream PR is green`. Founder-authored pointer bumps
follow the same rule.

### 4.5 Bootstrap-tier semantics (M3 fix)

Bootstrap tier (`aidoc-flow-interlog`) MUST install the local pre-push hook

- audit-trail check (single-file bash — no CI dependency). CI
`call / verify` workflow: **not installed** (caller file omitted from
`.github/workflows/`) until the repo joins the ai-review consumer set.
§5.5 Wave 4 rollout PR ships the hook + adds a HANDOFF note that CI
check adoption is pending. When bootstrap graduates to product tier
(§5.5 Wave 3 addition), a follow-up PR installs the caller + updates
branch-protection contexts (F5 blast-radius per PLAN-001 §5.4).

### 4.6 Bot / mechanical-commit exemption (H5 + local-hook parity)

Local hook and CI reusable have INTENTIONALLY DIVERGENT exemption
semantics, driven by PR-U3 security review (F1 CRITICAL: commit
metadata is attacker-spoofable on fork PRs; F2 HIGH: subject prefix
is unverifiable):

- **Local hook** (author discipline, not authorization):
  - Bot-authored range (dependabot / renovate / github-actions) checked
    via `git log --format=%an` → SKIPS. Safe locally because the local
    hook trusts the developer's own git config.
  - Revert-only range (all subjects start with `Revert "`) → SKIPS.
    Developer convenience.
- **CI reusable** (authorization gate; must not trust attacker input):
  - Bot exemption uses GitHub-authoritative
    `pull_request.user.type == 'Bot'` + `pull_request.user.login`
    allowlist (dependabot / renovate / github-actions). Commit `%an`
    NEVER referenced — attacker on a fork PR can trivially set author
    to `dependabot[bot]` and bypass an %an-based check.
  - Revert-only exemption REMOVED CI-side. Subject prefix `Revert "`
    is trivially spoofable + unverifiable at the gate; the phrase is
    cheap to add to a revert commit.
  - **Two-signal override (CI-side only):** `skip-audit-trail` PR
    label AND `[skip-audit-trail]` in commit body → SKIPS. Local hook
    cannot see PR labels so this branch is a CI-only escape.

Otherwise, at least one commit in the range must carry the OPS-0069 phrase.

### 4.7 Rollout self-hosting (M4 fix — bootstrap paradox)

`aidoc-flow-ci` is the canon home + is currently in the "unhookified"
column. Solve by adopting the canon on `aidoc-flow-ci` FIRST — see §6.4
Tier 0. This means PR-U4 (aidoc-flow-ci self-adoption) merges BEFORE the
first per-repo rollout PR. Every subsequent PR on aidoc-flow-ci (including
PLAN-002's remaining PRs) then flows through the same gate.

### 4.8 Circular source-of-truth resolution (M1 fix)

Canon on `aidoc-flow-ci` is the authoritative source going forward.
`aidoc-flow-operations` retires its bespoke `scripts/pre_push_check.sh`
and adopts canon via `install.sh` — same as every other consumer.

Operations-specific extra checks (verified-planning `check_plan.py` +
classify-parity) live in a THIN operations-side wrapper
`scripts/pre_push_check_ops.sh` with these EXACT semantics:

1. Operations' `.pre-commit-config.yaml` invokes the WRAPPER
   (`scripts/pre_push_check_ops.sh`) as the pre-push hook — NOT canon
   directly. This ensures verified-planning + classify-parity always
   fire.
2. Wrapper structure:

   ```bash
   #!/usr/bin/env bash
   set -uo pipefail
   cd "$(git rev-parse --show-toplevel)" || exit 2
   # Run canon first; propagate its rc without exiting.
   scripts/pre_push_check.sh; canon_rc=$?
   # Ops-only checks (verified-planning + classify-parity).
   ops_rc=0
   # ... check_plan.py invocation ...
   # ... verify-classify-parity.py invocation ...
   # Non-fatal accumulation matches canon's rc pattern.
   exit $(( canon_rc | ops_rc ))
   ```

3. Canon runs FIRST — audit-trail is the load-bearing OPS-0069 check;
   deferring it under ops-only checks would let mechanical linting
   errors mask a missing phrase.
4. Wrapper preserves canon's `set -uo pipefail` (NOT `-e`) so per-check
   failures don't short-circuit.

Same design supports other consumers that need repo-specific checks
(e.g., framework may add its own review-remediation-flow validator as
`scripts/pre_push_check_framework.sh` in a follow-up).

## 5. Deliverable shape — 4 unified PRs + per-tier rollout

Split into 4 focused PRs (each ≤3 or ≤4 surfaces per OPS-0061 Rule 1;
larger PRs bundled with atomic-suite founder OK per PLAN-001 §5.2/§5.3
precedent).

### 5.1 PR-U1 — canon script + REPO_STANDARDS.md §14 + stale-doc cleanup

**Purpose:** ship the canon `pre_push_check.sh` template + document the
mechanical layer + fix stale docs contradicted by OPS-0069.

**Files created / touched:**

- `install/templates/pre_push_check.sh` (NEW) — canon script per §4.1
  scope. Preserves reference impl's defensive `git rev-parse --verify
  --quiet` upstream detection (M10 fix), `set -uo pipefail` (L4 fix), and
  detailed error-message recovery steps.
- `install/templates/pre-commit-hook-block.yaml` (NEW) — canonical
  `.pre-commit-config.yaml` fragment for consumers to append: sets
  `default_install_hook_types: [pre-commit, pre-push]` + wires the local
  `pre_push_check.sh` hook.
- `docs/REPO_STANDARDS.md` — three amendments in ONE PR (H6 fix, bundled
  per PLAN-001 §5.2 atomic-suite precedent):
  - §14 (NEW) — self-review mechanical enforcement rule. Tier
    applicability: all non-paused (bootstrap adopts hook only; CI check
    pending per §4.5). Change log (previously §14) moves to §15.
  - §2 (edit) — add `call / verify` to each tier's required
    `contexts` array **except: (a) bootstrap tier (advisory-only until
    CI adoption per §4.5); (b) umbrella tier (canon umbrella JSON has
    `required_status_checks: null` by design — do NOT change to
    `contexts: ["call / verify"]` as that reverses a canon design choice
    and requires `--admin` on every submodule bump per §4.4).**
    Canonical name fixed per §4.3.
  - §12 (edit) — new compliance-evidence row.
- `docs/local-pre-push.md` — full rewrite (H8 fix). Reference to
  `SKIP_LOCAL_AI_REVIEW` deleted; new §2 documents the OPS-0069 audit-trail
  phrase + local hook pattern; §5 prereqs drop `claude` CLI dependency
  (canon script is bash-only).
- `docs/README.md` — line 21 stale description updated to reflect the
  post-OPS-0069 rewrite ("local AI review via `claude` CLI mirrors CI's
  `ai-review.yml` gate" → "canonical OPS-0069 pre-push audit-trail check
  - mechanical linter pass; bash-only, no CLI dependency").
- `CHANGELOG.md` — [Unreleased] entry.

**6 surfaces** — bundled as atomic doc-suite per PLAN-001 §5.1 precedent
(REPO_STANDARDS.md canon PR was 3 surfaces). Founder OK required for
bundle beyond Rule 1 cap.

**Rollout gate:** merges before PR-U2/U3/U4.

### 5.2 PR-U2 — installer + apply-standards.sh coverage

**Purpose:** mechanical apply of the pre-push hook via existing tools.

**Files created / touched:**

- `install/install.sh` (edit) — extend to install
  `scripts/pre_push_check.sh` from canon + merge the
  `.pre-commit-config.yaml` fragment (M5 fix — idempotency semantics):
  - Idempotency key: canonical marker comment `# CANON: aidoc-flow-ci
    pre_push_check` inserted immediately above the hook block. If
    present, install.sh treats the file as canonical-installed → no-op.
  - `default_install_hook_types` root key: if consumer file already has
    it, install.sh verifies it includes both `pre-commit` and `pre-push`;
    if not, install.sh UPGRADES the value in-place using `yq` (or Python
    `ruamel.yaml` fallback) — does NOT naive-concat which would produce
    invalid YAML.
  - Existing `pre-push`-stage hook from other sources: coexists side-by-
    side (canon hook appended; other hooks preserved). Consumers can
    reorder manually if execution-order matters.
- `install/apply-standards.sh` (edit) — add `scripts/pre_push_check.sh`
  (exact-match) + `.pre-commit-config.yaml` (subset — canon fragment
  lines present) to the drift matrix for `--check` / `--dry-run` /
  `--report` modes. `--apply` stays **server-side-only** (labels +
  repo-settings + actions-permissions + branch-protection via
  `gh api`); file installation is `install.sh`'s job (initial adoption
  path); per-repo file drift is corrected via per-repo compliance PR
  (§5.5 Wave 0–5 rollout).
- `CHANGELOG.md` — [Unreleased] entry.

**3 surfaces** — Rule 1 compliant.

**Rollout gate:** merges after PR-U1.

### 5.3 PR-U3 — CI belt-and-suspenders reusable

**Purpose:** shared `audit-trail-check.yml` reusable + WORKFLOWS.md
registry integration.

**Files created / touched:**

- `.github/workflows/audit-trail-check.yml` (NEW reusable) — implements
  §4.3 semantics: `workflow_call`; consumer `pull_request` events;
  scans `base_sha..head_sha` with `fetch-depth: 0`; exemption logic per
  §4.6; reusable's job named `verify` so check name renders as
  `call / verify`.
- `install/templates/labels.json` (edit) — add `skip-audit-trail` label
  (canon §5.3 area label) so consumers can apply the two-signal override
  per §4.6.
- `docs/WORKFLOWS.md` — three sub-section updates in one PR:
  - §1 catalog: new row for `audit-trail-check.yml`.
  - §2 per-repo matrix: new column.
  - §3 skip guidance: new §3.10.
- `CHANGELOG.md` — [Unreleased] entry.

**4 surfaces** — Rule 1 compliant (labels.json is a data file; WORKFLOWS.md
is one file even though 3 sub-sections change).

**Tag pin:** ships as MINOR bump `ci/v1.6.0` (additive reusable; current
tip is `ci/v1.5.1`). Per-repo rollout PRs (§5.5) pin at `ci/v1.6.0`.

**Rollout gate:** merges after PR-U2.

### 5.4 PR-U4 — aidoc-flow-ci self-adoption (bootstrap-paradox resolution)

**Purpose:** apply canon to `aidoc-flow-ci` itself before rolling out to
other consumers.

**Files created / touched:**

- `scripts/pre_push_check.sh` (NEW) — install from PR-U1 canon.
- `.pre-commit-config.yaml` (NEW or edit) — canonical block appended
  via PR-U2 install.sh semantics (idempotent).
- `.github/CODEOWNERS` (NEW from canon template) — per PLAN-001 §5.4.
- `.github/pull_request_template.md` (NEW from canon template).
- `.github/dependabot.yml` (NEW from canon template; **ship FULL canon,
  all 5 ecosystems**. Dependabot silently skips ecosystems with no
  matching manifests; trimming would create permanent DRIFT status
  because `install/apply-standards.sh` uses `exact_match_check` on
  this surface — F3 fold).
- `.gitignore` (edit) — merge canon baseline lines (subset semantics).
- `.gitattributes` (NEW — was absent pre-PR-U4; F4 fold).
- `.github/workflows/audit-trail.yml` (NEW; **not** `audit-trail-check.yml`
  — that filename is occupied by PR-U3's reusable in this same repo;
  F2 fold). Consumer caller of PR-U3 reusable, pinned at `ci/v1.6.0`.
- `.github/workflows/standards-drift.yml` (NEW; F1 fold — Wave 0 canon
  home should self-drift-check). Weekly `schedule: cron` caller
  running `bash sync/check-standards-drift.sh --tier product`;
  warning-only per canon §3.1b (never blocks).
- `CHANGELOG.md` — [Unreleased] entry documenting the self-adoption
  bundle + negative-test result (see below).

**10 surfaces** — bundled as atomic self-adoption suite per PLAN-001
§5.4 precedent. Founder OK required.

**In-PR validation (M7 fix — canon-home is the test bed):** PR-U4
carries a documented negative-test result in its PR body:

1. On a throwaway branch, commit WITHOUT the audit-trail phrase; `git
   push`; confirm local hook rejects with the expected error message.
2. Force with `git push --no-verify`; confirm CI `call / verify` reports
   failure on the resulting PR.
3. Add the audit-trail phrase in a fresh commit; confirm both pass.
4. Delete throwaway branch. Result attached as evidence in PR-U4 body.

This is the sole canonical negative-test invocation for the plan;
subsequent §5.5 rollout PRs do NOT repeat it (rely on PR-U4's proof). Server-side settings
(branch-protection contexts add `call / verify`, apply canon labels,
apply repo-settings + actions-permissions) applied via founder-run
`bash install/apply-standards.sh --apply --repo vladm3105/aidoc-flow-ci
--tier product --ci-tag ci/vX.Y.0 --yes` as a follow-up step (F5 blast-
radius) — NOT in the PR itself.

**Rollout gate:** merges after PR-U3.

### 5.5 Per-tier rollout PRs (out-of-plan follow-ups)

After PR-U1/U2/U3/U4 land, one adoption PR per non-paused repo, per T-C
coordinated-merge-window pattern. Each PR ships:

- Canon content surfaces (5 files: CODEOWNERS, PR template, dependabot.yml
  trimmed to repo's ecosystems, .gitignore merged, .gitattributes merged).
- Self-review hook: `scripts/pre_push_check.sh` + `.pre-commit-config.yaml`
  block (via `install.sh` from PR-U2).
- CI callers, both pinned at `ci/v1.6.0`:
  - `.github/workflows/audit-trail-check.yml` (Wave 4 bootstrap + Wave 5
    umbrella omit or ship as advisory per §4.4 / §4.5).
  - `.github/workflows/standards-drift.yml` — weekly `schedule: cron`
    caller that runs `bash sync/check-standards-drift.sh --tier <name>`;
    warning-only per canon §3.1b (never blocks). Required to satisfy §7
    success criterion.

Followed by founder-run `apply-standards.sh --apply` for server-side
settings (labels + repo-settings + actions-permissions + branch-protection
with new `call / verify` context — except umbrella per §4.4 and bootstrap
per §4.5).

**Rollout waves** (numbered as WAVES to distinguish from canon §1 tier
taxonomy — "Tier" always means canon tier; "Wave" always means rollout
sequence position):

- **Wave 0 (canon home):** `aidoc-flow-ci` (canon tier = product code) —
  self-adoption via PR-U4 above.
- **Wave 1 (governance tier):** `aidoc-flow-framework`,
  `aidoc-flow-iplan-standard` — highest blast radius on spec/schema
  drift. Framework rollout PR also updates
  `framework/governance/REVIEW_REMEDIATION_FLOW.md` (and related) to
  reference the new mechanical author-side gate (M7 fix).
- **Wave 2 (ops-private tier):** `aidoc-flow-operations`,
  `aidoc-flow-business`, `aidoc-flow-iplanic`. **Operations rollout PR
  retires bespoke `scripts/pre_push_check.sh` and adopts canon**;
  operations-only checks (verified-planning `check_plan.py` + classify-
  parity) move to a thin `scripts/pre_push_check_ops.sh` wrapper per
  §4.8. Business + iplanic get standard adoption.
- **Wave 3 (product-code tier):** `iplan-runner`, `aidoc-flow-engramory`
  (aidoc-flow-ci already self-adopted in Wave 0). These also need
  `WORKFLOWS.md` §2 workflow gaps closed alongside per PLAN-001 §5.4.
- **Wave 4 (bootstrap tier):** `aidoc-flow-interlog`. Local hook only;
  CI caller file NOT installed (mirroring §4.5 decoupling).
- **Wave 5 (umbrella tier):** `aidoc-flow`. Special: canon umbrella
  branch-protection has `required_status_checks: null` (§4.4 clarified);
  rollout PR installs hook + CI caller as ADVISORY only (workflow present
  in `.github/workflows/` but caller does NOT add `call / verify` to a
  contexts array that doesn't exist). Umbrella governance PRs (submodule
  bumps) MUST carry audit-trail phrase per OPS-0069 — the local hook
  enforces this.

**Paused repos** (`aidoc-flow-knowledge-rag`, `aidoc-flow-site`): SKIP
per founder direction (2026-07-04).

## 6. Risks (unified, with all v1 fixes folded)

| # | Risk | Severity | Mitigation |
| --- | --- | --- | --- |
| 1 | Pre-push hook rejects legitimate first push (no upstream yet) | High | Canon script preserves reference impl's `git rev-parse --verify --quiet @{upstream}` detection + graceful fallback to `origin/main..HEAD` (M10 fix). |
| 2 | `git push --no-verify` bypasses hook | Medium | PR-U3 CI check on `pull_request` events is the authoritative gate for the PR-based flow. Direct pushes to protected branches require `--admin` and are governed by OPS-0062 anyway. |
| 3 | Author forgot audit-trail phrase → push rejected | Medium | Hook error message includes exact phrase to append. `git commit --amend` recovery is one command. |
| 4 | CI check false-positives on bot / mechanical commits | High | Explicit exemption list per §4.6 (Dependabot / Renovate / github-actions[bot] / git revert / two-signal `skip-audit-trail` override). |
| 5 | Required-check activation blocks in-flight PRs on target repos | High | Each rollout PR follows PLAN-001 §5.4 F5 pattern: content surface + hook + workflow caller ship first; branch-protection contexts ADD `call / verify` in a follow-up founder-run `apply-standards.sh --apply` AFTER the workflow lands green (L6 fix). |
| 6 | Umbrella `--admin` bypasses required check | Low | Intentional per §4.4 (OPS-0062 governance layer). Documented not-a-bug. |
| 7 | Operations retire-bespoke-script window leaves a gap | Medium | Sequenced: canon script has full parity with operations' current audit-trail check BEFORE ops retires its own. `pre_push_check_ops.sh` wrapper preserves verified-planning + classify-parity checks. |
| 8 | Rollout of 8 repos + coordinated `--apply` invocations → cascade of amendment PRs | Medium | Roll out tier-by-tier per §5.5 (governance first, umbrella last). Each rollout PR self-hosts the discipline (carries audit-trail phrase in its own commit). |
| 9 | Framework's existing REVIEW_* governance docs contradict new mechanical layer | Low | Framework rollout PR updates `REVIEW_REMEDIATION_FLOW.md` (and 4 sibling docs) to reference the new author-side gate (M7 fix). |
| 10 | Windows CRLF line endings break audit-trail-phrase grep | Low | `grep -qF` fixed-string matches phrase within a single line; CRLF doesn't cross the phrase boundary. Verified pattern; noted for future contributors (L3 fix). |
| 11 | Circular source-of-truth (canon vs. ops reference impl) | Medium | Canon on aidoc-flow-ci is authoritative going forward; operations adopts canon like every other consumer (M1 fix + §4.8). |
| 12 | Fork-PR external contributors don't know about OPS-0069 | Medium | PR template (already canon) includes OPS-0065 reminder; `skip-audit-trail` label available for external contributors (§4.6 two-signal override); CI check exempts fork-PRs on request via label. |

## 7. Success criteria (verifiable)

- All 8 non-paused repos pass `bash install/apply-standards.sh --check`
  with zero drift + zero missing surfaces (content templates present +
  canon-compliant).
- All 8 non-paused repos have `scripts/pre_push_check.sh` +
  `.pre-commit-config.yaml` block installed.
- All non-bootstrap non-paused repos have `audit-trail-check.yml` caller
  in `.github/workflows/` + `call / verify` in branch-protection
  `contexts` (bootstrap skips CI-check requirement per §4.5).
- **Verifiable negative test** (per tier, on a scratch branch, single
  time): commit without audit-trail phrase → confirm local hook rejects
  `git push` with the expected error message. Then `git push --no-verify`
  → confirm CI check reports failure on the PR. Then add phrase to a
  fresh commit → confirm both pass. Scratch branch deleted after.
- `sync/check-standards-drift.sh` per non-paused repo returns `0 drift,
  0 fetch/scope error(s)` when run in that repo's CI.
- Zero regressions on operations' existing enforcement: OPS-0069 audit-
  trail check continues to gate ops PRs after canon adoption; verified-
  planning + classify-parity checks preserved via ops-specific wrapper.

## 8. Cross-references

- OPS-0061 (governance PR discipline) — `aidoc-flow-operations/ops/DECISIONS.md`
- OPS-0062 (AI-agent auto-merge default + exceptions) — same
- OPS-0065 (multi-agent automated review) — same
- OPS-0066 (3-cycle circuit-breaker) — same
- OPS-0067 (aidoc-flow-standard scope) — same
- OPS-0069 (mandatory pre-push audit-trail; NO env-var escape hatch) — same
- **PLAN-001 (repo standards canon — Phases 1–5 shipped)** —
  `plans/PLAN-001_repo-standards-canon.md`. This plan absorbs PLAN-001
  §5.4 rollout scope; PLAN-001 remains as historical record.
- Umbrella `CLAUDE.md` "Multi-agent automated review" (OPS-0067 scope
  declaration) + "AI agent auto-merge default (OPS-0062)".
- Reference implementation (retiring) — `aidoc-flow-operations/scripts/
  pre_push_check.sh` @ current tip. Preserved in git history; will be
  replaced by canon-consumption per §5.5 Tier 2.
- Cross-repo playbook — `aidoc-flow-operations/docs/CROSS_REPO_PLAYBOOKS.md`
  §T-C (referenced from ops; `aidoc-flow-ci` mirror is out-of-scope per
  L2 acknowledgement).
- Consumer-facing local pre-push guide — `docs/local-pre-push.md`
  (fully rewritten in PR-U1 per §5.1).

## 9. Supersession + audit trail

### 9.1 Supersession

- **PLAN-002 (v1)** — 2026-07-07 first draft; DRAFT status; never
  proceeded to impl. Superseded by this document; kept in git history
  for reference. Adversarial review (2026-07-07, `documentation-
  specialist` agent) identified 20 substantive findings; all folded here.
- **PLAN-001 §5.4** — Phases 1–5 of PLAN-001 shipped 2026-07-07 (PRs
  #55, #56, #57, #58, #60). PLAN-001 §5.4 per-tier rollout scope is
  absorbed into this document (§5.5); PLAN-001 remains as historical
  record of the canon design + phases 1–5 audit trail.

### 9.2 Audit trail

- 2026-07-07 — Plan drafted (unified successor).
  Origin: workspace-wide audit surfaced 7/8 non-paused repos lack
  mechanical pre-push enforcement despite CLAUDE.md discipline; PLAN-001
  §5.4 rollout was pending; PLAN-002 v1 draft had 20 review findings.
  Unified per founder direction 2026-07-07: "revise PLAN-001 and
  PLAN-002 together. It looks like we can merge them into one update
  plan."
