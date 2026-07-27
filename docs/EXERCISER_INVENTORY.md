# Exerciser inventory — aidoc-flow-ci

Every consumer-facing surface canon ships, mapped to the thing that **exercises**
it — a self-caller that runs it in canon's own CI, an offline test that drives
its logic, or an explicit record that it is **knowingly unexercised**, with the
reason.

## Why this file exists

PLAN-018 F1 — a bootstrap template deleted at `ci/v2.2.0` — shipped broken for
**nine releases**. Not because it was hard to find, but because **nothing
exercised canon's own output**: canon is already adopted, so it never runs its
own cold start, and no test drove the installer's resolution. The same root
cause produced FT-23 (canon runs almost none of the reusables it ships) and made
FT-15 reachable (a resolver bug nothing executed).

The failure mode is not "a bug." It is **an untracked surface** — a thing canon
distributes that no exerciser touches. This inventory makes that set explicit and
`tests/test_exerciser_inventory.sh` keeps it complete: **every `manifest.json`
surface and every reusable workflow must have a row here.** A new template added
without an inventory row fails the suite — the F1 failure mode caught in a new
place, per PLAN-018 contract item 7.

## Exerciser kinds

| Kind | Meaning |
| --- | --- |
| **self-caller** | a canon workflow runs this reusable in canon's own CI, so a regression fails canon's own checks |
| **offline-test** | a `tests/*.sh` drives the surface's logic without executing the workflow (the only option when canon cannot run the reusable — see FT-23) |
| **descoped** | deliberately NOT self-run, with a standing reason; regression risk is carried by an offline-test or accepted |
| **unexercised** | a genuine gap, tagged with the FT that closes it |

## Reusable workflows (16)

