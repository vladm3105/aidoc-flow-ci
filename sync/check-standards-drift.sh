#!/usr/bin/env bash
# aidoc-flow-ci sync/check-standards-drift.sh — server-side canon drift
# check. WARNING-ONLY (never blocks), mirroring sync/check-drift.sh's
# contract per PLAN-001 §5.3.
#
# Reads the current repo's actual server-side settings via `gh api` and
# compares against the canon templates for the specified tier. Emits
# `::warning::` for each drift.
#
# EXIT: warning-only BY DEFAULT (exit 0 on drift, per IPLAN-0017 §3.1b) —
# but `--strict` (see the STRICT handling at the tail of this script) exits
# non-zero on drift or an uncheckable control. The gating primitive already
# exists; a caller opts into it.
#
# Companion to sync/check-drift.sh (workflow-file drift) — this one
# handles server-side settings (branch protection, labels, repo settings,
# actions permissions).
#
# Usage:
#   bash sync/check-standards-drift.sh --tier <tier> [--strict]
#     --tier <name>   REQUIRED. governance|product|ops|umbrella|bootstrap.
#     --repo <owner/repo>
#                     REQUIRED unless run in a checked-out consumer repo
#                     (auto-detected via `gh repo view`).
#     --ci-tag <ref>  canon tag OR commit SHA — used only as a raw.githubusercontent
#                     ref (TEMPLATE_BASE + the check-pin-currency self-fetch), so
#                     either form works. A SHA-pinned caller passes its SHA so the
#                     template comparison matches what actually executed.
#                     (default: reads @ci/vX.Y.Z pin from .github/workflows/*.yml;
#                     falls back to main).
#
#     --strict       exit non-zero on drift or an uncheckable control; intended
#                    for release/adoption gates. Default remains warning-only.
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
STRICT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --tier)   TIER="$2"; shift 2 ;;
    --repo)   REPO="$2"; shift 2 ;;
    --ci-tag) CI_TAG_OVERRIDE="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    -h|--help) sed -nE '/^# aidoc-flow-ci/,/^set /p' "$0" | sed -E 's/^# ?//; /^set /d'; exit 0 ;;
    *) echo "::warning::check-standards-drift: unknown arg: $1"; exit 2 ;;
  esac
done

stop_uncheckable() {
  echo "::warning::check-standards-drift: $1"
  [ "$STRICT" -eq 0 ] && exit 0
  exit 2
}

case "$TIER" in
  governance|product|ops|umbrella|bootstrap) ;;
  *) stop_uncheckable "--tier required (governance|product|ops|umbrella|bootstrap)" ;;
esac

if ! command -v gh >/dev/null 2>&1; then
  stop_uncheckable "gh CLI not found — skipping"
fi
if ! command -v jq >/dev/null 2>&1; then
  stop_uncheckable "jq not found — skipping"
fi
if ! gh auth status >/dev/null 2>&1; then
  stop_uncheckable "gh CLI not authenticated — skipping"
fi

if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")
fi
if [ -z "$REPO" ]; then
  stop_uncheckable "--repo not provided and gh repo view failed"
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

MODE="warning-only"; [ "$STRICT" -eq 1 ] && MODE="strict"
echo "check-standards-drift: repo=$REPO tier=$TIER canon=$CI_TAG branch=$DEFAULT_BRANCH ($MODE)"

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
bp_err=$(mktemp)
if ! gh api "repos/${REPO}/branches/${DEFAULT_BRANCH}/protection" > "$bp_local" 2>"$bp_err"; then
  # FT-5: the protection endpoint needs `administration: read`. A scoped
  # GITHUB_TOKEN (contents:read) gets 403 — that is "can't verify", NOT "no
  # protection". Distinguish so the drift check doesn't false-alarm.
  if grep -qiE '403|forbidden|administration|not accessible|permission' "$bp_err"; then
    warn_uncheckable "branch-protection" "needs 'administration: read' on the token (FT-5) — grant it to the drift job (or run with a PAT) to verify branch protection; skipping"
  else
    echo "::warning::branch-protection: no protection on ${DEFAULT_BRANCH} (canon expects one)"
    DRIFT=$((DRIFT + 1))
  fi
  rm -f "$bp_err"
