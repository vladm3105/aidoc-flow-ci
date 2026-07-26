#!/usr/bin/env bash
# Ephemeral sandboxed CI runner supervisor — IPLAN-0012.
#
# Loops forever: fetch a ONE-SHOT JIT runner registration from GitHub → run a
# single CI job inside a FRESH, throwaway Ubuntu container → the container exits
# and is removed → repeat. Untrusted PR code runs ONLY inside the per-job
# container; the host is protected because the container gets:
#   • no host bind mounts          • no Docker socket
#   • a non-root in-container user  • CPU/memory caps      • the default bridge net
# The only credential in play is the short-lived JIT token (one job, then dead).
#
# This is the general `ci-runner` / `single-use` pool. Every container accepts
# one job and is then destroyed; AI jobs use scoped LiteLLM keys and need no
# durable CLI authentication.
#
# Usage:  TARGET_REPO=owner/repo ./run-ephemeral.sh
# Env overrides: RUNNER_LABELS, RUNNER_IMAGE, RUNNER_GROUP_ID, RUNNER_CPUS,
#                RUNNER_MEM, RUNNER_PIDS_LIMIT, RUNNER_WORKDIR, GH_HOST,
#                GH_TOKEN_STRIP (default 1 — see below), RUNNER_DNS.
set -euo pipefail

TARGET_REPO="${TARGET_REPO:?set TARGET_REPO=owner/repo}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,ci-runner,single-use}"
# Default: the local custom image baked by `build-image.sh` (same directory —
# adds `gh` atop the bare actions-runner image — without it, workflows that
# assume `gh` is available silently fail with `gh: not found` masked as a
# misleading "(api.github.com) — retrying" warning). Build once with
# `bash build-image.sh` before first use; rebuild after the
# upstream `actions-runner` image bumps. To bypass the custom image and use the
# bare upstream image directly, set RUNNER_IMAGE=ghcr.io/actions/actions-runner:latest.
RUNNER_IMAGE="${RUNNER_IMAGE:-aidoc-flow-runner:latest}"
RUNNER_GROUP_ID="${RUNNER_GROUP_ID:-1}"      # 1 = the repo's Default runner group
RUNNER_CPUS="${RUNNER_CPUS:-2}"
RUNNER_MEM="${RUNNER_MEM:-4g}"
RUNNER_PIDS_LIMIT="${RUNNER_PIDS_LIMIT:-512}"
RUNNER_WORKDIR="${RUNNER_WORKDIR:-_work}"
# Container DNS: by default a container inherits the host's resolver (often a LAN router), which can
# intermittently drop github.com / api.github.com lookups → false-red CI (lost verdicts, the
# composition false-block). Point the container at reliable public resolvers instead. Set RUNNER_DNS="" to
# fall back to the host resolver, or override the list as needed.
RUNNER_DNS="${RUNNER_DNS-1.1.1.1 8.8.8.8}"

# GH_TOKEN handling: some hosts (this workspace included) carry a stale
# GH_TOKEN export that shadows the host's keyring gh auth — default strips it.
# Headless hosts that authenticate VIA a GH_TOKEN service PAT (no interactive
# `gh auth login`) must set GH_TOKEN_STRIP=0 or every API call silently 401s.
GH_TOKEN_STRIP="${GH_TOKEN_STRIP:-1}"
if [ "$GH_TOKEN_STRIP" = 1 ]; then
  gh() { command env -u GH_TOKEN gh "$@"; }
fi

# Build the repeated -f labels[]=… args from the comma list.
label_args=()
IFS=',' read -ra _labels <<< "$RUNNER_LABELS"
for l in "${_labels[@]}"; do label_args+=(-f "labels[]=${l}"); done

# --dns args for the container (reliable resolvers; see RUNNER_DNS above).
dns_args=()
if [ -n "${RUNNER_DNS:-}" ]; then read -ra _dns <<< "$RUNNER_DNS"; for d in "${_dns[@]}"; do dns_args+=(--dns "$d"); done; fi

log() { printf '%s  %s\n' "$(date -u +%H:%M:%S)" "$*"; }

cleanup() { log "supervisor stopping (signal) — current job container will finish, then exit"; RUNNING=0; }
trap cleanup TERM INT
RUNNING=1

log "ephemeral CI runner supervisor up — repo=$TARGET_REPO labels=$RUNNER_LABELS image=$RUNNER_IMAGE"

while [ "$RUNNING" = 1 ]; do
  # Docker preflight BEFORE minting a JIT config: if the daemon is down, a
  # minted registration can never connect — without this check the loop would
  # register an orphan runner every ~2s for as long as the daemon is dead
  # (runner-list pollution + API hammering). The unit's ExecStartPre only
  # guards service START; this guards the mid-run path.
  if ! docker info >/dev/null 2>&1; then
    log "docker daemon unreachable — no JIT minted, retry in 30s"
    sleep 30
    continue
  fi
  name="ci-job-$(hostname -s)-$$-${SECONDS}"
  # One-shot JIT config: the runner registers, takes ONE job, then de-registers.
  jit="$(gh api -X POST "repos/${TARGET_REPO}/actions/runners/generate-jitconfig" \
          -f "name=${name}" -F "runner_group_id=${RUNNER_GROUP_ID}" \
          "${label_args[@]}" -f "work_folder=${RUNNER_WORKDIR}" \
          -q '.encoded_jit_config' 2>/dev/null)" || { log "jitconfig fetch failed — retry in 10s"; sleep 10; continue; }

  if [ -z "$jit" ] || [ "$jit" = "null" ]; then log "empty jitconfig — retry in 10s"; sleep 10; continue; fi

  log "starting ephemeral container $name (one job)…"
  # --rm: container removed on exit. No -v mounts, no --privileged, no socket.
  docker run --rm --name "$name" \
    --cpus "$RUNNER_CPUS" --memory "$RUNNER_MEM" \
    --pids-limit "$RUNNER_PIDS_LIMIT" --cap-drop ALL \
    --security-opt no-new-privileges \
    "${dns_args[@]}" \
    -e "JITCONFIG=${jit}" \
    "$RUNNER_IMAGE" \
    bash -c './run.sh --jitconfig "$JITCONFIG"' \
    || log "container $name exited non-zero (job failed or runner error) — continuing"

  # Brief pause so a misconfig can't hot-loop the API.
  sleep 2
done

log "supervisor exited."
