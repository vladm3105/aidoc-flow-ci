# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**State:** `main` unchanged — **nothing merged this session** · all work is
**9 commits on the local branch `feat/v3-composite-actions`** · **NOT PUSHED, no upstream, no PR** · tree clean · local checks
**5/5 exit 0**, suite **16 suites / 1236 passed / 0 failed** (verified at wrap) ·
nothing deployed: canon ships by tag and everything since `ci/v2.16.0` is
unreleased.

---

## 🔴 READ THIS FIRST — the work is not pushed and will be lost

```sh
git status -sb | head -1      # `## feat/v3-composite-actions` with NO `...origin/` = no upstream
git log --oneline main..HEAD  # 9 commits
```

Sessions run in ephemeral containers, so **only committed *and pushed* work
survives**. Nine commits of real work (six composite actions, five caller
templates, a toolchain fix, ~3,200 insertions) exist only on this machine.

**It cannot simply be pushed.** `scripts/pre_push_check.sh` will refuse:

```sh
git log main..HEAD --format='%B' | grep -c 'Multi-agent self-review per OPS-0065'   # → 0
```

That refusal is **correct**. The OPS-0065 multi-agent pre-push review has not run
on this diff, and every commit message says so explicitly rather than carrying
the phrase. Clearing it needs, in order:

1. Dispatch the OPS-0065 review on the branch diff (`git diff main...HEAD`).
2. Fold whatever it finds.
3. Add the audit-trail phrase to a commit, push, open a PR.

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

**Measured facts worth not re-deriving** (each re-derivable by the command shown
in the plan): PR wall clock on the self-hosted pool is **~99% queue, not
execution** — the longest run measured 33,808s queued against 196s executed. Job
*count* is therefore the cost driver, which is the whole basis for the composite-
action work.

## What to do next

The top item is actionable with no discovery.

1. **Decide the fate of the branch** — the 🔴 section above. Either run the
   OPS-0065 review and push, or accept the loss. Nothing else matters until this
   is settled.
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
| **Branch unpushed** | OPS-0065 review has not run; `pre_push_check.sh` refuses | Run the review, fold, add the phrase, push |
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
