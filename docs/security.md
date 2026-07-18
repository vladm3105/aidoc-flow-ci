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
- `trust.auto_fix` — authors whose PRs ALSO trigger autofix
  (PLAN-012; default-off — see §3b).

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

## 3. Self-hosted runners on PUBLIC repos — the AI-flows vs. the lint flows

[GitHub's documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security)
recommends AGAINST self-hosted runners on public repos:

> "We recommend that you only use self-hosted runners with
> private repositories. This is because forks of your public
> repository can potentially run dangerous code on your
> self-hosted runner machine by creating a pull request that
> executes the code in a workflow."

The load-bearing word is **"executes."** GitHub's warning is about a fork PR
running *untrusted code* on your runner. Whether self-hosted-on-public is safe
therefore depends entirely on whether a fork can reach a job that **executes PR
code** — and that differs between the two classes of flow.

**The AI-flows are safe on self-hosted, public OR private (PLAN-013).** The
uniform protected model runs `ai-review`, `doc-maintainer`, and `docs-sync`
(and `autofix`, a gated job within `ai-review` — PLAN-012, §3b) on the ephemeral self-hosted single-use
pool on every repo, with **no `-public`/`-private` split** (so a visibility flip
is a no-op). This is safe because **a fork never reaches a job that executes PR
code**:

- `ai-review` (`pull_request_target`): a fork PR triggers ONLY the `trust` job,
  which checks out the **trusted config repo** (never the PR head) and reads PR
  metadata — it runs **zero PR code**. The heavy review job is `needs: trust`-gated
  and forks are **never trusted**, so a fork never reaches it. `autofix` is
  likewise trust-gated (forks excluded).
- `doc-maintainer` + `docs-sync` are **post-merge** (`push: main`) — a fork PR
  cannot trigger them at all.

So the only fork-triggered work on the pool is the no-PR-code trust decision on an
isolated `--rm` container. This is **not** the "untrusted code on your box" case
GitHub warns about. (It does rest on two invariants that MUST hold: forks stay
trust-excluded, and the trust job takes no fork-controlled string into a shell
except via `env:` with a charset-safe value — see PLAN-013 §3.)

**The generic lint flows must STAY GitHub-hosted on public repos.** `markdown-lint`,
`links`, and `pre-commit` (all `on: pull_request`) **run the PR's own files,
including a fork's** — exactly the case GitHub's warning covers. Their
`-public`/`-private` split is therefore correct and must be kept: `ubuntu-latest`
on public, self-hosted on private. **Never converge a fork-code-executing lint flow
to self-hosted on a public repo** — that would create the very leak this section
warns about.

Residual on the AI-flows: fork PRs on a public repo each trigger a (fast, no-code)
trust job on our pool, so pool capacity must absorb public-fork volume
(`concurrency: cancel-in-progress` collapses same-PR pushes; sizing is an ops item).

See operations IPLAN-0017 §5 (Risks) + §7 claim C9 for the original risk record;
this section supersedes its "accepted-risk-only" framing for the AI-flows per
PLAN-013.

## 3b. Autofix — the fixer that writes a fix back (PLAN-012)

Autofix ships as a **gated job inside `ai-review.yml`** (not a separate workflow):
when the reviewer returns `request_changes`, the fixer asks the model for a unified
diff, applies it, and pushes it to the PR head via a **dedicated autofix App**; the
push re-fires the gate so the reviewer re-reviews the fix. **DEFAULT-OFF** — inert
unless the trusted config sets `autofix.enabled: true` AND `APP_AUTOFIX_ID/KEY` are
present. This is the one flow that stops being diff-only (it checks out the PR head),
so its safety rests on layered controls:

- **Forks never reach it.** The job is gated on `auto_fix_ok`, which is false for any
  fork (§2.2) — so autofix only ever edits a *trusted, non-fork* author's branch.
- **A PR cannot self-enable it.** `autofix.enabled` + `max_fix_rounds` are resolved
  from the TRUSTED config (operations@main), never the PR branch.
- **The model holds no push credential.** The fixer runs as two steps: the
  model-call/apply step has NO App token in its env (the model only returns text — a
  diff); a separate push step is the ONLY place the ephemeral App token appears.
- **Governance deny-floor (workflow logic, not a tunable).** A fix touching
  `.github/`, `governance/`, `*/governance/`, `framework/`, or `templates/ai-review/`
  is rejected — checked both by parsing the diff's declared targets *before* apply and
  by re-scanning the staged set *after* apply. Out-of-tree targets (`/…`, `..`) are
  rejected too.
- **Two-step push.** The fix is committed + `git format-patch`-exported with no token
  in scope, then pushed from a **pristine `git clone`** (App token only) via `git am`
  — so the pushed history comes from GitHub, never the fixer's workspace.
- **Bounded + escalating.** A monotonic bot-commit round cap (`autofix.max_fix_rounds`,
  default 2) → `ai:autofix-escalated` + a human. On ANY doubt (deny path, unparseable
  or non-applying diff, no change, cap) it escalates — it never force-pushes a guess.
- **Every fix is re-reviewed.** The App-token push re-fires the whole gate, so an
  injected or wrong fix cannot merge without passing review on its own.

**Honest residual:** a *trusted* author's PR diff is still untrusted content that
feeds the fixer prompt (prompt-injection surface). It is contained — the model only
emits a diff we validate against the deny-floor and apply mechanically, and every fix
is re-reviewed and capped — but it is a real surface, not "fully mitigated." The
dedicated App uses an **ephemeral** installation token (not the standing PAT
operations retired in OPS-0043). Credential: `APP_AUTOFIX_ID/KEY` (a SEPARATE App from
the reviewer App, preserving judge≠generator at the identity level) + a fix-scoped
`LITELLM_FIX_API_KEY`.

## 4. Secrets model

### 4.1 `secrets: inherit` (the typical caller pattern)

Consumer callers typically use:

```yaml
jobs:
  call:
    uses: vladm3105/aidoc-flow-ci/.github/workflows/ai-review.yml@ci/v2.3.0
    secrets: inherit   # passes all consumer-repo secrets to reusable
```

`inherit` passes consumer secrets to the reusable. The workflow references
only its documented names; unrelated inherited secrets are not exported to the
LiteLLM process.

### 4.2 What secrets the workflows need

| Workflow | Secrets required |
|---|---|
| `ai-review` | `APP_REVIEWER_1_ID` + `APP_REVIEWER_1_KEY`; `LITELLM_BASE_URL` + `LITELLM_REVIEW_API_KEY` |
| `doc-maintainer` | `LITELLM_BASE_URL` + `LITELLM_DOC_API_KEY`; live mode also requires `AIDOC_FLOW_BOT_ID` + `AIDOC_FLOW_BOT_KEY` |
| `composition` | None beyond `GITHUB_TOKEN` (auto-provided by Actions) |
| `labeler` | None beyond `GITHUB_TOKEN` |
| `codeql` | None beyond `GITHUB_TOKEN` |
| `markdown-lint` | None beyond `GITHUB_TOKEN` |
| `links` | None beyond `GITHUB_TOKEN` (passed to lychee to avoid GH rate limits on github.com URLs) |
| `secret-scan` | None beyond `GITHUB_TOKEN` |

### 4.3 Reviewer App secret-name convention

The `APP_REVIEWER_1_*` names are the canonical reviewer-App contract and are
declared explicitly by `ai-review.yml`. LiteLLM credentials deliberately use
separate purpose-scoped names: `LITELLM_REVIEW_API_KEY` for review and
`LITELLM_DOC_API_KEY` for documentation maintenance. Never reuse the proxy
master key or one unrestricted virtual key for both agents.

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

### Fork-safety of the other write-permission workflows (labeler / codeql / secret-scan)

Three more workflows need write on fork PRs but resolve it differently
(PLAN-004 B3):

| Workflow | Trigger | Fork-PR handling |
|---|---|---|
| `labeler` | **`pull_request_target`** | Needs `pull-requests: write` to apply labels. The reusable is JUST `actions/labeler` — it reads the base's `.github/labeler.yml` + the PR's changed-file list via the API and **never checks out PR code**, so `pull_request_target`'s elevated context can't run fork code. Same safe pattern as `ai-review`. |
| `codeql` | `pull_request` | MUST analyze the PR's code, so it stays on `pull_request` (read-only token). On a **fork** PR the analysis runs but the SARIF upload to code-scanning is **skipped** (`upload: never`) — the upload needs `security-events: write`, which forks don't get; findings are in the job log only. Push + weekly cron + same-repo PRs upload normally. (Not `pull_request_target`: that would analyze the trusted BASE ref, duplicating push/cron coverage while green-lighting an unanalyzed fork diff.) |
| `secret-scan` | `pull_request` | MUST scan the PR's code, so it stays on `pull_request`. The gitleaks scan runs and **still fails the job on a real leak** (the load-bearing gate); on a **fork** PR the SARIF upload is skipped (same `security-events: write` downgrade). Not `pull_request_target` — granting fork PRs write while checking out their code would defeat the safety boundary. |

The common rule: a workflow that must **execute/scan PR code** stays on
`pull_request` and degrades gracefully on forks (skip only the privileged
upload); a workflow that only reads **metadata** can safely use
`pull_request_target` for full write.

## 6. SHA-pinning external Actions

Every `uses:` line in the shared workflows pins to a **40-char SHA**
with the version tag in a trailing comment:

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
- uses: github/codeql-action/init@21eb7f7842f33eafc83782b56fff2a2c43e9696f # v4.36.1
# gitleaks installed as a direct binary (SHA-256 verified), not a
# marketplace wrapper — per canon's authoring allowlist (actions/*,
# github/*, vladm3105/aidoc-flow-ci/*; REPO_STANDARDS §4.3):
#   run: |
#     curl -sSfL "https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz" | tar xz
#     echo "551f6fc...  gitleaks" | sha256sum -c -
#     ./gitleaks git .
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
| **PR CI gate (this workflow)** | **gitleaks (direct binary, SHA-256 verified)** | ~30-60s | Full clone; blocks merge |
| Scheduled | trufflehog | Slower | Adds live-credential verification (kills false positives) |
| Platform | GitHub Secret Scanning + push protection | Real-time | Provider-partner program auto-revokes leaked tokens |

Consumers ideally enable all 4 layers. `aidoc-flow-ci` only ships
the CI-gate layer (`secret-scan.yml`); the others are per-consumer
infra.

### Why a direct binary, not a marketplace wrapper?

The official `gitleaks/gitleaks-action` switched to a proprietary
EULA at v2.0.0 (May 2026). Org-owned repos (including OSS)
require a paid license key. The `aidoc-flow-ci` solution installs the
same `gitleaks` binary directly (MIT-licensed, no key, no signup),
with SHA-256 verification at install time. The binary is not wrapped
in a third-party action, satisfying canon's authoring allowlist
(`actions/*`, `github/*`, `vladm3105/aidoc-flow-ci/*`). Per REPO_STANDARDS
§4.3 that authoring rule is deliberately stricter than the boundary the fleet
deploys, which also admits GitHub-verified creators.

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
