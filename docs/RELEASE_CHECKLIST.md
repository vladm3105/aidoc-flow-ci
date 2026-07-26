# Release checklist — aidoc-flow-ci

Run before cutting every `ci/vX.Y.Z` tag. Items are ordered — complete
each before proceeding to the next.

**`scripts/release.sh` automates the mechanical steps and enforces the
ordering (FT-21):** `release.sh prep <ci/vX.Y.Z>` does the VERSION bump, ref
sync, and CHANGELOG promotion on a prep branch (and tells you the one
expected-red check); after the prep PR is merged, `release.sh tag <ci/vX.Y.Z>`
cuts the tag and publishes the release. Since 2026-07-24 the 🔴 FT-30 dry-run
gate is **conditional** — `tag` requires `--dry-run-verified` only when the
release changes the installer bootstrap write path, and says so with the file
list when it does (see the COLD-START item below for the exact scope). The
checklist below is the human-judgment layer around it — the script refuses to
tag out of order and decides *whether* the dry-run is owed, but it cannot run
the 🔴 dry-run for you.

## Pre-tag

- [ ] **Schema validation:** `python3 -m json.tool schemas/ai-review-config-v2.schema.json >/dev/null`
  and `python3 -m json.tool ai-review/verdict.schema.json >/dev/null`. (The old
  `docs/router-config.schema.json` path no longer exists — corrected 2026-07-24.)
  CI must pass.
- [ ] **Test suite passes:** `bash tests/run.sh` — all assertion groups green
  (checknames, contracts, negative, scripts, lint).
- [ ] **`sync-version-refs.sh` clean:** no stale version references in docs or
  installer left behind. Run `bash scripts/sync-version-refs.sh` and verify
  zero diffs.
- [ ] **Zero-hook detector on the shipped fragment (FT-31):** a config resolved
  from the canon pre-commit fragment must select at least one hook at the
  pre-commit stage, or the required `call / Lint / format / security hooks` check
  ships vacuous (F3). Run:
  `bash install/check-precommit-hooks.sh install/templates/pre-commit-hook-block.yaml`
  — it must exit 0. (This is the operator-side detector; it also runs in
  `install.sh` post-merge and in `deploy-ci-wizard.sh preflight`. It is
  deliberately NOT on the `pre-commit` reusable's gating path — see
  `docs/REPO_STANDARDS.md` §14.1a.)
- [ ] **OPS-0065 review complete:** at least 2 review passes, at least 1
  independent (fresh-context subagent), ≤3 cycles per OPS-0066. Final pass
  must state zero load-bearing findings.
- [ ] **LiteLLM smoke passes (MAJOR bumps only):** run `litellm-smoke.yml`
  manually. Both canonical aliases (`ai-reviewer`, `ai-doc-maintainer`) must
  return valid responses from the real proxy.
- [ ] **Migration guide published (MAJOR bumps only):** `docs/MIGRATION_vX.Y.Z.md`
  covers required consumer actions (new secrets, removed inputs, config
  changes, repin commands, rollback). Cross-referenced from CHANGELOG and
  `docs/UPDATE_GUIDE.md`.
- [ ] **Release notes drafted:** copy the relevant `## Unreleased` entries
  from CHANGELOG.md into a `## ci/vX.Y.Z — <date>` section. Promote
  `## Unreleased` entries to the new tag header.
- [ ] **VERSION bumped:** `VERSION` file reads `ci/vX.Y.Z`. Must match the
  tag being cut. Write it **with a trailing newline** (`echo "ci/vX.Y.Z" >
  VERSION`, not `printf` without `\n`) — canon's own `self-pre-commit` gate runs
  `end-of-file-fixer` and a newline-less `VERSION` fails it. All readers strip
  whitespace, so the newline is inert to resolution.
- [ ] **`install.sh` fallback matches:** `CI_TAG_FALLBACK` in `install.sh`
  matches `VERSION`. Grep: `grep CI_TAG_FALLBACK install/install.sh`.
