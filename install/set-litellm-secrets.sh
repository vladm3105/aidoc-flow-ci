#!/usr/bin/env bash
# set-litellm-secrets.sh — provision LiteLLM CI secrets on the aidoc-flow fleet.
# PLAN-009 Phase 0 (founder-executed). Sets REPOSITORY-level GitHub Actions secrets:
#   LITELLM_BASE_URL, LITELLM_REVIEW_API_KEY  (+ optional LITELLM_DOC_API_KEY)
#
# SECURITY:
#   * Never hardcodes secret VALUES — reads them from env vars.
#   * Pipes values to `gh secret set` via STDIN (not argv), so they never appear
#     in `ps`/the process table.
#   * GitHub stores them encrypted + write-only; they are masked in Actions logs.
#   * Store only the SCOPED virtual key — never the LiteLLM master key.
#
# TWO MODES:
#   shared : one review key applied to every repo.
#            export LITELLM_BASE_URL LITELLM_REVIEW_API_KEY [LITELLM_DOC_API_KEY]
#   mint   : mint a fresh, per-repo, review-scoped virtual key from the master key
#            (revocable per repo; tagged with the repo name). --mint
#            export LITELLM_BASE_URL LITELLM_MASTER_KEY
#
# USAGE:
#   export LITELLM_BASE_URL="https://proxy.example/v1"
#   export LITELLM_REVIEW_API_KEY="<key>"         # shared mode
#   bash set-litellm-secrets.sh --pilot            # engramory only (pilot first)
#   bash set-litellm-secrets.sh                     # all 7 consumers
#   bash set-litellm-secrets.sh --repos "vladm3105/aidoc-flow-framework vladm3105/iplan-runner"
#   bash set-litellm-secrets.sh --dry-run          # print, change nothing
#   bash set-litellm-secrets.sh --doc              # also set the doc-maintainer key
#
#   # per-repo revocable keys (recommended once you have the master key locally):
#   export LITELLM_MASTER_KEY="<key>"
#   bash set-litellm-secrets.sh --mint --budget 50
#
# TIP: run in a subshell so the exported keys leave no trace in your shell history:
#   ( export LITELLM_BASE_URL=... LITELLM_REVIEW_API_KEY=...; bash set-litellm-secrets.sh )

set -euo pipefail

OWNER="vladm3105"
# The 7 PLAN-009 consumers (exact repo names; note iplan-runner has no aidoc-flow- prefix).
CONSUMERS=(
  aidoc-flow-framework
  aidoc-flow-business
  aidoc-flow-iplanic
  iplan-runner
  aidoc-flow-iplan-standard
  aidoc-flow-engramory
  aidoc-flow-interlog
)
PILOT="aidoc-flow-engramory"

DRY_RUN=0; MINT=0; SET_DOC=0; BUDGET=50
REPOS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --mint)    MINT=1 ;;
    --doc)     SET_DOC=1 ;;
    --pilot)   REPOS=("$OWNER/$PILOT") ;;
    --budget)  BUDGET="${2:?--budget needs a number}"; shift ;;
    --repos)   IFS=' ' read -r -a REPOS <<< "${2:?--repos needs a list}"; shift ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done
if [ "${#REPOS[@]}" -eq 0 ]; then for r in "${CONSUMERS[@]}"; do REPOS+=("$OWNER/$r"); done; fi

# ---- preflight ----
command -v gh >/dev/null || { echo "ERROR: gh CLI required" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "ERROR: run 'gh auth login' first" >&2; exit 1; }
: "${LITELLM_BASE_URL:?export LITELLM_BASE_URL first}"
case "$LITELLM_BASE_URL" in
  https://*) ;;
  http://*)  echo "WARN: HTTP base URL — the bearer key travels in cleartext. Prefer HTTPS / a private mesh." >&2 ;;
  *) echo "ERROR: LITELLM_BASE_URL must be an http(s) URL" >&2; exit 1 ;;
esac
# LiteLLM MANAGEMENT endpoints (/key/generate) live at the ROOT, NOT under /v1
# (the /v1 path is the OpenAI-compat surface). Derive the root from the base URL
# so a canonical `…/v1` base URL still mints against `…/key/generate`.
MGMT_URL="${LITELLM_BASE_URL%/}"; MGMT_URL="${MGMT_URL%/v1}"

if [ "$MINT" -eq 1 ]; then
  command -v jq   >/dev/null || { echo "ERROR: jq required for --mint" >&2; exit 1; }
  command -v curl >/dev/null || { echo "ERROR: curl required for --mint" >&2; exit 1; }
  : "${LITELLM_MASTER_KEY:?export LITELLM_MASTER_KEY for --mint}"
else
  : "${LITELLM_REVIEW_API_KEY:?export LITELLM_REVIEW_API_KEY (or use --mint)}"
  if [ "$SET_DOC" -eq 1 ]; then : "${LITELLM_DOC_API_KEY:?export LITELLM_DOC_API_KEY for --doc}"; fi
fi

put() {  # put SECRET_NAME REPO   (value on stdin; never echoed)
  gh secret set "$1" -R "$2"
  echo "    ✓ $1"
}

mint() {  # mint REPO PURPOSE MODEL_ALIAS  -> prints the scoped key
  curl -fsS -X POST "$MGMT_URL/key/generate" \
    -H "Authorization: Bearer $LITELLM_MASTER_KEY" -H "Content-Type: application/json" \
    -d "{\"models\":[\"$3\"],\"max_budget\":$BUDGET,\"metadata\":{\"purpose\":\"$2\",\"repo\":\"$1\"}}" \
    | jq -er '.key'
}

echo "LiteLLM secret provisioning — mode=$([ "$MINT" -eq 1 ] && echo mint || echo shared)  dry_run=$DRY_RUN  repos=${#REPOS[@]}  doc=$SET_DOC"
for repo in "${REPOS[@]}"; do
  echo "• $repo"
  if ! gh repo view "$repo" >/dev/null 2>&1; then echo "    SKIP: no access to $repo" >&2; continue; fi
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "    [dry-run] would set LITELLM_BASE_URL, LITELLM_REVIEW_API_KEY$([ "$SET_DOC" -eq 1 ] && echo ', LITELLM_DOC_API_KEY')$([ "$MINT" -eq 1 ] && echo ' (freshly minted)')"
    continue
  fi
  printf '%s' "$LITELLM_BASE_URL" | put LITELLM_BASE_URL "$repo"
  if [ "$MINT" -eq 1 ]; then
    k="$(mint "$repo" ci-review ai-reviewer)";        printf '%s' "$k" | put LITELLM_REVIEW_API_KEY "$repo"; unset k
    if [ "$SET_DOC" -eq 1 ]; then d="$(mint "$repo" ci-docs ai-doc-maintainer)"; printf '%s' "$d" | put LITELLM_DOC_API_KEY "$repo"; unset d; fi
  else
    printf '%s' "$LITELLM_REVIEW_API_KEY" | put LITELLM_REVIEW_API_KEY "$repo"
    if [ "$SET_DOC" -eq 1 ]; then printf '%s' "$LITELLM_DOC_API_KEY" | put LITELLM_DOC_API_KEY "$repo"; fi
  fi
done

echo "Done. Verify (names only, values are write-only):"
echo "  for r in ${REPOS[*]}; do echo \"== \$r\"; gh secret list -R \"\$r\" | grep -i litellm; done"
