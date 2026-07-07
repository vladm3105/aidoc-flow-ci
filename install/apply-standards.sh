#!/usr/bin/env bash
# aidoc-flow-ci install/apply-standards.sh — apply the repo-standards
# canon (docs/REPO_STANDARDS.md) to a consumer repo. PR-B2 ships the
# NON-MUTATING modes only (--check, --dry-run, --report). PR-C adds
# --apply (server-side mutations require F5 blast-radius per
# REPO_ONBOARDING.md).
#
# Runs from a checked-out consumer repo (`cd <consumer-repo> && bash
# <path-to>/apply-standards.sh`). Compares local content-surface files
# against canon templates fetched from
# raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${CI_TAG}/install/templates/.
# Same pattern as sync/check-drift.sh.
#
# Surfaces checked in this PR (PR-B1 shipped these templates):
#   1. .github/CODEOWNERS                     — exact-match
#   2. .github/pull_request_template.md       — exact-match
#   3. .github/dependabot.yml                 — exact-match
#   4. .gitignore                             — subset (canon lines all present)
#   5. .gitattributes                         — subset (canon lines all present)
#
# Labels + server-side settings (branch protection, security,
# actions-permissions) are deferred to PR-C alongside --apply.
#
# Modes:
#   --check          drift check, exit 1 if any drift, quiet on green
#                    (no output at all when every surface is OK)
#   --dry-run        (default) preview what --apply WOULD do, exit 0
#   --report         emit JSON compliance report to stdout
#   --apply          RESERVED — errors "reserved for PR-C"
#
# Optional flags:
#   --ci-tag <tag>   canon tag to compare against (default: reads first
#                    consumer workflow's @ci/vX.Y.Z pin; falls back to
#                    CI_TAG env var; final fallback: main)
#   --repo <owner/repo>
#                    used only in --report JSON's `repo` field. File
#                    surfaces are always local; script does not fetch
#                    remote consumer files.
#   -h | --help      usage
#
# Exit codes:
#   0    green (or dry-run/report success)
#   1    drift found (--check only)
#   2    usage error (unknown arg, invalid --ci-tag, bash <4)
#   3    canon fetch failed
#
# Requires: bash 4+ (macOS: `brew install bash`), curl, diff, grep, sed.

set -uo pipefail

if (( BASH_VERSINFO[0] < 4 )); then
  echo "apply-standards: requires bash 4+ (current: ${BASH_VERSION:-unknown}). macOS: brew install bash" >&2
  exit 2
fi

usage() {
  sed -nE '/^# aidoc-flow-ci/,/^set /p' "$0" | sed -E 's/^# ?//; /^set /d'
  exit "${1:-0}"
}

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

# --- args ---
MODE="dry-run"
CI_TAG_OVERRIDE="${CI_TAG:-}"
REPO_LABEL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --check)   MODE="check"; shift ;;
    --dry-run) MODE="dry-run"; shift ;;
    --report)  MODE="report"; shift ;;
    --apply)
      echo "apply-standards: --apply is reserved for PR-C" >&2
      echo "apply-standards: server-side mutations require F5 blast-radius per REPO_ONBOARDING.md" >&2
      exit 2
      ;;
    --ci-tag)  CI_TAG_OVERRIDE="$2"; shift 2 ;;
    --repo)    REPO_LABEL="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "apply-standards: unknown arg: $1" >&2; usage 2 ;;
  esac
done

