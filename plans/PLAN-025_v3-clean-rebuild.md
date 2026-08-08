# PLAN-025 — `ci/v3.0.0` clean rebuild: composite-action architecture + new documentation set

**Status:** Draft
**Owner:** canon (aidoc-flow-ci)
**Origin:** founder directive 2026-08-08 — implement the target configuration as a
new release built from scratch, archiving the existing flows so stale docs cannot
confuse adopters.
**Change level:** C3 (new major; every consumer surface changes)
**Supersedes:** PLAN-024 Phases D, E, F, G (absorbed here). PLAN-024 Phases A, B,
C ship **first and separately** — see §7.

## 1. Why a rebuild, and the one risk that governs it

The current library is 16 reusable workflows, 25 templates and a 2,700-line
rulebook accreted over ~2.16 releases. The founder's rationale is that
incremental edits leave stale documentation that misleads adopters, and the
measured evidence supports it: PLAN-024 found canon telling adopters to install a
flow being deleted, a rulebook section describing a superseded delivery model,
and three different template naming conventions in one directory.

**The governing risk: this library's apparent redundancy is mostly encoded
defect history.** PLAN-024 proposed removing structure four times — the
`-public`/`-private` pairs, the naming rule, a `python-tests.yml` reusable, and
the whole of Phase G — and independent review withdrew every one, because each
target was a fix for a measured failure. A from-scratch rebuild is the same error
at library scale, unless it is explicitly a **port against an inventory**.

**Therefore the rule for this plan: §2 is the acceptance criterion.** No rebuilt
artifact ships until every defense in §2 is either carried forward or has a
written reason for being dropped. "We rewrote it and it looks cleaner" is not a
reason.

## 2. Defense inventory — carry or consciously drop, never silently lose

Each row is a defect this library already paid for. The rebuild must state, per
row, **carried** or **dropped + why**.

> **P1 SIGNED OFF 2026-08-08 — all 19 defenses CARRIED, none dropped.**
> The rebuild changes **packaging** (reusable workflow → composite action) and
> **job count**, not defenses. That is the finding: nothing in the current
> library was found to be safely droppable, which is consistent with PLAN-024's
> four withdrawals. Two rows gained sharper meaning under the new architecture:
>
> - **D7 binds `quick-gates`.** It runs `pre-commit` against the PR's own files,
>   which is fork-code execution — so on a public repo `quick-gates` **must** be
>   `ubuntu-latest`. Only `security` and `ai-review` may take the self-hosted
>   pool there.
> - **D1 therefore still applies.** Because `quick-gates` and `security` want
>   different runner labels by visibility, the v3 callers still need
>   `-public`/`-private` variants, or `install.sh --update` re-creates the
>   queue-forever defect on private consumers.

