# PLAN-023 — build/test canon + conformance model (S1 + X2)

**Owner:** `aidoc-flow-ci` maintainer
**Origin:** founder direction 2026-08-03 — transform this repo into the company
CI/CD standard covering public + private repos, labelling, scanners and security.
A survey of the estate found the *gates* half mature (21 reusables) and the
*delivery* half absent: **no canon reusable builds, tests, packages, versions,
releases or deploys anything.** Decomposed into nine subsystems (S1–S7, X1–X2);
this plan is **S1** (build/test) plus **X2** (the language axis later subsystems
slot into).
**Status:** Draft — **all four Pass-6 items closed. One item was split rather than
closed: §9f.** A best-practices investigation (2026-08-03) changed two premises
(§3c, §3f). All 9 Pass-4 findings are folded; of Pass 6's 10, six were folded
in-pass and four are now closed — two by `DECISIONS.md` **CI-0029** and the
2026-08-03 ruleset probe (§3c, §15), and the last two across Passes 8–10: the F2
self-check extension is **decided as option (a)** and fully specified (§9d), and
the `ruleset-test-gate.json` meta-strip is closed **unconditionally** rather than
waiting on PLAN-020, whose applier is gated on this plan (§9e).

**What is ready and what is not.** PR-0..PR-3 are specified. **PR-4 is half
specified:** the conformance report and the §9d F2 extension are; the ruleset
*arming* mechanism is not — two review passes moved its answer twice, so §9f
carves out its five open questions rather than folding a third time into the
OPS-0066 cap. Nothing in PR-0..PR-3 depends on §9f, and arming is a 🔴 founder
act this plan enables rather than performs.
**Depends on:** [[PLAN-013]] uniform-protected model; [[PLAN-014]] scanner
precedent (opt-in, report-only-first, graduate deliberately).
**Deferred to later plans:** S3 database/service-container gate, S4 release
automation, S5 package publish, S6 container build, S7 deploy, X1 supply-chain
provenance. (**S8 was identified in Pass 2 and dissolved by the 2026-08-03
investigation** — GitHub repo rulesets already provide the mechanism; §3c.)
**Exit:** build/test conformance is (a) defined by a floor that is
language-agnostic and machine-checkable, (b) implementable by canon reusables for
Python and Node, (c) satisfiable by a repo's *own* workflow that emits the same
evidence, and (d) reportable across the fleet by one script. **No consumer repo
is modified by this plan.**

---

## 1. Purpose

**S1 — the capability.** Seven workspace repos are Python and none share a build
definition; every repo that tests its code hand-rolled a workflow outside canon
governance, several pinning actions by floating tag. Four repos independently
invented a `security.yml`; three invented a `plan-gate.yml`.

**X2 — the frame.** Canon has a **tier** taxonomy (Claim 15) and no **language**
axis, so an audit cannot ask *does this repo have a gate for each language it
contains?*, and every later subsystem would invent its own language switch.

The founder constraint shapes the deliverable: **this repo is a library and a
rulebook, not an all-in-one mandate.** Consumers add their own rules and flows.
So the unit of conformance is *evidence*, not *implementation*.

## 1a. AI-first by default (founder direction, 2026-08-03)

Later plans will add AI-based review, AI-based devops and related standards.
**Every rule and flow in this plan must already be AI-friendly**, which is a
design constraint now, not a retrofit later. Concretely, three properties:

1. **Every gate emits machine-readable structured evidence at a declared path**
   — not only human-readable logs. This becomes floor rule **M7** (§3).
2. **Every rule is a machine-checkable predicate.** A rule an agent cannot
   evaluate without human judgment is a SHOULD, never a MUST. This is what
   demotes M3 (§3) and what makes the floor auditable by an agent.
3. **Failure messages are deterministic and greppable** — a stable prefix plus a
   cause, so an agent can route a failure without parsing prose. Canon's
   `::error::<flow>: <cause>` convention already does this; the new reusables
   follow it.

Properties 2 and 3 are free — they are constraints on how rules are *written*.
**M7 is not free**, and an earlier draft wrongly claimed the whole of §1a cost
nothing. M7 owes three concrete artefacts, now budgeted: an evidence **schema**
(PR-1), an `evidence:` **declaration field** so a repo can say where its evidence
lives (§6, PR-4), and **artifact retrieval** in the report (§7, PR-4). Without
all three, M7 is a MUST no auditor can evaluate — which property 2 forbids.

This is what makes the AI-devops subsystems implementable on top rather than
beside.

## 2. Scope — reuse first

Canon covers eleven concerns; this plan **reuses** them:

| Concern | Covered by | Disposition |
| --- | --- | --- |
| Lint · typecheck · format | `pre-commit.yml` (Claims 2, 3) — **but see §2a** | reuse + **extend the canon pre-commit fragment (§2a)** |
| Secrets · SCA · SAST · IaC | `secret-scan` `dep-scan` `sast-scan` `codeql` `trivy-scan` | reuse |
| Markdown · links | `markdown-lint` `links` | reuse |
| AI review · identity · audit trail · drift | `ai-review` `composition` `audit-trail` `standards-drift` | reuse |
| **Package builds and installs** | — | **new** |
| **Test suite + coverage + JUnit evidence** | — | **new** |
| **Language detection / registry** | — | **new (X2)** |
| **Conformance report** | — | **new (§7)** |
| **Declared deviations** | prose only (Claim 12) | **new, small** |

### 2a. The reuse argument only holds if canon ships the hooks

`pre-commit.yml` runs whatever the consumer's `.pre-commit-config.yaml` declares
(Claims 2, 3) — it delivers lint and typecheck **only for a repo that already
configured them**. Measured across the workspace, that repo does not exist:
**no** `.pre-commit-config.yaml` in any workspace repo declares a `mypy` or
`pyright` hook, `ruff` appears in five, and canon's own config declares neither
(Claim 24). The plan's motivating example is the sharpest case — `engramory`'s
config declares exactly one hook (the canon pre-push validator), while its `ruff`
and `mypy` live in the hand-rolled `ci.yml` this plan intends to displace
(cross-repo evidence, §14).

So migrating that repo to canon under a naive "reuse" story would **lose its
typecheck gate**. The fix keeps the reuse shape and makes it true — but the
delivery mechanism is specific, and getting it wrong delivers to nobody:

- **TWO files must change, not one.** The distributed surface is
  `install/templates/pre-commit-hook-block.yaml`, a merge fragment — there is no
  `.pre-commit-config.yaml` template. But canon's **own**
  `.pre-commit-config.yaml` is a hand-maintained Wave-0 copy that instructs
  "keep the marker in step with `install/templates/pre-commit-hook-block.yaml`"
  (Claim 45), and nobody runs bootstrap against canon — so editing only the
  fragment leaves canon's own gate inspecting nothing, and PR-1's "canon passes
  its own new hooks" would be green having checked nothing. PR-1 edits **both**.
- **The marker version MUST be bumped `v2` → `v3` in the same change** (Claim 37).
  Bootstrap re-merges only when a consumer's marker is *lower* than canon's, so
  adding hooks without the bump reaches **zero** already-adopted repos —
  including canon itself. The fragment's own header records this exact
  freeze-forever failure (FT-32).
- **Delivery is bootstrap-only, not `--update`.** `--update` deliberately
  excludes this file because the canon block is merged rather than replaced
  (Claim 38). §8's row says so.
- **The `mypy` hook needs `additional_dependencies`.** A pre-commit hook runs in
  its own isolated venv, so a bare `mypy` hook sees none of the repo's
  dependencies and yields either import errors or `--ignore-missing-imports`
  vacuity — which is *not* the gate engramory has today, where `mypy src` runs
  after `pip install -e ".[dev]"`. The template ships the hook with a documented
  `additional_dependencies` slot and PR-1 states the limitation.

**`ruff` will not reach the five repos that already declare it.** The merge
de-dups by **repo URL**, keeping the consumer's entry and its rev and *reporting*
the collision rather than merging hook lists (Claim 46). §14 records `ruff`
already present in five workspace configs, so for those five canon's pinned
`ruff` lands as a WARN, not a hook. `mypy` — declared nowhere — lands everywhere.
§2a's argument survives on `mypy`, which is the gate engramory would otherwise
lose, but "the fragment ships the hooks" is not true of `ruff` fleet-wide and
§24 must say so.

**Wave-0 cost, budgeted here rather than discovered in PR-1:** canon self-adopts
(Claim 41), and `apply-standards.sh` subset-checks its config against the
fragment (Claim 40). So canon's own ten Python modules must pass `ruff` + `mypy`
under its lint gate, which is a **required** context on canon's `main` per the
FT-52 canon-specific protection profile. That work is part of PR-1, not a
surprise inside it, and may justify splitting PR-1 if the fixes are large —
**measure before writing**. The two new third-party `rev` pins also inherit
FT-35: no dependabot ecosystem covers `pre-commit` revs, so they have no
automated bump path.

## 3. The conformance floor

| # | Rule | Level | Audited by |
| --- | --- | --- | --- |
| **M1** | A repo where a language is **present** (`language_present`, §4 — not merely buildable) runs a build/test gate on every PR, covering lint, typecheck and tests | MUST | gate present; evidence emitted |
| **M2** | The gate emits JUnit XML + coverage as a named artifact, **and the evidence is non-vacuous** (§3a) | MUST | artifact parses; `tests-total > 0`; coverage denominator non-empty |
| **M3** | Dependencies install from a lockfile or fully pinned set | **SHOULD** (§3b) | manifest inspection |
| **M4** | The gate is a required check on `main`, armed via a **repo ruleset** (§3c), **and the required context is the gate job's** (M4a) | MUST | rulesets API — readable without admin (§3c) |
| **M4a** | The required context is an **always-running gate job** that asserts on the reusable's outputs, so no skip can satisfy it (§3f) | MUST | **joint predicate**: required-context set == gate job's context, AND gate is `if: always()` |
| **M5** | Every tool and action version is pinned — no floating tags (Claim 4) | MUST | §3e — audit target differs by mode |
| **M6** | A fork PR never executes on the self-hosted pool; **and where the gate is armed as required, a fork PR never yields a green gate without running** (§3d) | MUST | §3e |
| **M7** | The gate writes structured evidence conforming to the canon schema, at the path the repo declares (§1a, §6) | MUST | schema-validated; `unknown` when unreadable |

**Tier modulates strictness; it never adds a MUST.**

### 3a. M2 is not sufficient on its own — canon already ships the counter-pattern

An earlier draft made M2 ("an artifact exists and parses") the sole conformance
anchor. It is gameable, and canon has already been bitten by exactly this class:
`sast-scan` records that a PR committing `.semgrepignore` containing `*` produced
a silent green and a **complete gate bypass (VERIFIED)**, and its rule is **the
gate — not the scanned PR — decides coverage** (Claim 25). `dep-scan` encodes the
emptiness half: a security gate that scanned **nothing** must not pass silently
(Claim 7 context, `expect-manifests`).

A test gate reads `pytest.ini`, `[tool.pytest.ini_options]`, `.coveragerc` and
`conftest.py` **from the PR**, so a PR can collect zero tests, or exclude every
source file from coverage, and still emit a well-formed `junit.xml`.

**The `sast-scan` remedy does not transfer, and the plan must not pretend it
does.** `.semgrepignore` is pure data and semgrep has usable built-in defaults,
so stripping it is safe. pytest has neither property: `conftest.py` is
**executable test code** whose only disable (`--noconftest`) removes fixtures and
breaks essentially every real suite, and pytest's config lives inside the very
`pyproject.toml` §5b must read for `[build-system]`. Stripping is therefore
impossible in principle here.

M2 instead rests on the half that *is* achievable:

1. **Assert non-vacuity** — `tests-total > 0`, non-empty coverage denominator,
   zero failures. This is what actually closes the bypass.
2. **Override, never strip.** Coverage source is set gate-side via
   `COVERAGE_RCFILE` / explicit `--cov=<pkg>`; collection scope is set gate-side
   via an explicit path argument / `--override-ini testpaths=`. Both *override*
   PR-side configuration at invocation time; neither deletes a PR file, which is
   the thing that cannot be done safely.
3. **Give the escape clause a real mechanism.** The `sast-scan` precedent's
   promise is that an exclusion is expressed *gate-side*; §5's input table
   therefore carries `coverage-omit` and `testpaths`, so "express it gate-side"
   is a mechanism rather than an aspiration.

Non-vacuity (point 1) is what actually closes the bypass; points 2 and 3 exist so
a repo with a legitimate exclusion is not forced into a Mode-2 deviation.

### 3b. M3 is a SHOULD because no repo in the fleet can meet it

There is no lockfile anywhere in the workspace, and the declared constraints are
ranges, not pins (cross-repo evidence, §14). A MUST would paint every repo red on
day one — precisely the "warns forever, a human re-adjudicates every warning"
fatigue §6 exists to end, and per §1a a rule needing per-ecosystem judgment is a
SHOULD. It carries a graduation target and a per-ecosystem definition in §24.

Note the interaction with §5: `python -m build` runs in an isolated environment
that downloads **unpinned** build backends by default. The reusable pins them.

### 3c. M4 is armed by a repo RULESET, not by branch protection