# --- resolve CI_TAG ---
resolve_ci_tag() {
  if [ -n "$CI_TAG_OVERRIDE" ]; then
    echo "$CI_TAG_OVERRIDE"; return
  fi
  local pin
  # sort -Vu picks the highest semver on repos mid-migration between
  # pins (mixed @ci/v1.4.3 + @ci/v1.5.1 → prefer v1.5.1). ASCII sort
  # would silently pick the lowest.
  pin=$(grep -hoE '@ci/v[0-9]+\.[0-9]+\.[0-9]+' .github/workflows/*.yml 2>/dev/null \
        | sort -Vu | tail -1)
  if [ -n "$pin" ]; then
    echo "${pin#@}"; return
  fi
  echo "main"
}
CI_TAG=$(resolve_ci_tag)
if ! [[ "$CI_TAG" =~ ^(main|ci/v[0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
  echo "apply-standards: invalid --ci-tag / CI_TAG value: $CI_TAG" >&2
  echo "apply-standards: expected 'main' or 'ci/vX.Y.Z'" >&2
  exit 2
fi
TEMPLATE_BASE="https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${CI_TAG}/install/templates"

# --- helpers ---
fetch_canon() {
  # $1 = template path under install/templates/; writes to stdout
  curl -fsSL "${TEMPLATE_BASE}/$1" 2>/dev/null || {
    echo "apply-standards: FATAL canon fetch failed: ${TEMPLATE_BASE}/$1" >&2
    exit 3
  }
}

exact_match_check() {
  # $1 = local path, $2 = template path — sets DRIFT_<n> globals
  local local_path="$1" template="$2"
  local canonical status
  canonical=$(mktemp)
  fetch_canon "$template" > "$canonical"
  if [ ! -f "$local_path" ]; then
    status="MISSING"
  elif diff -q "$local_path" "$canonical" >/dev/null 2>&1; then
    status="OK"
  else
    status="DRIFT"
  fi
  DRIFT_STATUS["$local_path"]="$status"
  DRIFT_TEMPLATE["$local_path"]="$template"
  DRIFT_CANONICAL["$local_path"]="$canonical"
  DRIFT_MODE["$local_path"]="exact"
  DRIFT_MISSING_LINES["$local_path"]=""
}

subset_check() {
  # $1 = local path, $2 = template path — canon lines all present in local
  local local_path="$1" template="$2"
  local canonical status missing_lines
  canonical=$(mktemp)
  fetch_canon "$template" > "$canonical"
  if [ ! -f "$local_path" ]; then
    status="MISSING"
    missing_lines=""
  else
    # Canon lines (non-comment, non-blank) not present verbatim in
    # local. Strip trailing whitespace from the canon line before the
    # match so a stray editor space in the template doesn't create a
    # phantom DRIFT the consumer can never resolve (M4).
    missing_lines=$(grep -vE '^\s*(#|$)' "$canonical" \
                    | while IFS= read -r line; do
                        line="${line%"${line##*[![:space:]]}"}"
                        [ -z "$line" ] && continue
                        grep -qxF "$line" "$local_path" || echo "$line"
                      done)
    if [ -z "$missing_lines" ]; then
      status="OK"
    else
      status="DRIFT"
    fi
  fi
  DRIFT_STATUS["$local_path"]="$status"
  DRIFT_TEMPLATE["$local_path"]="$template"
  DRIFT_CANONICAL["$local_path"]="$canonical"
  DRIFT_MODE["$local_path"]="subset"
  DRIFT_MISSING_LINES["$local_path"]="$missing_lines"
}

# --- run checks ---
declare -A DRIFT_STATUS DRIFT_TEMPLATE DRIFT_CANONICAL DRIFT_MODE DRIFT_MISSING_LINES

# EXIT trap: clean up tmpfiles regardless of exit path (including
# fetch_canon exit 3 mid-run). M3 fix.
# shellcheck disable=SC2329  # called via trap
cleanup_tmpfiles() {
  local f
  for f in "${DRIFT_CANONICAL[@]:-}"; do
    [ -n "$f" ] && rm -f "$f"
  done
}
trap cleanup_tmpfiles EXIT

exact_match_check ".github/CODEOWNERS"                 "CODEOWNERS.template"
exact_match_check ".github/pull_request_template.md"   "pull_request_template.md"
exact_match_check ".github/dependabot.yml"             "dependabot.yml"
subset_check      ".gitignore"                          ".gitignore.template"
subset_check      ".gitattributes"                      ".gitattributes.template"

# --- report ---
DRIFT_COUNT=0
MISSING_COUNT=0
OK_COUNT=0
for path in "${!DRIFT_STATUS[@]}"; do
  case "${DRIFT_STATUS[$path]}" in
    OK)      OK_COUNT=$((OK_COUNT + 1)) ;;
    DRIFT)   DRIFT_COUNT=$((DRIFT_COUNT + 1)) ;;
    MISSING) MISSING_COUNT=$((MISSING_COUNT + 1)) ;;
  esac
done

emit_human() {
  # --check is quiet on green: skip all output if nothing to report.
  if [ "$MODE" = "check" ] && [ $((DRIFT_COUNT + MISSING_COUNT)) -eq 0 ]; then
    return
  fi
  echo "apply-standards: canon @ ${CI_TAG}  (mode: ${MODE})"
  echo "apply-standards: OK=${OK_COUNT}  DRIFT=${DRIFT_COUNT}  MISSING=${MISSING_COUNT}"
  echo ""
  local paths=(
    ".github/CODEOWNERS"
    ".github/pull_request_template.md"
    ".github/dependabot.yml"
    ".gitignore"
    ".gitattributes"
  )
  for path in "${paths[@]}"; do
    printf '  %-40s %s\n' "$path" "${DRIFT_STATUS[$path]}"
    if [ "${DRIFT_STATUS[$path]}" = "MISSING" ] && [ "$MODE" = "dry-run" ]; then
      echo "    would create $path from ${TEMPLATE_BASE}/${DRIFT_TEMPLATE[$path]}"
    elif [ "${DRIFT_STATUS[$path]}" = "DRIFT" ]; then
      if [ "${DRIFT_MODE[$path]}" = "subset" ]; then
        # Show only the canon lines missing from local — the full diff
        # would include intentional consumer extensions that pass the
        # subset check.
        [ "$MODE" = "dry-run" ] && echo "    would append missing canon lines to $path:"
        printf '%s\n' "${DRIFT_MISSING_LINES[$path]}" | sed 's/^/      /'
      else
        [ "$MODE" = "dry-run" ] && echo "    would replace $path with ${TEMPLATE_BASE}/${DRIFT_TEMPLATE[$path]}"
        diff -u "$path" "${DRIFT_CANONICAL[$path]}" 2>/dev/null | head -20 | sed 's/^/    /' || true
      fi
    fi
  done
}

emit_json() {
  local paths=(
    ".github/CODEOWNERS"
    ".github/pull_request_template.md"
    ".github/dependabot.yml"
    ".gitignore"
    ".gitattributes"
  )
  local repo_field
  repo_field=$(json_escape "${REPO_LABEL:-<local-checkout>}")
  printf '{\n'
  printf '  "repo": "%s",\n' "$repo_field"
  printf '  "ci_tag": "%s",\n' "$(json_escape "$CI_TAG")"
  printf '  "summary": { "ok": %d, "drift": %d, "missing": %d },\n' \
    "$OK_COUNT" "$DRIFT_COUNT" "$MISSING_COUNT"
  printf '  "surfaces": [\n'
  local first=1
  for path in "${paths[@]}"; do
    if [ "$first" -eq 1 ]; then
      first=0
    else
      printf ',\n'
    fi
    printf '    { "path": "%s", "status": "%s", "template": "%s" }' \
      "$path" "${DRIFT_STATUS[$path]}" "${DRIFT_TEMPLATE[$path]}"
  done
  printf '\n  ]\n}\n'
}

case "$MODE" in
  check)
    emit_human
    if [ $((DRIFT_COUNT + MISSING_COUNT)) -gt 0 ]; then exit 1; fi
    ;;
  dry-run)
    emit_human
    ;;
  report)
    emit_json
    ;;
esac

# EXIT trap handles tmpfile cleanup.
exit 0
