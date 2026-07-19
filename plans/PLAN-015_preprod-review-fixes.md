# PLAN-015 — Pre-prod review fix closure (rollout readiness)

> Status: DRAFT — not ready until the Review log has ≥2 passes (≥1 independent)
> with a clean final pass and `check_plan.py` is green.
> Owning repo: `aidoc-flow-ci`. Target release: **`ci/v2.8.0`** (additive) for the
> code/template changes; docs-only changes ride the same tag. **The fleet
> rollout target this plan reconciles to is `ci/v2.8.0`** (the tag that first
> contains the rollout-enabling fixes below) — `ci/v2.7.0` is the pre-merge
> latest and becomes the target on ship. Pinning the fleet at v2.7.0 would pin it
> one release behind this plan's own B2 detector / install-verify / `pre_push`
> fix.

## 1. Why

A 5-lens pre-prod review (security / correctness / docs / portability /
governance, 2026-07-18) of the CI canon at `ci/v2.7.0` returned
**SHIP-WITH-FIXES with the workflows ready but the *rollout* not**. The reusable
workflows are strong (no PR-head execution in a privileged context, real SHA
pins, env-var indirection, fail-closed gates) and every gate-level bug from the
`llm-router` field report against `ci/v2.0.0` is already fixed. What blocks
*rolling out to the other repos* is two things in the adoption/governance layer:

- **B1** — the fleet rollout-target tag has three different answers across the
  docs (PLAN-009 says `ci/v2.0.1`, HANDOFF/ROADMAP say `ci/v2.1.2`, VERSION/tool
  say `ci/v2.7.0`), so an operator cannot execute the rollout without guessing.
- **B2** — `install.sh` copies workflow files but never applies or verifies the
  server-side settings (branch protection, required-checks membership, the
  reviewer-App bot-id var) that the merge gate depends on, and no consumer ever
  runs drift detection — so a rollout predictably reproduces the measured fleet
  state (canon itself unprotected, 5/6 consumers `enforce_admins=false`, an inert
  required gate).

Plus five medium and several low findings. This plan closes the **AI-doable,
in-repo** set and **prepares** the `🔴` founder-executed server-side work as a
handoff runbook — it does not execute cross-repo writes (per the writes-to-
other-repos-inbox-first rule).

## 2. Scope split — AI-doable vs 🔴 founder-gated

| Item | What | Disposition |
| --- | --- | --- |
| **B1** | Reconcile rollout-target tag to `ci/v2.8.0` across PLAN-009 / HANDOFF / ROADMAP | **AI, in-repo** (Task 1) |
| **B2-detect** | Ship `standards-drift.yml` as a manifested, opt-in **consumer** template that runs `check-standards-drift.sh` against the consumer's own repo | **AI, in-repo** (Task 2) |
| **B2-apply** | Make `install.sh` invoke `apply-standards.sh --apply` (or gate "success" on a live server-side assertion) | **AI, in-repo** for the wiring (Task 3); the **actual per-repo application** is 🔴 founder-run (Task 8 runbook) |
| **M1** | Ratify `verified_allowed: true` (keep or drop) + record decision | **Decision → founder** (Task 4 prepares both options + the DECISIONS entry) |
| **M2** | Add CI-0008/0009/0010 for the v2.2–v2.7 policy shifts | **AI, in-repo** (Task 4) |
| **M3** | `pre_push_check.sh` CHANGED list → `@{upstream}..HEAD` | **AI, in-repo** (Task 5) |
| **M4** | Ship `install/templates/.yamllint.yaml`, manifest it opt-in | **AI, in-repo** (Task 6) |
| **M5** | README "12 workflows"→15 + scanner rows; "16 labels"→18 in 3 docs | **AI, in-repo** (Task 7) |
| **L1** | `codeql-private.yml` variant + `visibility_variants` | **AI, in-repo** (Task 6) |
| **L2** | `install.sh` bootstrap/verify shellcheck+actionlint | **AI, in-repo** (Task 6) |
| **L3** | `set-litellm-secrets.sh --mint` master key off argv | **AI, in-repo** (Task 5) |
| **L4** | Remove dead redaction helpers in `litellm_client.py` (or wire them) | **AI, in-repo** (Task 5) |
| **B2-arm / M1-apply** | Per-repo branch-protection arming + bot-id var + verified_allowed change | **🔴 founder runbook** (Task 8, ops/inbox handoff) |

