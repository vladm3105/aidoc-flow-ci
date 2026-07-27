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

# --- coverage accounting (CI-0018) ---------------------------------------
# A green run says almost nothing on its own: under the default GITHUB_TOKEN
# branch-protection and actions.* are unreadable and repo-settings comes back
# without its admin-only fields, so only `labels` is genuinely verified — yet
# the job concluded success. Track which control families were actually
# compared and state it in the summary, so a reader cannot mistake "nothing
# was checkable" for "nothing has drifted".
#
# Defined ABOVE stop_uncheckable so the earliest bail-outs (missing gh/jq, bad
# --tier) still emit a coverage line. Those are the runs that check the LEAST
# while exiting 0 in non-strict mode, so they are exactly the runs that must
# not look like a clean pass.
ALL_FAMILIES="branch-protection repo-settings actions labels"
VERIFIED_FAMILIES=""
SKIPPED_FAMILIES=""

_family_of() { printf '%s' "${1%%.*}"; }

mark_verified() {
  case " $VERIFIED_FAMILIES " in *" $1 "*) ;; *) VERIFIED_FAMILIES="$VERIFIED_FAMILIES $1" ;; esac
}

mark_skipped() {
  case " $SKIPPED_FAMILIES " in *" $1 "*) ;; *) SKIPPED_FAMILIES="$SKIPPED_FAMILIES $1" ;; esac
}

# ALWAYS the last line, stated in terms of what was VERIFIED rather than what
# was found. The clean branch is gated on the SKIP SET being empty — never on a
# count, which a family marked verified under a name outside ALL_FAMILIES could
# satisfy while that family sat in the unverified list.
emit_coverage() {
  _total=0; _verified=0; _skipped=""; _verified_out=""
  for _fam in $ALL_FAMILIES; do
    _total=$((_total + 1))
    case " $VERIFIED_FAMILIES " in
      *" $_fam "*) _verified=$((_verified + 1)); _verified_out="${_verified_out}${_verified_out:+, }${_fam}" ;;
      *) _skipped="${_skipped}${_skipped:+, }${_fam}" ;;
    esac
  done
  if [ -z "$_skipped" ]; then
    echo "check-standards-drift: coverage — verified ${_verified}/${_total} control families (${_verified_out})."
    return
  fi
  # A family can be unverified for two different reasons, and conflating them
  # tells a reader that a REAL finding "could not be read". Separate them.
  _unreadable=""; _other=""
  for _fam in $(printf '%s' "$_skipped" | tr ',' ' '); do
    case " $SKIPPED_FAMILIES " in
      *" $_fam "*) _unreadable="${_unreadable}${_unreadable:+, }${_fam}" ;;
      *) _other="${_other}${_other:+, }${_fam}" ;;
    esac
  done
  echo "::warning::check-standards-drift: coverage — verified ${_verified}/${_total} control families (${_verified_out:-none}); NOT verified: ${_skipped}.${_unreadable:+ Could not be read (cause is named per-family in the warnings above — commonly insufficient token scope, in which case re-run with an admin PAT or grant 'administration: read'): ${_unreadable}.}${_other:+ Incomplete for another reason (see the warnings above — a reported finding is a real result, not an unread one): ${_other}.} A green result does NOT mean the unverified families match canon."
}

stop_uncheckable() {
  echo "::warning::check-standards-drift: $1"
  emit_coverage
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
# CI-0018: `gh` writes the API error body to STDOUT and exits non-zero, so the
# old `$(gh … || echo main)` form CONCATENATED the 404 JSON with `main` and fed
# the result into `repos/…/branches/${DEFAULT_BRANCH}/protection` — every
# downstream branch-protection query then hit a garbage path. Assign on success
# only, and validate the shape before using it as a path segment.
if ! DEFAULT_BRANCH=$(gh api "repos/${REPO}" --jq '.default_branch' 2>/dev/null); then
  DEFAULT_BRANCH=""
fi
case "$DEFAULT_BRANCH" in
  ''|*[!A-Za-z0-9._/-]*|null)
    echo "::warning::check-standards-drift: could not resolve the default branch of ${REPO} (token scope or API failure) — falling back to 'main'"
    DEFAULT_BRANCH="main" ;;
esac

MODE="warning-only"; [ "$STRICT" -eq 1 ] && MODE="strict"
echo "check-standards-drift: repo=$REPO tier=$TIER canon=$CI_TAG branch=$DEFAULT_BRANCH ($MODE)"

DRIFT=0
FETCH_ERRORS=0

# --- helper: strip _*-prefix metadata keys from canon JSON ---
strip_meta() {
  jq 'walk(if type == "object" then with_entries(select(.key | startswith("_") | not)) else . end)' "$1"
}

# --- helper: is this API response actually usable? (CI-0018) ---------------
# `gh api` can exit 0 having written NOTHING (204/304, a truncated write, a
# proxy returning an empty 200) or an error page. Comparing canon against such
# a body prints `canon=X actual=` for every key — unread state reported as
# drift, the defect CI-0018 exists to kill.
#
# The `[ -s ]` test is LOAD-BEARING and must come first: on EMPTY input jq
# emits no output, so `-e` never sees a false/null result and exits 0 for ANY
# filter — an empty file would otherwise pass every shape check.
#   $1 = file, $2 = optional jq type name to require (e.g. "object")
json_readable() {
  [ -s "$1" ] || return 1
  if [ -n "${2:-}" ]; then
    jq -e "type == \"$2\"" "$1" >/dev/null 2>&1
  else
    jq -e . "$1" >/dev/null 2>&1
  fi
}

