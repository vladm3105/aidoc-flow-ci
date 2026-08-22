# LABELS.md — `aidoc-flow-ci` label conventions

This document defines the label conventions used by `aidoc-flow-ci`
across **two distinct namespaces**: GitHub **issue + PR labels** (applied
by the ai-reviewer + labeler workflows, and by hand on issues) and GitHub
**runner labels** (used in `runs-on:` to select runner pools).

> **Issue labels and PR labels are ONE GitHub namespace, not two.** A repo
> has a single label set; an issue and a PR draw from the same pool, and
> `gh label list` returns both. The split below is a **usage** distinction —
> which surface each group is applied to and by what — not a mechanical one.
> Two consequences that get re-derived wrong: a name collision between an
> issue label and a PR label is a real collision, and `labeler.yml` fires on
> pull-request events only — never on `issues` or `issue_comment` — so a bare
> word appearing on an **issue** is never a diff-class label. (The caller
> template's trigger is `pull_request_target`, **not** `pull_request`:
> `install/templates/workflows/labeler.yml:17-23` explains why — `pull_request`
> downgrades `GITHUB_TOKEN` to read-only on fork PRs and labeling silently
> fails.)

The namespaces have different behavior:

| Namespace | Allowed characters | Length | Aliasing |
|---|---|---|---|
| PR labels | User-facing issue/PR metadata; names may contain spaces, punctuation, and emoji | Descriptions are limited to 100 characters | n/a |
| Runner labels | Scheduling selectors; custom-label matching is case-insensitive | Use short lowercase ASCII names as a workspace convention | GitHub-hosted labels are fixed (`ubuntu-latest`, etc.); cannot be aliased to custom names |

The two namespaces therefore use different separator conventions
intentionally. Don't try to unify them; the constraints differ.

## Issue + PR labels — the canonical 21

`install/templates/labels.json` is the canonical set — **21 labels** in
four functional groups. `install/install.sh` creates them idempotently
on a consumer repo at bootstrap (fail-loud; prefetches existing, only
adds missing, never removes drift). The groups:

### 1. State / control labels (8)

The `ai:*` state labels are applied by `ai-review.yml`. The two `skip-*`
directives are applied by an authorized human/operator; workflows consume
them but do not create them automatically.

| Label | Color | Kind | Meaning |
|---|---|---|---|
| `ai:review-passed` | `0e8a16` | state (canon §5.1) | Reviewer App APPROVED the PR |
| `ai:review-changes` | `d93f0b` | state (canon §5.1) | Reviewer App requested CHANGES |
| `ai:review-infra-error` | `e8a33d` | state (PLAN-011 F4) | Reviewer infrastructure failure — no verdict produced (not a code finding; re-run). Third mutually-exclusive outcome state; check stays red (fail-closed) |
| `ai:human-review-required` | `fbca04` | state (canon §5.1) | Fork PR or non-allowlisted author — trust gate routed to human review |
| `ai:autofix-applied` | `1d76db` | action (PLAN-012; optional) | The autofix fixer pushed a fix commit on this PR (not a canon §5.1 required label) |
| `ai:autofix-escalated` | `b60205` | action (PLAN-012; optional) | Autofix stopped and handed the PR to a human — deny-path, apply failure, or the round cap (not a canon §5.1 required label) |
| `skip-ai-review` | `5319e7` | **control / directive** | Human override: suppress the reviewer on subsequent pushes; `composition` carries the prior approval forward |
| `skip-audit-trail` | `d876e3` | **control / directive** | Two-signal override for the OPS-0069 audit-trail CI check — MUST be paired with `[skip-audit-trail]` in a commit body (per REPO_STANDARDS §14.2 / PLAN-002 §4.6). One signal alone does not skip. |

> **Note on `skip-ai-review` semantics.** Its behavior is
> **suppress-and-carry-forward**: with the label present, `ai-review.yml`
> does not re-run the heavy reviewer on subsequent pushes and
> `composition.yml` carries the prior APPROVED verdict forward so the
> gate stays green. Apply it **only by hand** after a clean review, for a
> trivial follow-up that doesn't change reviewed code — auto-applying
> would defeat the gate. Remove the label to request a fresh review.

### 2. Diff-class labels (8) — auto-applied by `labeler.yml`

The OPS-0065 diff-class labels. The reusable `labeler.yml`
(`actions/labeler@v7`) applies them from the file paths a PR touches,
per the consumer's `.github/labeler.yml`. The **canonical path→label map
and diff-class mapping live in `docs/REPO_STANDARDS.md` §5.2** — that is
the source of truth; the table below is the label reference.