## 3. Tasks

### Task 1 — B1: single rollout-target tag (docs-only)

Reconcile every human-facing surface to **`ci/v2.8.0`** as the fleet target (the
tag this plan cuts; see the header note — v2.7.0 is the pre-merge latest, v2.8.0
is what the fleet re-pins to once this plan ships, so the docs never name a
target behind the rollout tooling).

- `plans/PLAN-009_fleet-v2-cutover.md`: retitle (`:1`), retarget the Status
  block and the re-pin steps from `ci/v2.0.1` to `ci/v2.8.0`; add a note that a
  v2.8.0 re-pin is **not** a drop-in — the PLAN-013 uniform-protected model
  (`ci/v2.2.0`) moves the ai-review job to self-hosted on **public** repos, so
  public consumers need a runner pool the original v2.0.1 plan never provisioned
  [Claim 12].
- `HANDOFF.md`: collapse the "What remains" narrative (`:108`–`:208`), which
  still describes a v2.1.2 world with "7 consumers still on `@ci/v1.9.5`", into
  one current section keyed to `ci/v2.8.0` as the target (v2.7.0 = latest cut)
  [Claim 13].
- `ROADMAP.md`: fix the two milestone rows that say `ci/v2.1.2` (`:31`, `:36`)
  and the self-contradiction against the `:13` "Latest is `ci/v2.7.0`" line
  [Claim 14].

**Done when:** grep across `plans/PLAN-009*.md`, `HANDOFF.md`, `ROADMAP.md`
yields exactly one fleet-target tag (`ci/v2.8.0`); no surface names `v2.0.1` or
`v2.1.2` as the *current* target (historical mentions are allowed only under an
explicit "history" heading).

### Task 2 — B2-detect: consumer-installable drift detector

`check-standards-drift.sh` already checks branch protection (`enforce_admins`,
required-status contexts, `required_signatures`) [Claim 8], and the canon
`standards-drift.yml` runs it — but only against canon itself (it auto-detects
its own repo and is absent from `manifest.json` and the wizard) [Claim 7].

- Add `install/templates/workflows/standards-drift.yml` — a scheduled caller
  that runs `check-standards-drift.sh --repo <this-repo> --tier <tier>` against
  the **consumer's own** repo (the script already supports `--repo`/tier).
  Warning-only per the IPLAN-0017 §3.1b contract (it must not become a hard gate
  without a separate founder decision).
- Register it in `install/templates/manifest.json` with `auto_install: false`
  (opt-in) and add it to the wizard's workflow list.
- The drift job needs `administration: read` to read branch protection
  (`check-standards-drift.sh:130` warns when the token lacks it) — document this
  token requirement in the template header and `docs/UPDATE_GUIDE.md`. Under a
  default `GITHUB_TOKEN` the script degrades to `warn_uncheckable` for the
  branch-protection / actions-permissions endpoints; warning-only mode tolerates
  that, but the template header must say so.

**Adoption dependency (do not mark B2-detect "done" on ship):** shipping the
template only makes drift detection *available* (`auto_install: false`). A
consumer does not run it until it is installed on that repo — which is the
per-repo work in the Task 8 runbook. So Task 2 closes "canon offers no consumer
detector"; it does **not** close "consumers can't see drift" until Task 8
installs it. State this so B2 is not read as done when the capability is merely
shipped (the exact capability-shipped ≠ deployed trap this whole review flagged).

**Done when:** a consumer that adopts the template runs drift detection on its
own repo on schedule and surfaces branch-protection drift as a warning;
`check-drift.sh`/manifest resolution finds the new template.

### Task 3 — B2-apply: install applies-or-verifies server-side standards

Today `install.sh`'s terminal step only **prints** "Set vars.APP_REVIEWER_1_BOT_ID
… until it is set, composition runs INERT" and "After CI green, apply branch
protection" [Claim 5]. `composition.yml` self-exempts green while the bot-id var
is unset [Claim 10], so an installed-but-unarmed consumer has an inert required
gate.

