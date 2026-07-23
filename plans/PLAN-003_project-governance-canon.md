# PLAN-003 — Project governance file canon + unified CLAUDE.md template

**Status:** SHIPPED — 2026-07-08 (canon + parser + ratification landed via PR-V1/V2/V3/V4; per-repo Waves 1-5 pending)
**Depends on:** PLAN-002 (workspace standards rollout) — canon already ships
`REPO_STANDARDS.md` §§1–14 + `apply-standards.sh --check` machinery this
plan extends.
**Origin:** founder direction 2026-07-08 after workspace audit showed governance
files (HANDOFF / DECISIONS / ROADMAP / TODO / plans) at 4 different paths across
9 non-paused repos, with 4 repos missing 2 or more of them entirely.

## 1. Purpose

Close the workspace-wide gap PLAN-002 didn't address: PLAN-002 unified the
**CI + governance-workflow surfaces** (CODEOWNERS, dependabot, pre-push hook,
audit-trail-check reusable, etc.); this plan unifies the **project-level
tracking artifacts** every repo needs for cross-session continuity + AI-agent
discoverability:

- CHANGELOG (release history)
- ROADMAP (forward plan)
- HANDOFF (live cross-session resume point)
- DECISIONS (ISO-stamped decision log)
- plans/ (per-initiative plans + TODO backlog)

Plus a **canonical CLAUDE.md template** so an AI agent entering any workspace
repo finds:

- A standardized "Where governance files live" table (per §16 canon).
- Standardized workspace-standard sections (OPS-0061, OPS-0062, OPS-0065,
  OPS-0067, OPS-0069) referencing the operations canonical rules rather
  than duplicating.

## 2. Current-state audit (2026-07-08 — re-verified)

