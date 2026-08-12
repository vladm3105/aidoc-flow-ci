# DECISIONS — aidoc-flow-ci

Durable, ISO-stamped, **append-only** record of load-bearing decisions
for the workspace CI + governance-workflow canon library.

**ID prefix:** `CI-NNNN`. Never reuse a retired ID.

**Entries are ordered by ID, not by date.** An ID reserved by an open plan may be
filled in place when that plan lands; nothing already written is changed.

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

## CI-0022: A prompt states the model's real inputs — and nothing else (2026-07-25)

**Context**

`ai-review/review-prompt.md` told the reviewer that "the changed files are in
the current directory", that "the working tree is the base branch", and to
"VERIFY by listing the file" before applying the doc-coverage rule.

None of that is true and none of it has ever been true. The `ai-review` job has
**no `actions/checkout`** by design (IPLAN-0024) — verified at `ci/v1.9.5` as
well as across `ci/v2.x`. Its prompt is assembled from exactly the rubric, a
changed-file inventory, and the diff, and is sent as a single completion.

What changed at `ci/v2.0.0` was not the access but the model's ability to
compensate for the claim. The v1 agentic CLIs had a shell and `GH_TOKEN`, so a
model told to look at a file could fetch it — a partial fetch is a plausible
mechanism for #81, where the reviewer asserted that an existing `OPS-NNNN`
decision "does not exist anywhere in `ops/DECISIONS.md`". The v2 completion has
no tools at all, so the instruction is not merely inaccurate; it is
**unexecutable**, and an unexecutable instruction is not skipped — it is
answered from nothing. Those verdicts blocked merges and spent OPS-0066
circuit-breaker budget on fabricated findings.

