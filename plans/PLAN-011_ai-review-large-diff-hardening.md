# PLAN-011 — ai-review large-diff hardening (Tier 1 + honest infra signal)

**Owner:** `aidoc-flow-ci` maintainer
**Origin:** consumer bug report (llm-router PR #7, 2026-07-17): the required
`ai-review` gate fails on large PRs with `litellm: proxy request failed after 3
attempts: ResponseShapeError` → `exit 1`, blocking merge of large coherent
changes even when every other check is green. Diagnosed as a reviewer-
infrastructure limitation (strict verdict-JSON parsing at scale), not a code
finding.
**Status:** SHIPPED — PC-1/PC-2 VERIFIED against the live proxy 2026-07-17; implemented (#185); released as `ci/v2.1.1` (verdict `max_tokens` 4096→8192 + `ai:review-infra-error` signal) and `ci/v2.1.2` (budget headroom → 24576, live-verified). See Live verification.
**Depends on:** none (bug is live on `ci/v2.1.0` and every prior tag — the client
is byte-identical at `ci/v2.0.0` and `main`, Claims 2/5).
**Exit:** a ~130 KB / 45-file PR either produces a valid verdict without a
`ResponseShapeError` **or** — if a residual mechanism remains (e.g. the verdict
genuinely needs > the model's output cap) — surfaces it legibly via the F4
infra signal instead of an opaque red check; AND a reviewer-infrastructure
failure is distinguishable from a genuine "changes requested". → `ci/v2.1.1`
patch tag. (The strict parser stays strict; residual robustness, if the honest
signal shows it's needed, is a follow-up with evidence — not a speculative
parser change now.)

## Summary

The verdict client (`scripts/litellm_client.py`) parses the model's free-form
`message.content` as strict JSON and fails closed after 3 attempts. The reported
`ResponseShapeError` on a 130 KB / 45-file diff has one lead cause and one honest-
signal gap — and, per the Pass-2 independent review, the two "extra robustness"
fixes I first proposed (mine `reasoning_content`; loosen the parser) would add
correctness/injection risk to a fail-closed security gate and are **rejected**
(see Rejected alternatives). The safe fix is two changes:

- **T1 — the model runs out of output budget.** The reported symptom is
  `ResponseShapeError` (not `TimeoutError`), which points at **truncation**:
  `max_tokens` defaults to **4096** (Claim 2) with no output-budget scaling while
  the *input* is gated at 400 KB (Claim 13). A large diff → a long completion cut
  mid-JSON → `json.loads` fails (Claim 8) → after 3 attempts, `fail()` (Claims 11,
  12). `response_format: json_object` is already set (Claims 4, 10), so once the
  model *finishes* it returns JSON the strict parser (Claim 8) already handles
  (bare or fenced) — the problem is finishing, not shape. The `--timeout` bump is
  **precautionary headroom** for the longer generation the larger budget permits
  (each attempt is capped at `timeout/3` ≈ 200s, Claims 22/23), not a fix for the
  observed `ResponseShapeError`.
- **F4 — dishonest failure signal.** On a client failure the verdict step tails
  the log and `exit 1` (Claim 15); the "Gate · comment · label · merge" step's
  `if:` is implicitly ANDed with `success()` (Claim 19), so it is **skipped** —
  the result is an opaque red required check with a `::error::litellm:` line, no
  label, no comment. The *asset/diff-fetch* infra failures already post
  "INFRASTRUCTURE error, NOT a verdict. Re-run." (Claim 16); the verdict-client
  failure does not.

This is **2 fixes** — give the model enough budget+time to finish (T1), and make
any residual failure legible (F4) — deliberately *not* speculative robustness on
the security parser. If large diffs still fail after T1, the honest F4 signal
makes the *actual* residual mechanism visible, and we add targeted robustness
then, with evidence, rather than guessing now.

### Rejected alternatives (Pass-2 security findings)

- **Mining `reasoning_content` (was T2) — rejected (F1).** `content` is empty
  essentially only when generation truncated mid-reasoning, so `reasoning_content`
  holds the model's *unfinished chain-of-thought*, not its verdict. Extracting a
  `{…}` from it surfaces a draft/quoted decision on a fail-closed gate. T1 (finish
  the generation) is the correct fix for empty content.
- **First-balanced-object parsing (was T3) — rejected (F2).** New injection
  surface: a diff-planted `{"decision":"approve"}` quoted in the model's prose
  before its real verdict would be extracted as "first `{`" and pass
  `validate_verdict`. The strict parser (Claim 8) fails closed on that today. Do
  not loosen the parser on untrusted-influenced output of a 9-repo security gate.
- **Author-side "split large PRs" rule — rejected.** Pushes an infra bug onto
  authors and fragments atomic changes; smaller PRs stay *soft* guidance, never a
  gate. The reviewer should be robust up to the existing 400 KB ceiling.
- **Deferred (not required to hit the exit criterion; revisit only with
  evidence):** chunked map-reduce review, `json_schema`/forced-tool-call
  structured output (DeepSeek support unverified), tiered-reviewer routing.

---

## Pre-implementation checks (REQUIRED before T1 picks a number — Pass-2 F4)

Both need live-proxy access (the `LITELLM_*` secrets); do them on a runner or a
scratch env, not blind:

- **PC-1 — model output cap.** Confirm `deepseek-v4-pro` (the `ai-reviewer` alias)
  accepts the chosen `max_tokens` *without a hard HTTP 400*, or that LiteLLM
  clamps it. 400 is non-retryable in the client (only 429/5xx retry, Claim 12's
  neighbourhood) → a too-high default would fail-close the gate on **every** PR.
  If the confirmed cap is below the target, set the default to the cap.
- **PC-2 — completion time.** Measure a large-diff verdict's wall-clock at the
  chosen `max_tokens` against the per-attempt window; set the verdict `--timeout`
  so a full completion fits inside one attempt with margin.

## T1 — Give the model enough budget + time to finish (`scripts/litellm_client.py` + `ai-review.yml`)

1. **`max_tokens`:** default verdict-mode to **8192** (2× today's headroom, within
   DeepSeek chat models' historical cap — pending PC-1; raise only if PC-1
   confirms a higher cap). Non-verdict `--json`/plain calls keep 4096. The
   `LITELLM_MAX_TOKENS` env override (Claim 2) is unchanged, so an operator can
   tune per-model without a canon edit — model-agnostic, no deepseek value baked
   into logic.
2. **Timeout:** pass an explicit `--timeout` on the verdict invocation
   (ai-review.yml, Claim 14) sized per PC-2 (e.g. 900), so a larger completion is
   not cut off by the ~200s per-attempt window. The client's 1..1800 bound
   (Claim 11's neighbourhood) already accommodates this.

**Exit:** a large-diff verdict finishes and returns parseable JSON — neither
truncated (budget) nor cut off (window) — for the reported 130 KB / 45-file case.

## F4 — Make an infra failure legible, not a fake "changes requested" (`ai-review.yml` + labels)

1. **A signalling step SCOPED to the verdict-client failure** (Pass-2 F5 + Pass-3
   F-1). The verdict step (the "Run review through LiteLLM → verdict file" step,
   Claim 14) has no `gh` token and the Gate step's `retry()`/`set_label()` are
   local to its `run:`, so this is a new step, not a helper reuse — modeled on the
   diff-fetch infra path (Claim 27), which already has `GH_TOKEN`/`GH_REPO`/`PR`
   and posts a comment. **A bare `if: failure()` would over-fire** — it runs on
   ANY prior step failure (asset-fetch, diff-fetch), and those already post their
   own infra comment (Claim 16/27) → a double-post. So:
   - give the verdict step an **`id:`** (it has none today), and
   - guard the new step `if: ${{ always() && steps.<id>.outcome == 'failure' }}`
     so it fires **only** when the verdict client failed (an earlier failure
     leaves the verdict step `skipped`, not `failure`, correctly excluding it).
   The step then sets `ai:review-infra-error` (see label handling below) and posts
   *"AI review — infrastructure error (the reviewer could not produce a verdict;
   e.g. `ResponseShapeError`). This is **not** a code finding — re-run the
   `ai-review` job."* It does **not** change the outcome: the verdict step already
   `exit 1`ed → the required check stays RED (fail-closed).
   *(Deferred, not the reported bug: unifying the asset/diff-fetch infra paths to
   also set the label — they comment honestly today but carry no label. A broader
   refactor; out of scope for this patch.)*
2. **Gate-step no-parseable-verdict path** (Claim 17) — *defensive consistency,
   not the reported bug* (Pass-2 F6: for a `ResponseShapeError` the verdict step
   exits 1 and the Gate step is skipped, so this branch is not reached; it is
   reached only if the client exits 0 with a garbage `$OUT`, which
   `os.replace`-after-`validate_verdict` (Claim 26) makes unlikely). Re-point its
   label from `ai:review-changes` to `ai:review-infra-error` (via the same
   three-way `set_label`) for the missing/garbage-file case only. Keep its `exit 1`.

**New label `ai:review-infra-error` — a THIRD mutually-exclusive review-outcome
state** (Pass-3 F-2 corrects Pass-2 F8): add to `install/templates/labels.json` +
`LABELS.md` §state table with an **unused** color (Pass-2 F7: `fbca04` is taken by
`ai:human-review-required`; use e.g. `d4c5f9` lilac). It is NOT like
`ai:human-review-required` (a trust-routing state, orthogonal, correctly outside
the cycle): a PR is in exactly one of {passed, changes, infra-error}, so
infra-error must **join** the mutual exclusion. Extend `set_label`'s cycle (Claim
18) from two states to **all three** — setting any one deletes the other two.
Otherwise a re-review that hits an infra error after a prior verdict shows
`ai:review-passed` AND `ai:review-infra-error` at once — the exact dishonest
signal F4 exists to remove. The F4 step (item 1) and the Gate step both use the
three-way cycle.

**Distribution caveat (Pass-3 F-3):** the label is applied via `POST
.../issues/{n}/labels`, which returns **422 for a label not present in the repo**
(it does not create labels) and is swallowed by `|| true`. On a consumer that
repins `ci/v2.1.1` but has not re-run `install.sh`'s label step (or
`gh label create`), the *label* half silently no-ops and only the *comment*
posts. Until the label is installed the comment is the reliable infra signal;
pair the tag with a consumer label-sync (or note it in the release).

**Constraint (fail-closed preserved):** F4 changes only the *signal* (label +
comment), never the *outcome* — every path that failed the required check before
still fails it. Verify no path that previously `exit 1`ed now exits 0.

**Governance-floor interaction:** F4 touches `.github/workflows/ai-review.yml` +
`install/templates/labels.json`; a PR editing the ai-review gate is
governance-locked (Claim 21) → human-merge, correct for a change to the gate.

**Exit:** a `ResponseShapeError` (or any verdict-client failure) surfaces as
`ai:review-infra-error` + an explanatory comment, distinct from
`ai:review-changes`; the required check stays red.

---

## Sequencing + verification

1. **PC-1 + PC-2** first (live proxy) — pin the `max_tokens` and `--timeout`
   values against the real model. Do NOT ship blind numbers.
2. **T1** in `scripts/litellm_client.py` (verdict `max_tokens` default) +
   `ai-review.yml` (verdict `--timeout`), with a **client unit test** in `tests/`
   (canon's suite runs `tests/test_*.sh`; the LiteLLM adapter already has a test
   harness — `tests/test_scripts.sh` exercises it):
   - the verdict-mode default is the chosen value, overridable by
     `LITELLM_MAX_TOKENS` (regression on Claim 2);
   - **`normalize_json_object`/`validate_verdict` are UNCHANGED** — assert the
     strict parser still rejects prose-wrapped and multi-object completions
     (locks in the F1/F2 rejections: no parser-loosening slipped in).
3. **F4** in `ai-review.yml` + `labels.json` + `LABELS.md`: a workflow-contract
   assertion that the `if: failure()` signalling step exists and that
   `ai:review-infra-error` is in `labels.json` outside the `set_label` cycle.
4. **Live verification** (the exit criterion, needs proxy): reproduce the
   llm-router PR #7 case (~130 KB / 45 files) — or a scripted large synthetic diff
   through the client against the live proxy — and confirm (a) a valid verdict
   with the new budget/timeout, and (b) that an *induced* client failure surfaces
   `ai:review-infra-error` + the infra comment, red check. Record both.
5. **Cut `ci/v2.1.1`** (patch — no input-schema change; `max_tokens` default,
   `--timeout`, and the new label are additive) per `docs/RELEASE_CHECKLIST.md`;
   the fleet repin (founder-tracked in operations #268) picks it up. `labels.json`
   is not auto-applied to consumers by a tag — note that consumers get the new
   label on their next `install.sh` label step (or a manual `gh label create`).

## Live verification (2026-07-17, against the running LiteLLM proxy)

Ran the real pre-checks + exit criterion against `ai-reviewer` → `deepseek-v4-pro`
on the live proxy (`localhost:4001`). **All pass; the two placeholder numbers are
confirmed correct.**

- **PC-1 (model output cap) — PASS.** `max_tokens=8192` with `response_format:
  json_object` → **HTTP 200**, `finish_reason: stop`, clean JSON in `content`. No
  non-retryable 400. The one assumption that could red-check every PR is
  disproven. Follow-up (2026-07-17): probed higher — 32768 and 65536 also return HTTP 200, so the model's cap is above this client's 32768 validator; the verdict default was raised 8192 → 24576 for headroom against reasoning spikes on large diffs.
- **PC-2 (completion time) — PASS.** A 205 KB / 45-file diff verdict completed in
  **31–42s** — well inside `--timeout 900` (≈300s/attempt). Ample margin.
- **Exit criterion — PASS.** The actual client (`--verdict`, 8192 default) produced
  a valid, schema-conformant verdict on a 205 KB / 45-file diff.
- **T1 mechanism + fix — PROVEN (differential).** SAME complex diff (45 files ×
  10 distinct security bugs): **`max_tokens=4096` → `ResponseShapeError` after 3
  attempts (168s)**; **`max_tokens=8192` → valid verdict, 10 findings (42s)**. The
  reported bug reproduced, the fix proven, on the live model. Root cause confirmed:
  `deepseek-v4-pro`'s **reasoning tokens count against `max_tokens`** (usage showed
  reasoning_tokens separate but billed to completion), so a complex diff's heavy
  reasoning exhausts 4096 before the verdict JSON finishes.
- **Validates a rejected fix.** `reasoning_content` came back **present and
  separate** from `content` — confirming Pass-2 F1: the verdict is in `content`, so
  the dropped "mine `reasoning_content`" fix would have read the model's *thinking*,
  not its decision.

Not live-exercised (no code path to drive without a full PR run): the F4
signalling step's end-to-end behaviour on a real gate — covered by the
security-auditor + silent-failure-hunter reviews on #185 and the client unit
tests. A throwaway consumer PR at the tagged ref would exercise it post-`ci/v2.1.1`.

## Claim ledger

| #   | Claim                                                                          | Symbol                              | Citation                              |
| --- | ------------------------------------------------------------------------------ | ----------------------------------- | ------------------------------------- |
| 1   | `ResponseShapeError` is the fail-closed error class                            | `ResponseShapeError`                | scripts/litellm_client.py:19          |
| 2   | verdict `max_tokens` defaults to 4096 via `LITELLM_MAX_TOKENS`                  | `LITELLM_MAX_TOKENS`                | scripts/litellm_client.py:76          |
| 3   | `max_tokens` is validated to 1..32768                                          | `LITELLM_MAX_TOKENS must be between` | scripts/litellm_client.py:79          |
| 4   | `response_format: json_object` is set when `json_mode`                          | `response_format`                   | scripts/litellm_client.py:88          |
| 5   | completion is read from `choices[0].message.content` only (no reasoning_content)| `["message"]["content"]`            | scripts/litellm_client.py:111         |
| 6   | list-shaped content is joined from `text` parts                                | `part.get("text"`                   | scripts/litellm_client.py:113         |
| 7   | blank content raises "empty completion"                                        | `empty completion`                  | scripts/litellm_client.py:117         |
| 8   | `normalize_json_object` accepts only fenced or exact JSON                       | `normalize_json_object`             | scripts/litellm_client.py:137         |
| 9   | `validate_verdict` enforces the strict verdict schema                          | `validate_verdict`                  | scripts/litellm_client.py:170         |
| 10  | `--verdict` sets verdict_mode; json_mode = json OR verdict                      | `json_mode=args.json_mode or`       | scripts/litellm_client.py:209         |
| 11  | `fail()` prints `::error::litellm:` and `SystemExit(1)`                         | `::error::litellm:`                 | scripts/litellm_client.py:43          |
| 12  | 3-attempt retry then `proxy request failed after 3 attempts: <ExcName>`         | `failed after 3 attempts`           | scripts/litellm_client.py:129         |
| 13  | ai-review gates the diff at 400000 bytes (refuses partial review)              | `400_000`                           | .github/workflows/ai-review.yml:565   |
| 14  | the verdict is generated by `litellm_client.py --verdict --output`             | `--verdict --output`                | .github/workflows/ai-review.yml:576   |
| 15  | on client failure the verdict step tails the log and `exit 1` (no label/comment)| `tail -n 20 .ai-review/reviewer.log` | .github/workflows/ai-review.yml:578   |
| 16  | an existing infra-error path comments "INFRASTRUCTURE error, NOT a verdict"     | `INFRASTRUCTURE error, NOT a`       | .github/workflows/ai-review.yml:429   |
| 17  | Gate-step fail-closed labels `ai:review-changes` on no-parseable-verdict         | `set_label ai:review-changes`       | .github/workflows/ai-review.yml:647   |
| 18  | `set_label` cycles only `ai:review-passed`/`ai:review-changes`                    | `for l in ai:review-passed ai:review-changes` | .github/workflows/ai-review.yml:637 |
| 19  | Gate step is `success()`-gated (`if: SKIP_REVIEW != '1'`), skipped on prior fail | `Gate · comment · label · merge`    | .github/workflows/ai-review.yml:606   |
| 20  | `ai:review-passed`/`ai:review-changes` are the two verdict-outcome state labels | `ai:review-passed`                  | install/templates/labels.json:3       |
| 21  | a PR touching `.github/**` is governance-locked (human-merge)                    | `(^\|/)\.github/`                     | .github/workflows/ai-review.yml:530   |
| 22  | verdict `--timeout` defaults to 600 (client), no `--timeout` passed by ai-review | `default=600`                       | scripts/litellm_client.py:202         |
| 23  | each attempt is capped at `timeout / 3` (~200s at default)                       | `timeout / 3`                       | scripts/litellm_client.py:104         |
| 24  | only HTTP 429/5xx are retryable; a 400 fails immediately (non-retryable)         | `429 or 500 <= exc.code`            | scripts/litellm_client.py:124         |
| 25  | `--timeout` is bounded 1..1800 (accommodates a larger verdict window)            | `1 <= args.timeout <= 1800`         | scripts/litellm_client.py:205         |
| 26  | `$OUT` is written atomically (`os.replace`) only after a validated verdict        | `os.replace`                        | scripts/litellm_client.py:221         |
| 27  | the diff-fetch infra path already has `GH_TOKEN` + posts an inline infra comment | `gh pr comment`                     | .github/workflows/ai-review.yml:509   |
| 28  | `ai:human-review-required` is a required state label kept outside the set_label cycle | `ai:human-review-required`      | install/templates/labels.json:13      |

## Review log

### Pass 1 - 2026-07-17

- Draft. Every claim opened and read in `scripts/litellm_client.py`,
  `.github/workflows/ai-review.yml`, and `install/templates/labels.json`.
  Confirmed the client is byte-identical at `ci/v2.0.0` and `main` (the reported
  bug is live on the current canon, not fixed by v2.1.0), and that
  `reasoning_content` appears nowhere in the repo.
- Scoped deliberately to 4 fixes for the 4 diagnosed mechanisms; parked
  chunking/structured-output/tiered-reviewer and rejected an author-side
  "split PRs" rule (infra bug pushed onto authors; smaller PRs stay soft
  guidance). Per the minimality rule — ~N fixes for N issues.
- Open decision D-T1 (verdict-only vs shared `max_tokens` default) recorded with
  a recommendation, not silently chosen.

### Pass 2 - 2026-07-17 - independent

Fresh-context reviewer, adversarial, against real source. All 21 claims verified
(2 one-line drifts, warnings only). **Six load-bearing/medium findings; two of
them invalidated fixes I proposed for a fail-closed security gate.** The plan is
re-scoped from 4 fixes to 2 (T1 + F4) — *smaller and safer*.

- **F1 (load-bearing) — DROP T2.** For a reasoning model, `content` is empty
  essentially only when generation truncated *mid-reasoning* — the model never
  emitted its final verdict. Mining `reasoning_content` then feeds the extractor
  the model's DRAFT/quoted `{…}` from its chain-of-thought, not its decision — on
  a fail-closed gate this can surface a draft "approve" when the completed
  reasoning was request_changes. The correct fix for empty-content is T1 (raise
  the budget so the model finishes and emits `content`), not mining CoT. **T2
  removed**; recorded as a rejected alternative.
- **F2 (load-bearing) — DROP T3.** "First-balanced-object" is a *new injection
  surface* the current strict parser does not have: if the model quotes a
  diff-planted `{"decision":"approve","findings":[]}` before its real verdict,
  the strict parser (Claim 8) fails closed, but "scan for the first `{`" extracts
  the attacker-influenced object and `validate_verdict` passes it. A reasoning
  model's real answer is *last*, not first. Loosening the parser on
  untrusted-influenced output of a gate consumed by 9 repos is the highest-risk
  change and is not required: `response_format: json_object` (Claim 4) + T1
  should yield clean JSON, which the strict parser already handles (bare or
  fenced). **T3 removed**; if prose-wrapping persists after T1, the fix is to
  enforce json_object/json_schema harder, not loosen the parser. Recorded as a
  rejected alternative.
- **F3 (load-bearing) — T1 must also raise the per-attempt timeout.** The verdict
  call passes no `--timeout` (Claim 14) → default 600 → each of 3 attempts capped
  at ~200s. ~16k tokens at ~80 tok/s ≈ 205s could exceed the window → TimeoutError,
  leaving the large-diff case still red. T1 now bumps the verdict `--timeout`
  alongside `max_tokens`.
- **F4 (load-bearing) — verify the model output cap before picking `max_tokens`.**
  16384 may exceed `deepseek-v4-pro`'s per-response cap (DeepSeek chat models
  historically 8192); if the provider returns HTTP 400 rather than clamping, the
  client treats 400 as **non-retryable** (only 429/5xx retry) → immediate fail →
  the gate goes red on *every* PR, a strict regression. T1 now (a) defaults to a
  conservative **8192** (2× today's headroom, within DeepSeek's typical cap) and
  (b) makes "confirm the target model accepts the chosen value (or LiteLLM
  clamps)" a REQUIRED pre-implementation step. The `LITELLM_MAX_TOKENS` override
  lets an operator raise it once a higher cap is confirmed, without a canon edit.
