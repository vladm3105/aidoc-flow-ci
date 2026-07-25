# Migration — ci/v1.x → ci/v2.0.0

`ci/v2.0.0` unifies the AI review and doc-maintainer pipelines behind a
single OpenAI-compatible LiteLLM proxy. Vendor CLI paths, credentials, and
workflow inputs are removed. This is a **breaking change** — consumers
pinned at `@ci/v1.x` must complete the steps below before bumping to
`@ci/v2.0.0`.

## Summary of changes

| Surface | ci/v1.x | ci/v2.0.0 |
|---|---|---|
| AI gateway | Vendor CLIs (Claude, Codex) per-job | One LiteLLM proxy (`LITELLM_BASE_URL`) |
| Reviewer auth | `OPENAI_API_KEY` / `CLAUDE_CODE_OAUTH_TOKEN` secrets | `LITELLM_REVIEW_API_KEY` (scoped virtual key) |
| Doc-maintainer auth | Vendor CLI credentials | `LITELLM_DOC_API_KEY` (scoped virtual key) |
| Model selection | `reviewer:` input on callers | `litellm.model` in `.github/ai-review/config.json` |
| Reviewer adapter | Vendor CLI install on runner | Dependency-free `litellm_client.py` (fetched from canon) |

## Required consumer actions

### 1. Add LiteLLM secrets

Set per-repo (or at org level). All three are required if you use both
ai-review and doc-maintainer; `LITELLM_REVIEW_API_KEY` is the minimum.

| Secret | Scope | Required for |
|---|---|---|
| `LITELLM_BASE_URL` | API base. **On the aidoc-flow self-hosted pool this is `http://172.17.0.1:4001/v1`** — see the callout below before setting it | ai-review, doc-maintainer |
| `LITELLM_REVIEW_API_KEY` | Review-scoped virtual key | ai-review |
| `LITELLM_DOC_API_KEY` | Doc-scoped virtual key | doc-maintainer (if adopted) |

**Generating virtual keys from a running LiteLLM proxy:**

```bash
# Review-scoped (only the 'ai-reviewer' model alias)
curl -s -X POST "$LITELLM_BASE_URL/key/generate" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"models": ["ai-reviewer"], "max_budget": 50,
       "metadata": {"purpose": "ci-review"}}'

# Doc-scoped (only the 'ai-doc-maintainer' model alias)
curl -s -X POST "$LITELLM_BASE_URL/key/generate" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"models": ["ai-doc-maintainer"], "max_budget": 50,
       "metadata": {"purpose": "ci-docs"}}'
```

Set the resulting `key` value as the GitHub secret.

> [!IMPORTANT]
> **`LITELLM_BASE_URL` must be the Docker bridge gateway, not loopback.**
>
> Jobs execute *inside* an ephemeral single-use container, so `127.0.0.1` and
> `localhost` resolve to the container itself, not the host running the proxy.
> The host proxy is reachable at the bridge gateway — `http://172.17.0.1:4001/v1`
> by default.
>
> This is the single most common v2 setup failure, and it is easy to get wrong
> because `http://127.0.0.1:4001/v1` **works when you test it from the host** and
> fails only in CI. Verified from inside a job container: the bridge address
> returns `HTTP 401` on `GET /v1/models` (alive, key required — the correct
> result), while `127.0.0.1` and `localhost` are unreachable.
>
> **`litellm_allow_insecure_http: true` is determined by the URL SCHEME, not by
> repo visibility.** Any consumer whose `LITELLM_BASE_URL` begins `http://` needs
> the flag, public or private. The bridge address is plain HTTP on a private
> Docker network, so *every* consumer on the shared self-hosted pool needs it —
> and since PLAN-013 routes the whole AI flow to that pool, public repos are now
> the common case, not the exception. Without the flag, `litellm_client.py`
> rejects the scheme with `LITELLM_BASE_URL must use HTTPS (or explicitly allow
> HTTP)`. (CI-0017.)

```bash
gh secret set LITELLM_BASE_URL -R <owner>/<repo>
gh secret set LITELLM_REVIEW_API_KEY -R <owner>/<repo>
gh secret set LITELLM_DOC_API_KEY -R <owner>/<repo>
```