# --- helper: emit a cannot-check warning (security H4 — no silent green) ---
warn_uncheckable() {
  echo "::warning::check-standards-drift: cannot check $1 ($2)"
  mark_skipped "$(_family_of "$1")"
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
elif ! json_readable "$bp_local" object; then
  # Same class as the repo-settings guard: a 0-exit-but-empty protection body
  # would otherwise compare as `canon=true actual=` on every key.
  warn_uncheckable "branch-protection" "the protection response for ${DEFAULT_BRANCH} is empty or is not a JSON object — an API/transport failure, NOT missing protection and NOT a token-scope problem. Re-run"
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
  mark_verified "branch-protection"
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
elif ! json_readable "$rs_local" object; then
  # CI-0018: `gh api` can exit 0 having written nothing (204/304, a truncated
  # write, a proxy returning an empty 200) or an error page. Validate the SHAPE
  # before probing keys.
  #
  # The `[ -s ]` test is LOAD-BEARING and must stay first: on EMPTY input jq
  # produces no output, so `-e` never sees a false/null result and exits 0 —
  # for ANY filter, including this one. Without the file test, an empty body
  # passes the shape guard, `has($k)` then reports every key PRESENT, and each
  # comparison prints `actual=` (blank) as drift while the family is marked
  # verified. Diagnose the transport rather than blaming the token or settings.
  warn_uncheckable "repo-settings" "the 'gh api repos/${REPO}' response is empty or is not a JSON object — an API/transport failure, NOT a settings drift and NOT a token-scope problem. Re-run; if it persists, check API availability from the runner"
else
  strip_meta "$rs_canon_raw" > "$rs_canon"
  # CI-0018: an admin-only field ABSENT from the `gh api repos/` response means
  # the token could not read it, NOT that the setting drifted. Emitting
  # `canon=false actual=null` presented unreadable state as a drift finding —
  # inconsistent with the adjacent actions.* arm, which correctly says "cannot
  # check". Never compare canon against a value we never obtained.
  rs_checked=0
  rs_unreadable=""
  for k in allow_merge_commit allow_squash_merge allow_rebase_merge delete_branch_on_merge allow_auto_merge allow_update_branch squash_merge_commit_title squash_merge_commit_message; do
    if ! jq -e --arg k "$k" 'has($k)' "$rs_local" >/dev/null 2>&1; then
      rs_unreadable="${rs_unreadable}${rs_unreadable:+, }${k}"
      continue
    fi
    local_v=$(jq -r --arg k "$k" '.[$k]' "$rs_local")
    canon_v=$(jq -r --arg k "$k" 'if has($k) then .[$k] else "null" end' "$rs_canon")
    rs_checked=$((rs_checked + 1))
    if [ "$local_v" != "$canon_v" ]; then
      echo "::warning::repo-settings.${k}: canon=$canon_v actual=$local_v"
      DRIFT=$((DRIFT + 1))
    fi
  done
  if [ -n "$rs_unreadable" ]; then
    warn_uncheckable "repo-settings" "these admin-only fields are absent from the 'gh api repos/${REPO}' response, so the token can read the repo but not its merge settings — grant 'administration: read' or run with an admin PAT: ${rs_unreadable}"
  fi
  # ALL-OR-NOTHING (CI-0018). A family counts as verified only when EVERY field
  # was readable. Marking it on partial progress let the same family be both
  # "cannot check" and "verified", and the summary then printed the clean
  # `4/4` line — reintroducing the very "unreadable read as verified" defect
  # this coverage mechanism exists to prevent.
  if [ "$rs_checked" -gt 0 ] && [ -z "$rs_unreadable" ]; then mark_verified "repo-settings"; fi
fi
rm -f "$rs_local" "$rs_canon_raw" "$rs_canon"

# --- Actions permissions: check ALL 4 endpoints, not just workflow (L2-code) ---
# CI-0018: `actions` counts as verified only when EVERY arm below was readable.
# Rather than a per-arm counter that a future 5th arm could forget to increment,
# snapshot FETCH_ERRORS and compare after — any `warn_uncheckable` in any arm
# (including ones added later) then correctly withholds the verified mark.
ap_err_before=$FETCH_ERRORS
ap_canon_raw=$(mktemp)
if ! curl -fsSL "${TEMPLATE_BASE}/actions-permissions.json" > "$ap_canon_raw" 2>/dev/null; then
  warn_uncheckable "actions.canon" "canon fetch failed"
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
# Verified only if NO arm above reported uncheckable (see ap_err_before).
if [ "$FETCH_ERRORS" -eq "$ap_err_before" ]; then mark_verified "actions"; fi
rm -f "$ap_canon_raw"

# --- Labels: only warn if a canon-required label is MISSING (never on extras) ---
lb_local=$(mktemp)
lb_canon=$(mktemp)
if ! gh api --paginate "repos/${REPO}/labels?per_page=100" > "$lb_local" 2>/dev/null; then
  warn_uncheckable "labels" "gh api labels failed"
elif ! curl -fsSL "${TEMPLATE_BASE}/labels.json" > "$lb_canon" 2>/dev/null; then
  warn_uncheckable "labels" "canon fetch failed"
elif ! json_readable "$lb_local"; then
  # No type filter: `--paginate` emits one array PER PAGE, so the body is a JSON
  # stream, not a single array. Guard only that it is non-empty and parses —
  # otherwise the slurpfile below yields an empty $actual, every canon label
  # reads as MISSING, and the family is marked verified off an unread response.
  warn_uncheckable "labels" "the labels response is empty or is not parseable JSON — an API/transport failure, NOT missing labels. Re-run"
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
  mark_verified "labels"
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

emit_coverage

[ "$STRICT" -eq 0 ] || [ $((DRIFT + FETCH_ERRORS + PIN_ERRORS)) -eq 0 ] || exit 1
exit 0
