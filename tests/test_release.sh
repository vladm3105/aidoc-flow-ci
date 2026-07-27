#!/usr/bin/env bash
# tests/test_release.sh — guard cover for scripts/release.sh (PLAN-018 FT-21).
#
# WHY THIS EXISTS: release.sh encodes the prep→merge→dry-run→tag ordering the
# v2.9.0 cut got wrong. Its GUARDS are the value — they refuse the exact mistakes
# that cut made (tag before prep-merge; tag without the 🔴 dry-run; a version the
# tree does not carry). This drives every guard's REJECTION path — all of which
# exit before mutating anything, so the test has no side effects (it never runs a
# real prep/tag).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(cd "$HERE/.." && pwd)"
REL="$ROOT/scripts/release.sh"

assert_ok "[ -x '$REL' ]" "release.sh is executable"

# helper: run release.sh, capture combined output + rc
run() { OUT="$(bash "$REL" "$@" 2>&1)"; RC=$?; }

echo "== usage / version-format guards =="
run;                         assert_eq "$RC" "1" "no subcommand -> non-zero"
assert_contains "$OUT" "usage" "no subcommand -> usage"
run prep v2.12;              assert_eq "$RC" "1" "prep: bad version format rejected"
assert_contains "$OUT" "ci/vX.Y.Z" "prep: names the required format"
run tag not-a-version --dry-run-verified; assert_eq "$RC" "1" "tag: bad version format rejected"
# The dry-run flag is OPTIONAL since the gate became conditional; every usage
# string must say so. `tag` with no args must reach usage, not die on `set -u`.
run
assert_contains "$OUT" "[--dry-run-verified]" "usage: dispatcher shows the flag as optional"
run tag
assert_eq "$RC" "1" "tag: no version -> usage (not an unbound-variable crash)"
assert_contains "$OUT" "usage" "tag: no version -> reaches the usage message"
assert_absent "$OUT" "unbound variable" "tag: no version -> no set -u crash"

echo ""
echo "== prep refuses the version the tree already carries =="
# prep of the CURRENT VERSION must always be rejected — but via one of TWO
# guards depending on release state: normally the tag exists ('already exists');
# but when the suite runs DURING a `prep` (VERSION already bumped, tag not cut
# yet — exactly how release.sh runs it), the 'VERSION already reads' guard fires
# instead. Both are valid rejections, so accept either. (This assertion was too
# specific and release.sh's own prep-suite run caught it — FT-21 self-exercising.)
cur="$(tr -d '[:space:]' < "$ROOT/VERSION")"
# Snapshot the branch set BEFORE — a rejected prep must not add or remove any
# branch. Compare before/after rather than asserting the prep branch is absent:
# when this test runs DURING a real `release.sh prep` (the suite prep runs), that
# prep branch legitimately already exists, and an absence check would false-fail.
# (release.sh's own prep-suite run caught exactly that — FT-21 self-exercising.)
_branches_before="$(git -C "$ROOT" branch --format='%(refname)' | sort)"
run prep "$cur"
assert_eq "$RC" "1" "prep: current version rejected"
if printf '%s' "$OUT" | grep -qE 'already exists|already reads'; then
  _g "prep: names the reason (tag-exists or VERSION-already-set)"
else
  _r "prep: names the reason (got: $OUT)"
fi
_branches_after="$(git -C "$ROOT" branch --format='%(refname)' | sort)"
assert_eq "$_branches_before" "$_branches_after" "prep: rejection changed no branches (no side effect)"

echo ""
echo "== FT-30 dry-run gate is CONDITIONAL on the cold-start surface =="
# The gate demands --dry-run-verified only when the release actually changes the
# installer cold-start path. On THIS repo the surface is usually unchanged, so the
# gate waives and the run proceeds to the later guards. Asserting only
# "output mentions dry-run-verified" would false-pass on the waive message, so
# assert the DECISION, and that it got past the gate to a different guard.
run tag ci/v99.0.0
assert_eq "$RC" "1" "tag: still rejected (a later guard), gate is not the blocker here"
assert_absent "$OUT" "tagging" "tag: did not proceed to tagging"
# Which LATER guard fires depends on the environment — CI checks out a PR ref, so
# the on-main guard trips before the VERSION one; locally on main it is the
# reverse. Assert only that the gate reached a decision and did not itself abort
# the run. The gate fixture below pins the decision logic deterministically.
_gate_waived=0
printf '%s' "$OUT" | grep -q 'AUTO-WAIVED' && _gate_waived=1
if [ "$_gate_waived" = 1 ]; then
  assert_absent "$OUT" "refusing to tag without --dry-run-verified" "tag: gate waived (surface unchanged) -> did not die at the gate"
