# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**State:** `main` unchanged — **nothing merged this session** · all work is on
the local branch `feat/v3-composite-actions` (count it: `git log --oneline
main..HEAD | wc -l`; 10 at the time of writing) · **NOT PUSHED, no upstream, no
PR** · tree clean · **`scripts/pre_push_check.sh` checks 1–4 pass; check 5
(OPS-0069 phrase) is the only failure** · suite **16 suites / 1278 passed / 0
failed** · nothing deployed: canon ships by tag and everything since
`ci/v2.16.0` is unreleased.

> **An earlier version of this line claimed "local checks 5/5 exit 0". That was
> false** — 7 markdownlint errors in the plan files and SC2164 in three test
> files were failing. The cause is worth carrying: the claim was derived from a
> gate loop *I built*, which linted two markdown files and ran shellcheck at
> `-S error`, while `pre_push_check.sh` lints **every** changed `.md` and uses
> `-S warning`. **A verification narrower than its claim is a false claim.**
> Both failures are now fixed; re-derive with `bash scripts/pre_push_check.sh`.

---

## 🔴 READ THIS FIRST — the work is not pushed and will be lost

```sh
git status -sb | head -1      # `## feat/v3-composite-actions` with NO `...origin/` = no upstream
git log --oneline main..HEAD | wc -l
```

Sessions run in ephemeral containers, so **only committed *and pushed* work
survives**. Six composite actions, four caller templates, a toolchain fix and a
hardened test suite exist only on this machine. Size it with
`git diff --shortstat main...HEAD` rather than trusting a number written here.

**It cannot simply be pushed.** `scripts/pre_push_check.sh` will refuse:

```sh
git log main..HEAD --format='%B' | grep -c 'Multi-agent self-review per OPS-0065'   # → 0
```

That refusal was correct while the review was outstanding, and the earlier
commits say so in their messages rather than carrying the phrase. The full
sequence, for whoever picks this up:

0. **Run `bash scripts/pre_push_check.sh` first** and fix whatever checks 1–4
   report. They are not implied by the suite being green: the suite and the gate
   lint different file sets at different severities.
1. Dispatch the OPS-0065 review on the branch diff (`git diff main...HEAD`).
2. Fold whatever it finds — and re-run the gate after folding, since a fold
   edits the files the gate reads.
3. Add the audit-trail phrase to a commit, push, open a PR.

**Status of steps 0–2 as of this wrap: DONE.** The five-agent OPS-0065 review
ran, ~90 findings were returned, and the load-bearing ones are folded (see
`CHANGELOG.md`). Checks 1–4 pass. What remains is step 3.

**Do not add the phrase without running the review** — the gate matches the
phrase, not the work (`CLAUDE.md` § Durable traps), so that would be a lie the
gate cannot detect.

---

## What this session did

**Nothing merged.** Two plans authored and reviewed, and PLAN-025's first three
phases built.

**PLAN-024** (`plans/PLAN-024_ci-flow-efficiency.md`) — a CI-efficiency plan whose
**most valuable output is its withdrawal list.** Four proposals were each
withdrawn after independent review found the structure they targeted was
deliberate: collapsing the `-public`/`-private` template pairs (they are the
`install.sh --update` fix), documenting a naming rule (§16.9 has it), a
`python-tests.yml` reusable (the job name *is* the required context), and all of
Phase G (`markdown-lint` is a live required context on canon's `main`, and the
scanners are a founder MUST-HAVE per PLAN-014). Surviving phases: eliminate
`doc-maintainer` (founder decision), reduce `docs-sync`, cut the stalled release.

**PLAN-025** (`plans/PLAN-025_v3-clean-rebuild.md`) — the v3 rebuild. **P1, P2,
P3, P3a done; P8 core done.** See its §5 status table and §8 blocker list; both
are current as of this wrap.

**One measured fact worth not re-deriving**, with the command, because the
earlier version of this paragraph quoted figures that appear nowhere else in the
repo and cited "the command shown in the plan" when neither plan carries one:

```sh
gh api repos/<owner>/<repo>/actions/runs/<id>/jobs --jq \
  '.jobs[] | {name, queued:((.started_at|fromdate)-(.created_at|fromdate)),
              exec:((.completed_at|fromdate)-(.started_at|fromdate))}'
```

Run against the longest jobs on the self-hosted pool, that split came back
**~99% queue, ~1% execution**. Note what it does and does not license:
PLAN-024 concluded from it that **there is no safe job-count reduction inside
the library** and that the remedy is runner capacity. v3's case is narrower and
compatible — a `workflow_call` reusable costs one provisioning cycle *each*, so
consolidating checks into one job removes cycles without removing checks. Do not
read the measurement as PLAN-024 endorsing consolidation; it does not.

## What to do next

The top item is actionable with no discovery.

1. **Push the branch and open a PR** — the 🔴 section above. The review is done
   and folded and checks 1–4 pass, so the only remaining step is the audit-trail
   phrase plus the push. Until that lands, everything below is at risk: this is
   an ephemeral container.
2. **PLAN-024 Phases A/B/C ship first** (PLAN-025 §7): eliminate
   `doc-maintainer`, reduce `docs-sync`, cut `ci/v3.0.0`. Building v3 around a
   flow being deleted wastes the work. Phase A carries a **release-gate
   circularity** — the MAJOR-bump LiteLLM smoke tests the `ai-doc-maintainer`
   alias that Phase A deletes, so `litellm-smoke.yml` must be edited inside the
   phase or the tag cannot be cut.
3. **PLAN-025 P5** — the v3 documentation set. Largest remaining build item, and
   §4.4 makes the §2→`RULES.md` mapping an acceptance test: all 46 defense rows
   must appear as rules.

Open issues are the backlog — do not restate them here:

```sh
gh issue list --state open --limit 200
```

## Blockers

| Blocker | Why | What clears it |
| --- | --- | --- |
| **Branch unpushed** | Review DONE and folded; checks 1–4 pass. Only the OPS-0069 phrase is missing | Add the phrase to a commit, push, open a PR |
| **🔴 FT-30 cold-start dry run** | Founder-executed; owed before ANY tag (PLAN-021 armed it) | Founder runs `scripts/ft30-dry-run.sh` |
| **PLAN-025 unreviewed since Pass 4** | OPS-0066 3-pass cap is spent; P2/P3/P8 material has never had an independent pass | Founder waiver, or a fresh plan for the remaining phases |
| **PLAN-025 P7 must not run** | Now *unblocked* by P8's core fix, but still the only irreversible phase | P9 (rollback) must exist first |
| **`semgrep` cannot install on the runner image** | No `python3-venv` (#349) — `sast-scan` is inert where it is the only SAST | Rebuild `aidoc-flow-runner:latest` |

## What did NOT change

`main`, any consumer repo, any live branch protection, any ruleset, any released
tag. No `gh` issue was opened, closed or commented this session. `doc-maintainer`
is still **live on `operations`** (`dry_run: false`) and still **paused on
`framework`** (`kill_switch: true`) — and `framework`'s pause cites #352/#353 as
resume-blockers, **both of which are closed**, so that pause is stale.

**The previous wrap's next-tasks were not worked** — PLAN-023 PR-1 and the
CI-0031 reservation. They are not dropped: they live in that plan's own header
and in issues #401/#402, which is where an open task belongs. This handoff does
not restate them, by design.

*(Relevant: issue #402 is about this exact hazard — a fact corrected in one wrap
reverting on the next wholesale regeneration. This successor was diffed against
its predecessor before publishing, per the wrap sequence.)*
