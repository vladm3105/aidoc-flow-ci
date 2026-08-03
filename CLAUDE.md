# CLAUDE.md — aidoc-flow-ci

Persistent context for the aidoc-flow workspace **CI + governance-workflow
canon** library. Auto-loaded every session. Keep it short and current.

## What this repo is

The **canonical source** for the CI + governance-workflow rules the
aidoc-flow workspace shares. Ships reusable workflows (`ai-review`,
`composition`, `audit-trail-check`, `secret-scan`,
etc.), canonical config templates (CODEOWNERS, dependabot, branch
protection), canonical scripts (`pre_push_check.sh`, `apply-standards.sh`,
`parse-governance-table.py`), governance-file templates
(`CLAUDE.md.template`, `HANDOFF.md.template`, `DECISIONS.md.template`,
`ROADMAP.md.template`, `plans-README.md.template`), the ai-review rubric

- verdict schema at `ai-review/`, and per-language + per-tier rulebooks
in `docs/REPO_STANDARDS.md`.

Semver-tagged (`ci/vX.Y.Z`); consumers pin via `uses:
vladm3105/aidoc-flow-ci/.github/workflows/<file>.yml@ci/vX.Y.Z`.

**This is the workspace CI layer** — not a product, not shipping to
customers. Its consumers are the sibling aidoc-flow repos
(operations, business, framework, iplanic, iplan-runner,
iplan-standard, engramory, interlog, umbrella).

**Canonical-source disambiguation (workspace has TWO canonical repos —
do not confuse):**

- **`aidoc-flow-ci` (this repo)** = CI reusable workflows + config
  templates + canonical scripts + governance-file templates + ai-review
  rubric + REPO_STANDARDS static-settings + workflow-adoption + tier
  rulebook. When a consumer
  cites a canonical CI/workflow/template/script source, point here.