- [ ] **🔴 COLD-START DRY-RUN (founder-executed) — PLAN-018 FT-30.**
  **CONDITIONAL since 2026-07-24 — `release.sh tag` decides for you.** The gate is
  required only when the release changes the installer **bootstrap write path** —
  the path whose breakage *aborts* a cold start (`fetch_template … || exit 1`),
  which is what F1 actually was. `release.sh` derives it from
  `install/templates/manifest.json` — both `template` **and every
  `visibility_variants` value**, because `install.sh` fetches
  `workflows/composition-private.yml` / `pre-commit-private.yml` directly and those
  appear only as variants — plus `install.sh`, `check-precommit-hooks.sh`,
  `labels.json`, and the pre-commit fragment. If nothing on it changed since the
  previous tag, `tag` prints **`FT-30 cold-start gate AUTO-WAIVED`** and proceeds:
  a dry-run of unchanged installer code proves nothing. If anything did change,
  `tag` refuses, **lists the files**, and demands `--dry-run-verified`.
  It **fails closed**: no previous `ci/vX.Y.Z` tag, an unreadable manifest, or a
  manifest whose shape yields no templates → the flag is required.
  **Deliberately OUT of scope — changing these will NOT trigger the gate:**
  `install/README.md`; `deploy-ci-wizard.sh` / `apply-standards.sh` (entry points a
  cold start never runs); and the **advisory standards-verify** assets reached
  transitively through `verify_standards` — `sync/check-standards-drift.sh` and what
  it fetches (`branch-protection-*.json`, `repo-settings.json`,
  `actions-permissions.json`, `check-pin-currency.sh`). `install.sh` captures that
  step's exit code rather than exiting, so a fault there degrades the *report*, not
  the install. **If your release changes those, pass `--dry-run-verified`
  deliberately — the gate will not force you.**
  When the gate DOES fire, run it as follows. Canon is
  already adopted, so it cannot exercise its own cold start; nothing else does
  either, which is how F1 (a bootstrap template deleted at `ci/v2.2.0`) shipped
  broken for nine releases. Before cutting a tag that changes `install.sh`, the
  bootstrap set, or the pre-commit fragment, run `install.sh` against a
  **throwaway repo** and confirm it completes through labels without error.
  - This is a 🔴 write-to-another-repo action (it clones the target and creates
    18 labels on it) — prepare it as an `ops/inbox` runbook and have the founder
    execute it, exactly like PLAN-017's live-verification gate. The AI does not
    run it in-session.
  - **The runbook MUST `export CI_TAG=<merge-sha>`** (or the tag once it exists).
    Without it the dry-run resolves `CI_TAG` from `VERSION`/the fallback and
    fetches templates from the PREVIOUS release — validating the pre-fix files,
    not the ones about to ship. This is the single most important line in the
    runbook.
  - Expected: the run reaches "creating canonical labels" and the final
    next-steps block with no `FAIL`/`404`; the runner-pool probe and the
    LiteLLM-HTTP note both print. Tear down the throwaway repo after.

## Tag + release

- [ ] **⚠️ Merge the prep PR with `--admin` — it will be BLOCKED, not just red
  (since FT-52, 2026-07-24).** `main` is now protected with 5 required checks, and
  **4 of them come from self-pinned callers** (`self-markdown-lint`,
  `self-pre-commit`, `self-secret-scan`, `audit-trail`). The prep bumps those pins
  to the tag being cut, which does not exist yet, so those workflows
  `startup_failure` and their required contexts are **never reported** — the PR
  sits at "Expected — waiting for status to be reported", not merely failing. The
  standalone `suite` check is additionally red on the FT-21 latest-tag assertion.
  This is the known chicken-and-egg, not a defect. `enforce_admins: false` is set
  precisely so `gh pr merge <N> --squash --delete-branch --admin` still works.
  Everything goes green on the next push after the tag exists (those
  `startup_failure` runs are NOT retryable — see FT-21 note (3)).
- [ ] **Tag cut:** `git tag -a ci/vX.Y.Z -m "ci/vX.Y.Z"` on the merge commit.
- [ ] **Tag pushed:** `git push origin ci/vX.Y.Z`.
- [ ] **GitHub Release created:** use `gh release create ci/vX.Y.Z --title "ci/vX.Y.Z" --notes-file -`
  with the release notes from CHANGELOG. Mark as "latest release" if it is
  the current recommended tag.
- [ ] **Release notes uploaded:** paste the `## ci/vX.Y.Z` section from
  CHANGELOG as the release body.
