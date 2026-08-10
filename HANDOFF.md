# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what
the last session did, and what to do next. **Regenerated wholesale at every wrap
per CI-0028** — nothing here is history, and every volatile claim carries the
command that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps";
the decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**State:** `main` carries **#433** (`--add-surface`), squashed
2026-08-09 · tree clean · **nothing deployed** — canon ships by tag, the last tag
is still `ci/v2.16.0`, and **41 merged PRs** are unreachable by any consumer ·
**37** open issues · **0** open PRs.

All gates green, **run on this merge commit, not carried forward**. Re-derive
every row; the commands are exact (see `CLAUDE.md` § Durable traps for why the
SGR strip and `--tier` are not optional):

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v2.16.0` |
| Unreleased **PRs** | `git log --oneline ci/v2.16.0..HEAD \| grep -cE '\(#[0-9]+\)$'` — count PRs, not commits; a wrap commit carries no `(#N)` and would inflate a `wc -l` | **41** |
| Suite | `bash tests/run.sh \| sed 's/\x1b\[[0-9;]*m//g' \| grep -oE '[0-9]+ passed, [0-9]+ failed' \| awk '{p+=$1;f+=$3} END{print NR" suites, "p" passed, "f" failed"}'` | **17 suites, 1,517 passed, 0 failed** |
| pre-commit | `pre-commit run --all-files` | exit 0 |
| pre-push | `bash scripts/pre_push_check.sh` | exit 0 |
| Governance table | `python3 install/parse-governance-table.py CLAUDE.md --repo-root .` | PASS |
| Standards drift | `bash sync/check-standards-drift.sh --tier product` | 4/4 families, **2 drift** = the deliberate FT-52 profile |
| Open issues | `gh issue list --state open --limit 200 --json number --jq 'length'` | **37** |
| Open PRs | `gh pr list --state open --json number --jq 'length'` | **0** |

## What this session did

**Ran a five-lens pre-prod review of the v3 surface, merged
[#430](https://github.com/vladm3105/aidoc-flow-ci/pull/430)** closing all five
blockers it found plus the two release-mechanics traps, then merged
**[#433](https://github.com/vladm3105/aidoc-flow-ci/pull/433)** giving v3 an
install path at all.

The blockers, each verified against source before it was acted on:

1. **`scanners` was red on arrival for every adopter.** The runner image ships
   `python3` without `ensurepip` (#349). v2 contained that to one context; v3's
   collect-then-fail consolidation makes semgrep take `dep-scan` and
   `trivy-scan` down with it.
2. **The D11 guard validated a stage the run would not use** — `RUN_STAGE`
   declared on a later step, and composite steps do not share `env:`.
3. **`links-external` could not report** — `fail-on-error: 'false'` pins
   `outcome` to `success`, so the failure arm was unreachable.
4. **`links-external` had no private variant** — a private consumer's weekly job
   queues forever (OPS-0049) with nothing to red it.
5. **All three SARIF uploads had lost D35's fork clause** and gated on
   `hashFiles` over PR-controllable paths.

**Three of the five were defenses `PLAN-025 §2` records as CARRIED.** Each was
ported correctly *as a body* and lost its defense *at a seam* — a caller-side
`if:`, a step-scoped `env:`, an input pairing. Recorded as **CI-0034**: a
defense inventory records intent; only an assertion records the defense.

**`docs/MIGRATION_v3.0.0.md` now exists**, closing the one `RELEASE_CHECKLIST`
MAJOR gate that had no artifact at all. CI-0024 applied prospectively — the doc
is a `sync-version-refs` target with its three version-bearing commands
marker-guarded, verified by bumping `VERSION` to `ci/v3.1.0`, running the
rewriter, and getting an empty diff.

**The tag cut could not previously follow its own instruction.** Every v3 caller
says "REMOVE THE MARKERS AT THE TAG CUT" while a test asserted they be present.
The assertion is now a biconditional keyed on `VERSION`, and `release.sh prep`
retires the markers — and their self-contradicting note — itself.

Review: OPS-0065, 2 lenses, cycle 1 of 3. Returned 1 blocker / 4 high / 6 medium
/ 5 low. It caught **a blocker I had caused and mis-reported as green** (see the
correction below), and **both reviewers independently found a security rationale
I had written into three files was false** — `!(a && null)` is TRUE in GitHub
expressions, so the restored step-level fork clause did not escape the job
guard's null-permissiveness. Both guards are now identity tests against
`github.repository`, **stronger than the v2 spelling**. Durable form in
auto-memory: `github-if-guards-are-null-permissive`.

Filed rather than folded, each with a reproduction and a fix shape:
[#425](https://github.com/vladm3105/aidoc-flow-ci/issues/425) (trivy/osv have no
D23 — reproduced 3→0 and 34→8),
[#426](https://github.com/vladm3105/aidoc-flow-ci/issues/426) (D11's
remote-manifest hole — reproduced),
[#427](https://github.com/vladm3105/aidoc-flow-ci/issues/427) (§27.2 scope
remainder), [#428](https://github.com/vladm3105/aidoc-flow-ci/issues/428) (SARIF
paths stated three times), and
[#432](https://github.com/vladm3105/aidoc-flow-ci/issues/432) (`pre_push_check`
run AFTER a push reports a false OPS-0069 failure and silently skips every
linter — hit while wrapping).
**[#429](https://github.com/vladm3105/aidoc-flow-ci/issues/429) was filed and
then FIXED in #433**: filing it was not finishing it, and a readiness pass that
leaves the artifact uninstallable has not finished.

### Two "founder-only" labels that did not survive being tested

Both had been carried forward across handoffs unexamined. **Test the label before
you repeat it** — the preflight below writes nothing and takes seconds.

- **FT-30's preflight was never run.** It is clean. Only the throwaway-repo run
  is genuinely a founder act.
- **`litellm-smoke` is not an infra fault.** The July failures were a
  mis-dispatch onto `ubuntu-latest`. It is still blocked — canon has zero
  registered runners — but that is a different and actionable statement.

### One correction to the previous handoff, which regeneration would otherwise revert

The last wrap asserted **"`call / verify` will red every canon PR until a tag
containing CI-0033 exists."** That is **false**, and now falsified twice — it
passed on **#424** and on **#430**. Re-derive:
`gh pr checks <N> --json name,bucket --jq '.[]|select(.name=="call / verify")|.bucket'`.
The pre-fix pipeline only inverts once the writer is large enough, so the
outcome depends on the commit range's size, not on the tag. `--admin` is **not**
routinely required. (This is #402's failure mode — stated here explicitly so the
next wholesale regeneration carries it rather than silently restoring the wrong
claim.)

## What to do next

The top item is actionable with no discovery.

1. **Take the founder decisions. Nothing below moves without them**, and they are
   now the *only* thing between the tree and a tag. They are in Blockers with
   their reasons. FT-30 gates **every** tag.
2. **Decide the v2.17.0 question, which is now nearly moot.** `ci/v3.0.0` cannot
   be an RC — `docs/REPO_STANDARDS.md:355` states pre-release pins are not
   supported by canon's own resolver, so validating v3 on a consumer branch needs
   a **SHA pin**, not a tag. If a `v2.17.0` is still wanted to get CI-0033 to
   consumers sooner, it must be cut **before** PLAN-024 Phase A, which makes
   `main` a MAJOR.
3. **The v3 install path now exists** — `install.sh --add-surface`, closed #429
   in #433. `docs/MIGRATION_v3.0.0.md` step 2 uses it. What remains of P8 is
   `deploy-ci-wizard.sh`, which is convenience, not a blocker.
4. **PLAN-024 Phase A is still prepare-and-propose, not execute.**
   `plans/PLAN-024_ci-flow-efficiency.md:3` reads `Status: Draft — no phase
   executed`, and §5 A4 carries two open founder items. `PLAN-025 §7` makes
   Phases A/B/C a precondition for v3.

Open issues are the backlog — do not restate them here:

```sh
gh issue list --state open --limit 200      # the --limit 30 default truncates silently
```

## Blockers

All founder-only. None moved this session, and #430 did not attempt to.

| Blocker | Why | What clears it |
| --- | --- | --- |
| **🔴 FT-30 cold-start dry run — PREFLIGHT IS CLEAN, only the real run remains** | `bash scripts/ft30-dry-run.sh --check` writes nothing and passes: gate owed (15 cold-start files changed), `CI_TAG` resolves and is pushed, `gh` authenticated. Run it yourself before asking the founder for anything | Founder runs `scripts/ft30-dry-run.sh --target <owner>/<throwaway>` — it CLONES and creates ~21 labels in another repo, which is why it is founder-owned. See `CLAUDE.md` § Durable traps for what it does **not** assert ([#358](https://github.com/vladm3105/aidoc-flow-ci/issues/358)) |
| **🔴 `litellm-smoke` cannot run — canon has ZERO registered runners** | A MAJOR-only `RELEASE_CHECKLIST` gate, and the diagnosis changed: the 2026-07-13 failures were a **mis-dispatch onto `ubuntu-latest`**, which per CI-0017 cannot reach the bridge proxy at `172.17.0.1`. The workflow's own default is already the pool — but `gh api repos/vladm3105/aidoc-flow-ci/actions/runners --jq '.total_count'` → **0**, so a correct dispatch would queue forever | Register an ephemeral pool against canon (`../operations/scripts/ci-runner/run-ephemeral.sh`), then dispatch with the input defaults plus `allow_insecure_http: true` |
| **🔴 PR-C deviation confirmation** | Due before `ci/v2.17.0`. #405 shipped the demotion only, not the de-allowlisting §4 PR-C item 1 called for | Founder decision; reasoning in PLAN-021 §4 PR-C LANDED note |
| **🔴 PLAN-025 unreviewed since Pass 4** | OPS-0066 3-pass cap spent; P2/P3/P8 material never had an independent pass | Founder waiver, or a fresh plan for the remaining phases |
| **The runner image must be REBUILT, per host** | #430 fixed the Dockerfile (`python3-venv`, `python3-pip`, `python3-yaml`) but the image is built locally with **no registry push**, and nothing prompts for it. Until then `scanners` is red on arrival (#349) | `cd install/templates/runner && bash build-image.sh` on each runner host — it now *builds* a venv and imports yaml to verify, rather than trusting the package list |

**PLAN-025 P7 must not run** — still the only irreversible phase; P9 (rollback)
must exist first. P4 and P5 (the full `docs/v3/` set) are also not started;
`docs/MIGRATION_v3.0.0.md` is the migration path but not the documentation set.

The **PLAN-021 consumer resume** owes two easy-to-get-wrong edits; they are
durable and live in `CLAUDE.md` § "The PLAN-021 consumer resume", not here.

## What did NOT change

No tag, no release, no consumer repo, no branch protection, no ruleset, no
required context, and no `VERSION` bump. No `doc-maintainer`, `docs-sync`,
`ai-review` or `secret-scan` behaviour.

**All five** v3 caller templates still pin `ci/v3.0.0`, a tag that does not
exist, behind `sync-version-refs:ignore` markers. `release.sh prep` now removes
them at the cut, so this is no longer a manual step — but count them rather than
trusting this line: `grep -rlF 'ci/v3.0.0' install/templates/workflows/`.

`doc-maintainer` remains **live on `operations`** and **paused on `framework`** —
not re-verified this session; re-derive with
`python3 -c "import json;[print(r, json.load(open(f'../{r}/.github/doc-maintainer.json'))['dry_run'], json.load(open(f'../{r}/.github/doc-maintainer.json'))['kill_switch']) for r in ('operations','framework')]"`.