| Label | Color | Applied when the PR touches |
|---|---|---|
| `governance` | `8b6914` | `CLAUDE.md`, `ops/DECISIONS.md`, `.claude/agents/`, `.claude/skills/`, `.github/ai-review/` |
| `docs` | `0075ca` | `docs/`, `README.md`, `CHANGELOG.md`, `ops/HANDOFF.md` |
| `workflows` | `5319e7` | `.github/workflows/` |
| `scripts` | `c5def5` | `scripts/` |
| `agents` | `d4c5f9` | `.claude/agents/`, `.claude/skills/`, `.claude/workflows/` |
| `tests` | `bfd4f2` | `tests/` |
| `config` | `fef2c0` | `Dockerfile`, `pyproject.toml`, `requirements*.txt`, `package*.json`, `uv.lock`, `.pre-commit-config.yaml` |
| `plans` | `e99695` | `ops/iplans/IPLAN-*.md`, `plans/PLAN-*.md` |

These are **unprefixed single words** — deliberately NOT `area:`-prefixed.
They map 1:1 to the OPS-0065 diff classes so a reviewer dispatching
diff-class agents can read the applied labels directly.

### 3. Area labels (2) — canon §5.3

| Label | Color | Applied when |
|---|---|---|
| `dependencies` | `0366d6` | Dependabot PR (matches Dependabot's own convention) |
| `security` | `b60205` | Security-tagged issue or PR |

### 4. Issue-lifecycle labels (3) — canon §5.4

Applied to **issues**, by hand or by an agent — never auto-applied, and never
by `labeler.yml` (which fires on pull-request events only). Provisioned by
`install.sh` exactly like the other three groups. The **rule — when each applies,
why the `handoff` lookup must be exact, and that provisioning `handoff` migrates
no repo's handoff surface — lives in `docs/REPO_STANDARDS.md` §5.4**; that is the
source of truth, and the table below is the label reference.

| Label | Color | Meaning |
|---|---|---|
| `handoff` | `006b75` | Session-continuity issue, in repos whose handoff **is** an issue. Exactly one open per repo; closed at each wrap and replaced by its successor |
| `todo` | `0052cc` | A captured backlog item — work to do, as distinct from a defect report |
| `status:in-progress` | `e4e669` | The issue is claimed and being worked. An issue being worked with neither this label nor an assignee cannot be told apart from an unstarted one |

**None of the three reuses a color from the other 18** — a deliberate choice for
this group so an issue label reads as distinct at a glance, and asserted in
`tests/test_contract.sh`. It is **not** a set-wide invariant: the existing 18
already collide twice (`5319e7` on `skip-ai-review` and `workflows`, `b60205` on
`ai:autofix-escalated` and `security`), and this change does not disturb them.

### Workflow-provisioned labels (NOT in the canonical 21)

Applied on demand by a workflow, self-created via `gh api` if missing — NOT
created by `install.sh` at bootstrap, so they are outside the canonical 21.

| Label | Applied by | Meaning |
|---|---|---|
| `ai:enforcer-failed` | `auto-merge-ai-prs.yml` | The stuck-green auto-merge enforcer could not re-arm native auto-merge; the PR stays open for operator attention (the workflow self-provisions the label, warning if creation fails). |

### Repo-local labels (NOT in the canonical 21)

Created by hand on **one** repo for that repo's own triage, never added to
`labels.json` and therefore never provisioned anywhere else. They are outside
the canonical 21 by design, so `tests/test_contract.sh`'s `length == 21`
assertion — a static check against `labels.json` with no path to any repo's
live label set — is unaffected, and no consumer inherits them.

| Label | Scope | Meaning |
|---|---|---|
| `status:deferred-post-v3` | `aidoc-flow-ci` only | The fix lands in canon but reaches no consumer until a re-pin. Parks the issue out of the default `gh issue list` view without closing it, so the reproduction stays searchable as OPEN. |
| `priority:high` | `aidoc-flow-ci` only | Fix before other queued work. Deliberately NOT canonical: it exists on no other repo, canon writes no priority policy, and provisioning it fleet-wide would push a scheme nobody uses. Re-derive with `gh label list -R vladm3105/<repo> --limit 200 \| grep priority`. |

**GitHub's stock defaults are not enumerated here.** Every repo is created with
`bug`, `documentation`, `duplicate`, `enhancement`, `good first issue`,
`help wanted`, `invalid`, `question` and `wontfix`. Canon neither provisions nor
removes them, so they are outside the canonical 21 by omission rather than by
decision. Counting them, this repo's live set reconciles exactly — **21
canonical + 2 repo-local + 9 stock = 32**. The workflow-provisioned label is
NOT in that sum: it is created on demand by the workflow that applies it, so it
does not exist until first used. Re-derive:

```sh
gh label list -R vladm3105/<repo> --limit 200 --json name --jq 'length'
```

Remove `status:deferred-post-v3` with `gh issue edit <N> --remove-label status:deferred-post-v3` once
a re-pin is scheduled. Re-derive the adoption state the label encodes — never
trust a count written here — with:

```sh
gh api "repos/vladm3105/<repo>/contents/.github/workflows/<any>.yml" --jq .content \
  | base64 -d | grep -oE 'aidoc-flow-ci/[^@]+@[^ ]+'
```

Prefer this over closing when the reason to drop an issue is *sequencing*
rather than *the defect being wrong*. Canon has paid for the alternative
once: `DECISIONS.md` CI-0040 records #404 closed *not planned — flow
deprecated* while its defect was reproduced and still live on `docs-sync`,
forcing the re-file as #495.

It takes the `status:<value>` form the rule below requires of every new issue
label. The gate is the value, so a second gate becomes a second value rather
than a third prefix.

### Naming conventions across the label set

Five forms, each marking a different label purpose at a glance:

| Form | Used by | Why this form |
|---|---|---|
| `ai:<noun>` (colon, no space) | §1 AI **state** labels (programmatic) | Tight prefix the workflow code parses/matches; no-space avoids quoted-string label handling in shell loops |
| `<verb>-<noun>` (hyphenated, no prefix) | §1 `skip-ai-review`, `skip-audit-trail` (human directives) | Reads like a command; not part of a namespace |
| `<noun>` (unprefixed single word) | §2 diff-class + §3 area labels, and §4 `handoff` / `todo` | Maps 1:1 to an OPS-0065 diff class, a well-known area, or one issue role; kept short for the sidebar |
| `status:<value>` (colon, no space) | §4 `status:in-progress` | A **state machine with room for more than one value** — the prefix reserves the space, exactly as `ai:` does. A bare word cannot express that it excludes its siblings |
| `issue:<role>` (colon, no space) | reserved — **no label uses it yet** | The form a **new** issue label naming a *role* takes (`issue:epic`, `issue:decision`). Reserved now so the next one has a form rather than inventing a fifth |

**Do NOT mix forms:** a state label MUST use `ai:<noun>`; a diff-class
label MUST be the bare word from §2. Consistency within each form is the
discipline.

**§4's two bare words are grandfathered, not a pattern to copy.** Both were
invented independently, before any standard existed, and matching what the fleet
already uses is worth more than prefix purity. Re-derive with
`gh label list -R <repo> --limit 200`:

| Repo | handoff | todo-role |
|---|---|---|
| `vladm3105/b-local-privy` | `handoff` | **`TODO`** (uppercase) |
| `vladm3105/llm-router` | `handoff` | `todo` |

**The casing disagrees, which is the other reason to standardise it** — canon
picks lowercase `todo`. Note GitHub's label namespace is case-insensitive
(`gh api repos/vladm3105/b-local-privy/labels/todo` returns `TODO`), so the two
are the *same* label to GitHub and cannot coexist in one repo.

**Every new issue label takes a prefix** — `status:<value>` if it names a state,
`issue:<role>` if it names a role. **Do not add more bare words to §4.**

**The form does not tell you which group a label is in, and no rule here claims
it does.** `labeler.yml` fires on pull-request events only, so a bare word on an
**issue** is never a *diff-class* label — but §3's `security` is documented for
issues **and** PRs, so a bare word on an issue is not uniquely §4 either.
(`dependencies` is Dependabot PRs only.) Read the group tables; the form is a
hint about purpose, not an index.

### Canonical source-of-truth + adding a label

`install/templates/labels.json` is canonical (name/color/description);
`docs/REPO_STANDARDS.md` §5.2 owns the diff-class path map. To add one:

1. Edit `install/templates/labels.json` (`{name, color, description}`).
   Keep the description **≤100 characters** — GitHub's hard limit, and
   `tests/test_contract.sh` asserts it.
2. Update the matching canon section: a diff-class label changes
   `docs/REPO_STANDARDS.md` §5.2's path→label map; an issue label changes
   §5.4; anything else is documented in the relevant table above.
3. **Bump the count assertion in `tests/test_contract.sh`** — it pins the
   exact set size (`length == 21`) so a label added to `labels.json` and
   nowhere else fails the suite rather than shipping undocumented. Bump the
   prose counts in this file's headings too.
4. PATCH-tag `aidoc-flow-ci` (a new label is additive) per `CHANGELOG.md`
   semver rules.
5. Consumers re-run `install/install.sh` to pick it up (idempotent +
   fail-loud, PR #116 fix — prefetches existing, adds only missing, exits
   nonzero on real auth/permission/network failures). **Until a consumer
   re-runs it the label does not exist there** — canon shipping a label
   provisions nothing by itself.

### Live drift from canonical (allowed, must be intentional)

A consumer may carry labels not in `labels.json` (e.g., operations has
`ai:review-escalated` + `ai:review-human-cleared`). `install.sh` does NOT
remove drifted labels — only adds missing canonical ones. To reconcile:
add useful extras to `labels.json` + PATCH-tag, or delete stale ones via
`gh label delete <name> -R <repo>`.

**This repo is not exempt from its own rule.** `aidoc-flow-ci` carries
repo-local labels too — see *Repo-local labels* above. A label that exists here
but not in `labels.json` is drift only if it was unintentional; the ones listed
there are deliberate and stay out of the canonical set.

## 2. Runner labels — composable scheduling convention

Used in the reusable workflow's `runs-on:` expressions (consumer
caller templates set the `runner_labels_*` inputs to one of these):

