# Local pre-push self-check (canonical pattern for `aidoc-flow-ci` consumers)

Every consumer repo ships a local pre-push validation script that catches
mechanical issues before they consume CI runner cycles AND enforces the
OPS-0069 audit-trail phrase in every push. The check is belt-and-
suspendered by the CI reusable `audit-trail-check.yml`.

**This doc supersedes** the pre-OPS-0069 `claude`-CLI-based pattern
(local single-pass ai-review-mirroring) that was removed 2026-07-06 per
OPS-0069 in favor of mandatory sub-agent dispatch + audit-trail
verification.

For the per-project architecture (library / governance / consumer), see
[`multi-project-guide.md`](multi-project-guide.md). For CI security
model, see [`security.md`](security.md). For the full canon rule, see
[`REPO_STANDARDS.md`](REPO_STANDARDS.md) §14.

## 1. What the local hook does

The canon `pre_push_check.sh` runs 5 checks on the changed files vs.
`origin/main`:

1. `markdownlint` on changed `.md` files (skipped-with-notice if not
   installed).
2. `yamllint` on changed `.yml`/`.yaml` files (skipped-with-notice if
   not installed).
3. `actionlint` on changed `.github/workflows/*.yml` files
   (skipped-with-notice if not installed).
4. `shellcheck` on changed `.sh` files (skipped-with-notice if not
   installed).
5. **OPS-0069 audit-trail phrase check** — mandatory, always runs.
   Scans commit messages in the push range for one of:
   - `Multi-agent self-review per OPS-0065` (standard case; commit body
     must also name the agents + verdict).
   - `Self-review skipped per founder OK <reason>` (override; requires
     founder authorization in-session).

Each linter is SKIPPED-with-notice if absent; a missing local tool must
not block a push (CI enforces linters authoritatively). The audit-trail
check has NO local skip path — the ONLY bypass is `git push --no-verify`
(git primitive; caught by the CI reusable `call / verify` on the
resulting PR).

**No env-var runtime opt-out.** The pre-OPS-0069 `SKIP_LOCAL_AI_REVIEW=1`
toggle was removed 2026-07-06 because it duplicated the deeper sub-agent
dispatch that is now mandatory.

## 2. Canonical pattern

**Canon script location:** `install/templates/pre_push_check.sh` (this
repo, in the `install/templates/` directory).

**Consumer install path:** `scripts/pre_push_check.sh`.

**Wiring:** via `.pre-commit-config.yaml` with
`default_install_hook_types: [pre-commit, pre-push]` — matches the
`pre-commit` toolchain the workspace already uses for repo hygiene.
Canonical fragment: `install/templates/pre-commit-hook-block.yaml`.

Consumers install both surfaces via `bash install/install.sh` (see
[`../install/README.md`](../install/README.md)).

## 3. Reference implementation

The canon script is `install/templates/pre_push_check.sh`. Consumers get
a byte-identical copy at `scripts/pre_push_check.sh` via `install.sh`.

Key features preserved from the operations reference implementation
(2026-07-06 tip):

- `set -uo pipefail` (NOT `-e`) — the rc-accumulator pattern below
  depends on per-check failures being non-fatal so all checks run.
- Defensive upstream-detection: `git rev-parse --verify --quiet
  @{upstream}` before using it in the commit range. Falls back to
  `origin/main..HEAD` on the very first push before upstream is set.
- Commit-range scoping: `@{upstream}..HEAD` (or fallback) — not
  `<merge-base>..HEAD` — because the merge-base range does NOT advance
  between pushes. Once a phrase-bearing commit was anywhere in the
  merge-base range, subsequent pushes of never-reviewed commits also
  passed. Broken; do not revert.
- Non-fatal per-check failures accumulate into `rc`; script exits with
  the accumulated `rc` so the operator sees ALL failures per push.

## 4. Consumer wrapper (optional; for repo-specific extras)

Repos with domain-specific checks not in the canon (e.g., verified-
planning `check_plan.py`, operations classify-parity) ship a thin
wrapper `scripts/pre_push_check_<repo>.sh` that:

1. Sources the canon script FIRST (audit-trail is the load-bearing
   check; deferring it under repo-only checks would let mechanical
   linting errors mask a missing phrase).
2. Runs the repo-specific extras AFTER, accumulating into `rc`.
3. Points `.pre-commit-config.yaml` at the WRAPPER (not the canon).

Reference: `aidoc-flow-operations/scripts/pre_push_check_ops.sh` (added
as part of the Wave 2 rollout per PLAN-002 §5.5).

## 5. Prerequisites

- **bash 4+.** macOS default is 3.2; install a newer bash (`brew install
  bash`) if you're a founder using the hook locally on macOS.
- **`pre-commit`** (the `pre-commit.com` toolchain): `pip install
  pre-commit` + `pre-commit install` in the consumer repo.
