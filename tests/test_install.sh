#!/usr/bin/env bash
# tests/test_install.sh — regression cover for install.sh's COLD-START template
# resolution, the mechanism PLAN-018 F1 broke.
#
# WHY THIS EXISTS: the bootstrap loop derived its template names as
# "${wf}-${VISIBILITY}.yml". PLAN-013 unified ai-review into a single template
# with no visibility split and deleted `workflows/ai-review-private.yml` at
# ci/v2.2.0 — so the derivation asked for a 404 and `|| exit 1` killed every
# cold-start install before config.json, CODEOWNERS, CLAUDE.md, pre_push_check.sh,
# the pre-commit merge, and all 18 labels. It survived nine releases because
# canon is already adopted and therefore never runs its own cold start.
#
# THE OBVIOUS TEST WOULD NOT HAVE CAUGHT IT. "Every auto_install:true manifest
# entry's template exists" passes: the ai-review entry resolves to
# workflows/ai-review.yml, which exists and always did. The manifest was never
# wrong — install.sh was. So this file checks the INSTALLER'S OWN resolution,
# and then checks it against the manifest, which is the documentation authority
# for the same consumer paths.
#
# HOW IT STAYS HONEST: the caller block is EXTRACTED FROM install.sh and
# EVALUATED, never re-implemented here. A test carrying its own copy of the
# naming table passes happily while the installer rots.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(cd "$HERE/.." && pwd)"
INSTALL="$ROOT/install/install.sh"
TEMPLATES="$ROOT/install/templates"
MANIFEST="$TEMPLATES/manifest.json"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------------------
# Part 0 — form guard. Everything below depends on fetch_template's first
# argument being a literal. An associative-array/variable form
# (`fetch_template "${TEMPLATES[$wf]}" …`) would still install *something* while
# making both the static check and the extracted-block evaluation meaningless.
#
# Extraction is deliberately in python, not grep+sed. A `sed -E
# 's/^([0-9]+):.*fetch_template[[:space:]]+/\1:/'` form was tried first and is
# UNSOUND: `.*` is greedy, so a line carrying TWO calls
# (`fetch_template "workflows/${X}.yml" … || fetch_template "workflows/a.yml" …`)
# had only its LAST argument inspected — the derivation form this guard exists to
# reject passed unreported. Every occurrence on a line is now examined, and the
# marker line numbers are recovered exactly so containment (part 2) is a numeric
# range test rather than a text comparison.
# ---------------------------------------------------------------------------
echo "== fetch_template call sites name their template literally =="

# lineno \t arg1 \t arg2 — one row per OCCURRENCE. Comment lines are excluded:
# install.sh's own header comment names the function, and an earlier revision of
# this test scraped that prose as a call site (part 1 then asserted
# `install/templates/stubbed,` exists — a real defect this file caught in itself).
# LOGICAL lines, not physical: a call wrapped on a backslash continuation
#   fetch_template "workflows/x.yml" \
#     ".github/workflows/x.yml" || exit 1
# otherwise yields a destination of "\", which fails the `.github/workflows/`
# filter and skips the call entirely — re-opening the containment hole in a form
# ordinary line-wrapping produces. Worse than silent: the stray call also ADDS
# two green assertions, so the suite looks like it grew coverage. The recorded
# line number is the FIRST physical line, which is what the range test needs.
#
# Only whole-line comments are skipped. A code line that merely mentions the
# function in a string (`echo "…fetch_template…"`) is still scraped, and fails
# loudly at part 1 naming a nonexistent template rather than naming the real
# cause — noted so the next person does not re-diagnose it from scratch.
python3 - "$INSTALL" <<'PY' > "$TMP/calls.tsv"
import re, sys
CALL = re.compile(r'(?:^|[^\w])fetch_template[ \t]+')
ARG  = re.compile(r'"([^"]*)"|(\S+)')
buf, start = "", None
for n, raw in enumerate(open(sys.argv[1], encoding="utf-8"), 1):
    line = raw.rstrip("\n")
    if start is None:
        start = n
    if line.endswith("\\"):
        buf += line[:-1] + " "
        continue
    logical, ln = buf + line, start
    buf, start = "", None
    if logical.lstrip().startswith("#"):
        continue
    for m in CALL.finditer(logical):
        args, rest = [], logical[m.end():]
        for a in ARG.finditer(rest):
            args.append(a.group(1) if a.group(1) is not None else a.group(2))
            if len(args) == 2:
                break
        while len(args) < 2:
            args.append("")
        print("\t".join([str(ln), args[0], args[1]]))
