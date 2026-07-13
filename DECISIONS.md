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
`LITELLM_BASE_URL` and a scoped `LITELLM_API_KEY`. Workflows select only a
LiteLLM model alias. Provider credentials, provider/model routing, fallback,
budgets, and retries beyond the bounded transport retry remain proxy policy.
Vendor CLIs and their credentials are no longer part of the CI contract.

The GitHub reviewer App remains separate: LiteLLM produces the judgment, while
the App supplies the GitHub identity that submits a counting review. Trust
gating, governance floors, and composition enforcement are unchanged.

**Consequences**

- `litellm.model` supersedes CI-0005's `.reviewer` engine selector.
- `ai-review` and `doc-maintainer` share a dependency-free HTTP adapter.
- Missing proxy configuration, network errors, and invalid output fail closed.
- Removing vendor-specific workflow inputs is a breaking `ci/v2.0.0` change.

**Origin**

Founder direction to use LiteLLM for all AI agents, including ai-review and
doc-maintainer, 2026-07-12.

---

<!-- Append new entries above this line; append-only. Never rewrite
history; if a decision is reversed, add a NEW entry citing the reversal
and update the superseded entry's "Consequences" section to reference
the reversal ID. -->
