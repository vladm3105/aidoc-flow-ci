# PLAN-029 — credential-less `ai-review` access, enforced at the proxy

**Status:** Draft — **NOT ready**, and deliberately so. Three independent review
passes were run (the OPS-0066 cap); pass 3 returned 3 load-bearing findings,
which are folded — but **that fold is unreviewed**, so one clean pass is owed
before execution. No phase has started. See the Review log for the open items.
**Owner:** canon (aidoc-flow-ci)
**Scope:** who may *use* the AI reviewer, and how that is proven. The per-repo
credential is today's de-facto repo gate; Phase B replaces it with proxy-side
OIDC authorization. Phase C is proxy key hygiene, actionable now.
**A canon-side `access.repos` allowlist was proposed and CUT at pass 2** — see
§1. Do not re-add it without reading that section first.
**Change level:** C3 — it moves the trust boundary of a required gate.
**Decisions of record:** CI-0051 (unified credentials; the `LITELLM_*`
fallbacks removed). This plan proposes the successor decision, not yet recorded.

## 1. The problem, and why this plan is only about the proxy

The founder's position: *"we have a trusted repos white list, so we do not need
API keys stored on the repos — repos should call `ai-review` directly without
credentials, like other checks."*

The goal is right. Two review passes reduced the plan to the only part that
delivers it.

**(a) The credential is today's de-facto repo gate.** Access is decided on the PR
**author** (Claims 1, 2); no allowlist of calling repositories gates ACCESS (`auto_merge.repos` is one, but it gates merges — §5). A
repo reaches the reviewer because someone provisioned it a key.

**(b) A canon-side allowlist cannot be the enforcement point.**
`trust_config_repo` is a **caller-supplied input** (Claim 16) and the shipped
caller invites overriding it (Claim 17) — a repo seeking access names the config
whose list is consulted. Worse, `composition` — the required check that actually
blocks merges — reads a **different config**: the consumer repo's own, at its
default branch (Claim 20), and is blind to any list placed in
`trust_config_repo`. Reconciling those two sources is the open, deliberately
deferred **FT-6** decision (Claim 21), not something to fold into this plan.

**(c) Therefore the enforcement point is the proxy.** It is the one place the
calling repo cannot choose the policy, and it is already partway to holding the
registry: keys minted by `--mint` carry `metadata.repo` (Claim 23). **Partway,
not complete** — shared-mode provisioning writes no per-repo metadata, which is
exactly the state C1 exists to fix on `framework` and `operations`.

