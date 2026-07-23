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
echo "== tag refuses without the FT-30 dry-run gate =="
# A plausible next version (not yet tagged). tag must refuse for lack of the
# --dry-run-verified flag BEFORE touching git.
run tag ci/v99.0.0
assert_eq "$RC" "1" "tag: refused without --dry-run-verified"
assert_contains "$OUT" "dry-run-verified" "tag: names the missing gate"
assert_absent "$OUT" "tagging" "tag: did not proceed to tagging"

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
