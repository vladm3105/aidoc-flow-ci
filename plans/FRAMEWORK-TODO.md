# FRAMEWORK-TODO — `aidoc-flow-ci`

Canon inconsistencies / bugs / improvement notes discovered while driving
the docs + workflows. Logged inline as found (per the framework-TODO
convention — examples/adoption ARE the system-under-test; their friction is
the framework's truth). Each item names the surfaces + a fix sketch; clear
when resolved.

## Open

### FT-52 — canon does not govern itself to the standard it ships (🔴 founder)

**Found:** 2026-07-23, PLAN-019 five-lens pre-prod review (G4 self-governance, S1).
**Surface:** canon `main` — `branches/main/protection` → 404, `rulesets` → `[]`
(verified live), while `install/templates/branch-protection-product.json` names
`aidoc-flow-ci` product-tier.
**Effect:** canon `main` is unprotected AND `ci/v*` release tags are mutable — the
fleet pins canon by mutable tag, so a force-moved tag reaches every consumer next
run with nothing stopping it.
**Fix (🔴 founder-executed runbook, NOT AI-run):** `plans/ROLLOUT_ft52-canon-self-governance.md`
— (A) immutable `ci/v*` tag ruleset (deletion + non-fast-forward blocked, creation
allowed); (B) branch protection with **canon's own check set** (NOT product-tier —
requiring `ai-review`/`composition` canon doesn't self-run would hang every PR, F2).
**RESOLVED — EXECUTED 2026-07-24 at the founder's in-session direction. Both parts
are LIVE:** Part A tag ruleset `19687369` (active, no bypass actors; create allowed,
delete + force-move rejected — verified by execution) and Part B branch protection on
`main` with canon's own 5-check set (0 required reviews, `enforce_admins: false`,
`required_signatures: false`, so AI auto-merge and the FT-21 `--admin` prep path both
still work). See CHANGELOG `## Unreleased` +
`plans/ROLLOUT_ft52-canon-self-governance.md` (header records the applied state).

### FT-51 — `runners.md` leads with org-level registration, impossible on a personal account

**Found:** 2026-07-23, PLAN-019 five-lens pre-prod review (G4 docs, §5).
**Surface:** `docs/runners.md:150` "### 3.1 Org-level registration (recommended)",
with §3.2 per-repo as "fallback".
**Effect:** `vladm3105` is a personal account; org-level runner registration is
impossible (PLAN-009 §Phase-0), so the doc sends an operator down an unavailable
path first.
**Fix:** flip the primacy — §3.1 per-repo (primary, with the personal-account
note), §3.2 org-level scoped to a true GitHub org only.
**RESOLVED (Unreleased -> `ci/v2.12.0`, PLAN-019 Workstream D / G4):** see CHANGELOG
`## Unreleased`.

### FT-50 — GNU-only `sed -i` + unguarded `mapfile` break on adopter macOS

**Found:** 2026-07-23, PLAN-019 five-lens pre-prod review (G4 portability, §5).
**Surface:** `install/install.sh` two `--repin` `sed -i -E` + an unguarded
`mapfile`; `install/deploy-ci-wizard.sh` one `sed -i`; `install/README.md:38`
implied bash4 was avoidable by skipping the pre-push hook.
**Effect:** bare GNU `sed -i` errors on BSD/macOS sed (adopters run these); a
macOS bash-3.2 user hits a cryptic `mapfile: command not found`.
**Fix:** portable `sed -i.bak … && rm` (3 sites); a `BASH_VERSINFO` guard up front
in `install.sh` with an actionable message; corrected `install/README.md` (bash≥4
is unconditional for install.sh). `test_scripts.sh` 27→29; a bare-`sed -i` revert
goes red.
**RESOLVED (Unreleased → `ci/v2.12.0`, PLAN-019 Workstream D / G4):** see CHANGELOG
`## Unreleased`.

### FT-49 — `FLEET_BRANCH_PROTECTION_ARMING.md` imperatively repins to a 10-release-old tag

**Found:** 2026-07-23, PLAN-019 five-lens pre-prod review (G3 doc-currency, §4).
**Surface:** `docs/FLEET_BRANCH_PROTECTION_ARMING.md:64-67` said `CI_TAG=ci/v2.1.0`
in a founder-executed re-pin runbook; `docs/REPO_STANDARDS.md:1368` said the
auto-merge templates pin `@ci/v2.0.0` (actual `@ci/v2.11.0`).
**Effect:** an operator following the runbook would re-pin the fleet ~10 releases
backwards.
**Fix:** both rewritten version-neutral — "the current release tag (`../VERSION`)".
**RESOLVED (Unreleased → `ci/v2.12.0`, PLAN-019 Workstream C / G3):** see CHANGELOG
`## Unreleased`. Remaining §4 content-currency (architecture.md rows/header,
4-doc markdown-autofix corruption, README EXERCISER row) tracked as a follow-up
doc-currency PR.

### FT-48 — `release.sh prep` has no on-main / up-to-date guard

**Found:** 2026-07-23, PLAN-019 five-lens pre-prod review (G3 ship-with-tag).
**Surface:** `scripts/release.sh` `prep()` checked tag/VERSION/tree/branch but not
`HEAD == origin/main` (which `tag()` does).
**Effect:** a prep from a stale/off-main tree promotes an incomplete
`## Unreleased` CHANGELOG into the release; `tag`'s VERSION-match guard can't catch
it (VERSION still matches).
**Fix:** `prep()` gains the same on-main + `origin/main`-up-to-date guards `tag`
carries, after the tag/VERSION checks (so a current-version prep still rejects with
its specific reason). `test_release.sh` 21→27: fixture tests reject off-main and
local-ahead prep, mutate nothing; removing either guard goes red.
**RESOLVED (Unreleased → `ci/v2.12.0`, PLAN-019 Workstream B / G3):** see CHANGELOG
`## Unreleased`.

### FT-47 — CI only ever exercises the fallback YAML backend

**Found:** 2026-07-23, PLAN-019 five-lens pre-prod review (G3 ship-with-tag).
**Surface:** `.github/workflows/tests.yml` installed `python3-yaml` (PyYAML) only;
`install.sh` prefers ruamel.yaml, so the ruamel merge path never ran in CI.
**Effect:** the ruamel round-trip (comment-preservation, and its distinct object
semantics) was uncovered — FT-44's ruamel-only `__ne__` false-positive was green
under PyYAML and only a human reviewer caught it.
**Fix:** run the suite under PyYAML, then a second step installs
`python3-ruamel.yaml` and re-runs `test_precommit_merge.sh` +
`test_precommit_refresh.sh` under ruamel. `test_contract.sh` asserts the ruamel
step is present (removing it goes red).
**RESOLVED (Unreleased → `ci/v2.12.0`, PLAN-019 Workstream B / G3):** see CHANGELOG
`## Unreleased`.

### FT-53 — `standards-drift` never compares `patterns_allowed`, now the whole boundary

**Found:** 2026-07-24, CI-0011 pre-push review (security-auditor + code-reviewer,
both independently).
**Surface:** `sync/check-standards-drift.sh:240` — `for k in github_owned_allowed
verified_allowed; do`. `patterns_allowed` is never compared against canon.
**Effect:** tolerable while `verified_allowed: true` was a wide standing grant. Now
that CI-0011 set it `false`, `patterns_allowed` is the **entire** non-GitHub-owned
admission — and it is the one field drift ignores. An operator who edits a
consumer's `patterns_allowed` in the Settings UI (adding `aquasecurity/*`, or
dropping `vladm3105/*` and bricking every canon reusable with a silent
`startup_failure`) gets **zero drift**, including in strict mode.
`tests/test_contract.sh` does not cover this — it reads the local canon template,
never a deployed repo.
**Fix:** extend the drift comparison to `patterns_allowed` (set-compare the array,
order-insensitive; report added/removed owners). Mind that the comparison is
against the template fetched at the consumer's own pinned tag, so a consumer on an
older pin must not be reported as drifted for a pattern that tag never shipped.
**RESOLVED (2026-07-24, Unreleased → next tag):** `check-standards-drift.sh` now
compares `patterns_allowed` as a set, reporting MISSING (availability — a blocked
action `startup_failure`s silently) and EXTRA (supply chain — boundary wider than
CI-0011 decided) as distinct conditions. Order-insensitive, since the API returns
arbitrary order. MISSING accounts for glob subsumption (`vladm3105/*` covers
`vladm3105/aidoc-flow-ci/*`), without which the in-flight CI-0011 rollout would
have produced a false "blocked at run-init" and hard-failed `--strict` on every
consumer widened ahead of its pin. `tests/test_scripts.sh` 29→50; five mutations
confirmed red (comparison removed; order-sensitive compare; MISSING/EXTRA
collapsed; drift increments removed; subsumption removed).
REPO_STANDARDS §4.3 updated — the gap paragraph is replaced by what the two layers
actually cover. Verified live against canon: 0 actions-related drift.

### FT-46 — canon has not applied its own FT-27 values; allowlist is wider than the rule

**Found:** 2026-07-23, PLAN-019 five-lens pre-prod review (G3 ship-with-tag).
**Surface:** `install/templates/actions-permissions.json` — `verified_allowed: true`
(wider than REPO_STANDARDS §4.3); canon's LIVE `can_approve_pull_request_reviews`
is `true` while the template ships `false`.
**Effect:** `verified_allowed: true` admits every verified-creator action,
undermining the allowlist that §4.3 enforces (and that forced `gacts/gitleaks` →
binary). Separately, canon's own live settings drifted from the template it ships.
**Blocked on:** decision **CI-0011** — PLAN-019's FT-46 spec never referenced it,
so the flip was NOT shipped with `ci/v2.12.0`; held in `git stash` pending the
founder's call.
**Fix:** set `verified_allowed: false` (only github-owned + `patterns_allowed`
admit an action); `patterns_allowed` broadened to the account-wide `vladm3105/*`;
REPO_STANDARDS §4.3 + security/troubleshooting/AI_CI_DEPLOYMENT synced;
`deploy-ci-wizard.sh` preflight grep widened so `vladm3105/*` is not a false
negative; `test_contract.sh` asserts both halves (mutations confirmed red).
**G4 / 🔴:** applying `actions-permissions.json` to canon itself (and to each
consumer) is a founder-executed settings write, tracked as a RELEASE_CHECKLIST
post-release item. FT-27/FT-46 are template values until applied per-repo.
**RESOLVED — CI-0011 DECIDED 2026-07-24 (drop the verified marketplace; admit only
the owner's account). Template + docs landed; canon-apply remains G4/🔴
(Unreleased → next tag after `ci/v2.12.0`, PLAN-019 Workstream B / G3):** see
CHANGELOG `## Unreleased` + `DECISIONS.md` CI-0011.

### FT-45 — `required-context-map.py` discards the job-id half of the context

**Found:** 2026-07-23, PLAN-019 five-lens pre-prod review (G3 ship-with-tag).
**Surface:** `install/required-context-map.py` — `_jobid, name = ctx.split(" / ", 1)`
dropped `_jobid`, validating only `<name>`.
**Effect:** a context `<jobid> / <name>` with the right name but a wrong job key
(e.g. `call / check-standards-drift` when the caller job is `drift`) validated as
"producer installed", but is never emitted → arming it hangs every PR (the F2
class this tool generalizes). Latent: no shipped branch-protection template had a
wrong key, but the validator accepted one.
**Fix:** parse each caller template's `jobs:`, record which job KEYS call each
reusable (`reusable_to_jobkeys`); a context resolves only when its `<jobid>` is a
caller job that actually calls the reusable. `test_required_contexts.sh` 21→23;
dropping the check goes red; all 15 shipped `call /` contexts still resolve.
**RESOLVED (Unreleased → `ci/v2.12.0`, PLAN-019 Workstream B / G3):** see CHANGELOG
`## Unreleased`.

### FT-44 — FT-32 silently under-delivers a *modified* hook

**Found:** 2026-07-23, PLAN-019 five-lens pre-prod review (G3 ship-with-tag).
**Surface:** `install/install.sh` pseudo-repo (`local`) merge — filtered canon
hooks by `id` only, recorded no collision for a present-but-changed hook, and
printed the clean "canon block appended" summary.
**Effect:** a canon `local` hook whose id the consumer has but whose body changed
(a customized `aidoc-flow-pre-push`) was silently kept — no WARN, no NOTE, marker
stamped anyway — contradicting the merge's promise that a kept canon change is
REPORTED. Most-likely future case: a bumped `aidoc-flow-pre-push`.
**Fix:** detect a present-but-not-identical canon `local` hook, emit a distinct
`WARN` + a `SKIPPED_HOOKS=` signal routed to the partial-merge NOTE path (not the
clean summary); additions-only preservation unchanged. Also fixed a latent
`pipefail` abort the signal exposed (COLLISIONS/SKIPPED_HOOKS greps now
`|| true`-guarded). `test_precommit_refresh.sh` 18→24; disabling the detection
goes red.
**RESOLVED (Unreleased → `ci/v2.12.0`, PLAN-019 Workstream B / G3):** see CHANGELOG
`## Unreleased`.

### FT-43 — a label/draft event can supersede a RED `ai-review`

**Found:** 2026-07-23, PLAN-019 five-lens pre-prod review (G3 ship-with-tag).
**Surface:** `.github/workflows/ai-review.yml` `trust` + `ai-review` job-level
`if:` skip on non-`skip-ai-review` label events and drafts; the caller template
subscribes to `labeled,unlabeled`, omits `ready_for_review`; concurrency
`cancel-in-progress: true`.
**Effect:** a skipped required job reports green, so a label applied after a
`request_changes` flips `call / ai-review` green. Armed repos are covered by
`composition` (defence-in-depth loss); a not-yet-armed adopter (composition INERT)
has a real both-checks-green bypass.
**Fix (fail-closed, NOT step-level-skip — a fresh SUCCESS supersedes):** job-level
`if:` on both jobs gains an unarmed clause (`vars.APP_REVIEWER_1_BOT_ID == ''`) so
armed repos still clean-skip (composition holds) but unarmed repos RUN and a new
first step (`FT43-FAIL-CLOSED`, extracted + driven) `exit 1`s — the FT-29 model.
`cancel-in-progress` excludes label events; template adds `ready_for_review` +
`converted_to_draft`. `test_contract.sh` 275→283; four mutations go red.
**RESOLVED (Unreleased → `ci/v2.12.0`, PLAN-019 Workstream B / G3):** see CHANGELOG
`## Unreleased`.

### FT-42 — `ai-review`'s `secrets: inherit` is structurally forced, not deferred

**Found:** 2026-07-23, PLAN-019 five-lens pre-prod review (G1 tag-cut blocker).
**Surface:** `.github/workflows/ai-review.yml` `workflow_call` (declared `inputs:`
only, no `secrets:` block) while the body reads 8 secrets;
`install/templates/workflows/ai-review.yml` (`secrets: inherit`).
**Effect:** a caller *cannot* pass an explicit least-privilege map when the
reusable declares no `secrets:` block, so `ai-review` was forced onto blanket
`inherit` — the workspace's largest standing secret-trust surface (it was the one
AI-flow the FT-27 pass could not convert), widening to each newly-armed consumer
at rollout.
**Fix:** declare all 8 secrets in the reusable's `workflow_call.secrets`
(`required: false`; `GITHUB_TOKEN` stays auto-provided, not declared); flip the
caller template to an explicit map. Additive — existing `inherit` callers keep
working (GitHub forwards inherited secrets by name regardless), unset = empty
inside the reusable either way, so self-skip behaviour is unchanged.
`test_contract.sh` adds a two-way completeness check (declared AND forwarded);
revert-to-inherit / drop-a-declared / drop-a-forwarded each go red (`contract`
272 → 275). Closes the FT-27 residual.
**RESOLVED (Unreleased → `ci/v2.12.0`, PLAN-019 Workstream A / G1):** see CHANGELOG
`## Unreleased`.

