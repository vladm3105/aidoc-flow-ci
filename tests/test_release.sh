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
echo "== prep refuses a version LOWER than VERSION (monotonicity) =="
# The two guards above reject a version that already EXISTS as a tag or that
# VERSION already carries. NEITHER rejects a LOWER one — and a prep rewrites
# CI_TAG_FALLBACK plus every shipped `@ci/vX.Y.Z` pin, then `tag` publishes the
# result `--latest`. So `prep ci/v2.17.0` on a v3 tree re-pinned the whole fleet
# BACKWARDS onto a version below the current release, and nothing downstream
# could catch it: `tag`'s FT-21 VERSION-match guard is SATISFIED by the rewrite.
# That is the ci/v2.0.1 incident sync-version-refs.sh was written to end,
# re-created by the tool that replaced the manual process.
#
# Derive the lower version from VERSION rather than hardcoding one, so this stays
# true after any future cut. Assert the REFUSAL and its stated reason, then that
# the same shape one MINOR ABOVE is not caught by this guard — a monotonicity
# check that rejects everything is indistinguishable from a broken prep.
# MINOR 99, not the current minor: the tag-exists guard runs BEFORE this one, so
# a lower version that HAPPENS to be a real released tag (ci/v2.0.0 is) is caught
# by that guard instead and this case silently certifies nothing. Pick a version
# that is unambiguously lower AND has never been cut.
_lower="$(printf '%s' "$cur" | awk -F. '{ mj=$1; sub(/^ci\/v/,"",mj); print "ci/v" (mj>0?mj-1:0) ".99.0" }')"
if git -C "$ROOT" rev-parse --verify -q "refs/tags/$_lower" >/dev/null 2>&1; then
  _r "monotonicity: $_lower unexpectedly exists as a tag — the case would test the wrong guard"
  _lower="$cur"
fi
if [ "$_lower" = "$cur" ]; then
  _r "monotonicity: could not derive a lower version from $cur — the case did not run"
