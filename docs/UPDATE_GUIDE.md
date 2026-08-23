# Updating a consumer to a newer canon (`install.sh --update`)

`install.sh --update` refreshes a repo that has **already adopted** the
aidoc-flow-ci canon against a newer `ci/vX.Y.Z`. It is the counterpart to
the one-shot bootstrap (`install.sh <owner/repo>`): bootstrap *adds* new
surfaces and preserves everything; `--update` *reconciles* the surfaces the
consumer already has against the pinned canon.

## When to use it

After the founder cuts a new `ci/vX.Y.Z` and you want a consumer to pick up
the changes — updated reusable-workflow callers, a new `dependabot.yml`,
etc. Pair it with bumping the `uses: …@ci/vX.Y.Z` pins in the consumer's
callers (the pin bump is what makes the reusable workflows run the new
version; `--update` refreshes the *caller files + config surfaces*).

## How it works

```bash
CI_TAG=ci/vX.Y.Z bash install.sh <owner/repo> --update
```

1. Clones the consumer (same stable work dir as bootstrap).
2. Detects the repo's real visibility (public/private) to pick the right
   caller variant.
3. Walks `install/templates/manifest.json` — the canonical index of every
   `template → consumer-file` mapping. For each surface the consumer
   **already has**, it re-fetches the template at `$CI_TAG`, substitutes the
   placeholders, and `diff -u`s it against the local file. Two kinds:
   the de-branding ones (`${CODEOWNER_HANDLE}`, `${CANON_*_URL}` — pass
   `--codeowner` / `--canon-*-url` to match what the consumer installed with),
   and `${INTEGRATION_BRANCH}` (PLAN-028 B5), which has no flag and is resolved
   per repo from `.github/aidoc-ci.json`, else the repo's GitHub default branch.
   It fills the `branches:` filter of every caller trigger arm, so **`--update`
   is the only way that change reaches a consumer** — `--repin` rewrites
   `uses:` tag strings and cannot touch a caller body. Expect a one-line diff
   per trigger arm on the first update after adopting this tag: `branches:
   [main]` becomes `branches: ["main"]` (or your actual default branch).
4. Files the consumer does **not** have are skipped — `--update` never
   introduces a surface the consumer didn't opt into. Use bootstrap to add
   new surfaces.

## Interactive vs non-interactive

For each **drifted** file:

| Mode | Behavior |
| --- | --- |
| interactive (default, TTY present) | prints the unified diff, then prompts `[k]eep local / [r]eplace with canon / [d]iff-only`. Default (empty answer) = keep. |
| `--non-interactive` (or no TTY) | replaces **only** `safe_to_replace` files (the mechanical workflow files + `dependabot.yml`); **keeps** everything else (`config.json`, `CODEOWNERS`, `CLAUDE.md`, `pre_push_check.sh`, and `codeql.yml` — which consumers customize) and prints the diff for manual review. |

`safe_to_replace` is declared per file in `manifest.json`. The safe set is
limited to mechanical canon (the workflow files + `dependabot.yml`) — files a
consumer never hand-edits. Policy/governance files (`config.json`,
`CODEOWNERS`, `CLAUDE.md`, `pre_push_check.sh`) and the consumer-customized
`codeql.yml` (its `languages` input) are `safe_to_replace: false`, so a
consumer's local edits are never auto-replaced (guards against
[R4 in PLAN-004 §6](../plans/PLAN-004_company-default-elevation.md)).

Replacement is atomic (staged in a sibling temp file, then renamed), so an
interrupted run never leaves a truncated file.

## What `--update` does NOT touch

- **`labels.json`** — canonical labels are a GitHub-API surface, created by
  bootstrap's label step. Re-run `install.sh <owner/repo>` (bootstrap) to
  reconcile labels; it is idempotent.
- **`.pre-commit-config.yaml`** — the canon block is *merged* (not replaced)
  via the `# CANON:` marker. Re-run bootstrap to re-merge.
- **Branch protection / repo settings / secrets** — see
  [`BRANCH_PROTECTION.md`](BRANCH_PROTECTION.md) and
  [`REVIEWER_APP_ONBOARDING.md`](REVIEWER_APP_ONBOARDING.md).