- **F5 (medium) — F4-1 is not a drop-in reuse of the Gate step's helpers.** The
  verdict step's env has only `LITELLM_*` (no `GH_TOKEN`/`GH_REPO`/`PR`), and
  `retry()`/`set_label()` are bash functions local to the Gate step's `run:`.
  F4-1 is now a **separate `if: failure()` signalling step** following the
  diff-fetch precedent (which has the token and posts an inline `gh pr comment`),
  plus the label set via the REST API.
- **F6 (medium) — F4-2 downgraded.** The Gate-step no-parseable-verdict branch
  (Claim 17) is reached only when the verdict step exited 0, and the client writes
  `$OUT` only after `validate_verdict` passes — so for the reported
  `ResponseShapeError` (verdict step exits 1, Gate skipped) it never mislabels.
  F4-2 is defensive consistency, not a live contributor; framing corrected.
- **F7 (minor) — infra-label color.** `fbca04` collides with
  `ai:human-review-required`; pick an unused color (e.g. `d4c5f9` lilac).
- **F8 (minor) — model the infra label like `ai:human-review-required`:** a
  required state label *outside* `set_label`'s mutual-exclusion cycle (Claim 18),
  not added into the delete loop.

Folded: T2/T3 removed (→ rejected-alternatives), T1 re-scoped (8192 default +
timeout bump + model-cap pre-check), F4-1 rewritten as a separate `if: failure()`
step, F4-2 downgraded, label color/handling corrected. **Result of Pass 2:
substantial re-scope — re-review required.**