else
  assert_contains "$OUT" "CHANGES the installer cold-start path" "tag: gate fired (surface changed) -> named the reason"
fi

echo ""
echo "== gate fixture: waive / require / fail-closed all drive for real =="
# A dedicated throwaway repo so BOTH gate branches are exercised deterministically,
# independent of what this repo's working tree happens to contain.
GFIX="$(mktemp -d)"
git init -q -b main "$GFIX" 2>/dev/null
git init -q --bare "$GFIX/origin.git" 2>/dev/null
mkdir -p "$GFIX/scripts" "$GFIX/install/templates"
cp "$REL" "$GFIX/scripts/release.sh"
printf 'ci/v1.0.0\n' > "$GFIX/VERSION"
printf 'CI_TAG_FALLBACK="ci/v1.0.0"\n' > "$GFIX/install/install.sh"
printf '{"files":[{"path":".github/workflows/x.yml","template":"workflows/x.yml"},{"path":".github/workflows/y.yml","template":"workflows/y-public.yml","visibility_variants":{"private":"workflows/y-private.yml","public":"workflows/y-public.yml"}}]}\n' > "$GFIX/install/templates/manifest.json"
mkdir -p "$GFIX/install/templates/workflows"
printf 'x\n' > "$GFIX/install/templates/workflows/x.yml"
printf 'yp\n' > "$GFIX/install/templates/workflows/y-public.yml"
printf 'yq\n' > "$GFIX/install/templates/workflows/y-private.yml"
printf 'frag\n' > "$GFIX/install/templates/pre-commit-hook-block.yaml"
printf '## Unreleased\n\n## ci/v2.0.0 — 2026-01-01\n\n- x\n' > "$GFIX/CHANGELOG.md"
# tag() runs `git fetch origin main` + an up-to-date check before the VERSION
# guard, so the gate tests that must reach the LATER guards need a real origin.
printf 'origin.git/\n' > "$GFIX/.gitignore"
_gc() { git -C "$GFIX" -c user.email=t@t -c user.name=t -c commit.gpgsign=false "$@"; }
git -C "$GFIX" add -A; _gc commit -q -m init
git -C "$GFIX" remote add origin "$GFIX/origin.git"
git -C "$GFIX" push -q origin main 2>/dev/null
_gc tag ci/v1.0.0
# keep origin/main level with local main after each fixture commit below
_gpush() { git -C "$GFIX" push -q origin main 2>/dev/null; }

# Each case needs its OWN diff window, otherwise an earlier case's change stays
# "changed" forever and every later case fires for the wrong reason. So: tag the
# current HEAD, make one change, and let `prev` be that fresh tag.
_next=1
_seal() { _next=$((_next+1)); _gc tag "ci/v1.$_next.0"; }        # prev := HEAD
_gtag() { (cd "$GFIX" && bash scripts/release.sh tag ci/v9.0.0 "$@" 2>&1); }

# (a) NO ci/v* tag reachable => fails CLOSED even though nothing changed.
_gc tag -d ci/v1.0.0 >/dev/null
nout="$(_gtag)"; nrc=$?
assert_eq "$nrc" "1" "gate: no previous tag -> refused"
assert_contains "$nout" "no previous ci/v* tag" "gate: fails closed with no previous tag"
_gc tag ci/v1.0.0

