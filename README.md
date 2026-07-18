# aidoc-flow-ci

**Single source-of-truth CI library** for the **aidoc-flow** workspace
and all future company projects. Consumer repos call the reusable
workflows via `uses:` from their own `.github/workflows/`; local files
always win
([IPLAN-0017 §3.1a](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017_unified-ci-flows.md)).

It also ships the **canonical config templates, governance-file templates,
canonical scripts, and the ai-review rubric + verdict schema** the workspace
shares. The rulebook is [`docs/REPO_STANDARDS.md`](docs/REPO_STANDARDS.md);
`docs/REPO_STANDARDS.md` §0 explains the split between this repo (CI + workflow
canon) and `aidoc-flow-operations` (OPS-NNNN business decisions).

## Who uses this

| Project | Status | Consumers |
|---|---|---|
| **aidoc-flow** (current) | Active | `aidoc-flow-operations`, `aidoc-flow-framework`, + siblings — each pins its own `@ci/vX.Y.Z` tag on its own cadence (see [`docs/WORKFLOWS.md`](docs/WORKFLOWS.md) §5 for current pins) |
| Future company projects | Onboarding flow ready | See [`docs/multi-project-guide.md`](docs/multi-project-guide.md) for new-project adoption |

This library is **decoupled from any single project's product cadence** —
it ships its own `ci/vX.Y.Z` tags driven by CI infrastructure changes
(reviewer-engine swaps, runner-platform updates, security-scan vendor
changes), not project releases. The current released tag is tracked in
the repo-root [`VERSION`](VERSION) file (single source of truth;
`install.sh` reads it, and `scripts/sync-version-refs.sh` keeps the docs'
install references in sync).

## What ships

The library provides **12 reusable workflows**. See
[`docs/WORKFLOWS.md`](docs/WORKFLOWS.md) for the full catalog (purpose,
per-repo applicability matrix, and skip guidance) and
[`docs/architecture.md`](docs/architecture.md) for the per-workflow design
rationale.

| Workflow | Purpose |
| --- | --- |
| `ai-review.yml` | AI code-review gate. Two-job split (trust → LiteLLM reviewer) — safe-by-design for public repos. Submits a formal review as the reviewer App, sets `ai:review-*` labels, and arms auto-merge when appropriate. |
| `composition.yml` | Authoritative identity gate for **counting** AI approvals (an App can approve but cannot be a CODEOWNER). |
| `auto-merge-ai-prs.yml` | Server-side enforcer — re-arms native auto-merge for stuck-green AI-opened PRs. |
| `pre-commit.yml` | `pre-commit run --all-files` runner (Python + caching + pinned pre-commit). |
| `codeql.yml` | CodeQL static analysis (language-configurable). |
| `secret-scan.yml` | Secret scanning with a pinned, checksum-verified gitleaks binary. |
| `markdown-lint.yml` | Markdown lint with pinned `markdownlint-cli2`; inline PR annotations. |
| `links.yml` | Link checking with a pinned, checksum-verified lychee binary; blocking internal + weekly external soft-fail. |
| `labeler.yml` | Path-based PR labeling (`actions/labeler@v6`). |
| `docs-sync.yml` | Mechanical post-merge doc fixer (deterministic version/structure propagation). |
| `doc-maintainer.yml` | AI-driven post-merge doc-of-record maintainer (supersedes `docs-sync.yml` at `ci/v2.0.0`). |
| `audit-trail-check.yml` | OPS-0069 audit-trail phrase gate (CI belt-and-suspenders for the local pre-push hook). Check renders as `call / verify`. |

Alongside the workflows the repo ships **workflow caller templates**
(both `-public` / `-private` variants where runner class differs) in
`install/templates/workflows/`, plus starter configs (CODEOWNERS, branch
protection, dependabot, labels, governance-file skeletons), the canonical
scripts (`install/install.sh`, `install/apply-standards.sh`,
`scripts/pre_push_check.sh`), drift detectors in `sync/`, `LABELS.md`
(label-namespace conventions), and the consumer-facing docs in `docs/`
(indexed in [`docs/README.md`](docs/README.md)).

