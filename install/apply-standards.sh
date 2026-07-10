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
# Surfaces checked (canon templates from PR-B1 + PR-U1 + PR-V2):
#   1. .github/CODEOWNERS                     — owner-normalized (FT-7)
#   2. .github/pull_request_template.md       — exact-match  (PR-B1)
#   3. .github/dependabot.yml                 — exact-match  (PR-B1)
#   4. scripts/pre_push_check.sh              — exact-match  (PR-U1)
#   5. .gitignore                             — subset       (PR-B1)
#   6. .gitattributes                         — subset       (PR-B1)
#   7. .pre-commit-config.yaml                — subset       (PR-U1;
#                                                canon fragment lines
#                                                must all be present)
#   8. CLAUDE.md#per-repo-governance          — governance   (PR-V2;
#                                                § Per-repo governance
#                                                table parsed per
#                                                PLAN-003 §4.5 contract;
#                                                required-row completeness
#                                                + declared-path existence)
#
# Labels + server-side settings (branch protection, security,
# actions-permissions) are applied by --apply (PR-C2).
#
# Modes:
#   --check          drift check, exit 1 if any drift, quiet on green
#                    (no output at all when every surface is OK)
#   --dry-run        (default) preview what --apply WOULD do, exit 0
#   --report         emit JSON compliance report to stdout
#   --apply          MUTATE the target repo's server-side settings from
#                    canon templates. Requires: --repo, --tier, gh CLI
#                    authenticated for write on the target. Interactive
#                    confirmation unless --yes. Backup written to
#                    install/backups/<sanitized-repo>-<timestamp>.json
#                    BEFORE any mutation. See --apply section below.
#
# --apply flags:
#   --tier <name>    REQUIRED with --apply. One of: governance, product,
#                    ops, umbrella, bootstrap. Selects branch-protection
#                    profile.
#   --yes            skip interactive confirmation
#   --skip-labels             skip label create pass
#   --skip-repo-settings      skip Settings → General → Pull Requests patch
#   --skip-actions            skip actions-permissions multi-endpoint pass
#   --skip-branch-protection  skip branch-protection PUT
#
# --apply does NOT touch content-surface FILES (CODEOWNERS, PR template,
# dependabot.yml, .gitignore, .gitattributes) — those ship via normal PR
# flow per PLAN-001 §5.4 rollout. --apply is server-side settings only.
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
#   0    green (or dry-run/report/apply success)
#   1    drift found (--check only)
#   2    usage error (unknown arg, invalid --ci-tag, bash <4,
#        --apply without --repo/--tier)
#   3    canon fetch failed
#   4    --apply mutation error (partial state possible; check backup)
#   5    --apply cancelled by user (interactive confirmation declined)
#
# Requires: bash 4+ (macOS: `brew install bash`), curl, diff, grep, sed.
# --apply additionally requires: gh CLI authenticated for write on target,
# jq (for stripping `_`-prefix metadata from canon JSON per PR-C1 contract).

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
TIER=""
YES=0
SKIP_LABELS=0
SKIP_REPO_SETTINGS=0
SKIP_ACTIONS=0
SKIP_BRANCH_PROTECTION=0
ALLOW_MAIN_CANON=0

while [ $# -gt 0 ]; do
  case "$1" in
    --check)   MODE="check"; shift ;;
    --dry-run) MODE="dry-run"; shift ;;
    --report)  MODE="report"; shift ;;
    --apply)   MODE="apply"; shift ;;
    --ci-tag)  CI_TAG_OVERRIDE="$2"; shift 2 ;;
    --repo)    REPO_LABEL="$2"; shift 2 ;;
    --tier)    TIER="$2"; shift 2 ;;
    --yes)     YES=1; shift ;;
    --skip-labels)            SKIP_LABELS=1; shift ;;
    --skip-repo-settings)     SKIP_REPO_SETTINGS=1; shift ;;
    --skip-actions)           SKIP_ACTIONS=1; shift ;;
    --skip-branch-protection) SKIP_BRANCH_PROTECTION=1; shift ;;
    --allow-main-canon)       ALLOW_MAIN_CANON=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "apply-standards: unknown arg: $1" >&2; usage 2 ;;
  esac