# (b) Surface UNCHANGED => auto-waive, and the run reaches the VERSION guard
#     (proving it got PAST the gate rather than dying in it).
printf 'docs only\n' > "$GFIX/install/README.md"; git -C "$GFIX" add -A; _gc commit -q -m docs; _gpush
wout="$(_gtag)"; wrc=$?
assert_contains "$wout" "AUTO-WAIVED" "gate: unchanged cold-start surface -> auto-waived"
assert_contains "$wout" "VERSION on main reads" "gate: waive proceeds to the next guard"
assert_eq "$wrc" "1" "gate: waive still ends in the later rejection"

# Drive each surface HALF independently. Without these, deleting the whole
# explicit list — or dropping install.sh from it — leaves the suite green.
_case() { # $1=path  $2=label
  _seal
  printf 'changed-%s\n' "$_next" > "$GFIX/$1"; git -C "$GFIX" add -A
  _gc commit -q -m "chg $1"; _gpush
  local o; o="$(_gtag)"
  assert_contains "$o" "CHANGES the installer cold-start path" "gate: fires on $2"
  assert_contains "$o" "$1" "gate: names $2 as the changed file"
  assert_absent "$o" "AUTO-WAIVED" "gate: did NOT waive on $2"
}
# (c) manifest-derived template
_case "install/templates/workflows/x.yml" "a manifest template"
# (c2) EXPLICIT half — install.sh itself, the single most important file
_case "install/install.sh" "install.sh (explicit half)"
# (c3) EXPLICIT half — a file the manifest never names
_case "install/templates/pre-commit-hook-block.yaml" "the pre-commit fragment (explicit half)"
# (c4) visibility_variants-only template — install.sh cold-start fetches these
#      directly and they appear ONLY under visibility_variants (the B1 blind spot)
_case "install/templates/workflows/y-private.yml" "a visibility_variants-only template"

# (d) the flag overrides a changed surface.
fout2="$(_gtag --dry-run-verified)"
assert_contains "$fout2" "dry-run-verified supplied" "gate: --dry-run-verified is acknowledged"
assert_contains "$fout2" "VERSION on main reads" "gate: --dry-run-verified overrides a changed surface"

# (e) unreadable manifest => fails CLOSED (must NOT silently shrink the surface).
_seal
printf 'NOT JSON\n' > "$GFIX/install/templates/manifest.json"; git -C "$GFIX" add -A; _gc commit -q -m break; _gpush
bout="$(_gtag)"; brc=$?
assert_eq "$brc" "1" "gate: unreadable manifest -> refused"
assert_contains "$bout" "could not compute the cold-start surface" "gate: fails closed on a broken manifest"

# (f) VALID json whose shape yields no templates => also fails CLOSED. A plain
#     `.get("files", [])` walk would return empty, rc=0, and silently waive.
_seal
printf '{"entries":[{"template":"workflows/x.yml"}]}\n' > "$GFIX/install/templates/manifest.json"
git -C "$GFIX" add -A; _gc commit -q -m schema; _gpush
sout="$(_gtag)"; src=$?
assert_eq "$src" "1" "gate: manifest schema drift -> refused"
assert_contains "$sout" "could not compute the cold-start surface" "gate: fails closed when the manifest yields no templates"

# (g) previous_tag must ignore non-release tags. `sort -V` ranks ci/vX.Y.Z-rc.N
#     ABOVE ci/vX.Y.Z, so an unfiltered glob would pick a pre-release as `prev`
#     and mis-scope the diff window.
_seal
printf '{"files":[{"path":".github/workflows/x.yml","template":"workflows/x.yml"}]}\n' > "$GFIX/install/templates/manifest.json"
git -C "$GFIX" add -A; _gc commit -q -m restore; _gpush
_seal                                   # prev := this commit (the real release)
printf 'changed\n' > "$GFIX/install/templates/workflows/x.yml"; git -C "$GFIX" add -A
_gc commit -q -m "chg after rc tag"; _gpush
# The pre-release tag must land AFTER the change, so that picking it as `prev`
# would collapse the window to empty. Tagging it alongside the seal would make
# both the filtered and unfiltered forms agree, and the test would not discriminate.
_gc tag "ci/v8.8.8-rc.1"                # a pre-release ABOVE every real tag, at HEAD
rout="$(_gtag)"
# If the rc tag were chosen as prev it would sit AFTER this change, the diff
# window would be empty, and the gate would waive. It must still fire.
assert_contains "$rout" "CHANGES the installer cold-start path" "previous_tag: a -rc.N tag is not treated as the previous release"
assert_absent "$rout" "AUTO-WAIVED" "previous_tag: pre-release tag did not collapse the diff window"

