# Security — `aidoc-flow-ci`

Threat model, trust boundaries, fork-PR handling, secrets model,
and the rationale for `pull_request_target` vs `pull_request`
choices. Honest framing where the design accepts risks; pointers
to mitigations.

For the workflow architecture, see
[`architecture.md`](architecture.md). For label conventions
(including the visibility routing rule), see
[`../LABELS.md`](../LABELS.md).

## 1. Threat model — what we defend against

| Threat | Surface |
|---|---|
| **Untrusted fork PR runs malicious code on the reviewer runner** | `ai-review` heavy job on PUBLIC repos with self-hosted runners |
| **Untrusted fork PR exfiltrates secrets via `pull_request_target` context** | `ai-review` + `composition` + any workflow with `pull_request_target` and `secrets: inherit` |
| **Compromised GitHub Action transitive-dependency leaks/replaces code** | All workflows; mitigation = SHA-pinning |
| **Reviewer App credentials leak via runner logs** | `ai-review` heavy job (token-minting step) |
| **Secret committed to repo and silently merged** | All PRs; mitigation = `secret-scan` workflow (gitleaks PR gate) |
| **Workflow file itself is malicious (consumer caller)** | Consumer repo CODEOWNERS protects `.github/` |
| **Reusable workflow upstream change silently breaks consumers** | Pinning to `ci/vX.Y.Z` tags (not `@main`) — see [`architecture.md`](architecture.md) §6 |

## 2. Trust boundaries

### 2.1 PR author trust (the trust gate)

Every PR runs the **`trust` job first** (in `ai-review.yml`). It
reads `.github/ai-review/config.json` from the BASE ref (not the
PR head — a PR cannot tamper with it). The config has two
allowlists:

```jsonc
{
  "trust": {
    "ai_review": ["vladm3105", "trusted-contributor-1"],
    "auto_fix":  []
  }
}
```

- `trust.ai_review` — authors whose PRs trigger the heavy reviewer.
- `trust.auto_fix` — authors whose PRs ALSO trigger the auto-fix
  pipeline (IPLAN-0014; default-off).

Non-allowlisted authors (incl. all fork authors) hit
`HUMAN-REVIEW-ONLY` path:

- `trust` job applies `ai:human-review-required` label.
- Heavy `ai-review` job is **skipped entirely**.
- `composition` exempts these PRs (it would otherwise block — no
  App approval exists).
- A human reviews + merges manually.

### 2.2 Fork-PR handling

Fork PRs always go through `HUMAN-REVIEW-ONLY` path regardless of
the author's allowlist status:

```jsonc
// ai-review.yml trust step (pseudo-logic)
if pr.head.repo.fork:
    label "ai:human-review-required"
    skip heavy reviewer
    exit 0
```

This is the **safe default** for the
self-hosted-runner-on-public-repo concern (see §3 below).

### 2.3 Branch-protection trust (composition as required check)

`composition` is the **sole identity enforcement** for App
approvals. GitHub Apps cannot be CODEOWNERS and cannot be
request_reviewers'd, so "require review from Code Owners" can't
make the App's approval *required*. `composition` encodes that
rule instead: on a routine PR it is GREEN only when, at the
current head SHA, an APPROVED review exists from the reviewer
App — matched on the App's bot-user **NUMERIC id** (the login
string is spoofable) + `user.type == "Bot"`.

This is why `composition` must stay in branch protection's
required-checks set — removing it is a governance change.

## 3. Self-hosted runners on PUBLIC repos — accepted risk