Canon ships 16 `workflow_call` reusables. It self-runs **5** of them today
(`audit-trail-check`, `docs-sync`, `secret-scan`, `pre-commit`, `markdown-lint` —
a canon workflow carries a non-comment `uses:` at that reusable, so a regression
fails canon's own checks);
the rest are covered offline or descoped. (The table also lists the
`audit-trail.yml` *caller* template — a consumer surface, not a 17th reusable.)

| Surface | Exerciser | Kind |
| --- | --- | --- |
| `.github/workflows/audit-trail-check.yml` | `audit-trail.yml` self-caller → `call / verify` on every PR | self-caller |
| `.github/workflows/audit-trail.yml` | canon's own `audit-trail.yml` IS this caller template, run on every PR (the `call / verify` gate) | self-caller |
| `.github/workflows/docs-sync.yml` | `self-docs-sync.yml` self-caller; `test_resolver.sh` (pin resolver) | self-caller + offline-test |
| `.github/workflows/secret-scan.yml` | `self-secret-scan.yml` self-caller | self-caller |
| `.github/workflows/standards-drift.yml` | `test_resolver.sh` (pin resolver). `standards-drift-self.yml` runs `sync/check-standards-drift.sh` **directly**, NOT this reusable — the reusable's fetch/resolver wrapper is exercised only offline (its own header notes canon "does not exercise this fetch path") | offline-test |
| `.github/workflows/pre-commit.yml` | `self-pre-commit.yml` self-caller (runs the reusable on canon's own config every PR); `test_install.sh` Part 4 (fragment selects a stage-matching hook); merge covered by `test_precommit_merge.sh` | self-caller + offline-test |
| `.github/workflows/markdown-lint.yml` | `self-markdown-lint.yml` self-caller (blocking; runs canon's root `.markdownlint.json` on every PR) | self-caller |
| `.github/workflows/ai-review.yml` | `test_resolver.sh` (resolver — the FT-15 surface), `test_checknames.sh`, `test_contract.sh` | descoped (library repo, founder 2026-07-22; live self-run needs LiteLLM + reviewer App + self-hosted pool this library does not warrant) + offline-test |
| `.github/workflows/composition.yml` | `test_checknames.sh`, `test_contract.sh` | descoped (library; live self-run needs the reviewer App identity) + offline-test |
| `.github/workflows/doc-maintainer.yml` | `test_resolver.sh` (resolver) | descoped (library; needs LiteLLM + App) + offline-test |
| `.github/workflows/auto-merge-ai-prs.yml` | `test_contract.sh` (I/O contract) | descoped — self-running it would auto-merge canon's own PRs; the behaviour cannot be safely dogfooded + offline-test |
| `.github/workflows/codeql.yml` | `test_contract.sh` | descoped — consumer-customized (`languages` input); not adopted on canon |
| `.github/workflows/dep-scan.yml` | `test_contract.sh` | descoped — PLAN-014 optional report-only scanner; not adopted on canon |
| `.github/workflows/trivy-scan.yml` | `test_contract.sh` | descoped — PLAN-014 optional report-only scanner; not adopted on canon |
| `.github/workflows/sast-scan.yml` | `test_contract.sh` | descoped — PLAN-014 optional report-only scanner; not adopted on canon |
| `.github/workflows/labeler.yml` | `test_contract.sh` | descoped — PR-labeling automation; low regression risk, not self-run |
| `.github/workflows/links.yml` | `test_contract.sh` | descoped — link checker; self-run candidate, not currently adopted |

> **The descoped AI-flows are a founder decision, not an oversight.**
> `aidoc-flow-ci` is a **library**; running `ai-review`/`doc-maintainer`/
> `composition` on itself would require registering a `ci-runner,single-use`
> self-hosted pool plus the reviewer App and LiteLLM secrets purely to dogfood —
> cost that a library repo does not warrant (founder, 2026-07-22). The
> regression risk that mattered — the pin **resolver** (FT-15 broke it silently
> for months) — is carried offline by `test_resolver.sh` (55 assertions), which
> exists *because* canon cannot self-run those reusables. This is the correct
> trade for a library, and it is recorded here rather than left implicit.

## Consumer config + governance surfaces

These are `manifest.json` surfaces that are not reusables. Their exerciser is the
installer/update path plus the offline tests that drive it.

| Surface | Exerciser | Kind |
| --- | --- | --- |
| `.github/ai-review/config.json` | `install.sh` bootstrap (`test_install.sh`); `test_contract.sh` schema | offline-test |
| `.github/doc-maintainer.json` | `--update` walk (`test_scripts.sh`) | offline-test |
| `.github/doc-maintainer-conventions.md` | `--update` walk | offline-test |
| `.github/docs-sync.json` | `--update` walk; `self-docs-sync.yml` consumes canon's own copy | self-caller + offline-test |
| `.github/dependabot.yml` | `apply-standards.sh` subset-check (`test_scripts.sh`) | offline-test |
| `.github/CODEOWNERS` | `install.sh` substitution (`test_install.sh`); `apply-standards.sh` | offline-test |
| `.github/pull_request_template.md` | `--update` walk | offline-test |
| `.markdownlint.json` | canon carries its own root copy (= shipped template); `self-markdown-lint.yml` enforces it | self-caller |
| `.yamllint.yaml` | `install.sh` bootstrap; canon's own `.yamllint.yaml` drives `test_lint.sh` yamllint | self-caller + offline-test |
| `.lychee.toml` | `links.yml` config; consumer-populated | descoped — consumer-customized |
| `install/templates/pre-commit-hook-block.yaml` | `test_install.sh` Part 4 (stage-matching hook) + `test_precommit_merge.sh` (URL-keyed merge, pseudo-repo exemption, fail-closed) | offline-test — MERGED into the consumer file, not a 1:1 `manifest.json` surface |
| `scripts/pre_push_check.sh` | canon's own pre-push hook + `test_scripts.sh` | self-caller + offline-test |
| `CLAUDE.md` | `install.sh` template-fill (`test_install.sh`); `check-governance` | offline-test |

## Canonical scripts

| Surface | Exerciser | Kind |
| --- | --- | --- |
| `install/install.sh` | `test_install.sh`, `test_precommit_merge.sh`, `test_version_sync.sh` | offline-test |
| `install/deploy-ci-wizard.sh` | `test_version_sync.sh` (VERSION resolution); scaffold path | offline-test |
| `install/apply-standards.sh` | `test_scripts.sh` | offline-test |
| `install/check-precommit-hooks.sh` | `test_precommit_stage.sh` (exit 0/1/2 on green/vacuous/undeterminable configs; agrees with the reusable's default stage) | offline-test |
| `install/required-context-map.py` | `test_required_contexts.sh` (the invariant + non-obvious chains + teeth) | offline-test |
| `tests/lib_count_stage_hooks.py` | `test_install.sh` Part 4 (fragment stage count) | offline-test |
| `install/set-litellm-secrets.sh` | — | **unexercised** — operator helper, no consumer surface, low risk; `accepted-no-FT` |
| `scripts/sync-version-refs.sh` | `test_version_sync.sh`; pre-commit hook | self-caller + offline-test |
| `scripts/release.sh` | `test_release.sh` (guard rejections: bad version, tag-without-dry-run-gate, existing-tag prep, on-main) | offline-test |
| `sync/check-drift.sh` | `test_scripts.sh` | offline-test |
| `sync/check-pin-currency.sh` | `test_scripts.sh` | offline-test |
| `sync/check-standards-drift.sh` | `standards-drift-self.yml` self-caller; `test_scripts.sh` | self-caller + offline-test |

## Third-party surfaces canon distributes

Not a workflow or script, but shipped to every adopter and therefore in scope for
"who maintains this":

| Surface | Exerciser | Kind |
| --- | --- | --- |
| `pre-commit/pre-commit-hooks` rev in the canon fragment | pinned at a frozen SHA; **no automated bump path** | **unexercised** — **FT-35** (no dependabot `pre-commit` ecosystem; bump with `pre-commit autoupdate --freeze`) |

## Open exerciser gaps (the worklist)

| Gap | Surface | Closes in |
| --- | --- | --- |
| ~~No `pre-commit` self-caller~~ | `pre-commit.yml` | **FT-36 CLOSED (PR C4)** — `self-pre-commit.yml` |
| ~~No `markdown-lint` self-caller~~ | `markdown-lint.yml`, `.markdownlint.json` | **FT-34 CLOSED (PR C4b)** — `self-markdown-lint.yml` + root `.markdownlint.json` |
| No automated rev bump | `pre-commit-hooks` rev | FT-35 |
| ~~No zero-hook detector~~ | `pre-commit` config vacuity | **FT-31 CLOSED (PR C2)** — `install/check-precommit-hooks.sh`, operator-side |
| ~~No required-context ↔ producer validator~~ | branch-protection contexts | **FT-18 CLOSED (PR C3)** — `install/required-context-map.py` + wizard preflight §6 |
