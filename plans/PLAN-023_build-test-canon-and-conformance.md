# PLAN-023 — build/test canon + conformance model (S1 + X2)

**Owner:** `aidoc-flow-ci` maintainer
**Origin:** founder direction 2026-08-03 — transform this repo into the company
CI/CD standard covering public + private repos, labelling, scanners and security.
A survey of the estate found the *gates* half mature (21 reusables) and the
*delivery* half absent: **no canon reusable builds, tests, packages, versions,
releases or deploys anything.** Decomposed into nine subsystems (S1–S7, X1–X2);
this plan is **S1** (build/test) plus **X2** (the language axis later subsystems
slot into).
**Status:** Draft — **NOT READY, 1 item open.** A best-practices investigation
(2026-08-03) changed two premises (§3c, §3f); all 9 Pass-4 and 9 of 10 Pass-6
findings are folded — the last two by `DECISIONS.md` **CI-0029** and by the
2026-08-03 ruleset probe (§3c, §15), which confirmed the §3c premise on a private
repo rather than leaving it asserted. Remaining: extend canon's F2 no-orphan
self-check to ruleset-armed contexts (Review log, Pass 6).
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
drift comparison (Claim 49). PLAN-023 must **not** ship a second template family
and a second applier. PR-4 therefore either extends PLAN-020's template and
applier, or PLAN-020 Phase 1 is pulled forward as this plan's dependency; PR-0
records which. FT-55's stated defect transfers with it: a ruleset that is
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
(M4's audit source is the **rulesets** API, not branch protection — measured
readable without admin, §3c. The paragraph below concerns the *settings* checker
this report deliberately does not build on.)
`sync/check-standards-drift.sh` is a server-side *settings* checker whose CI-0018
accounting records the blocker directly: under the default `GITHUB_TOKEN`,
**branch-protection and `actions.*` are unreadable**, yet the job concluded
success (Claim 36). M4's audit source is the branch-protection API, so the report
**must state its own coverage and require a PAT for the M4 row**, per §4.2d — a
check states its coverage, and unreadable is never reported as passing. The
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
  `GITHUB_TOKEN` except `AI_REVIEW_TOKEN`. Reading eight siblings' trees, rulesets
  and run artifacts needs a PAT or App with `contents:read`, `actions:read` and
  `administration:read` — a **🔴 founder prerequisite**, not a coding task, and
  the same problem Allstar solves by being a GitHub App.

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
| `install/required-context-map.py` | the `USES` regex (Claim 18) should pick new callers up unchanged — **verify in PR-2, do not assume** |
| `install/apply-standards.sh` | no change **in this plan**; ruleset arming lands via PLAN-020's applier or PR-4's extension of it (§3c) |
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
| **PR-4** | Deviation + `evidence:` parsing, artifact retrieval (§7), `conformance-report.sh` **+ its caller (canon-only, §7a)**, `ruleset-test-gate.json` + its `gh api` applier (§3c), §12 rows, `overrides.md` update | report runs in CI and states its coverage |

**PR-1 is the largest and may need splitting** — canon's ten Python modules
passing new `ruff` + `mypy` hooks under a required context (§2a) is unbounded
until measured. Measure it first; if the fixes are large, land the clean-up
ahead of the hook addition.

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
- **No second ruleset template family or applier** — PLAN-020 Phase 1 owns that surface (§3c).
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
  caller exists **before** arming, and PR-4 owns that check.

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

## 13. Cross-references

- `docs/REPO_STANDARDS.md` §4.1 (Claim 1), §4.3 (Claim 4), §12 (Claim 8), §23 (Claim 9)
- `plans/PLAN-013_uniform-protected-aiflows.md` — the Class A model
- `plans/PLAN-014_security-scanning-coverage.md` — opt-in + report-only precedent; §5c
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

**DECIDED 2026-08-03 — `DECISIONS.md` CI-0030.** The migration is approved and
sequenced **before** the CD subsystems (S4–S7), under its own plan; it is
explicitly **not** a dependency of PLAN-023, which ships on the current account.
CI-0030 prices it: 64 canon files hardcode the owner, so it is a canon change
plus a fleet re-pin, not a transfer alone. Rationale retained below.

