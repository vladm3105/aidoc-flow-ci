# Runners — `aidoc-flow-ci`

How to register self-hosted runner pools with the right labels so
`aidoc-flow-ci`'s reusable workflows can find them, plus per-origin
tradeoffs and operational notes.

For what the individual labels mean, see [`../LABELS.md`](../LABELS.md) §2.
**The routing rule lives HERE**, in the "Workspace policy" table below — it keys
off the flow class, not visibility alone, so `LABELS.md` deliberately does not
restate it. (It used to, as a flat PRIVATE/PUBLIC table; that table was wrong
for the AI-flows and was removed.) For the bigger architectural picture, see
[`architecture.md`](architecture.md) §5 ("Inputs that vary per
consumer").

> **Migration history — these are the names each release actually shipped.**
> `runner-self` was an unroutable placeholder and `ci-ephemeral` was the v1
> combined label. `ci/v2.0.0` replaced both with the purpose/lifecycle pair
> `ci-runner` + `single-use`; **CI-0043 then renamed that pair to the current
> `ci` + `ephemeral`**. A consumer still on a pre-CI-0043 pin registers the
> older names.

## Workspace policy — private repos are self-hosted ONLY (mandatory, canon)

**Within the aidoc-flow workspace, every PRIVATE repo MUST run CI on
self-hosted runners — `ubuntu-latest` is never acceptable for a private repo**
(founder policy, 2026-07-11). Runner routing now depends on the flow **class**,
not only visibility (PLAN-013):

| Flow class | Public repo | Private repo | Caller shape |
| --- | --- | --- | --- |
| **AI-flows** — `ai-review`, `docs-sync` (+ `autofix`, a gated job within `ai-review` — PLAN-012) | **self-hosted** `["self-hosted","ci","ephemeral"]` | **self-hosted** (same) | **ONE protected template** — no `-public`/`-private` split; a visibility flip is a no-op |
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
> `["self-hosted", "ci", "ephemeral"]` runner pool
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
| **Runner LABEL** | String matched by `runs-on:` to identify a specific runner image / pool within a class | `ubuntu-latest` (GitHub-hosted image) · `[self-hosted, ci, ephemeral]` (custom self-hosted pool) |

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
- **Label** determines which runner pool gets the job (`ci` = purpose;
  `ephemeral` = one job then destroy). Add `project-<name>` only for intentional
  project-specific isolation.

Workflow YAML uses labels (e.g. `runs-on: ubuntu-latest`); prose
should use class names when talking about the runner category, and
label names when talking about a specific image / pool. Example:

> "Private consumers use self-hosted runners labeled
> `[self-hosted, ci, ephemeral]`; public consumers use GitHub-hosted
> runners (`ubuntu-latest`)."

## 1. The runner-label convention recap

| Label | Origin | What's installed |
|---|---|---|
| `ci` | General CI workload purpose | Python, gh, jq, curl, git; network route to LiteLLM |
| `ephemeral` | One-job lifecycle | Fresh container is destroyed after its job |
| `ubuntu-latest` | GitHub-hosted | Standard tools; network route to LiteLLM required |
| *(future)* `runner-azure`, `runner-aws`, `runner-fargate` | Other origins (reserved namespace) | Per-provider |

**Constraint** (per [`../LABELS.md`](../LABELS.md) §2): GitHub
Actions runner labels are alphanumeric + `-` + `_` only. No colons.
GitHub-hosted labels are fixed by GitHub and cannot be aliased to
custom names.

## 2. Reference image — `aidoc-flow-runner:latest`

> **External adopters — the reference implementation is in this repo.**
> The runner templates (image spec, ephemeral supervisor, provisioning
> script) live at [`../install/templates/runner/`](../install/templates/runner/),
> versioned with the `ci/vX.Y.Z` tags. Two paths:
>
> 1. **Use `ubuntu-latest` (recommended default for EXTERNAL adopters** — the
>    aidoc-flow *workspace* default is self-hosted for private repos, see
>    "Workspace default" above). The
>    dependency-free HTTP adapter is included by the reusable workflow, so no
>    vendor CLI is needed. The runner must reach the configured LiteLLM proxy;
>    see [`REVIEWER_APP_ONBOARDING.md`](REVIEWER_APP_ONBOARDING.md).
> 2. **Copy the canon templates** if you need self-hosted (e.g., private
>    repos with no GitHub-hosted minutes): copy
>    [`../install/templates/runner/`](../install/templates/runner/) to your
>    runner host, run `TARGET_REPO=owner/repo bash provision-runner.sh`, and
>    point caller `runner_labels_*` inputs at the resulting
>    `ci` + `ephemeral` pool.

### ⚠️ Version floor — Actions Runner >= 2.327.1

The reusables call **node24** actions (`actions/checkout` **v5+**, `actions/setup-node` **v5+**,
`actions/setup-python` **v6+**, `actions/labeler` **v6+**,
`actions/create-github-app-token` **v3+**, `actions/download-artifact` **v7+**,
`actions/upload-artifact` **v6+**). node24 requires **Actions
Runner >= 2.327.1**. A pool below that fails at the **runtime**, not on your
config, and it surfaces in `ai-review`'s FIRST job (`trust`) — so the whole gate
looks broken rather than version-gated.

**This is not new, and not tied to one tag.** node24 actions have been in the
reusables since the early `ci/v1.x` series; at `ci/v2.15.0` there were already
**30 node24 call sites across 16 workflow files** (17 `checkout` v7, 6
`create-github-app-token` v3, 5 `setup-python` v6, 1 `setup-node` v6, 1
`labeler` v6). It went undocumented until #342 — do not read a particular tag as
the boundary.

Check your pool:

```sh
gh api repos/<owner>/<repo>/actions/runners --jq '.runners[].version'
```

`aidoc-flow-runner:latest` built from the canon `Dockerfile` satisfies this, and
`provision-runner.sh` now asserts it at provision time. **Rebuilding matters**:
the image is built per host with no registry push, so a host that has not re-run
`build-image.sh` keeps whatever runner its old base shipped. `ubuntu-latest` is
unaffected — GitHub-hosted runners are always current.

The reference self-hosted runner image spec lives at
[`../install/templates/runner/`](../install/templates/runner/)
(`Dockerfile` + `build-image.sh`). It builds atop a **digest-pinned**
[`ghcr.io/actions/actions-runner`](https://github.com/actions/runner) base
(see the [`Dockerfile`](../install/templates/runner/Dockerfile) for the
current pin — base-digest bumps land in canon and flow to consumers via
re-pin) with the following baked in:

| Tool | Why |
|---|---|
| `gh` CLI | Required by `ai-review` + `composition` workflows for `gh api` calls; **historical foot-gun** (PR #101 on operations spent ~2h debugging a "network failure" that was actually `gh: not found` in the runner image). **The self-expiring pin is FIXED** — `gh` is installed from its **immutable GitHub release asset** with a per-architecture SHA-256 check, not from the `cli.github.com` apt repo. Until [#435](https://github.com/vladm3105/aidoc-flow-ci/issues/435) landed, an exact `gh=${GH_VERSION}` apt pin stopped being installable the moment upstream shipped the next release — with no change here and nothing detecting it, so the image became unbuildable **by anyone** and [#349](https://github.com/vladm3105/aidoc-flow-ci/issues/349)'s fix could not be delivered (measured 2026-08-09: unbuildable since 2.97.0). Release assets are immutable, so a bump is now a deliberate edit of `GH_VERSION` **and both checksums together** |
| `libatomic1` | Node-backed lint tools installed at job time (markdownlint-cli2) crash without it — second shipped instance of the same image-drift class (business #63) |
| `ripgrep` | fast search for AI-review job scripts |
| `python3` | Runs the dependency-free LiteLLM adapter |
| `python3-venv`, `python3-pip` | `actions/sast-scan` installs semgrep into an isolated venv (D21). The base image ships the **interpreter** without `ensurepip`, so `python3 -m venv` fails while `command -v python3` succeeds — third shipped instance of the image-drift class ([#349](https://github.com/vladm3105/aidoc-flow-ci/issues/349)). `build-image.sh` now proves it by building a venv, not by checking the package list |
| `python3-yaml` | `actions/pre-commit`'s D11 guard parses the hook config on the **system** interpreter, before `actions/setup-python` runs — deliberately, so a config selecting zero hooks is refused before anything is provisioned. Without PyYAML the guard fails the whole `quick-gates` gate; it now names the cause instead of raising a traceback, but the package is what makes it work |
| `gh`, `jq`, `curl`, `git` | Standard CLI utilities the workflows assume |

The image spec is versioned here and re-tagged with the `ci/vX.Y.Z`
releases when those tools need an update — image and workflows can no
longer drift apart silently. The ephemeral runner supervisor
(`run-ephemeral.sh`, same directory) runs `aidoc-flow-runner:latest`
per container spawn (no long-running warm pool — each job gets a fresh
ephemeral container).

## 3. Registering a self-hosted runner with the right labels

### 3.1 Repo-level registration (primary — aidoc-flow's model)

`vladm3105` is a **personal account, not a GitHub organization**, so **org-level
runner registration is not available** — every repo is registered individually
(PLAN-009 records this: there is no org to inherit runners from). Register a runner
**per repo**:

1. Settings → Actions → Runners → New self-hosted runner (on the consumer repo)
2. Follow GitHub's install instructions on the runner host
3. **Add both `ci` and `ephemeral`** during JIT registration.
4. The GitHub-provided `self-hosted` label remains; the complete selector is
   `[self-hosted, ci, ephemeral]`.

Each private consumer repo needs its own runner instance — the supervisor spins a
fresh ephemeral container per job, so multiple repo instances coexist on one host.

### 3.2 Org-level registration (only under a GitHub org — not the current setup)

If the workspace is ever moved under a GitHub **organization**, register runners at
the org level so all repos share them — the cleanest path for a true multi-repo org.
The steps mirror §3.1 (New runner at org level; same `[self-hosted, ci,
ephemeral]` labels). **Not available on the current personal-account setup**, so
§3.1 is the path today.

### 3.3 Verifying the label

After registration, a workflow using
`runs-on: [self-hosted, ci, ephemeral]` should pick up the runner:

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
| `ci` + `ephemeral` | Fixed (your infrastructure) | Low (ephemeral spawn ~5-10s) | Standard tools + LiteLLM reachability | **Trust gate required** for PUBLIC repos (untrusted PR code on self-hosted is GitHub's documented anti-pattern) |
| `ubuntu-latest` (GitHub-hosted) | Free for PUBLIC; metered for PRIVATE (per OPS-0049 this account has zero GitHub-hosted minutes for PRIVATE) | High (~30-60s VM cold-start) | Standard tools + public LiteLLM reachability | Safe by default (GitHub-isolated VMs; fork PRs sandboxed) |
| `runner-azure`/`runner-aws`/etc. | Per-provider | Per-provider | Per-image | Same trust-gate concern as any self-hosted pool if shared with PUBLIC repos |

**For PRIVATE consumers:** a self-hosted pool is the practical choice
(no GitHub-hosted minutes; low latency). Inside aidoc-flow
that pool uses the generic `ci` + `ephemeral` selector; external
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
[`../install/templates/runner/`](../install/templates/runner/)
(`run-ephemeral.sh`, `ci-runner@.service` — install via
`provision-runner.sh`). Never relieve the bottleneck by
moving private-repo jobs to `ubuntu-latest`.

### 5a. Public repos on the ephemeral self-hosted pool — the AI-flows run fully self-hosted (safe); the lint flows do NOT

As of PLAN-013 (`ci/v2.2.0`), the **AI-flows** (`ai-review`, `docs-sync`; `autofix` runs as a gated job within `ai-review` — PLAN-012) run **entirely** on the ephemeral
self-hosted pool on public repos — trust job included — via one protected template
with no visibility split. This is **not** the "untrusted code on a self-hosted runner"
anti-pattern, because **a fork never reaches a job that executes PR code**:

1. **`ai-review` (`pull_request_target`):** a fork PR triggers ONLY the `trust`
   job, which checks out the **trusted config repo** (never the PR head) and reads
   PR metadata — it runs **zero PR code**. The review job is gated
   `if: needs.trust.outputs.ai_review_ok == 'true'` and forks are **never
   trusted**, so a fork never reaches it; and even for a trusted author the review
   job `curl`s the diff (no PR-head checkout).
2. **`docs-sync`** is **post-merge** (`push: main`) — a fork PR cannot trigger
   it.

Combined with ephemeral isolation (`--rm`, no mounts, no socket, non-root), the
worst case a fork can cause is a throwaway container running the no-PR-code trust
decision. Wiring is simply the single protected template's default:

```yaml
runner_labels_routine: '["self-hosted","ci","ephemeral"]' # trust job — no PR code
runner_labels_review:  '["self-hosted","ci","ephemeral"]' # review job — diff-only
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
   `git`, and `libatomic1`) and provide a route to LiteLLM. Use the canon
   [`../install/templates/runner/Dockerfile`](../install/templates/runner/Dockerfile)
   as the reference.
3. **Update [`../LABELS.md`](../LABELS.md) §2 table** to add the
   new label row with its capability description.
4. **Update this doc's §1 table** with the new origin.
5. **PATCH-tag a new `ci/vX.Y.Z` release** documenting the addition.

Consumers can then override their caller workflow's `runner_labels`
input to the new label.

## 7. Pool management — drain, update, scale

`manage.sh` (same directory as the runner templates) provides operational
commands for the runner pool. It works with the existing `ci-runner@.service`
systemd setup — no new platform required.

### 7.1 Commands

| Command | Purpose | Example |
| --- | --- | --- |
| `status` | Show all instances, their state, and queue depth | `manage.sh status --repo owner/repo` |
| `drain` | Stop supervisors, wait for in-flight jobs to finish | `manage.sh drain --repo owner/repo` |
| `update` | Safe cycle: drain → rebuild image → restart | `manage.sh update --repo owner/repo` |
| `scale` | Adjust instance count for a repo | `manage.sh scale --repo owner/repo --count 6` |
| `health` | Check Docker, image contract, GitHub API, queue | `manage.sh health` |

### 7.2 Safe update cycle (`manage.sh update`)

Updating the runner image while jobs are in flight kills those jobs (SIGTERM →
container destroyed → GitHub marks the job failed after ~2min). The `update`
command prevents this:

1. **Drain** — stops all supervisor units for the target repo. No new JIT
   configs are minted. In-flight containers continue to completion.
2. **Build** — runs `build-image.sh` to rebuild `aidoc-flow-runner:latest`.
3. **Verify** — checks the image contract stamp.
4. **Restart** — starts supervisors. New jobs use the updated image
   automatically (each container is one-shot).

If drain times out (default 30min), the update aborts and supervisors stay
stopped — the operator must restart manually after resolving the stuck job.

```bash
# Safe update for one repo
manage.sh update --repo vladm3105/iplanic

# Dry-run first
manage.sh update --repo vladm3105/iplanic --dry-run
```

### 7.3 Scaling

One supervisor = one job at a time (serial). A PR fans out to ~8 jobs; a
single instance runs them one-by-one. Scale to match peak concurrency:

```bash
# Check current state
manage.sh status --repo vladm3105/iplanic

# Scale to 6 parallel instances
manage.sh scale --repo vladm3105/iplanic --count 6

# Scale down during quiet periods
manage.sh scale --repo vladm3105/iplanic --count 2
```

`manage.sh scale` provisions new instances via `provision-runner.sh` (scale up)
or stops + disables excess instances (scale down). Existing in-flight jobs are
not affected when scaling down — the supervisor's signal handler lets the
current job finish.

### 7.4 Drain mode

Drain stops all supervisors for a repo and waits for in-flight jobs to
complete. Use before maintenance, host reboots, or manual image updates:

```bash
# Drain with confirmation prompt
manage.sh drain --repo vladm3105/iplanic

# Skip confirmation (for scripts)
manage.sh drain --repo vladm3105/iplanic --force

# Custom timeout (default 30min)
manage.sh drain --repo vladm3105/iplanic --timeout 3600
```

After drain, supervisors are stopped. Restart with:
```bash
manage.sh scale --repo vladm3105/iplanic --count <N>
# or: systemctl --user start ci-runner@<instance>.service
```

## 8. Monitoring

`monitor.sh` provides health checks and queue-depth reporting for the runner
pool. It checks:

- **Instance state** — are all systemd units active?
- **Docker daemon** — is the daemon reachable?
- **Image contract** — is the runner image current?
- **GitHub API** — is the API reachable, and is the rate budget healthy?
- **Queue depth** — are jobs building up (runner starvation)?

### 8.1 One-shot check

```bash
# All repos
monitor.sh

# One repo
monitor.sh --repo vladm3105/iplanic

# JSON output for alerting
monitor.sh --json
```

Exit codes: `0` = all clear, `2` = warning (degraded), `3` = critical.

### 8.2 Continuous monitoring

```bash
# Watch mode (checks every 60s)
monitor.sh --watch

# Custom interval
WATCH_INTERVAL=30 monitor.sh --watch
```

### 8.3 Systemd timer (automated)

Install the monitor as a systemd timer for periodic health checks:

```bash
# Copy timer and service files
cp ci-runner-monitor.service ~/.config/systemd/user/
cp ci-runner-monitor.timer ~/.config/systemd/user/

# Enable
systemctl --user daemon-reload
systemctl --user enable --now ci-runner-monitor.timer

# Check status
systemctl --user status ci-runner-monitor.timer
journalctl --user -u ci-runner-monitor.service -f
```

### 8.4 Alert thresholds

| Var | Default | Meaning |
| --- | --- | --- |
| `QUEUE_WARN` | `3` | Warn if queued jobs exceed this |
| `QUEUE_CRIT` | `8` | Critical if queued jobs exceed this |
| `STALE_MINUTES` | `30` | Warn if no jobs picked up in this long |

## 9. Where the runner work lives

- **Reference image spec + build:**
  [`../install/templates/runner/`](../install/templates/runner/)
  (`Dockerfile`, `build-image.sh`) — canon, versioned with `ci/vX.Y.Z`
- **Ephemeral supervisor + provisioning:**
  [`../install/templates/runner/`](../install/templates/runner/)
  (`run-ephemeral.sh`, `ci-runner@.service`, `provision-runner.sh`) — canon
  templates; deployed host state (env files, enabled units, built images,
  registrations) stays operator-side
- **Pool management:**
  [`../install/templates/runner/`](../install/templates/runner/)
  (`manage.sh`) — drain, update, scale, status, health
- **Monitoring:**
  [`../install/templates/runner/`](../install/templates/runner/)
  (`monitor.sh`, `ci-runner-monitor.service`, `ci-runner-monitor.timer`) —
  health checks, queue-depth reporting, alerting
- **Network monitor:** operations' `scripts/ci-runner/network-monitor.sh`
  (host-side debugging for the api.github.com flake class — operator
  tooling, deliberately not templatized)
- **Activation log:** operations' `docs/AI_REVIEW_ACTIVATION_LOG.md`
  records the runner-image rebuilds when CLI updates are needed
