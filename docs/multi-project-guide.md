# Multi-project guide — `aidoc-flow-ci` as company CI library

`aidoc-flow-ci` is the **single source-of-truth CI library** for
every company project — current (`aidoc-flow`) and future (trading,
future product lines, etc.). This doc covers the architectural model
+ how a new company project adopts.

For the per-project CI architecture inside a single project, see
[`architecture.md`](architecture.md). For the override patterns, see
[`overrides.md`](overrides.md).

## 1. Why a single CI library across all company projects

Three reasons (carried forward from the original
[IPLAN-0017 charter](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017-CHARTER_aidoc-flow-ci.md)):

1. **Reduce drift.** Every project that consumes `aidoc-flow-ci`
   gets the same reviewer logic, trust-gate semantics, label
   taxonomy, and security model. No project re-implements +
   diverges over time.
2. **Centralized improvements scale.** A new reviewer feature, a
   security patch, a new optional skill — ship once on
   `aidoc-flow-ci`; every project picks it up by bumping its pin.
3. **Independent semver from any one project.** `aidoc-flow-ci`
   ships its own `ci/vX.Y.Z` tags decoupled from any project's
   product release cycle. CI evolves on its own cadence.

## 2. The three-layer architecture

```text
┌──────────────────────────────────────────────────────────────────┐
│ LIBRARY                                                          │
│   aidoc-flow-ci/                                                 │
│   - .github/workflows/*.yml       (reusable workflows)           │
│   - scripts/                       (shared automation logic)     │
│   - install/templates/             (caller-side bootstrap)       │
│   - ai-review/review-prompt.md     (shared rubric — per IPLAN-0022) │
│   - ai-review/verdict.schema.json  (shared verdict schema)       │
│   - docs/                          (consumer-facing docs)        │
│   - skills/                        (future, per IPLAN-0021)      │
│   Versioned via ci/vX.Y.Z tags. ONE per company.                 │
└────────────┬─────────────────────────────────────────────────────┘
             │ shared across all projects
             ▼
┌──────────────────────────────────────────────────────────────────┐
│ PROJECT GOVERNANCE  (one per project — aidoc-flow has operations;│
│                       future projects get their own equivalent)  │
│   <project>-operations/                                          │
│   - ops/iplans/                    (project's plans)             │
│   - ops/DECISIONS.md               (project's decision log)      │
│   - ops/HANDOFF.md                 (project's live state)        │
│   - ops/inbox/                     (founder-execution runbooks)  │
│   - ROADMAP / OKRs                 (project-level)               │
│   Independent per-project; never centralized.                    │
└────────────┬─────────────────────────────────────────────────────┘
             │ project's CI choices feed into
             ▼
┌──────────────────────────────────────────────────────────────────┐
│ CONSUMER REPO  (each repo that runs CI: operations, framework,  │
│                  business, iplanic, future project's consumers) │
│   <consumer-repo>/                                               │
│   - .github/workflows/ai-review.yml          (thin caller)       │
│   - .github/workflows/composition.yml        (thin caller)       │
│   - .github/workflows/docs-sync.yml          (thin caller; opt-in)│
│   - .github/ai-review/config.json            (per-repo policy)   │
│   - .github/docs-sync.json                   (per-repo policy)   │
│   - .github/ai-review/review-prompt.md       (OPTIONAL override) │
│   - CHANGELOG / README / etc.                (per-repo state)    │
│   One per consumer. Independent.                                 │
└──────────────────────────────────────────────────────────────────┘
```

**The local-overrides-shared rule applies at every layer.** A
consumer's local file always wins over the library's default —
including the workflow file itself, the per-repo config, and (per
IPLAN-0022) the rubric + verdict schema. No merge / inheritance /
diamond pattern. See [`overrides.md`](overrides.md) for the three
override modes.

## 3. Onboarding a new company project

When a new company project starts (e.g., a new product line), the
sequence is:

### 3.1 Create the project's governance repo

Create `<new-project>-operations` (or analogous) as the
project's own governance home. Conventions per the existing
operations repo's CLAUDE.md:

| Surface | Path |
|---|---|
| Live HANDOFF | `ops/HANDOFF.md` (read first every session) |
| Decisions log | `ops/DECISIONS.md` (ISO-stamped, append-only) |
| Plans | `ops/iplans/IPLAN-NNNN_*.md` |
| Inbox runbooks | `ops/inbox/` (founder-execution checklists) |
| Roadmap | `ROADMAP.md` |
| Changelog | `CHANGELOG.md` |

Each project's governance is **independent** — never centralized
across projects. The aidoc-flow project's decisions don't bind
the trading project's decisions (and vice versa).

### 3.2 Onboard the project's consumer repos to `aidoc-flow-ci`