### Pass 3 - 2026-07-17 - independent

Fresh-context re-review of the re-scoped plan. Confirmed the fold is real (T2/T3
gone from the fix body → rejected-alternatives; `normalize_json_object` +
`validate_verdict` untouched; claims 22-28 verified), the "iterate with F4
evidence" stance legitimate (given the parser must stay strict), 8192 correctly
gated on PC-1, and fail-closed preserved. Found two more load-bearing defects —
in F4's workflow *mechanics*, which would have made the "honest signal" dishonest:

- **F-1 (load-bearing) — a bare `if: failure()` over-fires and double-posts.** It
  runs on ANY prior step failure (asset-fetch/diff-fetch), which already comment
  (Claims 16/27) → double comment. Folded: give the verdict step an `id:` and
  guard the new step `if: always() && steps.<id>.outcome == 'failure'` so it fires
  only for the verdict-client failure. Unifying the other infra paths to also set
  the label is noted as a deferred broader refactor.
- **F-2 (load-bearing) — infra-error must be a THIRD mutually-exclusive state, not
  outside the cycle** (this corrects my Pass-2 F8). Modeling it like
  `ai:human-review-required` leaves a re-review showing `ai:review-passed` AND
  `ai:review-infra-error` at once — the dishonest signal F4 exists to remove.
  Folded: extend `set_label`'s cycle from two states to all three; setting any one
  clears the other two.
- **F-3 (medium) — the label POST 422s on a not-yet-installed consumer** (swallowed
  by `|| true`), so only the comment posts until the label is installed. Folded as
  a distribution caveat; comment is the reliable signal, pair the tag with a
  label-sync.
- **F-4 (minor) — framing:** the reported symptom is `ResponseShapeError`
  (truncation), not `TimeoutError`; `--timeout` is precautionary headroom. Folded.
- **F-5 (minor) — Exit overclaimed** (PC-1/PC-2 verify accept + finish-in-time,
  not that 8192 is *sufficient* output length). Softened to "valid verdict OR
  legible via F4".

All folded. F-1/F-2 were mechanical defects with the reviewer's exact
prescriptions applied (step-id scoping; three-way label cycle) — not new design.

**Result: ready.** Pass 1 (self) → Pass 2 (independent, re-scoped 4→2 fixes on
security grounds) → Pass 3 (independent, F4-mechanics nailed down). The security
re-scope is confirmed correct, the dropped fixes stay dropped, no path that
exited 1 now exits 0, and the remaining folds are the reviewer's own
prescriptions. Per OPS-0066 (cap 3 cycles) this is the 3rd cycle; the plan is
implementation-ready with the pre-checks PC-1/PC-2 gating the two live numbers.
