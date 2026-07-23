#!/usr/bin/env bash
# tests/test_exerciser_inventory.sh — completeness guard for the exerciser
# inventory (PLAN-018 Workstream C, contract item 7).
#
# WHY THIS EXISTS: F1 shipped broken for nine releases because a consumer-facing
# surface (a bootstrap template) had no exerciser and nobody noticed the gap. The
# inventory (docs/EXERCISER_INVENTORY.md) makes the exercised/unexercised set
# explicit; this guard keeps it COMPLETE. A new manifest.json surface or a new
# reusable workflow added WITHOUT an inventory row fails here — the F1 failure
# mode (an untracked surface) caught the moment it is introduced.
#
# It does NOT assert that a surface is *exercised* — an honest "unexercised —
# FT-NN" row is a valid, passing state. It asserts only that every surface is
# ACCOUNTED FOR. Silence about a surface is the bug.
#
# HOW IT STAYS HONEST: the surface lists are derived from manifest.json and the
# workflow files at run time, never copied into this test. The inventory's
# coverage is checked against the live surfaces, so it cannot drift green.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(cd "$HERE/.." && pwd)"
INV="$ROOT/docs/EXERCISER_INVENTORY.md"
MANIFEST="$ROOT/install/templates/manifest.json"
WF="$ROOT/.github/workflows"

assert_ok "[ -f '$INV' ]" "exerciser inventory exists"

# The set of surface paths the inventory lists: the FIRST backtick-quoted token
# of each TABLE ROW whose first cell is a backtick path (`| `<path>` | …`). It is
# deliberately NOT "any backtick token anywhere" — that let a surface look covered
# via a stray prose/reason-column mention with no real exerciser row, the exact
# "present but silently unexercised" mode F1 was. A surface is 'covered' here only
# by an actual row keyed on it.
inv_surfaces() {
  grep -E '^\| `' "$INV" | sed -E 's/^\| `([^`]+)`.*/\1/' | sort -u
}
in_inventory() { inv_surfaces | grep -qxF "$1"; }

# ---------------------------------------------------------------------------
# 1. Every manifest.json consumer surface has an inventory row.
# ---------------------------------------------------------------------------
echo "== every manifest.json surface is accounted for in the inventory =="
missing_manifest=0
while IFS= read -r path; do
  [ -n "$path" ] || continue
  if in_inventory "$path"; then _g "manifest surface listed: $path"
  else _r "manifest surface MISSING from inventory: $path"; missing_manifest=1; fi
done < <(python3 -c "
import json
for f in json.load(open('$MANIFEST'))['files']:
    print(f['path'])
")
assert_eq "$missing_manifest" "0" "all manifest surfaces are in the inventory"

# ---------------------------------------------------------------------------
# 2. Every reusable workflow canon ships (workflow_call) has an inventory row.
#    Self-caller/local workflows (self-*.yml, tests.yml, standards-drift-self,
#    litellm-smoke, audit-trail.yml) are NOT library surfaces — they are the
#    exercisers — so they are excluded, not required to have a row.
# ---------------------------------------------------------------------------
echo ""
echo "== every reusable (workflow_call) workflow is accounted for =="
missing_wf=0
for f in "$WF"/*.yml; do
  grep -qE '^\s+workflow_call:' "$f" || continue
  rel=".github/workflows/$(basename "$f")"
  if in_inventory "$rel"; then _g "reusable listed: $rel"
  else _r "reusable MISSING from inventory: $rel"; missing_wf=1; fi
done
assert_eq "$missing_wf" "0" "all reusable workflows are in the inventory"

# ---------------------------------------------------------------------------
# 3. Every canonical script has an inventory row. Scripts are consumer-facing
#    (install/update/drift) or release-critical; an unlisted one is an untracked
#    surface. set-litellm-secrets is listed (as accepted-unexercised), so this
#    holds for all of them.
# ---------------------------------------------------------------------------
echo ""
echo "== every canonical script is accounted for =="
missing_script=0
for f in "$ROOT"/install/*.sh "$ROOT"/scripts/*.sh "$ROOT"/sync/*.sh; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  # Match by basename (a script may be referenced by either of its homes, e.g.
  # scripts/pre_push_check.sh). grep -F on the basename with an explicit '/' or
  # start anchor via a fixed-string suffix test — no regex metachar hazard from
  # the '.' in the filename.
  if inv_surfaces | grep -qxF "$base" || inv_surfaces | grep -qF "/$base"; then
    _g "script listed: $base"
  else _r "script MISSING from inventory: $base"; missing_script=1; fi
done
assert_eq "$missing_script" "0" "all canonical scripts are in the inventory"

# ---------------------------------------------------------------------------
# 3b. Shipped template FRAGMENTS that are NOT 1:1 manifest surfaces (merged into
#     the consumer file, so absent from the manifest walk) are still surfaces
#     canon distributes. The pre-commit fragment is the one F2/F3 are about — the
#     guard's manifest/reusable/script sets structurally miss it, so it is named
#     explicitly here rather than assumed covered.
# ---------------------------------------------------------------------------
echo ""
echo "== shipped non-manifest template fragments are accounted for =="
for frag in install/templates/pre-commit-hook-block.yaml; do
  if in_inventory "$frag"; then _g "fragment listed: $frag"
  else _r "fragment MISSING from inventory: $frag"; fi
done

# ---------------------------------------------------------------------------
# 4. Reverse guard: every UNEXERCISED row names an FT (or an explicit
#    'accepted'). An unexercised surface with no owner is the gap that must not
#    be silent — the whole point of the file.
# ---------------------------------------------------------------------------
echo ""
echo "== every 'unexercised' row names its closing FT or is explicitly accepted =="
bad_rows=0
while IFS= read -r line; do
  # Only TABLE ROWS whose first cell is a backtick-quoted surface path — skip the
  # intro prose and the kinds-legend row (`| **unexercised** | …`), which mention
  # the word without being surface rows.
  case "$line" in '| `'*) ;; *) continue ;; esac
  case "$line" in *unexercised*) ;; *) continue ;; esac
  # Owner = a closing FT, or the explicit sentinel `accepted-no-FT`. The bare
  # word 'accepted' is NOT accepted (it substring-matches "not accepted by
  # anyone" and other prose); the sentinel is unambiguous.
  if printf '%s' "$line" | grep -qE 'FT-[0-9]+|`accepted-no-FT`'; then
    _g "unexercised row is owned: $(printf '%s' "$line" | grep -oE '`[^`]+`' | head -1)"
  else
    _r "unexercised row names no FT and no accepted-no-FT sentinel: $line"; bad_rows=1
  fi
done < "$INV"
assert_eq "$bad_rows" "0" "no orphan unexercised rows"

suite_summary "exerciser-inventory"
