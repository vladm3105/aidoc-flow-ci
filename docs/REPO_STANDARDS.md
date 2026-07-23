# Repo standards — `aidoc-flow-ci`

Canonical rules for every repository in the aidoc-flow workspace.
Complements [`WORKFLOWS.md`](WORKFLOWS.md) (workflow-side compliance) and
`aidoc-flow-operations/docs/REPO_ONBOARDING.md` (CI activation steps).

This doc codifies the **static settings** side: branch protection, GitHub
security settings, labels, dependabot, CODEOWNERS, PR template, Actions
permissions, merge/cleanup, `.gitignore`/`.gitattributes`. The workflow-
adoption side lives in `WORKFLOWS.md`; the activation checklist for a new
repo lives in `REPO_ONBOARDING.md`. All three docs together are the
complete rulebook.

## 0. Canonical source authority (disambiguation)

The aidoc-flow workspace has **two** repos that consumers cite as
"canonical source" — one for **CI + governance-workflow canon**, and
one for **OPS-NNNN business decisions + multi-agent review prompt
templates**. These are DISTINCT concerns; do not confuse them:

| Concern | Canonical source | Read here |
| --- | --- | --- |
| CI reusable workflows (ai-review, composition, audit-trail-check, standards-drift, secret-scan, etc.) | **`aidoc-flow-ci`** | `.github/workflows/*.yml` (this repo) |
| Config templates (CODEOWNERS, dependabot, branch protection, PR template) | **`aidoc-flow-ci`** | `install/templates/*` (this repo) |
| Canonical scripts (`pre_push_check.sh`, `apply-standards.sh`, `parse-governance-table.py`) | **`aidoc-flow-ci`** | `scripts/pre_push_check.sh` + `install/apply-standards.sh` + `install/parse-governance-table.py` (this repo) |
| Governance-file templates (`CLAUDE.md.template`, `HANDOFF.md.template`, `DECISIONS.md.template`, `ROADMAP.md.template`, `plans-README.md.template`) | **`aidoc-flow-ci`** | `install/templates/` (this repo) |
| AI-review rubric + verdict schema | **`aidoc-flow-ci`** | `ai-review/` (this repo) |
| Static-settings + workflow-adoption + tier rules | **`aidoc-flow-ci`** | THIS FILE (`docs/REPO_STANDARDS.md`) |
| OPS-NNNN durable business decisions (governance-PR discipline, auto-merge default, multi-agent review dispatch, circuit-breaker, aidoc-flow-standard scope, audit-trail phrase, project-governance-canon ratification) | **`aidoc-flow-operations`** | `ops/DECISIONS.md` |
| Multi-agent review prompt templates | **`aidoc-flow-operations`** | `.claude/agents/review-prompts/` (per OPS-0067) |
| Cross-repo playbooks (T-C, T-C', T-D) | **`aidoc-flow-operations`** | `docs/CROSS_REPO_PLAYBOOKS.md` |
| Autonomy tiers table + AI-employees team registry | **`aidoc-flow-operations`** | `CLAUDE.md` |

**Rule of thumb for consumer docs:** when a consumer's `CLAUDE.md`
(or DECISIONS entry, or CHANGELOG entry) needs to cite a canonical
source, ask: is this about CI, workflows, templates, scripts, static
settings, or governance-file shape? → `aidoc-flow-ci`. Is it about an
OPS-NNNN business decision, multi-agent review prompt templates,
cross-repo playbooks, autonomy tiers, or AI-employees registry? →
`aidoc-flow-operations`.

**Historical note:** `IPLAN-0014_public-ci-actions-and-autofix.md`
(lines 13, 18, 57) authored BEFORE `aidoc-flow-ci` was created uses
"canonical template in operations" for CI concerns; that reflects the
pre-2026-06 layout where `operations/templates/` was the temporary home.
`IPLAN-0017-CHARTER_aidoc-flow-ci.md` is the migration doc that MOVED
those templates to `aidoc-flow-ci` — its "port operations Stage-1
designs as canonical defaults" language (line 171) reflects that
transition, not a pre-`aidoc-flow-ci` canon assignment. For the
AI-review rubric specifically, `operations/templates/ai-review/` was
the pre-2026-06 vendoring source; per IPLAN-0022 it now lives at
`aidoc-flow-ci/ai-review/`, with the reusable `ai-review.yml`
fetching it at the consumer's pinned tag. Historical text is not
back-annotated — read it in its temporal context.

## 1. Tier taxonomy (6 tiers)

Every workspace repo belongs to exactly one tier. Tier drives every
per-repo requirement below.

| Tier | Repos (2026-07-11) | Signal |
| --- | --- | --- |
| **Governance** | `aidoc-flow-framework`, `aidoc-flow-iplan-standard` | Public spec/schema repo; human-merge only |
| **Product code** | `iplan-runner`, `aidoc-flow-engramory`, `aidoc-flow-ci` | Public runtime/library repo |
| **Ops-private** | `aidoc-flow-operations`, `aidoc-flow-business`, `aidoc-flow-iplanic`, `aidoc-flow-interlog` | Private operations/docs repo |
| **Umbrella** | `aidoc-flow` | Multi-repo umbrella; submodule-pointer PRs only; `--admin` merge |
| **Bootstrap** | _(none currently — `aidoc-flow-interlog` graduated to Ops-private 2026-07 after full CI adoption)_ | New repo pending CI adoption |
| **Paused** | `aidoc-flow-knowledge-rag`, `aidoc-flow-site` | Frozen per founder direction 2026-07-04 |

Tier is not property of the repo file — it's a canonical assignment
maintained here. When a new repo enters the workspace, its tier is
declared before any settings apply (see §11 Rollout).

## 2. Branch protection

All non-paused repos protect `main`. Tier drives the profile.

| Setting | Governance | Product code | Ops-private | Umbrella | Bootstrap |
| --- | --- | --- | --- | --- | --- |
| Required PR before merge | ✅ | ✅ | ✅ | ✅ | ✅ |
| Required approving reviews | 1 human | 0 | 0 | 0 | 0 |
| Dismiss stale reviews on push | ✅ | ✅ | ✅ | ✅ | ✅ |
| Require review from CODEOWNERS | ✅ | ⏸ v2 | ⏸ v2 | ✅ | ⏸ v2 |
| Required status checks (baseline) | `call / ai-review`, `call / composition`, `call / verify`, `call / Lint / format / security hooks` + tier-specific | `call / ai-review`, `call / composition`, `call / verify`, `call / Lint / format / security hooks`, `call / gitleaks` + tier-specific | `call / ai-review`, `call / composition`, `call / verify`, `call / Lint / format / security hooks`, `call / gitleaks` + tier-specific | (no required checks — submodule-pointer only; `call / verify` runs advisory) | `call / Lint / format / security hooks` + tier-specific (`call / verify` deferred to CI adoption per §14.3) |
| Require branches up-to-date before merge | ⏸ (adds re-run round-trips; deferred) | ⏸ | ⏸ | ⏸ | ⏸ |
| Require signed commits | ⏸ v2 | ⏸ v2 | ⏸ v2 | ✅ (unsigned AI commits blocked; `--admin` per OPS-0062) | ⏸ v2 |
| Include administrators | ✅ | ✅ | ✅ | ⏸ (`--admin` merge is the intentional bypass) | ✅ |
| Allow force pushes | ❌ | ❌ | ❌ | ❌ | ❌ |
| Allow deletion | ❌ | ❌ | ❌ | ❌ | ❌ |

**Rationale — required approving reviews:**

- **Governance** requires ≥1 human because spec/schema changes carry the
  highest downstream blast radius (regeneration of tests, plugin
  templates, etc.).
- **Product code / Ops-private** set required-approving-reviews to 0
  (a distinct branch-protection setting from auto-merge armament).
  Substantive review comes from allowlisted AI authors +
  `ai-review.yml` + `composition.yml` chain; the trust gate + verdict
  gate + auto-merge gate are the required CHECKS, not a reviewer
  count. Auto-merge itself is a PR-side mechanism armed by
  `auto-merge-ai-prs.yml` (per `auto_merge.repos` allowlist).

**Rationale — signed commits (deferred except umbrella):** AI commits are
unsigned; requiring signed commits everywhere would force every AI push
through `--admin`. Umbrella already has this constraint as a deliberate
governance layer; other tiers defer until the workspace adopts a signing
solution (`gitsign`, `gh api PATs with commit signing`, etc.) — tracked
as v2.

**Verified emitted check-names (FT-2, 2026-07-12).** A required-context name
that does not match the string CI actually emits never turns green → the PR is
blocked forever. The canon reusables emit `call / <job>`; the verified map is:

| Workflow | Emitted required-check name |
| --- | --- |
| ai-review | `call / ai-review` (+ `call / trust`) |
| composition | `call / composition` |
| audit-trail | `call / verify` |
| pre-commit | `call / Lint / format / security hooks` |
| secret-scan (canon) | `call / gitleaks` |

**Caveat:** a repo using its own standalone `security.yml` (business, interlog)
emits `Secret scan (gitleaks)`, NOT `call / gitleaks` — arm that name instead on
those repos. `tests/test_checknames.sh` asserts every `call / …` context in a
branch-protection template maps to a real reusable job, so this can't drift again.

### 2.1 Branch naming and lifecycle

All changes use a short-lived working branch and a PR into the protected
default branch. The canonical technical lifecycle—intent-based naming,
automation exceptions, update strategy, squash merge, cleanup, hotfixes, and
the boundary between enforced settings and review conventions—is defined in
[`BRANCHING.md`](BRANCHING.md).

The standard prefixes are `feat/`, `fix/`, `docs/`, `chore/`, `refactor/`, and
`test/`; existing coordinated playbooks may retain the legacy `feature/` alias.
Automation that requires an actor prefix may use `agent/`, while managed
dependency bots keep their generated namespaces. Branch names are conventions,
not a branch-protection API rule. PR-only default-branch changes, no force-
push/deletion, squash-only merge, update-branch support, and automatic head-
branch deletion are enforced for non-bypass actors by the branch-protection and
repository-settings templates. The umbrella admin bypass is governed by
OPS-0062 and still requires a PR.

## 3. GitHub security settings

Each repo's GitHub-hosted security features (secret scanning, push
protection, dependabot alerts, code scanning). Availability depends on
visibility + license tier — settings that are unavailable on private
repos without Advanced Security are marked N/A.