## Body adoption vs re-pin — pick the right operation first

`--update` and `--repin` are **not** two strengths of the same thing. They
change different surfaces, and reaching for the wrong one is the single most
expensive mistake in a rollout:

There are in fact **three** operations, and the third exists because the pair
above cannot express "I need a surface I do not have":

| | `--repin` | `--update` | `--add-surface` |
| --- | --- | --- | --- |
| changes | the `@ci/vX.Y.Z` string, nothing else | the whole **body** of every `safe_to_replace` file the consumer HAS | adds a manifested surface the consumer LACKS |
| consumer customization | preserved by construction | **replaced** (16 surfaces: all 15 workflow callers + `dependabot.yml`) | untouched — it never overwrites |
| use for | picking up a new canon *version* | adopting a canon *topology* change (new job, changed inputs) | adopting an `auto_install: false` surface (the v3 callers) |

**`--update` will silently do nothing for a surface you lack** — it walks only
files already present. That is by design, and it is how the `ci/v3.0.0` callers
came to be manifested and uninstallable
([#429](https://github.com/vladm3105/aidoc-flow-ci/issues/429)). Full contract:
[`REPO_STANDARDS.md`](REPO_STANDARDS.md) §4.2e.

**Default to `--repin`.** A consumer that only needs the new canon version
never needs `--update`. Body adoption is the exception, taken deliberately when
canon's caller *shape* changed and the consumer must follow.

### What body adoption drops

A caller file is where a consumer records everything repo-specific about *how*
canon runs for them. Replacing the body discards all of it:

- **`runner_labels_*`** — the big one. Live example: `framework`'s ai-review
  caller pins `runner_labels_routine: '"ubuntu-latest"'`, while the canon
  template ships `'["self-hosted", "ci", "ephemeral"]'`. A
  non-interactive `--update` flips it to the self-hosted array; if that repo
  has no pool registered, **every job queues forever and the gate is bricked**
  — with green-looking config. The reverse also bites: a private repo silently
  reverted to a `runner-self` placeholder from an older release has the same
  outcome (see `CLAUDE.md` § Runner policy).
- **`permissions:`** — the caller block sets the *ceiling* for the reusable. A
  consumer that tuned it (as `operations` has) and loses the tuning gets
  `startup_failure` with zero jobs, because the reusable then requests more
  than the caller grants.
- **Triggers (`on:`)** and `concurrency` — repos that narrowed events or added
  a group get canon's defaults back.
- **Any inputs the consumer tuned** — `codeql.yml`'s `languages` is
  `safe_to_replace: false` for exactly this reason, but the 15 callers that
  *are* replaceable carry tuned inputs too.

None of this fails loudly at update time. It fails on the next PR.

### Reconciliation procedure

`--update` writes into a git work dir and replaces nothing outside it, so the
reconciliation is a **review gate on the resulting diff**, not a recovery step.
Do it before committing:

1. **Run the update**, then `cd <printed-work-dir>`.
2. **Read the diff for the four customization classes above** — not for canon
   correctness, which is the easy part:

   ```bash
   git diff -U0 -- .github/workflows/ \
     | grep -E '^[-+].*(runner_labels|permissions:|contents:|pull-requests:|issues:|^\+on:|concurrency)'
   ```

   Every `-` line here is a consumer decision the update just discarded.
3. **Restore each one deliberately.** Re-apply the consumer's value unless
   canon's change is specifically what you came to adopt. When in doubt, keep
   the consumer's — canon's caller templates are a starting point, not a
   fleet-wide truth.
4. **Verify before commit**, per `docs/runners.md`:
   - no `runner-self` anywhere (never a registered label — it queues forever);
   - private repos: every job on `["self-hosted", "ci", "ephemeral"]`,
     never `ubuntu-latest`;
   - public repos: the **fork-code-executing** lint callers
     (`markdown-lint`, `links`, `pre-commit`) stay on `ubuntu-latest`; only
     the AI flows run on the pool.
5. **Open the consumer PR and let its own CI prove it.** A bricked runner
   label shows up as jobs stuck in `queued` — treat any never-starting job as
   a failed reconciliation, not a flaky runner.

If a repo needs only the version, stop reading here and use `--repin`.

## ⚠️ Expected drift after re-pinning to `ci/v2.14.0` or later (CI-0011)

**Re-pinning alone will make `standards-drift` report two new warnings.** This is
expected and is not a regression — it means the repo's Actions settings have not yet
been brought to the CI-0011 boundary.

`ci/v2.13.0` narrowed the canon `actions-permissions.json`: the GitHub-verified
marketplace was dropped (`verified_allowed: false`) and `patterns_allowed` became the
owner's account (`vladm3105/*`). Those are **template values — they take effect only
when applied per-repo**, so a consumer that re-pins but has not applied them sees:

```text
actions.selected.verified_allowed: canon=false actual=true
actions.selected.patterns_allowed: MISSING (canon has, repo does not, and no live
  pattern covers it): vladm3105/* — an action matching these is BLOCKED at run-init
  (silent startup_failure, no logs)
```

**Nothing is actually broken.** Read the second message carefully: the repo's live
pattern (`vladm3105/aidoc-flow-ci/*`) is *narrower* than canon's, so every canon
reusable it calls is still admitted. The "BLOCKED" consequence applies only to a
hypothetical action under some *other* `vladm3105/` repo — which no consumer calls
today. The drift is real and worth closing; it is not an outage.

**Severity:** `strict` defaults to `false`, so this **warns and exits 0** (verified).
Only a caller that passes `strict: true` — a release or adoption gate — would newly
**fail** on it.

**Fix — apply the settings alongside the re-pin, and it is a non-event:**

```bash
# scan the target's uses: FIRST — a narrowed allowlist silently startup_failures
# anything outside actions/*, github/*, vladm3105/*
grep -rnoE 'uses:[[:space:]]*[^[:space:]]+' <repo>/.github/workflows/*.y*ml | sort -u

jq -c '.selected_actions | walk(if type=="object" then with_entries(select(.key|startswith("_")|not)) else . end)' \
  install/templates/actions-permissions.json |
  gh api -X PUT repos/<owner>/<repo>/actions/permissions/selected-actions --input -
```

**Do NOT blanket-apply.** `web-site` (`Azure/static-web-apps-deploy`) and
`knowledge-rag` (`codecov/codecov-action`) call verified-creator actions that are
admitted **today only** by `verified_allowed: true`; applying CI-0011 to them would
break those jobs. See `docs/RELEASE_CHECKLIST.md` for the full exclusion note, and
`DECISIONS.md` CI-0011 for the decision itself.

## Reading the drift report as the rollout worklist

Two different tools report drift, and knowing which one owns a surface is the
difference between triaging a finding and hunting for one that was never there:

| tool | surfaces |
| --- | --- |
| `install/apply-standards.sh --check` | the 8 config/governance surfaces in its own header — `CODEOWNERS`, PR template, `dependabot.yml`, `pre_push_check.sh`, `.gitignore`, `.gitattributes`, `.pre-commit-config.yaml`, `CLAUDE.md#per-repo-governance`. **No workflow caller is among them.** |
| `sync/check-drift.sh` (and the `standards-drift.yml` reusable) | `.github/workflows/*.yml` — the callers, by raw `diff`, with no visibility-aware exclusions |

During a rollout **their output is the worklist, not a bug list** — CI-0013
completes canon first and rolls consumers out afterwards, so every
not-yet-rolled-out repo is *expected* to be drifted. A clean report across the
fleet is the end state, not the precondition.

Read it in three buckets:

| bucket | meaning | action |
| --- | --- | --- |
| **Deliverable** | canon has a surface the consumer lacks | roll it out — this is the actual worklist |
| **Deliberate** | consumer's own value that canon must not overwrite | leave it; record why |
| **Not-yet-provisioned** | blocked on a 🔴 human action (pool, secret, App install) | escalate; do not paper over |

The **deliberate** bucket never reaches zero, so treat a persistently drifted
line as a question, not a defect. Known members today —

from `apply-standards.sh --check`, all three on `.pre-commit-config.yaml` and
enumerated in [`REPO_STANDARDS.md`](REPO_STANDARDS.md) §14.1a:

- a consumer's kept third-party `rev` (the refresh reports it rather than
  overwriting a deliberate pin; **FT-38** tracks the four repos still on a
  mutable `rev: v5.0.0`);
- a wrapper hook's own `name:`/`entry:` lines
  (`scripts/pre_push_check_<repo>.sh`, PLAN-002 §4.8);
- flow-style `default_install_hook_types: [pre-commit, pre-push]` —
  semantically canon, not a verbatim line match.

from `sync/check-drift.sh` / `standards-drift.yml`:

- per-repo `runner_labels_*` that correctly differ by visibility. That script
  diffs callers against the templates verbatim and has **no** visibility-aware
  exclusion, so a correctly-routed repo still reports drift on those lines —
  expected, and the reason the previous section says to keep the consumer's
  value rather than converge on canon's.

**Do not "fix" drift by making the consumer match canon byte-for-byte.** Three
of the four items above are deliberate, and overwriting them is precisely the
failure mode the previous section exists to prevent.

## After `--update`

The script prints the work-dir path. Inspect and commit:

```bash
cd <printed-work-dir> && git diff
# commit + push + open a PR on the consumer per its normal flow
```

`--update` is idempotent: re-running with no canon change prints only
`unchanged` lines and replaces nothing.

## `docs-sync` needs `pull-requests: write` on BOTH halves (CI-0015)

A reusable workflow's token is the **intersection** of the caller's grant and
the callee's own `permissions:` block. Raising either half alone changes
nothing.

`docs-sync.yml` (the callee) capped `pull-requests: read` while its `sync` job
runs `gh pr comment`, so the dry-run comment step was unreachable on **every**
consumer. It never surfaced because the step is gated on `proposed != 0` and had
not fired; the check was green until a merge finally produced a proposal, then
failed with `GraphQL: Resource not accessible by integration (addComment)`.

**What each consumer needs:**

| Consumer installed from | Action |
|---|---|
| `ci/v2.11.0` or later | **Re-pin only.** The shipped caller template has granted `pull-requests: write` since `ci/v2.11.0` — the missing half was the callee. |
| Before `ci/v2.11.0`, or a caller hand-edited to `read` | Re-pin **and** raise the caller to `pull-requests: write`. |

`install.sh --repin` does **not** raise a caller's permissions — it rewrites
`uses:` lines only. Check with:

```bash
grep -A6 '^permissions:' .github/workflows/docs-sync.yml
```

If it shows `pull-requests: read`, edit it to `write`.

## ci/v1.x → ci/v2.0.0 breaking-change migration

The `ci/v2.0.0` release replaces vendor CLIs with a unified LiteLLM proxy.
This is a breaking change — consumers must complete additional steps beyond
a normal `--update` or `--repin` cycle. Read the full migration guide:

- [`docs/MIGRATION_v2.0.0.md`](MIGRATION_v2.0.0.md) — complete checklist
  (new secrets, removed inputs, config changes, repin, smoke test)

Quick-reference:

<!-- sync-version-refs:ignore-start -->
<!-- CI-0024: the tag below is this migration's DESTINATION, not a reference that
     tracks VERSION. Unmarked, every release cut rewrote it — and at the ci/v3.0.0
     cut it read `CI_TAG=ci/v3.0.0`, sending a v1.x consumer across a MAJOR
     boundary from inside the v2.0.0 section, skipping the context surgery the
     v3 migration below requires (#450). Its twin in MIGRATION_v2.0.0.md was
     already marked; this one was the outlier. -->
1. Add `LITELLM_BASE_URL` + `LITELLM_REVIEW_API_KEY` secrets — **these names,
   not the modern ones.** The unified `LLM_URL` / `LLM_API_KEY` pair arrived
   2026-08-21, long after `ci/v2.0.0` was cut, and the fallback that accepts the
   old names (`secrets.LLM_URL || secrets.LITELLM_BASE_URL`) lives in the
   reusable — so at the **frozen `ci/v2.0.0` pin this step targets**, `LLM_URL`
   is not read at all and the ai-review job cannot find its secret. This
   quick-reference said `LLM_URL` while the full guide it summarises
   (`MIGRATION_v2.0.0.md` §2) said `LITELLM_*`: two documents, one step, mutually
   exclusive names. Set the modern pair as well if you intend to keep moving
   forward — `docs/MIGRATION_v4.0.0.md` §3 covers that — but this step needs the
   `LITELLM_*` pair to work at its own pin.
2. Set `.github/ai-review/config.json` to the **v2 shape** — BOTH fields, since
   CI-0014 asserts `version == 2` before reading anything and `litellm.model`
   has no default:
   `{"version": 2, "litellm": {"model": "ai-reviewer"}, ...}`
3. Drop deprecated vendor-CLI secrets (`OPENAI_API_KEY`, etc.)
4. `CI_TAG=ci/v2.0.0 bash install.sh <owner/repo> --repin` — and **only add
   `--update` if this consumer actually needs canon's new caller bodies**. The
   `v2.0.0` migration itself does not: it is secrets + config + a **hand-edit of
   the caller's `with:` block** (drop the removed `reviewer:` / vendor-model
   inputs — see `MIGRATION_v2.0.0.md` §4) + a pin bump.
   Running `--update` here replaces all 16 replaceable surfaces and discards the
   repo's `runner_labels_*` and `permissions:` — see
   [Body adoption vs re-pin](#body-adoption-vs-re-pin--pick-the-right-operation-first)
   and reconcile the diff before committing.
5. Verify LiteLLM connectivity (smoke test) before merging the consumer PR
<!-- sync-version-refs:ignore-end -->

That lands the consumer on `ci/v2.0.0`, not on the current release. Continue with
the v3 migration below — it is a second breaking change and the two do not
compose into one repin.

## ci/v3.0.0 → ci/v4.0.0 breaking-change migration

`ci/v4.0.0` changes the **operating contract**, not the packaging — the v3
composite-action rework is unchanged. Three breaks, and the first two are not
backward compatible:

| Change | What breaks if you ignore it |
|---|---|
| Runner labels `ci-runner`→`ci`, `single-use`→`ephemeral` (CI-0043) | Jobs **queue forever** — no failure, no timeout, no log |
| `doc-maintainer` reusable **deleted** (CI-0040) | A repinned caller gets `startup_failure`, which produces no logs |
| LLM credentials unify on `LLM_URL`/`LLM_API_KEY` | Nothing — the `LITELLM_*` names still resolve |

Two ordering rules carry the whole risk, and both are the kind that fail
silently rather than loudly:

1. **Register the coexistence runner label set BEFORE repinning**
   (`self-hosted,ci-runner,single-use,ci,ephemeral`), confirm a real job lands
   on the new labels, and only then narrow to `self-hosted,ci,ephemeral`. A job
   whose labels match no registered runner queues forever; `timeout-minutes`
   cannot fire on a job that never starts.
2. **Delete your `doc-maintainer.yml` caller BEFORE repinning**, not after.

`ci/v3.0.0` was **not** re-cut and remains a valid pin and the rollback target
(`DECISIONS.md` CI-0044).

- [`docs/MIGRATION_v4.0.0.md`](MIGRATION_v4.0.0.md) — complete checklist
  (preconditions, the ordered runner cutover, the delete-before-repin rule,
  secrets, rollback)

## ci/v2.x → ci/v3.0.0 breaking-change migration

The `ci/v3.0.0` release repackages six reusable workflows as **composite
actions** invoked from two consolidated jobs, plus a weekly `links-external`.
Nothing is removed and no check is lost, but **required status-check context
strings change**, so this cannot be done by `--repin` or `--update` alone. Read
the full migration guide:

- [`docs/MIGRATION_v3.0.0.md`](MIGRATION_v3.0.0.md) — complete checklist
  (preconditions, the context mapping, add-surface, the add-then-remove
  sequence, rollback)

**Arriving from a pin below `ci/v2.16.0` — including from the v2.0.0 section
above — read the two sections earlier in this file first.** A v3 repin crosses
both boundaries at once: `docs-sync` needs `pull-requests: write` on a caller
installed before `ci/v2.11.0`, and `ci/v2.14.0` or later emits two CI-0011
`standards-drift` warnings until the settings are applied. Neither is a v3
change, and neither announces itself at the v3 step that exposes it.

**Why `--repin` and `--update` are both insufficient here**, in the terms this
document already uses: `--repin` rewrites `uses:` tag strings, and `--update`
walks only files the consumer already has, so neither introduces a file that is
absent — which all three v3 callers are
([#429](https://github.com/vladm3105/aidoc-flow-ci/issues/429)). What
`auto_install` governs is narrower, and as of #481 it excludes **all three**:
`quick-gates.yml` joined `scanners.yml` and `links-external.yml` at
`auto_install: false`, so a **bootstrap** picks up none of them and a consumer
adopting by bootstrap needs `--add-surface` for all three. A consumer several
minors behind additionally needs body adoption — see
[Body adoption vs re-pin](#body-adoption-vs-re-pin--pick-the-right-operation-first)
and reconcile the diff.

Quick-reference:

<!-- sync-version-refs:ignore-start -->
<!-- CI-0024: same as the v2.0.0 block above — these tags are the destination of
     this migration, not references that track VERSION. -->
1. **Self-hosted consumers: rebuild the runner image FIRST** —
   `cd install/templates/runner && bash build-image.sh`. v3's `sast-scan` builds
   a venv and the `pre-commit` guard parses YAML on the system interpreter; a
   pre-v3 image has neither. The image is built per host with no registry push,
   so nothing prompts a host that has not rebuilt. Skipping this reds `scanners`
   on its first run and takes the two working scanners down with it
   ([#349](https://github.com/vladm3105/aidoc-flow-ci/issues/349)). In the same
   step confirm the runner version —
   `gh api repos/<owner>/<repo>/actions/runners --jq '.runners[].version'` —
   `2.327.1` is a hard floor for the node24 actions, unchanged from v2. Below it
   jobs die with an error naming neither the action nor the floor, which at
   step 4 is indistinguishable from a v3 defect.
2. `CI_TAG=ci/v3.0.0 bash install.sh <owner/repo> --repin`
3. Add the three new callers — `--add-surface` resolves the public/private
   variant from your repo's live visibility, so you cannot pick wrong:

   ```sh
   CI_TAG=ci/v3.0.0 bash install.sh <owner/repo> \
     --add-surface .github/workflows/quick-gates.yml \
     --add-surface .github/workflows/scanners.yml \
     --add-surface .github/workflows/links-external.yml
   ```

   They land in the fresh clone the run prints, not in your checkout — commit
   and push from there.
4. **Observe `quick-gates` and `scanners` green on a real PR before requiring
   them.** Old and new both run in this window; that double cost is the point.
5. Swap the required contexts — **add first, then remove** the six v2 ones. Do
   it in **both** branch protection and rulesets; `apply-standards.sh` never
   touches rulesets (CI-0029). Leave `links-external` non-required.
6. Only then delete the six v2 callers. Keep `secret-scan.yml`,
   `audit-trail.yml`, `composition.yml`, `ai-review.yml` — they are not part of
   v3. **Do not delete `links.yml` unless `links-external.yml` is installed**:
   `quick-gates` absorbs only the internal half, so dropping one without the
   other loses external link checking entirely, and nothing reports its absence.
7. Re-check `gh pr checks` for a context stuck on "Expected — Waiting for status
   to be reported": that is a required context nothing emits, and it has no
   `--admin`-free exit.
<!-- sync-version-refs:ignore-end -->

The mapping — three v2 contexts collapse into `quick-gates`, three into
`scanners`, so you add two and remove six — is the table at
[`MIGRATION_v3.0.0.md` § The mapping](MIGRATION_v3.0.0.md#the-mapping--old-context--new-context).
`call / X` disappears because it is `<caller-job-key> / <callee-job-name>` and
only a reusable call produces it; v3's jobs are plain jobs, so their contexts are
bare.