**Strategic note.** Converting the account to a GitHub
**Organization** would unlock org-level rulesets targeting repos dynamically
(e.g. `visibility:private -language:java`), custom properties as a native home
for the tier and language axes X2 invents, teams as CODEOWNERS — which is the
constraint `composition.yml` exists to work around — and org secrets, which is
the §7a credential problem. It also bears on the two 🔴 items in
`ASSESSMENT_flow-ci-value-and-standard-readiness.md` ("bus factor ≥2",
"shared infra, not per-team") that a personal account cannot structurally
express. This is a founder decision with fleet-wide blast radius and belongs in
`DECISIONS.md` on its own, **not** as a dependency of this plan.

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
| 8 | A compliance-evidence table exists mapping each rule to its audit trail | `## 12. Compliance evidence — where each rule's audit-trail lives` | docs/REPO_STANDARDS.md:972 |
| 9 | Only a code-changing event may cancel an in-flight run of a required gate | `## 23. Only a code-changing event may cancel an in-flight run of a required gate` | docs/REPO_STANDARDS.md:2008 |
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
| 27 | A required check with no producing workflow never reports and pins every PR | `required check with no producing workflow does not fail; it never reports, so` | docs/REPO_STANDARDS.md:1440 |
| 28 | Applying standards PUTs the whole tier protection template, clobbering hand-added contexts | `apply_branch_protection() {` | install/apply-standards.sh:700 |
| 29 | Canon records that a job skipped by `if:` reports green and can supersede a standing `request_changes` | `# unarmed repo has no such gate, so a skipped-job green would SUPERSEDE a prior ` | .github/workflows/ai-review.yml:143 |
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
| 44 | Canon already ships a `.gitattributes` baseline to carry linguist overrides | `### 10.2 `.gitattributes` baseline` | docs/REPO_STANDARDS.md:929 |
| 45 | Canon's own pre-commit config is a hand-maintained Wave-0 copy whose marker must be kept in step with the fragment | `# Keep the marker in step with install/templates/pre-commit-hook-block.yaml.` | .pre-commit-config.yaml:30 |
| 46 | The pre-commit merge de-dups by repo URL, keeping the consumer's rev and reporting the collision rather than merging hook lists | `# De-dup by repo URL, NOT whole-entry structural equality (PLAN-018 F3). Canon` | install/install.sh:988 |
| 47 | Self-callers pin the released tag by deliberate convention, so canon consumes what its consumers do | `# self-pre-commit.yml — canon dogfoods the pre-commit gate it ships (PLAN-018 FT-36).` | .github/workflows/self-pre-commit.yml:1 |
| 48 | Whether `GET /rulesets` is admin-class was an explicitly open question this plan must not assume — now measured (§15) | `### FT-55 — the immutable `ci/v*` tag ruleset is an act, not a standard` | plans/FRAMEWORK-TODO.md:206 |
| 49 | No canon machinery knows rulesets exist, and PLAN-020 Phase 1 already owns the fix | `**Fix:** `plans/PLAN-020_canon-self-adoption-and-ruleset-canon.md` Phase 1 — a` | plans/FRAMEWORK-TODO.md:218 |

## Review log

### Pass 1 - 2026-08-03 - self