done

# --apply preconditions (fail-fast before any I/O)
if [ "$MODE" = "apply" ]; then
  if [ -z "$REPO_LABEL" ]; then
    echo "apply-standards: --apply requires --repo <owner/repo>" >&2
    exit 2
  fi
  # M1-sec fix: tighter regex + explicit `..` guard.
  # Owner: leading alphanum, no double-hyphen, no leading `-`.
  # Repo: alphanum + . _ -, cannot be "." or ".." or start with `-` or `.`.
  if ! [[ "$REPO_LABEL" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9._][A-Za-z0-9._-]{0,99}$ ]] \
     || [[ "$REPO_LABEL" == *".."* ]]; then
    echo "apply-standards: invalid --repo value: $REPO_LABEL" >&2
    echo "  owner: [A-Za-z0-9][A-Za-z0-9-]{0,38} (no leading -)" >&2
    echo "  repo:  [A-Za-z0-9._][A-Za-z0-9._-]{0,99} (no leading . or -, no '..')" >&2
    exit 2
  fi
  case "$TIER" in
    governance|product|ops|umbrella|bootstrap) ;;
    "") echo "apply-standards: --apply requires --tier <governance|product|ops|umbrella|bootstrap>" >&2; exit 2 ;;
    *)  echo "apply-standards: invalid --tier value: $TIER" >&2; exit 2 ;;
  esac
  if ! command -v gh >/dev/null 2>&1; then
    echo "apply-standards: --apply requires gh CLI (not found in PATH)" >&2
    exit 2
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "apply-standards: --apply requires jq (not found in PATH)" >&2
    exit 2
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "apply-standards: --apply requires authenticated gh CLI (run 'gh auth login')" >&2
    exit 2
  fi
  # M3-code: non-TTY must combine with --yes; otherwise the confirm
  # prompt silently EOFs → "cancelled by user" (safe but confusing).
  if [ ! -t 0 ] && [ "$YES" -ne 1 ]; then
    echo "apply-standards: non-interactive shell — --apply requires --yes" >&2
    exit 2
  fi
fi