else
  _branches_before="$(git -C "$ROOT" branch --format='%(refname)' | sort)"
  run prep "$_lower"
  assert_eq "$RC" "1" "prep: a version BELOW VERSION ($_lower < $cur) is rejected"
  assert_contains "$OUT" "LOWER than the current VERSION" \
    "prep: ...refused by the MONOTONICITY guard specifically, naming the direction"
  # The refusal must say what it protects, or an operator reads it as a typo
  # check and re-runs with --force-shaped reasoning.
  assert_contains "$OUT" "BACKWARDS" "prep: ...and states the consequence (a backwards fleet re-pin)"
  _branches_after="$(git -C "$ROOT" branch --format='%(refname)' | sort)"
  assert_eq "$_branches_before" "$_branches_after" "prep: the monotonicity rejection changed no branches"

  # NEGATIVE CONTROL — and it must NOT be a live prep.
  #
  # A HIGHER version clears EVERY guard in `prep`: the tag does not exist, VERSION
  # differs, monotonicity passes by construction, the tree is clean, no prep branch
  # exists, and on `main` the on-main and up-to-date guards both pass. `prep` has no
  # terminal guard for that input — unlike `tag`, whose VERSION-match check always
  # refuses. So a bare `run prep "$_higher"` RUNS A REAL PREP: it creates the prep
  # branch, rewrites VERSION, retires the forward-pin markers across every shipped
  # template, runs sync-version-refs over ~37 pins, promotes the CHANGELOG, and
  # recursively invokes `bash tests/run.sh`.
  #
  # That would not show up here or on a PR — `actions/checkout` leaves a detached
  # HEAD on `pull_request`, so the on-main guard refuses. It fires on the
  # `push: main` run AFTER merge (checkout does `-B main`), and for any maintainer
  # running the suite from a clean, up-to-date `main`. It also breaks this file's
  # stated invariant at the top: "all of which exit before mutating anything ...
  # it never runs a real prep/tag".
  #
  # Make a LATER guard terminal instead. Pre-creating the prep branch trips the
  # branch-exists guard, which sits AFTER the monotonicity check and BEFORE any
  # mutation — so the run still proves monotonicity did not fire, and cannot
  # proceed. Assert the later guard POSITIVELY: without that, this case would also
  # "pass" if prep died earlier for some unrelated reason, certifying nothing.
  _higher="$(printf '%s' "$cur" | awk -F. '{ mj=$1; sub(/^ci\/v/,"",mj); print "ci/v" mj+1 ".0.0" }')"
  _hbranch="release/${_higher//\//-}-prep"
  if git -C "$ROOT" rev-parse --verify -q "$_hbranch" >/dev/null 2>&1; then
    _r "monotonicity control: $_hbranch already exists — refusing to drive a live prep"
    # And actually refuse. Without this the block below ran anyway, so the message
    # said "refusing" while driving, and the cleanup `git branch -D` deleted a
    # branch this test did NOT create — a repo mutation in the one file whose
    # header invariant is that it never mutates anything.
    _hbranch=""
  else
    # CHECK THAT IT WAS ACTUALLY CREATED. The whole safety of this control is
    # that the branch-exists guard stops `prep` before it mutates anything. If
    # `git branch` silently fails, every guard passes and a REAL prep runs —
    # the exact hazard this control exists to remove, reachable through a
    # discarded exit status.
    if ! git -C "$ROOT" branch "$_hbranch" >/dev/null 2>&1 \
       || ! git -C "$ROOT" rev-parse --verify -q "$_hbranch" >/dev/null 2>&1; then
      _r "monotonicity control: could not pre-create $_hbranch — refusing to drive a live prep"
      _hbranch=""
    fi
  fi
  if [ -n "${_hbranch:-}" ]; then
    # Cleanup is registered IMMEDIATELY, not left to the end of the block. The
    # `branch -D` below is the normal path; this trap is what keeps a stray
    # `release/ci-vN.0.0-prep` out of a developer's repo if anything between here
    # and there exits early. `_r`/`assert_*` do not exit, but a `set -e` abort in
    # a future edit would, and leaving a prep-shaped branch behind is exactly the
    # state that makes the NEXT run of this case skip itself.
    trap 'git -C "$ROOT" branch -D "$_hbranch" >/dev/null 2>&1 || true' EXIT
    _branches_before="$(git -C "$ROOT" branch --format='%(refname)' | sort)"
    _branch_before="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
    run prep "$_higher"
    assert_eq "$RC" "1" "prep: the HIGHER-version control still refuses (via a LATER guard)"
    assert_absent "$OUT" "LOWER than the current VERSION" \
      "prep: a HIGHER version ($_higher) is NOT caught by the monotonicity guard"
    # TWO guards sit between monotonicity and the first mutation, and which one
    # fires depends on the tree the suite runs against: `working tree not clean`
    # (release.sh:244) when a developer runs it mid-change, `branch ... already
    # exists` (:246) on the clean CI tree this case pre-creates the branch for.
    # Both are terminal and both are AFTER monotonicity, so accept either — but
    # name them, so a refusal from some THIRD reason still reds. Asserting only
    # one made this case fail locally while passing in CI, which is the shape that
    # gets an assertion loosened to `assert_ok true` on the next pass.
    if printf '%s' "$OUT" | grep -qE 'already exists|working tree not clean'; then
      _g "prep: ...it got PAST monotonicity and was stopped by a later pre-mutation guard"
    else
      _r "prep: ...refused for an UNEXPECTED reason — this case no longer proves monotonicity was passed (got: $OUT)"
    fi
    _branches_after="$(git -C "$ROOT" branch --format='%(refname)' | sort)"
    assert_eq "$_branches_before" "$_branches_after" \
      "prep: the HIGHER-version control created NO branch (it must never run a live prep)"
    git -C "$ROOT" branch -D "$_hbranch" >/dev/null 2>&1
    trap - EXIT
    # And the tree it was driven against is untouched — the assertions whose
    # absence let the live-prep hazard through in the first place. Capture the
    # branch BEFORE the run: comparing two reads taken after it is a tautology
    # that passes no matter what the run did (it was written that way first).
    assert_eq "$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)" "$_branch_before" \
      "prep: still on the same branch after the control (a live prep would have checked out the prep branch)"
    # ASSERT THE CONTENT, NOT THE DIFF. `git diff --quiet -- VERSION` is FALSE
    # during a real `release.sh prep`: prep writes VERSION at :262 and runs this
    # suite at :355, before any commit. So this assertion would have failed on
    # every cut, its FAIL text does not contain "latest published tag", and
    # `classify_suite` would therefore have called the prep suite an UNEXPECTED
    # red and `die`d — aborting the v4.0.0 cut after the branch, VERSION, the
    # forward-pin retirement and the CHANGELOG promotion had all been written.
    # That is the FT-21 self-exercising trap this file warns about twice in its
    # own comments, re-created by the fold that was making this control safe.
    #
    # `$cur` was read from VERSION at the top of this block, so during a prep it
    # already equals the rewritten value; a live prep inside this control would
    # have rewritten it again, to $_higher. Content is prep-invariant, the diff
    # is not.
    assert_eq "$(tr -d '[:space:]' < "$ROOT/VERSION")" "$cur" \
      "prep: VERSION was NOT rewritten by the control"
  fi