| Label | Dimension | Contract | Where it resolves |
|---|---|---|---|
| `self-hosted` | Runner class | GitHub-managed default label for self-hosted runners | Any registered self-hosted runner unless configured without default labels |
| `ci-runner` | Purpose | General CI workload with standard tools and a LiteLLM network route | Any conforming CI pool |
| `single-use` | Lifecycle | Accept exactly one job, then de-register and destroy the runner | JIT/single-use supervisor |
| `project-<name>` | Optional isolation | Restrict a job to a deliberately project-specific pool | Only runners registered for that project |
| `ubuntu-latest` | GitHub-hosted selector | GitHub-managed Ubuntu image; public LiteLLM reachability is still required for AI jobs | GitHub-hosted runner pool |

### Naming convention

Runner labels describe independent scheduling dimensions:

- **Purpose:** `ci-runner` says what workload the pool accepts.
- **Lifecycle:** `single-use` guarantees one job per runner registration.
  **`ci-runner` does NOT imply it.** Every selector and every registered runner
  in the fleet currently carries both, which makes `single-use` look redundant —
  but that is a property of today's registrations, not a constraint. A runner
  registered `ci-runner` without `single-use` would match a selector that omits
  it, and the job would land on a reused workspace. It is **defence in depth**,
  not the primary safety mechanism: `docs/security.md` §3 rests public-repo
  AI-flow safety on the trust gate and names exactly two invariants that must
  hold, neither of them this one. Dropping the lifecycle term still trades an
  enforced guarantee for a convention, which is why it stays in the selector. Renaming or collapsing the selector is `DECISIONS.md` CI-0007,
  deferred to a future breaking release and gated on fleet v2 adoption.
