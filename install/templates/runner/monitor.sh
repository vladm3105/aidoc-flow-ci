#!/usr/bin/env bash
# Runner pool monitor — continuous health + queue-depth reporting.
#
# Runs as a systemd timer or cron job. Reports runner health, queue depth,
# and recent job outcomes. Outputs structured logs suitable for alerting.
#
# Usage:
#   monitor.sh                      # one-shot check all repos
#   monitor.sh --repo owner/repo    # one repo
#   monitor.sh --watch              # continuous mode (every 60s)
#   monitor.sh --json               # JSON output for alerting
#
# Exit codes:
#   0  all clear
#   1  error (missing deps, API failure)
#   2  warning (degraded but functional)
#   3  critical (runners down, queue building)
#
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ENV_DIR="${ENV_DIR:-$HOME/.config/ci-runner}"
WATCH_INTERVAL="${WATCH_INTERVAL:-60}"
QUEUE_WARN="${QUEUE_WARN:-3}"       # warn if queued jobs exceed this
QUEUE_CRIT="${QUEUE_CRIT:-8}"       # critical if queued jobs exceed this
STALE_MINUTES="${STALE_MINUTES:-30}" # warn if a runner hasn't picked up work in this long

log()  { printf '%s  %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
warn() { log "WARN  $*"; }
crit() { log "CRIT  $*"; }
ok()   { log "OK    $*"; }

# ── helpers ──────────────────────────────────────────────────────────────────

# Discover all repos from env files.
discover_repos() {
  local repos=""
  for env_file in "$ENV_DIR"/*.env; do
    [ -f "$env_file" ] || continue
    local repo
    repo="$(grep -m1 '^TARGET_REPO=' "$env_file" | cut -d= -f2)"
    [ -n "$repo" ] && echo "$repos" | grep -qF "$repo" || repos="${repos}${repo}"$'\n'
  done
  echo "$repos" | sort -u | grep .
}

# Count instances for a repo.
count_instances() {
  local repo="$1" count=0
  for env_file in "$ENV_DIR"/*.env; do
    [ -f "$env_file" ] || continue
    local inst_repo
    inst_repo="$(grep -m1 '^TARGET_REPO=' "$env_file" | cut -d= -f2)"
    [ "$inst_repo" = "$repo" ] && count=$((count + 1))
  done
  echo "$count"
}

# Count active (running) instances for a repo.
count_active_instances() {
  local repo="$1" count=0
  for env_file in "$ENV_DIR"/*.env; do
    [ -f "$env_file" ] || continue
    local inst_repo inst_name
    inst_repo="$(grep -m1 '^TARGET_REPO=' "$env_file" | cut -d= -f2)"
    [ "$inst_repo" = "$repo" ] || continue
    inst_name="$(basename "$env_file" .env)"
    systemctl --user is-active "ci-runner@${inst_name}.service" &>/dev/null && count=$((count + 1))
  done
  echo "$count"
}

# Get queue depth from GitHub API.
get_queue_depth() {
  local repo="$1"
  gh api "repos/${repo}/actions/runs" --paginate \
    --jq '[.workflow_runs[] | select(.status=="queued")] | length' 2>/dev/null || echo -1
}

# Get running job count.
get_running_count() {
  local repo="$1"
  gh api "repos/${repo}/actions/runs" --paginate \
    --jq '[.workflow_runs[] | select(.status=="in_progress")] | length' 2>/dev/null || echo -1
}

# Get recent job outcomes (last 10).
get_recent_outcomes() {
  local repo="$1"
  gh api "repos/${repo}/actions/runs?per_page=10" \
    --jq '.workflow_runs[] | "\(.conclusion // .status) \(.name) (\(.head_branch))"' 2>/dev/null || echo "API unavailable"
}

# Get runner versions from GitHub.
get_runner_versions() {
  local repo="$1"
  gh api "repos/${repo}/actions/runners" --paginate \
    --jq '.runners[] | select(.status=="online") | "\(.name) v\(.version)"' 2>/dev/null || echo "API unavailable"
}

# ── single-repo check ───────────────────────────────────────────────────────

check_repo() {
  local repo="$1" json_mode="${2:-0}"
  local total active queued running severity="ok"
  local issues=""

  total="$(count_instances "$repo")"
  active="$(count_active_instances "$repo")"
  queued="$(get_queue_depth "$repo")"
  running="$(get_running_count "$repo")"

  # Check: any instances configured?
  if [ "$total" -eq 0 ]; then
    severity="warn"
    issues="${issues}no instances configured; "
  fi

  # Check: all instances active?
  if [ "$total" -gt 0 ] && [ "$active" -lt "$total" ]; then
    severity="warn"
    issues="${issues}$((total - active))/$total instances inactive; "
  fi

  # Check: queue depth.
  if [ "$queued" -ge "$QUEUE_CRIT" ]; then
    severity="crit"
    issues="${issues}queue depth $queued >= critical threshold $QUEUE_CRIT; "
  elif [ "$queued" -ge "$QUEUE_WARN" ]; then
    [ "$severity" != "crit" ] && severity="warn"
    issues="${issues}queue depth $queued >= warning threshold $QUEUE_WARN; "
  fi

  # Check: API reachable?
  if [ "$queued" -eq -1 ]; then
    severity="crit"
    issues="${issues}GitHub API unreachable; "
    queued="N/A"
  fi
  if [ "$running" -eq -1 ]; then
    running="N/A"
  fi

  # Output.
  if [ "$json_mode" = 1 ]; then
    cat <<EOF
{
  "repo": "$repo",
  "severity": "$severity",
  "instances_total": $total,
  "instances_active": $active,
  "queued_jobs": "$queued",
  "running_jobs": "$running",
  "issues": "$(echo "$issues" | sed 's/; $//')"
}
EOF
  else
    echo ""
    log "=== $repo ==="
    echo "  Instances:  $active/$total active"
    echo "  Queue:      $queued queued, $running running"
    if [ -n "$issues" ]; then
      case "$severity" in
        crit) crit "$issues" ;;
        warn) warn "$issues" ;;
      esac
    else
      ok "all clear"
    fi
  fi

  case "$severity" in
    crit) return 3 ;;
    warn) return 2 ;;
    *)    return 0 ;;
  esac
}

# ── main ─────────────────────────────────────────────────────────────────────

main() {
  local repo="" watch=0 json_mode=0 worst=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --repo)   repo="$2"; shift 2 ;;
      --watch)  watch=1; shift ;;
      --json)   json_mode=1; shift ;;
      -h|--help)
        echo "Usage: $(basename "$0") [--repo owner/repo] [--watch] [--json]"
        exit 0
        ;;
      *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
  done

  # One-shot or continuous.
  run_checks() {
    local repos
    if [ -n "$repo" ]; then
      repos="$repo"
    else
      repos="$(discover_repos)"
    fi

    if [ -z "$repos" ]; then
      log "No runner repos found in $ENV_DIR"
      return 1
    fi

    worst=0
    local first=1
    while read -r r; do
      [ -z "$r" ] && continue
      local rc=0
      check_repo "$r" "$json_mode" || rc=$?
      [ "$rc" -gt "$worst" ] && worst="$rc"
      first=0
    done <<< "$repos"

    if [ "$json_mode" = 0 ]; then
      echo ""
      case "$worst" in
        0) ok "All repos healthy" ;;
        2) warn "Some repos degraded" ;;
        3) crit "Critical issues found" ;;
      esac
    fi
    return "$worst"
  }

  if [ "$watch" = 1 ]; then
    log "Monitoring (every ${WATCH_INTERVAL}s, Ctrl-C to stop)"
    while true; do
      run_checks || true
      sleep "$WATCH_INTERVAL"
    done
  else
    run_checks
  fi
}

main "$@"