| Setting | Governance (public) | Product code (public) | Ops-private (private) | Umbrella (private) | Bootstrap (any) |
| --- | --- | --- | --- | --- | --- |
| Secret scanning | ✅ | ✅ | N/A (no Advanced Security) | N/A | ✅ if public else N/A |
| Secret scanning push protection | ✅ | ✅ | N/A | N/A | ✅ if public else N/A |
| Dependabot security updates | ✅ | ✅ | ✅ | ✅ | ✅ |
| Dependabot version updates (via `dependabot.yml`) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Code scanning (CodeQL) | ✅ | ✅ (only when repo has runtime code) | N/A (Advanced Security) | N/A | ⏸ pending |

**Enforcement:** apply via `install/apply-standards.sh --apply` (PR-C).
Public repos should NEVER have secret_scanning + push_protection
disabled; that's a hard rule. Private repos accept the N/A because
GitHub Advanced Security is a paid tier we don't license.

## 4. Actions permissions (repo-level)

GitHub's `Settings → Actions → General → Workflow permissions` and
related knobs. These control what workflows can do with the default
`GITHUB_TOKEN`, whether fork PRs can run workflows, and which actions
are allowed.

| Setting | All tiers (default) | Rationale |
| --- | --- | --- |
| Actions permissions | Allow local + explicit-allowlist third-party | Blocks unreviewed action-from-anywhere |
| Fork pull request workflows from outside collaborators | Require approval for first-time contributors | Prevents unlimited-fork abuse |
| Send write tokens to workflows from fork PRs | ❌ Disabled | Fork PRs never get write tokens |
| Send secrets and variables to workflows from fork PRs | ❌ Disabled | Fork PRs never see secrets |
| Default workflow permissions | ⚠️ `read` (not `write`) | Least-privilege default; workflows that need write set it explicitly at job-level |
| Allow GitHub Actions to create and approve pull requests | ✅ (needed for `docs-sync.yml` + `doc-maintainer.yml`) | Required by IPLAN-0018/0025 workflows |

**Enforcement gap risk:** GitHub's default is `read-write` on new repos.
`apply-standards.sh` (PR-B) tightens to `read` and adds the fork-PR
constraints.

### 4.0a AI documentation-maintainer safety contract

Repositories adopting `doc-maintainer.yml` MUST provide
`.github/doc-maintainer.json` and `.github/doc-maintainer-conventions.md`, begin
in dry-run mode, and keep autonomous edits restricted to explicit low-risk
documentation globs. The planner treats PR text and patches as untrusted data,
validates every AI-selected path against `allowed_paths`, caps edits per PR,
and classifies any path not explicitly low-risk as high-risk. Low-risk edits
open a normal bot PR subject to the repository's review gates; high-risk edits
open an issue and are never applied automatically. Live mode additionally
requires the scoped `aidoc-flow-bot` App and enforces `max_prs_per_day`.

### 4.0b Unified LiteLLM agent gateway

All canonical AI execution (`ai-review` and `doc-maintainer`) goes through one
OpenAI-compatible LiteLLM proxy — the default, API-based LLM gateway (it
replaces per-runner vendor CLIs and fronts many providers behind one endpoint).
Consumers provide **repository-level** secrets `LITELLM_BASE_URL`,
`LITELLM_REVIEW_API_KEY`, and `LITELLM_DOC_API_KEY` (set them **per repo** —
organization-level secrets require an org account and are unavailable on a
personal-account owner). They do not install or log in to vendor CLIs on runners.
AI review resolves its model alias from caller input
`model`, then trusted config `litellm.model`. Doc-maintainer uses its caller
`model` input (default `ai-doc-maintainer`). The proxy owns provider selection,
fallbacks, budgets, and provider credentials; CI receives only a scoped LiteLLM
key. Runners must be able to reach the configured proxy. Proxy failures and
malformed responses fail closed and never become an approving verdict.

The proxy URL MUST use HTTPS. Plain HTTP requires the explicit caller opt-in
`litellm_allow_insecure_http: true` and is limited to a controlled private
network. Use separate virtual keys for review and documentation maintenance,
restricted to their model aliases with spend/rate limits and rotation; never
use the LiteLLM master key. Disable sensitive prompt/response logging and apply
an appropriate retention policy: AI review sends a bounded, secret-pattern-
redacted PR diff to the proxy, which can still contain private source code.
Doc-maintainer sends redacted PR metadata, patches, repository conventions,
and redacted current documentation. Secret-shaped source values use opaque
placeholders during inference and are restored only after the response; missing
or duplicated placeholders fail closed.

Before a major AI-contract release is tagged, `.github/workflows/litellm-smoke.yml`
MUST pass against the actual proxy for both canonical aliases. Mocked unit tests
do not replace this provider/proxy compatibility gate.

### 4.1 Runner class by flow-class + visibility (canon)

Runner routing follows the flow **class**, not only visibility (PLAN-013):

| Flow class | Public | Private | Caller shape |
| --- | --- | --- | --- |
| **AI-flows** (`ai-review`, `doc-maintainer`, `docs-sync` (+ `autofix`, a gated job within `ai-review` — PLAN-012)) | self-hosted `["self-hosted","ci-runner","single-use"]` | self-hosted (same) | **ONE protected template** — no `-public`/`-private` split; visibility flip = no-op |
| **Generic checks** (`markdown-lint`, `links`, `pre-commit`, `composition`, `audit-trail`, `secret-scan`, `labeler`, `auto-merge-ai-prs`) | GitHub-hosted `ubuntu-latest` | self-hosted | `-public.yml` / `-private.yml` variants |

The AI-flows run **uniform self-hosted on both visibilities** because forks never
reach a job that executes PR code (trust-gated or post-merge) — safe on public per
`docs/security.md` §3. The **fork-code-running lint flows**
(`markdown-lint`/`links`/`pre-commit`) MUST stay `ubuntu-latest` on public
(running fork code on self-hosted is the leak GitHub warns against), so their
visibility split is kept. This account has **no GitHub-hosted minutes for private
repos** (OPS-0049), so private = self-hosted everywhere.

`install.sh --update` installs the AI-flows' single protected template regardless
of visibility (their manifest entries carry no `visibility_variants`); for the
generic checks it auto-detects visibility (`gh repo view isPrivate`) and installs
the matching variant. **A consumer MUST register the self-hosted `ci-runner` /
`single-use` pool before adopting** (now also for the AI-flows on public repos).
Full detail: `docs/runners.md` "Workspace policy".

As of `ci/v1.9.0` the `-private.yml` templates ship the **real**
`["self-hosted", "ci-runner", "single-use"]` label directly (earlier releases
shipped a `runner-self` placeholder that resolved to `runs-on: runner-self`,
matched no runner, and queued every required check — FT-9).

**Every GENERIC manifest workflow surface has a `-private` variant** (as of the
ci/v2.1.0 cut; the AI-flows dropped their variants for a single protected template
in `ci/v2.2.0` per PLAN-013 §4.1, so this applies to the generic checks only).
Previously only 5 of 11 did; the other 6 (`links`,
`markdown-lint`, `pre-commit`, `secret-scan`, `labeler`, `docs-sync`) were
generic templates carrying `runner_labels` only as a commented hint. That made
`install.sh --update` unsafe on a private consumer: `--update` resolves each
surface through `manifest.json`'s `visibility_variants`, and with no private
variant it re-applied the label-less generic → the reusable's `ubuntu-latest`
default → jobs queue forever on a private repo (OPS-0049). The variants close
this: `--update` now writes a labeled file for private repos, so it is safe
without hand-editing. The `deploy-ci-wizard.sh` injection path (which added the
labels at scaffold time) still works and is now belt-and-suspenders rather than
the only thing standing between a private consumer and a bricked gate.

### 4.2 Re-pinning consumers (version-only) — `install.sh --repin`

**A re-pin is a version-string-only change.** To move a consumer to a newer
`ci/vX.Y.Z`, use `install.sh <owner/repo> --repin` (with `CI_TAG` or the
`VERSION` fallback as the target): it rewrites the `@ci/vX.Y.Z` on every
`uses: …/aidoc-flow-ci/…` line and **preserves runner_labels, permissions,
triggers, and all consumer customization**. **Never use `--update` for a
re-pin** — `--update` re-applies the template body and clobbers customized
callers (this is exactly how the v1.8.1 sweep re-introduced `runner-self` and
bricked the fleet; FT-9). `--update` is only for deliberately adopting a new
template body, reviewing each drift.

### 4.2a The adopted pin must be readable — reusables resolve it from the caller

**A reusable that fetches cross-repo assets MUST resolve the canon tag from the
consumer's own adopted `uses:` pin, and MUST hardcode the canon owner/repo. It
must NOT use `github.workflow_ref`.**

