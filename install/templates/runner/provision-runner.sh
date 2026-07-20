#!/usr/bin/env bash
# Provision a single-use CI runner pool for one repository.
#
# The ONLY documented install path for the ci-runner@ systemd unit — it
# substitutes the unit template's @RUNNER_HOME@ ExecStart placeholder with
# this directory's absolute path (systemd does not expand env vars in
# ExecStart), builds the runner image, writes the per-instance env file,
# and enables the user service. Do not `cp` ci-runner@.service by hand.
#
# Usage (TARGET_REPO is required — no default):
#   TARGET_REPO=owner/repo bash provision-runner.sh
#   TARGET_REPO=owner/repo INSTANCE=myrepo bash provision-runner.sh
#
# Migrating from an older label scheme? Override the labels for the
# coexistence window so old-label and new-label jobs both find a runner,
# then re-run with the final labels once the migration PR merges:
#   TARGET_REPO=owner/repo \
#     RUNNER_LABELS=self-hosted,old-label,ci-runner,single-use \
#     bash provision-runner.sh
#
# Pass --dry-run to inspect without changing state.
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
TARGET_REPO="${TARGET_REPO:?set TARGET_REPO=owner/repo}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,ci-runner,single-use}"
INSTANCE="${INSTANCE:-${TARGET_REPO##*/}}"
ENV_DIR="${ENV_DIR:-$HOME/.config/ci-runner}"
SERVICE_DIR="${SERVICE_DIR:-$HOME/.config/systemd/user}"
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --target-repo) TARGET_REPO="$2"; shift 2 ;;
    --labels) RUNNER_LABELS="$2"; shift 2 ;;
    --instance) INSTANCE="$2"; shift 2 ;;
    *) echo "unknown arg: $1"; exit 1 ;;
  esac
done

ENV_FILE="$ENV_DIR/$INSTANCE.env"
SERVICE_FILE="$SERVICE_DIR/ci-runner@.service"

log() { printf '==> %s  %s\n' "$(date -u +%H:%M:%S)" "$*"; }

step_build() {
  log "building runner image"
  if [ "$DRY_RUN" = 1 ]; then
    echo "  [dry-run] docker build --pull -t aidoc-flow-runner:latest $SCRIPT_DIR/"
    return
  fi
  bash "$SCRIPT_DIR/build-image.sh"
}

step_install_service() {
  log "installing ci-runner@.service (ExecStart -> $SCRIPT_DIR/run-ephemeral.sh)"
  mkdir -p "$ENV_DIR" "$SERVICE_DIR"
  if [ "$DRY_RUN" = 1 ]; then
    echo "  [dry-run] sed 's|@RUNNER_HOME@|$SCRIPT_DIR|' $SCRIPT_DIR/ci-runner@.service > $SERVICE_FILE"
    return
  fi
  # Substitute the @RUNNER_HOME@ ExecStart placeholder with this directory —
  # the template unit is NOT installable by raw cp (see its header).
  sed "s|@RUNNER_HOME@|$SCRIPT_DIR|" "$SCRIPT_DIR/ci-runner@.service" > "$SERVICE_FILE"
}

step_env() {
  log "writing $ENV_FILE"
  if [ "$DRY_RUN" = 1 ]; then
    echo "  [dry-run] TARGET_REPO=$TARGET_REPO"
    echo "  [dry-run] RUNNER_LABELS=$RUNNER_LABELS"
    return
  fi
  cat > "$ENV_FILE" <<EOF
TARGET_REPO=$TARGET_REPO
RUNNER_LABELS=$RUNNER_LABELS
EOF
  chmod 600 "$ENV_FILE"
}

step_linger() {
  if [ "$DRY_RUN" = 1 ]; then
    echo "  [dry-run] loginctl enable-linger $USER"
    return
  fi
  if command -v loginctl >/dev/null 2>&1; then
    log "enabling linger for $USER"
    loginctl enable-linger "$USER" || true
  fi
}

step_reload() {
  if [ "$DRY_RUN" = 1 ]; then
    echo "  [dry-run] systemctl --user daemon-reload"
    return
  fi
  log "reloading systemd user units"
  systemctl --user daemon-reload
}

step_enable() {
  if [ "$DRY_RUN" = 1 ]; then
    echo "  [dry-run] systemctl --user enable --now ci-runner@$INSTANCE"
    return
  fi
  log "enabling and starting ci-runner@$INSTANCE"
  systemctl --user enable --now "ci-runner@$INSTANCE"
}

step_status() {
  sleep 2
  if [ "$DRY_RUN" = 1 ]; then
    echo "  [dry-run] systemctl --user status ci-runner@$INSTANCE"
    return
  fi
  systemctl --user status "ci-runner@$INSTANCE" || true
}

step_summary() {
  echo ""
  echo "Runner configured:"
  echo "  repo:     $TARGET_REPO"
  echo "  labels:   $RUNNER_LABELS"
  echo "  instance: $INSTANCE"
  echo "  env file: $ENV_FILE"
  echo ""
  echo "Verify the runner picks up jobs:"
  echo "  systemctl --user status ci-runner@$INSTANCE"
  echo "  journalctl --user -u ci-runner@$INSTANCE -f"
  echo ""
  echo "Labels will appear on GitHub under:"
  echo "  https://github.com/$TARGET_REPO/settings/actions/runners"
  echo "  (runners self-register with the labels from RUNNER_LABELS)"
}

echo "============================================"
echo "  flow-ci runner provisioner"
echo "  repo:     $TARGET_REPO"
echo "  labels:   $RUNNER_LABELS"
echo "  instance: $INSTANCE"
echo "  dry-run:  $DRY_RUN"
echo "============================================"
echo ""

step_build
step_install_service
step_env
step_linger
step_reload
step_enable
step_status
step_summary

log "done."
