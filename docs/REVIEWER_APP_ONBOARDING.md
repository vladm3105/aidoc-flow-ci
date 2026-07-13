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
| Secret | `LITELLM_BASE_URL` | OpenAI-compatible LiteLLM proxy URL, normally ending in `/v1` | AI execution |
| Secret | `LITELLM_REVIEW_API_KEY` | virtual key restricted to the review alias | `ai-review` |
| Secret | `LITELLM_DOC_API_KEY` | virtual key restricted to the documentation alias | `doc-maintainer` |
| Variable | `APP_REVIEWER_1_BOT_ID` | the App's **bot-user** numeric id (NOT the App ID) | `composition.yml` + the R3 early-exit — matches the App's APPROVED review by `user.id` |

Secrets can be set at the **repo** level (`gh secret set … --repo`) or
inherited from an **org** secret; the variable is per-repo (`gh variable
set …`).

## LiteLLM model alias (config-driven)

Which model reviews PRs is config-driven. The reusable resolves it as:

**caller `model:` input** (if set) → **`.litellm.model` in the trust-config
repo's `.github/ai-review/config.json`**.

- **aidoc-flow consumers** read the alias from **`operations@main`**'s config
  (the default `trust_config_repo`).
- **External adopters** (who set `trust_config_repo` to their own repo) read
  `.litellm.model` from their own config (template default `ai-reviewer`).
- **Per-repo force:** set caller input `model` to override trusted config.

Provider credentials and routing remain inside LiteLLM. CI receives only the
proxy URL and a scoped virtual key.

Use a review-specific virtual key restricted to the `ai-reviewer` alias, with
spend/rate limits and rotation. Never use the LiteLLM master key. Disable
sensitive request/response logging and configure retention appropriately:
review sends a bounded, secret-pattern-redacted diff, but it still contains
private source code. HTTPS is mandatory unless the caller explicitly opts into
HTTP for a controlled private network.

Doc-maintainer uses a separate scoped key and sends redacted PR metadata,
patches, conventions, and redacted current documentation. Secret-shaped source
values are replaced with opaque tokens during inference and restored only
afterward; token loss or duplication fails closed.

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

   **App-native trust-fetch (ci/v1.9.1+):** also install the App on the
   **`trust_config_repo`** (`aidoc-flow-operations`) with **`contents: read`**.
   Then the consumer needs **no `AI_REVIEW_TOKEN`** — the trust/review jobs mint
   an App installation token to read the trust config (precedence: App token →
   `AI_REVIEW_TOKEN` → `GITHUB_TOKEN`). A pre-flight verifies the App can read the
   config and falls back to the PAT if not, so this is safe to leave enabled.
   Consumers that keep `AI_REVIEW_TOKEN` are unaffected.

4. **Set the secrets** on the consumer:

   ```bash
   gh secret set APP_REVIEWER_1_ID  --repo <owner>/<repo> --body "<app-id>"
   gh secret set APP_REVIEWER_1_KEY --repo <owner>/<repo> < path/to/private-key.pem
   gh secret set LITELLM_BASE_URL       --repo <owner>/<repo> --body "https://litellm.example/v1"
   gh secret set LITELLM_REVIEW_API_KEY --repo <owner>/<repo> --body "<review-scoped-key>"
   gh secret set LITELLM_DOC_API_KEY    --repo <owner>/<repo> --body "<documentation-scoped-key>"
   ```

   Before cutting or adopting the release, dispatch the `LiteLLM agent smoke`
   workflow on the target ref. It calls both aliases with their separate keys.

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
- **`.litellm.model`** — the LiteLLM model alias used for review.
- **`.auto_merge.repos`** — **required to enable the auto-merge enforcer.**
  ⚠️ `config.json.template` ships **without** an `auto_merge.repos` key, and the
  enforcer fail-closes (disables itself) when it's absent or not an array. If
  you want auto-merge, add `"auto_merge": { "repos": ["your-org/your-repo"] }`
  (the repos you allow to auto-merge) to that config.

Public and private callers use the same HTTP adapter. Public runners require
network reachability to the proxy; private runners may use an internal URL.

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
