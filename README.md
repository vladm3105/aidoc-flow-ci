# aidoc-flow-ci

**Single source-of-truth CI library** for the **aidoc-flow** workspace
+ all future company projects. Consumer repos call the reusable
workflows via `uses:` from their own `.github/workflows/`; local files
always win
([IPLAN-0017 §3.1a](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017_unified-ci-flows.md)).

## Who uses this

| Project | Status | Consumers |
|---|---|---|
| **aidoc-flow** (current) | Active | `aidoc-flow-operations`, `aidoc-flow-framework` on `@ci/v1.1.3` |
| Future company projects | Onboarding flow ready | See [`docs/multi-project-guide.md`](docs/multi-project-guide.md) for new-project adoption |

This library is **decoupled from any single project's product cadence** —
it ships its own `ci/vX.Y.Z` tags driven by CI infrastructure changes
(reviewer-engine swaps, runner-platform updates, security-scan vendor
changes), not project releases.

## What ships in `ci/v1.1.3`

| Workflow | Purpose |
| --- | --- |
| `ai-review.yml` | AI-review gate (trust → reviewer App → comment / label / merge); ubuntu-latest CLI install + auth-env export validated end-to-end on framework Phase A activation (2026-06-24) |
| `composition.yml` | App-approval status check (PR-#111 conservative trigger shape; full `workflow_run` redesign deferred to Phase B) |
| `labeler.yml` | Path-based PR area labeling (`actions/labeler@v6`) |
| `codeql.yml` | CodeQL security analysis (matrix-driven explicit languages) |
| `markdown-lint.yml` | Markdownlint (`markdownlint-cli2-action`; inline PR annotations) |
| `links.yml` | Link checking (`lychee-action`; internal blocking + external cron non-blocking) |
| `secret-scan.yml` | Secret detection (`gacts/gitleaks` MIT — **not** the proprietary `gitleaks/gitleaks-action`) |
| `pre-commit.yml` | `pre-commit run --all-files` wrapper (Python version + extra-deps + hook-stage configurable) |

Plus `install/install.sh` (one-shot consumer bootstrap; raw-URL
template fetch; preserves local overrides), 10 caller templates +
starter configs in `install/templates/`, `sync/check-drift.sh`
(warning-only drift detector), `LABELS.md` (3 label-namespace
conventions), and 5 consumer-facing docs in `docs/` (architecture,
runners, overrides, security, troubleshooting).

For the per-workflow design rationale see [`docs/architecture.md`](docs/architecture.md).

## Install on a new consumer repo

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v1.1.3/install/install.sh) \
  vladm3105/<consumer-repo> --visibility private
```

**Per-consumer prerequisites** (one-time, after install.sh runs):

| Prerequisite | Why | Fix |
|---|---|---|
| **Actions allowlist** must include `vladm3105/aidoc-flow-ci/*` | If consumer is in `selected actions` mode, the reusable workflow is blocked → `startup_failure` | [`docs/troubleshooting.md` §13](docs/troubleshooting.md#13-startup_failure--reusable-workflow-blocked-by-consumers-actions-allowlist) |
| **Caller `permissions:` block** if repo-default `workflow_permissions: read` | Reusable workflow can't elevate above caller's grant → `startup_failure` | [`docs/troubleshooting.md` §14](docs/troubleshooting.md#14-startup_failure--callers-workflow_permissions-read-blocks-reusables-write) |
| **Secrets**: `APP_REVIEWER_1_ID/KEY` + `CLAUDE_CODE_OAUTH_TOKEN` (or `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` depending on reviewer choice) | ai-review job needs reviewer credentials | `gh secret set <NAME> --repo <consumer>` |
| **Repo variable** `APP_REVIEWER_1_BOT_ID` (after first review) | composition matches App identity by numeric bot id | `gh variable set APP_REVIEWER_1_BOT_ID --repo <consumer> --body "<id>"` (find via `gh api repos/<repo>/pulls/<n>/reviews`) |

See `install/README.md` for details + next steps. For the override
patterns + when to use each, see [`docs/overrides.md`](docs/overrides.md).

## Local overrides shared — the foundational rule

GitHub Actions runs whatever's in the consumer repo's
`.github/workflows/*.yml`. A shared workflow only runs when the
consumer explicitly calls it via `uses:`. So **local always wins** —
by GitHub's default, not by engineering.

Three override modes (preferred order):

| Mode | When | How |
| --- | --- | --- |
| **Parameter override** | Change one knob (runner labels, label colors, human-approval count) | Edit `with:` block in the local workflow; keep the `uses:` call |
| **Full replacement** | Local logic genuinely differs from canonical | Drop the `uses:` call; write the local jobs/steps |
| **Add a custom workflow** | New check the shared CI doesn't have | Create a new `.github/workflows/<custom>.yml`; siblings the shared callers |

There is no merge/inheritance/diamond pattern — GitHub doesn't
support one. "Override" means the consumer's workflow file is what
runs.

## Drift detection — warning-only

`sync/check-drift.sh` compares each consumer's
`.github/workflows/*.yml` against the canonical templates at the
pinned `ci/vX.Y.Z` tag and reports any diff as a `::warning::`.
**Never blocks the commit or the PR.** Run as a pre-commit hook or
periodic GitHub Action.

## v1.1.3 known limitations

- **Public-consumer CLI install — validated end-to-end on framework
  Phase A activation 2026-06-24.** The ubuntu-latest CLI install
  step (codex via npm + claude via curl install.sh) now ships +
  works in CI. Reviewer auth env vars (`CLAUDE_CODE_OAUTH_TOKEN`,
  `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`) are explicitly exported
  to the "Run review" step as of `ci/v1.0.5` (the earlier
  `secrets: inherit` gap that caused "Not logged in" is fixed).
  Required consumer-side: ONE of `CLAUDE_CODE_OAUTH_TOKEN` (claude
  subscription auth — preferred) / `ANTHROPIC_API_KEY` (claude pay-
  per-token) / `OPENAI_API_KEY` (codex pay-per-token).
- **Secret names hardcoded** to `APP_REVIEWER_1_ID` /
  `APP_REVIEWER_1_KEY` — v1.0.6 doesn't parameterize. v1.1.0+ may
  add `app_id_secret_name` / `app_key_secret_name` inputs IF
  consumers actually need non-default names.
- **Composition trigger shape** uses the PR-#111-conservative shape
  (`pull_request_target` [synchronize/labeled/unlabeled] +
  `pull_request_review` [submitted/dismissed/edited]). The full
  `workflow_run` redesign per IPLAN-0017 §3.4 is the Phase-B target
  (requires rewriting the composition body to handle
  `github.event.workflow_run.pull_requests[0]`).
- **LiteLLM proxy / multi-provider model routing** — not yet
  shipped. Today: codex (OpenAI) + claude (Anthropic) only via the
  vendor CLIs. v1.1.0+ may add a LiteLLM-proxy-routed reviewer
  option for cost optimization + provider failover.

For workarounds, see [`docs/troubleshooting.md`](docs/troubleshooting.md)
(13-section guide; §10 public-consumer CLI history; §13-14 reusable-
workflow startup_failure causes from framework Phase A) + the
security model in [`docs/security.md`](docs/security.md) §3-4.

## Charter + design

Full design + per-Phase rollout lives in `aidoc-flow-operations`:

- [`ops/iplans/IPLAN-0017_unified-ci-flows.md`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017_unified-ci-flows.md)
- [`ops/iplans/IPLAN-0017-CHARTER_aidoc-flow-ci.md`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017-CHARTER_aidoc-flow-ci.md)

## License

MIT.
