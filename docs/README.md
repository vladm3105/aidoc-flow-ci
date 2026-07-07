# aidoc-flow-ci documentation

Index of `aidoc-flow-ci` documentation. The repo's three top-level
docs cover consumer-facing intro, install, and release notes:

| Doc | Scope |
| --- | --- |
| [`../README.md`](../README.md) | Consumer-facing intro: what ships, how to install, override modes, v1.0.0 known limitations |
| [`../install/README.md`](../install/README.md) | `install/install.sh` usage + next steps |
| [`../CHANGELOG.md`](../CHANGELOG.md) | Release notes per `ci/vX.Y.Z` tag |

This `docs/` tree covers reference + design topics.

## Available now

| Doc | Scope |
| --- | --- |
| [`../LABELS.md`](../LABELS.md) | PR + runner label conventions (three namespaces: state, area, runner; separator rules; routing rule by visibility; processes for adding labels / runner origins) |
| [`troubleshooting.md`](troubleshooting.md) | Common issues + fixes (composition race; skip-ai-review carry-forward; runner-not-found; fabricated SHA pins; `gh: not found`; label install errors; Azure SWA quota; lychee bot-hostile hosts; v1.0.0 public-CLI gap; MD024; CHANGELOG rebase conflicts) |
| [`multi-project-guide.md`](multi-project-guide.md) | aidoc-flow-ci as company-wide CI library — three-layer architecture (library / project-governance / consumer); onboarding flow for new company projects; per-project decision boundaries |
| [`local-pre-push.md`](local-pre-push.md) | Canonical pre-push self-check pattern for consumers — local AI review via `claude` CLI mirrors CI's `ai-review.yml` gate to reduce iteration count; CI remains authoritative; reference implementation + hardening lessons + adoption prerequisites |
| [`security.md`](security.md) | Threat model, trust boundaries, fork-PR handling, secrets model, `pull_request_target` rationale, SHA-pinning, layered secret-scan defense |
| [`overrides.md`](overrides.md) | The 3 override modes (parameter / full replacement / custom workflow) with concrete examples per mode; what you cannot do; conflict resolution; examples in the wild |
| [`runners.md`](runners.md) | How to register self-hosted runner pools with the right labels; reference image (`aidoc-flow-runner:latest`) provisioning; per-origin cost/latency/CLI/fork-safety tradeoffs; scaling + adding new origins |
| [`architecture.md`](architecture.md) | How the pieces fit together: reusable-workflow model; the 11 shared workflows; trust + verdict flow (ai-review + composition); per-repo policy surfaces; versioning + tag scheme |
| [`WORKFLOWS.md`](WORKFLOWS.md) | **Workflow registry** — canonical enumeration of all 11 reusable workflows, per-repo applicability matrix, per-workflow skip-guidance, adoption sequencing for new repos, current pin state. Source-of-truth for CI-library capabilities. |

## Planned (drafted on demand, not preemptively)

These topics will get their own focused docs as concrete needs surface
(typically: a real consumer question, an incident, or a new release
that motivates the page). Drafting all 5 preemptively risks
documenting hypothetical patterns instead of real usage.

| Planned doc | Scope | Trigger |
| --- | --- | --- |
| `docs/architecture.md` | How `ai-review.yml` + `composition.yml` work together; trust gate; job dependencies; reusable-workflow pattern | First consumer asks "how does this work end-to-end" |
| `docs/runners.md` | How to register a self-hosted runner pool with the right labels; reference image (`aidoc-flow-runner:latest`) provisioning; per-origin cost / visibility tradeoffs | Founder onboards a second self-hosted pool, OR a new origin (Azure / AWS / Fargate) joins |
| `docs/overrides.md` | The 3 override modes (parameter / full replacement / custom workflow) — concrete examples per mode | First consumer asks how to customize for their case |
| `docs/security.md` | Trust gate semantics; fork-PR handling; secret model; `pull_request_target` vs `pull_request` choice; threat model | Security review by a consumer, OR an incident |
| `docs/migration.md` | v1.0.0 → v1.0.1 migration; v1.0.X → v1.1.0 (when MINOR ships) | When v1.0.1 ships |

## How to contribute a new doc

1. Pick a topic from "Planned" or propose a new one
2. Create `docs/<topic>.md` (one topic per file; short focused docs
   beat omnibus docs)
3. Add a row to "Available now" above
4. Add a `## Unreleased` `### Added` line in
   [`../CHANGELOG.md`](../CHANGELOG.md) documenting the new doc
5. PATCH-tag on the next `ci/vX.Y.Z` release

## Cross-references (design + governance)

The design rationale + rollout sequence for `aidoc-flow-ci` lives in
the operations repo (this repo is the artifact; operations owns the
plan):

- [`aidoc-flow-operations/ops/iplans/IPLAN-0017_unified-ci-flows.md`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017_unified-ci-flows.md)
  — full plan + per-phase rollout + claim ledger + revision log
- [`aidoc-flow-operations/ops/iplans/IPLAN-0017-CHARTER_aidoc-flow-ci.md`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/iplans/IPLAN-0017-CHARTER_aidoc-flow-ci.md)
  — charter explaining why a separate repo, ownership, versioning,
  consumer-vs-author roles
- [`aidoc-flow-operations/ops/DECISIONS.md`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/ops/DECISIONS.md)
  — operations decision log (e.g., `OPS-0049` no-GitHub-hosted-minutes
  for private; `OPS-0060` consume-from-aidoc-flow-ci supersession)