For each consumer repo in the new project (the project's main
repo, its sub-libraries, etc.):

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v1.0.6/install/install.sh) \
  <owner>/<consumer-repo> --visibility <public|private>
```

This drops the caller workflows + per-repo config templates + the
canonical labels. From there, the consumer follows the standard
ai-review activation steps (per [`security.md`](security.md) §2 +
the per-consumer prerequisites in
[`troubleshooting.md`](troubleshooting.md) §13-14).

### 3.3 Project-specific overrides (optional)

Each consumer in the new project decides:

- **Reviewer rubric override** — ship
  `.github/ai-review/review-prompt.md` for project-specific review
  focus (e.g., a trading project might emphasize numerical
  correctness + regulatory compliance; a docs project might
  emphasize accessibility + clarity)
- **Per-repo trust allowlist** — `.github/ai-review/config.json`
  `trust.ai_review` lists the authors whose PRs the AI gate
  reviews
- **Auto-merge eligibility** — whether the project's repos opt
  into auto-merge or stay human-merge-only

### 3.4 No coordination with other projects required

Each project consumes `aidoc-flow-ci` independently. Trading
doesn't need to know aidoc-flow's IPLAN list. aidoc-flow doesn't
need to know trading's labels (beyond the canonical 9 from
`install.sh`).

## 4. Versioning + library evolution

`aidoc-flow-ci`'s `ci/vX.Y.Z` semver is the **only company-wide
coordination point**. The release cadence is independent of any
project's product release cadence.

| Change scope | Tag bump | Consumer impact |
|---|---|---|
| New optional workflow (e.g., `docs-sync.yml` alpha.1) | MINOR (`ci/v1.1.0-alpha.N` then `ci/v1.1.0`) | Opt-in; consumers add the caller when ready |
| Bug fix in existing workflow | PATCH (`ci/v1.0.X`) | Consumer optionally bumps pin |
| Breaking change to inputs / output schema | MAJOR (`ci/v2.0.0`) | Consumer migrates per per-release migration notes |

**Each project's consumer repos pin INDEPENDENTLY.** Operations
can be on `ci/v1.0.6` while a future trading project's consumer
is on `ci/v1.1.0-alpha.1`. Pin updates are per-repo PRs.

## 5. Per-project decision boundaries (what stays per-project)

When a new project adopts `aidoc-flow-ci`, the project still owns:

- **WHICH reviewer to use** (codex / claude / future LiteLLM-routed) — config.json choice
- **WHO can approve** (trust.ai_review allowlist) — config.json choice
- **WHETHER to auto-merge** (auto_merge.enabled) — config.json choice
- **WHICH skills to apply** (per IPLAN-0021 once shipped) — config.json `skills.allowlist`
- **WHETHER to override the shared rubric** (per IPLAN-0022 once shipped) — optional file
- **WHICH runner pool to use** (`ubuntu-latest` / self-hosted) — workflow input

The **library** owns:

- The workflow LOGIC (trust gate, App-identity verification, verdict
  parsing, comment + label + merge orchestration)
- The DEFAULT rubric (used when consumer doesn't override)
- The verdict schema (downstream parsers depend on stable shape)
- The label taxonomy (canonical 9 labels every consumer gets)
- The security model (token mint, branch-protection bypass, audit
  trail patterns)

## 6. Why this works at company scale

- **Library improvements compound.** Every workflow improvement
  benefits every project at the next pin-bump.
- **Project governance stays autonomous.** Each project's
  operations-equivalent decides its own plans + decisions; no
  central council.
- **Onboarding is documented + repeatable.** A new project follows
  §3 above; no per-project re-design.
- **Consumer flexibility is preserved.** Per-repo overrides at
  every layer (workflow, config, asset) keep the local-wins
  philosophy intact.

## 7. Current state (2026-06-25)

| Project | Status |
|---|---|
| **aidoc-flow** (current) | Active. Operations + framework consumers live on `@ci/v1.0.6`. Phase C (iplan-runner, business, iplanic, iplan-standard, web-site, engramory) queued for onboarding. |
| Future projects (trading, etc.) | Not yet started. Will adopt this onboarding flow when they begin. |

## 8. References

- [`architecture.md`](architecture.md) — the per-project CI
  architecture (reusable-workflow model; the workflows; trust +
  verdict flow; per-repo policy surfaces)
- [`overrides.md`](overrides.md) — three override modes
  (parameter / full replacement / custom workflow)
- [`security.md`](security.md) — security model + trust gate +
  App identity
- [IPLAN-0017](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017_unified-ci-flows.md)
  + [IPLAN-0017-CHARTER](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017-CHARTER_aidoc-flow-ci.md)
  — the founding design + multi-project framing
- [`OPS-0060`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/DECISIONS.md)
  — the consume-from-aidoc-flow-ci decision (supersession of
  earlier vendored-only approach)
