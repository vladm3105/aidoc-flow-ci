#!/usr/bin/env bash
# aidoc-flow-ci install.sh — bootstrap a consumer repo with default
# callers, canonical labels, self-review canon (scripts/pre_push_check.sh
# + .pre-commit-config.yaml merge), and .github/ai-review/config.json.
# Idempotent; safe to re-run; preserves existing files (local override
# always wins); .pre-commit-config.yaml merges canon block via CANON
# marker per PLAN-002 §5.2 (M5 fix).
#
# Templates are fetched via raw GitHub URLs (the pinned CI_TAG) — works in
# both process-substitution mode (`bash <(curl …)`) AND local-clone mode.
# Earlier BASH_SOURCE-based design failed under process-sub because
# BASH_SOURCE points at /dev/fd/N there (caught on aidoc-flow-operations
# PR #108 review).
#
# Usage:
#   bash install.sh <owner/repo> [--visibility public|private]
#   CI_TAG=ci/v1.6.0 bash install.sh <owner/repo> --visibility private
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

# Default pinned to the current stable release tag. Bumped on each
# release cut so consumers who don't set CI_TAG explicitly get a frozen
# tag (not the moving `main`).
CI_TAG="${CI_TAG:-ci/v1.6.0}"
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

# --- PLAN-003 PR-V2: CLAUDE.md canon template bootstrap ---
# If consumer has no CLAUDE.md, install the canon template with all
# placeholders present (consumer MUST fill placeholders before commit).
# If consumer has a CLAUDE.md, verify presence of the 5 required
# sections (per PLAN-003 §4.3) + the Per-repo governance table anchor
# (per §4.5). Print a merge suggestion; do NOT auto-modify existing
# CLAUDE.md — too risky given the file's session-level importance.
if [ -f "CLAUDE.md" ]; then
  echo "  preserve  CLAUDE.md (already exists)"
  # Verify canonical section presence per §4.3 + §4.5. All 5 required
  # anchors: H1 title + 4 H2 sections.
  MISSING_SECTIONS=()
  grep -qE "^# CLAUDE\.md" CLAUDE.md || MISSING_SECTIONS+=("# CLAUDE.md — <REPO_FRIENDLY_NAME>")
  grep -qE "^## What this (repo|project) is" CLAUDE.md || MISSING_SECTIONS+=("## What this repo is")
  grep -qE "^## Per-repo governance(\s+[—-].*)?\s*$" CLAUDE.md || MISSING_SECTIONS+=("## Per-repo governance (with optional em-dash tail)")
  grep -qE "^## GitHub operations" CLAUDE.md || MISSING_SECTIONS+=("## GitHub operations")
  grep -qE "^## Workspace standards" CLAUDE.md || MISSING_SECTIONS+=("## Workspace standards (aidoc-flow canon — read the canonical rules directly)")
  if [ "${#MISSING_SECTIONS[@]}" -gt 0 ]; then
    echo "  WARN      CLAUDE.md is missing the following canonical sections (per PLAN-003 §4.3):"
    for section in "${MISSING_SECTIONS[@]}"; do
      echo "              - $section"
    done
    echo "            fetch template + merge manually:"
    echo "              curl -fsSL ${TEMPLATE_BASE}/CLAUDE.md.template"
    echo "            do NOT auto-overwrite — existing CLAUDE.md has session-level"
    echo "            content that must be preserved. See PLAN-003 §5.4c for the"
    echo "            per-repo rewrite scope + Wave rollout guidance."
  fi
else
  fetch_template "CLAUDE.md.template" "CLAUDE.md" || exit 1
  echo "  add       CLAUDE.md (template with placeholders — FILL BEFORE COMMIT: <REPO_FRIENDLY_NAME>, <REPO_PURPOSE_ONE_LINER>, table cells, etc.)"
fi

# --- PLAN-002 PR-U2: self-review canon (pre_push_check.sh + pre-commit wiring) ---

# scripts/pre_push_check.sh — exact-match canon. Preserve if already
# present (consumer may have added local edits pre-canon-adoption).
# L2 fold: script-branded error if `scripts` exists as a file.
if [ -e scripts ] && [ ! -d scripts ]; then
  echo "  FAIL: 'scripts' exists in the consumer repo but is not a directory — cannot install canon script" >&2
  exit 1
fi
mkdir -p scripts
if [ -f "scripts/pre_push_check.sh" ]; then
  echo "  preserve  scripts/pre_push_check.sh (already exists — inspect for canon parity via apply-standards.sh --check)"
  # L3 fold: advise on executable bit.
  if [ ! -x scripts/pre_push_check.sh ]; then
    echo "  WARN      existing scripts/pre_push_check.sh is not executable — 'chmod +x scripts/pre_push_check.sh' recommended (pre-commit's language: script needs it)"
  fi
else
  fetch_template "pre_push_check.sh" "scripts/pre_push_check.sh" || exit 1
  chmod +x scripts/pre_push_check.sh
  echo "  add       scripts/pre_push_check.sh"
fi

