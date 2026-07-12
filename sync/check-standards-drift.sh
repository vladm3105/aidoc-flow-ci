#!/usr/bin/env bash
# aidoc-flow-ci sync/check-standards-drift.sh — server-side canon drift
# check. WARNING-ONLY (never blocks), mirroring sync/check-drift.sh's
# contract per PLAN-001 §5.3.
#
# Reads the current repo's actual server-side settings via `gh api` and
# compares against the canon templates for the specified tier. Emits
# `::warning::` for each drift; ALWAYS exits 0.
#
# Companion to sync/check-drift.sh (workflow-file drift) — this one
# handles server-side settings (branch protection, labels, repo settings,
# actions permissions).
#
# Usage:
#   bash sync/check-standards-drift.sh --tier <tier>
#     --tier <name>   REQUIRED. governance|product|ops|umbrella|bootstrap.
#     --repo <owner/repo>
#                     REQUIRED unless run in a checked-out consumer repo
#                     (auto-detected via `gh repo view`).
#     --ci-tag <tag>  canon tag (default: reads @ci/vX.Y.Z pin from
#                     .github/workflows/*.yml; falls back to main).
#
# Exit codes:
#   0   always (warning-only contract)
#
# Requires: bash 4+, gh CLI authenticated, jq.

set -uo pipefail

if (( BASH_VERSINFO[0] < 4 )); then
  echo "::warning::check-standards-drift: requires bash 4+ (current: ${BASH_VERSION:-unknown})"
  exit 0
fi

TIER=""
REPO=""
CI_TAG_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --tier)   TIER="$2"; shift 2 ;;
    --repo)   REPO="$2"; shift 2 ;;
    --ci-tag) CI_TAG_OVERRIDE="$2"; shift 2 ;;
    -h|--help) sed -nE '/^# aidoc-flow-ci/,/^set /p' "$0" | sed -E 's/^# ?//; /^set /d'; exit 0 ;;
    *) echo "::warning::check-standards-drift: unknown arg: $1"; exit 0 ;;
  esac
done

case "$TIER" in
  governance|product|ops|umbrella|bootstrap) ;;
  *) echo "::warning::check-standards-drift: --tier required (governance|product|ops|umbrella|bootstrap)"; exit 0 ;;
esac

if ! command -v gh >/dev/null 2>&1; then
  echo "::warning::check-standards-drift: gh CLI not found — skipping"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "::warning::check-standards-drift: jq not found — skipping"
  exit 0
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "::warning::check-standards-drift: gh CLI not authenticated — skipping"
  exit 0
fi

if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
fi
if [ -z "$REPO" ]; then
  echo "::warning::check-standards-drift: --repo not provided and gh repo view failed"
  exit 0
fi

# Resolve ONE canon tag to compare this repo's WHOLE-REPO settings (branch
# protection, repo settings, actions permissions) against. Unlike
# check-drift.sh (which compares each caller against its OWN pin), the
# settings here have no per-file pin — they are single canon files — so
# resolving one tag is correct. Highest-semver is the deliberate frame: on a
# repo mid-bump, compare settings against the version it is migrating TOWARD.
# Warning-only + the resolved tag is echoed below, so the operator can judge.
if [ -n "$CI_TAG_OVERRIDE" ]; then
  CI_TAG="$CI_TAG_OVERRIDE"