The Pass-2 analysis of the problem stands: required contexts in canon's
protection templates are **tier-static JSON lists** with no language dimension
(Claim 26), so adding `call / test-python` to the product tier arms it on every
product repo — including ones with no Python and therefore no producing workflow,
canon's documented F2 failure where the check never reports and pins every PR on
*"Expected — Waiting for status to be reported"* indefinitely (Claim 27). A
hand-added context is then destroyed at the next `apply-standards.sh --apply`,
which PUTs the whole tier template (Claim 28).

**The conclusion drawn from it was wrong.** Pass 2 concluded a new mechanism
(*"S8"*) had to be built. It does not: **GitHub repo rulesets are a separate,
aggregating surface that canon does not touch at all** — verified, there is not a
single `ruleset` reference in `apply-standards.sh`, `install.sh` or `sync/*.sh`
(Claim 43). A required status check placed in a **repo ruleset** is therefore
structurally immune to the branch-protection PUT, and rulesets aggregate with
branch protection rather than replacing it.

**Availability is measured on the exact shape M4 needs, not inferred.** An
earlier revision rested on two weaker data points — a *tag*-target ruleset on
canon and a **disabled** one on private `aidoc-flow-business` — neither of which
is a branch-target `required_status_checks` rule at active enforcement. A review
pass correctly refused that as evidence.

**Probe run 2026-08-03, founder-authorised, on the private
`aidoc-flow-business`** (§15): a throwaway branch ruleset scoped to
`refs/heads/ruletest/*` — matching no real branch, so inert — carrying one
`required_status_checks` rule at `enforcement: active`, then read back and
deleted. Result: **created, persisted intact, no downgrade.** `enforcement` came
back `active`, the rule and its context survived, and the pre-existing ruleset
was untouched.

Three conclusions, all load-bearing:

- **No plan gating.** M4 is enforceable on private repos on this account, so it
  stays a MUST across all nine rather than reverting to SHOULD on four.
- **CI-0029's bypass shape is valid** — `{actor_id: 5, actor_type:
  RepositoryRole, bypass_mode: always}` was accepted verbatim and read back
  unchanged, so the quality-gate template needs no correction.
- **`Main Rules` at `enforcement: disabled` is a deliberate setting, not a
  ceiling** — an active ruleset succeeded on the same repo. The ambiguity that
  made the earlier evidence unusable is resolved.

What the probe does **not** cover: it never opened a PR against a matching
branch, so it proves the ruleset is *accepted and enforced-as-configured*, not
the end-to-end merge-blocking behaviour. That is exercised for real when PR-4
arms the first repo.

One half **is** settled: the readability question PLAN-020 flagged as open
("does *not* cover `GET /rulesets`, and this plan must not assume it does").
Measured 2026-08-03 — `gh api repos/actions/checkout/rulesets` returns data on a
repo this account does not administer, so `/rulesets` is **not** admin-class
(Claim 48 context, §15). M4 is therefore auditable by the report; §7's
pre-revision sentence naming branch-protection as M4's source is corrected.

**Relationship to PLAN-020 (deferred, not dead).** PLAN-020 Phase 1 / FT-55
already owns ruleset canon — `rulesets-canon.json` plus an opt-in `--rulesets`
drift comparison (Claim 49). That is the **read** side, and PLAN-023 ships none
of it. **Phase 1 ships no applier at all** — the apply path is PLAN-020 **Phase
3**, explicitly conditional on "only if a second repo needs rulesets" (Claim 56).
This plan is that condition, so PR-4 pulls Phase 3 forward under Phase 3's own
constraints rather than inventing a rival: §9e. PR-0 records that split.
FT-55's stated defect transfers with it: a ruleset that is
disabled or deleted is detected by **nothing** today, so M4's MUST would live on
the one server-side surface canon cannot monitor — the price of the
non-clobberability §3c gains, and it is only paid back when `--rulesets` lands.

**So M4 becomes a MUST**, and S8 dissolves — not into new work here, but into an
*existing* deferred plan. What Pass 2 sized as a subsystem is a ruleset template
and an applier that **PLAN-020 Phase 1 already specifies** (see below).

**This does not fix the skipped-check bypass** — see §3f. Rulesets share branch
protection's semantics, where a required check is satisfied by a successful,
**skipped**, or neutral status. The two problems are orthogonal.

### 3f. A required check must not be satisfiable by a skipped job (M4a)

The §3d bypass is not a quirk of this design; it is a **widely-documented
GitHub-wide failure mode**, and it has a named industry fix: an always-running
**gate job** (also "summary job"). The gate `needs:` every real job, runs under
`if: always()` so it can never itself be skipped, and asserts on the collected
results — turning "skipped" into an explicit failure rather than an implicit pass.

The canonical implementation is the `re-actors/alls-green` action, which **§4.3
forbids** (Claim 4). Canon therefore implements the same logic inline in the
caller template, keeping the supply chain inside canon.

**Two specifics, both load-bearing, because getting either wrong makes M4a
decoration:**

1. **The armed context must be the GATE JOB's, not `call / test-python`.** If the
   ruleset requires the reusable call's context, the bypass survives untouched —
   the inner job skips, the call reports skipped, skipped counts as success. A
   gate job that is not itself the required check changes nothing. Hence M4's
   joint predicate. Note the context naming differs by shape: a reusable call
   emits `<job-key> / <name>`, a repo-local job emits a bare name — so the gate's
   context is a bare name, which `required-context-map.py` classifies
   `?non-call` and does not resolve (§9d).
2. **The gate asserts on the reusable's `workflow_call` OUTPUTS, not on
   `needs.*.result`.** Whether a calling job whose inner job skipped resolves to
   `skipped` or `success` is not something this plan should guess — and if it
   resolves to `success`, a result-based gate passes and closes nothing. Asserting
   `tests-total > 0` is unambiguous: an all-skipped call yields empty outputs.
   **PR-2 must therefore promote `tests-total` / `tests-passed` /
   `coverage-percent` from job outputs to declared `workflow_call:` outputs** —
   no canon reusable declares any today. This is the same assertion M2 already
   needs, so it is one mechanism serving both, not two.

This applies to **any** canon flow that is or becomes a required context, not
only the test gate; §24 states it as a general rule so the next required gate
inherits it.

### 3d. M6 — a skipped fork job must not report green

The earlier draft set `fork-strategy: skip`, reasoning from the scanners. That
reasoning does not transfer, for a measured reason: **canon's own `ai-review`
records that a job skipped by `if:` reports green and can supersede a standing
`request_changes`** (Claim 29). No scanner is a required context in any tier
template, so their skip is harmless. A *required* test gate that skips to green
on fork PRs is **a bypass** — open the PR from a fork, and the gate passes having
run nothing.

**Resolution:** `fork-strategy` defaults to **`github-hosted`**, not `skip`. Fork
code never touches the self-hosted pool — the security property the founder asked
for (Claim 30 boundary) — while the gate still reports a real conclusion **once
the run is permitted to start**. That qualifier is load-bearing: on a public repo
the default first-time-contributor setting holds a fork run at
`action_required` until a maintainer approves, and canon records that it cannot
even read those fork-PR toggles via REST (Claim 42). This fails closed, which is
correct, but it is not "always reports".

**The default is visibility-dependent, because `github-hosted` is forbidden on
private repos.** One Class A template serves both visibilities, but this account
has no GitHub-hosted minutes for private repos (OPS-0049) and canon's rule is
absolute — never `ubuntu-latest` on a private repo. So:

| Visibility | Fork PR |
| --- | --- |
| Public | `github-hosted` — runs on `ubuntu-latest`, real conclusion, fork code never on the pool |
| Private | `skip` — a fork PR on a private repo is rare, and the alternative is forbidden |

`skip` therefore remains reachable, and **M6's MUST is scoped to the armed case**
— a skipped *required* check is a bypass; a skipped *optional* check is merely no
signal. With M4 now a MUST (§3c), a private repo that arms the gate **and** skips
forks needs M4a's gate job (§3f) to convert that skip into an explicit failure.
That is the interaction to get right in PR-2.

**Input typing (bites PR-2 otherwise):** `runner_labels` is a JSON-array *string*
consumed by `fromJSON` (Claim 6). `fork-strategy` cannot be both that and an
enum, so it is split — `fork-strategy` is the enum
(`github-hosted` | `skip`), and `fork-runner-labels` carries the labels string
used when the strategy is `github-hosted`.

**This reverses the founder's 2026-08-03 answer on fork strategy and needs
explicit confirmation before PR-2.**

### 3e. What audits M5 and M6 depends on the adoption mode

An earlier draft audited both by "a static scan of the caller". That is wrong:
§5a pins tools inside the **reusable** and §3d routes runners inside the
**reusable**, neither of which a caller scan can see — and a Mode-2 repo has no
reusable at all. The audit target is therefore mode-dependent, and §7's report
states which it used:

| Mode | M5 / M6 / M4a audit target |
| --- | --- |
| Canon call (Mode 1) | the pinned `uses:` ref **plus the caller's own `with:` block and gate job** — canon's contract tests cover the reusable's interior, but `fork-strategy` is a *caller* input, so the only M6 violation possible in Mode 1 is visible nowhere else |
| Full replacement (Mode 2) | the repo's own workflow file, scanned directly |
| Unreadable | reported `unknown`, never passing (§4.2d) |

## 4. Language registry (X2) — `install/templates/languages.json`

Detection is **two-level**, because filename presence answers neither question
correctly. Live counter-examples in both directions: `iplanic/pyproject.toml`
contains only `[tool.ruff]` and `[tool.bandit]` — **no `[project]`, no
`[build-system]`** — so a filename rule calls it a package and `python -m build`
hard-fails on it; and **this repo** ships ten Python modules with no manifest, so
a filename rule reports "no Python" and M1 is vacuously satisfied for canon
itself (cross-repo + local evidence, §14).

```json
{
  "_exclude": ["**/.venv/**", "**/node_modules/**", "**/vendor/**",
               "**/tests/fixtures/**", "linguist-vendored", "linguist-generated"],
  "python": {
    "language_present": { "globs": ["**/*.py"], "min_files": 1 },
    "buildable_package": {
      "file": "pyproject.toml",
      "anchor": "working-directory",
      "requires_any_table": ["build-system", "project"]
    },
    "reusable": "test-python.yml",
    "uniform_protected": true,
    "status": "canon"
  },
  "node": {
    "language_present": { "globs": ["**/*.{js,ts,jsx,tsx}"], "min_files": 1, "requires_manifest": true },
    "buildable_package": {
      "file": "package.json",
      "anchor": "working-directory",
      "requires_false": "private",
      "requires_any_key": ["main", "exports", "files", "scripts.build"]
    },
    "reusable": "test-node.yml",
    "status": "canon"
  },
  "rust": { "language_present": { "globs": ["**/*.rs"] }, "status": "reserved" }
}
```

`language_present` drives M1 coverage; `buildable_package` drives whether the
build step runs. `status: reserved` gives Rust a slot with no unbacked
implementation. Three specifics that a naive reading gets wrong:

- **`anchor` is explicit, and it is `working-directory` — not recursive.**
  `language_present` is recursive; `buildable_package` is not. Without this, the
  `tests/fixtures/` package PR-2 adds (§11) would make **canon itself** report as
  a buildable Python package and flip criterion 1. Anchoring also matches
  `working-directory`'s stated purpose for monorepo subdirectories.
- **Python matches TOML *tables*, not raw strings** (`requires_any_table`), so a
  `[tool.*]`-only file is correctly not-buildable.
- **Node cannot key on `name`/`version`.** They are present in essentially every
  `package.json` — application, private package, workspace root alike — and a raw
  string match additionally hits nested keys inside dependency objects, making
  the predicate true almost always. The real signal is *not* `private: true`
  plus one of `main`/`exports`/`files`/a build script.

**`language_present` is filtered, not a bare glob.** An unfiltered recursive glob
reproduces at the coverage level exactly the false-positive problem two-level
detection was created to solve: measured, the *only* JS in the nine repos is one
agent-config helper in `operations` with no `package.json`, which under a bare
glob would owe a Node gate forever. Three filters, in order of authority:

1. **`_exclude`** — `.venv/`, `node_modules/`, `vendor/`, and `tests/fixtures/`
   (which otherwise makes canon Python-present *via its own test fixture*).
2. **`linguist-vendored` / `linguist-generated` in `.gitattributes`** — the
   GitHub-native mechanism for exactly this, and canon already ships a
   `.gitattributes` baseline (Claim 44) to extend rather than a new file to
   invent. A repo suppresses its own false positive the standard way.
3. **`requires_manifest`** for Node — source files alone do not make a Node repo;
   a `package.json` must exist somewhere. Python deliberately does **not** set
   this, because canon itself is genuinely Python-present with no manifest.

## 5. The two reusables — one contract

**Class A, uniform protected** (Claim 1) — single template, self-hosted on both
visibilities (Claim 6), with the fork routing of §3d.

| Input | Default | Note |
| --- | --- | --- |
| `runner_labels` | `["self-hosted","ci-runner","single-use"]` | Claim 6 |
| `working-directory` | `.` | monorepo subdirectories |
| `runtime-versions` | JSON array | one shared input name across languages; the values are language-specific |
| `coverage-threshold` | `0` | report-only at ship (Claim 7) |
| `fork-strategy` | `github-hosted` | enum: `github-hosted` \| `skip` — §3d, **pending founder confirmation** |
| `fork-runner-labels` | `'"ubuntu-latest"'` | labels string used when `fork-strategy: github-hosted` |
| `coverage-omit` | `''` | gate-side exclusion (§3a) — never PR-side |
| `testpaths` | `''` | gate-side collection scope (§3a) |
| `build-tool-versions` | pinned defaults | M5 (§5a) |

**Deliberately absent: `install-command` / `test-command`.** Canon is
opinionated; a repo needing different commands uses override Mode 2, which now
declares itself (§6).

### 5a. Tool versions are pinned in the reusable, per M5

Canon's uniform precedent is an exact pin — `pre-commit==4.6.0` (Claim 31),
`semgrep==1.170.0` into a venv (Claim 32), a SHA-256-verified binary for
osv-scanner. `test-python.yml` pins `build`, `pytest`, `pytest-cov` and `pip`, or
it ships the floating-tag posture M5 forbids.

### 5b. Build assertion (founder decision 2026-08-03)

Where `buildable_package` holds, the gate builds a wheel with `python -m build`,
installs **that wheel** into a clean virtualenv, and runs the suite against the
*installed* artifact. An editable install resolves from the source tree and hides
the packaging defects that break consumers — missing package data, wrong
`MANIFEST.in`, modules absent from the wheel. It is also the artifact S5 will
publish.

Feasibility is **proven, not assumed**: `sast-scan` already runs `python3 -m venv`
on the pool (Claim 32). The cost is real, though — the runner is `--rm` with no
persisted tool cache (Claim 33), so every `runtime-versions` matrix leg
re-downloads a full CPython via `actions/setup-python`. §11 names this.

### 5c. This is the first canon flow to execute PR code on the pool

PLAN-014 **explicitly declined** in-CI dependency remediation because re-running
an ecosystem resolver (`npm install` lifecycle scripts, `pip`/sdist `setup.py`)
**executes untrusted PR code on the self-hosted runner** (Claim 34).
`test-python.yml` does exactly that for every non-fork PR: pip install, PEP 517
build hooks, then the suite.

This stays inside the documented boundary — the fork routing of §3d means fork
code never reaches the pool — but it is a **deliberate extension** of the
data-only posture the scanners were granted Class A under, and `dep-scan`
justifies fork-guard-only trust on the basis that an author allowlist "adds no
meaningful control **for a read-only scanner**" (Claim 5 context). PR-0's CI-0031
records the extension rather than letting §5 imply the shape is inherited
unchanged.

Outputs: `junit.xml` + coverage artifact (M2), a structured `conformance.json`
(M7), job outputs `tests-total` / `tests-passed` / `coverage-percent`, and a step
summary. **Concurrency uses §23's event allowlist verbatim** (Claims 9, 23) — the
gate is intended to become required, and a cancelled required check is retained
as non-success.

## 6. Extension and declared deviations

`docs/overrides.md` already defines three override modes and is the answer to
"how does a repo add its own rules". **No new mechanism.** The gap is that a
deviation is recorded as *a comment* (Claim 12) — unparseable, so drift warns
forever and an undeclared override is indistinguishable from real drift.

`.github/ci-conformance.yml`:

```yaml
evidence:
  # M7 — where this repo publishes its structured gate evidence, and how.
  - surface: .github/workflows/test-python.yml
    artifact: build-evidence-python      # run artifact name
    path: conformance.json               # path within the artifact
