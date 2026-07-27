# ROLLOUT — PLAN-017 (FT-15) tag cut + live verification

> **Status: PREPARED, NOT EXECUTED.** PLAN-017's canon-side work is merged
> (PRs #236 / #237 / #238). What remains is a release tag plus a consumer re-pin
> — the re-pin **writes to another repo**, 🔴 per the operations autonomy tiers,
> so the founder (or an operations-repo session) runs it. The AI does not execute
> it in-session.

## Why a live check is required at all

**Nothing in PLAN-017 is verified in production.** `aidoc-flow-ci` ships
`ai-review`, `doc-maintainer`, and `docs-sync` as `workflow_call` reusables and
has **no self-caller** for any of them (its only real self-`uses:` are
`audit-trail.yml:33` and `self-secret-scan.yml:32`). So their own PRs never execute the changed
code — green CI on #236/#237/#238 proves syntax, the repo suite, and the fixture
harness, and nothing more.

What IS already proven: a fixture harness exercised every branch of the resolver —
plain pin, SHA-pinned (fetches at the SHA), no pin, ambiguous pins, pre-release,
empty body, JSON body, empty base ref, `@`-in-branch-name, `*.yml.bak` leftover.

**The one thing only production can show:** that a consumer pinned at `@ci/vX.Y.Z`
now logs that tag instead of `refs/heads/main`. That is the exact assertion FT-15
was confirmed with, so it is the exact assertion that closes it.

## Step 1 — Cut `ci/v2.10.0` (canon-side; no cross-repo write)

Follow `docs/RELEASE_CHECKLIST.md` in order. Items that specifically matter here:

- `bash tests/run.sh` green — but **do not treat a local lint pass as
  authoritative.** `tests/test_lint.sh:34` runs a bare `actionlint` (it delegates
  `run:` blocks to `shellcheck` automatically when present), and CI pins
  **actionlint 1.7.12 + apt shellcheck** (`.github/workflows/tests.yml:40,43`).
  Version skew is real: PR-C's SC2015 finding reproduces on CI but **not** with
  actionlint 1.7.7 / shellcheck 0.11.0 locally — verified by re-running the exact
  failing construct both bare and with `-shellcheck=`. So the PR's `suite` check
  is the gate; a local green only means "no findings your versions detect."
- `bash scripts/sync-version-refs.sh` → zero diffs.
- `VERSION` reads `ci/v2.10.0` and `CI_TAG_FALLBACK` in `install/install.sh`
  matches.
- Promote the `## Unreleased` CHANGELOG entries (the three FT-15 entries) into a
  `## ci/v2.10.0 — <date>` section.
- **MINOR, not PATCH** — behaviour-preserving for consumers, but consumers must
  re-pin to get the fix, and it introduces a new hard requirement on the caller
  surface (a pin the resolver cannot read now hard-fails; pre-release pins are
  unsupported). See `docs/REPO_STANDARDS.md` §4.2a.
- ⚠️ The checklist's own post-release item says *"Smoke on one consumer:
  `install.sh <owner/repo> --repin`"*. **Do not run that against operations** — it
  contradicts Step 2: `--repin` rewrites only `uses:` lines and would leave the
  contract-lock (and surface 5) stale, failing the pre-commit guard. It is fine
  for a consumer without a contract-lock.
- **FT-21 sequencing:** merge the release-prep PR **before** tagging; the
  self-pin chicken-and-egg makes that PR's first check run red until the tag
  exists (workflow-file-issue runs are not rerunnable — an empty-commit
  re-trigger is the recovery).

## Step 2 — 🔴 Pilot re-pin: advance `operations` `ci/v2.0.1` → `ci/v2.10.0`

**Why operations is the only practical pilot.** It is the sole consumer already
on v2 (everything else is still `@ci/v1.9.5`, so re-pinning them means the whole
PLAN-009 v1→v2 cutover with its 🔴 Phase-0 prereqs). operations is also fully
armed (self-hosted pool + LiteLLM secrets + reviewer App), so one re-pin
exercises **both** fixed resolvers — `docs-sync` and `ai-review`.

**This is NOT a version-only `--repin`.** operations carries the contract-lock
`scripts/check-ci-contract.sh`, which hard-asserts the accepted pin (currently
`ci/v2.0.1`) in two places. It must advance in lockstep or the pre-commit hook
rejects the change — the same lesson as the earlier `v2.0.0 → v2.0.1` advance.
Four surfaces, mirroring that runbook
(`operations/ops/inbox/2026-07-16_founder_operations-ci-v2.0.1-advance-and-verify.md`):

1. `scripts/check-ci-contract.sh` — the accepted-pin assertion.
2. `scripts/check-ci-contract.sh` — the `standards-drift` ref assertion (this one
   is an `rg` **regex**, so its dots are escaped — a blanket `sed` misses it).
3. `.github/workflows/standards-drift.yml` — **both** `ref:` and `--ci-tag`.
4. The caller `uses:` pins.
5. **`.github/ai-review/config.json` — the `$schema` URL**, which also carries the
   tag. It sits outside both `scripts/` and `.github/workflows/`, and
   `check-ci-contract.sh` validates that file with `jq` (not against `$schema`),
   so a stale value passes the contract silently. (This surface was easy to miss —
   it was itself a review finding during the `v2.0.0 → v2.0.1` advance.)

Then `bash scripts/check-ci-contract.sh` must print `ci-contract: PASS`, and the
residue check must span **both** trees — note the wider path scope, which is what
catches surface 5:

```bash
grep -rn 'ci/v2\.0\.1' scripts/ .github/   # must be empty
```

> **Scope warning — this is a 10-minor jump, not a patch bump.** v2.0.1 → v2.10.0
> spans PLAN-013 (uniform-protected AI flows), PLAN-014 (three opt-in scanners,
> `auto_install: false` so they stay dormant), PLAN-015 (consumer-installable
> `standards-drift` + honest `install --verify-standards`) and PLAN-016 (runner
> canon). For a **private, already-self-hosted** consumer these are additive or
> opt-in, and operations keeps its own callers (local always wins), so a
> version-only advance is expected to be safe — but review the intervening
> CHANGELOG sections rather than assuming, and treat it as a cutover, not a bump.
>
> **What actually de-risks it:** because of FT-15 itself, operations has *already*
> been running `main`'s rubric, verdict schema, LiteLLM client and doc-maintainer
> scripts this whole time. So the v2.1–v2.9 **asset** content is already live in
> production and battle-tested there; the re-pin's real delta is the **workflow
> YAML**, not the scripts. Interface check (`ci/v2.0.1..main`): no reusable input
> removed or renamed, and all four inputs operations passes (`model`,
> `runner_labels_routine`, `runner_labels_review`, `litellm_allow_insecure_http`)
> still exist with unchanged semantics.

## Step 3 — Read the evidence (this is the actual verification)

**`docs-sync`** — post-merge, so the notice appears only *after* the re-pin PR
merges. In that run's log expect:

```text
::notice::docs-sync: adopted canon pin vladm3105/aidoc-flow-ci@ci/v2.10.0 (fetching at ci/v2.10.0)
```

**`ai-review`** — fires on the re-pin PR itself, but that PR's ai-review still
runs the **base** (`v2.0.1`) reusable, so it will still log the old FT-15 line.
Read the notice on the **next** PR opened after the re-pin merges:

```text
::notice::ai-review: adopted canon pin vladm3105/aidoc-flow-ci@ci/v2.10.0 (fetching at ci/v2.10.0)
```

| Outcome | Meaning |
| --- | --- |
| notice names `ci/v2.10.0` | ✅ **FT-15 closed.** The adopted pin now controls the assets. |
| notice names `refs/heads/main` | ❌ fix ineffective — do not proceed; re-open FT-15. |
| INFRA error naming a missing/ambiguous pin | resolver working, caller state wrong — fix the pin, not the code. |
| bare red `ai-review` with no label/comment | should no longer happen (PR-C widened the infra signal); if it does, report it. |

Quick pull, mirroring how FT-15 was confirmed:

```bash
gh run view <run-id> --repo vladm3105/aidoc-flow-operations --log \
  | grep -i 'adopted canon pin\|fetching assets from'
```

## Rollback

Reverse all five surfaces back to `ci/v2.0.1` and merge. No data, secret, or
runner change is involved — it is a pure pin reversion. The canon tag itself does
not need to be withdrawn (no consumer is pinned to it until they re-pin).

## After it passes

- Close **FT-15** in `plans/FRAMEWORK-TODO.md` (it is currently CONFIRMED with
  the fix landed but unverified).
- Mark PLAN-017 verified.
- **FT-22** — port the same resolver to `standards-drift.yml`, which pioneered
  the approach but predates the both-forms / scan-scope / pre-release /
  fail-closed / fetch-at-SHA properties (`docs/REPO_STANDARDS.md` §4.2a has the
  full list).
- Consider **canon self-adoption of `docs-sync`** (a self-caller +
  `.github/docs-sync.json`, `dry_run` first). The repo's own `CLAUDE.md` says
  *"Wave 0 (this repo) self-adopts BEFORE Wave 1+ consumers pull — the
  canon-source dogfoods its own canon"*, and the absence of a self-caller is
  precisely why this verification needs a 🔴 cross-repo write at all. Filed as
  FT-23.