**PHASE A CUT at pass 2.** Earlier drafts proposed an `access.repos` key in the
trust config, consulted by the trust job. Cut because it changed no behaviour
(absent key had to permit, or adoption broke every consumer), because the proxy
does not need a second copy of a repo list, and because it was **net-negative
risk**: a trusted author in an omitted repo would have had the review job
skipped while `composition` found no exemption and enforced — a permanent red
required check across that repo, from an edit to one shared file in another
repo. The policy is worth recording as a decision; it is not worth a consumed
config key ahead of knowing B2's mechanism.

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | Trust resolution reads the `trust` object keyed by PR author; there is no allowlist of calling repositories | `in_list()` | .github/workflows/ai-review.yml:346 |
| 2 | `AI_REVIEW_OK` is set from the author allowlist and the fork check — no repository allowlist participates | `in_list ai_review && AI_REVIEW_OK=true` | .github/workflows/ai-review.yml:351 |
| 8 | `LLM_URL` + `LLM_API_KEY` are declared reusable secrets — the credential Phase B removes | `LLM_API_KEY` | .github/workflows/ai-review.yml:92 |
| 16 | `trust_config_repo` is a caller-supplied input, so the caller chooses which config is consulted | `trust_config_repo` | .github/workflows/ai-review.yml:62 |
| 17 | The shipped caller explicitly invites external adopters to point it at their own config repo | `trust_config_repo: your-org/your-ops-repo` | install/templates/workflows/ai-review.yml:75 |
| 18 | Removing a declared secret breaks a caller using an EXPLICIT secrets map: GitHub refuses a map naming an undeclared secret and the workflow fails to LOAD. Callers using `secrets: inherit` are unaffected | `the workflow fails to LOAD` | .github/workflows/ai-review.yml:101 |
| 20 | `composition` reads the CONSUMER repo's own config at its default branch — not `trust_config_repo` — so a list placed there is invisible to the enforcing gate — NEW@pass2 | `contents/.github/ai-review/config.json?ref=$DEFAULT_BRANCH` | .github/workflows/composition.yml:226 |
| 21 | Reconciling the two config sources is an open, deliberately deferred decision (FT-6) — NEW@pass2 | `FT-6 — trust-config source inconsistency` | plans/FRAMEWORK-TODO.md:1099 |
| 11 | **BLOCKS Phase B.** The deployed proxy supports JWT/OIDC auth well enough to authorize on the `repository` claim | — | PROBE: `curl -sS -H "Authorization: Bearer $MASTER" http://172.17.0.1:4001/config/list -o /tmp/p.json; grep -ic jwt /tmp/p.json`. A grep hit is necessary, NOT sufficient — confirm the JWT auth path is not licence-gated on this install before treating it as GO |
| 12 | **BLOCKS Phase B.** The proxy ACCEPTS a GitHub OIDC token from a listed repo and REFUSES one whose `repository` claim is unlisted | — | PROBE: on a THROWAWAY repo, mint via `$ACTIONS_ID_TOKEN_REQUEST_URL`, POST twice — once listed, once unlisted — assert 2xx then 401/403. PRECONDITION: depends on Claim 22 |
| 22 | **BLOCKS Claim 12's probe.** The proxy is reachable only from the ephemeral pool, so a throwaway needs a JIT-registered runner on the proxy host — NEW@pass2 | — | PROBE: `ss -ltn 'sport = :4001'` on the proxy host to read the bind address, then attempt the same request from a host outside the bridge and record the result |
| 23 | Only `--mint` writes `metadata.repo`; shared mode provisions one key with no per-repo metadata — NEW@pass3 | `max_budget` | install/set-llm-secrets.sh:322 |
| 24 | `--mint` SKIPS minting when the target secret already exists unless `--overwrite` is passed, and the run still exits 0 — NEW@pass3 | `action_for LLM_API_KEY` | install/set-llm-secrets.sh:402 |
| 13 | **BLOCKS Phase C3.** `main-api-key` has `models: []`; whether that is unrestricted or none-permitted is not readable from canon | — | PROBE: attempt one completion with that key against a model NOT in any scoped list; 2xx means unrestricted, 4xx means none-permitted |

## 2. Phase B — move authorization to the proxy (BLOCKED on Claims 11, 12)

- **B1 — OIDC in the reusable.** Request a GitHub OIDC token and present it
  instead of a bearer key. No OIDC is used today.
- **B2 — proxy-side validation.** Validate against GitHub's JWKS and authorize on
  the `repository` claim. **Consider binding `job_workflow_ref` as well** —
  `repository` alone lets any workflow in a listed repo mint an accepted token.
  The repo list lives at the proxy, alongside the per-repo keys it replaces.
- **B3 — retire the per-repo credential.** Only after B1/B2 prove out.

**Definition of done for B2 is a REFUSAL, not an acceptance.** A proxy that skips
verification is indistinguishable from one that verifies until a claim is forged.

**Consumer cost:**

1. `permissions: id-token: write` on the caller — and the caller's
   workflow-level `permissions:` block is the ceiling.
2. Dropping `LLM_API_KEY` from the reusable's `secrets:` block breaks callers
   using an **explicit** map (which is what canon ships); `secrets: inherit`
   callers are unaffected (Claim 18). The migration is **enumerable** — audit
   which consumers use `inherit` — not universal.
3. **`--repin` cannot deliver either change** — both live in the caller body, so
   it is `--update` plus re-applying each consumer's local edits.
4. `LLM_URL` remains a repo secret. B removes the **credential**, not every secret.
5. **Canon's own provisioning surface must retire with it** — `--mint`/shared
   mode in `install/set-llm-secrets.sh`, the `LLM_API_KEY:` forward in
   `install/templates/workflows/ai-review.yml`, and `docs/MIGRATION_v4.0.0.md`
   §3. An earlier draft called the migration "enumerable" while listing only the
   consumer half — NEW@pass3.

Because of (2), B belongs in a MAJOR — and **not** `ci/v4.0.0`, which is
cut-ready with four breaking changes already.

## 3. Phase C — proxy key hygiene (C1/C2 actionable now; C3 blocked on Claim 13)