fi

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

echo ""
echo "== prep retires forward-pin markers the cut makes current (FT-21) =="
# Every v3 caller instructs "REMOVE THEM AT THE v3.0.0 TAG CUT" and nothing did.
# Left behind, `sync-version-refs` never descends into the span again and those
# pins freeze at v3.0.0 through every later release — invisibly, because
# `--check` skips exactly what it is told to skip.
#
# Extract the SHIPPED block and drive it, rather than grepping for its presence:
# the ordering and the version comparison are the parts that can be wrong, and
# neither is visible in a `grep -q`.
MK="$(mktemp -d)"
sed -n '/^  unmarked="\$(python3 - "\$version" <<.PY_MK.$/,/^PY_MK$/p' "$REL" | sed '1d;$d' > "$MK/mk.py"
assert_ok "[ -s '$MK/mk.py' ]" "the marker-retirement block was located in release.sh"

# SYNTHESIZED, NOT COPIED FROM THE LIVE TREE. Copying `install/templates/
# workflows/*.yml` made this block self-defeating: `prep` retires every marker at
# the v3.0.0 cut, so on the release PR that performs the cut the fixture carries
# zero markers, the `before >= 1` precondition fails, and the test reds on the
# one commit it exists to protect. Hardcoding `@ci/v3.0.0` in the survivor
# assertion broke it a second time, at v3.1.0. A fixture built here is
# independent of what the tree currently holds — and it lets the MIXED-pin
# branch be covered, which live templates cannot exercise because they are
# uniform.
mkdir -p "$MK/w/install/templates/workflows"
_mk_caller() {  # $1=file  $2=pin
  cat > "$MK/w/install/templates/workflows/$1" <<MKTPL
name: ${1%.yml}
jobs:
  j:
    runs-on: ubuntu-latest
    steps:
      # sync-version-refs:ignore-start
      # ^ FORWARD REFERENCE, not a stale pin. REMOVE THEM AT THE TAG CUT.
      # (FT-21 chicken-and-egg shape.)
      # An unrelated comment that must SURVIVE the retirement.
      - uses: vladm3105/aidoc-flow-ci/actions/pre-commit@$2
      # sync-version-refs:ignore-end
MKTPL
}
_mk_caller current.yml ci/v3.0.0
_mk_caller ahead.yml   ci/v9.9.9
# Mixed pins in ONE file: the span must survive, because retiring it would
# expose a reference that is still forward.
cat > "$MK/w/install/templates/workflows/mixed.yml" <<'MKMIX'
name: mixed
jobs:
  j:
    runs-on: ubuntu-latest
    steps:
      # sync-version-refs:ignore-start
      - uses: vladm3105/aidoc-flow-ci/actions/pre-commit@ci/v3.0.0
      - uses: vladm3105/aidoc-flow-ci/actions/links@ci/v9.9.9
      # sync-version-refs:ignore-end
MKMIX

_marked() { grep -rl 'sync-version-refs:ignore-start' "$MK/w/install/templates/workflows/" 2>/dev/null | wc -l; }
assert_eq "$(_marked)" "3" "fixture carries three marker-guarded callers (current, ahead, mixed)"

# A cut BELOW every pin must leave all spans alone — all still forward.
( cd "$MK/w" && python3 "$MK/mk.py" ci/v2.17.0 >/dev/null )
assert_eq "$(_marked)" "3" "a cut below the pins leaves every marker in place"

# A cut AT one pin retires only the file whose pins have ALL become current.
( cd "$MK/w" && python3 "$MK/mk.py" ci/v3.0.0 >/dev/null )
assert_eq "$(_marked)" "2" "a cut at a pinned tag retires only the file that became current"
assert_absent "$(cat "$MK/w/install/templates/workflows/current.yml")" "ignore-start" \
  "...the matching caller lost its markers"
assert_contains "$(cat "$MK/w/install/templates/workflows/ahead.yml")" "ignore-start" \
  "...a caller still ahead of the cut keeps its markers"
assert_contains "$(cat "$MK/w/install/templates/workflows/mixed.yml")" "ignore-start" \
  "...and a MIXED-pin caller keeps them, or a still-forward pin would be exposed"