| # | Encoded defense | What it prevents | Cite |
| --- | --- | --- | --- |
| D1 | `-public`/`-private` template variants | `install.sh --update` re-applies the label-less generic → private jobs queue forever | Claim 1 |
| D2 | Literal template names in `install.sh` (never derived) | Canon ships three naming shapes; derivation is wrong for at least one | Claim 2 |
| D3 | CI-0025 / §23 concurrency **allowlist** (not blanket cancel) | A cancelled required context is not success; the rollup stays FAILURE and the PR is `--admin`-only | Claim 3 |
| D4 | Job **id** is the required-context name | Renaming silently un-satisfies branch protection, which never fires again | Claim 4 |
| D5 | SHA-pinned `uses:` and pre-commit `rev`s | A moved tag reaches the whole fleet in one CI cycle; pre-commit runs the upstream build backend at install time | Claim 5 |
| D6 | ai-review verdict step `FATAL=1` (fail closed) | A reviewer-infrastructure failure must not render a green required check | Claim 6 |
| D7 | Fork-code-executing flows stay `ubuntu-latest` on public repos | Untrusted PR code on the self-hosted pool | Claim 7 |
| D8 | `gitleaks git`, not `gitleaks dir` | Working-tree-only scanning misses history (CI-0016) | Claim 8 |
| D9 | Callee `permissions:` are an intersection ceiling | A callee capped at `read` can never be raised by a caller; the step dies under `pipefail` (CI-0015) | Claim 9 |
| D10 | Hook-block marker version as refresh key | An adopted consumer freezes forever; canon changes never reach it | Claim 10 |
| D11 | Commit-stage hooks must exist in the fragment | Otherwise `--all-files` matches zero hooks and the required check "exited 0 while inspecting nothing" | Claim 11 |
| D12 | `dep-scan` zero-coverage guard | A scanner that finds no manifests must fail loud, not report clean | Claim 12 |
| D13 | Own scanners are MUST-HAVE (founder, PLAN-014) | Deleting them cancels a founder-owned graduation step | Claim 13 |
| D14 | `fail-on-findings` is a *default*, and the flow honours it with `exit 1` | Treating report-only as "cannot fail" | Claim 14 |
| D15 | Implicit `bash -e` in every `run:` step | `set -e` kills a step at the first non-zero, before a guard can forgive it | Claim 15 |
| D16 | `timeout-minutes` does not save a **queued** job | The clock starts when the job starts | Claim 16 |
| D17 | Actions Runner `>= 2.327.1` floor | node24 actions die with an error naming neither the action nor the floor | Claim 17 |
| D18 | LiteLLM at the docker bridge, not loopback | Loopback resolves to the container; works on the host, fails only in CI (CI-0017) | Claim 18 |
| D19 | Live branch protection ≠ the templates | Canon's `main` requires `call / markdownlint` and `suite`, which appear in no template | §3 below |

**D19 is new to this plan and was the defect that killed PLAN-024 Phase G.** Every
step of this rebuild that touches a required context reads
`gh api repos/<r>/branches/<b>/protection`, never the templates.

## 3. Target architecture

### 3.1 The lever: composite actions

Canon currently ships **zero composite actions** — every check is a
`workflow_call` reusable, and a reusable always gets its own runner. That is the
root of the provisioning cost: on `operations`, `audit-trail` takes ~167s to run
a `grep`, almost entirely provisioning.

| Mechanism | Runner cost |
| --- | --- |
| Reusable workflow (16× today) | one runner per check |
| Composite action | shares the caller's runner |

The rebuild ships the lightweight checks as **composite actions** and keeps
reusable workflows only where a separate runner, a separate permission set or a
separate trust boundary is actually required.

### 3.2 CI: 12 PR jobs → 4

**Corrected during implementation 2026-08-08: 12 → 5 jobs, not 4.** Only checks
sharing a **trigger** can share a job. `composition` fires on
`pull_request_review` + `workflow_run`, never `pull_request` (Claim 21), so it
**cannot** join `quick-gates` and stays its own workflow. An earlier draft of
this table listed it inside `quick-gates`; that was wrong.

| Job | Composite actions it runs | Trigger | Required context |
| --- | --- | --- | --- |
| `quick-gates` | pre-commit `--all-files`, audit-trail verify, markdownlint (cli2), links | `pull_request` | `call / quick-gates` |
| `security` | gitleaks (full history), osv-scanner, trivy, semgrep | `pull_request` | `call / security` |
| `composition` | unchanged — different trigger, cannot consolidate | `pull_request_review`, `workflow_run` | `call / composition` |
| `ai-review` | unchanged — separate runner, own trust gate | `pull_request_target` | `call / ai-review` |
| `auto-merge` | unchanged — event-driven, no PR cost | `workflow_run` | none |

**Checkout is the caller's, and it must satisfy the STRICTEST consumer.**
Composite actions share the job's working tree, so `quick-gates` checks out once
for all four. `audit-trail` needs `fetch-depth: 0` at
`github.event.pull_request.head.sha` — its full-history fork-PR false-pass guard
(Claim 22) — so the shared checkout takes those settings. **Each action must
verify the precondition it depends on and fail loudly if unmet**, rather than
assume it: a consolidated job that silently checked out shallow would weaken the
check while still reporting green, which is the exact defect class §2 exists to
prevent.

`links` also carries a `schedule` trigger. That is unaffected — the scheduled
caller invokes the same composite action in its own small workflow.

