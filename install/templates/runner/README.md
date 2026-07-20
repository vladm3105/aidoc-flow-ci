# Single-use sandboxed CI runner — reference implementation

The templates that satisfy the canonical `[self-hosted, ci-runner, single-use]`
label contract ([`../../../LABELS.md`](../../../LABELS.md) §2,
[`../../../docs/runners.md`](../../../docs/runners.md)): each CI job runs in a
**fresh, throwaway container**, then the container is destroyed. Cuts GitHub
Actions minutes to ≈ $0 on private repos while providing substantially
stronger isolation for jobs that execute PR content.

**Templates here; deployment state stays with the operator.** This directory
is the source of record for the *implementation* (image spec, supervisor,
provisioning). What lands on a runner host — `~/.config/ci-runner/*.env`
files, enabled systemd units, the built image, live runner registrations — is
operator-side state, never tracked in this repo. Workspace consumers vendor a
pinned copy of these files (`aidoc-flow-operations/scripts/ci-runner/`
re-baselines to this set per PLAN-016 W3 — pending); external adopters copy
them directly.

## What's in the box

| File | Role |
| --- | --- |
| `Dockerfile` | digest-pinned `actions-runner` base + `gh`, `ripgrep`, `libatomic1` (node-backed lint tools crash without it) |
| `build-image.sh` | builds + verifies `aidoc-flow-runner:latest` locally (no registry push) |
| `run-ephemeral.sh` | the supervisor loop — one-shot JIT registration → one job per fresh container → repeat |
| `ci-runner@.service` | user-systemd template for the supervisor — **not raw-`cp` installable** (carries an `@RUNNER_HOME@` ExecStart placeholder) |
| `provision-runner.sh` | **the only documented installer** — builds the image, substitutes the placeholder, writes the env file, enables the service |

## How it works

`run-ephemeral.sh` loops: fetch a **one-shot JIT** runner registration from
GitHub → `docker run` the image with `--jitconfig` → the runner takes
**exactly one job** then de-registers and the container is removed → repeat.

**Isolation controls:** no host bind mounts or Docker socket, non-root
execution, `no-new-privileges`, all Linux capabilities dropped,
PID/CPU/memory caps, and a fresh container per job. The default bridge still
permits outbound network access and shares the host kernel; treat this as
strong process isolation, not a VM security boundary. Restrict host firewall
exposure and never attach the Docker socket.

## Host prerequisites (no sudo required)

- Docker usable without sudo (user in the `docker` group)
- `gh` authenticated on the host (the supervisor mints JIT configs via `gh api`)
- `loginctl enable-linger "$USER"` for reboot-persistent user services
  (provision-runner.sh enables this)

## Provision a repo's pool

```bash
TARGET_REPO=owner/repo bash provision-runner.sh          # one command
TARGET_REPO=owner/repo bash provision-runner.sh --dry-run # inspect first
```

That builds the image, installs the unit (with the `@RUNNER_HOME@` ExecStart
placeholder substituted to this directory's absolute path — the reason raw
`cp` of `ci-runner@.service` is not supported), writes
`~/.config/ci-runner/<instance>.env`, and enables `ci-runner@<instance>`.

Add another repo: run it again with a different `TARGET_REPO` (the instance
name defaults to the repo basename).

**Migrating from an older label scheme?** Override the labels for the
coexistence window so old-label and new-label jobs both find a runner, then
re-provision with the final labels after the migration PR merges:

```bash
TARGET_REPO=owner/repo \
  RUNNER_LABELS=self-hosted,old-label,ci-runner,single-use \
  bash provision-runner.sh
```

## Parallelism

One supervisor = one job at a time. To parallelize, enable N instances with
the same labels (`ci-runner@myrepo-1 … ci-runner@myrepo-N`), sized to the
peak concurrent job count of a single PR (~6–8). GitHub distributes queued
jobs round-robin across matching runners.

## Image refresh

Re-run `build-image.sh` after deliberately reviewing and updating the
upstream `actions-runner` digest, or when another tool must be baked in. **No
service restart is needed** — each container is one-shot, so the next spawned
container picks up the new image. (A restart would kill an in-flight job for
no benefit.)

## Env knobs (`run-ephemeral.sh`)

| Var | Default | Meaning |
|---|---|---|
| `TARGET_REPO` | — (required) | `owner/repo` to serve |
| `RUNNER_LABELS` | `self-hosted,ci-runner,single-use` | runner labels |
| `RUNNER_IMAGE` | `aidoc-flow-runner:latest` | runner container image |
| `RUNNER_GROUP_ID` | `1` | Default runner group |
| `RUNNER_CPUS` / `RUNNER_MEM` | `2` / `4g` | per-job container caps |
| `RUNNER_PIDS_LIMIT` | `512` | maximum processes inside one job container |
| `RUNNER_DNS` | `1.1.1.1 8.8.8.8` | container resolvers (`""` = host resolver) |

Before enabling AI workflows, verify a single-use container can reach the
configured `LITELLM_BASE_URL` without exposing other host services. HTTP
endpoints require the callers' explicit `litellm_allow_insecure_http: true`;
prefer TLS whenever the proxy can provide it.

Host-side network diagnostics (probing api.github.com reachability from the
runner host) are operator-side tooling, deliberately not part of these
templates.
