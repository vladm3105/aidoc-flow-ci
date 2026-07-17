# PLAN-010 — Adoption model: make "installed" mean "compliant"

**Owner:** `aidoc-flow-ci` maintainer
**Origin:** the root finding of the `llm-router` flowci-feedback filing
(2026-07-14), triaged 2026-07-16. Its symptoms were fixed in PR #173
(`sync/check-drift.sh` coverage, `audit-trail` manifesting, §4.3); this plan is
the cause they share.
**Status:** DRAFT — **NOT READY, DO NOT EXECUTE** — 2026-07-17 EST.
Two independent reviews each invalidated the lead phase (the first would have
bricked canon; the second disproved its replacement's premise). The OPS-0066
3-cycle cap was reached without convergence — see the Review log's Pass 3 for
the disposition and the recommended split. The measured findings and the Claim
ledger are sound and reusable; the phase plan is not yet executable.
**Depends on:** PR #173 merged (`d442023`).
**Exit:** canon applies its own standard to itself; every non-paused consumer
receives a drift signal it did not hand-roll; `install.sh` no longer reports
success for an install that is not compliant.

## Summary

**Nothing verifies that what canon publishes is what a consumer deploys.** The
workflows themselves are careful — `ai-review` never checks out PR head under
`pull_request_target`, the auto-merge enforcer requires a tree-SHA-matched App
approval, the gitleaks binary is SHA-256 verified. The defect is one layer up,
in adoption.

Measured live 2026-07-17 against the tier templates. Canon ships **five**;
the four that govern real repos (governance/product/ops/bootstrap) all specify
`enforce_admins: true` (Claims 10, 12, 13, 31) — `umbrella` is the deliberate
`false` exception, because the umbrella merges via `--admin` (Claim 32):

| repo | tier | `enforce_admins` |
| --- | --- | --- |
| `aidoc-flow-operations` | ops-private | `true` |
| `iplan-runner` | product | `true` |
| `aidoc-flow-framework` | governance | `false` |
| `aidoc-flow-business` | ops-private | `false` |
| `aidoc-flow-iplanic` | ops-private | `false` |
| `aidoc-flow-interlog` | ops-private | `false` |
| `aidoc-flow-engramory` | product | **no protection at all** |
| `aidoc-flow-iplan-standard` | governance | **no protection at all** |
| **`aidoc-flow-ci` (canon itself)** | product | **no protection at all** |

**Seven of nine deviate; three have no protection whatsoever, including canon.**
When seven of nine drift the same way on the same field, the cause is the absent
feedback loop, not seven teams. This plan closes the loop; it does not blame the
consumers.

Three gaps, each with a citation:

- **G1 — `install.sh` reports success for an install it never completed.** It
  copies files, then *prints* `"4. After CI green, set … branch protection per
  IPLAN-0016 §2a-v3"` (Claim 1). It contains **zero** `gh api` protection calls
  (Claim 2) and never invokes `apply-standards.sh` — the only mentions are
  `echo` strings (Claim 3). So "installed" means "files copied", which is
  exactly why the fleet looks installed and is not.
- **G2 — no consumer receives drift detection.** Neither `sync/` script is in
  `manifest.json` (Claim 6), so every adopter hand-rolls a caller. The
  hand-rolls have rotted: `business` + `interlog` have none at all, and
  `iplanic`'s pins an unresolvable tag object (FT-13).
- **G3 — canon does not apply its own standard to itself.** `aidoc-flow-ci` has
  no branch protection (table above), violating the Wave-0 rule that the
  canon-source self-adopts before consumers pull (`CLAUDE.md`, "Rollout waves").
  Canon cannot currently detect that canon is unprotected.

**The machinery already exists.** `apply-standards.sh --apply` PUTs the tier's
branch-protection template (Claim 4); `--check` exits 1 on drift (Claim 5);
`check-standards-drift.sh --strict` exits non-zero on drift (Claim 7) and
chains `check-pin-currency.sh` itself (Claim 8). None of it is wired to
anything: **no workflow invokes `apply-standards.sh`** — the only mention under
`.github/workflows/` is that comment (Claims 9, 9a). This plan is
mostly wiring, not building.

---

## Measure before arming — the product template is deployed nowhere

The first draft of this plan proposed "Phase 1: arm canon's protection from
`branch-protection-product.json`; no decision needed; do first." **That would
have bricked canon**, and the independent review caught it. The measurement:

- `branch-protection-product.json` requires **five** contexts: `call / ai-review`,
  `call / composition`, `call / verify`, `call / Lint / format / security hooks`,
  `call / gitleaks` (Claim 18).
- Canon emits **two**: `call / verify` and `suite` (measured live on PR #173).
- Canon deploys exactly **one** caller — `audit-trail.yml` (Claim 19).
  `ai-review`, `composition`, `pre-commit` and `secret-scan` are
  `workflow_call`-only reusables with **no caller on canon**, so four of the five
  required contexts can never post. `suite` — canon's actual regression gate
  (Claim 20) — is not in the template at all.
- `enforce_admins: true` then removes the escape: `gh pr merge --admin` cannot
  bypass required checks when admins are included. Every canon PR would hang
  forever, recoverable only by an admin deleting the rule.

**The product template specifically is deployed nowhere.** `iplan-runner` is
the only protected product repo, and its eight required contexts match **none**
of the template's five (measured 2026-07-17: `Lint / format / security hooks`,
`Lint + types (ruff, mypy --strict)`, `Conformance (vectors + isolation + spec
parity)`, `Secret scan (gitleaks)`, four `Engine tests (…)`). Since
`apply-standards.sh` PUTs one atomic payload (Claim 21), `--apply --tier product`
would **replace** iplan-runner's real contexts with a set that does not post
there.

**But do not over-generalize that — an earlier draft of this section did.**
`aidoc-flow-operations` deploys `branch-protection-ops.json` **exactly**: all
five contexts and `enforce_admins: true` (measured 2026-07-17). The ops template
is not fiction; it is live and working on the one repo that adopted it fully. So
the accurate statement is narrow: **the PRODUCT template is deployed on no
product repo**, and no repo can be armed safely without first measuring
template-vs-emitted. That still inverts this plan's order — **build the detector
before touching enforcement** — but it is evidence *for* D3 Option A, not
against it, and D3 must weigh it.

This is also why the first draft's mitigation was inadequate. It cited
REPO_STANDARDS §2's verified-names table (Claim 22) and the FT-2 lesson — but
that table answers *"is the string spelled correctly?"*, not *"does this repo
emit it at all?"*. `tests/test_checknames.sh` has the same blind spot: it asserts
each `call / X` maps to a real reusable **job definition in canon** (Claim 23),
which passes today while four of five are undeployed. Name-accuracy and
deployment-coverage are different properties.

---

## Phase 0 — Decisions (founder)

Three forks this plan cannot resolve unilaterally.

### D3 — What should a tier's required contexts mean? (blocks Phases 2 + 5)

The product template is deployed on no product repo — but the ops template is
deployed exactly on `aidoc-flow-operations`. So the baseline is achievable, and
the question is whether it is the right target for every repo. Pick one:

- **Option A: the template is the target; repos adopt the callers to match it.**
  **`aidoc-flow-operations` already proves this works** — 5/5 contexts armed and
  green. Its cost is that it forces every repo in a tier onto an identical gate
  set, and `iplan-runner`'s eight repo-specific contexts show that is not how the
  fleet actually works today. For canon, A additionally requires a self-hosted
  runner pool it does not have (see Phase 2).
- **Option B (recommended): the template is a per-tier BASELINE, and each repo's
  armed set is `baseline ∩ emitted` ∪ repo-specific.** REPO_STANDARDS §2 already
  says "+ tier-specific" (Claim 22a), so this matches the documented intent.
  `apply-standards.sh` must then compute the armed set from what the repo
  actually emits rather than PUTting the template blind.

  **Option B needs a floor**, or it re-creates this plan's own defect class:
  GitHub accepts `required_status_checks.contexts: []` as valid, so a repo that
  emits no baseline context would arm protection requiring **zero checks** —
  silently. B MUST fail closed when `baseline ∩ emitted` is empty rather than
  arming an empty set. (Read the expression as `(baseline ∩ emitted) ∪
  repo-specific`.)

**Recommendation: B with the non-empty floor**, plus canon adopting the missing
callers on its own merits (Wave 0 — see G3). B is what makes `--apply` safe to
run anywhere; A alone does not, because it leaves `--apply` clobbering
`iplan-runner`. But **A is not fiction** — operations runs it — so if the fleet
is meant to converge on one gate set, A is viable and B is the interim.

### D1 — How does a consumer get drift detection?

The filing proposed adding `sync/*.sh` to `manifest.json` so every consumer
receives a **copy**.

- **Option A (as filed): copy the scripts.** Simple, and it matches how
  `pre_push_check.sh` already ships (Claim 15). But it manufactures another
  drifting surface — and we have the evidence: the hand-rolled callers are what
  a copied script becomes.
- **Option B (recommended): a canon reusable + a thin caller template.** A
  `standards-drift.yml` reusable in `.github/workflows/`, plus a caller template
  manifested like every other surface. The consumer pins `@ci/vX.Y.Z`; the
  script resolves from canon at that pin, never copied. This matches how every
  other canon surface is consumed, gets version-pinning free, becomes
  drift-checkable by the now-manifest-driven `check-drift.sh` (Claim 16), and
  structurally eliminates FT-13's bug class (a `uses:` pin cannot be an
  unresolvable tag object, and a `curl` in a `run:` step is invisible to the
  caller-scan).

