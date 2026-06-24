#!/usr/bin/env bash
# aidoc-flow-ci install.sh — bootstrap a consumer repo with default callers,
# default .github/ai-review/config.json, and canonical labels. Idempotent;
# safe to re-run; preserves existing files (local override always wins).
#
# Templates are fetched via raw GitHub URLs (the pinned CI_TAG) — works in
# both process-substitution mode (`bash <(curl …)`) AND local-clone mode.
# Earlier BASH_SOURCE-based design failed under process-sub because
# BASH_SOURCE points at /dev/fd/N there (caught on aidoc-flow-operations
# PR #108 review).
#
# Usage:
#   bash install.sh <owner/repo> [--visibility public|private]
#   CI_TAG=ci/v1.0.0 bash install.sh <owner/repo> --visibility private
#
# Requires: gh (authenticated for write on the target repo) + curl + git.

set -euo pipefail

TARGET_REPO="${1:?usage: $0 <owner/repo> [--visibility public|private]}"
shift
VISIBILITY="private"
while [ $# -gt 0 ]; do
  case "$1" in
    --visibility) VISIBILITY="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
case "$VISIBILITY" in public|private) ;; *) echo "--visibility must be public|private" >&2; exit 1 ;; esac

CI_TAG="${CI_TAG:-ci/v1.0.0}"
TEMPLATE_BASE="https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${CI_TAG}/install/templates"

echo "==> bootstrapping $TARGET_REPO (visibility=$VISIBILITY, tag=$CI_TAG)"

# Clone the consumer to a stable user-visible location (NOT a temp dir
# with auto-cleanup trap) — the user needs to inspect + commit after this
# script exits.
WORK_DIR="${WORK_DIR:-$PWD/aidoc-flow-ci-bootstrap-$$}"
gh repo clone "$TARGET_REPO" "$WORK_DIR/consumer" -- --depth 1
cd "$WORK_DIR/consumer"

mkdir -p .github/workflows .github/ai-review

fetch_template() {
  # $1 = source path under install/templates/; $2 = destination path
  local src="$1" dst="$2"
  if ! curl -fsSL "${TEMPLATE_BASE}/${src}" -o "${dst}"; then
    echo "  FAIL  failed to fetch ${TEMPLATE_BASE}/${src}" >&2
    return 1
  fi
}

# Drop the default consumer-side callers. Preserve existing files.
for wf in ai-review composition; do
  if [ -f ".github/workflows/${wf}.yml" ]; then
    echo "  preserve  .github/workflows/${wf}.yml (already exists — local override)"
  else
    fetch_template "workflows/${wf}-${VISIBILITY}.yml" ".github/workflows/${wf}.yml" || exit 1
    echo "  add       .github/workflows/${wf}.yml"
  fi
done

if [ -f ".github/ai-review/config.json" ]; then
  echo "  preserve  .github/ai-review/config.json (already exists)"
else
  fetch_template "config.json.template" ".github/ai-review/config.json" || exit 1
  echo "  add       .github/ai-review/config.json"
fi

# Canonical labels — idempotent + fail-loud. Prefetch existing labels so
# we don't conflate "already exists" with real failures (auth / permission
# / network / invalid repo).
echo "==> creating canonical labels on $TARGET_REPO"
LABELS_TMP=$(mktemp)
fetch_template "labels.json" "$LABELS_TMP" || exit 1
EXISTING_TMP=$(mktemp)
if ! gh label list --json name,color,description -R "$TARGET_REPO" > "$EXISTING_TMP" 2>/dev/null; then
  echo "  FAIL  failed to list existing labels on $TARGET_REPO (auth/permission/network?). Cannot safely idempotent-create." >&2
  rm -f "$LABELS_TMP" "$EXISTING_TMP"
  exit 1
fi
python3 -c "
import json, subprocess, sys
desired = json.load(open('$LABELS_TMP'))
existing_by_name = {l['name']: l for l in json.load(open('$EXISTING_TMP'))}
failures = 0
for d in desired:
    name = d['name']
    if name in existing_by_name:
        cur = existing_by_name[name]
        if cur.get('color') == d['color'] and cur.get('description') == d['description']:
            print(f'  exists   label {name}')
        else:
            print(f'  WARN     label {name} exists with different color/description (color: {cur.get(\"color\")} vs {d[\"color\"]}; not overwriting)')
        continue
    try:
        subprocess.run(['gh', 'label', 'create', name, '--color', d['color'], '--description', d['description'], '-R', '$TARGET_REPO'], check=True, capture_output=True)
        print(f'  add      label {name}')
    except subprocess.CalledProcessError as e:
        stderr = (e.stderr or b'').decode('utf-8', errors='replace').strip()
        print(f'  FAIL     gh label create {name} failed (exit {e.returncode}): {stderr}', file=sys.stderr)
        failures += 1
sys.exit(1 if failures > 0 else 0)
"
LABEL_RC=$?
rm -f "$LABELS_TMP" "$EXISTING_TMP"
if [ "$LABEL_RC" -ne 0 ]; then
  echo "==> ABORT: $LABEL_RC label-creation failure(s); the consumer may be missing canonical labels. Fix the failures and re-run."
  exit "$LABEL_RC"
fi

echo ""
echo "==> done. Next steps (founder):"
echo "    1. Inspect bootstrapped files: cd $WORK_DIR/consumer && git diff"
echo "    2. Commit + push + open PR on the consumer"
echo "    3. Add reviewer App secrets (APP_REVIEWER_1_ID + APP_REVIEWER_1_KEY) to the consumer"
echo "    4. After CI green, set vars.APP_REVIEWER_1_BOT_ID + branch protection per IPLAN-0016 §2a-v3"
echo "    5. (Cleanup, your choice) rm -rf $WORK_DIR"