Findings folded: Claim 21 reframed (an absence cannot resolve to `path:line`);
the false-drift trap avoided (a `grep` for `runner_labels` matched commented
illustrative examples and read as a security drift — withdrawn after re-checking
with comments stripped, REPO_STANDARDS §22's failure mode applied to a reader);
scope cut from `build-*` to `test-*` once `pre-commit.yml` was found to cover
lint/typecheck; runner class reassigned from a new Class B split to Class A.

Open question carried into the independent pass: whether M2's artifact
requirement is sufficient as the sole conformance anchor.

**Result:** gate-clean, dispatching independent review.

### Pass 2 - 2026-08-03 - independent

Eight load-bearing findings, seven minor. **The open question was answered: no.**
All folded:

1. **M4 unimplementable** — required contexts are tier-static (Claim 26); arming
   a language check fleet-wide triggers the F2 never-reports pin (Claim 27) and
   `--apply` clobbers hand-adds (Claim 28). → M4 demoted to SHOULD; **S8** added
   as a named deferred subsystem (§3c).
2. **`fork-strategy: skip` + a required check = a bypass** — canon records that a
   skipped job reports green (Claim 29), and no scanner is a required context, so
   they are not precedent. → default reversed to `ubuntu-latest` (§3d),
   **flagged for founder confirmation** as it reverses their answer.
3. **M2 gameable** — canon already ships the counter-pattern (Claim 25). → M2
   asserts non-vacuous evidence and the gate strips PR-supplied collection config
   (§3a).
4. **§2's reuse argument false for the fleet** — no workspace repo declares a
   `mypy` hook; canon's own config declares neither (Claim 24); engramory would
   *lose* its typecheck on migration. → §2a added; PR-1 ships pinned `ruff` +
   `mypy` hooks in the config template; M1 covers lint + typecheck.
5. **Filename detection wrong both ways** — `iplanic` is a false positive,
   canon itself a false negative. → two-level detection (§4); criterion 1
   rewritten to name both counter-examples.
6. **M3 unmeetable fleet-wide** — no lockfile exists anywhere. → SHOULD, with a
   per-ecosystem definition owed by §24 (§3b).
7. **§7 anchored to the wrong script** — the drift checker cannot read
   branch-protection under the default token (Claim 36). → own implementation,
   explicit coverage statement, `unknown` rows, PAT required for M4.
8. **§11's pilot contradicted criterion 7** — a pilot branch in a sibling is a
   cross-repo write. → canon becomes its own pilot via a `tests/fixtures/`
   package, which also repairs the Wave-0 gap.

Minor, all folded: cross-repo citations moved out of the ledger into §14 so every
ledger row resolves against one root; Claim 22 re-pointed to canon's own copy of
`run-ephemeral.sh` (Claim 33); the miscited Claim 8 reference dropped from §5 and
Claim 23 now referenced where it applies; criterion 6 rewritten to exercise the
wizard scaffold path rather than `--update`, which never introduces a surface
(Claim 35); tool-version pinning added as §5a (M5 applied to this plan's own
reusables); §5c added to record the PR-code-on-pool extension PLAN-014 explicitly
declined (Claim 34); wizard phase corrected from 3 (scanners) to 2 (lint); §9a
added because PR-1's original gate could not see PR-1's content.

Also folded, from founder direction received during this pass: **§1a AI-first by
default**, and floor rule **M7** (machine-readable structured evidence at a
declared path).

**Result:** findings folded; re-dispatching for an independent Pass 3.

### Pass 3 - 2026-08-03 - independent

Confirmed Claims 24–36 semantically sound and the M4→S8 and §3d folds correct in
principle. Found **nine load-bearing findings, all introduced by the Pass-2
fold** — the "a fold is a change and needs the same scrutiny" trap, in full. All
folded:

1. **The §2a remedy edited a file that does not exist and would have reached zero
   repos.** The surface is `pre-commit-hook-block.yaml`, a merge fragment whose
   **marker version is the delivery mechanism** (Claim 37) — without a `v2`→`v3`
   bump, bootstrap no-ops on every adopted repo (Claim 38), and `--update`
   excludes the file by design. The fragment's own header documents this exact
   freeze-forever failure (FT-32). → §2a rewritten with the real surface, the
   marker bump, and bootstrap-only delivery.
2. **§3a's "strip PR-supplied config" is impossible for pytest.** `conftest.py`
   is executable test code; pytest config lives in the same `pyproject.toml` §5b
   must read. The `sast-scan` analogy does not transfer. → strip requirement
   deleted; non-vacuity kept; `coverage-omit`/`testpaths` added so the
   "express it gate-side" escape has a mechanism.
3. **No producer for criteria 3 and 4.** Canon's Wave-0 mechanism is a `self-*`
   caller (Claim 41) and PR-2 shipped none. → `self-test-python.yml` added;
   criterion 4 moved to a shell unit test, since a fixture PR failing canon's own
   required gate would be unmergeable.
4. **M2/M7 audited against artifacts §7 never retrieved**, with no schema and no
   place to declare a path. → `evidence:` block added to §6, schema owed by PR-1,
   retrieval owed by PR-4; §1a's "costs nothing" claim corrected.
5. **`node.buildable_package` keyed on `name`/`version`** — true of essentially
   every `package.json`. → keyed on not-`private` plus `main`/`exports`/`files`/
   build script; criterion 1 gains a Node counter-example.
6. **The `mypy` hook would be vacuous** without `additional_dependencies`, and
   canon's own self-adoption cost (ten modules under a *required* lint context)
   was unbudgeted. → both stated; PR-1 flagged as possibly needing a split.
7. **`buildable_package` anchoring unspecified**, which the PR-2 fixture would
   have flipped — making canon report buildable and failing criterion 1. →
   `anchor: working-directory`, explicit and non-recursive.
8. **M6's predicate was self-contradictory** (unconditional MUST plus a
   universally-available `skip` carve-out) and M5/M6 named the wrong audit
   target. → M6 scoped to the armed case; §3e added for mode-dependent audit
   targets; §3d's "reports a conclusion" qualified with `action_required`
   (Claim 42); `fork-strategy` split into an enum plus `fork-runner-labels`.