**The objection to B, and its answer:** a consumer pinned at a stale tag runs
the *stale* drift check — the repos most needing drift detection get the weakest
one, which the copy option arguably avoids. B survives it because
`check-standards-drift.sh` chains `check-pin-currency.sh` (Claim 8), so a stale
pin is itself reported. Pinning is not pure upside; it is upside *given* the
pin-currency chain.

**Recommendation: B.** A is one PR cheaper and re-creates the problem.

### D2 — Should `install.sh` apply server-side settings?

🔴 — mutates consumer repos (branch protection, actions-permissions).

- **Option A: `install.sh --apply` invokes `apply-standards.sh --apply`.**
  Closes G1 completely. Highest blast radius; the F5 constraint recorded in
  `audit-trail.yml:12` says server-side application is founder-manual today
  (Claim 9).
- **Option B (recommended): `install.sh` refuses to report success until the
  server-side settings match** — it runs `apply-standards.sh --check`, reports
  `INCOMPLETE` with the exact remediation command, and mutates nothing. Keeps
  application founder-manual (respecting the existing F5 constraint) while
  making a non-compliant install impossible to mistake for a complete one.

**Recommendation: B.** It closes the honesty gap — which is the actual defect —
without taking the 🔴 action. A can follow later if B proves too passive.