assert_ok "grep -q 'actions/pre-commit@ci/v3.0.0' '$MK/w/install/templates/workflows/current.yml'" \
  "...and removes ONLY the markers — the pin itself survives"
# THE NOTE GOES WITH THE MARKERS. Its first line is a caret pointing at the
# marker line just deleted, and its last instruction is "REMOVE THEM AT THE TAG
# CUT" — an instruction that outlives its own execution and ships verbatim to
# every consumer via install.sh.
_cur="$(cat "$MK/w/install/templates/workflows/current.yml")"
assert_absent "$_cur" "FORWARD REFERENCE" "...the explanatory note is retired with them"
assert_absent "$_cur" "REMOVE THEM AT THE" "...including the instruction that has now been carried out"
assert_contains "$_cur" "An unrelated comment that must SURVIVE" \
  "...but an unrelated comment below the note is preserved"
assert_contains "$(cat "$MK/w/install/templates/workflows/ahead.yml")" "FORWARD REFERENCE" \
  "...and a still-forward caller keeps its note"
assert_ok "python3 -c \"import yaml,glob,sys; [yaml.safe_load(open(f)) for f in glob.glob('$MK/w/install/templates/workflows/*.yml')]\"" \
  "...and every caller still parses as YAML afterwards"
# Idempotent: re-running the same cut must not corrupt an already-retired file.
( cd "$MK/w" && python3 "$MK/mk.py" ci/v3.0.0 >/dev/null )
assert_eq "$(_marked)" "2" "re-running the same cut is a no-op"
rm -rf "$MK"

# ORDER IS LOAD-BEARING: retire the markers, THEN rewrite pins. Reversed, the
# rewriter skips the spans on the very cut that was supposed to free them.
# Anchored on the INVOCATION (`bash "$HERE/sync-version-refs.sh"`), not on any
# mention: the header comments name the script ~150 lines earlier, so a bare
# `grep -n 'sync-version-refs.sh' | head -1` compares against prose and reports
# the order backwards.
mk_line="$(grep -n 'PY_MK' "$REL" | head -1 | cut -d: -f1)"
sv_line="$(grep -n 'bash "\$HERE/sync-version-refs.sh"' "$REL" | head -1 | cut -d: -f1)"
assert_ok "[ -n '$mk_line' ] && [ -n '$sv_line' ]" "both prep steps located by line number"
assert_ok "[ '${mk_line:-0}' -lt '${sv_line:-0}' ]" \
  "marker retirement (line ${mk_line:-?}) runs BEFORE sync-version-refs (line ${sv_line:-?})"

echo ""
echo "== prep's red-suite classifier (the logic that says 'merge this RED PR') =="
# THE ONLY GUARD WHOSE OUTPUT IS AN INSTRUCTION TO OVERRIDE A RED GATE, and it
# had no cover: it lived inline in `prep()`, reachable only by running a real
# prep. Every OTHER guard in release.sh is driven above. It is now
# `classify_suite`, exposed through the internal `_classify-suite` subcommand.
#
# It depends on THREE format strings owned by other files — `tests/lib.sh`'s
# `FAIL ` prefix and its `<name>: N passed, M failed` summary, and
# `tests/run.sh`'s `━━ ` header. A rename in any of them turns `other_fails` to
# 0, and a genuinely broken suite then classifies as the benign FT-21
# chicken-and-egg. Pin all three against their real producers, then drive the
# three outcomes.
_cls() { bash "$ROOT/scripts/release.sh" _classify-suite "$1" "${2:-1}" 2>&1; echo "rc=$?"; }

# (1) BENIGN: only the latest-tag assertion failed, every group finished.
_benign="$(printf '%s\n' '━━ test_version_sync.sh ━━' '  FAIL VERSION (ci/v4.0.0) != latest published tag (ci/v3.0.0)' 'version-sync: 28 passed, 1 failed')"
_out="$(_cls "$_benign")"
assert_contains "$_out" "RED as EXPECTED" "benign FT-21 red is classified as expected"
assert_contains "$_out" "rc=0" "  and prep is allowed to proceed"

# (2) REAL RED: another assertion failed too. Must refuse, and must SHOW it —
# an operator who is told "unexpected" without the line cannot act.
_real="$(printf '%s\n' '━━ test_version_sync.sh ━━' '  FAIL VERSION (ci/v4.0.0) != latest published tag (ci/v3.0.0)' '  FAIL something genuinely broke' 'version-sync: 27 passed, 2 failed')"
_out="$(_cls "$_real")"
assert_contains "$_out" "UNEXPECTED red" "an additional FAIL is NOT classified as the chicken-and-egg"
assert_contains "$_out" "something genuinely broke" "  and the offending assertion is printed"
assert_contains "$_out" "rc=1" "  and prep refuses"

