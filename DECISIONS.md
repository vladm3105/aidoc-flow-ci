# DECISIONS — aidoc-flow-ci

Durable, ISO-stamped, **append-only** record of load-bearing decisions
for the workspace CI + governance-workflow canon library.

**ID prefix:** `CI-NNNN`. Never reuse a retired ID.

---

## CI-0001: Flexible-canonical approach for project governance files (2026-07-08)

**Context**

Workspace audit across 9 non-paused repos surfaced governance-file
variance: HANDOFF at 4 different paths, DECISIONS at 4 different
paths, 4 repos missing 2+ of the 6 durable surfaces. Two candidate
approaches: (A) canonical fixed paths (workspace-wide `HANDOFF.md` at
root, etc.); (B) flexible canonical — each repo picks + declares its
own paths in `CLAUDE.md`, canon enforces presence + declaration +
consistency.

**Decision**

Adopt approach B — flexible canonical — per PLAN-003 §4.1. Each repo's
`CLAUDE.md` MUST contain a `## Per-repo governance` H2 section with a
canonical table declaring where each of the 6 required surfaces lives.
Canon parser (`--check-governance`, PR-V2) verifies each declared path
exists on disk (or the cell is a valid "Not adopted — `<rationale>`"
line). Path variance is preserved; presence + declaration is enforced.

**Consequences**

- Existing intentional paths (operations `ops/`, framework `plans/`,
  business `docs/`) preserved — no forced migration.
- Consumers with dual surfaces (framework dual DECISIONS, engramory
  dual ROADMAP) declare each as an additional row per PLAN-003 §4.2.
- Consumers that intentionally decline a surface use the "Not adopted"
  cell format (business declines CHANGELOG + ROADMAP by policy).
- `docs/REPO_STANDARDS.md` §16 codifies the rule; consumers pull
  `install/templates/CLAUDE.md.template` as the canonical shape;
  `install/templates/{HANDOFF,DECISIONS,ROADMAP,plans-README}.md.template`
  ship for consumers creating fresh surfaces.

**Origin**

Founder direction 2026-07-08 (Option B) — "each repo picks paths,
declares in CLAUDE.md; canon enforces presence + declaration". Full
review + rationale in `plans/PLAN-003_project-governance-canon.md`
§4.1 + Review log Passes 2/3/4/5/6.

---

## CI-0002: Bundle PR-V1 canon templates with Wave 0 self-adoption (2026-07-08)

**Context**

PLAN-003 originally split canon shipment (PR-V1: templates only) from
Wave 0 self-adoption (PR-V3: aidoc-flow-ci adopts its own canon).
Pass 3 fold folded both into one PR-V1 bundle (11 surfaces) per
PLAN-002 §5.4 canon-home dogfood precedent — canon-source demonstrates
canon works by adopting it in the same commit that ships it.

11-surface bundle exceeds OPS-0061 Rule 1's ≤3 doc surfaces per
governance PR default. Pass 4 finding F#12: PLAN-002 precedent alone
doesn't authorize; each PR-V1 requires explicit founder OK.

**Decision**

PR-V1 bundles 5 canon templates (CLAUDE / HANDOFF / DECISIONS / ROADMAP /
plans-README) + REPO_STANDARDS §16 + 4 aidoc-flow-ci self-adoption
files (this DECISIONS.md, HANDOFF.md, ROADMAP.md, CLAUDE.md) +
CHANGELOG = 11 surfaces. Explicit founder OK obtained 2026-07-08:
"merge PLAN-003 PR-V1 if green". Audit-trail phrase per OPS-0069
records the OK.

**Consequences**

- PR-V1 opens with an 11-surface diff. Reviewer is the CI
  `ai-review.yml` reusable + author-side OPS-0065 multi-agent dispatch
  (2 fresh-context code-reviewer agents already ran on the plan).
- Future canon-home PRs default back to Rule 1 ≤3 surfaces unless a
  fresh founder OK justifies a bundle.
- Wave 1-5 rollout PRs (per PLAN-003 §5.5) each touch ≤3 surfaces per
  the OPS-0061 default — no bundle exception needed.

**Origin**

PLAN-002 §5.4 canon-home dogfood precedent + PLAN-003 Pass 4 F#12 fold +
founder OK 2026-07-08.

---

## CI-0003: 3-cycle review circuit-breaker discipline (2026-07-08)

**Context**

PLAN-003 review cycles: Pass 2 (independent, 18 findings) → Pass 3
(author fold) → Pass 4 (independent, 14 findings incl. 3 audit errors
Pass 3 missed) → Pass 5 (author fold) → Pass 6 (independent, APPROVED).
That's exactly 3 review→fix→re-review cycles — the OPS-0066 cap.

Value of the cap validated in practice: Pass 4 surfaced load-bearing
findings the author (twice) missed; Pass 6 validated the fold WITHOUT
introducing a new fold-then-re-review cycle. The cap forced the fold
to be complete rather than incremental.

**Decision**

Confirm OPS-0066 3-cycle cap applies canonically to this repo's plan
review discipline. If a Pass N (N ≥ 6) still surfaces load-bearing
findings, STOP + surface to founder rather than dispatch Pass N+1.
Recorded here for future PLAN-003 rollout Wave PRs which will use
the same discipline.

**Consequences**

- Every future PLAN-NNN in this repo runs Pass 0 (author) → Pass 2
  (independent) → Pass 3 (fold) → Pass 4 (independent) → Pass 5 (fold)
  → Pass 6 (independent) at maximum. If Pass 6 doesn't APPROVE, halt
  - surface.
- Author-fold pass discipline: Pass 3 + Pass 5 must be COMPLETE
  (address ALL findings from the preceding independent pass), not
  partial. Partial folds waste a review cycle.
- Independent Pass N+1 verifies BOTH resolution of prior findings AND
  no new load-bearing issues introduced by the fold.

**Origin**

OPS-0066 (aidoc-flow-operations `ops/DECISIONS.md`). Confirmed in
PLAN-003 Passes 4-6 (2026-07-08).

---

## CI-0004: Workflow-policy delegation to OPS-NNNN decisions (2026-07-09)

**Context**

