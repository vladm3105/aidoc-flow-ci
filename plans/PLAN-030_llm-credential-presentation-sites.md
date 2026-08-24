# PLAN-030 — pin the LLM credential's presentation sites

**Status:** Ready.
**Owner:** canon (`aidoc-flow-ci`).
**Scope:** one canon self-test. Tag-independent, probe-free, no consumer
mutation, no credential mutation, no network.

## 1. The problem, stated exactly

Neither `ai-review` job builds an authorization header. Both fetch and run
`scripts/llm_client.py`, which reads `LLM_API_KEY`, hard-fails when it is absent
(Claim 1), and builds the bearer header (Claim 2).

Nothing records this. A discarded plan proposed retiring the credential by
editing only the two workflow `env:` blocks; executed as written, every review
would have died at `llm_client.py:168` — the required `call / ai-review` check
(Claim 3) red across the fleet, from a change that looked complete.

The inverse error is equally available and was also made: a later draft asserted
`llm_client.py` is the **only** file building an LLM authorization header. That
is false at HEAD — `install/set-llm-secrets.sh` builds one at `:257` and `:319`
(Claim 4) against `LLM_URL`-derived endpoints. An "only one file" assertion goes
red at HEAD and has to be weakened at authoring time to ship, which is the
assert-the-message-not-the-teeth anti-pattern.

Both errors are the same shape: an unstated assumption about where a credential
is presented. The fix is to state it, closed, and let a test hold it.

## 2. The change

Add a canon self-test asserting a **closed allowlist of exactly two LLM
credential presentation sites**:

| Site | Role | Claim |
| --- | --- | --- |
| `scripts/llm_client.py` | runtime — every review and the smoke check | 2 |
| `install/set-llm-secrets.sh` | provisioning — pre-write probe and mint | 4 |

and that the runtime hard-fail is intact (Claim 1).

Scope the match to **LLM-endpoint** headers. Canon builds many GitHub-API bearer
headers that are not in this family and must not be swept in (Claim 5).

**Definition of done:**

- passes at HEAD;
- deleting the hard-fail at `llm_client.py:168` turns it red;
- adding an LLM authorization builder in any third file turns it red;
- adding a **GitHub-API** bearer header in a new file does **not** turn it red
  (the scope guard — without it the test fails on unrelated future work and gets
  weakened or deleted).

The test is offline and needs no `gh`, matching the existing script-test harness.

## 3. Out of scope — and why

| Excluded | Why |
| --- | --- |
| Cutting `ci/v4.0.0` | owned by PLAN-027 B1, still not started (Claim 6) |
| Per-repo virtual keys, revoking the shared key | gated on the tag **and** a fleet repin; neither has happened |
| OIDC / credential-less access | rests on unmeasured probes, and its edit sites were wrong |
| A pre-repin caller-compatibility fleet audit | **CUT@pass2** — see §4 |

## 4. What was cut, and why it is not here

A fleet audit detecting the silent v4 caller breaks (retired runner labels,
undeclared `LITELLM_*` in explicit `secrets:` maps, the renamed
`llm_allow_insecure_http` input, and the deleted `doc-maintainer` reusable) was
this plan's original deliverable. Two review passes took it from 5 load-bearing
findings to 10 — growth, which is the signal to cut rather than fold again.

The findings were not prose defects; they were terrain:

- the canon-side fleet step is **public-only by design** (Claim 7), so it
  structurally cannot read the four private consumers — including `operations`;
- `check-pin-currency.sh` is contractually **warning-only and always exits 0**
  (Claim 8), with three call sites, so making findings block is its own change;
- 4 of the 5 currently-audited repos are already pin-stale, so a naive exit-code
  change reds canon's weekly job for unrelated reasons;
- fleet mode has **no offline exerciser** (Claim 9), so every acceptance and
  mutation test would be live-network-only.

It is a real and valuable piece of work with a credential prerequisite that this
plan cannot settle. It is captured with its full evidence base — all ten findings
with citations — in **aidoc-flow-ci#528**, rather than carried here as a phase
that cannot converge.

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | The client hard-fails when the key is absent | `LLM_API_KEY is not set` | scripts/llm_client.py:168 |
| 2 | The client builds the LLM bearer header | `Authorization` | scripts/llm_client.py:209 |
| 3 | `call / ai-review` is a required status context | `call / ai-review` | install/templates/branch-protection-governance.json:7 |
| 4 | `set-llm-secrets.sh` also builds an LLM bearer header, so the client is not the only site | `Authorization: Bearer` | install/set-llm-secrets.sh:257 |
| 5 | Canon builds unrelated GitHub-API bearer headers that must not be swept into the assertion | `Authorization: Bearer` | .github/workflows/ai-review.yml:236 |
| 6 | `ci/v4.0.0` is not cut; PLAN-027 B1 owns it and has not started | `B1 — the cut itself` | plans/PLAN-027_v4-release-readiness.md:12 |
| 7 | The canon-side fleet step is public-only; `GITHUB_TOKEN` cannot read the private consumers | `--fleet` | .github/workflows/standards-drift-self.yml:88 |
| 8 | `check-pin-currency.sh` is contractually warning-only and always exits 0 | `exit 0` | sync/check-pin-currency.sh:108 |
| 9 | The script-test harness runs offline with no `gh`, and covers pin-currency in-repo only | `check-pin-currency` | docs/EXERCISER_INVENTORY.md:116 |

## Review log

### Pass 1 - 2026-08-24 - independent

5 load-bearing findings, all verified against source before folding; 3 fatal to
the draft. The two that survive into this plan:

- **The presentation-site assertion was false at HEAD.** `set-llm-secrets.sh`
  builds LLM bearer headers at `:257`/`:319` (Claim 4). "Only one file" would
  have gone red at HEAD. Restated as a closed two-site allowlist.
- The fleet-audit phase was rehomed after its first home was shown to be
  structurally inert. That phase was subsequently cut — see Pass 2.

### Pass 2 - 2026-08-24 - independent

10 load-bearing findings — **growth over Pass 1, so the fleet-audit phase was
CUT rather than folded a second time** (§4). Verified before cutting: the
public-only fleet constraint (Claim 7) and the warning-only exit contract
(Claim 8), which together made that phase's stated acceptance criteria
unachievable on the invocation path it named.

This pass independently verified the surviving phase as **sound and complete**:
it grepped every `Authorization` builder in canon and confirmed the only two
targeting an LLM endpoint are `scripts/llm_client.py:209` and
`install/set-llm-secrets.sh:257`/`:319` — the closed allowlist holds at HEAD.
It also confirmed `tests/test_scripts.sh:94` *reads* a header in a stub server
rather than building one, and that every other bearer header in canon is a
GitHub API token — which is why the scope guard is a named acceptance criterion.

**Result:** ready. Zero load-bearing findings against the surviving scope.
