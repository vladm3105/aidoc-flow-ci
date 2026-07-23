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

# Grep the FILE, never a slurped copy of it. `ai-review.yml` is ~96KB and passing
# that through a shell variable + `printf '%s' "$1"` argument (what
# assert_contains does) proved environment-sensitive: it worked locally and came
# back empty in CI, which silently INVERTED the results — every `contains` failed
# and the `absent` check spuriously passed. File-based greps have no such limit.
has()   { if grep -qF -- "$2" "$1"; then _g "$3"; else _r "$3"; fi; }
hasnt() { if grep -qF -- "$2" "$1"; then _r "$3"; else _g "$3"; fi; }

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
  has "$WF/$r.yml" "--include='*.yml'" "$r: directory scan scoped to executable workflow files"
done
hasnt "$WF/ai-review.yml" "--include='*.yml'" \
  "ai-review: single-file resolver correctly has no directory scope"

for r in $REUSABLES; do
  f="$WF/$r.yml"
  has "$f" "'^[[:space:]]*uses:'"     "$r: only real uses: lines are read"
  has "$f" 'vladm3105/aidoc-flow-ci/' "$r: canon owner anchored in the pattern"
  has "$f" 'PIN_COUNT'                "$r: ambiguity is counted (fail-closed)"
  has "$f" 'FETCH_REF'                "$r: fetches at the executed ref"
  has "$f" '*-*)'                     "$r: pre-release pin rejected"
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

echo "== FT-28: a SHA-form pin's SHA is verified against its claimed tag =="
# Both resolvers (review + autofix) must peel the claimed tag and hard-fail if
# the pinned SHA is not the tag's commit — else a `@<fork-sha> # ci/vX.Y.Z` pin
# executes never-merged code while reading as the released tag in review.
AR="$ROOT/.github/workflows/ai-review.yml"
peel_blocks="$(grep -c 'application/vnd.github.sha' "$AR" || true)"
assert_eq "$peel_blocks" "2" "both resolvers (review + autofix) peel the tag via the commits API"
assert_ok "grep -q 'is NOT the commit of tag' '$AR'" "resolvers hard-fail on a SHA/tag mismatch (FT-28)"
assert_ok "grep -q 'commits/\${CANON_TAG}' '$AR'" "peel targets the claimed CANON_TAG"
# The shipped caller template is tag-only, so this check is inert for normal
# consumers — it only arms for the SHA-form pin. Guard that so a future template
# change to SHA-form is a conscious decision, not an accident.
assert_ok "grep -qE 'ai-review\\.yml@ci/v[0-9]' '$ROOT/install/templates/workflows/ai-review.yml'" \
  "shipped ai-review caller pins tag-only (peel inert for normal consumers)"

# Behavioural teeth — DRIVE THE SHIPPED BLOCK, not a copy (FT-40). The prior
# version re-implemented the comparison in a local `verify()`, so mutating the
# real `ai-review.yml` guard (`if false;` in either resolver) left the suite
# green — the shipped code could be disabled undetected. Now both FT28-PEEL-VERIFY
# blocks are extracted from the workflow and run for real with `curl` stubbed to
# return a chosen tag-commit SHA; a mutation to the shipped comparison must go red.
SHA_A="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
SHA_B="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

nblocks="$(grep -c '# >>> FT28-PEEL-VERIFY >>>' "$AR" || true)"
assert_eq "$nblocks" "2" "both resolvers carry an extractable FT28-PEEL-VERIFY block"

# Extract the Nth block's body (comment lines inside are harmless when run).
extract_peel() { # $1 = 1-based block index -> stdout
  awk -v want="$1" '
    /# >>> FT28-PEEL-VERIFY >>>/ { n++; inb=(n==want)?1:0; next }
    /# <<< FT28-PEEL-VERIFY <<</ { inb=0; next }
    inb { print }
  ' "$AR"
}

# Run a block with curl stubbed. Mirrors the GitHub Actions default shell
# (`bash -eo pipefail`, NOT -u). $2 = pinned CANON_SHA; $3 = SHA the stubbed curl
# returns for the tag peel ('' = unreachable tag). Returns the block's exit code.
drive_peel() { # $1=block-body-file $2=CANON_SHA $3=stub-tag-commit -> rc
  {
    echo 'set -eo pipefail'
    printf 'CANON_SHA=%s\n' "$2"
    echo 'CANON_TAG=ci/v9.9.9'
    echo 'GITHUB_TOKEN=stub-token'
    echo "curl() { printf '%s' '$3'; }"
    cat "$1"
  } > "$FIX/drive.sh"
  ( bash "$FIX/drive.sh" ) >/dev/null 2>&1
}

for idx in 1 2; do
  which="review"; [ "$idx" = 2 ] && which="autofix"
  extract_peel "$idx" > "$FIX/peel-$idx.sh"
  assert_ok "grep -q 'TAG_COMMIT' '$FIX/peel-$idx.sh'" "$which resolver: peel block extracted"

  drive_peel "$FIX/peel-$idx.sh" "$SHA_A" "$SHA_A"
  assert_eq "$?" "0" "$which resolver: SHA matching the peeled tag is ACCEPTED (rc=0)"

  drive_peel "$FIX/peel-$idx.sh" "$SHA_A" "$SHA_B"
  assert_eq "$?" "1" "$which resolver: SHA ≠ the tag's commit is REJECTED (rc=1) — the FT-28 teeth"

  drive_peel "$FIX/peel-$idx.sh" "$SHA_A" ""
  assert_eq "$?" "1" "$which resolver: an unreachable tag (empty peel) is REJECTED (rc=1)"

  drive_peel "$FIX/peel-$idx.sh" "" "$SHA_B"
  assert_eq "$?" "0" "$which resolver: a tag-only pin (no SHA) skips the peel (rc=0)"
done

suite_summary "resolver"
