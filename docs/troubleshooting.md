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
| Stuck check on latest commit (no new push to retrigger) | [§15 Label-cycle retrigger](#15-stuck-check--label-cycle-retrigger) |

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
hit this — GitHub-hosted runners (including `ubuntu-latest`) don't
have the reviewer CLI pre-installed.

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

## 15. Stuck check — label-cycle retrigger (+ R3 force-fresh path, ci/v1.3.0+)

`ai-review.yml` still listens on `pull_request_target` event types
that include `labeled` + `unlabeled` — so a **label cycle** still
injects synthetic PR events that fire ai-review on the current
commit state:

```bash
gh pr edit <PR> --add-label "skip-ai-review"    # fires labeled event
sleep 3
gh pr edit <PR> --remove-label "skip-ai-review" # fires unlabeled event
```

**ci/v1.3.0+ change (IPLAN-0026 Phase 2):** the recommended
composition install template **no longer listens on
`pull_request_target`** — it listens on `pull_request_review`
(submitted/dismissed/edited) and `workflow_run` (ai-review
completed). A label cycle therefore **no longer directly
retriggers composition**; it retriggers ai-review, which on
completion fires `workflow_run` → composition picks up the
fresh signal. The net effect on a routine PR is the same, but
**composition is now event-causal from ai-review** rather than
being independently cycled. Consumers that locally re-added
`pull_request_target` to composition (per `docs/overrides.md`)
retain the direct retrigger path.

**ci/v1.3.0+ change (IPLAN-0027 P1, R3 early-exit):** when
ai-review fires and the reviewer App has **already APPROVED**
the current HEAD SHA, a new R3 early-exit step skips the heavy
reviewer CLI and carries the prior approval forward (saves
~$0.10-0.20 + ~2-3 min per redundant re-fire). This means a
`skip-ai-review` label cycle on an **already-approved** PR (at
the SAME HEAD) now ends with the R3 carry-forward — **not** a
fresh review. If you actually want a fresh review at the same
HEAD, use the gh-api dismissal force-fresh path (next section).

### Force-fresh-review path (ci/v1.3.0+) — dismiss the App's prior review

When the App has already APPROVED at the current HEAD and you
want a NEW review (e.g., the rubric changed; the review was
posted under a now-fixed bug; you want belt-and-braces
verification), DISMISS the App's existing review via the
GitHub API and the next ai-review fire will run fresh:

```bash
PR=<pr-number>
REPO=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')
HEAD_SHA=$(gh pr view "$PR" --json headRefOid -q .headRefOid)

# 1. Look up the App's APPROVED review id at the current HEAD SHA. Filtering on commit_id
#    avoids picking a stale older-commit approval in a multi-bot or multi-cycle scenario.
review_id=$(gh api "repos/$REPO/pulls/$PR/reviews" --paginate \
  -q ".[] | select(.user.type==\"Bot\" and .state==\"APPROVED\" and .commit_id==\"$HEAD_SHA\") | .id" | tail -1)

# 2. Dismiss it.
gh api -X PUT "repos/$REPO/pulls/$PR/reviews/$review_id/dismissals" \
  -f event=DISMISS -f message="forcing fresh ai-review at same HEAD"

# 3. Trigger ai-review — a label cycle, a no-op push, or any PR event will do.
#    R3 will now find no APPROVED-at-HEAD review → full review path runs.
gh pr edit "$PR" --add-label "skip-ai-review" && sleep 3 && gh pr edit "$PR" --remove-label "skip-ai-review"
```

The dismissal API is the explicit operator action for
force-fresh; the old label-cycle-alone path (which worked
pre-R3 because every cycle retriggered the full review) is
superseded by the dismiss-then-cycle pattern.

### The `skip-ai-review` label specifically

`skip-ai-review` is a workflow-recognized label. When PRESENT,
`ai-review.yml` reads:

```yaml
env:
  SKIP_REVIEW: ${{ contains(github.event.pull_request.labels.*.name, 'skip-ai-review') && '1' || '' }}
  SKIP_REASON: ${{ contains(github.event.pull_request.labels.*.name, 'skip-ai-review') && 'label' || '' }}
```

Every heavy step has `if: env.SKIP_REVIEW != '1'`, so the work
is skipped + the workflow emits a fast `ai:review-passed`
outcome. This is the LIBRARY mechanism for "I know this push
has no new content worth reviewing" — used during the cycle to
keep ai-review fast.

The R3 early-exit step (IPLAN-0027 P1, ci/v1.3.0+) can ALSO
flip `SKIP_REVIEW=1` via `$GITHUB_ENV` with `SKIP_REASON=r3`
when the App has already APPROVED the current HEAD SHA — see
the workflow comment header above the step. The final
"ai-review skipped" step branches on `$SKIP_REASON` to emit
the right notice (and posts a PR comment **only** for the
`label` case to avoid spamming label-cycles).

### When to use a label cycle

| Scenario | Use it? |
| --- | --- |
| Composition stuck on `pending` after a rebase-with-main commit (no actual review changes), pre-v1.3.0 install template | ✅ Yes — composition fires only on PR events; cycle injects fresh ones |
| Composition stuck on `pending` on a ci/v1.3.0+ install template (no `pull_request_target`) | ✅ Yes — cycle fires ai-review on `unlabeled`; ai-review completion fires `workflow_run` → composition |
| ai-review verdict still on a STALE commit after a rebase (HEAD CHANGED) | ✅ Yes — R3 finds no APPROVED-at-new-HEAD review; full review runs |
| ai-review verdict carrying forward on the SAME HEAD (you want a fresh review) | ❌ Cycle alone won't do it (R3 carries forward). Use the gh-api dismissal force-fresh path above. |
| Rebase-only commit that introduces no logical changes (previously APPROVED) | ❌ **Don't cycle** — add `skip-ai-review` label **permanently** (no remove) so ai-review skips entirely. **⚠️ ci/v1.7.x+ (PLAN-005 PR-A part 2):** `skip-ai-review` now carries the prior approval forward only when HEAD's **content (git tree) is identical to an App-approved commit**. A no-op / same-base rebase (unchanged tree) still carries. A **rebase onto an *advanced* base** incorporates new upstream content → different tree → the label no longer auto-merges; get a **fresh App review at the new HEAD** (or human-merge). This is deliberate: the rebased result contains code the App never reviewed. |
| Random "let me retry" reflex | ❌ No — wastes CI runner-minutes |

### Cost / risk

Each cycle fires **every workflow listening on labeled/unlabeled** —
post ci/v1.3.0, that's ai-review (and any locally-overridden
composition that re-added `pull_request_target`). Composition on the
v1.3.0+ install template fires only causally from ai-review's
`workflow_run` event, so the cycle blast radius is narrower than
pre-v1.3.0. On a busy queue, cycles can still cause cancellation
races where a newer run cancels an in-progress earlier one.

