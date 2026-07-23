# Release checklist — aidoc-flow-ci

Run before cutting every `ci/vX.Y.Z` tag. Items are ordered — complete
each before proceeding to the next.

## Pre-tag

- [ ] **Schema validation:** `python3 -m json.tool docs/router-config.schema.json >/dev/null`
  and any other schema files (ai-review config, verdict schema). CI must pass.
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
  tag being cut.
- [ ] **`install.sh` fallback matches:** `CI_TAG_FALLBACK` in `install.sh`
  matches `VERSION`. Grep: `grep CI_TAG_FALLBACK install/install.sh`.
- [ ] **🔴 COLD-START DRY-RUN (founder-executed) — PLAN-018 FT-30.** Canon is
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
- [ ] **CHANGELOG promotion:** the `## Unreleased` header is cleared and a
  new empty `## Unreleased` section is ready for the next release cycle.
