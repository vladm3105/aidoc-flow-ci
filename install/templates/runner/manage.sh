#!/usr/bin/env bash
# Runner pool management — drain, update, scale, status.
#
# Works with the existing ci-runner@.service systemd setup. Provides:
#   status  — show all runner instances, their state, and in-flight jobs
#   drain   — stop accepting new jobs, wait for in-flight to finish
#   update  — safe image rebuild: drain → build → reprovision → start
#   scale   — adjust the number of parallel instances for a repo
#   health  — check runner health and report issues
#
# Usage:
#   manage.sh status                          # all instances
#   manage.sh status --repo owner/repo        # one repo
#   manage.sh drain --repo owner/repo         # drain and wait
#   manage.sh update --repo owner/repo        # safe update cycle
#   manage.sh scale --repo owner/repo --count 4
#   manage.sh health                          # health check all
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_DIR="${ENV_DIR:-$HOME/.config/ci-runner}"
SERVICE_DIR="${SERVICE_DIR:-$HOME/.config/systemd/user}"
DRAIN_TIMEOUT="${DRAIN_TIMEOUT:-1800}"  # 30min max wait for in-flight jobs
POLL_INTERVAL="${POLL_INTERVAL:-15}"    # seconds between status checks

# ── helpers ──────────────────────────────────────────────────────────────────

log()  { printf '%s  %s\n' "$(date -u +%H:%M:%S)" "$*"; }
warn() { log "WARNING: $*"; }
err()  { log "ERROR: $*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  status    Show runner instances and their state
  drain     Stop accepting new jobs, wait for in-flight to finish
  update    Safe update: drain → build image → reprovision → start
  scale     Adjust instance count for a repo
  health    Health check all runner instances

Options:
  --repo OWNER/REPO    Target repository (required for drain/update/scale)
  --count N            Target instance count (required for scale)
  --timeout SECONDS    Drain timeout (default: $DRAIN_TIMEOUT)
  --force              Skip drain confirmation
  --dry-run            Show what would happen without changing state
  -h, --help           Show this help
EOF
}

# List all ci-runner@ instances (enabled or active).
list_instances() {
  local repo_filter="${1:-}"
  systemctl --user list-units 'ci-runner@*' --all --no-legend 2>/dev/null \
    | awk '{print $1}' \
    | sed 's/ci-runner@//;s/\.service$//' \
    | while read -r inst; do
        if [ -n "$repo_filter" ]; then
          local env_file="$ENV_DIR/$inst.env"
          [ -f "$env_file" ] || continue
          local inst_repo
          inst_repo="$(grep -m1 '^TARGET_REPO=' "$env_file" 2>/dev/null | cut -d= -f2)"
          [ "$inst_repo" = "$repo_filter" ] || continue
        fi
        echo "$inst"
      done
}

# Get the TARGET_REPO from an instance's env file.
instance_repo() {
  local inst="${1:-}" env_file="$ENV_DIR/${1:-}.env"
  [ -n "$inst" ] && [ -f "$env_file" ] && grep -m1 '^TARGET_REPO=' "$env_file" | cut -d= -f2
}

# Get the RUNNER_LABELS from an instance's env file.
instance_labels() {
  local inst="${1:-}" env_file="$ENV_DIR/${1:-}.env"
  [ -n "$inst" ] && [ -f "$env_file" ] && grep -m1 '^RUNNER_LABELS=' "$env_file" | cut -d= -f2
}

# Check if a systemd unit is active.
is_active() {
  systemctl --user is-active "ci-runner@$1.service" &>/dev/null
}

# Count in-flight jobs for a repo (queued + in_progress).
count_inflight_jobs() {
  local repo="$1"
  gh api "repos/${repo}/actions/runs" --paginate \
    --jq '[.workflow_runs[] | select(.status=="in_progress" or .status=="queued")] | length' 2>/dev/null || echo 0
}

# Count specifically queued jobs (waiting for a runner).
count_queued_jobs() {
  local repo="$1"
  gh api "repos/${repo}/actions/runs" --paginate \
    --jq '[.workflow_runs[] | select(.status=="queued")] | length' 2>/dev/null || echo 0
}

# Count in-progress jobs (actively running on a runner).
count_running_jobs() {
  local repo="$1"
  gh api "repos/${repo}/actions/runs" --paginate \
    --jq '[.workflow_runs[] | select(.status=="in_progress")] | length' 2>/dev/null || echo 0
}

# ── status ───────────────────────────────────────────────────────────────────