deviations:
  - surface: .github/workflows/test-python.yml
    mode: 2
    why: tests need a live Postgres; canon has no service-container support
    reconciled: 2026-08-03
    floor_met: [M1, M2, M5, M6, M7]
```

**The `evidence:` block is what makes M7 checkable at all.** Without a place to
declare where evidence lives, a repo satisfying the floor with its *own* workflow
— the plan's exit criterion (c) — leaves the report no way to find it, and
"parses as JSON" with no schema is vacuous by §1a rule 2's own standard. So M7
has three owed parts, budgeted in §9: the **schema** (PR-1), this **declaration
field** (PR-4, with the parser), and **artifact retrieval** (PR-4).

**In a separate file, never in the caller body** — `install.sh --update` replaces
whole caller bodies for `safe_to_replace` surfaces, so a declaration in the body
is destroyed by the next adoption; a file outside the manifest is untouched
(Claim 35). The **conformance report** then splits **declared** (informational, with a
staleness check on `reconciled`) from **undeclared** (a finding).

**Scope correction:** an earlier draft promised this split in terms of
`sync/check-drift.sh`'s warnings, but no PR teaches that script to read the file
— so the split would have existed only inside the report while drift warned
forever, exactly as before. Two honest options; this plan takes the first.
**(a)** The benefit belongs to the conformance report alone, and `check-drift.sh`
is unchanged — stated here so nobody expects otherwise. **(b)** Teach
`check-drift.sh` to read the file, which is a change to a script every consumer
runs and deserves its own plan. If (b) is wanted, it is a sixth PR, not a line
item.

**This design is industry-standard, not novel.** OpenSSF's **Allstar** enforces
org-level repo policy with per-repo opt-out declared in a `.allstar/` config
directory — the same shape as `.github/ci-conformance.yml`. Worth noting
alongside it: OpenSSF's guidance is to run policy **opt-out rather than opt-in**,
which is the reverse of this plan's (and PLAN-014's) opt-in default. That is a
deliberate difference — canon has no org-level enforcement point today (§15) —
and PR-0 records it as a choice rather than leaving it as an unexamined
divergence from the reference practice.

## 7. Audit surface — `install/conformance-report.sh`

**It is its own implementation, not an extension of either drift script.**
`sync/check-standards-drift.sh` is a server-side *settings* checker whose CI-0018
accounting records the blocker directly: under the default `GITHUB_TOKEN`,
**branch-protection and `actions.*` are unreadable**, yet the job concluded
success (Claim 36). **M4's audit source is the rulesets API, not branch
protection** — measured readable without admin (§3c, §15), so the M4 row needs no
PAT. The report must still **state its own coverage** per §4.2d — a check states
its coverage, and unreadable is never reported as passing — but for the rows that
read settings, not for M4. The
file-level `sync/check-drift.sh` is equally unsuitable: its coverage is the
manifest's workflow surface at the caller's pin, so a repo that never adopted
canon — the motivating case — is structurally invisible to it.

Per repo: detect languages (§4) → required gates → floor rows with an explicit
`unknown` state for anything unreadable → declared deviations and their age →
undeclared drift. Emits **JSON** (§1a) and a markdown table; `--fleet` produces
one board.

**M2 and M7 are audited against run artifacts, which are not repo files.** The
report therefore needs a retrieval step the earlier draft never budgeted:
resolve the latest successful run for the surface, `gh run download` the artifact
named in the repo's `evidence:` block (§6), and validate `conformance.json`
against the canon schema. Retention expiry, a missing artifact and a missing
declaration are each **`unknown`**, never a pass. PR-4 owns this.

### 7a. How the report reads other repos — mechanism and token

The earlier draft assumed cross-repo reading without naming either. Both are
prerequisites, and one is 🔴.

- **Mechanism: the API, not a checkout.** The only file-content precedent,
  `sync/check-drift.sh`, is documented to run *in the consumer repo root* against
  a local checkout — which the ephemeral `--rm` runner does not have (Claim 33).
  The report uses the git-trees / contents API for detection and `gh run
  download` for evidence, so it needs no checkout of any sibling.
- **Token: canon ships no cross-repo credential today.** Every workflow secret is
  `GITHUB_TOKEN` except `AI_REVIEW_TOKEN`. Reading eight siblings' trees and run
  artifacts needs a PAT or App with `contents:read` and `actions:read`; the
  settings rows additionally need `administration:read`. **The rulesets read —
  and therefore the M4 row — needs neither** (§7, §15). Scope the credential per
  row rather than to the union: it is a **🔴 founder prerequisite**, not a coding
  task, and the same problem Allstar solves by being a GitHub App.

**Therefore v1 ships single-repo and `--fleet` is gated on that credential.** The
CI caller (PR-4) runs the report against **canon itself**, which needs no extra
token. `--fleet` is implemented but unwired until the credential exists, and the
report states `unknown` for every row it could not read rather than passing.

**It MUST be wired to a caller in PR-4.** `governance_check` is the standing
counter-example — defined (Claim 10), called once (Claim 11), reachable by no
workflow, which is how a false governance table survived for weeks (#355).

## 8. Library and installer integration

| Surface | Change |
| --- | --- |
| `install/templates/manifest.json` | 2 entries, no `visibility_variants` (Class A), `auto_install: false` (Claim 13) |
| `install/templates/pre-commit-hook-block.yaml` | **§2a** — add pinned `ruff` + `mypy` hooks **and bump the marker `v2` → `v3`** (Claim 37). Delivered by **bootstrap only**; `--update` excludes this file by design (Claim 38) |
| `install/deploy-ci-wizard.sh` | `ALL_WF` (Claim 14) gains `test-python:1 test-node:1` — phase **1**, alongside `pre-commit`, since the gate needs the repo's own dependencies; phase 2 is the *content* checks and 3 the scanners. **The wizard carries a second, hand-maintained phase list in `plan()` (Claim 39) that must be updated in the same PR**, or it self-contradicts. Opt-in exactly as the PLAN-014 scanners are (Claim 16) |
| `install/required-context-map.py` | the `USES` regex (Claim 18) picks new *callers* up unchanged — **verify in PR-2, do not assume**. Separately, **PR-4 makes three substantive changes** to this file (ruleset glob, bare-context resolution by check name, `?non-call` → `?`): §9d |
| `install/deploy-ci-wizard.sh` (second row — map consumer) | **PR-4** — iterate the map's own column-1 values instead of the branch-protection file list, and delete the `?non-call` arm, or ruleset-armed contexts are silently dropped from check 6 (§9d change 4) |
| `install/apply-standards.sh` | **no change in this plan** — and this is now a decision, not an absence: §9e measured four reasons the ruleset applier does not belong in it |
| `install/templates/ruleset-test-gate.json` | **PR-4** — new template family (singular `ruleset-*`, distinct from PLAN-020's `rulesets-canon.json`); keeps canon's `_comment`, stripped at apply time by the same `jq walk` (§9e) |
| `install/arm-ruleset.sh` | **PR-4, shape UNSPECIFIED — see §9f.** Standalone arming path. Five open questions (template source, safety contract, pre-arm sharing, create-vs-update, credential) must be answered before it is written |
| `install.sh --update` / `--repin` | manifest-driven; `--update` never introduces an unadopted surface (Claim 35) |
| `install/templates/languages.json` | new template, read by the report |

**Migration follows the PLAN-014 precedent verbatim:** opt-in, report-only,
graduate deliberately. No consumer is touched.

## 9. Deliverable shape — 5 PRs

| PR | Content | Gate |
| --- | --- | --- |
| **PR-0** | `DECISIONS.md` CI-0031 — the floor incl. M4a, the declared-deviation rule, the §5c PR-code-on-pool extension, the ruleset arming model (§3c), and the deliberate opt-in-vs-Allstar-opt-out divergence (§6) | decision recorded before code |
| **PR-1** | `REPO_STANDARDS` §24 (floor, per-language rulebook, M3 per-ecosystem definition, M4a as a general rule) **+ §4.1's routing table extended for the third flow shape (§9b)** + `languages.json` + the `conformance.json` **schema** (M7) + the pre-commit fragment hooks and marker bump **and canon's own `.pre-commit-config.yaml`** (§2a) + canon's ruff/mypy clean-up + the `CLAUDE.md:17` correction (§9a) | `tests/run.sh` green; §24 + the `CLAUDE.md` fix asserted by new contract tests (§9a); canon passes its own new hooks |
| **PR-2** | `test-python.yml` + caller template (incl. the M4a gate job) + `self-test-python.yml` + manifest + contract tests + the canon package fixture (§11) | fixture builds, installs, tests green **in canon CI** (§9c) |
| **PR-3** | `test-node.yml` + template + `self-test-node.yml` + manifest + tests | `tests/run.sh` green |
| **PR-4** | Deviation + `evidence:` parsing, artifact retrieval (§7), `conformance-report.sh` **+ its caller (canon-only, §7a)**, `ruleset-test-gate.json`, **the `required-context-map.py` F2 extension + the wizard change it forces (§9d)**, `install/arm-ruleset.sh` (**shape unspecified — §9f gates this half**), §12 rows, `overrides.md` **+ the `REPO_STANDARDS` update its three canon-body changes require** | report runs in CI and states its coverage; criteria 8, 8a + 9 |

**PR-1 is the largest and may need splitting** — canon's ten Python modules
passing new `ruff` + `mypy` hooks under a required context (§2a) is unbounded
until measured. **The `mypy` half is now measured (§9g): 28 errors, of which
four `NoReturn` annotations clear 15. The `ruff` half is still unmeasured and
cannot be measured until PR-1 fixes which configuration the hook pins (§9g).**
Land the clean-up ahead of the hook addition only if the `ruff` half, once
measurable, turns out large — the `mypy` half on its own does not force it.

### 9g. The `mypy` measurement — four annotations clear 15 of 28

Measured 2026-08-15 at `2371444`, mypy 1.19.1. **This answers "measure it first"
in the PR-1 paragraph above for the `mypy` half only** — the `ruff` half is still
unmeasured, and the last subsection below says why that is not a formality.

Measure the way the gate will, in ONE invocation over all ten modules — the
`mypy` hook runs `pre-commit run --all-files`, so per-file runs are a different
measurement (they leave imports unresolved and report `[import-not-found]`
artifacts that the real gate never sees):

```console
$ python3 -m mypy $(git ls-files '*.py')
Found 28 errors in 5 files (checked 10 source files)
```

**Four modules define a `fail()` helper annotated `-> None` that never returns**
— `planner.py:27`, `apply.py:32`, `reconcile.py:41`, `litellm_client.py:42`.
Each raises `SystemExit` (Claim 80), so mypy reads every guarded block as a
fall-through and the narrowed value stays `Any | None`; that one shape produces
the `attr-defined`, `union-attr`, `arg-type`, `return` and `list-item` families.
Annotating all four `NoReturn` takes **28 → 13**:

| | Errors | Where |
| --- | --- | --- |
| Baseline | 28 | 5 modules |
| After 4 × `NoReturn` | 13 | 2 modules |

Each annotation is two edits, not one — the signature plus a `typing` import that
`from __future__ import annotations` does not remove the need for. Those added
import lines are what shift PLAN-021's citations into `planner.py`.

**The residual 13 is a genuinely separate clean-up**, in the two `install/`
modules, neither of which has a `fail()` helper at all:

| Module | Errors | Cause |
| --- | --- | --- |
| `install/parse-governance-table.py` | 7 | `json.load` returns `object`, never narrowed (5 `attr-defined`, 1 `operator`, 1 `index`) |
| `install/required-context-map.py` | 6 | module-level bare `{}` initialisers (5 `var-annotated`, 1 `misc`) |

**Consequence for PR-1's scope.** Size against **28**, not 13: the annotation
pattern is the dominant fix and worth taking first, but it is four annotations
across four modules, and 13 errors in `install/` need individual sites. Whether
that justifies splitting PR-1 is a judgement this measurement informs rather than
settles — it is bounded work now, which is what §9 asked for.

**The `ruff` half is invocation-dependent and remains unmeasured.** This repo
ships **no** `pyproject.toml`, so bare `ruff check` walks up and discovers the
**umbrella's** (`/opt/data/aidoc-flow/pyproject.toml`), which this repo does not
own and whose `select` includes `I`. `planner.py` passes
`ruff check --isolated` and fails bare `ruff check` with `I001` on that config.
**PR-1 must fix which configuration the pinned hook uses before any ruff count
means anything**; today's default-rule result does not predict it.

**Re-derive; the numbers drift.** #401 measured 13 for `planner.py` alone on
2026-08-06 and it is 15 today. The durable claims are the *shape* — one
annotation pattern across four modules, a separate `install/` cluster, and an
unpinned ruff configuration — not the counts. Carried from #401, whose
reproduction target was a `HANDOFF.md` since regenerated away; #393 holds the
re-pin discipline for the ledger citations into `planner.py`.

### 9a. PR-1's gate must test PR-1's content

`parse-governance-table.py` validates the **path cells of `CLAUDE.md`'s
governance table**; neither §24 nor the false claim at `CLAUDE.md:17` is in that
table, so it is green either way. PR-1 therefore adds a contract-test assertion
for §24's presence and for the corrected `CLAUDE.md` line — otherwise PR-1 ships
behind a check that cannot see it, the `ft30-dry-run.sh` failure class named in
`CLAUDE.md`.

PR-1 also closes a live doc defect: `CLAUDE.md` claims this repo ships
"per-language + per-tier rulebooks" (Claim 19). It does not — there is a tier
taxonomy (Claim 15) and no language axis.

### 9c. The self-caller cannot pin a tag that does not exist yet

Every existing `self-*` caller pins the **released** tag by deliberate convention
— canon consumes the same immutable version its consumers do (Claim 47). But
`test-python.yml` exists in no tag until after PR-2 merges and a release is cut,
so a self-caller pinned to any current tag `startup_failure`s and **never
reports** — canon's own FT-21 chicken-and-egg, and those runs are not retryable.

**Resolution, stated so PR-2 is not rediscovered as a red PR:** `self-test-*.yml`
ships in PR-2 with a **local ref** (`uses: ./.github/workflows/test-python.yml`),
which is the only form that can exercise the reusable in the PR that introduces
it. A comment records the departure from the pinned-tag convention and why. At
the next release cut it converts to the pinned form, joining the other four
self-callers. §24 notes the two-stage pattern for the next canon flow that needs
self-adoption from scratch.

### 9d. A ruleset-armed context escapes canon's F2 no-orphan self-check

**This is the plan's principal open item, and it has a section so it is actionable
rather than buried in a review log.**

Canon guards against F2 — a required context with no producing workflow, which
never reports and pins every PR — by enumerating required contexts and asserting
each has a producer. But `required-context-map.py` enumerates **only**
`install/templates/branch-protection-*.json` (Claim 18 context), and
`tests/test_required_contexts.sh` asserts the invariant over that output. A
ruleset template is invisible to both, so arming M4 via §3c moves the required
context to a surface the F2 guard cannot see — reintroducing exactly the failure
§3c was chosen to avoid.

Worse, per §3f the armed context is the **gate job's**, which is a *bare* name
(a reusable call emits `<job-key> / <name>`); the map classifies bare contexts
`?non-call` and deliberately does not resolve them.

**DECIDED 2026-08-03 — option (a), extend the map.** The alternative considered
was (b), a standalone pre-arm check inside the applier: cheaper, but a second
implementation of an invariant canon already implements, which is how two sources
of truth start.

**(a) is also the cheaper option, which the earlier framing had backwards.** The
cost attributed to it was back-compat on the `?non-call` class the map emits
without resolving (Claim 50) and the test passes green (Claim 51) — and that
class has **no live population**. Measured 2026-08-03:
`python3 install/required-context-map.py .` emits 15 rows across the five
branch-protection templates, every one `<jobid> / <name>`, every one resolving to
a producer, and **not one `?non-call`**. So teaching the map to resolve bare
contexts *strictly* changes no current verdict, and the test's green branch is
**removed** rather than kept beside a strict path. §8's "the `USES` regex should pick new callers up unchanged" does
not cover any of this — the work below is real, it is just not the work §9d
previously priced.

**PR-4 makes three changes to `install/required-context-map.py` and one to its
second consumer:**

1. **Enumerate ruleset templates.** Extend the emit loop's glob (Claim 52) to
   `install/templates/ruleset-*.json`, taking contexts from `.rules[] |
   select(.type == "required_status_checks") |
   .parameters.required_status_checks[].context`. Column 1 stops meaning "tier"
   and becomes the source template's stem. The glob deliberately excludes
   PLAN-020's `rulesets-canon.json` (plural) — a tag-immutability ruleset carries
   no `required_status_checks` rule, so the `select()` would yield nothing
   anyway; the naming keeps that intent explicit rather than incidental.
2. **Resolve bare contexts — by check name, not by job key.** A bare context is a
   repo-local caller job, so it resolves through the **same caller templates step
   2 already parses**: the job carrying `steps:` instead of `uses:` whose **`name:`
   — or, absent `name:`, whose key** — equals the context, mapped to a consumer
   basename through the manifest (Claim 54). Step 1 already encodes exactly this
   rule for reusables (Claim 61), and GitHub follows it for repo-local jobs too;
   a key-only match would resolve nothing for any gate job that declares a
   `name:`, turning a correctly-specified gate into a red F2 verdict. Step 2
   today skips every job without a matching `uses:` (Claim 55), which is why the
   gate job is invisible to it at all.
   Build the bare-name map with `setdefault` over the already-`sorted()` glob,
   matching the determinism rule step 1 states for the same hazard one level up
   (Claim 74): two caller templates could each declare a repo-local job of the
   same name, and resolving that by filesystem glob order would silently pick a
   producer basename the target-repo check is then run against.
   **Constraint on PR-2:** the gate job's `name:` must not contain `" / "` — the
   map splits on that separator to decide call-vs-bare (Claim 62), and canon
   already has a required context of that shape (`call / Lint / format / security
   hooks`), so a gate named with a slash would be misclassified as a reusable
   call and mis-resolved.
3. **Fail an unresolved bare context.** `?non-call` becomes `?`, bringing bare
   contexts inside the invariant. This flips nothing today (per the measurement
   above) and covers the gate job from the moment PR-2 introduces it.
   **This deliberately removes a declared class, not just a dead branch:** canon
   loses the ability to declare a legitimately repo-local required context it
   ships no producer for. Four comments encode that intent as *intentional*
   (Claims 50, 51, 64, 65) and are updated in the same PR. The new rule is: canon
   must ship a producer template for **every** required context, bare or not.
4. **Update the wizard, which is the map's other consumer — and the one that
   actually performs the pre-arm check.** `deploy-ci-wizard.sh` derives its
   iteration set from `ls templates/branch-protection-*.json` and filters map rows
   on column 1 equalling that tier (Claim 63). After change 1 a ruleset row's
   column 1 is a ruleset stem, matching no tier, so **every ruleset-armed context
   would be silently dropped** from check 6 — which would then report "all N
   required-context producer(s) installed" having never looked at the ruleset.
   That is precisely the class this section exists to close, reintroduced one
   level up.
   **Iterate the UNION** of the branch-protection stems, the ruleset stems, and
   the map's own column-1 values — *not* the column-1 values alone. The existing
   file-list iteration is deliberate and commented: it exists so `umbrella`, whose
   template declares no required contexts (Claim 75), still gets a "no required
   contexts" line instead of vanishing (Claim 76). Iterating column 1 alone would
   trade the ruleset silent-drop for the umbrella silent-drop — the same defect,
   one tier over. The wizard's `?non-call` arm (Claim 64) is deleted with the
   test's — **already done, ahead of this PR, by #481**, which had to teach the
   same `case` statement the new `!` symbol and could not leave a silently-passing
   arm next to it. PR-4 inherits it done; the union-iteration half is untouched
   and still owed.

**`tests/test_checknames.sh` is deliberately NOT extended.** It is canon's other
context enumerator and is also `branch-protection-*.json`-only (Claim 65), but it
keys on the literal `call /` prefix (trailing space included) and skips everything else (Claim 77) — note
that is narrower than the map's separator test, so it already skips
`drift / check-standards-drift` too. It would therefore ignore this plan's bare
gate context regardless. Recorded so the next session does not re-derive it: if a
future ruleset ever arms a `call / X` context, that guard is blind to it.

**§11's pre-arm check is only half-discharged by this.** The map answers *does
canon ship a producer template for this context* — its inputs are canon's own
tree (Claim 52, Claim 54). §11's risk is a property of the **target** repo: a
ruleset requiring a context whose caller is absent or misnamed *there*. The
wizard already implements both halves — map output for the canon half, the
fetched `have` list for the installed half (Claim 66) — which is why change 4
above is not optional bookkeeping. §11 is discharged by *map output ∧
installed-caller check against the target*, not by the map alone.

### 9e. The meta-strip cannot wait on PLAN-020, and does not need to

Pass 6 left open that `ruleset-test-gate.json` will **422 on `_`-prefixed meta
keys** unless PR-4 inherits `apply_canon_stripped` or ships meta-free, to be
confirmed "once PLAN-020's applier lands".

**That condition can never fire. PLAN-020's applier is its Phase 3, and Phase 3
is gated on "only if a second repo needs rulesets" (Claim 56) — which is this
plan.** Each plan was waiting on the other. The item is therefore closed here,
not deferred again.

**The meta-strip half closes cheaply; the applier does not, and an earlier
revision of this section conflated the two.** The strip is a solved problem and
was never PLAN-020's to ship: `apply_strip_meta` is a `jq walk` dropping every
`_`-prefixed key at any depth (Claim 57), used by `apply_canon_stripped`
(Claim 58) on the path `repo-settings` and `branch-protection` already apply by
(Claim 59). PR-4 reuses that same `jq walk`, so **`ruleset-test-gate.json` keeps
canon's `_comment` convention** and PLAN-020 Phase 1's either/or (meta-free
template *or* a strip in the cited command) is answered *for the mechanism*
rather than dodged.

**The applier is NOT a section inside `apply_run`, and NOT `apply_canon_stripped`.**
PLAN-020 Phase 3 sketched it as `apply_rulesets()` in `apply-standards.sh`; four
facts about that script, each measured, make it the wrong home:

1. **`--apply` mandates `--tier` and runs all four sections unconditionally**
   (Claims 67, 68). Arming a ruleset would therefore also PUT branch protection
   unless the operator remembers `--skip-branch-protection` — which on canon is
   the documented destructive act `CLAUDE.md` § "Durable traps" forbids outright.
   Opt-in on the *flag* does not make the *run* ruleset-only.
2. **`apply_backup` captures labels, repo-settings and `actions.*` — no rulesets**
   (Claim 69). Adding a write section without extending it makes the script's own
   backup/rollback contract false for the one section that is a cross-repo write
   with no read-side detector until PLAN-020 Phase 1 lands (§3c).
3. **`apply_canon_stripped` fetches from `raw.githubusercontent.com` at `CI_TAG`,
   and `--apply` refuses `CI_TAG=main`** (Claims 70, 71). The template would be
   unusable by its own applier until a release is cut — the FT-21 chicken-and-egg
   §9c already documents for self-callers, re-created on the write side.
4. **The pre-arm check needs a canon tree, and this script is designed to run
   curl-piped without one** (§9d, Claim 66). `required-context-map.py` reads
   `.github/workflows/`, `install/templates/workflows/` and the manifest; a
   single-file `curl` cannot supply that.

Reason 3 is the weakest of the four and is stated at its true weight: the script
ships `--allow-main-canon` as a documented override (Claim 78), so the tag
chicken-and-egg is a one-release-cycle inconvenience of the class §9c already
solves with its two-stage convention — not a structural blocker. Reasons 1, 2
and 4 stand on their own.

**What this closes, and what it opens.** The Pass-6 item was the *meta-strip*, and
that is now closed unconditionally. It is not a licence to consider the applier
designed: two review passes have moved this answer twice (`apply_rulesets()` in
`apply-standards.sh` → standalone script), and the second answer has open
questions of its own. **§9f carries them.** PR-0 through PR-3 do not depend on
any of it.

**PLAN-020 Phase 1 still owns the read side** — `rulesets-canon.json` and the
`--rulesets` drift comparison. This plan ships neither. **PLAN-020 Phase 3 must
be amended, not merely superseded in spirit:** its text still prescribes
`apply_rulesets()` in `apply-standards.sh` (Claim 56), so a session reading
PLAN-020 alone would implement the design §9e rejects. PR-0 records the
supersession in `DECISIONS.md` and edits PLAN-020 Phase 3 to point here.

### 9f. OPEN — the arming mechanism's shape is a design task, not an authoring one

**Do not treat this as a fold-able review finding.** It has been folded twice and
changed answer twice; the third fold would hit the OPS-0066 cap on a question
that is genuinely a design decision about a 🔴 cross-repo write path. It is
carved out here so the rest of the plan can proceed: **nothing in PR-0..PR-3
depends on it**, and arming is a founder act that PR-4 enables rather than
performs (§3c, §11).

Whoever specifies `install/arm-ruleset.sh` must answer all of these; each is a
measured gap, not a hypothetical:

1. **Where does the template come from?** "Run from a canon checkout" means the
   payload of a cross-repo write is whatever is in the working tree — mutable,
   possibly uncommitted. That is the exposure `apply-standards.sh` refuses by
   pinning `CI_TAG` and rejecting `main` (Claims 70, 71, 78). Fetch-at-tag with an
   explicit local override is the shape that matches canon's posture.
2. **What is its safety contract?** Moving out of `apply-standards.sh` escapes
   that script's missing ruleset backup — and also discards everything it *does*
   provide and §9e never re-owned: pre-state backup, interactive confirm, the
   `--repo` slug validation guarding a value interpolated into `gh api
   repos/$X/...`, `gh`/`jq`/auth preconditions, non-TTY `--yes`, and a dry-run
   default. A cross-repo write with **no** backup is worse than the section it
   avoided, not better.
3. **How is the pre-arm predicate shared with the wizard?** §9d change 4 puts both
   halves in `deploy-ci-wizard.sh`; if `arm-ruleset.sh` re-implements them, that
   is the third copy — the "two sources of truth" outcome §9d rejected option (b)
   to avoid. A sourceable helper consumed by both is the obvious answer; it needs
   stating, not assuming.
4. **Create-only or create-or-update?** The rulesets API creates by `POST` and
   updates by `PUT .../rulesets/{id}` (§15), so a naive re-run creates a
   **duplicate ruleset**. Converging needs PLAN-020's identity rule — target +
   normalized ref pattern, never `name` (Claim 72) — and inherits its detail-GET
   N+1 (Claim 73). If PR-4 is instead scoped create-only, refusing on an existing
   match must be *implemented*, not documented (see §12 criterion 9).
5. **Who runs it, from where, with what token?** Arming is 🔴. The plan says the
   act is the founder's but not the credential or the host.

Until these are answered, PR-4's arming half is unspecified. The conformance
*report* (§7) — PR-4's other half — is unaffected and needs none of them.

### 9b. §4.1's routing table must learn a third flow shape

§4.1 defines exactly **two** classes and justifies uniform self-hosted for the
AI-flows precisely because *forks never reach a job that executes PR code*
(Claim 1). This plan's gate runs **non-fork PR code on the pool** and routes
forks off it (§5c, §3d) — a third shape that neither row describes. Canon's own
rule is that every canon-body change ships with a `REPO_STANDARDS` update, so
PR-1 extends §4.1's table rather than leaving the routing canon silently
inconsistent with the flow this plan ships.

## 10. Non-goals

- No Rust implementation (registry slot only).
- No service containers or database tests — blocked, deferred to S3 (§11).
- No packaging, publishing, container build or deploy (S4–S7, X1).
- **No rival ruleset DRIFT family and no read-side comparison** — PLAN-020 Phase 1
  owns `rulesets-canon.json` + `--rulesets` (§3c). This plan does ship one
  ruleset *template* (`ruleset-test-gate.json`) and the *apply* path, which is
  PLAN-020 Phase 3 pulled forward because this plan is Phase 3's stated trigger
  (§9e) — one implementation of each surface, not a rival to either.
- **No `lang:*` label family.** CI-0028 rejected `kind:*` on the reasoning that a
  direction of travel is not a class of issue; language is detectable and the
  existing taxonomy (Claim 20) covers it.
- No coverage or lint enforcement at ship — report-only.
- **No consumer rollout.**

## 11. Risks

- **Canon is its own pilot — by construction.** An earlier draft proposed
  validating on "a pilot branch in a real consumer", which contradicts success
  criterion 7 (no sibling file modified) and is a cross-repo write the umbrella
  reserves to the founder. Instead **PR-2 adds a minimal package fixture under
  `tests/fixtures/`** — a real `pyproject.toml` with a `[build-system]`, one
  module, one test — so canon can build, install and test a wheel on its own CI
  without touching any sibling. This also repairs the Wave-0 self-adoption gap
  (Claim 21).
- **Service containers do not work on the private pool.** The ephemeral runner
  attaches no Docker socket (Claim 33), so `services:` blocks are unavailable.
  `iplanic` (24 SQL migrations) and `engramory` both have tests that will want a
  live database. S3 owns this; §24 must state the limitation rather than let
  adopters discover it.
- **Every matrix leg re-downloads its runtime.** No persisted tool cache on a
  `--rm` runner (Claim 33) — this, not only serialisation, is the matrix cost.
- **Serial execution** — one job per supervisor instance.
- **M4 is enforceable in v1 via rulesets (§3c), but arming remains a 🔴 founder
  act.** The mechanism now exists; applying it to a consumer is still a
  cross-repo write this plan does not perform. So conformance is *reported* on
  every repo and *enforced* only where the founder arms it — a deliberate gap,
  not a missing capability.
- **Ruleset arming inherits the F2 failure it was chosen to avoid.** A ruleset
  requiring `call / test-python` on a repo whose caller is absent or misnamed
  pins every PR on *"Waiting for status to be reported"* exactly as the tier
  template would (Claim 27). The applier must therefore verify the producing
  caller exists **before** arming, and PR-4 owns that check — as *map output ∧ an
  installed-caller check against the target repo*, which the wizard already
  implements both halves of (§9d), not a second implementation of either.

## 12. Success criteria (verifiable)

1. `languages.json` two-level detection returns, for each of the eight sibling
   consumers plus canon, the correct `language_present` set **and** `buildable_package` verdict
   — explicitly including `iplanic` as Python-present / not-buildable, **canon as
   Python-present / not-buildable *after* PR-2 adds the fixture** (the `anchor`
   rule, §4), and at least one Node repo that is present / not-buildable.
2. `conformance-report.sh` produces a canon-only table in CI (the wired path, §7a); `--fleet` is exercised against **recorded API fixtures** under `tests/`, since the live fleet run is gated on a 🔴 credential. It
   distinguishes declared from undeclared deviations, and marks every row it
   could not read — including a missing or expired evidence artifact — as
   `unknown` rather than passing.
3. `self-test-python.yml` runs in canon's own CI against the `tests/fixtures/`
   package: wheel built, installed into a clean venv, suite green, `junit.xml` +
   coverage + a schema-valid `conformance.json` retrievable as an artifact.
4. The non-vacuity assertion (§3a) is covered by a **shell unit test** under
   `tests/` that feeds the parser a zero-test JUnit document and expects
   failure. It is deliberately **not** a fixture PR — a PR that fails canon's own
   required gate would be unmergeable, so the negative case is tested at the
   parser, not through the gate.
5. `tests/run.sh` green on every PR; PR-1's §24 assertion fails when §24 is absent.
6. `bash install/deploy-ci-wizard.sh scaffold <repo> <dir>` **without** naming a
   test surface scaffolds neither, and naming one scaffolds it — the opt-in
   property lives on the wizard/bootstrap path, not on `--update`, which never
   introduces an unadopted surface (Claim 35).
7. No file under any sibling repo is modified.
8. **The F2 guard covers a ruleset-armed bare context (§9d).**
   `tests/test_required_contexts.sh` asserts, against a fixture ruleset template,
   that (a) a bare gate context resolves to a **canon-shipped producer template**,
   (b) the same context with that template removed reports `?` and reds the suite
   — the teeth test the existing suite already applies to `call / gitleaks` — and
   (c) a gate job declaring a `name:` different from its key resolves by `name:`.
   "Installed" is not this suite's notion; it is the wizard's (criterion 8a).
   8a. **The wizard does not silently drop rows (§9d change 4).** In
   `tests/test_contract.sh`, where wizard behaviour is already asserted: check 6
   **lists** the ruleset row, *and* still lists `umbrella` as "no required
   contexts". The failure mode on both sides is a *missing* line, not a wrong
   one, so the assertion must be on presence.
9. **`arm-ruleset.sh` refuses to arm a context with no producer (§9f).** A test
   drives it against a fixture where the producing caller is absent and asserts
   it exits non-zero **without issuing the write** — asserted on the *call* via an
   arg-recording `gh` stub, not on the return value, per `CLAUDE.md`'s stub trap.
   This requires the script to route writes through a `GH="${GH:-gh}"`
   indirection, as the wizard already does (Claim 79) — a constraint on §9f, not
   an afterthought. A second run against an already-armed repo either converges
   **or exits non-zero without issuing a POST**; "documented failure" is not a
   passing implementation of this criterion.

## 13. Cross-references

- `docs/REPO_STANDARDS.md` §4.1 (Claim 1), §4.3 (Claim 4), §12 (Claim 8), §23 (Claim 9)
- `plans/PLAN-013_uniform-protected-aiflows.md` — the Class A model
- `plans/PLAN-014_security-scanning-coverage.md` — opt-in + report-only precedent; §5c
- `plans/PLAN-020_canon-self-adoption-and-ruleset-canon.md` — Phase 1 / FT-55 owns
  the **read** side (`rulesets-canon.json` + `--rulesets` drift), which this plan
  ships none of. PR-4 pulls **Phase 3** forward — this plan is Phase 3's stated
  trigger (Claim 56) — and **supersedes its `apply_rulesets()` design** (§9e, §9f);
  PLAN-020 Phase 3's text must be edited to point here. PLAN-020 is DEFERRED, and
  `DECISIONS.md` CI-0029 constrains its WEAKENED-drift rule
- **`REPO_STANDARDS` §24 went to PLAN-021 and §25 to issue #387** — both landed
  while this plan was still unREADY, so **PR-1 takes §26**. The yield this plan
  declared is now called: **every remaining `§24` in this document is a forward
  reference to the section PR-1 will write, and PR-1 must renumber them all to
  §26** — **eleven occurrences across nine lines** (143, 215, 330, 660×2, 737,
  739, 760, 1015, 1052×2), deliberately left in place because renumbering them now
  would drift this plan's Claim-ledger citations for no benefit before PR-1
  exists. **This bullet's own `§24` mentions are NOT among them and must not be
  renumbered** — "§24 went to PLAN-021" stays true. **The line numbers above
  drift whenever anything is inserted above them** — they drifted twice while
  §9g was being written — so re-derive rather than trust them, with a filter
  that keys on content instead of line ranges:
  `grep -n '§24' plans/PLAN-023_*.md | grep -v 'PLAN-021\|forward reference\|remaining\|bullet\|grep -n'`.
  **Run it from the repo root** — from `plans/` the glob matches nothing and
  grep exits 2, which reads as a count of zero. The stable assertion is the
  **count** (11 across 9); the numbers are a convenience. Two known break modes:
  the exclusion terms are ordinary English words, so a future forward reference
  whose line contains one is dropped **silently**, and the previous line-range
  filter had already started excluding a real occurrence after the first drift.
  Check the count, not the list
  **`DECISIONS.md` CI-0031 remains reserved for PR-0** — #387 took **CI-0032**
  rather than disturb the three places this plan already cites CI-0031
- `docs/overrides.md` §5 — the three override modes this plan extends
- `plans/ASSESSMENT_flow-ci-value-and-standard-readiness.md` — why adoption, not
  canon breadth, is the binding constraint

## 14. Cross-repo evidence (verified in sibling checkouts; not gate-resolvable)

The ledger below is deliberately **canon-local** so every row resolves against
one root. These sibling facts were read directly and are load-bearing for §2a,
§3b and §4:

| Fact | Location |
| --- | --- |
| `engramory`'s pre-commit config declares exactly one hook (the canon pre-push validator) | `../engramory/.pre-commit-config.yaml:25-27` |
| …while its `ruff` + `mypy` run in the hand-rolled workflow this plan displaces | `../engramory/.github/workflows/ci.yml:20-23` |
| …which pins actions by floating tag | `../engramory/.github/workflows/ci.yml:12-13` |
| `iplanic/pyproject.toml` has `[tool.ruff]` and no `[project]`/`[build-system]` | `../iplanic/pyproject.toml:1` |
| `iplanic` declares nine range-pinned deps, no lockfile | `../iplanic/requirements.txt:1-9` |
| No workspace `.pre-commit-config.yaml` declares `mypy`/`pyright`; `ruff` in five | grep across `/opt/data/aidoc-flow/*/.pre-commit-config.yaml` |
| No lockfile of any ecosystem exists in the workspace | find across `/opt/data/aidoc-flow` |
| The only JS/TS outside a Node project is one agent-config helper with no `package.json` | `../operations/.claude/workflows/multi-agent-review.js` |

## 15. Live GitHub state (verified 2026-08-03 by API; not gate-resolvable)

The §3c ruleset premise rests on account state, which no file records:

| Fact | Command |
| --- | --- |
| The owner is a **User** account with **no organizations** — so org-level rulesets and custom properties are unavailable | `gh api user --jq .type`; `gh api user/orgs` |
| Custom repository properties are org-only and return **404** here | `gh api repos/vladm3105/aidoc-flow-ci/properties/values` |
| Repo rulesets are live on canon (an active `immutable ci/v*` tag ruleset) | `gh api repos/vladm3105/aidoc-flow-ci/rulesets` |
| Repo rulesets work on a **private** sibling — `aidoc-flow-business` has one (`Main Rules`, `enforcement: disabled`) | `gh api repos/vladm3105/aidoc-flow-business/rulesets` |
| Fleet visibility: 4 private, 5 public | `gh api repos/vladm3105/<repo> --jq .visibility` |
| **A branch ruleset with `required_status_checks` at `enforcement: active` is accepted on a PRIVATE repo** — created id `20305147` on `aidoc-flow-business`, read back unchanged, deleted (2026-08-03) | `gh api -X POST repos/vladm3105/aidoc-flow-business/rulesets --input -` then `GET`, then `DELETE` |
| **`bypass_actors: [{actor_id: 5, actor_type: RepositoryRole, bypass_mode: always}]` accepted verbatim** — validates CI-0029's quality-gate shape | same probe, read-back |
| `Main Rules` on `business` is `enforcement: disabled` **by choice, not by plan ceiling** — an active ruleset succeeded on the same repo | same probe |
| `GET /rulesets` is **not admin-class** — returns data on `actions/checkout`, which this account does not administer | `gh api repos/actions/checkout/rulesets` |
| **The `?non-call` class has no live population** — 15 rows across the five branch-protection templates, every one `<jobid> / <name>`, every one resolving to a producer, none bare (§9d change 3 is a no-op today) | `python3 install/required-context-map.py .` |
| A ruleset is created by `POST /repos/{owner}/{repo}/rulesets` and updated by `PUT .../rulesets/{id}` — there is no path-keyed idempotent write, so a naive re-run duplicates (§9e) | the 2026-08-03 probe row above: `POST` → `GET` → `DELETE` |

**DECIDED 2026-08-03 — `DECISIONS.md` CI-0030.** The migration is approved and
sequenced **before** the CD subsystems (S4–S7), under its own plan; it is
explicitly **not** a dependency of PLAN-023, which ships on the current account.

**Rationale, price, and what it does NOT unlock: `DECISIONS.md` CI-0030.**
Not restated here — `CLAUDE.md` § "Durable traps" forbids keeping a second copy
of a decision, because the copies drift. In particular CI-0030 records that an
org does **not** make `composition.yml` retirable (a GitHub App cannot be an org
team member either), correcting an earlier draft of this section.

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | Runner class is assigned by flow class × visibility; two classes exist | `### 4.1 Runner class by flow-class + visibility (canon)` | docs/REPO_STANDARDS.md:239 |
| 2 | `pre-commit.yml` has a step that runs the repo's hooks | `- name: Run hooks` | .github/workflows/pre-commit.yml:92 |
| 3 | That step runs whatever hooks the consumer's config declares, against all files | `pre-commit run --all-files` | .github/workflows/pre-commit.yml:98 |
| 4 | Canon reusables may `uses:` only `actions/*`, `github/*`, `vladm3105/aidoc-flow-ci/*`; tools install as pinned binaries | `### 4.3 Reusable workflows install tools as BINARIES, never third-party actions` | docs/REPO_STANDARDS.md:439 |
| 5 | A Class A scanner fork-guards by skipping the job for fork PRs | `if: ${{ github.event.pull_request.head.repo.fork != true }}` | .github/workflows/dep-scan.yml:57 |
| 6 | A Class A reusable defaults to the self-hosted single-use pool | `default: '["self-hosted", "ci-runner", "single-use"]'` | .github/workflows/dep-scan.yml:42 |
| 7 | The scanner precedent ships report-only via a `fail-on-findings` toggle | `fail-on-findings:` | .github/workflows/dep-scan.yml:27 |
| 8 | A compliance-evidence table exists mapping each rule to its audit trail | `## 12. Compliance evidence — where each rule's audit-trail lives` | docs/REPO_STANDARDS.md:1028 |
| 9 | Only a code-changing event may cancel an in-flight run of a required gate | `## 23. Only a code-changing event may cancel an in-flight run of a required gate` | docs/REPO_STANDARDS.md:2064 |
| 10 | `governance_check` is defined in the standards applier | `governance_check() {` | install/apply-standards.sh:320 |
| 11 | It has exactly one call site, reachable only by running the script by hand | `governance_check` | install/apply-standards.sh:433 |
| 12 | An intentional deviation is recorded only as a prose comment today | `- **Intentionally keep the divergence** — add a comment in your` | docs/overrides.md:183 |
| 13 | The manifest carries an `auto_install` flag whose false value means optional adoption | `"auto_install=install.sh bootstraps it (false = optional adoption)."` | install/templates/manifest.json:24 |
| 14 | The wizard enumerates installable surfaces in one ordered, phase-numbered list | `ALL_WF=` | install/deploy-ci-wizard.sh:50 |
| 15 | Canon has a tier taxonomy and no language axis | `## 1. Tier taxonomy (6 tiers)` | docs/REPO_STANDARDS.md:56 |
| 16 | The PLAN-014 scanners are wired into the wizard as explicitly opt-in | `3b. dep-scan, trivy-scan, sast-scan   (OPTIONAL own security scanners — PLAN-014;` | install/deploy-ci-wizard.sh:232 |
| 18 | `required-context-map.py` discovers canon callers by regex on the `uses:` path | `USES = re.compile(` | install/required-context-map.py:67 |
| 19 | `CLAUDE.md` claims per-language rulebooks ship in `REPO_STANDARDS.md` | `per-language + per-tier rulebooks` | CLAUDE.md:17 |
| 20 | A canonical label taxonomy already exists | `## 5. Labels — canonical taxonomy` | docs/REPO_STANDARDS.md:723 |
| 21 | This repo's own suite is a shell entrypoint, so it cannot dogfood a packaged-language gate unaided | `run: bash tests/run.sh` | .github/workflows/tests.yml:64 |
| 23 | This repo's own suite already uses the §23 concurrency allowlist shape | `cancel-in-progress: >-` | .github/workflows/tests.yml:22 |
| 24 | Canon's own pre-commit config declares only whitespace/YAML hygiene hooks plus two local hooks — no linter, no typechecker | `- id: check-yaml` | .pre-commit-config.yaml:44 |
| 25 | The gate, not the scanned PR, decides coverage — a PR-supplied ignore file produced a verified silent bypass | `# THE GATE — NOT THE SCANNED PR — DECIDES COVERAGE. semgrep ALWAYS honors a` | .github/workflows/sast-scan.yml:89 |
| 26 | Required status checks are a tier-static list with no language dimension | `"required_status_checks": {` | install/templates/branch-protection-product.json:5 |
| 27 | A required check with no producing workflow never reports and pins every PR | `required check with no producing workflow does not fail; it never reports, so` | docs/REPO_STANDARDS.md:1496 |
| 28 | Applying standards PUTs the whole tier protection template, clobbering hand-added contexts | `apply_branch_protection() {` | install/apply-standards.sh:700 |
| 29 | Canon records that a job skipped by `if:` reports green and can supersede a standing `request_changes` | `unarmed repo has no such gate, so a skipped-job green would SUPERSEDE a prior` | .github/workflows/ai-review.yml:143 |
| 30 | The fork boundary is what scopes the untrusted-code-on-self-hosted concern | `### 4.1 Runner class by flow-class + visibility (canon)` | docs/REPO_STANDARDS.md:239 |
| 31 | Canon's uniform precedent installs a tool at an exact pinned version | `python -m pip install --disable-pip-version-check "pre-commit==${PRE_COMMIT_VERSION}" "${extra_args[@]}"` | .github/workflows/pre-commit.yml:89 |
| 32 | Creating a clean virtualenv on the pool is proven, and used to install a pinned tool | `python3 -m venv "$VENV"` | .github/workflows/sast-scan.yml:86 |
| 33 | The ephemeral runner is `--rm` with no mounts and no Docker socket, so nothing persists between jobs | `# --rm: container removed on exit. No -v mounts, no --privileged, no socket.` | install/templates/runner/run-ephemeral.sh:90 |
| 34 | PLAN-014 declined in-CI remediation because re-running an ecosystem resolver executes untrusted PR code on the pool | `**executes untrusted PR code on the self-hosted runner**, breaking §1a's data-only` | plans/PLAN-014_security-scanning-coverage.md:186 |
| 35 | `--update` replaces whole caller bodies for `safe_to_replace` surfaces and never introduces an unadopted one | `# --update never introduces surfaces the consumer didn't opt into).` | install/install.sh:519 |
| 36 | Under the default `GITHUB_TOKEN` branch-protection is unreadable, yet the job concluded success | `# branch-protection and actions.* are unreadable and repo-settings comes back` | sync/check-standards-drift.sh:61 |
| 37 | The pre-commit surface is a merge fragment whose marker version is the refresh key; a change that does not bump it never reaches an adopted repo | `# CANON: aidoc-flow-ci pre_push_check v2 (idempotency marker per PLAN-002 §5.2)` | install/templates/pre-commit-hook-block.yaml:1 |
| 38 | Bootstrap no-ops when the consumer's marker is at or above canon's | `echo "  preserve  .pre-commit-config.yaml (canon marker v${_cmv} >= canon v${CANON_MARK_V} — no-op)"` | install/install.sh:910 |
| 39 | The wizard carries a second, hand-maintained phase list in its plan output | `Deploy in dependency order (one PR per workflow or batch the content-checks):` | install/deploy-ci-wizard.sh:228 |
| 40 | The standards applier subset-checks a consumer's pre-commit config against the canon fragment | `subset_check      ".pre-commit-config.yaml"             "pre-commit-hook-block.yaml"` | install/apply-standards.sh:432 |
| 41 | Canon self-adopts its own surfaces through dedicated `self-*` callers, because the in-repo file IS the reusable and needs a caller | `# self-pre-commit.yml — canon dogfoods the pre-commit gate it ships (PLAN-018 FT-36).` | .github/workflows/self-pre-commit.yml:1 |
| 42 | GitHub does not expose the fork-PR toggles via REST, so canon cannot verify them | `echo "    fork-PR toggles: SECURITY WARNING — GitHub does not expose these via REST."` | install/apply-standards.sh:694 |
| 43 | The installers never touch rulesets, so a ruleset is a surface no canon apply can clobber | `apply_branch_protection() {` | install/apply-standards.sh:700 |
| 44 | Canon already ships a `.gitattributes` baseline to carry linguist overrides | `### 10.2` | docs/REPO_STANDARDS.md:985 |
| 45 | Canon's own pre-commit config is a hand-maintained Wave-0 copy whose marker must be kept in step with the fragment | `# Keep the marker in step with install/templates/pre-commit-hook-block.yaml.` | .pre-commit-config.yaml:30 |
| 46 | The pre-commit merge de-dups by repo URL, keeping the consumer's rev and reporting the collision rather than merging hook lists | `# De-dup by repo URL, NOT whole-entry structural equality (PLAN-018 F3). Canon` | install/install.sh:988 |
| 47 | Self-callers pin the released tag by deliberate convention, so canon consumes what its consumers do | `# self-pre-commit.yml — canon dogfoods the pre-commit gate it ships (PLAN-018 FT-36).` | .github/workflows/self-pre-commit.yml:1 |
| 48 | Whether `GET /rulesets` is admin-class was an explicitly open question this plan must not assume — now measured (§15) | `### FT-55 — the immutable` | plans/FRAMEWORK-TODO.md:206 |
| 49 | No canon machinery knows rulesets exist, and PLAN-020 Phase 1 already owns the fix | `Branch protection is drift-checked; the ruleset protecting the tags the fleet pins` | plans/FRAMEWORK-TODO.md:216 |
| 50 | The map emits a bare context as `?non-call` without attempting to resolve it | `print("%s\t%s\t?non-call" % (tier, ctx))` | install/required-context-map.py:112 |
| 51 | The test treats `?non-call` as a PASS, so a bare context can never trip the F2 invariant | `'?non-call') _g` | tests/test_required_contexts.sh:43 |
| 52 | The emit loop enumerates branch-protection templates only | `install/templates/branch-protection-*.json` | install/required-context-map.py:106 |
| 53 | The test keys its producer assertions on the context column, not column 1 | `producer_for()` | tests/test_required_contexts.sh:58 |
| 54 | Template basename → consumer path basename is derived from the manifest | `tmpl_to_consumer = {}` | install/required-context-map.py:89 |
| 55 | Step 2 skips every caller-template job without a matching `uses:`, so a repo-local gate job is invisible to it | `if not m:` | install/required-context-map.py:77 |
| 56 | PLAN-020's apply path is its Phase 3, conditional on a second repo needing rulesets | `### Phase 3 — optional apply path` | plans/PLAN-020_canon-self-adoption-and-ruleset-canon.md:216 |
| 57 | A `jq walk` strip that drops every `_`-prefixed key at any depth already exists in canon | `apply_strip_meta() {` | install/apply-standards.sh:556 |
| 58 | A helper fetches a canon template through that strip, returning a tmpfile | `apply_canon_stripped() {` | install/apply-standards.sh:562 |
| 59 | The repo-settings apply path already routes its payload through it | `payload=$(apply_canon_stripped "repo-settings.json")` | install/apply-standards.sh:633 |
| 60 | The per-section apply convention is default-ON `--skip-*`, i.e. a new section applies unless opted out | `--skip-branch-protection) SKIP_BRANCH_PROTECTION=1; shift ;;` | install/apply-standards.sh:126 |
| 61 | The map resolves a job's check name as `name:` if declared, else the job key | `nm = jb.get("name", jk) if isinstance(jb, dict) else jk` | install/required-context-map.py:57 |
| 62 | The map decides call-vs-bare by splitting the context on `" / "` | `if " / " not in ctx:` | install/required-context-map.py:110 |
| 63 | The wizard filters map rows on column 1 equalling a branch-protection tier, so a non-tier column-1 value is dropped | `done < <(printf '%s\n' "$mapout" \| awk -F'\t' -v tt="$t" '$1==tt{print $2"\t"$3}')` | install/deploy-ci-wizard.sh:211 |
| 64 | The wizard's `?non-call` pass arm — the second copy of the token §9d removes — is GONE, removed ahead of PR-4 by #481; the label now reports as the defect it signals rather than passing | `'?'\|'?non-call') missing="$missing\n       · $ctx → canon ships NO producer — canon defect" ;;` | install/deploy-ci-wizard.sh:210 |
| 65 | Canon's other context enumerator is also branch-protection-only | `for tpl in install/templates/branch-protection-*.json; do` | tests/test_checknames.sh:32 |
| 66 | The wizard checks the *target* repo's installed callers, the half the map cannot supply | `local have; have="$($GH api "repos/$repo/contents/.github/workflows?ref=$defbr"` | install/deploy-ci-wizard.sh:156 |
| 67 | `--apply` exits 2 without `--tier`, so no apply run is section-scoped | `"") echo "apply-standards: --apply requires --tier <governance\|product\|ops\|umbrella\|bootstrap>" >&2; exit 2 ;;` | install/apply-standards.sh:151 |
| 68 | `apply_run` calls all four write sections unconditionally | `apply_labels` | install/apply-standards.sh:805 |
| 69 | The backup captures labels, repo-settings, four `actions.*` endpoints and branch-protection — and no rulesets. PLAN-028 B2 made `branch_protection` a MAP KEYED BY BRANCH; the set of endpoints captured is unchanged | `printf '  "branch_protection": {'` | install/apply-standards.sh:1052 |
| 74 | Step 1 resolves a duplicate job name deterministically by sorted filename, not glob order | `name_to_reusable.setdefault(nm, base)` | install/required-context-map.py:58 |
| 75 | The umbrella tier declares no required status checks, so the map emits zero rows for it | `"required_status_checks": null` | install/templates/branch-protection-umbrella.json:4 |
| 76 | The wizard iterates template FILES, not emitted rows, specifically so a zero-context tier still reports | `# List tiers from the template FILES (not only tiers the map emitted rows` | install/deploy-ci-wizard.sh:197 |
| 77 | `test_checknames.sh` keys on the literal `call /` prefix (trailing space included) and skips every other context | `"call / "*) job="${ctx#call / }" ;;` | tests/test_checknames.sh:40 |
| 78 | `--apply` ships a documented override for the mutable-canon refusal | `--allow-main-canon)       ALLOW_MAIN_CANON=1; shift ;;` | install/apply-standards.sh:127 |
| 79 | Canon's precedent for a test-overridable write path is a `GH` indirection | `GH="${GH:-gh}"` | install/deploy-ci-wizard.sh:44 |
| 70 | Templates are fetched from `raw.githubusercontent.com` at `CI_TAG`, so an unreleased template is unreachable | `TEMPLATE_BASE="https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${CI_TAG}/install/templates"` | install/apply-standards.sh:208 |
| 71 | `--apply` refuses `CI_TAG=main` without an explicit override | `apply-standards: --apply refuses CI_TAG=main (mutable canon = supply-chain risk)` | install/apply-standards.sh:204 |
| 72 | PLAN-020 fixes ruleset identity as target + normalized ref pattern, never the name | `Names are free text and mutable` | plans/PLAN-020_canon-self-adoption-and-ruleset-canon.md:129 |
| 73 | Rules and conditions come only from a per-ruleset detail GET, so identity matching is an N+1 | `**Fetch shape.** The list endpoint returns only` | plans/PLAN-020_canon-self-adoption-and-ruleset-canon.md:135 |
| 80 | `planner.py`'s `fail()` terminates unconditionally, so `NoReturn` is the correct annotation and the current `-> None` is what makes mypy read each guarded block as a fall-through (§9g). Pinned on the `raise`, NOT on the signature line — PR-1 rewrites the signature, which would take a signature pin to a `symbol not found` hard FAIL that `--fix` cannot repair | `raise SystemExit(1)` | scripts/doc-maintainer/planner.py:29 |

## Review log

### Pass 5 - 2026-08-03 - self (Passes 1-5 condensed)

Superseded by the body: every finding below is either folded into the section
named, or closed in Pass 6. Git holds the full narrative (commits on
`docs/plan-023-build-test-canon`); it is not restated here, per the repo's
own rule that prose volume is a defect surface.

- **Pass 1 - self (4).** Withdrew a false security-drift claim — a `grep` had
  matched *commented-out* examples, REPO_STANDARDS §22's failure mode aimed at a
  reader. Cut scope from `build-*` to `test-*` once `pre-commit.yml` was found to
  cover lint/typecheck (§2). Reassigned the runner class from a new Class B split
  to Class A (§5). Reframed an absence-shaped claim that could not resolve to
  `path:line`.
- **Pass 2 - independent (8+7).** M4 unimplementable via tier-static branch
  protection (§3c). `fork-strategy: skip` on a required check is a **bypass**
  (§3d). M2 gameable → non-vacuity (§3a). The reuse argument false fleet-wide —
  no repo declares a `mypy` hook (§2a).
- **Pass 3 - independent (9).** *Every finding a defect introduced by the Pass-2
  fold*, including a fix that edited a file which does not exist (§2a's merge
  fragment). Also: pytest config cannot be stripped (§3a); no `self-*` producer
  (§9c); M7 unbudgeted (§1a).
- **Pass 4 - independent (9).** Same pattern again on the Pass-3 folds. Triggered
  the OPS-0066 circuit-breaker: escalated rather than folding a fourth time.
- **Pass 5 - self.** Post-investigation revision. Two premises changed — S8
  dissolved into repo rulesets (§3c), M4a added for the skipped-check bypass
  (§3f) — plus all 9 Pass-4 items folded.

### Pass 6 - 2026-08-03 - independent

Ten findings against the revision. Confirmed sound and closed: §9c's local-ref
self-caller (the contract test already allowlists `./*`, and `sync-version-refs`
rewrites only the `@ci/v*` shape, so the emitted context is unchanged by the
two-stage convert); §4's linguist filter is safe from `--update` because
`.gitattributes` is a subset check; Claims 24, 40, 45, 46.

**Folded:**

1. **§3c over-read its own evidence.** The two live rulesets are a *tag*-target
   one on canon and a **disabled** one on private `business` — neither is a
   branch-target `required_status_checks` rule at active enforcement, which is
   what M4 needs on four private repos. §3c now says so and PR-4 opens with the
   throwaway-ruleset test (🔴, founder-run).
2. **M4a closed nothing as written** — M4 armed `call / test-python` while the
   gate job was a *different* context, so the skip bypass survived. M4 and M4a
   are now a **joint predicate**: the required context must *be* the gate job's.
3. **The gate's assertion mechanism was underspecified** for the case it exists to
   cover. It now asserts on the reusable's `workflow_call` **outputs**, not
   `needs.*.result` — and PR-2 must promote `tests-total` et al. to declared
   workflow outputs, which no canon reusable does today.
4. **M4's readability was an open question — now measured and closed favourably.**
   PLAN-020 recorded that `GET /rulesets` might be admin-class and must not be
   assumed. Measured: it returns data on a repo this account does not administer,
   so the report can audit M4 (Claim 48). §7's pre-revision branch-protection
   sentence corrected.
5. **PR-4 was duplicating a deferred plan.** PLAN-020 Phase 1 / FT-55 already owns
   `rulesets-canon.json` + `--rulesets` drift (Claim 49). PR-4 now extends it
   rather than shipping a rival template family, and FT-55's defect is recorded
   as the price of §3c's non-clobberability: a disabled or deleted ruleset is
   detected by nothing until `--rulesets` lands.
6. Orphans folded: §8 and §10's post-dissolution S8 references; criteria 1–2
   rescoped so nothing in PR-0..PR-4 depends on the 🔴 credential.

**Open — carried to the next revision, NOT folded:**

- ~~**`bypass_actors` unspecified**~~ — **CLOSED 2026-08-03 by `DECISIONS.md`
  CI-0029**: scoped by threat model, not precedent. Immutability rulesets keep
  *no* bypass (FT-52 stands); quality-gate rulesets carry the admin role, holding
  parity with `enforce_admins: false` so arming M4 changes what is required
  without changing who can break glass. CI-0029 also constrains PLAN-020's
  WEAKENED-drift rule to distinguish the two classes.
- ~~**§3c's private-repo premise was asserted beyond its evidence**~~ —
  **CLOSED 2026-08-03 by the ruleset probe** (§3c, §15): a branch ruleset with
  `required_status_checks` at `enforcement: active` was created on private
  `aidoc-flow-business`, read back unchanged and deleted. No plan gating; M4
  stays a MUST on all nine. The probe also validated CI-0029's `bypass_actors`
  shape and resolved the `Main Rules`-is-disabled ambiguity.
- ~~**`ruleset-test-gate.json` will 422 on `_`-prefixed meta keys**~~ —
  **CLOSED 2026-08-03 (Pass 8, §9e).** The deferral condition was circular:
  PLAN-020's applier is its Phase 3, itself gated on a second repo needing
  rulesets (Claim 56) — this plan. Closed unconditionally instead, by routing
  PR-4's `apply_rulesets()` through the strip canon already ships (Claims 57–59).
- ~~**A ruleset-armed context escapes canon's F2 self-check.**~~ —
  **CLOSED 2026-08-03 (Pass 8, §9d).** Decided as option (a), extend the map, and
  specified as three changes. Measurement reversed the cost argument: the
  `?non-call` class has no live population, so strict bare-context resolution is
  a no-op today rather than a back-compat burden.

**Pass 7 addendum — 2026-08-03, independent (OPS-0065 governance-docs class).**
`code-reviewer` + `documentation-specialist` reviewed the CI-0029/CI-0030/CHANGELOG
diff, which had had no review. Both returned REVISIONS-NEEDED. Folded: a **false
claim** that an org makes `composition.yml` retirable (Apps cannot be org team
members either — corrected in all three files); **CI-0021 cited backwards** (its
title is "…**not** `--admin`"; the tension is now stated rather than inverted);
`enforce_admins: false` is **not** fleet-wide (4 of 5 templates set `true`, so
the ruleset bypass is inert there); the ASSESSMENT's 🔴s recast as structural-half
rather than account-caused; CI-0031 forward-reference reserved CI-0028-style; the
64-file count now carries its command; §15's duplicate of CI-0030 cut to a
pointer; open-item counts reconciled across three places; §9d written; Review log
Passes 1-5 condensed (1148 → 985 lines). Deferred as low: foreign-section
prefixing (`RS §12`), §3f/§9c ordering, Claim-ledger numbering gaps.

**Result (as of this pass):** NOT READY — six folded, four open. All four have
since been closed (see the strikethroughs above). Later closures are dated inline
rather than by rewriting this result.

### Pass 8 - 2026-08-03 - self (closing the two carried items)

No new review of the plan's body — this pass exists to close Pass 6's two
remaining open items, both authoring work rather than decisions the founder owed.

- **§9d — decided (a), extend `required-context-map.py`.** Specified as three
  changes (ruleset glob, bare-context resolution through the caller templates
  step 2 already parses, `?non-call` → `?`). Reading the source to specify it
  reversed §9d's own cost argument: the `?non-call` class it treated as a
  back-compat burden has **no live population** — 15 rows emitted, none bare —
  so strict resolution is a no-op today. §11's pre-arm check becomes a call to
  this map, which is what kept it from being option (b) by default.
- **§9e — closed the meta-strip unconditionally.** The item was waiting on
  PLAN-020's applier; that applier is PLAN-020 **Phase 3**, gated on "only if a
  second repo needs rulesets" — this plan. Each was waiting on the other. Closed
  by routing PR-4's `apply_rulesets()` through the existing `apply_canon_stripped`
  (Claims 57–59), which is not PLAN-020's to ship and exists today.
- **Two inaccuracies corrected while closing them.** §3c and §10 both said
  PLAN-020 Phase 1 owns "the template family **and applier**"; Phase 1 owns the
  read side only. Both now name Phase 3 explicitly for the write side.

Eleven claims added (50–60), all cited to symbols read in this pass.

**Result:** the two carried items are closed and the body is self-consistent, but
this pass is **self**, not independent — so the plan is **not yet ready**. One
independent pass over the §3c/§9d/§9e/§10/§11 diff is the remaining gate.

### Pass 9 - 2026-08-03 - independent

Nine load-bearing findings **against Pass 8's fold**, plus four minor — the
repo's documented pattern (`CLAUDE.md` § "Durable traps": folding a review
finding is a code change and needs the same scrutiny) holding for the fourth
time on this plan. Every finding was re-verified against source before folding.

**The one that changes the answer: §9e's applier had the wrong home.** Pass 8
put `apply_rulesets()` in `apply-standards.sh` and priced it as "cheap, the strip
already exists". Three independent findings converged on that being wrong, and a
fourth made it unworkable: `--apply` mandates `--tier` and runs all four write
sections unconditionally (Claims 67, 68), so arming a ruleset would drag a
branch-protection PUT along — on canon, the destructive act `CLAUDE.md` forbids
outright; `apply_backup` captures no rulesets (Claim 69); templates are fetched
from a **released tag** (Claims 70, 71), so the template would be unusable by its
own applier until a release is cut; and the §9d pre-arm check needs a whole canon
tree, which a curl-piped script cannot supply. §9e now ships standalone
`install/arm-ruleset.sh`, template-parameterised so PLAN-020 Phase 1 can cite it.

**Folded, the rest:**

1. **The wizard is the map's second consumer, and Pass 8 broke it.** §9d change 1
   makes column 1 a ruleset stem; the wizard filters rows on column 1 equalling a
   branch-protection tier (Claim 63), so every ruleset-armed context would be
   dropped from check 6 while it reported "all producers installed" — the exact
   silent-drop class this section exists to close. Pass 8's claim that column 1 is
   "consumed only for the message" was true of the test and false of the wizard.
   Added as change 4, with the wizard's own `?non-call` arm (Claim 64).
2. **Bare-context resolution by job key was wrong.** GitHub emits a job's check
   name as `name:` when declared; the map already encodes this for reusables
   (Claim 61). A key-only match would resolve nothing for a gate job with a
   `name:` — turning a correct gate into a red F2 verdict. Also constrained PR-2's
   gate name to contain no `" / "` (Claim 62).
3. **Ruleset arming is create-or-update, not an idempotent PUT.** Every other
   applied template targets a path-keyed endpoint; rulesets are `POST` to create
   and `PUT .../{id}` to update (§15), so a naive re-run creates a **duplicate**.
   Identity now inherits PLAN-020's target + ref-pattern rule and its detail-GET
   N+1 (Claims 72, 73) rather than being reinvented.
4. **§11's pre-arm check was only half-discharged.** The map reads canon's tree;
   §11's risk is a property of the *target* repo. Now stated as *map output ∧
   installed-caller check against the target*, both of which the wizard already
   implements (Claim 66).
5. **Two unedited sections orphaned by Pass 8.** §8 still said
   `apply-standards.sh` takes "no change in this plan" and that the map's `USES`
   regex "should pick new callers up unchanged"; §7 still carried a sentence
   naming branch protection as M4's audit source **and requiring a PAT for the M4
   row**, directly contradicting the correction Pass 6 fold 4 had already made two
   paragraphs above. Both rewritten.
6. **§12 gained no criterion for either new deliverable** — `arm-ruleset.sh` had
   neither a criterion nor a gate, i.e. a cross-repo write function shipping with
   no declared verification. Criteria 8 + 9 added, 9 asserting on the *call* per
   the repo's stub trap.
7. Minor: §10's non-goal contradicted PR-4's own row (this plan does ship one
   ruleset template); the §9d glob's exclusion of `rulesets-canon.json` is now
   stated as deliberate; `test_checknames.sh` recorded as intentionally not
   extended (Claim 65); §9e notes it answers PLAN-020 Phase 1's either/or *for the
   mechanism*, which requires the applier be template-parameterised.

Thirteen claims added (61–73); the 15-row measurement moved to §15 with its
command, per this plan's own rule that a volatile claim carries its re-derivation.

**Confirmed sound by this pass** (recorded so coverage is legible): the §9d
measurement, re-derived independently; §9d change 1's jq path against the ruleset
schema; the manifest half of change 2, including `visibility_variants`; that
`tests/test_contract.sh` is inert under change 3; and **§9e's circularity
argument** — PLAN-020 Phase 1 is read-side only and Phase 3 is gated on a second
repo needing rulesets, so Claims 56–60 are semantically accurate.

**Result:** NOT READY — nine load-bearing findings, all folded. The fold changed a
decision (§9e's applier) and grew PR-4's scope, so it needs its own independent
pass; this is cycle 2 of the OPS-0066 cap of 3.

### Pass 10 - 2026-08-03 - independent

Eight load-bearing findings **against Pass 9's fold**, plus eight minor. Third
consecutive pass in which the previous fold was the defect source; all sixteen
were re-verified against source before folding.

**The finding that ends the loop.** Pass 9's fold moved the ruleset applier out of
`apply-standards.sh` into a standalone `install/arm-ruleset.sh` — and Pass 10
found the replacement inherits or newly opens most of what justified the move:
the template source is unspecified, and "run from a canon checkout" is the
mutable-canon exposure `apply-standards.sh` deliberately refuses (Claims 70, 71);
the backup problem is **relocated, not solved** — the standalone script has no
backup at all for a cross-repo write, worse than the section it avoided, and it
also silently sheds that script's confirm, `--repo` validation, auth
preconditions, non-TTY `--yes` and dry-run default; and it becomes a **third**
implementation of the pre-arm check, the two-sources-of-truth outcome §9d
rejected option (b) to avoid. Also: Pass 9's reason 3 overstated its case —
`--allow-main-canon` exists (Claim 78), so the tag chicken-and-egg is an
inconvenience, not a blocker.

**Rather than fold a third time, §9f splits the question out.** The Pass-6 item
was the *meta-strip*, and that is genuinely closed. The applier's *shape* is a
design decision about a 🔴 cross-repo write path, it has changed answer twice
under review, and the next fold would be cycle 3 — the OPS-0066 cap. §9f names
its five open questions; nothing in PR-0..PR-3 depends on them.

**Folded, the rest:**

1. **The wizard fix traded one silent drop for another.** Pass 9 prescribed
   iterating the map's column-1 values; the existing file-list iteration is
   deliberate and commented (Claim 76) so `umbrella`, which declares no required
   contexts (Claim 75), still reports rather than vanishing. Now the **union** of
   both, keeping the zero-context line.
2. **Bare-name resolution needed step 1's tie-breaking rule** (Claim 74) — two
   caller templates could declare a same-named repo-local job, and glob-order
   resolution would pick a producer basename the target check then runs against.
3. **Change 3 removes a *declared* class, not a dead branch.** Four comments
   encode repo-local required contexts as intentional; §9d now states the new
   rule (canon ships a producer for every required context, bare or not) and
   updates all four.
4. **PR-4 shipped three canon-body changes with no `REPO_STANDARDS` update** — a
   new template family, a new canonical script, and a *contract* change to the F2
   invariant. Canon's own rule requires it and nothing automated catches the
   omission; added to PR-4's row.
5. **§13 still said "PR-4 extends [Phase 1]"** — it extends Phase **3**, and
   PLAN-020 Phase 3's own text still prescribes the rejected `apply_rulesets()`
   design, so a session reading PLAN-020 alone would implement it. PR-0 now owns
   the supersession.
6. **Criterion 9 demanded behaviour §9e permitted the implementation to lack** —
   "converge or fail loudly" versus "create-only with a documented failure". The
   escape is now closed: refuse-on-existing must be implemented, and the criterion
   requires a `${GH:-gh}` indirection (Claim 79) so it can be asserted on the call.
7. **Criterion 8 conflated the map's half with the wizard's** ("installed" is not
   the map's notion) and assigned a wizard assertion to the wrong suite; split as
   8 and 8a.
8. Minor: Claim 69's enumeration was wrong — the backup does continue to
   `actions_access` and branch-protection (re-cited at :770); §9d misdescribed
   `test_checknames.sh`'s skip as separator-based when it keys on the literal
   `call /` prefix (trailing space included) (Claim 77); §7a's PAT scope list over-scoped a 🔴 credential
   by implying the rulesets read needs `administration:read` after §7 had just
   established it does not; §8 gained rows for both new PR-4 surfaces.

Six claims added (74–79).

**Confirmed sound by this pass:** Claim 68's symbol does support its assertion;
Claims 50–67 and 70–73 are semantically accurate; §9d change 1's glob genuinely
excludes `rulesets-canon.json`; a standalone script violates no canon convention
about where scripts live (`install/` already holds six canon-local tools); and
criterion 9's "assert on the call" is achievable — the suite already has an
arg-recording `gh` stub.

**Result:** NOT READY, and **not converging by folding** — three consecutive
passes have found the prior fold to be the defect source. §9d is closed and
converged. §9e's meta-strip is closed. §9f is **split out, not folded**, which is
what the OPS-0066 cap exists to force at cycle 3. The plan is ready for PR-0
through PR-3 and half-ready for PR-4; §9f needs its own decision, not another
review cycle.

### Pass 11 - 2026-08-15 - self + independent (§9g only)

Scoped pass: adds §9g and Claim 80, discharging §9's "unbounded until measured"
for the `mypy` half. **Does not reopen the §9f split or any Pass-10 finding.**

Two independent reviewers, one with a shell and one without. Four findings folded,
each of which had made the section wrong rather than merely thin:

1. **The conclusion outran its measurement.** §9g first measured `planner.py`
   alone and concluded for all ten modules. Re-measured in the gate's own
   invocation (`python3 -m mypy $(git ls-files '*.py')`): **28**, and the
   `NoReturn` shape generalises to **four** `fail()` helpers, not one, clearing
   15. The residual 13 is an unrelated `install/` cluster. The first correction
   was itself mis-scoped — it claimed 15 errors each needing an individual site,
   when 2 of those 15 fall to the same annotation pattern.
2. **The measurement was not the gate's.** Per-file `mypy` leaves imports
   unresolved and reports `[import-not-found]` artifacts the real gate never
   sees. Restated on the single-invocation form.
3. **Claim 80 pinned the line PR-1 deletes** — a `symbol not found` hard FAIL
   that `--fix` cannot repair. Re-pinned to `raise SystemExit(1)`, which
   survives the signature rewrite.
4. **`ruff`-clean did not reproduce.** This repo ships no `pyproject.toml`, so
   bare `ruff check` discovers the **umbrella's** and reports `I001`. Recorded as
   a PR-1 precondition rather than a measurement.

The §26 renumbering list at §13 was re-derived twice — the insertion shifted it,
and the fold shifted it again. Its line-range `grep -v` filter was replaced with
a content-based one, because after the first shift the old filter would have
**excluded a real occurrence**. That filter's terms are ordinary English words,
so a future forward reference containing one is dropped silently; the count
(11 across 9) is the assertion to check, and it must be run from the repo root.

**Result:** no new findings — ready for the §9g scope only. The plan's overall
status is unchanged by this pass, and Pass 10's **NOT READY** on §9f stands.