[GitHub's documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security)
explicitly recommends AGAINST self-hosted runners on public
repos:

> "We recommend that you only use self-hosted runners with
> private repositories. This is because forks of your public
> repository can potentially run dangerous code on your
> self-hosted runner machine by creating a pull request that
> executes the code in a workflow."

**Our routing rule (per [`../LABELS.md`](../LABELS.md) §2 +
[`runners.md`](runners.md) §4) follows GitHub's recommendation:**

- **PRIVATE repos** use `runner-self` (self-hosted) — no fork
  concern; safe per GitHub's guidance.
- **PUBLIC repos** use `ubuntu-latest` (GitHub-hosted) — GitHub's
  recommended path; no self-hosted exposure.

If a future consumer needs self-hosted for a PUBLIC repo
(unusual case — e.g., requires GPU or large workspace), the
mitigation is:

1. The trust gate ensures fork-PR code **never reaches the
   self-hosted reviewer job** (HUMAN-REVIEW-ONLY route).
2. The reusable workflow body **never executes PR code** — it
   reads PR-diff metadata via `gh api` only; the reviewer CLI
   analyzes the diff as text, not as executable code.
3. Even with both above, this is **accepted-risk, not GitHub-
   recommended**. Document the deviation in the consumer's
   CLAUDE.md.

See operations IPLAN-0017 §5 (Risks) + §7 claim C9 for the formal
risk + mitigation record.

## 4. Secrets model

### 4.1 `secrets: inherit` (the typical caller pattern)

Consumer callers typically use:

```yaml
jobs:
  call:
    uses: vladm3105/aidoc-flow-ci/.github/workflows/ai-review.yml@ci/v1.0.0
    secrets: inherit   # passes all consumer-repo secrets to reusable
```

The reusable workflow declares the secrets it uses
(`APP_REVIEWER_1_ID`, `APP_REVIEWER_1_KEY`, etc.) at the top of
the workflow file (`secrets:` block in `on: workflow_call:`).
`inherit` passes them through; the reusable workflow can also
explicitly accept them via the `secrets:` block.

### 4.2 What secrets the workflows need

| Workflow | Secrets required |
|---|---|
| `ai-review` | `APP_REVIEWER_1_ID` + `APP_REVIEWER_1_KEY` (the reviewer App's credentials; consumer sets these once after App install per F5 blast-radius rule) |
| `composition` | None beyond `GITHUB_TOKEN` (auto-provided by Actions) |
| `labeler` | None beyond `GITHUB_TOKEN` |
| `codeql` | None beyond `GITHUB_TOKEN` |
| `markdown-lint` | None beyond `GITHUB_TOKEN` |
| `links` | None beyond `GITHUB_TOKEN` (passed to lychee to avoid GH rate limits on github.com URLs) |
| `secret-scan` | None beyond `GITHUB_TOKEN` |

### 4.3 Secret-name convention (v1.0.0 limitation)

The `APP_REVIEWER_1_*` names are **hardcoded** in
`ai-review.yml`'s body. Consumers using non-default names would
need to fork. v1.0.1+ may add `app_id_secret_name` /
`app_key_secret_name` inputs IF consumers actually need
non-default names. See
[`../README.md`](../README.md) "v1.0.0 known limitations".

## 5. `pull_request_target` vs `pull_request` — why `_target`

`ai-review` uses `pull_request_target` (not `pull_request`). The
choice has a security reason:

| Trigger | Secrets on fork PR? | Write permissions on fork PR? | Workflow code from | PR code checked out? |
|---|---|---|---|---|
| `pull_request` | ❌ (no secrets on fork PRs) | ❌ (read-only on fork PRs) | PR head | YES (default) |
| `pull_request_target` | ✅ (full secrets) | ✅ (write) | BASE ref (trusted) | NO (unless explicit `checkout` with `ref: head.sha`) |

`pull_request_target` is required because:

- The `trust` job needs **write permissions** to apply labels +
  post review comments on fork PRs (impossible under
  `pull_request`).
- The reusable workflow + config are **read from BASE ref**
  (trusted main), so a PR cannot tamper with them — the
  governance + trust-gate logic is locked.
- The reusable workflow **never checks out PR code** — it only
  reads PR-diff metadata via `gh api`. So `pull_request_target`'s
  "elevated privileges" don't translate into running fork code.

This is the **standard pattern** for fork-PR-safe automation
(per [GitHub's `pull_request_target`
docs](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows#pull_request_target)).

### Composition no longer uses `pull_request_target` (ci/v1.3.0+)

`composition` originally used `pull_request_target` for the same
reasons (write to apply labels; BASE-ref governance). IPLAN-0026
Phase 2 (ci/v1.3.0) dropped that trigger from the install template:
composition is now driven by `pull_request_review` (App's APPROVED
review submission) and `workflow_run` (consumer's `ai-review` caller
completing — any conclusion). Both triggers carry the same BASE-ref
+ secrets posture as `pull_request_target` (workflow code from
default branch; secrets available; no PR code checked out), so the
security analysis above still applies — composition never executed
fork code under `pull_request_target` either. The Phase-2 drop is
about eliminating the early-fire stale-red merge-friction pattern,
not about changing the security model. Existing consumers that have
a flow dependent on the old trigger can still locally re-add it
(local always wins per `docs/overrides.md`).

## 6. SHA-pinning external Actions

Every `uses:` line in the shared workflows pins to a **40-char SHA**
with the version tag in a trailing comment:

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
- uses: github/codeql-action/init@21eb7f7842f33eafc83782b56fff2a2c43e9696f # v4.36.1
- uses: gacts/gitleaks@c9a0338361dc45a01aa7ebaaa5330179f3c62873 # v1.3.2
- uses: lycheeverse/lychee-action@885c65f3dc543b57c898c8099f4e08c8afd178a2 # v2.6.1
```

This protects against compromised-action attacks (a malicious
maintainer can move a tag like `v4` to point at a malicious
commit; SHA-pinning makes the dependency immutable).

**Verifying SHA-pins:** any new `uses:` line MUST verify the SHA
via `gh api repos/<owner>/<repo>/git/refs/tags/<tag>` before
shipping. Research subagents and search snippets can fabricate
plausible-looking SHAs that don't resolve to real commits. The
operations memory entry `feedback_verify_sha_pins` records the
W2 incident where 4 of 7 SHAs were fabricated and required a
fix-up sweep. `actionlint` catches non-resolving SHAs with an
`Unable to resolve action 'owner/repo@<sha>'` diagnostic.

## 7. The secret-scan layered defense

`secret-scan.yml` (gitleaks) is one layer in a defense-in-depth
stack:

| Layer | Tool | Speed | Coverage |
|---|---|---|---|
| Pre-commit (local) | gitleaks `protect --staged` | Sub-second | Diff only; offline |
| **PR CI gate (this workflow)** | **`gacts/gitleaks` (MIT)** | ~30-60s | Full clone; blocks merge |
| Scheduled | trufflehog | Slower | Adds live-credential verification (kills false positives) |
| Platform | GitHub Secret Scanning + push protection | Real-time | Provider-partner program auto-revokes leaked tokens |

Consumers ideally enable all 4 layers. `aidoc-flow-ci` only ships
the CI-gate layer (`secret-scan.yml`); the others are per-consumer
infra.

### Why `gacts/gitleaks` not `gitleaks/gitleaks-action`?

The official `gitleaks/gitleaks-action` switched to a proprietary
EULA at v2.0.0 (May 2026). Org-owned repos (including OSS)
require a paid license key. `gacts/gitleaks` is the **MIT-licensed
community wrapper** — same `gitleaks` binary underneath, no
license key, no signup. The CMS OSPO guide
([dsacms.github.io](https://dsacms.github.io/ospo-guide/resources/gitleaks-action-license/))
explicitly points to `gacts/gitleaks` for this use case.

## 8. Reporting security issues

This repo is the shared CI library, not a product with customer
data. Security issues in the workflows themselves (compromised
SHAs, leaked credentials, fork-PR escape paths) should be reported
via:

1. GitHub Security Advisory on `vladm3105/aidoc-flow-ci`
   (preferred — private, coordinated disclosure)
2. Direct contact with the maintainer (see
   [`../README.md`](../README.md))

Do NOT open a public issue for a security report. Use the Advisory
path so any vulnerability is fixed before disclosure.

## 9. References

- [GitHub Docs — About self-hosted runners (security)](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security)
- [GitHub Docs — `pull_request_target` event](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/events-that-trigger-workflows#pull_request_target)
- [GitHub Docs — SHA-pinning for actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#using-third-party-actions)
- [`aidoc-flow-operations` `ops/iplans/IPLAN-0017_unified-ci-flows.md`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017_unified-ci-flows.md) §5 (Risks) + §7 claim C9
- [CMS OSPO guide — gitleaks-action license](https://dsacms.github.io/ospo-guide/resources/gitleaks-action-license/)