PY

nsites="$(wc -l < "$TMP/calls.tsv" | tr -d ' ')"
assert_ok "[ '$nsites' -gt 0 ]" "found fetch_template call sites ($nsites)"

: > "$TMP/srcs"
while IFS=$'\t' read -r ln arg _dest; do
  if printf '%s' "$arg" | grep -q '[$`]'; then
    _r "install.sh:$ln — template argument is not a literal ('$arg')"
  else
    _g "install.sh:$ln — literal template argument ('$arg')"
    printf '%s\n' "$arg" >> "$TMP/srcs"
  fi
done < "$TMP/calls.tsv"

# ---------------------------------------------------------------------------
# Part 1 — every literal install.sh fetches resolves under install/templates/.
# This is the direct F1 assertion: the 404'd name would fail here.
# ---------------------------------------------------------------------------
echo ""
echo "== every fetched template exists under install/templates/ =="
# Direct test, not `assert_ok "[ -f '\''…'\'' ]"` — that form evals a
# repo-derived string inside single quotes, so a template name containing a
# quote would break the quoting and eval whatever followed.
while IFS= read -r src; do
  if [ -f "$TEMPLATES/$src" ]; then _g "install/templates/$src exists"
  else _r "install/templates/$src exists"; fi
done < <(sort -u "$TMP/srcs")

# ---------------------------------------------------------------------------
# Part 2 — the installer's resolution matches the manifest's, per visibility.
#
# Part 1 alone is satisfied by any name that happens to exist: naming
# `composition-public.yml` on a private install passes it while shipping the
# wrong runner labels to a private consumer. This part closes that class — the
# drift the F1 fix *creates* by hardcoding names in the installer while leaving
# manifest.json as the documented authority.
#
# The block is extracted between the BOOTSTRAP-CALLERS markers and evaluated
# with fetch_template stubbed, in an empty cwd (so the "already exists —
# preserve" branch is not taken). That yields what install.sh ACTUALLY resolves,
# not what a re-implementation here would predict.
# ---------------------------------------------------------------------------
echo ""
echo "== bootstrap callers resolve to the manifest's templates =="

# Marker line numbers, recovered exactly. BOTH markers must appear exactly once:
# with a missing/renamed end marker, `sed -n '/start/,/end/p'` prints to EOF, so
# the "block" becomes the rest of install.sh — non-empty (passing an `-s` guard)
# and then SOURCED, executing the config.json / CODEOWNERS / CLAUDE.md / label
# sections in the sandbox with only `fetch_template` stubbed.
mstart="$(grep -c '^# >>> BOOTSTRAP-CALLERS >>>' "$INSTALL")"
mend="$(grep -c '^# <<< BOOTSTRAP-CALLERS <<<' "$INSTALL")"
assert_eq "$mstart" "1" "exactly one BOOTSTRAP-CALLERS start marker"
assert_eq "$mend" "1" "exactly one BOOTSTRAP-CALLERS end marker"

BSTART="$(grep -n '^# >>> BOOTSTRAP-CALLERS >>>' "$INSTALL" | cut -d: -f1)"
BEND="$(grep -n '^# <<< BOOTSTRAP-CALLERS <<<' "$INSTALL" | cut -d: -f1)"
assert_ok "[ '${BSTART:-0}' -lt '${BEND:-0}' ]" "start marker precedes end marker"