Governance-file matrix across 9 non-paused repos (paths verified by
`find` against each repo's working tree 2026-07-08):

| Repo | CHANGELOG | ROADMAP | HANDOFF | DECISIONS | plans/ | TODO |
| --- | --- | --- | --- | --- | --- | --- |
| `aidoc-flow-ci` | `CHANGELOG.md` | **—** | **—** | **—** | `plans/` | **—** |
| `aidoc-flow-operations` | `CHANGELOG.md` | `docs/ROADMAP.md` | `ops/HANDOFF.md` | `ops/DECISIONS.md` | `ops/iplans/` | **—** (backlog in IPLANs) |
| `aidoc-flow-business` | **—** (policy) | **—** (policy — `docs/STARTUP_STRATEGY.md` §8 serves) | `docs/SESSION_HANDOFF.md` | `docs/DECISIONS.md` | **—** | `docs/TODO.md` |
| `aidoc-flow-framework` | `CHANGELOG.md` + `platforms/hermes/CHANGELOG.md` + `platforms/claude-code-plugin/CHANGELOG.md` (per-package) | `ROADMAP.md` | `plans/HANDOFF.md` | `plans/DECISIONS.md` (repo-lifecycle) + `framework/governance/DECISIONS.md` (nested; spec governance) | `plans/` | `plans/FRAMEWORK-TODO.md` |
| `aidoc-flow-iplanic` | `CHANGELOG.md` | `ROADMAP.md` | `docs/HANDOFF.md` | `docs/DECISIONS.md` | `plans/` | **—** |
| `iplan-runner` | `CHANGELOG.md` | `ROADMAP.md` | `plans/HANDOFF.md` | `plans/DECISIONS.md` | `plans/` | `TODO.md` (root) |
| `aidoc-flow-iplan-standard` | `CHANGELOG.md` | **—** | **—** | **—** | **—** | **—** |
| `aidoc-flow-engramory` | `CHANGELOG.md` | `docs/ROADMAP.md` (older, thinner) + `roadmap/ROADMAP.md` (larger, newer — canonical) | **—** | **—** | **—** | `TODO.md` (root) + stray `tmp/TODO.md` (to clean) |
| `aidoc-flow-interlog` | `CHANGELOG.md` | `ROADMAP.md` | `HANDOFF.md` | **—** | `plans/` | **—** |

**Paused** (`aidoc-flow-knowledge-rag`, `aidoc-flow-site`) — skip per founder
direction 2026-07-04.

**Findings:**

- Same file kind at 4+ different paths across repos:
  - HANDOFF at `ops/` (operations), `plans/` (framework, iplan-runner),
    `docs/` (iplanic), root (interlog).
  - DECISIONS at `ops/` (operations), `plans/` (framework, iplan-runner),
    `docs/` (business, iplanic), `framework/governance/` (framework — nested dual).
  - ROADMAP at root (framework, iplanic, iplan-runner, interlog),
    `docs/` (operations, engramory).
  - plans dir at `plans/` (most), `ops/iplans/` (operations), absent
    (business, iplan-standard, engramory).
- **Repos missing HANDOFF** (3): aidoc-flow-ci, iplan-standard,
  engramory. iplanic HAS one at `docs/HANDOFF.md` (P2 H1 correction).
  Business HAS one at `docs/SESSION_HANDOFF.md` (P4 F#1 correction —
  non-canonical filename, permitted under Option B).
- **Repos missing DECISIONS** (3): aidoc-flow-ci, iplan-standard,
  engramory. Interlog has NONE at present but scope is limited (see
  Wave 4 in §5.5 for the "Not adopted — logging-hub embedded" decision).
- **Repos missing ROADMAP** (2): aidoc-flow-ci, iplan-standard.
  Business declines by policy (STARTUP_STRATEGY §8 serves).
- **Repos missing plans/ dir** (3): business, iplan-standard,
  engramory.
- **`aidoc-flow-iplan-standard` has ONLY CHANGELOG** — biggest gap;
  no ROADMAP, HANDOFF, DECISIONS, or plans dir.
- **`aidoc-flow-business` deliberately declines CHANGELOG + ROADMAP**
  (policy stated in its `CLAUDE.md`); has `docs/SESSION_HANDOFF.md` +
  `docs/DECISIONS.md` + `docs/TODO.md`. plans/ dir absent.
- **`aidoc-flow-engramory` missing HANDOFF + DECISIONS + plans/**; has
  `TODO.md` at root from prior session PR AND stray `tmp/TODO.md`
  (transient; PLAN-003 rollout must NOT preserve `tmp/` — per memory
  rule "Never in tmp/"). Has DUAL ROADMAP: `docs/ROADMAP.md` (older,
  1.4KB) alongside `roadmap/ROADMAP.md` (newer, 5.6KB — canonical);
  Wave 3 must consolidate (see §5.5).
- **`aidoc-flow-framework` has DUAL DECISIONS** at `plans/DECISIONS.md`
  (repo-lifecycle) + nested `framework/governance/DECISIONS.md` (product
  spec governance). Intentional per framework CLAUDE.md; canon must
  permit dual-decision declarations via the §4.2 additional-row pattern.
- **`aidoc-flow-framework` has 3 CHANGELOGs** (root + `platforms/hermes/` +
  `platforms/claude-code-plugin/`) — per-package changelogs are
  intentional (Hermes + plugin ship independently versioned); canon
  must permit multi-CHANGELOG declarations.
- No canonical CLAUDE.md template — every repo hand-authors sections
  duplicating operations' rules; drift over time.

## 3. Non-goals (v1)

- Do NOT force path migration on repos that already have files at
  intentional non-root paths (operations `ops/HANDOFF.md` is documented
  in its `CLAUDE.md`; framework `plans/HANDOFF.md` matches its
  `framework/` vs `platforms/` split). Path variance is preserved;
  presence + declaration is enforced.
- Do NOT touch paused repos (`knowledge-rag`, `site`).
- Do NOT centralize governance files in the `aidoc-flow` umbrella —
  umbrella holds no dev per memory rule.
- Do NOT retrofit historical activity into new files (a fresh HANDOFF
  on iplan-standard starts empty; not a reconstruction of past work).
- Do NOT block business's deliberate CHANGELOG-decline; the canon
  permits explicit omission with rationale in CLAUDE.md.

## 4. Design constraints

### 4.1 Flexible canonical shape (per Option B — founder direction)

Canon does NOT dictate ONE path per file kind. Each repo picks + declares
its own paths in `CLAUDE.md`. Canon enforces:

1. **Presence** — every non-paused non-bootstrap repo has all 5 file
   kinds present (or intentionally omitted with a rationale line in
   `CLAUDE.md` per §4.4 below).
2. **Declaration** — each repo's `CLAUDE.md` contains a standardized
   `## Per-repo governance` section with a table declaring where each
   file kind lives.
3. **Consistency** — `apply-standards.sh --check` verifies that the
   declared paths in `CLAUDE.md` exist on disk.

### 4.2 Canonical CLAUDE.md template shape

Ships as `install/templates/CLAUDE.md.template`. Structure:

```markdown
# CLAUDE.md — <repo-friendly-name>

Persistent context for <repo-purpose-one-liner>. Auto-loaded every session.
Keep it short and current.

## What this repo is

<1-2 paragraph repo-specific description; consumer authors this>

## Where things are

<consumer-specific paths — this section is repo-idiomatic>

## Per-repo governance

The `aidoc-flow` workspace is multi-repo. Each repo governs its own activity
tracking; cross-session continuity is per-repo. Durable surfaces for this
repo:

| Surface | Path (in this repo) |
| --- | --- |
| Live HANDOFF | <path or "Not adopted — rationale"> |
| TODO / backlog | <path or "Not adopted — rationale"> |
| Decisions log | <path or "Not adopted — rationale"> |
| Plans | <path or "Not adopted — rationale"> |
| Changelog | <path or "Not adopted — rationale"> |
| Roadmap | <path or "Not adopted — rationale"> |
| _(repo-specific rows below — same table, optional)_ | |
| <e.g. "Governance decisions"> | <e.g. `governance/DECISIONS.md`> |
| <e.g. "Per-package CHANGELOGs"> | <e.g. `platforms/*/CHANGELOG.md`> |

**Required rows** = the 6 above. **Additional rows** are permitted below
the required set when a repo has multiple surfaces of the same conceptual
kind (framework's nested `framework/governance/DECISIONS.md` alongside
`plans/DECISIONS.md`; framework's per-package `platforms/hermes/CHANGELOG.md`
alongside root `CHANGELOG.md`; engramory's `roadmap/ROADMAP.md` alongside
`docs/ROADMAP.md`; a repo that splits per-team HANDOFF; etc.). The
`--check-governance` mode reads the FULL table, not just the top 6, and
verifies every declared path exists.

**Heading tail is optional.** The H2 anchor `## Per-repo governance`
accepts an em-dash tail such as `— this repo owns its own continuity`
(the form 7 existing consumers already use). See §4.5 anchor regex.
Consumers do NOT need to rename the heading during rollout.

**Row labels are matched by canonical-token substring** — a row labeled
`Plans (IPLANs)`, `Live HANDOFF`, or `Decisions log (append-only)`
counts as the required row without a forced rename. See §4.5 label table.

Never in `tmp/` (transient). Never in the umbrella `aidoc-flow/` (holds no
dev). Cross-repo coordination captured here, references siblings by path
(`../<repo>/`), never relocates their state.

## GitHub operations

Use the GitHub CLI (`gh`) as the default for all GitHub operations — PRs,
issues, reviews, releases, repo queries — not the GitHub MCP servers
(`github-tt`, `github-vl`) or raw API calls. If `gh` is unauthenticated,
run `gh auth login` rather than falling back to MCP/API.

## Workspace standards (aidoc-flow canon — read the canonical rules directly)

Every workspace-standard rule below states (a) a one-sentence summary of
what it says + (b) the canonical file path to READ for the full rule.
Prose "OPS-NNNN" mentions alone do NOT auto-load into Claude Code
context — the file path does. When in doubt, open the linked path.

- **OPS-0061 governance PR discipline** — ≤3 doc surfaces per governance
  PR + mandatory adversarial pre-push self-review on diff.
  → `../aidoc-flow-operations/CLAUDE.md` § "Governance PR discipline".
- **OPS-0062 AI-agent auto-merge default** — auto-watch + auto-merge
  green PRs the AI opens; 10-attempt cap; carve-outs for
  🟡/🔴/governance/cross-repo/spec.
  → `../aidoc-flow-operations/CLAUDE.md` § "AI agent auto-merge default".
- **OPS-0065 multi-agent automated review** — before every push, dispatch
  the diff-class-matched sub-agents in parallel; the canonical diff-class →
  agents table + prompt templates live upstream.
  → `../aidoc-flow-operations/CLAUDE.md` § "Multi-agent automated review"
  + `../aidoc-flow-operations/.claude/agents/review-prompts/INDEX.md`.
- **OPS-0066 3-cycle circuit-breaker** — cap review→fix→re-review loops
  at 3 cycles; escalate to founder if not converged.
  → `../aidoc-flow-operations/CLAUDE.md` § "Circuit-breaker on review/fix loops".
- **OPS-0067 aidoc-flow-standard scope** — multi-agent review applies to
  ALL non-paused workspace repos.
  → `../aidoc-flow-operations/CLAUDE.md` § "Multi-agent automated review"
  → "aidoc-flow standard scope".
- **OPS-0069 mandatory pre-push audit-trail phrase** — every push must
  carry either `Multi-agent self-review per OPS-0065 (<agents>): <verdict>`
  or `Self-review skipped per founder OK <reason>` in a commit message.
  Enforced locally by `scripts/pre_push_check.sh` + in CI by
  `.github/workflows/audit-trail.yml` → `call / verify`.
  → `../aidoc-flow-operations/CLAUDE.md` § "Multi-agent automated review"
  → "Mandatory pre-push OPS-0065 sub-agent dispatch".
- **REPO_STANDARDS canonical rulebook** — the CI + governance-workflow
  canon (CODEOWNERS, dependabot, standards-drift, pre-push, audit-trail).
  → `../aidoc-flow-ci/docs/REPO_STANDARDS.md`.

**Rationale for path-with-summary format (H5 decision):** Prose
mentions of "OPS-NNNN" do not resolve automatically. A Claude Code
session reading a consumer `CLAUDE.md` needs (a) enough one-sentence
context to know if the rule applies to the current work + (b) an
explicit READABLE path if it does. Both together prevent the two
failure modes: silent skip (no summary → agent doesn't know what
the rule requires) + read-explosion (no summary → agent must read
every referenced file to decide relevance).

Repo-specific rules (that DO belong here — not in canon): <consumer
authors this — e.g., framework's GATE-SPEC-E005 version bump rule,
operations' locked business decisions, iplan-standard's schema versioning
policy, etc.>
```

### 4.3 Section blocks — required vs optional

**REQUIRED** in every non-paused repo's CLAUDE.md:

1. `# CLAUDE.md — <friendly-name>` (H1 title)
2. `## What this repo is`
3. `## Per-repo governance` (canonical table shape per §4.2)
4. `## GitHub operations` (canonical text — no repo variance)
5. `## Workspace standards (aidoc-flow canon — reference, do not
   duplicate)` (canonical section with OPS-NNNN references)

**OPTIONAL** (repo-specific):

1. `## Where things are` (repo file layout — highly repo-specific;
   not mandated)
2. `## Locked decisions` (only if the repo has locked-decision-list content;
   framework, operations, business do; others don't).
3. `## Development workflow` (repo-specific workflow guidance).
4. Repo-specific sections keyed to that repo's specialty (framework's
   GATE-SPEC rule, engramory's evaluation-harness discipline, etc.).

### 4.4 "Not adopted — rationale" pattern

A repo may INTENTIONALLY omit a file kind. The canon permits this if:

1. The `Per-repo governance` table cell reads `Not adopted — <one-line
   rationale>` (e.g., business `CHANGELOG.md not adopted — DECISIONS.md
   - git commit log serve as the changelog`).
2. The rationale is durable (not "TODO adopt later").

`apply-standards.sh --check` treats "Not adopted — …" as a valid cell
value and does not flag the missing file. Any cell starting with `Not
adopted —` (em-dash `—` OR ASCII `--`) followed by 1+ words is accepted.

### 4.5 Parser contract — anchor + column headers

`--check-governance` locates and parses the `Per-repo governance` table
in each consumer `CLAUDE.md` deterministically using this contract. The
parser MUST fail loud if any invariant below is broken; the fix belongs
in the consumer's CLAUDE.md, not in the parser.

**Section anchor:** H2 heading matching this regex (case-sensitive `##`
prefix; permits a trailing dash/em-dash tail, which 7 existing consumers
use — verified 2026-07-08):

```text
^## Per-repo governance(\s+[—-].*)?\s*$
```

Matches both `## Per-repo governance` (canon-source form) and
`## Per-repo governance — this repo owns its own continuity` (existing
consumer form). The parser reads from this line to the next `^##`
line (next H2), which is the table region.

**Table format:** GitHub-Flavored-Markdown pipe table with a Surface/Path
header pair on the first two non-blank lines after the section body prose.
Both the "loose" and "tight" GFM forms of the separator row are accepted
(`| --- | --- |` OR `|---|---|`):

```text
| Surface | Path (in this repo) |
| --- | --- |
```

Column headers match by prefix on the first cell — the first cell must
start with `Surface` (case-insensitive) and the second cell must start
with `Path` (case-insensitive). This tolerates existing consumers'
column-header formatting variance while still enforcing intent.

**Row format:** `| <surface-label> | <path-or-Not-adopted-cell> |`.

- `<surface-label>`: matched against the six REQUIRED labels using
  case-insensitive substring match — a row's `<surface-label>` counts
  as the required row if it CONTAINS one of the canonical tokens
  below (which handles `Plans (IPLANs)`, `Live HANDOFF`, `Live handoff
  (protocol in ...)`, etc. without forced rename):

  | Required row | Canonical token (substring) |
  | --- | --- |
  | HANDOFF | `handoff` |
  | TODO | `todo` OR `backlog` |
  | Decisions | `decisions` |
  | Plans | `plans` OR `iplan` |
  | Changelog | `changelog` |
  | Roadmap | `roadmap` |

  Rows whose label matches NONE of the tokens are treated as REPO-SPECIFIC
  additional rows (also verified for path existence, but not counted
  toward required-row completeness).

- `<path-or-Not-adopted-cell>`: either a filesystem path (relative to
  the repo root; matched against `os.path.exists`; strip surrounding
  backticks + parenthesized annotation like `(protocol in ...)` before
  matching), OR a cell matching the "Not adopted —" pattern per §4.4.
  Empty cells fail with a `missing-cell` error.

  **"Not adopted —" precedence:** the parser detects the
  `Not adopted [—-]` prefix (em-dash or ASCII double-dash) BEFORE any
  path-extraction. A Not-adopted cell containing punctuation in the
  rationale (commas, etc.) is treated atomically as an intentional
  omission; no path extraction is attempted.

**Multiple surfaces for the same required row** (framework's dual
DECISIONS, engramory's dual ROADMAP): use the `## Per-repo governance`
table's ADDITIONAL-row pattern from §4.2 (rows below the required 6).
The required row cites the primary/canonical path; a repo-specific
additional row cites the secondary. Multi-value cells (comma-separated
paths in one cell) are NOT accepted — one row per surface preserves the
distinct label + rationale.

**Repo-specific-rows separator:** the informational separator row `|
_(repo-specific rows below — same table, optional)_ | |` is
IGNORED by the parser (recognized by the leading underscore prose).
Consumers may omit the separator entirely; it is documentation-only.

**Diagnostic output (JSON, so lint tooling can consume):**

```json
{
  "clm_path": "aidoc-flow-framework/CLAUDE.md",
  "found_anchor": true,
  "found_table": true,
  "required_rows": {"Live HANDOFF": {"cell": "plans/HANDOFF.md", "verified": true}, ...},
  "additional_rows": [{"surface": "Governance decisions", "cell": "governance/DECISIONS.md", "verified": true}, ...],
  "errors": []
}
```

Consumers use the JSON to fix specific rows without reading full parser
output. The JSON emission is the canonical DoD for §5.2 `--check-
governance` mode.

## 5. Deliverable shape — 4 PRs (bundled PR-V1+V3 + split PR-V4)

Split into 4 focused PRs, per OPS-0061 Rule 1 (≤3 surfaces bundles are
atomic where PLAN-002 precedent applies). Two structural choices from the
Pass 2 fold:

- **PR-V1 bundles the canon templates + aidoc-flow-ci self-adoption in
  ONE PR** (per PLAN-002 §5.4 Wave 0 precedent: canon-home dogfooded its
  own canon in the same PR that shipped it, so the canon is
  demonstrably usable at merge time). See §5.1 below.
- **Original PR-V4 split into PR-V3 (operations, owns its own governance)
  - PR-V4 (aidoc-flow-ci, ships the wave-scheduling doc)**. The two
  repos have different reviewers, different governance surfaces, and
  coupling them in one PR would violate OPS-0061 Rule 1 (≤3 surfaces
  PER PR — split by owning repo). See §5.3 + §5.4 below.

### 5.1 PR-V1 — canon templates + REPO_STANDARDS.md §16 + aidoc-flow-ci self-adoption (Wave 0)

**Purpose:** ship the canonical templates + rulebook anchor + demonstrate
the canon works by adopting it on aidoc-flow-ci in the same PR (per
PLAN-002 §5.4 Wave 0 dogfood precedent — canon-home eats own dogfood
alongside shipping the canon).

**Files created / touched:**

Canon (canon-source ships):

- `install/templates/CLAUDE.md.template` (NEW) — canonical `CLAUDE.md`
  shape per §4.2 + placeholder markers (`<REPO_NAME>`, `<REPO_PURPOSE>`,
  etc.) that consumers substitute per repo.
- `install/templates/HANDOFF.md.template` (NEW) — minimal live-resume
  document. Sections: `## Current state (<ISO-date>)`, `## Open threads`,
  `## Next-session start-here`.
- `install/templates/DECISIONS.md.template` (NEW) — minimal decision log.
  Format: `## <ID>: <title> (<ISO-date>)` with `**Context**` /
  `**Decision**` / `**Consequences**` sub-headers.
- `install/templates/ROADMAP.md.template` (NEW) — minimal roadmap.
  Sections: `## Current phase`, `## Next phase`, `## Deferred`.
- `install/templates/plans-README.md.template` (NEW) — content for
  `plans/README.md` explaining the per-repo plan naming convention.
- `docs/REPO_STANDARDS.md` §16 (NEW section) — canonical rule per
  §4.1 + §4.5 parser contract.

aidoc-flow-ci self-adoption (Wave 0 in-same-PR):

- `HANDOFF.md` (NEW at repo root) — created from
  `install/templates/HANDOFF.md.template`. Initial content: "Live resume
  point for aidoc-flow-ci — PLAN-002 Wave 1-3 rolled out; PLAN-003 in
  flight (canon templates ship here in PR-V1)."
- `DECISIONS.md` (NEW at repo root) — created from
  `install/templates/DECISIONS.md.template`. Initial entries: backfill
  PLAN-001 canon establishment + PLAN-002 unification + PLAN-002 §14
  audit-trail check as CI-DEC-001/002/003.
- `ROADMAP.md` (NEW at repo root) — created from
  `install/templates/ROADMAP.md.template`. Current phase: PLAN-003
  rollout. Next: canon labels sync + Wave 5 umbrella.
- `CLAUDE.md` (NEW at repo root) — aidoc-flow-ci previously had no
  `CLAUDE.md` (rare among workspace repos); this PR creates it from
  the shipped `install/templates/CLAUDE.md.template`. Substantive: this
  repo is the canon-source; per-repo governance section declares
  HANDOFF/DECISIONS/ROADMAP at root, plans at `plans/`, changelog at
  root, TODO "Not adopted — plans/ + issue-tracker serve as backlog".

Umbrella:

- `CHANGELOG.md` — single `[Unreleased]` entry covering the canon
  templates + Wave 0 self-adoption.

**Surface count:** 11 files (5 canon templates + 4 aidoc-flow-ci self-
adoption + REPO_STANDARDS §16 + CHANGELOG). Above the OPS-0061 Rule 1
≤3 default. **The PLAN-002 §5.4 Wave 0 dogfood precedent is NOT
blanket authorization** (per P4 F#12): an explicit per-PR founder OK
must be obtained BEFORE push, and the commit message audit-trail line
per OPS-0069 must cite the OK.

**Pre-PR-V1 gate items:**

1. Explicit founder OK on the 11-surface bundle. Ask before opening
   PR-V1. Do NOT default to PLAN-002 precedent.
2. Author `Multi-agent self-review per OPS-0065 (<agents>): <verdict>,
   Wave-0 11-surface bundle per PLAN-002 §5.4 precedent, founder OK
   <date>` in the PR-V1 commit message.

**Rollout gate:** merges before V2/V3/V4. Merge validates canon by
demonstration — the canon-source repo passes its own `--check-
governance` on the same commit that ships the canon.

### 5.2 PR-V2 — apply-standards.sh coverage

**Purpose:** mechanical check that the canon is followed on each consumer.

**Files created / touched:**

- `install/apply-standards.sh` (edit) — new `--check-governance` mode
  that reads consumer's `CLAUDE.md` for the `## Per-repo governance`
  table, parses declared paths, and verifies each declared file exists
  on disk (or the cell is a valid "Not adopted — …" line). Extends the
  existing drift matrix; runs by default in `--check` mode too.
- `install/install.sh` (edit) — if consumer has no `CLAUDE.md`, install
  the canon template with all placeholders present (consumer must fill
  in before commit). If consumer has a `CLAUDE.md`, verify it has the
  5 required sections per §4.3; if missing, print a merge suggestion
  (don't auto-modify existing CLAUDE.md — too risky).
- `CHANGELOG.md` — `[Unreleased]` entry.

**3 surfaces** — Rule 1 compliant.

**Rollout gate:** merges after V1.

### 5.3 PR-V3 — operations CROSS_REPO_PLAYBOOKS §T-D (owning repo: aidoc-flow-operations)

**Owning repo:** `aidoc-flow-operations` (owns `docs/CROSS_REPO_PLAYBOOKS.md`
canonically per operations `CLAUDE.md` § "Where things are").

**Purpose:** codify the PLAN-003 wave rollout scheme into operations'
canonical cross-repo playbooks doc so the per-repo waves are discoverable
from operations' authoritative index.

**Files created / touched:**

- `docs/CROSS_REPO_PLAYBOOKS.md` — new §T-D "Project-governance-canon
  rollout waves (PLAN-003 §5.5)" section. Content mirrors PLAN-003 §5.5
  wave-order table with an explicit link back to
  `../aidoc-flow-ci/plans/PLAN-003_project-governance-canon.md`.
- `CHANGELOG.md` — `[Unreleased]` entry.
- `ops/DECISIONS.md` — NEW `OPS-0070` entry ratifying PLAN-003 canon +
  citing PR-V3 (this PR) as the operations-side adoption.

**3 surfaces** — Rule 1 compliant.

**Reviewers:** operations code-owners (per operations `.github/CODEOWNERS`).

**Rollout gate:** merges after PR-V2. Independent of PR-V4.

### 5.4 PR-V4 — aidoc-flow-ci PLAN-003 completion + rollout doc (owning repo: aidoc-flow-ci)

**Owning repo:** `aidoc-flow-ci` (owns `plans/PLAN-003_*.md`
canonically).

**Purpose:** finalize PLAN-003 status + ship the per-repo rollout wave
scheduling doc from the canon-source side. Content is redundant with
PR-V3 §T-D but lives on the canon-source repo for AI agents that enter
via `aidoc-flow-ci/` first.

**Files created / touched:**

- `plans/PLAN-003_project-governance-canon.md` — status flip to
  "SHIPPED" + audit-trail line for the rollout Waves.
- `docs/PLAYBOOK_governance-canon-rollout.md` (NEW) — per-repo rollout
  wave doc that mirrors PR-V3's §T-D content but lives on the
  canon-source. Serves AI agents that enter via `aidoc-flow-ci` first
  and don't cross-load `../aidoc-flow-operations/docs/CROSS_REPO_PLAYBOOKS.md`
  automatically. Content is a summary + link-back to §T-D, not a
  duplicate.
- `CHANGELOG.md` — `[Unreleased]` entry.

**3 surfaces** — Rule 1 compliant.

**Reviewers:** aidoc-flow-ci code-owners.

**Rollout gate:** merges after PR-V2. Independent of PR-V3.

### 5.4c Per-repo CLAUDE.md rewrite scope (H6 quantification)

Audit against current CLAUDE.md files (2026-07-08 line counts + section
presence). Each rollout PR touches ONLY the columns marked NEW /
MODIFIED / REPLACED; UNCHANGED columns are preserved verbatim.

| Repo | Lines | H1 title | `## What this repo is` | `## Per-repo governance` | `## GitHub operations` | `## Workspace standards` block | Repo-specific rules |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `aidoc-flow-ci` | 0 (no CLAUDE.md) | NEW | NEW | NEW | NEW | NEW | NEW (canon-home details) |
| `aidoc-flow-operations` | 691 | UNCHANGED | UNCHANGED | MODIFIED (add `Changelog \| CHANGELOG.md` + `Roadmap \| docs/ROADMAP.md` rows currently absent; canon parser accepts `Plans (IPLANs)` label without rename per §4.5) | UNCHANGED | UNCHANGED (canonical source — other repos link here per §4.2 H5 mechanism) | UNCHANGED (many; locked decisions, autonomy tiers, agent registry) |
| `aidoc-flow-business` | 277 | UNCHANGED | UNCHANGED | MODIFIED (existing `docs/SESSION_HANDOFF.md` + `docs/TODO.md` + `docs/DECISIONS.md` rows PRESERVED; add `Plans \| Not adopted — business is strategic ops, no per-initiative plans yet`; add `Changelog \| Not adopted — DECISIONS.md + git commit log serve as changelog per policy`; add `Roadmap \| Not adopted — docs/STARTUP_STRATEGY.md §8 serves as roadmap`) | UNCHANGED | MODIFIED (retrofit path-with-summary format per §4.2 H5 mechanism) | UNCHANGED (strategy anchors, locked decisions) |
| `aidoc-flow-framework` | 468 | UNCHANGED | UNCHANGED | MODIFIED (existing 5 rows preserved; add `Roadmap \| ROADMAP.md` row currently absent; add additional rows for nested `framework/governance/DECISIONS.md` + per-package `platforms/hermes/CHANGELOG.md` + `platforms/claude-code-plugin/CHANGELOG.md`) | UNCHANGED | MODIFIED (retrofit path-with-summary format per §4.2 H5 mechanism) | UNCHANGED (GATE-SPEC, plugin bundle rules, D-decisions) |
| `aidoc-flow-iplanic` | 229 | UNCHANGED | UNCHANGED | MODIFIED (existing table PRESERVED — `docs/HANDOFF.md` already present per P2 H1 correction; retrofit path-with-summary format) | UNCHANGED | MODIFIED (retrofit path-with-summary format per §4.2 H5 mechanism) | UNCHANGED |
| `iplan-runner` | 277 | UNCHANGED | UNCHANGED | MODIFIED (add `TODO.md` root row) | UNCHANGED | MODIFIED (retrofit path-with-summary format per §4.2 H5 mechanism) | UNCHANGED |
| `aidoc-flow-iplan-standard` | 56 | UNCHANGED | UNCHANGED | **NEW** (whole section — currently absent) | UNCHANGED | MODIFIED (currently thin; expand to canonical path-with-summary format per §4.2 H5) | UNCHANGED (schema versioning policy) |
| `aidoc-flow-engramory` | 187 | UNCHANGED | **NEW** (currently missing `## What this repo is`) | MODIFIED (existing table PRESERVED; add HANDOFF row + DECISIONS row — both currently missing files; Wave 3 must consolidate DUAL ROADMAP: canonical = `roadmap/ROADMAP.md` (5.6KB, newer), deprecate `docs/ROADMAP.md` (1.4KB, older) or declare it as additional row; clean stray `tmp/TODO.md`) | UNCHANGED | MODIFIED (retrofit path-with-summary format per §4.2 H5 mechanism) | UNCHANGED |
| `aidoc-flow-interlog` | 84 | UNCHANGED | UNCHANGED | MODIFIED (add `Decisions log \| Not adopted — DECISIONS embedded in plans/ until PLAN-004 logging-hub PR completes` row) | UNCHANGED | **NEW** (currently missing OPS-standards section) | UNCHANGED (logging-hub scope) |
| `aidoc-flow` (umbrella) | 66 | UNCHANGED | UNCHANGED | **NEW** (currently no Per-repo governance heading; add with single-row cell "No local governance files — all live in submodules; see per-submodule CLAUDE.md") | UNCHANGED | UNCHANGED (already has 2 relevant blocks) | UNCHANGED (umbrella-only scope) |

**Rewrite volume per repo** (approximate delta lines vs current — revised
per P4 F#3+F#6 findings; note that em-dash heading tail + label-substring
match mean NO consumer heading rename is required, but required-row
additions for operations/business/framework increase scope):

| Repo | Approx Δ lines | Reviewer effort |
| --- | --- | --- |
| aidoc-flow-ci | +150 (whole file NEW) | Full review; canon-source dogfood |
| operations | +30 (2 required rows added + path-with-summary reference-format retrofit) | Skim + verify link mechanism preserves canonical-source status |
| business | +40 (3 required rows added with policy rationale + retrofit) | Full review; policy declarations sensitive |
| framework | +50 (1 required row + 3 additional rows + retrofit) | Full review; verify dual DECISIONS + multi-CHANGELOG additional rows |
| iplanic | +15 (retrofit only) | Skim |
| iplan-runner | +15 (add TODO row + retrofit) | Skim |
| iplan-standard | +40 (whole gov section NEW + retrofit) | Full review; biggest additions |
| engramory | +45 (What-repo section NEW + HANDOFF/DECISIONS rows + ROADMAP consolidation decision + retrofit) | Full review; ROADMAP consolidation is a real decision |
| interlog | +35 (workspace-standards block NEW + DECISIONS Not-adopted row) | Full review; new block |
| umbrella | +15 (gov section wholly NEW) | Trivial (1 row) |

Aggregate ≈ **435 lines** across 10 repos; median per repo ≈ 35 lines.
Each rollout PR touches ONLY its own CLAUDE.md + newly created governance
files + CHANGELOG — well within OPS-0061 Rule 1 (≤3 doc surfaces per PR).

### 5.5 Per-repo rollout waves (out-of-plan follow-up PRs)

After PR-V1/V2/V3/V4 merge, one PR per non-paused repo (T-C
coordinated-merge-window per operations `docs/CROSS_REPO_PLAYBOOKS.md`
§T-D). Each PR:

1. Adds MISSING file kinds per each repo's chosen convention (not
   canonical paths); scope per §5.4c row for that repo.
2. Updates `CLAUDE.md` to include the standardized `## Per-repo
   governance` table (with any repo-specific ADDITIONAL rows per §4.2)
   - the 5 required sections per §4.3.
3. Preserves existing intentional paths (operations `ops/` retained;
   framework `plans/` retained; framework's dual `governance/DECISIONS.md`
   preserved as an additional row).

**Wave order:**

- **Wave 0** (canon-home self-adoption): `aidoc-flow-ci` — handled by
  PR-V1 above (bundled per Pass-2 H4 fold).
- **Wave 1** (governance tier): `aidoc-flow-framework`,
  `aidoc-flow-iplan-standard`.
  Framework: only CLAUDE.md updates needed (+30 lines per §5.4c);
  no file additions since HANDOFF+DECISIONS+ROADMAP+plans all exist.
  iplan-standard: biggest scope — needs HANDOFF+DECISIONS+ROADMAP+plans/
  ALL created + CLAUDE.md `## Per-repo governance` block wholly NEW
  (+40 lines per §5.4c).
- **Wave 2** (ops-private tier): `aidoc-flow-operations`,
  `aidoc-flow-business`, `aidoc-flow-iplanic`.
  Operations: link-summary retrofit only (+20 lines per §5.4c); ops/
  paths already documented as intentional.
  Business: CLAUDE.md gov table PRESERVES existing rows (`docs/SESSION_HANDOFF.md`
  per P4 F#1 correction, `docs/TODO.md`, `docs/DECISIONS.md`); adds
  "Not adopted" rationale cells for CHANGELOG + Plans + Roadmap
  (rationales per business's stated policy in existing CLAUDE.md).
  Iplanic: CLAUDE.md gov table row for `docs/HANDOFF.md` (already
  exists — audit correction per H1 fold) + link-summary retrofit.
- **Wave 3** (product tier): `iplan-runner`, `aidoc-flow-engramory`.
  iplan-runner: CLAUDE.md +15 lines; existing `TODO.md` root row added.
  Engramory: adds HANDOFF + DECISIONS files + `## What this repo is`
  section (currently missing) + cleans stray `tmp/TODO.md` (per memory
  rule "Never in tmp/"). Existing root `TODO.md` stays as backlog.
  **DUAL ROADMAP consolidation** (per P4 F#4): canonical =
  `roadmap/ROADMAP.md` (5591 bytes, mtime 2026-07-07); Wave 3 PR MUST
  choose one of: (a) delete `docs/ROADMAP.md` (older 1456-byte version)
  and declare only `roadmap/ROADMAP.md` in gov table; (b) keep both and
  declare `docs/ROADMAP.md` as an additional row per §4.2 with a
  rationale (e.g., "older strategic-summary; roadmap/ is operational");
  (c) merge content of `docs/` into `roadmap/` then delete `docs/`.
  Recommendation: (a) — clean single canonical roadmap.
- **Wave 4** (bootstrap): `aidoc-flow-interlog` — CLAUDE.md gains the
  `## Workspace standards` block (currently missing entirely per §5.4c
  audit) + a `Decisions log \| Not adopted — DECISIONS embedded in
  plans/ until PLAN-004 logging-hub PR completes` row (per P4 F#5).
  No file additions since HANDOFF+ROADMAP+plans+CHANGELOG exist.
- **Wave 5** (umbrella): `aidoc-flow` — special-case. Umbrella CLAUDE.md
  currently has NO `## Per-repo governance` heading (per P4 F#15
  correction — was previously said "MODIFIED", actually NEW). Wave 5
  PR adds the heading with a single explicit cell: "No local governance
  files — all live in submodules; see per-submodule CLAUDE.md at
  `<submodule>/CLAUDE.md`". No file creation.

**Paused** (`aidoc-flow-knowledge-rag`, `aidoc-flow-site`) — skipped
per founder direction 2026-07-04.

**Merge sequencing constraint:** Waves 1-4 may overlap in time but each
wave's PRs must merge in the order shown (within a wave, alphabetical is
fine — no coupling across repos in the same wave). Cross-wave: Wave N+1
does not start until Wave N is FULLY green (all PRs in the wave merged

- `--check-governance` passes on each). Wave 5 (umbrella) always last.

## 6. Risks

| # | Risk | Severity | Mitigation |
| --- | --- | --- | --- |
| 1 | Canon CLAUDE.md template drift vs each repo's hand-authored sections | High | Canon template ONLY covers required sections (§4.3); optional sections stay hand-authored. `apply-standards.sh --check` verifies presence of required sections + canonical table shape, not full-body match. |
| 2 | Repo authors intentionally omit files but forget the "Not adopted — rationale" line | Medium | `apply-standards.sh --check` requires either a valid path OR a "Not adopted — …" cell value; empty cells fail the check. |
| 3 | Consumer CLAUDE.md rewrites lose repo-specific content during Wave rollout | High | Wave PR authors HAND-MERGE new canonical sections into existing CLAUDE.md; never overwrite. `install.sh` prints a suggestion rather than auto-modifying. |
| 4 | Governance table path declarations become stale (path moves; CLAUDE.md not updated) | Medium | `--check` fails if declared path doesn't exist. Consumer forced to keep declaration ↔ filesystem in sync. |
| 5 | Repos with truly different governance model (business's DECISIONS.md at `docs/`) can't fit canon table | Medium | Canon table PERMITS any path; consumer declares what's actually there. No path enforcement. |

## 7. Success criteria

- Every non-paused non-bootstrap repo passes `bash install/apply-standards.sh
  --check --check-governance` with zero missing files + zero missing table
  cells.
- Every non-paused repo's `CLAUDE.md` contains the 5 required sections per
  §4.3 (auto-verified by `--check`).
- An AI agent entering ANY non-paused workspace repo finds a canonical
  `## Per-repo governance` table + can locate HANDOFF/DECISIONS/etc. in
  ≤1 file read (the CLAUDE.md itself).
- The 5 workspace-standards sections (OPS-0061/62/65/66/67/69) are
  REFERENCED not DUPLICATED across repos — canonical text lives in
  `aidoc-flow-operations/CLAUDE.md` + `aidoc-flow-ci/docs/REPO_STANDARDS.md`;
  each consumer CLAUDE.md points at them.

## 8. Cross-references

- PLAN-002 (workspace standards rollout — CI + governance-workflow canon):
  `plans/PLAN-002_workspace-standards-rollout.md`. PLAN-003 extends its
  rollout-wave shape + `apply-standards.sh --check` machinery.
- REPO_STANDARDS.md (this repo) — will gain §16 in PR-V1.
- `aidoc-flow-operations/ops/DECISIONS.md`:
  - OPS-0061 (governance PR discipline)
  - OPS-0062 (auto-merge default)
  - OPS-0065 (multi-agent review)
  - OPS-0066 (3-cycle circuit-breaker)
  - OPS-0067 (aidoc-flow-standard scope)
  - OPS-0069 (mandatory pre-push audit-trail)
- `aidoc-flow-operations/docs/CROSS_REPO_PLAYBOOKS.md` — T-C wave-window
  pattern used by §5.5. PR-V4 extends with §T-D "Project-governance-
  canon rollout waves."
- Existing consumer `CLAUDE.md` files (per-repo reference for §5.5 wave
  scoping):
  - `aidoc-flow-operations/CLAUDE.md` (fullest — canon-source of §4.3
    required sections)
  - `aidoc-flow-framework/CLAUDE.md`
  - `aidoc-flow-business/CLAUDE.md`
  - `aidoc-flow-engramory/CLAUDE.md`
  - `aidoc-flow-iplanic/CLAUDE.md` (229 lines; existing per §5.4c)
  - `iplan-runner/CLAUDE.md` (277 lines; existing per §5.4c)
  - `aidoc-flow-iplan-standard/CLAUDE.md` (56 lines; existing per §5.4c)
  - `aidoc-flow-interlog/CLAUDE.md`
  - `aidoc-flow/CLAUDE.md` (umbrella)

## 9. Audit trail

- 2026-07-08 — Plan drafted (Pass 0). Origin: founder direction after
  PLAN-002 Wave 2 rollout in progress — audit showed governance-file
  variance across 9 repos + missing files on 4. Founder chose "Option
  B — flexible canonical (each repo declares paths in CLAUDE.md)" +
  "unified CLAUDE.md template."
- 2026-07-08 — Pass 2 adversarial review (fresh-context code-reviewer
  agent) returned REVISIONS-NEEDED with 6 HIGH + 6 MED + 6 LOW
  findings. Load-bearing HIGH findings: H1 iplanic HANDOFF audit
  wrong (docs/HANDOFF.md exists); H2 canon template needs
  repo-specific ADDITIONAL rows (framework dual DECISIONS,
  multi-CHANGELOG); H3 parser contract needs codified anchor + column
  headers; H4 PR-V4 needs splitting by owning repo; H5 "reference-not-
  duplicate" needs concrete mechanism (chosen: 1-sentence summary +
  canonical path); H6 rewrite scope needs quantification.
- 2026-07-08 — Pass 3 author fold (this revision): H1-H6 folded,
  MED/LOW findings addressed inline. Re-audit (2026-07-08) via `find`
  discovered 3 additional inaccuracies in the §2 matrix beyond H1:
  business `docs/TODO.md` (not empty); framework multi-CHANGELOG
  (root + platforms/hermes + platforms/claude-code-plugin) + dual
  DECISIONS (plans/ + governance/); engramory ROADMAP at `docs/`
  (not `roadmap/`) + stray `tmp/TODO.md`. All corrected in §2.
- **Next:** Pass 4 fresh-context independent review before opening
  the plan PR (per verified-planning skill discipline: ≥2 passes,
  ≥1 independent, final states zero findings).
- 2026-07-08 — Passes 4/5/6 completed (OPS-0066 cycle 3 = final).
  Plan PR opened + merged (aidoc-flow-ci #72).
- 2026-07-08 — PR-V1 merged (aidoc-flow-ci #73): canon templates
  (`install/templates/*.template`) + `REPO_STANDARDS.md` §16 + Wave 0
  self-adoption bundle. 11 surfaces under explicit founder OK per §5.1
  gate item #1. Multi-agent review: 4 HIGH + 3 MED + 5 LOW folded.
- 2026-07-08 — PR-V2 merged (aidoc-flow-ci #74): `--check-governance`
  parser mode (`install/parse-governance-table.py` + `governance_check`
  in `install/apply-standards.sh` + `install/install.sh` CLAUDE.md
  bootstrap step). Multi-agent review: 4 HIGH + 7 MED + 3 LOW folded
  (including the template-parser self-inconsistency and path-traversal
  sandbox items).
- 2026-07-08 — PR-V3 merged (aidoc-flow-operations #217):
  CROSS_REPO_PLAYBOOKS §T-D operational playbook + `OPS-0070`
  ratification. Multi-agent review: 1 CRITICAL + 2 HIGH + 6 MED + 2
  LOW folded.
- 2026-07-08 — PR-V4 (this PR): status flip DRAFT → SHIPPED + this
  audit-trail entry + `docs/PLAYBOOK_governance-canon-rollout.md`
  canon-source-side summary.
- **SHIPPED** (canon layer). Per-repo Waves 1-5 rollout PRs execute
  next per §5.5 / operations §T-D.

## Claim ledger

> Every load-bearing file-path claim cites `<repo>/<path>:<line>` actually
> opened. Cross-repo citations use `<repo-folder>/<path>` form against the
> umbrella root `/opt/data/aidoc-flow` (passed via `--root`).

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | operations HANDOFF lives at `ops/HANDOFF.md` | `# HANDOFF — AIDoc Flow Operations` | operations/ops/HANDOFF.md:1 |
| 2 | operations DECISIONS lives at `ops/DECISIONS.md` | `# DECISIONS — AIDoc Flow Operations` | operations/ops/DECISIONS.md:1 |
| 3 | business deliberately declines CHANGELOG + ROADMAP per policy in CLAUDE.md | `**Not adopted (deliberately):** a separate` | business/CLAUDE.md:68 |
| 4a | business has `docs/TODO.md` | `# TODO — Remaining Tasks` | business/docs/TODO.md:1 |
| 4b | business has `docs/SESSION_HANDOFF.md` (P4 F#1 correction) | `# Session Handoff — continue here` | business/docs/SESSION_HANDOFF.md:1 |
| 5a | framework has DECISIONS at `plans/DECISIONS.md` | `# Decision Log` | framework/plans/DECISIONS.md:1 |
| 5b | framework has ALSO nested `framework/governance/DECISIONS.md` (dual — governance-side decisions distinct from plans-side) | `# Framework Governance Decisions` | framework/framework/governance/DECISIONS.md:1 |
| 6a | framework root CHANGELOG present | `# Changelog` | framework/CHANGELOG.md:1 |
| 6b | framework Hermes per-package CHANGELOG | `# Hermes Platform Changelog` | framework/platforms/hermes/CHANGELOG.md:1 |
| 6c | framework plugin per-package CHANGELOG | `# Claude Code Plugin Changelog` | framework/platforms/claude-code-plugin/CHANGELOG.md:1 |
| 7 | iplanic HANDOFF exists at `docs/HANDOFF.md` (H1 fold correction) | `# iplanic — Session Handoff` | iplanic/docs/HANDOFF.md:1 |
| 8 | iplan-standard has ONLY CHANGELOG (biggest gap) | `# Changelog` | iplan-standard/CHANGELOG.md:1 |
| 9a | engramory has `docs/ROADMAP.md` (older, 1.4KB) | `# Engramory roadmap` | engramory/docs/ROADMAP.md:1 |
| 9b | engramory ALSO has `roadmap/ROADMAP.md` (newer, 5.6KB — canonical per P4 F#4) | `# Engramory — Project Roadmap` | engramory/roadmap/ROADMAP.md:1 |
| 10 | engramory has stray `tmp/TODO.md` to clean (violates memory rule "Never in tmp/") | `# Engramory TODO — derived from STRATEGY.md + MEMORY_CONCEPT_REVIEW.md` | engramory/tmp/TODO.md:1 |
| 11 | interlog CLAUDE.md exists but has no workspace-standards block | `# CLAUDE.md — Interlog` | interlog/CLAUDE.md:1 |
| 12 | engramory CLAUDE.md exists but missing `## What this repo is` | `# CLAUDE.md` | engramory/CLAUDE.md:1 |
| 13 | operations `docs/CROSS_REPO_PLAYBOOKS.md` exists (PR-V3 target) | `# Cross-repo playbooks` | operations/docs/CROSS_REPO_PLAYBOOKS.md:1 |
| 14 | PLAN-002 §5.4 canon-home dogfood precedent (justifies PR-V1 bundling Wave-0 self-adoption) | `### 5.4 PR-U4 — aidoc-flow-ci self-adoption (bootstrap-paradox resolution)` | aidoc-flow-ci/plans/PLAN-002_workspace-standards-rollout.md:407 |
| 15 | OPS-0061 governance PR discipline lives in operations CLAUDE.md | `## Governance PR discipline (mandatory)` | operations/CLAUDE.md:605 |
| 16 | OPS-0065 multi-agent automated review lives in operations CLAUDE.md | `**Multi-agent automated review (OPS-0065 — generalizes the CI ai-reviewer` | operations/CLAUDE.md:222 |
| 17 | OPS-0067 canonical prompt templates live at operations INDEX | `# Multi-agent review-prompt templates — INDEX` | operations/.claude/agents/review-prompts/INDEX.md:1 |
| 18 | OPS-0069 audit-trail rule enforced by operations wrapper script | `pre_push_check_ops.sh — operations-side pre-push wrapper per PLAN-002 §4.8` | operations/scripts/pre_push_check_ops.sh:2 |

## Review log

### Pass 0 — 2026-07-08 — author draft

Load-bearing gaps identified pre-Pass-2: none (self-check).
**Result:** hand off to Pass 2.

### Pass 2 — 2026-07-08 — independent (fresh-context code-reviewer agent)

Verdict: REVISIONS-NEEDED.
Load-bearing findings (6 HIGH + 6 MED + 6 LOW). Full findings folded
in §9 Audit trail above + this revision.
**Result:** author fold (Pass 3).

### Pass 3 — 2026-07-08 — author fold (this revision)

- H1-H6 folded inline (§2, §4.2, §4.5, §5.1, §5.4a/b/c, §5.5).
- MED/LOW folded inline (link-summary format §4.2, empty separator row §4.5,
  wave-sequencing constraint §5.5, per-repo delta table §5.4c).
- Additional Pass-3-discovered §2 corrections: business `docs/TODO.md`;
  framework dual DECISIONS + multi-CHANGELOG; engramory ROADMAP path +
  stray `tmp/TODO.md`.
- Added Claim ledger §10 (18 verified citations) + this Review log §11.
**Result:** hand off to Pass 4 (fresh-context independent re-review).

### Pass 4 — 2026-07-08 — independent (fresh-context code-reviewer agent)

Verdict: REVISIONS-NEEDED.

**Load-bearing findings** (6 HIGH + 5 MED + 3 LOW). Full findings:

- **F#1 HIGH audit-error-business-handoff:** business has `docs/SESSION_HANDOFF.md`
  (7885 bytes, existing) — §2 originally missed it. Same class of failure
  H1 addressed for iplanic.
- **F#2 HIGH anchor-regex-incompat:** 7 existing consumers use `## Per-repo
  governance — this repo owns its own continuity` (em-dash tail); Pass-3
  regex `^## Per-repo governance\s*$` rejects all of them.
- **F#3 HIGH label-matching-incompat:** operations/business/framework existing
  tables use variant labels (`Plans (IPLANs)`, `Strategy / roadmap`) that
  wouldn't match Pass-3 required-label spec.
- **F#4 HIGH engramory-dual-roadmap-missed:** `roadmap/ROADMAP.md` (5.6KB)
  exists alongside `docs/ROADMAP.md` (1.4KB); Pass-3 §2 dismissed
  `roadmap/` as absent.
- **F#5 HIGH interlog-wave4-decisions-omission:** Wave 4 didn't specify
  interlog DECISIONS disposition.
- **F#6 HIGH multi-value-vs-additional-row-precedence:** §4.2 (additional rows)
  and §4.5 (multi-value cells) both offered for the same problem; ambiguous.
- **F#7-11 MED, F#12-15 LOW.**

**Verified resolutions of Pass 2 H1-H6:** H1/H2/H4/H5 RESOLVED; H3
PARTIAL (needs Pass 5 rework — findings F#2/F#3/F#6/F#11 all point at
§4.5); H6 PARTIAL (line-count deltas 2-3× low; needs Pass 5 recalc).

**Result:** author fold (Pass 5).

### Pass 5 — 2026-07-08 — author fold (this revision)

Folded ALL Pass 4 HIGH findings + MED/LOW cleanups. Key changes:

- **F#1 fold:** §2 corrected — business HANDOFF at `docs/SESSION_HANDOFF.md`;
  Claim ledger row 4b added; Findings-list "missing HANDOFF (5)" → "(3)".
- **F#2 fold:** §4.5 anchor regex relaxed to
  `^## Per-repo governance(\s+[—-].*)?\s*$` — accepts em-dash tail.
  §4.2 updated to note heading tail is optional.
- **F#3 fold:** §4.5 required-label matching switched to CANONICAL-TOKEN
  SUBSTRING match (table of tokens) — accepts `Plans (IPLANs)`,
  `Live HANDOFF`, etc. without forced rename. §5.4c per-repo table
  updated to enumerate REAL work (add missing required rows for
  operations/business/framework rather than force renames).
- **F#4 fold:** §2 engramory row shows dual ROADMAP; Claim ledger rows
  9a/9b split; §5.5 Wave 3 disposition decision codified — canonical =
  `roadmap/ROADMAP.md`, recommend option (a) delete `docs/ROADMAP.md`.
- **F#5 fold:** §5.5 Wave 4 interlog now specifies "Decisions log \|
  Not adopted — DECISIONS embedded in plans/ until PLAN-004 completes"
  row.
- **F#6 fold:** §4.5 multi-value cell spec DELETED; additional-row is
  the sole mechanism.
- **F#7 fold (Not-adopted precedence):** §4.5 now explicit — Not-adopted
  detection precedes any path extraction. Moot since multi-value dropped.
- **F#8 fold:** §5.4c operations Workspace-standards column changed
  UNCHANGED (canonical source; other repos link here).
- **F#9 fold:** §5.1 file count corrected 12 → 11.
- **F#10 fold:** already folded with F#1.
- **F#11 fold:** §4.5 explicitly accepts both `|---|---|` and
  `| --- | --- |` separator forms.
- **F#12 fold:** §5.1 no longer treats PLAN-002 precedent as blanket
  authorization; adds explicit pre-PR-V1 gate item requiring per-PR
  founder OK before push.
- **F#13 fold:** PR-V4a → PR-V3, PR-V4b → PR-V4, empty §5.3 slot
  removed. All cross-references updated (§5.4c, §5.5, Claim ledger row 13).
- **F#14 fold:** §8 TBD markers replaced with actual line counts.
- **F#15 fold:** §5.4c umbrella `## Per-repo governance` column changed
  MODIFIED → NEW; §5.5 Wave 5 clarified.

Additional Claim-ledger rows added (4b, 9a, 9b) to cover the new
citations introduced by fold.

**Result:** hand off to Pass 6 (fresh-context independent re-review,
final cycle per OPS-0066 3-cycle circuit-breaker).

### Pass 6 — 2026-07-08 — independent (fresh-context code-reviewer agent) — FINAL PASS PER OPS-0066

Verdict: APPROVED.

Verified all P4 F#1-F#15 resolutions RESOLVED on disk. Spot-checked 7
Claim-ledger citations (rows 4b, 5b, 9b, 14, 15, 16, 18) — all resolve
to real content at cited lines. Independently re-verified §4.5 parser
contract against all 7 consumer heading forms + actual label variants
(`Plans (IPLANs)`, `Live HANDOFF`, `Strategy / roadmap`, `Decisions
log`, etc.) — all match the substring-token spec.

**Non-blocking advisory** (does not require plan revision; Wave 3 PR
resolves inline): engramory's existing CLAUDE.md declares
`Decisions log | sdd/05_ADR/` (multi-value) — under §4.5's F#6 fold
banning multi-value, Wave 3 PR will reformat this into required-row +
additional-row pair. §5.5 Wave 3 rollout scope subsumes this.

**Result:** ready — no new findings from Pass 6; plan ready to open
PR-V1 pending §5.1 pre-PR-V1 gate item #1 (explicit founder OK on the
11-surface bundle).