Off the PR path: `codeql` (push-to-main + weekly only — report-only and
GitHub-native), `standards-drift` (weekly), `docs-sync` (post-merge),
`labeler` (event-driven).

**Also drop the redundant `push: branches: [main]` trigger** wherever a flow also
runs on `pull_request`: under squash-merge those scan identical content minutes
apart.

### 3.3 Local: comprehensive and fail-closed

**Commit stage:** `check-yaml`, `check-json`, `check-toml`, `end-of-file-fixer`,
`trailing-whitespace`, `check-merge-conflict`, `check-added-large-files`,
`mixed-line-ending`, `detect-private-key`, **`markdownlint-cli2`**, `yamllint`,
`actionlint`, `shellcheck`, `ruff` + `ruff-format`, `gitleaks` (working tree).

**Pre-push:** `pre_push_check.sh`, `bandit`, audit-trail phrase.

Two rules that make the local layer real rather than decorative:

1. **Fail closed on a missing tool.** Today checks 1–4 of `pre_push_check.sh`
   "skip with notice", so the layer silently evaporates on a machine without
   `actionlint`. Hard-fail with an install hint instead.
2. **Tool parity is mandatory.** Local markdownlint must be **cli2 with canon's
   `.markdownlint.json`** — the ecosystem's usual hook is cli1, with different
   ignore semantics. A mismatch means local passes and CI reds, which trains
   people to bypass hooks.

### 3.4 Security posture

- The three own scanners **graduate to `fail-on-findings: true`** (PLAN-014
  Phase 5 — a founder step, and the single largest security gain available).
- `gitleaks` gains a local working-tree pass; CI keeps full history (D8).
- **`actionlint` becomes enforced** — it currently has no enforcement anywhere,
  in a library whose product is GitHub workflows.
- `bandit` runs pre-push, before code leaves the machine.
- `ai-review` unchanged.

Net: ~12 checks (three unable to fail) → **~20 checks, all able to fail**, on
**4 PR jobs instead of 12**.

## 4. Documentation set

### 4.1 New

A rebuilt set, written for an adopter who has never seen v2:

| Doc | Replaces |
| --- | --- |
| `docs/v3/ARCHITECTURE.md` | `architecture.md`, parts of `WORKFLOWS.md` |
| `docs/v3/ADOPT.md` | `AI_CI_DEPLOYMENT.md`, `install/README.md`, `UPDATE_GUIDE.md` |
| `docs/v3/FLOWS.md` | `WORKFLOWS.md` — the 4-job model and every composite action |
| `docs/v3/LOCAL.md` | *(new — the local layer has no doc today)* |
| `docs/v3/SECURITY.md` | `security.md` |
| `docs/v3/RUNNERS.md` | `runners.md` |
| `docs/v3/RULES.md` | `REPO_STANDARDS.md`, re-derived against the v3 surface |
| `docs/MIGRATION_v3.0.0.md` | *(new — required by the release checklist for a MAJOR)* |

### 4.2 Archived, not deleted

v2 docs move to `docs/v2/` with a banner: *"Describes `ci/v2.x`. The current
release is `ci/v3.x` — see `docs/v3/`."* They stay because ten repos remain
pinned to v2 tags until they migrate, and a v2 adopter debugging a v2 pin needs
v2 docs.

### 4.3 Untouchable — append-only

**`CHANGELOG.md`, `DECISIONS.md`, `docs/MIGRATION_v2.0.0.md` are history and are
never rewritten, reordered or scrubbed.** They are the only surviving record of
why the §2 defenses exist. Correct anything wrong in them with a new dated entry.
A rebuild that scrubs them destroys the evidence that makes §2 auditable.

### 4.4 The rulebook is re-derived, not copied

`REPO_STANDARDS.md` is 2,700 lines, much of it incident narrative attached to
rules. `docs/v3/RULES.md` states each **rule** with a one-line cause and a link
into `DECISIONS.md`/`CHANGELOG.md` for the incident. **Every §2 row must appear
as a rule.** That mapping is the acceptance test for §4.4.