- Add an `install.sh` post-install **verification** step (not a cross-repo
  mutation): after files are written, call **`sync/check-standards-drift.sh
  --tier <tier> --strict`** — NOT `apply-standards.sh --dry-run`. This is
  load-bearing: `apply-standards.sh --dry-run` only checks local content-surface
  files (`codeowners_check` etc., `:425`–`:490`); every server-side read
  (branch protection, actions-permissions, labels) lives **only** in `--apply`
  (`apply_branch_protection`, `:700`), so a `--dry-run` against an unarmed
  consumer reads no protection and exits 0 green — the exact false-OK this task
  exists to prevent [Claim 9, Claim 18]. `check-standards-drift.sh --strict`
  exits non-zero on drift **or** an uncheckable control (`:308`) [Claim 19].
- **Token caveat:** `--strict` treats an *uncheckable* control (scoped token
  lacking `administration: read`, the FT-5 `warn_uncheckable` branch at
  `check-standards-drift.sh:130`) as a non-zero exit — conflating "can't verify"
  from an install-time token with "not armed." So the verify step must run with a
  token that has `administration: read`, or classify uncheckable-vs-drift and
  only *block* on genuine drift. Document the token requirement here as well as in
  Task 2.
- Do **not** have `install.sh` itself mutate consumer branch protection in this
  plan — that is the 🔴 write-to-other-repos action (Task 8). Wire the
  verification + honest reporting; leave the mutation to the founder runbook.
- `apply-standards.sh --apply --tier <t>` (the *mutation* path) already exists
  [Claim 9]; it stays owned by the Task 8 runbook, not `install.sh`.

**Done when:** running the installer against a repo with no branch protection
ends with a non-zero/loud "standards NOT applied — run the arming runbook"
signal instead of a clean success.

### Task 4 — M1 + M2: decision-log closure

- **M2 (AI):** append to `DECISIONS.md` (last entry is CI-0007 `:298` [Claim 11]):
  - **CI-0008** — uniform-protected AI-flow model (PLAN-013 / `ci/v2.2.0`): why
    public repos now run the ai-review job on the self-hosted pool and why that
    is safe (fork PRs never reach a code-executing job). This reverses the prior
    public/private visibility split, so it needs a durable anchor.
  - **CI-0009** — autofix write-App trust model (PLAN-012 / `ci/v2.3.0`,
    default-off): dedicated ephemeral-token App, governance deny-floor.
  - **CI-0010** — own-scanner suite (PLAN-014 / `ci/v2.4.0`–`v2.7.0`): binaries-
    not-marketplace-actions, report-only-first graduation, opt-in
    `auto_install: false`, the trivy static-scanner SSRF scoping, and the
    semgrep autofix-**preview**-only choice.
- **M1 (decision → founder):** `verified_allowed: true` in
  `actions-permissions.json` admits every GitHub-verified creator's action
  fleet-wide; §4.3 now documents this accurately and flags widening as "a
  decision to take deliberately." This plan **does not change the value** — it
  drafts a CI-0011 stub presenting keep-vs-drop with the security trade-off and
  routes the choice to the founder. If dropped, that is a canon change (expect
  `trivy-action`-style verified actions to then `startup_failure`) tracked as a
  follow-up, not bundled here.

**Done when:** CI-0008/0009/0010 exist with rationale; CI-0011 stub states the
open `verified_allowed` decision and its consequences. (≤3 governance doc
surfaces per the governance-PR-discipline rule — DECISIONS is one surface; keep
this task's edits within the cap.)

### Task 5 — M3 + L3 + L4: script correctness/hygiene

- **M3:** `scripts/pre_push_check.sh` computes the linted `CHANGED` file list
  from `git merge-base HEAD origin/main` … `"$BASE"...HEAD` (`:55`) [Claim 3],
  so pre-existing errors on older branch commits block every subsequent push.
  Switch `CHANGED` to the same `@{upstream}..HEAD` range the phrase-check already
  uses (`:157`) [Claim 3b], with `origin/main..HEAD` fallback on first push.
- **L3:** `install/set-litellm-secrets.sh --mint` passes the master key via
  `curl -H "Authorization: Bearer $KEY"` (argv, visible in `ps`) despite the
  file's own STDIN-only contract. Move it off argv (`-H @-` heredoc or a
  `--config` file on a private fd).
- **L4:** `scripts/litellm_client.py` defines `redact_secret_shaped` /
  `restore_redactions` that `main()`/`completion()` never call. The ai-review
  workflow already redacts inline before piping to the client
  (`ai-review.yml:569`), so these are dead code implying a protection the client
  does not itself provide — delete them (or wire them and note the double-
  redaction is intentional). Prefer deletion.