**Rule of thumb:** only cycle when a check is genuinely stuck for
≥10 min beyond expected runtime. Otherwise, wait — the queue is
likely just slow.

Surfaced as a session-end debrief 2026-06-26: operations + framework
were each cycling redundantly during IPLAN-0022 PR-B/PR-C rollout;
the label-cycle pattern works but compounded slowness on the 2-runner
self-hosted pool. Documented here as canonical guidance for consumers.

## 16. `standards-drift` / `apply-standards.sh --check` reports drift

**Symptom:** the scheduled `standards-drift` workflow (or a manual
`apply-standards.sh --check`) emits `::warning::` lines like
`branch-protection.contexts: canon=[…] actual=[…]` or a workflow-file
diff.

**Cause:** the repo's live settings/workflows diverge from the canon at
the resolved `ci/vX.Y.Z` tag. This is **warning-only by design** — it
never blocks a commit or PR; it's a reconcile signal.

**Fix:** decide per drift — re-align (`apply-standards.sh --apply` for
settings, re-install the caller for a workflow), keep the divergence
intentionally (add a comment explaining why; the warning persists as a
documented deviation), or upstream it (PR on `aidoc-flow-ci`). See
[`overrides.md`](overrides.md) §5. If `--check` compares against the
WRONG tag, pin it: `CI_TAG=ci/vX.Y.Z apply-standards.sh --check`
(otherwise it resolves the tag from the repo's own workflow pins).

## 17. `call / verify` (audit-trail) fails or errors

**Symptom:** the `call / verify` required check is red.

- **`missing the OPS-0069 audit-trail phrase`** — the push has no commit
  body carrying `Multi-agent self-review per OPS-0065 …` or
  `Self-review skipped per founder OK …`. Add the phrase to a commit in
  the range (amend + force-push, or a new commit). See
  [`local-pre-push.md`](local-pre-push.md) §7.1.
- **`BASE_SHA … unreachable after fetch — check cannot run`** — the
  caller's checkout lacks history. The `audit-trail` caller MUST use
  `fetch-depth: 0`. The error now includes the `git fetch stderr` — if it
  shows `gh`/auth/network, that's the real cause; if it's an unknown-ref,
  the base ref genuinely isn't fetchable (rebased/force-pushed base).
- **To bypass intentionally** — apply the `skip-audit-trail` label AND
  put `[skip-audit-trail]` in a commit body (two-signal; one alone won't
  skip). See [`../LABELS.md`](../LABELS.md) §1.

## 18. `install.sh` fails on `ruamel.yaml` / `pyyaml` not installed

**Symptom:** `install.sh` exits with
`FAIL: neither ruamel.yaml nor PyYAML available` while merging the canon
block into an existing `.pre-commit-config.yaml`.

**Cause:** the consumer already has a `.pre-commit-config.yaml`, so
`install.sh` merges (not copies) the canon hook block, which needs a
Python YAML library on the **operator's machine**.

**Fix:** `pip install ruamel.yaml` (preferred — preserves the consumer's
comments) or `pip install pyyaml` (strips comments), then re-run. Only
required when the consumer already has a `.pre-commit-config.yaml`; a
repo without one gets the canon fragment copied verbatim (no YAML lib
needed). See [`../install/README.md`](../install/README.md) Prerequisites.

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
