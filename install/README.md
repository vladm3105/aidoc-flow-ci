# install/

One-shot bootstrap for a consumer repo. Drops default workflow callers +
config + labels with safe defaults, then prints next steps for the
founder. Preserves any existing files (local override always wins).

## Run it

```bash
# Latest pinned tag (ci/v1.0.0) — adjust as new tags ship:
bash <(curl -fsSL https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v1.0.0/install/install.sh) \
  vladm3105/<consumer-repo> --visibility private

# Or override the tag:
CI_TAG=ci/v1.0.1 bash install.sh vladm3105/<consumer-repo> --visibility public
```

## What it does

1. Clones the consumer repo to `$PWD/aidoc-flow-ci-bootstrap-$$/consumer`
   (stable; not auto-deleted — you need to inspect + commit after exit).
2. Drops `.github/workflows/ai-review.yml` + `composition.yml` (per-visibility
   templates from `templates/workflows/`). Preserves any existing local files.
3. Drops `.github/ai-review/config.json` (the per-repo policy). Preserves
   existing.
4. Creates the canonical 5 labels (`ai:review-passed` / `ai:review-changes` /
   `ai:human-review-required` / `skip-ai-review` / `ai:autofix-applied`) on
   the consumer repo via `gh label create`. Idempotent + fail-loud.

## What it does NOT do

- Doesn't add secrets (consumer adds `APP_REVIEWER_1_ID` / `APP_REVIEWER_1_KEY`
  manually — these are founder actions).
- Doesn't change branch protection (founder).
- Doesn't install the GitHub App on the consumer repo (founder per F5
  "Only select repositories" blast-radius rule).
- Doesn't overwrite existing workflow files (preserve = local override always
  wins).

## v1.0.0 known limitations

- **Public consumers**: `runner_labels_review` ships as a `REPLACE-ME-with-
  runner-having-reviewer-CLI` placeholder. The reusable workflow body invokes
  `codex` / `claude` CLI directly; GitHub-hosted `ubuntu-latest` does NOT have
  those installed + authenticated. Public consumers MUST point at a self-
  hosted runner with the CLI until v1.0.1 ships explicit install + auth
  steps for the GitHub-hosted path.
- **Secret names hardcoded** to `APP_REVIEWER_1_ID` / `APP_REVIEWER_1_KEY` —
  v1.0.0 doesn't parameterize. v1.0.1+ may add `app_id_secret_name` /
  `app_key_secret_name` inputs IF consumers actually need non-default names.