# --- resolve CI_TAG ---
resolve_ci_tag() {
  if [ -n "$CI_TAG_OVERRIDE" ]; then
    echo "$CI_TAG_OVERRIDE"; return
  fi
  local pin
  # Resolve ONE canon tag to apply/compare a coherent settings+config set
  # from. sort -Vu picks the highest semver on repos mid-migration between
  # pins (mixed @ci/v1.4.3 + @ci/v1.5.1 → prefer v1.5.1); ASCII sort would
  # silently pick the lowest. This is a WHOLE-REPO tag (config files have no
  # per-file pin) — deliberately not per-caller; per-caller workflow drift is
  # sync/check-drift.sh's job (PLAN-004 PR-A2).
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
# security H1: refuse to --apply from mutable main canon unless the
# operator explicitly opted in with --allow-main-canon. main can move
# under our feet between review and apply (attacker-merged PR); tag pins
# are stronger (still not tamper-proof, but require force-push override).
if [ "$MODE" = "apply" ] && [ "$CI_TAG" = "main" ] && [ "$ALLOW_MAIN_CANON" -ne 1 ]; then
  echo "apply-standards: --apply refuses CI_TAG=main (mutable canon = supply-chain risk)" >&2
  echo "apply-standards: pin --ci-tag ci/vX.Y.Z, OR pass --allow-main-canon to override" >&2
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

normalize_codeowners() {
  # stdin → stdout. Replace every @owner token — including the canon's
  # ${CODEOWNER_HANDLE} placeholder (which appears as @${CODEOWNER_HANDLE})
  # and any consumer's substituted @handle — with a fixed @OWNER sentinel.
  # A token is @ followed by non-whitespace, so `@a @b` → `@OWNER @OWNER`
  # (the COUNT/position is preserved; only identity is anonymized).
  sed -E 's/@[^[:space:]]+/@OWNER/g'
}

codeowners_check() {
  # $1 = local path, $2 = template path. CODEOWNERS is exact-match EXCEPT the
  # owner handles: the canon parameterizes them as @${CODEOWNER_HANDLE} (FT-7)
  # and each consumer substitutes their own, so WHO owns is inherently
  # consumer-specific and is NOT canon — the path-routing STRUCTURE is. So
  # normalize every @owner on BOTH sides to a sentinel and diff that. This
  # catches added/removed/reordered rules and extra/missing owner tokens
  # (structure) while ignoring the handle identity, so a de-branded consumer
  # does not read as permanent drift against the placeholder template.
  local local_path="$1" template="$2"
  local canonical canonical_norm local_norm status
  canonical=$(mktemp); canonical_norm=$(mktemp); local_norm=$(mktemp)
  # Register ALL three for cleanup BEFORE fetch_canon (which can `exit 3` on a
  # canon-fetch failure, firing the EXIT trap before canonical_norm would
  # otherwise be registered via DRIFT_CANONICAL below) — else it leaks.
  APPLY_TMPFILES+=("$canonical" "$canonical_norm" "$local_norm")
  fetch_canon "$template" > "$canonical"
  if [ ! -f "$local_path" ]; then
    status="MISSING"
  else
    normalize_codeowners < "$canonical"   > "$canonical_norm"
    normalize_codeowners < "$local_path"  > "$local_norm"
    if diff -q "$local_norm" "$canonical_norm" >/dev/null 2>&1; then
      status="OK"
    else
      status="DRIFT"
    fi
  fi
  DRIFT_STATUS["$local_path"]="$status"
  DRIFT_TEMPLATE["$local_path"]="$template"
  # Store the NORMALIZED canonical + local so emit_human's diff shows the
  # structural delta (not handle noise). canonical_norm is cleaned via the
  # DRIFT_CANONICAL sweep; local_norm + raw canonical via APPLY_TMPFILES.
  DRIFT_CANONICAL["$local_path"]="$canonical_norm"
  DRIFT_LOCAL_NORMALIZED["$local_path"]="$local_norm"
  DRIFT_MODE["$local_path"]="normalized"
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
                        grep -qxF -- "$line" "$local_path" || echo "$line"
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

governance_check() {
  # PLAN-003 PR-V2: parse CLAUDE.md § Per-repo governance table via
  # parse-governance-table.py (co-located parser); verify each declared
  # path exists on disk (or is a valid "Not adopted — <rationale>" cell).
  # Records status under the pseudo-path "CLAUDE.md#per-repo-governance"
  # in the DRIFT_* arrays so emit_human + emit_json surface it alongside
  # the exact/subset check results.
  local local_path="CLAUDE.md#per-repo-governance"
  local status parse_output errors_count
  DRIFT_TEMPLATE["$local_path"]="CLAUDE.md.template"
  DRIFT_MODE["$local_path"]="governance"
  # Governance mode does not do canonical-file diff (no tmpfile created).
  # emit_human branches on DRIFT_MODE first, so the empty canonical
  # never reaches the `diff -u` else-branch; cleanup_tmpfiles' `[ -n ]`
  # guard skips it (per code-reviewer F#7 fold 2026-07-08).
  DRIFT_CANONICAL["$local_path"]=""

  if [ ! -f "CLAUDE.md" ]; then
    DRIFT_STATUS["$local_path"]="MISSING"
    DRIFT_MISSING_LINES["$local_path"]="CLAUDE.md not found at repo root"
    return
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    DRIFT_STATUS["$local_path"]="OK"  # cannot check without python3; do not block
    DRIFT_MISSING_LINES["$local_path"]="governance check skipped: python3 not available"
    return
  fi

  local parser
  parser="$(dirname "${BASH_SOURCE[0]}")/parse-governance-table.py"
  if [ ! -f "$parser" ]; then
    # apply-standards.sh may be invoked via curl-pipe-bash from CI;
    # parser co-located at same URL. Fetch to a tmpfile in that case.
    parser=$(mktemp --suffix=.py)
    APPLY_TMPFILES+=("$parser")
    curl -fsSL "https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${CI_TAG}/install/parse-governance-table.py" \
      -o "$parser" 2>/dev/null || {
      DRIFT_STATUS["$local_path"]="OK"
      DRIFT_MISSING_LINES["$local_path"]="governance check skipped: parser fetch failed"
      return
    }
  fi

  # stderr NOT merged into stdout: any parser stderr write (Python
  # warnings, argparse errors) would corrupt the JSON parse otherwise
  # (per code-reviewer F#4 fold 2026-07-08).
  local parse_stderr_tmp
  parse_stderr_tmp=$(mktemp)
  APPLY_TMPFILES+=("$parse_stderr_tmp")
  parse_output=$(python3 "$parser" "CLAUDE.md" --repo-root "." 2>"$parse_stderr_tmp") || true
  # Surface parser stderr to the shell's stderr for the operator; DO
  # NOT include it in the JSON parse.
  [ -s "$parse_stderr_tmp" ] && cat "$parse_stderr_tmp" >&2
  errors_count=$(printf '%s' "$parse_output" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    print(len(d.get('errors', [])))
except Exception:
    print(-1)
" 2>/dev/null || echo -1)

  if [ "$errors_count" = "0" ]; then
    status="OK"
    DRIFT_MISSING_LINES["$local_path"]=""
  elif [ "$errors_count" = "-1" ]; then
    status="DRIFT"
    DRIFT_MISSING_LINES["$local_path"]="parse-governance-table.py error: $parse_output"
  else
    status="DRIFT"
    # Extract error list for reporting.
    DRIFT_MISSING_LINES["$local_path"]=$(printf '%s' "$parse_output" | python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    for e in d.get('errors', []):
        print(f'  - {e}')
except Exception as ex:
    print(f'  - parser-output-error: {ex}')
" 2>/dev/null)
  fi
  DRIFT_STATUS["$local_path"]="$status"
}

# --- run checks (skipped for --apply — it operates on server-side only) ---
declare -A DRIFT_STATUS DRIFT_TEMPLATE DRIFT_CANONICAL DRIFT_MODE DRIFT_MISSING_LINES DRIFT_LOCAL_NORMALIZED
# L1-code: track apply-mode tmpfiles separately so cleanup_tmpfiles
# handles them too (previously they leaked on fetch_canon exit 3).
APPLY_TMPFILES=()

# EXIT trap: clean up tmpfiles regardless of exit path (including
# fetch_canon exit 3 mid-run). M3 fix.
# shellcheck disable=SC2329  # called via trap
cleanup_tmpfiles() {
  local f
  for f in "${DRIFT_CANONICAL[@]:-}"; do
    [ -n "$f" ] && rm -f "$f"
  done
  for f in "${APPLY_TMPFILES[@]:-}"; do
    [ -n "$f" ] && rm -f "$f"
  done
}
trap cleanup_tmpfiles EXIT

if [ "$MODE" != "apply" ]; then
  codeowners_check  ".github/CODEOWNERS"                 "CODEOWNERS.template"
  exact_match_check ".github/pull_request_template.md"   "pull_request_template.md"
  exact_match_check ".github/dependabot.yml"             "dependabot.yml"
  exact_match_check "scripts/pre_push_check.sh"          "pre_push_check.sh"
  subset_check      ".gitignore"                          ".gitignore.template"
  subset_check      ".gitattributes"                      ".gitattributes.template"
  subset_check      ".pre-commit-config.yaml"             "pre-commit-hook-block.yaml"
  governance_check
fi

# --- report (skipped for --apply) ---
DRIFT_COUNT=0
MISSING_COUNT=0
OK_COUNT=0
if [ "$MODE" != "apply" ]; then
  for path in "${!DRIFT_STATUS[@]}"; do
    case "${DRIFT_STATUS[$path]}" in
      OK)      OK_COUNT=$((OK_COUNT + 1)) ;;
      DRIFT)   DRIFT_COUNT=$((DRIFT_COUNT + 1)) ;;
      MISSING) MISSING_COUNT=$((MISSING_COUNT + 1)) ;;
    esac
  done
fi

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
    "scripts/pre_push_check.sh"
    ".gitignore"
    ".gitattributes"
    ".pre-commit-config.yaml"
    "CLAUDE.md#per-repo-governance"
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
      elif [ "${DRIFT_MODE[$path]}" = "governance" ]; then
        # PLAN-003 §16 governance-canon check — show parser errors.
        # Each error already has a `- ` prefix from the parser output.
        [ "$MODE" = "dry-run" ] && echo "    governance-table errors (fix per PLAN-003 §4.5):"
        printf '%s\n' "${DRIFT_MISSING_LINES[$path]}" | sed 's/^/    /'
      elif [ "${DRIFT_MODE[$path]}" = "normalized" ]; then
        # FT-7 CODEOWNERS structural check — diff the owner-normalized
        # forms so the operator sees the STRUCTURAL delta, not handle noise.
        [ "$MODE" = "dry-run" ] && echo "    would replace $path with ${TEMPLATE_BASE}/${DRIFT_TEMPLATE[$path]} (owner handles normalized to @OWNER for comparison)"
        diff -u "${DRIFT_LOCAL_NORMALIZED[$path]}" "${DRIFT_CANONICAL[$path]}" 2>/dev/null | head -20 | sed 's/^/    /' || true
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
    "scripts/pre_push_check.sh"
    ".gitignore"
    ".gitattributes"
    ".pre-commit-config.yaml"
    "CLAUDE.md#per-repo-governance"
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

# --- apply mode helpers (server-side mutations only; safest surfaces first) ---

# Sanitize owner/repo to a filesystem-safe token.
apply_repo_slug() { echo "${REPO_LABEL//\//-}"; }

apply_backup_dir() {
  local script_dir
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  echo "${script_dir}/backups"
}

apply_confirm() {
  # $1 = summary; returns 0 on OK, exits 5 on decline
  if [ "$YES" -eq 1 ]; then return 0; fi
  echo ""
  echo "$1"
  printf "apply-standards: proceed with --apply on %s (tier=%s)? [y/N] " "$REPO_LABEL" "$TIER"
  local ans
  read -r ans
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) echo "apply-standards: cancelled by user" >&2; exit 5 ;;
  esac
}

