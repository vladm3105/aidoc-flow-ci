# Reviewer App onboarding

`ai-review.yml` submits its verdict as a **GitHub App** review, not as
`github-actions[bot]`. This is deliberate: a GitHub App *can* submit a
COUNTING approval that `composition.yml` matches by numeric bot id and
that branch protection can require, whereas `github-actions[bot]` cannot
approve a PR. Without the App wired, ai-review runs in **comment-only**
(inert) mode — it posts a verdict comment but nothing gates merge.

This doc is the one-time setup to arm the reviewer App on a consumer
repo. These are **founder / admin actions** (App install has F5
blast-radius — "only select repositories"); an AI agent prepares this
checklist but does not perform it.

> Canonical activation checklist + F5 rules live in
> `aidoc-flow-operations` `docs/REPO_ONBOARDING.md`. This doc is the
> aidoc-flow-ci-side reference for what each secret/variable is and how
> the workflow consumes it.

## What you provision

| Kind | Name | What it is | Consumed at |
| --- | --- | --- | --- |
| Secret | `APP_REVIEWER_1_ID` | the reviewer App's numeric **App ID** | `ai-review.yml` + `auto-merge-ai-prs.yml` (mint installation token) |
| Secret | `APP_REVIEWER_1_KEY` | the reviewer App's **private key** (full PEM, incl. BEGIN/END lines) | same |
| Secret | one reviewer-auth token — **must match your `.reviewer` engine** (see "Reviewer engine" below) | for `.reviewer: claude` → `CLAUDE_CODE_OAUTH_TOKEN` (Claude subscription CLI, free on Pro/Max) **or** `ANTHROPIC_API_KEY` (Claude API, pay-per-token); for `.reviewer: codex` → `OPENAI_API_KEY` | the "Run review" step exports it to the reviewer CLI/API |
| Variable | `APP_REVIEWER_1_BOT_ID` | the App's **bot-user** numeric id (NOT the App ID) | `composition.yml` + the R3 early-exit — matches the App's APPROVED review by `user.id` |

Secrets can be set at the **repo** level (`gh secret set … --repo`) or
inherited from an **org** secret; the variable is per-repo (`gh variable
set …`).

## Reviewer engine (config-driven)

Which engine reviews PRs is **config-driven**, not hardcoded in the caller
(PLAN-005 PR-D). The reusable resolves the engine as:

**caller `reviewer:` input** (if set) → **`.reviewer` in the trust-config
repo's `.github/ai-review/config.json`** → **`codex` fallback**.

- **aidoc-flow consumers** read the engine from **`operations@main`**'s
  config (the default `trust_config_repo`). To change the workspace default,
  set `.reviewer` there — until then it falls back to `codex`.
- **External adopters** (who set `trust_config_repo` to their own repo) read
  `.reviewer` from **their own** `config.json` (shipped from
  `config.json.template`, default `"codex"`).
- **Per-repo force:** uncomment `reviewer: claude` (or `codex`) in the caller
  to override config entirely.

**The auth token you set MUST match the resolved engine** — otherwise the
reviewer CLI/API can't authenticate (the "App set, engine key wrong" failure):

| `.reviewer` | Auth secret (set ONE) |
| --- | --- |
| `claude` | `CLAUDE_CODE_OAUTH_TOKEN` (subscription CLI, free on Pro/Max) **or** `ANTHROPIC_API_KEY` (API) |
| `codex` | `OPENAI_API_KEY` (API) |

## Steps

1. **Create (or locate) the reviewer App.** One App per org — the
   aidoc-flow workspace uses `aidoc-reviewer`
   (`https://github.com/settings/apps/aidoc-reviewer`). If starting a new
   org, create a GitHub App with these **repository permissions**:
   - **Pull requests: Read and write** — submit reviews + set labels.
   - **Contents: Read and write** — required for auto-merge arming (a
     missing Contents:write is the common cause of ai-review falling back
     to `GITHUB_TOKEN`, which suppresses downstream push workflows).
   - **Issues: Read and write** — label create/apply paths.
   - **Metadata: Read-only** (default).

2. **Generate the App private key** (App settings → Private keys →
   Generate) and download the PEM.