## 5. Phases

**P1 — Defense inventory sign-off.** Complete §2: for each row, carried or
dropped-with-reason. **Nothing is built before this is signed off.** It is the
plan's whole safeguard against repeating PLAN-024's four withdrawals.

**P2 — Composite actions.** Build `actions/<name>/action.yml` for each
lightweight check. Each carries its §2 defenses (D5 pinning, D15 `bash -e`,
D3 where it owns concurrency). Unit-test via `tests/`.

**P3 — The four callers.** `quick-gates`, `security`, `ai-review`, `auto-merge`
as templates. D3's allowlist and D4's job-id discipline apply to every one.

**P4 — Local layer.** New hook block, marker bumped (D10), fail-closed
`pre_push_check.sh`, cli2 parity. **Ships before P5** — the local layer must be
in place before CI consolidation changes what adopters rely on.

**P5 — Documentation set.** §4, including the §2→RULES mapping.

**P6 — Release `ci/v3.0.0`.** Migration guide, LiteLLM smoke (MAJOR gate), FT-30
cold-start dry run (🔴 founder). Canon self-adopts first (Wave 0).

**P7 — Per-repo required-context migration.** The only irreversible step:

1. Add the new job **alongside** the old
2. Add the new context to **live** protection; observe green
3. Remove old contexts from live protection
4. Only then delete the old callers

Read live protection at every step (D19). `enforce_admins: true` on consumer
tiers means there is no `--admin` escape if this is got wrong.

## 6. Non-goals

- **No check is deleted.** Consolidation reduces jobs, not coverage. The three
  scanners get *stronger* (D13, D14).
- **`CHANGELOG.md` / `DECISIONS.md` are not touched** beyond appending.
- **v2 is not deleted** — tags remain, docs are archived, consumers migrate on
  their own schedule.

## 7. Relationship to PLAN-024

PLAN-024 Phases **A** (eliminate `doc-maintainer`), **B** (`docs-sync` reduction)
and **C** (`ci/v3.0.0` release mechanics) **ship first and separately.** Building
v3 around a flow being deleted would waste the work, and A already owns the
`litellm-smoke` circularity and the FT-30 precondition that P6 inherits.

PLAN-024 Phases **D, E, F, G** are **superseded** by this plan: D's `ai-review`
decomposition is moot once job consolidation is the organising idea, E and F are
absorbed into §3.3 and §4, and G was withdrawn outright.

