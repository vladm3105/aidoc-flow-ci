# aidoc-flow-ci

Shared CI library for the **aidoc-flow** workspace and future company
projects. Consumer repos call the reusable workflows via `uses:` from
their own `.github/workflows/`; local files always win
([IPLAN-0017 §3.1a](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017_unified-ci-flows.md)).

## What ships in `ci/v1.0.0`

| Workflow | Purpose |
|---|---|
| `ai-review.yml` | AI-review gate (trust → reviewer App → comment / label / merge) |
| `composition.yml` | App-approval status check (PR-#111 conservative trigger shape; full `workflow_run` redesign deferred to Phase B) |

Plus `install/install.sh` (one-shot consumer bootstrap; raw-URL
template fetch; preserves local overrides), the 4 caller templates +
config + labels in `install/templates/`, and `sync/check-drift.sh`
(warning-only drift detector).

## Install on a new consumer repo

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v1.0.0/install/install.sh) \
  vladm3105/<consumer-repo> --visibility private
```

See `install/README.md` for details + next steps.

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

## v1.0.0 known limitations

- **Public consumers**: `runner_labels_review` in the public
  ai-review template ships as a `REPLACE-ME-with-runner-having-
  reviewer-CLI` placeholder. The reusable workflow body invokes
  `codex` / `claude` CLI directly; GitHub-hosted `ubuntu-latest`
  does NOT have those installed + authenticated. Public consumers
  MUST point at a self-hosted runner with the CLI until v1.0.1
  ships explicit install + auth steps for the GitHub-hosted path.
- **Secret names hardcoded** to `APP_REVIEWER_1_ID` /
  `APP_REVIEWER_1_KEY` — v1.0.0 doesn't parameterize. v1.0.1+ may
  add `app_id_secret_name` / `app_key_secret_name` inputs IF
  consumers actually need non-default names.
- **Composition trigger shape** uses the PR-#111-conservative shape
  (`pull_request_target` [synchronize/labeled/unlabeled] +
  `pull_request_review` [submitted/dismissed/edited]). The full
  `workflow_run` redesign per IPLAN-0017 §3.4 is the Phase-B target
  (requires rewriting the composition body to handle
  `github.event.workflow_run.pull_requests[0]`).

## Charter + design

Full design + per-Phase rollout lives in `aidoc-flow-operations`:

- [`ops/iplans/IPLAN-0017_unified-ci-flows.md`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017_unified-ci-flows.md)
- [`ops/iplans/IPLAN-0017-CHARTER_aidoc-flow-ci.md`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017-CHARTER_aidoc-flow-ci.md)

## License

MIT.
