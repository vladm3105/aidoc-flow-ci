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
# This is the general `ci` / `ephemeral` pool. Every container accepts
# one job and is then destroyed; AI jobs use scoped LiteLLM keys and need no
# durable CLI authentication.
#
# Usage:  TARGET_REPO=owner/repo ./run-ephemeral.sh
# Env overrides: RUNNER_LABELS, RUNNER_IMAGE, RUNNER_GROUP_ID, RUNNER_CPUS,
#                RUNNER_MEM, RUNNER_PIDS_LIMIT, RUNNER_WORKDIR, GH_HOST,
#                GH_TOKEN_STRIP (default 1 — see below), RUNNER_DNS.
set -euo pipefail

TARGET_REPO="${TARGET_REPO:?set TARGET_REPO=owner/repo}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,ci,ephemeral}"
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

# ── STALE-IMAGE DETECTION (#458) ─────────────────────────────────────────────
# The image is built per host with no registry push, so a host that skipped a
# rebuild keeps an old one and nothing prompts it. Since #349/#436 an old image
# lacks python3-venv/python3-yaml, which makes `sast-scan` inert and takes the
# whole consolidated `scanners` job down with it — RED ON ARRIVAL for every repo
# whose jobs land on that host, with a failure that names semgrep, not the image.
#
# THREE OUTCOMES, and the split is the safety property. This unit runs under
# `Restart=always` / `RestartSec=5`, so ANY exit here returns in five seconds:
#
#   no label / unreadable -> WARN, keep serving. Every host is in this state
#                            until it rebuilds once, and a transient inspect
#                            failure (daemon not up yet at boot) is not evidence
#                            of a stale image. Landing this must not take CI down.
#   below the minimum, and
#   the unit knows 78     -> REFUSE (exit 78). That state exists only after a
#                            deliberate contract raise.
#   below the minimum, but
#   the unit does NOT     -> WARN. See below; this is the case that would
#                            otherwise crash-loop the host forever.
#
# WHY THE UNIT IS CHECKED AT ALL: `exit 78` is terminal only because
# ci-runner@.service carries `RestartPreventExitStatus=78`. That file is
# installed by provision-runner.sh — and every operator-facing refresh
# instruction (README, troubleshooting, UPDATE_GUIDE, MIGRATION) says to re-run
# BUILD-IMAGE.SH, which does not touch it. So a host provisioned before this
# change has an old unit, and refusing there would restart every 5s forever
# (systemd's default burst of 5-per-10s never trips at one start per 5s).
# Rather than rely on an instruction nobody is given, the refusal VERIFIES its
# own precondition and degrades to a warning when it is absent.
RUNNER_CONTRACT_MIN="${RUNNER_CONTRACT_MIN:-2}"
RUNNER_CONTRACT_REFUSE_RC=78
case "$RUNNER_CONTRACT_MIN" in
  ''|*[!0-9]*)
    log "WARNING: RUNNER_CONTRACT_MIN='$RUNNER_CONTRACT_MIN' is not a number — ignoring it rather than comparing against a non-integer (which would pass silently)."
    RUNNER_CONTRACT_MIN=0 ;;
esac

# Does the INSTALLED unit make the refusal terminal? `grep -q` on a FILE is not
# a pipeline, so §27.1 does not apply.
unit_knows_refuse_rc() {
  local u line code
  for u in "$HOME"/.config/systemd/user/ci-runner@*.service; do
    [ -e "$u" ] || continue
    while IFS= read -r line; do
      case "$line" in RestartPreventExitStatus=*) ;; *) continue ;; esac
      # The directive takes a SPACE-SEPARATED list of codes, so compare tokens.
      # A regex over the whole line gets this wrong in a way that reads correct:
      # `=.*(^|[^0-9])78` cannot match `=78`, because the character after `=` is
      # already the digit. That spelling silently disabled the whole guard, and
      # only driving it against a real unit file showed it.
      for code in ${line#RestartPreventExitStatus=}; do
        if [ "$code" = "$RUNNER_CONTRACT_REFUSE_RC" ]; then return 0; fi
      done
    done < "$u"
  done
  return 1
}

_contract_warned=0
check_runner_contract() {
  # `[ … ] && return 0` works here (bash exempts a non-final `&&` operand from
  # errexit) but this script runs `set -euo pipefail` and that exemption is
  # exactly the subtlety CLAUDE.md's "Bash, where the fix quietly creates the
  # next bug" section is about. Spell it out.
  if [ "${RUNNER_SKIP_CONTRACT_CHECK:-0}" = "1" ]; then return 0; fi
  local img_contract
  img_contract="$(docker image inspect --format '{{ index .Config.Labels "dev.aidoc-flow.runner.contract" }}' "$RUNNER_IMAGE" 2>/dev/null || true)"
  case "$img_contract" in
    ''|'<no value>'|*[!0-9]*)
      if [ "$_contract_warned" = 0 ]; then
        log "WARNING: '$RUNNER_IMAGE' carries no runner-contract label — this host has NOT rebuilt since the stamp landed (#458)."
        log "WARNING: jobs still run, but an image older than #349 makes 'scanners' red on arrival with a message naming semgrep, not the image."
        log "WARNING: fix on THIS host: bash $(dirname "$(readlink -f "$0")")/build-image.sh"
        _contract_warned=1
      fi
      return 0 ;;
  esac
  if [ "$img_contract" -ge "$RUNNER_CONTRACT_MIN" ]; then
    if [ "$_contract_warned" = 0 ]; then
      log "runner image contract ${img_contract} >= ${RUNNER_CONTRACT_MIN} — this host is current."
      _contract_warned=1
    fi
    return 0
  fi
  if ! unit_knows_refuse_rc; then
    if [ "$_contract_warned" = 0 ]; then
      log "WARNING: '$RUNNER_IMAGE' is at runner-contract ${img_contract}, below the required ${RUNNER_CONTRACT_MIN}."
      log "WARNING: NOT refusing, because the installed ci-runner@.service has no RestartPreventExitStatus=${RUNNER_CONTRACT_REFUSE_RC};"
      log "WARNING: exiting there would restart every RestartSec (5s) forever instead of stopping."
      log "WARNING: fix on THIS host: bash $(dirname "$(readlink -f "$0")")/build-image.sh && bash $(dirname "$(readlink -f "$0")")/provision-runner.sh"
      _contract_warned=1
    fi
    return 0
  fi
  log "ERROR: '$RUNNER_IMAGE' is at runner-contract ${img_contract}, below the required ${RUNNER_CONTRACT_MIN}."
  log "ERROR: this host has not rebuilt since the contract was raised. Refusing to serve jobs from a known-stale image."
  log "ERROR: fix on THIS host: bash $(dirname "$(readlink -f "$0")")/build-image.sh"
  log "ERROR: exiting ${RUNNER_CONTRACT_REFUSE_RC} — the unit names it in RestartPreventExitStatus, so this STOPS rather than restarting."
  exit "$RUNNER_CONTRACT_REFUSE_RC"
}
check_runner_contract

cleanup() { log "supervisor stopping (signal) — current job container will finish, then exit"; RUNNING=0; }
trap cleanup TERM INT
RUNNING=1

log "ephemeral CI runner supervisor up — repo=$TARGET_REPO labels=$RUNNER_LABELS image=$RUNNER_IMAGE"

while [ "$RUNNING" = 1 ]; do
  # Re-checked per iteration, not only at startup: these supervisors run for
  # weeks under `linger`, so a contract raised while one is up would otherwise
  # never be seen and the host would keep serving jobs from a stale image. The
  # log is emitted once per state, not once per job.
  check_runner_contract
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