Inside a `workflow_call` reusable, `github.workflow_ref` is the **CALLER's**
entry workflow ref (the consumer's default branch), not the reusable's pinned
tag — and its first path segment is the **caller's owner**, not the canon's.
Using it means the adopted pin controls neither the version nor the source: the
gate silently tracks canon `main`, rollback-by-re-pin does nothing, and external
adopters 404 against `<their-org>/aidoc-flow-ci`. This was live in production
until FT-15 (confirmed 2026-07-21); `github.job_workflow_sha` is not a
substitute because it is not accessible as a `${{ }}` expression.

The canonical resolver — **copy `docs-sync.yml`** (or `standards-drift.yml`,
which pioneered the approach and was brought to this full property list by
FT-22). The rule:

- scan only files GitHub actually executes (`--include='*.yml' --include='*.yaml'`)
  and only real `uses:` lines. Without both filters a `*.yml.bak` / `*.disabled`
  leftover or a commented-out example can supply the tag and **win** the version
  sort — a silent wrong-version hazard (verified, not theoretical);
- key the pattern to **this reusable's own filename**, never an unkeyed one — an
  unkeyed match can pick up the trailing comment on a line pinning a _different_
  reusable and resolve the wrong tag;
- accept both pin forms canon recognises: plain `@ci/vX.Y.Z` and the
  commented-SHA `@<40-hex> # ci/vX.Y.Z`;
- **reject pre-release pins explicitly.** Capture any `-suffix` and hard-fail on
  it. Silently dropping it resolves `ci/v2.10.0-rc.1` to `ci/v2.10.0` — a real
  but _different_ tag once that ships, reintroducing the wrong-version class with
  a notice that looks correct;
- **fail CLOSED when more than one distinct pin is found.** Only one reusable
  actually runs, so the correct tag is not knowable from the tree; picking the
  highest would silently fetch a version the repo never adopted. Error and list
  the competing pins;
- **when the caller pinned by SHA, fetch at the SHA — not the trailing comment.**
  GitHub executes the reusable at the SHA, while `# ci/vX.Y.Z` is documentation
  that can lag it (a surgical-sed re-pin updates one and not the other). Trusting
  the comment runs one version's workflow with another version's assets — the
  same wrong-version class through the other pin form;
- distinguish "`.github/workflows/` unreadable" from "no pin found" (`grep` exit
  ≥2 vs 1), so the error cannot misdiagnose a correctly-installed caller;
- **guard the fetched input itself** — a 200-with-empty-body, or a JSON body when
  raw was requested, must be its own INFRASTRUCTURE error. Otherwise a transport
  fault produces "no pin found" and sends an operator to audit a correct caller;
- anchor the owner in the pattern (`vladm3105/aidoc-flow-ci/…`). Unanchored, a
  pin naming a _different_ owner's `aidoc-flow-ci` matches and then 404s against
  the hardcoded owner — fail-closed, but with a confusing diagnostic;
- **fail loud and INFRASTRUCTURE-classed in every one of those cases — never fall
  back to `main`**, which would silently restore the defect.

**Install constraint (fail-closed, but worth knowing):** for reusables that
resolve over the API (`ai-review`), `github.workflow_ref` names the **entry**
workflow. A consumer that wraps a canon reusable inside its _own_ `workflow_call`
reusable has no canon pin in the entry file, so resolution hard-fails. Call canon
reusables directly from the entry workflow.

**Consequence for consumers:** a caller whose pin the resolver cannot read now
hard-fails instead of silently fetching `main`. **Pre-release pins
(`@ci/vX.Y.Z-rc.N`) are not supported** — the resolver pattern is unanchored and
would prefix-match `ci/v2.10.0-rc.1` to the nonexistent `ci/v2.10.0`. Pin
released tags only.

### 4.3 Reusable workflows install tools as BINARIES, never third-party actions

**Canon reusable workflows may `uses:` only `actions/*`, `github/*`, and
`vladm3105/aidoc-flow-ci/*`.** This is a **canon-side authoring rule**, and it
is deliberately **stricter than the boundary the fleet actually enforces** —
do not "relax" it to match the deployed allowlist.

**The deployed boundary is wider.** `install/templates/actions-permissions.json`
sets three _additive_ fields, not one list:

| Field | Value | Admits |
| --- | --- | --- |
| `github_owned_allowed` | `true` | every `actions/*` + `github/*` action |
| `verified_allowed` | `true` | **every action by a GitHub-verified creator** (`aquasecurity`, `docker`, `hashicorp`, …) |
| `patterns_allowed` | 3 patterns | `vladm3105/aidoc-flow-ci/*`, `actions/*`, `github/*` |

So a third-party action's fate at run-init depends on **who publishes it**:

- **Non-verified creator** (`gacts/gitleaks`, `lycheeverse/lychee-action`,
  `DavidAnson/markdownlint-cli2-action`) → **BLOCKED at run-init →
  `startup_failure`** — no logs, no API error (the message is web-UI-only;
  `actionlint` does NOT catch it). This silently bricked `secret-scan` (fixed
  v1.9.2), `links`, and `markdown-lint` (both fixed v1.9.4).
- **Verified creator** → **admitted, and runs.** It does not `startup_failure`.
  Any later failure (a bad tag, a runtime error) surfaces normally, with logs.

**Do not reason from "third-party ⇒ `startup_failure`" — that generalization is
false, and it misdiagnoses failures.** A verified-creator action that fails at
tag resolution produces `##[error]Unable to resolve action …`, which looks
nothing like the allowlist block and is not one. Read the repo's actual
`actions/permissions/selected-actions` before attributing any failure to the
allowlist.

The canon authoring rule stands on its own merits — it keeps canon's supply
chain to sources this workspace controls or GitHub itself owns, without relying
on GitHub's verification programme as a trust boundary. Widening canon to the
verified marketplace is a **decision to take deliberately**, not a conclusion to
reach from the fact that the deployed allowlist already permits it.

**Pattern:** install the tool directly in a `run:` step —

- **Static binary** (gitleaks, lychee): `curl` the pinned release, verify its
  SHA-256, run it. Prefer a **musl static build** where offered — the gnu
  build links against a recent GLIBC and fails on older self-hosted Debian
  ephemeral runners.
- **npm / language package** (markdownlint-cli2): use the allowlisted
  `actions/setup-node` (or `setup-python`, etc.) to guarantee the runtime,
  then install the pinned package in a `run:` step.

Map every consumer-controlled input to `env:` (never interpolate `${{ }}`
into the shell) so a hostile input value cannot inject an expression. When
authoring or reviewing a canon workflow, verify every `uses:` is on the **canon
authoring allowlist** above (`actions/*`, `github/*`,
`vladm3105/aidoc-flow-ci/*`) — NOT the wider deployed allowlist. A verified-
creator action passing run-init is not evidence that it belongs in canon.

Downloaded executables MUST be version-pinned and checked against a hard-coded
upstream SHA-256 before extraction or execution. Language-installed CI tools
MUST pin their top-level package version. Secret scanning MUST cover tests,
fixtures, examples, and baselines by default; a consumer may suppress a false
positive only with a narrow repository-owned rule rather than a directory-wide
canon exclusion. Canon CI validation MUST fail when shellcheck, yamllint, or
actionlint is unavailable, and actionlint MUST inspect embedded workflow shell.
Downloaded binaries MUST be installed into a job-scoped directory created with
`BIN_DIR="$RUNNER_TEMP/bin"; mkdir -p "$BIN_DIR"`, added to `$GITHUB_PATH`, and
verified by invoking the absolute path in the install step. Do not assume
`$HOME/.local/bin` exists and do not require `sudo` or `/usr/local/bin`; this
single pattern works on GitHub-hosted and self-hosted ephemeral runners.

`sync/check-standards-drift.sh` remains warning-only for scheduled observation,
but release and adoption validation MUST invoke `--strict`, which fails on
settings drift, stale pins, fetch errors, or controls that cannot be verified.

As of PLAN-015 (B2), `standards-drift` ALSO ships as a **`workflow_call`
reusable** (`.github/workflows/standards-drift.yml`) with opt-in consumer caller
templates (`install/templates/workflows/standards-drift.yml` + a `-private`
variant, `auto_install: false`, manifested with `visibility_variants`). A
consumer that installs the caller runs the drift check against its OWN repo on
schedule — the reusable fetches the script from the **adopted canon tag**, which
it reads from the consumer's OWN checked-out standards-drift caller pin (NOT
`github.workflow_ref`, which inside a `workflow_call` reusable is the caller's own
default-branch ref, not the pin; consumers do not vendor `sync/`). Canon's own
weekly self-check + the fleet pin audit moved
to `.github/workflows/standards-drift-self.yml`. **Branch protection is only
verifiable with an admin-scoped token — NOT a grantable `GITHUB_TOKEN` workflow
scope** — so under the default token that one control reports `warn_uncheckable`
(non-blocking unless `--strict`), never a false green; run with an admin PAT to
verify it.

#### 4.3a A consumer `.gitleaks.toml` MUST declare rules — canon proves the ruleset is non-empty

A gitleaks config that declares an `[allowlist]` but neither `[extend]
useDefault = true` nor its own `[[rules]]` has **zero rules**. It finds zero
secrets and exits 0: a **green required check that scans nothing**. The failure
is silent and inverted — a consumer wires `config-path` to quiet a red gate, the
gate goes green, and the repo now has _less_ scanning than the default it
replaced.

**Rule:** any `.gitleaks.toml` passed to `secret-scan.yml`'s `config-path` MUST
declare `[extend] useDefault = true` (keeping the consumer's `[allowlist]`
alongside it) or its own `[[rules]]`. `secret-scan.yml` enforces this: before
the real scan it runs the resolved config against a planted-credential canary
and fails the job if the config detects nothing. `validate-config: false` opts
out, and is defensible ONLY for a repo whose custom `[[rules]]` deliberately do
not cover AWS/GitHub credentials — record the reason on the caller.

