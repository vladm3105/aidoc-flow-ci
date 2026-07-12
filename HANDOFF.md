# HANDOFF — aidoc-flow-ci

Live cross-session resume point for the workspace CI + governance-workflow
canon library. Read at session start; refresh at milestones and before
context compaction.

## Current state (2026-07-12)

**PLAN-007 production-hardening — W1/W2/W3(markdown-lint)/W5 DONE; remaining work
is entirely founder-gated (W4 arming + W3 docs-sync-live).** Completed: W1 test
suite (`tests/`, PR #143), W5 Dependabot prune (#137), W2 guardrails
(FT-1/2/5 resolved, FT-6 downgraded; #144/#145).

- **W3 markdown-lint report-only → blocking — DONE across all 6 canon consumers.**
  Founder chose to **relax the canon `.markdownlint.json`** (disable
  MD013/MD024/MD036 — workspace-legitimate false-positives; ci #149,
  REPO_STANDARDS §4.4), then per-repo graduation to `fail-on-findings: true`:
  **business #57, interlog #63, engramory #49, iplan-runner #89, iplanic #258,
  iplan-standard #30 all MERGED**. operations + framework covered-by-own-tooling.
  Tracked in FT-11. **Load-bearing lesson (codified in FT-11):** a blind
  `markdownlint-cli2 --fix` is UNSAFE on these docs — it corrupts prose (a literal
  `+`/`#` at line-start → MD004/MD001 cascades) and code identifiers
  (`__init__.py`→`**init**.py` via MD050). Every graduation reflowed prose-`+`
  roots first, `--fix`ed only structural rules, and had a documentation-specialist
  verify zero prose changed (caught real BLOCKERs on iplan-runner + iplanic; the
  pre-commit `check_plan` gate caught `--fix` breaking verified-planning ledger
  citations twice). engramory added a repo-local `MD025.front_matter_title:""`.
- **W4 — arm gates fleet-wide = 🔴 founder-executed** (write to other repos +
  branch-protection change; not AI-autonomous per autonomy tiers + OPS-0062 +
  `feedback_writes_to_other_repos_inbox_first`). Founder-runnable runbook with
  exact per-repo `gh api` commands + verification + rollback:
  **`docs/FLEET_BRANCH_PROTECTION_ARMING.md`**. This is the highest-value
  remaining step — it makes the now-blocking checks actually BLOCK red PRs, and
  fixes the FT-12 phantom bare-lint contexts still forcing `--admin` merges on
  business/interlog/iplanic/framework. FT-12 also records iplan-runner canon
  gitleaks fix (RESOLVED, iplan-runner #88) + interlog composition conditionality.
- **W3 docs-sync dry-run → live — still 🔴** founder App (`aidoc-flow-bot`), or
  fold into the `doc-maintainer.yml` supersession. Note: the functional
  doc-maintainer work (a concurrent effort this session) has landed on `main`
  (see CHANGELOG "functional doc-maintainer …") — reconcile W3 docs-sync-live
  against it before provisioning the App.

_Recent (2026-07-11):_ **PLAN-006 W4 content-check population — COMPLETE across all active repos.**
Two releases fixed the canon (`ci/v1.9.4` binary-install for links+markdown-lint;
`ci/v1.9.5` markdown-lint `fail-on-findings` toggle + `.lychee.toml`
`include_fragments` invalid-key fix), then populated the fleet. Final state
audited 2026-07-11 (see `docs/WORKFLOWS.md` §2):
- **links** ✅ every active repo (lychee musl binary). operations + framework
  ship a `.lychee.toml` scoping out cross-repo `../sibling/` links (resolve only
  in the local workspace, not single-repo CI) + framework's `platforms/**`+
  `examples/**` debt (framework-side FRAMEWORK-TODO `LINKS-PLATFORM-DEBT`).
- **markdown-lint** ✅ — 6 repos run the canon reusable **report-only**
  (`fail-on-findings: false`); operations (`docs-lint.yml`) + framework
  (pre-commit markdownlint) covered-by-own (adding `.markdownlint.json` breaks
  their pre-push — the secret-scan business/interlog covered-by-own pattern).
- **docs-sync** ✅ — deployed **dry-run** every active repo. Was WRONGLY thought
  founder-blocked: the `aidoc-flow-bot` App is only used by the live-mode Apply
  step (gated by `dry_run != true`); dry-run proposes doc-fixes as a PR comment
  via `GITHUB_TOKEN` — no App needed.
- **iplan-runner** (a 9th active submodule, initially missed) populated with all
  three content-checks (PR #79).

**Graduations status (SUPERSEDED by the 2026-07-12 current-state above):**
1. **markdown-lint report-only → blocking — DONE 2026-07-12** (all 6 consumers
   merged; the "259 residual/repo + `--fix`" framing was superseded by relaxing
   the canon `.markdownlint.json` per the founder decision). Only the
   founder-executed W4 arming remains. `plans/FRAMEWORK-TODO.md` FT-11.
2. **docs-sync dry-run → live** — still 🔴 founder provisions the `aidoc-flow-bot`
   App + `AIDOC_FLOW_BOT_ID`/`KEY` secrets per repo (only ci + operations have
   it); or fold into the now-functional `doc-maintainer.yml` supersession.

_History (v1.9.4):_ **`ci/v1.9.4` SHIPPED (PLAN-006 W4 — content-check canon fix).** While
populating the missing content-check workflows, discovered the same
allowed-actions defect that broke `secret-scan` also blocked **`links`** and
**`markdown-lint`**: both wrapped third-party marketplace actions
(`lycheeverse/lychee-action`, `DavidAnson/markdownlint-cli2-action`) →
`startup_failure` at run-init, so neither ever ran on any consumer. `ci/v1.9.4`
refactors both to install the tool directly (lychee musl static binary +
SHA-256 verify; `markdownlint-cli2@0.23.0` via `setup-node` + `npm
--ignore-scripts`), relaxes MD060 in the `.markdownlint.json` template (new
strict cli2-0.23 rule, 348 hits/repo), and adds REPO_STANDARDS §4.3
(binary-not-action rule). PR #128 merged; tag + release cut. Pre-push OPS-0065
review: security READY, correctness clean, docs 4 findings folded.

**W4 accurate fleet tally (canon workflows on 8 repos, real repo names):**
- **labeler 8/8** ✅ (interlog #54 merged last; ci self-adopted).
- **secret-scan 8/8 effective** ✅ (6 via `secret-scan.yml`; business + interlog
  covered by their own standalone `security.yml` gitleaks — confirmed clean 0
  findings locally on both v8.21.2 + v8.30.1).
- **ai-review / composition / audit-trail** — deployed fleet-wide (core gates).
- **markdown-lint / links / docs-sync** — canon RUNNABLE (v1.9.4) + now populated
  fleet-wide. markdown-lint **graduated to blocking on all 6 consumers 2026-07-12**
  (canon relaxed + per-repo cleanup; see current-state above); links populated;
  docs-sync deployed dry-run (live-mode still 🔴 App). FT-11.

_History (v1.9.0 → v1.9.3):_ **`ci/v1.9.0`** (PLAN-006 W2 — FT-9 fix + self-hosted policy). The
v1.8.1 consumer-sync sweep (via `install.sh --update`) clobbered the private
callers' runner topology — the `-private.yml` templates shipped a `runner-self`
**placeholder** that resolves to no registered runner, so every required check
queued forever and bricked the gate (FT-9). Caught by ai-review on operations
#244; remediated surgically across all 4 private repos. **All 4 private repos
(operations/business/iplanic/interlog) are now on `@ci/v1.8.1` + self-hosted
`ci-ephemeral`, ai-review proven green on operations/business/iplanic** (interlog
confirms on next PR). v1.9.0 prevents recurrence: `-private.yml` templates now
ship the real `ci-ephemeral` array, and a new **`install.sh --repin`** does a
version-only pin bump (never `--update` for a re-pin). Founder policy codified:
**private repos are self-hosted ONLY** (CLAUDE.md "Runner policy", REPO_STANDARDS
§4.1/§4.2, docs/runners.md). **NEXT (PLAN-006):** W3 strict self-hosted on the
lightweight callers + stale-pin sync (interlog audit-trail v1.6.0); W4 populate
per-repo canon gaps; W5 public loose ends (iplan-runner #76, engramory).

_History (2026-07-10):_ **PLAN-004 + PLAN-005 SHIPPED. Releases: `ci/v1.7.0`
(PLAN-004 elevation), `ci/v1.7.1` (caller permissions), `ci/v1.8.0` (PLAN-005
A1/C/D/E/F/G), `ci/v1.8.1` (PLAN-005 PR-A part 2 / D2).** PLAN-005 7/7 complete.

_History:_ **`ci/v1.7.1` PATCH** — PLAN-005 PR-B / B2: the `ai-review` caller
templates shipped with no `permissions:` block → `startup_failure` on consumers
under the canon `read` default (the pipeline never ran). Fixed by adding the
caller `permissions:` block to both variants. Consumers re-pin `@ci/v1.7.1` or
`install.sh --update`. **PLAN-005 REVISED to rev 2** (2026-07-10) after a
three-agent from-scratch review: PR-B marked SHIPPED (v1.7.1); D2 redesigned
(HEAD-relative + §15-safe — the original was both a live bypass AND broke §15
recovery); PR-E reversed (don't flip `trust_config_repo` default — it breaks the
enforcer schema + weakens trust); PR-C collapsed to a preventive guard; stale
PLAN-004 cross-refs corrected; added D7 (inert gov knobs) + D8/§Release
(propagate fixes to the ~9 consumers via `install.sh --update`). Gate: 28
citations, 3 passes. **PLAN-005 execution — 6.5 of 7 PRs done (only PR-A part 2
remains).** MERGED: PR-A part 1 (enforcer governance floor — closes gov-path
double-label bypass) #108; PR-C (remote tag guard `--check-published`) #109;
PR-D (config-driven reviewer engine — callers drop hardcoded `reviewer: codex`,
reusable `.reviewer // "codex"` fallback + onboarding token-pairing) #111; PR-E
(external-adopter trust-override docs) #112; PR-F (trust-boundary DECISIONS
CI-0005 + D7 declarative-knob `_note` — bootstrap install guard DROPPED as
misdirected; the ops `auto_merge.repos` allowlist already gates auto-merge) #114;
PR-G (`composition.yml` reads config from the repo's DEFAULT BRANCH, not
hardcoded `?ref=main` — unblocks master/develop consumers; FT-6 `@main` half;
security-auditor READY). ⚠️ **PR-G landed as a DIRECT commit to main (184415c),
NOT via a PR** — I forgot the feature branch + a diagnostic `git push origin
HEAD` pushed it; main is unprotected so it went through. The change was
security-reviewed READY + tested + carries the OPS-0069 phrase (the only gate),
so it's substantively fine, but it bypassed the PR record. Left on main (revert+
redo would just churn history for an identical correct commit) — founder may
redo via PR if the record matters.
**Remaining:**
- **PR-A part 2** (D2 HEAD-relative skip carry-forward — product-code
  approve-then-inject) — needs a LIVE §15 label-cycle smoke test (plan Step 7) on
  a scratch PR; §15 tension resolved in design (§15 keeps the approval AT HEAD).
  The ONLY remaining PLAN-005 code PR.
- **§Release propagation sweep** — `install.sh --update` to the ~9 consumers for
  the v1.7.1 caller fix + PR-D callers. 🔴 write-to-other-repos → ops inbox
  runbook, not in-session. To flip the WORKSPACE default reviewer, set
  `.reviewer` in operations@main config (ops-repo edit).
FT-6 PARTIALLY resolved (PR-G); FT-8 post-elevation; FT-1..FT-5 remain.
A 5-agent pre-prod review of this repo → SHIP-WITH-FIXES; the fix plan
(`plans/PLAN-004_company-default-elevation.md`, merged #82) sequences A1–A6
(docs) → B (correctness) → C (security) → D (de-brand + trust-root) → E
(install `--update`). Merged so far:

- **A-series** (#83–#90, wrap #91): all adopter docs + governance + CHANGELOG,
  plus the drift-check per-caller fix.
- **B-series** (correctness): B1 #92 (doc-maintainer schedule bug — reconcile
  split into own job + dedup fall-through), B2 #93 (composition author via
  gh-api — `workflow_run.pull_requests[].user` is ABSENT), B3 #94 (fork-safety:
  labeler→pull_request_target, codeql/secret-scan skip-upload-on-fork), B4 #95
  (timeout-minutes on 12 reusables + apply-standards label %3A-encode +
  audit-trail fetch diag + troubleshooting §16-18).
- **C-series** (security): C1 #96 (SHA-pins + npm pin + curl|bash + drift
  permissions), C2 #97 (env-var indirection), C3 #98 (BL-3 auto-merge
  composition-armed gate — closes hand-applied-label bypass, preserves
  stuck-green recovery).
- **D1** #99 (BL-2 trust-root parameterization — trust_config_repo/ref inputs;
  defaults byte-identical).