**Fleet batch (aidoc-flow):** to provision all consumers at once, use the helper
`install/set-litellm-secrets.sh` — it reads values from env (never argv), pipes
them to `gh` via stdin, supports `--dry-run`, `--pilot`, and a `--mint` mode that
generates a per-repo review-scoped virtual key from the master key. See its header
for usage.

### 2. Drop deprecated secrets

Remove these from consumer repo settings — they are no longer referenced
by any `ci/v2.0.0` reusable:

- `OPENAI_API_KEY`
- `CLAUDE_CODE_OAUTH_TOKEN` / `CLAUDE_CODE_API_KEY`
- Any other vendor-CLI credential used by the old ai-review path

### 3. Add `litellm.model` to consumer config

In `.github/ai-review/config.json`, add:

```json
{
  "litellm": {
    "model": "ai-reviewer"
  }
}
```

The old `reviewer:` input on caller templates is removed. Model selection is
now config-driven — the reusable reads `litellm.model` from the trusted
config. The default is `"ai-reviewer"` if absent.

### 4. Drop `reviewer:` / `model:` inputs from callers

The following inputs are **removed** from the `ci/v2.0.0` reusables and
must be dropped from consumer caller `with:` blocks:

- `reviewer:` (ai-review caller)
- Any vendor-specific model inputs
- `OPENAI_API_KEY` / vendor-CLI credential `with:` passes

### 5. Repin all callers to `@ci/v2.0.0`

```bash
CI_TAG=ci/v2.14.0 bash install.sh <owner/repo> --repin
```

`--repin` does a version-only pin bump (`@ci/vX.Y.Z` → `@ci/v2.0.0` on every
`uses:` line) without replacing files — this is the correct, complete cutover
step.

> **Do NOT run `install.sh --update` to cut over.** `--update` re-applies the
> caller template bodies and **clobbers per-repo customizations** —
> `runner_labels`, `permissions`, triggers (FT-9) — which bricks a private
> consumer's gate (jobs queue forever on the wrong runner label). Re-pin only.
> If a body refresh is ever genuinely needed, reconcile each customized field by
> hand afterward.

### 6. Verify LiteLLM connectivity

Configure both canonical aliases (`ai-reviewer`, `ai-doc-maintainer`) in the
LiteLLM proxy, then run the manual smoke test from the `aidoc-flow-ci` repo:

```bash
gh workflow run litellm-smoke.yml
```

If the smoke passes, consumers can safely bump to `@ci/v2.0.0`.

### 7. Expect new `secret-scan` findings — v2 scans full history

`secret-scan` changed scope in v2 and this was not documented until `ci/v2.15.0`:

| | v1.x | v2.x |
|---|---|---|
| Command | `gitleaks dir .` | `gitleaks git .` |
| Scope | working tree at `HEAD` | all reachable commit history |

**Validate locally with `gitleaks git .`, not `gitleaks dir .`.** Using `dir`
reproduces the v1 scope, so it returns clean while CI fails — you will push, go
red, and allowlist in a second round. A repo carrying historical placeholder
credentials at paths that no longer exist at `HEAD` surfaces them all on its
first v2 run; one consumer saw **0 findings under `dir` and 33 under `git`**.

Findings in unreachable history cannot be fixed by editing files — allowlist
them in `.gitleaks.toml` with an **anchored** `paths` regex (e.g.
`'^tests/fixtures/'`). An unanchored allowlist that matches everything is
detected and reported INCONCLUSIVE by the config canary, because it would also
suppress real findings. The scope expansion itself is deliberate and is an
improvement; only its documentation was missing. (CI-0016.)

## Rollback

To revert a consumer from `ci/v2.0.0` to the last `ci/v1.x` tag:

```bash
CI_TAG=ci/v2.14.0 bash install.sh <owner/repo> --repin
```

Then restore the deprecated vendor-CLI secrets and drop the LiteLLM secrets.
The `ci/v1.x` reusables still reference the old secret names.