- **Optional isolation:** `project-<name>` is appended only when a project
  must not share the general pool. It is not part of the default selector.
- **Provider/origin is intentionally omitted** from the canonical selector.
  Moving the pool between hosts or clouds must not require caller changes.
- **GitHub's fixed labels** (`ubuntu-latest`, `ubuntu-22.04`,
  `windows-latest`, `macos-latest`, …) — used as-is. We cannot
  alias a GitHub-hosted runner to a custom label name.

The canonical selector for the self-hosted tier is therefore:

```json
["self-hosted", "ci-runner", "single-use"]
```

Do not add `aidoc`, a repository name, host name, cloud provider, or model name
to the default selector. Add `project-<name>` only when isolation is an
explicit requirement and the matching runner registration already exists.

> **…and do not rename it either without reading
> [`DECISIONS.md`](DECISIONS.md) CI-0007 (2026-07-16) first.** A rename was
> considered and deferred: the selector stays `[self-hosted, ci-runner,
> single-use]` until a future breaking release, and then only once the whole
> fleet is on v2. Any candidate must respect the dimensions above.
> `private-*` is **ruled out permanently** — public repos *may* use this pool
> for the ai-review *review* job (PLAN-009 Edit F, not yet executed), so the
> label would become false. `isolated-*` collides with the `project-<name>`
> isolation dimension. `sandbox-*` is accurate but names confinement rather
> than lifecycle, so it cannot replace `single-use`.