9. **Wizard phase wrong** (lint is phase 1, not 2) and a **second hand-maintained
   phase list** exists (Claim 39); **§4.1 defines only two flow classes** and
   this plan ships a third. → §8 corrected; §9b added so PR-1 extends §4.1.

**Result:** findings folded; re-dispatching for an independent Pass 4 — the final
pass permitted under OPS-0066's 3-independent-pass cap.

### Pass 4 - 2026-08-03 - independent

**Nine load-bearing findings. NOT folded — the OPS-0066 circuit-breaker fired.**

This was the third independent pass. Each of the three found defects *introduced
by the previous fold*, so folding a fourth time without review would repeat the
one failure mode this log has demonstrated three times running. Per OPS-0066 the
open items are surfaced to the founder rather than silently folded.

Confirmed sound and **not** to be re-opened: Claims 37, 38, 39, 41, 42; the
marker-delivery mechanism; §9b's two-class reading of §4.1; the Mode-2 mapping;
every §14 cross-repo row spot-checked.

**Open — design-changing:**

1. **PR-2/PR-3 gates cannot be met inside PR-2/PR-3.** Every existing `self-*`
   caller pins the *released* tag by deliberate convention, and `test-python.yml`
   exists in no tag yet — so the new self-caller `startup_failure`s and never
   reports. This is canon's own FT-21 chicken-and-egg. Needs either
   post-tag-cut sequencing or an explicit local `uses: ./…` departure.
2. **PR-1 must edit a second pre-commit file nobody names** — canon's own
   `.pre-commit-config.yaml` is a hand-maintained copy, not a bootstrap product,
   so the marker bump does not deliver hooks to canon. PR-1's "canon passes its
   own new hooks" gate therefore has **no producer** — the identical defect
   Pass 3 fixed for the test gate, left live for the lint gate. Also: the merge
   de-dups by repo URL, so canon's pinned `ruff` will **not** reach the five
   repos that already declare `ruff` (WARN only); `mypy` does land.
3. **`--fleet` has no data source and no token model.** Reading nine repos' file
   trees, branch protection and run artifacts from canon's ephemeral runner needs
   a cross-repo PAT that does not exist today (every workflow secret is
   `GITHUB_TOKEN` bar `AI_REVIEW_TOKEN`). A 🔴 founder prerequisite PR-4 depends
   on and no section owns.
4. **M1 contradicts §4.** M1 says "a repo containing **buildable code**"; §4 says
   `language_present` drives M1 coverage. The two showcase repos (`iplanic`,
   canon) land on opposite verdicts depending on which sentence is read.
5. **`language_present` kept the naive predicate** the two-level design existed to
   kill — bare recursive globs, no exclusions. `operations` has exactly one stray
   `.js` and would permanently owe a Node gate; `**/*.py` will match `.venv/`,
   vendored trees and (after PR-2) the fixture itself.
6. **§3e's Mode-1 row cannot audit M6** — `fork-strategy` is a *caller* input, so
   the only M6 violation possible in Mode 1 is invisible to a scan of the pinned
   ref.
7. **§6 fixes no drift** — the declared/undeclared split is promised in drift
   terms, but no PR teaches `sync/check-drift.sh` to read the file. After PR-4,
   drift still warns forever.