- **C1 — per-repo keys for `framework` and `operations`**, then revoke the
  now-unused generic key. Gets per-repo revocability **today**, without Phase B.
  **Use the shipped script, not the API by hand** — `install/set-llm-secrets.sh`
  mints AND re-provisions the repo's `LLM_API_KEY` in one run, which is the step
  whose omission is #350:

  ```sh
  ( export LLM_URL=... LLM_MASTER_KEY=...            # subshell: key leaves no trace
    bash install/set-llm-secrets.sh --mint --overwrite \
      --repos "vladm3105/aidoc-flow-framework vladm3105/aidoc-flow-operations" )
  ```

  **`--overwrite` is REQUIRED and its absence is silent** (Claim 24): both repos
  already hold an `LLM_API_KEY`, so a bare `--mint` reports `2 kept`, exits 0,
  and changes nothing while reading as done. Run `--dry-run` first.

  **Identify the key to revoke by `metadata.repo`, never by purpose**: `ci-review`
  is the `purpose` on *every* review key including the per-repo ones (Claim 23).
  Revoke only after a real PR on each repo has gone green on the new key.
  Re-derive the inventory (volatile, CI-0028): `curl -sS -H "Authorization:
  Bearer $MASTER" http://172.17.0.1:4001/key/list?return_full_object=true -o
  /tmp/k.json`, then inspect each key's `metadata.repo`.
- **C2 — drop the leftover `ci-review-mint-test` key.**
- **C3 — settle `main-api-key`'s scope** (Claim 13) and narrow it if unrestricted.

**Already done:** the two `ai-doc-maintainer` virtual keys were revoked
2026-08-24, after confirming both surviving callers are `disabled_manually`.
They were credential debt from the flow CI-0040 retired.

## 4. The decision to record

The access policy belongs in `DECISIONS.md` whether or not B ever ships: *the
reviewer is a shared service; the repo list lives at the proxy, and canon-side
config is advisory because the caller chooses it.* That is the auditable
artifact Phase A was reaching for, at none of its cost.

## 5. What this plan does NOT do

- It does not change who the trusted **authors** are.
- It does not touch `auto_merge.repos`, or reconcile the two config sources
  (FT-6, Claim 21).
- It does not alter the review budget (PLAN-011 owns that).
- It does not assume B is cheap. If Claim 11 probes negative, B needs a
  different mechanism and this plan should be re-scoped, not stretched.

## Review log

### Pass 1 - 2026-08-24 - independent

`verified-planning-reviewer`. **9 load-bearing findings**, three of them fatal to
the plan's framing. All folded; the fold was subtractive — the plan is smaller
and claims less.

| # | Finding | Fold |
| --- | --- | --- |
| 1 | Claim 10 cited `governance.locked_paths`, which CI-0005 records as read by NO workflow and forbids relying on | Citation replaced with the hardcoded glob (`ai-review.yml:898`) |
| 2 | §1a's lead argument (reuse impossible because framework is absent) is refutable — framework is hardcoded LOCKED before the allowlist is consulted | RETRACTED; §1a now leads with policy separation. Claim 14 added |
| 3 | **Phase A is not an authorization boundary** — `trust_config_repo` is caller-supplied, so the caller elects which list applies | Plan re-shaped: A produces the list, only B enforces. §1c added; Claims 16, 17 |
| 4 | Claim 3 false — `auto_merge.repos` has TWO consumers, not one | Corrected; conclusion (merge-only) strengthened |
| 5 | A1 and A2 contradicted on the absent-key case | Resolved: absent ⇒ PERMIT, with the reasoning from §1c. RETRACTED |
| 6 | Phase B cost understated — removing a declared secret hard-breaks stale callers (`startup_failure`), plus the permissions ceiling and `--repin` | Four costs enumerated; Claim 18 |
| 7 | Claim 12's probe not executable — proxy unreachable from GitHub-hosted runners | Precondition added (JIT runner on the host); Claim 15 |
| 8 | §1b overstated the residual threat | RETRACTED; narrowed to repos with a registered runner |
| 9 | A2's denial would leave `composition` permanently red — a repo-wide merge outage | A2 now requires routing to human review, never a job failure. Claim 19 |