- **L5 (correctness lens #5):** `audit-trail-check.yml`'s header comment claims
  `pull_request_target` support, but the gate is `if: github.event_name ==
  'pull_request' && …` [Claim 20] — so a consumer who wires it on
  `pull_request_target` gets the `verify` job **skipped**, i.e. the audit-trail
  check silently never runs (fail-open on the gate it exists to be). Either widen
  the guard to `(pull_request || pull_request_target)` or delete the
  `pull_request_target` claim from the comment so the scope is honestly
  `pull_request`-only. Prefer deleting the claim (the reusable is not designed for
  the `pull_request_target` trust model).

**Done when:** `pre_push_check.sh` lints only the current-push range (add a
`tests/` assertion if feasible); no secret on a curl argv; no unreferenced
redaction helpers; the audit-trail `if:`/comment no longer contradict each other.

### Task 6 — M4 + L1 + L2: install ergonomics

- **M4:** add `install/templates/.yamllint.yaml` (120-char line length,
  `document-start`/`truthy` as warnings — SDD YAML-as-documentation) and manifest
  it `auto_install: false`; have `install.sh` copy it if the consumer lacks one.
  No template exists today [Claim 15].
- **L1 (confirm-first — may be moot):** `codeql.yml` has no `-private` variant
  and its `runner_labels` override is commented out [Claim 16], so a private
  caller inherits `ubuntu-latest` and queues forever. **But** CodeQL default-setup
  needs GitHub Advanced Security, which these private repos don't have — the
  manifest itself notes the semgrep SAST scanner "Complements native CodeQL (N/A
  on private)" [Claim 21]. **First verify a private consumer can actually run the
  codeql reusable at all.** If CodeQL is unavailable on private (SAST is the
  private substitute), **drop L1** — a `-private` variant fixes a path no private
  consumer reaches. Only ship `codeql-private.yml` if the confirmation shows a
  private repo genuinely reaches the reusable.
- **L2:** add an `install.sh` step (or a documented `local-pre-push.md` section)
  that checks for `shellcheck` + `actionlint` and installs/points to install
  instructions — today 2 of 5 pre-push checks silently degrade to SKIP.
- **L5b (security lens doc-nit):** `install/templates/workflows/ai-review.yml`'s
  header comment asserts the reusable "never `actions/checkout`s the PR head."
  The autofix job *does* (`ref: head.sha`), safely (trusted-author-only,
  default-off, read-only `GITHUB_TOKEN`, `persist-credentials:false`, PR code
  never executed). Add one line noting the autofix exception so a future editor
  doesn't rely on a false invariant.

**Done when:** a fresh private consumer gets a working `.yamllint.yaml`; the
CodeQL-private variant ships **only if** L1's confirmation warrants it; the
installer reports which pre-push tools are missing; the ai-review caller comment
states the autofix head-checkout exception.

### Task 7 — M5: docs vs shipped reality

- `README.md:32` says "**12 reusable workflows**" [Claim 5b] — count the
  consumer-facing reusables (the 3 scanners dep-scan/trivy-scan/sast-scan ship
  templates + manifest entries) and correct the number + add the scanner rows to
  the README table; mirror into `install/README.md`.
- "**16 canonical labels**" appears in `install/README.md:124` and
  `docs/AI_CI_DEPLOYMENT.md:200,340` [Claim 6] while `labels.json` ships **18**
  [Claim 6b]. Correct to 18 and add the two missing labels
  (`ai:review-infra-error`, `ai:autofix-escalated`) to the enumeration. Also add
  a `LABELS.md` row for `ai:enforcer-failed`, which `auto-merge-ai-prs.yml:442`
  self-provisions but is undocumented [Claim 17].

Task 7 touches **4** doc surfaces (`README.md`, `install/README.md`,
`docs/AI_CI_DEPLOYMENT.md`, `LABELS.md`) — over the ≤3 governance-PR cap. Split
into two PRs: **7a** = workflow-count (`README.md` + `install/README.md`); **7b**
= label docs (`docs/AI_CI_DEPLOYMENT.md` "16"→"18" + `LABELS.md`
`ai:enforcer-failed` row). The count is **12→15** consumer-facing reusables
(independently confirmed: of the 16 `.github/workflows/` files carrying a
`workflow_call` trigger, exactly one — `self-secret-scan` — is internal-only, so
16−1 = 15 consumer-facing. `audit-trail`, `litellm-smoke`, `standards-drift`, and
`tests` are not `workflow_call` reusables at all and never counted).

