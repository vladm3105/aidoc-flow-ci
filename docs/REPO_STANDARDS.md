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

The aidoc-flow workspace has **three** repos that consumers cite as
"canonical source" — one for **CI + governance-workflow canon**, one for
**OPS-NNNN business decisions + multi-agent review prompt templates**, and one
for the **agent harness itself** (the global settings and agent definitions the
AI runs under, in every repo). These are DISTINCT concerns; do not confuse them:

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
| Agent definitions (the `agents/*.md` an agent type resolves to — `security-auditor`, `code-reviewer`, `preprod-review-lens`, `verified-planning-reviewer`, …) | **`aidoc-flow-claude-agents-config`** | `agents/` |
| Global agent settings — the global `CLAUDE.md`, the global `AGENTS.md` (Codex reads the same file), path-scoped `rules/`, and user-level `skills/` | **`aidoc-flow-claude-agents-config`** | repository root |

**Rule of thumb for consumer docs:** when a consumer's `CLAUDE.md`
(or DECISIONS entry, or CHANGELOG entry) needs to cite a canonical
source, ask: is this about CI, workflows, templates, scripts, static
settings, or governance-file shape? → `aidoc-flow-ci`. Is it about an
OPS-NNNN business decision, multi-agent review prompt templates,
cross-repo playbooks, autonomy tiers, or AI-employees registry? →
`aidoc-flow-operations`. Is it about **which agents exist, how they are
defined, or the global rules the AI itself runs under**? →
`aidoc-flow-claude-agents-config`.

**Two boundaries here are easy to get wrong. Both are drawn explicitly, because
each has a live counter-example in this workspace.**

**(a) Prompts vs agents.** `aidoc-flow-operations` owns the **review prompts** —
which prompt a given diff class gets, and the verdict schema it must return.
`aidoc-flow-claude-agents-config` owns the **agents** — what an agent type
resolves to when dispatched, and its tools and model tier. A change to "what the
reviewer is asked" is an operations change; a change to "what the reviewer _is_"
is an agent-config change.

**(b) GLOBAL agents vs a repo's OWN agents — and this row covers only the
first.** The rows above are scoped to the **global, user-level** harness
(`~/.claude/agents/`): the types any repo can dispatch, such as
`security-auditor` or `verified-planning-reviewer`. A repository's own
project-local `.claude/agents/*.md` stays owned by **that** repository.
`aidoc-flow-operations` is the live example — it carries its own roster of
AI-employee personas (`ceo.md`, `cto-platform.md`, `aidoc-flow-lead.md`, …)
under its own change process, and those are **not** governed by the
agent-config repo. So "which agents exist" is not by itself the routing
question; ask whether the agent is dispatchable from any repo (global) or
belongs to one repo's own roster (that repo).

**It is a live config, not a distribution.** That repository's working tree _is_
`~/.claude` — editing a tracked file changes the rules the AI is running under,
with no deploy step and no drift between "the repo" and "what is loaded". Canon
cites it as a source of record; canon does **not** fetch from it, install it, or
pin it, and no workflow in this repository reads it.

**It is PRIVATE, like `aidoc-flow-operations`** — private by intent, because
although no single tracked file is a credential, together they map the autonomy
tiers, merge policy and repo topology.

**Cite it by repository NAME, never as a `https://github.com/…` URL** — and
the reason is _not_ that CI would catch it. Canon's blocking `links` gate runs
`mode: internal`, which adds `--offline`, so it skips external URLs and makes no
request at all; the `external` mode that does reach the network ships
`fail-on-error: false` and cannot fail a job. **Nothing in CI would ever flag a
URL to a private repo** — it would simply be a dead link for every human reader
of a PUBLIC repository who lacks access. That is exactly why the convention has
to be held by hand, and every existing §0 row already holds it.
(`exclude_all_private` in `.lychee.toml` is unrelated: it excludes private **IP
ranges**, not private GitHub repositories.)

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

All non-paused repos protect the branches they **declare**; tier drives the
profile. A repo that declares nothing protects its **default branch**, which is
what every repo does today.

**The declaration is `.github/aidoc-ci.json`** (PLAN-028 B0, contract in
`BRANCHING.md` §8). `--tier` cannot carry it: three repos share the `product`
tier, so the branch set is not derivable from the tier. The file is **optional**
and an absent file is a valid declaration — it means the single-branch model
against the repo's API-reported `default_branch`, byte-for-byte the behaviour
that shipped before the file existed.

```jsonc
{ "version": 1, "branching": { "model": "dev-staging-main" } }
```

`install/apply-standards.sh --apply` protects every branch in the resolved set;
`sync/check-standards-drift.sh` verifies every one of them. Both read the
**pushed** copy over the API, not the operator's working tree — `--apply`
requires `--repo` and may be run from any checkout, so a CWD-relative read would
apply the branch set of whatever repo you happened to be standing in.
`integration_branch: null` resolves to the repo's GitHub `default_branch`, never
to a literal `dev`; an explicit `[]` is an opt-out, distinct from `null`. Three
rules bind:

- **The integration branch MUST be the repo's GitHub `default_branch`.** Four
  canon surfaces — `composition.yml`'s trusted allowlist, `ai-review.yml`'s
  canon-pin resolution, `check-pin-currency.sh` and `deploy-ci-wizard.sh` —
  resolve `default_branch` at run time and cannot read this declaration; two of
  them are trust boundaries. `apply-standards.sh` warns on divergence and
  `check-standards-drift.sh` counts it as drift. `BRANCHING.md` §8a.
- **The integration branch must NOT also be a promotion branch.**
  `apply-standards.sh` refuses this outright; `check-standards-drift.sh` counts
  it as drift. Declaring the model _before_ flipping the GitHub default produces
  exactly that overlap, and the `enforce_admins: false` overlay would then land
  on the repo's default branch — the trust anchor itself.
- **Every branch in `promotion_branches` is protected with the tier profile
  overlaid with `enforce_admins: false`**, because that is the only mechanism on
  a user-owned account that permits a fast-forward promotion push (measured,
  `DECISIONS.md` CI-0048). On such a branch the PR requirement is **advisory for
  admins, not enforced** — an accepted trade recorded as CI-0049, not an
  oversight. The integration branch is never a promotion branch and keeps
  `enforce_admins: true`, which is what preserves it as a trust anchor.

**Under the opt-in three-branch model** (`dev` → `staging` → `main`,
`BRANCHING.md` §0) a repo protects **all three**, `dev` is the `default_branch`,
and `main` receives only fast-forwards. The enforcement surfaces are in place as
of PLAN-028 Phase B, but **no repo has adopted the model yet, canon included** —
the cutover path is PLAN-028 Phases C and D. Note that the trigger-arm change
arrives via `install.sh --update` only; `--repin` rewrites `uses:` tag strings
and cannot deliver a caller-body edit. **`codeql.yml` is
`safe_to_replace: false`**, so even `--update` preserves the consumer's copy and
its two `branches:` filters must be edited by hand — `sync/check-drift.sh`
reports the file as drifted until they are.

The table below describes the profile applied to a protected branch; it is the
same profile whichever branch it is applied to.

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
| Allow GitHub Actions to create and approve pull requests | ✅ (needed for `docs-sync.yml`) | Required by IPLAN-0018 |

**Enforcement gap risk:** GitHub's default is `read-write` on new repos.
`apply-standards.sh` (PR-B) tightens to `read` and adds the fork-PR
constraints.

### 4.0a Doc-automation safety contract

**Scope narrowed by CI-0040.** This section governed `doc-maintainer`, retired
with that decision. What survives applies to `docs-sync`, now the sole doc
automation:

Repositories adopting `docs-sync.yml` MUST provide `.github/docs-sync.json` and
**begin in dry-run mode**. Autonomous edits stay restricted to explicit
low-risk documentation globs; anything else reaches a human. Live mode
additionally requires the scoped `aidoc-flow-bot` App.

**Dry-run-first is the adoption contract, and it is asserted at the config
fallback, not just in this prose** — see `docs/WORKFLOWS.md` §3.8. The retired
flow's planner/apply model (untrusted-input validation, `allowed_paths`,
per-PR caps, low/high-risk tiering) is **not** carried forward: `docs-sync` runs
deterministic Python and makes no model call, so it has no planner to constrain.

### 4.0b Unified LiteLLM agent gateway

All canonical AI execution (`ai-review`) goes through one
OpenAI-compatible LiteLLM proxy — the default, API-based LLM gateway (it
replaces per-runner vendor CLIs and fronts many providers behind one endpoint).
Consumers provide **repository-level** secrets `LLM_URL` and
`LLM_API_KEY` (set them **per repo** —
organization-level secrets require an org account and are unavailable on a
personal-account owner). They do not install or log in to vendor CLIs on runners.
AI review resolves its model alias from caller input
`model`, then trusted config `litellm.model`. `ai-reviewer` is the only
canonical alias since CI-0040 retired `ai-doc-maintainer`. The proxy owns
provider selection,
fallbacks, budgets, and provider credentials; CI receives only a scoped LiteLLM
key. Runners must be able to reach the configured proxy. Proxy failures and
malformed responses fail closed and never become an approving verdict.

The proxy URL MUST use HTTPS. Plain HTTP requires the explicit caller opt-in
`llm_allow_insecure_http: true` and is limited to a controlled private
network. **The opt-in is required by the URL SCHEME, not by repo visibility**:
any consumer whose `LLM_URL` begins `http://` must set it, public or
private. On the shared self-hosted pool the proxy is reached over the Docker
bridge gateway (`http://172.17.0.1:4001/v1`) — plain HTTP on a private network —
so every consumer there needs the flag, and since PLAN-013 routes the whole AI
flow to that pool, public repos are the common case rather than the exception.
`LLM_URL` MUST NOT be loopback: jobs run inside a container, so
`127.0.0.1`/`localhost` resolve to the container, not the proxy host. (CI-0017.)

Use ONE scoped virtual key — `LLM_API_KEY` — restricted to the model aliases it
must reach, with spend/rate limits and rotation; never use the endpoint's master
key. **This superseded the per-purpose (review + autofix) key convention**: the
doc key retired with `doc-maintainer` (CI-0040) and the remaining two converged
by founder decision, so revoking the key now stops autofix as well as review —
the trade-off is stated in `docs/security.md` §4.3. If you enable autofix, the
key's model scope must include the fixer alias (default `ai-fixer`) as well as
`ai-reviewer`, or the fixer gets HTTP 403 model-scope rather than 401. Disable sensitive prompt/response logging and apply an appropriate
retention policy: AI review sends a bounded, secret-pattern-redacted PR diff to
the proxy, which can still contain private source code. Secret-shaped source
values use opaque placeholders during inference and are restored only after the
response; missing or duplicated placeholders fail closed.

`docs-sync` sends nothing to the proxy — it makes no model call — so it is out
of scope for this subsection entirely.

Before a major AI-contract release is tagged, `.github/workflows/llm-smoke.yml`
MUST pass against the actual proxy for both canonical aliases. Mocked unit tests
do not replace this provider/proxy compatibility gate.

### 4.1 Runner class by flow-class + visibility (canon)

Runner routing follows the flow **class**, not only visibility (PLAN-013):

| Flow class | Public | Private | Caller shape |
| --- | --- | --- | --- |
| **AI-flows** (`ai-review`, `docs-sync` (+ `autofix`, a gated job within `ai-review` — PLAN-012)) | self-hosted `["self-hosted","ci","ephemeral"]` | self-hosted (same) | **ONE protected template** — no `-public`/`-private` split; visibility flip = no-op |
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
the matching variant. **A consumer MUST register the self-hosted `ci` /
`ephemeral` pool before adopting** (now also for the AI-flows on public repos).
Full detail: `docs/runners.md` "Workspace policy".

