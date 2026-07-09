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
|---|---|---|---|
| Secret | `APP_REVIEWER_1_ID` | the reviewer App's numeric **App ID** | `ai-review.yml` + `auto-merge-ai-prs.yml` (mint installation token) |
| Secret | `APP_REVIEWER_1_KEY` | the reviewer App's **private key** (full PEM, incl. BEGIN/END lines) | same |
| Secret | one reviewer-auth token | `CLAUDE_CODE_OAUTH_TOKEN` (Claude subscription — preferred, free on Pro/Max) **or** `ANTHROPIC_API_KEY` (Claude pay-per-token) **or** `OPENAI_API_KEY` (codex) | the "Run review" step exports it to the reviewer CLI |
| Variable | `APP_REVIEWER_1_BOT_ID` | the App's **bot-user** numeric id (NOT the App ID) | `composition.yml` + the R3 early-exit — matches the App's APPROVED review by `user.id` |

Secrets can be set at the **repo** level (`gh secret set … --repo`) or
inherited from an **org** secret; the variable is per-repo (`gh variable
set …`).

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
   # ONE reviewer-auth token (pick per your reviewer vendor):
   gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo <owner>/<repo> --body "<token>"
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