# .pre-commit-config.yaml — merge canon hook block idempotently.
# Idempotency key: canonical marker `# CANON: aidoc-flow-ci pre_push_check`.
# If present → no-op. If absent → merge (append hook block; upgrade
# default_install_hook_types root key from [pre-commit] → [pre-commit,
# pre-push] if consumer had only [pre-commit]).
PRECOMMIT_TMP=$(mktemp)
fetch_template "pre-commit-hook-block.yaml" "$PRECOMMIT_TMP" || { rm -f "$PRECOMMIT_TMP"; exit 1; }
if [ ! -f ".pre-commit-config.yaml" ]; then
  # Consumer has no pre-commit config — install canon fragment verbatim.
  # (Canon fragment carries the marker at line 1 → subsequent re-runs no-op.)
  cp "$PRECOMMIT_TMP" .pre-commit-config.yaml
  echo "  add       .pre-commit-config.yaml (from canon fragment)"
elif grep -qF "# CANON: aidoc-flow-ci pre_push_check" .pre-commit-config.yaml; then
  echo "  preserve  .pre-commit-config.yaml (canon marker present — no-op)"
else
  # M2 fold: fail-fast on missing YAML library BEFORE entering merge, so
  # the operator gets an actionable message instead of a generic FAIL.
  # M1 fold: prefer ruamel.yaml (round-trip preserves consumer comments);
  # fall back to PyYAML with explicit WARN about comment stripping.
  yaml_lib=""
  if python3 -c 'import ruamel.yaml' 2>/dev/null; then
    yaml_lib="ruamel"
  elif python3 -c 'import yaml' 2>/dev/null; then
    yaml_lib="pyyaml"
    echo "  WARN      ruamel.yaml unavailable — falling back to PyYAML which STRIPS consumer comments from .pre-commit-config.yaml. Install ruamel.yaml (pip install ruamel.yaml) to preserve comments." >&2
  else
    echo "  FAIL: neither ruamel.yaml nor PyYAML available — 'pip install ruamel.yaml' (preferred) or 'pip install pyyaml' and re-run install.sh" >&2
    rm -f "$PRECOMMIT_TMP"
    exit 1
  fi

  # M3 fold: put tempfile on the target filesystem so `mv` is atomic
  # rename(2), not cross-fs copy+unlink (which would leave a truncated
  # .pre-commit-config.yaml on SIGINT mid-mv).
  MERGE_TMP=$(mktemp ./.pre-commit-config.yaml.tmp.XXXXXX)
  if python3 - "$PRECOMMIT_TMP" "$MERGE_TMP" "$yaml_lib" <<'PYEOF' ; then
import sys

canon_path, out_path, yaml_lib = sys.argv[1], sys.argv[2], sys.argv[3]

if yaml_lib == "ruamel":
    from ruamel.yaml import YAML
    ry = YAML(typ='rt')
    ry.preserve_quotes = True
    load = lambda p: ry.load(open(p))
    dump = lambda obj, f: ry.dump(obj, f)
else:
    import yaml
    load = lambda p: yaml.safe_load(open(p))
    dump = lambda obj, f: yaml.safe_dump(obj, f, default_flow_style=False, sort_keys=False)

try:
    consumer = load('.pre-commit-config.yaml') or {}
except Exception as e:
    print(f"  FAIL  .pre-commit-config.yaml parse error: {e}", file=sys.stderr)
    sys.exit(1)
try:
    canon = load(canon_path) or {}
except Exception as e:
    print(f"  FAIL  canon fragment parse error: {e}", file=sys.stderr)
    sys.exit(1)

# Root-key upgrade: default_install_hook_types must include pre-push.
# L1 fold: preserve consumer intent — if scalar (invalid but real), coerce
# to a single-element list rather than resetting to canonical default.
consumer_hooks = consumer.get('default_install_hook_types', ['pre-commit'])
if isinstance(consumer_hooks, str):
    consumer_hooks = [consumer_hooks]
elif not isinstance(consumer_hooks, list):
    consumer_hooks = ['pre-commit']
canon_hooks = canon.get('default_install_hook_types', ['pre-commit', 'pre-push'])
for h in canon_hooks:
    if h not in consumer_hooks:
        consumer_hooks.append(h)
consumer['default_install_hook_types'] = consumer_hooks

# Append canon repos-block entries (which are hooks). Preserve existing.
consumer_repos = consumer.setdefault('repos', [])
for canon_repo in canon.get('repos', []):
    # De-dup by structural equality. Canon uses `repo: local` + a
    # single hook id `aidoc-flow-pre-push` — check for exact match.
    if canon_repo not in consumer_repos:
        consumer_repos.append(canon_repo)

with open(out_path, 'w') as f:
    # Preserve the canon marker line at top so future re-runs no-op.
    f.write("# CANON: aidoc-flow-ci pre_push_check (idempotency marker per PLAN-002 §5.2)\n")
    dump(consumer, f)
PYEOF
    mv "$MERGE_TMP" .pre-commit-config.yaml
    echo "  merge     .pre-commit-config.yaml (canon block appended; default_install_hook_types upgraded if needed; ${yaml_lib}-backed)"
  else
    rm -f "$MERGE_TMP" "$PRECOMMIT_TMP"
    echo "  FAIL      .pre-commit-config.yaml merge failed — inspect manually" >&2
    exit 1
  fi
fi
rm -f "$PRECOMMIT_TMP"

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