3. **Install the App on the consumer repo** — App settings → Install App
   → select the repo (only-select-repositories, per F5).

4. **Set the secrets** on the consumer:

   ```bash
   gh secret set APP_REVIEWER_1_ID  --repo <owner>/<repo> --body "<app-id>"
   gh secret set APP_REVIEWER_1_KEY --repo <owner>/<repo> < path/to/private-key.pem
   # ONE reviewer-auth token — MUST match your resolved `.reviewer` engine (see above).
   # The default engine is `codex` (the config fallback) → set OPENAI_API_KEY:
   gh secret set OPENAI_API_KEY --repo <owner>/<repo> --body "<token>"
   #   if you set `.reviewer: claude` instead → CLAUDE_CODE_OAUTH_TOKEN (CLI) or ANTHROPIC_API_KEY (API):
   # gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner>/<repo> --body "<token>"
   ```

5. **Open a first PR** from an allowlisted author (a login in
   `operations@main` `.github/ai-review/config.json` `trust.ai_review`).
   ai-review runs and the App submits a review. Until step 6 the App
   works, but `composition` cannot yet match its identity.

6. **Capture the App's bot-user id and set the variable.** The App's
   *bot user* id is different from the App ID; read it from the review it
   just submitted:

   ```bash
   gh api repos/<owner>/<repo>/pulls/<pr>/reviews \
     --jq '.[] | select(.user.type=="Bot") | {login:.user.login, id:.user.id}'
   gh variable set APP_REVIEWER_1_BOT_ID --repo <owner>/<repo> --body "<id>"
   ```

7. **Make `composition` enforce it** — add `call / composition` (and the
   rest of the tier's required checks) to branch protection. See
   [`BRANCH_PROTECTION.md`](BRANCH_PROTECTION.md).

## External adopters (outside the aidoc-flow workspace)

By default the trust config is read from `vladm3105/aidoc-flow-operations@main`
— a private repo you can't read. Point it at your **own** ops/config repo
instead (the override already ships in the caller templates as commented
`trust_config_repo:` / `trust_config_ref:` lines — uncomment them). Set it on
**both** the `ai-review` **and** `auto-merge-ai-prs` callers so the review
gate and the merge enforcer read the same allowlist:

```yaml
with:
  trust_config_repo: your-org/your-ops-repo
  trust_config_ref: main
```

That repo's `.github/ai-review/config.json` must carry:

- **`.trust.ai_review`** — the login allowlist (who may be auto-reviewed).
- **`.reviewer`** — your engine (`claude` | `codex`); see "Reviewer engine".
- **`.auto_merge.repos`** — **required to enable the auto-merge enforcer.**
  ⚠️ `config.json.template` ships **without** an `auto_merge.repos` key, and the
  enforcer fail-closes (disables itself) when it's absent or not an array. If
  you want auto-merge, add `"auto_merge": { "repos": ["your-org/your-repo"] }`
  (the repos you allow to auto-merge) to that config.

**Public-runner reviewer path is EXPERIMENTAL.** The public caller installs the
reviewer CLI at workflow start on `ubuntu-latest` (per `ci/v1.0.2+`); that path
is not yet verified end-to-end in CI. Treat public-runner review as
experimental until you've confirmed a green run in your own public repo; the
private (self-hosted, CLI-pre-baked) path is the verified one.

## Verifying it's armed

- A routine PR gets an **APPROVED review by the App** (not just a
  comment) and the `ai:review-passed` label.
- `composition` (`call / composition`) resolves SUCCESS at the PR HEAD.
- If you still see only a comment + `::notice::` about "App not
  configured", re-check that `APP_REVIEWER_1_KEY` is the full PEM and the
  App is installed on this specific repo.

## Related

- [`ai-review-assets.md`](ai-review-assets.md) — the rubric + verdict
  schema the reviewer uses.
- [`security.md`](security.md) — the trust model, why the App token is
  minted per-run + auto-revoked, and the two-job fork-safety split.
- `.github/workflows/ai-review.yml` — the "Mint reviewer App token" +
  "Gate · comment · label · merge" steps that consume the above.
