# PLAN-021 — doc-maintainer: make the dry-run path executable

**Status:** **NOT READY — stopped at the OPS-0066 review cap.** Three independent
passes returned 10, 9 and 6 load-bearing findings; all 25 are folded, but the
third pass's fold is **itself unreviewed** and the cap forbids a fourth pass.
One founder item remains open (§9 item 2); 353b is **decided — approved**. Do
**not** begin implementing while this line reads NOT READY.
**Issues:** [#352](https://github.com/vladm3105/aidoc-flow-ci/issues/352),
[#353](https://github.com/vladm3105/aidoc-flow-ci/issues/353),
[#354](https://github.com/vladm3105/aidoc-flow-ci/issues/354),
**+1 to file** (planner inventory ignores `allowed_paths` — see §4 PR-D)
**Semver:** MINOR → `ci/v2.17.0`
**Decision record:** `CI-0027` (new) · **Canon:** `REPO_STANDARDS` §24 (new)

> **Gate invocation** (root order is load-bearing — both consumer repos have a
> `.github/doc-maintainer.json`, and the first root wins):
>
> ```sh
> python3 ~/.claude/skills/verified-planning/check_plan.py \
>   plans/PLAN-021_doc-maintainer-dry-run-cluster.md \
>   --root /opt/data/aidoc-flow/framework \
>   --root /opt/data/aidoc-flow/operations
> ```

---

## 1. TL;DR

`doc-maintainer`'s **dry-run** path cannot complete a run that has anything to
say. Four defects converge on it, each verified against source at `ci/v2.16.0`:

| Issue | Defect | Effect |
|---|---|---|
| **#352** | Step 9 renders the patch with `diff`, which exits 1 when files differ. GitHub's default shell carries `-e`, so the step dies *at* the `diff` — before the `rc=$?` written to tolerate it. | No plan containing a low-risk edit can complete a dry run |
| **#353** | The planner's validation loop tests `path in seen or not matches(path, allowed)` and `fail()`s on either, aborting the run. `validation.rejected` is declared and never written. | A duplicate reports as an allowlist violation, naming a path that *is* allowlisted |
| **#354** | `apply.py` refuses files over 200 KB; the install template ships `CHANGELOG.md` as a low-risk path. Changelogs only grow. | Guaranteed red whenever the model picks the changelog |
| **PR-D** (to file) | Two coupled defects: the inventory globs **every** `*.md` with no allowlist filter (contradicting IPLAN-0025 §2.1 step 4), **and** the prompt never actually forbids proposing outside `allowed_paths` — its only prohibition is by file *type*. | The model is shown a menu and a changed-file list that both contradict an allowlist it is never instructed to obey — the 6 non-allowlisted rejections |

**Consumer state — the pilot is PAUSED.** `aidoc-flow-framework` (the only
`dry_run: true` consumer) set `kill_switch: true` on 2026-07-30. Precisely: the
switch is a **`maintain`-job property only**, checked at one place in the
reusable. Push runs still execute Steps 1-2 and exit 0; the `reconcile` job is
gated `github.event_name == 'schedule'` and reads **no config at all**, so
framework's `cron: '7,37 * * * *'` keeps it dispatching ~48×/day. The accurate
claim is **no LLM cost, no proposals, no failures** — not "no runs".

The consumer's recorded census, over its first 47 runs — **23 failures**, 12 of
13 `push` runs:

| Failures | Cause | Fixed by |
|---:|---|---|
| **9** | planner rejects a **repeated** `plans/HANDOFF.md`; the path **is** allowlisted | PR-B (353b) |
| **6** | planner rejects a genuinely non-allowlisted path (`plans/PIN-CURRENCY-READER-PLAN.md` ×3, `CLAUDE.md` ×2, the conventions file ×1) | **PR-D, and only its prompt half** — see the warning below |
| **3** | apply refuses `CHANGELOG.md` at 200 KB | PR-C — but on `framework` these **migrate into the row above**, they do not disappear |
| **3** | Step 9 dies silently rendering the dry-run patch | PR-A |
| **2** | apply's 30 %-deletion guard on `README.md` | **not fixed — see §3** |

> ⚠️ **Two corrections to how this table must be read.**
>
> **(a) These are run counts, not defect instances.** `reconcile.py` treats a
> completed run with `conclusion != "success"` as *un-maintained* and
> re-dispatches the SHA; its 90-minute lookback against a 30-minute cron means
> each failing push run is re-dispatched up to ~3 times. That is how 13 push runs
> became 47. **The 23 failures are roughly 6 distinct merges, retry-multiplied by
> an unknown per-bucket factor** — so the bucket *ranking* is not established.
> **Re-derive the census by distinct merge SHA before putting 353b to the
> founder** (§3 currently recommends it on "9 of 23", which is a run count). It
> also means every residual failure costs ~3 extra planner+apply LLM invocations.
>
> **(b) `CHANGELOG.md` is the most likely first red after resume, and no PR here
> closes it.** `framework` has already removed it from `allowed_paths`, so its 3
> apply-200 KB failures cannot recur as #354 — they recur as **non-allowlisted
> rejections**, because nothing stops the model proposing it: framework's
> `CHANGELOG.md` is in the inventory *and* in the changed-file list of nearly
> every merge, since this workspace requires a changelog entry per PR. Only the
> prompt imperative in PR-D closes this.

**#352 is among the smallest buckets by count and is still the graduation
blocker**, because its loop reads `.low_risk_set[]` — so no plan containing a
low-risk edit can complete a dry run, which is exactly what the P4 gate
exercises. (A plan of *only* high-risk edits does survive Step 9 and post a real
proposal; that is why the pilot is not merely "always red" but exercises the
wrong path.) "What blocks the goal" and "what fails most often" are different
defects here; both are in scope.

**Nothing here is observable until `kill_switch` is flipped back in the
*framework* repo** — a cross-repo action this plan does not own. See §6.

`aidoc-flow-operations` runs `dry_run: false`, is not paused, and is unaffected
by #352 — but is on the same trajectory for #354 as its changelog grows, in
**live** mode.

**Why #352 in particular survived every release since `ci/v0.0.1-ruletest`.**
Canon ships `doc-maintainer.yml` as a reusable and has **no self-caller**;
`EXERCISER_INVENTORY` records the workflow as `descoped (library; needs LiteLLM +
App)`, so the sole coverage of the *workflow body* is the resolver. **This
explains #352 only.** #353, #354 and PR-D live in `planner.py` / `apply.py`,
which **do** have an offline exerciser — it copies both scripts into one
directory, drives the real planner and apply as subprocesses, and already asserts
two apply guards. What was missing there is not coverage but **fixtures**: a
duplicate path, an over-limit path, and a non-allowlisted path. Two different
root causes, and §5 addresses them differently.

---

## 2. What is already correct (do not "fix" these)

- **The live branch is sound.** Step 10's `git diff --cached --quiet && { … }`
  puts the tolerated non-zero in the exempt position of an `&&` list, so `-e`
  does not fire. Step 9 is gated `dry_run == 'true'`, so `operations` does not
  hit #352.
- **The correct `set +e` idiom already exists in this file, twice** — the two
  pin-resolution steps. **Note carefully:** those steps open with
  `set -euo pipefail`, *not* `set -uo pipefail`. See §4 PR-A.
- **The 200 KB guard itself is right** and stays. The defect is that nothing
  stops such a path being *planned*.
- **The allowlist is not leaking.** `matches()` / `clean_path()` are correct and
  no non-allowlisted path reaches apply. #353 is a reporting and blast-radius
  defect, not a containment failure.
- **`apply.py`'s 400-line and 30 %-deletion ceilings are correct as guards** and
  are not being weakened. Their *blast radius* is a separate question — §3.
- **Rejections are distinguishable from infrastructure faults in the two
  pin-resolve/fetch steps**, which carry the literal suffix `INFRASTRUCTURE
  error, not a maintenance result` (13 occurrences). **This is not a universal
  property of the workflow** — the LiteLLM-config, planner and apply failure
  paths carry no such suffix. Anything that counts P4(e) infrastructure errors by
  grepping that string will undercount.

---

## 3. The decision boundary — narrower than it first appears

Issue #353's suggested fix (record and continue) looks like it collides with
IPLAN-0025 **D12** ("failure modes are LOUD, never silent", naming
*plan-validation rejection*). Reading D12 in context narrows it:

- **D12's only *defined* instance is the out-of-allowlist case.** Risk 1 and
  §2.1 step 6 both specify exactly that: reject the whole plan if any entry is
  out of `allowed_paths`, fail loud with `::error::`. A **duplicate** path
  appears nowhere in IPLAN-0025 (its only "duplicate" is duplicate *runs*, Risk
  4). Dropping a duplicate and continuing is most likely not an amendment to D12
  at all — it is a case D12 never contemplated.
- **353a is what makes P4(d) measurable**, not 353b. P4(d) requires "zero
  allowlist-violation rejections", a count; once the message names one
  condition, that count is readable. An earlier draft claimed the opposite.

| | Change | Decision needed? |
|---|---|---|
| **353a** | De-conflate: two branches, two messages. Both still `fail()`. | **No.** Preserves D12; makes P4(d) countable. |
| **353b** | A **duplicate** is recorded to `validation.rejected` with a `::warning::` and the run continues. A **non-allowlisted** path still fails. | **Founder confirmation**, not escalation — the D12 conflict is likely absent. |

**Recommendation: take both.** 353b converts the largest single bucket — 9 of 23,
all the same duplicated `plans/HANDOFF.md` — from a run-killer into a warning,
without touching the safety boundary.

**353b must be `record-then-fail`, not `record-and-skip`.** A naive
implementation writes
`allowlist_violations = [r for r in rejected if r["reason"] == "not-allowlisted"]`
at plan construction — a field that **can never be non-empty**, because a
non-allowlisted path still calls `fail()`, which raises `SystemExit(1)` *before*
the plan is written. That would ship a second declared-never-populated field, the
exact defect #353 is about. Instead: **write the plan artifact, then exit
non-zero**, collecting **all** violations and failing once at the end — a
fail-at-first-violation loop makes the artifact's contents depend on where in
`updates` the first violation happens to fall, which is not a count.

**Do not justify this by artifact countability — that rationale is false.** The
plan JSON is never uploaded (the only `upload-artifact` takes the *patch*), and
`Cleanup` is `if: always()` and `rm -rf`s it; every downstream step carries an
implicit `success()`, so nothing reads it after the failure. The field would be
written to a file deleted seconds later on the runner. **353a's de-conflated
`::error::` line is what makes P4(d) countable**, as stated above.
`record-then-fail` is worth doing for a narrower reason — it stops the schema
declaring a field it never populates. If artifact countability is genuinely
wanted, that is a **fifth change** (an `if: always()` upload of the plan JSON),
not a free consequence. Note also that the no-PR
early-exit write site emits `{"rejected": []}` with no `allowlist_violations` and
no `patch_bytes`, so any consumer of `validation.*` must tolerate two shapes;
say so in the schema comment rather than silently widening it.

**What remains red after all four PRs — 2 of 23, and it is not zero.** The two
30 %-deletion trips stay. The guard is correct, but it **reds the whole run
instead of dropping the entry** — structurally the same blast-radius defect as
353b, on a different guard. Ruling it "the guard working, not in scope" while
taking 353b is inconsistent, and the consumer's own resume note says the
30 %-deletion class "should be understood by then too". **Treatment: do not
change the guard in this plan**; state the residual honestly in `CI-0027` and
file the blast-radius question as its own issue. Do not let §1's resume condition
be read as "this plan makes the pilot green".

**If the founder declines 353b:** 353a still ships and the message stops lying,
but 9 of 23 failures remain, framework's resume condition ("RESUME REQUIRES #352
**AND** #353") is not met, and the pilot stays paused. Record that in `CI-0027`
rather than discovering it at resume time.

---

## 4. PR sequence

Five PRs, one defect each. PR-C's half 2 depends on PR-B's plumbing; PR-D is
independent but should land with the others so the resume is a single event.

### PR-0 — `DECISIONS.md` CI-0027

The cluster, the D12 reading, the 353b confirmation, the standing 30 %-deletion
residual, and the PR-D spec deviation. Lands first so the others can cite it.
One doc surface.

### PR-A — #352: scope `-e` off around the tolerated `diff`

**Change.** Wrap the `diff` in the idiom the file already uses:

```yaml
          while IFS= read -r path; do
            set +e
            diff -u --label "a/$path" --label "b/$path" "$path" ".doc-maintainer-proposed/${path}.proposed" >> "$PATCH"
            rc=$?
            set -e
            [ "$rc" -le 1 ] || { echo "::error::could not render dry-run patch for $path"; exit "$rc"; }
          done < <(jq -r '.low_risk_set[].path' .doc-maintainer-plan.json)
```

**Also fix Step 9's PR resolution — and the guard there is dead code today.**
Measured, not inferred: `gh api … --jq '.[0].number'` on an empty array emits
jq's `null`, which `gh` prints as the **literal string `null`** — not empty. So
`[ -z "$PR" ]` never fires, the designed "no PR found" early exit is
**unreachable**, and the real no-PR failure is `gh pr comment null` at the end of
the step. Verify with `echo '[]' | jq -r '.[0].number'` before writing anything.

That changes the fix in three ways:

1. **The guard must test both forms** — `[ -z "$PR" ] || [ "$PR" = null ]`.
2. **It must distinguish two cases that need opposite handling.** A legitimately
   PR-less SHA (direct push, reconciler-dispatched non-PR SHA) must exit **0**
   with a notice; a transient `gh api` fault must exit **1**. The step currently
   swallows the fault with `2>/dev/null || echo ""` and cannot tell them apart.
   `low_count != 0` **does** prove a PR exists (the planner returns early with
   `pr_number: None` and an empty `low_risk_set` otherwise) — but **Step 9's
   `if:` carries no `low_count` term**, so it also runs on the legitimate no-PR
   path. A bare `exit 1` mirroring Step 10 would red every PR-less main SHA.
3. **Better: read the value the planner already recorded** —
   `PR=$(jq -r '.pr_number' .doc-maintainer-plan.json)`, exactly as Step 11 does.
   That removes the redundant second API call, and with it the fault case
   entirely.

**Do NOT "fix" the artifact race by creating `$PATCH` earlier.** The upload step
carries `if-no-files-found: error` and cannot see that Step 9 bailed, so moving
`$PATCH` above the early exit converts a misnamed red into a **silent green** —
notice, `exit 0`, empty artifact, no comment posted. That is precisely the silent
miss D12 exists to prevent. Once (3) lands, the inconsistency closes on its own.

**Sweep the mental model.** Two comments assert `set -uo pipefail` means
*"(no -e)"*. Correct both — **and state the reason correctly**: `-e` is inherited
from GitHub's default shell (`bash --noprofile --norc -e -o pipefail {0}`), and
the explicit `|| { echo "::error::…"; exit 1; }` gate exists because under bare
`-e` the step fails **without emitting the `::error::` annotation**, which is the
substance of D12. It is *not* "deliberate redundancy" — an earlier draft said so,
and shipping that wording would have invited the gate's deletion.

**Audit obligation — enumeration verified.** Six steps open with
`set -uo pipefail`. **None uses `set +e`**; both `set +e` blocks live inside steps
opening `set -euo pipefail`. Of the six, Step 9's `diff` is the only
non-zero-tolerating command outside a tested context — the other five are
`||`-guarded (three `python3 … || {…}`, one `$(gh … || echo "0")`, one
`jq empty … || {…}`). Put that in the PR body as evidence.

**Doc surfaces:** `REPO_STANDARDS` §24.1 · `CHANGELOG.md` ·
`docs/EXERCISER_INVENTORY.md`.

### PR-B — #353: de-conflate, then record duplicates

**353a — unconditional.** Split the single `if` into two branches with two
messages.

**353b — on founder confirmation.** Duplicate → append
`{"path": …, "reason": "duplicate"}` to `rejected`, emit `::warning::`,
`continue`. Non-allowlisted → append with `reason: "not-allowlisted"`, then
**write the plan and exit non-zero** (see §3). An empty survivor set is an empty
plan, which the flow already handles.

**Do not widen this.** `max_edits_per_pr` and the not-low-risk-means-high-risk
classification are correct and out of scope.

**Doc surfaces:** `REPO_STANDARDS` §24.2 · `CHANGELOG.md` · the issue close comment.

### PR-C — #354: stop planning what apply will refuse

1. **Template default.** Drop `CHANGELOG.md` from `allowed_paths` and
   `auto_merge.low_risk_paths` in the install template.
2. **Planner pre-filter, tier-scoped.** Drop over-limit paths before dispatching,
   recording them in `validation.rejected` (depends on PR-B). **Measure with the
   same yardstick as the guard** — `len(read_text().encode())`, never
   `stat().st_size`; they differ on CRLF files and a mismatch produces a silent
   false drop.

**The pre-filter must run AFTER classification, against the low-risk set only.**
The 200 KB refusal is reachable only from `apply.py`, and the workflow invokes
apply **only** with `--tier low_risk`. High-risk entries never touch apply — they
go to Step 11's issue body or the dry-run comment. An unscoped filter would
silently delete over-limit **high-risk** proposals that work correctly today.

**Why half 1 is not sufficient — and the consumer guidance is not what it looks
like.** `.github/doc-maintainer.json` is `safe_to_replace: false`, so `--update`
never rewrites a consumer's config; half 1 reaches **new adopters only**. Measured
state of the two consumers (2026-07-30):

- **`framework` has already dropped `CHANGELOG.md` by hand**, citing #354. Half 1
  is a no-op for it.
- **`operations` still carries it and runs live** — but its `allowed_paths` ends
  with the catch-all **`"*.md"`**, and `matches()` uses `fnmatch.fnmatchcase`,
  which translates `*` to `.*` with no path-separator exception. **So removing
  `CHANGELOG.md` from `allowed_paths` there changes nothing** — the catch-all
  re-admits it. The knob that actually protects `operations` is
  `auto_merge.low_risk_paths`: removing it there makes it high-risk, and
  high-risk never reaches apply — in **both** modes, since Step 8's `if:` has no
  `dry_run` term. **That is the correction that belongs in the release notes**,
  not "drop it from `allowed_paths`".

  **State its cost, or the consumer will read it as free.** (a) operations'
  changelog is ~90 KB — well under the 200 KB trigger the plan gives as the
  reason — so its near-term hazard is not the size refusal but **truncation on
  whole-file regeneration tripping the 30 %-deletion guard**, which §7 puts out
  of scope. (b) The demotion **retires changelog auto-maintenance on the live
  consumer**, which is that flow's primary op and the one `docs-sync` is slated
  to be deleted for. Both belong in the release note.

**Constant ownership.** `200_000` is an inline literal and PR-C must **name it
first**. Both scripts are fetched into one directory by the workflow's
`for op in planner apply reconcile` loop, `apply.py` has no import-time side
effects (module level is imports plus four function defs, entrypoint guarded),
and the offline harness copies both into one directory too — so `planner.py` can
import the constant as it already imports from `litellm_client`. Fallback if
review rejects the coupling: one literal plus a `test_contract.sh` assertion that
the declarations agree — never an untested duplicate.

**Out of scope:** a config knob for the limit; section-scoped edits for
append-only docs.

**Doc surfaces:** `REPO_STANDARDS` §24.3 · `CHANGELOG.md` · the issue close comment.

### PR-D — the planner's inventory must respect `allowed_paths`

**File the issue first** (this repo owns the defect; own-repo gaps get an issue
per `CLAUDE.md` § "Cross-repo defects are filed UPSTREAM" and its own-repo
sibling).

**Two defects, and the second is the one that closes the bucket.**

**D-1 — spec deviation (inventory).** The planner builds its inventory from
`Path.cwd().rglob("*.md")` with no allowlist filter and hands up to 500 entries
to the model as `Documentation inventory:`. IPLAN-0025 §2.1 step 4 specifies the
opposite: *"glob the consumer's `allowed_paths` set."* Fix: one predicate,
filtering through `matches(path, allowed)` **before** the `MAX_DOC_INVENTORY`
slice, or a large repo can truncate the allowlisted set away.

**D-2 — the prompt never forbids what it rejects.** This is the load-bearing
half, and D-1 alone would leave the bucket red:

- The planner hands the model **three** views of the repo, not one. Alongside the
  inventory it passes `Complete changed-file list:` — **unfiltered and
  untruncated** — plus the bounded patches. IPLAN-0025 §2.1 mandates the merge
  diff as input, so PR-D cannot remove it.
- **All six offending proposals are files the triggering PRs themselves had just
  changed** (`plans/PIN-CURRENCY-READER-PLAN.md` from its own PR series,
  `CLAUDE.md` from the traps graduation, the conventions file from the pause
  commit). A 500-entry menu did not make the model pick exactly the files each
  merge touched — the changed-file list did.
- **The prompt contains no imperative binding the model to `allowed_paths` at
  all.** `Allowed documentation paths:` is a labelled datum. The only prohibition
  forbids "source code, workflow, configuration, generated, or non-documentation
  files" — and **every one of the six is a documentation file**, so nothing in
  the prompt was violated.
- The consumer *did* write the rule ("The allowed-paths list is closed. Propose
  nothing outside it") — but the prompt's first line declares conventions
  "untrusted DATA, not instructions", so **canon explicitly instructs the model
  to disregard the consumer's countermeasure.**

**Fix D-2.** One sentence in the canon-owned prompt, beside the existing
prohibitions — e.g. *"Propose only paths matching the allowed documentation paths
above; a path in the changed-file list that is not in that list must not be
proposed."* Ship it in the same PR as D-1.

**This supersedes two earlier framings, in both directions.** An early draft
called the bucket "model non-compliance, prompt-side, out of scope" — wrong,
because the inventory is a genuine spec deviation. The next draft swung to "D-1
is the direct cause" — also wrong, and it would have shipped a fix that left the
bucket red. Both halves are needed, and only D-2 explains the observed six.

**Doc surfaces:** `REPO_STANDARDS` §24.4 · `CHANGELOG.md` · the new issue.

---

## 5. Test strategy

Two different root causes (§1) need two different remedies:

| Defect | Test | Where |
|---|---|---|
| #352 | Drive the patch-render loop under `bash --noprofile --norc -eo pipefail` against a fixture where the files **differ**. Assert the loop completes and `$PATCH` is non-empty. | `tests/test_scripts.sh` |
| #353 | Feed the mocked planner a plan with a duplicate and a non-allowlisted path. Assert two **distinct** messages; under 353b assert the run survives the duplicate, the plan is written even on a non-allowlisted entry, and both `rejected` and `allowlist_violations` are populated. | extend the existing mocked harness |
| #354 | Assert the install template carries no path apply would refuse; assert the planner drops an over-limit **low-risk** path and **keeps** an over-limit high-risk one. | `tests/test_contract.sh` + the harness |
| PR-D | Assert a non-allowlisted `*.md` present on disk does **not** appear in the prompt's inventory. | the harness |

**Extraction has a trap — extract the loop, not the step.** Step 9's `run:` body
contains five `${{ }}` expressions; fed to bash verbatim they are a syntax error,
so the harness would die before reaching the `diff` — going red for the wrong
reason, or being "repaired" by re-implementing the loop, which must not happen.
**Extract the expression-free `while … done` loop** (verified expression-free;
seven lines after PR-A's fix, five before). **Use the repo's existing marker
convention** (`# >>> NAME >>>` / `# <<< NAME <<<`, driven by `test_resolver.sh`) —
PR-A must add the markers to Step 9, or the extraction is line-range-fragile and
silently breaks on the next edit above it. The harness must define `$PATCH`
itself and apply `set -u` itself — both live *outside* the extracted range.
GitHub's default shell is `bash --noprofile --norc -e -o pipefail {0}`, so
`-eo pipefail` reproduces it.

**Extract-and-drive, never re-implement** — how FT-40's SHA-peel guard passed
while untested.

**Mutation obligation.** Each test must fail when its fix is reverted; record the
mutation and its observed failure in the PR body. #352's is the one to distrust:
reverting to `set -uo pipefail` alone must make it red, or the harness is not
reproducing GitHub's shell.

**Inventory — the guard will not catch this for you.**
`EXERCISER_INVENTORY`'s `doc-maintainer.yml` row reads `descoped … +
offline-test`; PR-A must update it. `test_exerciser_inventory.sh` enforces its
FT-naming rule **only on rows containing the literal `unexercised`**, so a stale
exerciser column passes green. This is an authoring obligation, not a gated one.

---

## 6. Release and resume impact

**PR-C trips the 🔴 FT-30 cold-start gate; PR-0, PR-A, PR-B and PR-D do not.**
Manifest-derived, verified:

- `coldstart_surface` walks **every** manifest `template` (no `auto_install`
  filter) plus `visibility_variants`, plus five explicit installer files.
- `install/templates/doc-maintainer.json` **is** a manifest template → PR-C's
  half 1 puts it in the diff → `release.sh tag` refuses without
  `--dry-run-verified`.
- The **reusable** `.github/workflows/doc-maintainer.yml` and
  `scripts/doc-maintainer/*.py` are **not** on the surface — the manifest ships
  the *caller* template `workflows/doc-maintainer.yml`, a different file that no
  PR here touches.
- `coldstart_material_changes` normalises the release's own `@ci/vX.Y.Z` pin bump
  away, so the gate does not fire on the prep commit.

**Sequencing:** a cut after PR-0 + PR-A + PR-B + PR-D needs no founder step. Once
PR-C lands, the founder-executed `scripts/ft30-dry-run.sh` is owed before
`ci/v2.17.0` can be tagged. Decide deliberately; do not discover it at tag time.

**Resume is a cross-repo action this plan does not own.** Framework pins the
**tag** form `@ci/v2.16.0`, so GitHub executes the reusable at that tag *and*
`FETCH_REF` resolves to it — meaning **both** the workflow-body fix and the
script fixes require the re-pin. Sequence: PRs merge → tag `ci/v2.17.0` →
framework re-pins → framework sets `kill_switch: false`. The consumer's own
conventions state the identical sequence. Record the handoff so the switch is not
left off indefinitely.

**Consumer action:** a re-pin, plus one manual edit for `operations` — and the
edit is to **`auto_merge.low_risk_paths`**, not `allowed_paths` (§4 PR-C). No
`workflow_call` input or secret changes.

**Semver.** MINOR because PR-C's pre-filter and PR-D's inventory filter are
additive behaviour and the template default changes; the absence of input/secret
changes is what rules out MAJOR, which is a separate test from MINOR-vs-PATCH.

---

## 7. Out of scope

- **The 30 %-deletion guard's blast radius** (§3) — it reds a whole run instead
  of dropping the entry. Same class as 353b; file separately, do not weaken the
  guard.
- **Opening a tracking issue on plan-validation rejection.** D12 requires
  `::error::` **and** a tracking issue; the implementation does the first only.
- Config-knob for the apply size limit; section-scoped edits for append-only docs.
- The other five open canon issues (#347, #348, #349, #350, #351). **#350 is more
  urgent than this cluster in wall-clock terms** — it has framework's required
  `ai-review` gate red — but it is unrelated and needs a founder key re-provision.
- Giving canon a `doc-maintainer` self-caller — needs a self-hosted pool +
  LiteLLM secrets + the App. A PLAN-009-shaped item.

---

## 8. Canon rule and decision record

**`REPO_STANDARDS` §24 (new), four sub-rules — one per PR**, so no PR exceeds the
governance cap:

- **§24.1** — *A step that tolerates a non-zero exit must scope `-e` off around
  it.* `set -uo pipefail` does **not** clear the `-e` GitHub's default shell
  already applied; only `set +e` does, or a tested context. A comment asserting
  otherwise is a defect in its own right.
- **§24.2** — *An error message names one condition.* De-conflate at the branch,
  not in the message text.
- **§24.3** — *A default a canon template recommends must be executable by the
  code that consumes it*, and a guard's pre-filter must be scoped to the tier
  that reaches the guard.
- **§24.4** — *What canon shows a model must agree with what canon will accept
  from it.* An inventory wider than the allowlist manufactures rejections and
  charges them to the model.

**`DECISIONS.md` CI-0027** (PR-0) records the cluster, the D12 reading, the 353b
confirmation, the PR-D spec deviation, and the standing 30 %-deletion residual.

---

## 9. Open items for the founder — implementation must not start until these close

1. ~~**353b (record duplicates instead of aborting).**~~ **DECIDED 2026-07-30 —
   founder approved the recommendation: take both 353a and 353b.** The residual
   caveat still stands and is *not* a blocker: §1's warning (a) shows the
   "9 of 23" figure is retry-weighted, so **re-derive the census by distinct
   merge SHA before quoting bucket sizes anywhere else** (release notes,
   `CI-0027`, the issue close comments). The decision does not depend on it; the
   published numbers do.
2. **PR-C's cost on the live consumer.** Demoting `CHANGELOG.md` to high-risk on
   `operations` retires changelog auto-maintenance there — that flow's primary op.
   Confirm that is acceptable, or scope an alternative.

**Two measurements owed before the first line of code**, both cheap and both
capable of changing the diff:

- `echo '[]' | jq -r '.[0].number'` — confirms Step 9's `[ -z "$PR" ]` is dead
  code (it prints the literal `null`). PR-A's guard depends on it.
- Re-derive the census by **distinct merge SHA** rather than run count.

---

## 10. Review status — stopped at the cap

Three independent passes returned **10, 9 and 6** load-bearing findings. All 25
are folded. **The third pass's fold is itself unreviewed**, and OPS-0066 caps the
cycle at three independent passes, so no fourth was dispatched.

The trend is the useful signal: each pass found fewer, and the third pass's own
verdict was that its findings are *"bounded and do not warrant a fourth review
cycle"* — but three of them changed the shipping diff, so the plan cannot be
called ready on that basis alone. **A fourth pass should be run by a fresh
session after the founder answers §9**, scoped to the Pass-4 fold only (§1
warnings, §3's countability correction, §4 PR-A's `null` guard, §4 PR-D's D-2).

---

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | Step 9 sets `-uo pipefail` only, so `-e` from GitHub's default shell survives | `set -uo pipefail` | .github/workflows/doc-maintainer.yml:407 |
| 2 | The `diff` whose non-zero exit is the normal case | `diff -u --label "a/$path"` | .github/workflows/doc-maintainer.yml:420 |
| 3 | The `rc` capture that `-e` prevents being reached | `rc=$?` | .github/workflows/doc-maintainer.yml:421 |
| 4 | The tolerance guard, unreachable as written | `could not render dry-run patch for` | .github/workflows/doc-maintainer.yml:422 |
| 5 | No `shell:` or `defaults:` override anywhere in the workflow, so the default `-e` shell applies | `doc-maintainer` | .github/workflows/doc-maintainer.yml:1 |
| 6 | A correct `set +e` block — inside a step opening `set -euo pipefail` (:135), NOT one of the six `set -uo` steps | `set +e` | .github/workflows/doc-maintainer.yml:142 |
| 7 | Second correct `set +e` block, likewise inside a `set -euo pipefail` step (:233) | `grc=$?` | .github/workflows/doc-maintainer.yml:246 |
| 8 | A comment asserting `set -uo pipefail` means "no -e" — the wrong model that produced #352 | `set -uo pipefail` (no -e) would otherwise swallow the planner | .github/workflows/doc-maintainer.yml:370 |
| 9 | The same wrong assertion, second occurrence | `not be swallowed by` | .github/workflows/doc-maintainer.yml:395 |
| 10 | The `\|\|` gate exists to emit the `::error::` D12 requires — bare `-e` fails the step without it | `failing LOUD per IPLAN-0025 D12 / Risk 12` | .github/workflows/doc-maintainer.yml:382 |
| 11 | Step 9's early exit precedes `$PATCH` creation | `dry-run: no PR found for merge` | .github/workflows/doc-maintainer.yml:410 |
| 12 | ...and Step 9 swallows the API fault that would cause it | `--jq '.[0].number' 2>/dev/null` | .github/workflows/doc-maintainer.yml:408 |
| 13 | `$PATCH` is assigned after that early exit and outside the extractable loop | `PATCH=.doc-maintainer-proposed.patch` | .github/workflows/doc-maintainer.yml:417 |
| 14 | The upload step hard-errors on a missing file and cannot see that Step 9 bailed | `if-no-files-found: error` | .github/workflows/doc-maintainer.yml:454 |
| 15 | Step 9's `run:` body contains `${{ }}` expressions, so verbatim extraction is a bash syntax error | `RUN_URL="${{ github.server_url }}` | .github/workflows/doc-maintainer.yml:413 |
| 16 | Step 10 already carries the correct empty-PR guard for PR-A to mirror | `cannot resolve source PR for` | .github/workflows/doc-maintainer.yml:477 |
| 17 | The live branch uses a tested context and is unaffected | `git diff --cached --quiet` | .github/workflows/doc-maintainer.yml:501 |
| 18 | High-risk entries never reach apply — they go to the issue body | `high_risk_set` | .github/workflows/doc-maintainer.yml:517 |
| 19 | apply is invoked ONLY with `--tier low_risk`, which is why the pre-filter must be tier-scoped | `--tier low_risk` | .github/workflows/doc-maintainer.yml:398 |
| 20 | The workflow fetches planner and apply into one directory, so a shared import resolves | `for op in planner apply reconcile; do` | .github/workflows/doc-maintainer.yml:280 |
| 21 | The kill switch is a `maintain`-job property, checked in exactly one place | `KILL=$(jq -r '.kill_switch // false' "$CONFIG_PATH")` | .github/workflows/doc-maintainer.yml:340 |
| 22 | The reconcile job is schedule-gated and reads no config, so the kill switch does not stop it | `if: ${{ github.event_name == 'schedule' }}` | .github/workflows/doc-maintainer.yml:111 |
| 23 | Infrastructure errors carry a literal suffix in the pin-resolve/fetch steps — not workflow-wide | `INFRASTRUCTURE error, not a maintenance result` | .github/workflows/doc-maintainer.yml:180 |
| 24 | Planner's validation tests two conditions in one `if` | `if path in seen or not matches(path, allowed):` | scripts/doc-maintainer/planner.py:187 |
| 25 | ...and reports them with one message, aborting the run | `duplicate or non-allowlisted plan path:` | scripts/doc-maintainer/planner.py:188 |
| 26 | `validation.rejected` / `allowlist_violations` are declared at plan construction — reached only after every `fail()` is past | `"allowlist_violations": []` | scripts/doc-maintainer/planner.py:202 |
| 27 | The no-PR early exit writes a DIFFERENT validation shape, so consumers must tolerate both | `"pr_number": None` | scripts/doc-maintainer/planner.py:130 |
| 28 | `fail()` raises `SystemExit(1)` — which is why `allowlist_violations` can never be populated without record-then-fail | `raise SystemExit(1)` | scripts/doc-maintainer/planner.py:22 |
| 29 | Classification runs after validation, so a tier-scoped pre-filter must follow it | `if matches(path, high_patterns) or not matches(path, low_patterns):` | scripts/doc-maintainer/planner.py:197 |
| 30 | **PR-D:** the inventory globs every `*.md` with no allowlist filter | `for path in Path.cwd().rglob("*.md")` | scripts/doc-maintainer/planner.py:151 |
| 31 | ...is truncated to 500 entries, so the filter must precede the slice | `MAX_DOC_INVENTORY` | scripts/doc-maintainer/planner.py:16 |
| 32 | ...and is handed to the model as a candidate menu alongside the allowlist | `Documentation inventory:` | scripts/doc-maintainer/planner.py:167 |
| 33 | The allowlist IS also given to the model — so the two contradict each other | `Allowed documentation paths:` | scripts/doc-maintainer/planner.py:166 |
| 34 | `matches()` uses `fnmatchcase`, so a `*.md` catch-all matches any path — the reason operations' `allowed_paths` edit is a no-op | `fnmatch.fnmatchcase(path, pattern)` | scripts/doc-maintainer/planner.py:64 |
| 35 | apply.py refuses any source file over 200 KB, as an inline literal PR-C must name | `if len(original.encode()) > 200_000:` | scripts/doc-maintainer/apply.py:59 |
| 36 | ...with a message naming the file, not the config that nominated it | `refusing autonomous full-file generation over 200 KB` | scripts/doc-maintainer/apply.py:60 |
| 37 | apply.py is import-safe, so planner.py may import a constant from it | `if __name__ == "__main__":` | scripts/doc-maintainer/apply.py:104 |
| 38 | The 30 %-deletion guard whose blast radius is the standing residual | `agent deleted/replaced more than 30% of` | scripts/doc-maintainer/apply.py:96 |
| 39 | apply.py demands a complete replacement file — the wrong shape for an append-only doc | `Return the COMPLETE replacement file` | scripts/doc-maintainer/apply.py:66 |
| 40 | The install template ships `CHANGELOG.md` as allowed | `"allowed_paths"` | install/templates/doc-maintainer.json:6 |
| 41 | ...and as low-risk, i.e. auto-mergeable | `"low_risk_paths"` | install/templates/doc-maintainer.json:10 |
| 42 | Canon's own changelog is 363 KB — 1.8x the apply limit | `# Changelog — aidoc-flow-ci` | CHANGELOG.md:1 |
| 43 | The manifest entry for the consumer config; its `safe_to_replace` is `false` (:72), so `--update` never rewrites it | `".github/doc-maintainer.json"` | install/templates/manifest.json:69 |
| 44 | The cold-start surface walks every manifest template with no `auto_install` filter | `out.add(t)` | scripts/release.sh:112 |
| 45 | ...plus five explicitly named installer files, which do not include `scripts/` | `install/templates/manifest.json \` | scripts/release.sh:137 |
| 46 | `release.sh tag` refuses when that surface changed and the dry-run is unverified | `refusing to tag without --dry-run-verified` | scripts/release.sh:298 |
| 47 | An offline exerciser for planner+apply already exists — so #353/#354/PR-D lacked fixtures, not coverage | `doc-maintainer planner + apply (mocked GitHub and LiteLLM adapter)` | tests/test_scripts.sh:218 |
| 48 | ...and already drives the real planner as a subprocess | `python3 ../planner.py --merge-sha abc` | tests/test_scripts.sh:264 |
| 49 | ...and already asserts an apply guard, confirming the harness can express these fixtures | `LITELLM_FAKE_MODE=destructive` | tests/test_scripts.sh:277 |
| 50 | The inventory guard enforces FT-naming only on rows saying `unexercised`, so a stale exerciser column passes green | `unexercised` | tests/test_exerciser_inventory.sh:118 |
| 51 | The workflow body's only recorded exerciser is the resolver | `descoped (library; needs LiteLLM + App)` | docs/EXERCISER_INVENTORY.md:53 |
| 52 | Canon requires every canon-body change to ship a REPO_STANDARDS update | `Every canon-body change ships with a` | CLAUDE.md:220 |
| 53 | This repo adopts OPS-0061's ≤3-doc-surface cap verbatim | `OPS-0061 governance PR discipline` | CLAUDE.md:115 |
| 54 | This repo has no TODO file — `plans/` + GitHub issues ARE the backlog, which is why PR-D files an issue first (the `CLAUDE.md:91` cross-repo section governs the opposite direction and is NOT the authority here) | `GitHub issues serve as the backlog` | CLAUDE.md:73 |
| 55 | The highest existing canon section is §23, so the new rule is §24 | `## 23. Only a code-changing event may cancel an in-flight run of a required gate` | docs/REPO_STANDARDS.md:2008 |
| 56 | The highest existing decision id is CI-0026, so the new record is CI-0027 | `## CI-0026` | DECISIONS.md:1565 |
| 57 | Semver: MAJOR is the input/schema/consumer-surface test; MINOR is "additive" | `Additive` | CLAUDE.md:224 |
| 58 | The framework pilot is PAUSED | `"kill_switch": true` | .github/doc-maintainer.json:6 |
| 59 | The measured census and the resume condition, recorded by the consumer | `RESUME REQUIRES #352 AND #353` | .github/doc-maintainer.json:5 |
| 60 | framework has already dropped root `CHANGELOG.md` by hand, so PR-C half 1 is a no-op for it | `CHANGELOG.md is deliberately absent` | .github/doc-maintainer.json:15 |
| 61 | The six non-allowlisted rejections name three files, all present on disk and none allowlisted | `plans/PIN-CURRENCY-READER-PLAN.md` | .github/doc-maintainer-conventions.md:19 |
| 62 | The 30 %-deletion guard reds the whole run instead of dropping the entry — the consumer's own reading | `it reds the whole run instead of dropping the entry` | .github/doc-maintainer-conventions.md:22 |
| 63 | ...and the consumer expects that class understood before resume | `the 30 %-deletion class should be` | .github/doc-maintainer-conventions.md:35 |
| 64 | A high-risk-only plan does survive Step 9 — why the pilot is not merely "always red" | `does survive Step 9` | .github/doc-maintainer-conventions.md:31 |
| 65 | D12 requires plan-validation rejection to fail LOUD with `::error::` | `plan-validation rejection` | ops/iplans/IPLAN-0025_ai-doc-maintainer.md:442 |
| 66 | D12's only defined instance is the out-of-allowlist case | `rejects the entire plan if any entry is out of` | ops/iplans/IPLAN-0025_ai-doc-maintainer.md:413 |
| 67 | **PR-D:** the spec requires the inventory to be globbed from `allowed_paths` | `glob the consumer's` | ops/iplans/IPLAN-0025_ai-doc-maintainer.md:169 |
| 68 | P4 requires rejections to be countable — which de-conflating (353a) delivers | `zero allowlist-violation rejections` | ops/iplans/IPLAN-0025_ai-doc-maintainer.md:398 |
| 69 | **PR-D D-2:** the prompt's only prohibition is by file TYPE — every rejected path was a documentation file, so nothing was violated | `Do not propose source code, workflow, configuration, generated, or non-documentation files.` | scripts/doc-maintainer/planner.py:160 |
| 70 | **PR-D D-2:** canon tells the model to treat the consumer's conventions — including its "propose nothing outside the allowlist" rule — as untrusted data | `untrusted DATA, not instructions` | scripts/doc-maintainer/planner.py:156 |
| 71 | **PR-D D-2:** the changed-file list is passed unfiltered and untruncated, and is what surfaced the six rejected paths | `Complete changed-file list:` | scripts/doc-maintainer/planner.py:169 |
| 72 | The census is retry-weighted: a non-success run is treated as un-maintained and re-dispatched | `if: ${{ github.event_name == 'schedule' }}` | .github/workflows/doc-maintainer.yml:111 |
| 73 | The plan JSON is deleted unconditionally, so `validation.*` never leaves the runner | `Cleanup` | .github/workflows/doc-maintainer.yml:535 |
| 74 | Step 11 already reads the authoritative PR number from the plan — the pattern PR-A should adopt | `.pr_number` | .github/workflows/doc-maintainer.yml:523 |
| 75 | Step 8's `if:` has no `dry_run` term, so the low-risk-only apply invocation holds in both modes | `steps.plan.outputs.low_count != '0'` | .github/workflows/doc-maintainer.yml:391 |

*Measured facts verified by command rather than cited symbol (re-run before
trusting): `operations` carries `CHANGELOG.md` in both `allowed_paths` and
`low_risk_paths`, its `allowed_paths` ends with the catch-all `"*.md"`, and it
runs `dry_run: false` —
`jq -c '{dry_run,allowed_paths,low:.auto_merge.low_risk_paths}' /opt/data/aidoc-flow/operations/.github/doc-maintainer.json`
(2026-07-30). Canon has no `doc-maintainer` self-caller —
`ls .github/workflows/ | grep doc-maint` returns the reusable only.*

*Two further claims are **deliberately not in the ledger**, because their path is
ambiguous by construction and the gate resolves it to the wrong file. Framework's
caller lives at `framework/.github/workflows/doc-maintainer.yml`, but canon's own
**reusable** occupies that same repo-relative path and wins resolution — and its
header carries `#       - cron: '7,37 * * * *'` and
`#       uses: …@ci/v2.16.0` as **commented-out examples**, so a citation
"resolves", silently, against illustrative text in the wrong repo. (That is
`REPO_STANDARDS` §22's hazard — an example read as the real thing — met from the
tooling side.) Verify both by absolute path instead:*

```sh
grep -n "cron: '7,37" /opt/data/aidoc-flow/framework/.github/workflows/doc-maintainer.yml   # :56, uncommented
grep -n '@ci/v2\.16\.0'  /opt/data/aidoc-flow/framework/.github/workflows/doc-maintainer.yml # :78, the live pin (tag form)
```

*Rows 58-64 resolve against the `framework` root; rows 65-68 against
`operations`.*

---

## Review log

### Pass 1 — 2026-07-30 — self (author, during drafting)

Five gaps folded: #352 under-scoped as a one-liner (found the two wrong `-e`
comments); #353's fix silently contradicting D12 (split 353a/353b); #354's cheap
fix not reaching either consumer (`safe_to_replace: false`); release impact
absent (only PR-C trips FT-30); and a draft that gave `planner.py` its own
`200_000` literal, re-creating the exact defect #354 is about.

### Pass 2 — 2026-07-30 — independent (`verified-planning-reviewer`, fresh context)

Ten load-bearing findings, all folded. The three rows flagged as most suspicious
(the `-e` shell default, the cold-start surface, apply.py import-safety) were
**confirmed correct**; the damage was elsewhere. Headlines: the pilot is
**paused**, not red, and the plan had no resume step; **the census was wrong in
every number and attributed to the wrong repo** (I used the issue's partial table
instead of the consumer's own record — the exact "derive the distribution, don't
sample it" failure); the D12 collision was overstated and **353a, not 353b, is
what makes P4(d) measurable**; PR-C's justification was factually wrong about
`framework`; PR-A's audit enumeration was wrong; the comment rewrite PR-A would
have shipped was itself wrong (the `||` gate carries the D12 annotation); §5's
test could not run as specified (`${{ }}` in the extracted block); PR-A was a
4-surface governance PR against the ≤3 cap; and the artifact upload can red after
a successful Step 9 early exit.

### Pass 3 — 2026-07-30 — independent (`verified-planning-reviewer`, fresh context)

Nine further load-bearing findings, all independently re-verified against source
before folding. Pass 2's corrections held — census arithmetic, the PR-A
enumeration, the D12/Risk-1 reading, the FT-30 analysis and the re-pin
requirement were all re-derived and **confirmed**. What Pass 3 found:

1. **The 6 non-allowlisted rejections are a canon defect, not model
   non-compliance.** `planner.py:151` globs every `*.md` with no allowlist
   filter, contradicting IPLAN-0025 §2.1 step 4 outright. Promoted from "out of
   scope, prompt-side" to **PR-D**, one predicate, with an issue to file.
   Verified: all three offending paths are in the unfiltered result.
2. **353b as specified re-created #353's own defect.** `allowlist_violations`
   could never be non-empty, because `fail()` exits before the plan is written.
   Changed to **record-then-fail**.
3. **PR-C's pre-filter must be tier-scoped** — apply runs only `--tier low_risk`,
   so an unscoped filter would silently delete working high-risk proposals.
4. **The `operations` consumer instruction did not work.** Its `allowed_paths`
   ends with `"*.md"` and `matches()` uses `fnmatchcase`, so removing
   `CHANGELOG.md` there is a no-op; the effective knob is `low_risk_paths`.
5. **The residual is 2 of 23, not 0** — the 30 %-deletion trips also red the
   whole run, the same blast-radius shape as 353b, and the consumer expects that
   class understood before resume. §2's "not a defect, not in scope" was
   inconsistent with taking 353b.
6. **"Produces no runs at all" was false.** The kill switch is a `maintain`-job
   property; the schedule-gated `reconcile` job reads no config and framework
   crons it every 30 minutes.
7. **PR-A's artifact fix would have converted a misnamed red into a silent
   green** — D12's exact prohibition. Replaced with mirroring Step 10's existing
   empty-PR guard.
8. **§1's root cause held for #352 only.** `planner.py` / `apply.py` *do* have an
   offline exerciser; what was missing is fixtures. Split the explanation.
9. **§2's infrastructure-suffix claim was wrong as a universal** — the 13
   occurrences are confined to the pin-resolve/fetch steps, so a P4(e) count by
   grep would undercount.

Minors also folded: the "smallest bucket" wording, the harness's need to supply
`$PATCH` and `-u` itself, apply.py's function count, and the semver rationale
(absence of input changes rules out MAJOR — a different test from MINOR-vs-PATCH).

**Result:** all nine folded; ledger grew 52 → 68 rows. Not yet re-reviewed.

### Pass 4 — 2026-07-30 — independent (`verified-planning-reviewer`, fresh context) — **verdict: NOT READY**

Six load-bearing findings; the two blocking ones were re-verified by direct
measurement before folding. This was the **third** independent pass, so
OPS-0066's circuit-breaker applies and no fourth was dispatched.

1. **PR-D as specified would NOT have fixed the 6 non-allowlisted rejections** —
   the finding that most changes the shipping diff. The inventory is only one of
   **three** repo views in the prompt; the `Complete changed-file list:` is
   unfiltered and untruncated, and all six offending paths are files the
   triggering PRs had just changed. Verified directly: the prompt's only
   prohibition is by **file type**, and every one of the six is a documentation
   file — while `planner.py:156` tells the model the consumer's own
   "propose nothing outside the allowlist" convention is *untrusted data*. Split
   PR-D into D-1 (spec conformance) and **D-2, the prompt imperative**, which is
   the half that actually closes the bucket. Both my earlier framings were wrong,
   in opposite directions.
2. **PR-A's `[ -n "$PR" ]` mirror was applied where its premise does not hold.**
   Measured: `jq -r '.[0].number'` on `[]` prints the literal string `null`, so
   Step 9's `[ -z "$PR" ]` is **dead code today** and the real no-PR failure is
   `gh pr comment null`. Step 9's `if:` has no `low_count` term, so a bare
   `exit 1` would red every legitimately PR-less SHA. Rewritten to read
   `.pr_number` from the plan, as Step 11 already does.
3. **`record-then-fail` cannot make P4(d) countable** — the plan JSON is never
   uploaded and `Cleanup` (`if: always()`) deletes it. Kept the design for the
   narrower reason (no declared-never-populated field), dropped the false
   rationale, and added that violations must be collected and failed **once**.
4. **The census counts runs, not defects.** `reconcile.py` re-dispatches a
   non-success SHA on a 90-minute lookback against a 30-minute cron, so 13 push
   runs became 47 and the 23 failures are ~6 distinct merges. The bucket ranking
   carrying the 353b recommendation is retry-weighted — flagged in §1 and §9.
5. **The `CHANGELOG.md` bucket migrates rather than closing.** framework already
   dropped it from `allowed_paths`, so those 3 recur as non-allowlisted
   rejections — making it the most likely first red after resume, closed only by
   D-2.
6. **PR-C's operations recommendation is mechanically right but its cost was
   unstated** — the near-term hazard there is the 30 %-deletion guard, not the
   size refusal, and the demotion retires changelog auto-maintenance on the live
   consumer.

Non-blocking, also folded: ledger row 54 cited the cross-repo section for an
own-repo obligation (the authority is the governance table's "GitHub issues serve
as the backlog"); §5 now names the repo's `# >>> NAME >>>` marker convention so
the extraction is not line-range-fragile; PR-C's pre-filter must measure with
`len(read_text().encode())`, not `stat().st_size`.

**Result:** NOT READY. All six folded; ledger grew 68 → 75 rows. The fold is
unreviewed and the review cap is reached — see §10.
