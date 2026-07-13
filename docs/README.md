# aidoc-flow-ci documentation

Index of `aidoc-flow-ci` documentation. The repo's three top-level
docs cover consumer-facing intro, install, and release notes:

| Doc | Scope |
| --- | --- |
| [`../README.md`](../README.md) | Consumer-facing intro: what ships, how to install, override modes, drift detection |
| [`../install/README.md`](../install/README.md) | `install/install.sh` usage + next steps |
| [`../CHANGELOG.md`](../CHANGELOG.md) | Release notes per `ci/vX.Y.Z` tag |
| [`MIGRATION_v2.0.0.md`](MIGRATION_v2.0.0.md) | Migration guide from `ci/v1.x` to `ci/v2.0.0` (LiteLLM unification — breaking change) |
| [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md) | Pre-tag checklist for cutting a `ci/vX.Y.Z` release |

This `docs/` tree covers reference + design topics.

## Available now

| Doc | Scope |
| --- | --- |
| [`../LABELS.md`](../LABELS.md) | PR + runner label conventions (three namespaces: state, area, runner; separator rules; routing rule by visibility; processes for adding labels / runner origins) |
| [`troubleshooting.md`](troubleshooting.md) | Common issues + fixes (composition race; skip-ai-review carry-forward; runner-not-found; fabricated SHA pins; `gh: not found`; label install errors; Azure SWA quota; lychee bot-hostile hosts; v1.0.0 public-CLI gap; MD024; CHANGELOG rebase conflicts) |
| [`multi-project-guide.md`](multi-project-guide.md) | aidoc-flow-ci as company-wide CI library — three-layer architecture (library / project-governance / consumer); onboarding flow for new company projects; per-project decision boundaries |
| [`local-pre-push.md`](local-pre-push.md) | Canonical pre-push self-check pattern for consumers — bash-only OPS-0069 audit-trail phrase check + 4 mechanical linters (markdownlint / yamllint / actionlint / shellcheck); no CLI dependency; wired via `.pre-commit-config.yaml default_install_hook_types`; belt-and-suspendered by CI reusable `call / verify` |
| [`security.md`](security.md) | Threat model, trust boundaries, fork-PR handling, secrets model, `pull_request_target` rationale, SHA-pinning, layered secret-scan defense |
| [`overrides.md`](overrides.md) | The 3 override modes (parameter / full replacement / custom workflow) with concrete examples per mode; what you cannot do; conflict resolution; examples in the wild |
| [`runners.md`](runners.md) | How to register self-hosted runner pools with the right labels; reference image (`aidoc-flow-runner:latest`) provisioning; per-origin cost/latency/CLI/fork-safety tradeoffs; scaling + adding new origins |
| [`architecture.md`](architecture.md) | How the pieces fit together: reusable-workflow model; the 12 shared workflows; trust + verdict flow (ai-review + composition); per-repo policy surfaces; versioning + tag scheme |
| [`WORKFLOWS.md`](WORKFLOWS.md) | **Workflow registry** — canonical enumeration of all 12 reusable workflows, per-repo applicability matrix, per-workflow skip-guidance, adoption sequencing for new repos, current pin state. Source-of-truth for CI-library capabilities. |
| [`REPO_STANDARDS.md`](REPO_STANDARDS.md) | **Repo standards canon** — the static-settings rulebook for every workspace repo. 6-tier taxonomy (governance / product / ops-private / umbrella / bootstrap / paused) drives per-tier requirements for branch protection, GitHub security settings, labels, dependabot, CODEOWNERS, PR template, Actions permissions, merge/cleanup settings, `.gitignore`/`.gitattributes`. Companion to `WORKFLOWS.md` (workflow-side compliance) + `aidoc-flow-operations/docs/REPO_ONBOARDING.md` (CI activation). Per PLAN-001. |

## Planned (drafted on demand, not preemptively)

New docs get drafted as concrete needs surface (a real consumer
question, an incident, or a release that motivates the page) rather
than preemptively — so we document real usage, not hypothetical
patterns. All previously-listed planned docs (`architecture`, `runners`,
`overrides`, `security`) now exist under "Available now". No docs are
currently queued; per-release migration guidance lives in
[`docs/MIGRATION_v2.0.0.md`](MIGRATION_v2.0.0.md) for the
`ci/v2.0.0` LiteLLM unification (breaking change).

## How to contribute a new doc

1. Propose a topic (a real need, not a hypothetical)
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