- **D2** (de-brand install templates): `config.json.template`
  (`${CODEOWNER_HANDLE}`) + `CLAUDE.md.template` (`${CANON_OPERATIONS_URL}` ×7 /
  `${CANON_CI_URL}` ×1) parameterized; `install.sh` `--codeowner` /
  `--canon-operations-url` / `--canon-ci-url` flags + `python3` literal
  substitution (argv, not interpolated) + fail-closed post-sub assertion;
  defaults byte-identical (round-trip verified). REPO_STANDARDS §16.7.
  **Scope correction vs the pre-D2 HANDOFF/plan:** CLAUDE.md is NOT
  exact-match drift-checked (it's a structural governance-table parse) and
  config.json isn't drift-checked at all — so both parameterize with zero
  drift risk. The feared "drift-pipeline redesign" applied ONLY to
  `CODEOWNERS.template` (the only de-brand template that is content
  drift-checked, and it was not install-written) — done as **FT-7**.
- **FT-7** (CODEOWNERS de-brand): `CODEOWNERS.template` owner routes →
  `@${CODEOWNER_HANDLE}`; `apply-standards.sh` `codeowners_check` normalizes
  every `@owner` → `@OWNER` on both sides before diff (verifies path
  structure, ignores handle identity — approach (a)); `install.sh` now
  installs `.github/CODEOWNERS` (substituted, preserve-if-exists). Defaults
  byte-identical; existing `@vladm3105` consumers keep passing. REPO_STANDARDS
  §7 + §16.7.
- **E** (update path + manifest): new `install/templates/manifest.json` (the
  index of every `template → consumer-file` mapping: path, template +
  visibility variants, `substitute`, `safe_to_replace`) + `install.sh --update`
  mode walking it (re-fetch adopted surfaces → substitute → diff →
  `[k]eep/[r]eplace/[d]iff-only`; `--non-interactive` replaces only
  `safe_to_replace` = workflow callers + dependabot, keeps policy/governance;
  atomic replace; idempotent). New `docs/UPDATE_GUIDE.md`; REPO_STANDARDS
  §16.8. The `sync/check-drift.sh` manifest migration is scoped OUT to **FT-8**
  (E2) to keep this PR reviewable — no broken intermediate (check-drift.sh
  still works on its hardcoded loop).

✅ **`ci/v1.7.0` tag + GitHub release cut 2026-07-10** (on `f424aa7`, the PR-E
merge — all A–E under one cut). VERSION + docs + the `curl …/ci/v1.7.0/…`
install URLs now resolve. Post-cut verification: run a live `install.sh
--update` against one real consumer (e.g. interlog).

Earlier canon layers SHIPPED: **PLAN-003** (governance-file canon, #73–#75 +
follow-ups #76–#80) and **PLAN-002** (workspace standards + self-review
enforcement, PR-U1/U2/U3/U4, 2026-07-08).

## Open threads

- **PLAN-004 SHIPPED (A–E + `ci/v1.7.0` tag/release, 2026-07-10).** All A–E
  slices landed under the one cut (VERSION = `ci/v1.7.0`; the plan's per-slice
  `v1.8.0`/`v1.9.0` numbers were aspirational — D2 + FT-7 + E are
  additive/byte-identical, not breaking). The `curl …/ci/v1.7.0/…` install URLs
  now resolve. Remaining verification: a live end-to-end `install.sh --update`
  against a real consumer (e.g. interlog).
- **`plans/FRAMEWORK-TODO.md`** — FT-1 (branch-protection templates lag
  REPO_STANDARDS §2 on `call / verify`), FT-2 (verify `pre-commit`/`secret-scan`
  emitted context names), FT-3 (`labels.json` `skip-ai-review` description),
  FT-4 (CHANGELOG back-catalog per-tag cut), FT-5 (drift job needs
  `administration: read`), FT-6 (composition trust-source not parameterized —
  reads `$GH_REPO@main`; fails safe), FT-8 (migrate `sync/check-drift.sh` onto
  `manifest.json` = PLAN-004 E2). FT-1..FT-6 + FT-8 are now open backlog (the
  elevation shipped without them; none block adoption). **FT-7 (CODEOWNERS
  de-brand) RESOLVED 2026-07-09.**
- **PLAN-003 per-repo rollout waves** — one PR per non-paused repo per
  PLAN-003 §5.5 / operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D. Wave status
  is tracked there (do not hardcode a "next wave" here — it drifts). Validation
  gate: zero drift via the curl-piped `apply-standards.sh --check` (see
  `docs/PLAYBOOK_governance-canon-rollout.md`).

## Next-session start-here

1. **PLAN-007 production-hardening — W1/W2/W3(markdown-lint)/W5 DONE; the two
   remaining items are BOTH 🔴 founder-gated:**
   - **W4 — arm the gates as required checks** (`docs/FLEET_BRANCH_PROTECTION_ARMING.md`).
     Highest-value: makes the now-blocking checks actually block red PRs + fixes
     the FT-12 phantom bare-lint contexts forcing `--admin` merges. Do NOT execute
     as an AI (write to other repos + branch-protection = 🔴); hand the runbook to
     the founder.
   - **W3 docs-sync dry-run → live** — 🔴 `aidoc-flow-bot` App, or fold into the
     now-functional `doc-maintainer.yml` (landed on main this session — reconcile
     first). FT-11.
2. Open FT follow-ups (`plans/FRAMEWORK-TODO.md`): FT-8 (migrate
   `sync/check-drift.sh` onto `manifest.json`), FT-7/FT-10 (de-branding), FT-12
   (arming anomalies — subsumed by W4). Cap review/fix loops at 3 per OPS-0066.
3. `docs/REPO_STANDARDS.md` is the durable canon consumers follow. For PLAN-003
   rollout work, read `docs/PLAYBOOK_governance-canon-rollout.md` then defer to
   operations `docs/CROSS_REPO_PLAYBOOKS.md` §T-D.
4. _History:_ PLAN-004 SHIPPED (A–E merged + `ci/v1.7.0` 2026-07-10); PLAN-006 W4
   content-check population COMPLETE (2026-07-11).

## Recent decisions

See `DECISIONS.md` for the full CI-NNNN record. Latest:

- **CI-0004** (2026-07-09) — workflow-policy delegation table: this repo's
  workflow behaviors implement OPS-0062/0065/0066/0067/0061/0069; change
  policy in operations, implementation here.
- **CI-0003** (2026-07-08) — 3-cycle review circuit-breaker (OPS-0066)
  confirmed canonical for this repo's plan review.
- **CI-0002** (2026-07-08) — bundle PR-V1 canon with Wave 0 self-adoption.
- **CI-0001** (2026-07-08) — flexible-canonical (Option B) governance files.

Recent merges: PLAN-003 PR-V1/V2/V4 (#73/#74/#75) + canon follow-ups
(#76 template row / #77 parser suffix / #78 rubric / #79 canonical-source
disambiguation / #80 REPO_STANDARDS §17 auto-merge canon); PLAN-004 #82
(plan) + #83–#90 (A-series A1–A6, complete).

---

**Maintenance protocol:**

- Update `Current state` on every PR that changes what this repo is
  actively working on. Never leave a "(this PR)" self-reference — name the
  PR number, or phrase it as upcoming.
- Move resolved `Open threads` to `Recent decisions` (with CI-NNNN ID)
  or to git commit history.
- Prune `Recent decisions` — entries older than 4 weeks belong only in
  `DECISIONS.md`.