**New adopter? Start here:** [`docs/AI_CI_DEPLOYMENT.md`](docs/AI_CI_DEPLOYMENT.md)
is the dependency-ordered playbook (prerequisites → deploy sequence → arming),
and `install/deploy-ci-wizard.sh preflight <owner/repo>` audits every
prerequisite and prints a 🟢/🔴 readiness report before you touch the repo.

## Install on a new consumer repo

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v2.4.0/install/install.sh) \
  vladm3105/<consumer-repo> --visibility private
```

**Per-consumer prerequisites** (one-time, after `install.sh` runs):

| Prerequisite | Why | Fix |
|---|---|---|
| **Actions allowlist** must include `vladm3105/aidoc-flow-ci/*` | If consumer is in `selected actions` mode, the reusable workflow is blocked → `startup_failure` | [`docs/troubleshooting.md` §13](docs/troubleshooting.md) |
| **Caller `permissions:` block** if repo-default `workflow_permissions: read` | Reusable can't elevate above caller's grant → `startup_failure` | [`docs/troubleshooting.md` §14](docs/troubleshooting.md) |
| **Reviewer App + LiteLLM secrets** `APP_REVIEWER_1_ID/KEY`, `LITELLM_BASE_URL`, `LITELLM_REVIEW_API_KEY`, `LITELLM_DOC_API_KEY` | AI jobs need scoped keys and a reachable LiteLLM proxy | See [`docs/REVIEWER_APP_ONBOARDING.md`](docs/REVIEWER_APP_ONBOARDING.md) |
| **Private runner pool** `[self-hosted, ci-runner, single-use]` | Private callers intentionally never fall back to GitHub-hosted runners | See [`docs/runners.md`](docs/runners.md) |
| **Repo variable** `APP_REVIEWER_1_BOT_ID` (set immediately — it is App-global, `294948438`; do NOT wait for a first review, or `composition` runs INERT and enforces nothing until it is set) | composition matches App identity by numeric bot id | `gh variable set APP_REVIEWER_1_BOT_ID --repo <consumer> --body "294948438"` |
| **Branch-protection required checks** | Install runs CI but nothing is enforced until the checks are required | See [`docs/BRANCH_PROTECTION.md`](docs/BRANCH_PROTECTION.md) |

See [`install/README.md`](install/README.md) for exactly what the
installer does (and does not do) + its prerequisites. For the override
patterns, see [`docs/overrides.md`](docs/overrides.md).

## Local overrides shared — the foundational rule

GitHub Actions runs whatever's in the consumer repo's
`.github/workflows/*.yml`. A shared workflow only runs when the
consumer explicitly calls it via `uses:`. So **local always wins** —
by GitHub's default, not by engineering.

Three override modes (preferred order): **parameter override** (edit the
`with:` block, keep the `uses:` call), **full replacement** (drop the
`uses:` call, write local jobs), **add a custom workflow**. There is no
merge/inheritance pattern — GitHub doesn't support one. See
[`docs/overrides.md`](docs/overrides.md) for when to use each.

## Drift detection — warning-only

[`sync/check-drift.sh`](sync/check-drift.sh) compares each consumer's
`.github/workflows/*.yml` against the canonical templates at the pinned
`ci/vX.Y.Z` tag and reports any diff as a `::warning::`. It **never
blocks** the commit or PR — the warning is the operator's cue to
reconcile intent when a consumer legitimately deviates. Run it as a
periodic GitHub Action; it is not wired as a pre-commit hook.

## Charter + design

- [`docs/REPO_STANDARDS.md`](docs/REPO_STANDARDS.md) — the canonical
  rulebook (§0 canonical-source authority; §1 tier taxonomy; §5.2
  diff-class labels).
- Full design + per-Phase rollout in `aidoc-flow-operations`:
  [`IPLAN-0017_unified-ci-flows.md`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017_unified-ci-flows.md)
  and [`IPLAN-0017-CHARTER_aidoc-flow-ci.md`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017-CHARTER_aidoc-flow-ci.md).

## License

MIT.