Not load-bearing, also folded: Claims 1/2 reworded ("no repository **allowlist**"
rather than "no repository term" — `IS_FORK` is repository-derived); Claim 7's
line corrected (`:41` is the top-level `additionalProperties`; `:17` is
`litellm`'s); C1 gained a re-derive command per CI-0028.

Confirmed sound by the reviewer: **A3's retraction** — nothing validates the
config against its schema at runtime, so no lockstep is needed. Claims 4, 5, 8
semantically true in context.

**Note added at pass 2, corrected at pass 3:** Claims 10, 14 and 19 were CUT
with Phase A at pass 2. Claim 15 was NOT cut — its content survives as Claim 22,
which still gates Claim 12's probe. Their references above are historical —
they record what pass 1 changed, not rows in the current ledger.

**Result:** folded, re-dispatching.

### Pass 2 - 2026-08-24 - independent

`verified-planning-reviewer`, aimed at the pass-1 FOLD. **4 load-bearing
findings.** The fold was correct on facts and wrong on shape; the response was a
scope cut, not another layer of prose.

| # | Finding | Fold |
| --- | --- | --- |
| 1 | **A2's denial-routing remedy did not clear the failure it was added to fix.** `composition` carries its own mirrored trust gate reading the CONSUMER's config, is blind to `ai:human-review-required`, and would enforce anyway — a permanent red required check | **Phase A CUT.** The path no longer exists. Claims 20, 21 added |
| 2 | One `access.repos` key cannot serve both gates — the shipped template says so itself (FT-6) | Folded into §1b; Claim 21 |
| 3 | **The case for cutting Phase A is stronger than keeping it** — no behaviour change, B does not need the list, A1's shape undecided until B2's mechanism is, and it carried net-negative risk | **Accepted. Phase A cut**; the policy is recorded as a decision instead (§4) |
| 4 | §1b's retraction swapped one uncited certainty for another — the proxy's bind address had no citation and is unverifiable from either repo | Demoted to PROBE (Claim 22), which now gates Claim 12's probe |

Minor, also folded: Claim 14's stated ordering was false at the second consumer
(conclusion survived, claim cut with Phase A); Claim 18 rescoped — `secrets:
inherit` callers are unaffected, so the B3 migration is enumerable, not
universal; Claim 11's probe marked necessary-but-not-sufficient; orphaned rows
(5, 9, 10) removed with the cut.

**Ledger: 13 rows → 12** (6 cut across the two folds, 3 added). The plan body
shrank by roughly a third. Growth would have been the defect signal; this went
the other way.

**Result:** folded by scope cut. One more pass owed on the reduced plan.

### Pass 3 - 2026-08-24 - independent

`verified-planning-reviewer`, on the reduced plan. **3 load-bearing findings —
the plan did NOT converge within the OPS-0066 cap of 3 passes.**

| # | Finding | Fold |
| --- | --- | --- |
| 1 | Title and Scope still sold Phase A, which the body forbids — and in this repo the plan header IS the cold-start registry row (CLAUDE.md names PLAN-024's stale header as the precedent) | Retitled; Scope rewritten to lead with B and record the cut |
| 2 | **C1 would have silently done nothing.** `--mint` skips when the secret exists unless `--overwrite`, and still exits 0; C1 also omitted re-provisioning (the #350 failure) and invited revoking by `purpose`, which every review key shares | C1 rewritten around the shipped script, with `--overwrite`, the subshell, and identification by `metadata.repo`. Claims 23, 24 added |
| 3 | §1c asserted the proxy "already holds a per-repo registry" — uncited, and untrue for shared-mode repos; B3's cost omitted canon's own provisioning surface | §1c corrected to "partway"; cost item 5 added. Claim 23 |

Minors folded: "five breaking changes" → four (`MIGRATION_v4.0.0.md` says four);
§1a's "anywhere" qualified now that Claim 3 is cut; the pass-2 cut note corrected
(Claim 15 was NOT cut — it survives as Claim 22); Review-log arithmetic fixed.

Confirmed by the reviewer, not to be re-litigated: the **Phase-A cut is
justified** — `composition.yml` has no exemption keyed on
`ai:human-review-required` and a skipped review job falls through to enforce;
Claims 1, 2, 8, 16, 17, 18, 20, 21 semantically true in context; **no reference
to `PLAN-029` exists outside the plan itself** in either repo, so the cut
orphaned nothing; each remaining phase owns a deliverable.

**Result: NOT ready — cap reached with 3 load-bearing findings.** Per OPS-0066
no fourth pass was dispatched. The findings above are folded, but **that fold is
itself unreviewed**, which is precisely the state the cap exists to surface
rather than paper over. Open items for the human:

1. Is the reduced scope (B blocked + C actionable + a decision to record) the
   right plan, or should B be dropped until the probes are run?
2. C1 is executable today and is the only part with immediate value — run it
   independently of the rest?
3. The pass-3 fold needs one clean pass before this is called ready.