sed -n "${BSTART},${BEND}p" "$INSTALL" > "$TMP/block.sh"
assert_ok "[ -s '$TMP/block.sh' ]" "BOOTSTRAP-CALLERS block found in install.sh"
assert_ok "grep -q 'fetch_template' '$TMP/block.sh'" "block contains the caller installs"

# No `.github/workflows/` install may sit OUTSIDE the markers — otherwise a new
# bootstrapped caller is added where nothing checks it (the F1 shape again).
#
# Containment is a NUMERIC RANGE TEST on the call site's line number. The earlier
# text-comparison form (`grep -vFf` of the block's own lines) was unsound in both
# directions: `grep -vF` substring-matches, so a stray duplicate call outside the
# markers carrying a trailing comment was filtered out as "inside"; and the LHS
# pattern did not skip comments, so documenting the rule inside install.sh's own
# header broke the rule's own check. Line numbers have neither failure mode.
#
# KNOWN LIMIT, stated rather than implied: this sees only calls whose destination
# is a literal beginning `.github/workflows/`. A variable destination
# (`"$WFDIR/x.yml"`), or a workflow written by `curl -o`/`cp` instead of
# `fetch_template`, is invisible to it. Part 2's manifest cross-check is the
# backstop for what IS inside the markers; §16.9 records the gap.
: > "$TMP/outside"
while IFS=$'\t' read -r ln _arg dest; do
  case "$dest" in
    .github/workflows/*) ;;
    *) continue ;;
  esac
  if [ "$ln" -lt "$BSTART" ] || [ "$ln" -gt "$BEND" ]; then
    printf 'install.sh:%s -> %s\n' "$ln" "$dest" >> "$TMP/outside"
  fi
done < "$TMP/calls.tsv"
assert_eq "$(cat "$TMP/outside")" "" "no workflow install outside the BOOTSTRAP-CALLERS markers"

# One call per line — the greedy-match hole part 0's header describes. Two calls
# sharing a line are legal bash and would let the second mask the first here too.
multi="$(cut -f1 "$TMP/calls.tsv" | sort | uniq -d | tr '\n' ' ')"
assert_eq "${multi% }" "" "no install.sh line carries two fetch_template calls"

# Evaluate the block once per visibility; record template -> destination.
eval_block() { # $1 = visibility
  local vis="$1" sandbox="$TMP/run-$1"
  mkdir -p "$sandbox"
  (
    # Same shell options as install.sh (`set -euo pipefail`, install.sh:49) so
    # the harness is a faithful stand-in if the block ever grows a statement
    # whose non-zero status should abort.
    set -euo pipefail
    cd "$sandbox" || exit 1
    # shellcheck disable=SC2034  # read by the sourced block, not by this file
    VISIBILITY="$vis"
    # shellcheck disable=SC2317,SC2329  # called from the extracted block
    fetch_template() { printf '%s\t%s\n' "$1" "$2" >> "$TMP/resolved-$vis"; }
    # shellcheck disable=SC1090
    . "$TMP/block.sh" >/dev/null
  )
}

for vis in public private; do
  : > "$TMP/resolved-$vis"
  # The rc is ASSERTED, not discarded: the sandbox runs `set -euo pipefail`, so a
  # block statement that should abort does abort — but with a bare call nothing
  # observed it, and a failure AFTER both installs left the suite green.
  # Called BARE, rc captured after — NOT `if eval_block …; then`. Running a
  # function in a condition disables `set -e` for its entire body (the same trap
  # install.sh documents for update_mode), which silently defeated the sandbox's
  # `set -euo pipefail`: a failing statement after both installs left the suite
  # green. The outer script has no `-e`, so a bare call is safe here.
  eval_block "$vis"; eb_rc=$?
  if [ "$eb_rc" -eq 0 ]; then _g "$vis: block runs clean under set -euo pipefail"
  else _r "$vis: block aborted under set -euo pipefail (rc=$eb_rc)"; fi
  if [ -s "$TMP/resolved-$vis" ]; then _g "$vis: block resolved at least one caller"
  else _r "$vis: block resolved at least one caller"; fi
done

# The manifest's own resolution, same rule update_mode uses:
#   visibility_variants[vis] if present, else template.
manifest_template() { # $1 = consumer path  $2 = visibility
  python3 - "$MANIFEST" "$1" "$2" <<'PY'
import json, sys
manifest, path, vis = sys.argv[1:4]
for f in json.load(open(manifest))["files"]:
    if f["path"] == path:
        print(f.get("visibility_variants", {}).get(vis, f["template"]))
        break
else:
    print("")
PY
}

for vis in public private; do
  while IFS=$'\t' read -r tmpl dest; do
    [ -n "$tmpl" ] || continue
    want="$(manifest_template "$dest" "$vis")"
    assert_eq "$tmpl" "$want" "$vis: $dest <- $tmpl (manifest: ${want:-<no entry>})"
  done < "$TMP/resolved-$vis"
done

# REVERSE DIRECTION — which callers the block installs, not just whether what it
# installs is named right. Without this, DELETING a whole caller stanza passes
# with zero failures (the checks above only inspect what remains), and a cold
# start silently ships without that workflow. That is not hypothetical: it is
# exactly PLAN-018 F2, where the bootstrap set omits the `pre-commit` caller
# whose check is required on every tier but umbrella.
#
# The expected set is `manifest.json`'s `auto_install: true` workflow entries —
# data already in the repo, and the manifest is the documented authority for the
# bootstrap set (§16.8). This does NOT contradict install.sh being deliberately
# not manifest-driven: that rationale is about a network fetch + parse on the
# COLD-START path at runtime. This test is offline and already reads the manifest.
# It also means adding a bootstrap caller and flipping its `auto_install` must
# happen together, or this fails — which is the coupling F2's fix needs.
#
# Subsumes the old "public and private bootstrap the same caller set" check: both
# visibilities are compared against the same expected set.
want_dests="$(python3 - "$MANIFEST" <<'PY'
import json, sys
for f in json.load(open(sys.argv[1]))["files"]:
    if f.get("auto_install") and f["path"].startswith(".github/workflows/"):
        print(f["path"])
PY
)"
want_dests="$(printf '%s\n' "$want_dests" | sort -u)"
assert_ok "[ -n '$want_dests' ]" "manifest declares an auto_install workflow set"
for vis in public private; do
  got="$(cut -f2 "$TMP/resolved-$vis" | sort -u)"
  assert_eq "$got" "$want_dests" "$vis: bootstrap installs exactly the manifest's auto_install callers"
done

# ---------------------------------------------------------------------------
# Part 3 — the asymmetry that makes an implicit convention unsafe.
#
# Canon ships THREE naming shapes: no-variant (ai-review), both-suffixed
# (composition), and bare-public/suffixed-private (pre-commit). An implementer
# generalising from composition writes `pre-commit-public.yml` and reproduces F1
# for every public adopter. Asserted against the template files themselves so
# the shapes cannot drift out from under the comment in install.sh.
# ---------------------------------------------------------------------------
echo ""
echo "== the three naming shapes canon actually ships =="
assert_ok "[ -f '$TEMPLATES/workflows/ai-review.yml' ]" "ai-review: bare name exists"
assert_fail "[ -f '$TEMPLATES/workflows/ai-review-private.yml' ]" \
  "ai-review: no -private variant (deleted at ci/v2.2.0 — the F1 404)"
assert_fail "[ -f '$TEMPLATES/workflows/ai-review-public.yml' ]" \
  "ai-review: no -public variant"
assert_ok "[ -f '$TEMPLATES/workflows/composition-public.yml' ]" "composition: -public exists"
assert_ok "[ -f '$TEMPLATES/workflows/composition-private.yml' ]" "composition: -private exists"
assert_ok "[ -f '$TEMPLATES/workflows/pre-commit.yml' ]" "pre-commit: PUBLIC variant is the bare name"
assert_ok "[ -f '$TEMPLATES/workflows/pre-commit-private.yml' ]" "pre-commit: -private exists"
assert_fail "[ -f '$TEMPLATES/workflows/pre-commit-public.yml' ]" \
  "pre-commit: no -public variant (the asymmetry — deriving one 404s)"

# ---------------------------------------------------------------------------
# Part 4 — the canon pre-commit fragment must select at least one hook at the
# stage the reusable actually runs (PLAN-018 F3).
#
# The `pre-commit` reusable runs `pre-commit run --all-files` with NO
# `--hook-stage` when `run-stage` is empty (its default), which selects the
# `pre-commit` stage. A fragment whose hooks are all `stages: [pre-push]` matches
# ZERO hooks, prints nothing, and exits 0 — a green REQUIRED check that inspected
# nothing, on every fresh adopter. That was the shipped state for nine releases,
# masked only on repos with a pre-existing rich config.
#
# Asserts the PROPERTY, not the specific hook ids: any hook running at the
# default stage satisfies it. A hook with no `stages:` key runs at every stage,
# so it counts.
# ---------------------------------------------------------------------------
echo ""
echo "== canon pre-commit fragment selects hooks at the reusable's stage =="

FRAGMENT="$TEMPLATES/pre-commit-hook-block.yaml"
if [ -f "$FRAGMENT" ]; then _g "canon fragment exists"; else _r "canon fragment exists"; fi

n_default_stage="$(python3 "$HERE/lib_count_stage_hooks.py" "$FRAGMENT" 2>/dev/null || echo ERR)"
case "$n_default_stage" in
  SKIP) printf '  \033[33mskip\033[0m PyYAML not installed — fragment stage count skipped\n' ;;
  ERR)  _r "fragment stage count failed to run" ;;
  *)    if [ "${n_default_stage:-0}" -gt 0 ]; then
          _g "fragment has $n_default_stage hook(s) at the default (pre-commit) stage"
        else
          _r "fragment has ZERO default-stage hooks — the required check would inspect nothing"
        fi ;;
esac

# The reusable's default really is the stage this part assumes — extracted from
# the workflow, not restated here. If the empty-`run-stage` branch ever starts
# passing --hook-stage, this is what says so out loud.
PCWF="$ROOT/.github/workflows/pre-commit.yml"
if grep -qE '^\s*pre-commit run --all-files --show-diff-on-failure$' "$PCWF"; then
  _g "reusable's default branch runs with no --hook-stage (selects pre-commit stage)"
else
  _r "reusable's default branch no longer runs bare — Part 4's premise changed"
fi

# ---------------------------------------------------------------------------
# Part 5 — fetch body validation (FT-39). `curl -f` rejects a 4xx/5xx, but a
# proxy/CDN can answer 200 with an empty or HTML body; writing that over a canon
# gate template silently 0-bytes a required check, and for the pre-commit
# fragment it makes marker_version() read 1 → the whole legacy fleet's refresh
# freezes (FT-32 fails open). The validator is EXTRACTED from install.sh and
# DRIVEN here, never re-implemented: a mutation removing the `-s`/HTML-tag/marker
# checks must turn this red (the FT-40 lesson — a re-implemented check is no
# teeth at all).
# ---------------------------------------------------------------------------
echo ""
echo "== fetch body validation rejects empty / HTML / marker-less bodies (FT-39) =="

vstart="$(grep -c '^# >>> FETCH-VALIDATE >>>' "$INSTALL")"
vend="$(grep -c '^# <<< FETCH-VALIDATE <<<' "$INSTALL")"
assert_eq "$vstart" "1" "exactly one FETCH-VALIDATE start marker"
assert_eq "$vend" "1" "exactly one FETCH-VALIDATE end marker"

VS="$(grep -n '^# >>> FETCH-VALIDATE >>>' "$INSTALL" | cut -d: -f1)"
VE="$(grep -n '^# <<< FETCH-VALIDATE <<<' "$INSTALL" | cut -d: -f1)"
assert_ok "[ '${VS:-0}' -lt '${VE:-0}' ]" "FETCH-VALIDATE start marker precedes end marker"
sed -n "${VS},${VE}p" "$INSTALL" > "$TMP/validate.sh"
assert_ok "[ -s '$TMP/validate.sh' ]" "FETCH-VALIDATE block found in install.sh"
assert_ok "grep -q 'validate_fetched()' '$TMP/validate.sh'" "block defines validate_fetched"

# Source the extracted block and drive the shipped function against crafted
# bodies. Run in a subshell so the sourced definition does not leak, with
# `set +e` so a non-zero return is captured, not fatal.
(
  set +e
  # shellcheck disable=SC1090
  . "$TMP/validate.sh"
  : > "$TMP/f_empty"
  printf '<!DOCTYPE html>\n<html><body>404</body></html>\n' > "$TMP/f_html"
  printf '   \n\t<html>error</html>\n'                       > "$TMP/f_wsphtml"
  printf 'repos:\n  - repo: local\n'                          > "$TMP/f_good"
  printf '# CANON: aidoc-flow-ci pre_push_check v2\nrepos:\n' > "$TMP/f_frag"
  # A canon markdown template can open with an HTML COMMENT (pull_request_template.md
  # starts `<!--`). It must NOT be rejected as an HTML page (FT-39 review fold).
  printf '<!-- Canonical PR template -->\n## Summary\n'        > "$TMP/f_mdcomment"
  {
    printf 'empty=%s\n'   "$(validate_fetched "$TMP/f_empty"   empty   2>/dev/null; echo $?)"
    printf 'html=%s\n'    "$(validate_fetched "$TMP/f_html"    html    2>/dev/null; echo $?)"
    printf 'wsphtml=%s\n' "$(validate_fetched "$TMP/f_wsphtml" wsphtml 2>/dev/null; echo $?)"
    printf 'good=%s\n'    "$(validate_fetched "$TMP/f_good"    good    2>/dev/null; echo $?)"
    printf 'mdcomment=%s\n' "$(validate_fetched "$TMP/f_mdcomment" mdcomment 2>/dev/null; echo $?)"
    # 3rd arg = required marker. good body lacks it → reject; frag carries v2 → accept.
    printf 'goodmark=%s\n' "$(validate_fetched "$TMP/f_good" good '^# CANON: aidoc-flow-ci pre_push_check v[0-9]+' 2>/dev/null; echo $?)"
    printf 'fragmark=%s\n' "$(validate_fetched "$TMP/f_frag" frag '^# CANON: aidoc-flow-ci pre_push_check v[0-9]+' 2>/dev/null; echo $?)"
  } > "$TMP/vres"
)
_res() { grep "^$1=" "$TMP/vres" | cut -d= -f2; }
assert_eq "$(_res empty)"    "1" "empty body rejected (rc=1)"
assert_eq "$(_res html)"     "1" "HTML body rejected (rc=1)"
assert_eq "$(_res wsphtml)"  "1" "leading-whitespace HTML rejected (rc=1)"
assert_eq "$(_res good)"     "0" "valid body accepted (rc=0)"
assert_eq "$(_res mdcomment)" "0" "markdown body opening with '<!--' accepted, not HTML-rejected (rc=0)"
assert_eq "$(_res goodmark)" "1" "marker-less body rejected when marker required (rc=1)"
assert_eq "$(_res fragmark)" "0" "versioned-marker fragment accepted (rc=0)"

# fetch_template must actually CALL the validator — otherwise the extracted-block
# teeth above pass while the live fetch path is unguarded.
assert_ok "grep -q 'validate_fetched \"\$dst\"' '$INSTALL'" \
  "fetch_template invokes validate_fetched on its destination"
# the pre-commit fragment fetch asserts the versioned marker (point 2).
assert_ok "grep -q 'validate_fetched \"\$PRECOMMIT_TMP\"' '$INSTALL'" \
  "pre-commit fragment fetch is marker-validated"

# Point 3 — `--update` must not read a missing TTY as consent to replace.
assert_ok "grep -q 'no TTY and no --non-interactive — keeping local' '$INSTALL'" \
  "update: no-TTY-without-flag defaults to keep, not replace (FT-39)"

suite_summary "test_install"