**Scope of the guarantee — state it precisely.** The canary proves the ruleset
is **non-empty**. It does NOT prove the scan covers the repository: a config
with real rules plus a broad `[allowlist] paths` can still hide a live secret,
and canon does not override that — a repo-owned allowlist is the documented,
supported way to suppress a false positive. So "the canary passed" means "this
config can detect something", not "this gate would catch your leak". Both the
pass message and the workflow comment say so; do not paraphrase them into the
stronger claim.

**Three outcomes, not two.** gitleaks' exit codes do not separate these on
their own, so `secret-scan` reads the debug log as well:

| Outcome | Meaning | Job |
| --- | --- | --- |
| **passed** | the config detected the planted credential | continues |
| **INCONCLUSIVE** | the consumer's `[allowlist]` matches even a randomized canary path, i.e. it is effectively universal — rule-effectiveness is unprovable | continues, with a `::warning::` |
| **error** | the config is missing/malformed (`unable to load gitleaks config`), or it detected nothing at a randomized path | fails |

The INCONCLUSIVE case must **not** fail. A correct config whose allowlist
happens to match the canary would otherwise be red-gated, and the predictable
consumer response is `validate-config: false` — which disables the check
permanently and leaves the repo worse off than before it existed. A guard whose
false-positive drives people to switch it off is a net negative.

**Validate config BEHAVIOUR, never config TEXT.** Grepping the TOML for
`^\[extend\]` was measured (gitleaks 8.30.1) to fail in both directions: it
rejects the valid inline form `extend = { useDefault = true }`, which detects
correctly, and admits `[extend]` + `disabledRules` with no `useDefault`, which
detects nothing. Only executing the scanner distinguishes them.

**Canary fixtures must be verified-detectable.** The well-known
`AKIA…7EXAMPLE` key is allowlisted by gitleaks' own default ruleset and is NOT
detected even under `useDefault = true` — a canary built from it passes
rule-less configs and proves nothing. Build canary credentials by
concatenation at runtime so the workflow source carries no matchable secret,
and confirm the fixture fires under `useDefault` before trusting it.

#### 4.3b A gate MUST fail closed on a broken PARSE, not only a broken READ

A canon gate that reads a trust/config file MUST validate the parse before
acting on it. Reading bytes is not reading config.

**`jq`'s exit code does not mean what the calling shell usually assumes.**
`jq -e 'query'` exits **1** when the query yields false/null AND **4** (or
other non-zero) when the input does not parse. So

```bash
if ! jq -e --arg a "$AUTHOR" '(.trust.ai_review // []) | index($a)' "$CFG"; then
  exempt   # WRONG: fires on malformed JSON and on a renamed key, not just "author absent"
fi
```

treats _"this file is garbage"_ as _"this author is not allowlisted"_. Measured
on `composition.yml` (fixed 2026-07-17): a malformed `config.json` on the
default branch exited 4, satisfied `! jq -e`, and exempted **every author on
every PR** — including trusted ones — turning the sole App-approval enforcement
green fleet-wide. The read had succeeded; only the parse failed, and the
fail-closed contract only covered the read.

**Rule:** schema-validate first, treat validation failure as fail-closed, and
only then interpret a non-zero `jq` as the semantic answer:

```bash
if [ -n "$cfg_ok" ] && ! jq -e '(.trust.ai_review | type == "array")' "$CFG" >/dev/null 2>&1; then
  echo "::warning::config failed schema validation — fail-closed"
  cfg_ok=            # fall through to ENFORCE
fi
```

**Fail-closed has opposite polarity in different gates — state which you mean.**
In `composition.yml` fail-closed = **enforce** (refuse to exempt); in
`auto-merge-ai-prs.yml` fail-closed = `exit 0` (refuse to merge). Both are
"safe"; a reviewer who pattern-matches on the `exit` code alone will
misread one of them.

#### 4.3c `jq`'s array `contains()` substring-matches — use `index()` for names

`["no-skip-ai-review-here"] | contains(["skip-ai-review"])` is **true**: jq's
array `contains` does substring matching on string elements. For exact
membership — every label, author, and repo-name check — use
`index("x") != null`. Verified on jq 1.7 (2026-07-17): `composition.yml` used
`contains()` while `auto-merge-ai-prs.yml` used `index()`, so the two workflows
classified the same PR differently and a label named `skip-ai-review-exempt`
set the skip flag without anyone applying the real label.

### 4.4 `markdown-lint` config template (`install/templates/.markdownlint.json`)

The canon `.markdownlint.json` is the recommended ruleset consumers **copy**
(cli2 auto-resolves the consumer's own root copy; the reusable does not bake a
default). It disables three rules that fire almost entirely on legitimate
workspace doc styles rather than defects:

| Rule | Disabled because |
| --- | --- |
| `MD013` line-length | The 120-char limit fires on changelog data rows + long reference lines across every repo; enforcing it means hundreds of prose reflows. Disabled workspace-wide (founder decision 2026-07-12; accepts abandoning the line-length discipline). |
| `MD024` duplicate-heading | keep-a-changelog inherently repeats `### Added`/`### Changed` per release; `siblings_only` did not fully suppress it. |
| `MD036` emphasis-as-heading | Every `DECISIONS.md` uses `**Context**`/`**Decision**`/`**Consequences**`/`**Origin**` bold-labels by deliberate ADR style, not as headings. |
| `MD004` unordered-list style | **Pinned to `dash`** (not disabled) — without a pinned style `--fix` normalizes bullets to the unconventional `+`; pinning `dash` gives conventional `-` bullets consistently. (PLAN-018 FT-34.) |

`MD033` (inline HTML, allowlisted elements), `MD040` (code-fence language),
`MD056` (table columns), and the rest stay **enforced** — those are genuine
cleanups a consumer fixes when graduating `fail-on-findings: false → true`
(PLAN-007 W3 / FT-11). This is a **template-only change**: no reusable body
change, no new `ci/` tag — do NOT bump `VERSION` for it (that would falsely flag
every pinned consumer as stale via `check-pin-currency.sh`). Consumers adopt it
by re-copying the config in their own graduation PR.

**Canon dogfoods this config (PLAN-018 FT-34).** This repo carries its own root
`.markdownlint.json` (identical to the shipped template) and runs
`self-markdown-lint.yml` as a **blocking** gate on every PR — canon's docs were
brought into full conformance in the same change. So a regression in the
`markdown-lint` reusable, or a new non-conforming doc, fails canon's own checks
rather than shipping to the fleet unseen.

## 5. Labels — canonical taxonomy

The label taxonomy aligns with the **OPS-0065 diff-class dispatch table**
in `operations/CLAUDE.md`, so path-based labels reinforce which
sub-agents should be dispatched pre-push. Existing operations `.github/
labeler.yml` pattern + framework labeler config are the reference
shapes.

### 5.1 State labels (ai-review state machine — required)

| Label | Emitted by | Semantics |
| --- | --- | --- |
| `ai:review-passed` | `ai-review.yml` | verdict = APPROVED; auto-merge armed |
| `ai:review-changes` | `ai-review.yml` | verdict = CHANGES_REQUESTED; blocks merge |
| `ai:review-infra-error` | `ai-review.yml` | Reviewer infrastructure failure — no verdict produced (not a code finding; re-run). `ci/v2.1.1`+ |
| `ai:human-review-required` | `ai-review.yml` trust job | Fork PR or non-allowlisted author |
| `skip-ai-review` | Operator (manual) | Re-fire the gate; carry-forward safe |

Every tier that adopts `ai-review.yml` MUST create these 5 labels first
(the workflow does not create them). The three verdict-outcome labels
(`review-passed` / `review-changes` / `review-infra-error`) are mutually
exclusive — the gate clears the other two whenever it sets one.

### 5.2 Diff-class labels (path-based, from OPS-0065 table)

Labels aggregate ≥1 diff class from the canonical diff-class-map at
`operations/.claude/agents/review-prompts/diff-class-map.json`. Path
globs may overlap by design — a diff touching `.claude/agents/*.md`
gets both `governance` (diff-class: governance-docs-root +
agents-and-skills; dispatch = governance-docs review) and `agents`
(dispatch = agents-and-skills review); both diff-class agent sets fire
per OPS-0065.

| Label | Path glob | OPS-0065 diff class(es) |
| --- | --- | --- |
| `governance` | `CLAUDE.md`, `ops/DECISIONS.md`, `.claude/agents/*.md`, `.claude/skills/*.md`, `.github/ai-review/**` | governance-docs-root + agents-and-skills + ai-review-config |
| `docs` | `docs/**`, `README.md`, `CHANGELOG.md`, `ops/HANDOFF.md` | docs |
| `workflows` | `.github/workflows/**` | workflow-yaml |
| `scripts` | `scripts/**` | scripts |
| `agents` | `.claude/agents/**`, `.claude/skills/**`, `.claude/workflows/**` | agents-and-skills + workflow-js |
| `tests` | `tests/**` | tests |
| `config` | `Dockerfile`, `pyproject.toml`, `requirements*.txt`, `package*.json`, `uv.lock`, `.pre-commit-config.yaml` | deps-config |
| `plans` | `ops/iplans/IPLAN-*.md`, `plans/PLAN-*.md` | plans (verified-planning) |

Tier ignores diff-class label existence — every non-paused repo should
have them. Adoption via `labeler.yml` reusable + `.github/labeler.yml`
config maps the paths above.

### 5.3 Area labels (tier-specific; optional)