### FT-41 — `markdown-lint`'s blocking default is unasserted

**Found:** 2026-07-23, PLAN-019 five-lens pre-prod review (G1 tag-cut blocker).
**Surface:** `.github/workflows/markdown-lint.yml:63` (`fail-on-findings` input
`default: true`); `tests/test_contract.sh` had no assertion on it.
**Effect:** verified by mutation — `default: true → false` left
`test_contract.sh` at 271/0. The three report-only scanners assert their callers
ship `fail-on-findings: false`, but the inverse (markdown-lint blocks by default)
was uncovered, so canon could flip the fleet's markdown gate to report-only with
the suite green.
**Fix:** `test_contract.sh` parses the reusable's `fail-on-findings` input default
(`yaml.safe_load`, handling PyYAML's bare-`on:`→`True`) and asserts it is `True`;
a flip to `false` goes red (`contract` 271 → 272).
**RESOLVED (Unreleased → `ci/v2.12.0`, PLAN-019 Workstream A / G1):** see CHANGELOG
`## Unreleased`.

### FT-40 — the FT-28 SHA-peel guard is untested; shipped code can be disabled with the suite green

**Found:** 2026-07-23, PLAN-019 five-lens pre-prod review (G1 tag-cut blocker).
**Surface:** `.github/workflows/ai-review.yml` (both resolvers' FT-28 SHA/tag peel
comparison); `tests/test_resolver.sh` `verify()` (a re-implementation, not the
shipped block) + grep-presence assertions.
**Effect:** verified by mutation — `if false;` on both resolvers' `if [ -n
"$CANON_SHA" ] && [ -n "$CANON_TAG" ]` guard left `test_resolver.sh` at 62/0. The
FT-28 gate (a `@<fork-sha> # ci/vX.Y.Z` pin cannot fetch/execute never-merged
canon code) could be disabled and shipped to the fleet undetected, because canon
has no self-caller that runs `ai-review` (FT-23).
**Fix:** wrap each resolver's peel comparison in extractable
`# >>> FT28-PEEL-VERIFY >>>` markers (comment-only, no behaviour change); drive
BOTH shipped blocks from `test_resolver.sh` with `curl` stubbed — assert a
matching SHA is accepted, a mismatch and an empty peel rejected, a tag-only pin
skips the peel. Delete the `verify()` re-implementation. `if false;` (either
resolver) and neutering the equality check now go red.
**RESOLVED (Unreleased → `ci/v2.12.0`, PLAN-019 Workstream A / G1):** see CHANGELOG
`## Unreleased`.

### FT-39 — `fetch_template` writes whatever the transport returns; `--update` infers non-interactive from a missing TTY

**Found:** 2026-07-23, PLAN-019 five-lens pre-prod review (G1 tag-cut blocker).
**Surface:** `install/install.sh` `fetch_template` (the `curl -fsSL … -o "$dst"`
body); the `--update` per-file fetch; the `[ ! -t 0 ]` interactivity inference;
the pre-commit fragment fetch feeding `marker_version()`.
**Effect:** `curl -f` rejects a 4xx/5xx, but a proxy/CDN/captive portal can serve
a **200 with an empty or HTML body**. Written over a canon gate template, that
silently 0-bytes a required check; written as the pre-commit fragment, a
truncated/pre-`v2` body makes `marker_version()` read `1` and freezes every
legacy consumer's FT-32 refresh (fails open). Separately, `[ ! -t 0 ]` was read as
`--non-interactive`, so a piped `--update` overwrote every customized
`safe_to_replace` caller with the canon body without consent.
**Fix:** new `validate_fetched` helper (extractable `# >>> FETCH-VALIDATE >>>`
markers) rejects empty / HTML-document bodies (matched on the opening tag over a
bounded prefix, so a markdown template opening with `<!--` is not false-rejected)
and, with an optional 3rd arg, a missing required marker; `fetch_template` and the
`--update` fetch both call it;
the pre-commit fragment fetch asserts the versioned
`^# CANON: aidoc-flow-ci pre_push_check v[0-9]+` marker; `--update` defaults a
missing TTY to keep-local (destructive replace now needs explicit
`--non-interactive`). Teeth: `tests/test_install.sh` Part 5 drives the extracted
validator; three mutations each go red.
**RESOLVED (Unreleased → `ci/v2.12.0`, PLAN-019 Workstream A / G1):** see CHANGELOG
`## Unreleased`.

### FT-38 — four fleet repos pin `pre-commit-hooks` at a mutable rev the refresh cannot move

**Found:** 2026-07-23, PLAN-018 Workstream D / PR D1 pre-push review (fleet
simulation across all 7 sibling configs).
**Status:** OPEN — a rollout worklist item, not a defect in FT-32.

FT-32's refresh is **additive only**: on a repo-URL collision the merge keeps the
consumer's entry and only WARNs. `operations`, `framework`, `iplanic` and
`iplan-runner` already declare
`https://github.com/pre-commit/pre-commit-hooks` at **`rev: v5.0.0`** — a mutable
git tag — so the refresh delivers canon's other lines but cannot move them to
canon's SHA pin (`3e8a8703…`, frozen v6.0.0).

That matters more than a normal drift item because of what the fragment itself
argues: pre-commit `pip install`s the cloned tree, so the upstream build backend
runs arbitrary code at INSTALL time on developer machines and on the ephemeral
CI pool, which re-resolves the ref every run — a moved tag reaches the fleet
within one CI cycle. Canon SHA-pins every `uses:` for exactly this reason
(REPO_STANDARDS §4.3).

Simulated refresh outcome (missing canon lines, before → after):

| repo | before | after | residual |
| --- | --- | --- | --- |
| operations | 19 | 6 | kept `rev`, wrapper `name:`/`entry:`, flow-style root key |
| framework | 18 | 1 | kept `rev` |
| iplanic | 18 | 1 | kept `rev` |
| iplan-runner | 1 | 1 | kept `rev` |
| interlog / engramory / iplan-standard | 5 | 0 | — |

**Fix sketch:** per-repo decision during the rollout wave, not a canon change —
each repo either accepts canon's SHA pin (drop their `rev:` line and let the
refresh deliver it) or documents why it keeps `v5.0.0`. Do **not** make the merge
overwrite a consumer `rev`: that is the property protecting deliberate pins.
Revisit only if the fleet converges on canon's pin anyway.

### FT-36 — canon does not self-run the `pre-commit` reusable it ships

**Found:** 2026-07-22, PLAN-018 PR-B pre-push review.
**Status:** CLOSED (PLAN-018 Workstream C / PR C4, 2026-07-23) —
`.github/workflows/self-pre-commit.yml` runs canon's `.pre-commit-config.yaml`
through the `pre-commit` reusable on every PR (public → ubuntu-latest, pinned to
the released tag). Canon self-runs 4 of its 16 reusables now (was 3). Adoption
surfaced a real non-conformance (`VERSION` had no trailing newline →
`end-of-file-fixer`), fixed, with the release checklist updated so a future prep
does not reintroduce it. Original root cause: canon ships a surface nothing
exercises (same class as FT-23, FT-34).

`.github/workflows/pre-commit.yml` is the `workflow_call` definition; **no canon
workflow calls it**. So PR-B's Wave-0 self-adoption of the commit-stage hooks is
enforced only for developers who ran `pre-commit install` locally — canon's own
CI never runs the reusable whose vacuity was PLAN-018 F3. A regression in the
reusable's stage handling would ship to the fleet unseen, which is exactly how
F3 survived.

`tests/test_install.sh` Part 4 partly compensates: it asserts the fragment has
default-stage hooks and that the reusable's empty-`run-stage` branch still runs
bare. That is a static check of the premise, not an execution of the reusable.

**Surfaces:** `.github/workflows/` (a self-caller), `docs/REPO_STANDARDS.md` §16
(canon dogfoods its own canon).

**Fix sketch:** Workstream C, alongside the `ai-review`/`doc-maintainer`
self-callers (FT-23). A `pre-commit` self-caller is cheaper than those two — it
needs no LiteLLM secret and no App identity, and canon is a public repo so it
can run on `ubuntu-latest` per the fork-code-executing rule. Likely the first
self-caller to land.

### FT-37 — F2's producer ships fleet-wide but only `operations` can run it

**Found:** 2026-07-22, PLAN-018 PR-B pre-push review.
**Status:** OPEN — not a defect in F2; a rollout prerequisite F2 makes newly
load-bearing.

PR-B installs the `pre-commit` caller unconditionally, including on private
repos. Per the runner policy, private repos MUST run on
`["self-hosted","ci-runner","single-use"]`, and only `operations` currently has
that pool registered. On `business` / `iplanic` / `interlog` the newly-required
check would **queue forever** — the same "never reports" symptom F2 exists to
cure, arriving by a different route. `timeout-minutes` starts at job *start*, so
it never fires.

This is not new in kind (`ai-review` and `composition` bootstrap identically and
have the same dependency), but F2 makes a *required* context depend on it.

**Surfaces:** host runner registration (🔴 founder), `docs/runners.md`,
`plans/PLAN-009_fleet-v2-cutover.md` Phase 0.

**Fix sketch:** none in canon — this is the existing PLAN-009 Phase 0 pool
registration, already 🔴-gated on the founder. Record here so the rollout
sequencing does not treat "F2 landed" as "F2 is live for the fleet". Cross-check
against PLAN-009 Phase 0 rather than duplicating its runbook.

### FT-35 — canon's first third-party `rev` has no automated bump path

**Found:** 2026-07-22, PLAN-018 PR-B (F3).
**Status:** OPEN — non-blocking; the pin is correct today (`v6.0.0`, the current
latest, verified against the upstream tag list, and all three hook ids confirmed
present at that ref before pinning).

`install/templates/pre-commit-hook-block.yaml` now pins
`pre-commit/pre-commit-hooks` at a frozen-SHA `rev`
(`3e8a870…  # frozen: v6.0.0`). Whatever bump path is chosen MUST use
`pre-commit autoupdate --freeze` — a plain `autoupdate` rewrites the SHA back to
a mutable tag and quietly undoes the pin. Nothing updates it: neither this
repo's `.github/dependabot.yml` nor the consumer template
`install/templates/dependabot.yml` declares a `pre-commit` ecosystem — they
cover `github-actions`, `docker`, and (template only)
`pip`/`npm`/`gitsubmodule`.
So the rev canon ships to every fresh adopter will silently age, and the
workspace already shows the drift this produces: sibling repos currently sit at
`v4.6.0` and `v5.0.0`.

**Surfaces:** `.github/dependabot.yml`, `install/templates/dependabot.yml`,
`install/templates/pre-commit-hook-block.yaml`.

**Fix sketch:** confirm FIRST whether Dependabot supports a `pre-commit`
ecosystem — do not assume it does; if it does not, the remedy is a scheduled
`pre-commit autoupdate` workflow opening a PR, or Renovate. Whichever is
chosen must cover BOTH canon's own config and the shipped consumer template,
or consumers inherit a pin nothing maintains. Pairs naturally with the
Workstream C exerciser inventory: "who updates this surface" is the same
question the inventory asks.

### FT-34 — canon does not dogfood its own markdown gate

**Found:** 2026-07-22, PLAN-018 PR-A pre-push run.
**Status:** CLOSED (PLAN-018 Workstream C / PR C4b, 2026-07-23) — canon carries
its own root `.markdownlint.json` (= the shipped template, with `MD004` pinned to
`dash` so `--fix` yields conventional `-` bullets) and runs
`self-markdown-lint.yml` as a **blocking** gate. The 174 "MD013 findings" that
prompted this were measured against markdownlint's DEFAULT config; canon's actual
shipped standard has `MD013` **off**, so the real work was 347 structural nits
(MD004/MD032/MD049/…), 304 auto-fixed by `markdownlint-cli2 --fix` and 43 fixed
by hand (code-fence languages, `|`-in-table-cell escapes, wrapped issue-refs read
as H1). Canon's docs are now fully conformant; the shipped template gained the
same `MD004: dash` pin (consumer-facing improvement — consistent bullets).

`scripts/pre_push_check.sh` runs `markdownlint-cli2` over the changed `.md`
files **in full**, and this repo ships **no `.markdownlint.json`**, so
defaults apply — including `MD013` at 80 columns. Measured on an unmodified
`origin/main` checkout with a one-line probe commit: **122 MD013 findings in
`CHANGELOG.md` alone**, none of them introduced by the probe. Any change to
that file therefore fails the check on prose nobody in this PR wrote.