cmd_status() {
  local repo_filter="${1:-}"
  local instances
  instances="$(list_instances "$repo_filter")"

  if [ -z "$instances" ]; then
    log "No ci-runner instances found${repo_filter:+ for $repo_filter}."
    return 0
  fi

  printf '%-20s %-12s %-30s %-10s %-10s\n' "INSTANCE" "STATE" "REPO" "QUEUED" "RUNNING"
  printf '%-20s %-12s %-30s %-10s %-10s\n' "--------" "-----" "----" "------" "-------"

  local repos_seen=""
  while read -r inst; do
    local repo state queued running
    repo="$(instance_repo "$inst")"
    state="$(systemctl --user is-active "ci-runner@$inst.service" 2>/dev/null || echo "inactive")"

    # Only query API once per repo.
    if echo "$repos_seen" | grep -qF "|$repo|"; then
      queued="-"
      running="-"
    else
      queued="$(count_queued_jobs "$repo")"
      running="$(count_running_jobs "$repo")"
      repos_seen="${repos_seen}|$repo|"
    fi

    printf '%-20s %-12s %-30s %-10s %-10s\n' "$inst" "$state" "$repo" "$queued" "$running"
  done <<< "$instances"
}

# ── drain ────────────────────────────────────────────────────────────────────

cmd_drain() {
  local repo="$1"
  local timeout="${2:-$DRAIN_TIMEOUT}"
  local instances
  instances="$(list_instances "$repo")"

  if [ -z "$instances" ]; then
    err "No ci-runner instances found for $repo"
    return 1
  fi

  local inst_count
  inst_count="$(echo "$instances" | wc -l)"
  log "Draining $inst_count instance(s) for $repo (timeout: ${timeout}s)"

  # Step 1: Stop all supervisor units. They stop accepting new JIT configs.
  # In-flight containers continue to completion (the supervisor's trap waits).
  while read -r inst; do
    if is_active "$inst"; then
      log "  stopping ci-runner@$inst (in-flight job will finish)"
      systemctl --user stop "ci-runner@$inst.service" &
    fi
  done <<< "$instances"
  wait

  log "All supervisors stopped. Waiting for in-flight jobs to complete..."

  # Step 2: Wait for all running containers to finish.
  local elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    local running
    running="$(count_running_jobs "$repo")"
    if [ "$running" -eq 0 ]; then
      log "All in-flight jobs completed (waited ${elapsed}s)."
      return 0
    fi
    log "  $running job(s) still running (${elapsed}s/${timeout}s)..."
    sleep "$POLL_INTERVAL"
    elapsed=$((elapsed + POLL_INTERVAL))
  done

  warn "Drain timeout (${timeout}s) reached with jobs still running."
  warn "Remaining running jobs:"
  gh api "repos/${repo}/actions/runs" --paginate \
    --jq '.workflow_runs[] | select(.status=="in_progress") | "  \(.name) #\(.id) (\(.head_branch))"' 2>/dev/null || true
  return 1
}

# ── update ───────────────────────────────────────────────────────────────────

cmd_update() {
  local repo="$1" dry_run="${2:-0}"
  local instances
  instances="$(list_instances "$repo")"

  if [ -z "$instances" ]; then
    err "No ci-runner instances found for $repo"
    return 1
  fi

  local inst_count
  inst_count="$(echo "$instances" | wc -l)"

  log "Safe update cycle for $repo ($inst_count instance(s))"
  echo ""
  echo "Steps:"
  echo "  1. Drain: stop supervisors, wait for in-flight jobs"
  echo "  2. Build: rebuild aidoc-flow-runner:latest image"
  echo "  3. Verify: run build-image.sh checks"
  echo "  4. Restart: start supervisors (new image picked up automatically)"
  echo ""

  if [ "$dry_run" = 1 ]; then
    log "[dry-run] Would drain $inst_count instance(s), rebuild image, restart"
    return 0
  fi

  # Step 1: Drain.
  log "Step 1/4: Draining..."
  if ! cmd_drain "$repo"; then
    err "Drain failed. Aborting update. Supervisors are STOPPED — restart manually if needed:"
    while read -r inst; do
      echo "  systemctl --user start ci-runner@$inst.service"
    done <<< "$instances"
    return 1
  fi

  # Step 2: Build.
  log "Step 2/4: Building new image..."
  if ! bash "$SCRIPT_DIR/build-image.sh"; then
    err "Image build failed. Supervisors are STOPPED — fix and restart manually."
    return 1
  fi

  # Step 3: Verify contract.
  log "Step 3/4: Verifying image contract..."
  local contract
  contract="$(docker image inspect --format '{{ index .Config.Labels "dev.aidoc-flow.runner.contract" }}' aidoc-flow-runner:latest 2>/dev/null || true)"
  if [ -z "$contract" ] || [ "$contract" = "<no value>" ]; then
    warn "New image has no runner-contract label — run-ephemeral.sh will warn."
  else
    log "  Image contract: $contract"
  fi

  # Step 4: Restart supervisors.
  log "Step 4/4: Starting supervisors (new image will be used for next jobs)..."
  while read -r inst; do
    log "  starting ci-runner@$inst"
    systemctl --user start "ci-runner@$inst.service" &
  done <<< "$instances"
  wait

  log "Update complete. New image active for $repo."
  echo ""
  cmd_status "$repo"
}