- `platform: hermes`, `platform: claude` — framework-specific
- `sub-plan: PLAN-XXX` — iplan-runner / iplanic
- `dependencies` — Dependabot PRs
- `security` — security-tagged issues/PRs

## 6. Dependabot (`.github/dependabot.yml`)

Every non-paused repo ships `.github/dependabot.yml`. Ecosystems declared
based on repo content:

| Ecosystem | When applicable | Schedule | Group |
| --- | --- | --- | --- |
| `github-actions` | Every repo | weekly | `github-actions` |
| `pip` | Any Python code | weekly | `python-runtime` (patch+minor) |
| `npm` | Any Node/JS code | weekly | `javascript-runtime` (patch+minor) |
| `docker` | Any Dockerfile | weekly | `docker-baseimages` |
| `gitsubmodule` | Umbrella only | weekly | `submodules` |

**Auto-merge policy** — Dependabot PRs pass through the standard
`ai-review.yml` + `composition.yml` chain and auto-merge on green per
`auto_merge.repos` allowlist (opt-in per repo). Governance-tier repos
do NOT auto-merge dependabot PRs (human-merge only).

**Grouping** batches minor/patch bumps into single PRs to reduce CI
churn; major bumps get individual PRs (breaking-change scrutiny).

Template ships in `install/templates/dependabot.yml` (PR-B).

## 7. CODEOWNERS

Every non-paused repo ships `.github/CODEOWNERS` mapping path patterns
to reviewer routing. Canonical shape:

```text
# Global default: founder
*                                       @vladm3105

# Security-sensitive paths (double-review)
.github/**                              @vladm3105
.github/workflows/**                    @vladm3105
.github/ai-review/**                    @vladm3105

# Governance surfaces
CLAUDE.md                               @vladm3105
ops/DECISIONS.md                        @vladm3105
docs/REPO_STANDARDS.md                  @vladm3105

# Docs (tier-specific override — product-code repos let AI-review own docs)
docs/**                                 @vladm3105
```

**Adoption:** governance + umbrella tiers require CODEOWNERS review
(branch-protection setting §2); product-code + ops-private tiers ship
CODEOWNERS but do not gate merges on it (defer to `ai-review.yml` +
`composition.yml` for the substantive review). v2 evaluation: enforce
CODEOWNERS review on all tiers.

**Single-owner phase:** all patterns currently route to `@vladm3105` —
the workspace is a single-owner phase. v2 will fan out per-domain
reviewers (e.g., docs → docs-savvy, workflows → security-savvy) as the
team grows.

Template ships in `install/templates/CODEOWNERS.template`. The owner
handle is parameterized as `${CODEOWNER_HANDLE}` (default `vladm3105`);
`install.sh --codeowner <handle>` substitutes it, and the drift check
normalizes owner identity before comparing so a consumer's own handle is
not read as drift (§16.7).

## 8. PR template

Every non-paused repo ships `.github/pull_request_template.md`.

Contents (canonical):

- Summary section
- Files touched (self-check for OPS-0061 ≤3-surface rule)
- Multi-agent review section (naming dispatched sub-agents + verdict — OPS-0069 audit-trail phrase belongs in the COMMIT MESSAGE, not the PR body; PR template reminds authors)
- Cross-references (OPS-NNNN, IPLAN-NNNN, related PRs)
- Test plan (checkboxes)
- Governance-tier callout (🟡/🔴 exceptions per OPS-0062)

Template ships in `install/templates/pull_request_template.md` (PR-B).

## 9. Merge & branch-cleanup settings

Repo-level `Settings → General → Pull Requests` block. Uniform across
all tiers.

| Setting | All tiers |
| --- | --- |
| Allow merge commits | ❌ Disabled |
| Allow squash merging | ✅ Enabled (default) |
| Allow rebase merging | ❌ Disabled |
| Automatically delete head branches | ✅ Enabled |
| Allow auto-merge | ✅ Enabled |
| Squash commit title | PR title |
| Squash commit message | PR body |

**Umbrella note:** the umbrella tier additionally requires `--admin`
merge and enforces signed commits via the branch-protection layer (§2),
independent of the merge-settings block above.

**Rationale:** squash-only keeps `main` linear; delete-on-merge prevents
stale-branch accumulation. Rebase-merge is disabled because it rewrites
PR commits onto base after review — the App's APPROVED review is
anchored to the pre-merge HEAD SHA (verified in `ai-review.yml`
`github.event.pull_request.head.sha` + `composition.yml`'s
`commit_id == HEAD_SHA` filter), and rebase-merge splits one PR into
multiple main-branch commits that dissociate from that review anchor,
complicating traceability. Squash-merge keeps one merge commit per PR
= one-to-one with the reviewed HEAD.

## 10. `.gitignore` + `.gitattributes` baseline

Every non-paused repo ships baseline versions.

### 10.1 `.gitignore` baseline

Workspace-common ignores. Repo-specific ignores extend (never replace)
the baseline.

```gitignore
# AI-workspace scratch
.claude/
.review/

# Transient
tmp/
scratch/

# Env / secrets
.env
.env.*
!.env.example

# Python
__pycache__/
*.pyc
.venv/
.pytest_cache/
.mypy_cache/
.ruff_cache/
dist/
build/
*.egg-info/

# Node
node_modules/

# OS / editors
.DS_Store
.vscode/
.idea/
Thumbs.db
```

### 10.2 `.gitattributes` baseline

Enforce LF line endings across contributors (Windows contributors get
platform-native on checkout via `text=auto`; committed content is LF).

```gitattributes
* text=auto eol=lf
*.png binary
*.jpg binary
*.pdf binary
```

Templates ship in `install/templates/.gitignore.template` +
`install/templates/.gitattributes.template` (PR-B).

## 11. Rollout — coordinated-merge-window pattern

Rolling out the canon to 10 workspace repos is exactly the T-C
coordinated-merge-window pattern from
`operations/docs/CROSS_REPO_PLAYBOOKS.md`. Sequence:

1. **PR-A merges first** — this doc + index entry + CHANGELOG.
2. **PR-B merges second** — templates + `install/apply-standards.sh`.
3. **PR-C merges third** — server-side enforcement JSONs + drift check.
4. **Per-repo compliance PRs** — one PR per repo touching the doc-shipped
   surfaces (CODEOWNERS, PR template, dependabot.yml, .gitignore/
   .gitattributes, labels sync). Rolled out per tier priority:
   1. **Governance** (framework, iplan-standard) — highest blast radius.
   2. **Ops-private** (operations, business, iplanic) — internal-only.
   3. **Product code** (iplan-runner, engramory, aidoc-flow-ci) — most
      of these also need `WORKFLOWS.md` §2.1 gaps closed alongside.
   4. **Bootstrap** (none currently — all repos have been graduated).
   5. **Umbrella** (aidoc-flow) — apply last; special-case per OPS-0062.
5. **Server-side settings** (branch protection, security, Actions
   permissions) apply via `--apply` mode as a SEPARATE pass AFTER each
   tier's per-repo compliance PR (step 4) has merged. The per-repo PR
   ships the content surfaces (CODEOWNERS, PR template, dependabot.yml,
   .gitignore/.gitattributes, labels-sync via `gh api`); the follow-up
   `--apply` invocation flips the server-side knobs. Founder runs
   `bash install/apply-standards.sh --apply <owner/repo>` per repo (F5
   blast-radius per REPO_ONBOARDING.md — server-side changes stay
   founder-manual).

## 12. Compliance evidence — where each rule's audit-trail lives

| Requirement | Evidence location |
| --- | --- |
| Workflow adoption | [`WORKFLOWS.md`](WORKFLOWS.md) §2 matrix |
| CI activation (reviewer App install, allowlist) | `operations/docs/REPO_ONBOARDING.md` Steps 1-4 |
| Branch protection | GitHub API — verify via `bash install/apply-standards.sh --check` (PR-B) |
| Security settings | Same as branch protection |
| Actions permissions | Same |
| Labels | Same |
| Dependabot | Presence of `.github/dependabot.yml` + `--check` verifies contents |
| CODEOWNERS | Presence of `.github/CODEOWNERS` + `--check` |
| PR template | Presence of `.github/pull_request_template.md` + `--check` |
| Merge/cleanup | GitHub API — `--check` |
| `.gitignore` / `.gitattributes` | Presence + `--check` compares against baseline |
| Self-review mechanical enforcement (§14) | Presence of `scripts/pre_push_check.sh` + `.pre-commit-config.yaml` block with canon marker; `.github/workflows/audit-trail-check.yml` caller (except bootstrap/paused); OPS-0069 phrase in every push commit range |

## 13. Cross-references

- [`WORKFLOWS.md`](WORKFLOWS.md) — workflow registry (16 reusables +
  per-repo applicability matrix)
- [`architecture.md`](architecture.md) — reusable-workflow model + trust
  flow
- [`multi-project-guide.md`](multi-project-guide.md) — new-project
  onboarding flow
- [`overrides.md`](overrides.md) — 3 override modes
- [`security.md`](security.md) — threat model + secrets
- [`../LABELS.md`](../LABELS.md) — pre-existing label conventions
  (label separators + runner-label namespace)
- [`BRANCHING.md`](BRANCHING.md) — canonical branch naming, lifecycle,
  update, merge, cleanup, and enforcement boundary
- `aidoc-flow-operations/docs/REPO_ONBOARDING.md` — 4-step CI
  activation checklist
- `aidoc-flow-operations/docs/CROSS_REPO_PLAYBOOKS.md` — T-C
  coordinated-merge-window pattern (used by §11 rollout)
- `aidoc-flow-operations/.github/ai-review/config.json` — trust
  allowlist + `auto_merge.repos` allowlist