elif { rm -f "$bp_err"; ! curl -fsSL "${TEMPLATE_BASE}/branch-protection-${TIER}.json" > "$bp_canon_raw" 2>/dev/null; }; then
  warn_uncheckable "branch-protection" "canon fetch failed"
else
  strip_meta "$bp_canon_raw" > "$bp_canon"
  for k in enforce_admins required_signatures allow_force_pushes allow_deletions; do
    # GitHub returns these as {enabled:false}; canon stores flat booleans.
    # Do not use `//` for normalization because jq treats false as fallback.
    local_v=$(jq -r --arg k "$k" 'if has($k) then if (.[$k] | type) == "object" then if (.[$k] | has("enabled")) then .[$k].enabled else "null" end else .[$k] end else "null" end' "$bp_local")
    canon_v=$(jq -r --arg k "$k" 'if has($k) then .[$k] else "null" end' "$bp_canon")
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
  local_strict=$(jq -r '.required_status_checks.strict // false' "$bp_local")
  canon_strict=$(jq -r '.required_status_checks.strict // false' "$bp_canon")
  if [ "$local_strict" != "$canon_strict" ]; then
    echo "::warning::branch-protection.strict: canon=$canon_strict actual=$local_strict"
    DRIFT=$((DRIFT + 1))
  fi
  # Compare the PR-only contract as a normalized subset. GitHub's response may
  # include URL metadata and optional fields that are not part of our canon.
  review_filter='(.required_pull_request_reviews // null) | if . == null then null else {
    dismiss_stale_reviews: (.dismiss_stale_reviews // false),
    require_code_owner_reviews: (.require_code_owner_reviews // false),
    required_approving_review_count: (.required_approving_review_count // 0),
    require_last_push_approval: (.require_last_push_approval // false)
  } end'
  local_reviews=$(jq -c "$review_filter" "$bp_local")
  canon_reviews=$(jq -c "$review_filter" "$bp_canon")
  if [ "$local_reviews" != "$canon_reviews" ]; then
    echo "::warning::branch-protection.required_pull_request_reviews: canon=$canon_reviews actual=$local_reviews"
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
  for k in allow_merge_commit allow_squash_merge allow_rebase_merge delete_branch_on_merge allow_auto_merge allow_update_branch squash_merge_commit_title squash_merge_commit_message; do
    local_v=$(jq -r --arg k "$k" 'if has($k) then .[$k] else "null" end' "$rs_local")
    canon_v=$(jq -r --arg k "$k" 'if has($k) then .[$k] else "null" end' "$rs_canon")
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
    # patterns_allowed (FT-53). Since CI-0011 set verified_allowed=false, this list
    # is the ONLY non-GitHub-owned admission — the half that actually decides
    # whether an action runs — and it was the one field drift never compared.
    #
    # Reported as two DISTINCT conditions because they fail in opposite directions:
    #   MISSING (canon has, repo lacks) -> availability. A canon reusable matching
    #     that pattern is blocked at run-init: startup_failure, no logs, web-UI-only
    #     message, actionlint blind to it.
    #   EXTRA   (repo has, canon lacks) -> supply chain. The deployed boundary is
    #     wider than the one canon documents and CI-0011 decided.
    # Compared as SETS: the API returns patterns in arbitrary order, so a plain
    # string compare would report drift on ordering alone.
    if ! jq -e 'type == "object" and ((.patterns_allowed | type) as $t | $t == "array" or $t == "null")' "$ap_selected" >/dev/null 2>&1; then
      # Do not guess from an unparseable body: "3 patterns are missing" and "I could
      # not read the API response" are different operator actions.
      warn_uncheckable "actions.selected.patterns_allowed" "unreadable selected-actions response"
    else
    pa_local=$(mktemp); pa_canon=$(mktemp)
    jq -r '(.patterns_allowed // [])[]' "$ap_selected" 2>/dev/null | sort -u > "$pa_local"
    jq -r '(.selected_actions.patterns_allowed // [])[]' "$ap_canon_raw" 2>/dev/null | sort -u > "$pa_canon"
    # Glob SUBSUMPTION, not literal set-difference. Entries are globs and GitHub
    # wildcards span `/`, so `vladm3105/*` fully covers `vladm3105/aidoc-flow-ci/*`.
    # A pattern that was BROADENED is absent as a string yet loses no coverage; a
    # literal diff would report it MISSING and assert a `startup_failure` that
    # cannot occur — a false alarm on a symptom that is web-UI-only and expensive
    # to disprove. Report MISSING only where NO live pattern covers the canon one.
    # (The widening itself is still reported, correctly, as EXTRA.)
    # Subsumption is symmetric. `covered_by <pattern> <file>`: true when some glob
    # in <file> fully covers <pattern>. Used BOTH ways, because a literal
    # set-difference is wrong in both directions:
    #   MISSING — a canon pattern the repo BROADENED (`vladm3105/*` covers
    #     `vladm3105/aidoc-flow-ci/*`) loses no coverage; calling it blocked asserts
    #     a `startup_failure` that cannot happen.
    #   EXTRA   — a live pattern already INSIDE a canon pattern widens nothing;
    #     calling it "wider than canon" is simply false.
    # Only genuinely-uncovered entries are reported, on either side.
    covered_by() {
      local pat="$1" listfile="$2" g
      while IFS= read -r g; do
        [ -n "$g" ] || continue
        [ "$g" = "*" ] && return 0
        case "$g" in
          *'*') [ "${pat#"${g%\*}"}" != "$pat" ] && return 0 ;;
        esac
      done < "$listfile"
      return 1
    }
    pa_missing=""
    while IFS= read -r c; do
      [ -n "$c" ] || continue
      covered_by "$c" "$pa_local" || pa_missing="${pa_missing:+${pa_missing},}${c}"
    done < <(comm -13 "$pa_local" "$pa_canon")
    pa_extra=""
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      covered_by "$l" "$pa_canon" || pa_extra="${pa_extra:+${pa_extra},}${l}"
    done < <(comm -23 "$pa_local" "$pa_canon")
    if [ -n "$pa_missing" ]; then
      echo "::warning::actions.selected.patterns_allowed: MISSING (canon has, repo does not, and no live pattern covers it): ${pa_missing} — an action matching these is BLOCKED at run-init (silent startup_failure, no logs)"
      DRIFT=$((DRIFT + 1))
    fi
    if [ -n "$pa_extra" ]; then
      echo "::warning::actions.selected.patterns_allowed: EXTRA (repo admits what canon does not): ${pa_extra} — the supply-chain boundary is wider than canon; re-widening is a decision to record in DECISIONS.md (CI-0011), not a config tweak"
      DRIFT=$((DRIFT + 1))
    fi
    rm -f "$pa_local" "$pa_canon"
    fi
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
PIN_ERRORS=0
if [ -f sync/check-pin-currency.sh ]; then
  bash sync/check-pin-currency.sh || PIN_ERRORS=$((PIN_ERRORS + 1))
else
  _pc="$(mktemp)"
  if curl -fsSL "https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/${CI_TAG}/sync/check-pin-currency.sh" -o "$_pc" 2>/dev/null; then
    bash "$_pc" || PIN_ERRORS=$((PIN_ERRORS + 1))
  else
    echo "::notice::check-standards-drift: check-pin-currency.sh not available at ${CI_TAG} — skipping pin-currency (re-pin standards-drift to a release that includes it)"
  fi
  rm -f "$_pc"
fi

echo "check-standards-drift: $DRIFT drift, $FETCH_ERRORS fetch/scope error(s), $PIN_ERRORS pin error(s) ($MODE)"
[ "$STRICT" -eq 0 ] || [ $((DRIFT + FETCH_ERRORS + PIN_ERRORS)) -eq 0 ] || exit 1
exit 0
