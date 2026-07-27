# PLAN-006 — Complete + populate CI flows across all aidoc-flow repos

**Status:** active (founder goal, 2026-07-11)
**Owner:** aidoc-flow-ci (canon source)
**Supersedes/extends:** PLAN-005 (ai-review hardening); closes out the v1.8.1
re-pin regression + FT-9.

## Goal

Every aidoc-flow repo runs the **complete canon CI surface**, pinned to the
current `ci/vX.Y.Z`, correctly routed per the runner policy, with a
**proven-green** ai-review pipeline. "Populate" = fill the per-repo canon gaps;
"complete" = every adopted caller is current, correctly-routed, and green.

## Completion criteria (per repo)

1. **Surface** — all *applicable* canon workflows present (manifest set:
   ai-review, composition, auto-merge-ai-prs, doc-maintainer, codeql, docs-sync,
   labeler, links, markdown-lint, pre-commit, secret-scan, dependabot) + the
   governance files (`.github/ai-review/config.json`, CODEOWNERS,
   pull_request_template.md, `scripts/pre_push_check.sh`, CLAUDE.md).
   Applicability: `doc-maintainer` = repos that adopt it; `codeql` = repos with
   compiled/scanned code; the rest = all.
2. **Pins** — every `uses: …/aidoc-flow-ci/…@ci/vX` at the current tag (v1.8.1).
3. **Runner routing** — **private repos: ALL callers self-hosted**
   `["self-hosted","aidoc","ci-ephemeral"]` (heavy reviewer job may use the
   `ai-review` pool); **public repos: `ubuntu-latest`**. `ubuntu-latest` is
   never acceptable on a private repo (founder policy, absolute — see
   [[feedback_private_repos_self_hosted_only]] / CLAUDE.md "Runner policy").
4. **Green** — a real ai-review run concludes SUCCESS on the repo's pool.
5. **Gates** — branch-protection required checks match REPO_STANDARDS §2.

## Repos in scope

Private: operations, business, iplanic, interlog · Public: engramory, framework,
iplan-standard (no ai-review by design), iplan-runner (ai-review → operations@main).
Paused (skip): knowledge-rag, aidoc-flow-site.

## Workstreams

### W1 — Verify + unstick the v1.8.1 self-hosted migration

- [x] operations — v1.8.1, 2-pool self-hosted, ai-review green (run 29154615751).
- [x] business — v1.8.1, ci-ephemeral, ai-review green (13:44).
- [~] iplanic — config correct; stale runner-self runs cancelled; fresh ai-review
  triggered (reopen #246) — confirm green.
- [~] interlog — config correct (#40); stale runs cancelled; needs a fresh
  ai-review to confirm green (no open PR — next PR or a trigger).

### W2 — Canon prevention (closes FT-9) — *aidoc-flow-ci, my lane*

The root cause: `install.sh --update` wholesale-replaces callers, and the
`*-private.yml` templates ship the `runner-self` **placeholder** + `ubuntu-latest`
on the lightweight callers. Until fixed, the next re-pin re-breaks the fleet.

- [ ] `-private.yml` templates: emit real `["self-hosted","aidoc","ci-ephemeral"]`
  for **every** caller (ai-review/composition/auto-merge/doc-maintainer/docs-sync
  **and** audit-trail/pre-commit/links/markdown-lint/secret-scan/labeler). No
  `runner-self`, no `ubuntu-latest` in a `-private` template.
- [ ] `install.sh`: add a **version-only `--repin`** path (rewrite `@ci/v*` on
  `uses:` lines, preserve all customizations) — the correct re-pin operation.
- [ ] REPO_STANDARDS.md + docs/runners.md sync; semver **MINOR**; cut `ci/v1.9.0`.
- Requires verified-planning 2-cycle review before the PR (canon change).

### W3 — Apply strict self-hosted to live private consumers

Migrate the lightweight callers (audit-trail, pre-commit, links, markdown-lint,
secret-scan) to `ci-ephemeral` on operations/business/iplanic/interlog; sync
stale pins (interlog `audit-trail.yml` @ci/v1.6.0 → current). Cross-repo (🔴):
AI preps surgical diffs, founder pushes (or authorizes per-repo).

### W4 — Populate per-repo canon gaps

Reliable adoption audit (existence + calls-aidoc-flow-ci, not a flaky content
probe) → per repo, add missing applicable canon workflows via `install.sh`
(bootstrap for absent, `--repin`/surgical for present). Cross-repo (🔴).

### W5 — Public-repo loose ends

- iplan-runner #76 — pre-existing: 12 legacy plans fail `check-plan`; ai-review
  (→operations@main) failing. Fix plans or scope the hook; then re-pin.
- engramory — `last-run=failure`; confirm stale vs real.
- framework / iplan-standard — confirm current + green (framework last-run green).

## Sequencing

W1 (finish) → **W2 (canon fix + v1.9.0 release)** → W3 + W4 (per-repo, gated on
runner pools) → W5. W2 first so re-population uses fixed templates (no
re-introducing `runner-self`).

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | canon workflow surface (12 wf + governance files) | `files[]` | install/templates/manifest.json:1 |
| 2 | `--update` wholesale-replaces safe_to_replace callers | `update_mode` | install/install.sh:186 |
| 3 | reusable consumes runner_labels via fromJSON → runs-on (no fallback) | `runs-on` | .github/workflows/ai-review.yml:163 |
| 4 | `-private.yml` ships `runner-self` placeholder | `runner_labels_routine` | install/templates/workflows/ai-review-private.yml:43 |
| 5 | lightweight callers default `ubuntu-latest` | `default` | .github/workflows/pre-commit.yml:UNVERIFIED (confirm exact line) |

## Review log

### Pass 0 — 2026-07-11 — author self-draft

Scoped from the live fleet audit during the v1.8.1 self-hosted migration.
Load-bearing facts (manifest set, `--update` clobber mechanism, `fromJSON`
runner routing, `-private.yml` placeholder) verified against source this session.
Open: reliable W4 adoption audit; W2 needs an independent verified-planning pass
before its implementation PR. **Result:** draft — not yet ready (W2 impl PR
pending independent review).
