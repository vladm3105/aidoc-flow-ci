# PLAN-003 — Project governance file canon + unified CLAUDE.md template

**Status:** DRAFT — 2026-07-08
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

## 2. Current-state audit (2026-07-08)

Governance-file matrix across 9 non-paused repos:

| Repo | CHANGELOG | ROADMAP | HANDOFF | DECISIONS | plans / TODO |
| --- | --- | --- | --- | --- | --- |
| `aidoc-flow-ci` | root | — | — | — | `plans/` |
| `aidoc-flow-operations` | root | `docs/` | `ops/` | `ops/` | `ops/iplans/` |
| `aidoc-flow-business` | **—** (policy) | **—** | **—** | `docs/` | **—** |
| `aidoc-flow-framework` | root | root | `plans/` | `plans/` | `plans/FRAMEWORK-TODO.md` |
| `aidoc-flow-iplanic` | root | root | **—** | `docs/` | `plans/` |
| `iplan-runner` | root | root | `plans/` | `plans/` | root `TODO.md` |
| `aidoc-flow-iplan-standard` | root | **—** | **—** | **—** | **—** |
| `aidoc-flow-engramory` | root | `roadmap/` | **—** | **—** | root `TODO.md` |
| `aidoc-flow-interlog` | root | root | root | **—** | `plans/` |

**Paused** (`aidoc-flow-knowledge-rag`, `aidoc-flow-site`) — skip per founder
direction 2026-07-04.

**Findings:**

- Same file kind at 4 different paths across repos (HANDOFF at
  `root/` / `ops/` / `plans/`; DECISIONS at `root/` / `ops/` / `docs/` /
  `plans/`).
- `aidoc-flow-iplan-standard` has ONLY CHANGELOG; no ROADMAP, HANDOFF,
  DECISIONS, or plans dir.
- `aidoc-flow-business` deliberately declines CHANGELOG (policy stated in
  its `CLAUDE.md`); also missing HANDOFF + ROADMAP + plans dir.