Three separate gaps behind it:

1. **No config.** Canon ships `.markdownlint.json` to consumers as a template
   surface (§4.4) but does not carry one itself.
2. **`MD013` cannot be satisfied by the table rows** §16.9 and the tier tables
   need; the usual remedy is `"tables": false`, which requires (1).
3. **The gate is inert in both places it should bite** — no git hook is
   installed here (`.git/hooks/pre-push` absent, so `pre_push_check.sh` only
   runs when invoked by hand), and `.github/workflows/` has **no
   `markdown-lint` self-caller** (only the reusable definition). So the rule is
   enforced on consumers and on nobody here.

**Surfaces:** `scripts/pre_push_check.sh`, a new root `.markdownlint.json`,
`.github/workflows/` (a self-caller), `docs/REPO_STANDARDS.md` §4.4.

**Fix sketch:** belongs with PLAN-018 Workstream C (the verification surface —
this is the same "canon has no exerciser for its own rule" shape as F1). Add
the repo's own `.markdownlint.json` matching the consumer template, reflow or
grandfather the existing violations, then add the self-caller so the gate is
real. Do NOT weaken the consumer-facing rule to make canon green.

### FT-33 — `tests/test_install.sh`'s call extractor has two residual evasions

**Found:** 2026-07-22, PLAN-018 PR-A cycle-3 pre-push review.
**Status:** OPEN — non-blocking. Both need pathological bash, neither is
reachable by ordinary drift, and the F1 defect class survives both (verified:
part 2's evaluation still catches a derivation hidden behind either).

The extractor joins backslash continuations into logical lines so a wrapped
`fetch_template` call is not skipped by the containment check (the cycle-2
finding). Two edges remain:

1. **A comment line ending in `\` swallows the next line.** Bash comments never
   continue, but the accumulator joins them, so `# note \` directly above a
   stray `fetch_template` makes that call invisible to containment.
2. **A trailing `\` on the file's last line never flushes the buffer**, dropping
   a call held in it.

**Surfaces:** `tests/test_install.sh` (the `python3` extractor in part 0).

**Fix sketch:** test `line.lstrip().startswith("#")` *before* the
`endswith("\\")` branch — that matches bash semantics and closes (1)
completely; add a post-loop `if buf:` flush for (2). Three lines total. Fold
when the extractor is next touched for another reason rather than re-opening a
reviewed file for its own sake.

### FT-32 — the canon pre-commit fragment is un-upgradeable in any adopted consumer

**Found:** 2026-07-22, PLAN-018 re-scope review (independent pass on Workstreams
B-D).
**Status:** CLOSED (PLAN-018 Workstream D / PR D1, 2026-07-23) — the `CANON:`
marker is now VERSIONED (`# CANON: aidoc-flow-ci pre_push_check vN`, canon at
**v2**) and `install.sh` bootstrap RE-MERGES when a consumer's `vN` is older than
canon's, then stamps canon's (so the next run no-ops). That makes
`manifest.json`'s "re-run install.sh to refresh those" TRUE for this file for the
first time — previously ANY marker meant no-op forever, and with `--update`
excluding the file and `--apply` writing no content, an adopted consumer could
never receive a fragment change. Chose the versioned marker over a new
`--refresh-hooks` mode precisely because it makes the DOCUMENTED path real rather
than adding a second one. The re-merge is additive and, for the `local`
pseudo-repo, de-duped by hook `id` — so a legacy consumer gets the missing canon
hooks WITHOUT duplicating one it already carries (a wart the first cut had, caught
by testing the refresh end-to-end). `test_precommit_merge.sh` guards the merge
output; `tests/test_precommit_refresh.sh` (new) guards the DECISION — it extracts
the block from `install.sh` between `# >>> PRECOMMIT-MERGE >>>` markers and drives
the version matrix, because a pre-push review restored the exact freeze by
mutation and the whole suite stayed green. **This unblocks CI-0013's "drift report
becomes the rollout worklist" — there is now a mechanism behind it.**
**BUMP `vN` whenever the fragment changes**, or adopted consumers stay frozen.

**Scope of the fix — additions only.** The re-merge never overwrites a consumer
entry, so a `rev` bump or a new hook id *inside a repo they already declare* is
reported, not applied; a partial merge stamps `vN` anyway (required to converge)
and prints that the named lines stay unapplied. On today's fleet that leaves four
repos on a mutable `rev: v5.0.0` for `pre-commit-hooks` — **named per-repo items
on the rollout worklist**, not something the refresh closes. Filed as **FT-38**.

Once a consumer's `.pre-commit-config.yaml` carries the `# CANON: aidoc-flow-ci
pre_push_check` marker, **no canon path can ever update the canon block again**:

- **bootstrap** no-ops on the marker — `install/install.sh:579` prints
  `preserve … (canon marker present — no-op)`;
- **`--update`** excludes `.pre-commit-config.yaml` from the manifest walk
  entirely (`install/install.sh:301`);
- **`apply-standards.sh --apply`** applies only labels, repo settings,
  actions-permissions and branch protection (`install/apply-standards.sh:782`) —
  it never writes a content file, and this file is report-only (`:432`).

`install/templates/manifest.json:12` instructs the operator to "Re-run
`install.sh` to refresh those" for exactly this file. **That instruction is false
once the marker exists** — the marker is what makes the re-run a no-op. The
defect has been latent since PLAN-002 shipped the marker (nothing had yet needed
to change the fragment); PLAN-018 F3 is the first change that does.

**Fix sketch:** either (a) **version the marker** — `# CANON: aidoc-flow-ci
pre_push_check v2` — and have the merge path re-merge when the consumer's marker
version lags canon's, or (b) add an explicit `--refresh-hooks` path that
re-merges the canon block idempotently regardless of marker. (a) is closer to the
existing design and keeps one code path; (b) is more explicit but adds a mode.
Either way `manifest.json:12`'s note and `install/README.md` step 6 must be
corrected in the same PR.

### FT-31 — no mechanism to detect a required check that selected zero hooks

**Found:** 2026-07-21, PLAN-018 Pass-1 review (deferred out of F3).
**Status:** CLOSED (PLAN-018 Workstream C / PR C2, 2026-07-22) —
`install/check-precommit-hooks.sh` counts hooks at the stage the `pre-commit`
reusable runs and exits 1 at zero. Runs **operator-side only** (install.sh
post-merge, `deploy-ci-wizard.sh preflight`, the release-checklist pre-tag step)
— never on the reusable's gating path, so it cannot flip a consumer's green
required check red (the constraint that deferred it out of F3). Config-parsing,
not the output-emptiness heuristic F3 rejected. Driven by `test_precommit_stage.sh`.

The general form of FT-30's third defect: `pre-commit run --all-files` prints
nothing and exits 0 when no hook matches the stage, and pre-commit exposes no
exit code, flag, or count distinguishing that from "all hooks passed" (hooks that
match but have no files print `Skipped`, so only the fully-empty-stdout case is
even distinguishable). PLAN-018 originally proposed making the reusable fail on
zero-hooks and **dropped it**: the only implementation is an output-emptiness
heuristic, and it would flip any consumer using `run-stage: manual` with no
`manual` hooks from pass to fail on re-pin. PLAN-018 F3 therefore fixes only the
canon-shipped fragment, and its fix contract is scoped to canon-*installed*
configs — a consumer's own hook-less config can still produce a vacuous pass.
**Needs:** a real signal (upstream feature request, or a canon-side pre-flight
that parses the resolved config and counts stage-matching hooks) before this can
be closed without breaking consumers.

### FT-30 — the cold-start path has no exerciser, and drifted unnoticed for 9 releases

**Found:** 2026-07-21, pre-prod review scoped to onboarding `feedback-desk`.
**Status:** OPEN — PLAN-018 re-scoped to canon completeness (CI-0013). The
`docs/RELEASE_CHECKLIST.md` cold-start item ships in **Workstream A, PR-C**
(PLAN-018 §8) — NOT Workstream C, which would make A depend on C. The 🔴
founder-executed dry-run is PLAN-018 §10. Both former founder items are closed.

Every fleet consumer adopted before `ci/v2.2.0`, so `install.sh` on a repo with
**no** prior canon surfaces has had no exerciser since. Three defects accumulated
in exactly that path, found only when scoping the `feedback-desk` onboarding:
the documented one-liner 404s at `install/install.sh:462` (the
`ai-review-${VISIBILITY}.yml` variants were deleted at the `ci/v2.2.0` release
commit); the bootstrap install set does not include the `pre-commit` caller that
emits `call / Lint / format / security hooks`, a required context on every tier
but umbrella; and the canon pre-commit fragment ships a single `pre-push`-staged
hook, so the reusable's stage-less `pre-commit run` selects **zero** hooks and
exits 0 — a required check that inspects nothing, by construction, on every
fresh adopter.

**Fix sketch — the generalisable lesson, not the three bugs:** canon has no cold-start
regression cover at all. `plans/PLAN-018_canon-completeness.md` §8 (PR-C) makes
the standing fix a **cold-start dry-run in `docs/RELEASE_CHECKLIST.md`**; without
it the next nine releases can drift the same way. Note the dry-run is a 🔴
cross-repo write (clone + 18 `gh label create` on the target), so it is
founder-executed via `ops/inbox`.

### FT-29 — `skip-ai-review` + INERT `composition` = an all-green PR with zero review

**Found:** 2026-07-21, pre-prod review (security lens).
**Status:** CLOSED (PLAN-018 Workstream B / PR B4, 2026-07-23) — fix option (1),
the most robust (catches every arming path, not just `apply-standards`). The
`ai-review` skip-notice step's `label` branch now reads `vars.APP_REVIEWER_1_BOT_ID`
and **fails closed** when it is unset: `skip-ai-review` carries a PRIOR approval
forward, but only `composition` (inert until that var is set) can have counted
one, so the skip is a fiction while the App is unarmed. `call / ai-review` goes
RED → the zero-review merge window is closed. R3 / review-event skips are
unaffected (they only fire when the App HAS approved at HEAD). `test_contract.sh`
guards the structure + the block/allow logic.
**Known residual (out of FT-29 scope, human-merge-gated):** a non-allowlisted
author / fork PR skips the whole `ai-review` job (trust gate), which reports
green; with INERT composition that is also both-green-zero-review. It is
materially safer than the label path and NOT closed here: `auto-merge` never
fires for untrusted authors (human merge required), and the trust job posts
`ai:human-review-required` + a "needs human review" PR comment, so the PR is
self-documenting as unreviewed — unlike the label path's reassuring "prior
approval carried forward" notice. Left as-is by design; revisit if the
human-merge floor is ever weakened.

`composition.yml:102-105` exits 0 with `::notice::composition INERT` when
`vars.APP_REVIEWER_1_BOT_ID` is unset, and every branch-protection template pairs
`call / composition` with `required_approving_review_count: 0`. During the
ordinary partial-provisioning window (App secrets set, LiteLLM key or bot-id var
still pending) the documented unstick label `skip-ai-review` makes ai-review
conclude SUCCESS while INERT composition also concludes SUCCESS — **both required
checks green, no review performed, zero approvals required.** `auto-merge-ai-prs`
correctly refuses (it fails closed on an unset `EXPECTED_ID`), but a human or
agent following the standing merge-on-green directive sees an all-green PR.

**Fix sketch (any one closes it):** make `skip-ai-review` fail rather than pass
under an unarmed App; have `apply-standards.sh` refuse to apply a protection
template requiring `call / composition` while the bot-id var is unset; or make
the documented rollout order (secrets + var **before** branch protection)
machine-enforced rather than prose. PLAN-018 states the ordering; nothing checks it.

### FT-28 — `ai-review`'s SHA-pin branch never verifies the SHA against its own tag comment

**Found:** 2026-07-21, pre-prod review (security lens).
**Status:** CLOSED (PLAN-018 Workstream B / PR B3, 2026-07-23) — both resolvers
(review + autofix) now peel the claimed tag via `GET /repos/…/commits/${CANON_TAG}`
(`Accept: application/vnd.github.sha`) and hard-fail when the pinned SHA is not the
tag's commit, so a `@<sha> # ci/vX.Y.Z` pin can no longer fetch/execute a commit
the tag does not point at. The notice now prints the actual `FETCH_REF` +
"(SHA verified against tag)". Inert for shipped consumers (the caller template
pins tag-only, so `CANON_SHA` is empty). `test_resolver.sh` guards both the
structure and the accept/reject logic.

Post-FT-15, `ai-review.yml:495-501` resolves assets from the consumer's own pin
and accepts either a tag or a `<40-hex> # ci/vX.Y.Z` form. The trailing tag is
documented as "can lag" and is **never** checked against `CANON_SHA`, and
`raw.githubusercontent.com` serves any commit object reachable in the public
canon repo — including unmerged fork-PR commits. The fetched `litellm_client.py`
is then executed on the runner holding the LiteLLM key and a minted App token.

Not a fork-PR escalation (the caller file is read at a trusted, event-selected
ref, and the shipped template pins tag-only), so this is review-integrity
hardening: a pin reading as `ci/v2.10.0` in code review can execute never-merged
code. **Fix:** peel the tag via `GET /git/ref/tags/$CANON_TAG` and hard-fail on
mismatch; print `FETCH_REF` in the notice, not `CANON_TAG`.

### FT-27 — privileged callers over-grant: `secrets: inherit` + actions-can-approve

**Found:** 2026-07-21, pre-prod review (security lens).
**Status:** MOSTLY RESOLVED (PLAN-018 Workstream B / PR B2, 2026-07-23). (a)
`composition-{private,public}` lost `secrets: inherit` entirely (composition
reads only the automatic `GITHUB_TOKEN`); `doc-maintainer`, `docs-sync`,
`auto-merge-ai-prs-{public,private}` now pass **explicit** `secrets:` maps of
exactly the secrets their reusables DECLARE. `test_contract.sh` guards each.
(b) `actions-permissions.json` `can_approve_pull_request_reviews` defaulted
**false**, with a note to flip it in the bot-PR adoption runbook.
**REMAINING:** `ai-review.yml`'s caller keeps `secrets: inherit` because the
`ai-review` REUSABLE declares no `secrets:` block — it reads 8 inherited
secrets undeclared. Converting it to an explicit map requires adding `secrets:`
declarations to the reusable (a security-sensitive change to the core gate);
tracked as its own follow-up so the enumeration + security review get their own
PR. Documented as a deliberate exception in `test_contract.sh` so it is not
accidental.