- **`aidoc-flow-operations`** = OPS-NNNN durable business decisions
  (governance-PR discipline, auto-merge default, multi-agent review
  dispatch, circuit-breaker, aidoc-flow-standard scope, audit-trail
  phrase, project-governance-canon ratification), multi-agent review
  prompt templates at `.claude/agents/review-prompts/` (per OPS-0067),
  cross-repo playbooks (T-C, T-C', T-D), autonomy-tiers table, AI-
  employees team registry. When a consumer cites an OPS-NNNN business
  decision or multi-agent review prompt template, point at operations.

Full disambiguation table + rule of thumb in `docs/REPO_STANDARDS.md`
§0 "Canonical source authority".

## Where things are

- `docs/REPO_STANDARDS.md` — the canonical rulebook (§1-§16).
- `install/` — canonical config templates + `apply-standards.sh` +
  `install.sh` bootstrap.
- `install/templates/` — per-file canonical templates (workflows,
  CODEOWNERS, branch protection, dependabot, governance-file
  skeletons).
- `.github/workflows/` — reusable workflow definitions (called by
  consumers via `uses:`).
- `scripts/` + `.github/workflows/` — canonical scripts + drift-check
  workflow (`pre_push_check.sh` + `standards-drift.yml`, etc.).
- `plans/` — per-initiative canon-evolution plans (PLAN-001, PLAN-002,
  PLAN-003, ...).
- `docs/troubleshooting.md` — recovery patterns (label-cycle §15, etc.).

## Per-repo governance — this repo owns its own continuity

The `aidoc-flow` workspace is **multi-repo**. Each repo governs its own
activity tracking; cross-session continuity is per-repo. The durable
surfaces for **this** repo:

| Surface | Path (in this repo) |
| --- | --- |
| Live HANDOFF | `HANDOFF.md` |
| TODO / backlog | `plans/` (per-initiative plans + GitHub issues — this repo's open issues **are** its backlog, whoever filed them; a finding below the promotion bar stays in the worked `plans/` entry, not in the tracker. Read the tracker with `gh issue list --state all --limit 200` — the `--limit 30` default truncates silently.) |
| Legacy FT queue (being retired) | `plans/FRAMEWORK-TODO.md` (still holds open entries; until its retirement lands, both surfaces are live) |
| Decisions log | `DECISIONS.md` |
| Plans | `plans/` |
| Changelog | `CHANGELOG.md` |
| Roadmap | `ROADMAP.md` |

Never in `tmp/` (transient). Never in the umbrella `aidoc-flow/`
(holds no dev). Cross-repo coordination captured here references
siblings by path (`../<repo>/`), never relocates their state.

## GitHub operations

Use the **GitHub CLI (`gh`)** as the default for all GitHub operations —
PRs, issues, reviews, releases, repo queries — not the GitHub MCP
servers (`github-tt`, `github-vl`) or raw API calls. If `gh` is
unauthenticated, run `gh auth login` rather than falling back to
MCP/API.

### Cross-repo defects get filed UPSTREAM (CI-0020, §18)

A defect this repo surfaces but does NOT own — in a sibling submodule,
an upstream spec, `operations` — gets a **GitHub issue on that repo**,
not just a line in `HANDOFF.md`/`DECISIONS.md`. The test is **ownership,
not severity**; a local workaround does not discharge it. Link the issue
number back here. Full rule + the CI-0014 incident that motivated it:
`docs/REPO_STANDARDS.md` §18.

**`gh issue create --body -` publishes a literal `-`** (exit 0, prints a
URL — it looks fine). Use `--body-file`, then read it back with
`gh issue view <N> --json body --jq '.body | length'`. Issues #305–#309
were all published empty this way. Same trap on `gh issue comment` /
`gh pr comment`.

Note the inbound direction too: consumers filing defects **against
canon** land here as issues, and this repo is the owner that must act on
them.

## Workspace standards (aidoc-flow canon — read the canonical rules directly)

Every workspace-standard rule below states (a) a one-sentence summary of
what it says + (b) the canonical file path to READ for the full rule.

- **OPS-0061 governance PR discipline** — ≤3 doc surfaces per governance
  PR + mandatory adversarial pre-push self-review on diff.
  → `../operations/CLAUDE.md` § "Governance PR discipline".
- **OPS-0062 AI-agent auto-merge default** — auto-watch + auto-merge
  green PRs the AI opens; 10-attempt cap; carve-outs for
  🟡/🔴/governance/cross-repo/spec.
  → `../operations/CLAUDE.md` § "AI agent auto-merge default".
- **OPS-0065 multi-agent automated review** — before every push, dispatch
  the diff-class-matched sub-agents in parallel.
  → `../operations/CLAUDE.md` — search `OPS-0065` (text landmark, lives
  under `## Autonomy tiers`)
  - `../operations/.claude/agents/review-prompts/INDEX.md`.
- **OPS-0066 3-cycle circuit-breaker** — cap review→fix→re-review loops
  at 3 cycles; escalate to founder if not converged.
  → `../operations/CLAUDE.md` — search `OPS-0066` (text landmark, lives
  under `## Autonomy tiers`).
- **OPS-0067 aidoc-flow-standard scope** — multi-agent review applies to
  ALL non-paused workspace repos.
  → `../operations/CLAUDE.md` — search `OPS-0067` (text landmark, lives
  under `## Autonomy tiers`).
- **OPS-0069 mandatory pre-push audit-trail phrase** — every push must
  carry either `Multi-agent self-review per OPS-0065 (<agents>): <verdict>`
  or `Self-review skipped per founder OK <reason>` in a commit message.
  Enforced locally by `scripts/pre_push_check.sh` (in this repo, canon
  source) + in CI by `.github/workflows/audit-trail.yml` → `call / verify`.
  → `../operations/CLAUDE.md` — search `OPS-0069` (text landmark, lives
  under `## Autonomy tiers`).
- **REPO_STANDARDS canonical rulebook** — this repo IS the canon source
  for CI + governance-workflow rules. Reference by section number.
  → `docs/REPO_STANDARDS.md`.

## Runner policy — private repos are self-hosted ONLY (no exceptions)

**Every private aidoc-flow repo (operations, business, iplanic, interlog)
MUST run CI on self-hosted runners — never `ubuntu-latest`.** GitHub-hosted
minutes on a private repo are OPS-0049 billing exposure and against workspace
policy (founder, 2026-07-11). The canonical private label is the verbose array
`["self-hosted", "ci-runner", "single-use"]` for both AI and non-AI jobs.

- As of `ci/v1.9.0` the `install/templates/workflows/*-private.yml` templates
  ship the real `["self-hosted","ci-runner","single-use"]` label. **Earlier**
  releases shipped a `"runner-self"` placeholder — NOT a registered label, so a
  caller left on `runner-self` (or on the reusable's `ubuntu-latest` default)
  queues forever. If you see `runner-self` in an installed caller, replace it
  with the real pool array.
- **A job with no matching runner queues forever, and `timeout-minutes` does not
  save it** — the timeout clock starts when the job *starts*, so a job that never
  starts never times out. The symptom is a check pinned on "Expected — Waiting
  for status to be reported", not a failure.
- **Never "fix" a bricked private-repo gate by falling back to `ubuntu-latest`.**
  If a private repo has no pool yet, the fix is to **register the pool**
  (`../operations/scripts/ci-runner/run-ephemeral.sh`, labels
  `self-hosted,ci-runner,single-use`), not to switch to GitHub-hosted.
- Public repos (engramory, framework, iplan-standard, iplan-runner) run on
  `ubuntu-latest` — **except** the ai-review *review* job, which may run on the
  ephemeral self-hosted pool (see below). Full routing table + registration
  steps: `docs/runners.md`.

## Ephemeral single-use runners — what a fresh AI session must know

The self-hosted pool is **ephemeral single-use** (`operations/scripts/ci-runner/run-ephemeral.sh`):
a fresh `--rm` container per job — no host mounts, no docker socket, non-root,
CPU/mem/PID caps — runs **one** job, then is destroyed. Consequences a fresh
session must not re-derive or get wrong:

- **No state carries between jobs.** Every job is independent; the reusables
  `curl`-fetch assets into a fresh workspace — never assume prior-job files.
- **Tools are baked into `aidoc-flow-runner:latest`** (`python3`, `gh`, `jq`,
  `curl`, `git`, `ripgrep`; verified present). ai-review v2 hard-needs `python3`
  (the LiteLLM client); the `ci/v2.0.1` preflight names the cause if an image
  lacks it. The image is built **per host** (no registry push) — rebuild when
  tools update. A missing tool ≠ a code failure — check the image first.
- **Concurrency = one job per supervisor instance (SERIAL).** A PR fans out to
  ~8 jobs; on a private repo (all jobs self-hosted) a single `ci-runner@<repo>`
  instance runs them **one at a time**. Run **N parallel instances per repo**
  (sized to peak PR job-count, ~6–8) to parallelize — else PR feedback serializes.
  Do NOT "fix" slow feedback by moving jobs to `ubuntu-latest` on a private repo.
- **LiteLLM route:** the container uses the default docker bridge, so it reaches
  the host proxy at **`http://172.17.0.1:4001`** (the `LITELLM_BASE_URL` secret).
  Loopback (`127.0.0.1`/`localhost`) resolves to the *container*, not the host —
  it works when tested from the host and fails only in CI.
  It is HTTP on the private bridge → callers set
  `litellm_allow_insecure_http: true`. **This is scoped by the URL SCHEME, not by
  repo visibility:** any caller whose `LITELLM_BASE_URL` is `http://` needs the
  flag, and since PLAN-013 puts the whole AI flow on the shared pool, that
  includes every PUBLIC repo too — not just the private trio. (CI-0017.)

**PUBLIC repos run the AI-flows FULLY on the ephemeral self-hosted pool (PLAN-013,
`ci/v2.2.0`) — trust job included. This is safe and is NOT the "untrusted code on
self-hosted" anti-pattern**, because a fork never reaches a job that executes PR
code: for `ai-review` a fork triggers only the `trust` job, which checks out the
**trusted config repo** (never the PR head) and reads PR metadata — **zero PR
code**; the review job is `needs: trust`-gated and forks are never trusted;
`doc-maintainer`/`docs-sync` are post-merge so forks can't trigger them. The
AI-flows ship as ONE protected template (`runner_labels_routine`/`_review` both
self-hosted), no `-public`/`-private` split, so a visibility flip is a no-op.
**The fork-code-running lint flows (`markdown-lint`, `links`, `pre-commit`,
`on: pull_request`) MUST stay `ubuntu-latest` on public repos** — they run the
PR's own files (a fork's included), so moving THEM to self-hosted is the real
untrusted-code-on-self-hosted leak. **NEVER** converge a fork-code-executing job to
self-hosted on a public repo. Full boundary: `docs/security.md` §3 + `docs/runners.md` §5a.

## Repo-specific rules (canon-source discipline)

**Canon changes are load-bearing across the workspace.** Every
change to `install/templates/*`, `.github/workflows/*.yml`, or
`docs/REPO_STANDARDS.md` propagates to every consumer that pins the
next `ci/vX.Y.Z` tag. Discipline:

- **Every canon-body change ships with a `docs/REPO_STANDARDS.md`
  update** — either amending an existing section or adding a new one.
  The rulebook + the template must stay in sync; the CI
  `standards-drift` check enforces detection.
- **Semver discipline:** breaking changes to workflow inputs / config
  schema / expected consumer surfaces = MAJOR bump. Additive
  changes = MINOR. Bug fixes without schema changes = PATCH.
  Tagged via `git tag ci/vX.Y.Z` + GitHub release.
- **Rollout waves apply to canon adoption.** Per PLAN-002 §5.5 for CI +
  governance-workflow canon; per PLAN-003 §5.5 for project-governance
  file canon. Wave 0 (this repo) self-adopts BEFORE Wave 1+ consumers
  pull. The canon-source dogfoods its own canon.

## Durable traps — do not re-derive these

Facts about this repo and its toolchain, each of which cost a session at least
once. They live here, not in `HANDOFF.md`: under CI-0028 the handoff is
regenerated wholesale at every wrap, so anything durable parked there is
re-summarised or silently dropped on each pass. A trap graduates here once it
has settled — measured, reproduced, and not expected to change.

### Adopting a canon release in a consumer

- **`--repin` and `--update` deliver different things, and neither is the
  general answer.** `--repin` rewrites `uses:` tag strings only, so it **cannot**
  deliver a change that lives in a caller **body** — the CI-0025/#329
  concurrency fix did, and a `--repin`-only adoption silently misses it.
  `--update` replaces whole caller bodies and therefore clobbers a consumer's
  local `runner_labels_*`, `permissions:`, `config-path:` and job splits.
  Decide per release by asking whether the release changed caller bodies; when
  it did, `--update --non-interactive` **then re-apply the local edits**.
  Without a TTY, a bare `--update` defaults to KEEP (FT-39) and delivers nothing.
- **Actions Runner `>= 2.327.1` is a hard floor.** The reusables call node24
  actions; below the floor jobs die in `ai-review`'s *first* job with an error
  that names neither the action nor the floor. Check with
  `gh api repos/<owner>/<repo>/actions/runners --jq '.runners[].version'`.
  GitHub-hosted runners are unaffected. `docs/runners.md` §2,
  `docs/troubleshooting.md` §19.

### Gates that measure the wrong thing

- **`pre_push_check.sh` matches a PHRASE, not the work.** A commit body reading
  `Multi-agent self-review per OPS-0065: skipped` satisfies the gate while
  declaring the opposite — it is `grep -qF` on the prefix (`:211-213`). The gate
  cannot distinguish the phrase from the work, so the discipline is yours, not
  its. Every time the review was then actually run, it found something real.
- **`governance_check` has no automated reader.** It verifies that every path a
  repo's `CLAUDE.md` declares exists, has one call site
  (`install/apply-standards.sh:433`), and nothing in `.github/workflows/`
  invokes `apply-standards.sh` — `standards-drift-self.yml` runs
  `sync/check-standards-drift.sh`, which never reaches it. Run it by hand:
  `python3 install/parse-governance-table.py CLAUDE.md --repo-root .`.
  Tracked as [#355](https://github.com/vladm3105/aidoc-flow-ci/issues/355).
- **A governance-table row is machine-parsed, so write it as
  `` `path` (annotation) ``.** The parser reads a row's whole path cell as a
  path, stripping only a trailing `§N`/`#anchor` (`:172`) or a parenthesized
  annotation (`:180`). A prose cell — including one starting `**` — parses as a
  path and fails. Measured; see CI-0028.
- **`scripts/ft30-dry-run.sh` asserts the bootstrap COMPLETED, not that it
  installed the right file set.** A run that silently dropped `ai-review.yml`
  passes every criterion. Tracked as
  [#358](https://github.com/vladm3105/aidoc-flow-ci/issues/358).

### Destructive on canon specifically

- **Never run `apply-standards.sh --apply --tier product` on canon.** It PUTs
  `branch-protection-product.json`, which requires `ai-review` and `composition`
  — checks canon does **not** self-run — so it hangs every canon PR, and it
  clobbers FT-52's deliberate canon-specific protection profile. Use the
  per-section `gh api` PUTs, or `--skip-branch-protection`. The `access` section
  is skipped on canon anyway (PUBLIC → 422).
- **A release prep PR shows BLOCKED, not merely red, and that is by design.**
  Since FT-52 protected `main`, 4 of the 5 required contexts come from
  self-pinned callers that `startup_failure` and are therefore never reported —
  the FT-21 chicken-and-egg: they reference a tag that does not exist yet.
  `enforce_admins: false` exists precisely so
  `gh pr merge <N> --squash --delete-branch --admin` still works. Those
  `startup_failure` runs are **not retryable**; the post-release push is what
  re-triggers them green. `docs/RELEASE_CHECKLIST.md` § "Tag + release".

### Process

- **Review sub-agents mutate the shared working tree.** They run `git stash` /
  `git add`, which can unstage code between your `git add` and your
  `git commit` — a fix can silently fail to land. Always `git add -A` and diff
  against what was reviewed **after** the agents finish, before committing.
  (Found as the FT-45 incident: PR #277 dropped its code to exactly this race,
  and #278 had to land it separately.)
- **Folding a review finding is a code change and needs the same scrutiny as
  one.** A Pass-2 review has repeatedly found defects introduced by the Pass-1
  *fold* — including a fix that re-created its own defect. Re-review the fold,
  not just the original.
- **A review sub-agent will cite a convention that does not exist.** One quoted a
  `CHANGELOG.md` rule verbatim ("Its status lives in the plan header, not here")
  that `grep` finds nowhere in the file, to support otherwise-sound advice.
  Folding it unchecked would have written a fabricated convention into canon
  under the authority of a citation. **Grep the cited string before folding it**
  — the finding can be right and its evidence invented.
- **A stub that controls only what a command returns tests nothing about how it
  was called.** A harness stubbing `gh`'s return value but not its arguments let
  three separate live mutations stay green.
- **Prose volume is a defect surface.** #322 took five review passes; only the
  *first* found a code defect. Every later pass corrected claims written *about*
  the fix, until the last recommended **cutting** rather than correcting. Prefer
  one scoped statement plus pointers to an exhaustive narrative.
- **`DECISIONS.md` is authoritative; never keep a second copy of it.** The
  handoff carried a "Recent decisions" excerpt that sat at CI-0011 while
  CI-0012..CI-0024 landed, contradicting the top of its own file. Removed under
  CI-0028. Link to `DECISIONS.md`; do not summarise it.

## Session handoff

Sessions run in ephemeral containers — **only committed + pushed work
survives**. Start each session by reading `HANDOFF.md`; refresh it at
milestones and before any context compaction. Commit messages must
not contain model identifiers.

**`HANDOFF.md` is regenerated, not appended (CI-0028).** It is a briefing for a
fresh session with zero context, answering two questions in order: what the last
session did, and what to do next. Every volatile claim carries the command that
re-derives it — a carried-forward claim otherwise reads as freshly verified,
which is how the headline sat at "0 open issues" for three days against eight.
Target well under ~200 lines; size is a defect, and the cause is almost always
retained history. Git is the archive.