# Strip _*-prefix metadata keys from a canon JSON payload. Uses jq to
# handle nested objects; PR-C1 templates document this contract.
apply_strip_meta() {
  # $1 = path to raw canon JSON
  jq 'walk(if type == "object" then with_entries(select(.key | startswith("_") | not)) else . end)' "$1"
}

# Fetch a canon template into a tmpfile with meta-keys stripped.
apply_canon_stripped() {
  # $1 = template path under install/templates/; echoes tmpfile path
  local raw stripped
  raw=$(mktemp)
  stripped=$(mktemp)
  # L1-code: track tmpfiles for EXIT-trap cleanup even on mid-fetch exit.
  APPLY_TMPFILES+=("$raw" "$stripped")
  fetch_canon "$1" > "$raw"
  apply_strip_meta "$raw" > "$stripped"
  echo "$stripped"
}

apply_labels() {
  [ "$SKIP_LABELS" -eq 1 ] && { echo "  labels: SKIPPED (--skip-labels)"; return 0; }
  echo "  labels: applying from labels.json..."
  local labels_json created=0 updated=0 name color desc n enc
  labels_json=$(mktemp)
  APPLY_TMPFILES+=("$labels_json")
  fetch_canon "labels.json" > "$labels_json"
  # L4-code: validate jq output before iterating.
  n=$(jq 'length' "$labels_json" 2>/dev/null || echo "")
  if [ -z "$n" ] || ! [[ "$n" =~ ^[0-9]+$ ]]; then
    echo "    ERROR: could not parse labels.json (jq returned '$n')" >&2
    exit 4
  fi
  for i in $(seq 0 $((n - 1))); do
    name=$(jq -r ".[$i].name" "$labels_json")
    color=$(jq -r ".[$i].color" "$labels_json")
    desc=$(jq -r ".[$i].description" "$labels_json")
    # URL-encode ':' in the label name for the PATH (ai:review-passed →
    # ai%3Areview-passed). Without this the GET 404s on colon labels, so the
    # label is treated as missing and re-POSTed every --apply → 422 "already
    # exists" WARN noise. (corr M1; install.sh sidesteps this by using the
    # `gh label` subcommands instead of raw `gh api` paths.) Form-field values
    # (`-f name=…` / `-f new_name=…`) do NOT need this — gh encodes them.
    enc="${name//:/%3A}"
    # Check if exists (silently — 404 is expected).
    if gh api "repos/${REPO_LABEL}/labels/${enc}" >/dev/null 2>&1; then
      # Update (name+color+description).
      if gh api -X PATCH "repos/${REPO_LABEL}/labels/${enc}" \
           -f "new_name=${name}" -f "color=${color}" -f "description=${desc}" \
           >/dev/null 2>&1; then
        updated=$((updated + 1))
      else
        # M4-code: race — label deleted between our check and PATCH.
        # Fall through to POST rather than silently missing.
        if gh api -X POST "repos/${REPO_LABEL}/labels" \
             -f "name=${name}" -f "color=${color}" -f "description=${desc}" \
             >/dev/null 2>&1; then
          created=$((created + 1))
        else
          echo "    WARN: PATCH and POST both failed for label '$name'" >&2
        fi
      fi
    else
      if gh api -X POST "repos/${REPO_LABEL}/labels" \
           -f "name=${name}" -f "color=${color}" -f "description=${desc}" \
           >/dev/null 2>&1; then
        created=$((created + 1))
      else
        echo "    WARN: POST failed for label '$name'" >&2
      fi
    fi
  done
  echo "    labels: $created created, $updated updated"
}