(a) `composition-private.yml:45`, `auto-merge-ai-prs-private.yml:36`,
`ai-review.yml:68`, `docs-sync.yml:45`, `doc-maintainer.yml:79` all use
`secrets: inherit`, handing a tag-referenced reusable every secret the repo holds
— though `composition.yml` reads exactly one, the automatic `secrets.GITHUB_TOKEN`,
which needs no inherit at all. (b) `install/templates/actions-permissions.json`
sets `can_approve_pull_request_reviews: true` for every adopter; GitHub bundles
create+approve in that one toggle, and it is needed only by the opt-in
doc-maintainer/docs-sync bot-PR flows. Harmless under
`required_approving_review_count: 0`; a standing bypass if that count is ever
raised. **Fix:** explicit `secrets:` maps per caller; default the toggle false
and flip it in the bot-PR adoption runbook.

### FT-26 — `codeql.yml`: tag-object SHA pin + no GHAS guard on private repos

**Found:** 2026-07-21, pre-prod review (portability + correctness lenses).
**Status:** CLOSED (PLAN-018 Workstream B / PR B1, 2026-07-23) — `autobuild`
repinned from the annotated tag object `21eb7f78…` to the peeled commit
`87557b9c84dde89fdd9b10e88954ac2f4248e463` (v4.36.1), matching `init`/`analyze`;
verified by peeling the tag ref via the git API. `test_lint.sh` now asserts all
three `codeql-action` steps pin ONE commit (teeth: a tag-object drift fails it).
The GHAS requirement for private repos is documented in the reusable header and
the wizard `plan` output — a hard `init` error is the intended signal, so no
fork/GHAS guard is added.

`codeql.yml:97` pins `autobuild@21eb7f7842f33eafc83782b56fff2a2c43e9696f`, which
is the **annotated tag object** for v4.36.1, not a commit — `GET
/repos/github/codeql-action/commits/21eb7f78…` returns 422, while `init` (:89)
and `analyze` (:114) correctly use the peeled commit
`87557b9c84dde89fdd9b10e88954ac2f4248e463`. Runtime risk is low (tag objects are
content-addressed) but it trips the workspace's own mandatory SHA audit, which is
the canary that catches fabricated pins. Separately, `codeql.yml` has no
fork/GHAS conditioning and no `continue-on-error` on `analyze`, unlike every
other scanner — on a private repo without Advanced Security, `init` errors
outright. **Fix:** repin to the commit SHA; document "private repos require GHAS"
in the caller header and in the wizard's `plan` output.

### FT-25 — adopter-facing gaps the cold-start review surfaced (grouped)

**Found:** 2026-07-21, pre-prod review (correctness + docs lenses).
**Status:** CLOSED (PLAN-018 Workstream B / PR B5, 2026-07-23) — all four:
(1) the wizard `scaffold` now drops the `.github/labeler.yml` starter when
labeler is chosen (was installable by no path → labeler ran against a missing
config); (2) `AI_CI_DEPLOYMENT.md` §step-2 now says to use the `-private` variant
on private repos and names the FT-9 brick, instead of the single-template advice
that predates the `-private` variants; (3) `preflight` §3 surveys ALL canon labels
from `labels.json` (was 5-of-18), and §4 reads `/actions/permissions` and branches
on `allowed_actions` — flagging `local_only` and `selected`-without-`github_owned_allowed`
as 🔴 blocks (canon reusables use `actions/*`+`github/*`, which those states block),
not a masked 409;
(4) `verify` short-circuits when the caller is not yet on the default branch —
the `pull_request_target`/`workflow_run` gates arm only after merge, so on the
adoption PR that ADDS them they do not run, and the old poll burned 24×25s
matching nothing. `test_contract.sh` guards all four.

- **`labeler.yml` config is installable by no path.** It ships as
  `install/templates/labeler.yml` but `install.sh` never fetches it, the wizard's
  config copy omits it, and it is absent from `manifest.json` — so `--update` and
  `sync/check-drift.sh` never see it. Yet `labeler` IS in the wizard's default
  scaffold set, so `actions/labeler` runs with `configuration-path` pointing at
  nothing. Same defect class as the audit-trail `_note` already records.
- **`AI_CI_DEPLOYMENT.md` carries F1's naming trap for humans.** It tells
  hand-copy adopters to use "the single template" for
  `pre-commit`/`markdown-lint`/`links`/`labeler`/`doc-maintainer`, but all but
  `doc-maintainer` gained `-private` variants at `ci/v2.1.0` — a private adopter
  following that doc installs the label-less generic, which is the FT-9 brick.
- **`deploy-ci-wizard.sh preflight` under-reports.** §3 checks only 5 of the 18
  canonical labels, and §4 prints a raw 409 JSON blob as `unreadable/all-allowed`
  when `allowed_actions != selected` — an unactionable warning on the one check
  guarding the documented `startup_failure` mode. Read `/actions/permissions`
  first and branch on `allowed_actions`.
- **`verify` burns 10 minutes proving nothing on an adoption PR.** `ai-review`
  (`pull_request_target`) and `composition`/`auto-merge` (`workflow_run`) resolve
  their definition from the base ref, so on the PR that first *adds* them they do
  not run; the wizard's poll never matches and runs its full 24 × 25 s. Break
  early with an explicit "these triggers arm only after merge to the default
  branch" note, and document the two-PR adoption shape.

### FT-1 — Branch-protection templates lag REPO_STANDARDS §2 on `call / verify`

**RESOLVED (2026-07-12, PLAN-007 W2):** branch-protection templates + REPO_STANDARDS §2 corrected to the verified `call / …` emitted names (incl. `call / verify`); `tests/test_checknames.sh` guards against recurrence.

**Found:** 2026-07-09, during PLAN-004 PR-A3 (`BRANCH_PROTECTION.md` authoring).
**Surfaces:** `docs/REPO_STANDARDS.md` §2 (line ~84) lists `call / verify`
in the required-checks baseline for governance/product/ops; the shipped
`install/templates/branch-protection-{governance,product,ops}.json` omit
it (they predate the 2026-07-08 §2 amendment per §15 change log).
**Effect:** `apply-standards.sh --apply` produces protection WITHOUT
`call / verify`; a `--check` against §2 then reports it as drift; the doc
had to describe "§2 target vs template today" rather than one number.
**Constraint (why not a trivial template edit):** requiring `call / verify`
universally would block every PR on any tier repo that hasn't adopted the
`audit-trail` caller yet (per its §14.3 Wave). So the fix must couple the
template change to audit-trail adoption state, or keep `call / verify` a
per-repo post-adoption addition.
**Fix sketch:** decide the canonical position — either (a) §2 marks
`call / verify` as "add after audit-trail adoption" (matching current
templates + `BRANCH_PROTECTION.md`), or (b) ship the audit-trail caller
template + bump the three branch-protection templates together in a wave
that also flips required checks. Reconcile §2 ⇄ templates ⇄
`BRANCH_PROTECTION.md` so all three agree.

### FT-2 — Verify the real emitted context names for `pre-commit` + `secret-scan`

**RESOLVED (2026-07-12, PLAN-007 W2):** verified emitted check-names captured from live runs + recorded in REPO_STANDARDS §2 verified-names table; templates aligned; regression-tested.