As of `ci/v1.9.0` the `-private.yml` templates ship the **real**
`["self-hosted", "ci", "ephemeral"]` label directly (earlier releases
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

### 4.2b Shared config is versioned, and a reusable asserts the schema it reads

**A reusable MUST assert the schema version of any config it reads from a SHARED
source BEFORE reading any field, and MUST fail loud rather than default.**

The trust config is a single shared source (`trust_config_repo`, default
`vladm3105/aidoc-flow-operations@main`) while every consumer pins its **own**
`ci/vX.Y.Z` reusable. That combination has a property worth stating plainly:

> **One repo's config upgrade is a breaking change for every consumer that has
> not re-pinned yet.**

`jq -r '.field // "default"'` is the wrong shape for reading such a config. A
schema the reusable does not understand then produces a _default_ instead of an
_error_, and the resulting failure surfaces far from its cause. This is not
hypothetical: the v1→v2 cutover (`reviewer` → `litellm.model`) left seven
consumers silently selecting an engine none of them had credentials for, for
nine days, behind an error that named neither the cause, the trigger, nor the
owner — long enough for a consumer to record the wrong diagnosis in its HANDOFF
and carry it across sessions (CI-0014).

Requirements:

- assert the version **first**, in every job that fetches the config;
- the error MUST name the **config source** (`owner/repo@ref`), the version
  **found**, the version **expected**, and the **remedy** — a mismatch is
  cross-repo, so an error that does not name the other repository sends the
  reader to audit the wrong one;
- do NOT fall back to an engine, model, or credential. "Refusing to guess" is
  the correct behaviour;
- a field the schema marks `required` gets no `//` fallback — the fallback
  silently contradicts the schema.

**Schema bumps.** Either version the config path (`config.v1.json` /
`config.v2.json`) so consumers resolve their own, or land the bump only after
every consumer has re-pinned. The assertion makes a mismatch _detected_, not
_safe_.

### 4.2c A reusable's `permissions:` block is a ceiling, not a request

**A reusable MUST declare the maximum permission any of its steps needs.**

GitHub computes a reusable's token as the **intersection** of the caller's grant
and the callee's declaration. A callee capped at `read` therefore cannot be
raised by any caller, and the corresponding step is unreachable for every
consumer. Both halves must be raised; either alone is inert.

State this in template comments as an intersection in **both** directions.
"A callee cannot grant its own permissions — the caller must" is only half the
rule, and reading it as the whole rule led a consumer to raise its caller and
wait for an upstream half that was never coming (CI-0015).

**A green reusable proves nothing about a step gated behind a condition that has
never been true.** `docs-sync`'s comment step is gated on `proposed != 0`; it
reported green from the day it shipped until the first real proposal, which is
when the permission ceiling was finally exercised. When adding a step that needs
a permission, verify the ceiling on the path that uses it — not by observing a
green check.

### 4.2d A check states its coverage; unreadable is never reported as drifted

**A verification job MUST distinguish "this differs from canon" from "I could
not read this", and MUST state how much it actually verified.**

Two failure modes, both live (CI-0018):

1. **Unreadable reported as drift.** Comparing canon against a value never
   obtained yields lines like `repo-settings.allow_merge_commit: canon=false
   actual=null`, which read as findings but mean "the token could not read it".
   Route absent/unreadable state through the `warn_uncheckable` path instead.
2. **Green that verified almost nothing.** Under the default `GITHUB_TOKEN`,
   branch-protection and `actions.*` are unreadable and `repo-settings` returns
   without its admin-only fields — leaving `labels` as the only genuinely
   verified family, while the job concludes `success`.

Therefore: emit a **coverage summary as the final line** — `verified N/M control
families`, naming the unverified ones and stating explicitly that a green result
does not mean they match canon. Under `--strict`, uncheckable is fatal: a
release gate that cannot read the settings it gates on must not pass.

### 4.2e Adopting a surface a consumer does not have — `install.sh --add-surface`

**Three modes, three disjoint jobs, and the third existed only after a shipped
release turned out to be uninstallable.**

| Mode | What it touches |
|---|---|
| bootstrap (no flag) | installs the `auto_install: true` set on a cold start |
| `--update` | re-applies template bodies for files the consumer **already has** — it never introduces a new surface |
| `--add-surface <path>` | installs a manifested surface the consumer **lacks** — never overwrites one it has |

**An `auto_install: false` surface therefore had no install path at all** until
`--add-surface`: bootstrap skipped it, `--update` skipped it by design, and
`--repin` only rewrites tag strings. `ci/v3.0.0`'s three consolidating callers
shipped in that state — manifested, documented, and impossible to adopt
([#429](https://github.com/vladm3105/aidoc-flow-ci/issues/429)). **Whenever a new
surface is added with `auto_install: false`, state which mode installs it**, or
it is shipped-and-unreachable; `tests/test_install.sh` asserts the route exists.

**Do not "fix" this by flipping `auto_install` to true.** Bootstrap runs on repos
that still carry the surfaces the new one replaces, so auto-installing would give
them both — doubled jobs on a serial self-hosted pool, and two sets of contexts
where the add-new → observe-green → remove-old sequence assumes the new one is
added deliberately. **Adoption of a replacing surface is a deliberate act.**

`--add-surface` accordingly:

- **resolves the visibility variant from the repo's live visibility**, never from
  `--visibility`, and refuses to guess — the same rule as `--update`, because
  picking wrong pins a private consumer to `ubuntu-latest` and the job queues
  forever (D1, OPS-0049);
- **never overwrites** — replacing an existing caller is `--update`'s job and its
  own hazard (FT-9);
- **warns when a surface it `replaces` is still installed**, using the manifest's
  `replaces` array. The warning is advisory: running both briefly is a required
  step of the migration, not a mistake;
- **arms no required context.** Branch protection and rulesets are untouched,
  because arming a context before its producer is observed green is the one
  migration step with no `--admin`-free exit.

**`replaces` is part of the manifest contract.** An entry naming a caller canon
does not ship warns about nothing, forever, with nobody the wiser —
`tests/test_install.sh` asserts every entry resolves.

### 4.3 Reusable workflows install tools as BINARIES, never third-party actions

**Canon reusable workflows may `uses:` only `actions/*`, `github/*`, and
`vladm3105/aidoc-flow-ci/*`.** This is a **canon-side authoring rule**, and it
is deliberately **stricter than the boundary the fleet actually enforces** —
do not "relax" it to match the deployed allowlist.

**The deployed boundary is the workspace owner's own account + GitHub's
(CI-0011).** `install/templates/actions-permissions.json` sets three _additive_
fields, not one list:

| Field | Value | Admits |
| --- | --- | --- |
| `github_owned_allowed` | `true` | every `actions/*` + `github/*` action |
| `verified_allowed` | `false` | nothing extra — verified-creator actions are **not** auto-admitted (FT-46: was `true`, wider than this rule) |
| `patterns_allowed` | 3 patterns | `vladm3105/*`, `actions/*`, `github/*` |

So a third-party action's fate at run-init no longer depends on who publishes it —
**any action outside `github/*`, `actions/*`, and `vladm3105/*` is BLOCKED at
run-init → `startup_failure`**, verified creator or not:

- **Non-verified creator** (`gacts/gitleaks`, `lycheeverse/lychee-action`,
  `DavidAnson/markdownlint-cli2-action`) → **BLOCKED** — no logs, no API error (the
  message is web-UI-only; `actionlint` does NOT catch it). This silently bricked
  `secret-scan` (fixed v1.9.2), `links`, and `markdown-lint` (both fixed v1.9.4).
- **Verified creator** (`aquasecurity`, `docker`, `hashicorp`, …) → **also BLOCKED**
  now that `verified_allowed: false`. Before FT-46 (`verified_allowed: true`) it was
  admitted; the wider grant was the discrepancy FT-46 closed.

**A `startup_failure` with no logs is the allowlist block; `##[error]Unable to
resolve action …` (with logs) is a tag-resolution failure, not the allowlist.**
Read the repo's actual `actions/permissions/selected-actions` before attributing a
failure to the allowlist — and note this is only in force once the repo has
**applied** `actions-permissions.json` (a template value until applied per-repo).

The canon authoring rule stands on its own merits — it keeps canon's supply
chain to sources this workspace controls or GitHub itself owns, without relying
on GitHub's verification programme as a trust boundary.

**The authoring rule remains STRICTER than the deployed boundary, deliberately.**
Deployed admits any repo under `vladm3105/*`; canon authoring admits only
`vladm3105/aidoc-flow-ci/*`. The gap is defence-in-depth, not drift: a consumer
may legitimately call another of the owner's repos, while canon itself stays
pinned to the one repo it ships from. Do not "relax" the authoring rule to match
the deployed allowlist.

**CI-0011 (founder, 2026-07-24) settled the outer edge:** the verified
marketplace was dropped (`verified_allowed: true → false`) and the owner's own
account (`vladm3105/*`) became the sole non-GitHub-owned allowance. Re-admitting
the verified marketplace — or adding any other owner to `patterns_allowed` — is a
**decision to take deliberately** and to record in `DECISIONS.md`, not a
conclusion to reach from convenience.

Two consequences of making the account the boundary:

- **Do not fork a third-party action into `vladm3105/`.** `patterns_allowed`
  carries no per-repo or per-ref constraint, so any repo under the account — a
  fork of a marketplace action included — is admitted at any ref. Forking one in
  re-widens the boundary CI-0011 just narrowed, without any config change to
  review.
- **Two layers guard it, and they cover different things.**
  `tests/test_contract.sh` asserts both halves of the shipped
  `actions-permissions.json`, so a silent re-widening of the **template** goes red
  — but it reads the local canon file and never observes a deployed repo.
  `sync/check-standards-drift.sh` covers the deployed side: since FT-53 it compares
  `patterns_allowed` order-insensitively (the API returns arbitrary order) and
  reports the two failure directions separately —
  **MISSING** (canon has it and **no live pattern covers it** → an action is blocked
  at run-init, a silent `startup_failure`) and **EXTRA** (repo has, canon lacks →
  the deployed supply-chain boundary is wider than the one CI-0011 decided).
  MISSING accounts for **glob subsumption**: entries are globs and GitHub wildcards
  span `/`, so `vladm3105/*` fully covers `vladm3105/aidoc-flow-ci/*`. A _broadened_
  pattern therefore loses no coverage and is reported only as EXTRA — a literal
  set-difference would call it MISSING and assert a `startup_failure` that cannot
  happen. The inverse (a repo **narrower** than canon) is a real loss of coverage
  and still fires.
  On the reusable path (`standards-drift.yml`) the comparison uses the canon
  template **at the consumer's own `standards-drift` pin**, so an older-pinned repo
  is not reported MISSING for a pattern that tag never shipped — though it may
  legitimately be reported EXTRA if its settings were widened ahead of its pin. Run
  directly from a CLI with no `--ci-tag`, the script instead resolves the
  highest `@ci/v*` pin across the repo's workflows and falls back to `main`.

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

#### 4.3d `secret-scan` scans FULL HISTORY, and its docs must say so

Canon runs **`gitleaks git .`** — all reachable commit history — not
`gitleaks dir .`, which scans only the working tree at `HEAD`. This changed in
`ci/v2.0.0`; the header comment and migration guide said `dir` until CI-0016
corrected them.

The scope is deliberate: a credential reachable in history is leaked whether or
not it survives at `HEAD`. The rule is about **documenting the scope actually
run**. A consumer validating locally per a guide that names the wrong command
sees clean and pushes into a red gate — one saw **0 findings under `dir` and 33
under `git`**, and needed a second allowlisting round (CI-0016).

**Rules.** Local validation MUST use `gitleaks git .`. First-run v2 adopters
should expect findings in unreachable history; those cannot be fixed by editing
files and MUST be allowlisted with an **anchored** `paths` regex (an unanchored
one is reported INCONCLUSIVE by the canary in §4.3a, because it would suppress
real findings too). **When a workflow's scope changes, the header comment, the
migration guide, and the changelog are all part of the change.**

#### 4.3e The GATE decides scanner coverage — never a PR-committed file (D23)

Every scanner canon ships honours **configuration committed to the repository
being scanned**, independently of the flags the action passes. A PR can
therefore choose its own coverage. Measured against the pinned tool versions:

| File the PR commits | Scanner | Discovered | Measured effect |
|---|---|---|---|
| `.semgrepignore` containing `*` | `sast-scan` | working dir | coverage → zero (verified gate bypass) |
| `.trivyignore` listing the AVD IDs | `trivy-scan` | working dir **only** | misconfigurations 3 → 0 |
| `trivy.yaml` narrowing `severity` | `trivy-scan` | working dir **only** | misconfigurations 3 → 0 |
| `osv-scanner.toml` with `[[IgnoredVulns]]` | `dep-scan` | **per directory** | results 24 → 0 |
| `.gitignore` naming a manifest | `dep-scan` | per directory | results 70 → 24 (targeted) or rc 128 (total) |

**Discovery differs per tool and the difference is load-bearing.** trivy reads
its config and ignore file from the **working directory only** — the same file in
a subdirectory was measured to have no effect — so a _recursive_ strip of
`trivy.yaml` would delete files trivy is meant to **scan** (`deploy/trivy.yaml`
is a plausible Kubernetes manifest). osv-scanner is the inverse: its config is
found **beside each manifest**, and a root-only strip misses every one.

**The harm outlives the PR.** A zeroed scan still writes a _legitimate_ empty
SARIF, so a purge that catches a PR **supplying** a report cannot see a PR
**causing** an empty one. `hashFiles` is non-empty, the upload runs, and because
Code Scanning keys an analysis by `category`, the `push: main` run **replaces**
that category's analysis and every open alert it held is erased.

**Rules.** Every scanner surface — composite action **and** `workflow_call`
reusable — MUST, before scanning:

1. **Strip** each config/ignore file its tool honours, matching `-type f` **and
   `-type l`** — git stores symlinks natively (mode 120000) and the scanner
   follows the link, so a `-type f` strip is bypassable by symlink (REPRODUCED
   against `sast-scan`, 2026-08-08).
2. **Scope the strip to the tool's real discovery** — recursive where config is
   per-directory, depth-limited where it is working-directory-only. A defense
   broader than the discovery removes coverage in the name of coverage.
3. Enforce a **post-condition**: if any such file still resolves, `exit 1` with
   an `::error::` naming the survivor. The strip's `|| true` makes the
   post-condition — not the strip — the actual gate.
4. Derive the post-condition from the **same expression** the strip used. Two
   statements of one fact drift; that is how `sast-scan` came to verify
   `scan-path` while its strip also cleared the root (#423). Note the corollary:
   because both read one expression, a _symmetric_ scoping regression is
   self-consistent and silent — so the tests MUST assert that the planted files
   are **gone**, not merely that the step exited 0.
5. Decide on **captured output**, never a pipeline's exit status
   (§27.1 / CI-0033): `find … -print -quit | grep -q .` is a REPRODUCED
   fail-open, because `-quit` returns non-zero when a traversal error is
   recorded before it quits _while still printing the match_, and `pipefail`
   takes that status over `grep`'s.
6. **Neutralise gate-side what cannot be stripped.** `.gitignore` is honoured by
   osv-scanner and every repo has a legitimate one, so it cannot be deleted —
   `--no-ignore` disables the discovery instead. Expect the coverage change that
   implies: vendored trees are no longer skipped.
7. **Validate `scan-path` before it reaches `find`.** It is an action input, and
   on `pull_request` the caller's workflow file comes from the PR head. `find`
   reads a leading `-` as an **option**: `scan-path: -delete` yields
   `find -delete . …` with no path operand — measured to empty the workspace,
   after which the post-condition certifies the empty tree clean. Reject a
   leading `-` and require an existing directory.
8. **Fold every PR-controlled path before echoing it.** Newlines are legal in
   git paths and the runner parses every output line for `::command::`, so an
   unfolded path lets a PR forge `::stop-commands::` and suppress the very
   `::error::` the refusal depends on.
9. **Say what was removed.** A repo that committed one of these on purpose has
   it deleted from the workspace; emit a `::warning::` naming the file and the
   gate-side alternative, or the maintainer concludes the scanner is broken.

A repo needing a genuine exclusion expresses it **gate-side** — in the ruleset,
or via a new action input — never in a PR-mutable file.

**Scope notes — what D23 does NOT cover.**

- **In-line suppressions** inside scanned sources (for example
  `#trivy:ignore:<AVD-ID>` in a Dockerfile) cannot be stripped without altering
  the code under scan. Inherent to scanning PR-controlled content.
- **A directory at a config path** is excluded from the strip (`-type f -o
  -type l`), because a directory cannot be read as config. For trivy it is still
  a weapon — a `trivy.yaml/` directory makes trivy exit FATAL, which the tool
  error arm reports as "Re-run", a permanent red whose remedy can never work —
  so `trivy-scan` names that collision explicitly instead.
- **`.trivyignore.yaml` / `.trivyignore.yml`** are stripped defensively; measured
  at trivy 0.72.0 they are **not** auto-discovered.

**Conformance is COMPLETE for rules 1–5 and 7–9, and the list of surfaces is
DERIVED.** (Rule 6 is open on `sast-scan` — see below; the earlier draft of this
sentence said "complete" flatly and dropped that disclosure.) All six scanner
surfaces satisfy those rules: `actions/{dep,trivy,sast}-scan/action.yml`
and the three `workflow_call` reusables of the same names. The previously
recorded non-conformance — `actions/sast-scan/action.yml` missing the
`scan-path` validation, and `.github/workflows/sast-scan.yml` carrying the
pre-#425 strip (`-type f` only, no root strip, **no post-condition**, so its
`|| true` was the whole gate) — is discharged.

**Read the shape of that gap before trusting the next one.** D23 ORIGINATED on
`sast-scan`, and #425 hardened the two surfaces it was EXTENDED to while leaving
the origin behind. It stayed there for the life of the v3 line, disclosed in
this very section, because the test that drives D23 named **four** surfaces and
called that "every shipped surface" — both sast surfaces were outside the guard
by construction, so nothing could go red. A defence with a hand-maintained list
of where it applies is a defence with a hand-maintained list of where it does
not. `tests/test_actions.sh` now DERIVES the surface list from the tree
(`actions/*-scan/action.yml` + `.github/workflows/*-scan.yml`, less
`secret-scan`, whose config canon itself ships) and reds when the derived set
and the driven set disagree.

**`secret-scan` is the one deliberate exclusion.** gitleaks' config is
`.gitleaks.toml`, which canon SHIPS as a template and every adopter is meant to
carry — stripping it would delete the gate's own configuration, the coverage
defence removing coverage. Its equivalent exposure is closed gate-side by
pinning `--config`.

**Rule 6 remains OPEN on `sast-scan`, and this paragraph is its only carrier.**
Whether semgrep 1.170.0 honours `.gitignore` for target selection is
**unmeasured**. `dep-scan` closes the equivalent hole gate-side with
`--no-ignore` (osv-scanner was measured to take results 70 → 24 via a
`.gitignore` naming a manifest); neither sast surface passes an equivalent flag.
So `sast-scan` satisfies rules 1–5 and 7–9, not rule 6.

This disclosure was deleted once already. The conformance rewrite above replaced
a "known non-conformance" block that ended _"Whether semgrep also honours
`.gitignore` (rule 6) is unmeasured"_ — and removing the carrier removed the
open question with it, while the replacement asserted every surface satisfied
the rule. That is the failure this section warns about two paragraphs down,
committed inside the fix for it. **Measure it** (plant a `.gitignore` naming a
file with a known finding, record the delta the way the trivy and osv numbers
are recorded), then either add the gate-side flag and claim conformance, or keep
this paragraph.

**Origin:** `sast-scan` shipped D23 at `ci/v3.0.0`; #425 extended it to
`trivy-scan` and `dep-scan` across both the actions and the reusables, and added
rules 2 and 6–9 from what that work measured. The back-port to the origin
surfaces, and the derived surface list, landed for `ci/v4.0.0`.

#### 4.3i The GATE decides the RULESET, and an input is not "explicit" (D26)

§4.3e governs config files the scanned repo COMMITS. This governs the coverage
levers the scanned repo **passes**, which is the same hole through a door that
looks like it is already shut.

`sast-scan` carried the claim _"Explicit `--config` (registry ruleset), NEVER
repo-local auto-discovery → a PR cannot inject rules."_ That was true of
semgrep's DISCOVERY and false of the INPUT. `config` is supplied by the caller;
on `on: pull_request` the caller's workflow file comes from the **PR head**, the
same access level §4.3e already assumes. semgrep's `--config` accepts a registry
ref, **a local path, or a URL** — so `config: ./empty.yaml` yields a zero-rule
scan that exits 0 with a legitimate empty SARIF, `n=0`, `::notice::no SAST
findings`, and a **green** required check that inspected nothing.

The rule:

1. **A coverage-determining input is validated against an allowlist of VALUES,
   gate-side — not a namespace prefix.** `sast-scan` accepts exactly
   `p/default`, `p/security-audit` and `p/python`.

   The first fix allowed the registry namespaces (`p/*|r/*`) and did **not**
   deliver this rule. `r/` addresses an _individual_ registry rule, so
   `config: r/generic.comment.something` passes a prefix check, resolves to a
   real ruleset of one rule, exits 0 with a valid SARIF, and the gate goes green
   having scanned essentially nothing — as does a narrow pack like `p/comment`.
   The original bypass took coverage to zero rules; a prefix check takes it to
   one. A prefix is also only a prefix: `p/../s/<attacker-snippet>` matches
   `p/*`. **A namespace is not a coverage guarantee.**

   This costs nothing today — those three values are exactly what canon ships
   and documents. A repo needing another pack asks canon to add it, which is the
   rule restated: the gate decides coverage, not the scanned code.
2. **"Explicit" describes where a value is WRITTEN, not who controls it.**
   Passing an input explicitly protects against a changed DEFAULT. It says
   nothing about whether the scanned code chose the value. Do not let the first
   property be documented as if it delivered the second.
2a. **`scan-path` is the same lever through a second door, and it is closed the
   same way.** All three scanner surfaces validate `scan-path` for _safety_ — it
   must not begin with `-` (or `find` reads it as an option) and must be an
   existing directory. Neither constrains _coverage_: `scan-path: docs` passes
   both, scans a code-free tree, exits 0, writes a valid empty SARIF, and the
   gate goes green. The rule was written for `config`, applied to `config`, and
   the identical bypass sat one input away — found in the second review cycle of
   the change that introduced rule 1. All six surfaces now accept `.` only,
   which is the input's default and what every shipped caller passes.

3. **Claim only what is enforced.** `fail-on-findings` is also caller-supplied
   and canon itself ships it `false` during a report-only rollout, so a PR
   setting it false is not an escalation beyond the shipped default — that is
   stated rather than quietly folded into the claim.

   Still _not_ enforced, and named here rather than left to be rediscovered:
   **`sarif-path`**. It cannot make the findings count read zero (the count is
   computed from the file the scanner just wrote, and an unwritable or empty
   path trips the infrastructure-error arm), but it is a **report** lever — a PR
   pointing the sast step's `sarif-path` at `osv.sarif` makes semgrep overwrite
   dep-scan's report, and on `push: main` Code Scanning keys an analysis by
   category, so the dep-scan category is replaced by content holding none of its
   rule IDs and its open alerts auto-resolve. Same harm as §4.3e's
   "outlives the PR" paragraph, reached through an input. Carried in
   `plans/PLAN-027` §C rather than fixed here.

**Origin:** the D26 prose predates enforcement; the guard and its both-direction
tests landed for `ci/v4.0.0`.

#### 4.3j `persist-credentials: false` — everywhere a later step does not need it

The input defaults to **true**, so this is an invariant held only by writing it
at every site.

**The rule is not "every checkout sets it false."** It is: _omit it only where a
later step needs the credential, and say why._ Both halves are load-bearing, and
the `ci/v4.0.0` hardening pass got the second one wrong before review caught it.

A sweep read "untrusted-head checkout without `persist-credentials`" as a
uniform defect and set it `false` on `audit-trail-check.yml` — the one canon
workflow that runs a **remote** git operation:

```sh
fetch_err=$(git fetch --no-tags origin "$BASE_SHA" 2>&1) || true
```

`actions/checkout` authenticates by writing `http.https://github.com/.extraheader`
into `.git/config`; `persist-credentials: false` removes it, and nothing else in
that job configures a credential helper. On a **private** consumer the fetch
then goes anonymous, the following `git cat-file -e` fails, and the required
`call / verify` context reds on every PR with an error naming the wrong cause —
`fetch-depth: 0`, which _is_ set. It would not reproduce on canon's own PRs
(canon is public, so an anonymous fetch of a reachable SHA succeeds), which is
exactly how it would have shipped green.

So the current state, and the shape to keep:

| Site | Setting | Why |
|---|---|---|
| every checkout in canon except one | `persist-credentials: false` | data-only — the job reads a tree and talks to the API with an explicit `GH_TOKEN` |
| `audit-trail-check.yml` | left at the default | a later step runs `git fetch` against the remote (D36) |
| ai-review `autofix` | `false` on the editing tree | the write-scoped credential is confined to a separate pristine clone |

**An exemption must carry its reason at the site.** An unexplained exemption is
one waiting to be tidied away by the next sweep, which is what happened here.

Enforced by `tests/test_contract.sh` from **parsed YAML**, not grep — a
`grep -q persist-credentials` passes on a header comment that merely mentions it,
and cannot tell two checkouts apart when only one is set. The check runs in
**both directions**: a non-exempt checkout that omits the setting fails, _and_ an
exempt checkout that sets it fails. The first draft enforced only the first
direction, so re-introducing the exact regression passed clean — an allowlist
that permits the defect it exists to prevent is not a guard. A converse sweep
also fails any non-exempt workflow that runs a remote git op after a
credential-less checkout, and a count floor keeps the whole check from passing
by finding zero checkouts.

#### 4.3f A pinned tool must be pinned to something IMMUTABLE (#435)

`install/templates/runner/Dockerfile` pinned `gh` with an exact apt version
against `cli.github.com`. **That repo carries only the current release**, so the
pin stopped being installable the moment upstream shipped the next one — with no
change to this repo, and with nothing detecting it.

Measured twice, which is what makes it a class and not a bump:

| Date | Pinned | apt offered | Result |
|---|---|---|---|
| 2026-08-09 | 2.96.0 | 2.97.0 only | unbuildable |
| 2026-08-20 | 2.97.0 | 2.98.0 only | unbuildable again |

The second occurrence had **no commit between it and the first fix** — the
defect re-armed itself.

**An unbuildable image is worse than a stale one.** It makes every fix that
requires a rebuild undeliverable while it sits merged and looking done: #349
(`sast-scan` cannot install semgrep) was fixed by editing this Dockerfile, and
the fix could not be delivered by anyone for the life of the expired pin.

**Rules.**

1. Pin to an artifact that **cannot be withdrawn** — a release asset, a digest,
   a commit SHA. A package index that carries only `latest` is not one.
2. Verify the artifact's **checksum before use** (D20), and keep the checksum
   next to the version so a bump that forgets it fails loudly.
3. State the **bump procedure** where the bumper will look, including where the
   checksums come from.
4. Fail closed on an unhandled variant (an architecture with no pinned digest)
   rather than installing something unverified.

**Origin:** #435.

#### 4.3g Per-host build state must be READABLE, not remembered (#458)

The runner image is built per host with no registry push, so a host that skipped
a rebuild keeps the old one and nothing prompts it. The record of which hosts had
rebuilt lived only in `HANDOFF.md`, which CI-0028 regenerates wholesale at every
wrap — so it was re-summarised or dropped on every pass, and it survived two
regenerations in near-identical wording before anyone noticed it was not
volatile state at all.

**The fix is not a list of hosts.** A hand-maintained list is a second queue and
goes stale exactly the same way. The artifact states its own version instead:

1. **Stamp the artifact** with a contract version it carries at run time.
2. **Declare the minimum** where the artifact is consumed, and check it there —
   at the supervisor, not inside the job. A job-side failure is remote,
   repo-shaped and names the wrong cause; a supervisor-side one is local, names
   the host, and states the command that fixes it.
2a. **Match the severity to how the check will be RESTARTED.** A supervised
   process under `Restart=always` turns any refusal into a crash-loop, so a
   condition that is true of every host on landing must WARN, and only a
   deliberately-raised minimum may refuse — with a distinct exit code the unit
   names in `RestartPreventExitStatus`, so the unit stops with a stated cause.
   A gate that is right about the defect and wrong about the restart policy
   takes down more than the defect did.
3. **Raise both in one change**, and assert they agree — two files stating one
   fact is the drift class that produced #423, #426 and #428.

**Origin:** #458.

#### 4.3h The GATE decides what is on the IMPORT PATH — clear before you fetch (#495)

§4.3e governs what a scanner _covers_. This governs what a workflow _executes_,
which is strictly more severe: the failure is arbitrary code running with the
job's credentials, not a coverage gap.

**Rule.** Any canon surface that fetches an interpreter asset into a
repo-relative directory and then runs it MUST clear that directory
**before** the fetch, under a post-condition that refuses to proceed if the
directory survives. The same applies to a directory a later step _trusts_ —
one whose contents decide what gets written, or where.

The vehicle is not exotic. `python3 <dir>/<script>.py` puts `<dir>` on
`sys.path[0]`; a fetch that overwrites only the names it knows leaves every
other committed file in place and importable, so a consumer-committed
`json.py` shadows the stdlib module the fetched script imports and executes
at import time.

1. **Clear before the fetch, not after the run.** A post-run purge is hygiene;
   it recovers nothing, because the module has already had its effect. Order is
   the whole defence, so **assert the order**, not merely that both lines exist.
2. **The post-condition is the gate; the `rm` is best-effort.** `rm -rf … ||
   true` is deliberate — a bare `rm -rf` that fails on permissions aborts under
   `set -e` before the `::error::`, producing a red step with no stated cause.
3. **Test `-e` AND `-L`.** `-e` catches the real exploit, a surviving
   **directory** of committed files — and `mkdir -p` is no backstop for it,
   returning 0 silently on an existing directory. `-L` catches what `-e` cannot
   see: `-e` follows the link and reads false on a **broken** symlink. `rm -rf`
   removes a symlink, live or dangling, and never follows it, so `-L` fires only
   when the unlink itself failed, or on ELOOP.
4. **Refuse with a non-zero exit, not a warning.** A gate that prints
   `::error::` and exits 0 lets the consumer's own module execute verbatim.
   Assert the exit, not the message — a REPRODUCED fail-open: changing `exit 1`
   to `exit 0` left a nine-assertion suite fully green.
5. **Fold captured stderr before echoing it** (§4.3e rule 8, same forgery
   vector through a different writer).
6. **Prefer removing the search path outright.** `PYTHONSAFEPATH=1` (Python
   3.11+) drops `sys.path[0]` entirely, making the guarantee independent of
   directory hygiene and pre-empting a refactor to `python3 -m <op>` or a `cd`
   that would re-open the vector. Defence in depth, not a replacement for the
   clear.
7. **A post-run purge must stay best-effort.** Placed mid-job under the default
   `bash -e`, a failing purge fails the step — and because sibling steps carry
   plain `if:` expressions with an implicit `success()`, it silently suppresses
   whatever they produce.

**Origin:** #495 (re-filed from #404, whose PLAN-024 A5 carve-out was not
honoured). Applied surface: `.github/workflows/docs-sync.yml`, for both
`.docs-sync-scripts/` (executed) and `.docs-sync-proposed/` (trusted — the ops
write a `.proposed`/`.target` pair there and live mode reads it to decide what to
write where, so a committed pair is arbitrary-content-to-arbitrary-path for a
bot commit made with the branch-protection-bypass App identity).

#### 4.3k A fork test must be an IDENTITY, never a negated nullable flag (D27)

`github.event.pull_request.head.repo.fork` is **null**, not false, when the fork
was deleted before a `reopened` event. `null != true` is TRUE, so
`if: ${{ …head.repo.fork != true }}` runs the job on a fork-origin tree while it
holds `security-events: write`. `fork == false` is not a fix either — GitHub
coerces both null and false to 0, so `null == false` is also true.

**The required form compares identity, which fails CLOSED because
`null == 'owner/repo'` is false:**

```yaml
if: ${{ !contains(fromJSON('["pull_request","pull_request_target","pull_request_review"]'),
                  github.event_name)
        || github.event.pull_request.head.repo.full_name == github.repository }}
```

**Enumerate every PR-ish event — a bare `github.event_name != 'pull_request'` is
not enough, and in a reusable it is actively wrong.** These are `workflow_call`
reusables, so `github.event_name` is the **caller's** event. A consumer whose
caller is wired to `pull_request_target` makes `!= 'pull_request'` TRUE, and the
guard then ADMITS a live fork that the old nullable-flag spelling correctly
skipped — running fork code on the self-hosted pool with `security-events:
write`. The first version of this rule shipped the narrow form and would have
propagated it to every consumer.

Four rules, each learned the hard way:

1. **Apply it to every surface in the same change.** `scanners.yml` carried this
   fix while the six v2 reusables every un-migrated consumer still calls kept the
   defective spelling — including a workflow whose own comment described the bug
   it was not fixing.
2. **Check the polarity before converting a site.** Not every nullable-flag read
   fails open. `composition.yml` builds `IS_FORK` and tests `= "true"`: a null
   there means "not exempted", so the gate BLOCKS, and converting it to the
   identity form would make a deleted fork _exempt_. **Converting a
   fail-closed site to the identity form is a regression.**
3. **Assert the form on the line that carries it.** An unanchored
   `grep -q 'full_name == github.repository'` is satisfied by the SARIF upload
   guard while the job guard regresses. Anchor to the job-level `if:`, and
   separately forbid the null-permissive spelling outside comments.
4. **PIN THE EXEMPTION POSITIVELY, not in prose.** Rule 2 has exactly one
   counterexample in canon (`composition.yml`), and a rule of the form "this
   spelling is banned" is executed by sweeps and by agents. Left as a paragraph,
   the next uniform pass inverts the ai-review gate. `tests/test_contract.sh`
   asserts that `composition.yml` **still contains** `head.repo.fork` and still
   tests `IS_FORK` against the literal `"true"` — the two properties that make
   its null fail closed. **A documented exemption with no assertion is a defect
   waiting for a tidy-up.**

**`secret-scan` has no job-level fork guard, deliberately** — it must scan fork
PRs, which is the highest-value case, and its gate is `gitleaks --exit-code`,
not the SARIF upload. Do not "apply the rule to every surface" there.

#### 4.3l Every resolver that turns a caller pin into a FETCH REF must peel-verify (FT-28)

A caller may pin `@<40-hex> # ci/vX.Y.Z`. GitHub executes the SHA, so the asset
fetch must use the SHA — but `raw.githubusercontent` serves **any commit
reachable in the public canon repo, including never-merged fork-PR commits**,
while the trailing tag comment reads as the released version in review. The
resolver must therefore peel the claimed tag through the API and refuse when the
pinned SHA is not that tag's commit.

**The rule is the CONSTRUCTION, not the workflow.** Any file containing
`FETCH_REF="${CANON_SHA:-$CANON_TAG}"` needs the block. `ai-review.yml` carried
it from FT-28; `standards-drift.yml` and `docs-sync.yml` had the identical
construction and none of the verification — and those two are the ones that
**execute** what they fetch (`bash "$SCRIPT"`, `python3 …/*.py` whose output is
committed by the App identity holding the branch-protection bypass). Fetching
data unverified is a stale comparison base; fetching _code_ unverified is
arbitrary code execution.

Ship the block between `# >>> FT28-PEEL-VERIFY >>>` / `# <<< FT28-PEEL-VERIFY <<<`
markers so the test extracts and DRIVES the shipped code rather than a copy, and
**derive the required set from the tree** (`grep -rlE 'FETCH_REF="\$\{CANON_SHA…'`,
with `--include='*.yml'` so a `*.yml.bak` leftover cannot join the set) rather
than pinning a count in one file — a count is satisfied by the files that already
comply while a new resolver ships without one.

#### 4.3m A declaration file's schema must be ENFORCED by every reader

`schemas/aidoc-ci-v1.schema.json` declared `additionalProperties: false` at both
levels and required `version`; all four readers of `.github/aidoc-ci.json`
checked only "`.branching` is an object". A schema nothing validates against is
documentation, and the gap is not cosmetic: `"promotion_branchs": []` — one
transposed letter — is invisible to `has("promotion_branches")`, so the reader
takes the **model default** and writes `enforce_admins: false` onto the two
branches the operator was explicitly opting out of. **A typo inverted the one
setting that makes the gate advisory.**

1. **Validate with `jq`, not a jsonschema dependency** — these run on consumer
   machines and on a runner image that ships neither.
2. **PIN the key lists to the schema by test.** The guard hand-copies them into
   four files; derive them from the schema in the suite and assert every reader
   carries exactly them, or the schema and its enforcement drift apart silently.
3. **Say what it does NOT check.** This validates keys and `version`; it does not
   check types, enums or `maxItems`. A guard that claims more than it enforces is
   the defect it was written to close.
4. **A reader's severity matches its role.** The mutating surface
   (`apply-standards.sh`) and the push gate refuse outright; the _verifier_
   warns and counts a fetch error, because a verifier that exits fatal stops
   reporting the rest.

#### 4.3o A fail-closed limit needs a gradient, not just a wall

`ai-review` caps the redacted diff at 400 KB and **refuses** past it — it does
not truncate, because a partial review presented as a complete one is the
dangerous failure: the model approves a PR having seen part of it. That polarity
is correct and must not be "simplified" into a truncation.

What it lacked was a way to see the wall coming. The refusal was the **first**
signal, and by then the PR is already unreviewable. Measured on real PRs
2026-08-24: `aidoc-flow-framework` #527 sat at **87%** of the cap, #530 at 36%,
`aidoc-flow-ci` #519 at 56% — grazing it, not hitting it, with nothing surfacing
that fact.

1. **Report the headroom on every run**, not only on the failure. A limit whose
   utilisation is invisible is a limit you learn about by tripping it.
2. **Warn on approach, fail only at the wall.** The `::warning::` at 75% never
   fails a run; the PR is reviewed normally. It exists so the TREND is visible
   while there is still time to act on it.
3. **Do not let the warning become the fix.** It is an instrument, not a
   remedy — the remedy (chunked map-reduce review) is deferred in PLAN-011
   pending exactly this evidence. One PR at 87% is a data point, not a mandate.
4. **Mutation-test the polarity, not just the threshold.** The test that matters
   is the one that reds when someone replaces the refusal with
   `encoded = encoded[:LIMIT]`. A threshold test alone passes happily while the
   fail-closed property is removed underneath it.

#### 4.3n A LIST call that feeds a decision must be PAGINATED, not defaulted

`gh <thing> list` defaults to **30** and truncates **silently** — no warning, no
non-zero exit. When that list is then used to decide whether something exists,
the truncation becomes a wrong answer rather than a short answer.

`install.sh` prefetched labels with `gh label list` so it could tell "already
exists" apart from a real failure — the right intent, stated in its own comment.
But canon ships **21** labels and GitHub creates **9** on a new repo, so a repo
sitting at 30 plus one local label makes the prefetch omit a label that exists;
the loop concludes it is missing, `gh label create` is rejected as a duplicate,
and the bootstrap **aborts**. Measured on the fleet when found: `framework` 39,
canon 32. Present since the installer's first commit and shipped through
`ci/v3.0.0`.

1. **Use `gh api --paginate "…?per_page=100"`.** It has no ceiling to get wrong
   on a normal REST collection — pagination ends when the `Link: rel="next"`
   header does, not at a client-side number. A bigger `--limit` only moves the
   same silent truncation further out. **Exception: the `/search/*` endpoints
   cap at 1000 results regardless of pagination**, so a search-backed decision
   needs its own completeness argument.
2. **Do NOT add `--jq` to a `--paginate` call whose output is parsed as one
   document.** `--paginate` merges JSON array pages into a single array only
   when it is not also filtering; with `--jq` gh emits one array **per page**,
   concatenated, and a `json.load` fails with "Extra data". The first fix for
   the defect above carried `--jq` and would have traded a truncation bug at 30
   labels for a parse crash at 100.
3. **A fresh fixture cannot find this class.** A brand-new throwaway has 9
   labels, so every create succeeds and the gate passes. It surfaces only
   against a target that already holds the data — which is what a REAL adopter
   looks like. When a dry-run's fixture is materially cleaner than production,
   the gate is testing the easy case; re-running against a used target is not
   contamination, it is the more representative run.

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

### 5.4 Issue-lifecycle labels (required where the tracker is the task surface)

**§5.1–§5.3 name no issue _role_.** One of them is applied to issues —
§5.3's `security` is documented "security-tagged issues/PRs" — but it names an
_area_, which is a different thing. (`dependencies` is Dependabot **PRs** only.)
Once a repo's open issues **are** its backlog, three
issue roles need names, and a role with no label can only be found by searching
prose.

That backlog convention is set outside this repo and canon does not currently
have an `OPS-NNNN` to cite for it — §5.4 provisions the labels the convention
needs and takes no position on the convention itself. A repo that does not work
that way carries the labels unused, which costs nothing.

| Label | Applied by | Semantics |
| --- | --- | --- |
| `handoff` | Human/agent at a session wrap | The session-continuity issue, **in repos whose handoff is an issue**. Exactly one open per repo |
| `todo` | Human/agent at capture | A captured backlog item — work to do, as distinct from a defect report |
| `status:in-progress` | Whoever claims the issue | The issue is claimed and being worked. An issue being worked with neither this label nor an assignee cannot be told apart from an unstarted one |

Provisioned from `install/templates/labels.json` by `install.sh` like the other
three groups; nothing auto-applies them, and `labeler.yml` cannot, because it
fires on pull-request events only — never on `issues`. Every non-paused repo should carry all three —
a repo that never uses the issue-form handoff simply leaves `handoff` unused.

**A label is a lookup key, and an approximate lookup key is a defect when the
next step is destructive.** Finding the live handoff by title search is the
instance:

```sh
gh issue list --label handoff --state open              # exact
gh issue list --search "HANDOFF in:title" --state open  # returns non-handoffs
```

`in:title` matches the word anywhere in the title, case-insensitively, so it
also returns issues merely _about_ handoffs. Measured in `vladm3105/llm-router`:
that search returned the live handoff **and** an unrelated migration issue. The
wrap procedure's next step is to **close** what it found, so the failure is not
a slow lookup — it is closing the wrong issue.

**Shipping the label does not fix any caller.** The wrap procedure that runs the
title search lives outside this repo, so it keeps running it until it is changed
there; canon here supplies the exact key and says which one to use. Per §18 that
is the owning repo's issue to file, not a local workaround to apply.

**Provisioning `handoff` does not migrate any repo's handoff to an issue.** The
surface each repo declares in its §16 governance table governs. Canon ships the
label so that repos on the issue form have an exact key, not to move anyone onto
that form — a repo on the file form keeps it by declaring a path, and `handoff`
simply stays unused there.

**`todo` is what lets the backlog be read without the handoff in it.** Where the
task list is the open-issue list, a pinned handoff issue otherwise sits
permanently at the top of it as a non-task. `is:open -label:handoff` is the
filter; no other mechanism excludes it.

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

- [`WORKFLOWS.md`](WORKFLOWS.md) — workflow registry (15 reusables +
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

**Push range — one resolution, two consumers.** The changed-file list
(`BASE`...`HEAD`) and the OPS-0069 phrase scan (`commit_range`) are derived from
a single `@{upstream}` resolution, falling back to merge-base with `origin/main`,
then local `main`, then the **root commit** before a branch's first push.
Resolving the two independently is what allowed the canon and template copies to
diverge on `BASE=` — the template shipping the pre-PLAN-015-M3 behaviour, which
re-lints every pre-existing branch commit on every push — while the phrase range
stayed in sync and nothing detected the difference (#477).

**The range describes the CHECKED-OUT branch, not the refs being pushed**, and
that limit is load-bearing. `git push origin feat` from an up-to-date `main`
produces an empty range while unreviewed commits are in flight; a multi-ref push
(`git push origin a b`, `git push --all`) is not described at all. Reading the
pushed refs is the real repair and is tracked as #432 — it requires handling
multi-ref pushes, deletions, tag pushes and working-tree coverage, and a partial
version of it was measured letting an unreviewed commit reach a remote.

**Until then, an EMPTY range exits NON-ZERO.** It is not a pass and it is not a
violation, and the script says so in those terms:

| Surface | Behaviour on an empty range |
| --- | --- |
| Mechanical linters | not run — there are no files in range |
| OPS-0069 phrase | not scanned; **never** reported as a violation |
| Exit status | `1` — a run that verified nothing must not approve a push |
| Final banner | `NOTHING VERIFIED`, never `local pre-push checks passed` and never `local pre-push checks FAILED` |

The defect this repairs (#432) is the **message**, not the exit status: an empty
range raised a hard OPS-0069 failure directing the reader to `git commit --amend`
a commit that already carried the phrase, while silently skipping every
mechanical linter in the same run. It was loud in the wrong place and silent in
the right one. **Exiting 0 instead is not the fix** — that was tried, and because
an empty range is not proof that nothing is being pushed, it let an unreviewed
commit through.

**Two further states fail closed, each naming its own cause**, because the
generic block's only remedies are `git commit --amend` and neither can clear
them:

| State | Cause | Reported as |
| --- | --- | --- |
| unresolvable range | the range's base ref is missing from the clone | `does not resolve`, remedied by fetching the base ref or setting the upstream |
| `git diff` non-zero | unrelated histories; the status used to be discarded, so zero files were linted and the run still printed the pass banner | `GATE MALFUNCTION`, `rc=1` |

**The two copies are byte-for-byte identical**, asserted with `cmp` in
`tests/test_pre_push_range.sh`, which also runs every behaviour above against
both copies. A `sed`-scoped comparison of one hunk previously stood in for this;
its comment claimed a general no-drift invariant its range did not cover. A
string comparison is **not** sufficient — `$(cat …)` strips trailing newlines,
so it calls two files identical when one has extra blank lines.

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
`scripts/pre_push_check_<repo>.sh` that runs canon + adds its own checks.
Wrapper preserves the canon's `set -uo pipefail` + rc-accumulator
pattern. See PLAN-002 §4.8 for the operations wrapper reference.

**The wrapper must RUN canon as a subprocess, never `source` it.** Canon
exits — `exit "$rc"` at the end, and `exit 2` at three earlier guard points —
so sourcing it terminates the wrapper at whichever it reaches first, with
canon's own status. The wrapper then reports canon's result and **silently
runs none of its extras**. There is no error; the extras' output is simply
absent, which an author who has never seen them run has no baseline to
notice. Capture the status instead:

```sh
#!/usr/bin/env bash
set -uo pipefail   # NOT -e — see below; -e aborts before the extras run

bash "$(dirname "$0")/pre_push_check.sh"; rc=$?

python3 scripts/my_extra_check.py; extra_rc=$?
rc=$(( rc | extra_rc ))    # OR-accumulate; never `rc=$?` on its own

exit "$rc"
```

**`set -euo pipefail` re-creates the defect this rule exists to prevent.**
Under `-e` the wrapper aborts the moment canon returns non-zero — before any
extra runs — and exits with canon's status. From the outside that is
indistinguishable from the `source` form: canon's output, canon's status,
extras absent. Measured: `-e` and `source` both produce zero extras and
exit 1, where `set -uo pipefail` produces the extras and exit 1.

**A wrapper must not weaken §14.2.** Whatever it adds, canon's non-zero
status has to survive it — an extra check that overwrites `rc` instead of
accumulating into it turns the OPS-0069 audit-trail gate off without
touching it. Assert this directly: canon-red plus extras-green must still
exit non-zero.

**Any REPORTING (non-blocking) hook MUST set `verbose: true`.** `pre-commit`
prints a hook's stdout only when that hook **fails**. A hook that reports and
exits 0 therefore renders as a single word — `Passed` — and its entire output
is discarded. Measured on this repo's own `claim-ledger-gate`: 14 failing plans
and 85 diagnostic lines swallowed, by a gate whose stated purpose was to print
them. An advisory hook without `verbose: true` is not advisory, it is absent —
the same "a gate nothing reads" shape §14.1 exists to prevent, arriving through
a config default rather than a missing script.

**A skip must respect the mode it is skipping.** Where a wrapper's extra check
can be unavailable (an absent interpreter, a tool that ships outside the repo),
the skip is legitimate in reporting mode and is a **hard failure** in enforcing
mode. A skip path that exits 0 unconditionally is an env-var escape hatch, and
§14.1's whole point is that canon deliberately has none.

**This repo's own wrapper is `scripts/pre_push_check_ci.sh`** (#469). It
reads `check_plan.py` over the Claim ledgers of every plan whose `Status:`
line does not mark it finished, with the workspace root passed as an extra
`--root` so cross-repo citations resolve. Two properties worth stating
because both are load-bearing and neither is obvious:

- **It fails closed.** A plan with no parseable `Status:` line is _gated_,
  not exempt. Treating an unreadable header as "finished" would drop plans
  from the gate silently, which is the defect the gate exists to catch.
- **It is advisory** (`LEDGER_GATE_BLOCKING=1` enforces). The exemption
  marker lives in the file the gate checks, so a plan can escape by
  declaring itself SHIPPED; the exempt set is therefore printed on every
  run rather than applied silently.

`check_plan.py` ships with the verified-planning Claude skill, **not** with
this repo, so this gate cannot become a CI job without vendoring it first —
the ephemeral runners have no `~/.claude`.

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

**SUPERSEDED by `DECISIONS.md` CI-0039 (2026-08-20); the operator-side detectors
below still stand.** This paragraph read: _"Detecting this class in general is
deliberately NOT on the gating path … the only in-reusable implementation is an
output-emptiness heuristic … moving it into the reusable is a separate proposal
needing its own decision (FT-31)."_ Both halves were overtaken by #426. The
implementation is **not** an emptiness heuristic — `pre-commit` prints one line
per hook it executes and nothing for a hook the stage did not select, so the run
is counted, not guessed — and the named risk (a consumer on `run-stage: manual`
with no `manual` hooks flipping to fail on re-pin) **is** the defect: that check
was passing while inspecting nothing. The detector is now on the gating path on
both surfaces; see §14.1b. The operator-side detectors (`install.sh`, the wizard
preflight, the release checklist) remain, and catch it earlier.

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

#### 14.1b D11 is asserted on the RUN, not predicted from the config

§14.1a's rule is about what the fragment ships. This is about how the gate
**proves** it worked, and the two are not the same check.

`actions/pre-commit` parses `.pre-commit-config.yaml` to count hooks selected at
the requested stage. That prediction is **structurally incomplete**: when a hook
entry omits `stages:` and `default_stages` is absent, the **hook repo's remote
manifest** decides the stage, and no parser of the consumer's config can see it.

Reproduced at `pre-commit` 4.5.1 — a hook repo whose manifest declares
`stages: [pre-push]`, referenced by a config that says nothing about stages:

```console
$ # the guard's prediction
pre-commit: 1 hook(s) selected at stage 'pre-commit'      → exit 0  PASS
$ pre-commit run --all-files --hook-stage pre-commit
                                                          → exit 0  (no output)
```

A green required check that inspected nothing — the exact D11 shape the guard
exists to prevent, surviving _inside_ the guard. Worse, the guard's own comment
and a test's assertion name both encoded the wrong premise ("no `stages:`
anywhere means the hook runs at every stage"), so the suite ratified it.

**Rules.**

1. The config parse is a **fast pre-check** for an obviously empty stage. It is
   never the evidence that hooks ran.
2. The **post-condition is on the run**: capture `pre-commit`'s output and
   require at least one executed hook. `pre-commit` prints one dotted line per
   hook it executes and nothing for a hook the stage did not select, so the
   count is an observation, not an inference.
3. A hook that ran with no matching files (`(no files to check)Skipped`) **counts
   as executed** — the stage selected it, which is what D11 asserts. Conflating
   it with zero-selection reds every repo whose hooks are file-scoped.
4. The post-condition is scoped to **`rc == 0`**. A non-zero run already fails
   with `pre-commit`'s own diagnosis, and firing D11 there replaces a real cause
   (unparseable config, missing hook repo) with a misleading one.
5. Read the run's status from **`PIPESTATUS[0]`**, not `$?`. Be precise about
   why: `set +e` does not clear `pipefail`, so `$?` agrees whenever `tee`
   succeeds; it stops agreeing when `tee` fails, and then reports tee's failure
   as the tool's. Capture the whole array in **one** command — `rc=${PIPESTATUS[0]}`
   is itself a command and resets `PIPESTATUS`, so a second read dies under
   `set -u`. Give the capture failure its own arm: a truncated log makes the
   count meaningless, and reporting that as a hook-selection problem names the
   wrong cause.
6. **Anchor on the outcome, never on a padding width.** The dot padding is
   computed per run from the longest selected hook name, and for that hook's
   `(no files to check)` line it collapses to **three** dots. A pattern requiring
   four missed the legitimate line while still matching the illegitimate one —
   a false red on a correct config, diagnosed as stage selection.
7. **Refuse `SKIP`.** It makes `pre-commit` print a `Skipped` line per named hook
   and exit 0; measured, that read as "2 hook(s) EXECUTED … satisfied" with
   nothing run. A required check does not let its environment choose what runs —
   invoke under `env -u SKIP`. Do NOT read `SKIP` into a shell variable to warn
   about it: every step declares the env it reads, and this is an ambient var the
   step defends against rather than consumes.
8. **Pin `--color=never`.** Colour wraps the outcome word in ANSI, so the line no
   longer ends in the outcome and every line is missed.
9. **All hooks reporting `(no files to check)` is zero inspection too**, and reds
   with its own diagnosis. One such hook counts as executed — the stage selected
   it — but all of them means nothing was read.
10. **Do not attest on a run where the check did not execute.** Printing
    "post-condition satisfied" beside a failing run states a conclusion the step
    never reached.
11. **Both surfaces.** A composite action and its `workflow_call` reusable are
    two shipped implementations; a rule that binds one and not the other is not
    in force. Ask which surface the fleet actually runs — see CI-0039.

**Generalise it.** A gate that predicts what a tool _will_ inspect is only as
good as its model of that tool. Where the tool can report what it _did_ inspect,
the report is the gate and the prediction is a convenience. The corollary bit
twice here: the new counter's own model of `pre-commit`'s output was wrong about
the padding, and hand-written test fixtures could only ratify that model.
**Generate fixtures from the real tool.**

**Origin:** #426; the gating-path decision is `DECISIONS.md` CI-0039.

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

A surface may instead live **in the issue tracker rather than on disk**
by declaring `Tracker — <descriptor>` (e.g. `` Live HANDOFF | Tracker —
`label:handoff` ``). The descriptor names how to find it and must be
non-trivial; a bare `Tracker —` is rejected. Use this form ONLY when the
surface is genuinely adopted — declaring `Not adopted —` for a surface
the repo does use is a false declaration, and declaring `Tracker —` for
one it does not is equally false.

The three forms are mutually exclusive and the parser reports which one a
cell used in its `form` field (`path` / `tracker` / `not-adopted`), so a
consumer can tell a tracker-hosted surface from an unadopted one — both
verify with no path on disk.

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

**`pre-commit` remains the bootstrap producer under `ci/v3.0.0`, and
`quick-gates` does not replace it until PLAN-026 §C0 lands (#481).** v3 folds
`pre-commit` + `markdownlint` + `links` into `quick-gates`, so the producer is
_meant_ to move — but that is two edits, not one: this flag, and §C0
substituting the bare `quick-gates` context into the four tier templates that
carry `call / Lint / format / security hooks`. They must land as **one change**.
Landing either alone arms a required context with no installed producer, and
both halves have now been live separately:

| Landed alone | Who breaks |
| --- | --- |
| the flag (`#441`, reverted here) | a **cold start** installs `quick-gates` while the templates still require `pre-commit`'s context — a new repo bricked on arrival, and consumer tiers have no `--admin` escape |
| §C0 alone | **every already-installed consumer** — measured 2026-08-16, all eight consumers that carry required contexts have `pre-commit.yml` and none has `quick-gates.yml` (the umbrella tier requires no checks at all). A re-bootstrap never supplies one, because `quick-gates.yml` is `auto_install: false` and the bootstrap block installs only its three hardcoded callers |

The order is therefore PLAN-026 C1–C5 first (put `quick-gates.yml` on the
fleet), then §C0 and the flag together. Until then `quick-gates` is adopted
deliberately, per surface: `install.sh <repo> --add-surface
.github/workflows/quick-gates.yml`.

`install/required-context-map.py` now marks with `!` a producer canon ships but
a cold start omits (`auto_install: false`), and
`tests/test_required_contexts.sh` §5 reds the suite when the **bootstrap** tier
depends on one. The script previously answered only "does canon **ship** a
producer?", which is why every row read green in both broken directions.

**What that check does and does not cover.** It stops either half landing alone
without reddening — §C0 alone leaves `quick-gates` at `auto_install: false`, so
the newly-required context resolves to `!`. It does **not** enforce the ordering
above: `auto_install` describes a _cold start_, whereas the fleet hazard is about
what already-installed consumers have on disk, and canon cannot read consumer
repos. A green suite is not clearance to land §C0.

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
- **Private consumer** (self-hosted `ci` / `ephemeral` runners):
  `install/templates/workflows/auto-merge-ai-prs-private.yml`

Both templates pin at the current `@ci/vX.Y.Z` release tag (see `../VERSION`;
`sync-version-refs.sh` keeps the template pins in step at release). Consumer copies
the template verbatim into its `.github/workflows/auto-merge-ai-prs.yml`.

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

## 18. Cross-repo defects are filed as issues on the OWNING repo

**When work in one repo surfaces a defect owned by ANOTHER repo — the CI canon,
a sibling submodule, an upstream spec — file it there as a GitHub issue.**

Recording it only in the finding repo's `DECISIONS.md` / `HANDOFF.md` /
`plans/` is not sufficient. Those files are read by sessions entering _that_
repo, never by the people or agents who own the fix, so the defect stays latent
for every other consumer.

This is the corollary of §0 (canonical source authority): **if canon owns the
rule, canon owns the defect report.**

### 18.1 The rule

- **The test is OWNERSHIP, not severity.** If the fix belongs in another repo's
  files, it gets an issue there. A local workaround does not discharge the
  obligation — ship the workaround **and** file the issue.
- **One issue per defect.** Group only trivially-related items (e.g. several
  doc-accuracy corrections), and say so up front. New evidence for an
  already-filed defect goes on that issue as a **comment**, not a new thread.
- **Link it back.** Record the issue number in the finding repo's `DECISIONS.md`
  or `HANDOFF.md`, so a later session finds the upstream thread instead of
  rediscovering the defect as a fresh bug.

### 18.2 What a filed issue must contain

| Element | Why |
|---|---|
| Reproduction against **their** source — `file:line` plus the command or run that exercised it | An unreproduced report is a guess the owner must re-derive |
| Blast radius, **checked** across the fleet rather than assumed | Distinguishes "my repo" from "every consumer" |
| Why it was hard to diagnose, when the symptom misnames the cause | The diagnostic cost is often the larger half of the defect |
| A concrete suggested fix | Turns a complaint into a starting point |
| What is **not** broken, where you checked and it was fine | Bounds the owner's search |

### 18.3 Why this is a canon rule and not a preference

The evidence is CI-0014 (issue #305). `ci/v1.x` `ai-review` silently fell back
to an engine no consumer had credentials for once the shared trust config moved
to schema v2. That broke the AI review gate on **seven repos for ~9 days**,
behind a symptom (`no parseable verdict — fail-closed`) naming neither the
cause, nor the trigger — a schema change in a _different repository_ — nor the
owner.

A consumer's `HANDOFF.md` had recorded a **wrong** root cause and prescribed a
fix that would not have worked. That misdiagnosis survived multiple sessions.
It survived **precisely because it was only ever written down locally**: nothing
about a per-repo `HANDOFF.md` reaches canon, and canon is where the fix lived.

This generalises. Where **one shared config plus per-consumer version pins** is
the norm (§4.2b), a defect found in one repo is very often a defect for all of
them, and the finding repo is systematically the wrong place to write it down.

### 18.4 Read the filed artifact back — `--body -` publishes an empty issue

**`gh issue create --body -` sets the body to a literal `-`.** It exits 0 and
prints a URL, so it looks like it worked. `--body-file -` is the flag that reads
stdin.

This is not hypothetical: **all five issues from the `ci/v2.14.0` migration
(#305–#309) were initially published empty this way**, and were caught only
because a human went and looked. A filing rule that does not survive its own
tooling is not a filing rule.

**Therefore: after filing or commenting, read the artifact back.**

```sh
gh issue view <N> -R <owner>/<repo> --json body --jq '.body | length'
```

A length of `1` (or `0`) means the body did not land. The same applies to
`gh issue comment` and `gh pr comment`. Prefer `--body-file <path>` for anything
longer than a sentence, and verify before considering the defect reported —
under §18 an empty issue discharges nothing.

**Origin:** issue #310, proposed from the `ci/v2.14.0` migration; adopted first
in `aidoc-flow-framework`. Recorded as CI-0020.

## 19. Infrastructure break-glass — an outage must not require `--admin`

**When the reviewer is DOWN (as opposed to requesting changes), the supported
path is `ai:review-infra-error` plus an allowlisted human approval at HEAD — not
`gh pr merge --admin`.** Opt-in per repo.

### 19.1 The problem

`call / ai-review` is a required context on every non-bootstrap tier, and
`skip-ai-review` is deliberately **advisory**: it carries a _prior_ App approval
across trivial pushes and refuses when the App has never approved. Correct as a
default — but it means that during a reviewer outage there is **no
non-`--admin` path to merge anything**, including the PR that would fix the
reviewer.

`--admin` is not a targeted override. **It bypasses every required check, not
just the broken one.** So an outage pushes operators into a habit that disables
the entire gate, and once `--admin` is routine, nobody reads the gate at all.

That is how CI-0014 stayed hidden: seven repos ran a fail-closed `ai-review` for
~9 days, every merge went through `--admin`, and a wrong root cause sat
unchallenged the whole time. The outage and the normalisation of `--admin` were
mutually reinforcing.

### 19.2 The exchange — three independent conditions

`composition` passes only when **all three** hold:

| # | Condition | Role |
|---|---|---|
| 1 | `ai:review-infra-error` is on the PR | **Signal** — the reviewer is down, not dissenting |
| 2 | An `APPROVED` review at the **current head SHA** from a non-Bot login in `vars.CI0021_BREAKGLASS_APPROVERS` | **Authorization** |
| 3 | That approver **did not author or push any commit at HEAD** | **Separation of duties** |

**Opt-in.** `vars.CI0021_BREAKGLASS_APPROVERS` unset — the default — means the
break-glass does not exist and behaviour is exactly as before. It is a repo
**variable**, not a caller input, because it must be admin-writable only: a
caller-supplied input would let the repo being gated choose its own overriders.

### 19.3 Why each condition is load-bearing

- **The label is never authorization.** Anyone with write access can add a
  label, and `ai-review` auto-applies this one on any reviewer-client failure —
  including an oversized diff, which a determined actor can induce.
- **`author_association` is not a permission check.** `MEMBER` and
  `COLLABORATOR` do not imply write access, so they cannot stand in for an
  allowlist. The App path next to this one pins a numeric id for the same
  reason: identity claims that are easy to obtain are not authorization.
- **Separation of duties is the one GitHub does not give you.** GitHub forbids
  the PR **author** from approving — it says nothing about whoever **pushed**
  the commits. A collaborator can push to another user's PR branch and then
  legitimately approve it. Canon's tier templates set
  `required_approving_review_count: 0` and `require_last_push_approval: false`,
  so on `ops`/`product`/`bootstrap` this check is the only gate on the diff.
  Without condition 3, one account could push code and clear it.

  **What condition 3 actually checks, and its limit.** It compares the approver
  against the git **author** and **committer** logins of every commit at HEAD.
  It does _not_ check the pusher: GitHub's REST API exposes no pusher field —
  that exists only on the push webhook and the audit log. Author and committer
  are written by whoever ran `git commit`, so a **deliberate** actor can set a
  commit email that resolves to a different account, or to none.

  Unattributable commits therefore **fail closed**: when an email matches no
  GitHub account both login fields are `null`, and treating that as "no author"
  would exempt exactly the actor this condition exists to catch. An incomplete
  commit listing (the API caps at 250) fails closed for the same reason.

  The residual is real and worth stating plainly: **without commit signature
  verification, condition 3 stops an accident and a careless actor, not a
  determined one.** A repo arming this break-glass on a tier where
  `required_approving_review_count: 0` should also set `required_signatures:
  true`, so that authorship is cryptographic rather than self-asserted.
- **Latest review per user wins.** The reviews API returns every submission as
  its own object retaining its own state, so an `APPROVED` later retracted by a
  `REQUEST_CHANGES` at the same SHA would otherwise still match.

Do **not** describe this as guaranteeing "a second person": it guarantees a
second **account** on the allowlist that did not write the code. An
organisation that allowlists a machine account has given that account the
authority, which is a choice the allowlist makes visible.

Fail-closed throughout: if the review list _or_ the commit authorship cannot be
fetched, the check blocks. An unverifiable separation-of-duties test is not a
passed one.

### 19.4 Properties worth preserving

- **Targeted.** Only the `ai-review` gate is discharged; `verify`, `gitleaks`,
  lint and audit-trail still apply. That is the entire difference from `--admin`.
- **Auditable.** The pass emits a `::warning::` naming the approver and stating
  the App did not approve. `--admin` leaves no comparable trace.
- **Revocable**, with a caveat: removing the label re-blocks on the next
  evaluation, but during a live outage `ai-review` fails again and re-applies
  `ai:review-infra-error`. Do not plan a rollback around removing the label
  alone — remove the approver from the allowlist to actually disarm it.
- **Cannot drive auto-merge.** `auto-merge-ai-prs.yml` independently requires
  `ai:review-passed` plus an App approval, and `ai:review-passed` /
  `ai:review-infra-error` are mutually exclusive — so a break-glass pass never
  produces an automated merge.

**Origin:** issue #311, from the `ci/v2.14.0` migration. Recorded as CI-0021.

## 20. A prompt states the model's real inputs — and nothing else

**Every instruction in a model-facing prompt must be executable with the inputs
that prompt is actually given. An instruction the model cannot carry out is not
skipped — it is answered anyway.**

### 20.1 The failure mode

A deterministic step that cannot do what it was told fails loudly: the file is
missing, the command exits non-zero, the job goes red. A model told to do
something it cannot do produces text _consistent with having done it_. The
instruction becomes a licence to assert, and the assertion arrives with the
same confidence as a real finding.

This is worse than a missing check, because the reviewer's output is a merge
gate. A fabricated `medium` blocks a PR, consumes an OPS-0066 review cycle, and
sends the author to fix something that was never wrong.

### 20.2 The rule

Rules 1-7 govern the two prompts this repo ships as files
(`ai-review/review-prompt.md`, `ai-review/fix-prompt.md`); **rule 8 reaches
further — see its own Scope note**:

1. **Enumerate the inputs.** The prompt states, up front, exactly what the model
   receives and that it receives nothing else — no tools, no filesystem, no
   working tree unless one is genuinely present.
2. **Every rule is decidable from that list.** A rule whose precondition cannot
   be evaluated from the stated inputs is either given the input it needs, or
   narrowed to the cases the inputs settle, or removed. "The model will probably
   get it right" is not a third option.
3. **Name the undecidable cases explicitly.** Where a check is partly decidable,
   the prompt says which cases are decidable and instructs the model to emit
   nothing — not a hedge, not a `low` — for the rest. Silence is the required
   output when evidence is absent.
4. **An unavailable input has a literal marker.** When an input can fail to be
   collected — or to be shown COMPLETE — the assembly writes a fixed sentinel
   (canon uses `UNAVAILABLE`) and the prompt branches on it. An empty or
   truncated block must never be able to read as evidence of absence.
5. **A filtered input is a lying input.** If the assembly narrows what it
   collects, the prompt must say so where the rule consumes it, or the omitted
   category reads as "absent from the repo". Prefer collecting the whole set
   with the distinction marked over filtering it away.
6. **The assembly and the prompt are one contract.** The step that builds the
   prompt and the prompt's own "your inputs" section must list the same blocks,
   by the same names, in the same order; `tests/test_contract.sh` asserts the
   names, the order and the count. Changing one without the other re-creates
   this defect.
7. **A degraded input set is disclosed to humans.** A review that ran with an
   input missing is, by construction, the one that goes green — and nobody
   reads the log of a green check. Canon puts the degradation in the PR comment,
   so an unevaluated rule is not indistinguishable from a passed one.
8. **The set a prompt shows a model and the set the code will accept from it
   must agree — and a datum the prompt never turns into an imperative
   constrains nothing.** Two obligations, and each fails on its own:
   - **Show the accepted set, and narrow before you truncate.** An input wider
     than what the consumer will accept manufactures rejections and charges
     them to the model. Where the assembly can narrow a block to the accepted
     set, it does — and the narrowing precedes any truncation of that block,
     or every rejectable entry sorting ahead of an acceptable one consumes a
     slot and the truncation discards the accepted set instead. This is a case
     rule 5's "prefer collecting the whole set" preference yields to, because
     the omitted entries are not merely unmarked but _rejectable_; rule 5's
     labelling obligation still applies in full, so the narrowed block's own
     label states its scope.
   - **State the constraint as an instruction.** A labelled block is an input,
     not a prohibition; the model has no way to tell which of the blocks it was
     handed is enforced. Where the consuming code rejects on a rule, the prompt
     must instruct the model to obey that rule, naming the block it applies to
     **by that block's label** — never by position, which is false the moment a
     block moves. This bites hardest when the prompt also declares
     consumer-supplied text untrusted DATA: canon has then instructed the model
     to disregard any equivalent rule the consumer wrote for itself, so the
     imperative must be canon's own.

   The imperative is **advisory** — it makes non-compliance less likely, not
   impossible, and the enforcement branch in the consuming code remains the only
   guarantee. Do not record a prompt sentence as closing a failure bucket;
   re-measure the bucket after the change instead. And where the narrowing is a
   no-op for a given consumer's configuration, do not let a release note claim
   the gain for that consumer.

   **Scope.** Rule 8 was derived from a third prompt this repo shipped — the one
   `scripts/doc-maintainer/planner.py` assembled — which is **deleted** with that
   flow (CI-0040). The rule now governs the two prompts named in the lead-in, and
   is stated in general terms because it is not about the prompt that produced
   it. Its `#413` non-compliance record (rules 1, 4, 6 and 7 unmet on the deleted
   prompt) closed _not planned_ with the flow; do not read that closure as canon
   having achieved compliance.

### 20.3 Applied to `ai-review` (ci/v2.x)

The reviewer is a **single-shot completion with no checkout** (IPLAN-0024,
`ai-review.yml`). Its inputs are exactly three fenced blocks: the changed-file
inventory, the repo-root file inventory, and the secret-redacted unified diff.

The doc-coverage rule (§"Doc-coverage rule" in the rubric) is gated on whether
the consumer has `CHANGELOG.md` **at its root** — a fact the diff and the
changed-file inventory cannot establish, since a repo that has the file and did
not touch it looks identical to a repo that has none. That precondition is now
answered by the repo-root inventory rather than guessed. The dead-link rule is
narrowed to the three cases the inputs settle: a root-level target, a target the
PR itself deletes or renames, and a reference internal to the diff.

The root inventory lists **every** root entry, directories carrying a trailing
`/`. Listing only regular files would have been rule 5's failure: every root
directory would be absent from a list the dead-link rule reads as authoritative
for absence, so `docs/…` would be flagged dead because `docs` was filtered out.

It **fails soft**: on an API failure, an empty body, an unknown base commit, or a
listing at the contents API's 1000-entry cap, the block is the literal
`UNAVAILABLE` and the dependent rules are inapplicable. That is not a fail-open
— an unavailable input can only _suppress_ a blocking finding, never manufacture
one — and hard-failing a required check on a transient API blip would be worse.
The changed-file inventory is held to the same standard: it is reported
`UNAVAILABLE` unless provably complete, and the rubric falls back to the diff's
own `diff --git` headers.

### 20.4 Scope note

This is a **prompt-construction** rule, not a model-quality one. It says nothing
about how good the review is; it says the reviewer must not be asked questions
it has no way to answer. The same discipline applies to any future prompt canon
ships, including a per-consumer rubric override if one is ever built.

**Origin:** issue #315 (and #81, its v1 symptom). Recorded as CI-0022.

## 21. A fail-closed guard fails on faults — not on what a consumer happens to have

**A mandatory safety mechanism must abort only when it genuinely cannot do its
job. Aborting because of a benign, legal shape in the consumer's tree turns a
safety mechanism into an availability defect.**

### 21.1 The failure mode

Fail-closed is the right default for a guard whose whole purpose is to protect
something (FT-57's pre-write backup: if the snapshot cannot be taken, write
nothing). The trap is that "cannot take the snapshot" quietly widens to include
inputs that are merely _unusual_ rather than _broken_.

`install.sh` enumerates the consumer's surfaces with `find -L … ! -type d`,
which yields a **dangling symlink** — the stat fails, so `find` returns the link
itself. The copy was a bare `cp -p`, which **dereferences**. A consumer that
carried one broken symlink anywhere under `.github/` therefore could not run
`install.sh` **in any mode**, including the documented `--repin` upgrade path.
Nothing was wrong with that repo, and nothing about the backup was actually
impossible — the link is perfectly copyable _as a link_.

### 21.2 The rule

For each input a guard enumerates, decide explicitly whether it is a **fault**
(abort) or a **shape** (handle it). Write the branch, say in a comment which it
is and why, and **do the sweep across every arm of the guard** — the same input
shape usually reaches it by more than one path. Concretely, for the backup:

| Input | Classification | Behaviour |
| --- | --- | --- |
| Resolvable symlink | shape | captured by **content** (what a restore wants) |
| Dangling symlink | shape | copied as the **link** (`cp -Pp`) — no content exists |
| Symlink **loop** | **fault** | aborts: `find -L` cannot traverse it, so completeness cannot be proven |
| Unreadable file | **fault** | aborts |
| Unenumerable directory | **fault** | aborts |

The sweep is the part that gets skipped. This backup enumerates from **two**
arms — a `find -L` over `.github/` and an explicit root-list loop — and the
dangling-symlink case was wrong in _both_, in opposite directions: the copy
aborted on it (fail-closed), while the root list's `[ -e "$r" ]` test
dereferences and so **dropped it silently** (fail-open, the outcome this guard
exists to prevent). Fixing only the arm that announced itself with an error
would have left the quieter, worse half in place.

**A fault must also name itself correctly.** A symlink loop and an unreadable
directory both surface as a non-zero `find`, but the remedies are unrelated;
reporting the loop as "unreadable subdirectory?" sends the operator to `chmod`
for a cycle no `chmod` can fix.

**Residual, stated rather than papered over — and scoped to the arm it applies
to.** `[ ! -e ]` is false for `EACCES` as well as `ENOENT`, so a resolvable link
whose target sits behind an unsearchable directory is misclassified as dangling
and backed up as a link rather than by content. This is reachable **only on the
root-list arm**. On the `.github/` arm it cannot happen: `find -L` stats the
link, gets `EACCES`, and the run hard-aborts before the copy branch is reached —
so that arm is _more_ conservative than this table's "shape" row suggests, not
less. Reaching the residual at all requires running the installer as someone who
cannot traverse the consumer's own tree.

Do not "simplify" such a branch away. Collapsing this one to a blanket `cp -P`
would silently stop capturing content for resolvable symlinks — a different
defect in the same place — which is why the test suite asserts both directions.

### 21.3 Enforcement

`tests/test_install.sh` drives the `MANDATORY-BACKUP` block extracted from
`install.sh` itself, and includes a **mutation** case: restoring the bare
`cp -p` must make the dangling-link fixture abort. An assertion that cannot fail
is not a guard.

**Origin:** found in the `ci/v2.15.0` pre-cut review, a regression introduced by
FT-57 in the same unreleased window. Recorded as CI-0023.

## 22. A mechanical rewriter must not rewrite illustrative examples

**A tool that propagates a current value across the docs must distinguish
references that should TRACK that value from references that are historical or
illustrative. Matching on shape alone is not that distinction.**

### 22.1 The failure mode

`scripts/sync-version-refs.sh` makes `VERSION` the single source for install
references, rewriting four shapes: the raw-URL install command, `uses:…@tag`
pins, and `CI_TAG=`. Shape says _"this is an install reference"_; it does not
say _"this one is supposed to be current."_

`docs/MIGRATION_v2.0.0.md` is a target and contains two `CI_TAG=` commands that
must **not** track `VERSION`: the §5 "repin to `@ci/v2.0.0`" step, and — the
damaging one — the **Rollback** section, whose command exists to pin a consumer
_back_ to `ci/v1.x`. Every release cut rewrote both to the new tag, so the
published rollback instruction re-pinned **forward**: an operator following it
during an incident would do the exact opposite of what the heading promised.

The script's header had _already identified this risk_ and prescribed the
remedy — "if a historical install command is **ever added** to a target, mark
that line to exclude it".

**That caveat was accurate when written**, and the history matters more than the
defect. At `a0fc68c` (2026-07-09) `TARGETS` held two READMEs and
`MIGRATION_v2.0.0.md` did not exist; the warning was correct and prospective,
and it named its own trigger condition — though it anticipated the inverse
event: an example being added to a target, rather than a file that _already_
contained two being added to `TARGETS`. That is what happened on 2026-07-17, when
`1a027da` (#175) added that doc to `TARGETS`. The rollback command read
`ci/v1.9.5` until that commit and has tracked the release tag at every cut
since.

So the failure is not a wrong comment. It is that **the prescribed remedy was
described but never implemented**, leaving nothing for #175 to fail against —
and the author of a commit eight days later has no reason to read this file.

### 22.2 The rule

Any span whose install references are illustrative or historical is wrapped:

```text
<!-- sync-version-refs:ignore-start -->
… examples pinned to an old tag on purpose …
<!-- sync-version-refs:ignore-end -->
```

Both `--check` and the rewrite honour the markers. **Unbalanced markers are a
hard error** (`exit 2`), naming the file and line: an unterminated
`ignore-start` would otherwise freeze the rest of a file silently, converting
this guard into the drift it exists to prevent.

**A caveat that names a future trigger condition must be enforced mechanically,
in the same change that names it.** Prose cannot stop the commit that trips the
trigger, because that commit is written months later by someone who never opens
the file the prose lives in. If the enforcement genuinely cannot be built yet,
the comment must say the gap is **unguarded** — an unguarded risk that reads as
handled is worse than one stated plainly, because it survives review.

**This section is held to its own rule.** The marker facility alone would be a
second unenforced caveat, so `tests/test_version_sync.sh` **pins the explicit
`TARGETS` array**: adding a file to it fails the suite with instructions to
inspect the new target for illustrative install commands and wrap them. That is
precisely the event #175 tripped. The two **glob** arms are deliberately not
pinned — a caller template's pin _should_ track `VERSION` — so do not read the
guard as covering them.

**What remains, split honestly into the guarded and the unguarded half** — the
first draft of this section called both unguarded, which was itself the error
this section legislates against:

- **Pinned to an OLD tag** (the #175 case): **guarded.** `--check` flags it as a
  stale reference and fails **both** the local pre-commit hook and CI. The hook
  is `always_run` (#323): it was previously scoped by a `files:` regex that had
  drifted behind `TARGETS` and skipped 8 of 14 entries — including
  `MIGRATION_v2.0.0.md`, the file CI-0024 is about — so a commit touching only
  that file never fired it locally. Because the hook is `pass_filenames: false`,
  the regex never decided _what_ was checked, only _whether_ the hook ran; a
  second list to keep in step with `TARGETS` was pure drift surface.
  Its message names _both_ remedies,
  because offering only "run the rewriter" pointed the operator at the one action
  that falsifies the command — a guard that fires and then misdirects is barely
  better than none.
- **Pinned to the CURRENT tag when written:** **genuinely unguarded.** It is
  textually identical to a live reference, so nothing can separate them, and it
  drifts silently at the next cut. This half rests on the markers being used.

§22.2's escape clause covers only the second. Do not use it for the first.

### 22.3 Enforcement

`tests/test_version_sync.sh` drives `sed_program` and `validate_ignore_markers`
extracted from the shipped script, asserts both directions (outside a span is
rewritten; inside is preserved; the span closes at `ignore-end`), covers all
four malformed-marker cases, and includes a **mutation** case: stripping the
negated address ranges must clobber the historical rollback command.

**Origin:** found in the `ci/v2.15.0` pre-cut review — the release's own prep
re-falsified the rollback instruction. Recorded as CI-0024.

## 23. Only a code-changing event may cancel an in-flight run of a required gate

**A required check that is cancelled at the live head SHA can block a PR
permanently: a cancelled check is not success, and a later success of the same
context from a _separate run_ does not replace it (§23.1 scopes that claim to
what was observed). So only a genuinely code-changing event may cancel an
in-flight run of a gate — and that is expressed as an allowlist, never as a
denylist of the events the gate itself emits.**

### 23.1 The failure mode

**Observed** on the CI-0025 incident (`aidoc-flow-framework` #346): a `cancelled`
and a `SUCCESS` check-run for the same context name, from two different workflow
runs, both persisted on the same head SHA, both reported `isRequired`, and the
rollup was `FAILURE`. A later success from a _different run_ did not displace the
earlier cancellation. Branch protection then refuses the merge and the only escape
is `--admin`.

**Scope, settled (#330).** The mechanism is a **re-run attempt vs. an
independent run**, not a matter of sample size: `gh run rerun` reuses the same
workflow-run id (a new _attempt_), while a label add/remove is by definition a
distinct triggering event and so produces a distinct run and check-run. The rule
is therefore about _separate runs_. A
**re-run of the same run replaces** its check-run, which is why re-running clears
a stuck check; a **separate run adds a second check-run alongside**, and both are
retained. Measured both ways: an in-place re-run took `suite` from check-run
`89856301834` (`failure`) to `89857163070` (`success`) leaving **one** check-run
on the SHA, while two separate runs on `aidoc-flow-framework` #346 left **two**
`call / ai-review` check-runs (`cancelled` + `success`) and a `FAILURE` rollup.

`docs/troubleshooting.md` §15 previously recommended a label cycle to clear a
stuck check. A label cycle starts a _separate_ run, so it adds a context rather
than replacing one — during the CI-0025 incident one cycle took a PR from one
cancelled run to two. §15 is corrected to scope it to contexts that never
reported.

### 23.2 The rule

**Express `cancel-in-progress` as an allowlist of the code-changing events, never
as a denylist of the self-emitted ones.**

The rule's trigger is **required-context ∧ non-code-changing-event**, and note
that it is NOT limited to events the gate emits. §23.1's mechanism does not care
who wrote the label — a _human_ label write at the live head SHA cancels an
in-flight required check just as effectively. Canon has at least two more
instances beyond `ai-review`: `audit-trail` (`call / verify`) whose caller
subscribes to `labeled`/`unlabeled` for the documented `skip-audit-trail` escape
hatch, and the lint family (`call / Lint / format / security hooks`) via
`reopened`. **Both are fixed** (#329): the eight caller templates feeding a
required context — `audit-trail`, `pre-commit`, `secret-scan`, `markdown-lint`,
each in its public and private variant — now carry the same fail-safe allowlist,
**and so do canon's own five** (`audit-trail`, `self-pre-commit`,
`self-markdown-lint`, `self-secret-scan`, `tests`) per the §16.6 Wave 0 rule. The
first draft of this fix shipped the templates only and left canon's own `main`
exposed — the lesson-not-swept failure §23.3 names, committed while amending §23.3.
A workflow that is not a required context on any tier is exempt, because a
cancelled non-required context does not block anything; `labeler`, `links` and
`codeql` are therefore deliberately left alone.

**Where `cancel-in-progress` lives decides the release boundary.** `ai-review`
sets it in the **reusable**, so its fix reached consumers by a re-pin. For
`audit-trail` and the lint family the reusables carry no `concurrency:` block at
all — the flag is in the **caller templates**, so those fixes require consumers to
**re-install** the affected callers; `--repin` rewrites `uses:` lines only and
will not deliver them. That is why the two shipped in different releases.

A denylist fails twice over, and canon shipped both failures before arriving here:

- **It is never complete.** You must enumerate every event the gate emits _and_
  keep that list in step with the caller's triggers. The first CI-0025 fix was a
  denylist; it added `pull_request_review` and still cancelled on `reopened`,
  `ready_for_review` and `converted_to_draft` — the last two added to the caller
  by FT-43 _after_ the predicate was written. Every event except a head-SHA change
  fires at the live head, so every one of them reproduces the defect.
- **It fails in the unsafe direction.** Where the `github` context can resolve
  empty — `concurrency` on a _called_ workflow has that history — `!=` clauses all
  evaluate true and the gate cancels everything, which is precisely the bug. `==`
  yields false and cancels nothing. **A guard whose degraded mode is the failure it
  exists to prevent is not a guard.**

Both a flat `cancel-in-progress: false` and a correct allowlist are acceptable;
the contract test accepts either. `false` is the simplest safe answer and is
composition's choice. Prefer an **allowlist** when superseding on push still
matters — which on the **serial** self-hosted pool it does even for cheap jobs,
because the constraint is pool occupancy, not cost per run: a stale lint run that
is not superseded blocks the next job in the queue. That is why the required-context
lint and scan callers use an allowlist rather than `false`.

**Residual, not closed by this rule.** GitHub cancels a _pending_ run when a
newer one queues in the same group, independently of `cancel-in-progress`. If a
pending-cancelled run materialises a check-run, a second non-code-changing event
while one is already queued reproduces the defect. Unverified either way, and it
applies to a flat `false` too. This rule removes the deterministic case; it does
not make the group safe by construction. Dropping `concurrency` entirely, or
keying the group by event, would.

**The test must evaluate the expression, and must derive its cases from the
caller's own `types:` list** — so adding a trigger fails the suite until someone
classifies it. A hand-written case table is how the first fix passed while still
broken.

### 23.3 Carry the lesson across every workflow that shares the shape

`composition.yml` already stated this rule at its own `concurrency:` block —
"cancelling it … would leave a satisfied PR permanently blocked" — and set
`cancel-in-progress: false`. `ai-review.yml` had the same exposure and did not get
the same treatment. FT-43 then fixed the label half of `ai-review` without
generalising to the review half.

**The recurring defect is a lesson learned in one file and not swept across the
others that share its shape.** When a rule like this is established, grep for the
shape — here, every reusable reachable from a caller that subscribes to an event
the gate itself emits — and **record the negatives too**. For this sweep: there is
no `issue_comment` trigger anywhere in canon, so verdict comments are inert; and
`set_label` writes with `GITHUB_TOKEN`, whose events do not start workflow runs,
so the gate self-emits one triggering event per run (except when `autofix` is
armed). An unrecorded negative gets re-derived by the next reader, which is the
recurrence this section exists to stop.

**And a recorded negative must itself be checked.** A draft of this section
claimed the gate's label writes re-trigger `labeler`; they do not — `labeler`
subscribes to the default `pull_request_target` types (`opened`, `synchronize`,
`reopened`) and not to `labeled`/`unlabeled` at all. That false negative also
contradicted the `GITHUB_TOKEN` bullet beside it. A wrong recorded negative is
worse than none: it is the thing the next reader trusts instead of checking.
§21.2 makes the same demand for a guard's multiple arms.

### 23.4 A fail-closed guard that cannot fail open is only a cost

A guard is worth its cost only if some reachable state it blocks would otherwise
be unsafe. Establish that state before adding one, and re-establish it when the
model it rests on changes — otherwise the guard survives on its name.

`ai-review`'s FT-43 step is the worked example (#331). It `exit 1`d on any draft
or non-`skip-ai-review` label event while the reviewer App was unarmed, to stop a
fresh SUCCESS "superseding" a standing `request_changes`. Two things were wrong,
and the second is the general lesson:

- §23.1 says a later SUCCESS from a **separate run** never replaces an earlier
  conclusion, so there was nothing to supersede.
- **It never covered the events that would have mattered.** `reopened`,
  `ready_for_review` and `pull_request_review: submitted` all re-fire a full
  review at an unchanged HEAD on an unarmed repo, and the guard's `if:` named
  none of them. Had the supersede risk been real, those three were already the
  bypass. A guard defending a **proper subset** of an open surface closes nothing
  — so its removal did not depend on §23.1 being right.

What it did instead was write a **permanent** non-success required context on the
live head SHA (§23.1) — and the gate triggered it _itself_, because its own
`ai:review-passed` write fires a `labeled` event. An unarmed repo went
`--admin`-only on its own label.

**Corollary — a gate must not re-enter itself.** Removing the step left the
job-level `if:` routing the gate's own label writes back into a full review, so
those `ai:review-*` writes are now excluded explicitly. §23.2's allowlist rule
covers cancellation; this covers _triggering_. Both reduce to: enumerate what the
gate emits, and make sure none of it comes back in.

**Origin:** issue #322, reproduced on `aidoc-flow-framework` PR #346. Recorded as
CI-0025. §23.4 added from #331.

## 24. The PLAN-021 cluster — shell, message, template and prompt discipline

**§24 is a container, not a single rule.** It holds four independent sub-rules,
one per PLAN-021 **code** PR (PR-A…PR-D; PR-0 was the decision record and
carries no rule). §24.1 shipped with PR-A, §24.2 with PR-B, §24.3 (_a default a
canon template recommends must be executable by the code that consumes it_) with
PR-C, and §24.4 (_what canon shows a model must agree with what canon will
accept from it_) with PR-D. §24.4's rule belongs to prompt assembly and is
therefore carried by §20.2 rule 8, which §24.4 extends.

**All four rules are KEPT, and their evidence is now HISTORY (CI-0040).** Every
measurement in §24 was taken against `doc-maintainer`, which is retired and
deleted. The rules are general — implicit `bash -e` in any `run:` step, error
de-conflation, template-default executability, prompt/enforcement agreement —
and doc-maintainer was only the surface that happened to prove them. Read the
worked examples in the past tense; do not treat a deleted flow as a reason to
drop a rule.

**And note what no longer watches them.** §24.2's and §24.3's assertions lived
in `tests/test_scripts.sh` and `tests/test_contract.sh` and read the deleted
scripts and templates, so both rules now have **zero automated readers** and are
enforced by review alone. That is declared in the suites themselves; it is
recorded here so a reader of the rulebook is not misled by a green suite.
**§24 is claimed in full by PLAN-021 — a later plan wanting a new section takes
§26**, PLAN-023 included. (§25 went to issue #387, which landed first; PLAN-023
already declares that it yields and renumbers on landing.)

### 24.1 A tolerated non-zero exit must be scoped off

**A step that tolerates a command's non-zero exit must scope `-e` off around that
command — `set +e` … `set -e`, or a tested context. Adding `set -uo pipefail` at
the top of the step does NOT do this, because the `-e` it would have to clear was
applied by the shell GitHub invoked, before the step's first line ran.**

For a `run:` step with no `shell:` key and no workflow `defaults:`, GitHub's
implicit default shell on Linux is **`bash -e {0}`**. The step's own
`set -uo pipefail` adds `-u` and `-o pipefail` and leaves that inherited `-e` in
place; the effective flag set is `-euo pipefail`. Only `set +e`, or putting the
command in a tested context (`if cmd; then`, `cmd || { … }`, `cmd && { … }`),
suppresses it.

Do not confuse the implicit default with the string an **explicit** `shell: bash`
selects, `bash --noprofile --norc -eo pipefail {0}`. Both carry `-e` — which is
all this rule turns on — but only the explicit form carries `-o pipefail`, so a
harness that drives one step's block under the other's flags is testing
something the step never runs.

**A comment asserting the opposite is a defect in its own right**, not a
harmless inaccuracy: it is the artifact a later reader uses to decide the step is
already safe. Canon shipped two — `doc-maintainer.yml` carried
`` `set -uo pipefail` (no -e) `` twice, at the two steps whose explicit
`|| { echo "::error::…"; exit 1; }` gates the comments were there to justify.

State the reason correctly, because the gate's purpose is not what the wrong
comment claimed. Under bare `-e` a failing command **already** fails the step; the
explicit `|| { … }` gate exists so it fails **with an `::error::` annotation
instead of silently**, which is the substance of the fail-LOUD requirement
(IPLAN-0025 D12). Describing the gate as redundancy invites its deletion.

**The failure mode is a silent step, and the log actively misleads.**
**Observed** on `doc-maintainer.yml` Step 9. The dry-run patch renderer ran
`diff -u … >> "$PATCH"` — which exits 1 **whenever the files differ**, the normal
case for a proposed edit — and captured `rc=$?` on the next line under a
`[ "$rc" -le 1 ]` guard written to tolerate exactly that. The inherited `-e`
killed the step **at the `diff`**, so the capture and the guard were unreachable.
Every dry-run carrying ≥1 **low-risk** proposed edit died with a bare `exit 1`
and no annotation — the loop is fed `.low_risk_set[]` only. It shipped in every
release that carried the renderer, `ci/v2.0.0` through `ci/v2.16.0`, so the path
had never once worked.

Two properties make this class expensive to diagnose, and both generalise:

- **The step emits nothing.** `gh run view --log-failed` yields only
  `##[error]Process completed with exit code 1.`
- **`--log-failed` echoes the step's `run:` source**, so any `::error::` string
  _literals_ in the step body appear in the log and read as though those guards
  had fired. Distinguishing emitted output from echoed source needs the
  `\x1b[36;1m` command-echo prefix filtered out. Grepping for `##[error]` is not
  enough.

**Auditing a step for this.** Enumerate the step's commands that may
legitimately exit non-zero, and confirm each is either scoped with `set +e` or
in a tested context. A command that is
neither is the defect. `diff`, `grep -q`, `git diff --quiet`, `cmp` and
`jq -e` are the usual carriers — all of them signal a **result** through exit
status, so tolerating that status is the whole point of the call.

**A regression test must drive the step under `bash -euo pipefail`**, the real
flag set. A test that drives it under the step's own `set -uo pipefail` alone
does not reproduce GitHub's shell and will pass against the unfixed code.
**Extract and drive the real block — never re-implement it** (a re-implementation
tests the copy, which is how FT-40's SHA-peel guard passed while untested), and
fence it with the repo's `# >>> NAME >>>` / `# <<< NAME <<<` markers so the
extraction does not silently break when lines above it move. Extract the
expression-free inner block, not the whole step: a `run:` body containing
`${{ }}` expressions is a bash syntax error, and a harness fed one goes red for
the wrong reason.

**Origin:** issue #352, reproduced on `aidoc-flow-framework` runs
[30546848518](https://github.com/vladm3105/aidoc-flow-framework/actions/runs/30546848518),
30548353113 and 30553994621. Recorded as CI-0027 (PLAN-021 PR-A). Same class as
the closed #306 — a dry-run branch that cannot complete, in a flow whose whole
purpose during pilot is the dry run.

### 24.2 An error message names one condition

**A guard that tests two conditions in one `if` must be split into one branch
per condition, each with its own message. De-conflate at the branch, not in the
message text.** A message naming alternatives — `duplicate or non-allowlisted
plan path: X` — is a defect whichever condition actually fired, because the
reader cannot tell which, and the two conditions have different owners and
different fixes.

**Measured.** Across `aidoc-flow-framework`'s pilot — 23 failures over its first
47 runs — `planner.py` rejected 15 plans under one such guard. **9 of the 15
named `plans/HANDOFF.md`, a path that _is_ in that consumer's `allowed_paths`**
— the cause was a duplicate every time. Read literally, the message pointed at
an allowlist that was correct the whole time; the misreading was recorded in
that repo's backlog as an allowlist misconfiguration, with a stated fix that
would have changed nothing. The message compounded it by being plausible: the
planner does hand the model the allowlist, so an allowlist error reads as a
config fault rather than as model non-compliance.

⚠️ **Those are run counts, and run counts rank wrong here.** `reconcile.py`
re-dispatches an un-maintained merge, so one merge contributes 1–4 failures. By
distinct merge the 15 rejections are **4 duplicate merges and 4 non-allowlisted
merges out of 12 failing merges** — tied, where the run counts read 9 and 6.
Quote the by-merge figure when ranking a fix; see `DECISIONS.md` CI-0027,
whose title is that finding.

**Rewording is not the fix.**
Splitting the branch is what makes the _dispositions_ separable, and they were
never the same: a duplicate is a plan-quality problem, a non-allowlisted path is
a safety-boundary problem. While both conditions share one branch, both must
share one disposition — so the cheap fault forces the expensive one's blast
radius. Here that meant a repeated path discarded an entire completed LLM
planning call.

**A field a schema declares must be written by some path.** The same guard
aborted before either `validation.rejected` or `validation.allowlist_violations`
could be populated, so both shipped declared-and-never-populated — and the
IPLAN-0025 P4 graduation gate, which requires _zero allowlist violations_, had
no artifact to count. A declared-never-populated field reads to a consumer as a
measured zero.

**Where a violation must both be recorded and kill the run, record then fail:**
write the artifact, then exit non-zero, having collected **all** violations
first. Failing at the first one makes the artifact's contents depend on where in
the input the first violation happened to fall, which is not a count.

⚠️ **Do not justify record-then-fail by artifact countability without checking
that something reads the artifact.** In this flow **nothing reads
`validation.*`** — Steps 8-11 read the plan for its risk sets only, the plan
JSON is never uploaded (the upload takes the _patch_), and `Cleanup` is
`if: always()` and removes it, so no reader outside the run can ever see the
record. The de-conflated `::error::` line in the log is what makes the
violations countable — so the **emission must be deduplicated on the same key
as the count**, or the summary names a number the lines above it do not add up
to. The narrow reason record-then-fail is still right is the one above: it
stops the schema declaring a field it never populates.

**Each rejection branch must `continue`, and a test must prove it.** Recording a
rejection and then falling through re-creates the very defect being fixed,
because the per-entry validation below the guard still runs on the rejected
entry: a rejected path absent from disk aborted as `planned documentation file
does not exist` — one condition reported as another again — and a rejected path
present on disk was classified into the accepted set, handing a recorded
violation to the apply stage. **Assert the rejected path is absent from the
accepted sets**, not merely that the message changed; a message-only assertion
passes against both bugs. Drive both shapes — one rejected path on disk, one
not.

**Origin:** issue #353, measured on `aidoc-flow-framework`'s 23 `doc-maintainer`
failures over its first 47 runs under `ci/v2.16.0`. Recorded as CI-0027
(PLAN-021 PR-B). The
blast-radius half of the same defect on a different guard — the 30 %-deletion
trip, which redded the run rather than dropping the entry — was tracked as
[#372](https://github.com/vladm3105/aidoc-flow-ci/issues/372) and **closed _not
planned_ with the flow** (CI-0040). It was never fixed; the guard it describes
no longer exists. The RULE above stands on its own and is not affected.

### 24.3 A default a canon template recommends must be executable by the code that consumes it

**A value shipped as a default in a canon template is a claim that the code
downstream of it will accept that value. Where a later stage can refuse the
default, the template must not route the value to that stage — and where the
refusal turns on a quantity that moves in one direction, "it works today" is not
the test.**

**Measured.** `apply.py` refuses full-file regeneration above `MAX_APPLY_BYTES`
(200 KB). `install/templates/doc-maintainer.json` shipped `CHANGELOG.md` in
**both** `allowed_paths` and `auto_merge.low_risk_paths`. Sizes as measured at
diagnosis, `wc -c` on 2026-07-30:

| File | Bytes | Against the limit |
|---|---:|---|
| `aidoc-flow-ci/CHANGELOG.md` | 363,377 | 1.8× — canon's own |
| `framework/CHANGELOG.md` | 281,502 | 1.4× — failing at the time |
| `operations/CHANGELOG.md` | 89,703 | under, and running `dry_run: false` |

Re-measured 2026-08-06: `aidoc-flow-ci` 392,780 and `framework` 316,335, both
larger; `operations` unchanged at 89,703, because it has taken no entry since.
**Growth is monotonic, not continuous** — a file under the limit is not safe, it
is undated.

Three of `aidoc-flow-framework`'s 23 pilot failures — **3 of its 12 distinct
failing merges** — were this refusal. Nothing between the two files stops it:
the planner is given no file sizes at all — only the allowlist and a `*.md`
inventory — and the size limit lives in a different script that runs later, so
an over-limit path is planned, dispatched, and refused only after a full LLM
planning call has been spent.

**The threshold is one-way, which is what makes "under the limit today"
worthless as an argument.** A Keep a Changelog file is append-only by
construction: entries are added, never rewritten, reordered or pruned (the
workspace's changelog rule, in the global `CLAUDE.md` under "Changelog and
Roadmap Policy" — a per-agent file, so state the property rather than citing it
at a consumer). No adopter's changelog comes back under the limit. The only open
question is when each one crosses it — and `operations` will cross it in
**live** mode, not dry-run.

**It also mis-attributes.** The refusal names the file, so it reads as a
property of that document rather than of the configuration that nominated it,
and it fires only on the merges where the model happens to select the changelog
— so the same broken default looks fine on most runs.

**Four rules follow, and the first is the one most likely to be got wrong.**

1. **Demote the doomed default — do not de-allowlist it.** The knob that
   protects anyone is `auto_merge.low_risk_paths`, because that is what routes a
   path into the refusing stage; removing the path from `allowed_paths` instead
   **relocates the failure rather than removing it.** The path is still proposed
   — the conventions template canon installs alongside the config tells the model
   to use the changelog, and the merge's changed-file list reaches the model
   unfiltered. (§24.4 later narrowed the _inventory_, which was the third route,
   and added an allowlist imperative that is advisory only — neither removes
   this one.) A non-allowlisted proposal is a run-killing
   `return 1`, where a high-risk one is an issue body a human acts on. Measured
   against the shipped planner: de-allowlisted → `::error::` and exit 1;
   demoted → exit 0 with the proposal in `high_risk_set`. **De-allowlisting a
   path canon's own conventions recommend also makes canon contradict itself**,
   which is what §24.4 forbids.
2. **A `safe_to_replace: false` template change reaches new adopters only, and
   an interactive `--update` is the exception.** `--non-interactive` and the
   no-TTY path both keep the local file, so nothing is rewritten unattended. An
   **interactive** `--update` still prints a drift prompt for the file, and
   answering `[r]` replaces the whole thing — discarding every local tuning.
   Answer `[k]` and make the edit by hand. Existing consumers therefore need a
   named, hand-applied edit in the release note, not "the template changed".
   Note also that removing a path from a consumer's `allowed_paths` by name can
   be an outright no-op: `matches()` uses `fnmatch.fnmatchcase`, whose `*`
   crosses `/` with no path-separator exception, so an allowlist ending in a
   `*.md` catch-all re-admits it. The low-risk knob has no such escape, in
   **both** modes, since the apply step's `if:` carries no `dry_run` term.
3. **Pre-filter upstream, scoped to the tier that reaches the guard.** The
   planner drops an over-limit path before dispatching and records it in
   `validation.rejected` with its own reason, so a configuration mismatch
   surfaces as a note rather than a red run. **Scope is load-bearing:** apply is
   invoked only with `--tier low_risk`, so an unscoped filter would silently
   delete over-limit **high-risk** proposals, which work correctly — they are
   read by a human, not regenerated. The filter therefore runs _after_
   classification, never before it. **Scope it to the guard you are mirroring,
   and say so** — a pre-filter comment reading "drop what the next stage will
   refuse" claims coverage of every refusal that stage has, and the next reader
   will believe it.
4. **Measure with the guard's own yardstick, and declare the number once.**
   `len(read_text().encode())`, not `stat().st_size`: `read_text()` translates
   CRLF, so the two disagree on any CRLF file and the mismatch is a silent false
   drop in one direction and a false keep in the other. The limit is declared
   once in the script that enforces it and **imported** by the pre-filter; a
   second literal is an untested duplicate, and a pre-filter tuned to a limit
   the guard no longer enforces fails in the direction that looks safe.

**A pre-filter must name the configuration, not only the path.** The dropped
path is not the thing that is wrong; the entry in `auto_merge.low_risk_paths`
that nominated it is. A message naming only the file sends the reader to the
document.

**State the cost of the demotion, or it reads as free.** Demoting a changelog to
high-risk on a live consumer **retires changelog auto-maintenance there** —
which on `aidoc-flow-operations` is that flow's primary operation. That cost was
put to the founder and accepted (CI-0027); it is not a side effect to discover
after the fact.

**What is NOT wrong here.** The 200 KB guard is correct and stays: re-emitting a
281 KB file to change one entry sends the whole file through the model in both
directions and re-derives every unchanged byte, and two of the pilot's twelve
failing merges tripped apply's own 30 %-deletion guard on exactly that shape.
The defect is only that nothing prevented such a path from being _planned_. The
deeper mismatch — whole-file regeneration is the wrong edit shape for an
append-only document at any size, where the only correct edit is an insert under
`## [Unreleased]` — is real and deliberately out of scope; a section-scoped edit
mode is a separate change.

**Origin:** issue
[#354](https://github.com/vladm3105/aidoc-flow-ci/issues/354), measured on
`aidoc-flow-framework` under `ci/v2.16.0` (runs
[30557567489](https://github.com/vladm3105/aidoc-flow-framework/actions/runs/30557567489),
30546425750, 30504587299). Recorded as CI-0027 (PLAN-021 PR-C).

### 24.4 What canon shows a model must agree with what canon will accept from it

**COLLAPSED by CI-0040.** This subsection recorded the case that produced
**§20.2 rule 8** — `scripts/doc-maintainer/planner.py` handing the model an
unfiltered `rglob("*.md")` inventory while `allowed_paths`, the set the same
script rejected on, sat beside it as an unlabelled datum with no instruction
attached. That script is deleted with `doc-maintainer`, so the worked example
no longer exists in the tree and is not reproduced here.

**§20.2 rule 8 is the rule and is unchanged.** It was always the general
statement; this section was only its evidence. A future flow that assembles a
prompt from a set the consuming code rejects on is governed by rule 8 directly.

## 25. A coordination surface with N writers needs a carrier that refuses a concurrent write

Every coordination mechanism canon specifies was designed for **one agent per
repo at a time**. That assumption no longer holds: fleets of independent agents
— Claude Code sessions, Codex, DeepSeek — run against one repository with no
orchestrator and no shared context. Each mechanism is a shared mutable resource
with **no lock**, which is correct for one writer and silently wrong for N.

**This section is a no-op for a single writer.** Every rule below is already
satisfied when one agent works one repo; none of it adds a step to that case.

### 25.1 The failure mode — an unlocked compare-and-swap reads as success

The session-handoff convention is the sharp instance. "Close the current handoff
issue and open its successor" is a **compare-and-swap** — read the current value,
act on it, write a new one — with nothing between the read and the write. With
five agents:

- each closes whatever it found and creates its own, so four sessions' handoffs
  become **unfindable** — not deleted, which is the part that makes it hard to
  notice;
- two wrapping in the same window both create successors, breaking the _exactly
  one open_ invariant that the lookup depends on.

Neither failure raises anything. Both agents report success, because both did
exactly what they were told. Latent workspace-wide, not yet observed — the
evidence and the reason for deciding it early are in `DECISIONS.md` CI-0032.

### 25.2 The rule — choose the carrier by how it behaves under a concurrent write

**Coordinate per issue, not per session.** An issue is naturally sharded:
claiming or commenting on one never touches another. Within that, three carriers
behave differently and are not interchangeable:

| Carrier | Concurrent-write behavior | Use for |
| --- | --- | --- |
| Issue **body** | Last write wins, silently | Current state of that one issue — **one claimant** |
| Issue **comments** | Append-only; every write survives | Per-session log — **safe for N writers** |
| A **git file** | **Refuses** the write — non-fast-forward, or a merge conflict | Repo-wide state |

**Repo-wide state belongs in a git file, and the reason is the refusal, not the
format.** Git is the only one of the three that fails a concurrent write instead
of silently taking the last.

**This does not decide any repo's handoff surface — §16 does.** The surface each
repo declares in its §16 governance table governs, exactly as §5.4 states.
A file form has no compare-and-swap to lose, which is a property of that choice,
not the reason canon made it. Where a repo's handoff **is** an issue, it carries
the `handoff` label (§5.4), which is what makes the lookup exact rather than a
title search — `aidoc-flow-ci` itself moved to that form under `DECISIONS.md`
CI-0042, declared as `` Tracker — `label:handoff` ``.

### 25.3 Claim before starting

**Set the assignee, the `status:in-progress` label (§5.4), or both, before the
first edit — not at the first push.** An issue being worked that carries neither
is indistinguishable from an unstarted one, so agents handed "the open issues in
priority order" all start the same one.

Re-derive with `gh label list -R <repo> --limit 200 | grep status:`. Measured
2026-08-05, **before** §5.4 shipped, across seven repos (`aidoc-flow-ci`,
`-operations`, `-framework`, `-interlog`, `-business`, `b-local-privy`,
`llm-router`): **0 carried any `status:*` label**, so the claim was unrecordable
everywhere. `aidoc-flow-ci` now carries it — it self-adopted with §5.4 — so that
repo no longer reproduces the zero.

### 25.4 One worktree per issue

**An agent that will edit files works in its own `git worktree`, on a branch
named for the issue it claimed.** Agents sharing one checkout share `HEAD` and
the index: one agent's `checkout -b` moves another's branch mid-edit, and
`git add -A` sweeps a neighbour's half-written files into your commit. The
result passes hooks and reads correctly in review, because nothing about it is
malformed — it is simply someone else's work, or missing your own.

Worktrees are the right shape because they give each agent its own `HEAD` and
index **while sharing the object store** — no `.git/index.lock` contention, and
integration stays a local `git merge`. The alternatives considered and rejected
are in CI-0032.

Three caveats, all load-bearing:

- **A worktree does NOT protect a session from its own sub-agents.** They run in
  the parent's tree by construction, so the one measured loss in this repo —
  PR #277 shipping without the code it was written to add, landed separately by
  #278 — is **not** prevented by this rule. What prevents it is the durable trap
  in `CLAUDE.md`: `git add -A` and diff against what was reviewed **after** the
  agents finish, before committing. §25.4 separates agents from _each other_;
  that rule separates you from _your own_. You need both.
- **These repos are submodules of the `aidoc-flow` umbrella.** A worktree lives
  outside the umbrella's tree, so the umbrella's pointer bump must still be made
  from the primary checkout.
- **Remove the worktree when the issue closes** (`git worktree remove`). An
  abandoned worktree keeps a branch checked out, and the next agent's `checkout`
  of that branch fails with a message that names the worktree, not the cause.

### 25.5 What this section deliberately does NOT require

Two rules proposed with it are **declined, not deferred** — recorded here so they
are not re-proposed as oversights. The evidence and the full reasoning are in
`DECISIONS.md` CI-0032; do not restate them:

- **A `flock`-serialized deploy is not canon here** — no repo that canon governs
  deploys a running service from a shell, so the rule would have no instance to
  bind. It belongs in the docs of a repo that does.
- **`CLAUDE.md` is not made a symlink to `AGENTS.md`** — it would change what
  §16's governance table and `parse-governance-table.py` parse, and degrade to a
  text stub on Windows without `core.symlinks`.

**The problem behind the second decline is real and stays open:** conventions
living in `CLAUDE.md` and Claude-only skills are never seen by Codex or DeepSeek.
Declining the symlink does not address it —
[#395](https://github.com/vladm3105/aidoc-flow-ci/issues/395) does.

**Origin:** issue #387, filed from `vladm3105/llm-router`. Recorded as CI-0032.
Labels in §5.4 (#386).

## 27. A gate must not decide on the exit status of a pipeline into `grep -q`

> **§26 is intentionally absent.** It is reserved by §24's closing note for
> PLAN-023 PR-1, which already plans to renumber eleven `§24` forward references
> onto it. CI-0033 took the next free number instead of that reservation, so
> nothing in PLAN-023 has to move; PR-1 fills §26 above this section when it
> lands. Do not renumber this section to close the gap.

`grep -q` exits the instant it matches. Its writer is then killed by `SIGPIPE`
or gets `EPIPE` (exit 141), and under `set -o pipefail` **that 141 becomes the
pipeline's status**. So this reads as "not found" precisely when the string
_was_ found:

```bash
if echo "$haystack" | grep -qF "$needle"; then   # WRONG on a load-bearing gate
```

**What decides the outcome is whether the writer has finished issuing its
`write(2)` calls when `grep` leaves — NOT the payload size.** This is the part
that is easy to get wrong, so it is stated with the measurement:

| writer | payload | inversions |
| --- | --- | --- |
| `echo` — bash builtin, one `write(2)` | 8 KB | 0/20 |
| `echo` | 40 KB | 0/20 |
| a process emitting one line per record | 8 KB | **18/20** |
| a process emitting one line per record | 17 KB | **20/20** |

A single-`write` builtin under the pipe buffer genuinely cannot invert — the
write completes before `grep` is ever scheduled. **A multi-write writer inverts
at a fraction of the buffer**, because `grep` can exit between two of its
writes. `git log`, `git diff --raw`, `git branch` and any loop are multi-write.

So there is no safe size, and **"the payload is small" is not a justification**
— it is only valid together with "and the writer emits it in one call". Even for
a single-`write` builtin the margin is environmental: the origin incident was a
38 KB `echo` that was clean 200/200 on a dev host and inverted in the runner,
where pipe capacity and bash's buffering differ. **The same command is correct
on a laptop and wrong on a runner.**

**EPIPE is not the only way `pipefail` poisons the decision — the writer's own
exit status does it too, and deterministically.** Everything above frames the
hazard as the reader signalling the writer, which makes it tempting to clear a
site by reasoning about `write(2)` counts. That reasoning is necessary and not
sufficient: `pipefail` returns the _rightmost non-zero_ status from **any** stage,
so a writer that exits non-zero for reasons of its own inverts the verdict with
no race at all. `find … -print -quit` is the reproduced case (§27.2's table) — it
returns non-zero when a traversal error is recorded before it quits, _while still
printing the match_, so the pipeline reads "not found" on output that contains
the find. `git`, `jq` and `grep` itself all have non-zero exits that mean
something other than "no match".

**Note what that case does _not_ license: a repeatability claim.** Whether the
error is reached before the match depends on `readdir` order, which is not
alphabetical and not under your control — the same directory contents were
observed inverting and not inverting. A ratio like the `18/20` rows above comes
from repeated trials of one configuration; **do not write one observation in that
notation.** It reads as a measured rate and is not one. The correct statement is
that the inversion is reachable and its trigger is not yours to control, which is
sufficient to ban the construct and is all that was established.

**So the taxonomy below is keyed on the writer for EPIPE only.** A row marked
EPIPE-latent is not thereby safe; it is safe only if the writer also cannot exit
non-zero. This is why §27.1 is stated over a pipeline's _status_ rather than over
SIGPIPE.

### 27.1 The rule

**Any pipeline whose exit status is a decision must decide on captured OUTPUT,
or use no pipeline at all.** For a substring test, use bash's `case` — it forks
nothing, so there is no status to invert:

```bash
case "$haystack" in
  *"$needle"*) found=1 ;;                        # quoted expansion = literal, i.e. grep -F
esac
```

Where a real regex is needed, capture first and test the capture
(`out="$(printf '%s' "$h" | grep -E … || true)"; [ -n "$out" ]`).

`grep -q` reading a **file** or a process-substitution is unaffected — there is
no writer in the pipeline to signal. The banned construct is specifically
`… | grep -q…`.

### 27.2 Scope — where this is mandatory

Mandatory on anything whose result gates a merge, a push, a release or a
security decision: the reusables in `.github/workflows/`, the composite actions
in `actions/`, `scripts/`, `install/templates/`, and two named files —
`tests/lib.sh` and `install/install.sh`. `assert_absent` is the sharpest case —
the inversion turns it into a **silent pass**, so a suite loses coverage without
a single red. `install/install.sh` is the file every consumer curls: its two
sites decide which tag a cold-start install pins and whether the operator is
told that AI-flow jobs will sit Queued forever.

**Known gap, stated rather than implied.** The REST of `install/` and `tests/`
is not in scope yet and does carry live instances — `install/deploy-ci-wizard.sh`
(11 sites) and roughly 28 across `tests/`. Every current writer there is a
`printf`/`echo` builtin, so none has been shown to invert; that is a statement
about today's payload sizes, not a clearance, and §27's own rule is that "the
payload is small" is not a justification. It is tracked as its own change rather
than folded into a release-readiness pass. **A scope with an undeclared gap is
the thing this clause exists to prevent, so the gap is declared here and the
guard's `SURFACE_FILES` comment points back at it.**

**`actions/` was added to this scope after the fact, and the reason generalises.**
The composite actions were being written on `feat/v3-composite-actions` while
this section was being written on `main`; neither branch could see the other, so
the surface v3 makes _primary_ entered canon outside the rule and outside its
guard. **A scope written against the tree you can see is narrower than the rule
the moment a parallel branch adds a surface.**

Two corrections that came out of closing it, both worth more than the fix:

- **This clause names DIRECTORIES; the guard must glob all of each, not one
  extension or one depth.** It globbed `install/templates/**/*.sh` — four files —
  while 31 `*.yml` templates under the same declared directory went unscanned.
  Those are what lands in every consumer repo on the next tag. The narrower
  spellings were each measured to pass a planted construct:
  `ls .github/workflows/*.yml` missed a `.yaml` sibling, and `ls scripts/*.sh`
  missed anything below `scripts/`. **The globbed extension set is part of this
  contract, not an implementation detail:** `*.sh`, `*.bash`, `*.yml`, `*.yaml`,
  at any depth, in each of the four directories, plus the named files
  `tests/lib.sh` and `install/install.sh`. Widen the guard and this sentence
  together, or the rulebook claims a coverage the guard does not have — which is
  the failure this whole clause is about.
- **The named files needed a pin of their own, for the same reason the
  directories did.** `tests/lib.sh` was appended to the guarded set by a bare
  `echo` inside the `mapfile`, with no assertion anywhere that it was there —
  deleting that single line removed the sharpest surface in the list, silently.
  Named files are now a pinned array, asserted both as a list and by presence in
  the iterated product.
- **A check derived from the thing it checks cannot detect that thing's own
  truncation. This took three attempts, and each fix reproduced the defect one
  level up.** (1) A glob of `actions/*/action.yml` was "verified" against a
  counter carrying the _same_ depth-2 and `.yml`-only assumptions, so both sides
  missed `action.yaml` and `actions/a/b/action.yml` identically and the assertion
  read green. (2) The replacement floor was asserted on the guard's own private
  enumeration rather than on the array actually iterated, so deleting the one
  line that copied it into scope left six action files unscanned — 111 passed, 0
  failed. (3) The per-surface floors were then driven by the surface _list_, so
  deleting an entry deleted its own floor: 111 passed, 0 failed again.
  **The invariant that finally held: every check must be anchored to something
  the mutation cannot also edit** — the iterated array, a separate enumeration,
  or a literal pin. Three now exist, deliberately overlapping: the surface list
  is pinned to a literal, each surface is counted against `GUARDED` itself, and
  an **independent** oracle over a different file set requires every action canon
  `uses:` to resolve to a guarded file.

**An oracle must be asserted non-empty.** That cross-check first matched
`./actions/…` while every caller writes `<owner>/<repo>/actions/…@<tag>`, so it
examined nothing and printed nothing. A count assertion is what turns a vacuous
oracle into a red.

**`tests/test_sigpipe_guard.sh` enforces exactly this scope — it globs it, it
does not carry a hand-written file list.** That is deliberate: CI-0033's first
draft guarded four hand-listed files while the rule declared four _directories_,
and the gap is what had let the sites below sit unflagged for a year. A guard
narrower than the rule it enforces reports compliance the rule does not have.

Converted under CI-0033, beyond the four OPS-0069 surfaces that prompted it.
**The writer column is the one that matters, and it is stated as measured or as
theoretical — never blurred.** A row whose writer is a bash builtin is a
_latent_ instance: correct today, and banned anyway because the construct is
one refactor away from a real writer.

| Site | Writer in the pipeline | Status |
| --- | --- | --- |
| `ai-review.yml` — autofix symlink-escape guard | `git diff --cached --raw` — **multi-write** | **MEASURED fail-open**: missed the symlink 4/5 at 401 staged files (#418) |
| `ft30-dry-run.sh` | `git branch -r --contains` — **multi-write** | fail-open, same class, unmeasured |
| `ai-review.yml` ×2 — deny-floor path checks | `printf` builtin, one path | latent — cannot invert at this size |
| `composition.yml` ×2 — break-glass + separation-of-duties | `printf` builtin | latent — 0/20 inversions at 300 KB and 5 MB |
| `secret-scan.yml` ×3 — config canary | `printf` builtin | latent, but into the exact case its own comment warns of |
| `release.sh`, `sync-version-refs.sh` | `printf` builtin, version string | latent |
| `actions/sast-scan/action.yml` — D23 ignore-file post-condition | `find … -print -quit` — one write, then exits | **REPRODUCED fail-open — by the writer's own exit status, not by EPIPE.** `find -quit` returns non-zero when a traversal error is recorded before it quits, _while still printing the match_; `pipefail` takes that over `grep`'s 0 and the gate proceeds. Reachable, not certain: it turns on `readdir` order. EPIPE-latent (one write, so `grep` cannot leave first) |

For contrast, the two writers that were measured to invert: `git log` at
20,760 bytes → 3/20, and `git diff --raw` at 401 files → 4/5.

**Direction ranks the work, not size.** The audit-trail instance failed _closed_
— loud, blocking, diagnosed in a day. Every site in that table fails _open_: a
false green that nothing surfaces. That asymmetry, not the measured/latent
split, is why they were converted here rather than deferred.

Two known sites are **out of scope and stay unconverted**: `install/install.sh`
and `install/deploy-ci-wizard.sh`. Neither gates anything — they are the
bootstrap and an interactive wizard — and both read short `gh` API listings. The
allowlist in the guard carries one further entry,
`install/templates/runner/build-image.sh`, whose pipeline runs inside `sh -c` in
a container with no `pipefail`, so the writer's `EPIPE` cannot reach the
decision. An allowlist entry is a claim that must stay true, not a way to
silence a hit.

### 27.2a The construct is a LOGICAL line, and the guard must fold before matching

`tests/test_sigpipe_guard.sh` enforces §27.1 by matching a regex against the
guarded files. It matched **physical** lines, so the ordinary way to wrap a long
pipeline inside a `run: |` block walked past it (#422):

```bash
printf '%s' "$SCAN_PATH" |
  grep -q .
```

Planted in `actions/sast-scan/action.yml`, the suite reported **119 passed, 0
failed** with the banned construct sitting in a security-gate action.

**Note which half was covered, because it is the instructive part.** The _other_
continuation spelling — a trailing `\` before the newline — **was** caught, but
only incidentally: the literal text `| grep -q` still lands on one physical line.
So the guard appeared to handle continuations while handling exactly one of the
two spellings. A guard that catches one spelling of a construct and not the
other is not enforcing the construct; it is enforcing a typography.

**Rules.**

1. Fold shell continuations — a line ending in a **single** `|`, or in a
   backslash — into one logical line **before** matching.
1a. **Do not fold what only looks like a continuation.** The guard is a text
   heuristic over `.sh` **and** `.yml`, and two shapes end in `|` without being
   shell continuations:
   - a **YAML block-scalar header** (`run: |`, `script: |`, `run: |-`). Folding
     it yields `run: | grep -q x "$f"`, which the pattern matches — red-lining
     `grep -q` against a **file**, the shape §27.1 explicitly blesses, and
     pointing at a line with no grep on it. Comment and blank lines are
     transparent to a pending fold, so the exposure is the first non-blank body
     line, not merely the next one.
   - **`||`**, which is an OR-branch, not a pipeline. The pattern's `\|` would
     bind its second `|`. Skipping it closes no hole: a genuine pipe further
     down the same construct is still caught on its own line.
   A guard that red-lines correct code is removed by the next person it blocks,
   so each exemption carries a negative probe.
2. Carry the **first** physical line number through the fold. A hit that reports
   the last line sends the reader to the wrong place, which defeats the only
   reason to report a number.
3. Probe **both** spellings, and probe the negatives (a wrapped comment, a
   wrapped legitimate pipeline). A fold that only ever matches more is a fold
   that will be reverted the first time it fires spuriously.

**Generalise it.** This is the §27 family's own lesson turned on the guard: a
check derived from one representation of a fact does not cover the others. Note
the symmetry the fix had to respect — widening a guard creates the opposite
failure, a false RED, and the review that caught both exemptions found them by
asking what the wider guard would now match rather than what it would catch. The
same shape produced #423 (a post-condition scoped to one of two strip roots)
and #426 (a count predicted from the config rather than read from the run).

**Origin:** #422.

### 27.3 Why review did not catch it

The line entered on 2026-07-07 in `e827ab8` (PLAN-002 PR-U3, #64), under a
two-agent review its own commit message records as
`code-reviewer + security-auditor`, and first produced a visible failure on
2026-08-08. The issue that reported that failure then investigated the mechanism
directly and **explicitly ruled it out**.

Both were reasoning correctly from a local reproduction that could not fail: at
the payload size in question the shape is sound on a dev host. **A negative
result from a size-dependent test is not evidence of absence** — reproduce at a
size well past any pipe buffer, or read the runner log, which names it directly
(`echo: write error: Broken pipe`).

Enforced by `tests/test_sigpipe_guard.sh`, which runs the shipped `run:` block
against a 4 MB commit range and separately bans the construct from the four
surfaces above.

**Origin:** issue [#417](https://github.com/vladm3105/aidoc-flow-ci/issues/417),
a false negative from `call / verify` on PR #416. Recorded as CI-0033.