8. **`fork-runner-labels: ubuntu-latest` violates the private-runner policy.** One
   Class A template serves both visibilities, and private repos may never use
   GitHub-hosted (OPS-0049). The default needs a visibility-dependent answer.
9. **§3a contradicts itself** — point 2 says collection is "never overridden";
   point 3 and §5 add a `testpaths` input that overrides exactly that.

**Open — wording:** the §2 scope table still says "extend the config template"
(orphaned, contradicts §2a); repo counts say "nine" where canon makes ten; PR-1's
content column never lists the `CLAUDE.md:17` fix §9a requires; `runtime-versions`
names two different inputs in its own note; §2a's required-context citation points
at the product-tier file when canon runs FT-52's own profile.

**Result:** NOT READY — 3 independent passes exhausted, 9 load-bearing items open.
Escalated to founder per OPS-0066.

### Pass 5 - 2026-08-03 - self (post-investigation revision)

Founder approved a best-practices investigation against real-world practice
before folding. It **changed two design premises**, which is why the OPS-0066
counter resets here rather than this being a fourth fold of the same design.

**Premise change 1 — S8 dissolved (§3c).** Pass 2's diagnosis was right and its
conclusion wrong. Repo **rulesets** are a separate, aggregating surface that the
installers never touch (Claim 43, verified: zero `ruleset` references in
`apply-standards.sh`, `install.sh`, `sync/*.sh`), so a required check placed
there is immune to the branch-protection PUT. Measured live (§15): rulesets are
active on canon and on the **private** `aidoc-flow-business`, so the mechanism
works on both visibilities today. **M4 returns to MUST**; the deferred subsystem
becomes a template plus a `gh api` applier in PR-4.

**Premise change 2 — the bypass has a named industry fix (§3f).** The
skipped-job-reports-green problem is GitHub-wide and well documented; the
standard remedy is an always-running **gate job** (`if: always()` over
`toJSON(needs)`). Added as floor rule **M4a**, stated in §24 as a general rule for
any required canon gate. The canonical `re-actors/alls-green` implementation is
barred by §4.3, so canon implements it inline. Note rulesets share branch
protection's skipped-as-success semantics, so §3c does **not** subsume this.

**Also adopted from the investigation:** OpenSSF **Allstar**'s `.allstar/`
per-repo opt-out validates §6's design as standard practice rather than
invention, and its opt-out-by-default guidance is recorded in PR-0 as a
deliberate divergence; **linguist attributes** in the `.gitattributes` baseline
canon already ships (Claim 44) become the native fix for §4's false positives;
the **org-migration** question is recorded in §15 as a separate founder decision,
explicitly not a dependency.

**All 9 Pass-4 items folded:** self-caller chicken-and-egg → §9c local-ref
two-stage pattern; canon's own `.pre-commit-config.yaml` as the second required
edit → §2a (Claim 45) plus the `ruff` URL-de-dup limit (Claim 46); `--fleet`
mechanism and token → §7a, v1 ships canon-only with `--fleet` gated on a 🔴
credential; M1 re-worded to `language_present`; `language_present` filtered
(`_exclude`, linguist, `requires_manifest`); §3e Mode-1 now reads the caller's
`with:` block; §6's drift promise scoped honestly to the report; fork routing
made visibility-dependent because `github-hosted` is forbidden on private repos;
§3a's collection contradiction resolved as *override, never strip*. Wording items
folded: the §2 scope-table orphan, repo counts (eight consumers + canon),
`runtime-versions` naming, PR-1's `CLAUDE.md` fix now listed, and §2a's
required-context citation corrected to FT-52's canon profile.

**Result:** premises changed and all prior findings folded; dispatching a fresh
independent review.

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
- **`ruleset-test-gate.json` will 422 on `_`-prefixed meta keys** unless PR-4
  inherits `apply_canon_stripped` or ships meta-free. Resolved by folding into
  PLAN-020's applier (item 5) — confirm when that lands.
- **A ruleset-armed context escapes canon's F2 self-check.**
  `required-context-map.py` enumerates only `branch-protection-*.json`, and the
  gate's bare context is `?non-call`, which it deliberately does not resolve. The
  pre-arm producer check does not come free.

**Result:** NOT READY. Six items folded, three open — two of which are founder
decisions rather than authoring work.