**Done when:** README count reads 15 and matches the shipped reusable set; all
three "16" sites read "18"; `LABELS.md` documents every operator-visible label a
workflow sets; neither PR exceeds 3 surfaces.

### Task 8 — 🔴 founder runbook (prepare, do not execute)

Prepare a handoff runbook (do **not** run it) that:

- Arms branch protection per repo per `docs/FLEET_BRANCH_PROTECTION_ARMING.md`
  (the existing runbook) — this is the B2-arm half and the M1-apply half.
- Installs the Task 2 consumer `standards-drift.yml` per repo (this is what
  actually closes B2's "consumers can't see drift" — see the Task 2 adoption
  dependency).
- Sets `vars.APP_REVIEWER_1_BOT_ID` on any consumer where composition is still
  inert.
- Carries the founder's `verified_allowed` decision (Task 4 / CI-0011) into the
  per-repo `actions-permissions` application if the decision is to change it.
- Fixes the FT-13 residuals the review surfaced (portability F3 / governance F5):
  iplanic's standards-drift caller pins an unresolvable annotated-tag-object SHA,
  and business/interlog have no standards-drift caller — consumer-side fixes, not
  canon code.

**The runbook artifact lives in this repo's `plans/`** (e.g.
`plans/ROLLOUT_plan015-arming.md`) — it *describes* the ops/inbox handoff but is
authored here; do not write into `operations/` in-session (writes-to-other-repos-
inbox-first). **Done when:** the runbook exists in `aidoc-flow-ci/plans/` with
exact `gh api` commands, verification, and rollback; nothing in it is executed
in-session.

## 4. Sequencing & release

1. Tasks 1, 4, 7 (docs/governance) and Tasks 5, 6 (code/templates) are
   independent — parallelizable.
2. Task 2 + Task 3 (B2 wiring) share `manifest.json` + `install.sh` — do them
   together to avoid a broken intermediate.
3. Bundle the template/script/code changes (Tasks 2, 3, 5, 6) into `ci/v2.8.0`
   (additive: new opt-in template + new opt-in `.yamllint.yaml` + a
   backward-compatible `pre_push` range fix + CodeQL-private variant). Docs
   (Tasks 1, 4, 7) ride the same tag.
4. Respect governance-PR-discipline: ≤3 doc surfaces per governance PR — Task 1
   (PLAN-009 + HANDOFF + ROADMAP = 3, at the cap), Task 4 (DECISIONS), Task 7a
   (README + install/README = 2), Task 7b (AI_CI_DEPLOYMENT + LABELS = 2) each
   ship separately; none exceeds 3 surfaces.
5. Cap review/fix loops at 3 cycles (OPS-0066).

## 5. Out of scope / explicit deferrals

- **No cross-repo writes** in-session — all per-repo arming and
  `actions-permissions` changes go through the Task 8 founder runbook.
- The `verified_allowed` **value change** (if the founder chooses drop) is a
  follow-up canon change, not bundled here.
- Turning the consumer `standards-drift.yml` into a **hard** gate — stays
  warning-only per IPLAN-0017 §3.1b unless separately decided.
- The B2-apply *mutation* inside `install.sh` (auto-applying branch protection)
  is deliberately not built — install verifies + reports; the founder applies.

**Explicitly deferred low findings (dispositioned, not dropped)** — each review
finding not turned into a task above, with why:

