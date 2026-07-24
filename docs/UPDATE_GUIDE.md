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
   de-branding placeholders (`${CODEOWNER_HANDLE}`, `${CANON_*_URL}` — pass
   `--codeowner` / `--canon-*-url` to match what the consumer installed
   with), and `diff -u`s it against the local file.
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

| | `--repin` | `--update` |
| --- | --- | --- |
| changes | the `@ci/vX.Y.Z` string, nothing else | the whole **body** of every `safe_to_replace` file |
| consumer customization | preserved by construction | **replaced** (16 surfaces: all 15 workflow callers + `dependabot.yml`) |
| use for | picking up a new canon *version* | adopting a canon *topology* change (new job, changed inputs) |

**Default to `--repin`.** A consumer that only needs the new canon version
never needs `--update`. Body adoption is the exception, taken deliberately when
canon's caller *shape* changed and the consumer must follow.

### What body adoption drops

A caller file is where a consumer records everything repo-specific about *how*
canon runs for them. Replacing the body discards all of it:

- **`runner_labels_*`** — the big one. Live example: `framework`'s ai-review
  caller pins `runner_labels_routine: '"ubuntu-latest"'`, while the canon
  template ships `'["self-hosted", "ci-runner", "single-use"]'`. A
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
   - private repos: every job on `["self-hosted", "ci-runner", "single-use"]`,
     never `ubuntu-latest`;
   - public repos: the **fork-code-executing** lint callers
     (`markdown-lint`, `links`, `pre-commit`) stay on `ubuntu-latest`; only
     the AI flows run on the pool.
5. **Open the consumer PR and let its own CI prove it.** A bricked runner
   label shows up as jobs stuck in `queued` — treat any never-starting job as
   a failed reconciliation, not a flaky runner.

If a repo needs only the version, stop reading here and use `--repin`.

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

## ci/v1.x → ci/v2.0.0 breaking-change migration

The `ci/v2.0.0` release replaces vendor CLIs with a unified LiteLLM proxy.
This is a breaking change — consumers must complete additional steps beyond
a normal `--update` or `--repin` cycle. Read the full migration guide:

- [`docs/MIGRATION_v2.0.0.md`](MIGRATION_v2.0.0.md) — complete checklist
  (new secrets, removed inputs, config changes, repin, smoke test)

Quick-reference:

1. Add `LITELLM_BASE_URL` + `LITELLM_REVIEW_API_KEY` secrets
2. Add `"litellm": {"model": "ai-reviewer"}` to `.github/ai-review/config.json`
3. Drop deprecated vendor-CLI secrets (`OPENAI_API_KEY`, etc.)
4. `CI_TAG=ci/v2.13.0 bash install.sh <owner/repo> --repin` — and **only add
   `--update` if this consumer actually needs canon's new caller bodies**. The
   `v2.0.0` migration itself does not: it is secrets + config + a **hand-edit of
   the caller's `with:` block** (drop the removed `reviewer:` / vendor-model
   inputs — see `MIGRATION_v2.0.0.md` §4) + a pin bump.
   Running `--update` here replaces all 16 replaceable surfaces and discards the
   repo's `runner_labels_*` and `permissions:` — see
   [Body adoption vs re-pin](#body-adoption-vs-re-pin--pick-the-right-operation-first)
   and reconcile the diff before committing.
5. Verify LiteLLM connectivity (smoke test) before merging the consumer PR
