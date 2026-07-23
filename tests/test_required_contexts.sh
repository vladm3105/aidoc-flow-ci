#!/usr/bin/env bash
# tests/test_required_contexts.sh — required-context ↔ producer validator
# (PLAN-018 FT-18), install/required-context-map.py.
#
# WHY THIS EXISTS: F2 was "a required status-check context has no producing
# workflow installed, so arming protection pins every PR forever." test_checknames
# already proves each required context names a real reusable JOB; this proves the
# next link — that canon ships a CALLER that produces it, and it drives the map
# the wizard uses to catch a consumer missing that caller.
#
# THE INVARIANT (general form of F2 as a canon self-check): every required
# context in every tier template must resolve to a producing caller canon ships.
# A tier that requires `call / X` with no producer is F2 latent in canon — a
# `?` in the map, and a red test here.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(cd "$HERE/.." && pwd)"
MAP="$ROOT/install/required-context-map.py"

assert_ok "[ -f '$MAP' ]" "required-context map generator exists"

out="$(python3 "$MAP" "$ROOT" 2>/dev/null || echo '')"
if [ "$out" = SKIP ] || [ -z "$out" ]; then
  if [ "${CI:-}" = "true" ]; then
    _r "map generator returned SKIP/empty in CI (install python3-yaml)"
    suite_summary "required-contexts"; exit $?
  fi
  printf '  \033[33mskip\033[0m PyYAML unavailable — required-context tests skipped\n'
  suite_summary "required-contexts"; exit $?
fi

# ---------------------------------------------------------------------------
# 1. THE INVARIANT — every required context resolves to a producer (no `?`).
# ---------------------------------------------------------------------------
echo "== every required context has a canon producer (no orphan required check) =="
orphans=0
while IFS=$'\t' read -r tier ctx producer; do
  [ -n "$tier" ] || continue
  case "$producer" in
    '?')       _r "$tier: '$ctx' has NO producing caller in canon — arming would hang (F2 latent)"; orphans=1 ;;
    '?non-call') _g "$tier: '$ctx' is a bare (repo-local) context — no canon producer expected" ;;
    *)         _g "$tier: '$ctx' <- $producer" ;;
  esac
done < <(printf '%s\n' "$out")
assert_eq "$orphans" "0" "no required context is missing a canon producer"

# ---------------------------------------------------------------------------
# 2. The chain is DERIVED correctly — spot-check the non-obvious resolutions
#    against source. These are asserted, not hardcoded in the map: the map reads
#    reusable job names + caller `uses:` + the manifest. In particular
#    `call / verify` must resolve through the audit-trail-check REUSABLE to the
#    audit-trail CALLER (different basenames — the case a naive map gets wrong).
# ---------------------------------------------------------------------------
echo ""
echo "== producer resolution is correct for the non-obvious chains =="
producer_for() { printf '%s\n' "$out" | awk -F'\t' -v c="$1" '$2==c{print $3; exit}'; }
assert_eq "$(producer_for 'call / verify')" "audit-trail.yml" \
  "call / verify resolves through audit-trail-check reusable to the audit-trail caller"
assert_eq "$(producer_for 'call / Lint / format / security hooks')" "pre-commit.yml" \
  "call / Lint / format / security hooks resolves to pre-commit.yml (the F2 instance)"
assert_eq "$(producer_for 'call / gitleaks')" "secret-scan.yml" \
  "call / gitleaks resolves to secret-scan.yml"

# ---------------------------------------------------------------------------
# 3. TEETH — remove a caller template and the context it produced loses its
#    producer (-> `?`). Confirms the map really reads the templates rather than
#    inventing the answer, and that the invariant would catch the regression.
# ---------------------------------------------------------------------------
echo ""
echo "== removing a producer's caller template is detected =="
SB="$(mktemp -d)"; trap 'rm -rf "$SB"' EXIT
cp -r "$ROOT/.github" "$ROOT/install" "$SB/" 2>/dev/null
# Drop BOTH secret-scan caller templates so nothing produces call / gitleaks.
rm -f "$SB"/install/templates/workflows/secret-scan.yml "$SB"/install/templates/workflows/secret-scan-private.yml
mut="$(python3 "$MAP" "$SB" 2>/dev/null || echo '')"
gitleaks_prod="$(printf '%s\n' "$mut" | awk -F'\t' '$2=="call / gitleaks"{print $3; exit}')"
assert_eq "$gitleaks_prod" "?" "with secret-scan caller templates removed, call / gitleaks has NO producer"

suite_summary "required-contexts"
