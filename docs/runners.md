# Runners — `aidoc-flow-ci`

How to register self-hosted runner pools with the right labels so
`aidoc-flow-ci`'s reusable workflows can find them, plus per-origin
tradeoffs and operational notes.

For label conventions, see [`../LABELS.md`](../LABELS.md) §2. For
the routing rule (PRIVATE → self-hosted `["self-hosted","ci-runner","single-use"]`;
PUBLIC → `ubuntu-latest`), see [`../LABELS.md`](../LABELS.md) §2 "Routing rule
(per repo visibility)". For the bigger architectural picture, see
[`architecture.md`](architecture.md) §5 ("Inputs that vary per
consumer").

> **Migration:** `runner-self` was an unroutable placeholder and
> `ci-ephemeral` was the v1 combined label. `ci/v2.0.0` replaces both with the
> purpose/lifecycle pair `ci-runner` + `single-use`.

## Workspace policy — private repos are self-hosted ONLY (mandatory, canon)

**Within the aidoc-flow workspace, every PRIVATE repo MUST run CI on
self-hosted runners — `ubuntu-latest` is never acceptable for a private repo**
(founder policy, 2026-07-11). Runner routing now depends on the flow **class**,
not only visibility (PLAN-013):

| Flow class | Public repo | Private repo | Caller shape |
| --- | --- | --- | --- |
| **AI-flows** — `ai-review`, `doc-maintainer`, `docs-sync` (+ `autofix`, planned — PLAN-012) | **self-hosted** `["self-hosted","ci-runner","single-use"]` | **self-hosted** (same) | **ONE protected template** — no `-public`/`-private` split; a visibility flip is a no-op |
| **Generic checks** — `markdown-lint`, `links`, `pre-commit`, `composition`, `audit-trail`, `secret-scan`, `labeler`, `auto-merge-ai-prs` | GitHub-hosted `ubuntu-latest` | **self-hosted** | the `-public.yml` / `-private.yml` variants |

The AI-flows run uniform self-hosted because **forks never reach a job that
executes PR code** (trust-gated or post-merge) — safe on public per
[`security.md`](security.md) §3. The **fork-code-running lint flows**
(`markdown-lint`/`links`/`pre-commit`, `on: pull_request`) MUST stay
`ubuntu-latest` on public repos — converging them to self-hosted would run
untrusted fork code on our box. Their visibility split is therefore correct and
kept.

Rationale for private = self-hosted everywhere: this account has **no
GitHub-hosted Actions minutes for private repos** (OPS-0049), so a private repo
pinned to `ubuntu-latest` queues indefinitely.

`install.sh` encodes this: for the **generic checks** it auto-detects visibility
(`gh repo view isPrivate`) and installs the matching `-private`/`-public` variant;
for the **AI-flows** the manifest carries no `visibility_variants`, so the single
protected (self-hosted) template installs regardless of visibility.

> ⚠️ **Prerequisite for a private consumer:** register the
> `["self-hosted", "ci-runner", "single-use"]` runner pool
> **before** adopting — otherwise the correctly-installed self-hosted callers
> queue forever with no matching runner. See §2 for the reference image.

**External adopters** can use the same generic labels for their own pool, or
override the selector — see §2 option 1 (`ubuntu-latest`, if their private repos
have GitHub-hosted minutes) or option 2 (build their own pool).

## 0. Terminology — runner CLASS vs runner LABEL (canonical)

Per [GitHub Actions docs](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners),
runners have two distinct CLASSES and many possible LABELS:

| Concept | Definition | Examples |
|---|---|---|
| **Runner CLASS** | Who provisions + manages the runner machine | "GitHub-hosted runners" (managed by GitHub) · "self-hosted runners" (operator-provisioned) |
| **Runner LABEL** | String matched by `runs-on:` to identify a specific runner image / pool within a class | `ubuntu-latest` (GitHub-hosted image) · `[self-hosted, ci-runner, single-use]` (custom self-hosted pool) |

**Common terminology mistakes to AVOID** (these conflate class and label):

| ❌ Incorrect framing | ✅ Correct framing |
|---|---|
| "ubuntu-latest runner" | "GitHub-hosted runner (e.g. `ubuntu-latest`)" |
| "ubuntu-latest does fresh clone" | "GitHub-hosted runners do fresh clone per job" |
| "PRIVATE consumers use ubuntu-latest runner" | "PRIVATE consumers use a GitHub-hosted runner labeled `ubuntu-latest`" |
| "on ubuntu-latest" (as a category) | "on GitHub-hosted runners (image: ubuntu-latest)" |

The distinction matters because:

- **Class** determines billing model (GitHub-hosted = metered for PRIVATE / free for PUBLIC; self-hosted = your infra cost)
- **Class** determines lifecycle (GitHub-hosted = fresh VM per job; self-hosted = persistent state unless ephemeral-by-design)
- **Label** determines which runner pool gets the job (`ci-runner` = purpose;
  `single-use` = one job then destroy). Add `project-<name>` only for intentional
  project-specific isolation.

Workflow YAML uses labels (e.g. `runs-on: ubuntu-latest`); prose
should use class names when talking about the runner category, and
label names when talking about a specific image / pool. Example:

> "Private consumers use self-hosted runners labeled
> `[self-hosted, ci-runner, single-use]`; public consumers use GitHub-hosted
> runners (`ubuntu-latest`)."

## 1. The runner-label convention recap

| Label | Origin | What's installed |
|---|---|---|
| `ci-runner` | General CI workload purpose | Python, gh, jq, curl, git; network route to LiteLLM |
| `single-use` | One-job lifecycle | Fresh container is destroyed after its job |
| `ubuntu-latest` | GitHub-hosted | Standard tools; network route to LiteLLM required |
| *(future)* `runner-azure`, `runner-aws`, `runner-fargate` | Other origins (reserved namespace) | Per-provider |

**Constraint** (per [`../LABELS.md`](../LABELS.md) §2): GitHub
Actions runner labels are alphanumeric + `-` + `_` only. No colons.
GitHub-hosted labels are fixed by GitHub and cannot be aliased to
custom names.

## 2. Reference image — `aidoc-flow-runner:latest`

> **External adopters — this is aidoc-flow-operations infrastructure.**
> The `aidoc-flow-runner:latest` image and `scripts/ci-runner/` build live in
> `aidoc-flow-operations`. External adopters can reproduce the generic labels
> on their own pool. They have two paths:
>
> 1. **Use `ubuntu-latest` (recommended default for EXTERNAL adopters** — the
>    aidoc-flow *workspace* default is self-hosted for private repos, see
>    "Workspace default" above). The
>    dependency-free HTTP adapter is included by the reusable workflow, so no
>    vendor CLI is needed. The runner must reach the configured LiteLLM proxy;
>    see [`REVIEWER_APP_ONBOARDING.md`](REVIEWER_APP_ONBOARDING.md).
> 2. **Build your own self-hosted image** only if you need self-hosted
>    (e.g., private repos with no GitHub-hosted minutes). Use the
>    operations `Dockerfile` below as a **template** — it shows exactly
>    what to bake in (see the table) — build + register your own pool with
>    the canonical `ci-runner` + `single-use` labels, and point caller
>    `runner_labels_*` inputs at that pool.

The reference self-hosted runner image lives in
[`aidoc-flow-operations/scripts/ci-runner/`](https://github.com/vladm3105/aidoc-flow-operations/tree/main/scripts/ci-runner)
(`Dockerfile` + `build-image.sh`). It builds atop
[`ghcr.io/actions/actions-runner:latest`](https://github.com/actions/runner)
with the following baked in:

| Tool | Why |
|---|---|
| `gh` CLI | Required by `ai-review` + `composition` workflows for `gh api` calls; **historical foot-gun** (PR #101 on operations spent ~2h debugging a "network failure" that was actually `gh: not found` in the runner image) |
| `python3` | Runs the dependency-free LiteLLM adapter |
| `gh`, `jq`, `curl`, `git` | Standard CLI utilities the workflows assume |

The image is rebuilt and re-tagged when those tools need an update.
Operations' ephemeral runner supervisor pulls
`aidoc-flow-runner:latest` per container spawn (no long-running
warm pool — each PR run gets a fresh ephemeral container).

## 3. Registering a self-hosted runner with the right labels

### 3.1 Org-level registration (recommended)

Register self-hosted runners at the **organization level** so all
repos in the org can use them. This is the cleanest path for a
multi-repo workspace like aidoc-flow.

1. Settings → Actions → Runners → New runner (org level)
2. Follow GitHub's install instructions on the runner host
3. **Add both `ci-runner` and `single-use`** during JIT registration.
4. The GitHub-provided `self-hosted` label remains; the complete selector is
   `[self-hosted, ci-runner, single-use]`.

### 3.2 Repo-level registration (fallback)

If org-level isn't available, register per-repo. Same label rules
apply. Less convenient (each new consumer repo needs its own runner
registration) but acceptable for small workspaces.

### 3.3 Verifying the label

After registration, a workflow using
`runs-on: [self-hosted, ci-runner, single-use]` should pick up the runner:

```bash
# From the consumer repo, after opening a test PR:
gh run list --workflow=ai-review --limit 1
```

If the run sits in "Queued" state >30s, the label probably isn't
registered correctly. Check the runner's labels via
`Settings → Actions → Runners`.

## 4. Per-origin operational tradeoffs

| Origin | Cost | Latency | CLI availability | Fork-PR safety |
|---|---|---|---|---|
| `ci-runner` + `single-use` | Fixed (your infrastructure) | Low (ephemeral spawn ~5-10s) | Standard tools + LiteLLM reachability | **Trust gate required** for PUBLIC repos (untrusted PR code on self-hosted is GitHub's documented anti-pattern) |
| `ubuntu-latest` (GitHub-hosted) | Free for PUBLIC; metered for PRIVATE (per OPS-0049 this account has zero GitHub-hosted minutes for PRIVATE) | High (~30-60s VM cold-start) | Standard tools + public LiteLLM reachability | Safe by default (GitHub-isolated VMs; fork PRs sandboxed) |
| `runner-azure`/`runner-aws`/etc. | Per-provider | Per-provider | Per-image | Same trust-gate concern as any self-hosted pool if shared with PUBLIC repos |

**For PRIVATE consumers:** a self-hosted pool is the practical choice
(no GitHub-hosted minutes; low latency). Inside aidoc-flow
that pool uses the generic `ci-runner` + `single-use` selector; external
adopters may reproduce it on their own infrastructure.

**For PUBLIC consumers:** `ubuntu-latest` is GitHub's documented
recommendation (no self-hosted-on-public security concern). Slower
cold-start is the tradeoff.

## 5. Scaling the runner pool — one supervisor is SERIAL

**A single ephemeral supervisor instance runs one job at a time.**
`run-ephemeral.sh` is a loop: generate a JIT config → `docker run` a fresh
`--rm` container for **one** job (blocking) → destroy it → loop. So per
`ci-runner@<repo>` systemd instance there is exactly **one live runner**, and a
repo's jobs execute **serially**.

This matters most on **private repos**, where *every* job is self-hosted: a
single PR fans out to ~8 jobs (ai-review `trust` + `review`, composition,
`verify`, links, markdown-lint, pre-commit, secret-scan) that then run
**one-at-a-time** on a single instance — slow feedback, and concurrent PRs
compete for the one runner.

**To parallelize, run N supervisor instances** with the same labels (e.g.
`ci-runner@iplanic-1 … ci-runner@iplanic-N`), sized to the **peak concurrent
job count of a single PR (~6–8)**. GitHub distributes queued jobs round-robin
across the matching runners. Reference supervisor + systemd template:
[operations `scripts/ci-runner/`](https://github.com/vladm3105/aidoc-flow-operations/tree/main/scripts/ci-runner)
(`run-ephemeral.sh`, `ci-runner@.service`). Never relieve the bottleneck by
moving private-repo jobs to `ubuntu-latest`.

### 5a. Public repos on the ephemeral self-hosted pool — the AI-flows run fully self-hosted (safe); the lint flows do NOT

As of PLAN-013 (`ci/v2.2.0`), the **AI-flows** (`ai-review`, `doc-maintainer`,
`docs-sync`; `autofix` planned — PLAN-012) run **entirely** on the ephemeral
self-hosted pool on public repos — trust job included — via one protected template
with no visibility split. This is **not** the "untrusted code on a self-hosted runner"
anti-pattern, because **a fork never reaches a job that executes PR code**:

1. **`ai-review` (`pull_request_target`):** a fork PR triggers ONLY the `trust`
   job, which checks out the **trusted config repo** (never the PR head) and reads
   PR metadata — it runs **zero PR code**. The review job is gated
   `if: needs.trust.outputs.ai_review_ok == 'true'` and forks are **never
   trusted**, so a fork never reaches it; and even for a trusted author the review
   job `curl`s the diff (no PR-head checkout).
2. **`doc-maintainer` + `docs-sync`** are **post-merge** (`push: main`) — a fork
   PR cannot trigger them.

Combined with single-use isolation (`--rm`, no mounts, no socket, non-root), the
worst case a fork can cause is a throwaway container running the no-PR-code trust
decision. Wiring is simply the single protected template's default:

```yaml
runner_labels_routine: '["self-hosted","ci-runner","single-use"]' # trust job — no PR code
runner_labels_review:  '["self-hosted","ci-runner","single-use"]' # review job — diff-only
```

**The fork-code-running lint flows MUST stay GitHub-hosted on public repos.**
`markdown-lint`, `links`, `pre-commit` (all `on: pull_request`) run the PR's own
files, **including a fork's** — the exact case GitHub warns against. **NEVER** move
those — or any job that checks out / runs PR code — to self-hosted on a public
repo. They keep the `-public.yml` (`ubuntu-latest`) variant. See
[`security.md`](security.md) §3 for the full boundary. This is also what lets a
**private-only** LiteLLM proxy serve public repos without any public endpoint.

Residual: on a public repo every fork PR fires a (fast, no-code) trust job on the
pool — size the pool for fork volume (`concurrency: cancel-in-progress` collapses
same-PR pushes).

## 6. Adding a new runner origin

When a new origin needs to join the namespace (e.g., Azure-hosted
or AWS-Fargate self-registered):

1. **Register the runner pool** with the custom label
   (e.g., `runner-azure`). Must match `[a-zA-Z0-9_-]+` (no colons).
2. **Bake the standard tools** into the image (`python3`, `gh`, `jq`, `curl`,
   and `git`) and provide a route to LiteLLM. Use [operations'
   `scripts/ci-runner/Dockerfile`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/scripts/ci-runner/Dockerfile)
   as the reference.
3. **Update [`../LABELS.md`](../LABELS.md) §2 table** to add the
   new label row with its capability description.
4. **Update this doc's §1 table** with the new origin.
5. **PATCH-tag a new `ci/vX.Y.Z` release** documenting the addition.

Consumers can then override their caller workflow's `runner_labels`
input to the new label.

## 7. Where the runner work lives

- **Reference image build:**
  [`aidoc-flow-operations/scripts/ci-runner/`](https://github.com/vladm3105/aidoc-flow-operations/tree/main/scripts/ci-runner)
- **Ephemeral supervisor:** operations' `scripts/ci-runner/run-ephemeral.sh`
  (out of scope for `aidoc-flow-ci` — consumer-side infra)
- **Network monitor:** operations' `scripts/ci-runner/network-monitor.sh`
  (host-side debugging for the api.github.com flake class)
- **Activation log:** operations' `docs/AI_REVIEW_ACTIVATION_LOG.md`
  records the runner-image rebuilds when CLI updates are needed
