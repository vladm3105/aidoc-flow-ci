# PLAN-017 — FT-15 fix: make the adopted pin actually control the fetched assets

> Status: PLANNING — awaiting review passes. Owning repo: `aidoc-flow-ci`.
> Closes **FT-15** (CONFIRMED LIVE 2026-07-21, `plans/FRAMEWORK-TODO.md`).
> Scope: 3 reusables, 5 `workflow_ref` sites, **one reviewed PR per reusable**
> (per FT-15's own instruction — these are in-production, security-reviewed
> workflows every consumer's AI gate depends on).

## 1. Problem

Three reusables build cross-repo asset-fetch URLs from `github.workflow_ref`.
Inside a `workflow_call` reusable that value is the **CALLER's** entry workflow
ref, not the reusable's pinned tag — confirmed live, not reasoned from docs: a
consumer pinned `@ci/v2.0.1` logged `fetching assets from
vladm3105/aidoc-flow-ci@refs/heads/main`.

Two independent defects flow from the one expression:

- **D1 — ref is wrong → determinism broken.** The adopted `@ci/vX.Y.Z` pin does
  not control which rubric / verdict schema / LiteLLM client / reconcile script
  runs. Any merge to canon `main` changes every consumer's live gate with no
  tag, no re-pin, no adoption step; rollback by re-pinning does not roll back
  the assets.
- **D2 — owner is wrong → external adoption is broken.** `CI_OWNER` is field 1
  of the same string, i.e. the **caller's** owner. It works today only because
  every consumer shares the `vladm3105` owner. An external adopter fetches
  `<their-org>/aidoc-flow-ci/...` → 404, or silently their own fork.

D2 also makes a dormant-looking failure reachable today: any trigger yielding a
ref absent from `aidoc-flow-ci` (`pull_request` → `refs/pull/N/merge`, or a
`workflow_dispatch` from a feature branch → `refs/heads/<branch>`) 404s and
bricks the gate, surfacing as an INFRA-looking flake.

## 2. The fix contract (what must be true when this is done)

1. Every cross-repo asset fetch resolves the canon tag from **the consumer's own
   adopted pin**, never from `github.workflow_ref`'s ref component.
2. The canon **owner/repo is hardcoded** (`vladm3105/aidoc-flow-ci`), never
   derived from caller-controlled input.
3. A resolution failure is **loud and named as INFRASTRUCTURE**, never a silent
   fallback to `main` (a fallback would preserve exactly the bug being fixed).
4. Comments/docs asserting pin-determinism are corrected in the same PR.
5. No behavioural change to review verdicts, merge gating, or runner routing.

**Explicit non-goal:** changing which assets are fetched, or moving per-consumer
config off `operations@main`. Ref + owner correctness only.

## 3. Reference implementation (already in-repo)

`standards-drift.yml` hit this exact problem and was fixed before merge. It
resolves the tag by grepping the **consumer's own checked-out caller file**
(claim 14) and **hardcodes the owner** in the URL (claim 15), with a loud
INFRA-classed error when the pin can't be found. Its header (claim 1) documents
the `workflow_ref` semantics and why `github.job_workflow_sha` is not an option
(not `${{ }}`-accessible). That is the pattern to port — where it ports.

## 4. Per-reusable design

### PR-A — `docs-sync.yml` (simplest; land first)

Its `sync` job checks out the **caller** repo with no `repository:` override
(claim 18), so the caller's `.github/workflows/` is on disk. Port the
`standards-drift` grep (claim 14) **and extend it** — "port directly" is not
sufficient, because that pattern rejects the commented-SHA pin form §5 requires.
Extend on the same line, **keyed to the workflow filename**, e.g.

```
docs-sync\.yml@(?:[0-9a-f]{40} +# +)?ci/v[0-9]+\.[0-9]+\.[0-9]+
```

⚠️ Do **not** copy `check-pin-currency.sh`'s alternation branch
(`@[0-9a-f]{40} # ci/v[0-9.]+`, claim 31) — it is **not keyed to a workflow
path**, and the ported grep runs recursively over `.github/workflows/`, so it
would match the trailing comment on a line pinning a *different* reusable and
resolve the wrong tag. (Note also that only `check-pin-currency.sh`'s fleet
branch recognises the commented-SHA form; its local mode does not — so "canon
already recognises it" is half-true, which matters if a pin-shape check is
added.) Hardcode the owner. Also fix the wrong-mental-model comment at
`docs-sync.yml:112` (claim 13).

### PR-B — `doc-maintainer.yml` (same shape, two sites)

Both jobs check out the caller with no override (claim 17), so the same grep
applies at both sites (claims 10, 11). Keyed to the `doc-maintainer.yml` pin.

### PR-C — `ai-review.yml` (the genuine exception — two sites, different answers)

**Site 1, the `ai-review` review job, has no `actions/checkout` — deliberately.**
`ai-review.yml:351-362` (claim 16) records that a 5-cycle sparse-checkout saga
(`v1.1.0`→`v1.1.3`, plus the `v1.1.4` reorder attempt) proved `actions/checkout`
interaction with workspace state and runner class *was* the failure mode, and
that `curl` was adopted precisely because it has none of those. **Re-introducing
checkout here to read a pin would reopen a closed, expensively-learned failure
class — do not do it.** The `trust` job's checkout targets the trust-config repo,
not the consumer (claim 22), so it cannot supply the caller's file either.

Note the constraint precisely: it is **"no second checkout in the review job"**,
not "checkout is impossible in this workflow" — the `autofix` job runs
`actions/checkout` successfully under `pull_request_target` (claim 19).

Options considered:

| # | Approach | Verdict |
|---|---|---|
| A | Re-add `actions/checkout` to the review job | **Rejected** — reopens the IPLAN-0024 failure class (claim 16) |
| B | New `canon_tag` **input** on the reusable | **Rejected as primary** — duplicates the `uses:` pin in every caller; the two can silently disagree, and the input is caller-controlled (weakens D2's fix) |
| C | Use `workflow_ref` as the caller-file **locator**, fetch that file over HTTP, grep its `@ci/vX.Y.Z` pin | **Chosen — with C's ref component explicitly discarded (see below)** |

Option C keeps the curl-only property the job was deliberately built on, needs no
new input, and reads the *authoritative* pin (the `uses:` line actually running)
rather than a hand-maintained copy.

**C must NOT reuse `workflow_ref`'s `@<ref>` component — that would make a
caller-controlled ref security-load-bearing and reintroduce the bug in a new
place.** Use `workflow_ref` for `<owner>/<repo>/<path>` **only**, and fetch the
caller file at a **trusted ref chosen per event** — matching which copy of the
caller workflow GitHub actually executed:

| Event | Executing caller copy | Ref to read |
|---|---|---|
| `pull_request_target` | the PR's **base** branch | `github.event.pull_request.base.ref` |
| `pull_request_review` | the repo's **default** branch | `github.event.repository.default_branch` |
| *any other event* | — | `github.event.repository.default_branch` (**required default arm**) |

The default arm is not optional: without it, a consumer adding any third trigger
yields an empty ref and — under contract 3's no-fallback rule — a hard fail. No
consumer is affected today.

Order matters: on a review event, a PR targeting a **non-default** base would
resolve the wrong file if `base.ref` were preferred — and the review-event path
is exactly the exposure below. Both are event-supplied and trusted (neither is
PR-content-controlled).

Why this is load-bearing rather than theoretical: the caller template ships
**`pull_request_review`** alongside `pull_request_target` (claim 23), and the
review job is **not** always skipped on review events — the unarmed guard at
`ai-review.yml:301-304` `exit 0`s into a *full review* **before** the
`pull_request_review` skip at `:314` (claim 24). So on an **unarmed** consumer a
review event reaches the fetch step. All 8 consumers are armed today (verified
2026-07-21), so this is **latent, not live** — but a consumer installed from the
template **starts unarmed** (arming is a separate 🔴 step), so the exposure is
real precisely during onboarding, which is exactly when the rollout adds repos.
(`operations` is doubly unaffected — it deliberately removed the
`pull_request_review` trigger from its own caller, claim 32 — but the shipped
template retains it, so every newly-installed consumer has it.)
**State the benefit precisely** (a PR-C reviewer will otherwise ask why the extra
code exists): for the two triggers consumers actually ship, `workflow_ref`'s ref
component *already equals* the table's values — base branch and default branch
respectively. So discarding it is not a fix for today's consumers; it removes the
**class** — the `pull_request` (`refs/pull/N/merge`, PR-authored) and
branch-`workflow_dispatch` cases — and stops a caller-controlled value being
security-load-bearing, so a consumer adding a trigger can never silently
reintroduce the defect. That, plus uniformity across both sites, is the
justification.

**Fetch mechanism:** use the **API contents endpoint**
(`https://api.github.com/repos/<caller>/contents/<path>?ref=<base>` with
`Accept: application/vnd.github.raw`), not `raw.githubusercontent.com` — this
same file already documents that private-repo raw auth is "historically finicky"
and falls back to exactly that endpoint (claim 25). Site 1 has a token in its
step env (claim 5a) and the job holds `contents: write` (claim 26); **site 2's
fetch step has no token in its step env** and inherits only the job-level
`GH_TOKEN` (claim 27) — the implementation must pass one explicitly there.

**Site 2, the `autofix` job, is the *safer* of the two — correcting an earlier
framing.** It checks out the PR head, but at `path: prhead` (claim 19), so a
naive root-level grep of `.github/workflows/` finds nothing and fails loudly
rather than reading tampered content. It is additionally fork-proof
(`auto_fix_ok` is false for forks, claim 28), `pull_request_target`-only
(claim 29) so its own `workflow_ref` ref *is* the base branch, and default-off.
The residual actor is a write-access author who could edit the base pin anyway.
Site 2 adopts the same base-ref resolution purely for uniformity, not because it
is the riskier site. Also fix the misleading step name "…from the pinned ref"
(`ai-review.yml:1137`) — it is currently false.

## 5. Sequencing + risk

Land **PR-A → PR-B → PR-C** (lowest blast radius first: `docs-sync` is
post-merge, `doc-maintainer` is post-merge/scheduled, `ai-review` is the merge
gate).

**Verification requires a tag — canon cannot test these reusables on its own PRs.**
`aidoc-flow-ci` ships all three as `workflow_call`-only and has **no self-caller**
for any of them (claim 30: the only real `uses:` self-calls are
`audit-trail-check` and `secret-scan`; every other occurrence is a commented
example). So a PR's own CI never executes the changed code, and "verify each PR's
own run" is impossible. Therefore:

1. After **PR-A**, cut a normal **`ci/v2.10.0`** and re-pin **one** low-risk
   consumer's `docs-sync` caller to it. Read the `::notice::` line and confirm it
   names the adopted tag, not `refs/heads/main`. **This is the gate for
   PR-B/PR-C** — without it, "proven on docs-sync first" would be an empty claim.
   Two practical constraints: the pilot re-pin is a **write to a consumer repo →
   🔴, so it goes through an `ops/inbox` runbook**, not an in-session push; and
   `docs-sync` is **post-merge**, so the `::notice::` only appears after that
   re-pin PR merges. Budget for both, or PR-B will look unexpectedly blocked.
2. After **PR-B + PR-C**, cut **`ci/v2.11.0`** as the complete fix and pilot one
   consumer's `ai-review` before any fleet re-pin.

> **Do NOT use a pre-release tag (`-rc.N`) for step 1.** The ported resolver
> regex is unanchored (claim 14), so `@ci/v2.10.0-rc.1` silently prefix-matches
> to **`ci/v2.10.0`** — verified by direct test — a tag that would not exist,
> producing an INFRA failure that looks like a bug in the fix rather than a bad
> pin. It would also violate this plan's own contract 3. Two normal semver tags
> avoid the problem entirely and need no regex or contract change. If pre-release
> pins are ever wanted, that is a separate change: extend the regex to
> `ci/v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?` **and** amend contract 3 **and**
> the `sync/` consumers of the same pattern — out of scope here.

**Semver — MINOR, deliberately.** The reusables' inputs and outputs are
unchanged, so this is additive/corrective rather than a breaking interface
change. But it does introduce a **new hard requirement on the caller surface**:
contract 3 (no silent fallback) means a caller whose `uses:` pin the resolver
cannot read will hard-fail instead of silently fetching `main`. The resolver
must therefore accept **both** pin forms canon already recognises — the plain
`@ci/vX.Y.Z` tag **and** the `@<40-hex-sha> # ci/vX.Y.Z` commented-SHA form that
`sync/check-pin-currency.sh` accepts (claim 31) — or that form must be removed
from canon in the same change. All 8 consumers use plain semver pins (verified
2026-07-21), so live impact is nil; per this repo's own semver rule ("breaking
changes to expected consumer surfaces = MAJOR") this is called out explicitly
rather than left implicit, and MINOR is justified on the basis that no shipped
consumer is affected. Document the requirement in `docs/REPO_STANDARDS.md` +
CHANGELOG, and consider adding a pin-shape check to
`sync/check-pin-currency.sh` so a bad pin surfaces as warning-only drift rather
than first appearing as a bricked ai-review.

| Risk | Mitigation |
|---|---|
| A resolution bug bricks every consumer's AI gate | Fail loud + INFRA-classed (contract 3); normal-tag pilot (`ci/v2.10.0`) after PR-A (above) before the fix reaches the merge gate |
| Fallback-to-`main` sneaks in as "safety" | Explicitly forbidden by contract 3 — it would preserve the exact bug being fixed |
| Non-semver pin now hard-fails | Verified zero affected consumers; document + optional `check-pin-currency.sh` warning |
| Consumers stay silently on the old behaviour | They do until they re-pin; call this out in CHANGELOG + the arming rollout |

**Sequencing impact beyond this plan:** `ROLLOUT_plan015-arming.md` and any
widening of deployment must not be premised on "the pin determines reviewer
behaviour" until PR-C lands **and** consumers re-pin.

## Claim ledger

| # | Claim | Symbol | Citation |
|---|---|---|---|
| 1 | In a `workflow_call` reusable, `workflow_ref` is the CALLER's entry ref; `job_workflow_sha` is not `${{ }}`-accessible | `CALLER's` | .github/workflows/standards-drift.yml:11 |
| 2 | ai-review site 1 binds the caller ref into env | `GITHUB_WORKFLOW_REF` | .github/workflows/ai-review.yml:415 |
| 3 | ai-review site 1 parses the ref component | `REF=` | .github/workflows/ai-review.yml:429 |
| 4 | ai-review site 1 derives the owner from the same string (D2) | `CI_OWNER=` | .github/workflows/ai-review.yml:430 |
| 5 | ai-review site 1 builds the rubric/schema URL from both | `raw.githubusercontent.com` | .github/workflows/ai-review.yml:436 |
| 5a | A token is already available in that step's env | `GITHUB_TOKEN` | .github/workflows/ai-review.yml:418 |
| 6 | ai-review site 1 fetches the LiteLLM client the same way | `litellm_client.py` | .github/workflows/ai-review.yml:447 |
| 7 | ai-review site 2 (autofix) binds the caller ref | `GITHUB_WORKFLOW_REF` | .github/workflows/ai-review.yml:1140 |
| 8 | ai-review site 2 parses ref + owner identically | `CI_OWNER=` | .github/workflows/ai-review.yml:1144 |
| 9 | ai-review site 2 builds its fetch URL from both | `raw.githubusercontent.com` | .github/workflows/ai-review.yml:1150 |
| 10 | doc-maintainer site 1 uses the same expression | `CI_TAG:` | .github/workflows/doc-maintainer.yml:135 |
| 11 | doc-maintainer site 2 uses the same expression | `CI_TAG:` | .github/workflows/doc-maintainer.yml:196 |
| 12 | docs-sync uses the same expression | `CI_TAG:` | .github/workflows/docs-sync.yml:109 |
| 13 | docs-sync carries the wrong mental model in a comment | `github.workflow_ref` | .github/workflows/docs-sync.yml:112 |
| 14 | The fixed reference resolves the tag from the consumer's own checked-out caller pin | `CANON_TAG=` | .github/workflows/standards-drift.yml:83 |
| 15 | The fixed reference hardcodes the canon owner/repo in the URL | `vladm3105/aidoc-flow-ci` | .github/workflows/standards-drift.yml:98 |
| 16 | The review job deliberately uses `curl` not `actions/checkout`, after a 5-cycle failure saga | sparse-checkout saga | .github/workflows/ai-review.yml:353 |
| 17 | doc-maintainer `reconcile` checks out the caller repo (no `repository:` override) | `actions/checkout` | .github/workflows/doc-maintainer.yml:123 |
| 17a | doc-maintainer `maintain` likewise (the second site PR-B must fix) | `actions/checkout` | .github/workflows/doc-maintainer.yml:184 |
| 18 | docs-sync checks out the caller repo (no `repository:` override) | `actions/checkout` | .github/workflows/docs-sync.yml:76 |
| 19 | The autofix job checks out the PR **head**, so a PR controls those files | `pull_request.head.sha` | .github/workflows/ai-review.yml:1131 |
| 20 | ai-review has no existing canon/tag input (option B would be new surface) | `trust_config_ref` | .github/workflows/ai-review.yml:65 |
| 21 | FT-15 is confirmed with live evidence + scope | FT-15 | plans/FRAMEWORK-TODO.md:513 |
| 22 | The trust job checks out the trust-config repo, not the consumer | `trust_config_repo` | .github/workflows/ai-review.yml:175 |
| 23 | The shipped caller template triggers on `pull_request_review`, not only `pull_request_target` | `pull_request_review` | install/templates/workflows/ai-review.yml:29 |
| 24 | The unarmed guard `exit 0`s into a FULL review **before** the review-event skip — so an unarmed consumer reaches the fetch on review events | `R3 early-exit skipped` | .github/workflows/ai-review.yml:302 |
| 25 | Private-repo raw auth is "historically finicky"; this file already falls back to the API contents endpoint | `PRIVATE repo raw auth is historically finicky` | .github/workflows/ai-review.yml:464 |
| 26 | The review job holds `contents: write` | `contents: write` | .github/workflows/ai-review.yml:233 |
| 27 | Site 2's fetch step has no step-env token; only a job-level `GH_TOKEN` exists | `GH_TOKEN:` | .github/workflows/ai-review.yml:1018 |
| 28 | Forks never reach the autofix job | `Forks never reach here` | .github/workflows/ai-review.yml:996 |
| 29 | The autofix job is `pull_request_target`-only, so its own ref is the base branch | `github.event_name == 'pull_request_target'` | .github/workflows/ai-review.yml:1008 |
| 30 | Canon self-calls only `audit-trail-check` — it has NO self-caller for the three reusables, so their PRs cannot self-verify | `audit-trail-check.yml@ci/v2.9.0` | .github/workflows/audit-trail.yml:33 |
| 31 | Canon also recognises a commented-SHA pin form, which the resolver must accept or canon must drop | `# ci/v[0-9.]+` | sync/check-pin-currency.sh:71 |
| 32 | operations deliberately removed `pull_request_review` from its own ai-review caller (the template still ships it) | `pull_request_review:submitted REMOVED` | ../operations/.github/workflows/ai-review.yml:8 |

## Review log

### Pass 0 - 2026-07-21 - author

Drafted from the FT-15 live confirmation. Ledger built by opening each cited
line. Key finding that shaped the design: the review job's missing checkout is
**deliberate** (claim 16), which rules out a straight port of the
`standards-drift` pattern and forces the option analysis in §4 PR-C. Second
finding: the autofix job's PR-head checkout (claim 19) makes the naive "grep the
checked-out caller file" fix a **privilege problem** there, not just a mechanical
one. Gate run before dispatching review.

### Pass 1 - 2026-07-21 - independent

`verified-planning-reviewer`, fresh context, tasked adversarially. Returned **2
load-bearing + 5 minor**; all folded. Every finding re-verified at source by the
author before folding (none accepted on the reviewer's word).

- **LB-1 — Option C made a caller-controlled ref security-load-bearing.** The
  draft used `workflow_ref`'s `@<ref>` to fetch the caller file. The template
  also ships `pull_request_review` (claim 23) and the unarmed guard proceeds to a
  full review *before* the review-event skip (claim 24), so an unarmed consumer
  reaches the fetch on a review event — where the ref is PR-controlled. That is
  the same tamper vector the draft flagged for site 2, at the site it called
  trusted. **Fixed:** ref component discarded entirely; resolve at
  `pull_request.base.ref` → `repository.default_branch`. Verified all 8
  consumers are armed today (latent, not live) — but new consumers onboard
  **unarmed**, so it is live exactly during rollout.
- **LB-2 — the verification story was impossible.** Canon has no self-caller for
  these three reusables (claim 30), so a PR's own CI never executes the changed
  code; and a single tag after PR-C left nothing to re-pin to, making "proven on
  docs-sync first" vacuous. **Fixed:** §5 gained an explicit tag-then-pilot gate
  for PR-B/C. *(This fold initially used an `-rc.1` pre-release tag; Pass 3's
  LB-3 showed that breaks the resolver regex, and §5 now uses two normal semver
  tags. Recorded here so the log reflects what actually happened.)*
- **Minor, all folded:** site 2 is the *safer* site, not the riskier one
  (`path: prhead` → loud fail, fork-gated, `pull_request_target`-only — claims
  19/28/29), so the PR-C rationale was rewritten; the constraint is "no second
  checkout in the review job", not "checkout impossible" (claim 19); fetch must
  use the API contents endpoint, not raw, and site 2 needs an explicit token
  (claims 25/26/27); the new non-semver-pin hard-fail is now stated with an
  explicit MINOR justification; ledger gap for the second doc-maintainer
  checkout closed (claim 17a).

### Pass 2 - 2026-07-21 - independent

Fresh `verified-planning-reviewer`, told not to assume Pass 1 was right. It
**attacked and cleared LB-1's fold** (confirming the `base.ref` design was not
mis-generalised to PR-A/PR-B, which correctly use the on-disk grep and need no
`pull_request` object) and re-verified claims 23/24/30 semantically. It raised
**1 new load-bearing + 3 minor**; all folded, each re-verified at source first.

- **LB-3 (new) — the RC-tag gate contradicted the plan's own contract.** The
  ported resolver regex is unanchored, so `@ci/v2.10.0-rc.1` silently
  prefix-matches to `ci/v2.10.0` — **reproduced by direct test** — a nonexistent
  tag yielding an INFRA failure that would look like a bug in the fix. It also
  violated contract 3. **Fixed:** dropped pre-release entirely; §5 now cuts two
  normal semver tags (`ci/v2.10.0` after PR-A, `ci/v2.11.0` after PR-B+C), which
  needs no regex or contract change. Expanding the regex was rejected as
  speculative scope and recorded as explicitly out of scope.
- **Minor — `base.ref` is wrong on review events.** `pull_request_review`
  executes the **default-branch** copy of the caller, so a PR targeting a
  non-default base would read the wrong file — on exactly the exposed path.
  **Fixed:** §4 PR-C now selects the ref per event in a table.
- **Minor — the commented-SHA pin form** (`@<sha> # ci/vX.Y.Z`, claim 31) is
  legal in canon and contract 3 would have hard-failed it. **Fixed:** the
  resolver must accept both forms, or canon drops that form in the same change.
- **Minor — count inconsistency** (8 vs 9 consumers) reconciled to 8, and
  `operations`' removal of its own `pull_request_review` trigger noted
  (claim 32) so the narrative is not over-generalised.

Pass 2's own result was **1 load-bearing finding**, now folded. Readiness is NOT
claimed here — the author's fold does not get to certify itself. Pass 3
re-verifies.

### Pass 3 - 2026-07-21 - independent

Fresh `verified-planning-reviewer`, final pass under the OPS-0066 3-cycle cap.
Verified Pass 2's fold holds: canon is at `ci/v2.9.0`, so `ci/v2.10.0` →
`ci/v2.11.0` are the next MINORs and both match the resolver regex exactly with
no prefix hazard; it further confirmed the step-1 pilot is executable (all 8
consumers ship a `docs-sync` caller with a plain semver pin **and** the
`.github/docs-sync.json` that `docs-sync.yml` requires before the resolver step).
It independently confirmed the per-event ref table is correct and re-confirmed
claim 24's ordering. **Zero load-bearing findings.** Five minors raised, all
folded:

- a **stale "RC-tag pilot" cell** left in the risk table, contradicting the
  bolded no-pre-release block — the very defect Pass 2 found, surviving in one
  cell (fixed);
- the §4 rationale **overstated its own case** — for the two triggers consumers
  actually ship, `workflow_ref`'s ref already equals the table's values, so
  discarding it removes the *class*, not a live defect (restated precisely);
- PR-A must **port *and extend*** the grep, keyed to the workflow filename, with
  an explicit warning against copying the unkeyed alternation (which would match
  a different reusable's trailing comment and resolve the wrong tag);
- the per-event table needed a **default arm** for any third trigger;
- §5 step 1 is a **🔴 cross-repo write** (ops/inbox runbook) and `docs-sync` is
  post-merge, so the confirming notice lags the pilot PR's merge.

Scope confirmed right-sized: 3 PRs for 3 affected reusables, regex generalisation
explicitly deferred.

**Result:** ready