# (h) a template path with whitespace would be silently dropped by the caller's
#     word-splitting, under-reporting the surface. Refuse instead.
_seal
printf '{"files":[{"path":".github/workflows/z.yml","template":"workflows/has space.yml"}]}\n' > "$GFIX/install/templates/manifest.json"
git -C "$GFIX" add -A; _gc commit -q -m spacepath; _gpush
pout2="$(_gtag)"; prc2=$?
assert_eq "$prc2" "1" "gate: whitespace in a template path -> refused"
assert_contains "$pout2" "could not compute the cold-start surface" "gate: fails closed on an unsplittable template path"

# --- pin-bump normalisation -------------------------------------------------
# Every prep commit rewrites the @ci/vX.Y.Z self-pin inside every shipped
# template. Without normalisation the gate fires on EVERY release and the flag is
# a rubber stamp again — the exact defect this whole change removes.
_seal
printf '{"files":[{"path":".github/workflows/x.yml","template":"workflows/x.yml"}]}\n' > "$GFIX/install/templates/manifest.json"
printf 'uses: vladm3105/aidoc-flow-ci/.github/workflows/x.yml@ci/v1.0.0\nbody: original\n' > "$GFIX/install/templates/workflows/x.yml"
git -C "$GFIX" add -A; _gc commit -q -m base; _gpush
_seal                                    # prev := this commit

# (i) ONLY the pin changed => not material => waive.
printf 'uses: vladm3105/aidoc-flow-ci/.github/workflows/x.yml@ci/v7.7.7\nbody: original\n' > "$GFIX/install/templates/workflows/x.yml"
git -C "$GFIX" add -A; _gc commit -q -m pinbump; _gpush
pb="$(_gtag)"
assert_contains "$pb" "AUTO-WAIVED" "gate: a pure @ci/vX.Y.Z pin bump is NOT a material change"
assert_absent "$pb" "CHANGES the installer cold-start path" "gate: pin bump alone does not fire the gate"

# (j) pin bump PLUS a real content change => material => fire.
_seal
printf 'uses: vladm3105/aidoc-flow-ci/.github/workflows/x.yml@ci/v8.8.8\nbody: EDITED\n' > "$GFIX/install/templates/workflows/x.yml"
git -C "$GFIX" add -A; _gc commit -q -m realchange; _gpush
rc2="$(_gtag)"
assert_contains "$rc2" "CHANGES the installer cold-start path" "gate: a real edit alongside a pin bump still fires"
assert_contains "$rc2" "install/templates/workflows/x.yml" "gate: names the materially-changed template"

# (k) F1 ITSELF: a shipped template DELETED. Must fire — this is the failure the
#     whole gate exists to catch (one shipped broken for nine releases).
_seal
git -C "$GFIX" rm -q "install/templates/workflows/x.yml"
_gc commit -q -m "delete a shipped template"; _gpush
del="$(_gtag)"
assert_contains "$del" "CHANGES the installer cold-start path" "gate: a DELETED shipped template fires (the F1 case)"
assert_contains "$del" "install/templates/workflows/x.yml" "gate: names the deleted template"
assert_absent "$del" "AUTO-WAIVED" "gate: deletion is never waived"
rm -rf "$GFIX"