else
  PIN=$(grep -hoE '@ci/v[0-9]+\.[0-9]+\.[0-9]+' .github/workflows/*.yml 2>/dev/null | sort -Vu | tail -1)
  CI_TAG="${PIN#@}"
  [ -z "$CI_TAG" ] && CI_TAG="main"
fi
TEMPLATE_BASE="https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${CI_TAG}/install/templates"

# Discover the target's actual default branch (M4-sec: not hardcoded main).
DEFAULT_BRANCH=$(gh api "repos/${REPO}" --jq '.default_branch' 2>/dev/null || echo "main")

echo "check-standards-drift: repo=$REPO tier=$TIER canon=$CI_TAG branch=$DEFAULT_BRANCH (warning-only)"

DRIFT=0
FETCH_ERRORS=0

# --- helper: strip _*-prefix metadata keys from canon JSON ---
strip_meta() {
  jq 'walk(if type == "object" then with_entries(select(.key | startswith("_") | not)) else . end)' "$1"
}

# --- helper: emit a cannot-check warning (security H4 — no silent green) ---
warn_uncheckable() {
  echo "::warning::check-standards-drift: cannot check $1 ($2)"
  FETCH_ERRORS=$((FETCH_ERRORS + 1))
}

# --- Branch protection tier profile ---
bp_local=$(mktemp)
bp_canon_raw=$(mktemp)
bp_canon=$(mktemp)
if ! gh api "repos/${REPO}/branches/${DEFAULT_BRANCH}/protection" > "$bp_local" 2>/dev/null; then
  echo "::warning::branch-protection: no protection on ${DEFAULT_BRANCH} (canon expects one)"
  DRIFT=$((DRIFT + 1))
elif ! curl -fsSL "${TEMPLATE_BASE}/branch-protection-${TIER}.json" > "$bp_canon_raw" 2>/dev/null; then
  warn_uncheckable "branch-protection" "canon fetch failed"
else
  strip_meta "$bp_canon_raw" > "$bp_canon"
  for k in enforce_admins required_signatures allow_force_pushes allow_deletions; do
    local_v=$(jq -r ".${k}.enabled // .${k} // \"null\"" "$bp_local")
    canon_v=$(jq -r ".${k} // \"null\"" "$bp_canon")
    if [ "$local_v" != "$canon_v" ]; then
      echo "::warning::branch-protection.${k}: canon=$canon_v actual=$local_v"
      DRIFT=$((DRIFT + 1))
    fi
  done
  local_ctx=$(jq -r '.required_status_checks.contexts // [] | sort | join(",")' "$bp_local")
  canon_ctx=$(jq -r '.required_status_checks.contexts // [] | sort | join(",")' "$bp_canon")
  if [ "$local_ctx" != "$canon_ctx" ]; then
    echo "::warning::branch-protection.contexts: canon=[$canon_ctx] actual=[$local_ctx]"
    DRIFT=$((DRIFT + 1))
  fi
fi
rm -f "$bp_local" "$bp_canon_raw" "$bp_canon"

# --- Repo settings ---
rs_local=$(mktemp)
rs_canon_raw=$(mktemp)
rs_canon=$(mktemp)
if ! gh api "repos/${REPO}" > "$rs_local" 2>/dev/null; then
  warn_uncheckable "repo-settings" "gh api repos/ failed"
elif ! curl -fsSL "${TEMPLATE_BASE}/repo-settings.json" > "$rs_canon_raw" 2>/dev/null; then
  warn_uncheckable "repo-settings" "canon fetch failed"
else
  strip_meta "$rs_canon_raw" > "$rs_canon"
  for k in allow_merge_commit allow_squash_merge allow_rebase_merge delete_branch_on_merge allow_auto_merge; do
    local_v=$(jq -r ".${k}" "$rs_local")
    canon_v=$(jq -r ".${k}" "$rs_canon")
    if [ "$local_v" != "$canon_v" ]; then
      echo "::warning::repo-settings.${k}: canon=$canon_v actual=$local_v"
      DRIFT=$((DRIFT + 1))
    fi
  done
fi
rm -f "$rs_local" "$rs_canon_raw" "$rs_canon"

# --- Actions permissions: check ALL 4 endpoints, not just workflow (L2-code) ---
ap_canon_raw=$(mktemp)
if ! curl -fsSL "${TEMPLATE_BASE}/actions-permissions.json" > "$ap_canon_raw" 2>/dev/null; then
  warn_uncheckable "actions-permissions" "canon fetch failed"
else
  # general.allowed_actions
  ap_general=$(mktemp)
  if ! gh api "repos/${REPO}/actions/permissions" > "$ap_general" 2>/dev/null; then
    warn_uncheckable "actions.general" "gh api failed (token scope?)"
  else
    local_v=$(jq -r ".allowed_actions" "$ap_general")
    canon_v=$(jq -r ".general.allowed_actions" "$ap_canon_raw")
    if [ "$local_v" != "$canon_v" ]; then
      echo "::warning::actions.general.allowed_actions: canon=$canon_v actual=$local_v"
      DRIFT=$((DRIFT + 1))
    fi
  fi
  rm -f "$ap_general"
  # workflow.default_workflow_permissions
  ap_workflow=$(mktemp)
  if ! gh api "repos/${REPO}/actions/permissions/workflow" > "$ap_workflow" 2>/dev/null; then
    warn_uncheckable "actions.workflow" "gh api failed (token scope?)"
  else
    local_v=$(jq -r ".default_workflow_permissions" "$ap_workflow")
    canon_v=$(jq -r ".workflow.default_workflow_permissions" "$ap_canon_raw")
    if [ "$local_v" != "$canon_v" ]; then
      echo "::warning::actions.workflow.default_workflow_permissions: canon=$canon_v actual=$local_v"
      DRIFT=$((DRIFT + 1))
    fi
  fi
  rm -f "$ap_workflow"
  # selected_actions.github_owned_allowed + verified_allowed
  ap_selected=$(mktemp)
  if ! gh api "repos/${REPO}/actions/permissions/selected-actions" > "$ap_selected" 2>/dev/null; then
    warn_uncheckable "actions.selected" "gh api failed (or allowed_actions != selected)"
  else
    for k in github_owned_allowed verified_allowed; do
      local_v=$(jq -r ".${k}" "$ap_selected")
      canon_v=$(jq -r ".selected_actions.${k}" "$ap_canon_raw")
      if [ "$local_v" != "$canon_v" ]; then
        echo "::warning::actions.selected.${k}: canon=$canon_v actual=$local_v"
        DRIFT=$((DRIFT + 1))
      fi
    done
  fi
  rm -f "$ap_selected"
  # access.access_level — only meaningful on private/internal repos
  visibility=$(gh api "repos/${REPO}" --jq '.visibility' 2>/dev/null || echo "unknown")
  if [ "$visibility" != "public" ]; then
    ap_access=$(mktemp)
    if ! gh api "repos/${REPO}/actions/permissions/access" > "$ap_access" 2>/dev/null; then
      warn_uncheckable "actions.access" "gh api failed"
    else
      local_v=$(jq -r ".access_level" "$ap_access")
      canon_v=$(jq -r ".access.access_level" "$ap_canon_raw")
      if [ "$local_v" != "$canon_v" ]; then
        echo "::warning::actions.access.access_level: canon=$canon_v actual=$local_v"
        DRIFT=$((DRIFT + 1))
      fi
    fi
    rm -f "$ap_access"
  fi
fi
rm -f "$ap_canon_raw"

# --- Labels: only warn if a canon-required label is MISSING (never on extras) ---
lb_local=$(mktemp)
lb_canon=$(mktemp)
if ! gh api --paginate "repos/${REPO}/labels?per_page=100" > "$lb_local" 2>/dev/null; then
  warn_uncheckable "labels" "gh api labels failed"
elif ! curl -fsSL "${TEMPLATE_BASE}/labels.json" > "$lb_canon" 2>/dev/null; then
  warn_uncheckable "labels" "canon fetch failed"
else
  missing=$(jq -r --slurpfile local "$lb_local" '
    [.[].name] as $canon
    | [$local[0][].name] as $actual
    | ($canon - $actual)
    | .[]
  ' "$lb_canon")
  if [ -n "$missing" ]; then
    while IFS= read -r m; do
      echo "::warning::labels: canon label missing: $m"
      DRIFT=$((DRIFT + 1))
    done <<< "$missing"
  fi
fi
rm -f "$lb_local" "$lb_canon"

# --- pin-currency (companion drift dimension) ---
# Also flag @ci/v* caller pins that LAG the current VERSION — the staleness
# dimension this settings check + check-drift.sh both miss. In-repo (reads the
# local ./.github/workflows checkout, so it works for public AND private via
# each repo's own token). Warning-only. Uses the local copy if present
# (self-run / already fetched), else fetches from the resolved CI_TAG.
if [ -f sync/check-pin-currency.sh ]; then
  bash sync/check-pin-currency.sh || true
else
  _pc="$(mktemp)"
  if curl -fsSL "https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${CI_TAG}/sync/check-pin-currency.sh" -o "$_pc" 2>/dev/null; then
    bash "$_pc" || true
  else
    echo "::notice::check-standards-drift: check-pin-currency.sh not available at ${CI_TAG} — skipping pin-currency (re-pin standards-drift to a release that includes it)"
  fi
  rm -f "$_pc"
fi

echo "check-standards-drift: $DRIFT drift, $FETCH_ERRORS fetch/scope error(s) (never blocks)"
exit 0