- `aidoc-flow-operations/ops/DECISIONS.md`:
  - OPS-0061 Rule-1 (≤3 doc surfaces per PR)
  - OPS-0062 (auto-merge default; umbrella `--admin`)
  - OPS-0065 (multi-agent diff-class dispatch — informs label taxonomy §5.2)
  - OPS-0068 (reviewer App install permissions)
  - OPS-0069 (mandatory pre-push audit trail)

## 14. Self-review mechanical enforcement

Every non-paused repo ships an author-side pre-push hook that verifies
the OPS-0069 audit-trail phrase in every push. The check is
belt-and-suspendered by a CI reusable that re-verifies the phrase on
every PR at merge time.

### 14.1 Local hook

**Canonical script:** `install/templates/pre_push_check.sh` (this repo).
Consumer install path: `scripts/pre_push_check.sh`. Wired via
`.pre-commit-config.yaml` with
`default_install_hook_types: [pre-commit, pre-push]`; canonical fragment
in `install/templates/pre-commit-hook-block.yaml`.

**Scope (5 checks):**

1. `markdownlint` on changed `.md` files (skipped if not installed).
2. `yamllint` on changed `.yml`/`.yaml` files (skipped if not installed).
3. `actionlint` on changed `.github/workflows/*.yml` (skipped if not
   installed).
4. `shellcheck` on changed `.sh` files (skipped if not installed).
5. OPS-0069 audit-trail phrase check (`Multi-agent self-review per
   OPS-0065` OR `Self-review skipped per founder OK`) in
   `@{upstream}..HEAD` (or `origin/main..HEAD` on first push).

**No env-var runtime opt-out** — matches OPS-0069's removal of
`SKIP_LOCAL_AI_REVIEW`. Only bypass path: `git push --no-verify` (git
primitive; caught by §14.2 CI check).

**Exemption logic (local hook implements 2 of 3):**

- ALL commits in range authored by `dependabot[bot]`, `renovate[bot]`,
  or `github-actions[bot]` → check SKIPS (parity with CI; bots rarely
  push via the local hook path).
- ALL commits in range have subject line starting with `Revert "` →
  check SKIPS (mixed ranges still require the phrase).
- Two-signal `skip-audit-trail` label + `[skip-audit-trail]` body
  marker → **CI-side only** (git has no PR-label context at push time).

**Repo-specific extras** (e.g., verified-planning `check_plan.py`,
operations classify-parity) live in a consumer wrapper
`scripts/pre_push_check_<repo>.sh` that sources canon + adds its own
checks. Wrapper preserves the canon's `set -uo pipefail` + rc-accumulator
pattern. See PLAN-002 §4.8 for the operations wrapper reference.

### 14.1a The canon fragment MUST carry commit-stage hooks

The `pre-commit` reusable runs `pre-commit run --all-files` with **no
`--hook-stage`** when its `run-stage` input is empty (the default), and
`pre-commit` then selects the **`pre-commit` stage**. So a config whose only
hooks are `stages: [pre-push]` matches **zero** hooks, prints nothing, and exits
**0** — a green check that inspected nothing.

Until PLAN-018 F3 the canon fragment was exactly that: one `pre-push`-staged
local hook. Because `call / Lint / format / security hooks` is a required check
on every tier that has required checks (§16.9), **a fresh adopter's only
required gate was vacuous by construction**. Repos with a pre-existing rich config
(`operations`) masked it; a cold start could not.

The fragment therefore ships commit-stage hooks — `check-yaml`,
`end-of-file-fixer`, `trailing-whitespace` from `pre-commit/pre-commit-hooks` —
and canon self-adopts them (Wave 0). Two consequences, stated rather than
discovered later:

- **This is canon's first third-party `rev`.** The fragment was `repo: local`
  only: no network, no upstream to track. Accepted because the alternative is
  canon maintaining its own linters. The rev has **no automated bump path** —
  neither canon's nor the consumer template's `dependabot.yml` covers a
  `pre-commit` ecosystem (FT-35).
- **The merge de-dups by repo URL, not whole-entry equality.** An adopter
  already using `pre-commit-hooks` at a different `rev` is structurally unequal,
  so the previous rule appended a second entry for the same repo. On a URL
  collision `install.sh` **keeps the consumer's entry and its rev** and reports
  the collision, naming any canon hook ids they lack — silently merging would
  overwrite a deliberate rev, silently skipping would hide a missing
  canon-required hook. The de-dup is for **coherence, not validity**:
  `pre-commit` does _not_ reject duplicate entries (verified on 4.5.1 —
  duplicate URLs at differing revs, and even duplicate hook ids, all validate
  and run), and four sibling repos ship two `repo: local` blocks today.
- **`local` and `meta` are exempt from URL de-dup.** They are pseudo-repos, not
  identities, and `pre-commit` permits any number of them. Keying de-dup on them
  treats a consumer's own `local` block as a collision and never installs
  `aidoc-flow-pre-push` — dropping the OPS-0069 audit-trail check, permanently,
  because the `CANON:` marker makes every later `install.sh` run a no-op. Any
  future change to this de-dup rule MUST preserve the exemption;
  `tests/test_precommit_merge.sh` asserts it.
- **The pin is a frozen SHA, not the tag.** `rev:` carries the commit SHA with a
  `# frozen: vX.Y.Z` trailer — the `pre-commit autoupdate --freeze` format. A
  plain `pre-commit autoupdate` (no `--freeze`) silently rewrites it back to a
  mutable tag, which is a downgrade: `pre-commit` `pip install`s the cloned
  tree, so the upstream build backend executes at install time on developer machines
  and on CI runners, and the ephemeral pool is cold every run (the reusable has
  no cache step) — a moved tag would reach the whole fleet within one CI cycle.
  **Bump with `--freeze`.**
- **A consumer whose `repo: local` already defines `aidoc-flow-pre-push`** — the
  wrapper pattern this fragment itself documents, pointing at
  `scripts/pre_push_check_<repo>.sh` — keeps their entry untouched. The `local`
  pseudo-repo de-dups by hook `id`, so canon's copy is skipped entirely and the
  config carries exactly one hook with that id. (Before FT-32 the rule was
  whole-entry structural equality, which appended canon's alongside and required
  removing it by hand.)
- **Three residual DRIFT classes `apply-standards.sh --check` cannot resolve.**
  It subset-checks the consumer's file against the canon fragment
  line-for-line, so anything the merge deliberately declines to overwrite
  reports DRIFT indefinitely: (a) a consumer's **kept `rev`**, which the merge
  just promised to keep; (b) a wrapper hook's own `name:` / `entry:` lines,
  preserved by the id-level de-dup above; (c) a consumer writing
  `default_install_hook_types` in **flow style** (`[pre-commit, pre-push]`),
  which is semantically canon but not a verbatim line match. All three are
  per-repo decisions for the rollout worklist — do **not** "fix" them by
  overwriting a consumer's pin or wrapper.

**Detecting this class in general is deliberately NOT on the gating path.**
`pre-commit run` exits 0 and prints nothing whether zero hooks matched or all
hooks passed, so the only in-reusable implementation is an output-emptiness
heuristic — and it would flip any consumer running `run-stage: manual` with no
`manual` hooks from pass to fail on re-pin. The detector belongs operator-side
(`install.sh`, the wizard preflight, the release checklist); moving it into the
reusable is a separate proposal needing its own decision (FT-31).

**Already-adopted consumers DO now receive fragment changes (FT-32, resolved).**
The `CANON:` marker is **versioned** (`# CANON: aidoc-flow-ci pre_push_check vN`)
and bootstrap **re-merges** when a consumer's `vN` is older than canon's, then
stamps canon's. `--update` still excludes `.pre-commit-config.yaml` and `--apply`
still writes no content files — `install.sh` (re-run) is the single refresh path,
which is what `manifest.json`'s "re-run install.sh to refresh those" always
claimed and, before FT-32, was false for this file. **Bump `vN` whenever the
fragment changes** — necessary, though not on its own sufficient (see the limit
below); without the bump, adopted consumers stay frozen.

**The refresh delivers ADDITIONS ONLY.** The re-merge never overwrites a
consumer entry, which is what makes it safe to run unattended — and is also its
limit:

| fragment change | reaches an adopted consumer? |
| --- | --- |
| new `repo:` block | yes |
| new hook id in canon's `local` block | yes |
| `rev` bump on a repo they already declare | **no** — `WARN` only |
| new hook id inside a repo they already declare | **no** — `WARN` only |
| change to a hook id they already carry (`entry`, `stages`, `args`) | **no** — id de-dup skips it |

A partial merge still stamps canon's `vN` (it must, or the run would never
converge), so `install.sh` will not revisit the file: it prints the unapplied
lines and they stay unapplied until merged by hand. On the current fleet this
is load-bearing — four repos declare `pre-commit-hooks` at a **mutable
`rev: v5.0.0`**, and the refresh cannot move them to canon's SHA pin. Treat
those as named per-repo items on the rollout worklist, not as delivered.

Two operational notes for a refresh PR: the merge **round-trips the whole
file**, so the diff shows re-indentation well beyond the added lines; and it
requires `ruamel.yaml` — under the `pyyaml` fallback the round-trip **strips
the consumer's comments**. Adding canon's lines flips repos to `DRIFT` under
`apply-standards.sh --check`, which is **expected signal and the rollout
worklist**, not breakage.

### 14.2 CI belt-and-suspenders

**Reusable workflow:** `.github/workflows/audit-trail-check.yml` (this
repo). Same `workflow_call` pattern as `ai-review.yml` / `composition.yml`.
Consumer callers use `jobs.call:` → check-name renders as `call / verify`.