echo ""
echo "== runtime teeth: the on-main + VERSION-match guards actually fire (fixture) =="
# The rejection tests above never get past the --dry-run-verified gate, so the
# on-main and (core) VERSION-match guards were only source-grep-covered — weak for
# the one guard this whole tool exists to enforce. This drives them for real in a
# throwaway repo: a refactor that keeps the guard string but breaks its logic
# (inverted comparison, wrong var) fails HERE.
FIX="$(mktemp -d)"
git init -q -b main "$FIX" 2>/dev/null
git init -q --bare "$FIX/origin.git" 2>/dev/null
mkdir -p "$FIX/scripts" "$FIX/install"
cp "$REL" "$FIX/scripts/release.sh"
printf 'ci/v1.0.0\n' > "$FIX/VERSION"
printf 'CI_TAG_FALLBACK="ci/v1.0.0"\n' > "$FIX/install/install.sh"
printf '## Unreleased\n\n## ci/v2.0.0 — 2026-01-01\n\n- x\n' > "$FIX/CHANGELOG.md"
# The bare origin repo lives inside the work tree; ignore it so prep's tree-clean
# guard (FT-48) sees a clean tree (tag() doesn't check tree-clean, so the tag
# fixture tests never needed this).
printf 'origin.git/\n' > "$FIX/.gitignore"
git -C "$FIX" add -A
git -C "$FIX" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q -m init
git -C "$FIX" remote add origin "$FIX/origin.git"
git -C "$FIX" push -q origin main 2>/dev/null

# On main, up to date, tag ci/v2.0.0 absent, VERSION=ci/v1.0.0 => the VERSION-match
# guard must fire (reaching it proves on-main + up-to-date + tag-exists all passed).
vout="$(cd "$FIX" && bash scripts/release.sh tag ci/v2.0.0 --dry-run-verified 2>&1)"; vrc=$?
assert_eq "$vrc" "1" "fixture: tag with VERSION(1.0.0) != version(2.0.0) rejected"
assert_contains "$vout" "VERSION on main reads" "fixture: VERSION-match guard fired at runtime"
assert_absent "$vout" "tagging" "fixture: VERSION mismatch did not proceed to tag"
# no tag was created in the fixture (no mutation on a rejected tag)
assert_fail "git -C '$FIX' rev-parse --verify -q refs/tags/ci/v2.0.0" "fixture: no tag created on rejection"

# Off main => the on-main guard must fire first.
git -C "$FIX" checkout -q -b feature
fout="$(cd "$FIX" && bash scripts/release.sh tag ci/v2.0.0 --dry-run-verified 2>&1)"; frc=$?
assert_eq "$frc" "1" "fixture: tag off-main rejected"
assert_contains "$fout" "must be on main" "fixture: on-main guard fired at runtime"

# FT-48: prep gains the SAME on-main + up-to-date guards tag has. Fixture is on
# `feature` here — prep of a NEW version (tag absent, VERSION differs, tree clean,
# branch absent) must reach and fire the on-main guard, mutating nothing.
pout="$(cd "$FIX" && bash scripts/release.sh prep ci/v3.0.0 2>&1)"; prc=$?
assert_eq "$prc" "1" "fixture: prep off-main rejected (FT-48)"
assert_contains "$pout" "must be on main" "fixture: prep on-main guard fired at runtime"
assert_fail "git -C '$FIX' rev-parse --verify -q refs/heads/release/ci-v3.0.0-prep" "fixture: prep off-main created no branch (no mutation)"

# On main but local ahead of origin/main => the up-to-date guard must fire.
git -C "$FIX" checkout -q main
git -C "$FIX" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m local-ahead
uout="$(cd "$FIX" && bash scripts/release.sh prep ci/v3.0.0 2>&1)"; urc=$?
assert_eq "$urc" "1" "fixture: prep with local main ahead of origin rejected (FT-48)"
assert_contains "$uout" "not up to date" "fixture: prep up-to-date guard fired at runtime"
assert_fail "git -C '$FIX' rev-parse --verify -q refs/heads/release/ci-v3.0.0-prep" "fixture: prep not-up-to-date created no branch (no mutation)"
rm -rf "$FIX"

echo ""
echo "== the guards exist in the source (not just at runtime) =="
# Cheap belt-and-suspenders: the load-bearing guard strings are present, so a
# refactor that drops one is visible here even if a runtime path is missed.
assert_ok "grep -q 'dry-run-verified' '$REL'" "source carries the dry-run gate"
assert_ok "grep -q 'not.*merged yet\\|is not merged\\|VERSION on main reads' '$REL'" \
  "source carries the VERSION-must-match-tree guard"
assert_ok "grep -q \"must be on main\" '$REL'" "source carries the on-main guard"

suite_summary "release"
