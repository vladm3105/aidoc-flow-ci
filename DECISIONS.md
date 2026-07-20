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
exists on disk (or the cell is a valid "Not adopted — <rationale>"
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
  + surface.
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
  + this entry are annotated (append-only).

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

## CI-0011: `verified_allowed` supply-chain boundary — OPEN (founder decision)

**Status: OPEN — awaiting founder decision. Do not treat as decided.**

**Context**

`install/templates/actions-permissions.json` sets `verified_allowed: true` (and
`github_owned_allowed: true`) alongside the three-pattern `patterns_allowed`
(`vladm3105/aidoc-flow-ci/*`, `actions/*`, `github/*`). So the DEPLOYED
allowlist admits **any GitHub-verified creator's action** (`aquasecurity`,
`docker`, `hashicorp`, …) on every consumer, not just the three patterns.
`REPO_STANDARDS.md` §4.3 now documents this accurately and flags widening to the
verified marketplace as "a decision to take deliberately" — but that decision
was never recorded, so code and policy have drifted apart by default, not by
choice.

**The decision (founder):**

- **Keep `verified_allowed: true`** — accept that any verified-creator action can
  run on consumer runners (incl. the private self-hosted pool) as an intentional
  convenience; OR
- **Drop it** — narrow the deployed boundary to the three patterns. Expect
  verified actions currently relied upon (e.g. `aquasecurity/trivy-action` if any
  consumer still calls it) to then `startup_failure`; canon reusables already
  install tools as binaries, so canon itself is unaffected.

**Related note (not itself a decision):** `actions-permissions.json` also sets
`workflow.can_approve_pull_request_reviews: true`. This is defanged here — the
`composition` gate counts ONLY the reviewer App's numeric bot-id + `type==Bot`,
never `github-actions[bot]` — so an Actions-minted approval does not satisfy the
merge gate. Fold confirmation of this into whichever way CI-0011 resolves.

**Origin**

PLAN-015 M1 (pre-prod review security lens #2). Filed as an open decision;
resolve before treating the supply-chain boundary as settled.

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

**Origin**

`plans/PLAN-016_runner-canon-templates.md` (17-citation Claim ledger; 7
independent verified-planning-reviewer passes; two founder-authorized cap
extensions). Supersedes the runners.md §2 "this is aidoc-flow-operations
infrastructure" framing; OPS-0075's contract (labels, single-use, hardening,
LiteLLM) is unchanged and remains authoritative in operations.

---

<!-- Append new entries above this line; append-only. Never rewrite
history; if a decision is reversed, add a NEW entry citing the reversal
and update the superseded entry's "Consequences" section to reference
the reversal ID. -->
