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
4. `CI_TAG=ci/v2.5.0 bash install.sh <owner/repo> --repin` then `--update`
5. Verify LiteLLM connectivity (smoke test) before merging the consumer PR