**PLAN-024's status must be updated in the same change that lands this plan** —
its surviving phases re-scoped, its superseded ones marked, per plan-status
governance.

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | The -private variants exist because --update otherwise reverts private repos to ubuntu-latest | `install.sh --update` unsafe on a private consumer | docs/REPO_STANDARDS.md:273 |
| 2 | Canon ships three naming shapes; the bootstrap must name templates literally | `canon ships three naming shapes` | docs/REPO_STANDARDS.md:1475 |
| 3 | The concurrency allowlist exists because a cancelled required check is not success | `CI-0025 / REPO_STANDARDS §23` | install/templates/workflows/markdown-lint.yml:33 |
| 4 | The job name string is the required context; renaming silently un-satisfies protection | `This exact string is the required-status-check context` | ../framework/.github/workflows/acceptance.yml:37 |
| 5 | Hook revs are SHA-pinned because pre-commit executes the upstream build backend at install time | `SHA-pinned, not tag-pinned` | install/templates/pre-commit-hook-block.yaml:47 |
| 6 | The ai-review verdict step fails closed to keep the required check red | `ai-review` IS the required status context | .github/workflows/ai-review.yml:741 |
| 7 | Fork-code-executing lint flows must stay ubuntu-latest on public repos | `NEVER` | CLAUDE.md:215 |
| 8 | secret-scan scans full commit history, not the working tree | `Full-clone scan (fetch-depth: 0)` | .github/workflows/secret-scan.yml:19 |
| 9 | A callee's permissions are an intersection ceiling a caller cannot raise | `pull-requests` MUST be `write` here | .github/workflows/docs-sync.yml:59 |
| 10 | The hook-block marker version is the refresh key | `the REFRESH KEY` | install/templates/pre-commit-hook-block.yaml:3 |
| 11 | A fragment with no commit-stage hook made the required check exit 0 while inspecting nothing | `exited 0 while inspecting nothing` | install/templates/pre-commit-hook-block.yaml:30 |
| 12 | dep-scan fails loud when it finds no manifests | `expect-manifests` | .github/workflows/dep-scan.yml:28 |
| 13 | Own scanners are a founder MUST-HAVE with graduation a founder step | `our own scanners are MUST-HAVE` | plans/PLAN-014_security-scanning-coverage.md:5 |
| 14 | fail-on-findings is a default the flow honours with exit 1, not an incapacity | `fail-on-findings` | .github/workflows/trivy-scan.yml:27 |
| 15 | GitHub runs every run: step under an implicit bash -e | `bash -e` | docs/REPO_STANDARDS.md:2282 |
| 16 | timeout-minutes cannot fire on a job that never starts | `A job with no matching runner queues forever` | CLAUDE.md:161 |
| 17 | Actions Runner 2.327.1 is a hard floor for the node24 reusables | `2.327.1` | CLAUDE.md:257 |
| 18 | The LiteLLM route is the docker bridge; loopback resolves to the container | `172.17.0.1:4001` | CLAUDE.md:194 |
| 19 | markdown-lint is named among the caller templates feeding a required context | `the eight caller templates feeding a` | docs/REPO_STANDARDS.md:2154 |
| 20 | The pre-commit reusable runs every hook against every file | `pre-commit run --all-files --show-diff-on-failure` | .github/workflows/pre-commit.yml:100 |

## Implementation log

### 2026-08-08 — P1 signed off; P2 started (branch `feat/v3-composite-actions`)

**Founder clarification:** "from scratch" means a fresh release without the old
issues — **copying well-established flows forward is expected.** That is what
this plan does: step bodies are ported **verbatim**, only the packaging changes.
It removes the rewrite risk §1 warns about, and §2 becomes a port checklist
rather than a re-derivation exercise.

**Landed:**
- `actions/markdownlint/action.yml` — verbatim port of the v2 reusable's run
  body. Carries D5 (SHA-pinned `uses:`), D15 (`set -euo pipefail`), the
  env-not-interpolation injection defense, `noglob` glob collection, and
  `--ignore-scripts`. Does **not** check out (§3.2).
- `install/templates/workflows/quick-gates.yml` — the consolidating caller.
  Carries D3 (§23 allowlist, not blanket cancel), D4 (job id = context), D7
  (`ubuntu-latest` on public because it executes PR code), D9 (least-privilege
  grant), and the strictest-consumer checkout (`fetch-depth: 0` at the PR head
  for audit-trail's fork-PR guard).
- `tests/test_actions.sh` — 18 assertions, one per §2 defense the composite
  packaging makes newly assertable. Auto-discovered by `tests/run.sh`.

**Mutation-tested, because a suite that only passes proves nothing.** Four
mutations, all killed, baseline restored green afterwards:

| Mutation | Caught by |
| --- | --- |
| unpin `setup-node` SHA → `@v7` | D5 assertion |
| drop `shell: bash` | run/shell count equality |
| `markdownlint-cli2` → `markdownlint-cli` | both tool-parity assertions |
| `cancel-in-progress: true` | both D3 assertions |

**Correction found during implementation, folded into §3.2:** `composition`
fires on `pull_request_review` + `workflow_run`, never `pull_request`
(Claim 21), so it **cannot** share `quick-gates`' job. Target is **12 → 5 jobs,
not 4**. An earlier draft of §3.2 had it inside `quick-gates`; that would have
consolidated a check into a job whose trigger never fires for it.

**Remaining in P2 (mechanical ports, bodies already proven):**
`actions/pre-commit` (33-line body), `actions/links` (66), `actions/audit-trail`
(135 — needs the checkout-precondition guard §3.2 requires), then the `security`
job's four. `composition` (403 lines) is **not** ported — it stays a reusable.

## Review log
