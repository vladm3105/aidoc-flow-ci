#!/usr/bin/env bash
# tests/test_resolver.sh — regression cover for the canon-pin RESOLVER, the
# mechanism FT-15 broke.
#
# WHY THIS EXISTS: the four asset-fetching reusables resolve which canon version
# to fetch from by grepping the consumer's own adopted `uses:` pin. That logic is
# security- and determinism-load-bearing (FT-15: the pin did not control the
# fetched assets for months, across every consumer, undetected). Canon cannot
# execute those reusables in its own CI for `ai-review`/`doc-maintainer` — see
# FT-23 — so without this file a resolver regression ships to the fleet unseen.
#
# HOW IT STAYS HONEST: every pattern is EXTRACTED FROM THE WORKFLOW ITSELF, never
# copied here. A test that hard-codes its own copy of the regex passes happily
# while the real one rots.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(cd "$HERE/.." && pwd)"
WF="$ROOT/.github/workflows"

# reusable -> the workflow filename its pin pattern is keyed to
REUSABLES="ai-review doc-maintainer docs-sync standards-drift"

# Pull the live pin pattern out of a workflow (first occurrence; all sites in a
# file are identical by construction and §4.2a requires that).
pattern_for() {
  python3 - "$WF/$1.yml" <<'PY'
import re,sys
src=open(sys.argv[1]).read()
m=re.search(r"grep -ohE '([^']*aidoc-flow-ci[^']*\.yml@[^']*)'", src)
print(m.group(1) if m else "")
PY
}

# The real two-stage pipeline: uses:-lines in executable workflow files, then the
# keyed pattern.
resolve() { # $1=fixture dir  $2=pattern
  grep -rhE --include='*.yml' --include='*.yaml' '^[[:space:]]*uses:' "$1" 2>/dev/null \
    | grep -ohE "$2" | sort -u
}

FIX="$(mktemp -d)"; trap 'rm -rf "$FIX"' EXIT
mkdir -p "$FIX/.github/workflows"
put() { printf '%s\n' "$2" > "$FIX/.github/workflows/$1"; }
clear_fix() { rm -f "$FIX"/.github/workflows/*; }

echo "== resolver pattern is extractable from every reusable =="
for r in $REUSABLES; do
  p="$(pattern_for "$r")"
  assert_ok "[ -n '$p' ]" "$r: pin pattern found in the workflow"
done

echo "== §4.2a properties present in every resolver (structural) =="
# NOTE the deliberate asymmetry: doc-maintainer / docs-sync / standards-drift
# GREP A DIRECTORY (the caller's checked-out .github/workflows/), so they need
# `--include` to keep a *.yml.bak or *.disabled leftover from winning the version
# sort. ai-review has NO checkout by design (IPLAN-0024), so it fetches the
# caller's single entry workflow over the API and greps THAT ONE FILE — there is
# no directory to scope and no leftover to exclude. Asserting `--include` on it
# would be cargo-culting a property it cannot have.
DIR_SCANNERS="doc-maintainer docs-sync standards-drift"
for r in $DIR_SCANNERS; do
  assert_contains "$(cat "$WF/$r.yml")" "--include='*.yml'" \
    "$r: directory scan scoped to executable workflow files"
done
assert_absent "$(cat "$WF/ai-review.yml")" "--include='*.yml'" \
  "ai-review: single-file resolver correctly has no directory scope"

for r in $REUSABLES; do
  body="$(cat "$WF/$r.yml")"
  assert_contains "$body" "'^[[:space:]]*uses:'"     "$r: only real uses: lines are read"
  assert_contains "$body" 'vladm3105/aidoc-flow-ci/' "$r: canon owner anchored in the pattern"
  assert_contains "$body" 'PIN_COUNT'                "$r: ambiguity is counted (fail-closed)"
  assert_contains "$body" 'FETCH_REF'                "$r: fetches at the executed ref"
  assert_contains "$body" '*-*)'                     "$r: pre-release pin rejected"
done

echo "== behavioural: the LIVE pattern against fixtures =="
for r in $REUSABLES; do
  p="$(pattern_for "$r")"
  [ -z "$p" ] && { _r "$r: no pattern; skipping behaviour"; continue; }

  clear_fix
  put a.yml "    uses: vladm3105/aidoc-flow-ci/.github/workflows/$r.yml@ci/v2.10.0"
  assert_eq "$(resolve "$FIX/.github/workflows" "$p" | grep -oE 'ci/v[0-9.]+$')" "ci/v2.10.0" \
    "$r: plain pin resolves"

  clear_fix
  put a.yml "    uses: vladm3105/aidoc-flow-ci/.github/workflows/$r.yml@a1b2c3d4e5f60718293a4b5c6d7e8f9012345678 # ci/v2.8.0"
  assert_contains "$(resolve "$FIX/.github/workflows" "$p")" "a1b2c3d4e5f60718293a4b5c6d7e8f9012345678" \
    "$r: commented-SHA pin form matches (and the SHA is available to fetch at)"

  clear_fix
  put a.yml "    uses: someorg/aidoc-flow-ci/.github/workflows/$r.yml@ci/v9.9.9"
  assert_eq "$(resolve "$FIX/.github/workflows" "$p")" "" \
    "$r: a FOREIGN owner's pin is rejected, not silently resolved"

  clear_fix
  put a.yml "    # uses: vladm3105/aidoc-flow-ci/.github/workflows/$r.yml@ci/v9.9.9"
  assert_eq "$(resolve "$FIX/.github/workflows" "$p")" "" \
    "$r: a commented-out example cannot supply the tag"

  # Directory-scan hazard only — ai-review reads a single fetched file, so a
  # stray *.bak is not reachable for it (see the structural note above).
  case " $DIR_SCANNERS " in *" $r "*)
    clear_fix
    put real.yml "    uses: vladm3105/aidoc-flow-ci/.github/workflows/$r.yml@ci/v2.10.0"
    printf '%s\n' "    uses: vladm3105/aidoc-flow-ci/.github/workflows/$r.yml@ci/v9.9.9" \
      > "$FIX/.github/workflows/stale.yml.bak"
    assert_eq "$(resolve "$FIX/.github/workflows" "$p" | grep -oE 'ci/v[0-9.]+$')" "ci/v2.10.0" \
      "$r: a *.yml.bak leftover cannot win the version sort"
  ;; esac

  clear_fix
  put a.yml "    uses: vladm3105/aidoc-flow-ci/.github/workflows/$r.yml@ci/v2.11.0-rc.1"
  assert_contains "$(resolve "$FIX/.github/workflows" "$p")" "-rc.1" \
    "$r: a pre-release pin is CAPTURED whole (so it can be rejected, not truncated)"

  # cross-keying: one reusable's pattern must never match another's pin
  other="docs-sync"; [ "$r" = "docs-sync" ] && other="ai-review"
  clear_fix
  put a.yml "    uses: vladm3105/aidoc-flow-ci/.github/workflows/$other.yml@ci/v9.9.9"
  assert_eq "$(resolve "$FIX/.github/workflows" "$p")" "" \
    "$r: does not match ${other}'s pin (filename-keyed)"
done

suite_summary "resolver"