apply_repo_settings() {
  [ "$SKIP_REPO_SETTINGS" -eq 1 ] && { echo "  repo-settings: SKIPPED (--skip-repo-settings)"; return 0; }
  echo "  repo-settings: applying repo-settings.json..."
  local payload
  payload=$(apply_canon_stripped "repo-settings.json")
  if gh api -X PATCH "repos/${REPO_LABEL}" --input "$payload" >/dev/null; then
    echo "    repo-settings: applied"
  else
    echo "    ERROR: PATCH repos/${REPO_LABEL} failed" >&2
    exit 4
  fi
}

apply_actions_permissions() {
  [ "$SKIP_ACTIONS" -eq 1 ] && { echo "  actions-permissions: SKIPPED (--skip-actions)"; return 0; }
  echo "  actions-permissions: iterating sections..."
  local raw visibility
  raw=$(mktemp)
  APPLY_TMPFILES+=("$raw")
  fetch_canon "actions-permissions.json" > "$raw"
  # H3-code fix: use visibility (public/private/internal), not isPrivate —
  # `access` endpoint 422s on public but is VALID on internal + private.
  # `--` protects against a REPO_LABEL starting with `-` (security L2).
  visibility=$(gh repo view -- "$REPO_LABEL" --json visibility --jq '.visibility' 2>/dev/null || echo "unknown")
  # 4 endpoints applied in canonical order: general MUST come before
  # selected_actions because setting `allowed_actions=selected` in general
  # enables the selected list slot. Order verified against canon §4 spec.
  # Fork-PR settings block is UI-only and skipped with a security-explicit warning.
  local sec endpoint payload api_path verb
  for sec in general selected_actions workflow access; do
    if [ "$sec" = "access" ] && [ "$visibility" = "public" ]; then
      echo "    access: SKIPPED (public repo — endpoint 422s per PR-C1 _conditional)"
      continue
    fi
    # H4-code fix: validate _endpoint shape before using it.
    endpoint=$(jq -r ".${sec}._endpoint // \"\"" "$raw")
    if [ -z "$endpoint" ] || ! [[ "$endpoint" =~ ^PUT[[:space:]]/ ]]; then
      echo "    ERROR: malformed _endpoint in actions-permissions.json for section '${sec}': '${endpoint}'" >&2
      rm -f "$raw"
      exit 4
    fi
    verb="${endpoint%% *}"
    api_path="${endpoint#* }"
    # security H1: enforce that _endpoint scopes to the target repo only.
    # Prevents a hostile canon from pivoting to /orgs/... or another repo.
    api_path="${api_path/\{owner\}\/\{repo\}/$REPO_LABEL}"
    if ! [[ "$api_path" =~ ^/?repos/${REPO_LABEL}/ ]]; then
      echo "    ERROR: _endpoint escapes target-repo scope: '${verb} ${api_path}'" >&2
      echo "    (canon may be tampered — pin --ci-tag to a trusted ci/vX.Y.Z)" >&2
      rm -f "$raw"
      exit 4
    fi
    payload=$(mktemp)
    APPLY_TMPFILES+=("$payload")
    jq ".${sec} | walk(if type == \"object\" then with_entries(select(.key | startswith(\"_\") | not)) else . end)" "$raw" > "$payload"
    if gh api -X "$verb" "$api_path" --input "$payload" >/dev/null 2>&1; then
      echo "    ${sec}: applied (${verb} ${api_path})"
    else
      echo "    ERROR: ${verb} ${api_path} failed" >&2
      rm -f "$raw" "$payload"
      exit 4
    fi
    rm -f "$payload"
  done
  # M5-sec: name the security consequence, not just "verify in UI".
  echo "    fork-PR toggles: SECURITY WARNING — GitHub does not expose these via REST."
  echo "                     Until set in Settings > Actions > General per canon §4,"
  echo "                     fork PRs MAY receive write-scoped tokens and secrets."
  rm -f "$raw"
}