Two rules were affected in defined ways. The doc-coverage precondition ("does
this consumer have `CHANGELOG.md` at its root?") is **unanswerable** from the
diff plus a changed-file inventory: a repo that has the file and did not touch
it is indistinguishable from a repo that has none, so the rule either disabled
itself silently on every consumer or fired on a guess, and canon did not
determine which. The dead-relative-link check had the same shape — a target
outside the diff is simply not visible.

**Decision**

Align the prompt with the architecture, not the reverse; the no-checkout design
is deliberate and worth keeping. Three parts:

1. **State the inputs.** The rubric opens by enumerating exactly what the model
   receives and asserting it has no shell, no tools and no working tree, with
   the operative consequence spelled out: a finding that cannot be grounded in
   those blocks must not be emitted, softened into a suspicion, or described as
   having been checked. Under-reporting is the intended failure mode.
2. **Make the precondition evaluable.** `ai-review.yml` now passes a **repo-root
   file inventory** — the regular files at the repository root at the PR's base
   commit, one `gh api` call — as a third input block. This was option 3 in
   issue #315 and is the only branch that makes the doc-coverage precondition
   genuinely decidable rather than scoped away.
3. **Narrow what is left.** The dead-link rule is restricted to the three cases
   the inputs settle (root-level target, a target this PR deletes or renames, a
   reference internal to the diff) and instructs silence — not a hedge — for
   everything else. The quantitative-claims section is scoped to counts
   recountable from the diff text.

**Consequences**

- Codified as `docs/REPO_STANDARDS.md` §20, written as a general
  prompt-construction rule rather than an `ai-review` fix, because
  `fix-prompt.md` and any future canon prompt are subject to the same failure.
- The root inventory **fails soft** to the literal marker `UNAVAILABLE` on an
  API failure, an empty body, or a listing at the contents API's 1000-entry cap
  (which truncates with no flag, so "absent from it" would stop meaning "absent
  from the repo"). The rubric branches on that marker and treats the dependent
  rules as inapplicable. This is not a fail-open: an unavailable input can only
  suppress a blocking finding, never manufacture one, and hard-failing a
  required check on a transient contents-API blip would be strictly worse.
- **The inventory lists every root entry, directories marked with a trailing
  `/`.** A files-only listing was the first draft and was caught in review: it
  would have made every root directory absent from a list the dead-link rule
  reads as authoritative for absence, so a link to `docs/…` would be flagged
  dead because `docs` was filtered out. A filtered input is a lying input; the
  general form is `REPO_STANDARDS` §20.2 rule 5.
- **The changed-file inventory is held to the same standard.** Its listing is
  fetched fail-soft while the diff fetch is fail-hard, so it could reach the
  reviewer labelled `(complete)` when it was truncated — and this change makes
  the doc-coverage precondition key on it. It is now reported `UNAVAILABLE`
  unless provably complete, and the rubric falls back to the diff's own
  `diff --git` headers, which are equally complete.
- **All three blocks are fenced and labelled untrusted.** Paths are
  attacker-influenced and git permits a newline in a path, so an unfenced list
  sat in the prompt's highest-authority position as free text. The fence bounds
  that channel rather than closing it; the root inventory itself is read from
  the base repo, so no fork can put a byte in it.
- **A degraded input set is disclosed in the verdict comment**, not only in a
  `::warning::`. A review missing an input is by construction the one that goes
  green, and nobody reads the log of a green check.
- The marker is a **contract between the workflow and the rubric** — the
  workflow writes the literal, the rubric keys on it. `tests/test_contract.sh`
  gains 31 assertions: both halves of that contract, same-name same-order
  same-count parity between the prompt assembly and the rubric's "Your inputs"
  section, and 11 assertions that **drive the shipped root-inventory block**
  through nine stubbed `gh` scenarios — success, API failure, empty body,
  output-then-failure, at-cap, below-cap, fail-twice-then-succeed, missing base
  sha, and one that runs the block's own `-q` filter through real `jq` against a
  contents-API payload. A stub that only controls the return value left the URL
  and the filter untested; that gap hid three live mutations (dropping
  directories, inverting the base-sha guard, collapsing the retry loop) until
  review named it.
- Behaviour change for consumers is confined to the reviewer's verdicts and its
  PR comment; no input, secret, permission or required-context changes. The extra
  API call needs repo-contents read, which the job's existing `contents: write`
  already includes.
- `ai-review/README.md` and `docs/ai-review-assets.md` still describe the v1
  sparse-checkout asset delivery, which now contradicts §20.3's "no checkout"
  head-on. Filed as **#318** rather than folded in here — this PR is already at
  the OPS-0061 Rule 1 three-doc-surface cap.
- The DECISIONS-substitution branch stays explicitly deferred and
  must-not-be-invented: this rubric still specifies no reliable mechanism for
  detecting a per-consumer alternate docs-of-record convention.
- #81 stays open as the record of the user-visible symptom and closes when this
  ships. Its "file-window truncation" root cause is a v1-era hypothesis that is
  now **moot** rather than disproved — under v2 the file is never read at all —
  and its symptom class (asserting that an unseen `OPS-NNNN` decision does not
  exist) is what the dead-reference rule now forbids. Its structural mitigation
  (splitting `operations/ops/DECISIONS.md` by year) is deliberately NOT carried
  forward: the truncation it targeted is not the mechanism. The guard is
  prompt-level, so a recurrence reopens #81.

**Origin**

Issue #315 (2026-07-25), filed from re-scoping #81. The scope widened during
verification: the mismatch is not "restore what v2 dropped" but "state the
reviewer's real inputs, which have never included a working tree" — the
doc-coverage rule dates from #78, written when the reviewer was agentic, and was
always describing a working tree that did not exist.

---

## CI-0023: A fail-closed guard fails on faults, not on a consumer's tree shape (2026-07-26)

**Context**

FT-57 gave `install.sh` a mandatory pre-write backup that is deliberately
fail-CLOSED: if the snapshot cannot be taken, nothing is written. The
enumeration is `find -L .github ! -type d`, which yields a **dangling symlink**
(the stat fails, so `find` returns the link itself). The copy was a bare
`cp -p`, which **dereferences** — so it failed on that link, and the
fail-closed contract turned one broken link into `exit 1`.

A consumer carrying a single dangling symlink anywhere under `.github/` could
therefore not run `install.sh` **in any mode**, including the documented
`--repin` upgrade path. That repo was not broken and the backup was not
impossible: a dangling link is perfectly copyable *as a link*. The adjacent
comment already claimed broken symlinks were handled, so the code read as
correct.

This is a regression against `ci/v2.14.0`, introduced by FT-57 inside the same
unreleased window, and it sits on the FT-30 cold-start bootstrap write path —
where a throwaway-repo dry-run would never have surfaced it, because a fresh
repo has no dangling links.

**Decision**

For every input a guard enumerates, classify it explicitly as a **fault**
(abort) or a **shape** (handle), write the branch, record which in a comment —
and **sweep every arm of the guard**, because the same input shape usually
reaches it by more than one path.

For the backup: a resolvable symlink is captured by **content** (what a restore
wants), a dangling one is copied as the **link**, and a symlink loop, an
unreadable file or an unenumerable directory remain genuine faults that abort.

The branch must not be "simplified" to a blanket `cp -P` — that would stop
capturing content for resolvable symlinks, a different defect in the same
place. Both directions are asserted.

**Consequences**

- `install/install.sh` branches on `[ -L "$p" ] && [ ! -e "$p" ]`, copying with
  `cp -Pp` (bare `-P` would not carry the link's own timestamps).
- **The sweep found the same shape wrong in a second arm, in the opposite
  direction.** The root-list loop gated on `[ -e "$r" ]`, which dereferences, so
  a dangling symlink at a root path was **silently dropped** — rc=0, "success",
  that surface absent from the snapshot while `install.sh` could still overwrite
  it. Fail-OPEN, strictly worse than the abort, and it announced nothing. Now
  `{ [ -e "$r" ] || [ -L "$r" ]; }`.
- **A symlink loop stays a fault but now names itself.** `find -L` exits
  non-zero having enumerated nothing, and the old message blamed an "unreadable
  subdirectory?" — sending the operator to `chmod` for a cycle no `chmod` can
  fix. `find`'s stderr is now kept and the loop diagnosed by name.
- **Residual, scoped:** `[ ! -e ]` is false for `EACCES` as well as `ENOENT`,
  so a resolvable link whose target sits behind an unsearchable directory is
  misclassified as dangling and backed up as a link. Reachable **only on the
  root-list arm** — on the `.github/` arm `find -L` gets `EACCES` and the run
  hard-aborts before the copy branch. Recorded in §21 rather than left implicit.
- `tests/test_install.sh` 101→114, driving the `MANDATORY-BACKUP` block
  extracted from `install.sh` itself, including a **mutation** case: restoring
  the bare `cp -p` must make the dangling-link fixture abort.
- Codified as `docs/REPO_STANDARDS.md` §21.
- No consumer action; no input, secret or permission change.

**Origin**

Found in the `ci/v2.15.0` pre-cut review (2026-07-26), before the tag was
published — so no released version ever carried it.

---

## CI-0024: A mechanical rewriter must not rewrite illustrative examples (2026-07-26)

**Context**

`scripts/sync-version-refs.sh` makes `VERSION` the single source for install
references, rewriting four shapes: the raw-URL install command, `uses:…@tag`
pins, and `CI_TAG=`. Shape identifies *an install reference*; it does not
identify *one that is supposed to be current*.

`docs/MIGRATION_v2.0.0.md` is a TARGET and carries two `CI_TAG=` commands that
must not track `VERSION`: its §5 "repin to `@ci/v2.0.0`" step, and — the
damaging one — its **Rollback** section, whose command exists to pin a consumer
*back* to `ci/v1.x`. Every release cut rewrote both to the new tag. The
published rollback instruction therefore re-pinned **forward**, so an operator
following it during an incident would do the opposite of what the heading
promised, and the §5 heading contradicted the command directly beneath it.

The script's header had already identified this exact risk and prescribed the
remedy — "if a historical install command is **ever added** to a target, mark
that line to exclude it".

**That caveat was accurate when written.** At `a0fc68c` (2026-07-09) `TARGETS`
held `README.md` and `install/README.md`, and `docs/MIGRATION_v2.0.0.md` did not
exist. The warning was correct, prospective, and named its trigger condition
— though not quite the event that occurred: it anticipated an example being
added to a target, whereas what happened was the inverse, a file that *already
contained two* being added to `TARGETS`. That happened on 2026-07-17 in
`1a027da` (#175); the rollback command read `ci/v1.9.5` up to `5992b9b` and has
tracked the release tag at every cut since.

So the defect is not a wrong comment — it is that **the prescribed remedy was
described but never implemented**, so there was nothing for #175 to fail
against. The author of a commit eight days later has no reason to open the
script whose header stated the condition they were about to trip.

**Decision**

The promised mechanism now exists. A span whose install references are
illustrative or historical is wrapped in
`<!-- sync-version-refs:ignore-start -->` / `<!-- sync-version-refs:ignore-end -->`;
both `--check` and the rewrite honour it.

**Unbalanced markers are a hard error** (`exit 2`, naming file and line). An
unterminated `ignore-start` would otherwise silently freeze the rest of a file,
converting this guard into the drift it exists to prevent.

General rule: **a caveat that names a future trigger condition must be enforced
mechanically, in the same change that names it.** Prose cannot stop the commit
that trips the trigger. If the enforcement cannot be built yet, the comment must
say the gap is **unguarded** — an unguarded risk that reads as handled survives
review, which is exactly what happened here.

**This entry holds itself to that rule.** The marker facility alone would be
another unenforced prose caveat, so `tests/test_version_sync.sh` **pins the
`TARGETS` list**: adding a file to it fails the suite with instructions to check
the new target for illustrative install commands and wrap them. That is the
exact trigger #175 tripped, now mechanical.

**What remains, split into its guarded and unguarded halves.** An earlier draft
of this entry called the whole case unguarded; that was wrong, and wrong in the
direction this entry legislates against — a guarded risk described as unguarded
means nobody learns that CI already stops them.

- An illustrative command pinned to an **OLD** tag in a file already in
  `TARGETS` — the #175 case — **is** detected: `--check` reports it stale and
  fails pre-commit and CI. The defect was that its message offered only "run the
  rewriter", which is the action that falsifies the command. It now names both
  remedies, including the markers.
- An illustrative command pinned to the **CURRENT** tag when written is
  **genuinely unguarded**: textually identical to a live reference, undetectable,
  and it drifts at the next cut. Only the markers cover it.

**Consequences**

- Each substitution carries its own negated address range rather than sharing a
  `{ … }` block, because a bare `}` line — as measured here — truncated the
  function-extraction `awk` the tests use to drive the shipped code.
- `tests/test_version_sync.sh` 9→29, driving `sed_program` and
  `validate_ignore_markers` extracted from the script, asserting both
  directions, all four malformed-marker cases, and a **mutation** case:
  stripping the address ranges must clobber the historical rollback command.
- Codified as `docs/REPO_STANDARDS.md` §22.
- The two falsified commands in `docs/MIGRATION_v2.0.0.md` are corrected and
  wrapped in a follow-up PR; this entry ships the mechanism.

**Origin**

Found in the `ci/v2.15.0` pre-cut review (2026-07-26): the release's own prep
run re-falsified the rollback instruction, which is what surfaced it.

---

## CI-0025: Only a code-changing event may cancel an in-flight run of a required gate (2026-07-26)

**Context**

`ai-review`'s caller template subscribes to `pull_request_review: [submitted]`,
and the reusable's concurrency predicate was
`cancel-in-progress: ${{ github.event.action != 'labeled' && github.event.action != 'unlabeled' }}`.

A `pull_request_review` event carries `action == 'submitted'`, which is neither
`labeled` nor `unlabeled`, so the predicate evaluated **true**. The reviewer's own
review submission therefore started a run that cancelled **the run that had just
posted that review** — both on the same head SHA.

A cancelled required check is **not** success and the rollup stays `FAILURE`
(scope, evidence and the open platform question: §23.1 and #330). `call / ai-review` is a required context on the ops, product and
governance tiers, so those PRs could only merge with `--admin`.

Nothing reported an error. `gh pr checks` showed a green `call / ai-review` (the
later run); `gh pr merge` said only "the base branch policy prohibits the merge",
naming no check. The cancelled duplicate was visible only through the GraphQL
`isRequired` projection. The documented recovery made it worse: the
`skip-ai-review` label-cycle starts more runs, each able to cancel another, so the
SHA accumulated cancelled contexts.

This is a strong candidate for the standing "every PR needs `--admin`" folklore in
consumer repos. On `aidoc-flow-framework` it had been recorded as a `composition`
defect; composition was in fact green on the PR head.

**Decision**

**Only a genuinely code-changing event may cancel an in-flight run of a gate**,
expressed as an **allowlist**, not as a denylist of self-emitted events.

`ai-review`'s predicate is now
`github.event_name == 'pull_request_target' && contains(fromJSON('["opened","synchronize"]'), github.event.action)`.

The first draft of this fix was a denylist — it added `pull_request_review` to
FT-43's `labeled`/`unlabeled` exemptions — and **it did not close the defect.**
The caller subscribes to eight `(event, action)` pairs; a denylist naming the
known self-emitted ones still cancelled on `reopened`, `ready_for_review` and
`converted_to_draft`, all of which fire at the CURRENT head SHA. FT-43 added the
latter two to the caller after the predicate was written, and nobody re-derived
it.com, but GHES consumers may still see it —
the same discussion reports it on **3.18.4**, so an earlier draft of this entry
bounding it at "GHES ≤ 3.16" was refuted by its own citation). This is canon
shipped to arbitrary consumers. With `!=` clauses an empty context makes every
comparison true → cancel everything → this very defect. With `==` it yields false
→ never cancel → the fail-safe stance. **A guard whose
degraded mode is the bug it exists to prevent is not a guard.**

FT-43 established exactly this rule for the gate's own **label** writes and did not
generalise it to the gate's own **review** writes, which fire the same way — the
reviewer submits a review on the approval path and again on the IPLAN-0029
non-counting comment-state path.

Letting the review-triggered run finish is cheap **on an armed repo**, and the
qualifier matters: the R3 early-exit skips the heavy reviewer on a
`pull_request_review` event and concludes SUCCESS via the skip-notice step, so no
model call happens. But R3's unarmed guard runs BEFORE that skip (deliberately —
it closes the ci/v2.0.1 review-event bypass), so on a repo with
`vars.APP_REVIEWER_1_BOT_ID` unset **every review event runs a full review**. And
the `trust` job runs in full on every review event regardless, consuming one
serial runner slot. "Cheap" is not "free", and it is armed-only.

**`composition.yml` had already reached this conclusion** and states it at its own
`concurrency:` block — "the run started by the App's `pull_request_review:submitted`
is exactly the one that records the check GREEN — cancelling it … would leave a
satisfied PR permanently blocked." It uses a flat `cancel-in-progress: false`.
`ai-review` cannot: its runs are expensive, so a real push must still supersede an
in-flight review. Hence a predicate rather than `false`. **The lesson existed in
canon and was not carried across the two workflows that needed it** — which is the
generalisable failure here, not the missing clause itself.

**Consequences**

- **`ai-review` is the only workflow fixed here — it is NOT the only one exposed.**
  An earlier draft of this entry claimed it was, scoped to the
  `pull_request_review` trigger; that scoping was wrong, because §23.1's mechanism
  does not care *who* emits the event. Any required context whose caller
  subscribes to a non-code-changing action while `cancel-in-progress: true` is in
  force has the same defect. **Note where that flag lives**, because it decides
  the release boundary: `ai-review` is the only one that sets it in the
  **reusable**, which is why this fix reaches consumers by a re-pin alone. For
  `audit-trail` and the lint family the reusables carry no `concurrency:` block
  at all — the flag is in the **caller templates**, so fixing them requires
  consumers to re-install workflow files. Bundling them here would falsify this
  entry's own "no consumer action beyond re-pinning". The other known instances are
  `audit-trail` (`call / verify`, required on all three tiers) whose caller
  subscribes to `labeled`/`unlabeled` **deliberately**, for the documented
  `skip-audit-trail` escape hatch — so canon's own instructions fire it, by a
  *human* label write; and the lint family (`call / Lint / format / security
  hooks`, required on every tier but umbrella) via `reopened`. Filed as #329 rather than
  expanded into this PR.
- **The sweep's negatives, recorded so nobody re-derives them.** (a) There is **no
  `issue_comment` trigger anywhere in the repo**, so the gate's verdict comments
  are inert and cannot re-trigger anything. (b) The gate self-emits exactly **one**
  workflow-triggering event per run: `set_label` writes labels with
  `secrets.GITHUB_TOKEN`, and GITHUB_TOKEN-authored events do not start workflow
  runs — only the App-token review submission triggers. Two carve-outs to that
  "exactly one": it breaks if `set_label` is ever moved to the App token, and it
  is already false when `autofix` is armed (default-off), since the autofix push
  re-fires the gate with `synchronize` — which is correctly in the allowlist, so
  no behavioural impact.
- **Residual, NOT closed — and cheaper to reach than first written.** GitHub
  documents that queueing behind a concurrency group cancels any previously
  *pending* run in that group, regardless of `cancel-in-progress`. So the trigger
  is one in-flight run plus **two** exempt events, and **the gate supplies one of
  them itself**: a `synchronize` review is running, it posts its own review
  (exempt → run B pending), a human adds any label (exempt → run C pending, B
  cancelled) → a cancelled required context on the live head SHA. No external
  actor and no review spam required. What remains genuinely unverified is only
  whether an evicted-while-pending run has already materialised its check-run;
  queued reusable jobs do surface as pending checks, which suggests it has.
  **This applies to a flat `cancel-in-progress: false` too**, so it is not
  something the allowlist or composition's stance eliminates. CI-0025 is narrowed
  decisively — the deterministic, every-PR case is gone — not proven closed.
- The FT-43 contract test asserted the predicate by **grepping its literal text**,
  so it stayed green while the `pull_request_review` case was absent, and would
  have gone red on a harmless reordering. It now **evaluates** the shipped
  expression, and **derives its case list from the caller template's own `types:`
  and asserts that list has not changed** — an added trigger fails the suite by
  name, which a length floor would not have caught, and un-re-derived triggers
  are the CI-0025 history. All eight subscribed pairs are classified, plus an
  empty-context case. Mutation-verified three ways: the original predicate, the
  failed denylist first draft, and a complete-but-fail-unsafe denylist all go red.
- **Consumer action: none beyond re-pinning.** No input, secret, permission or
  required-context change. Consumers already carrying cancelled contexts on an
  open PR's head SHA need one new push (or a re-run of the cancelled context) to
  clear the stale conclusion; the fix prevents recurrence, it does not rewrite
  history.

**Origin**

Issue #322 (2026-07-26), reproduced on `aidoc-flow-framework` PR #346.

---

## CI-0026: A fail-closed guard that cannot fail open is only a cost (2026-07-27)

**Context**

`ai-review`'s FT-43 step `exit 1`d on any draft or non-`skip-ai-review` label
event while the reviewer App was unarmed, to stop a fresh SUCCESS superseding a
standing `request_changes` at the same HEAD.

Its premise was disproved by CI-0025/#330 — a later SUCCESS from a separate run
never replaces an earlier conclusion. But the decisive objection is independent
of that: **the guard never covered the events that would have mattered.**
`reopened`, `ready_for_review` and `pull_request_review: submitted` each re-fire
a full review at an unchanged HEAD on an unarmed repo, and its `if:` named none
of them. Had the supersede risk been real, those three were already the bypass.

What it actually did was write a **permanent** non-success `call / ai-review` —
required on every non-bootstrap tier — on the live head SHA. And the gate fired
it itself: run1's `ai:review-passed` write raises a `labeled` event. An unarmed
repo bricked its own PRs on its own label.

**Decision**

Remove the step. `FT-29` is the guard that actually holds the line: a PR carrying
`skip-ai-review` sets `SKIP_REVIEW='1'`, every heavy step goes inert, and the
skip-notice step `exit 1`s while composition is INERT. Every other unarmed path
now runs a **real review**.

Establish the unsafe state a fail-closed guard blocks before adding it, and
re-establish it when the model beneath it changes.

**Consequences**

- The job-level `if:` keeps FT-43's armed-repo skip; only the step is removed.
  Armed repos are doubly unaffected — the step was unreachable when armed (the
  trust `if:` and the step `if:` are mutually exclusive there) and its armed
  branch `exit 0`d anyway.
- **A gate must not re-enter itself.** Removal left the unarmed clause routing the
  gate's own `ai:review-*` label writes into a fresh full review — unbounded on a
  verdict flip, on a serial pool, from a label any writer can toggle. Both job
  `if:`s now exclude them. Codified as §23.4.
- `tests/test_contract.sh` 354→357: the step must stay absent, both exclusions
  must be present, and **FT-29 is now DRIVEN rather than grep-asserted** — armed
  proceeds, unarmed fails closed, `r3` proceeds. Mutation-verified three ways.
- **Residual:** §23.1's measured pair is `cancelled` + `success`; extending it to
  `failure` + `success` follows from the stated mechanism but was not itself
  measured. The removal does not rest on it (see the subset argument above).

**Origin**

Issue #331, filed from the CI-0025 work. Security-reviewed before merge: no
event/state combination yields SUCCESS without a review on an unarmed repo.

---

## CI-0027: The `doc-maintainer` dry-run cluster — and a census keyed on retries ranks the wrong fix (2026-08-03)

*(Fills the ID slot `CI-0028` below records as reserved; that note is now
historical and carries a forward pointer. Nothing already written was changed.
`plans/PLAN-021_doc-maintainer-dry-run-cluster.md` is unblocked — its status
lives in its own header, not here.)*

**Context**

`doc-maintainer`'s **dry-run** path cannot complete a run that has anything to
say. Four defects converge on it, each verified against source at `ci/v2.16.0`:

| Issue | Defect |
|---|---|
| [#352](https://github.com/vladm3105/aidoc-flow-ci/issues/352) | Step 9 renders the patch with `diff`, which exits 1 when files differ. GitHub's default shell carries `-e`, so the step dies **at** the `diff`, before the `rc=$?` written to tolerate it. |
| [#353](https://github.com/vladm3105/aidoc-flow-ci/issues/353) | The planner tests `path in seen or not matches(path, allowed)` in one `if` and `fail()`s on either — so a duplicate reports as an allowlist violation, naming a path that *is* allowlisted. `validation.rejected` **and** `validation.allowlist_violations` are both declared and never written (`planner.py:202`). |
| [#354](https://github.com/vladm3105/aidoc-flow-ci/issues/354) | `apply.py` refuses files over 200 KB; the install template ships `CHANGELOG.md` as a low-risk path. Changelogs only grow. |
| [#360](https://github.com/vladm3105/aidoc-flow-ci/issues/360) | The inventory globs every `*.md` with no allowlist filter, contradicting IPLAN-0025 §2.1 step 4 — **and** the prompt never forbids proposing outside `allowed_paths`, its only prohibition being by file *type*. |

The pilot (`aidoc-flow-framework`, the only `dry_run: true` consumer) has been
paused via `kill_switch: true` since 2026-07-30. The switch is a **`maintain`-job
property only**: the schedule-gated `reconcile` job reads no config, so
framework's cron keeps dispatching. The accurate claim is *no LLM cost, no
proposals, no failures* — not "no runs".

**Measurement — the census is keyed on `MERGE_SHA`, and its ranking is not the
run-count ranking.** 23 failures over the pilot's first 47 runs are **12 distinct
merges**, not 23 defect instances: `reconcile.py` treats a non-success run as
un-maintained and re-dispatches the SHA, with a retry factor varying 1–4.

| Merges | Cause | Fixed by |
|---:|---|---|
| 4 | duplicate of an allowlisted path (`plans/HANDOFF.md`) | PR-B (353b) |
| 4 | genuinely non-allowlisted path | PR-D (#360) |
| 3 | apply refuses `CHANGELOG.md` at 200 KB | PR-C **for new adopters only**; on the pilot these migrate into the row above and are closed by D-2 |
| 2 | apply's 30 %-deletion guard on `README.md` | **not fixed — [#372](https://github.com/vladm3105/aidoc-flow-ci/issues/372)** |
| 1 | Step 9 dies rendering the dry-run patch | PR-A |

Buckets sum to 14 over 12 merges: two merges fail two ways. By run count the
first two read 9 and 6; **by merge they are 4 and 4**, because the duplicate
bucket is 9 retries of only 4 merges.

**Retries are not replays.** Each re-dispatch re-invokes the planner LLM and
draws a fresh plan, so one merge can fail two different ways across its retries.
Bucket membership at a merge is a *sample*, not a property; the aggregation used
here is "this cause appears at least once".

**Decision**

Ship the cluster as PLAN-021's five PRs, on these four findings — none of them
derivable from the failure counts the plan was drafted against.

1. **PR-D is co-equal with PR-B and lands with the cluster, not after it.** The
   run counts that ranked it fourth are retry-weighted; by merge it ties.

2. **The consumer's recorded resume condition — `RESUME REQUIRES #352 AND #353`
   — is insufficient, and `#360` belongs in it.** Satisfying it as written fixes
   only the duplicate bucket and the Step-9 death, leaving **8 of the 12 merges
   still red**: the 4 non-allowlisted, the 3 `CHANGELOG.md` merges (`#354` is
   also omitted from the condition), and the 2 30 %-deletion trips, less the one
   merge appearing in two of those buckets. The consumer's
   `.github/doc-maintainer.json` note is to be updated when the cluster lands.

3. **353b is `record-then-fail`, not `record-and-skip`.** A non-allowlisted path
   still calls `fail()`, which raises `SystemExit(1)` *before* the plan is
   written — so an `allowlist_violations` populated at plan construction could
   never be non-empty, leaving the field declared-and-never-populated exactly as
   it is today. Write the plan artifact, collect **all** violations, then exit
   non-zero once.

4. **D12 is narrower than #353's fix appears to collide with.** IPLAN-0025 D12
   names plan-validation rejection as a LOUD failure, but its only *defined*
   instance is the out-of-allowlist case (Risk 1, §2.1 step 6). A **duplicate**
   path appears nowhere in IPLAN-0025. Recording a duplicate and continuing is
   therefore most likely not an amendment to D12 at all — it is a case D12 never
   contemplated. **353b approved by the founder 2026-07-30**, taking both 353a
   (de-conflate into two branches, two messages, both still failing) and 353b.

**Consequences**

- **`record-then-fail` does not make the rejections countable, and must not be
  justified that way.** The plan JSON is never uploaded and `Cleanup`
  (`if: always()`) deletes it. **353a's de-conflated `::error::` line is what
  makes P4(d) countable.**
- **PR-C's cost on the live consumer is accepted.** Demoting `CHANGELOG.md` to
  high-risk on `operations` retires changelog auto-maintenance there — that
  flow's primary op. The decision was put **three** times; the middle put rested
  on a figure (1 of 11) that was wrong in the direction making acceptance easier,
  the true figure being 3 of 12. Sequence in PLAN-021 §9 item 2.
- **`operations`' `allowed_paths` edit is a no-op** — its list ends with the
  catch-all `"*.md"` and `matches()` uses `fnmatchcase`, which re-admits the
  changelog. The effective knob is `auto_merge.low_risk_paths`.
- **#360's spec deviation has two halves, and only the second closes the
  bucket.** D-1 (filter the inventory through the allowlist, before the
  `MAX_DOC_INVENTORY` slice) is genuine spec conformance. But all six offending
  proposals were files the triggering PRs had just changed, and the planner
  passes a `Complete changed-file list:` that is unfiltered and untruncated;
  all six are markdown prose files and five are unambiguously documentation, so
  the prompt's file-*type* prohibition does not reach them — while canon tells
  the model the consumer's own "propose nothing outside the allowlist"
  convention is *untrusted data*. D-2, the prompt imperative, is the load-bearing
  half.
- **D-1 must disclose its narrowing, per `REPO_STANDARDS` §20.2 rule 5** ("a
  filtered input is a lying input", CI-0022). Filtering `Documentation
  inventory:` silently makes the omitted files read as absent from the repo; the
  block's label must state it is scoped to `allowed_paths`. PR-D's new §24.4
  must be written as an extension of §20, not beside it.
- **Standing residual — the cluster does not make the pilot green.** The two
  30 %-deletion trips remain. The guard is correct; it reds the whole run instead
  of dropping the entry, structurally the same blast-radius defect as 353b one
  stage later. Deliberately out of scope and filed as
  [#372](https://github.com/vladm3105/aidoc-flow-ci/issues/372). **Do not cite
  PLAN-021 as closing the pilot's failure set.**
- **PLAN-021 is a founder release, not a converged review.** Three independent
  passes returned 10, 9 and 6 findings; all 25 are folded, but the third pass's
  fold is itself unreviewed and OPS-0066 caps the cycle at three. The cap's own
  escape is escalation to the founder, which is what happened. **PLAN-021 §10's
  scoped fourth pass over that fold is still owed, and its precondition — the §9
  founder answers — is now met.** Per-PR review does not discharge it.

**Origin**

PLAN-021 PR-0, from issues #352, #353, #354 and #360. The census correction and
the M1/M2 measurements were run before any code, per PLAN-021 §9; M2 changed the
plan's priority framing, which is why it was required first.

---

## CI-0028: Three doc surfaces, three edit shapes — and feedback is a direction, not a class (2026-07-31)

*(`CI-0027` is reserved by `plans/PLAN-021_doc-maintainer-dry-run-cluster.md`,
which is NOT READY. The gap is deliberate; IDs are never reused. **Filled
2026-08-03 by `CI-0027` above.**)*

**Context**

`doc-maintainer` writes to a repo's documents of record through one edit mode:
`scripts/doc-maintainer/apply.py:66` demands *"Return the COMPLETE replacement
file"*, and `:59` refuses any source over 200 KB. That treats every document
alike. Two of the three surfaces it touches are not alike, and the mismatch has
already produced defects in both directions:

- A changelog only grows, so the 200 KB refusal makes a red run **guaranteed**
  once the model picks it (`#354`).
- This repo's `HANDOFF.md` is 1,393 lines carrying a "Previous state
  (2026-07-25)" block against a ~200-line target — and on 2026-07-30 its
  headline read *"0 open issues, 0 open PRs"* while eight issues were open. It
  had been wrong for three days.
- This repo's `CLAUDE.md` governance table declared the backlog surface *"Not
  adopted"* while `plans/FRAMEWORK-TODO.md` held 1,896 lines when PLAN-022 was
  drafted (2026-07-30) and **1,968 as this decision is written**
  (`wc -l plans/FRAMEWORK-TODO.md`) — PR #356 added FT-58 to it. Per §2 below,
  the command is stated so the figure can be re-derived rather than trusted.

**Decision**

**1. Three surfaces, three edit shapes.**

| Surface | Lifespan | Correct edit | Never |
|---|---|---|---|
| Changelog | permanent, grows monotonically | **anchored insert** under the Unreleased heading | regenerate · reorder · prune · prepend to the file |
| Handoff | ephemeral, rewritten each wrap | **full regeneration** | append · accrete "previous state" sections |
| Backlog | — | the repo's open **GitHub issues** | a parallel markdown queue — except `plans/FRAMEWORK-TODO.md`, grandfathered until FT-58 retires it |

"Add at the beginning" means **beneath the `## [Unreleased]` anchor**, not at
the top of the file — a naive prepend puts entries above the H1. The primitive
is *anchored insert*. The anchor must be configurable: seven workspace repos use
`## [Unreleased]`, **this repo uses the unbracketed `## Unreleased`**
(`CHANGELOG.md:6` — canon is the outlier), and `business` has no changelog at
all by its own governance table, which is a supported state and not an error.
**Canon normalises its own heading rather than shipping a tool whose default its
own repo violates** — deferred, not dropped: `scripts/release.sh:207` hardcodes
`anchor = "## Unreleased\n"` and `:209` aborts the cut if it is absent, so
normalising the heading is canon-body work. It ships with the PLAN-021 Phase 2
tooling that first depends on the default, not before.

**2. Every volatile claim in a handoff carries the command that re-derives it.**
Regeneration alone does not fix the stale-headline failure, because a
carried-forward claim reads as freshly verified. `0 open issues` is
unfalsifiable prose; the same line followed by the
`gh issue list --state all --limit 200` that produced it is checkable in one
paste. This converts a stale handoff from *misleading* into *obviously stale*.

**3. Feedback is a direction of travel, not a class of issue.** A repo's open
issues are its backlog regardless of who filed them: `#352`, filed by a
framework session, and a locally-found bug both mean "ci must fix this" — same
triage, same queue, same close-on-merge. So **no `kind:feedback` label family**;
a classifier that drives no action is a second surface that can only drift.
Direction has teeth in three places, none needing a taxonomy: the promotion bar
and five-part body attach to the **outbound act** (filing on someone else's repo
spends their attention); the **close permission** stays asymmetric (a reporter
never closes another repo's issue); and `source:` survives as **provenance**,
never a sort key.

**Consequences**

- `CLAUDE.md`'s governance table is corrected to describe **reality**: the
  backlog row names `plans/` + GitHub issues, and a **second row declares
  `plans/FRAMEWORK-TODO.md` as a legacy queue that is still live**. Asserting
  "GitHub issues are the backlog" over a queue of that size would recreate the
  same false declaration, inverted. A governance table describes what *is*.
- That correction falsifies the workspace intake contract, which lists ci's
  capture surface as `plans/` + GitHub issues **"(TODO file declined)"**
  (`operations/docs/AGENT_FEEDBACK_INTAKE.md:73`). The routing it governs is
  unaffected — the legacy queue takes no new entries — but the phrase a session
  acts on is now incomplete. Filed as
  `vladm3105/aidoc-flow-operations#291`.
- The row shape is constrained by canon's own parser, not by taste.
  `install/parse-governance-table.py` reads a row's whole path cell as a path,
  stripping only a trailing `§N`/`#anchor` (`:172`) or a parenthesized
  annotation (`:180`). Measured: the prose row PLAN-022 originally prescribed
  took the parser from `errors: []` to `path-not-found`. Write governance rows
  as `` `path` (annotation) ``.
- **That existence-check has no automated reader.** `governance_check` is
  reached only by a hand-run of `install/apply-standards.sh` (`:433`); nothing
  in `.github/workflows/` invokes it. Filed as `#355`. Until it lands, the
  governance table is enforced by whoever remembers to run the parser — which is
  how the false backlog row survived.
- **No migration ships with this decision.** `plans/FRAMEWORK-TODO.md` is not
  deleted and its ~57 entries are not triaged; that work is deferred visibly as
  `FT-58`, carrying its own open question (where a below-promotion-bar entry
  goes once its queue file is gone). Three review passes on the superset
  returned 12, 9 and 7 findings without converging, and 22 of the 28 landed in
  the migration sections.
- `apply.py`'s edit-mode taxonomy follows from §1 and is **specified, not
  implemented**: changelog → anchored insert *plus a retained volume ceiling*;
  handoff → whole-file regeneration, staying human-reviewed; README/docs/roadmap
  → targeted edit, unchanged. It lands as PLAN-021 Phase 2, after PLAN-021.
  A pure-insertion assert is **not** a straight upgrade over the existing
  400-line ceiling: `apply.py:91` computes changed lines as a per-opcode
  `max(i2 - i1, j2 - j1)`, so the ceiling already bounds insertions while a
  pure-insertion assert bounds only deletions. Keep both. **The insertion
  invariant is scoped to the maintainer path**, because legitimate
  heading-touching changelog edits exist: `scripts/release.sh:212` rewrites the
  Unreleased heading at every cut, and normalising canon's own heading (§1) is
  itself a non-insertion edit. An unconditional invariant would red the release
  path.
- **This decision's own counterexample is still live in this repo.**
  `HANDOFF.md:12-13` states *"`## Unreleased` is empty, and there are 0 open
  issues and 0 open PRs"*; the tracker holds nine
  (`gh issue list --state open --limit 200 | wc -l`) and this change makes
  `## Unreleased` non-empty. It is not corrected here: `HANDOFF.md` would be a
  fourth doc surface and OPS-0061 Rule 1 caps a governance PR at three. It is
  regenerated in the wrap PR that follows this one, under §2's rule — which is
  the first application of that rule to the document that motivated it.

**Origin**

`plans/PLAN-022_doc-surface-governance.md` (PR #356), narrowed from a superset
that also carried the `FRAMEWORK-TODO` migration. Records §1 and §2 of that
plan; §4's taxonomy is recorded here as a contract for PLAN-021 Phase 2, not as
shipped behaviour.

---

## CI-0029: Ruleset `bypass_actors` is scoped by threat model, not by precedent (2026-08-03)

**Context**

FT-52 applied an immutable `ci/v*` **tag** ruleset to canon with **no**
`bypass_actors`, on the reasoning that "immutability with an admin bypass is not
immutability" (`plans/ROLLOUT_ft52-canon-self-governance.md`). PLAN-020 Phase 1
classes a non-empty `bypass_actors` as WEAKENED drift.

PLAN-023 §3c proposes arming a build/test gate as a required check via a
**branch** ruleset, because rulesets are a separate, aggregating surface that
`apply-standards.sh` never touches — so a language-specific required context
placed there survives the tier-template PUT that would clobber it in branch
protection.

That raises a question the tag precedent does not answer. `enforce_admins: false`
is the deliberate break-glass for **branch protection** and has **no effect on a
ruleset**; repository admins are not ruleset bypass actors unless explicitly
listed. This is not inferred — the umbrella already carries a live **active
branch** ruleset (`gh api repos/vladm3105/aidoc-flow/rulesets/17136252`) whose
`bypass_actors` lists RepositoryRole 2, 4 and 5 at `bypass_mode: always`, which
is why `--admin` works there at all.

`--admin` is load-bearing for **one specific, structural case**: FT-21
release-prep PRs are BLOCKED by construction — 4 of 5 required contexts come from
self-pinned callers that `startup_failure` against a tag that does not exist yet,
so they are never reported — and `enforce_admins: false` exists on canon
precisely so `gh pr merge --squash --delete-branch --admin` still works
(`docs/RELEASE_CHECKLIST.md` § "Tag + release"). Arming a ruleset with no bypass
would brick canon's own release process.

**The tension with CI-0021 is real and is accepted rather than papered over.**
CI-0021 decided that an *infrastructure outage* gets a targeted, default-off
break-glass and explicitly **not** `--admin`, on the reasoning that "`--admin`
bypasses **every** required check, not just the broken one" and "once the bypass
is routine, nobody reads the gate." This entry grants a standing admin bypass on
one class of ruleset, which cuts against that direction. It is justified only by
the FT-21 case above — a *structural* impossibility, not an outage — and it is
why the bypass is scoped to quality gates and denied to immutability rulesets.

**Decision**

`bypass_actors` is decided **per ruleset by threat model**, and the FT-52
precedent is explicitly **not** generalised:

- **Immutability rulesets** (tag protection): **no** `bypass_actors`. The threat
  is a force-moved tag reaching every consumer on its next run; an admin escape
  defeats the entire control. FT-52 stands unchanged.
- **Quality-gate rulesets** (the PLAN-023 build/test gate, and any future
  required check of that class): `bypass_actors` includes the repository **admin**
  role. The exact payload, verified against the live API by the 2026-08-03 probe
  (created on private `aidoc-flow-business`, read back unchanged, deleted):

  ```json
  "bypass_actors": [
    { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" }
  ]
  ```

  **This is parity with `enforce_admins: false` only where that is set — which is
  not fleet-wide.** Measured 2026-08-03: only
  `install/templates/branch-protection-umbrella.json` sets `false`; `-ops`,
  `-product`, `-governance` and `-bootstrap` all set `true`, and live
  `aidoc-flow-operations` and `iplan-runner` are `true`. On an
  `enforce_admins: true` repo the ruleset bypass is **inert** — branch protection
  and rulesets aggregate and the stricter wins, so the admin stays blocked. The
  arming applier must not assume otherwise.

**Consequences**

- Arming M4 changes *what is required*, not *who can break glass* — one variable
  at a time, which is the property wanted when introducing a required gate.
- PLAN-020's WEAKENED-drift rule must distinguish the two classes, or it will
  report every correctly-configured quality gate as drift. Recorded here as a
  constraint on that plan.
- A quality gate armed this way is **no stronger than today's branch protection**
  against an admin. That is accepted: its purpose is to make the check *reach the
  right repos* (the tier-static problem), not to bind admins.
- Anyone reading the tag ruleset in isolation will infer a blanket no-bypass
  rule. This entry exists so that inference is corrected at the source.

**Origin**

`plans/PLAN-023_build-test-canon-and-conformance.md` §3c, and the first item of
that plan's Review log Pass 6 "Open — carried" list (`bypass_actors`
unspecified). Note the `--admin`/ruleset interaction is reasoned here, not in the
plan: it follows from GitHub's ruleset bypass model and is corroborated by the
umbrella's live ruleset above; the 2026-08-03 probe validated the **bypass
shape**, not the `--admin` merge path. Founder decision 2026-08-03.

---

## CI-0030: Migrate the workspace to a GitHub Organization, ahead of the CD subsystems (2026-08-03)

**Context**

`vladm3105` is a personal **User** account with no organizations (verified
2026-08-03: `gh api user --jq .type`; `gh api user/orgs` empty; custom repository
properties return **404**, being org-only). Every workspace repo is user-owned.

Three separate lines of work converged on this as a **sequencing argument** —
not a binding constraint. Nothing is blocked: PLAN-023 ships fully on the current
account. The case is that the migration gets more expensive with every repo, tag
and pin, and it unlocks native mechanisms this workspace is currently hand-building:

- **PLAN-023 X2** invents a language axis because canon has only a tier axis.
  Org **custom properties** are the native home for both, and org-level rulesets
  can target repos dynamically by them (`visibility:private -language:java`),
  replacing nine per-repo rulesets with one.
- **PLAN-023 §7a** needs cross-repo read for its conformance report and has no
  credential; **org secrets** (or an org-installed App) is the answer that does
  not require a standing user PAT.
- **`ASSESSMENT_flow-ci-value-and-standard-readiness.md`** scores "bus factor ≥2"
  and "shared infra, not per-team" 🔴. An org addresses the **structural half** of
  each — teams and org-owned repos for the first, org secrets and runner groups
  for the second. It does **not** address what that assessment actually names as
  the fixes (cut complexity or add a maintainer; provision the LiteLLM proxy,
  runner pools and reviewer App as platform services; decouple governance;
  resolve FT-15; prove on ≥3 teams). Those remain separate work.

**What this does NOT unlock — stated because an earlier draft of this entry got
it wrong.** `composition.yml` exists because a GitHub **App** cannot be a
CODEOWNER, and an org does **not** fix that: Apps cannot be org team members
either, so teams-as-CODEOWNERS applies to *humans* only. The reviewer App still
cannot be a CODEOWNER after migration, `composition.yml` remains the sole
identity enforcement, and it is **not** retired or made retirable by this
decision. Removing it stays a governance change (`.github/workflows/composition.yml`).

**Decision**

Migrate to a GitHub Organization, sequenced **before** the CD subsystems
(S4 release, S5 publish, S6 container, S7 deploy), and executed under its **own
plan** — not as a dependency of PLAN-023, which ships fully on the current
account.

**Consequences**

- **Priced, not assumed:** **64 non-markdown canon files** hardcode `vladm3105`
  — `grep -rIl vladm3105 --include='*.yml' --include='*.yaml' --include='*.sh'
  --include='*.py' --include='*.json'` (2026-08-03; the unscoped repo-wide count
  is 114, the difference being plans and docs). Including `docs-sync.yml` fetching from
  `raw.githubusercontent.com/vladm3105/aidoc-flow-ci/...`, and FT-15's fix
  deliberately hardcodes the canon owner (§4.2a). Migration is therefore a canon
  change **plus a fleet re-pin**, not a transfer alone.
- The cost grows with every repo, tag and consumer pin — which is the argument
  for doing it before S4–S7 multiply the surface, not after.
- The opt-in default owed by **CI-0031** — *reserved by
  `plans/PLAN-023_build-test-canon-and-conformance.md` PR-0, not yet written; IDs
  are never reused* — is revisitable once an org-level enforcement point exists;
  OpenSSF's opt-out guidance presumes one.
- Requires GitHub Team or above for org-level rulesets **on private repos**
  (org rulesets targeting public repos are available on Free orgs). Vendor plan
  tiers rot — re-verify at migration time.
- Until it lands, PLAN-023 ships `--fleet` implemented but unwired, and M4 is
  armed per-repo.

**Origin**

Best-practices investigation 2026-08-03 (GitHub org rulesets + custom
properties; OpenSSF Allstar's org-level model), recorded in
`plans/PLAN-023_build-test-canon-and-conformance.md` §15. Founder decision
2026-08-03.

---

## CI-0032: A coordination surface with N writers needs a carrier that refuses a concurrent write (2026-08-05)

**Context**

Every coordination mechanism canon specifies was designed for one agent per repo
at a time. Fleets of independent agents — Claude Code sessions, Codex, DeepSeek —
now run against one repository with no orchestrator and no shared context. Each
mechanism is a shared mutable resource with no lock: correct for one writer,
silently wrong for N.

The sharp instance is the session handoff. "Close the current handoff issue and
open its successor" is a compare-and-swap with nothing between the read and the
write. With N agents, each closes whatever it found and creates its own, so the
losing sessions' handoffs become **unfindable rather than deleted** — and both
agents report success, because both did what they were told.

**Status across the workspace: latent, not observed.** Wraps have been serial so
far. This is decided before the first collision deliberately, because after one
the evidence is an intact, unreferenced artifact that looks like nothing
happened.

**Decision**

`REPO_STANDARDS` §25. Choose a coordination carrier by how it behaves under a
concurrent write, not by convenience:

- **Issue body** — last write wins silently → the state of that one issue, one
  claimant.
- **Issue comments** — append-only, every write survives → per-session log, safe
  for N writers.
- **A git file** — *refuses* the write (non-fast-forward or merge conflict) →
  repo-wide state.

Git is the only one of the three that fails a concurrent write rather than
taking the last, and that refusal — not the file format — is why repo-wide state
lives in a file.

**This decides no repo's handoff surface.** §16 governs that, via each repo's
declared governance table, and §16 states nothing about files versus issues — it
requires presence, declaration and consistency, and §16.4's parser only verifies
that a declared path exists. `aidoc-flow-ci` declares the file form and CI-0028
decides how that file is *edited* (regenerated wholesale), not whether it is a
file. That the file form happens to have no compare-and-swap to lose is a
property of the choice, not the reason it was made.

Plus: **claim before starting** (assignee and/or `status:in-progress`, §5.4), and
**one `git worktree` per issue** on a branch named for it.

**Alternatives rejected for the worktree rule.** Separate clones lose the shared
object store, so integration becomes a remote round-trip instead of a local
`git merge`. Sandboxes bound blast radius but do not give a second index, so two
agents still contend on `.git/index.lock` — they are complementary, not a
substitute. A worktree is the only option that gives each agent its own `HEAD`
and index while keeping one object store.

**Two proposals in the source issue are DECLINED, not deferred**, so they are not
re-proposed as oversights:

- **`flock`-serialized deploy/verify.** The reasoning is sound — `flock` releases
  on process death where an issue-based lock cannot. But **no repo that canon
  governs deploys a running service from a shell.** The 2026-08-05 sweep of the
  nine non-paused repos (CI-0001's roster; `.gitmodules` lists eleven, of which
  `feedback-desk` and `logging` are out of scope) found only `install/deploy-ci-wizard.sh` (a founder-executed CI installer),
  `scripts/release.sh` (tag cut), and a runbook plus a post-deploy smoke test in
  `framework`/`iplanic` — none a singleton runtime that concurrent execution
  corrupts. `flock` appears nowhere in this repo. (§23 is **not** the counter-
  argument and is not cited as one: it is a *cancellation* policy — which events
  may cancel an in-flight required gate — and mandates mutual exclusion for
  nothing.) A canon rule whose subject no consumer has is untested and
  unenforceable; it belongs in the docs of a repo that deploys from a shell.
- **Making `CLAUDE.md` a symlink to `AGENTS.md`.** The problem is real —
  conventions in `CLAUDE.md` and Claude-only skills are never seen by Codex or
  DeepSeek. But `AGENTS.md` exists in **2 of the 9** non-paused repos and is a
  **symlink in neither** — and the two do not agree on a direction, so there is
  no single convention for a symlink to codify:

  - `aidoc-flow-framework` — a short orientation pointing at the long file:
    "`CLAUDE.md` is the full working agreement; this file is the short
    orientation… Where the two disagree, `CLAUDE.md` wins" (87 lines vs 1,029).
  - `engramory` — **co-equal and split by topic**, pointing the other way:
    `CLAUDE.md` says "For engineering conventions… see **AGENTS.md** — this file
    records only what's specific to Engramory as an aidoc-flow workspace repo…
    **Both files apply**", and `AGENTS.md` is a declared §16 surface in its own
    right (`| Engineering agreement | AGENTS.md |`). 41 lines vs 218.

  An earlier draft of this entry read both as the framework shape and called it a
  2-of-2 convergence. It is not, and the corrected reading does not rescue the
  symlink: it makes the case weaker, because there is no agreed direction to
  invert. What decides it is mechanical — a symlink changes what §16's governance
  table and `parse-governance-table.py` parse, and degrades to a text stub on
  Windows without `core.symlinks`.

**Consequences**

- §25 is a **no-op for a single writer** — every rule is already satisfied when
  one agent works one repo, and none of it adds a step to that case.
- **The shared-tree hazard is measured here, but the worktree rule is not what
  fixes the measured case.** PR #277 shipped without the code it was written to
  add — its diff carries only `CHANGELOG.md`, `HANDOFF.md` and
  `plans/FRAMEWORK-TODO.md`; the code landed in #278, whose title is "land the
  FT-45 code that PR #277 dropped" and whose body names the mechanism
  contemporaneously: the review sub-agents ran `git stash` / `git add` on the
  shared tree between the `git add` and the `git commit`. Those racers were a
  session and **its own sub-agents**, which share the parent's tree by
  construction — a per-issue worktree gives them the same tree and would not have
  helped. The remedy for that case is `CLAUDE.md`'s durable trap (`git add -A`
  and re-diff after the agents finish). §25.4 separates agents from *each other*;
  both rules are needed, and §25.4 says so.
- These repos are submodules: a worktree lives outside the umbrella's tree, so
  the umbrella pointer bump must still be made from the primary checkout.
- **The `AGENTS.md` reachability problem is unresolved by this entry.** Declining
  the symlink does not address it; making the short vendor-neutral orientation
  file a required §16 surface across all nine repos is the version worth doing,
  and it is [#395](https://github.com/vladm3105/aidoc-flow-ci/issues/395).
- Reopening either decline needs **new evidence** — a repo that actually deploys
  from a shell, or a vendor that reads neither file — not a re-reading.

**Origin**

Issue [#387](https://github.com/vladm3105/aidoc-flow-ci/issues/387), filed from
`vladm3105/llm-router` at the founder's direction. Labels in §5.4
([#386](https://github.com/vladm3105/aidoc-flow-ci/issues/386), CI-0032's
prerequisite). **CI-0031 is deliberately skipped** — it is reserved by PLAN-023
PR-0, which already cites it in three places; per the ordering rule at the top of
this file it is filled in place when that plan lands.

---

## CI-0033: A gate must not decide on the exit status of a pipeline into `grep -q` (2026-08-08)

**Context**

`call / verify` — the required OPS-0069 audit-trail context — failed PR #416
with `no OPS-0069 phrase found in any commit in the PR range`. The phrase was
present twice in the range, `pre_push_check.sh` exited 0 on the same two SHAs,
and the failure was deterministic across reruns. Issue #417 verified every input
the check reads (base SHA, head SHA, commit count, bot exemption, labels) and
could not account for it; it explicitly tested and **ruled out** the SIGPIPE
mechanism.

The runner log settles it. Immediately before the error:

```text
line 103: echo: write error: Broken pipe
```

Line 103 of the generated step script is `if echo "$push_msgs" | grep -qF
"$phrase"; then`. `grep -q` exited on matching at byte 703; `echo` was still
writing the 38,744-byte range and took `EPIPE`; `set -o pipefail` handed the
pipeline that 141. **The grep matched and the gate recorded a miss.**

The reason it survived its review (`e827ab8`, 2026-07-07, PLAN-002 PR-U3 #64,
whose commit message records `code-reviewer + security-auditor`) and then a
dedicated investigation a month later is that
the inversion is **size-dependent**. Measured on the dev host: 0/200 false
negatives at the real 38 KB payload, 50/50 at 256 KB and above. The runner's
threshold is lower. A local reproduction at the real size therefore returns a
clean negative and proves nothing.

Same shape, same file, on the escape hatch the error message recommends: the
`[skip-audit-trail]` body-marker probe was its own `git log … | grep -qF`, so
the two-signal override inverted at the same sizes the gate did. `assert_absent`
in `tests/lib.sh` inverts to a **silent pass**, i.e. lost coverage with no red.

**Decision**

1. **A pipeline whose exit status is a decision must decide on captured output,
   or not be a pipeline.** For substring tests, bash `case` — no fork, no status
   to invert, `grep -F` semantics from the quoted expansion.
2. Applied to all four OPS-0069 surfaces: `audit-trail-check.yml` (three sites),
   `scripts/pre_push_check.sh`, `install/templates/pre_push_check.sh`,
   `tests/lib.sh`. The range is now materialised once and every probe reads that
   one string.
3. `grep -q` reading a file stays legal — no writer, no signal. The banned
   construct is an early-exiting reader on the RIGHT of a pipe: `grep -q`,
   `grep --quiet`, `grep -m<N>`, and by the same mechanism `head -N` and
   `sed …q`. The guard's regex covers the `grep` family; `head`/`sed` are named
   here because `| head -1` for DISPLAY is legitimate and must not be banned
   wholesale — what matters is whether a DECISION reads the pipeline's status,
   or whether `set -e` can kill the step before the diagnostic it precedes.
4. Enforced by `tests/test_sigpipe_guard.sh`: the shipped `run:` block is
   extracted and executed against a 4 MB commit range, plus a structural ban
   that **globs the scope §27.2 declares** — 33 files, not a hand-written list.
   Mutation-tested against that test: reverting the phrase loop reds 4
   assertions, the no-jq fallback 2, all four OPS-0069 surfaces 9, and running
   it against the whole pre-fix tree reds 15.

**Consequences**

- **No consumer is fixed by this until the next tag.** Callers pin
  `audit-trail-check.yml@ci/v<tag>`, so every repo runs the defective copy until
  `ci/v2.17.0`/`ci/v3.0.0` ships. PR #416 stays `--admin`-only.
- The blast radius is every OPS-0069 gate in the workspace, and it grows with PR
  size — large PRs are exactly where the review evidence matters most.
- No exemption was consumed. The two-signal override was **not** used on #416;
  it would have hidden the defect, and it was inverted too.
- **The ban is construct-based, so it indicted sites well beyond the reported
  one, and those were converted here rather than deferred.** Eleven further
  decisions across `ai-review.yml`, `composition.yml`, `secret-scan.yml`,
  `ft30-dry-run.sh`, `release.sh` and `sync-version-refs.sh`. **Every one of them
  fails OPEN when it inverts** — one measured (`git diff --raw`, 4/5 at 401
  staged files), the rest latent, their writer being a `printf` builtin that
  cannot invert at its current size. The reported instance is the only one that
  failed CLOSED, and it is the only one anybody noticed. That asymmetry is the finding: a gate that
  wrongly reds gets diagnosed in a day; a guard that wrongly greens does not get
  diagnosed at all.
- The sharpest was `ai-review.yml`'s autofix symlink-escape guard (PLAN-012
  §4.4), measured missing the symlink 5/5 at 400 staged files. Filed as
  [#418](https://github.com/vladm3105/aidoc-flow-ci/issues/418) when the scope
  looked separable, then folded in once review established it was the same
  defect inside the scope §27.2 declares mandatory; **#418 closes with this
  change.**
- **The guard globs the declared scope instead of listing files.** The first
  draft guarded four hand-listed files while §27.2 declared four directories —
  which is precisely how these sites stayed invisible. A guard narrower than its
  rule reports a compliance that does not exist.

**Origin**

Issue [#417](https://github.com/vladm3105/aidoc-flow-ci/issues/417), from the
`call / verify` failure on PR #416 (run 31279465250, 2026-08-08). Rulebook:
`docs/REPO_STANDARDS.md` §27. The general trap was already recorded in
`CLAUDE.md` § "Bash, where the fix quietly creates the next bug"; what is new is
that it reached a required gate and that a correct-looking local test cannot
detect it.

## CI-0034: A defense inventory records intent; only an assertion records the defense (2026-08-09)

**Context**

A five-lens pre-prod review of the v3 surface at `c0e50c1` returned five
blocking defects. Three of them were defenses that `PLAN-025 §2` explicitly
records as **carried**, and that source showed were not:

- **D35** — all three v2 SARIF uploads carry a fork clause on the upload step
  (`dep-scan.yml:138`, `trivy-scan.yml:114`, `sast-scan.yml:169`). All three v3
  uploads shipped without it, leaving the job-level `if:` as the only barrier to
  three steps holding `security-events: write`. §2 says "All 27 CARRIED. None
  dropped." Restoring the clause exposed a second defect **in the v2 spelling
  itself**: `head.repo.fork != true` is null-permissive, and a deleted fork on a
  `reopened` event gives a null `head.repo`. Both guards are now identity tests
  against `github.repository`, which fails closed on null. `fork == false` would
  not have worked — GitHub coerces null and false alike to 0.
- **D11** — the pre-commit precondition guard read `RUN_STAGE`, declared only on
  a later step. Composite steps do not share `env:`, so it validated a stage the
  run would not use. §8 blocker 8 records it "verified against the reproduced
  manual-only config"; that verification ran with `run-stage` unset, where the
  default and the hardcoded value coincide and the defect is invisible.
- **D42** — `links-external`'s report step could not fire. `fail-on-error:
  'false'` makes the action exit 0 for every lychee result short of a timeout,
  pinning `steps.links.outcome` to `success`. The file's own header says "A
  REPORT-ONLY JOB WITH NO REPORT IS NOT A CHECK".

The pattern is not carelessness. Each was ported correctly *as a body* and lost
its defense *at the seam* — the caller-side `if:`, the step-scoped `env:`, the
input pairing. §1 makes the port verbatim precisely to avoid rewrite risk, and
the residue is that what is NOT in the body is what goes missing.

**Decision**

1. **A row in a defense inventory is a claim about intent. It is not evidence,
   and a review must not treat it as one.** Where §2 says "carried", the
   question to ask of source is "carried *where*" — a defense expressed in a
   caller, a step's `env:` scope, or the pairing of two inputs does not travel
   with the body it belonged to.
2. **Every carried defense gets an assertion that fails when it is removed**,
   and the assertion is written against the seam, not the body. Added here:
   SARIF uploads looped for their own fork clause; a general check that no
   composite step reads an env var its own step never declared; the links
   token/mode biconditional; the ubuntu-latest-caller/private-variant
   biconditional.
3. **Prefer the general form.** Three of the five would have been caught by a
   check of the *class* rather than the instance — which is why the env check
   scans all six actions rather than asserting `RUN_STAGE` in one place.
4. **Consolidation raises the cost of every missing seam.** In v2 each check was
   its own job with its own `permissions`, its own guard, its own context. v3
   puts three in one job, so a dropped guard has no sibling behind it and one
   scanner that cannot install reds two that can (`#349`).

**Consequences**

- Five defects fixed before any consumer could see them, none of which the
  suite, the plan, or three prior author passes had surfaced.
- **Three of the FIXES broke before they held, each caught only by executing
  them** — the SARIF purge's `rm -f` aborting under `set -e` on a directory
  survivor with no `::error::`; the private-variant check reading the manifest's
  claim about a file instead of the file; the step-order assertion matching a
  header comment rather than an invocation. This is the same shape as CI-0033's
  fold and reinforces it: **a fix inherits the defect class it fixes.**
- The purge, the D11 guard and `release.sh`'s marker retirement are now
  **executed** by the suite against real fixtures, not merely parsed. Every
  structural assertion passed against the broken first drafts.
- This does not retire `PLAN-025 §2`. The inventory is still how the port is
  planned; it is no longer how the port is verified.

---

## CI-0035: PR-C's `CHANGELOG.md` deviation is CONFIRMED — demote, do not de-allowlist (2026-08-10)

**Context**

`PLAN-021 §4` PR-C point 1 specified dropping `CHANGELOG.md` from **both**
`allowed_paths` and `auto_merge.low_risk_paths`. What shipped in #405 dropped it
from `low_risk_paths` only, added it to `high_risk_paths`, and left it
allowlisted. The plan flagged the divergence, recorded *"the founder has not been
re-asked"*, and asked for confirmation before the next tag.

**Decision**

**The shipped shape is confirmed. Do not restore the de-allowlisting.** Founder,
2026-08-10.

The reasoning is measured, not argued. Driven against the shipped planner with a
stub proposing `CHANGELOG.md`:

| Config | Result |
| --- | --- |
| de-allowlisted | `::error::` + **exit 1** — a run-killing `return 1` |
| demoted to high-risk | **exit 0**, `high_risk_set: [CHANGELOG.md]` — an issue body a human acts on |

De-allowlisting does not remove the red run, it **relocates** it. The path is
still proposed — the inventory is an unfiltered `rglob("*.md")` until PR-D lands,
and `install/templates/doc-maintainer-conventions.md` instructs the model to use
`CHANGELOG.md`. On the only population half 1 reaches (new adopters, since
`safe_to_replace: false`), point 1 as written ships a config whose first
changelog-touching merge reds from day one, at any file size.

**Consequences**

- The 🔴 blocker "PR-C deviation confirmation" is **closed**. It gated
  `ci/v2.17.0` and carried forward to `ci/v3.0.0`; neither is gated by it now.
- `PLAN-021 §9` item 2's *"PR-C ships as specified, both halves"* is **superseded
  on point 1 only** by this entry. Its "as specified" predates the reproduction.
- Two other places in PLAN-021 already reached this conclusion (§4's analysis of
  `operations`, §1 correction (b)); three independent pre-push reviewers
  converged on it, two with reproductions. This entry is the record that was
  missing, not a new position.

---

## CI-0036: OPS-0066 waived for PLAN-025 — the v3 tag rests on the CODE review (2026-08-10)

**Context**

`PLAN-025 §8` recorded the OPS-0066 three-pass cap as spent and offered two ways
forward: a founder waiver, or *"better — a fresh plan for the remaining phases,
reviewed on its own budget."*

**The fresh-plan route was attempted and did not converge.** PLAN-026 took three
independent passes (10 load-bearing findings, then 5, **two of them introduced by
the intervening fold**), ended with one open item, and spent its own cap. Its
Pass-3 fold has had no re-review.

**Decision**

**Waived. The `ci/v3.0.0` tag rests on the review the CODE received, not on
PLAN-025 converging.** Founder, 2026-08-10.

The distinction is the substance: the merged v3 surface had a five-lens
independent pre-prod review this session (5 blockers, all fixed), plus two
independent OPS-0065 reviews of the fixes. A plan that has not converged and code
that has been reviewed are different claims, and the tag depends on the second.

**Consequences**

- The 🔴 blocker "PLAN-025 unreviewed since Pass 4" is **closed**.
- **This waiver is a judgement about an acceptable rate, not a claim the concern
  was wrong.** §8's stated worry was *"every pass has still found something a
  consumer would have felt"* — and that held again: the pre-prod review found
  five blockers, three of them defenses §2 records as *carried*. The waiver
  accepts that finding rate as tolerable at the tag, with the migration sequence
  and rollback as the containment.
- **PLAN-026 stays NOT READY and is not a release gate.** Its remaining phases
  (P4/P5/P7/P9) are work against the tag, not preconditions for it. Its one open
  item is resolved in code by PR #441, which merges at the cut.
- **PR-C's confirmation (CI-0035) closed in the same session**, so the founder
  gates remaining before a tag are the FT-30 cold-start dry run and the timed
  merge of #441.

---

<!-- Append new entries above this line (or into a previously reserved ID
slot — see the ordering rule at the top); append-only. Never rewrite
history; if a decision is reversed, add a NEW entry citing the reversal
and update the superseded entry's "Consequences" section to reference
the reversal ID. -->