Custom labels are case-insensitive. Register them in lowercase so workflow
YAML, operational tooling, and UI output remain consistent. **Runner
registration — not a separately pre-created label record — is the source of
truth**: a label exists because a runner claims it. (An earlier revision here
also asserted GitHub deletes unused custom labels after exactly 24 hours. That
figure was never sourced, unlike every other load-bearing claim in this file,
so it has been dropped rather than carried forward as if verified.)

### Routing — owned by `docs/runners.md`, not restated here

**Which flow class runs where is policy, and `docs/runners.md` owns it.** This
file defines what the labels *mean*; it does not decide which workflow gets
which selector. Read the routing table at
[`docs/runners.md`](docs/runners.md) § "Workspace policy".

The one-line summary, and the reason a per-visibility table cannot express it:
routing keys off the **flow class**, not visibility alone (PLAN-013). The
**AI-flows** (`ai-review`, `docs-sync`) ship ONE protected template and run
self-hosted on public and private alike — a visibility flip is a no-op — while
the **generic checks** ship `-public.yml` / `-private.yml` variants and do split
on visibility. A two-row visibility table has no column for that distinction,
which is how this section previously stated the opposite of what
`install/templates/workflows/ai-review.yml` actually ships.

> **FT-9 trap, kept because it still bites.** Pre-`ci/v1.9.0` the PRIVATE
> templates shipped a `'"runner-self"'` placeholder — a label no repo registers,
> so jobs queued forever rather than failing. `ci/v1.9.0`+ ship a real array;
> `ci/v2.0.0` replaced the combined `ci-ephemeral` label with the separate
> `ci-runner` + `single-use` pair. Any template still carrying `runner-self`
> is broken, not merely stale.

Consumers override the relevant `runner_labels*` input in their own caller.

### Adding a specialized pool

1. Decide which capability or isolation property the shared pool lacks.
2. Choose a descriptive lowercase label, normally `project-<name>` for
   isolation or a capability such as `gpu`.
3. Register the runner with the base labels plus the specialized label.
4. Override only the callers that require that pool; general callers retain
   `["self-hosted", "ci-runner", "single-use"]`.
5. Add the label contract to this table if it becomes workspace-wide.
6. **PATCH-tag** `aidoc-flow-ci` per `CHANGELOG.md` semver rules
   (additive — no consumer template changes needed unless the
   default routing rule changes).

## 3. Branch + commit naming — see `docs/BRANCHING.md`

[`docs/BRANCHING.md`](docs/BRANCHING.md) is the standard: Conventional Commit types,
branch prefixes, the `agent/` automation namespace, bot namespaces, and the
squash-only merge policy. It is not restated here — a second copy of one
convention is the drift this file warns against elsewhere, and the copy that
used to live here had already fallen behind on four of those.

## 4. References

- [`docs/BRANCHING.md`](docs/BRANCHING.md) — branch + commit naming standard
- `install/templates/labels.json` — canonical 21-label taxonomy
  (name/color/description).
- `docs/REPO_STANDARDS.md` §5.2 — diff-class label path→label map
  (source of truth for §2 above); §5.3 — area labels; §5.4 — issue-lifecycle
  labels (source of truth for §4 above).
- `install/install.sh` — idempotent install + fail-loud creation
  (handles drift between canonical and existing labels).
- `.github/workflows/ai-review.yml` — applies the §1 state labels.
- `.github/workflows/labeler.yml` — applies the §2 diff-class labels.
- `.github/workflows/composition.yml` — checks `skip-ai-review`
  for carry-forward semantics.
- `.github/workflows/audit-trail-check.yml` — honors `skip-audit-trail`
  (two-signal).
- Operations governance:
  `aidoc-flow-operations/ops/iplans/IPLAN-0017_unified-ci-flows.md`
  §3.1c (runner-label convention) + §3.3 (PR-label taxonomy);
  `ops/DECISIONS.md` `OPS-0049` (no GitHub-hosted minutes for
  private repos).
- GitHub docs: [About self-hosted runners — security](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security)