# ── scale ────────────────────────────────────────────────────────────────────

cmd_scale() {
  local repo="$1" target="$2" dry_run="${3:-0}"
  local instances current
  instances="$(list_instances "$repo")"
  current="$(echo "$instances" | grep -c . || true)"

  if [ "$current" -eq 0 ] && [ "$target" -gt 0 ]; then
    # Fresh provisioning — no existing instances.
    log "No existing instances for $repo. Provisioning $target new instance(s)."
    local labels="${RUNNER_LABELS:-self-hosted,ci,ephemeral}"
    for i in $(seq 1 "$target"); do
      local inst="${repo##*/}-${i}"
      log "  Provisioning ci-runner@$inst"
      if [ "$dry_run" = 0 ]; then
        TARGET_REPO="$repo" RUNNER_LABELS="$labels" INSTANCE="$inst" \
          bash "$SCRIPT_DIR/provision-runner.sh"
      else
        echo "  [dry-run] TARGET_REPO=$repo INSTANCE=$inst bash provision-runner.sh"
      fi
    done
    return 0
  fi

  if [ "$target" -eq "$current" ]; then
    log "Already at $target instance(s) for $repo. Nothing to do."
    return 0
  fi

  if [ "$target" -gt "$current" ]; then
    # Scale up: provision new instances.
    local labels
    labels="$(instance_labels "$(echo "$instances" | head -1)")"
    labels="${labels:-self-hosted,ci,ephemeral}"
    local needed=$((target - current))
    log "Scaling up: $current → $target ($needed new instance(s))"

    for i in $(seq $((current + 1)) "$target"); do
      local inst="${repo##*/}-${i}"
      log "  Provisioning ci-runner@$inst"
      if [ "$dry_run" = 0 ]; then
        TARGET_REPO="$repo" RUNNER_LABELS="$labels" INSTANCE="$inst" \
          bash "$SCRIPT_DIR/provision-runner.sh"
      else
        echo "  [dry-run] TARGET_REPO=$repo INSTANCE=$inst bash provision-runner.sh"
      fi
    done
    return 0
  fi

  # Scale down: stop excess instances (newest first).
  local excess=$((current - target))
  log "Scaling down: $current → $target (removing $excess instance(s))"

  local to_remove
  to_remove="$(echo "$instances" | tail -n "$excess")"
  while read -r inst; do
    log "  Stopping and disabling ci-runner@$inst"
    if [ "$dry_run" = 0 ]; then
      systemctl --user stop "ci-runner@$inst.service" 2>/dev/null || true
      systemctl --user disable "ci-runner@$inst.service" 2>/dev/null || true
      rm -f "$SERVICE_DIR/ci-runner@${inst}.service"
      rm -f "$ENV_DIR/${inst}.env"
    else
      echo "  [dry-run] stop + disable ci-runner@$inst, remove env + service files"
    fi
  done <<< "$to_remove"

  if [ "$dry_run" = 0 ]; then
    systemctl --user daemon-reload
  fi

  log "Scale complete. $target instance(s) for $repo."
}

# ── health ───────────────────────────────────────────────────────────────────