- `aidoc-flow-engramory` missing HANDOFF + DECISIONS (has TODO.md at root
  from prior session's PR).
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
| Live HANDOFF | <path or "not adopted — rationale"> |
| TODO / backlog | <path or "not adopted — rationale"> |
| Decisions log | <path or "not adopted — rationale"> |
| Plans | <path or "not adopted — rationale"> |
| Changelog | <path or "not adopted — rationale"> |
| Roadmap | <path or "not adopted — rationale"> |

Never in `tmp/` (transient). Never in the umbrella `aidoc-flow/` (holds no
dev). Cross-repo coordination captured here, references siblings by path
(`../<repo>/`), never relocates their state.

## GitHub operations

Use the GitHub CLI (`gh`) as the default for all GitHub operations — PRs,
issues, reviews, releases, repo queries — not the GitHub MCP servers
(`github-tt`, `github-vl`) or raw API calls. If `gh` is unauthenticated,
run `gh auth login` rather than falling back to MCP/API.

## Workspace standards (aidoc-flow canon — reference, do not duplicate)

This repo follows the aidoc-flow workspace canon. Canonical rules live
on `aidoc-flow-ci` (`docs/REPO_STANDARDS.md`) + `aidoc-flow-operations`
(`ops/DECISIONS.md`); reference by OPS-NNNN and canon section; do not
duplicate the rules here:

- **OPS-0061 governance PR discipline** (≤3 doc surfaces per PR; mandatory
  adversarial pre-push self-review).
- **OPS-0062 AI-agent auto-merge default** (auto-watch + auto-merge when
  green; 10-attempt cap; per-repo exception rules).
- **OPS-0065 multi-agent automated review** (diff-class → agent-set
  dispatch table; canonical prompt templates at
  `aidoc-flow-operations/.claude/agents/review-prompts/`).
- **OPS-0066 3-cycle circuit-breaker** on review/fix loops.
- **OPS-0067 aidoc-flow-standard scope** — multi-agent review applies
  workspace-wide.
- **OPS-0069 mandatory pre-push audit-trail phrase** — every push carries
  either `Multi-agent self-review per OPS-0065 (<agents>): <verdict>` or
  `Self-review skipped per founder OK <reason>` in a commit message.
  Enforced locally by `scripts/pre_push_check.sh` (canon; PLAN-002 §14.1)
  + CI by `.github/workflows/audit-trail.yml` → `call / verify` (PLAN-002
  §14.2).

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

6. `## Where things are` (repo file layout — highly repo-specific;
   not mandated)
7. `## Locked decisions` (only if the repo has locked-decision-list content;
   framework, operations, business do; others don't).
8. `## Development workflow` (repo-specific workflow guidance).
9. Repo-specific sections keyed to that repo's specialty (framework's
   GATE-SPEC rule, engramory's evaluation-harness discipline, etc.).

### 4.4 "Not adopted — rationale" pattern

A repo may INTENTIONALLY omit a file kind. The canon permits this if:

1. The `Per-repo governance` table cell reads `Not adopted — <one-line
   rationale>` (e.g., business `CHANGELOG.md not adopted — DECISIONS.md
   + git commit log serve as the changelog`).
2. The rationale is durable (not "TODO adopt later").

`apply-standards.sh --check` treats "Not adopted — …" as a valid cell
value and does not flag the missing file.

## 5. Deliverable shape — 4 PRs

Split into 4 focused PRs, per OPS-0061 Rule 1 (≤3 surfaces bundles are
atomic where PLAN-002 precedent applies).

### 5.1 PR-V1 — canon templates + REPO_STANDARDS.md §16

**Purpose:** ship the canonical templates + rulebook anchor.

**Files created / touched:**

- `install/templates/CLAUDE.md.template` (NEW) — canonical `CLAUDE.md`
  shape per §4.2. Placeholder markers (`<REPO_NAME>`,
  `<REPO_PURPOSE>`, etc.) that consumers substitute per repo.
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
  §4.1 above.
- `CHANGELOG.md` — `[Unreleased]` entry.

**7 surfaces** — atomic doc-suite bundle per PLAN-002 §5.1 precedent.

**Rollout gate:** merges before V2/V3/V4.

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

### 5.3 PR-V3 — self-adoption on aidoc-flow-ci

**Purpose:** aidoc-flow-ci eats its own dogfood.

**Files created / touched:**

- `HANDOFF.md` (NEW) — created from `install/templates/HANDOFF.md.template`
  with initial content ("Live resume point for aidoc-flow-ci — PLAN-002
  Wave 1-3 rolled out; PLAN-003 in flight...").
- `DECISIONS.md` (NEW) — created from `install/templates/DECISIONS.md.template`
  with initial ISO-stamped entries backfilled from PLAN-001/002 major
  decisions (F1/F2/F3 folds; ci/v1.6.0 tag; PLAN-002 unification).
- `ROADMAP.md` (NEW) — created from `install/templates/ROADMAP.md.template`.
  Current phase: PLAN-003 rollout. Next: canon labels sync + Wave 5 umbrella.
- `CLAUDE.md` (NEW) — created from `install/templates/CLAUDE.md.template`;
  aidoc-flow-ci did not previously have a `CLAUDE.md` (rare among workspace
  repos). Substantive: this repo is the canon-source; per-repo governance
  section declares HANDOFF/DECISIONS/ROADMAP at root, plans at
  `plans/`, changelog at root.
- `CHANGELOG.md` — `[Unreleased]` entry.

**5 surfaces** — atomic self-adoption bundle per PLAN-002 §5.4 precedent
(9 surfaces for aidoc-flow-ci Wave 0 self-adoption; founder OK).

**Rollout gate:** merges after V2.

### 5.4 PR-V4 — CROSS_REPO_PLAYBOOKS T-C wave scheduling

**Purpose:** codify the Wave 5+ rollout scheme (mirrors PLAN-002 §5.5)
into `CROSS_REPO_PLAYBOOKS.md` on operations (already exists) so the
per-repo rollout waves are discoverable from a canonical source.

**Files created / touched:**

- `aidoc-flow-operations/docs/CROSS_REPO_PLAYBOOKS.md` — new §T-D
  section: "Project-governance-canon rollout waves (PLAN-003
  §5.5)". References the wave sequencing table below.
- `CHANGELOG.md` (both repos) — `[Unreleased]` entries.

**2 surfaces** — Rule 1 compliant.

### 5.5 Per-repo rollout waves (out-of-plan follow-up PRs)

After V1/V2/V3/V4 merge, one PR per non-paused repo (T-C coordinated-merge-
window per operations `docs/CROSS_REPO_PLAYBOOKS.md`). Each PR:

1. Adds MISSING file kinds per each repo's chosen convention (not
   canonical paths).
2. Updates `CLAUDE.md` to include the standardized `## Per-repo
   governance` table declaring paths + the 5 required sections per §4.3.
3. Preserves existing intentional paths (operations `ops/` retained;
   framework `plans/` retained).

**Wave order** — same as PLAN-002 §5.5:

- **Wave 0** (canon-home self-adoption): `aidoc-flow-ci` — handled by
  PR-V3 above.
- **Wave 1** (governance tier): `aidoc-flow-framework`, `aidoc-flow-iplan-standard`.
  Framework already has HANDOFF+DECISIONS+plans in `plans/`; only
  CLAUDE.md canonical section update needed. iplan-standard needs
  HANDOFF+DECISIONS+ROADMAP+plans/ ALL created — biggest scope in
  this wave.
- **Wave 2** (ops-private tier): `aidoc-flow-operations`,
  `aidoc-flow-business`, `aidoc-flow-iplanic`.
  Operations retains `ops/` paths (documented as intentional; CLAUDE.md
  canonical section reflects this). Business retains CHANGELOG-decline
  policy (canonical section cell reads "Not adopted — DECISIONS.md +
  git log serve as changelog per business STARTUP_STRATEGY §7"); adds
  HANDOFF + ROADMAP + plans/ that were missing. Iplanic adds HANDOFF
  + plans/ dir if not present.
- **Wave 3** (product tier): `iplan-runner`, `aidoc-flow-engramory`.
  iplan-runner already has most files. Engramory adds HANDOFF +
  DECISIONS (existing `TODO.md` from prior session PR stays as the
  TODO cell value).
- **Wave 4** (bootstrap): `aidoc-flow-interlog` — bootstrap-tier
  applies here too; only CLAUDE.md canonical section needed since
  interlog already has HANDOFF + ROADMAP + plans + CHANGELOG.
- **Wave 5** (umbrella): `aidoc-flow` — special-case. Umbrella
  CLAUDE.md exists but has no dev; canonical section declares NO
  local governance files (all live in submodules).

**Paused** (`aidoc-flow-knowledge-rag`, `aidoc-flow-site`) — skipped
per founder direction.

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
  - `aidoc-flow-iplanic/CLAUDE.md` — TBD (check existence during PR-V1)
  - `iplan-runner/CLAUDE.md`
  - `aidoc-flow-iplan-standard/CLAUDE.md` — TBD
  - `aidoc-flow-interlog/CLAUDE.md`
  - `aidoc-flow/CLAUDE.md` (umbrella)

## 9. Audit trail

- 2026-07-08 — Plan drafted. Origin: founder direction after PLAN-002
  Wave 2 rollout in progress — audit showed governance-file variance
  across 9 repos + missing files on 4. Founder chose "Option B — flexible
  canonical (each repo declares paths in CLAUDE.md)" + "unified
  CLAUDE.md template."
- Awaiting adversarial fresh-context Pass 2 review before opening the
  plan PR (per verified-planning skill discipline).