apply_branch_protection() {
  [ "$SKIP_BRANCH_PROTECTION" -eq 1 ] && { echo "  branch-protection: SKIPPED (--skip-branch-protection)"; return 0; }
  echo "  branch-protection: applying branch-protection-${TIER}.json..."
  local payload default_branch
  # M4-sec: use the target's actual default branch, not hardcoded "main".
  default_branch=$(gh api "repos/${REPO_LABEL}" --jq '.default_branch' 2>/dev/null || echo "main")
  payload=$(apply_canon_stripped "branch-protection-${TIER}.json")
  # Branch-protection PUT requires special Accept header; gh api handles it.
  if gh api -X PUT "repos/${REPO_LABEL}/branches/${default_branch}/protection" \
       -H "Accept: application/vnd.github+json" \
       --input "$payload" >/dev/null; then
    echo "    branch-protection: applied (tier=$TIER, branch=$default_branch)"
  else
    echo "    ERROR: PUT branch protection failed" >&2
    exit 4
  fi
}

apply_backup() {
  local backup_dir slug ts backup_file default_branch
  backup_dir=$(apply_backup_dir)
  # security H3: mkdir + write must succeed BEFORE any mutation runs.
  # Silent-write failure (curl-piped bash → /dev/fd/N as script_dir) would
  # leave the operator thinking a backup exists when none does.
  mkdir -p "$backup_dir" || {
    echo "apply-standards: FATAL backup dir not creatable: $backup_dir" >&2
    exit 4
  }
  if [ ! -w "$backup_dir" ]; then
    echo "apply-standards: FATAL backup dir not writable: $backup_dir" >&2
    exit 4
  fi
  slug=$(apply_repo_slug)
  # H1 fix: single timestamp source (dead gh-api-meta line removed); PID
  # suffix prevents same-second collision on retry.
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  backup_file="${backup_dir}/${slug}-${ts}-$$.json"
  # Extra safety: increment sequence suffix if PID-slot ever collides.
  local n=0
  while [ -f "$backup_file" ]; do
    n=$((n + 1))
    backup_file="${backup_dir}/${slug}-${ts}-$$-${n}.json"
  done
  # M4-sec: use the target's actual default branch, not hardcoded "main".
  default_branch=$(gh api "repos/${REPO_LABEL}" --jq '.default_branch' 2>/dev/null || echo "main")
  echo "  backup: capturing current state to $backup_file"
  # security M3 + code L3: restrict permissions so private-repo metadata
  # in the backup isn't world-readable.
  (
    umask 077
    {
      echo "{"
      echo '  "repo": "'"$(json_escape "$REPO_LABEL")"'",'
      echo '  "tier": "'"$(json_escape "$TIER")"'",'
      echo '  "default_branch": "'"$(json_escape "$default_branch")"'",'
      echo '  "timestamp_utc": "'"$ts"'",'
      # security H2: capture ALL 4 actions-permissions sub-endpoints so
      # partial-run rollback has each surface's pre-state.
      printf '  "labels": '; gh api --paginate "repos/${REPO_LABEL}/labels?per_page=100" 2>/dev/null || echo "null"
      printf ','
      printf '  "repo_settings": '; gh api "repos/${REPO_LABEL}" 2>/dev/null || echo "null"
      printf ','
      printf '  "actions_general": '; gh api "repos/${REPO_LABEL}/actions/permissions" 2>/dev/null || echo "null"
      printf ','
      printf '  "actions_selected": '; gh api "repos/${REPO_LABEL}/actions/permissions/selected-actions" 2>/dev/null || echo "null"
      printf ','
      printf '  "actions_workflow": '; gh api "repos/${REPO_LABEL}/actions/permissions/workflow" 2>/dev/null || echo "null"
      printf ','
      printf '  "actions_access": '; gh api "repos/${REPO_LABEL}/actions/permissions/access" 2>/dev/null || echo "null"
      printf ','
      printf '  "branch_protection": '; gh api "repos/${REPO_LABEL}/branches/${default_branch}/protection" 2>/dev/null || echo "null"
      echo "}"
    } > "$backup_file"
  )
  # security H3: verify backup landed with non-zero content.
  if [ ! -s "$backup_file" ]; then
    echo "apply-standards: FATAL backup write failed or produced empty file: $backup_file" >&2
    exit 4
  fi
  echo "    backup: written ($(wc -c < "$backup_file") bytes; mode 600)"
}