cmd_health() {
  local repo_filter="${1:-}"
  local instances issues=0
  instances="$(list_instances "$repo_filter")"

  if [ -z "$instances" ]; then
    log "No ci-runner instances found."
    return 0
  fi

  log "Health check — $(echo "$instances" | wc -l) instance(s)"
  echo ""

  # Check 1: Instance state.
  log "Instance states:"
  while read -r inst; do
    local state repo
    state="$(systemctl --user is-active "ci-runner@$inst.service" 2>/dev/null || echo "inactive")"
    repo="$(instance_repo "$inst")"
    if [ "$state" = "active" ]; then
      printf '  %-20s %-10s %s\n' "$inst" "OK" "$repo"
    else
      printf '  %-20s %-10s %s\n' "$inst" "FAIL" "$repo"
      issues=$((issues + 1))
    fi
  done <<< "$instances"
  echo ""

  # Check 2: Docker daemon.
  log "Docker daemon:"
  if docker info &>/dev/null; then
    echo "  OK — daemon reachable"
  else
    echo "  FAIL — daemon unreachable"
    issues=$((issues + 1))
  fi
  echo ""

  # Check 3: Runner image.
  log "Runner image:"
  local img_contract min_contract
  img_contract="$(docker image inspect --format '{{ index .Config.Labels "dev.aidoc-flow.runner.contract" }}' aidoc-flow-runner:latest 2>/dev/null || true)"
  min_contract="$(grep -m1 'RUNNER_CONTRACT_MIN=' "$SCRIPT_DIR/run-ephemeral.sh" 2>/dev/null | grep -oE '[0-9]+' || echo 0)"
  if [ -z "$img_contract" ] || [ "$img_contract" = "<no value>" ]; then
    echo "  WARN — no contract label (host has not rebuilt since #458)"
    issues=$((issues + 1))
  elif [ "$img_contract" -ge "$min_contract" ] 2>/dev/null; then
    echo "  OK — contract $img_contract >= $min_contract"
  else
    echo "  FAIL — contract $img_contract < $min_contract (rebuild needed)"
    issues=$((issues + 1))
  fi
  echo ""

  # Check 4: GitHub connectivity.
  log "GitHub API:"
  if gh api rate_limit --jq '.rate.remaining' &>/dev/null; then
    local remaining
    remaining="$(gh api rate_limit --jq '.rate.remaining' 2>/dev/null)"
    echo "  OK — $remaining requests remaining"
    if [ "$remaining" -lt 100 ]; then
      echo "  WARN — low API budget ($remaining remaining)"
      issues=$((issues + 1))
    fi
  else
    echo "  FAIL — cannot reach GitHub API"
    issues=$((issues + 1))
  fi
  echo ""

  # Check 5: Queued jobs (potential runner starvation).
  log "Queue status:"
  local repos_seen=""
  while read -r inst; do
    local repo
    repo="$(instance_repo "$inst")"
    echo "$repos_seen" | grep -qF "|$repo|" && continue
    repos_seen="${repos_seen}|$repo|"
    local queued
    queued="$(count_queued_jobs "$repo")"
    if [ "$queued" -gt 0 ]; then
      echo "  $repo: $queued queued job(s) — possible runner starvation"
      issues=$((issues + 1))
    else
      echo "  $repo: queue clear"
    fi
  done <<< "$instances"
  echo ""

  # Summary.
  if [ "$issues" -eq 0 ]; then
    log "Health check: ALL CLEAR"
  else
    warn "Health check: $issues issue(s) found"
  fi
  return "$issues"
}

# ── main ─────────────────────────────────────────────────────────────────────

main() {
  local cmd="" repo="" count="" timeout="" force=0 dry_run=0

  while [ $# -gt 0 ]; do
    case "$1" in
      status|drain|update|scale|health) cmd="$1"; shift ;;
      --repo)    repo="$2"; shift 2 ;;
      --count)   count="$2"; shift 2 ;;
      --timeout) timeout="$2"; shift 2 ;;
      --force)   force=1; shift ;;
      --dry-run) dry_run=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) err "Unknown argument: $1"; usage; exit 1 ;;
    esac
  done

  if [ -z "$cmd" ]; then
    err "No command specified."
    usage
    exit 1
  fi

  case "$cmd" in
    status)
      cmd_status "$repo"
      ;;
    drain)
      [ -z "$repo" ] && { err "--repo required for drain"; exit 1; }
      if [ "$force" -eq 0 ]; then
        echo "This will stop all runner supervisors for $repo."
        echo "In-flight jobs will finish, but no new jobs will be accepted."
        read -rp "Continue? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || { log "Aborted."; exit 0; }
      fi
      cmd_drain "$repo" "${timeout:-$DRAIN_TIMEOUT}"
      ;;
    update)
      [ -z "$repo" ] && { err "--repo required for update"; exit 1; }
      cmd_update "$repo" "$dry_run"
      ;;
    scale)
      [ -z "$repo" ] && { err "--repo required for scale"; exit 1; }
      [ -z "$count" ] && { err "--count required for scale"; exit 1; }
      cmd_scale "$repo" "$count" "$dry_run"
      ;;
    health)
      cmd_health "$repo"
      ;;
  esac
}

main "$@"