**Found:** 2026-07-09, PLAN-004 PR-A3 (pre-push review L1).
**Surfaces:** `docs/REPO_STANDARDS.md` §2 + the `branch-protection-*.json`
templates require contexts `Lint / format / security hooks` and
`Secret scan (gitleaks)`. But `secret-scan.yml`'s job name is `gitleaks`
and both are consumed via a caller `jobs.call:` job, so GitHub likely
renders them as `call / gitleaks` and `call / Lint / format / security
hooks`. If the required context string doesn't match what the check
actually posts, the required check never turns green → PR blocked.
**Fix sketch:** on one live PR that runs both reusables, read the actual
posted context names (`gh api repos/<r>/commits/<sha>/check-runs --jq
'.check_runs[].name'` or the PR's status contexts). If they differ from
the canon strings, correct §2 + every `branch-protection-*.json`. Doc
(`BRANCH_PROTECTION.md`) currently mirrors canon faithfully, so it self-
corrects once canon is fixed.

### FT-3 — `labels.json` `skip-ai-review` description corrected

**Found:** 2026-07-09, PLAN-004 PR-A3 (`LABELS.md` rewrite).
**Status:** RESOLVED — 2026-07-12.
**Resolution:** `install/templates/labels.json:20` now reads "Operator override:
suppress re-review and carry forward a valid prior approval" — matches the actual
behavior (`ai-review.yml` SKIP_REVIEW + `composition.yml:110-117` carry-forward).
`LABELS.md` already documented the correct behavior; the stale description was
cosmetic only.

### FT-4 — CHANGELOG back-catalog (v1.1.0–v1.6.0) not cut into per-tag `##` headers

**Found:** 2026-07-09, PLAN-004 PR-A4b (CHANGELOG restructure).
**Surface:** `CHANGELOG.md` — the 18 tags in the `ci/v1.1.0` … `ci/v1.6.0`
band (16 excluding the two `ci/v1.1.0-alpha.*` prereleases; note `ci/v1.1.4`
was never cut — a gap the executor should expect) have their entries under
`## Unreleased` as dated `###` sub-sections, not per-tag `## ci/vX.Y.Z`
headers. PR-A4b did the safe parts (deduped the
doubled `ci/v1.0.3` header; renamed `## Unreleased` → staging header for the
genuinely-unreleased post-v1.6.0 work; added the PLAN-004 A-series entry)
but did NOT promote the released back-catalog.
**Why deferred (PLAN-004 §6 R5):** PLAN-004 item 10 assumed every Unreleased
sub-section carried an inline tag — false: the ~20 top entries (2026-07-08
work) are untagged, and the interspersed doc-only entries don't map cleanly
to a tag. A sweep risks mislabeling release provenance. `ci/v1.0.6`↓ already
have correct `##` headers, so this is bounded to the v1.1.0–v1.6.0 band.
**Fix sketch:** reconcile against `git log --tags --oneline` (each tag →
its commit range → the entries in that range), promote each inline-tagged
`### … ci/vX.Y.Z …` to `## ci/vX.Y.Z — <date>`, and assign the untagged
doc-only entries to the release whose commit range contains them. Verify no
entry is dropped or duplicated (line-count + entry-count before/after).

### FT-5 — `standards-drift` can't verify branch-protection / actions-permissions — STILL OPEN (needs a PAT/App token, NOT a permissions line)

**STILL OPEN (re-checked 2026-07-17), and the "one-line fix" does not exist.**
PLAN-007 W2 (2026-07-12) was marked RESOLVED but only made the 403 *legible* —
it never granted the scope, so the gap stayed live and the banner hid it until
the pre-prod governance review. The obvious fix — add `administration: read` to
the drift job's `permissions:` — was **attempted 2026-07-17 and rejected by
actionlint**: `administration` is not a grantable `GITHUB_TOKEN` workflow-
permission scope at all (the enum is actions/attestations/checks/contents/
deployments/discussions/id-token/issues/packages/pages/pull-requests/
repository-projects/security-events/statuses). So `branches/*/protection` reads
**cannot** be authorized via the workflow token; they require a PAT or a GitHub
App installation token with `administration:read`, provided as a secret.

**Effect (still live):** `.github/workflows/standards-drift.yml` grants only
`contents: read`, so `check-standards-drift.sh`'s branch-protection +
actions-permissions reads `warn_uncheckable`-skip. The drift check does NOT
verify the exact server-side settings PLAN-001 governs. Load-bearing for
PLAN-010's detector.

**Fix (real):** mint an App installation token (or a fine-grained PAT) with
`administration:read` + `actions:read`, store it as a repo/org secret, and have
the workflow use it for the `gh api` reads instead of `GITHUB_TOKEN`. That is a
provisioning task (🔴, touches secrets), not a canon-code one-liner — which is
why it belongs with the PLAN-010 adoption-model work, not a drive-by.

**Lesson:** "made the error legible" ≠ "fixed the error"; and a fix sketch's own
caveat ("confirm GITHUB_TOKEN can read another repo's branch protection") is
worth executing before marking anything RESOLVED. actionlint caught the bad fix
in one run.

**Found:** 2026-07-09, PLAN-004 C1 review.
**Surface:** `.github/workflows/standards-drift.yml` job grants `contents: read`;
`sync/check-standards-drift.sh` makes `gh api` reads of `branches/*/protection`,
`actions/permissions*`, and repo settings — which need `administration: read`
(branch-protection needs admin). With only `contents: read` those calls
`warn_uncheckable`-skip, so the drift check emits `::warning::cannot check …`
instead of actually verifying those surfaces.
**Effect:** the scheduled drift check silently does NOT catch branch-protection
or actions-permissions drift — the exact settings PLAN-001 canon governs.
**Pre-existing** (not introduced by C1's `permissions: {}` addition).
**Fix sketch:** add `administration: read` (and `actions: read`) to the drift
job's `permissions:` so those checks run instead of warn-skipping. Confirm the
GITHUB_TOKEN can read another repo's branch protection, or document that it
requires a PAT/App token with admin:read for cross-repo drift.

### FT-6 — trust-config source inconsistency: `composition` reads `$GH_REPO@main`, ai-review/auto-merge read `trust_config_repo`

**VERIFIED not-an-enforcement-gap (2026-07-12, PLAN-007 W2):** re-read composition.yml — when a repo has no local `.github/ai-review/config.json`, the read falls to the `else` branch = **fail-closed, ENFORCE the App-approval requirement** (composition.yml ~213). The consumer-local config is read ONLY for the author-EXEMPTION path (exempt a non-trusted author as human-review-only); it fails safe. So composition enforces everywhere; the `GH_REPO`-vs-`trust_config_repo` difference is a low-priority consistency nit (unify the author-exemption source with ai-review's `trust_config_repo`), NOT a gate that silently passes. Downgraded from load-bearing.

**PARTIALLY RESOLVED:** 2026-07-10, PLAN-005 PR-G — the hardcoded `?ref=main` is
fixed: `composition.yml` now reads the config from the repo's **actual default
branch** (`gh api repos/$GH_REPO -q .default_branch`, fall back to `main`), so
`master`/`develop` consumers aren't degraded to always-enforce. STILL OPEN: the
*source-repo* half — composition reads the CONSUMER's own repo while
ai-review/auto-merge read `trust_config_repo` (they can still consult different
allowlists). The `trust_config_repo`/`trust_config_ref` inputs on composition
(fix sketch (a) below) remain a deliberate future decision.

**Found:** 2026-07-09, PLAN-004 D1 (trust-root parameterization).
**Surface:** after D1, `ai-review.yml` + `auto-merge-ai-prs.yml` read the trust
config (`.trust.ai_review` + `auto_merge.repos`) from `trust_config_repo` @
`trust_config_ref` (default `vladm3105/aidoc-flow-operations@main`). But
`composition.yml:156` reads `.trust.ai_review` from
`repos/$GH_REPO/contents/.github/ai-review/config.json?ref=main` — the
CONSUMER's own repo, hardcoded `?ref=main`.
**Effect:** the three gates can consult DIFFERENT allowlists. For aidoc-flow
(operations' central config vs a consumer's minimal `["vladm3105"]`) they may
diverge, so composition could exempt/enforce an author differently than
ai-review routed them. Not de-branded by D1 because composition has no hardcoded
operations ref (it's already consumer-relative), and switching it to
`trust_config_repo` is a BEHAVIOR change on a live security gate — deferred to a
deliberate decision, not a rushed breaking PR.
**Fix sketch:** decide the canonical trust-source model — either (a) composition
also reads `trust_config_repo`@`trust_config_ref` (aligning all three; a
behavior change for aidoc-flow that must be validated against the live gate), or
(b) document that composition intentionally uses the consumer's own config and
ai-review/auto-merge use the central one, with the reason. Reconcile + add the
`trust_config_repo`/`trust_config_ref` inputs to composition either way.

### FT-7 — `CODEOWNERS.template` still hardcodes `@vladm3105`; de-brand needs a handle-normalizing drift check

**RESOLVED:** 2026-07-09 — implemented approach (a) normalize. `CODEOWNERS.template`
owner routes → `@${CODEOWNER_HANDLE}`; `apply-standards.sh` gained
`codeowners_check` (`normalize_codeowners` maps every `@owner` → `@OWNER` on both
sides before diff, verifying path structure while ignoring handle identity);
`install.sh` now installs `.github/CODEOWNERS` (substituted, preserve-if-exists)
reusing D2's `substitute_placeholders`. Defaults byte-identical; existing
`@vladm3105` consumers keep passing. REPO_STANDARDS §7 + §16.7. Original entry
retained below for context.

**Found:** 2026-07-09, PLAN-004 D2 (de-brand install templates).
**Surface:** D2 parameterized `config.json.template` (`${CODEOWNER_HANDLE}`) and
`CLAUDE.md.template` (`${CANON_*_URL}`) because neither is exact-match
drift-checked (config.json is drift-exempt; CLAUDE.md drift is a structural
governance-table parse via `parse-governance-table.py`). `CODEOWNERS.template`
was deliberately LEFT branded: `apply-standards.sh` `exact_match_check`
(`.github/CODEOWNERS` vs `CODEOWNERS.template`) diffs byte-for-byte, so a
`${CODEOWNER_HANDLE}` placeholder in the template would read as permanent DRIFT
against a consumer's substituted `@handle` on every `--check`. It is also NOT
written by `install.sh` today (install.sh installs callers, config.json,
CLAUDE.md, pre_push_check, pre-commit, labels — no CODEOWNERS), and `@vladm3105`
is already correct for every current (vladm3105-owned) consumer, so leaving it
branded has zero impact on the live workspace.
**Effect:** a true external adopter must hand-edit `.github/CODEOWNERS` after
install; the handle there is not yet flag-parameterized.
**Fix sketch (drift-pipeline design decision — do deliberately):** pick one —
(a) **normalize** owner handles out of the CODEOWNERS comparison: strip
`@[\w/-]+` tokens (and map `${CODEOWNER_HANDLE}` on the template side) on BOTH
sides before `diff`, so the check verifies path-routing STRUCTURE (which is
canon) and ignores WHO owns (inherently consumer-specific) — needs no handle
plumbed into CI, and is semantically correct since the owner is not canon;
(b) **handle-aware:** thread `--codeowner` into `apply-standards.sh --check`
(read from a repo var or the consumer's own `* @handle` line) and substitute
before diff — more CI plumbing; (c) **structural:** downgrade CODEOWNERS from
exact to a presence/shape check. Recommended: (a). Then add a CODEOWNERS install
step to `install.sh` (fetch + `substitute_placeholders` + write
`.github/CODEOWNERS`) reusing the D2 substitution helper, and de-brand
`CODEOWNERS.template` to `${CODEOWNER_HANDLE}`. Defaults must stay byte-identical.

### FT-8 — migrate `sync/check-drift.sh` onto `manifest.json` (PLAN-004 PR-E2)

**RESOLVED (2026-07-16).** `sync/check-drift.sh` no longer hardcodes
`for wf in ai-review composition`. The loop is now driven by the consumer's own
pinned callers under `.github/workflows/*.yml` and resolved through
`manifest.json` **fetched at each caller's own pin** (preserving the PR-A2
per-caller pin frame — a mid-bump consumer must not be judged against a newer
caller's canon), with the warning-only contract intact. A newly-manifested canon
workflow is drift-checked without editing the script.

Verified against a simulated consumer: the old script reported **"no drift"** on
a consumer carrying three real drifts (`labeler` + `secret-scan` `concurrency`
block dropped, `pre-commit` `push:main` trigger dropped — the exact drifts the
filing reported as invisible); the new script flags all three by name.

**Coverage is the manifest's workflow surface, not "every canon workflow"** —
and the distinction was load-bearing: `audit-trail` shipped `-public`/`-private`
templates but had **no manifest entry**, so the OPS-0069 gate (deployed on 9/9
repos) resolved to nothing and was reported as an unknown caller. It was the only
such omission across the template set; `install/templates/manifest.json` now
manifests it, which also brings it into `install.sh --update`'s walk. Do not
restate coverage as complete without re-measuring against `manifest.json`.

The reporting contract was tightened in the same pass, because a drift tool that
reports a pass over files it never opened is the same defect class as the
secret-scan that greens while scanning nothing: every uncompared caller now
emits a `::warning::` and increments a skip counter, the verdict carries its
denominator (`compared N of M; S skipped`), and the words "no drift" are gated
on `SKIPPED == 0`. A canon caller pinned to a branch or bare SHA — previously
classified as consumer-owned and skipped in total silence — is now reported as
an unpinned canon caller. (This does not reach FT-13's unresolvable iplanic pin:
that is a `curl` in a `run:` step, not a `uses:`, so no `@ref` exists to scan.)

Scope limits are stated in the script header rather than left silent: non-pinned
canon surfaces (`.markdownlint.json`, `CODEOWNERS`, `CLAUDE.md`,
`scripts/pre_push_check.sh`, …) carry no tag for this per-pin tool to resolve
them at and are `apply-standards.sh --check`'s job; templates with `substitute`
placeholders are skipped (a raw diff would false-flag them); callers pinned
below `ci/v1.7.0` predate `manifest.json` and are reported as skipped, never as
clean.

**Found:** 2026-07-09, PLAN-004 PR-E (update path). PR-E shipped
`install/templates/manifest.json` + `install.sh --update` consuming it, but
scoped OUT the `sync/check-drift.sh` rewrite to keep the PR reviewable.
**Surface:** `sync/check-drift.sh:30` still uses a hardcoded
`for wf in ai-review composition` loop over the two auto-installed callers.
It should read the workflow surface from `manifest.json` (the same list
`install.sh --update` walks) so a newly-added canon workflow is drift-checked
without editing the script. The existing "bring back to canonical: remove the
local file + re-run install/install.sh" note (`sync/check-drift.sh:66`) can
point at `install.sh --update` as the reconciliation path.
**Effect:** drift-check coverage is limited to ai-review + composition;
optional adopted workflows (labeler, codeql, secret-scan, …) are not
drift-flagged by check-drift.sh (apply-standards.sh + check-standards-drift.sh
cover other surfaces). Non-breaking gap, not a correctness bug.
**Fix sketch:** replace the hardcoded loop with a `python3` walk of
`manifest.json` filtering to `.github/workflows/*` entries (visibility
resolved like `install.sh --update`), preserving the per-caller pin logic
(each caller compared against the tag IT is pinned to, per PR-A2) and the
warning-only/never-block contract. Reuse the manifest entry emission from
`install.sh update_mode`. Keep it a separate PR (E2) — it touches a live
CI drift-check script.

### FT-9 — 🔴 `install.sh --update` wholesale-replaces `safe_to_replace` callers, clobbering per-repo runner/permissions/trigger customizations

**Found:** 2026-07-10, during the PLAN-005 v1.8.1 consumer-sync sweep — a
fleet-wide gate-brick regression. Caught on operations #244 by that repo's own
ai-review (verdict: changes-requested); the identical regression had **already
merged** on iplanic (#247), business, and interlog before detection.
**Surface:** `install/install.sh` `update_mode()` (lines ~186-261): for any
manifest entry with `safe_to_replace: true` (all workflow callers except
`codeql.yml`), `--update` **overwrites the local caller file wholesale** with
the fetched generic template. The template ships the framework default
`runner_labels: '"runner-self"'` and omits per-repo caller `permissions:`
blocks, trigger customizations (`ready_for_review`, the `pull_request_review`
exclusion), and per-caller `runner_labels` overrides.
**Effect (critical):** running `--update` on a repo that has customized its
callers silently reverts those customizations. Concretely on the private
consumers, `runs-on: ${{ fromJSON(inputs.runner_labels_review) }}` became
`runs-on: runner-self` — a label no repo has registered (operations pool =
`self-hosted,aidoc,ci-ephemeral` + `…,ai-review`; iplanic = `…,ci-ephemeral`)
— so every required-check job (ai-review trust/review, composition,
doc-maintainer) queues indefinitely and **bricks the merge gate for every
subsequent PR**. Also drops docs-sync/links overrides → `ubuntu-latest`
fallback → OPS-0049 billing gate-down, and deletes doc-maintainer's
`permissions:` block → startup_failure.
**Root confusion:** `--update` conflates two distinct operations — "adopt a new
canon **template body**" vs "bump the **pin version**." A **re-pin is
version-only**: it must change only the `@ci/vX.Y.Z` string on each `uses:`
line and touch nothing else.
**Fix sketch:** split the two. Either (a) add a dedicated `--repin` path that
surgically rewrites `@ci/v*` → target tag on existing caller `uses:` lines,
preserving all customizations (the manual fix applied to operations #244 +
iplanic); or (b) mark all workflow callers `safe_to_replace: false` in
`manifest.json` so `--update` only reports body drift (never auto-replaces) and
handles the pin bump separately; or (c) make `update_mode` merge — preserve the
consumer's `with:` block (runner_labels/permissions/trigger overrides) while
adopting non-`with:` template changes. Requires a plan (canon change → semver
MINOR + `REPO_STANDARDS.md` update + verified-planning 2-cycle review). Until
shipped: **never run `install.sh --update` for a re-pin on a repo with a
customized caller — do a surgical `@ci/v*` sed instead.**
**RESOLVED (ci/v1.9.0, PLAN-006 W2):** `-private.yml` templates now ship the real
`ci-ephemeral` array (no more `runner-self` placeholder); `install.sh --repin`
(version-only pin bump) added — option (a). See CHANGELOG v1.9.0.

### FT-10 — `runner-self` still used as a pool-nickname across reference docs

**Status:** ALREADY RESOLVED — verified 2026-07-23 (PLAN-018 Workstream B triage).
The nickname-as-registration-label usage this was filed for (runners.md §2
registration steps, `troubleshooting.md`, `LABELS.md:121`) was cleaned up in
subsequent doc work. Every remaining `runner-self` mention across `docs/` +
`LABELS.md` now frames it as **the retired placeholder to avoid** — e.g.
`AI_CI_DEPLOYMENT.md:271` "`runner-self` is a placeholder, NOT a registered
label", `runners.md:14` the migration note. Verified: no doc tells a reader to
register/use/target `runner-self` as a pool label (grep for
`use|register|labels:|runner_labels|--labels` + `runner-self` → zero hits); the
canonical `["self-hosted","ci-runner","single-use"]` (CI-0007) labels are used
throughout. No fix needed; recorded so the ledger is not re-worked.

**Found:** 2026-07-11, v1.9.0 doc-consistency review (documentation-specialist).
**Surface:** after v1.9.0 removed `runner-self` from the shipped templates, the
reference docs still use `runner-self` as the *nickname* for the self-hosted pool
in several places: `docs/runners.md` §0/§2 pool tables + registration steps
(~lines 91, 103, 122, 152-191), `docs/troubleshooting.md:95-96/286`,
`LABELS.md:121`. Not a contradiction with the template change (the genuine
"templates ship runner-self" claims were fixed in v1.9.0), but `runner-self` is
**not registered on any runner**. The **canonical label is
`["self-hosted","ci-runner","single-use"]`** (CI-0007, since v2.0.0 — see
`DECISIONS.md`). NB the older `aidoc,ci-ephemeral` nickname is ALSO retired; this
entry previously named it as "the real labels", which would have made this
doc-fix install a second wrong nickname — fix the docs to the CI-0007 labels.
**Effect:** a reader following runners.md registration steps would register a
`runner-self` label no caller targets. Educational drift, not a live break.
**Fix sketch:** reconcile the nickname — rewrite the reference docs to the real
`ci-ephemeral`/`ai-review` labels throughout (align docs to infra; preferred).
One focused docs PR; split to keep ≤3 surfaces.

### FT-11 — graduate `markdown-lint` (report-only → blocking) + `docs-sync` (dry-run → live)

**Found:** 2026-07-11, PLAN-006 W4 population. **Status: population DONE;
graduations remain.**
**Done:** the canon defect was fixed (`v1.9.4` binary-install for
`markdown-lint`+`links`; `v1.9.5` `markdown-lint` `fail-on-findings` toggle +
`.lychee.toml` `include_fragments` fix), and all content-check workflows are
now deployed on every active repo (see `docs/WORKFLOWS.md` §2):

- **`links`** — blocking (offline) on every repo (0 errors; debt repos ship a
  scoping `.lychee.toml`).
- **`markdown-lint`** — deployed **report-only** (`fail-on-findings: false`);
  operations/framework covered by own tooling.
- **`docs-sync`** — deployed **dry-run** (proposes doc-fixes as a PR comment;
  no App needed — the `aidoc-flow-bot` App is only for the live Apply step).

**Remaining (deliberate opt-in graduations, NOT dev gaps):**

- **`markdown-lint` report-only → blocking — DONE across all canon consumers
  (PLAN-007 W3, 2026-07-12).** Sequence: (1) founder chose to **relax the canon
  `.markdownlint.json`** (disable MD013/MD024/MD036 — workspace-legitimate
  false-positives on changelog data rows, keep-a-changelog headings, ADR
  `**Context**`/`**Decision**` bold-labels; ci #149, REPO_STANDARDS §4.4). (2)
  Per-repo graduation to `fail-on-findings: true`: **business #57, interlog #63,
  engramory #49, iplan-runner #89, iplanic #258, iplan-standard #30 all
  MERGED** (iplan-standard is governance tier — OPS-0062-excluded from AI
  auto-merge, so the founder merged it). operations + framework are covered-by-own-tooling (not the canon
  reusable). **Key lesson: a blind `markdownlint-cli2 --fix` is UNSAFE on these
  docs** — it corrupts prose (a literal `+`/`#` at line-start misread as a
  list/heading marker → MD004/MD001 cascades) and code identifiers
  (`__init__.py`→`**init**.py` via MD050). Every graduation reflowed the prose-`+`
  roots first, used `--fix` only for genuinely-structural rules, and ran a
  documentation-specialist to verify zero prose changed (it caught real MD050
  BLOCKERs on iplan-runner + iplanic; the pre-commit `check_plan` gate caught
  `--fix` breaking verified-planning ledger citations twice). engramory added a
  repo-local `MD025.front_matter_title:""` for its `sdd/**` frontmatter-titled
  docs. **Still pending: arming each as a required status check = the
  founder-executed W4 step** (`docs/FLEET_BRANCH_PROTECTION_ARMING.md`; FT-12).
- **`docs-sync` dry-run → live.** 🔴 founder provisions `aidoc-flow-bot` App +
  `AIDOC_FLOW_BOT_ID`/`KEY` secrets per repo, then set `dry_run: false`. Weigh
  against the pending `doc-maintainer.yml` supersession at `ci/v2.0.0` — the
  dry-run adoptions may migrate to `doc-maintainer` rather than each graduating.

Ties to [[reference_canon_workflow_hard_constraints]] #3.

### FT-12 — fleet branch-protection arming anomalies (PLAN-007 W4 survey)

**Found:** 2026-07-12, PLAN-007 W4 read-only survey. Runbook:
`docs/FLEET_BRANCH_PROTECTION_ARMING.md`. Arming itself is 🔴 (founder-executed).
Three sub-issues the survey surfaced that need canon/repo remediation
independent of the arming act:

- **Phantom required-context (framework, business, iplanic).** Each arms a
  **bare** `Lint / format / security hooks` required-check but emits the canon
  `call / Lint / format / security hooks` → the bare context never posts, so
  these repos have been merging via `--admin`. Fix = re-point the required
  context to the emitted name (in the runbook's step B).
- **iplan-runner canon adoption — RESOLVED (iplan-runner #88, 2026-07-12).**
  `call / gitleaks` was failing on a placeholder HMAC key in the
  `iplanic-vectors/` conformance vectors (the canon default allowlist matches a
  bare `vectors/` but not the compound dir name). Fixed consumer-side via
  `config-path: .gitleaks.toml` + a proper `[extend] useDefault=true` allowlist
  (which also un-broke the repo's previously rule-less, no-op standalone
  gitleaks). On the fix PR, `call / ai-review` + `call / composition` ran green —
  the earlier "skipped" was PR-specific, not a wiring defect. Its canon `call/…`
  gates are now armable.
  - *Canon observation (low-priority):* the reusable's default gitleaks
    allowlist path `(^|/)(vectors|fixtures|testdata|examples)/` misses compound
    names like `*-vectors/`. The `config-path` escape hatch is the intended
    per-consumer fix, so leaving the canon default strict (opt-in) is defensible;
    broadening it fleet-wide risks over-suppression. No action unless a second
    consumer hits it.
- **interlog `call / composition` conditionality.** Armed but did not emit on
  its latest PR (path-filtered?). Confirm composition posts on every PR or
  reclassify it non-required.

### FT-13 — private-repo standards-drift callers are broken; one pins an unresolvable SHA

**Found:** 2026-07-16, triaging the `llm-router` flowci-feedback filing.
**Surfaces:** `.github/workflows/standards-drift.yml` (fleet pin-currency step);
the consumer-side callers in operations / business / iplanic / interlog.

**The mechanism exists.** `sync/check-standards-drift.sh` chains
`check-pin-currency.sh` itself (uses `sync/check-pin-currency.sh` if present
locally, else `curl`s it from `${CI_TAG}`), so a private repo running
standards-drift gets pin-currency transitively without naming it in the caller.
Canon's own fleet audit cannot cover the private repos — `GITHUB_TOKEN` cannot
read private repo contents — so the per-repo run is the intended path.

**Verified facts (2026-07-16). Only these; see the caution below.**

1. **`business` and `interlog` have no `standards-drift.yml` at all** — so they
   get no drift and no pin-currency signal from any source.
2. **`iplanic`'s caller pins a SHA that can never resolve.**
   `e15ec7d44234726195da316a740ad1684a2c5abd` is the **annotated tag object** of
   `ci/v1.6.0`, not a commit: `gh api repos/…/commits/e15ec7d…` returns `422 No
   commit found`, and raw.githubusercontent has never served it (HTTP 404). The
   commit the tag dereferences to is `e827ab8268917ea4a81a0b8ddbc59eace702f7ed`,
   which serves HTTP 200 today. So this is a **permanent authoring bug, not
   decay** — the caller has never worked, and "re-pin it to a live tag" is the
   wrong fix. The right one is to deref the tag
   (`gh api repos/<r>/git/refs/tags/<tag> --jq '.object.sha'` returns the TAG
   object for an annotated tag; dereference via `git/tags/<sha> --jq
   '.object.sha'`, or just pin the tag name).
3. **Every private standards-drift run on record has failed** (latest:
   2026-07-13). None is presently producing a signal.

**Caution — this entry has now been wrong three times; do not add a fourth
without measuring.** (a) The original comment claimed the private four were
"covered by their OWN weekly run, which chains check-pin-currency.sh in-repo" —
true for operations, false for the rest. (b) Its first correction over-swung to
"none of them chains pin-currency" — false for operations; that measurement
grepped only the caller YAML and missed the chain one level down, inside the
script the caller invokes. (c) Its second correction attributed operations'
2026-07-13 failure to its current checkout-based caller — but that caller was
authored **2026-07-16**, after the run. At the time of the failure operations
was `curl`-ing the same unresolvable `e15ec7d…` URL as iplanic, so the two had
the *same* bug, not different ones. **operations' current caller has never run**;
whether its chain works is unproven by inspection alone.

The checks each miss would have needed: grep the transitive path, not just the
caller; and confirm the cited run actually executed the caller you are
describing (`gh api "repos/<r>/commits?path=<workflow>"` vs the run's
`createdAt`).

**Why it matters:** a consumer that cannot fetch its drift script has no drift
signal and no indication that it has none — the same absent-feedback-loop shape
as the fleet-wide `enforce_admins` drift. Note this specific shape is NOT caught
by `sync/check-drift.sh`, even after the 2026-07-16 coverage work: iplanic
references canon via a `curl` inside a `run:` step, not a `uses:`, so there is no
`@ref` for the caller-scan to see. Reporting unresolvable canon references in
`run:` steps is unsolved.

**Fix sketch (needs a decision, hence a plan not a patch):** the filing proposed
adding `sync/*.sh` to `manifest.json` so every consumer gets a copy. Copying a
script into every consumer manufactures another drifting surface — and the
hand-rolled callers above are what that looks like in practice. The alternative
is a canon reusable + a thin caller template that resolves the scripts at the
consumer's pinned tag, matching how every other canon surface is consumed and
getting version-pinning (and drift-checking, now that callers are
manifest-resolved) for free — and removing the class of bug in (2) entirely,
since a `uses:` pin cannot be an unresolvable tag object. Choosing between them —
and deciding whether `install.sh` should apply server-side standards at all (🔴:
it mutates consumer repos) — is the scope of the adoption-model plan (next free
PLAN number). Consumer-side callers are cross-repo work and go through the
ops/inbox runbook, never a direct edit from a canon session.

### FT-14 — `pre_push_check.sh`'s yamllint is stricter than canon's own CI gate, so canon fails its own hook

**Status:** ALREADY RESOLVED — verified 2026-07-23 (PLAN-018 Workstream B triage).
A root `.yamllint.yaml` was added `2026-07-17` (the day after this was filed), and
`pre_push_check.sh:105-106` invokes `yamllint -c .yamllint.yaml` when it is
present (which it now always is), so the hook uses the SAME relaxed profile as
`tests/test_lint.sh`. Confirmed green on `main`: `yamllint -c .yamllint.yaml`
over `.github/workflows/` + templates returns rc 0. No fix needed; recorded here
so the ledger is not re-worked. `install/templates/.yamllint.yaml` also exists,
so consumers get the profile too.

**Found:** 2026-07-16, running `scripts/pre_push_check.sh` while closing the
flowci-feedback findings.
**Surfaces:** `scripts/pre_push_check.sh` §2 (yamllint); `tests/test_lint.sh:20-23`;
the absent `install/templates/.yamllint.yaml`.

**Two invocations of the same tool disagree:**

- `tests/test_lint.sh:22` — canon's **authoritative** gate (runs in `tests.yml`
  on every PR) invokes yamllint with an explicit relaxed profile:
  `line-length: disable, document-start: disable, truthy: disable, …`. Its own
  comment says *"yamllint relaxed (no line-length…)"*. It is green on `main`.
- `scripts/pre_push_check.sh:98-101` — falls back to a **bare `yamllint`** when
  no `.yamllint.yaml` exists. Canon has none, so the hook enforces line-length
  and every rule the CI gate deliberately disabled.

**Effect:** measured 2026-07-16 on pristine `main`, bare yamllint reports **172
issues** across `.github/workflows/`, so `pre_push_check.sh` **exits non-zero on
an unmodified canon checkout**. Anyone with yamllint installed who runs the hook
is told not to push work that canon's own CI accepts. The hook is not currently
installed as a git hook in every checkout, which is the only reason this has not
blocked anyone — i.e. the local gate is inert where it is wrong, and wrong where
it is not inert.

**Relation to the filing.** This is flowci-feedback's *"install.sh ships no
default `.yamllint.yaml`"* finding. That entry was assessed as **inert for
consumers** and that assessment holds — `install.sh` never installs yamllint, so
a fresh consumer's check 2 skips-with-notice and no consumer-facing CI runs
yamllint at all. But it is **not** inert for **canon**, which has yamllint
available and no config. The filing reasoned from consumer symptoms and reached
the right fix shape for the wrong repo.

**Fix sketch (a decision, not a patch — hence not done here):** the profile is
already chosen and proven; `tests/test_lint.sh:22` is the de-facto canon
yamllint config. Either (a) extract that inline `-d` profile into a repo-root
`.yamllint.yaml` and have both call sites read it — one source of truth, and
`pre_push_check.sh`'s existing `-f .yamllint.yaml` branch (dead code today,
never exercised in canon) starts working; or (b) leave canon's config absent and
make the hook's fallback match the relaxed profile. Prefer (a). Whether the same
file also ships to consumers via `install/templates/` + `manifest.json` is the
separable question the filing actually asked, and it should be settled with the
adoption-model plan rather than as a drive-by: shipping a lint config to repos
that do not run the linter adds a drift surface for no signal.

### FT-15 — audit fleet reusables (ai-review / doc-maintainer / docs-sync) for the `workflow_ref`-is-the-caller asset-fetch bug

**Status:** ⚠️ **CONFIRMED LIVE 2026-07-21 — the claim is TRUE. The pin does NOT
control reviewer assets.** Investigation closed; the FIX is now OPEN (do NOT
blind-fix — see "Fix sketch", one reviewed PR per reusable).

**Live evidence (production logs, not docs reasoning).** `ai-review.yml:431`
already emits the resolved ref as a notice on **every** run, so no throwaway run
was needed — the proof was in every historical log. Two consecutive `operations`
runs (`29790683633` @ 2026-07-21T00:35, `29788760133` @ 2026-07-20T23:56):

```text
##[notice]ai-review fetching assets from vladm3105/aidoc-flow-ci@refs/heads/main
```

while that same repo's caller is pinned:

```yaml
uses: vladm3105/aidoc-flow-ci/.github/workflows/ai-review.yml@ci/v2.0.1
```

`refs/heads/main` ≠ `ci/v2.0.1`. **`github.workflow_ref` is the CALLER's entry
workflow ref, exactly as the docs say.** operations, pinned at `v2.0.1`, fetches
`main`'s `review-prompt.md`, `verdict.schema.json`, and `litellm_client.py`.

*Ambiguity closed (adversarial re-verify):* under `pull_request_target`,
`github.ref` **also** equals `refs/heads/main`, so the log line alone does not
prove the source. Resolved against the **tag** source — `git show
ci/v2.0.1:.github/workflows/ai-review.yml` (lines 397, 411-413) shows
`GITHUB_WORKFLOW_REF: ${{ github.workflow_ref }}` → `REF="${GITHUB_WORKFLOW_REF##*@}"`
→ that exact notice, so the printed value provably comes from `workflow_ref`.
operations has exactly one `ai-review.yml` (a thin caller — no local copy), and
the run's `headBranch` (`docs/handoff-wrap-2026-07-20`) differs from the resolved
ref, confirming it is the caller's *base* ref, not the reusable's tag.
`standards-drift.yml:10-13` already documents this behaviour in-repo.

**Realized drift is narrower than the mechanism implies — state it precisely.**
`git diff --stat ci/v2.0.1 origin/main` over the three fetched assets: only
**`litellm_client.py` differs** (+19/-1); `review-prompt.md` and
`verdict.schema.json` are byte-identical. So the *mechanism* is fully broken and
the determinism / rollback / release-discipline consequences below hold in full,
but the *realized* divergence to date is one file — **not** a silently-swapped
rubric. Do not overstate this as "8 versions of rubric drift."

**The "works in production" tension is resolved — both sides were right, measuring
different things.** It never 404s because the caller's ref happens to be
`refs/heads/main` and `aidoc-flow-ci` *also* has a `main`, so the URL resolves —
to the wrong version. Every affected trigger lands on `refs/heads/main`:
`ai-review` is `pull_request_target` (ref = base branch), `doc-maintainer` and
`docs-sync` are `push: [main]`.

**Scope confirmed by code inspection — all three reusables, 5 `workflow_ref`
sites (7 curl invocations).** `grep -rn 'github.workflow_ref' .github/workflows/`
returns exactly these 5 env assignments, so the enumeration is complete — no
reusable was missed:

| Reusable | Sites | Assets fetched from the wrong ref |
| --- | --- | --- |
| `ai-review.yml` | 429-447, 1143-1150 | rubric, verdict schema, `litellm_client.py` |
| `doc-maintainer.yml` | 135-142, 196-209 | `reconcile.py`, `litellm_client.py` |
| `docs-sync.yml` | 109-117 | docs-sync scripts |

`doc-maintainer`/`docs-sync` name the variable `CI_TAG`/`TAG` rather than `REF`,
but both are `CI_TAG: ${{ github.workflow_ref }}` → `TAG="${CI_TAG##*@}"` —
the identical defect. `docs-sync.yml:112`'s comment ("The reusable workflow's
`github.workflow_ref`") states the wrong mental model that produced the bug;
correct it with the fix.

**What is and isn't broken (precise):** GitHub resolves the reusable's *workflow
YAML* at the pinned tag — that part is the platform and is correct. Only the
**curl-fetched assets** float. So a consumer runs **pinned workflow logic with
floating `main` assets**. Consequences:

- **Determinism** — the pin does not reproduce a review; the rubric can change
  under a consumer with no re-pin.
- **Release discipline is bypassed** — any merge to `aidoc-flow-ci` `main`
  instantly changes every consumer's live gate, with no tag, no release, no
  adoption step. This is the inverse of the semver contract the canon advertises.
- **Rollback is ineffective** — re-pinning a consumer to an older tag does NOT
  roll back the rubric/client.

**NEW — two extensions this investigation found beyond the original entry:**

1. **`CI_OWNER` is also caller-derived, so external adoption is broken today.**
   `ai-review.yml:430` does `CI_OWNER=$(echo "${GITHUB_WORKFLOW_REF}" | cut -d/ -f1)`
   — field 1 of the ref is the **CALLER's owner**, not the canon's. It only works
   because every current consumer shares the `vladm3105` owner. An external
   adopter (`acme/their-repo`) would fetch
   `raw.githubusercontent.com/acme/aidoc-flow-ci/...` → 404 → INFRA failure, or —
   worse — silently fetch *their own* fork's rubric if such a repo exists. This
   contradicts the entry's earlier note that "host + repo path are hardcoded; only
   the ref is wrong": the **owner is not hardcoded**. Repo-path and host are.
   Relevant to PLAN-010 (adoption model) and the "External adopters" guidance in
   `docs/runners.md` / `docs/REVIEWER_APP_ONBOARDING.md`. The fix must hardcode
   the owner (or take it as an input), not derive it.
2. **A hard-404 failure mode that is reachable TODAY — no customization needed.**
   Any trigger yielding a ref absent from `aidoc-flow-ci` — `pull_request`
   (`refs/pull/N/merge`) or a push/dispatch on a feature branch
   (`refs/heads/<branch>`) — 404s and bricks the gate. The original assumption
   that "all three triggers yield `refs/heads/main`" is **wrong**:
   `operations/.github/workflows/doc-maintainer.yml` also declares `schedule:`
   (:11) and **`workflow_dispatch:` (:16)** — so a manual dispatch from a feature
   branch hits the 404 path immediately. (`ai-review` is `pull_request_target`,
   plus `pull_request_review` on business/iplanic/interlog — both base-ref, so
   still `main`; `docs-sync` is `push: [main]`.) The failure surfaces as an
   INFRA-looking fetch error, not a config error, so it would likely be
   misdiagnosed as a flake.
**Priority ELEVATED 2026-07-19 → trust-blocker:** the value/standard-readiness
assessment (`plans/ASSESSMENT_flow-ci-value-and-standard-readiness.md`) makes this
gating — if the deployed ai-review fetches its rubric/client from `main` rather
than the pinned tag, the gate's "version-deterministic" guarantee has not held in
production. **→ CONFIRMED 2026-07-21: it has NOT held.** The gate's
version-determinism claim is false as shipped, so the trust-blocker is now a
**fix-blocker**: the rollout/arming sequence (`ROLLOUT_plan015-arming.md`) and any
widening of deployment should not proceed on the assumption that a pin determines
reviewer behaviour, because it does not. Correct the "pinned tag" determinism
wording wherever it appears (comments, `docs/`, adoption material) as part of the
fix.

**Surfaced by:** PLAN-015 B2 pre-push review (2026-07-18, security + correctness
lenses, both CONFIRMED with GitHub-docs citations). While building the new
`standards-drift` reusable, two independent reviewers established that inside a
`workflow_call` reusable, **`github.workflow_ref` resolves to the CALLER's entry
workflow ref (the consumer's default branch), NOT the reusable's pinned tag.**
The reusable's own resolved commit is `github.job_workflow_sha`.

`standards-drift.yml` was fixed to use `job_workflow_sha` before merge. But the
**existing** fleet reusables parse `github.workflow_ref` to build their
cross-repo asset-fetch URLs:

- `ai-review.yml:427-447` — fetches rubric / schema / `litellm_client.py` from
  `…/aidoc-flow-ci/${REF}/…` where `REF="${GITHUB_WORKFLOW_REF##*@}"`.
- `doc-maintainer.yml:135,142,196,203,209` — same pattern for
  `reconcile.py` / `litellm_client.py`.
- `docs-sync.yml:109-117` — same.

**The claim to verify (NOT yet verified — this is why it's an investigation):**
if `REF` is really the caller's ref, these fetch assets from
`aidoc-flow-ci@<consumer-default-branch>` (e.g. `main`), NOT from the consumer's
adopted `@ci/vX.Y.Z` pin — so the pin does not control which rubric / client /
reconcile-script version actually runs. This "works" today only because
`main` ≈ the tagged asset for same-owner consumers, and it would silently track
`main` rather than the pinned release. It is a **determinism** regression, not a
cross-domain supply-chain break (host + repo path are hardcoded; only the ref is
wrong).

**Why not fixed here:** (1) these are in-production, security-reviewed reusables
that every consumer's AI gate depends on — a blind edit is high-risk; (2) it must
first be **confirmed live** (a throwaway run logging `github.workflow_ref` vs
`github.job_workflow_sha` from inside one of these reusables) rather than reasoned
from docs alone, because the "works in production" evidence is genuinely in
tension with the docs claim and one side is wrong; (3) the fix (switch to
`job_workflow_sha`) is mechanical once confirmed, but should land as its own
reviewed PR per reusable, not bundled into B2.

**Fix sketch (after confirmation):** `github.job_workflow_sha` is NOT
expression-accessible (verified 2026-07-18: actionlint rejects it and it is not
in the documented `github` context — the reviewer that suggested it conflated the
OIDC token claim with a context field), so the fix is NOT a drop-in swap. The
robust pattern (used by the fixed `standards-drift.yml`) is to **derive the
adopted `@ci/vX.Y.Z` tag from the consumer's OWN checked-out caller file** and
fetch from that tag + a hardcoded `vladm3105/aidoc-flow-ci` owner. For ai-review
this is more involved than standards-drift — the review job does not check out the
consumer's `.github/workflows/` the same way — so each reusable needs its own
analysis, which is why this stays an investigation, not a mechanical sweep.
Correct any "pinned tag" determinism wording in their comments/docs to match.

### FT-24 — canon's own Dependabot PRs: triage, and a paired-dependency defect in #222

**Status:** OPEN — triaged 2026-07-21, deliberately NOT merged.

Six Dependabot PRs sit on canon (#221–#225, #228). All show `suite=SUCCESS` — but
that is precisely the FT-23 blind spot: **canon's suite never executes
`ai-review`/`doc-maintainer`/`docs-sync`**, so a green suite is not evidence that
a bumped action still works inside them. Merging on that signal is the
overconfidence FT-15 already cost us once.

| PR | Bump | Assessment |
| --- | --- | --- |
| **#222** | `download-artifact` 4.3.0 → **8.0.1** | ⛔ **Do not merge as-is — paired-dependency asymmetry.** `ai-review.yml:1126` downloads what `ai-review.yml:1052` uploads with **`upload-artifact` v4.6.2**, which Dependabot did not bump. The artifact backend changed across those majors, so bumping one half risks breaking the **autofix** path of the merge gate — the exact path canon cannot self-verify. Convert to a paired upload+download bump, or close. |
| #223 | `checkout` 4.2.2 → 7.0.1 | Low risk / beneficial: canon already runs **v7.0.0 in 17 places**; this harmonises the **single** remaining v4.2.2 straggler (the autofix checkout) plus a patch bump on the rest. |
| #221 | github-actions group (codeql / dep-scan / sast-scan) | Low blast radius — the scanners are opt-in (`auto_install: false`) and report-only. |
| #224 / #225 | `setup-python` 6.3.0 → 7.0.0 · `setup-node` 6.4.0 → 7.0.0 | Major bumps, single-purpose, contained. |
| **#228** | runner base image digest | Needs the **image actually rebuilt and the PLAN-016 build-verification gates re-run** before merge — a bad base digest bricks the self-hosted fleet. Runner infra, founder-adjacent. |

**Recommended sequencing:** hold all six until the FT-15 pilot verification lands
(`plans/ROLLOUT_plan017-verify.md`). `ci/v2.10.0` was just cut and the fleet is
about to re-pin to it; adding unverifiable action bumps to `main` now means the
*next* tag — the one consumers may adopt — carries changes nothing exercised.
Once a consumer is on v2.10.0 and green, these can be merged in a batch and
verified on that consumer.

### FT-23 — canon does not self-adopt `docs-sync`/`doc-maintainer`, so canon changes to them cannot self-verify

**Status:** PARTIALLY RESOLVED / SCOPED-DOWN — surfaced by PLAN-017.
**Found:** 2026-07-21, PLAN-017 verification planning.

**SCOPE DECISION (founder, 2026-07-22):** `aidoc-flow-ci` is a **library**;
running `ai-review`/`doc-maintainer`/`composition` on itself would require
registering a `ci-runner,single-use` self-hosted pool + the reviewer App +
LiteLLM secrets purely to dogfood — cost a library repo does not warrant. Those
three self-callers are therefore **descoped**, not deferred. The regression risk
that mattered — the pin **resolver** (FT-15) — is carried offline by
`test_resolver.sh` (55 assertions), and the whole exercised/unexercised set is
now recorded in `docs/EXERCISER_INVENTORY.md` with that reason. `docs-sync` +
`secret-scan` + `standards-drift` + `audit-trail-check` already self-run; the two
remaining GENUINE gaps that do NOT need the pool — `pre-commit` (FT-36) and
`markdown-lint` (FT-34) — land in Workstream C / PR C4. What remains of FT-23
after this is those two, plus the inventory that keeps the set honest.

`aidoc-flow-ci` ships `ai-review`, `doc-maintainer`, and `docs-sync` as
`workflow_call` reusables and has **no self-caller** for any of them (the only
real self-`uses:` are `audit-trail.yml:33` and `self-secret-scan.yml:32` —
`audit-trail-check.yml` is the *reusable*, not a caller).
Consequence: a PR that changes those reusables **cannot exercise its own change** —
canon's CI proves syntax + `tests/run.sh` + fixtures only. PLAN-017's entire
verification therefore needs a 🔴 cross-repo consumer re-pin
(`plans/ROLLOUT_plan017-verify.md`).

This contradicts the repo's own stated discipline in `CLAUDE.md`: *"Wave 0 (this
repo) self-adopts BEFORE Wave 1+ consumers pull. The canon-source dogfoods its own
canon."*

**PARTIALLY CLOSED 2026-07-21** — `docs-sync` self-caller +
`.github/docs-sync.json` (dry-run) landed. **It paid for itself on day one:** the
pre-push review found that the reusable's dry-run path posts a PR comment
(`gh pr comment`) and therefore needs `pull-requests: write`, while both the
shipped template (`install/templates/workflows/docs-sync.yml`) and every consumer
caller grant only `read` — so the job fails 403 *exactly when it has something to
report*, and is green only when idle. operations never hit it because `proposed`
had always been 0. Fixed in the template (consumer-facing) and the new caller.
That is the FT-23 thesis demonstrated: canon shipped a latent defect it could not
see because it ran none of its own reusables.

**Still open — three gaps:**

1. **PR-scope.** The self-caller pins the RELEASED tag and fires on
   `push: [main]`, so it verifies the released reusable *after* a release, not a
   PR's own change to `docs-sync.yml`. Expressions are not permitted in `uses:`,
   so a SHA cannot be interpolated — closing this needs a PR-triggered job using a
   **local** `uses: ./.github/workflows/docs-sync.yml` reference. Note the
   interaction: a local-path caller carries no `@ci/vX.Y.Z` pin, so the resolver
   would fall back to the sibling self-caller's pin — worth designing, not
   bolting on.
2. **`doc-maintainer`** and **`ai-review`** self-callers — **BLOCKED on 🔴 runner
   provisioning, not on effort.** Verified 2026-07-21: canon has every secret
   (`LITELLM_*`, `APP_REVIEWER_1_*`) and is ARMED, but has **0 self-hosted
   runners**, and the LiteLLM proxy is host-local (`172.17.0.1:4001`, canon's own
   `CLAUDE.md`). Both reusables are LiteLLM-dependent (34 and 22 references);
   `docs-sync` self-adopted precisely because it has **0** and is deterministic
   Python. So an `ai-review` self-caller would either queue forever (self-hosted
   labels, no pool) or fail unreachable (`ubuntu-latest`) — **either way it bricks
   every canon PR.** Prerequisite: register a `ci-runner,single-use` pool for
   `aidoc-flow-ci` on the proxy host. Do NOT add these callers before that.
3. **PR-scope** (see item 1) applies to all three. **Partly mitigated 2026-07-21**
   by `tests/test_resolver.sh`: the resolver — the actual load-bearing mechanism —
   is now regression-tested on every PR against fixtures, with the patterns
   EXTRACTED from the live workflows so the test cannot drift from what it guards.
   Teeth verified: removing the owner anchor, or dropping the pre-release capture
   (the FT-15 truncation bug), each fail the suite. This does not replace a real
   self-caller — it covers the resolver, not the surrounding job — but it closes
   the gap that mattered most, and it works for `ai-review`, where a self-caller
   cannot exist until canon has a runner pool.

### FT-22 — `standards-drift.yml` resolver predates the FT-15 rule (both-forms + scan-scope + pre-release reject)

**Status:** ✅ **CLOSED 2026-07-21.** Ported to the full §4.2a property list:
`uses:`-line + `*.yml`/`*.yaml` scan scope, both pin forms, fail-closed on
multiple distinct pins, pre-release rejected, `grep` exit ≥2 distinguished from
no-match, and fetch-at-the-SHA. Also switched the script's `--ci-tag` to the
executed ref: the script uses it purely as a raw-URL ref for `TEMPLATE_BASE` and
its `check-pin-currency` self-fetch, so a SHA works identically — and a SHA-pinned
caller must compare against the templates it actually executed. §4.2a's "do not
copy `standards-drift.yml` as-is" warning is removed; both it and `docs-sync.yml`
are now conformant exemplars.
**Found:** 2026-07-21, PLAN-017 PR-A review (code-reviewer, MAJOR doc-consistency finding).

`standards-drift.yml:83` pioneered "resolve the adopted tag from the consumer's
own caller pin", but it accepts **only** the plain `@ci/vX.Y.Z` form and scans
`.github/workflows/` unfiltered. `REPO_STANDARDS` §4.2a now mandates three extra
properties that `docs-sync.yml` implements and `standards-drift.yml` does not:

- accept the commented-SHA form `@<40-hex> # ci/vX.Y.Z` (legal per
  `sync/check-pin-currency.sh:71`) — a consumer pinning `standards-drift` that
  way hard-fails INFRA-classed on every run today;
- restrict the scan to `--include='*.yml' --include='*.yaml'` **and** real
  `uses:` lines — otherwise a `*.yml.bak` / `*.disabled` leftover or a
  commented-out example can win the version sort (verified reproducible);
- capture and **reject** a pre-release `-suffix` rather than silently truncating
  `ci/v2.10.0-rc.1` → `ci/v2.10.0`.

**Fix:** port `docs-sync.yml`'s resolver verbatim (keyed to
`standards-drift\.yml`). It gained two further properties in PR-B —
fail-closed on multiple distinct pins, and fetch-at-the-SHA when the caller is
SHA-pinned — so use §4.2a's full property list, not the three enumerated above. §4.2a already points implementers at `docs-sync.yml`
and warns against copying `standards-drift.yml` until this lands.

### FT-16 — runner-fleet health has no reflexes: wedged supervisor queued 16 jobs ~3h with zero alerting

**Found:** 2026-07-20, operations — the single `ci-runner,single-use`
runner's JIT session went stale (container alive, `Runner.Listener`
token-refreshing ~50-min cadence, GitHub showing `offline`); the one-shot
supervisor only replaces containers when they EXIT, so it waited on the
zombie indefinitely. PRs #275/#276 queued 8 jobs each ~3h.
`ci-network-monitor` saw nothing (it probes api.github.com reachability
only; the network was fine). Diagnosis + `systemctl --user restart` were
fully manual.
**Surfaces:** `install/templates/runner/` (new watchdog script + timer
template), `docs/runners.md`.

**Fix sketch:** a fleet watchdog beside the supervisor (systemd timer, same
no-sudo model as ci-network-monitor): per enabled `ci-runner@<i>`, compare
GitHub-side runner status (`gh api repos/$TARGET_REPO/actions/runners`)
against supervisor liveness; on offline-while-container-running >N minutes,
restart the unit (safe: `docker run --rm` reaps the zombie; one-shot design
makes restart idempotent) + log a durable event. Highest-value automation
gap — every other layer sits on runners that currently fail silently.

### FT-17 — post-v2-cutover: verify whether ai-review INFRA-class failures persist; if so, give them bounded auto-recovery

**Found:** 2026-07-20 — iplanic #265 (`reviewer CLI 'codex' not found`) and
iplan-runner #94 (`no parseable verdict — fail-closed`, twice) recovered
only by manual skip-ai-review label-cycle (`gh run rerun` does NOT work —
reruns keep the pre-label trigger context; only label remove→re-add fires a
fresh evaluation). Root cause of BOTH observed instances: the ci/v1
vendor-CLI symptom already documented in `docs/troubleshooting.md` §10 —
fixed by the v2 cutover (PLAN-009), NOT a v2 gap.
**Surfaces:** `ai-review.yml`, `docs/troubleshooting.md` §10/§15,
`auto-merge-ai-prs.yml`.

**Fix sketch:** two parts. (a) After the PLAN-009 v2 cutover completes on
these repos, confirm whether any INFRA-class ai-review failure mode remains
(LiteLLM unreachable, asset-fetch, runner env) — the flow already
distinguishes its infra-error exits from verdicts in its messages. (b) If
yes: either self-retry the reviewer step with backoff, or emit a
machine-readable `infra-error` conclusion a small recovery workflow can act
on (bounded label-cycle, OPS-0066-capped) instead of requiring a
session-AI/human. Also document the rerun-vs-label-cycle trap in §15 (a
rerun does not re-read labels).

### FT-18 — deploy wizard has no required-context ↔ emitted-check-name validator; 🔴-step prep/verify is under-automated (builds the guard for FT-12's class)

**Status:** CLOSED for the required-context validator (PLAN-018 Workstream C /
PR C3, 2026-07-22). `install/required-context-map.py` DERIVES, for every required
context in every tier template, the consumer caller that must be installed to
produce it (context → reusable job-name → caller template → manifest consumer
path — no hand-maintained table). `deploy-ci-wizard.sh preflight §6` diffs that
map against the repo's installed workflows and reports, per tier, any required
context whose producer is not installed (the F2 hang, before arming).
`test_required_contexts.sh` asserts the canon invariant (every required context
has a producer, or the test is red — F2 latent in canon), the non-obvious chains
(`call / verify` → audit-trail caller via the audit-trail-check reusable), and
teeth. The remaining FT-18 scope — the broader PLAN-009 Phase 0 preflight
(per-repo LiteLLM secrets, pool registration) — stays open and 🔴 founder-manual;
the live phantom-context instances remain FT-12.

**Found:** 2026-07-20 — iplanic `main` carried the orphaned required
context `Lint / format / security hooks` (real check: `call / Lint / format
/ security hooks`); every PR blocked at green until a founder settings edit.
The live instances of this class are tracked in **FT-12** (phantom
required-contexts on framework/business/iplanic) — this item is the
*validator + preflight tooling* that prevents the class, not a duplicate
report of the instances. Broader class (PLAN-009 Phase 0): per-repo LiteLLM
secrets, pool registration, and protection rules are founder-manual with no
automated preflight that says exactly what is missing/wrong per repo.
**Surfaces:** `install/deploy-ci-wizard.sh`, `docs/runners.md` §3,
`install/templates/branch-protection-*.json`; cross-ref FT-12.

**Fix sketch:** extend `deploy-ci-wizard.sh` (or a new `preflight` mode) to
diff required-status-check contexts against the check names the installed
callers actually emit (catches orphans + renames — would have caught FT-12
and today's iplanic block automatically), and emit a per-repo 🔴-step
worksheet (exact commands + current-state checks) so the founder executes
rather than derives.

### FT-19 — job containers share the default docker bridge: fork-PR code can reach host-local services (LiteLLM) — egress restriction needed; founder risk-accept pending for the current tag

**Found:** 2026-07-20 pre-tag security lens — `run-ephemeral.sh` runs each
job container on the default bridge with no egress restriction; on a public
repo, fork `pull_request` code inside the container can reach the bridge
gateway `172.17.0.1`, where this fleet binds the LiteLLM proxy (`:4001`) and
where sibling runners live. Today the only boundary is the proxy requiring a
key (fork jobs get no secrets → 401) — a residual, not an open door, but
canon should not lean on "the service happens to require auth."
**Surfaces:** `install/templates/runner/run-ephemeral.sh`,
`install/templates/runner/README.md`, `docs/runners.md`.

**Fix sketch:** dedicated user-defined docker network per supervisor +
documented host firewall rules denying the container RFC1918 + the bridge
gateway except the explicit LiteLLM endpoint; or move LiteLLM off the bridge
the runners use. Until then the risk is PENDING explicit founder risk-accept for
the current tag (tracked here + CHANGELOG 2026-07-20; flip this line when
granted).

### FT-20 — runner defense-in-depth bundle: JITCONFIG via env, no job-container disk quota, no provision preflight

**Found:** 2026-07-20 pre-tag review (security + portability lenses), all
low-severity residuals: (a) the JIT config rides `-e JITCONFIG` — readable
by PR code via `/proc/1/environ` and `docker inspect`; mitigations real
(single-use, consumed at connect, same-user trust model) — prefer stdin or a
0600 tmpfs file; (b) no `--storage-opt size=`/tmpfs cap on `_work` — PR code
can fill host docker storage (shared-daemon DoS); needs overlay2+pquota so
opt-in; (c) `provision-runner.sh` preflight is docker-on-PATH only (added
2026-07-20); still unchecked: docker-group membership (socket permission),
`gh auth status`, `systemctl --user` reachability — those
first-run-adopter failures still land deep with raw errors while the
provisioner reports done (wizard-side sibling: FT-18).
**Surfaces:** `install/templates/runner/{run-ephemeral.sh,provision-runner.sh,README.md}`.

**Fix sketch:** (a) stdin/`--env-file` on tmpfs; (b) documented opt-in
`--storage-opt`; (c) `step_preflight` failing fast per missing prerequisite.

### FT-21 — release cut has no sequencing tool: prep-merge→tag ordering is tribal, and the self-pin chicken-and-egg guarantees one red run

**Status:** CLOSED (PLAN-018 Workstream C / PR C5, 2026-07-23) —
`scripts/release.sh` encodes the sequence with guards on all three v2.9.0 failure
modes: `prep <ci/vX.Y.Z>` (branch + VERSION-with-newline + sync-version-refs +
CHANGELOG promotion, and detects the ONE expected-red — version-sync's latest-tag
assertion — vs a real one); `tag <ci/vX.Y.Z> --dry-run-verified` refuses unless
on up-to-date main AND `VERSION` on the tree already equals the version (the (1)
guard: no tag pointing at the old version) AND the `--dry-run-verified` flag is
present (the 🔴 FT-30 gate). Chicken-and-egg handled per **option (a)**: the
expected one-red-run is documented, not worked around with a mutable `@main` pin
or a fragile pre-merge tag. `test_release.sh` drives every guard rejection.
`docs/RELEASE_CHECKLIST.md` points at it. This is the last Workstream C item —
canon's "no exerciser / tribal-knowledge" gaps are now closed.

**Found:** 2026-07-20, the ci/v2.9.0 cut — three failure modes in one release:
(1) the tag was cut BEFORE the release-prep PR merged → tag pointed at a
tree whose internal `VERSION` said v2.8.0 and whose consumer templates
carried v2.8.0 pins (fixed by delete+re-cut at post-prep main, safe only
because zero consumers had pinned); (2) the prep PR's own checks
hard-failed as a "workflow file issue" because its bumped self-pins
reference a tag that cannot exist yet (chicken-and-egg inherent to
self-pinning canon); (3) such runs are NOT retryable (`gh run rerun`
refuses workflow-file-issue runs) — recovery required an empty re-trigger
commit after the tag existed.
**Surfaces:** `scripts/sync-version-refs.sh`, `VERSION`,
`docs/RELEASE_CHECKLIST.md` (EXISTS — states tag-on-merge-commit ordering
but was not consulted during this cut, and is silent on the self-pin
chicken-and-egg + non-retryability gotchas — harden it, do not draft a
competing doc), potentially a new `scripts/release.sh` enforcing it.

**Fix sketch:** a `release.sh` that enforces the sequence: verify prep PR
merged at main → tag main → `gh release create` → print the consumer
re-stamp checklist (VENDORED-FROM headers). For the chicken-and-egg,
either (a) document the expected one-red-run + empty-commit re-trigger as
the known path, or (b) have the prep PR pin `@main` and a post-tag
follow-up flip to the tag, or (c) cut the tag from the prep BRANCH head
just before merge (tag == squash-merge tree only if squash is a no-op —
needs thought). At minimum: write the release runbook down; today it
lived in one session's context.