- [ ] **`docs/WORKFLOWS.md` updated:** current pin state (§5) reflects the
  new tag. Fleet applicability matrix (§2) reflects any new adopters.

## Post-release verification

- [ ] **Smoke on one consumer:** `CI_TAG=ci/vX.Y.Z bash install.sh <owner/repo> --repin`
  on a real adopted consumer (e.g., operations or interlog). Verify the
  ai-review gate fires on the next PR.
- [ ] **`check-pin-currency.sh --fleet` green:** no stale pins across the
  fleet (or flag known laggards as intentional).
- [ ] **🔴 Apply `actions-permissions.json` to canon itself (FT-46):** canon's
  live settings are wider than the template ships — `selected-actions.verified_allowed`
  is `true` (should be `false`, FT-46) and `workflow.can_approve_pull_request_reviews`
  is `true` (should be `false`, FT-27; note these are two *different* endpoints).
  **✅ DONE for canon 2026-07-24** — `verified_allowed: true→false`,
  `patterns_allowed → ["vladm3105/*","actions/*","github/*"]`,
  `can_approve_pull_request_reviews: true→false`. (`default_workflow_permissions`
  was already `read`; the `access` section is **skipped on canon — it is PUBLIC**
  and that endpoint 422s.) Verified safe first: no canon workflow uses a
  verified-creator action, `docs-sync` only `gh pr comment`s, and canon has **no**
  `self-doc-maintainer` caller, so nothing needed create-and-approve.
  **⚠️ Do NOT run `apply-standards.sh --apply --tier product` on canon.** It also
  PUTs `branch-protection-product.json`, which requires `call / ai-review` +
  `call / composition` — reusables canon does **not** self-run — so every canon PR
  would hang forever (the F2 hang), and it would clobber the FT-52 protection.
  Apply the actions sections directly instead:
  `jq -c '.<section> | walk(if type=="object" then with_entries(select(.key|startswith("_")|not)) else . end)' install/templates/actions-permissions.json | gh api -X PUT repos/<owner>/<repo>/actions/permissions/<endpoint> --input -`
  — or use `apply-standards.sh --skip-branch-protection`.
- [ ] **🔴 Apply to each CONSUMER — but scan its `uses:` FIRST (CI-0011):**
  `apply-standards.sh --apply` PUTs the whole `selected_actions` object, so it
  **replaces `patterns_allowed` wholesale and flips `verified_allowed` to false**
  with no target-side check. Any action the target repo calls that is not
  GitHub-owned and not under `vladm3105/*` will then `startup_failure` with **zero
  logs**. Before applying to a repo, run:
  `grep -rnoE 'uses:[[:space:]]*[^[:space:]]+' <repo>/.github/workflows/*.y*ml | sort -u`
  and confirm every hit is `actions/*`, `github/*`, or `vladm3105/*`. (Match
  `uses:` unanchored — an anchored `^\s*uses:` silently misses the dominant
  list form `- uses: …`; and use `[[:space:]]`, not `\s`, which is a GNU-grep
  extension that matches a literal `s` on BSD/macOS and returns a false all-clear.)
  **Known non-admitted callers as of 2026-07-24 — do NOT blanket-apply to these:**
  `web-site` (`Azure/static-web-apps-deploy` — verified creator, admitted TODAY only
  by `verified_allowed: true`; applying would brick its only deploy job) and
  `knowledge-rag` (`codecov/codecov-action`, verified; plus `gitleaks/gitleaks-action`,
  already blocked). Both repos are paused/independent and outside the fleet rollout —
  named here so a later "fleet uniformity" pass does not silently break them.
  (`iplanic`'s `lycheeverse/lychee-action` is non-verified and already blocked today —
  applying changes nothing for it.)
- [ ] **Consumer drift note (CI-0011):** once a consumer re-pins to the tag carrying
  this change, `standards-drift` emits `verified_allowed: canon=false actual=true`
  every run until the settings write above happens. Default is warning-only, so
  nothing goes red unless an arming runbook passes `strict: true` — but don't let it
  accrete as permanent yellow.
- [ ] **CHANGELOG promotion:** the `## Unreleased` header is cleared and a
  new empty `## Unreleased` section is ready for the next release cycle.
