# Local pre-push self-check (canonical pattern for `aidoc-flow-ci` consumers)

Every consumer repo should ship a local pre-push enforcement script that
catches issues **before** they consume CI runner cycles. This doc
describes the canonical pattern + the reference implementation +
what consumers should do.

For the per-project architecture (library / governance / consumer), see
[`multi-project-guide.md`](multi-project-guide.md). For CI security
model, see [`security.md`](security.md).

## 1. Why local enforcement

The CI `ai-review.yml` gate is **mandatory + authoritative** — every PR
that merges must pass it. But the gate is **long-running** (claude CLI
call on the diff = ~3-5 min/run) and self-hosted runner pools are
typically small (2-4 concurrent slots). When iteration cycles compound
(push → CR → fix → push → CR → fix), the CI queue saturates and
session throughput collapses.

**Local pre-push enforcement catches the same issues earlier**, with
zero CI cost (uses operator's `claude` subscription quota).

| Mode | Cost | Latency | Authority |
|---|---|---|---|
| **Local pre-push self-review** | $0 (subscription quota) | 1-3 min (blocks the push) | Advisory; PUSH is blocked but CI is still the merge gate |
| **CI `ai-review.yml` gate** | CI runner-minutes | 3-5 min per fire + queue latency | **Authoritative** — required for merge |

The local pass is a **mirror, not a replacement**. CI remains mandatory.

## 2. The pattern

A consumer repo's `scripts/pre_push_check.sh` should:

1. **Run mechanical linters** on the changed files only (fast): markdownlint, yamllint, actionlint, shellcheck, etc.
2. **Run AI self-review** on the diff vs `origin/main` via local `claude` CLI:
   - System prompt: `.github/ai-review/review-prompt.md` (same rubric the CI gate uses; future per [IPLAN-0022](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0022_source-of-truth-migration.md) — moves to `aidoc-flow-ci/ai-review/`)
   - User prompt: the diff + instruction to emit `VERDICT: APPROVED` or `VERDICT: CHANGES_REQUESTED` on first line
   - First-line anchored regex parses the verdict; `CHANGES_REQUESTED` → exit 1 (blocks push)
3. **Wire as a pre-commit pre-push hook** (via `.pre-commit-config.yaml` with `default_install_hook_types: [pre-commit, pre-push]`).

## 3. Reference implementation

[`aidoc-flow-operations/scripts/pre_push_check.sh`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/scripts/pre_push_check.sh)
is the canonical reference (shipped 2026-06-25 in operations PR #137).
Other consumers should mirror its structure.

Key shape (excerpt):

```bash
# AI self-review (mirror of CI's ai-review gate; uses local claude CLI subscription auth)
if [ "${SKIP_LOCAL_AI_REVIEW:-0}" = "1" ]; then
  echo "ℹ️  AI self-review SKIPPED via SKIP_LOCAL_AI_REVIEW=1 (CI will still enforce)."
elif have claude && [ -f ".github/ai-review/review-prompt.md" ]; then
  DIFF=$(git diff "$BASE"...HEAD 2>/dev/null | head -c 100000)
  if [ -n "$DIFF" ]; then
    PROMPT="Review the diff below per the rubric in your system prompt.
Output FIRST LINE EXACTLY one of: 'VERDICT: APPROVED' or 'VERDICT: CHANGES_REQUESTED'.
Then a bulleted list of load-bearing findings if any. Under 600 words.

DIFF:
\`\`\`diff
${DIFF}
\`\`\`"
    VERDICT=$(timeout 300 claude --print \
      --append-system-prompt-file ".github/ai-review/review-prompt.md" "$PROMPT" 2>&1)
    claude_rc=$?
    FIRST_LINE=$(echo "$VERDICT" | head -1)
    if [ "$claude_rc" -eq 124 ]; then
      echo "::warning::AI self-review timed out — CI will still enforce."
    elif [ "$claude_rc" -ne 0 ]; then
      echo "::warning::claude exit $claude_rc — CI will still enforce."
    elif echo "$FIRST_LINE" | grep -qE '^VERDICT:[[:space:]]*CHANGES_REQUESTED'; then
      echo "::error::AI self-review: CHANGES REQUESTED"
      echo "$VERDICT"
      rc=1
    elif echo "$FIRST_LINE" | grep -qE '^VERDICT:[[:space:]]*APPROVED'; then
      echo "  ✅ AI self-review: APPROVED"
    else
      echo "::warning::verdict line unrecognized — CI will still enforce."
    fi
  fi
fi
```

## 4. Hardening principles (lessons from the reference implementation)

The reference implementation went through a pre-push self-review cycle
itself + hardened against these failure modes:

| Risk | Mitigation |
|---|---|
| Hung claude call (network/auth) blocks push indefinitely | `timeout 300` wrapper; on exit 124 → warn-and-pass |
| Prose mentioning "CHANGES_REQUESTED" in passing false-blocks | First-line regex anchor: `^VERDICT:[[:space:]]*CHANGES_REQUESTED` |
| Model drift produces unrecognized verdict line | Fallback to warn-and-pass (don't permanently break pushes) |
| Diff too large for prompt | Truncate at ~100KB head; CI gets full diff |
| Operator needs to bypass (rare; mechanical-only changes) | `SKIP_LOCAL_AI_REVIEW=1` env var with audit-trail commit-message line |
| Diff contains triple-backticks that close the code fence early | Future hardening: pass diff via tmpfile + `--add-dir`; current risk is low |

## 5. Prerequisites for a consumer to adopt

| Prerequisite | How |
|---|---|
| `claude` CLI installed locally | `curl -fsSL https://claude.ai/install.sh \| sh` |
| `claude` authenticated | `claude` (interactive login) OR `CLAUDE_CODE_OAUTH_TOKEN` env var |
| `.github/ai-review/review-prompt.md` present | Per [IPLAN-0022](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0022_source-of-truth-migration.md), this will move to `aidoc-flow-ci/ai-review/` (consumer fetches via reusable workflow). Until then, copy from operations. |
| `scripts/pre_push_check.sh` present + executable | Copy from operations reference implementation |
| Pre-commit hooks wired | `pre-commit install --install-hooks` (sets up pre-commit + pre-push automatically per `default_install_hook_types: [pre-commit, pre-push]`) |

## 6. CI gate relationship — what's STILL mandatory

Local pre-push does NOT change CI behavior. After local enforcement
lands:

- `ai-review.yml` reusable workflow still fires on every push (per
  `pull_request_target` trigger)
- `composition.yml` still gates the merge
- Required-check branch protection still applies
- The CI verdict is still the authoritative `pre_merge` gate per
  `aidoc-flow-operations/CLAUDE.md` §"Merge governance"

**Local enforcement reduces iteration count; it does not replace CI.**

## 7. Governance-PR additional discipline

For PRs touching `ops/DECISIONS.md`, `IPLAN-*.md`, `CLAUDE.md`,
`.github/ai-review/`, or supersession-related surfaces (per consumer's
own CLAUDE.md "Governance PR discipline" Rule 2), additionally
dispatch a **broader `code-reviewer` agent pass** on the full diff.
The pre-push hook's AI step is a fast first-line filter; deeper
adversarial review (dead-refs, supersession completeness, internal
consistency across all surfaces) is still required for governance
changes.

## 8. Future enhancement — ship as an install template

Today consumers copy the script manually from operations. Future:
ship `install/templates/scripts/pre_push_check.sh` on aidoc-flow-ci;
`install.sh` drops it into new consumer repos as part of the standard
bootstrap. Tracked as a follow-up; not blocking.

## 9. References

- [`architecture.md`](architecture.md) — per-project CI architecture
- [`multi-project-guide.md`](multi-project-guide.md) — library / governance / consumer split
- [`security.md`](security.md) — CI security model + trust gate
- Reference implementation: [`aidoc-flow-operations/scripts/pre_push_check.sh`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/scripts/pre_push_check.sh)
- Operations PR #137 (the activation): [aidoc-flow-operations#137](https://github.com/vladm3105/aidoc-flow-operations/pull/137)
- Governance PR discipline (Rule 1 + Rule 2): see consumer's own CLAUDE.md "Governance PR discipline" section
