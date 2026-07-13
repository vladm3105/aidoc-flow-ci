#!/usr/bin/env bash
# aidoc-flow-ci sync/check-pin-currency.sh — flag consumer @ci/vX.Y.Z pins that
# LAG the current canon VERSION. Complements the other two drift checks, which
# both compare a caller against the template AT THE TAG IT IS PINNED TO and so
# CANNOT tell you a pin is stale:
#   - sync/check-drift.sh            → workflow-file content drift (per pinned tag)
#   - sync/check-standards-drift.sh  → server-side settings drift (per tier)
# This one answers "is the pin itself current?" — the pin-staleness dimension.
#
# WARNING-ONLY, NEVER BLOCKS (mirrors the other drift checks): emits
# `::warning::` per stale pin and ALWAYS exits 0.
#
# Usage:
#   bash sync/check-pin-currency.sh                 # in a consumer repo; audits ./.github/workflows
#   bash sync/check-pin-currency.sh --canon ci/v1.9.5   # pin the canon explicitly (else fetched from main)
#   bash sync/check-pin-currency.sh --fleet R1 R2 …  # audit multiple repos via `gh api` (table + summary)
#
# Canon resolution order: --canon arg → local ./VERSION (if run in aidoc-flow-ci)
# → https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/main/VERSION.
set -uo pipefail
GH="${GH:-gh}"

CANON=""; MODE="inrepo"; FLEET_REPOS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --canon) CANON="$2"; shift 2;;
    --fleet) MODE="fleet"; shift; while [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; do FLEET_REPOS+=("$1"); shift; done;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

resolve_canon() {
  [ -n "$CANON" ] && { echo "$CANON"; return; }
  [ -f VERSION ] && grep -qE '^ci/v' VERSION && { tr -d '[:space:]' < VERSION; return; }
  curl -fsSL "https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/main/VERSION" 2>/dev/null | tr -d '[:space:]' || echo ""
}

# semver compare: echoes -1 (a<b), 0 (a==b), 1 (a>b). Input "ci/vA.B.C".
ver_cmp() {
  local a="${1#ci/v}" b="${2#ci/v}"; IFS=. read -r a1 a2 a3 <<<"$a"; IFS=. read -r b1 b2 b3 <<<"$b"
  for pair in "$a1 $b1" "$a2 $b2" "$a3 $b3"; do
    set -- $pair; local x="${1:-0}" y="${2:-0}"
    [ "$x" -lt "$y" ] 2>/dev/null && { echo -1; return; }
    [ "$x" -gt "$y" ] 2>/dev/null && { echo 1; return; }
  done; echo 0
}

audit_repo() {  # $1 = "local" | owner/repo ; $2 = canon
  local repo="$1" canon="$2" stale=0 total=0
  local files pin wf tag
  if [ "$repo" = "local" ]; then
    for f in .github/workflows/*.yml .github/workflows/*.yaml; do
      [ -f "$f" ] || continue
      while read -r wf tag; do
        [ -z "$tag" ] && continue
        tag="${tag#__sha__ }"; [ "${tag#ci/v}" = "$tag" ] && continue  # tag must be ci/vX
        total=$((total+1))
        if [ "$(ver_cmp "$tag" "$canon")" = "-1" ]; then
          printf '::warning::pin-currency: %s pinned @%s (canon %s) — re-pin\n' "$(basename "$f")" "$tag" "$canon"
          stale=$((stale+1))
        fi
      done < <(grep -oE '@ci/v[0-9]+\.[0-9]+\.[0-9]+' "$f" 2>/dev/null | sort -u | sed "s#@#$(basename "$f" .yml) #")
    done
  else
    local default_branch; default_branch="$($GH api "repos/$repo" -q '.default_branch' 2>/dev/null)"
    [ -n "$default_branch" ] || default_branch=main
    local list; list="$($GH api "repos/$repo/contents/.github/workflows?ref=$default_branch" --jq '.[].name' 2>/dev/null)" || { echo "  $repo: unreadable"; return; }
    local worst="$canon" any=0
    for wf in $list; do
      [[ "$wf" == *.yml ]] || continue
      pin="$($GH api "repos/$repo/contents/.github/workflows/$wf?ref=$default_branch" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null | grep -oE 'vladm3105/aidoc-flow-ci/[^@]+@ci/v[0-9]+\.[0-9]+\.[0-9]+|@[0-9a-f]{40} # ci/v[0-9.]+' | grep -oE 'ci/v[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
      [ -z "$pin" ] && continue
      pin="ci/v${pin#ci/v}"; any=1; total=$((total+1))
      if [ "$(ver_cmp "$pin" "$canon")" = "-1" ]; then
        stale=$((stale+1)); [ "$(ver_cmp "$pin" "$worst")" = "-1" ] && worst="$pin"
        printf '    %-20s @%s  ⚠️ STALE\n' "${wf%.yml}" "$pin"
      fi
    done
    if [ "$any" = 0 ]; then echo "    (no aidoc-flow-ci pins)";
    elif [ "$stale" = 0 ]; then echo "    ✅ all $total pins current (@$canon)";
    else echo "    → $stale/$total stale; oldest @$worst.  Re-pin: install/install.sh $repo --repin  (CI_TAG=$canon)"; fi
  fi
  return "$stale"
}

CANON="$(resolve_canon)"
[ -z "$CANON" ] && { echo "::warning::pin-currency: could not resolve canon VERSION (pass --canon ci/vX.Y.Z)"; exit 0; }

if [ "$MODE" = fleet ]; then
  echo "Pin-currency audit — canon = $CANON"
  fleet_stale=0
  for r in "${FLEET_REPOS[@]}"; do
    echo "── $r ──"
    audit_repo "$r" "$CANON" || fleet_stale=$((fleet_stale+1))
  done
  echo
  echo "Repos with stale pins: $fleet_stale/${#FLEET_REPOS[@]}.  Re-pin each with: install/install.sh <repo> --repin"
else
  echo "pin-currency: auditing ./.github/workflows against canon $CANON"
  audit_repo local "$CANON"; s=$?
  [ "$s" = 0 ] && echo "pin-currency: all pins current ✅" || echo "pin-currency: $s stale pin(s) — run 'install/install.sh <this-repo> --repin' (warning-only)"
fi
exit 0
