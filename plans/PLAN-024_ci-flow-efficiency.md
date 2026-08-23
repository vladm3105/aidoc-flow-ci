# PLAN-024 — aidoc-flow-ci library optimization

**Status:** PARTIALLY EXECUTED — Phase A **A1/A2/A3/A5/A6/A7 are done**
(A5 2026-08-20, the rest via #496, `2df9e87`/`d60e56f`); A4 and all other phases
Draft; superseded in part by PLAN-025 (D/E/F/G)
**Owner:** canon (aidoc-flow-ci)
**Scope:** this repo's own artifacts — reusable workflows, install templates,
canonical scripts, `docs/REPO_STANDARDS.md`. Consumer repos and other projects
are out of scope (narrowed 2026-08-06).
**Change level:** C3. Dropped to C2 after the Pass-3 withdrawals, then back to C3
when Phase G (drop four CI flows into the hook layer) was added on 2026-08-07 —
it changes the surface every consumer adopts. Phase H is C2: after its own
withdrawal it is a docs + fragment change, not a workflow build.

> **A5 executed 2026-08-20** on the founder's deprecation of `doc-maintainer`
> — decision of record `DECISIONS.md` **CI-0040**. All eleven defects are closed
> *not planned*.
>
> **A1/A2/A3/A6/A7 EXECUTED 2026-08-21 via #496** (`2df9e87`, `d60e56f`).
> This blockquote previously read *"No artifact or wiring has been removed"* and
> stayed that way after the removal landed, so the plan and the tree disagreed on
> a shipped breaking change. Removed: the reusable, the caller template, the
> config and conventions templates, `scripts/doc-maintainer/` (593 lines), three
> `manifest.json` entries, `LITELLM_DOC_API_KEY` and the second `llm-smoke` arm.
> The flow is no longer installable through any supported path. Execution record:
> `DECISIONS.md` **CI-0045**.
>
> **A4 remains open** (`litellm-smoke` alias circularity).
>
> **A5 deviated on one issue.** #404 was carved out of the closure by A5's own
> text (*"#404 must NOT be closed"*) and was closed anyway. Its defect survives
> verbatim in `docs-sync`; re-filed as **#495**.

## 1. What this plan found — and mostly withdrew

Three drafts of this plan proposed removing or collapsing library structure on
the strength of surface measurements (line counts, duplication ratios, run
minutes). **Two independent review passes falsified most of it.** The withdrawn
items are recorded here rather than deleted, because each is an attractive-
looking change that the next session would otherwise re-propose.

| Proposed | Verdict | Why |
| --- | --- | --- |
| Collapse the 9 public/private template pairs into one template each | **WITHDRAWN** | The pairs are the fix, not the debt (§2) |
| Document a template naming rule | **WITHDRAWN** | The rule exists at §16.9, and the manifest disambiguates (§3) |
| Ship a canonical pre-commit fragment | **WITHDRAWN** | Already shipped (§4) |
| Retire `docs-sync` | **WITHDRAWN** | Its changelog operation has no successor; 10 callers vs 3 |
| Demote `ai-review` from required contexts | **WITHDRAWN** | Among the cheapest flows measured |
| Promote a `python-tests.yml` reusable (H1) | **WITHDRAWN** | The job name IS the required context; a reusable renames it (§5 H1) |
| Drop 4 CI flows into the hook layer (Phase G) | **WITHDRAWN** | `markdown-lint` is a live required context on canon's `main`; the scanners are a founder MUST-HAVE (§5 G) |

### 2. The template pairs are load-bearing — do not collapse them

The nine `-public`/`-private` pairs look like hand-maintained duplication
(`audit-trail` differs by 4 lines of ~40). They are the **resolution mechanism
for `install.sh --update` on private consumers**, shipped at `ci/v2.1.0` to
close a live defect: six flows previously carried `runner_labels` as a commented
hint only, `--update` resolves each surface through `manifest.json`'s
`visibility_variants`, and with no private variant it re-applied the label-less
generic → the reusable's `ubuntu-latest` default → **jobs queue forever on a
private repo** (Claim 1).

Collapsing them restores that defect. A per-consumer input the adopter must
remember to set is exactly what was found insufficient.

The AI-flows *did* collapse to one template at `ci/v2.2.0` (Claim 2) — that is a
deliberate exception for the protected flows, stated in the same section, not a
precedent the generic checks failed to adopt. An earlier draft cited it as
precedent; that reading was wrong.

**Corollary for the security boundary:** every one of the nine reusables already
defaults `runner_labels` to `ubuntu-latest` (Claim 3), so the hazard an earlier
draft warned about — a collapse silently defaulting lint flows onto the
self-hosted pool — has no mechanism. The default does not live in the template.
The real exposure runs the other way and is the `--update` defect above.

### 3. The naming rule already exists

`REPO_STANDARDS.md` §16.9 states that canon ships **three** naming shapes and
that the bootstrap must name each template literally rather than deriving it
(Claim 4). `manifest.json` records `visibility_variants` on the paired flows and
an explicit `_note` on every uniform one (Claim 5). `install.sh` carries a
LOAD-BEARING comment forbidding refactoring the literal names into a lookup, and
`tests/test_install.sh` pins the exact file set.

The residual true observation is narrow: a bare *filename* does not tell an
adopter which shape it belongs to. That is a docs nicety, not the interface
defect an earlier draft asserted, and it does not justify restructuring.

### 4. The canonical pre-commit fragment is already shipped

`install/templates/pre-commit-hook-block.yaml` exists and the rulebook names it
canonical (Claim 6). Canon's own `.pre-commit-config.yaml` carrying exactly
`check-yaml`, `end-of-file-fixer`, `trailing-whitespace` is **evidence the
fragment shipped and canon self-adopted it (Wave 0)** — an earlier draft read
the same three hooks as evidence that no fragment existed.

## 5. What survives

### Phase A — eliminate `doc-maintainer` from the library

**Decision of record (founder, restated 2026-08-06):** the flow is eliminated,
not paused, not graduated. An intermediate draft of this plan reversed that on
an inference from "all flows should be AI-first"; the inference was the author's,
not an instruction, and is withdrawn.

**Measured basis:** 48 scheduled runs/day/repo (Claim 7), ~88% of CI minutes on
both repos that ran it, and 11 open defects — the largest single defect cluster
in this repo's tracker.

**One fact the decision post-dates, recorded once:** the flow is live on
`operations` (`dry_run: false`), so this removes a running capability there, not
only a dry-run pilot. Elimination proceeds regardless; the consumer-side removal
is that repo's business and out of this plan's scope.

A1. **Remove the library artifacts:** the reusable
(`.github/workflows/doc-maintainer.yml`, 561 lines), the caller template, the
config template, the conventions template, and `scripts/doc-maintainer/`
(planner 338 / reconcile 140 / apply 115 = 593 lines of Python).

A2. **Remove the distribution wiring:** 3 `manifest.json` entries (Claim 22), 4
`deploy-ci-wizard.sh` references, 1 in `install.sh`, and
`install/set-litellm-secrets.sh`'s `--doc` flag, which mints the
`ai-doc-maintainer` key into `LITELLM_DOC_API_KEY`.

**33 tracked files reference the flow**, not the 49 an earlier draft claimed —
that count traversed gitignored `tmp/`, which this repo may prune at any time,
so it was not reproducible. Beyond the surfaces already named, the removal
touches `docs/WORKFLOWS.md` (the workflow catalog, adoption matrix and all of
§3.9), `docs/security.md`, `docs/runners.md`, `docs/EXERCISER_INVENTORY.md`,
`docs/architecture.md`, `docs/AI_CI_DEPLOYMENT.md`,
`docs/REVIEWER_APP_ONBOARDING.md`, `install/templates/actions-permissions.json`,
`install/templates/runner/Dockerfile`, `sync/check-drift.sh`,
`.github/workflows/ai-review.yml:597`, `CLAUDE.md`, `README.md`, `ROADMAP.md`
and `HANDOFF.md`.

**Append-only surfaces are carved out and must NOT be scrubbed:**
`CHANGELOG.md` (56 hits), `DECISIONS.md` (11) and `docs/MIGRATION_v2.0.0.md` (8)
are history. Correct them with new dated entries where needed; never edit them.

**The three test files are EDITED, not removed.** All three are general suites
covering surviving code — `test_resolver.sh` is the only regression cover for
the FT-15 resolver on three flows that stay (Claim 28), `test_scripts.sh` covers
`check-pin-currency.sh` and both `--repin` seds, and `test_contract.sh` loops
every `workflow_call` reusable. Deleting them would silently drop several
hundred assertions from a suite this repo tracks at 1,093. Remove the named
blocks only.

A3. **Rulebook surgery — corrected; an earlier draft had this backwards.**

- **§20.2 needs almost nothing.** Rules 1–7 govern the two prompt files this
  repo ships for `ai-review` and never mention doc-maintainer (Claim 29). Only
  rule 8's Scope note is flow-bound. The claim that §20.2 was "derived from
  doc-maintainer incidents" was false.
- **§24.1–§24.3 are general rules with doc-maintainer as *evidence*, not rules
  about it** — implicit `bash -e` in any `run:` step, error-message
  de-conflation, and template-default executability. Keep all three; rewrite
  only their measured-evidence paragraphs. **§24.4 is the sole subsection that
  collapses**, being an explicit pointer to §20.2 rule 8.
- **Do not vacate the §24 number.** Claim 26 is a section-number *reservation*,
  not a note needing an edit. PLAN-021 is In Progress with §24 as its declared
  canon deliverable, and PLAN-023's yield-and-renumber declaration is keyed to
  §24 staying occupied — so re-state PLAN-021's status rather than renumbering.

A4. **MAJOR bump — `ci/v3.0.0` — and it carries three obligations the plan must
discharge inside Phase A, not after it.**

- **The MAJOR-bump smoke gate is circular as written.** `RELEASE_CHECKLIST.md`
  requires `litellm-smoke.yml` to pass with **both** canonical aliases including
  `ai-doc-maintainer` (Claim 30), and that alias is what A3 deletes. So Phase A
  must also edit `litellm-smoke.yml` (Claim 31), the two rulebook/checklist
  statements of the rule, and `test_contract.sh`'s assertion that the smoke
  names both aliases and keys. **Miss this and `ci/v3.0.0` cannot be tagged.**
- **A migration guide is a checklist item, not release notes** (Claim 32). Ship
  `docs/MIGRATION_v3.0.0.md`; it is the natural home for the instruction that a
  consumer must **delete the caller, not `--repin`**, since `--repin` would move
  them to a tag where the called workflow does not exist.
- **The 🔴 FT-30 cold-start gate is already owed.** `scripts/release.sh` puts
  `manifest.json` in the explicit cold-start surface (Claim 33), so removing
  manifest entries demands `--dry-run-verified`; and PLAN-021 records that the
  founder-executed dry run was already owed before the next tag (Claim 34).
  Name it as a blocker with its owner rather than discovering it at tag time.

A5. **Close 10 of the 11 defects, and carve one out.** Close #413, #409, #408,
\#406, #403, #391, #390, #389, #384, #372 as *not planned — flow eliminated*.

- **#404 must NOT be closed.** Its defect — a scripts directory not cleared
  before fetch, so a committed package shadows the module at import time —
  **survives verbatim in `docs-sync`**, the flow A6 makes sole: `mkdir -p
  .docs-sync-scripts` with no preceding `rm -rf`, then `python3
  .docs-sync-scripts/<op>.py` (Claim 35). Re-file it against `docs-sync`.
- **Two closes dangle a live citation.** #413 is cited in the rulebook as the
  filed §20.2 gap, and #372 is carried in `REPO_STANDARDS.md` and twice in
  `DECISIONS.md` as a deliberately-unfixed defect. Pair each close with its
  citation edit — and in `DECISIONS.md` as new text, never a rewrite.
- Name each issue's subject beside its number in the closing comment, so the
  #404 carve-out is visible rather than buried in a bare list.

A6. **`docs-sync` becomes the sole doc flow — and canon currently tells adopters
the opposite.** Three passages in `docs/WORKFLOWS.md` still direct new consumers
to adopt `doc-maintainer` and describe `docs-sync` as the interim layer awaiting
supersession (Claim 36). Those are named edits in this phase, not consequences
to notice later. **What `docs-sync` then becomes is Phase B.**

A7. **Declare the retired check.** `test_contract.sh`'s §24.3 assertions all read
the doc-maintainer config and conventions templates, so after A1 that rule
survives with **zero automated readers**. The workspace rule is explicit that a
change retiring a check must say so in the change that retires it.

### Phase B — reduce `docs-sync` to what it actually does

Phase A makes `docs-sync` the workspace's only doc automation. In its current
shape that means **one implemented operation of three, disabled everywhere** —
all ten configs are `dry_run: true` (Claim 37). This phase makes the flow honest
about its own scope. **The improvement is mostly subtraction.**

> **B1 and B2 ARE UNSAFE AS WRITTEN — do not execute (#501).** Both delete a
> module from `scripts/docs-sync/`, which pre-FT-15 consumers fetch from canon's
> `main` at runtime. Seven of eight consumers pin below `ci/v2.10.0`, the fetch
> loop names all three modules by name, and it hard-exits on a 404 — so a
> deletion reds their `push: main` job on merge, with no re-pin involved. The
> freeze lifts only when every consumer pins ≥ `ci/v2.10.0`.

B1. **Delete `version_sync` — it duplicates a better-placed tool.**
`scripts/sync-version-refs.sh` already makes `VERSION` the sole source and
rewrites the mechanical install references across 14 targets (Claim 38), and it
runs as a **pre-commit hook**, so it fails before the commit lands rather than
after the merge. `version_sync` would do less, later, via a per-consumer regex
map whose design has been deferred to "alpha.2" through two alphas.

**It also ships `enabled: true` while being detection-only** (Claim 39) — a
config asserting a capability that does not exist, which is worse than shipping
it off. Remove the operation, its config block, and `scripts/docs-sync/version_sync.py`.

B2. **Delete `cross_ref_repair`.** `links.yml` already detects dead links via
lychee. The only thing this operation adds is *auto-repair* — a bot write to
`main` for a problem a human is already told about. It is `enabled: false`
(Claim 40), unimplemented, and its stated design dependency was never resolved.
Remove the operation, its config block, and `scripts/docs-sync/cross_ref_repair.py`.

B3. **Keep `changelog_stub`, and make dry-run its permanent mode.** This is the
one real capability. The config frames `dry_run: true` as a 1–2 week pilot
pending "≥5 merges with zero divergence" (Claim 37); nobody graduated it, and
that is the right outcome rather than a stalled one:

- The operation's value is **telling you the changelog was not updated**. A PR
  comment delivers that in full.
- Committing a deliberately low-quality stub to `main` delivers the same signal
  *plus* a bot commit *plus* follow-up work to rewrite it. The stub is low-quality
  by design — "currency, not polish" — so the write is not the product.
- The comment path needs no new implementation. It works now that CI-0015 is
  fixed; it had never executed before that.

So: rewrite the config comment to state that dry-run **is** the mode, not a
waypoint, and retire the live-commit path — with it, the `AIDOC_FLOW_BOT_ID`/
`AIDOC_FLOW_BOT_KEY` secrets, the commit allowlist and the 50-commits/day cap,
none of which a comment-only flow needs.

B4. **Result:** one operation, ~92 lines of Python instead of 186, one config
block instead of three, no bot writes to `main`. Small enough to maintain.

B5. **The alternative, stated so it is a choice and not a default.** CI-0015 is
the reason for skepticism: this flow **reported green from the day it shipped**
until a merge finally produced a proposal (Claim 41), because the failing step
was gated behind a condition that never fired. Canon's own `self-docs-sync` shows
48 successes in 50 runs, all dry-run, all writing nothing. **If B1–B3 are not
done, retire `docs-sync` as well** and let documentation currency rest on the
`CLAUDE.md` discipline rather than on CI. What must not survive Phase A is the
current state — three operations, one implemented, none enabled — as the
workspace's only doc automation.

### Phase C — release currency (the library's own CD)

Uncontested across both review passes. The last tag is `ci/v2.16.0`
(2026-07-27); merges have landed since, and consumers pin by tag, so everything
merged since is **merged but not deployable**.

```bash
git tag -l 'ci/v*' --sort=-creatordate --format='%(creatordate:short) %(refname:short)' | head -3
```

C1. Cut `ci/v3.0.0` carrying Phases A and B plus the merged-but-unreleased work.
C2. Adopt a cadence rule in `docs/RELEASE_CHECKLIST.md` — no more than N merges
or D days of unreleased canon.
C3. Record per release whether it changed **caller bodies**: `--repin` rewrites
only `uses:` strings and cannot deliver a body change, while `--update` replaces
bodies and clobbers local `runner_labels_*`/`permissions:`/`config-path:`.
Phase A removes a workflow outright, which `--repin` cannot express at all —
C3 is what stops a consumer re-pinning into a broken state.

**Obsoleted by Phase A.** An earlier draft carried a phase to fix the
`doc-maintainer` cron cadence — expose `lookback_min` as an input so the
90-minute reconcile window and the cron cadence move together, since a
template-only change would leave a 90-minute window opened once per 24 hours.
Elimination removes the reconciler, so the whole phase is moot. Recorded because
the underlying trap (a hardcoded window sized against a cadence set elsewhere)
is a shape worth recognising in the flows that remain.

### Phase D — decompose `ai-review.yml`, with the size target corrected

1,785 lines, 32% of the repo's workflow code in one file, and the largest share
of its historical defect load. Real, and the only one of the three original
"defects" that survived review.

D1. **The stated ~600-line target is unreachable by the proposed split.** The
file has three jobs — `trust`, `ai-review`, `autofix` (Claim 12). Extracting
`trust` and `autofix` leaves the review job at ~1,213 lines. The remaining bulk
is *steps inside* the review job, not separable jobs.

D2. **And splitting further trades away gate coverage.** The job id `ai-review`
is what renders the required context `call / ai-review` (Claim 13); moving the
verdict/labelling tail into a nested reusable gives it a path-derived context
that is not in any branch-protection tier, so a verdict failure would stop
blocking — while that step is deliberately the enforcement half (Claim 14).

D3. Therefore scope D to extracting `trust` and `autofix` only, and **state the
resulting size honestly (~1,200 lines) rather than claiming a target the split
cannot reach.** Whether to go further is a separate decision with a gate-coverage
cost, and needs its own record.

### Phase E — `pre-commit` reusable scope input (low priority)

E1. The reusable runs `pre-commit run --all-files` unconditionally (Claim 15).
Add an opt-in `scope` input; keep `all-files` as the default.

E2. Two constraints: the checkout sets no `fetch-depth`, so there is no base ref
for `--from-ref/--to-ref` (the input must set depth and define `push` behaviour);
and a `run-stage` input already exists (Claim 16) that `scope` must compose with
rather than duplicate.

E3. **Priority: low.** Execution was not the bottleneck anywhere measured. Ship
for interface correctness, not throughput.

### Phase F — overlap matrix in the rulebook

F1. Per standalone scan flow, which pre-commit hook subsumes it and where it is
sole coverage. Two entries are load-bearing: `sast-scan` (semgrep) is the only
SAST where CodeQL is N/A (Claims 17, 18), and `secret-scan` runs `gitleaks git`
over full history, which a working-tree hook cannot do (Claim 19).

F2. Not a new rule — a consolidation of facts already scattered across §3, §4.1
and the workflow headers.

### Phase G — collapse redundant GitHub jobs into the local hook layer

**Directive (founder, 2026-08-07): keep the local check, drop the GitHub job,
reduce PR wait.** The mechanism that makes this safe is already in the library
and an earlier draft missed it: **the `pre-commit` reusable runs
`pre-commit run --all-files` (Claim 15), so every hook in the config is re-run in
CI.** A tool moved into the canonical hook block is therefore still enforced on
every PR — by **one** job instead of four. Coverage is preserved; the job count
is not.

> **PHASE G IS WITHDRAWN (Pass 10, 2026-08-07).** Its safety proof was false,
> its coverage substitutions do not work, and it reverses a founder directive.
> The detail below is retained because each failure is instructive; **do not
> implement it.** What remains open is G6.

G0. **~~Safety proof~~ — FALSE, and this is the phase-killer.** The claim was
that none of the four dropped flows is a required context, verified by grepping
`install/templates/branch-protection-*.json`. **That is precisely the surface
where the fact is invisible.** Live protection on canon's own `main`:

```console
$ gh api repos/vladm3105/aidoc-flow-ci/branches/main/protection \
    --jq '.required_status_checks.contexts'
["suite","call / verify","call / markdownlint",
 "call / Lint / format / security hooks","call / gitleaks"]
```

**`call / markdownlint` is required on canon's `main` right now.** The rulebook
says so in prose too — `markdown-lint` is named among "the eight caller templates
feeding a required context" (Claim 51) — and `tests/test_contract.sh` calls it
"the **live-protection-only** `call / markdownlint`", i.e. the test hardcodes it
*because* a template-derived map cannot see it.

Dropping `markdown-lint` removes the producer of a required context, pinning
every canon PR on "Expected — Waiting for status to be reported", `--admin`-only
forever. **G2 violates this plan's own §6 non-goal.** Any future work in this
area must read **live protection**, never only the templates.

G1. **Extend the canonical hook block — four implementation constraints, all
load-bearing.** `install/templates/pre-commit-hook-block.yaml` currently ships
three upstream hooks. Add `markdownlint`, `bandit`, `pip-audit`. Then:

- **G1a. Bump the marker version to `v3`.** The header line
  `# CANON: aidoc-flow-ci pre_push_check v2` is the **refresh key** — bootstrap
  re-merges the block only when a consumer's marker is *lower* than canon's
  (Claim 46). **Without the bump the change never reaches an already-adopted
  consumer**, `--update` excludes this file, and `--apply` writes no content.
  Every adopter would keep the three-hook block while canon drops the four CI
  flows — the exact coverage gap G is designed to avoid, delivered silently.
- **G1b. SHA-pin every new `rev`, `# frozen: vX.Y.Z` format.** Canon's stated
  reason is specific and applies with more force to three new entries: pre-commit
  `pip install`s the cloned tree, so the upstream build backend **executes at
  install time** on developer machines and on the cold ephemeral CI pool, which
  re-resolves the ref every run — a moved tag would reach the fleet in one CI
  cycle (Claim 47). Use `pre-commit autoupdate --freeze` output so bumps
  round-trip.
- **G1c. `pip-audit` must be registered at the DEFAULT commit stage, not
  `manual` — and this is the one that breaks G silently.** The `pre-commit`
  reusable runs `pre-commit run --all-files` with no `--hook-stage`, which
  selects only the `pre-commit` stage; canon's own `run-stage` input documents
  `manual` as the expected placement for "opt-in audits (e.g. pip-audit)"
  (Claim 10). **A pip-audit hook at `manual` stage would not run in CI at all**,
  so dropping `dep-scan` in G2 would lose the check outright rather than relocate
  it. Register at the default stage and accept the commit-time cost, or leave
  `dep-scan` in place — but do not assume the hook covers it.
  *This is the precedent: PLAN-018 F3 records that the fragment once had no
  commit-stage hook at all, so the required check "exited 0 while inspecting
  nothing" (Claim 48). Same failure shape.*
- **G1d. Record the trade FT-35 makes worse.** The block goes from one
  third-party `rev` to four, and canon has **no automated bump path** for the
  pre-commit ecosystem (no dependabot coverage in canon or the consumer
  template). Four pinned revs that nothing bumps is a maintenance liability the
  plan is choosing knowingly, not an oversight.

**G1 must land, and reach consumers, before G2.** Dropping a CI flow before its
hook is present *on the adopter* is a real coverage gap — which is why G1a is a
precondition of G2 and not a tidy-up.

G2. **Then drop four CI flows from the PR fan-out:**

| Dropped | Replaced by | Net |
| --- | --- | --- |
| `markdown-lint` | `markdownlint` hook | same check, no separate job |
| `dep-scan` | `pip-audit` hook | same check; the flow was `fail-on-findings: false` and could never block |
| `sast-scan` | `bandit` hook | **improvement** — semgrep cannot install on the self-hosted image (#349), so the flow is inert where it is the only SAST |
| `trivy-scan` | none | report-only; cannot fail by design, so nothing is lost that was ever enforced |

G3. **Keep these, and the reasons are specific:**

- **`pre-commit`** — the enforcement backstop. A local hook is bypassable with
  `--no-verify`; this is what catches that, and it is a required context in all
  four tiers (Claims 16, 20). **G2 increases its importance**, since it becomes
  the CI reader for four more tools.
- **`links`** — lychee is network-dependent and has no practical pre-commit
  equivalent. Not redundant.
- **`secret-scan`** — `gitleaks git` reads full history (Claim 19); a
  working-tree hook structurally cannot. Not redundant.
- **`codeql`** — weekly and free on public repos; near-zero PR cost.

G4. **Measured effect:** four fewer jobs per PR, each of which currently pays a
full runner-provisioning cycle. This is the change that most directly reduces
wait time, and it removes no check that has ever fired — all four dropped flows
show 0 failures across the sampled windows, and three of them **cannot** fail
(`fail-on-findings: false`).

G5. **~~The one thing this trades away~~ — the trade was mis-stated, and the
escape hatch is destroyed by the phase proposing it.** "Three of them *cannot*
fail" was wrong: `fail-on-findings: false` is a **default**, not a capability.
Both `trivy-scan` and `dep-scan` implement `exit 1` when it is true (Claim 52),
and `dep-scan` additionally has a **zero-coverage guard** that no hook replicates.
G5's own remedy — "later flip `fail-on-findings: true` on the flow" — is
unavailable the moment G2 deletes the flow.

G5a. **G2 reverses a founder directive without naming it.** PLAN-014 records the
directive of 2026-07-18: *"our own scanners are **MUST-HAVE**"*, status
**IMPLEMENTED**, with **"Remaining: Phase 5 (graduate `fail-on-findings`
false→true per scanner — a founder step)"** (Claim 53). The three scanners are
report-only **pending a founder graduation**, not because they are worthless —
the exact inverse of what G2 assumed. Deleting them cancels a founder-owned step
and voids PLAN-014's stated exit criterion (an *own* canon reusable for SCA,
IaC and SAST). Under plan-status governance that would require re-levelling
PLAN-014 in the same change; G did none of it.

G5b. **The hook substitutions do not actually work.** Three independent
mechanisms, any one of which is fatal:

- **The merge de-dups on repo URL, and stamps the marker on a partial merge.**
  If a consumer already declares an upstream repo, canon's hook is **reported,
  never applied** — while the marker is written anyway, so bootstrap never
  revisits the file. `framework` already declares `PyCQA/bandit`,
  `pypa/pip-audit` **at `stages: [manual]`**, and `igorshubovych/markdownlint-cli`.
  So on framework: canon's pip-audit is silently not applied, framework's own
  stays `manual` (never running in CI, per G1c), and G2 deletes `dep-scan`. The
  silent coverage gap G1a exists to prevent, arriving by a route G never
  considered.
- **`pip-audit` with no arguments audits the current *environment*** — in the
  reusable, a bare runner venv holding `pre-commit`. framework's working entry
  needs `args: [-r, <path>]`, a per-repo path a canonical fragment cannot know.
- **`markdownlint-cli2` ≠ `markdownlint-cli`.** The flow runs cli2 against
  canon's `.markdownlint.json`, and canon's docs were brought into conformance
  with *that* tool and config; the pre-commit ecosystem's usual hook is cli1,
  with different ignore semantics. "Same check" is not true.

G6. **What is actually open, and it is the opposite of G.** The live item is
**PLAN-014 Phase 5** — graduate `fail-on-findings` false→true per scanner. That
is a **founder step**, already owed, and it converts three report-only jobs into
real gates rather than deleting them. It does not reduce job count.

**And on the original goal: within the library, there is no safe job-count
reduction available.** The measured PR wait was ~99% *queue*, not execution, and
its remedy was runner capacity — which left scope when the plan narrowed to the
library on 2026-08-06. Reducing wait time is a consumer-infrastructure change,
not a canon change. Saying so is more useful than a fourth attempt to find a
flow to delete.

### Phase H — promote what `aidoc-flow-framework` built that canon lacks

Surveyed `framework`'s seven own (non-canon) workflows. Two findings.

H1. **WITHDRAWN — a `python-tests.yml` reusable has no migration candidates.**

An earlier draft proposed promoting the `setup-python` → install → run-command
shape, listing seven candidates. **Founder review (2026-08-07) established that
rows 3–7 are SDD-domain work belonging to `framework` alone, and a close read of
rows 1–2 disqualifies them too.** The phase is withdrawn, not deferred.

The decisive reason is not domain specificity — it is branch protection:

- **The job `name:` string IS the required status context**, and `acceptance.yml`
  says so in-file: changing it "silently un-satisfies branch protection, which
  never fires again" (Claim 42). A reusable renders its contexts as
  `call / <job name>`, so migrating `Acceptance tier (deterministic)` **renames
  the required context** and un-satisfies protection on `framework`. That file
  also records the workflow becoming "the 6th required context on 2026-07-27"
  (Claim 49). Both rows 1 and 2 feed required contexts.
- **Their content is SDD-specific**, exactly as rows 3–7: the suites are
  `test_layer_adr.py`, `test_layer_bdd.py`, `test_layer_brd.py`,
  `test_layer_ears.py`, `test_ears_model.py`, `test_element_id_layer_contract.py`.
- **The saving would be four trivial steps** — checkout, setup-python, pip
  install, run. Set against renaming a required context, the trade is not close.

This is the same class of error the plan withdrew in §2: proposing to collapse
structure whose apparent redundancy is not the thing that matters about it.

H1'. **What the close read DID find: canon rule text propagating by copy-paste.**
`acceptance.yml` and `conformance.yml` carry a **byte-identical ~15-line
concurrency allowlist** implementing CI-0025 / REPO_STANDARDS §23 — the two files
differ only by one comment paragraph. Four `framework` workflows carry it
(Claim 50).

Canon ships that expression inside its own caller templates (`pre-commit`,
`markdown-lint`, `secret-scan` and their `-private` variants), but offers a
consumer **no way to apply §23 to a workflow the consumer writes itself** — and
§23 applies to *any* workflow feeding a required context, not only canon's. So an
adopter authoring one hand-copies an expression subtle enough that
`acceptance.yml`'s own comment records a previous version of the reasoning having
been **wrong** (it argued blanket cancellation was safe, on grounds that were
"true and irrelevant").

**Promote the snippet, not a reusable.** Ship the allowlist as a documented
canonical block under §23 that a consumer can paste into its own workflow, with
the required-context naming warning attached. A reusable is the wrong vehicle
precisely because it would swallow the job name — the thing H1 just failed on.

H1''. **Sizing.** This is a docs + one-template-fragment change, not a workflow
build: C2, not the C3 H1 would have been.

H2. **`pin-currency-reader` (153 lines) is a workaround for a canon defect —
promote the fix, not the workaround.** Issue #351 (OPEN) records that canon's
pin-currency check *is correct* but its verdict is unreachable on any structured
surface, so `framework`'s reader **parses the run log** because that is the only
surface carrying the signal (Claim 43). Canonising a log-scraper would make a
defect permanent. The correct sequence: fix #351 so canon emits a structured
verdict, then the reader collapses to a few lines and *that* is what ships.

H3. **Nothing else is worth promoting.** The remaining framework flow bodies are
domain-specific to the SDD corpus (spec gates, doc lint, plugin manifest
validation) and stay exactly as they are — repo-local workflows. *(An earlier
draft ended this item "…become thin callers of H1's reusable", which re-proposed
the migration H1's withdrawal killed. Corrected in Pass 10.)*

## 6. Non-goals

- **No required status context is renamed or removed.** The tiers are not
  uniform: bootstrap requires only the pre-commit context (Claim 20), while
  product and ops additionally require `call / verify` and `call / gitleaks`
  (Claim 21).
- **Do not run `apply-standards.sh --apply --tier product` on this repo** — it
  PUTs a profile requiring `ai-review` and `composition`, which canon does not
  self-run, and clobbers the deliberate FT-52 canon profile.

## 7. Sequencing

1. **Phase A** — the decision of record; largest removal, and A3's rulebook
   surgery is the only part needing judgement rather than deletion.
2. **Phase B** — `docs-sync` reduction. Sequenced immediately after A because A
   makes it the sole doc flow; shipping A without B leaves the workspace's only
   doc automation at one implemented operation of three, disabled everywhere.
3. **Phase C** — cut `ci/v3.0.0` carrying A and B. A is breaking, so neither
   reaches a consumer without this.
4. **Phase F** — doc consolidation, cheap.
5. **Phase H** — H1 is **withdrawn**; what ships is H1', a documented §23
   snippet, independent and cheap. H2 waits on #351.
6. **Phase D** — decomposition, scoped to two jobs.
7. **Phase E** — last, interface only. Keep `all-files` as the default.

**Phase G is withdrawn** and appears in no step. Its one live successor, G6, is
**PLAN-014 Phase 5** — a founder step owned by that plan, not this one.

**A and B ship together or the release is worse than not cutting it.** They are
one user-visible change: the doc automation the workspace has.

**G1 before G2 is not a preference.** Dropping a CI flow before its hook exists
is a coverage gap; the reverse order is a no-op reshuffle.

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | The -private variants exist because --update otherwise reverts private repos to ubuntu-latest and jobs queue forever | `install.sh --update` unsafe on a private consumer | docs/REPO_STANDARDS.md:273 |
| 2 | The AI-flows dropped their variants as a deliberate exception at ci/v2.2.0 | `the AI-flows dropped their variants for a single protected template` | docs/REPO_STANDARDS.md:269 |
| 3 | The generic reusables already default runner labels to ubuntu-latest | `ubuntu-latest` | .github/workflows/markdown-lint.yml:68 |
| 4 | The rulebook already states canon ships three naming shapes | `canon ships three naming shapes` | docs/REPO_STANDARDS.md:1475 |
| 5 | The manifest records visibility variants per paired flow | `visibility_variants` | install/templates/manifest.json:38 |
| 6 | A canonical pre-commit hook fragment already ships, and the bootstrap installs it | `pre-commit-hook-block.yaml` | install/install.sh:881 |
| 6a | The rulebook names that fragment as canonical | `install/templates/pre-commit-hook-block.yaml` | docs/REPO_STANDARDS.md:1085 |
| 7 | The caller template schedules doc-maintainer twice hourly | `cron: '7,37 * * * *'` | install/templates/workflows/doc-maintainer.yml:56 |
| 8 | The reconciler's lookback window is hardcoded, sized against a cadence set elsewhere | `--lookback-min 90` | .github/workflows/doc-maintainer.yml:191 |
| 22 | The manifest carries the doc-maintainer distribution entries to remove | `.github/workflows/doc-maintainer.yml` | install/templates/manifest.json:61 |
| 23 | The rulebook imposes an adoption requirement that dies with the flow | `Repositories adopting` | docs/REPO_STANDARDS.md:188 |
| 24 | A dedicated LiteLLM model alias exists for it | `ai-doc-maintainer` | docs/REPO_STANDARDS.md:209 |
| 25 | The runner-routing row names it alongside flows that survive | `**AI-flows**` | docs/REPO_STANDARDS.md:245 |
| 26 | §24 is claimed in full by PLAN-021, so its retirement needs that plan updated | `§24 is claimed in full by PLAN-021` | docs/REPO_STANDARDS.md:2276 |
| 27 | The rulebook cites planner.py as the prompt-assembly implementation | `scripts/doc-maintainer/planner.py` | docs/REPO_STANDARDS.md:1884 |
| 28 | test_resolver covers three surviving reusables alongside doc-maintainer | `REUSABLES=` | tests/test_resolver.sh:23 |
| 29 | §20.2 rules 1-7 govern ai-review's prompt files, not doc-maintainer | `Rules 1-7 govern the two prompts this repo ships as files` | docs/REPO_STANDARDS.md:1821 |
| 30 | A MAJOR bump requires a smoke against both aliases, one of which Phase A deletes | `LiteLLM smoke passes (MAJOR bumps only)` | docs/RELEASE_CHECKLIST.md:41 |
| 31 | The smoke workflow defaults to the doc-maintainer alias | `ai-doc-maintainer` | .github/workflows/litellm-smoke.yml:19 |
| 32 | A MAJOR bump requires a published migration guide | `Migration guide published (MAJOR bumps only)` | docs/RELEASE_CHECKLIST.md:44 |
| 33 | The manifest is in the explicit cold-start surface, so removing entries arms FT-30 | `coldstart_surface` | scripts/release.sh:137 |
| 34 | PLAN-021 records the founder-executed FT-30 dry run as already owed | `FT-30 cold-start gate` | plans/PLAN-021_doc-maintainer-dry-run-cluster.md:10 |
| 35 | #404's shadowing shape survives in docs-sync, which becomes the sole doc flow | `mkdir -p .docs-sync-scripts` | .github/workflows/docs-sync.yml:184 |
| 36 | Canon still tells new consumers to adopt the flow being removed | `Superseded by` | docs/WORKFLOWS.md:226 |
| 37 | docs-sync ships dry-run framed as a 1-2 week pilot awaiting graduation | `Start with dry_run: true for first 1-2 weeks` | install/templates/docs-sync.json:4 |
| 38 | sync-version-refs already makes VERSION the sole source for install refs | `the sole source and rewrites only the mechanical install references` | scripts/sync-version-refs.sh:8 |
| 39 | version_sync ships enabled while being detection-only | `alpha.1 stub does detection only` | install/templates/docs-sync.json:17 |
| 40 | cross_ref_repair ships disabled and unimplemented | `full impl ships in alpha.2` | install/templates/docs-sync.json:25 |
| 41 | docs-sync reported green from the day it shipped, its comment step never having run | `reported green from the day it shipped` | .github/workflows/docs-sync.yml:66 |
| 42 | The job name string is the required context; renaming it silently un-satisfies branch protection | `This exact string is the required-status-check context` | ../framework/.github/workflows/acceptance.yml:37 |
| 49 | framework's acceptance workflow became a required context on 2026-07-27 | `it became the 6th required context on 2026-07-27` | ../framework/.github/workflows/acceptance.yml:29 |
| 50 | The CI-0025 concurrency allowlist propagates into consumer workflows by copy-paste | `CI-0025 / REPO_STANDARDS §23` | ../framework/.github/workflows/conformance.yml:15 |
| 51 | markdown-lint is named in the rulebook among the caller templates feeding a required context | `the eight caller templates feeding a` | docs/REPO_STANDARDS.md:2154 |
| 52 | fail-on-findings is a default that the flow honours with exit 1, not an incapacity | `fail-on-findings` | .github/workflows/trivy-scan.yml:27 |
| 53 | PLAN-014 is a founder directive making own scanners MUST-HAVE, with graduation a founder step | `our own scanners are MUST-HAVE` | plans/PLAN-014_security-scanning-coverage.md:5 |
| 43 | framework's pin-currency reader parses the run log for want of a structured verdict | `pin-currency-reader` | ../framework/.github/workflows/pin-currency-reader.yml:1 |
| 44 | The canonical hook block is the surface Phase G extends | `pre-commit-hook-block.yaml` | install/apply-standards.sh:432 |
| 45 | The bootstrap tier's only required context is the pre-commit one, and the four dropped flows appear in no tier | `call / Lint / format / security hooks` | install/templates/branch-protection-bootstrap.json:7 |
| 46 | The hook block's marker version is the refresh key; without a bump the change never reaches an adopted consumer | `the REFRESH KEY` | install/templates/pre-commit-hook-block.yaml:3 |
| 47 | New hook revs must be SHA-pinned because pre-commit executes the upstream build backend at install time | `SHA-pinned, not tag-pinned` | install/templates/pre-commit-hook-block.yaml:47 |
| 48 | A fragment with no commit-stage hook made the required check exit 0 while inspecting nothing | `exited 0 while inspecting nothing` | install/templates/pre-commit-hook-block.yaml:30 |
| 12 | ai-review.yml has three jobs, the middle one carrying the bulk | `autofix:` | .github/workflows/ai-review.yml:1427 |
| 13 | The ai-review job id is what renders the required context | `ai-review` IS the required status context | .github/workflows/ai-review.yml:741 |
| 14 | That job is deliberately the enforcement half and fails closed | `FATAL=1` | .github/workflows/ai-review.yml:741 |
| 15 | The pre-commit reusable always runs against every file | `pre-commit run --all-files --show-diff-on-failure` | .github/workflows/pre-commit.yml:100 |
| 16 | A run-stage input already exists on that reusable | `pre-commit hook stage` | .github/workflows/pre-commit.yml:53 |
| 17 | semgrep covers repos CodeQL cannot | `GitHub Advanced Security and is N/A on private repos` | .github/workflows/sast-scan.yml:5 |
| 18 | CodeQL is unavailable on private repos | `Code scanning (CodeQL)` | docs/REPO_STANDARDS.md:159 |
| 19 | secret-scan scans full commit history | `Full-clone scan (fetch-depth: 0)` | .github/workflows/secret-scan.yml:19 |
| 20 | The bootstrap tier requires only the pre-commit context | `call / Lint / format / security hooks` | install/templates/branch-protection-bootstrap.json:7 |
| 21 | Product tier additionally requires gitleaks | `call / gitleaks` | install/templates/branch-protection-product.json:11 |

## Review log

### Pass 1 - 2026-08-06 - author

Self-review of the first draft. Folded an overstated "live outage" claim;
withdrew a recommendation that three scan flows were redundant with pre-commit
(it rested on a *consumer's* hook config, not canon's); corrected the root cause
after job-level decomposition showed measured wall clock was ~99% queue, not
execution.

**Result:** folded; dispatched independent review.

### Pass 2 - 2026-08-06 - independent

18 findings, 11 load-bearing. Falsified the draft's central premise: it claimed
both doc flows were inert, citing canon *templates*, when the reusable reads the
**consumer's** config at runtime. Author re-verified the three critical findings
against source before folding. Survived into the current scope: the cron's
mechanism (a separate `reconcile` job, not `dry_run`), `enforce_admins: true` on
consumer tiers, and the pre-commit scope input's two implementation constraints.

**Result:** folded; plan then re-scoped to the library only.

### Pass 3 - 2026-08-06 - independent

14 findings, 9 load-bearing. **Invalidated the rewritten plan's three headline
defects.** Author independently verified the three that kill phases before
folding — all confirmed at source:

1. **Phase A would re-open the defect `ci/v2.1.0` fixed.** The pairs are the
   `--update` resolution mechanism, not debt (Claim 1). Phase A **withdrawn**.
2. **Claim 1 of the prior draft did not support its own phase** — the cited
   section routes the generic checks to variants and explains why the split is
   *kept*; the AI-flow collapse is a stated exception (Claim 2). The "proven
   pattern not yet carried over" reading was false.
3. **The naming rule and manifest disambiguation already exist** (Claims 4, 5);
   **the canonical pre-commit fragment already ships** (Claim 6). Both remedies
   **withdrawn**.
4. **The A2 security hazard was inverted** — the reusables already default to
   `ubuntu-latest` (Claim 3), so the warned-of failure has no mechanism.
5. **Phase C's cadence change guts the reconciler** — lookback is hardcoded at
   90 minutes (Claim 11). Became B1/B2: reusable input first, template second.
6. **Phase B's ~600-line target is unreachable** and going further trades gate
   coverage (Claims 12–14). Rescoped to two jobs with an honest resulting size.

Minor findings folded: template count 26→25; the 24 `.github/workflows` files
are not all reusables (7 are canon's own callers/CI); an orphan ledger row
removed; a citation-class slip on the template header.

**Result:** load-bearing findings folded by **withdrawing** the affected phases
rather than repairing them.

### Pass 4 - 2026-08-06 - author (scope correction)

**Not a review pass — a correction of record.** The founder restated that the
decision taken earlier in the session was to **eliminate** `doc-maintainer`. An
intermediate draft had reversed that, inferring from "all flows should be
AI-first" that the AI flow should be graduated and the mechanical one retired
instead. That inference was the author's, not an instruction, and the reversal
was made without asking. Withdrawn.

Consequences folded: elimination is now Phase A; the cron-cadence phase is
obsoleted by it (recorded, not deleted, because the hardcoded-window trap
generalises); the release phase becomes `ci/v3.0.0` because removing a
`workflow_call` reusable is breaking; `docs-sync` becomes the sole doc flow by
default rather than by decision, which A6 flags as needing its own record.

**Result:** decision of record restored; Phase A is new and unreviewed.

### Pass 5 - 2026-08-06 - independent (third and final; OPS-0066 cap reached)

Narrowly scoped to Phase A. **16 findings, 10 load-bearing.** The elimination
decision was out of scope; the removal *plan* was the target. Author verified
the two highest-consequence findings at source before folding.

Folded into A2–A7:

1. **The MAJOR-bump smoke gate is circular** — `RELEASE_CHECKLIST.md:41-43`
   requires a smoke against `ai-doc-maintainer`, the alias A3 deletes.
   `ci/v3.0.0` is untaggable until `litellm-smoke.yml`, both rulebook/checklist
   statements and `test_contract.sh` are edited *inside* Phase A. **Verified.**
2. **#404 must not be closed** — its shadowing shape survives verbatim in
   `docs-sync.yml:184`, the flow that becomes sole. **Verified.** Re-file it.
3. **Blast radius was ~17 surfaces short** — `WORKFLOWS.md` (largest after the
   rulebook), `security.md`, `runners.md`, `litellm-smoke.yml`,
   `set-litellm-secrets.sh`, `EXERCISER_INVENTORY.md`, `actions-permissions.json`,
   the runner `Dockerfile`, `sync/check-drift.sh` and more.
4. **Append-only surfaces needed an explicit carve-out** — `CHANGELOG.md`,
   `DECISIONS.md`, `MIGRATION_v2.0.0.md` are history; "49 files reference it"
   invited an implementer to scrub exactly what this repo forbids editing.
5. **The three test files must be edited, not removed** — all are general suites;
   deletion would drop hundreds of assertions on surviving code.
6. **A3 was backwards.** §20.2 rules 1–7 are `ai-review`'s and need no surgery;
   §24.1–§24.3 are general rules with doc-maintainer as evidence and should be
   kept; only §24.4 collapses. Claim 26 is a number *reservation*, not a note to
   edit — PLAN-021 is In Progress with §24 as its deliverable.
7. **A MAJOR bump owes a migration guide**, and the **🔴 FT-30 cold-start gate is
   already owed** per PLAN-021 — both now named as blockers with owners.
8. **§24.3 loses its only automated reader** — declared in A7 per the workspace
   rule that a change retiring a check must say so.

Corrected counts: 3 manifest entries (not 6 — that was a grep line count);
33 tracked files (not 49 — the earlier count traversed gitignored `tmp/`).

**Result:** all load-bearing findings folded. **The OPS-0066 three-pass cap is
reached**; remaining items go to the human rather than a fourth independent
pass. Phase A is materially larger than first scoped — it is a coordinated
removal with a release-gate circularity and a 🔴 precondition, not a deletion.

### Pass 6 - 2026-08-07 - author (scope addition)

**Not a review pass.** Phase B (`docs-sync` reduction) added at the founder's
direction, and the remaining phases renumbered C–F. Author verified the two
overlap claims the phase turns on, before writing it:

- `scripts/sync-version-refs.sh` propagates `VERSION` into install references
  across 14 targets and runs as a **pre-commit** hook, so it fails before the
  commit lands — strictly better placed than `version_sync`, which would do less
  post-merge. Confirmed at source (Claim 38).
- `links.yml` runs lychee as a **detector**; `cross_ref_repair` would add only
  auto-repair, i.e. a bot write to `main` for a problem already surfaced.
  Confirmed at source.

Also folded: `version_sync` ships `enabled: true` while being detection-only
(Claim 39) — a config asserting a capability that does not exist.

**Phase B is UNREVIEWED.** The OPS-0066 cap was reached at Pass 5, so it is
surfaced to the human rather than triggering a fourth independent pass. Its risk
profile is lower than Phase A's — two deletions of unimplemented code plus a
mode/config change, no required context and no release gate touched — but that
is an author's assessment, not a reviewer's.

**Result:** Phase B folded; plan not ready — Phase B unreviewed by design, and
Phase A carries two open 🔴/decision items for the human (§5 A4).

### Pass 7 - 2026-08-07 - author (scope addition)

**Not a review pass.** Phases G and H added at the founder's direction: eliminate
redundant GitHub jobs in favour of local checks, and survey `framework` for flows
worth promoting to canon.

Evidence gathered before writing them:

- **Gate-firing rates.** Across `framework` (250 runs, 21 flows), canon (200 runs,
  6 flows) and `iplan-runner` (150 runs), essentially **no gate has fired** — 4
  failures total on canon, 0 elsewhere but Dependabot. Sample sizes on
  `framework` are small (6–9 PR runs per flow), so canon's 40-run samples are the
  reliable read. Interpretation: with a mandatory pre-push multi-agent review,
  CI is largely *confirming* a result rather than detecting one, so a flow's
  value is what it catches that local discipline structurally cannot.
- **Three scanners cannot fail.** `sast-scan`, `dep-scan` and `trivy-scan` all
  ship `fail-on-findings: false`, so their zero-failure records carry no
  information. This is what makes G2 a job reduction rather than a coverage cut.
- **The mechanism that makes G safe** — `pre-commit run --all-files` (Claim 15)
  re-runs every hook in CI, so a tool moved into the hook block stays enforced
  by one job instead of four. G1-before-G2 ordering is load-bearing.
- **`framework`'s six own test workflows share one shape** (Claim 42), and canon
  ships no reusable for it — nine hand-rolled equivalents across four repos.
- **`pin-currency-reader` parses run logs** because canon exposes no structured
  verdict (Claim 43, canon issue #351, OPEN). H2 promotes the fix, not the
  workaround.

**Phases G and H are UNREVIEWED** — the OPS-0066 cap was reached at Pass 5.
G5 records the one thing G trades away (bandit ≠ semgrep, pip-audit ≠
osv-scanner) so the trade is visible rather than implied.

**Result:** G and H folded; plan not ready. Three phases (B, G, H) now stand
unreviewed by design, and the human owns whether to spend a further review
budget on them.

### Pass 8 - 2026-08-07 - author (implementation detail)

**Not a review pass.** Phase G written to implementation depth and Phase H's
migration inventory enumerated, at the founder's direction. Reading the target
files surfaced four constraints the phase as previously written would have
violated, and one over-claim:

1. **G0 — safety proof obtained.** None of the four flows G2 drops is a required
   context in any tier (Claim 45). G2 touches no branch protection. This was
   asserted before; it is now verified with the command that re-derives it.
2. **G1a — the marker version is a refresh key.** Editing the hook block without
   bumping `v2`→`v3` means the change **never reaches an already-adopted
   consumer** (Claim 46): `--update` excludes the file and `--apply` writes no
   content. Adopters would keep the three-hook block while canon dropped four CI
   flows — G's exact failure mode, delivered silently. Promoted to a precondition
   of G2.
3. **G1c — `pip-audit` at `manual` stage would break G silently.** The reusable
   runs `--all-files` with no `--hook-stage`, selecting only the `pre-commit`
   stage, and canon's own input docs name `manual` as pip-audit's expected
   placement (Claim 10). Registered there, the hook would never run in CI and
   dropping `dep-scan` would lose the check rather than relocate it. Same shape
   as the PLAN-018 F3 incident where the required check "exited 0 while
   inspecting nothing" (Claim 48).
4. **G1b/G1d — pinning and maintenance.** New revs must be SHA-pinned because
   pre-commit executes the upstream build backend at install time on cold CI
   runners (Claim 47); and the block goes from one third-party rev to four with
   no automated bump path (FT-35). Both now stated as chosen trades.
5. **H1 over-claim corrected.** "Nine hand-rolled workflows across four repos"
   is **seven across three** — canon's `tests.yml` is bash, not Python;
   `framework/plugin` is a JSON validation needing no Python; and `engramory`'s
   `ruff check` is lint that belongs in the hook block per Phase G, not in a test
   reusable. The inventory now lists each candidate with its actual install form,
   which showed the reusable needs to accept editable installs (`-e path[extra]`)
   and not only `-r requirements.txt`.

**Result:** G is implementation-ready; H has a concrete inventory. Both remain
**unreviewed** — the OPS-0066 cap stands, and G1c in particular is the kind of
silent-coverage-loss defect an independent pass exists to catch.

### Pass 9 - 2026-08-07 - founder review + author verification

**Founder finding:** migration rows 3–7 are SDD work belonging to `framework`
alone, and rows 1–2 warranted a closer look. Verified at source, and **H1 is
withdrawn entirely** — there are no migration candidates.

The disqualifier is not domain specificity but branch protection:
`acceptance.yml` states in-file that the job `name:` string **is** the required
status context and that changing it "silently un-satisfies branch protection,
which never fires again" (Claim 42). A reusable renders contexts as
`call / <job name>`, so migrating renames it. Both rows feed required contexts —
`acceptance` became `framework`'s sixth on 2026-07-27 (Claim 49). Rows 1–2 are
also SDD-specific in content (`test_layer_{adr,bdd,brd,ears}.py`,
`test_ears_model.py`, `test_element_id_layer_contract.py`), exactly as 3–7.

**This is the same error class §2 already withdrew** — proposing to collapse
structure whose apparent redundancy is not what matters about it. Third instance
in this plan's history; the pattern is measuring shape and not reading purpose.

**What the close read did find (H1'):** `acceptance.yml` and `conformance.yml`
carry a **byte-identical ~15-line CI-0025/§23 concurrency allowlist**, differing
only by one comment paragraph, and four `framework` workflows carry it
(Claim 50). Canon ships that expression inside its own caller templates but gives
a consumer no way to apply §23 to a workflow the consumer writes — though §23
governs *any* required-context workflow. The expression is subtle enough that
`acceptance.yml`'s comment records a previous version of the reasoning having
been wrong. Promote it as a **documented snippet under §23**, not a reusable —
a reusable is the wrong vehicle for exactly the reason H1 failed.

**Result:** H1 withdrawn; H1' substituted and re-sized to C2. Plan not ready.

### Pass 10 - 2026-08-07 - independent (founder-authorised, full plan)

Full-plan pass, founder-authorised beyond the OPS-0066 cap. **17 findings, 9
load-bearing. Phase G is withdrawn entirely** — it was wrong in premise,
mechanism and authority. Author verified the two decisive findings at source.

1. **G0's safety proof was FALSE.** `call / markdownlint` is a **live required
   context on canon's own `main`** (verified via the protection API). G0 grepped
   only the branch-protection templates — the one surface where a
   live-protection-only context is invisible. `tests/test_contract.sh` even names
   it "the live-protection-only `call / markdownlint`" *because* a
   template-derived map cannot see it. G2 would have pinned every canon PR on an
   unreported required context.
2. **G2 reverses a founder directive.** PLAN-014 (2026-07-18): "our own scanners
   are **MUST-HAVE**", IMPLEMENTED, with a **founder-owned Phase 5** remaining to
   graduate `fail-on-findings`. The scanners are report-only *awaiting the
   founder's flip*, the inverse of G's "cannot fail by design" premise.
3. **"Cannot fail" is a default, not a capability** — both trivy and dep-scan
   `exit 1` when it is true, and dep-scan has a zero-coverage guard no hook
   replicates. G5's own escape hatch is destroyed by G2.
4. **The substitutions do not work**: the hook merge de-dups on repo URL and
   stamps the marker on a *partial* merge (framework already declares bandit,
   pip-audit at `manual`, and markdownlint-cli); `pip-audit` with no args audits
   the runner venv, not the repo; `markdownlint-cli2` ≠ `markdownlint-cli`.
5. **Neither G nor B enumerated a blast radius** — the four flows appear 77 times
   in `test_contract.sh` alone, and deleting the files fails the suite outright.
6. **H3 still referenced the withdrawn H1** — corrected.
7. **Sequencing contradicted itself** on whether G folds into `ci/v3.0.0`; moot
   now that G is withdrawn, and the list is rewritten.

Minor, folded or noted: dangling claim references (the ledger has no rows 9/10/11
— G1c's fact is Claim 16); orphaned ledger rows; Claim 50's count is two
framework-owned files, not four; B3 proposes removing a 50-commits/day cap that
exists only as a header comment; B3's "dry-run permanent" needs the
`.dry_run // false` fallback flipped, since an absent key currently defaults to
**live**; review-log phase letters in Passes 3 and 8 are stale after renumbering.

**Pattern, stated because it is now the plan's defining feature.** Four separate
proposals — the template pairs, the naming rule, the `python-tests.yml` reusable,
and Phase G — were each withdrawn after review found the structure they targeted
was deliberate. Every one was generated by measuring shape (duplication ratio,
line count, job count, run minutes) without reading purpose. **This plan's
durable output is that list of withdrawals, more than its surviving phases.**

**Result:** Phase G withdrawn; H3 and §7 corrected. Plan not ready — Phase B
remains unreviewed in detail, and the minor items above are unfolded.
