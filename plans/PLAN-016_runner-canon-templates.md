# PLAN-016 — Runner reference implementation moves into CI canon

**Status:** ready — 7-pass verified (see Review log)
**Owner:** AI team (canon PRs) + founder (host actions, tag arming)
**Upstream:** OPS-0075 (unified v2 contract), PLAN-013 (uniform protected
AI-flows), PLAN-009 (fleet v2 cutover — consumes this plan's output)

## 1. Why

The v2 contract is deliberately unified: every reusable workflow routes by a
`runner_labels` input, the label pair `ci-runner`+`single-use` is defined in
`LABELS.md`, and the deploy wizard checks that a matching pool is online. But
the implementation that *satisfies* the label contract — the runner image and
single-use supervisor — lives in the **private** `aidoc-flow-operations` repo:

- The public adopter docs link into that private repo
  (`docs/runners.md:126`) — a 404 for every external adopter; the canon's
  documented adopter path is unfollowable.
- The wizard flags a missing pool as a 🔴 founder action
  (`install/deploy-ci-wizard.sh:48`) but cannot point at a template that
  creates one — the missing half of its own check.
- Image spec and workflows version independently, so workflows assume tools
  the image doesn't guarantee. Two shipped defects of this class: `gh: not
  found` (operations PR #101, ~2h lost) and `libatomic.so.1` missing (breaks
  markdownlint's node on business #63, 2026-07-20) — the current Dockerfile
  installs only `gh` + `ripgrep` beyond the base image.

Moving the *templates* (not the host state) into flow-ci puts interface and
reference implementation under the same `ci/vX.Y.Z` tags. Operations then
becomes the **first vendored consumer** of the runner canon — a pinned local
copy, exactly how every repo already consumes the canon workflows — because
its contract-lock, live systemd unit, onboarding docs, and dependabot config
all depend on the in-repo copy (ledger rows 13-15); deleting it would
red-gate the PR and break the deployed supervisor.

## 2. Scope split — AI-doable vs 🔴 founder-gated

**AI-doable (this plan's PRs):** add `install/templates/runner/` templates to flow-ci;
fix the image spec (add `libatomic1`); parameterize the provisioning default;
rewrite `docs/runners.md` §2 + the wizard hint; re-baseline the operations
copy as a vendored pin of the canon; changelog/roadmap entries; ci-preprod-review before tagging.

**🔴 founder-gated (NOT executed by this plan):** building + deploying the new
image on the runner host; registering pools for repos that lack them
(business, interlog — PLAN-009 Phase 0); disabling the legacy persistent
`iplan-runner` reviewer runner (OPS-0075 marks transitional services
must-disable); cutting/arming the `ci/vX` tag.

## 3. Tasks

### W1 — flow-ci: add `install/templates/runner/` (PR 1)

(Placed under `install/templates/` with the other consumer templates.)

Copy from `aidoc-flow-operations/scripts/ci-runner/`, adapted:

| File | Adaptation |
| --- | --- |
| `Dockerfile` | add `libatomic1` to the apt install line (fixes the markdownlint/node class) |
| `build-image.sh` | unchanged |
| `ci-runner@.service` | ExecStart hardcodes the operations checkout path (`:23`) — canon template carries an `@RUNNER_HOME@` placeholder; `provision-runner.sh` is the **only documented installer** and substitutes the operator's checkout path at install time (systemd does not expand env vars in ExecStart). The unit header's raw-`cp` instructions (`:4-10`) are REPLACED with "install via provision-runner.sh" — a raw `cp` of the placeholder unit would deploy a broken ExecStart |
| `run-ephemeral.sh` | unchanged |
| `provision-runner.sh` | canon-clean rewrite: `TARGET_REPO` required (`${TARGET_REPO:?set TARGET_REPO=owner/repo}`); `RUNNER_LABELS` defaults to the FINAL `self-hosted,ci-runner,single-use` (drop the transitional `aidoc,ci-ephemeral` hybrid at :15); DELETE the operations-only `step_old_runner_disable` migration step (:107-114,:153). ADD the ExecStart-path substitution when installing the unit (see `ci-runner@.service` row). This file is a *template operators copy and run on their host* — the template is canon; its execution and resulting state stay operator-side (no contradiction with §5) |
| `network-monitor.sh`, `ci-network-monitor.service`, `ci-network-monitor.timer` | **NOT templatized — operations-only.** `ci-network-monitor.service:7` hardcodes the operations checkout path and is installed only by raw `cp` (never via provision-runner); it is host-diagnostic tooling for this runner host, not adopter pool mechanics. Shipping it "unchanged" would reproduce the hardcoded-path defect class in public canon. It stays in operations `scripts/ci-runner/` outside the vendored set (its files carry no vendored header) |
| `README.md` | rewrite paths; replace **every** raw-`cp` unit-install instruction (the persistent-setup block at :66 AND the upgrade-section step at :81) with the provision-runner.sh flow (single install path, matches the placeholder mechanism); drop the operations-specific ci-ephemeral migration section; state clearly: templates here, host deployment state stays with the operator |

### W2 — flow-ci: docs + wizard point inward (PR 1, same)

- `docs/runners.md`: replace **every** operations reference, not just the
  bare links — the §2 blockquote framing ("this is aidoc-flow-operations
  infrastructure", :107-109), the "operations `Dockerfile` below" phrasing
  (:120), the three URLs (:126, :211, :262), and the §7 "Where the
  runner work lives" routing table (:275-281) — repointed to
  `install/templates/runner/` **except two operations-side carve-outs**: the
  Network-monitor bullet (:278, host-diagnostic tooling excluded from the
  template set per W1) and the Activation-log bullet (:280, an operations
  host log) keep pointing at operations — repointing them would mint fresh
  404s at canon paths that deliberately don't exist. §2's option-1/option-2 structure is reframed:
  the reference implementation is now in-repo and public, so option 2
  ("build your own") becomes "copy the canon templates". External-adopter
  guidance retained (ubuntu-latest default; the build-your-own path becomes
  actually followable).
- `install/deploy-ci-wizard.sh:48` hint gains the template path:
  `🔴 founder registers the pool (docs/runners.md §2/§5a; templates: install/templates/runner/)`.
- flow-ci `.github/dependabot.yml` gains a `docker` ecosystem watch on
  `/install/templates/runner` — base-digest bumps land in canon and flow to
  consumers via re-pin, never the reverse.
- `CHANGELOG.md` + `ROADMAP.md` entries; `DECISIONS.md` records the
  placement change canon-side (references OPS-0075; does not reopen it).

### W3 — operations: re-baseline as the first vendored consumer (PR 2)

**Not a deletion.** Operations keeps `scripts/ci-runner/` — its contract-lock
hard-asserts the files exist (`check-ci-contract.sh:64,:69-72`), the deployed
systemd unit ExecStarts `run-ephemeral.sh` from this checkout
(`ci-runner@.service:23` — deletion would wedge the live pool on next
restart/reboot, the outage class this plan exists to prevent), onboarding
routes through `provision-runner.sh` (`REPO_ONBOARDING.md:90`), and
dependabot watches the Dockerfile (`dependabot.yml:50`). Instead:

- Re-baseline `scripts/ci-runner/*` to byte-match the canon templates at the
  released tag (picking up libatomic1 + the provisioning cleanup), with the
  operations ExecStart path substituted in the deployed-unit copy.
- Stamp each file with a one-line vendored header:
  `# VENDORED-FROM aidoc-flow-ci install/templates/runner @ ci/vX.Y.Z` —
  the same pin-currency model as the vendored workflows.
- `scripts/ci-runner/README.md` gains the vendored-consumer note (canon is
  source of record; re-pin via the canon template + local ExecStart
  substitution; host runbooks unchanged and remain valid **by design** —
  the inbox cutover runbook's `scripts/ci-runner/...` paths still resolve).
- The **live** fleet-cutover runbook
  (`ops/inbox/2026-07-14_founder_flow-ci-v2-fleet-cutover-prereqs.md`,
  `Status: DRAFT — awaiting founder execution` at :10) raw-`cp`s the unit at
  :165 — under the placeholder mechanism that would deploy a broken
  `ExecStart=@RUNNER_HOME@/...` on the three fleet hosts it provisions. Its
  Stage-A install block (:162-171) is rewritten in this PR to the
  `provision-runner.sh` flow, making "provision-runner.sh is the only
  documented installer" actually true. **The rewrite passes the migration
  hybrid explicitly** —
  `RUNNER_LABELS=self-hosted,aidoc,ci-ephemeral,ci-runner,single-use`
  (plus `TARGET_REPO`/instance) — because canon's new default is final-only
  labels and Stage-A deliberately needs the hybrid so old-label base-branch
  jobs and new-label PR jobs both find a runner during each fleet repo's
  migration window (:157-159); dropping to the default would strand
  old-label jobs, the coexistence failure the two-stage transition exists
  to prevent. (The *completed* 2026-07-13 cutover
  runbook stays historical, untouched — vendoring keeps its paths valid.)
- `docs/REPO_ONBOARDING.md:90` invocation updated to
  `TARGET_REPO=vladm3105/<repo> bash scripts/ci-runner/provision-runner.sh`
  (canon's strict `TARGET_REPO` is kept; the bare invocation would now
  hard-error — the script's own header example rides in corrected via the
  byte-match).
- operations `.github/dependabot.yml` drops its `docker` ecosystem entry for
  `/scripts/ci-runner` (canon watches the Dockerfile now — consumer must not
  lead canon on base digests; config file, not a doc surface).
- `CHANGELOG.md` entry. (Doc-surface budget: ci-runner README +
  REPO_ONBOARDING + live fleet runbook + CHANGELOG = **4** — over the
  self-imposed 3, stated plainly: all four are one theme (the vendored
  re-baseline), and PR 2 touches none of the Rule-1 governance-trigger paths
  (DECISIONS/IPLAN/CLAUDE.md/.github/ai-review), so the hard cap does not
  bind; splitting the runbook fix out would leave a brick-window on the
  fleet hosts. Vendored-header stamps + dependabot are script/config files.)

### W4 — release (after PRs 1–2 merge)

- Run `ci-preprod-review` over the changed canon surface.
- 🔴 founder: cut the next `ci/vX.Y.Z` (minor — additive templates + docs),
  rebuild `aidoc-flow-runner:latest` from the (now vendored-current)
  Dockerfile. **No supervisor restart** — per the one-shot model (ledger
  row 5) the next spawned container `docker run`s the rebuilt `:latest`; a
  restart would kill any in-flight job for no benefit. The deployed systemd
  unit is untouched (vendoring keeps its ExecStart path valid).

## 4. Sequencing & release

PR 1 (flow-ci) → PR 2 (operations re-baseline, pinned to PR 1's content) →
ci-preprod-review → 🔴 tag + image rebuild. PR 2 must not merge before PR 1
(the vendored header must reference a real canon path). **PR 2 is not
auto-mergeable by design:** `scripts/ci-runner/` is in ai-review
`governance.locked_paths` (`check-ci-contract.sh:46`), so it requires the
founder's human approval — already in the W4 loop. PLAN-009 Phase 0+ then consumes the canon templates for
business/interlog pool registration.

## 5. Out of scope / explicit deferrals

- Pool **registration** for business/interlog and the public-repo AI-flow
  pools — PLAN-009 owns the fleet rollout.
- Retiring the legacy persistent `iplan-runner` aireview runner — 🔴 host
  action mandated by OPS-0075; tracked in PLAN-009's cutover checklist, not
  duplicated here.
- Any change to the label contract, workflow routing, or LiteLLM wiring —
  the interface is fixed (OPS-0075); this plan moves only the reference
  implementation.
- Host deployment state (`~/.config/ci-runner/*.env`, enabled units, live
  registrations) — stays on the operator side permanently.
- **Automated drift detection** for the vendored `scripts/ci-runner/` copy
  (extending `sync/check-pin-currency.sh` or the standards-drift flow to
  cover runner templates) — named follow-up, not this plan; the vendored
  header makes drift *visible*, wiring the check is deferred to keep this
  plan right-sized.

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | canon reusables are label-agnostic — routing is an input | `runs-on: ${{ fromJSON(inputs.runner_labels) }}` | .github/workflows/labeler.yml:57 |
| 2 | adopter docs link the runner implementation into the private operations repo | `aidoc-flow-operations/tree/main/scripts/ci-runner` | docs/runners.md:126 |
| 3 | wizard flags a missing pool as 🔴 founder but offers no template path | `founder registers the pool` | install/deploy-ci-wizard.sh:48 |
| 4 | image spec installs only gh+ripgrep beyond base — no libatomic | `apt-get install -y -qq --no-install-recommends "gh=${GH_VERSION}" ripgrep` | scripts/ci-runner/Dockerfile:44 |
| 5 | supervisor model is one-shot per job; image updates need no service restart | `each container is one-shot` | scripts/ci-runner/README.md:50 |
| 6 | OPS-0075 marks legacy persistent runners transitional, must-disable | `transitional rollback paths only and must` | ops/DECISIONS.md:2896 |
| 7 | provisioning default hardcodes operations as target repo | `TARGET_REPO="${TARGET_REPO:-vladm3105/aidoc-flow-operations}"` | scripts/ci-runner/provision-runner.sh:14 |
| 8 | install.sh already takes per-consumer visibility — the split lives at install time, not in canon | `--visibility public|private` | install/install.sh:17 |
| 9 | provisioning script defaults to the transitional hybrid labels OPS-0075 retires | `self-hosted,aidoc,ci-ephemeral,ci-runner,single-use` | scripts/ci-runner/provision-runner.sh:15 |
| 10 | provisioning script embeds an operations-only legacy-disable migration step | `step_old_runner_disable` | scripts/ci-runner/provision-runner.sh:107 |
| 11 | the completed 2026-07-13 runbook hard-codes the script paths — vendoring keeps them valid; it stays historical | `bash scripts/ci-runner/build-image.sh` | ops/inbox/2026-07-13_founder_flow-ci-v2-operations-cutover.md:52 |
| 12 | runner docs route all runner work to operations in §7, beyond the three URLs | `Reference image build` | docs/runners.md:274 |
| 13 | operations contract-lock hard-asserts the runner service file exists — deletion self-blocks PR 2 | `new runner service is missing` | scripts/check-ci-contract.sh:64 |
| 14 | `run-ephemeral.sh` is invoked from the repo checkout (README run surface; the load-bearing instance is the deployed unit's ExecStart at ci-runner@.service:23, whose `@`-path the gate regex cannot cite) — deletion wedges the live pool | `scripts/ci-runner/run-ephemeral.sh` | scripts/ci-runner/README.md:59 |
| 15 | onboarding routes private-repo provisioning through the in-repo script | `scripts/ci-runner/provision-runner.sh` | docs/REPO_ONBOARDING.md:90 |
| 16 | the LIVE fleet-cutover runbook raw-cps the unit — must move to the provision-runner flow with the placeholder | `cp scripts/ci-runner/ci-runner@.service` | ops/inbox/2026-07-14_founder_flow-ci-v2-fleet-cutover-prereqs.md:165 |
| 17 | the network-monitor unit hardcodes the operations checkout path — excluded from the canon template set | `ExecStart=/opt/data/aidoc-flow/operations/scripts/ci-runner/network-monitor.sh` | scripts/ci-runner/ci-network-monitor.service:7 |

Cross-repo citations (rows 4–7, 9–11, 13–17) resolve with `--root ../operations`.

## Review log

### Pass 0 - 2026-07-20 - author

Initial draft from in-session investigation (wedged-runner outage diagnosis +
flows/labels/docs verification). All ledger rows opened and read this session.

### Pass 1 - 2026-07-20 - independent

`verified-planning-reviewer` agent. 3 load-bearing + 2 minor findings, all
folded: (1) W2 undercounted the runners.md operations references (§2 framing,
:120, §7 table) — rewrite scope corrected; (2) provision-runner.sh carried
transitional-label default + operations-only legacy-disable step, and its
host-action nature seemed to contradict §5 — canon-clean rewrite specified,
template-vs-execution boundary clarified; (3) W3 would have stranded the live
founder cutover runbook's hard-coded paths — runbook path updates added to
PR 2; (4) W4 restart step contradicted ledger row 5 — removed; (5) placement
moved under install/templates/, real ci-network-monitor filenames. Ledger
rows 9-12 added covering the new claims.

### Pass 2 - 2026-07-20 - independent

`verified-planning-reviewer` agent (fresh instance). Verified all Pass-1
folds resolve their findings (no paper-overs), then surfaced 3 load-bearing +
2 minor NEW findings, all against the expanded W3 deletion design:
contract-lock self-block (`check-ci-contract.sh:64`), live-supervisor
ExecStart breakage (`ci-runner@.service:23`), orphaned onboarding
(`REPO_ONBOARDING.md:90`), dangling dependabot target, ≤3-surface budget
overflow. **Design changed in response:** W3 is no longer a deletion —
operations becomes the first *vendored consumer* of the runner canon
(pinned byte-matched copy + vendored headers), which preserves every
dependent surface by design; canon `ci-runner@.service` template gains an
`@RUNNER_HOME@` ExecStart placeholder substituted at provision time; drift
check wiring explicitly deferred (§5). Ledger rows 13-15 added (a 16th dependabot row was folded into W3 prose — its file exists in both repos, which defeats the gate's root-ordered resolution; the dependabot dependency itself is moot under vendoring since the Dockerfile stays).

### Pass 3 - 2026-07-20 - independent

`verified-planning-reviewer` agent (fresh instance). Confirmed the vendored
design neutralizes all three Pass-2 deletion-breakage findings, but found the
redesign itself not yet internally consistent — 3 load-bearing: (1) canon's
required-`TARGET_REPO` rewrite breaks the documented bare invocation in
`REPO_ONBOARDING.md:90` + the script's own header; (2) byte-match-vs-ExecStart
substitution is an unresolved contradiction with a broken-unit failure mode
under the raw-`cp` install docs; (3) dependabot auto-bumping the operations
Dockerfile makes the consumer lead the canon on base digests, falsifying the
vendored-header pin. Plus 3 minor (governance-locked path needs human review
on PR 2; two citation-line nits; wizard-hint section pointer).

**Result:** NOT ready — 3-pass cap reached (OPS-0066). STOPPED per the
circuit-breaker; open items surfaced to the founder with recommended
resolutions rather than dispatching a fourth pass.

### Pass 4 - 2026-07-20 - independent (founder-authorized cap extension)

Founder approved the Pass-3 resolutions; all six folded. Fresh
`verified-planning-reviewer` instance verified every fold resolves its
finding without paper-over (contract-lock existence-only → placeholder safe;
dependabot inversion coherent; completed runbook correctly historical) and
found **1 remaining load-bearing**: the placeholder-everywhere mechanism
missed the LIVE 2026-07-14 fleet-cutover-prereqs runbook, whose raw-`cp` at
:165 would deploy a broken placeholder unit on the three PLAN-009 fleet
hosts. Folded per founder's standing "address the gaps": the runbook's
Stage-A block moves to the provision-runner flow in PR 2 (W3), budget
restated honestly at 4 doc surfaces with the Rule-1 non-binding rationale;
row 11 qualifier corrected (completed, kept-valid); row 16 added. 2 minors
folded with it.

### Pass 5 - 2026-07-20 - independent

Fresh `verified-planning-reviewer` instance. Confirmed the Pass-4 live-runbook
fold resolves without paper-over and swept both repos for other raw-`cp`
paths. 2 load-bearing + 1 minor: (1) `ci-network-monitor.service` carries the
same hardcoded-checkout ExecStart and was marked "unchanged" for templating —
RESOLVED by scoping it operations-only (author judgment, flagged for founder
veto: host-diagnostic tooling, not adopter pool mechanics; exclusion cannot
break adopters, a second substitution mechanism could); (2) the Stage-A
rewrite would silently default to final-only labels, stranding old-label jobs
mid-migration — RESOLVED by requiring the explicit hybrid `RUNNER_LABELS`
override in the rewritten block; (3) README's second raw-`cp` at :81 —
RESOLVED by widening the W1 README instruction to every unit-install block.
Ledger row 17 added. Founder's standing "address the gaps" direction covered
the folds; Pass 6 is the final verification.

### Pass 6 - 2026-07-20 - independent

Fresh instance, narrow verification of the Pass-5 folds. Folds 2 and 3 clean
(hybrid-override coherent with W1's final-only default + row 9; README
raw-`cp` widening complete). 1 load-bearing: the network-monitor exclusion
was not propagated into W2's §7 "all repoint" instruction — as written it
would repoint the runners.md:278 Network-monitor bullet at a canon path W1
deliberately doesn't create. RESOLVED: §7 rewrite now carves out the
Network-monitor (:278) and Activation-log (:280) bullets to stay
operations-side.

### Pass 7 - 2026-07-20 - independent

Fresh instance, closing verification. Carve-out confirmed exact (:278
Network-monitor, :280 Activation-log verified as the only §7 bullets
referencing excluded artifacts; every other bullet repoints to template-set
members). No design re-opened.

**Result:** ready — zero load-bearing findings.