**Availability:** ships in **PLAN-002 PR-U3** (not yet available in this
release; §14.1 local hook ships in PR-U1). Consumers wire callers +
required-status-check entries only after PR-U3 lands. Full rollout via
per-repo Wave PRs per §5.5 of PLAN-002.

**Range:** `${{ github.event.pull_request.base.sha }}..${{
github.event.pull_request.head.sha }}` on `pull_request` events. Reusable
uses `fetch-depth: 0` (prevents fork-PR false-pass with default depth-1
checkout).

**Push events NOT covered** by the reusable (direct pushes to protected
branches require `--admin` and are governed by OPS-0062; local hook is
the enforcement point for author-side pre-push).

**Exemption logic** (CI-side identity-verified; some divergence from
local hook by design):

- **CI exemption 1 — PR opened by trusted bot:** verified via GitHub's
  authoritative `pull_request.user.type == 'Bot'` +
  `pull_request.user.login` allowlist (`dependabot[bot]`,
  `renovate[bot]`, `github-actions[bot]`). Commit `%an` is NOT used
  CI-side — attacker-spoofable on fork PRs. Local hook uses `%an`
  because it enforces author discipline, not authorization.
- **CI exemption 2 — revert-only: NOT exempted CI-side.** Subject
  prefix `Revert "` is trivially spoofable + unverifiable at the gate;
  CI requires the phrase on revert commits too. Local hook keeps this
  exemption for developer convenience.
- **CI exemption 3 — two-signal override:** `skip-audit-trail` PR label
  AND `[skip-audit-trail]` in commit body → check SKIPS. Label
  membership checked via `jq -e 'index("skip-audit-trail") != null'`
  (exact match; no substring false-positive).
- Otherwise: at least one non-exempt commit must carry an OPS-0069 phrase.

**Fail-closed on infrastructure failures:** unreachable `BASE_SHA` /
`HEAD_SHA` after fetch, or empty commit range (`git rev-list --count`
= 0), or unsupported event (not `pull_request` / `pull_request_target`)
→ `::error::` + exit 1. Silent PASS on the load-bearing gate is
exactly the failure mode this workflow prevents.

### 14.3 Tier applicability

| Tier | Local hook | CI reusable | Required-check `call / verify` in `contexts` |
| --- | --- | --- | --- |
| Governance | ✅ | ✅ | ✅ |
| Product code | ✅ | ✅ | ✅ |
| Ops-private | ✅ | ✅ | ✅ |
| Umbrella | ✅ | ✅ (advisory) | ❌ — umbrella has `required_status_checks: null` by design (§2); do not add |
| Bootstrap | ✅ | ❌ — pending CI adoption (§4.5 of PLAN-002); caller file omitted from `.github/workflows/` | ❌ |
| Paused | ❌ | ❌ | ❌ |

## 15. Change log

- 2026-07-07 — Initial canon codified per PLAN-001 §5.1.
- 2026-07-08 — §14 added (self-review mechanical enforcement); §2 amended
  to add `call / verify` to non-paused non-bootstrap non-umbrella tier
  `contexts`; §12 amended with new compliance row. Per PLAN-002 PR-U1.
- 2026-07-08 — §16 added (project governance file canon). Per PLAN-003
  PR-V1.

## 16. Project governance file canon

Every non-paused, non-bootstrap workspace repo declares its **project
governance files** — the 6 durable surfaces used for cross-session
continuity — in its `CLAUDE.md` under a canonical `## Per-repo
governance` H2 section. This canon does NOT dictate ONE path per file
kind; each repo picks + declares its own paths. Canon enforces
**presence + declaration + consistency**, not a fixed path.

Full design + parser contract lives in `plans/PLAN-003_project-
governance-canon.md`. Rules below are the durable summary consumers
must follow.

### 16.1 Required surfaces (6)

Every non-paused, non-bootstrap repo declares these 6 surfaces:

| Surface | Purpose |
| --- | --- |
| Live HANDOFF | Cross-session resume point. Read at session start; refresh at milestones. |
| TODO / backlog | Durable backlog of unresolved work items too small for a plan. |
| Decisions log | ISO-stamped append-only record of load-bearing decisions. |
| Plans | Per-initiative plans directory. |
| Changelog | Release-history record. |
| Roadmap | Forward-looking phase view. |

