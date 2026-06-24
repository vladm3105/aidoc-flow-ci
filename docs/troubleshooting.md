# Troubleshooting — `aidoc-flow-ci`

Common issues + fixes, drawn from the operations-side AI-reviewer
activation arc (PRs #100-118) and the aidoc-flow-ci bootstrap +
v1.0.0/v1.0.1 work.

For the broader architecture, see
[`architecture.md`](architecture.md). For security boundaries, see
[`security.md`](security.md). For runner-pool issues, see
[`runners.md`](runners.md). For label conventions, see
[`../LABELS.md`](../LABELS.md).

## Table of contents

| Symptom | Section |
| --- | --- |
| `composition` is RED before `ai-review` even posted the verdict | [§1 Composition pre-ai-review race](#1-composition-pre-ai-review-race) |
| `composition` won't fire on a `skip-ai-review` push | [§2 Skip-ai-review carry-forward](#2-skip-ai-review-carry-forward) |
| Job queues indefinitely ("Waiting for runner") | [§3 Runner not found](#3-runner-not-found-job-queues-indefinitely) |
| `Unable to resolve action 'owner/repo@<sha>'` | [§4 Fabricated SHA pin](#4-fabricated-sha-pin) |
| `gh: not found` in CI logs | [§5 Missing gh CLI on runner](#5-gh-not-found-on-runner) |
| Label creation fails silently / labels missing on consumer | [§6 Label install loop swallows errors](#6-label-install-loop-swallows-errors) |
| Azure SWA "max staging environments" build failure | [§7 Azure SWA quota](#7-azure-swa-max-staging-environments) |
| `actions/labeler` says "label does not exist" | [§8 Labels not bootstrapped](#8-labeler-label-does-not-exist) |
| External lychee link check flakes on twitter/linkedin | [§9 Bot-hostile hosts](#9-lychee-flakes-on-bot-hostile-hosts) |
| Reviewer CLI not installed on `ubuntu-latest` | [§10 Public-consumer CLI gap](#10-public-consumer-cli-gap-v100-known-limitation) |
| Markdownlint says MD024/no-duplicate-heading | [§11 Markdownlint MD024](#11-markdownlint-md024no-duplicate-heading) |
| Rebase conflict on shared CHANGELOG.md | [§12 CHANGELOG rebase conflicts](#12-changelog-rebase-conflicts-on-stacked-prs) |
| Reusable workflow `startup_failure` (no logs, empty jobs) | [§13 Actions allowlist blocks reusable](#13-startup_failure--reusable-workflow-blocked-by-consumers-actions-allowlist) |
| Reusable workflow `startup_failure` after §13 fix | [§14 Caller workflow_permissions blocks reusable](#14-startup_failure--callers-workflow_permissions-read-blocks-reusables-write) |

## 1. Composition pre-ai-review race

**Symptom:** A PR is open; `composition` fires + reports RED
within ~5s; `ai-review` is still running or hasn't even started.
The PR shows the failed composition check next to a pending
ai-review.

**Cause:** On the original (pre-PR-#111) trigger shape,
composition fired on `pull_request_target [opened, reopened,
ready_for_review, synchronize, labeled, unlabeled]`. The
`opened/reopened/ready_for_review` event types fire BEFORE the
App could possibly have approved — composition correctly reports
"no App approval at head" but it looks like a failure.

**Fix:** `ci/v1.0.0`+'s reusable `composition.yml` uses the
post-PR-#111 conservative trigger shape:
`pull_request_target [synchronize, labeled, unlabeled]` plus
`pull_request_review [submitted, dismissed, edited]`. The
review-submitted event re-fires composition the moment the App
approves — flipping it from RED to GREEN.

**If the race still occurs on a force-push (synchronize fires
before the new App approval):** re-run the stale composition:

```bash
STALE=$(gh pr checks <PR> 2>&1 | awk -F'\t' '$2=="fail"' | grep -oE "runs/[0-9]+" | head -1 | cut -d/ -f2)
gh run rerun "$STALE" --failed
```

See [operations PR #111](https://github.com/vladm3105/aidoc-flow-operations/pull/111)
for the original fix.

## 2. Skip-ai-review carry-forward

**Symptom:** PR has `skip-ai-review` label applied (deliberately,
by a human). New push happens. `composition` shows "pending" or
"missing" on the new head SHA; PR can't merge despite previous
approval.

**Cause:** With `synchronize` removed from composition's trigger
types (early design), the `skip-ai-review` carry-forward path
broke: ai-review skipped (correctly), but composition didn't fire
on the new head, so the required check stayed stale on the prior
head.

**Fix:** `ci/v1.0.0`+'s composition keeps `synchronize` in
`pull_request_target.types` precisely so it fires on push and the
body's `if [ "${SKIP_REVIEW:-}" = "1" ]` early-pass exits 0 with
a notice. Trade-off: non-skip PRs see a brief synchronize-race on
push (re-run composition once after ai-review re-approves).

See [operations PR #111 finding](https://github.com/vladm3105/aidoc-flow-operations/pull/111#issuecomment)
where this was caught.

## 3. Runner not found (job queues indefinitely)

**Symptom:** A workflow job stays in "Waiting for runner" >30s.
No worker picks it up.

**Possible causes + fixes:**

1. **Label mismatch.** Workflow specifies
   `runs-on: runner-self` but no self-hosted runner has
   `runner-self` in its label set. Check via
   `Settings → Actions → Runners → <name> → Labels`.
2. **Invalid label characters.** GitHub Actions runner labels
   must match `[a-zA-Z0-9_-]+` (no colons). Using `runner:self`
   would queue indefinitely — see [`../LABELS.md`](../LABELS.md)
   §2 for valid label rules.
3. **`runner-github` is not a real label.** GitHub-hosted runners
   only accept GitHub's fixed labels (`ubuntu-latest`,
   `ubuntu-22.04`, `windows-latest`, `macos-latest`, etc.). You
   cannot make up a label for GitHub-hosted runners. Use
   `ubuntu-latest` directly.
4. **Org-level vs repo-level runner mismatch.** A repo-level
   runner doesn't satisfy an org-level workflow expecting the
   label, and vice versa. See [`runners.md`](runners.md) §3 for
   registration patterns.

## 4. Fabricated SHA pin

**Symptom:** `actionlint` (or GitHub when the workflow first
runs) reports:
`Unable to resolve action 'owner/repo@<40-char-hex>', repository or
version not found`.

**Cause:** The SHA in `uses: owner/repo@<sha>` doesn't exist on
the upstream repo. Common when copy-pasting from search results
or AI suggestions without verification — see the operations
memory entry `feedback_verify_sha_pins` for the Wave-2 incident
where 4 of 7 SHAs were fabricated.

**Fix:** Verify each SHA via `gh api`:

```bash
gh api repos/<owner>/<repo>/git/refs/tags/<tag> --jq '.object.sha'
```

Replace the SHA in your workflow with the actual one. Always
SHA-pin (not tag-pin) for security per
[`security.md`](security.md) §6, but verify the SHA exists.

## 5. `gh: not found` on runner

**Symptom:** Workflow logs show `gh: command not found` or
`/usr/bin/env: 'gh': No such file or directory`. The composition
workflow's warning line shows
`config.json read attempt N failed: gh: not found` instead of a
real network error.

**Cause:** The runner image doesn't have `gh` CLI installed. The
default `ghcr.io/actions/actions-runner:latest` image does NOT
ship `gh`. Cost operations ~2h of debugging during PR #101 before
the actual cause surfaced.

**Fix:**

- **Self-hosted runners:** rebuild the runner image with `gh`
  baked in. See operations'
  [`scripts/ci-runner/Dockerfile`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/scripts/ci-runner/Dockerfile)
  for the reference (installs `gh` from GitHub's official APT
  repo atop `actions-runner:latest`).
- **GitHub-hosted runners** (`ubuntu-latest`): `gh` is
  pre-installed; this error shouldn't occur there.

The `composition.yml` retry loop's warning message includes the
`gh: not found` text explicitly when detected, so future
occurrences won't be misdiagnosed as network failures.

## 6. Label install loop swallows errors

**Symptom:** `install/install.sh` reports
`exists  label <name>` for labels that DON'T exist on the
consumer repo. Subsequent workflows fail because the labels
aren't there.

**Cause:** Earlier versions of `install.sh` caught EVERY
`gh label create` `CalledProcessError` and treated it as
"already exists" — masking auth/permission/network failures.
Caught on aidoc-flow-operations PR #116.

**Fix:** `ci/v1.0.0`+'s `install.sh` prefetches existing labels
via `gh label list --json name,color,description` and only treats
a name match as "exists". Any failure on `gh label create` for
a missing label is a REAL failure → exit nonzero with the actual
stderr in the message.

If you see `FAIL gh label create <name> failed (exit N): <reason>`,
the `<reason>` text tells you the actual cause (auth /
permission / network / invalid color, etc.). Fix that, then
re-run `install.sh`.

## 7. Azure SWA "max staging environments"

**Symptom:** Azure SWA build job on a web-site PR fails ~56s in
with:
`This Static Web App already has the maximum number of staging
environments. Please remove one and try again.`

**Cause:** Azure SWA has a per-app cap on staging environments
(varies by plan). Stale environments from closed PRs accumulate.

**Fix (per operations memory
[`reference_azure_swa_staging_env_quota`](file:///home/ya/.claude/projects/-opt-data-aidoc-flow/memory/reference_azure_swa_staging_env_quota.md)):**

```bash
# Find the static webapp + list envs
az staticwebapp list --query "[].{name:name, resourceGroup:resourceGroup}" -o table
az staticwebapp environment list --name <swa-name> --resource-group <rg-name>

# Delete the oldest stale env (typically from a closed PR branch)
az staticwebapp environment delete --name <swa-name> --resource-group <rg-name> --environment-name <num> --yes

# Re-run the failed CI run
STALE=$(gh pr checks <PR> 2>&1 | awk -F'\t' '/Build.*fail/' | grep -oE "runs/[0-9]+" | head -1 | cut -d/ -f2)
gh run rerun "$STALE" --failed
```

This is web-site-specific (the only consumer using Azure SWA);
unrelated to the shared `aidoc-flow-ci` workflows but listed here
because it surfaces on consumer PRs.

## 8. Labeler "label does not exist"

**Symptom:** `actions/labeler` workflow runs but reports something
like `Label '<name>' could not be added because it does not exist
in this repository`.

**Cause:** `actions/labeler` doesn't create labels — it only
applies existing ones. Either:

- The label is missing from the consumer repo (the canonical
  taxonomy wasn't bootstrapped via `install.sh`)
- The label name in `.github/labeler.yml` doesn't match the
  actual label name in the repo (typo, case mismatch, missing
  space in `area: ci` vs `area:ci`)

**Fix:**

1. Bootstrap the canonical taxonomy on the consumer:
   `bash install.sh <owner/repo> --visibility <private|public>`
2. Verify label name matches exactly:
   `gh label list -R <owner/repo> | grep '<expected name>'`
3. Check `.github/labeler.yml` for the exact label string;
   colon-space matters for `area: <value>` form (see
   [`../LABELS.md`](../LABELS.md) §3).

## 9. Lychee flakes on bot-hostile hosts

**Symptom:** External lychee link check (the cron-mode `links`
workflow) reports failures for URLs like `twitter.com/...`,
`x.com/...`, `linkedin.com/...` returning 403/999, even though
the URLs are valid in a browser.

**Cause:** These hosts return 403/999 to automated user-agents
to discourage scraping. Standard for major social platforms.

**Fix:** The starter `.lychee.toml`
([`install/templates/.lychee.toml`](../install/templates/.lychee.toml))
already excludes these hosts via regex. If you're seeing it on a
host not in the default list, add it:

```toml
exclude = [
  '^https?://(www\.)?(twitter|x)\.com',
  '^https?://(www\.)?linkedin\.com',
  '^https?://(www\.)?reddit\.com',   # add as needed
]
```

External mode is **non-blocking** by design (cron + `fail-on-error:
false`); flaky hosts shouldn't gate PRs anyway. The blocking
internal mode uses `--offline` and skips all http(s) URLs.

## 10. Public-consumer CLI gap (v1.0.0 known limitation)

**Symptom:** Public consumer with `runner_labels_review:
'"ubuntu-latest"'` runs ai-review; the heavy reviewer job fails
with `codex: not found` (or `claude: not found`).

**Cause:** `ci/v1.0.0` ships the public ai-review template with
`runner_labels_review: '"REPLACE-ME-with-runner-having-reviewer-CLI"'`
as a placeholder. Consumers who set the value to `"ubuntu-latest"`
hit this — ubuntu-latest doesn't have the reviewer CLI.

**Fix:** Two options:

1. **Wait for `ci/v1.0.1`** which adds CLI install + auth steps
   to the reusable workflow gated on `contains(inputs.
   runner_labels_review, 'ubuntu-latest')`. See operations
   IPLAN-0017 §4 Phase B.
2. **Set up a self-hosted runner** with the CLI pre-baked + use
   `runner_labels_review: '"runner-self"'`. See
   [`runners.md`](runners.md) §2 for the reference image.

## 11. Markdownlint MD024/no-duplicate-heading

**Symptom:** `markdown-lint` workflow fails with
`MD024/no-duplicate-heading: Multiple headings with the same
content`. Same heading text appears in different sections
(e.g., `### Added` under multiple version sections in
CHANGELOG.md).

**Cause:** Default MD024 mode flags ANY duplicate heading text
in the document. Most projects want duplicates allowed across
siblings (e.g., `### Added` under each version section).

**Fix:** Add `siblings_only: true` to your `.markdownlint.json`
(the starter ships this):

```json
{
  "MD024": { "siblings_only": true }
}
```

This treats duplicate headings as siblings-of-same-parent,
allowing the same `### Added` in different `## ci/vX.Y.Z`
sections.

## 12. CHANGELOG rebase conflicts on stacked PRs

**Symptom:** Working on a stack of PRs all adding `### Added`
entries to `## Unreleased`. After the first PR merges, the second
PR's rebase against main hits a `<<<<<<< HEAD` conflict in
CHANGELOG.md.

**Cause:** Multiple PRs target the same lines (top of
`## Unreleased`). Git can't auto-merge the additions even though
they don't logically conflict.

**Fix:** Manual resolution — keep both entries in chronological
order (or order-by-importance). Use python to extract both blocks:

```python
from pathlib import Path
p = Path("CHANGELOG.md"); s = p.read_text()
start = s.index("=======\n") + len("=======\n")
end = s.index(">>>>>>>")
new = s[start:end]
head_start = s.index("<<<<<<< HEAD\n") + len("<<<<<<< HEAD\n")
head_end = s.index("=======\n")
head = s[head_start:head_end]
prefix = s[:s.index("<<<<<<< HEAD")]
suffix = s[s.index("\n", s.index(">>>>>>>")) + 1:]
p.write_text(prefix + new + head + suffix)
```

This puts the new (branch-side) block first, then the existing
HEAD content. Adjust order if you want HEAD-first.

For PRs in long stacks, consider rebasing each PR onto the
previous (rather than onto main) so conflicts arise once at the
top of the stack instead of cascading.

## 13. `startup_failure` — reusable workflow blocked by consumer's Actions allowlist

**Symptom:** Consumer's PR fires `ai-review` (or any reusable
workflow), but the run completes immediately with
`conclusion: startup_failure`. The run has zero jobs spawned.
GitHub's UI shows: "This run likely failed because of a workflow
file issue."

**Cause:** The consumer repo's Actions permissions are set to
`selected actions` mode (`allowed_actions: "selected"`) with
`github_owned_allowed: true` only — third-party reusable workflows
like `vladm3105/aidoc-flow-ci/.github/workflows/*.yml` are NOT in
the `patterns_allowed` list, so GitHub blocks them at workflow-load
time.

**Diagnose:**

```bash
gh api repos/<owner>/<consumer-repo>/actions/permissions
# If allowed_actions == "selected":
gh api repos/<owner>/<consumer-repo>/actions/permissions/selected-actions
# patterns_allowed should include "vladm3105/aidoc-flow-ci/*"
```

**Fix:**

```bash
gh api repos/<owner>/<consumer-repo>/actions/permissions/selected-actions \
  -X PUT \
  -F github_owned_allowed=true \
  -F verified_allowed=false \
  -f "patterns_allowed[]=vladm3105/aidoc-flow-ci/*"
# (To preserve existing patterns_allowed entries, fetch them first + merge.)
```

After the change, re-trigger the workflow via label cycle (add then
remove `skip-ai-review`) — `gh run rerun` does NOT work for
startup_failure runs.

Surfaced by framework Phase A activation 2026-06-24. The
`pull_request_target` event reads workflows from the BASE ref, so
the bootstrap PR (adding the caller workflow) doesn't trigger the
reusable workflow itself — the first PR AFTER the bootstrap merges
is when this failure mode surfaces.

## 14. `startup_failure` — caller's `workflow_permissions: read` blocks reusable's `write`

**Symptom:** Consumer's `ai-review` or `composition` fires but
fails with `startup_failure`. Run logs are unavailable; jobs array
is empty. Allowlist (§13) already includes `vladm3105/aidoc-flow-ci/*`.

**Cause:** Consumer's repo-default workflow permissions are
`read`. The reusable `ai-review.yml` declares `contents: write` +
`pull-requests: write` in its body, but a callee workflow CANNOT
elevate permissions above the caller's level — only restrict them.
GitHub blocks the run at startup because the declared permissions
can't be granted.

**Diagnose:**

```bash
gh api repos/<owner>/<consumer-repo>/actions/permissions/workflow
# If default_workflow_permissions == "read":
```

**Fix (recommended — caller-level permissions block):** add an
explicit `permissions:` block to the consumer's caller workflows.
For the `ai-review` caller:

```yaml
name: ai-review
on: { ... }
# Required because the consumer's repo-default workflow_permissions
# is `read`; the reusable workflow's `contents: write` cannot
# elevate above the caller's grant.
permissions:
  contents: write        # auto-merge
  pull-requests: write   # review comment, labels, merge
  issues: write          # labels
jobs:
  call:
    uses: vladm3105/aidoc-flow-ci/.github/workflows/ai-review.yml@ci/v1.0.X
    secrets: inherit  # pragma: allowlist secret
```

For the `composition` caller:

```yaml
permissions:
  pull-requests: read
  contents: read
```

**Fix (alternative — bump repo default to `write`):** less granular
but works for ALL workflows in the repo. Trade-off: broader
permission grant by default.

```bash
gh api repos/<owner>/<consumer-repo>/actions/permissions/workflow \
  -X PUT \
  -F default_workflow_permissions=write \
  -F can_approve_pull_request_reviews=false
```

Surfaced by framework Phase A activation 2026-06-24. Framework
v1.0.6 caller templates do NOT include the `permissions:` block
by default (would surprise consumers who don't need it); document
the requirement so consumers can add it when they hit this.

## Reporting new issues

If you hit something not covered here:

1. Search [GitHub issues](https://github.com/vladm3105/aidoc-flow-ci/issues)
   for prior reports.
2. Open a new issue with the workflow name, your caller config
   (redacted), and the failing log.
3. Once resolved, the fix should be added to this doc + the
   relevant section above.

Recurring issues become their own section here. One-off issues
stay in the GitHub issue tracker.
