# HANDOFF — aidoc-flow-ci

Live cross-session resume point for the workspace CI + governance-workflow
canon library. Read at session start; refresh at milestones and before
context compaction.

## Current state (2026-07-17)

**`ci/v2.1.2` is cut + released (Latest) — the pre-prod-hardened canon plus the
ai-review large-diff fix.** Three tags shipped this session, in order:

- **`ci/v2.1.0`** — a 5-lens pre-prod review (security/correctness/docs/
  portability/governance) of the canon as company-default source of truth
  returned BLOCKER; all canon-side blockers closed (#175–#177):
  - **#175** — 3 security/correctness blockers: `composition` exempted every
    author on a malformed trust config (`jq -e` exits 4 on a parse error, not
    just 1 on author-absent → `! jq -e` fired → `exit 0`; it is the SOLE
    App-approval enforcement, and tier templates set
    `required_approving_review_count: 0`); `VERSION`/`CI_TAG_FALLBACK` said
    `ci/v2.0.0` while `v2.0.1` was live, so every CI_TAG-less `--repin` pinned
    consumers BACKWARDS (now mechanically synced + `tests/test_version_sync.sh`
    guards it); `ai-review` `APP_KEY_PRESENT` tested KEY-only in the review job
    → half-provisioned repos hard-bricked.
  - **#176** — 6 `-private` template variants (`links`, `markdown-lint`,
    `pre-commit`, `secret-scan`, `labeler`, `docs-sync`): `--update` on a
    private repo used to revert them to the label-less generic →
    `ubuntu-latest` → queue forever. `--update` is now safe on private repos.
  - **#177** — adopter cold-start: LiteLLM-proxy prerequisite stated, secrets
    ordered before the PR, `AI_CI_DEPLOYMENT.md` linked as the front door.
  - Earlier flowci-feedback triage (merged #173): `secret-scan` config canary,
    `check-drift.sh` manifest coverage (FT-8), `audit-trail` manifested,
    REPO_STANDARDS §4.3/§4.3a/§4.3b/§4.3c, FT-13/FT-14.
- **`ci/v2.1.1`** — ai-review large-diff fix (**PLAN-011**, from consumer bug
  report llm-router PR #7: the required gate failed on large PRs with
  `ResponseShapeError` → `exit 1`, blocking merge even when every other check
  was green). Root cause, live-verified: `deepseek-v4-pro` reasoning tokens
  count against `max_tokens`, and at 4096 the reasoning exhausts the budget
  mid-JSON → the strict verdict parser rejects the truncation. Fix: verdict-mode
  `max_tokens` default 4096→8192; a residual infra failure now surfaces honestly
  as the new `ai:review-infra-error` label + comment (F4) instead of a fake
  `CHANGES_REQUESTED`. Proven against the live model — 4096 reproduces the
  failure on a complex 45-file diff, 8192 produces a valid verdict.
- **`ci/v2.1.2`** — verdict-budget headroom bump 8192→24576 (PLAN-011
  follow-up). Live-probed the model accepts ≥65536; the practical ceiling is the
  client's own 32768 validator. A typical complex verdict uses only ~2.3k
  tokens, but reasoning spikes non-deterministically — the headroom covers a
  heavy-reasoning spike on a near-400 KB diff, and costs nothing extra
  (per-actual-token billing).

**All canon work for this session is landed + released; both `aidoc-flow-ci` and
`operations` have 0 open PRs.** PLAN-011 is SHIPPED (see
`plans/PLAN-011_ai-review-large-diff-hardening.md`).

**What remains — founder-gated fleet rollout (🔴 cross-repo, NOT canon code).**
Runbook: `../operations/ops/inbox/2026-07-17_cto-platform_flow-ci-v2.1.0-cut-and-preprod-closure.md`
(operations #268, retargeted to `ci/v2.1.2`):

1. **Re-pin the fleet to `ci/v2.1.2`** — version-only `--repin` with an explicit
   `CI_TAG` (safe; a re-pin never clobbers `runner_labels` — that is `--update`).
2. **Arm branch protection** — `aidoc-flow-ci` itself (canon), `engramory`, and
   `iplan-standard` have **no branch protection at all**; `business` + `iplanic`
   require only the phantom bare `Lint / format / security hooks` context per
   FT-12, so `composition` is not a required check and they merge via `--admin`
   (no real review gate — this is the pre-prod security finding).
3. business/iplanic/interlog are still on the retired `aidoc,ci-ephemeral`
   runner pool (now tool-migratable via the #176 `-private` variants +
   `--update`, but still needs executing).

These gate the *rollout*, not the tags — the tags are cut. Arming runbook:
`docs/FLEET_BRANCH_PROTECTION_ARMING.md`.

**Read before touching FT-13.** Its claim has been wrong three times in three
directions; the entry documents each miss and the check that would have caught
it. Verified: iplanic's standards-drift caller pins `e15ec7d…`, the **annotated
tag object** of `ci/v1.6.0` rather than a commit, so raw has never served it —
a permanent authoring bug, not decay (deref: `git/tags/<sha> --jq '.object.sha'`
→ `e827ab82…`, HTTP 200). The same trap as the SHA-pin lesson in FT-10's
neighbourhood: `git/refs/tags/<tag>` returns the TAG object for annotated tags.

**Adoption-model root finding: `plans/PLAN-010_adoption-model.md` — DRAFT, NOT
READY.** `install.sh` only *prints* a branch-protection reminder (`:602`) and
never invokes `apply-standards.sh`; no consumer receives either `sync/` script;
5 of 6 consumers deviate identically on `enforce_admins` and canon itself is
unprotected. PLAN-010 exists but two independent reviews each invalidated its
lead phase (see its Review log); the recommended disposition is to SPLIT the
detector + consumer-caller half (evidence-producing, decision-free once D1 is
answered) from the D3/enforcement half (founder decision, unanswerable from
canon today). It has a 🔴 half (making `install.sh` apply server-side settings
mutates consumer repos); consumer-side callers go via the ops/inbox runbook.

**Fleet v2 cutover (PLAN-009) — target SUPERSEDED `ci/v2.0.1` → `ci/v2.1.2`
(operations #268); Phase 0 partially done, still 🔴-gated.** `ci/v2.0.1` was the
original fleet target (tag → `819d148`; patches `ci/v2.0.0` → `d3f4b03` with the
3 ai-review blocker fixes), but `ci/v2.1.2` is strictly better (it *contains*
v2.0.1's fixes plus the pre-prod hardening and PLAN-011), so the fleet re-pins
straight to `ci/v2.1.2` per the runbook above — do not re-pin to v2.0.1. **`operations` is advanced to `@ci/v2.0.1` and LIVE-VERIFIED (2026-07-16,
PR #265).** `plans/PLAN-009_fleet-v2-cutover.md` syncs the other **7 consumers**
(still `@ci/v1.9.5`).

**v2.0.1 verification banked on operations, not deferred to the pilot** —
operations (not the pilot) is the first armed consumer. Throwaway PR #266
confirmed **B1 live**: a synthetic auth-bypass diff drew a proper
`CHANGES_REQUESTED` naming the `[critical]` finding (no "verdict malformed"
discard) → the armed blocking path works. **B2 is source-verified only and
ACCEPTED-UNVERIFIED live** — its bypass exists *only while UNARMED*, and a live
check on 2026-07-16 found **every consumer ARMED** (`APP_REVIEWER_1_BOT_ID` set on
engramory/operations/framework/interlog), so none can enter the B2 path. The
obvious pilot test would pass **vacuously via the armed skip** (it would have
passed on buggy v2.0.0 too) — do NOT book it as B2 closure. Exercising B2 needs a
deliberately **unarmed fixture**. Residual risk is low precisely because the
bypass is unreachable while armed. **The `python3` preflight (HIGH) is likewise
not live-exercised.**

**Phase 0 status (verified live 2026-07-16):**

- ✅ LiteLLM secrets on the **private trio** (business/iplanic/interlog, set
  2026-07-15). ❌ still absent on the **4 public repos** (engramory, framework,
  iplan-standard, iplan-runner) — **no org inheritance** on a personal account,
  so each needs them set individually.
- ❌ `ci-runner,single-use` pools on business/iplanic/interlog (only operations
  has one; they still carry the v1 `aidoc,ci-ephemeral` runner).
- ✅ **public-reachability RESOLVED** — no public endpoint needed. Public repos
  run only the ai-review *review* job on the ephemeral self-hosted pool via
  `runner_labels_review` (PLAN-009 **Edit F**); LiteLLM stays private.

Runbook: `../operations/ops/inbox/2026-07-14_founder_flow-ci-v2-fleet-cutover-prereqs.md`.
**Nothing in PLAN-009 Phase 1+ (engramory pilot → propagate) starts until the
remaining 🔴 items (public-repo secrets + private pools) are confirmed live.**

**Unified LiteLLM agent gateway (`feat/unified-litellm-agents`) — SHIPPED as
`ci/v2.0.0`.** *(2026-07-12 note, now historical — the implementation below was
published and consumed by operations.)* Implementation: `ai-review` and `doc-maintainer` now use a
dependency-free OpenAI-compatible adapter with `LITELLM_BASE_URL`, separate
review/documentation keys, and model aliases; vendor CLI paths are removed. The
change
is staged as breaking `ci/v2.0.0`, with templates, installer fallback, wizard,
standards, security docs, and tests aligned. Safety controls include HTTPS by
default (explicit private-HTTP opt-in), no redirects, bounded requests and
responses, secret-pattern redaction, exact verdict schema/semantic validation,
oversized-diff refusal, total retry deadlines, atomic outputs, and job-scoped
permissions. Config schema v2 and a real-proxy two-alias smoke workflow were
included; both LiteLLM aliases were configured and the real-proxy smoke passed
(green for `ai-reviewer` + `ai-doc-maintainer`), the PR was published + merged,
and `ci/v2.0.0` was cut (resolves to `d3f4b0320b831e38b91c4b85bb5e8b26e62296f7`).
Full suite passed (checknames 14, contracts 100, negative 9, scripts 24).
OPS-0065 review used the maximum 3 cycles: final code/failure reviewers READY;
the security reviewer’s final documentation-only finding was folded without a
prohibited fourth cycle.

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

**Graduations status (history — 2026-07-12; W4 arming still founder-gated per
current state above):**
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

- **PLAN-008 pre-prod gap closure** — 5-lens review (2026-07-13) of the
  `ci/v2.0.0` surface found 29 findings across documentation staleness,
  missing migration/release collateral, and code corrections. Grouped into
  5 PRs (plan in `plans/PLAN-008_pre-prod-gap-closure.md`).

- **PLAN-004 SHIPPED (A–E + `ci/v1.7.0` tag/release, 2026-07-10).**
- **`plans/FRAMEWORK-TODO.md`** — FT-3 RESOLVED 2026-07-12 (labels.json description
  corrected). FT-1, FT-2, FT-4, FT-5, FT-6, FT-8 remain open backlog.
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

- **CI-0006** (2026-07-12) — LiteLLM unification: all AI jobs route through
  one OpenAI-compatible LiteLLM proxy via a dependency-free Python adapter.
  Vendor CLI paths, credentials, and workflow inputs are removed. Breaking
  interface change targeted for `ci/v2.0.0`.
- **CI-0005** (2026-07-10) — trust boundary: `trust_config_repo` and
  `trust_config_ref` inputs on ai-review and auto-merge-ai-prs parameterize
  the trust source. External adopters point at their own ops/config repo;
  default is byte-identical to the prior hardcoded `vladm3105/aidoc-flow-
  operations@main`.
- **CI-0004** (2026-07-09) — workflow-policy delegation table.
- **CI-0003** (2026-07-08) — 3-cycle review circuit-breaker (OPS-0066).
- **CI-0002** (2026-07-08) — bundle PR-V1 canon with Wave 0 self-adoption.
- **CI-0001** (2026-07-08) — flexible-canonical (Option B) governance files.

Recent merges: `feat/unified-litellm-agents` (#154 — LiteLLM unification for
`ci/v2.0.0`); PLAN-007 W1/W2/W3/W5 (test suite + guardrails + markdown-lint
graduation + Dependabot prune); PLAN-006 W4 content-check population.
Earlier: PLAN-003 PR-V1/V2/V4 (#73/#74/#75) + canon follow-ups; PLAN-004
#82-#99; PLAN-005 #108-#114.

---

**Maintenance protocol:**

- Update `Current state` on every PR that changes what this repo is
  actively working on. Never leave a "(this PR)" self-reference — name the
  PR number, or phrase it as upcoming.
- Move resolved `Open threads` to `Recent decisions` (with CI-NNNN ID)
  or to git commit history.
- Prune `Recent decisions` — entries older than 4 weeks belong only in
  `DECISIONS.md`.