# (3) CRASH: a group started and never printed its summary (set -e abort, missing
# tool). Prints NO `FAIL` line at all, so an "any-other-FAIL" subtraction reads it
# as benign — the misclassification the header/summary count exists to catch.
_crash="$(printf '%s\n' '━━ test_version_sync.sh ━━' '  FAIL VERSION (ci/v4.0.0) != latest published tag (ci/v3.0.0)' 'version-sync: 28 passed, 1 failed' '━━ test_contract.sh ━━')"
_out="$(_cls "$_crash")"
assert_contains "$_out" "UNEXPECTED red" "a group that crashed without a summary is NOT classified as benign"
assert_contains "$_out" "crashed without a summary" "  and is diagnosed as a crash, not as an assertion failure"
assert_contains "$_out" "rc=1" "  and prep refuses"

# (4) The expected assertion did not fire at all — something else broke first.
_other="$(printf '%s\n' '━━ test_contract.sh ━━' '  FAIL a contract assertion' 'contract: 1 passed, 1 failed')"
_out="$(_cls "$_other")"
assert_contains "$_out" "did NOT fire" "a red WITHOUT the latest-tag assertion is called out specifically"
assert_contains "$_out" "rc=1" "  and prep refuses"

# (5) Green passes through untouched.
_out="$(_cls "" 0)"
assert_contains "$_out" "fully green" "a green suite is reported as green"
assert_contains "$_out" "rc=0" "  and prep proceeds"

# THE FORMAT STRINGS ARE A CONTRACT WITH OTHER FILES. Pin them against their real
# producers, so a rename reds HERE rather than silently disarming the classifier.
assert_contains "$(cat "$ROOT/tests/run.sh")" '━━ ' \
  "tests/run.sh still emits the ━━ group header the classifier counts"
# NB the literal `passed, ` does NOT appear in lib.sh: `suite_summary` prints
# `%d passed\033[0m, %s%d failed`, i.e. an SGR reset sits between the words —
# the same escape-sequence trap CLAUDE.md records for reading the suite total.
# The classifier survives it because it strips SGR first (`sed 's/\x1b...//g'`);
# this pin must therefore match the FORMAT, not the rendered line.
assert_ok "grep -q '%d passed' '$ROOT/tests/lib.sh'" \
  "tests/lib.sh still emits the 'N passed' half of the summary the classifier counts"
assert_ok "grep -q '%d failed' '$ROOT/tests/lib.sh'" \
  "tests/lib.sh still emits the 'M failed' half"
# And the classifier must still strip SGR — without that step its own summary
# count matches nothing on real (coloured) output and every group reads as crashed.
_cls_fn="$(awk '/^classify_suite\(\) \{/,/^\}/' "$ROOT/scripts/release.sh")"
assert_contains "$_cls_fn" "x1b" \
  "classify_suite strips SGR before counting (coloured output otherwise reads as all-crashed)"
# Drive it: a COLOURED benign red must still classify as benign. A static check
# alone would pass against a strip that no longer works.
_benign_colour="$(printf '\033[1m━━ test_version_sync.sh ━━\033[0m\n  \033[31mFAIL\033[0m VERSION (ci/v4.0.0) != latest published tag (ci/v3.0.0)\n\nversion-sync: \033[32m28 passed\033[0m, \033[31m1 failed\033[0m\n')"
_out="$(_cls "$_benign_colour")"
assert_contains "$_out" "RED as EXPECTED" "  ...and a COLOURED benign red still classifies as benign"
# PIN THE PREFIX THE CLASSIFIER MATCHES, not the bare word. `grep -q 'FAIL'`
# is satisfied by the six `T_FAIL` occurrences in lib.sh, so it passed no matter
# what happened to `_r`'s output format — the one pin of the four here that could
# not fail. The classifier greps `^[[:space:]]+FAIL ` on SGR-stripped output, so
# what matters is the INDENT plus `FAIL` plus a space.
assert_ok "grep -qE '  .*FAIL' '$ROOT/tests/lib.sh'" \
  "tests/lib.sh still emits an INDENTED FAIL prefix — the shape the classifier greps, not merely the word"

suite_summary "release"
