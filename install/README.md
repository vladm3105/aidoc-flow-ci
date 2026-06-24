# install/

One-shot bootstrap for a consumer repo. Drops default workflow callers +
config + labels with safe defaults, then prints next steps for the
founder. Preserves any existing files (local override always wins).

## Run it

```bash
# Latest pinned tag (ci/v1.0.6) — adjust as new tags ship:
bash <(curl -fsSL https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v1.0.6/install/install.sh) \
  vladm3105/<consumer-repo> --visibility private

# Or override the tag:
CI_TAG=ci/v1.0.6 bash install.sh vladm3105/<consumer-repo> --visibility public
```

## What it does

1. Clones the consumer repo to `$PWD/aidoc-flow-ci-bootstrap-$$/consumer`
   (stable; not auto-deleted — you need to inspect + commit after exit).
2. Drops `.github/workflows/ai-review.yml` + `composition.yml` (per-visibility
   templates from `templates/workflows/`). Preserves any existing local files.
3. Drops `.github/ai-review/config.json` (the per-repo policy). Preserves
   existing.
4. Creates the canonical labels on the consumer repo via `gh label create`:
   5 state/control labels (`ai:review-passed` / `ai:review-changes` /
   `ai:human-review-required` / `skip-ai-review` / `ai:autofix-applied`)
   plus 4 area labels added in `ci/v1.0.1` (`area: ci` / `area: governance`
   / `area: deps` / `area: tests`). Idempotent + fail-loud (per-PR-#116
   fix: prefetches existing labels, exits nonzero on real failures).
5. (Optional) consumers can also drop the 5 additional caller templates
   shipped in `ci/v1.0.1` (`labeler.yml` / `codeql.yml` /
   `markdown-lint.yml` / `links.yml` / `secret-scan.yml`) — these are NOT
   bootstrapped automatically; consumer chooses which to adopt.

## What it does NOT do

- Doesn't add secrets (consumer adds `APP_REVIEWER_1_ID` / `APP_REVIEWER_1_KEY`
  manually — these are founder actions).
- Doesn't change branch protection (founder).
- Doesn't install the GitHub App on the consumer repo (founder per F5
  "Only select repositories" blast-radius rule).
- Doesn't overwrite existing workflow files (preserve = local override always
  wins).

## v1.0.6 known limitations

- **ubuntu-latest CLI install validated end-to-end** on framework Phase A
  activation (2026-06-24). Reviewer auth env vars
  (`CLAUDE_CODE_OAUTH_TOKEN` / `ANTHROPIC_API_KEY` / `OPENAI_API_KEY`)
  are explicitly exported as of `ci/v1.0.5` (earlier `secrets: inherit`
  gap fixed). Required consumer-side: ONE of
  `CLAUDE_CODE_OAUTH_TOKEN` (claude subscription auth — preferred,
  free under Pro/Max plans) / `ANTHROPIC_API_KEY` (claude pay-per-token)
  / `OPENAI_API_KEY` (codex pay-per-token).
- **Secret names hardcoded** to `APP_REVIEWER_1_ID` / `APP_REVIEWER_1_KEY` —
  v1.0.6 doesn't parameterize. v1.1.0+ may add inputs IF consumers
  need non-default names.

### Per-consumer prerequisites (discovered during framework Phase A)

After `install.sh` runs, two additional consumer-side settings are
required for the reusable workflow to start:

| Setting | Why | Doc |
|---|---|---|
| **Actions allowlist** | If consumer is in `selected actions` mode (`gh api repos/<c>/actions/permissions`), `vladm3105/aidoc-flow-ci/*` must be in `patterns_allowed` or the reusable workflow returns `startup_failure` | [`../docs/troubleshooting.md` §13](../docs/troubleshooting.md#13-startup_failure--reusable-workflow-blocked-by-consumers-actions-allowlist) |
| **Caller `permissions:` block** | If consumer's repo-default `workflow_permissions: read` (`gh api repos/<c>/actions/permissions/workflow`), the reusable's `contents: write` declaration is rejected — add an explicit `permissions:` block to the caller workflow | [`../docs/troubleshooting.md` §14](../docs/troubleshooting.md#14-startup_failure--callers-workflow_permissions-read-blocks-reusables-write) |

See [`../docs/troubleshooting.md`](../docs/troubleshooting.md) for the
14-section troubleshooting guide.