apply_run() {
  echo "apply-standards: --apply MODE"
  echo "  repo:  $REPO_LABEL"
  echo "  tier:  $TIER"
  echo "  canon: $CI_TAG"
  echo ""
  echo "  Will apply (in order, safest first):"
  [ "$SKIP_LABELS" -eq 0 ]            && echo "    1. labels (create/update from labels.json)"
  [ "$SKIP_REPO_SETTINGS" -eq 0 ]     && echo "    2. repo-settings (PATCH /repos/${REPO_LABEL})"
  [ "$SKIP_ACTIONS" -eq 0 ]           && echo "    3. actions-permissions (4 endpoints, access skipped on public)"
  [ "$SKIP_BRANCH_PROTECTION" -eq 0 ] && echo "    4. branch-protection (PUT branches/main/protection, tier=$TIER)"
  echo ""
  echo "  BACKUP: current state → install/backups/$(apply_repo_slug)-<UTC-timestamp>-<pid>.json"
  echo "  Rollback path: MANUAL — the backup captures raw GET responses"
  echo "                 which don't round-trip via naive PUT (branch-protection"
  echo "                 restrictions + required_pull_request_reviews shapes"
  echo "                 differ between GET and PUT). Use the backup as a"
  echo "                 REFERENCE for restoration via Settings UI or a"
  echo "                 hand-authored PUT payload. Automated --rollback is v2."
  apply_confirm "  Any error mid-run leaves the target in a PARTIAL state (backup preserves the pre-state as reference)."
  echo ""
  echo "apply-standards: proceeding..."
  apply_backup
  apply_labels
  apply_repo_settings
  apply_actions_permissions
  apply_branch_protection
  echo ""
  echo "apply-standards: --apply COMPLETE for $REPO_LABEL (tier=$TIER)"
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
  apply)
    apply_run
    ;;
esac

# EXIT trap handles tmpfile cleanup.
exit 0
