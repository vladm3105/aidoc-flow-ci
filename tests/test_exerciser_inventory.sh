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
# Since PLAN-031 Phase D it also asserts the REVERSE: every inventory row must
# name a repo-relative full path that is on disk (and not git-ignored), tracked
# in git, or declared as a consumer destination in manifest.json — a row citing
# nothing real is the phantom the forward walks cannot see.
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
  # Optional $1 overrides the inventory file (the §5 teeth point it at a
  # mutated copy); default is the real inventory.
  local f="${1:-$INV}"
  grep -E '^\| `' "$f" | sed -E 's/^\| `([^`]+)`.*/\1/' | sort -u
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
#    llm-smoke, audit-trail.yml) are NOT library surfaces — they are the
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
#    surface. Every canonical script now carries a real exerciser, so this holds
#    for all of them with no accepted-unexercised entries in that table.
#    Covers *.sh AND *.py plus one level of subdirectory (scripts/docs-sync):
#    the old install|scripts|sync/*.sh glob was blind to the .py files that run
#    on every consumer via docs-sync.yml (PLAN-031 G06).
# ---------------------------------------------------------------------------
echo ""
echo "== every canonical script is accounted for =="
missing_script=0
for f in "$ROOT"/install/*.sh "$ROOT"/install/*.py "$ROOT"/scripts/*.sh "$ROOT"/scripts/*.py "$ROOT"/scripts/docs-sync/*.py "$ROOT"/sync/*.sh "$ROOT"/sync/*.py; do
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
# One entry today, deliberately written as a roster: fragments are named here
# explicitly because the manifest/reusable/script walks structurally miss them,
# and the next one is added to this list.
# shellcheck disable=SC2043
for frag in install/templates/pre-commit-hook-block.yaml; do
  if in_inventory "$frag"; then _g "fragment listed: $frag"
  else _r "fragment MISSING from inventory: $frag"; fi
done

echo ""
echo "== every COMPOSITE ACTION is accounted for (D44) =="
# `actions/*/action.yml` is a surface CLASS this guard was structurally blind
# to: it derives its set from manifest `files[].path`, `workflow_call`
# reusables, and install|scripts|sync/*.sh — and a composite action is none of
# those. Measured: adding a seventh, entirely unaccounted-for action raised the
# suite's own count by 7 passing assertions and tripped nothing here.
#
# Discovered, not enumerated. A roster (as used for fragments above) would need
# hand-maintenance and is the F1 failure mode this file exists to prevent, and
# actions are added often enough for that to rot.
missing_actions=0
found_actions=0
while IFS= read -r a; do
  [ -n "$a" ] || continue
  found_actions=$((found_actions+1))
  if in_inventory "$a"; then _g "action listed: $a"
  else _r "composite action MISSING from inventory: $a"; missing_actions=1; fi
done < <(cd "$ROOT" && find actions -name action.yml 2>/dev/null | sort)
# Fail closed: `actions/` exists in this repo, so finding zero means the walk
# broke, not that there is nothing to check.
if [ -d "$ROOT/actions" ] && [ "$found_actions" -eq 0 ]; then
  _r "actions/ exists but the walk found no action.yml — the discovery broke"
fi
assert_eq "$missing_actions" "0" "all composite actions are in the inventory (D44)"

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
  # Owner = a closing FT, a plan reference WITH its phase (plans/ IS the
  # backlog per CI-0046, so a plan + phase names an owner — a bare PLAN-NN
  # mention in prose does not), or the explicit sentinel `accepted-no-FT`.
  # The bare word 'accepted' is NOT accepted (it substring-matches "not
  # accepted by anyone" and other prose); the sentinel is unambiguous.
  if printf '%s' "$line" | grep -qE 'FT-[0-9]+|PLAN-[0-9]+ Phase [A-Z]+|`accepted-no-FT`'; then
    _g "unexercised row is owned: $(printf '%s' "$line" | grep -oE '`[^`]+`' | head -1)"
  else
    _r "unexercised row names no FT and no accepted-no-FT sentinel: $line"; bad_rows=1
  fi
done < "$INV"
assert_eq "$bad_rows" "0" "no orphan unexercised rows"

# ---------------------------------------------------------------------------
# 5. Reverse guard: every inventory row names a path that is on disk (and not
#    git-ignored), TRACKED in git, or declared as a consumer destination `path`
#    in manifest.json. The forward walks (§1-§3b) ask "does every real file have
#    a row?" and can never see a row citing nothing real. Legitimate untracked
#    rows exist: consumer destination paths
#    (quick-gates/scanners/links-external) never live in canon, so manifest
#    membership exempts them (PLAN-031 G05); and a NEW script's row must pass in
#    the same uncommitted change that adds the file, so on-disk presence counts
#    (PLAN-031 §9 gate-bug note). Rows MUST be repo-relative full paths.
# ---------------------------------------------------------------------------
echo ""
echo "== every inventory row names a tracked file or a manifest destination =="
TRACKED_LIST="$(mktemp)"; git -C "$ROOT" ls-files > "$TRACKED_LIST"
MANIFEST_PATHS="$(mktemp)"
python3 -c "import json; print('\n'.join(f['path'] for f in json.load(open('$MANIFEST'))['files']))" > "$MANIFEST_PATHS"
TEETH_DIR="$(mktemp -d)"
trap 'rm -f "$TRACKED_LIST" "$MANIFEST_PATHS"; rm -rf "$TEETH_DIR"' EXIT
row_is_real() {  # $1 = surface, a repo-relative FULL path (never a bare basename:
  # §3 matches scripts by basename but §5 demands the full path, so a
  # basename-keyed row would pass §3 and fail here — rows MUST be full paths);
  # 0 iff on disk and not git-ignored, tracked in git, or a manifest destination
  # On-disk presence counts as much as tracked status, and the reason is a
  # chicken-and-egg: a NEW canon script MUST ship with its inventory row in the
  # SAME change (that coupling is the point of this walk), but `git ls-files`
  # cannot see the new file until that change is committed. Tracked-only would
  # therefore make the row phantom on the way in and real only afterwards —
  # unpassable inside the very commit that satisfies it. Measured, not
  # hypothetical: it reds on install/generate-required-contexts.py.
  # This still catches the defect the check exists for — a path that never
  # existed is neither on disk nor tracked nor manifested. The on-disk disjunct
  # excludes git-ignored files: otherwise a stray `touch` at a bogus path (or a
  # build artifact that happens to share the name) would silently neuter the
  # guard while the row stays untracked and unmanifested.
  { [ -f "$ROOT/$1" ] && ! git -C "$ROOT" check-ignore -q -- "$1"; } \
    || grep -qxF -- "$1" "$TRACKED_LIST" || grep -qxF -- "$1" "$MANIFEST_PATHS"
}
# Echo the surfaces in $1 (an inventory file) that are neither — the checker's
# core, shared by the live walk below and the teeth.
unreal_surfaces() {
  local f="$1" surf
  while IFS= read -r surf; do
    [ -n "$surf" ] || continue
    if row_is_real "$surf"; then :; else printf '%s\n' "$surf"; fi
  done < <(inv_surfaces "$f")
}
reverse_rows=0
reverse_bad=0
while IFS= read -r surf; do
  [ -n "$surf" ] || continue
  reverse_rows=$((reverse_rows+1))
  if row_is_real "$surf"; then _g "row is real: $surf"
  else _r "row is PHANTOM (neither tracked nor manifested): $surf"; reverse_bad=1; fi
done < <(inv_surfaces)
assert_eq "$reverse_bad" "0" "every inventory row names a tracked file or manifest destination"
# WITHOUT THIS THE SECTION CANNOT FAIL. An empty extraction (grep/sed drift,
# renamed file) yields zero rows, zero phantoms, and a green assertion over
# nothing — the vacuous-pass class test_required_contexts.sh:174 names.
assert_ok "[ '$reverse_rows' -gt 0 ]" "reverse walk inspected $reverse_rows inventory rows (non-vacuous)"

# ---------------------------------------------------------------------------
# 5b. TEETH for §5 — the reverse check must be REACHABLE, or §5 is a check
#     that can only ever pass. Mutate a COPY (never the real inventory): plant
#     a bogus path and require exactly one phantom; the unmutated copy must
#     stay clean, or the checker is hardcoded to red. Cf.
#     test_required_contexts.sh §6 (mutation + unrelated control + no-op
#     refusal).
# ---------------------------------------------------------------------------
echo ""
echo "== reverse-guard teeth: a planted phantom is caught, the clean copy passes =="
bogus='.github/workflows/bogus-phantom-teeth.yml'
# Preconditions: the teeth path must REALLY be neither on disk, tracked, nor
# manifested, or the red below discriminates nothing.
assert_fail "test -e '$ROOT/$bogus'" "teeth precondition: bogus path is not on disk"
assert_fail "grep -qxF -- '$bogus' '$TRACKED_LIST'" "teeth precondition: bogus path is not tracked"
assert_fail "grep -qxF -- '$bogus' '$MANIFEST_PATHS'" "teeth precondition: bogus path is not manifested"
cp "$INV" "$TEETH_DIR/inv-bogus.md"
printf '| `%s` | nothing exercises this | offline-test |\n' "$bogus" >> "$TEETH_DIR/inv-bogus.md"
assert_ok "grep -qF -- '$bogus' '$TEETH_DIR/inv-bogus.md'" "teeth precondition: the planted row is really in the mutated copy"
assert_eq "$(unreal_surfaces "$TEETH_DIR/inv-bogus.md")" "$bogus" "teeth: the planted bogus row — and only it — fails the reverse check"
cp "$INV" "$TEETH_DIR/inv-clean.md"
assert_eq "$(unreal_surfaces "$TEETH_DIR/inv-clean.md")" "" "control: the unmutated copy passes the reverse check"

# ---------------------------------------------------------------------------
# 6. The stated reusable count is DERIVED, not hardcoded. The inventory names
#    its count once, in the `## Reusable workflows (N)` header; this asserts it
#    equals the live workflow_call file count using the SAME predicate as §2,
#    so the two cannot drift apart (PLAN-031 G05: the "16" that was really 15).
# ---------------------------------------------------------------------------
echo ""
echo "== the inventory's stated reusable count matches the live tree =="
live_reusables=0
for f in "$WF"/*.yml; do
  grep -qE '^\s+workflow_call:' "$f" || continue
  live_reusables=$((live_reusables+1))
done
stated_reusables="$(sed -n -e 's/^## Reusable workflows (\([0-9][0-9]*\))$/\1/p' "$INV")"
assert_ok "[ -n '$stated_reusables' ]" "the inventory states its reusable count in the section header (machine-readable)"
assert_eq "$stated_reusables" "$live_reusables" "stated reusable count matches the live workflow_call file count"

suite_summary "exerciser-inventory"