A surface may be **intentionally omitted** by declaring `Not adopted —
<one-line rationale>` in its table cell. The rationale must be
durable — not "TODO adopt later" — and must justify why the surface
isn't needed for this repo (e.g., business `Changelog | Not adopted —
DECISIONS.md + git commit log serve as changelog per policy`).

### 16.2 Additional rows (repo-specific)

A repo with multiple surfaces of the same conceptual kind (e.g.
framework's dual DECISIONS log at `plans/DECISIONS.md` + nested
`framework/governance/DECISIONS.md`; framework's per-package CHANGELOGs
at `platforms/*/CHANGELOG.md`; engramory's dual ROADMAP) declares
each as an ADDITIONAL row below the required 6 in the same table
shape. Additional rows are read + verified by the parser but not
counted toward required-row completeness.

Multi-value cells (comma-separated paths in one row) are NOT
accepted — one row per surface preserves the distinct label + rationale.

**Wrong (rejected by parser):**

```text
| Live HANDOFF | HANDOFF.md, ops/HANDOFF.md |
```

**Right (additional row per §16.2):**

```text
| Live HANDOFF | HANDOFF.md |
| _(additional rows below — optional)_ | |
| Ops-side HANDOFF | ops/HANDOFF.md |
```

**Parser precedence when a repo has a required row with a non-standard
label AND an additional row with the canonical token:** required rows
come FIRST in the table (in the canonical 6-row order); additional
rows sit below the "additional-rows" divider (or simply below the
required 6). The parser reads top-down and matches the FIRST row whose
label contains the canonical token as the required row; subsequent
same-token matches are additional-rows. Consumers keep the required 6
in canonical order at the top to avoid ambiguity.

### 16.3 CLAUDE.md canonical template

Consumers author their `CLAUDE.md` from
`install/templates/CLAUDE.md.template` (per this repo's install
tooling). The template ships with placeholder markers
(`<REPO_FRIENDLY_NAME>`, `<REPO_PURPOSE_ONE_LINER>`, etc.) that
consumers substitute per repo. Existing consumers retrofit the
`## Per-repo governance` section; the parser accepts variance in
heading tail (`— this repo owns its own continuity` suffix) and
row-label form (`Plans (IPLANs)`, `Live HANDOFF`, etc. via
canonical-token substring match).

### 16.4 Consistency check (`--check-governance`)

`install/apply-standards.sh --check-governance` mode (ships in PLAN-003
PR-V2) reads each consumer's `CLAUDE.md` `## Per-repo governance`
table, parses declared paths, and verifies each declared path exists
on disk (or the cell is a valid "Not adopted —" line). Governance-canon
compliance is warning-only in `--check` mode (same discipline as the
other REPO_STANDARDS rules); consumers CAN opt out or delay but the
warning surfaces the drift.

### 16.5 Additional file templates

`install/templates/` also ships minimal skeletons for the 4 governance
files consumers may need to create:

- `HANDOFF.md.template`
- `DECISIONS.md.template`
- `ROADMAP.md.template`
- `plans-README.md.template`

Consumers unpack the templates only when creating a fresh governance
surface; existing surfaces stay in place.

### 16.6 Rollout waves

Per PLAN-003 §5.5. Wave 0 = canon-home (aidoc-flow-ci) self-adopts in
PR-V1 (bundled with canon shipment). Waves 1-4 = one PR per
non-paused repo. Wave 5 = umbrella. Waves execute sequentially; within
a wave, alphabetical order is fine.

### 16.7 Template parameterization (de-branding)

The templates `install.sh` writes carry the aidoc-flow workspace's own
identity only as **defaults**. A different org overrides them at install
time without editing the canon, via literal placeholders substituted as
the template is fetched (PLAN-004 D2 + FT-7):

| Placeholder | Template | `install.sh` flag | Default |
|---|---|---|---|
| `${CODEOWNER_HANDLE}` | `config.json.template` (`trust.ai_review`, `governance.code_owners`) + `CODEOWNERS.template` (all owner routes) | `--codeowner` | `vladm3105` |
| `${CANON_OPERATIONS_URL}` | `CLAUDE.md.template` (operations canon links) | `--canon-operations-url` | `../operations` |
| `${CANON_CI_URL}` | `CLAUDE.md.template` (CI canon link) | `--canon-ci-url` | `../aidoc-flow-ci` |

Discipline for this mechanism:

- **Defaults are byte-identical.** Omitting every flag MUST reproduce the
  pre-parameterization template exactly, so existing consumers see no
  drift. A round-trip test guards this.
- **Values are data, never code.** `install.sh` passes flag values as
  argv to a `python3` literal `str.replace`, never interpolating them into
  a shell or regex — a hostile handle/URL cannot inject (same discipline
  as PLAN-004 C2's env-var indirection for consumer input). `--codeowner`
  is additionally validated against the GitHub handle grammar before
  substitution, since it lands in the `config.json` `trust.ai_review`
  security allowlist inside a JSON string.
- **Fail closed on a surviving placeholder.** After substitution,
  `install.sh` greps ONLY the three declared placeholder names; any
  survivor aborts the install rather than committing a half-branded file.
  It does not blanket-scan `${...}` (a consumer may legitimately carry
  shell-style `${VAR}` text elsewhere).
- **`CODEOWNERS` uses an owner-normalized drift check (FT-7).** CODEOWNERS
  is the one de-brand template that `apply-standards.sh` drift-checks by
  content (config.json is drift-exempt; CLAUDE.md drift is a structural
  governance-table parse, §16.4). Because each consumer substitutes its own
  `--codeowner` handle, WHO owns is consumer-specific and is **not** canon —
  the path-routing **structure** is. So the check (`codeowners_check`)
  normalizes every `@owner` token to a fixed `@OWNER` sentinel on both the
  fetched template and the consumer file, then diffs: it catches
  added/removed/reordered rules and extra/missing owner tokens while
  ignoring handle identity. A de-branded consumer therefore does not read as
  drift against the `${CODEOWNER_HANDLE}` placeholder template, and a
  consumer that still hardcodes `@vladm3105` continues to pass. `install.sh`
  also installs `.github/CODEOWNERS` (substituted, preserve-if-exists), so a
  fresh consumer gets a correctly-owned file for its tier. **Owner _identity_
  is intentionally out of drift scope:** the check cannot flag an owner
  pointed at a wrong/typo'd or malicious handle (the canon has no correct
  per-consumer handle to compare against). That is backstopped by branch
  protection `require_code_owner_reviews` (which enforces whoever is listed —
  and `.github/**` routes to the owner, so the CODEOWNERS file is itself
  owner-gated) plus the consumer's audit log, not by canon-parity drift.

### 16.8 Canonical surface manifest + update path

`install/templates/manifest.json` is the machine-readable index of every
1:1 `template → consumer-file` mapping (per-file: consumer path, source
template + per-visibility variants, de-branding `substitute` placeholders,
and a `safe_to_replace` flag). It is the single list that `install.sh
--update` walks; drift tooling migrates onto the same list so the surface
set lives in one place instead of hardcoded per-script loops. Canon **rules**
stay in this document; the manifest is only the index (per PLAN-004 §6 R6).

- **`install.sh --update <owner/repo>`** re-fetches each surface the consumer
  already has, substitutes placeholders, diffs vs local, and — interactively
  — prompts `[k]eep / [r]eplace / [d]iff-only`; `--non-interactive` replaces
  only `safe_to_replace` files (the mechanical workflow files +
  `dependabot.yml`) and keeps policy/governance files plus the
  consumer-customized `codeql.yml`. See `docs/UPDATE_GUIDE.md`.
- **Out of the file-diff walk:** `labels.json` (a GitHub-API surface) and
  `.pre-commit-config.yaml` (canon block MERGED, not replaced). Re-run
  bootstrap `install.sh` to reconcile those.

### 16.9 Bootstrap callers name their template explicitly — canon ships three naming shapes

`install.sh`'s bootstrap path installs its default callers by naming each
template **literally**. It must never derive the name from a pattern such as
`workflows/<workflow>-<visibility>.yml`, because canon does not ship one naming
convention — it ships three:

| Caller template | public template | private template |
| --- | --- | --- |
| `ai-review` (bootstrapped) | `workflows/ai-review.yml` | same file (no variants — §4.1: one protected template, a visibility flip is a no-op) |
| `composition` (bootstrapped) | `workflows/composition-public.yml` | `workflows/composition-private.yml` |
| `pre-commit` (bootstrapped) | `workflows/pre-commit.yml` | `workflows/pre-commit-private.yml` |

The bootstrap set is exactly the `auto_install: true` workflow entries in
`manifest.json` (§16.8) — `ai-review` + `composition` + `pre-commit`.

**`pre-commit` is bootstrapped unconditionally, not gated on `--tier`**, and is
the one deliberate exception to `auto_install: false` for every non-bootstrap
surface. It emits `call / Lint / format / security hooks`, a required status
check on **every tier that has required checks at all** — all but umbrella,
which deliberately has none — and the bootstrap tier's _only_ required context. A
required check with no producing workflow does not fail; it never reports, so
armed protection pins every PR on _"Expected — Waiting for status to be
reported"_ indefinitely. `TIER` defaults to empty and the documented one-liner
passes none, so a tier-gated install would leave the primary documented path
without a producer. On umbrella the installed caller is advisory — additive, not
harmful.

`pre-commit` is **asymmetric**: its public variant is the bare name, so an
implementer generalising from `composition` writes `pre-commit-public.yml` — a
file that does not exist — and breaks every public adopter. This is exactly how
the derived form failed for `ai-review`: it requested
`workflows/ai-review-private.yml`, deleted when the AI flows were unified, and
the `|| exit 1` at the call site aborted every cold-start install before
`config.json`, CODEOWNERS, `CLAUDE.md`, `pre_push_check.sh`, the pre-commit
merge, and the label set. Canon had no cold-start exerciser, so it shipped
undetected across nine releases.

Two constraints follow, both enforced by `tests/test_install.sh`:

- **The template path is a literal at the `fetch_template` call site.** A
  variable form (`fetch_template "${TEMPLATES[$wf]}" …`) reintroduces the
  derivation and disarms the check.
- **The bootstrap caller installs live between the `BOOTSTRAP-CALLERS`
  markers in `install.sh`, and the set they install — and each one's
  resolution — must equal `manifest.json`'s, under both visibilities.**
  Resolution is `visibility_variants[<visibility>]`, else `template`; the set
  is the `auto_install: true` workflow entries. The installer hardcodes the
  names; the manifest (§16.8) remains the documented authority, and the
  equality is what keeps the two from drifting apart. It runs in **both
  directions on purpose**: name-matching alone catches an existing-but-_wrong_
  variant (a `-public` template on a private install) that file-existence does
  not, while set-matching catches a caller being **dropped** — a stanza deleted
  from the block leaves nothing behind for a name check to inspect. Adding a
  bootstrap caller and flipping its `auto_install` are therefore one change.

  **Enforcement limit, stated so it is not assumed away:** the containment check
  reads only `fetch_template` calls whose destination is a literal beginning
  `.github/workflows/`. A variable destination, or a workflow written with
  `curl -o`/`cp`, is invisible to it. Set-equality is the backstop only for what
  is **inside** the markers — it compares the block's own resolutions, so a
  caller installed outside them in either of those forms is caught by nothing.
  Install bootstrap callers inside the markers, with a literal destination.

## 17. Auto-merge for AI-opened PRs (two-layer default)

Every non-paused, non-bootstrap workspace repo consumes both layers of
the workspace auto-merge default so AI-opened PRs merge when green
without human intervention.

### 17.1 Layer 1 — GitHub-native `--auto` (in-session)

When an AI session opens a PR, it enables GitHub-native auto-merge via
`gh pr merge <N> --auto --squash --delete-branch`. GitHub waits for
required checks + branch-protection to go green, then merges the PR
without further session action. This handles the happy path where the
session is still active when checks complete.

Rule: for every PR the AI opens on any workspace repo, the session
enables `--auto` after passing pre-push OPS-0065 self-review + running
CI. Skip only when the PR is a 🟡/🔴 governance-tier PR requiring
human review per OPS-0062 exceptions.

### 17.2 Layer 2 — server-side `auto-merge-ai-prs.yml` (out-of-session)

When the session ends before checks complete OR the `--auto` set-up
step is skipped (e.g., session crash), the reusable
`auto-merge-ai-prs.yml` workflow provides server-side recovery. It
polls for stuck-green PRs (label = `ai:review-passed` +
`mergeStateStatus = CLEAN` + `autoMergeRequest = null` +
`updatedAt > 2 min`) and re-arms `gh pr merge --auto --merge` under
the reviewer App's token.

The reusable workflow lives at
`vladm3105/aidoc-flow-ci/.github/workflows/auto-merge-ai-prs.yml`;
consumers ship a thin caller from one of the canonical templates:

- **Public consumer** (ubuntu-latest runners):
  `install/templates/workflows/auto-merge-ai-prs-public.yml`
- **Private consumer** (self-hosted `ci-runner` / `single-use` runners):
  `install/templates/workflows/auto-merge-ai-prs-private.yml`

Both templates pin at `@ci/v2.0.0` (bump per this repo's release
cadence). Consumer copies the template verbatim into its
`.github/workflows/auto-merge-ai-prs.yml`.

### 17.3 Prerequisites

- **Consumer must be in the `auto_merge.repos` allowlist** at
  `operations/.github/ai-review/config.json`. Repos not in the
  allowlist get the label + review but a **human merges**.
- **Reviewer App must be installed on the consumer** for the App-token
  merge path. Without it, the reusable falls back to `GITHUB_TOKEN`
  with a downgrade warning (workflow_run triggers won't fire from the
  merge commit per GHA anti-recursion, but merges still succeed).
- **ai-review + composition callers must be present** as the
workflow_run triggers. Bootstrap-tier repos without CI adoption
get auto-merge as part of full CI adoption, not standalone. (No
bootstrap-tier repos currently exist — interlog was promoted to
ops-private tier as of PLAN-006 W4.)

### 17.4 Non-goals

- Spec / governance-tier PRs are excluded from auto-merge by
  `ai-review.yml`'s `tier=spec` check. No consumer override.
- Cross-repo coordinated changes (multi-submodule pointer bumps,
  branch protection rule changes) surface for human review even
  when green.

### 17.5 Origin + cross-references

OPS-0062 (AI agent auto-merge default) codified 2026-06-27; server-
side companion codified in IPLAN-0030 (auto-merge-ai-prs enforcer).
See:

- `../operations/CLAUDE.md` — search `OPS-0062` (the AI-agent-in-session
  auto-merge default rule).
- `../operations/ops/DECISIONS.md` — `OPS-0062` full record.
- `../operations/ops/iplans/IPLAN-0030_*.md` — server-side enforcer
  design.
- `.github/workflows/auto-merge-ai-prs.yml` (this repo) — reusable
  implementation.
- `install/templates/workflows/auto-merge-ai-prs-{public,private}.yml`
  (this repo) — canonical caller templates.