---

## Phase 1 — Build the detector (no decision needed; do first; mutates nothing)

Nothing here arms anything. This is what the first draft should have led with.

1. **Grant the drift check the scope it needs (FT-5).** `standards-drift.yml`
   grants only `contents: read` (Claim 24), so `check-standards-drift.sh`'s
   branch-protection and actions-permissions reads 403 and `warn_uncheckable`-
   skip (Claim 25). FT-5 is marked RESOLVED, but it only made the 403 *legible*
   — it never granted the scope, and its own fix sketch is this step (Claim 26).
   Add `administration: read` + `actions: read`. **Without this, every
   server-side check in this plan silently warn-skips** — including Phase 3's
   self-check and Phase 4's exit criterion.
2. **Add a template-vs-emitted guard where it can see the target.**
   `tests/test_checknames.sh` is canon-local — it globs canon's own
   `.github/workflows/` (Claim 33) — so it cannot inspect the repo being armed
   (and for a private consumer, cannot read it at all). Extending it would cover
   canon only. The apply-time home is **`install/apply-standards.sh`**, which
   already runs with founder credentials against the target: before any
   protection PUT, assert every required context is emitted by a **deployed
   caller** there, and refuse otherwise. Keep a canon-local `test_checknames.sh`
   assertion too (it is cheap and guards canon's own arming), but the
   load-bearing guard is the apply-time one.
3. **Report template-vs-emitted.** Extend `check-standards-drift.sh` to say, per
   repo: which required contexts are armed, which are emitted, and the
   difference.

   **Scope limit — this cannot cover the fleet from canon.** Reading a repo's
   protection needs admin on that repo, and reading its emitted contexts needs
   its workflow files; canon's `GITHUB_TOKEN` is scoped to canon, and
   `standards-drift.yml:56-59` already records that the fleet step "covers the
   PUBLIC fleet only". So this step yields **canon + the public fleet**;
   private-repo data requires the per-repo self-run that Phase 3 ships.

   **That is a real ordering constraint, not a footnote.** D3 wants fleet
   template-vs-emitted data → complete data needs Phase 3's consumer callers →
   Phase 3 is gated on D1 (not D3), so the cycle breaks there: **decide D1 and
   ship Phase 3 first, then D3 on complete data.** Until then D3 must be decided
   on canon + public-fleet evidence, which is what the section above uses.

**Exit:** canon can answer "is what we publish what they deploy?" for **itself
and the public fleet**, without changing a single server-side setting.

---

## Phase 2 — Canon self-adopts (needs D3)

Wave 0 per the rollout rule (Claim 27): the canon-source dogfoods its own canon
before consumers pull. Closes **G3** — whose real content is not "canon lacks
protection" but **canon deploys 1 of 5 canon callers**. The missing protection is
a symptom.

1. Adopt the four missing canon callers (`ai-review`, `composition`,
   `pre-commit`, `secret-scan`). It is the Wave-0 rule canon already committed
   to, independent of D3.

   **🔴 This is founder-gated, not mechanical.** Canon has the secrets and vars
   (`APP_REVIEWER_1_BOT_ID`, App + LiteLLM, measured 2026-07-17) — but **zero
   self-hosted runners** (`actions/runners` → `total_count: 0`, measured
   2026-07-17). LiteLLM is private-bridge-only, so a PUBLIC repo's ai-review
   *review* job must run on `["self-hosted","ci-runner","single-use"]`
   (`docs/runners.md` §5a permits exactly this — the policy is not the obstacle;
   the absent pool is). **PLAN-009 already tracks "a shared pool for the public
   review jobs" as an open 🔴 founder Phase-0 item (Claim 34)** — this step
   inherits that gate and must not be scheduled ahead of it.
2. Confirm on a throwaway PR that all five contexts post, using Phase 1's guard.
3. Arm protection: the template's contexts (per D3) **plus `suite`**, canon's own
   regression gate (Claim 20), as the repo-specific addition §2 allows.
   `enforce_admins` last.

**Note:** `apply-standards.sh` PUTs contexts and `enforce_admins` in one atomic
payload (Claim 21) — there is `--skip-branch-protection` but no staged flag, so
"arm enforce_admins last" needs either a two-call sequence added to the script or
a manual `gh api` for the final step. The first draft assumed a staging ability
the tool does not have.

---

## Phase 3 — Ship drift detection to consumers (needs D1)

Under **D1=B**:

1. **`.github/workflows/standards-drift.yml` already exists** as canon's own
   scheduled run (Claim 28) — this step ADDs a `workflow_call` trigger + inputs
   (tier, `strict`) alongside the existing `schedule`/`workflow_dispatch`, so
   canon keeps its own run while consumers can call it. Note `CLAUDE.md` already
   claims canon "Ships reusable workflows (…, `standards-drift`, …)" (Claim 29)
   — that is **false today**; this step makes it true, and the claim should not
   be inherited as if already satisfied.
   Inputs are **(tier, strict, runner_labels)** — not just (tier, strict): the
   workflow currently hardcodes `runs-on: ubuntu-latest` (Claim 35), and without
   a `runner_labels` input every private consumer would land on GitHub-hosted,
   violating the runner policy (private repos are self-hosted ONLY). Step 2's
   private caller variant has nothing to carry otherwise.
2. Add `install/templates/workflows/standards-drift-{public,private}.yml`
   callers (the private variant carries `runner_labels` per the runner policy).
3. **The caller templates MUST grant `administration: read` + `actions: read`.**
   For a reusable, the CALLER's `permissions:` bound the called workflow, so
   Phase 1 step 1 (which fixes canon's own standalone workflow) does **not**
   reach consumers. Without this the shipped consumer signal is file-surface +
   pin-currency forever — i.e. the FT-5 gap re-shipped fleet-wide, and Phase 5's
   exit criterion unverifiable on every repo.
4. Manifest both — `auto_install: false`, `safe_to_replace: true` — mirroring
   `audit-trail`, which PR #173 manifested for exactly this reason (Claim 17).
5. Add the caller to `deploy-ci-wizard.sh`'s tier list.

**Exit:** a fresh consumer gets a drift signal by adopting a pinned caller, with
no bespoke YAML; `check-drift.sh` then drift-checks that caller too. **This exit
holds for file-surface + pin-currency only unless Phase 1 step 1 landed** — a
consumer without `administration: read` gets `uncheckable` warnings for exactly
the server-side settings G1/G3/Phase 5 exist to fix.

---

## Phase 4 — `install.sh` honesty (needs D2)

Under **D2=B**: after the file copies, run `apply-standards.sh --check` and
print a compliance verdict. On drift, exit non-zero naming the exact
`apply-standards.sh --apply --tier <t>` command. The current free-text reminder
(Claim 1) must not be the only signal.

**Exit:** `install.sh` cannot report success for a repo whose server-side
settings do not match its tier.

---

## Phase 5 — Fleet reconciliation (🔴, via ops/inbox)

Six repos need `enforce_admins`; three need protection at all. This is
cross-repo work: prepare an ops/inbox runbook and hand off. **Do not execute
from a canon session**, per the writes-to-other-repos rule. The runbook must pass
`--yes`: `apply-standards.sh` hard-errors on a non-TTY without it (Claim 36). FT-13's consumer
callers (business/interlog absent, iplanic's dead pin) fold into the same
runbook.

Sequenced deliberately **after** Phase 3: arming protection on repos that still
cannot see their own drift re-creates the same open loop at a higher enforcement
level.

---

## Phase 6 — Rulebook + release (required by canon's own rules; not optional)

The canon-source discipline says **every canon-body change ships with a
`docs/REPO_STANDARDS.md` update**, and that releases are `git tag ci/vX.Y.Z`
(`CLAUDE.md`, "Repo-specific rules"). The first draft had neither, which made
Phase 3's exit unreachable: "a consumer gets a signal by adopting a **pinned**
caller" needs a tag to pin.

1. **§2 baseline** changes under D3=B (the armed set becomes
   `(baseline ∩ emitted) ∪ repo-specific`, with the non-empty floor). §2's
   required-checks row (Claim 22a) states the baseline as-is today.
2. **§2's check-name note** states test_checknames' current semantics — that a
   context "maps to a real reusable job, so this can't drift again" — which Phase
   1 step 2 changes. Stale on merge otherwise.
3. **New §** for the adoption contract: what `install.sh` guarantees (D2), and
   that a required context MUST be emitted by a deployed caller before it is
   armed (the brick lesson).
4. **Cut the tag.** Phase 3 is a new reusable + caller templates + manifest
   entries = **MINOR**. Note canon's own `audit-trail.yml:22` still pins
   `@ci/v2.0.0` while `ci/v2.0.1` exists, and `VERSION` says `ci/v2.0.0` — so
   `install.sh --repin`'s `VERSION` fallback would pin consumers *backwards*.
   Reconcile both in the same cut.

---

## Also measured, not yet addressed (name them rather than let them rot)

- **Canon miscites §3.1b in two places.** `.github/workflows/standards-drift.yml`
  ("WARNING-ONLY per canon §3.1b" — a dead ref within this repo) and
  `sync/check-standards-drift.sh` ("per IPLAN-0017 §3.1b"). Per Claim 30, §3.1b
  scopes warning-only to `check-drift.sh` file-surface diffing only, so both
  overstate it. Small; fold into Phase 6's rulebook pass.
- **`install.sh` advertises a check it never runs.** `:393`/`:445` tell operators
  to "inspect for canon parity via `apply-standards.sh --check`" (Claim 3) for
  CODEOWNERS and `pre_push_check.sh`. Phase 4 makes `install.sh` run `--check`
  for protection; the same call covers these surfaces, so Phase 4 should close
  them too rather than leave the advice unexecuted.

## Non-goals

- **Making drift block.** The warning-only contract is defensible and stays;
  `--strict` already exists (Claim 7) for release gates. The filing's complaint
  was that the warnings reach nobody — that is G2, not the contract.
  *Scope note:* IPLAN-0017 §3.1b scopes warning-only to `sync/check-drift.sh`
  (file-surface template diffing), not to `apply-standards.sh --check` or
  `check-standards-drift.sh` (Claim 30). Treating it as governing all three is a
  defensible **extension**, not compliance — say so rather than citing §3.1b as
  if it already covered them.
- **Re-litigating FT-9 / `--update` semantics.** `--repin` is the sanctioned
  path and FT-9 is RESOLVED.
- **Shipping a `.yamllint.yaml`** (FT-14). Separable and smaller; do it
  standalone.

## Claim ledger

| #   | Claim                                                                       | Symbol                              | Citation                                               |
| --- | --------------------------------------------------------------------------- | ----------------------------------- | ------------------------------------------------------ |
| 1   | install.sh only PRINTS a branch-protection reminder                         | `branch protection per IPLAN-0016`  | install/install.sh:602                                 |
| 2   | install.sh's bootstrap copies workflows and makes no protection API call    | `for wf in ai-review composition`   | install/install.sh:369                                 |
| 3   | install.sh never invokes apply-standards.sh (echo mentions only)            | `apply-standards.sh --check`        | install/install.sh:393                                 |
| 4   | apply-standards.sh --apply PUTs the tier branch-protection template          | `branch-protection-${TIER}.json`    | install/apply-standards.sh:706                         |
| 5   | apply-standards.sh --check exits 1 on drift/missing                          | `DRIFT_COUNT + MISSING_COUNT`       | install/apply-standards.sh:816                         |
| 6   | manifest.json contains no `sync/` entry                                      | `"files"`                           | install/templates/manifest.json:19                     |
| 7   | check-standards-drift.sh --strict exits non-zero on drift                    | `STRICT`                            | sync/check-standards-drift.sh:308                      |
| 8   | check-standards-drift.sh chains check-pin-currency.sh itself                 | `check-pin-currency.sh`             | sync/check-standards-drift.sh:295                      |
| 9   | server-side application is recorded as founder-manual (F5 blast-radius)      | `apply-standards.sh --apply`        | .github/workflows/audit-trail.yml:12                   |
| 9a  | that comment is the ONLY apply-standards mention under .github/workflows/   | `apply-standards`                   | .github/workflows/audit-trail.yml:12                   |
| 10  | product tier template specifies enforce_admins: true                         | `enforce_admins`                    | install/templates/branch-protection-product.json:14    |
| 11  | aidoc-flow-ci's own tier is product                                          | `Product code`                      | docs/REPO_STANDARDS.md:64                              |
| 12  | governance tier template specifies enforce_admins: true                      | `enforce_admins`                    | install/templates/branch-protection-governance.json:13 |
| 13  | ops tier template specifies enforce_admins: true                             | `enforce_admins`                    | install/templates/branch-protection-ops.json:14        |
| 14  | check-standards-drift.sh auto-detects its target repo via `gh repo view`     | `nameWithOwner`                     | sync/check-standards-drift.sh:78                       |
| 15  | pre_push_check.sh ships to consumers by copy (the D1-A precedent)            | `scripts/pre_push_check.sh`         | install/templates/manifest.json:175                    |
| 16  | check-drift.sh resolves callers via manifest at each caller's own pin        | `fetch_manifest`                    | sync/check-drift.sh:100                                |
| 17  | audit-trail was manifested in PR #173 (the precedent Phase 3 step 3 mirrors) | `.github/workflows/audit-trail.yml` | install/templates/manifest.json:37                     |
| 18  | product template requires 5 contexts incl. `call / ai-review`                | `call / ai-review`                  | install/templates/branch-protection-product.json:7     |
| 19  | audit-trail is a deployed caller (`uses:` a canon reusable)                  | `audit-trail-check.yml@`            | .github/workflows/audit-trail.yml:22                   |
| 19a | it is canon's ONLY one — verified by enumerating all 16 workflows; every other `uses:` of a canon reusable is commented out or absent | `uses:`                             | .github/workflows/audit-trail.yml:22                   |
| 20  | `suite` is canon's own regression gate, absent from the template             | `suite`                             | .github/workflows/tests.yml:21                         |
| 21  | branch-protection PUT is ONE atomic payload (contexts+enforce_admins; no staged flag) | `branches/${default_branch}/protection` | install/apply-standards.sh:706         |
| 22  | REPO_STANDARDS §2 has a verified-emitted-names table (name accuracy only)    | `Verified emitted check-names`      | docs/REPO_STANDARDS.md:110                             |
| 22a | §2's required-checks baseline is explicitly "+ tier-specific" (D3-B's basis) | `+ tier-specific`                   | docs/REPO_STANDARDS.md:84                              |
| 23  | test_checknames asserts a context maps to a reusable JOB, not a deployed caller | `a real reusable job`            | tests/test_checknames.sh:4                             |
| 24  | standards-drift.yml grants only `contents: read`                             | `contents: read`                    | .github/workflows/standards-drift.yml:43               |
| 25  | a scoped token 403s -> warn_uncheckable (cannot verify protection)           | `warn_uncheckable`                  | sync/check-standards-drift.sh:115                      |
| 26  | FT-5's own fix sketch is granting administration/actions: read               | `administration: read`              | plans/FRAMEWORK-TODO.md:78                             |
| 27  | Wave-0 rule: the canon-source dogfoods its own canon before consumers pull   | `dogfoods its own canon`            | CLAUDE.md:204                                          |
| 28  | standards-drift.yml already exists as canon's scheduled run                  | `schedule:`                         | .github/workflows/standards-drift.yml:23               |
| 29  | CLAUDE.md already claims canon ships a standards-drift reusable (false today)| `Ships reusable workflows`          | CLAUDE.md:9                                            |
| 30  | IPLAN-0017 §3.1b scopes warning-only to check-drift.sh (file-surface) only   | `Drift detection — warning-only`    | ops/iplans/IPLAN-0017_unified-ci-flows.md:169          |
| 31  | bootstrap tier template also specifies enforce_admins: true                  | `enforce_admins`                    | install/templates/branch-protection-bootstrap.json:10  |
| 32  | umbrella is the deliberate enforce_admins:false exception (--admin is the bypass) | `enforce_admins`               | install/templates/branch-protection-umbrella.json:5    |
| 33  | test_checknames is canon-local (globs canon's own workflows)                 | `.github/workflows/*.yml`           | tests/test_checknames.sh:18                            |
| 34  | PLAN-009 gates the public review job on a self-hosted pool (🔴 Phase 0)       | `ai-review REVIEW job on the ephemeral self-hosted pool` | plans/PLAN-009_fleet-v2-cutover.md:133 |
| 35  | standards-drift.yml hardcodes runs-on: ubuntu-latest (no runner_labels input) | `runs-on: ubuntu-latest`            | .github/workflows/standards-drift.yml:40               |
| 36  | apply-standards --apply hard-errors on a non-TTY without --yes               | `--apply requires --yes`            | install/apply-standards.sh:169                         |

> **Claim 30 is cross-repo** (`aidoc-flow-operations`); the gate resolves it with
> `--root /opt/data/aidoc-flow/operations`.
>
> **Live-state claims carry no `file:line`.** The fleet `enforce_admins` table
> and consumer `standards-drift.yml` presence are GitHub state, not repo source.
> Measured 2026-07-17 via
> `gh api repos/vladm3105/<r>/branches/main/protection --jq '.enforce_admins.enabled'`
> and `gh api repos/vladm3105/<r>/contents/.github/workflows/standards-drift.yml`.
> **Re-measure before executing Phase 4.** The FT-13 lesson is that this table
> decays and that citing a stale measurement is how that entry went wrong three
> times — including once by attributing a run to a caller authored after it.

## Review log

### Pass 1 - 2026-07-17

- Draft. Every source claim opened and read before citing; the fleet table was
  re-measured live rather than carried over from the filing. The filing reported
  6 repos with one unprotected; the live sweep found 9, with **three**
  unprotected — so the evidence is stronger than filed, and the filing's own
  table was already stale.
- Dropped a speculative "compliance badge" phase (the filing's fix-shape 2): no
  consumer surface consumes it and it restates `--check`'s output. Sized to the
  3 measured gaps rather than to N speculative features.
- Sequenced Phase 4 after Phase 2 on reflection: arming enforcement on repos
  that still cannot see their own drift would re-create the open loop one level
  up.

### Pass 2 - 2026-07-17 - independent

Fresh-context reviewer, dispatched against the plan + real source. **Five
load-bearing findings; the first invalidated the plan's lead phase.**

- **F1 (decisive) — "Phase 1: arm canon's protection; no decision needed; do
  first" would have BRICKED canon.** The product template requires 5 contexts;
  canon emits 2, because it deploys 1 of 5 canon callers. `enforce_admins: true`
  then removes `--admin`, so every canon PR would hang forever. Verified
  independently (`gh pr checks 173` → `call / verify`, `suite`). **Restructured:
  Phase 1 is now "build the detector, mutate nothing"; self-adoption moved to
  Phase 2 behind D3.** Widened while confirming it: `iplan-runner` (product,
  `enforce_admins: true`) requires 8 contexts matching **none** of the
  template's 5 — so the baseline is deployed on zero product repos and `--apply`
  would clobber a working repo. Added as a new section + D3.
- **F2 — the mitigation could not catch F1's class, and its second half was not
  implementable.** REPO_STANDARDS §2's table answers "is the name spelled
  right?", not "does this repo emit it?"; `test_checknames.sh` has the same blind
  spot (Claim 23). And `apply-standards.sh` PUTs one atomic payload (Claim 21) —
  "arm enforce_admins last" assumed a staging ability the tool lacks. Both now
  stated; the durable fix (extend `test_checknames.sh` to assert
  required-context ⊆ emitted-by-deployed-caller) is Phase 1 step 2.
- **F3 — G3 misdiagnosed.** The Wave-0 violation is not "canon lacks
  protection"; it is that **canon deploys 1 of 5 canon callers** — the missing
  protection is a symptom. Phase 1 was *under*-scoped, not over-scoped. Folded
  into Phase 2.
- **F4 — FT-5 is marked RESOLVED but its gap is live and defeats two phases.**
  It only made the 403 legible; `standards-drift.yml` still grants only
  `contents: read` (Claim 24), so every server-side check warn-skips (Claim 25).
  Added as Phase 1 step 1 and as an explicit caveat on Phase 3's exit.
- **F5 — Phase 3 contradicted itself.** `standards-drift.yml` already exists
  (Claim 28); "promote into" read as creating it. Rewritten as "add a
  `workflow_call` trigger alongside the existing schedule". Also noted CLAUDE.md
  already claims canon ships that reusable (Claim 29) — false today.
- Minor, all folded: Claim 9 split (a comment cannot prove absence → 9a); D1=B's
  stale-pin objection stated with its pin-currency answer (Claim 8); Phase 2
  step 2's rationale was inverted (`--check` is server-side; file-surface is
  `check-drift.sh`); §3.1b's scope is narrower than the plan used it (Claim 30 —
  an extension, not compliance); `--apply` is interactive without `--yes` (noted
  for the Phase 5 runbook); Claim 12 line drift corrected 14 → 13.

### Pass 3 - 2026-07-17 - independent

Fresh-context re-review of the restructured plan. It confirmed the F1-F5 folds
were real (not cosmetic) and then found **eight more load-bearing findings**. All
independently re-verified before folding:

- **L1 (decisive) — the restructure's own central premise was false.** Pass 2's
  fold asserted "the template's required-contexts baseline was never true of any
  repo". **`aidoc-flow-operations` deploys `branch-protection-ops.json` exactly**
  — 5/5 contexts + `enforce_admins: true` (re-measured). Only the narrow claim
  ("zero *product* repos") holds. Worse, operations is a live existence proof for
  **D3 Option A**, which D3 dismissed as fiction without mentioning it. Section
  and D3 rewritten; A is now presented with its proof.
- **L2 — Phase 1's exit was unachievable and the phase graph had a cycle.** Canon
  cannot read private repos' protection or workflows, so "for every repo" is
  false (canon's own `standards-drift.yml` already says the fleet step is
  public-only). Cycle: Phase 1 step 3 → D3 → Phase 3 → Phase 1 step 3. Exit
  narrowed to canon + public fleet; the cycle is named and broken at D1/Phase 3.
- **L3 — Phase 2 step 1's "mechanical" was false.** Canon has the secrets but
  **zero self-hosted runners** (`total_count: 0`); a public repo's ai-review
  review job needs the pool, which PLAN-009 tracks as an open 🔴 founder Phase-0
  item (Claim 34). Marked 🔴 and coupled to PLAN-009.
- **L4 — D3 Option B could arm a gate that gates nothing.** `baseline ∩ emitted`
  with no floor + GitHub accepting `contexts: []` = protection requiring zero
  checks, silently — this plan's own defect class. Non-empty floor added.
- **L5 — the guard was sited where it cannot see its target.** `test_checknames`
  is canon-local (Claim 33); the apply-time home is `apply-standards.sh`.
- **L6 — Phase 3's inputs contradicted its own step 2.** `standards-drift.yml`
  hardcodes `ubuntu-latest` (Claim 35); without a `runner_labels` input the
  private caller variant has nothing to carry and private consumers land on
  GitHub-hosted, violating the runner policy. Input added.
- **L7 — Phase 3 never delivered `administration: read` to consumers.** A
  reusable is bounded by the CALLER's permissions, so Phase 1 step 1 doesn't
  reach them; the exit named the caveat but nothing closed it. Now step 3.
- **L8 — no rulebook update and no tag.** Canon's own rule requires a
  REPO_STANDARDS update per canon-body change, and Phase 3's exit ("adopting a
  **pinned** caller") is unreachable without a tag. Phase 6 added; it also
  reconciles canon's `audit-trail.yml` pin and the stale `VERSION`.
- Minors folded: Claim 21 mis-cited the actions-permissions loop rather than the
  protection PUT (→ `:706`); Claim 22 didn't support D3-B (→ new 22a at `:84`);
  Claim 19 repeated the absence-cited-with-presence defect Pass 2 fixed on Claim
  9 (→ 19a); "six of eight" over a nine-row table (→ seven of nine); "all four
  tier templates" (→ five, umbrella deliberately `false`, Claims 31-32);
  `--apply` needs `--yes` non-interactively (→ Phase 5, Claim 36). Two measured
  gaps Pass 3 flagged as unaddressed now have their own section.

**Result: NOT READY — OPS-0066 3-cycle cap reached without convergence.**

Pass 1 (self) → Pass 2 (independent, 5 load-bearing) → Pass 3 (independent, 8
load-bearing). Findings are still being surfaced at a rate that does not suggest
convergence, and the circuit-breaker explicitly names verified-planning
Pass N+1 as subject to the cap. Continuing to Pass 4 would violate it.

**This is a signal about the plan, not just the process.** Two independent
reviewers each invalidated the *lead phase* — first by proving it would brick
canon, then by proving its replacement's premise false. The common cause is that
this plan reasons about **live fleet state that canon cannot see** (private
repos' protection and emitted contexts). Every wrong claim so far has been an
over-generalization from partial measurement, and the plan's own L2 finding is
that the data needed to decide D3 does not exist until Phase 3 ships.

**Recommended disposition — founder call:**

1. **Split.** Phase 1 (build the detector; mutates nothing) and Phase 3 (ship
   the consumer caller) are self-contained, decision-free once D1 is answered,
   and are what *produce* the evidence. Land them as their own small plan.
2. **Defer** D3 / Phase 2 / Phase 5 until that evidence exists. They are the
   phases both reviewers broke, and they are unanswerable from canon today.
3. Do not treat this document as executable in its current form.
