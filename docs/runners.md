# Runners — `aidoc-flow-ci`

How to register self-hosted runner pools with the right labels so
`aidoc-flow-ci`'s reusable workflows can find them, plus per-origin
tradeoffs and operational notes.

For label conventions, see [`../LABELS.md`](../LABELS.md) §2. For
the routing rule (PRIVATE → `runner-self`, PUBLIC → `ubuntu-latest`),
see [`../LABELS.md`](../LABELS.md) §2 "Routing rule (per repo
visibility)". For the bigger architectural picture, see
[`architecture.md`](architecture.md) §5 ("Inputs that vary per
consumer").

## 0. Terminology — runner CLASS vs runner LABEL (canonical)

Per [GitHub Actions docs](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners),
runners have two distinct CLASSES and many possible LABELS:

| Concept | Definition | Examples |
|---|---|---|
| **Runner CLASS** | Who provisions + manages the runner machine | "GitHub-hosted runners" (managed by GitHub) · "self-hosted runners" (operator-provisioned) |
| **Runner LABEL** | String matched by `runs-on:` to identify a specific runner image / pool within a class | `ubuntu-latest`, `ubuntu-22.04`, `windows-latest` (GitHub-hosted images) · `[self-hosted, aidoc, ci-ephemeral]`, `[self-hosted, aidoc, ai-review]` (custom self-hosted pools) |

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
- **Label** determines which runner image / pool gets the job (`ubuntu-latest` resolves to GitHub's latest Ubuntu LTS image; `[self-hosted, aidoc, ai-review]` resolves to your reviewer-CLI-pre-baked pool)

Workflow YAML uses labels (e.g. `runs-on: ubuntu-latest`); prose
should use class names when talking about the runner category, and
label names when talking about a specific image / pool. Example:

> "Operations uses self-hosted runners labeled `[self-hosted, aidoc,
> ci-ephemeral]` for the trust job and `[self-hosted, aidoc, ai-review]`
> for the heavy reviewer; framework uses GitHub-hosted runners
> (`ubuntu-latest`) for both."

## 1. The runner-label convention recap

| Label | Origin | What's installed |
|---|---|---|
| `runner-self` | Our self-hosted pool | gh + `codex`/`claude` CLI pre-baked + authenticated |
| `ubuntu-latest` | GitHub-hosted | gh CLI pre-installed; reviewer CLI installed at workflow start (`ci/v1.0.2`+) |
| *(future)* `runner-azure`, `runner-aws`, `runner-fargate` | Other origins (reserved namespace) | Per-provider |

**Constraint** (per [`../LABELS.md`](../LABELS.md) §2): GitHub
Actions runner labels are alphanumeric + `-` + `_` only. No colons.
GitHub-hosted labels are fixed by GitHub and cannot be aliased to
custom names.

## 2. Reference image — `aidoc-flow-runner:latest`

> **External adopters — this is aidoc-flow-operations infrastructure.**
> The `runner-self` label, the `aidoc-flow-runner:latest` image, and the
> `scripts/ci-runner/` build live in `aidoc-flow-operations` and resolve
> only to the aidoc-flow workspace's own self-hosted pool. A different
> company/org adopting this CI standard does NOT have access to them. You
> have two paths:
>
> 1. **Use `ubuntu-latest` (recommended default for adopters).** The
>    reviewer CLI is installed just-in-time at workflow start (`ci/v1.0.2`+),
>    so no self-hosted infra is needed. Works for public repos and private
>    repos that have GitHub-hosted Actions minutes. (You still set the
>    reviewer-auth secret — the JIT-installed CLI needs it to authenticate;
>    see [`REVIEWER_APP_ONBOARDING.md`](REVIEWER_APP_ONBOARDING.md).)
> 2. **Build your own self-hosted image** only if you need self-hosted
>    (e.g., private repos with no GitHub-hosted minutes). Use the
>    operations `Dockerfile` below as a **template** — it shows exactly
>    what to bake in (see the table) — build + register your own pool with
>    your **own** label, and point the caller `runner_labels_*` inputs at
>    it. Do not expect `runner-self` to resolve outside aidoc-flow.

The reference self-hosted runner image lives in
[`aidoc-flow-operations/scripts/ci-runner/`](https://github.com/vladm3105/aidoc-flow-operations/tree/main/scripts/ci-runner)
(`Dockerfile` + `build-image.sh`). It builds atop
[`ghcr.io/actions/actions-runner:latest`](https://github.com/actions/runner)
with the following baked in:

| Tool | Why |
|---|---|
| `gh` CLI | Required by `ai-review` + `composition` workflows for `gh api` calls; **historical foot-gun** (PR #101 on operations spent ~2h debugging a "network failure" that was actually `gh: not found` in the runner image) |
| `codex` CLI | Default reviewer for `ai-review` |
| `claude` CLI | Alternate reviewer; selected via `reviewer: claude` input |
| `python3`, `jq`, `curl`, `git` | Standard CLI utilities most workflows assume |

The image is rebuilt + re-tagged when any of those tools needs an
update. Operations' ephemeral runner supervisor pulls
`aidoc-flow-runner:latest` per container spawn (no long-running
warm pool — each PR run gets a fresh ephemeral container).

## 3. Registering a self-hosted runner with the right labels

### 3.1 Org-level registration (recommended)

Register self-hosted runners at the **organization level** so all
repos in the org can use them. This is the cleanest path for a
multi-repo workspace like aidoc-flow.

1. Settings → Actions → Runners → New runner (org level)
2. Follow GitHub's install instructions on the runner host
3. **Add the `runner-self` label** during configuration (or
   afterwards via `Settings → Actions → Runners → <name> → Labels`)
4. The runner's existing labels (`self-hosted`, OS-specific labels
   like `linux`/`x64`) remain — `runner-self` is **additive**, not
   a replacement. Existing workflows that use
   `runs-on: [self-hosted, aidoc, ci-ephemeral]` continue to work
   alongside ones using `runs-on: runner-self`.

### 3.2 Repo-level registration (fallback)

If org-level isn't available, register per-repo. Same label rules
apply. Less convenient (each new consumer repo needs its own runner
registration) but acceptable for small workspaces.

### 3.3 Verifying the label

After registration, a workflow that uses
`runs-on: runner-self` should pick up the runner without queuing:

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
| `runner-self` | Fixed (your infrastructure) | Low (warm container; ephemeral spawn ~5-10s) | Pre-baked (gh + codex + claude) | **Trust gate required** for PUBLIC repos (untrusted PR code on self-hosted is GitHub's documented anti-pattern) |
| `ubuntu-latest` (GitHub-hosted) | Free for PUBLIC; metered for PRIVATE (per OPS-0049 this account has zero GitHub-hosted minutes for PRIVATE) | High (~30-60s VM cold-start) | gh pre-installed; reviewer CLI installed by workflow at start (`ci/v1.0.2`+) | Safe by default (GitHub-isolated VMs; fork PRs sandboxed) |
| `runner-azure`/`runner-aws`/etc. | Per-provider | Per-provider | Per-image | Same trust-gate concern as `runner-self` if shared with PUBLIC repos |

**For PRIVATE consumers:** a self-hosted pool is the practical choice
(no GitHub-hosted minutes; CLI pre-baked; low latency). Inside aidoc-flow
that pool is `runner-self`; **external adopters** substitute their own
self-hosted label per the §2 callout — `runner-self` resolves only to
aidoc-flow's pool.

**For PUBLIC consumers:** `ubuntu-latest` is GitHub's documented
recommendation (no self-hosted-on-public security concern). Slower
cold-start is the tradeoff.

## 5. Scaling the runner pool

If a single runner becomes the bottleneck (multiple concurrent PRs
queueing), spin additional runners with the same labels. GitHub
distributes jobs round-robin across runners matching the requested
labels. For ephemeral container-based pools (the
`aidoc-flow-runner:latest` shape), the operations supervisor
manages concurrent container spawn — see
[operations `scripts/ci-runner/`](https://github.com/vladm3105/aidoc-flow-operations/tree/main/scripts/ci-runner)
for the reference implementation.

## 6. Adding a new runner origin

When a new origin needs to join the namespace (e.g., Azure-hosted
or AWS-Fargate self-registered):

1. **Register the runner pool** with the custom label
   (e.g., `runner-azure`). Must match `[a-zA-Z0-9_-]+` (no colons).
2. **Bake the same CLI set** into the image (`gh` + reviewer CLI
   + standard utilities). Use [operations'
   `scripts/ci-runner/Dockerfile`](https://github.com/vladm3105/aidoc-flow-operations/blob/main/scripts/ci-runner/Dockerfile)
   as the reference; the reviewer-CLI install steps are
   provider-agnostic.
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