- **`can_approve_pull_request_reviews: true`** (security #4) — defanged (composition
  counts only the App's numeric bot-id, never `github-actions[bot]`). Folded as a
  "why it's safe" note into the CI-0011 stub (Task 4), not a code change.
- **Hardcoded reviewer-App bot-id `294948438` in the wizard** + **hardcoded
  `vladm3105/*` URLs in reusable failure output** (portability F5/F6) —
  external-adopter cosmetics only; the trust/asset/owner plumbing is already
  parameterized. Defer to a future external-adoption pass; not rollout-gating.
- **`docs/ai-review-assets.md` historical `@ci/v1.0.6` example pins** (docs F5) —
  intentional illustrations; low risk a skimmer copies one. Optional one-line
  "illustrative" prefix; defer.
- **CHANGELOG back-catalog gap v1.1–v1.6** (governance F4) — already tracked as
  `FRAMEWORK-TODO` FT-4; cross-reference, do not re-solve here.
- **FT-13 private-repo drift residuals** (portability F3 / governance F5) — the
  consumer-side pin fixes are in the Task 8 runbook (above); Task 2 ships the
  detector but does not itself fix existing consumer pins.

## Claim ledger

| #   | Claim                                                                                                   | Symbol                              | Citation                                             |
| --- | ------------------------------------------------------------------------------------------------------- | ----------------------------------- | ---------------------------------------------------- |
| 1   | Canon at `ci/v2.7.0`; VERSION = CI_TAG_FALLBACK = latest tag (backwards-repin class closed)             | `CI_TAG_FALLBACK`                   | install/install.sh:123                               |
| 3   | pre_push linted CHANGED list uses `merge-base` … `$BASE...HEAD` (not push range)                        | `BASE=`                             | scripts/pre_push_check.sh:55                         |
| 3b  | phrase-check already uses the correct `@{upstream}..HEAD` range to mirror                                | `upstream_ref=`                     | scripts/pre_push_check.sh:157                        |
| 5   | install.sh terminal step only PRINTS the bot-id + branch-protection reminders                           | `composition runs INERT`            | install/install.sh:610                               |
| 5b  | README claims "12 reusable workflows" (omits the 3 scanners)                                             | `12 reusable workflows`             | README.md:32                                         |
| 6   | "16 canonical labels" stated in install/README + AI_CI_DEPLOYMENT                                        | `16 canonical labels`               | install/README.md:124                                |
| 6b  | labels.json ships the two labels the "16" docs omit (proof it is 18, not 16)                             | `ai:review-infra-error`             | install/templates/labels.json:13                     |
| 7   | canon `standards-drift.yml` exists in `.github/workflows/` (not shipped as a consumer template)          | `standards-drift`                   | .github/workflows/standards-drift.yml:1              |
| 8   | check-standards-drift.sh checks branch protection (enforce_admins/contexts/signatures)                  | `enforce_admins`                    | sync/check-standards-drift.sh:140                    |
| 9   | apply-standards.sh has an `--apply --tier` mode that mutates server-side settings                       | `--apply`                           | install/apply-standards.sh:38                        |
| 10  | composition.yml self-exempts green when `vars.APP_REVIEWER_1_BOT_ID` is unset                            | `composition INERT`                 | .github/workflows/composition.yml:103                |
| 11  | DECISIONS.md latest entry is CI-0007 (nothing for v2.2–v2.7 policy shifts)                               | `## CI-0007`                        | DECISIONS.md:298                                     |
| 12  | PLAN-009 title/target still names `ci/v2.0.1` as the fleet target                                       | `ci/v2.0.1`                         | plans/PLAN-009_fleet-v2-cutover.md:1                 |
| 13  | HANDOFF "What remains" narrates a v2.1.2 world (7 consumers on `@ci/v1.9.5`)                             | `@ci/v1.9.5`                        | HANDOFF.md:178                                       |
| 14  | ROADMAP milestone rows name `ci/v2.1.2` while `:13` says latest is v2.7.0                                | `Fleet re-pin to`                   | ROADMAP.md:31                                        |
| 15  | pre_push runs bare `yamllint` when no `.yamllint.yaml` is present (and none ships as a template)          | `yamllint`                          | scripts/pre_push_check.sh:101                        |
| 16  | no `codeql-private.yml` variant (only `codeql.yml`) → private opt-in queues forever                     | `codeql.yml`                        | install/templates/workflows/codeql.yml:32            |
| 17  | auto-merge self-provisions `ai:enforcer-failed`, undocumented in LABELS.md                               | `ai:enforcer-failed`                | .github/workflows/auto-merge-ai-prs.yml:442          |
| 18  | server-side branch-protection read is ONLY in `--apply` (`--dry-run` checks content files only)          | `apply_branch_protection`           | install/apply-standards.sh:700                       |
| 19  | `check-standards-drift.sh --strict` exits 1 on drift or uncheckable — the correct server-side verifier   | `STRICT`                            | sync/check-standards-drift.sh:308                    |
| 20  | audit-trail gate `if:` is `pull_request`-only, contradicting its `pull_request_target` comment claim      | `github.event_name == 'pull_request'` | .github/workflows/audit-trail-check.yml:79         |
| 21  | manifest notes semgrep SAST "Complements native CodeQL (N/A on private)" — CodeQL unavailable on private | `N/A on private`                    | install/templates/manifest.json:102                  |

## Review log

> ≥2 passes before ready. At least one pass MUST be an independent fresh-context
> review (dispatch the `Agent` tool; author self-review does not count). The
> final pass must state zero findings.

### Pass 1 - 2026-07-18 - author self-check

- Split every finding into AI-doable vs 🔴 founder-gated so the plan cannot be
  read as authorizing cross-repo writes; B2-apply mutation and M1 value-change
  explicitly deferred to the Task 8 runbook.
- Kept governance edits within the ≤3-surface rule by splitting Task 1 / Task 4 /
  Task 7 into separate PRs.
- Sized to the 12 review findings (no speculative scope) per the minimal-plan
  convention.
- Pending: independent fresh-context review (Pass 2).

### Pass 2 - 2026-07-18 - independent (fresh-context Agent) + author completeness audit

Independent fresh-context reviewer (all 18 original ledger citations resolved to
real source; defects were in task *design*):

- **F1 (HIGH, folded):** Task 3 cited the wrong verifier — `apply-standards.sh
  --dry-run` checks only content files; server-side reads are `--apply`-only
  (`apply_branch_protection:700`), so it would exit green on an unarmed consumer.
  Rewired Task 3 to `check-standards-drift.sh --strict` (`:308`) + the
  `administration: read` token caveat. Added Claims 18, 19.
- **F2 (HIGH, folded):** plan cut `ci/v2.8.0` but Task 1 reconciled the fleet
  target to `ci/v2.7.0` — one release behind this plan's own fixes. Reconciled
  the fleet target to `ci/v2.8.0` in the header + Task 1 + HANDOFF/ROADMAP
  done-when. (Reviewer's parenthetical "no `v2.1.2` tag exists" is factually
  wrong — the tag exists — but does not affect the fix; discarded that detail.)
- **F3 (MEDIUM, folded):** Task 7 was 4 doc surfaces, over the ≤3 cap. Split into
  7a (README + install/README) and 7b (AI_CI_DEPLOYMENT + LABELS); updated
  Sequencing item 4. Reviewer independently confirmed the 12→15 count is correct.
- **F4 (advisory, folded):** L1 codeql-private may be moot (CodeQL N/A on private;
  SAST is the substitute). Made L1 confirm-first: verify a private consumer
  reaches the codeql reusable before shipping the variant; else drop L1. Added
  Claim 21.
- Reviewer notes folded: Task 8 artifact stays in `aidoc-flow-ci/plans/` (not an
  ops/inbox write); M3 must hoist the `@{upstream}` computation above the CHANGED
  calc; Task 2 emits `warn_uncheckable` under a default token (documented).

Author completeness audit (cross-checked all 5 lens reports for silently-dropped
findings — the independent reviewer lacked those reports):

- **Added L5** (Task 5): `audit-trail-check.yml:79` `if:` is `pull_request`-only
  while its comment claims `pull_request_target` support → silent skip. Claim 20.
- **Added L5b** (Task 6): `ai-review.yml` caller comment falsely says "never
  checks out PR head" (autofix does, safely) — one-line fix.
- **Added B2-detect adoption dependency** (Task 2): shipping the drift template
  ≠ consumers running it; Task 8 installs it. Prevents B2 being marked done on
  ship.
- **Expanded §5** with 5 explicitly-deferred low findings (security #4;
  portability F5/F6; docs F5; governance F4/FT-13) so no review finding vanishes
  silently.

### Pass 3 - 2026-07-18 - independent (fresh-context Agent), confirming

Fresh-context reviewer opened every cited source and confirmed the F1/F2/F3/F4
resolutions sound, the L5/L5b additions real, and Claims 18–21 exact. It found a
**single** load-bearing leak: the §2 scope-table B1 row (`:42`) still named
`ci/v2.7.0` as the reconcile target — a mechanical miss of the already-decided
F2 change (Task 1 and the header were correct). Fixed `:42` → `ci/v2.8.0`. Also
corrected the non-blocking 12→15 count justification (16 `workflow_call` files, 1
internal-only `self-secret-scan` excluded → 15; the other 4 named workflows carry
no `workflow_call` and were never reusables). No other `v2.7.0` occurrence is a
target-leak (all are "pre-merge latest" / "canon reviewed" usage). No new citation
drift; no design change — the sole finding was a copy-paste correction of a change
this pass had already verified as correct elsewhere.

**Result:** ready — no further load-bearing findings.