- **Linters** (the canon script skips each individually if absent — so a
  missing tool means that check runs only in CI, not locally). `install.sh`
  emits a `NOTE` naming any missing `shellcheck`/`actionlint` at install time.
  Install all four so the local hook mirrors CI (2 of the 5 checks —
  `actionlint`, `shellcheck` — silently SKIP without them):
  - `markdownlint-cli2` — `npm install -g markdownlint-cli2`
  - `yamllint` — `pip install yamllint` (reads the shipped `.yamllint.yaml`, M4)
  - `actionlint` — `brew install actionlint`; apt has none, so on Linux use
    `go install github.com/rhysd/actionlint/cmd/actionlint@latest` or the
    release binary (`github.com/rhysd/actionlint/releases`)
  - `shellcheck` — `brew install shellcheck` · `apt install shellcheck` ·
    `dnf install ShellCheck`

- **`.yamllint.yaml`** (PLAN-015 M4) — `install.sh` copies a consumer profile
  (120-char, prose-relaxed) if you don't already have one, so `yamllint` doesn't
  flood SDD prose YAML with 80-char errors. Tune it for your repo.

The audit-trail phrase check requires only `git` + `grep` (in every
POSIX-ish env). No CLI dependency, no network calls.

## 6. Invocation

```bash
# Runs automatically when pre-commit is installed + you `git push`.
# Run by hand:
bash scripts/pre_push_check.sh
```

## 7. Failure modes + recovery

### 7.1 Missing OPS-0069 audit-trail phrase

Hook prints the exact phrase to append, plus recovery options:

1. Dispatch the OPS-0065 diff-class-matched sub-agents (Claude Code
   `Agent()` / Codex agents / etc.); fold findings; `git commit --amend`
   to add the `Multi-agent self-review per OPS-0065 (<agents>): <verdict>`
   line to HEAD's commit message body.
2. Get founder authorization in-session AND `git commit --amend` to add
   `Self-review skipped per founder OK <reason>`.

See `aidoc-flow-operations/ops/DECISIONS.md` OPS-0069 for the full rule.

### 7.2 Linter failure

Hook prints the linter output. Fix per the linter's guidance; re-push.
If the linter is unavailable locally but you want to push anyway, CI
will catch it — but the hook still enforces the audit-trail phrase.

### 7.3 Emergency bypass

`git push --no-verify` bypasses the hook entirely (git primitive). This
does NOT bypass the CI `call / verify` reusable on the resulting PR —
the CI check is authoritative for the PR merge boundary. Use only when
audit-trail is present in the pushed commits but a local tool is
misbehaving.

## 8. CI belt-and-suspenders

The CI reusable `.github/workflows/audit-trail-check.yml` re-verifies
the audit-trail phrase on every PR at merge time. Consumer callers use
the standard `jobs.call:` pattern; check-name renders as `call / verify`
and is a required status check per `REPO_STANDARDS.md` §2 (non-paused
non-bootstrap non-umbrella tiers).

Range: `${{ github.event.pull_request.base.sha }}..${{
github.event.pull_request.head.sha }}` on `pull_request` events. Uses
`fetch-depth: 0` to avoid the default-checkout depth-1 fork-PR
false-pass.

**Exemption logic** — the CI gate deliberately **diverges** from the
local hook on the bot + revert signals, because commit `%an` and a
`Revert "` subject are fork-spoofable and unverifiable at the gate. It
uses only signals it can trust:

- **Bot-authored PR** — the PR *author* is a Bot
  (`pull_request.user.type == 'Bot'`) with a login in the allowlist
  (`dependabot[bot]` / `renovate[bot]` / `github-actions[bot]`) → check
  SKIPS. Note this keys on the **PR author**, NOT per-commit authorship
  (unlike the local hook): a human-authored PR that happens to contain a
  bot commit is NOT exempt CI-side.
- **Reverts are NOT exempt CI-side.** The local hook exempts a `Revert "`
  subject; the CI gate does not (spoofable/unverifiable at merge).
- **Two-signal override**: `skip-audit-trail` PR label AND
  `[skip-audit-trail]` in a commit body → check SKIPS. (This is the one
  exemption identical to the local hook.)

## 9. Cross-references

- [`REPO_STANDARDS.md`](REPO_STANDARDS.md) §14 — canonical rule.
- [`WORKFLOWS.md`](WORKFLOWS.md) §1 — `audit-trail-check.yml` registry
  row (added by PLAN-002 PR-U3).
- `aidoc-flow-operations/ops/DECISIONS.md`:
  - OPS-0065 — multi-agent automated review (sub-agent dispatch table).
  - OPS-0066 — 3-cycle circuit-breaker on review/fix loops.
  - OPS-0069 — mandatory pre-push audit-trail (no env-var escape hatch).
- `plans/PLAN-002_workspace-standards-rollout.md` — the unified plan
  driving this canon.