The reusable workflows this repo ships encode POLICY choices, not just
mechanics: `ai-review.yml` + `auto-merge-ai-prs.yml` auto-merge green
AI-opened PRs by default; `audit-trail-check.yml` requires a phrase in
every push; the multi-agent pre-push review pattern gates commits. An
adopter (or a future maintainer) asking "why does this workflow behave
this way — and where do I change the policy vs. the implementation?"
needs a trace to the authoritative decision. Those decisions are
**OPS-NNNN business decisions in `aidoc-flow-operations`**, not
re-decided here (per REPO_STANDARDS §0 canonical-source split). Without
an explicit mapping the trace is a cross-repo scavenger hunt (PLAN-004
pre-prod review, governance finding "no CI-NNNN backs the workflow
policies").

**Decision**

This repo's workflow behaviors **delegate** to the OPS-NNNN decisions
below; it implements them, it does not re-decide them. Change the
POLICY via a new OPS-NNNN in operations; change the IMPLEMENTATION
(the workflow YAML) here.

| Workflow / behavior | Backing decision | What it decides |
| --- | --- | --- |
| `auto-merge-ai-prs.yml` + ai-review auto-merge arming | **OPS-0062** | AI-agent auto-merge default: auto-watch + merge on green; 10-attempt cap; 🟡/🔴 + governance + cross-repo carve-outs |
| pre-push multi-agent review dispatch | **OPS-0065** | dispatch diff-class-matched sub-agents before every push |
| review/fix loop cap (incl. `docs/` + plan review) | **OPS-0066** | 3-cycle circuit-breaker; STOP + surface to founder past cycle 3 (see CI-0003) |
| scope of the aidoc-flow multi-agent-review standard | **OPS-0067** | applies to ALL non-paused workspace repos |
| governance-PR discipline (≤3 surfaces, adversarial self-review) | **OPS-0061** | shape of every governance PR in this repo |
| `audit-trail-check.yml` → `call / verify` | **OPS-0069** | mandatory pre-push audit-trail phrase in a commit body |

**Consequences**

- Adopters trace a workflow-policy question to the cited OPS-NNNN in
  operations, not to this repo. The CLAUDE.md "Workspace standards"
  section is the quick-reference; this entry is the durable record.
- A CHANGELOG entry that changes a policy-driven behavior cites the
  OPS-NNNN it implements, so the semver bump is traceable to the
  decision.
- If operations reverses one of these (e.g., a future OPS decision
  disables auto-merge-by-default), the workflow change here cites the
  reversing OPS-NNNN and this table is updated (append-only: add a new
  CI-NNNN, annotate this one's Consequences).

**Origin**

PLAN-004 pre-prod review (2026-07-09) governance finding — the workflow
policies leaned on upstream OPS-NNNN referenced in CLAUDE.md but had no
durable DECISIONS entry composing them. Codified here.

---

## CI-0005: AI-review trust boundary + declarative-only config knobs (2026-07-10)

**Context**

PLAN-005's pre-prod review of the ai-review pipeline surfaced two gaps at
company-default elevation: (1) no CI-NNNN records the ai-review / auto-merge
**trust boundary** — who may be auto-reviewed + auto-merged, and where that is
decided; (2) `config.json` ships several governance / auto-merge / composition
knobs that LOOK enforceable but are read by **no** workflow (grep-verified),
because the governance globs are hardcoded server-side. A consumer adding `spec/`
to `governance.locked_paths` expecting human-merge protection gets none.

**Decision**

Trust boundary (this repo IMPLEMENTS it; the POLICY is OPS-0062 — see CI-0004):

- **Who may be auto-reviewed:** logins in `.trust.ai_review` of the trust-config
  repo (`trust_config_repo`@`trust_config_ref`, default
  `vladm3105/aidoc-flow-operations@main` — a non-PR-mutable ref).
- **Who may get auto-fix:** logins in `.trust.auto_fix` of the same trust-config
  repo (`ai-review.yml` gates the auto-fix capability on it).
- **Who may auto-merge:** repos in `.auto_merge.repos` of the operations config
  (an operations-controlled allowlist). A repo not listed → the enforcer
  fail-closes (disabled). **This is why no install-time "a bootstrap repo can't
  auto-merge" guard is needed** — the allowlist already gates it; a
  bootstrap-profile repo is simply not added until it has a review gate.
- **Reviewer-App approval identity:** `vars.APP_REVIEWER_1_BOT_ID` (the counting
  approval; the BL-3 App-at-HEAD gate + PR-A part 1 enforcer governance floor
  build on it).
- **`skip-ai-review`:** advisory carry-forward — hardened by PLAN-005 PR-A: the
  enforcer's governance floor refuses it **unconditionally** on gov-locked PRs
  (`.github/**` | `governance/**` | `templates/ai-review/**`); the HEAD-relative
  product-code check is PR-A part 2.
- **Reviewer engine (superseded by CI-0006):** was config-driven via
  `.reviewer`; `ci/v2.0.0` instead resolves `litellm.model`.

Declarative-only config knobs (PLAN-005 D7): these `config.json` fields are NOT
read by any workflow as of `ci/v1.7.x` and MUST NOT be relied on for
enforcement — `governance.locked_paths`, `governance.require_human_review`,
`governance.code_owners`, `auto_merge.enabled`, `auto_merge.spec_paths_blocked`,
`composition.required`, `composition.carry_forward_on_skip_label`,
`autofix.enabled`. (The ENFORCED fields are `trust.ai_review`, `trust.auto_fix`,
  `reviewer`, `auto_merge.repos`; CI-0006 supersedes `reviewer` with
  `litellm.model` for `ci/v2.0.0`.) The
governance globs are hardcoded server-side in `ai-review.yml` **deliberately** —
a consumer-editable gov floor could be loosened by a PR. Wiring any of these
(e.g. ADDING paths to `locked_paths`) is a future opt-in; a `_note` field in
`config.json.template` flags them inline for anyone reading a consumer config.

**Consequences**

- A consumer reading `config.json` knows which fields bite (`trust.ai_review`,
  `trust.auto_fix`, `reviewer`, `auto_merge.repos`; `reviewer` is superseded by
  CI-0006's `litellm.model`) and which are declarative
  (via the `_note` + this entry) — and that all but `trust.ai_review` are
  resolved from the trust-config repo, not their local copy.
- Auto-merge enablement is an operations-side allowlist action, not a
  consumer-side config toggle — closing the "bootstrap repo self-enables
  auto-merge" concern without new install tooling.
- If a declarative knob is later wired, a new CI-NNNN records it and the `_note`
  - this entry are annotated (append-only).

**Origin**

PLAN-005 rev-2 review (2026-07-10), findings "no CI-NNNN backs the trust
boundary" (PR-F) + "governance config knobs are inert" (D7). The misdirected
original PR-F "bootstrap install guard" was dropped: `apply-standards.sh` /
`install.sh` do not install the auto-merge caller, and the operations allowlist
already gates auto-merge — so the guard is a documented policy, not code.

---

## CI-0006: Route every canonical AI job through LiteLLM (2026-07-12)

**Context**

AI review and documentation maintenance selected and authenticated vendor CLIs
independently. That duplicated installation, credentials, routing, fallback,
and cost controls across runners and made a unified self-hosted deployment
impossible.

**Decision**

Canonical AI jobs call one OpenAI-compatible LiteLLM proxy using
`LITELLM_BASE_URL` and separate `LITELLM_REVIEW_API_KEY` /
`LITELLM_DOC_API_KEY` virtual keys. Workflows select only a LiteLLM model alias.
Provider credentials, provider/model routing, fallback,
budgets, and retries beyond the bounded transport retry remain proxy policy.
Vendor CLIs and their credentials are no longer part of the CI contract.

The GitHub reviewer App remains separate: LiteLLM produces the judgment, while
the App supplies the GitHub identity that submits a counting review. Trust
gating, governance floors, and composition enforcement are unchanged.

**Consequences**

- `litellm.model` supersedes CI-0005's `.reviewer` engine selector.
- `ai-review` and `doc-maintainer` share a dependency-free HTTP adapter.
- AI-review configuration is explicitly schema-versioned as v2.
- A real-proxy smoke run for both aliases is required before tagging.
- Missing proxy configuration, network errors, and invalid output fail closed.
- Removing vendor-specific workflow inputs is a breaking `ci/v2.0.0` change.

**Origin**

Founder direction to use LiteLLM for all AI agents, including ai-review and
doc-maintainer, 2026-07-12.

---

## CI-0007: Runner-label naming — defer any rename to a future major; rule out `private-*` (2026-07-16)

**Context**

Founder proposed renaming the canonical self-hosted runner labels for more
meaningful naming: `ci-runner` → `private-ci-runner` and `single-use` →
`isolated-ci-runner`, then offered `sandbox-*` as a further candidate. Raised
explicitly as **naming planning only** — no migration intended now. All three
candidates are analysed below so the question is not re-derived later.

Current canonical selector: `[self-hosted, ci-runner, single-use]`, adopted at
the breaking `ci/v2.0.0` (replacing the v1 `aidoc,ci-ephemeral`). `LABELS.md`
§2 defines the scheme as **orthogonal scheduling dimensions** — purpose
(`ci-runner`), lifecycle (`single-use`), optional isolation (`project-<name>`) —
with provider/origin **intentionally omitted** so the pool can move hosts or
clouds without caller changes. PLAN-009's fleet cutover to those labels is
mid-flight: 7 consumers are still on `@ci/v1.9.5`.

**Decision**

Keep `[self-hosted, ci-runner, single-use]` unchanged. **No rename, no
migration now.** Defer any label rename to a future **breaking** release
(earliest `ci/v3.0.0`), and only once the whole fleet is unified on v2.

Two constraints bind any future proposal:

1. **`private-*` is ruled out permanently** — not merely deferred. Public repos
   **may** use this pool for the ai-review **review** job (`CLAUDE.md` — "PUBLIC
   repos MAY use the ephemeral self-hosted pool … for the ai-review *review* job
   ONLY"; wired by PLAN-009 **Edit F**). That is a *permission*, not today's
   state — as of 2026-07-16 all four public repos still ship
   `runner_labels_review: '"ubuntu-latest"'` and Edit F is unexecuted — so a
   `private-` label would not be false *yet*; it would **become** false the
   moment the public trio cuts over, which the plan intends. Independently of
   that timing, `private-` encodes visibility/origin, which §2's naming
   convention deliberately excludes from the selector — that alone is
   disqualifying.
2. **`isolated-*` collides with an already-occupied dimension** — §2 assigns
   "optional isolation" to `project-<name>`. Naming the *lifecycle* label
   `isolated-` overloads a term the scheme uses for a different dimension. It is
   also vaguer than `single-use`, which names the actual mechanism (accept
   exactly one job, then de-register and destroy); a persistent sandboxed runner
   can equally be "isolated". Repeating `-ci-runner` across two labels of one
   selector (`[self-hosted, private-ci-runner, isolated-ci-runner]`) further
   collapses the purpose/lifecycle split into two nouns for the same thing.

**`sandbox-*` (founder, same session) — the strongest candidate; carried
forward, not adopted.** Unlike `private-*` it is **accurate**: the pool genuinely
is sandboxed (`run-ephemeral.sh` gives each job a fresh `--rm` container — no
host mounts, no docker socket, non-root, CPU/mem/PID caps), and it avoids the §2
word-collision that sinks `isolated-*`. Two reasons it is still not adopted here:

- **It names confinement, not lifecycle** — so it cannot *replace* `single-use`,
  which guarantees "accept one job, then de-register and destroy". A long-lived
  runner can be sandboxed and never single-use. Swapping the two drops a
  guarantee rather than renaming it; keeping both would add a 4th selector
  dimension, which costs more than it returns.
- **Security-suggestive labels overclaim.** A runner label is a *scheduling
  selector*, not an enforced property: nothing stops a non-conforming runner
  registering with a `sandbox-*` label, after which jobs route to it under a name
  asserting a posture the label cannot guarantee. `single-use` states an
  operational contract instead — a weaker claim, and one the supervisor actually
  keeps. If `sandbox-*` is ever adopted, pair it with a conformance check rather
  than trusting the name.

Recorded as valid but **not acted on**: `ci-runner` is a weak, near-tautological
purpose label. A future rename should encode the pool's genuinely
distinguishing trait (its LiteLLM / private-network reachability, or its
sandboxed shape per above), keep the purpose and lifecycle dimensions
orthogonal, and avoid the duplicate suffix.

**Consequences**

- No caller, template, runbook, or pool-registration change. The staged Phase-0
  runbook (`../operations/ops/inbox/2026-07-14_founder_flow-ci-v2-fleet-cutover-prereqs.md`)
  stays valid exactly as written.
- Renaming now would force a **second** breaking migration one release after the
  first: a new major tag, re-registering every pool (including the three not yet
  created on business/iplanic/interlog), another hybrid-then-narrow cutover, and
  it would invalidate that unexecuted runbook — for zero functional gain.
- **Revisit trigger:** the next breaking canon release, once every consumer is
  on v2. Re-open this entry rather than re-deriving the analysis.

**Origin**

Founder naming proposal + AI analysis, 2026-07-16 (the session that advanced
operations to `ci/v2.0.1`). Scope limited by the founder to tracking the
decision only: "we do not need migration now just track the decision."

---

## CI-0008: Uniform-protected AI-flows — public and private on the self-hosted pool, no visibility split (2026-07-17)

**Context**

The AI-flows (`ai-review`, `doc-maintainer`, `docs-sync`) previously shipped as
`-public` / `-private` caller variants: public repos ran the flow on
GitHub-hosted runners, private on the self-hosted ephemeral pool. A visibility
flip therefore required swapping templates, and the split was justified by "keep
untrusted fork code off the self-hosted pool."

**Decision**

Collapse each AI-flow to ONE self-hosted protected template — the same
`runner_labels_routine` / `runner_labels_review` pool on BOTH public and private
repos, no visibility branch in the templates, manifest, or installer. A
visibility flip is a no-op.

This is SAFE and is NOT the "untrusted code on self-hosted" anti-pattern: a fork
never reaches a job that executes PR code. `ai-review`'s fork path runs only the
`trust` job, which checks out the trusted config repo (never PR head) and reads
PR metadata — zero PR code; the review job is `needs: trust`-gated and forks are
never trusted. `doc-maintainer` / `docs-sync` are post-merge, so forks cannot
trigger them. The generic fork-code lint flows (`markdown-lint`, `links`,
`pre-commit`, `on: pull_request`) MUST stay GitHub-hosted on public repos — they
run the PR's own files — and are deliberately NOT converged.

**Consequences**

- Reverses the visibility-split posture; public repos now need a `ci-runner` /
  `single-use` pool to run the ai-review *review* job (a PLAN-009 Phase-0 prereq).
- No `-public` / `-private` AI-flow template variants; `tests/test_contract.sh`
  asserts the single-template invariant + no `visibility_variants` in the manifest.
- Shipped as `ci/v2.2.0` (PLAN-013).

**Origin**

Founder direction 2026-07-17: make all AI-based flows uniform-protected
(public + private, no visibility split). Recorded retroactively per PLAN-015 M2.

---

## CI-0009: ai-review autofix — dedicated write-capable App, default-off, governance deny-floor (2026-07-17)

**Context**

On a `request_changes` verdict the reviewer could only comment; applying the fix
required a human. Automating it needs a token that can push to the PR branch —
a materially larger trust grant than the read-only reviewer path.

**Decision**

Add an autofix job to `ai-review.yml` that, on `request_changes` for a
trusted-author (`trust.auto_fix`) PR, generates a diff, applies it under a hard
governance deny-floor (parse + post-apply + symlink + framework-lock checks), and
pushes via a **dedicated ephemeral-token autofix GitHub App** (contents:write,
NOT a PAT, separate from the reviewer App) to re-fire the gate. Ships
**default-off**: inert until a founder registers the App, sets
`APP_AUTOFIX_ID/KEY` + `LITELLM_FIX_API_KEY`, adds authors to `trust.auto_fix`,
and flips `autofix.enabled: true` in the TRUSTED config. A PR cannot self-enable
it; forks never reach it; the round-cap fails closed → escalate.

**Consequences**

- A second, write-capable App trust root exists but is dormant until founder
  enablement (per-repo, staged).
- Shipped as `ci/v2.3.0` (PLAN-012); security-reviewed (no blocker).

**Origin**

Founder direction 2026-07-17 to build the ai-review autofix flow. Recorded
retroactively per PLAN-015 M2.

---

## CI-0010: Own security-scanner suite — binaries not marketplace actions, report-only-first, opt-in (2026-07-18)

**Context**

The workspace wanted SCA / IaC-misconfig / SAST coverage. Marketplace scanner
actions are blocked for non-verified creators (`startup_failure`) and, where
admitted, broaden the supply-chain surface; a hard gate on day one would block
PRs fleet-wide before the findings were triaged.

**Decision**

Ship three own scanners as reusables that install the tool DIRECTLY (no
marketplace action), each SHA/version-pinned: `dep-scan` (osv-scanner binary),
`trivy-scan` (trivy binary, `config` only — static scanners, SSRF-hardened),
`sast-scan` (semgrep via pinned pip). All are:

- **opt-in** (`auto_install: false`; the founder passes them explicitly to the
  wizard — not a force-sweep);
- **report-only first** (`fail-on-findings: false`), graduating to blocking
  per-scanner per-repo only after a clean window (a founder step);
- data-only / static (no source compilation; `trivy` terraform/helm scanners
  excluded because they fetch PR-controlled remote sources);
- the `sast-scan` autofix is **preview-only** (`semgrep --autofix` surfaced in the
  job summary, nothing pushed) — the one safe autofix path that needs no App.

**Consequences**

- Complements native CodeQL (N/A on private repos) — `sast-scan` gates private too.
- Shipped as `ci/v2.4.0`–`ci/v2.7.0` (PLAN-014 Phases 1–4); deployment + the
  false→true `fail-on-findings` graduation are 🔴 founder steps.

**Origin**

Founder direction 2026-07-18 ("osv/trivy/semgrep, all in, report-only first").
Recorded retroactively per PLAN-015 M2.

---

## CI-0011: `verified_allowed` supply-chain boundary — DECIDED (2026-07-24)

**Status: DECIDED (founder, 2026-07-24) — drop the verified marketplace; admit
only the founder's own account.**

**Decision**

- `verified_allowed: true → false`. The verified marketplace is no longer a trust
  boundary for this workspace.
- `patterns_allowed` broadened from `vladm3105/aidoc-flow-ci/*` to **`vladm3105/*`**
  — the founder's own account becomes the **sole** non-GitHub-owned allowance,
  replacing "any verified creator". `github_owned_allowed` stays `true`, and
  `actions/*` + `github/*` remain listed explicitly.
- Net effect: an action is admitted at run-init **iff** it is GitHub-owned or lives
  under `vladm3105/*`. Everything else `startup_failure`s — verified creator or not.

**Why this way:** "any verified creator" is an unbounded third-party set the
workspace does not control; the owner's own account is a bounded one it does.
Narrowing loses nothing, because canon already installs tools as binaries (the
rule that forced `gacts/gitleaks` → binary) rather than calling marketplace
wrappers.

**Blast radius verified before landing:** every `uses:` across
`.github/workflows/` and `install/templates/` resolves to `actions/*`, `github/*`,
or `vladm3105/*` — so canon is unaffected. (Independently re-verified: canon has
no composite actions and no `uses: ./` at all.) A consumer that
still calls a verified-creator action (e.g. `aquasecurity/trivy-action`) will
`startup_failure` once it applies the template; that is the intended boundary.

**Guardrails:** `tests/test_contract.sh` asserts both halves — `verified_allowed`
is `false`, `patterns_allowed` carries `vladm3105/*`, and no owner beyond
`vladm3105`/`actions`/`github` appears. Both mutations were confirmed to go red.
Re-admitting the marketplace or adding another owner is a new decision to record
here, not a config tweak.

**Note on the canon authoring rule (unchanged):** REPO_STANDARDS §4.3 still
restricts canon's own `uses:` to `actions/*`, `github/*`,
`vladm3105/aidoc-flow-ci/*` — deliberately **stricter** than this deployed
boundary. Do not relax it to match.

**🔴 Follow-up (not done by this decision):** canon's own live settings still
carry `verified_allowed: true`; applying `actions-permissions.json` to canon and
to each consumer is a founder-executed settings write, tracked as a
RELEASE_CHECKLIST post-release item. These are template values until applied
per-repo.

**Confirmed as part of this resolution** (was flagged in the original filing):
`workflow.can_approve_pull_request_reviews` is defanged — the `composition` gate
counts ONLY the reviewer App's numeric bot-id + `type==Bot`, never
`github-actions[bot]` — so an Actions-minted approval cannot satisfy the merge
gate. The template ships it `false` regardless (FT-27).

---

**Original filing (context, for the record)**

`install/templates/actions-permissions.json` sets `verified_allowed: true` (and
`github_owned_allowed: true`) alongside the three-pattern `patterns_allowed`
(`vladm3105/aidoc-flow-ci/*`, `actions/*`, `github/*`). So the DEPLOYED
allowlist admits **any GitHub-verified creator's action** (`aquasecurity`,
`docker`, `hashicorp`, …) on every consumer, not just the three patterns.
`REPO_STANDARDS.md` §4.3 now documents this accurately and flags widening to the
verified marketplace as "a decision to take deliberately" — but that decision
was never recorded, so code and policy have drifted apart by default, not by
choice.

**The options as filed** (the founder chose the second, and additionally
narrowed `patterns_allowed` to the account — see the Decision above):

- **Keep `verified_allowed: true`** — accept that any verified-creator action can
  run on consumer runners (incl. the private self-hosted pool) as an intentional
  convenience; OR
- ✅ **Drop it** — narrow the deployed boundary. Expect verified actions currently
  relied upon (e.g. `aquasecurity/trivy-action` if any consumer still calls it) to
  then `startup_failure`; canon reusables already install tools as binaries, so
  canon itself is unaffected.

**Related note (not itself a decision):** `actions-permissions.json` also sets
`workflow.can_approve_pull_request_reviews: true`. This is defanged here — the
`composition` gate counts ONLY the reviewer App's numeric bot-id + `type==Bot`,
never `github-actions[bot]` — so an Actions-minted approval does not satisfy the
merge gate. Confirmed as part of this resolution (see Decision above).

**Origin**

PLAN-015 M1 (pre-prod review security lens #2). Filed as an open decision;
resolved 2026-07-24.

---

## CI-0012: Runner reference implementation lives in canon; consumers vendor it (2026-07-20)

**Decision**

The implementation that satisfies the `[self-hosted, ci-runner, single-use]`
label contract — image spec (`Dockerfile` + `build-image.sh`), single-use
supervisor (`run-ephemeral.sh` + `ci-runner@.service`), and provisioning
(`provision-runner.sh`) — lives in this repo at `install/templates/runner/`,
versioned with the `ci/vX.Y.Z` tags. Workspace consumers (operations first)
vendor a pinned, byte-matched copy stamped with a `VENDORED-FROM` header;
deployed host state (env files, enabled units, built images, registrations)
stays operator-side and is never tracked in canon. The systemd unit template
carries an `@RUNNER_HOME@` ExecStart placeholder; `provision-runner.sh` is
the only documented installer (raw `cp` deploys a broken unit by design).
Dependabot watches the canon Dockerfile — base-digest truth flows
canon→consumer via re-pin, never the reverse. `ci-network-monitor.*` is
deliberately excluded (operations host diagnostics, not pool mechanics).

**Why**

The label contract, pool check, and adopter docs were already canon, but the
implementation lived in the private operations repo: the public runners.md
adopter path 404'd, and image↔workflow drift shipped two defects (`gh: not
found`, operations PR #101; missing `libatomic1`, business #63 — fixed by
this move). Interface and reference implementation now version together.

**Consequences**

- Operations (and any future workspace consumer) must keep its vendored copy
  byte-current with canon via re-pin; the VENDORED-FROM headers are
  re-stamped at each `ci/vX.Y.Z` cut. Until a consumer re-pins AND rebuilds
  the image, canon-side image fixes (e.g. `libatomic1`) do not reach its
  running runners.
- Automated drift detection for the vendored `scripts/ci-runner/` copy is
  explicitly deferred (PLAN-016 §5) — the header makes drift visible;
  wiring the check is a named follow-up.
- Base-image digest bumps land in canon only (consumer dependabot watches
  removed); the canon docker watch is best-effort against a tagless digest
  (manual refresh path in the runner README remains authoritative).

**Feature-freeze reconciliation:** the 2026-07-19 ASSESSMENT recommended
freezing new canon capability until fleet adoption catches up. PLAN-016 is
exempt as **defect closure + adopter-path repair**, not new capability: it
fixes two shipped image-drift defects (`gh: not found` PR #101;
`libatomic.so.1` business #63) and the public 404 in the documented adopter
path — all pre-existing obligations of the already-shipped label contract.

**Origin**

`plans/PLAN-016_runner-canon-templates.md` (17-citation Claim ledger; 7
independent verified-planning-reviewer passes; two founder-authorized cap
extensions). Supersedes the runners.md §2 "this is aidoc-flow-operations
infrastructure" framing; OPS-0075's contract (labels, single-use, hardening,
LiteLLM) is unchanged and remains authoritative in operations.

---

## CI-0013: Complete the canon before rolling it out; pre-rollout consumer drift is expected signal (2026-07-22)

**Context**

A five-lens pre-prod review scoped to onboarding a new private consumer
(`aidoc-flow-feedback-desk`) found the cold-start path — `install.sh` on a repo
with no prior canon surfaces — broken for 9 consecutive releases (FT-30), plus
six further canon defects (FT-25 … FT-29, FT-31). Every existing fleet consumer
adopted before `ci/v2.2.0`, so none of them exercised the broken path.

This forced a sequencing question that PLAN-018 could not answer on its own:
should canon fixes be constrained by "do not disturb the already-adopted fleet",
or should canon be completed first and the fleet re-rolled afterwards?

**Decision**

Founder direction (2026-07-22): **complete `aidoc-flow-ci` first** — templates,
scripts, flows, and rules — and roll the canon over to the other repos only once
it is complete. Canon completeness is the goal; fleet propagation is a later,
separate phase.

Two consequences follow directly, and are decided here rather than per-PR:

1. **Pre-rollout consumer drift is expected, correct signal — not damage.** When
   canon adds a required surface (e.g. commit-stage hooks in
   `install/templates/pre-commit-hook-block.yaml`), already-adopted consumers
   will report `DRIFT` under `install/apply-standards.sh --check`. That report is
   TRUE — those repos predate the completed canon — and it becomes the worklist
   the later rollout consumes. Canon therefore asserts its full intended
   standard and does NOT weaken a check to keep the stale fleet green.
2. **The prohibition that survives is narrower: no SILENT WEAKENING of a live
   gate.** Divergence is acceptable; quietly turning an enforcing gate off is
   not. Concretely, a canon template change must never flip a consumer's
   deliberately-graduated blocking gate to report-only through
   `install.sh --update` (the `markdown-lint` `fail-on-findings` case,
   PLAN-018 F6).

**Consequences**

- `apply-standards.sh --check` is expected to report fleet-wide drift on
  `.pre-commit-config.yaml` between canon completion and rollout. This is an
  operator-run report, not a CI gate — no workflow invokes `apply-standards.sh`
  (`standards-drift.yml` runs `sync/check-standards-drift.sh`, which does not
  inspect that file), so nothing goes red in the interim.
- PLAN-018 is re-scoped from "unblock the feedback-desk onboarding" to canon
  completeness; findings previously deferred to the FT ledger as out-of-scope
  are pulled back in.
- The rollout phase needs a migration path, and the one that exists is
  **version-only**. FT-9 is RESOLVED (`ci/v1.9.0`, PLAN-006 W2) by adding
  `install.sh --repin`, which surgically rewrites `@ci/vX.Y.Z` on `uses:` lines
  and preserves per-repo customization. But `--update` — the path that adopts a
  new template *body* — still wholesale-replaces every `safe_to_replace` caller
  by design, and rolling a *completed* canon out is body-adoption, not a re-pin.
  So the rollout will need per-repo caller reconciliation (runner labels,
  `permissions:` blocks, trigger customizations), and canon should carry a
  documented procedure for it. Tracked as part of this plan's Workstream D
  rather than assumed.
- Supersedes the working assumption in PLAN-018's original fix-contract item 6
  ("no installed surface may diverge from its canon template").

---

## CI-0014: A reusable asserts the trust-config schema version it understands (2026-07-25)

**Context**

The trust config (`.github/ai-review/config.json`) is a **single shared source**
— `trust_config_repo` defaults to `vladm3105/aidoc-flow-operations@main` — while
each consumer pins its **own** `ci/vX.Y.Z` reusable. Every read of that config
was a `jq -r '.field // "default"'`, so a schema the reusable did not understand
silently produced a default instead of an error.

`ci/v2.0.0` replaced the v1 `reviewer` field with `litellm.model`. When
operations cut over on 2026-07-16, `reviewer` vanished for *every* consumer,
including the seven still on `ci/v1.9.5`, whose `jq -r '.reviewer // "codex"'`
then silently selected the codex engine. None of those repos holds
`OPENAI_API_KEY`, so all seven had a fail-closed AI-review gate that could not
pass for ~9 days; merges in that window went through `--admin`. The surfaced
error — `no parseable verdict — fail-closed` — named neither the cause, nor the
trigger (a schema change in *another repository*), nor the owner. One consumer's
`HANDOFF.md` recorded the cause as a lapsed reviewer credential, and that
misdiagnosis survived across sessions.

**Decision**

A reusable MUST assert the config schema version it understands **before**
reading any field, and MUST fail loud — naming the config source, the version
found, the version expected, and the remedy — rather than defaulting. The v2
reusables assert `version == 2` in both jobs that fetch the config, and the
`litellm.model` read no longer carries a `// "ai-reviewer"` fallback (the v2
schema already declares `version: {const: 2}` and requires `litellm.model`; the
assertion enforces a contract the schema stated but no code checked).

**Consequences**

- Forward-only by founder direction (2026-07-25): no `ci/v1.9.6` backport. A
  v1 reusable has no LiteLLM client, so failing loud there would name the cause
  but still not restore the gate; migrating those consumers to v2 is the remedy.
- **Shared config + per-consumer pins means one repo's upgrade is a breaking
  change for every un-upgraded consumer.** Any future schema bump MUST either
  version the config path (`config.v1.json` / `config.v2.json`) or land after
  every consumer has re-pinned. The assertion makes such a mismatch *detected*
  and *named*; it does not make it safe.
- Verified before landing: the live operations config declares `"version": 2`,
  so the assertion passes for current v2 consumers rather than bricking them.
- **The two copies are deliberately asymmetric, and the asymmetry is the point.**
  `ai-review` is `needs: trust` with a non-`always()` `if:`, so failing the
  `trust` job SKIPS `ai-review` — and a skipped job reports green to branch
  protection, while `call / trust` is not a required context in any tier
  profile. A fatal assertion in `trust` would therefore have converted the exact
  event this check exists to catch into a GREEN required check with no review
  performed: strictly worse than the original defect, which at least went red.
  It would also have removed the `skip-ai-review` label escape hatch, since that
  label cannot rescue a PR whose `trust` job hard-fails. So the trust copy
  **diagnoses** (`FATAL=0`, warning) and the `ai-review` copy **enforces**
  (`FATAL=1`, red required check). Same reasoning as FT-43: never let a
  skipped-job green stand in for a verdict. A `trust` job that cannot read the
  config still fails safe on its own — it finds no `trust.ai_review` entry,
  treats the author as untrusted, and routes to human-review-required.
- **Accepted break:** an external adopter pointing `trust_config_repo` at a
  hand-rolled config with no `"version"` field now fails the `ai-review` job
  where it previously ran on a guessed default. This enforces what the published
  v2 schema always required, and canon's own template has always shipped
  `"version": 2`; every in-workspace consumer is unaffected. **Classified MINOR**
  (founder, 2026-07-25): enforcing an already-published schema requirement that
  no real consumer violates does not warrant a fleet-wide major bump, and this
  repo's stated consumers are the sibling aidoc-flow repos.
- Three distinguishable preconditions get three distinct errors — `jq` missing,
  config missing/empty, config unparseable — each labelled INFRASTRUCTURE and
  each saying *do not edit the config schema in response to this*. Collapsing
  them into the "no `version` field" message would have reproduced CI-0014's own
  pathology (an error naming the wrong cause and the wrong repository) inside
  the fix for it.

**Origin**

Finding 1 of the `aidoc-flow-framework` `ci/v2.14.0` migration report
(`framework/tmp/CANON-FINDINGS_ci-canon-v2-migration.md`, 2026-07-25), filed
upstream after reproduction against canon source.

---

## CI-0015: A reusable's `permissions:` block is a ceiling, not a request (2026-07-25)

**Context**

`docs-sync.yml` capped `pull-requests: read` at workflow level with no job
override, while its `sync` job runs `gh pr comment`. GitHub computes a reusable
workflow's token as the **intersection** of caller and callee permissions, so no
caller could grant `write` — the comment step was unreachable for every consumer
from the day it shipped. It went unnoticed because the step is gated on
`proposed != 0` and had never fired; the workflow reported green throughout.

The caller template *did* grant `write`, and its comment explained the rule only
half-correctly ("a callee cannot grant its own permissions — the caller must").
That framing led a consumer to raise its caller (framework PR #333) expecting the
upstream half to arrive with a re-pin; it did not, and `docs-sync` stayed red
after migrating.

**Decision**

A reusable MUST declare the maximum permission any of its steps needs, and canon
comments MUST state the rule as an intersection in **both** directions: raising
either half alone is inert. `docs-sync.yml` moves to `pull-requests: write`.

**Consequences**

- **The missing half was always the callee.** The shipped caller template has
  granted `pull-requests: write` since `001df6e`, first released in
  `ci/v2.11.0`, so for a consumer installed from `ci/v2.11.0` onward the remedy
  is simply to re-pin to a release containing this fix — no caller edit needed.
  Only a caller installed before `ci/v2.11.0` and never re-installed, or one
  hand-edited down to `read`, also needs a caller-side change. (Stated precisely
  because the earlier draft of this entry claimed all callers grant `read`,
  which contradicted its own Context section.)
- `--repin` does not raise a caller that IS at `read`: it rewrites `uses:` lines
  only.
- A green reusable proves nothing about a step gated behind a condition that has
  never been true. Permission ceilings are exercised only on the path that uses
  them.

**Origin**

Finding 2 of the framework `ci/v2.14.0` migration report (2026-07-25).

---

## CI-0016: `secret-scan` scans full history; document the scope it actually runs (2026-07-25)

**Context**

`ci/v1.x` ran `gitleaks dir .` (working tree at `HEAD`); `ci/v2.x` runs
`gitleaks git .` (all reachable commit history). The workflow's own header
comment still said `dir`, and neither `MIGRATION_v2.0.0.md` nor the `v2.0.0`
changelog mentioned the change. A consumer validating locally per the migration
guide ran `dir`, saw **0 findings**, pushed, and CI found **33** — all in
pre-migration history at paths absent from `HEAD` — forcing a second round of
allowlisting.

**Decision**

The scope expansion stands: full-history scanning is the correct shape for a
secret gate, since a credential reachable in history is leaked regardless of
whether it survives at `HEAD`. Only the documentation was wrong, and it is
corrected at the workflow header and in the migration guide, which now states
the v1→v2 scope change and directs local validation to `gitleaks git .`.

**Consequences**

- First-run v2 adopters with historical placeholder credentials should expect
  new findings, and must allowlist with an **anchored** `paths` regex — an
  unanchored allowlist is reported INCONCLUSIVE by the config canary because it
  would also suppress real findings.
- Canon rule: when a workflow's scope changes, the header comment, the migration
  guide, and the changelog are all part of the change.

**Origin**

Finding 3 of the framework `ci/v2.14.0` migration report (2026-07-25).

---

## CI-0017: `litellm_allow_insecure_http` is scoped by URL scheme, not repo visibility (2026-07-25)

**Context**

PLAN-009 Edit D assigned `litellm_allow_insecure_http: true` to the private trio
only, implicitly assuming public consumers reach the proxy over HTTPS. That does
not follow: `aidoc-flow-framework` is **public** and reaches the same host-local
proxy over `http://`, so it needed the flag too. Separately, the bridge-vs-
loopback base URL was documented only as a parenthetical, and its failure mode is
opaque — `proxy request failed after 3 attempts: URLError`. Setting
`http://127.0.0.1:4001/v1` works when tested **from the host** and fails only in
CI, because the job executes inside a container.

**Decision**

State the rule by **URL scheme**: any consumer whose `LITELLM_BASE_URL` begins
`http://` needs the flag, regardless of repo visibility. Since PLAN-013
(CI-0008) routes the whole AI flow to the shared self-hosted pool — where the
proxy is the plain-HTTP Docker bridge gateway — public repos are the common
case, not the exception. `LITELLM_BASE_URL` MUST NOT be loopback, and
`litellm_client.py` now names that specific cause when a connection fails from
inside a container instead of surfacing a bare `URLError`.

**Consequences**

- Corrected wherever the rule was stated by visibility: `CLAUDE.md`,
  `docs/REPO_STANDARDS.md`, both reusables' input descriptions, and both caller
  templates.
- Container detection sharpens an error message only; it never gates behaviour,
  so a false negative merely restores the previous, vaguer diagnostics.

**Origin**

Findings 5 and 6 of the framework `ci/v2.14.0` migration report (2026-07-25).

---

## CI-0018: A drift check states its coverage; unreadable is not drifted (2026-07-25)

**Context**

Run `30174458428` on `aidoc-flow-framework` (`tier=governance`, default
`GITHUB_TOKEN`) concluded **success** while verifying almost nothing. It emitted
`repo-settings.allow_merge_commit: canon=false actual=null` for eight fields —
presenting *unreadable* state as a drift finding, since `null` meant the token
could not read it. The adjacent `actions.*` arm handled the same situation
correctly with "cannot check". Of four control families, branch-protection and
actions were skipped and repo-settings were unreadable; only **labels** was
genuinely verified, and the job still passed.

**Decision**

Two rules. (1) **Never compare canon against a value never obtained** — an
admin-only field absent from the API response routes through `warn_uncheckable`,
matching the precedent already set by the `actions.selected.patterns_allowed`
arm. (2) **A drift check states its own coverage**: the final line reports
`verified N/4 control families`, names the unverified ones, and says explicitly
that a green result does not mean they match canon.

**Consequences**

- Under the default `GITHUB_TOKEN` a typical run now reads `verified 1/4
  (labels)` with a warning naming the rest — the honest reading of what a green
  check meant all along.
- `--strict` already failed on `FETCH_ERRORS`, so a gate that cannot read its
  settings already did not pass; that behaviour is unchanged and now tested.
- Consistent with the failure class named in CI-0011 and CI-0013: a check that
  cannot see its subject must say so rather than report a comparison.
- **"Verified" is ALL-OR-NOTHING per family.** The first implementation marked a
  family verified on any partial progress, so a run could emit *"cannot check
  repo-settings"* and *"verified 4/4"* in the same output — the defect this
  mechanism exists to prevent, rebuilt inside it. `actions` derives its mark from
  a `FETCH_ERRORS` snapshot rather than a per-arm counter, so an arm added later
  cannot forget to withhold it. The summary's clean branch is gated on the skip
  SET being empty, never on a count.
- **`jq -e` exits 0 on EMPTY input for any filter**, because it emits no output
  and `-e` never sees a false result. Every response shape guard therefore tests
  `[ -s "$file" ]` FIRST (`json_readable`). Without it, a 0-exit-but-empty `gh
  api` body read as fully present and printed `canon=X actual=` for every key —
  unread state reported as drift, with the family then marked verified. The same
  guard is applied to the branch-protection, repo-settings and labels arms.
- The coverage line distinguishes *could not be read* from *unverified for
  another reason*; telling a reader that a real, read, confirmed finding "could
  not be read" is its own mis-attribution.
- Fixed alongside: `DEFAULT_BRANCH` was resolved as `$(gh api … || echo main)`,
  but `gh` writes its error body to STDOUT, so a 404 CONCATENATED with `main` and
  every downstream branch-protection query hit a garbage path.

**Origin**

Finding 4 of the framework `ci/v2.14.0` migration report (2026-07-25).

---

## CI-0019: A plan names `Latest` as its rollout target, never a fixed tag (2026-07-25)

**Context**

PLAN-009 carried two contradictions. Its Phase 2 **Edit F** body still said to
move only the heavy *review* job to the self-hosted pool and keep the trust job
on `ubuntu-latest` — the pre-PLAN-013 shape, contradicting the plan's own
superseded-target banner, and **under-sizing the pool by half** for anyone who
followed the body. Its fleet target said `ci/v2.8.0`, six minors behind the
current `Latest` (`ci/v2.14.0`), so a consumer following it literally would
re-pin and immediately need a second re-pin. Both had already gone stale once
before (`ci/v2.0.1` → `ci/v2.8.0`).

**Decision**

A multi-phase rollout plan states its target as **`Latest` resolved at execution
time** (from `VERSION` or `gh release view`), not a fixed tag, and directs the
executor to the release notes for caller-body changes `--repin` cannot apply.
Where a plan body is superseded, the body is corrected — a banner alone is not
sufficient, because executors follow bodies.

**Consequences**

- Edit F now sets **both** `runner_labels_routine` and `runner_labels_review` to
  the pool, with the fork-safety boundary stated inline (a fork reaches only the
  `trust` job, which checks out the trusted config repo and executes zero PR
  code; fork-code-executing lint flows stay on `ubuntu-latest`).
- Pool sizing for public consumers must budget for both jobs per repo.

**Origin**

Finding 7 of the framework `ci/v2.14.0` migration report (2026-07-25).

---

## CI-0020: Cross-repo defects are filed as issues on the owning repo (2026-07-25)

**Context**

CI-0014 was discovered by a consumer (`aidoc-flow-framework`) during its
`ci/v2.14.0` migration, but the defect was owned by canon. Before it was filed
upstream, the consumer's `HANDOFF.md` recorded a **wrong** root cause ("no
working reviewer key") and prescribed a fix that would not have worked — the
credential was valid throughout and never consulted.

That misdiagnosis survived multiple sessions, and it survived **precisely
because it was only ever written down locally**. Nothing about a per-repo
`HANDOFF.md` reaches canon, and canon is where the fix lived. Meanwhile the
same defect sat latent on six other consumers.

**Decision**

Adopt the rule proposed in issue #310: when work in one repo surfaces a defect
**owned by another repo**, file it there as a GitHub issue. The test is
**ownership, not severity** — if the fix belongs in another repo's files, it
gets an issue there, and a local workaround does not discharge the obligation.
One issue per defect; new evidence for an already-filed defect is a comment,
not a new thread; the issue number is linked back in the finding repo.

A filed issue carries: reproduction against their source (`file:line` + the
command or run), blast radius actually checked rather than assumed, why the
symptom misnames the cause, a concrete suggested fix, and what is *not* broken.

**Consequences**

- Codified as `docs/REPO_STANDARDS.md` §18, and as a `## GitHub operations`
  subsection in `install/templates/CLAUDE.md.template` so adopters inherit it.
- Wave 0 self-adoption: this repo's own `CLAUDE.md` carries it, including the
  inbound direction — canon is the OWNER for defects consumers file against it.
- Corollary of §0 (canonical source authority): if canon owns the rule, canon
  owns the defect report. The two sections should be read together.
- Does not change any workflow behaviour; it is a process rule with no CI
  enforcement. Compliance is visible in the issue tracker, which is the point —
  a rule whose observance is public needs no gate.

- **Operational addendum (§18.4):** `gh issue create --body -` sets the body to
  a literal `-` — it exits 0 and prints a URL, so it looks like it worked.
  `--body-file -` is the flag that reads stdin. All five issues from this
  migration (#305-#309) were initially published EMPTY that way and were caught
  only because a human looked. The rule therefore requires reading the artifact
  back (`gh issue view <N> --json body --jq '.body | length'`); an empty issue
  discharges nothing. A filing rule that does not survive its own tooling is not
  a filing rule.

**Origin**

Issue #310 (2026-07-25), proposed from the `ci/v2.14.0` migration and adopted
first in `aidoc-flow-framework` (its PR #340). Motivating incident: CI-0014.

---

## CI-0021: An infrastructure outage gets a targeted break-glass, not `--admin` (2026-07-25)

**Context**

`call / ai-review` is required on every non-bootstrap tier, and `skip-ai-review`
is deliberately advisory. Fail-closed is right, but the consequence is that
during a reviewer **outage** there is no non-`--admin` path to merge anything,
including the PR that would fix the reviewer. `--admin` bypasses **every**
required check, not just the broken one.

CI-0014 is the demonstration: seven repos ran a fail-closed `ai-review` for ~9
days, every merge went through `--admin`, and a wrong root cause sat
unchallenged throughout. Once the bypass is routine, nobody reads the gate.

**Decision**

Let the INFRASTRUCTURE-vs-verdict distinction canon already maintains
(`ai:review-infra-error`) reach `composition`, discharging the ai-review gate —
and only that gate — on **three independent conditions**: the label is present;
an `APPROVED` review exists at the current head SHA from a non-Bot login in
`vars.CI0021_BREAKGLASS_APPROVERS`; and that approver authored/pushed **no**
commit at HEAD.

**Opt-in**: with the variable unset (the default) the break-glass does not
exist. A repo variable rather than a caller input, because it must be
admin-writable — a caller input would let the gated repo pick its own
overriders.

**Consequences**

- **Separation of duties is mandatory, and it is the condition GitHub does not
  provide.** GitHub forbids the PR AUTHOR from approving but says nothing about
  whoever PUSHED the commits, and canon's tiers set
  `required_approving_review_count: 0` + `require_last_push_approval: false`, so
  `composition` is the only gate on the diff. An earlier draft of this change
  omitted condition 3 and was a **single-account merge bypass**: push to a
  colleague's PR branch, induce or apply the label, approve your own code.
  Caught in adversarial review before shipping.
- **State the property accurately, including the residual.** Condition 3 compares
  the approver against the git **author/committer** logins at HEAD. It does NOT
  check the pusher — GitHub's REST API exposes no pusher field. Author and
  committer are written by whoever ran `git commit`, so a determined actor can
  set an email resolving to another account or to none. Unattributable commits
  and truncated commit listings therefore fail CLOSED (a second review cycle
  found that treating a null login as "no author" re-opened the bypass). The
  honest claim: **without `required_signatures`, condition 3 stops an accident
  and a careless actor, not a determined one** — a repo arming the break-glass
  on a tier with `required_approving_review_count: 0` should also require
  signatures.
- **State the property accurately.** This guarantees a second **account** on the
  allowlist that did not write the code — not "a second person". `MEMBER` /
  `COLLABORATOR` do not imply write access, and `user.type != "Bot"` does not
  exclude a machine account driven by a PAT; the allowlist is what makes the set
  of overriders an explicit, admin-controlled decision.
- **Latest review per user wins, across pages.** The reviews API returns each
  submission as its own object retaining its own state, so an `APPROVED`
  retracted at the same SHA would otherwise still match. `--slurp` is
  load-bearing here: `gh --paginate` applies `--jq` to each page separately, so
  without it the aggregation computed latest-per-user within a 30-review page —
  inert on exactly the long-lived PRs it was written for. Only state-CHANGING
  reviews take part, since GitHub treats `COMMENTED` as non-state-changing.
- **Fail-closed on both fetches.** An unreadable review list or unreadable
  commit authorship blocks; an unverifiable separation-of-duties test is not a
  passed one.
- **Targeted + auditable.** Only ai-review is discharged; the pass emits a
  warning naming the approver and stating the App did not approve.
- **Cannot drive auto-merge**: `auto-merge-ai-prs.yml` independently requires
  `ai:review-passed`, which is mutually exclusive with `ai:review-infra-error`.
- Normal path unchanged: with no infra label the block is inert.
- **Correction to an earlier claim in this entry's first draft:** the composition
  caller templates do NOT subscribe to label events (`pull_request_target` was
  dropped in IPLAN-0026 Phase 2), so "removing the label re-triggers
  composition" is only true indirectly — via ai-review's own label trigger and
  the `workflow_run` chain. The break-glass does not depend on it, because the
  human approval fires `pull_request_review` directly.
- Codified as `docs/REPO_STANDARDS.md` §19; 18 assertions, nine of which drive
  the shipped block itself via markers (FT-43 precedent).

**Origin**

Issue #311 (2026-07-25), raised while bringing `aidoc-flow-framework`'s required
checks into line with its tier template. Motivating incident: CI-0014.

---

<!-- Append new entries above this line; append-only. Never rewrite
history; if a decision is reversed, add a NEW entry citing the reversal
and update the superseded entry's "Consequences" section to reference
the reversal ID. -->
