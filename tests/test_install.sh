#!/usr/bin/env bash
# tests/test_install.sh — regression cover for install.sh's COLD-START template
# resolution, the mechanism PLAN-018 F1 broke.
#
# WHY THIS EXISTS: the bootstrap loop derived its template names as
# "${wf}-${VISIBILITY}.yml". PLAN-013 unified ai-review into a single template
# with no visibility split and deleted `workflows/ai-review-private.yml` at
# ci/v2.2.0 — so the derivation asked for a 404 and `|| exit 1` killed every
# cold-start install before config.json, CODEOWNERS, CLAUDE.md, pre_push_check.sh,
# the pre-commit merge, and all 21 labels. It survived nine releases because
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
# Assert the PREMISE — the default branch passes no --hook-stage — not a
# literal command string. #426 added `env -u SKIP`, `timeout` and
# `--color=never` to both branches; the premise was unchanged but a
# whole-line match called it a premise change. Extract the else-branch
# invocation and test the two properties that actually matter.
_default_inv="$(awk '/^ *else$/{f=1;next} f&&/pre-commit run/{print;exit}' "$PCWF")"
if [ -n "$_default_inv" ] && printf '%s' "$_default_inv" | grep -q -- '--all-files' \
   && ! printf '%s' "$_default_inv" | grep -q -- '--hook-stage'; then
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

echo ""
echo "== FT-57: mandatory pre-write backup of the consumer's existing surfaces =="
# Drives the MANDATORY-BACKUP block extracted from install.sh itself, not a copy.
bstart="$(grep -c '^# >>> MANDATORY-BACKUP >>>' "$INSTALL")"
bend="$(grep -c '^# <<< MANDATORY-BACKUP <<<' "$INSTALL")"
assert_eq "$bstart" "1" "exactly one MANDATORY-BACKUP start marker"
assert_eq "$bend" "1" "exactly one MANDATORY-BACKUP end marker"
BS="$(grep -n '^# >>> MANDATORY-BACKUP >>>' "$INSTALL" | cut -d: -f1)"
BE="$(grep -n '^# <<< MANDATORY-BACKUP <<<' "$INSTALL" | cut -d: -f1)"
assert_ok "[ '${BS:-0}' -lt '${BE:-0}' ]" "MANDATORY-BACKUP start marker precedes end marker"

# The hook must precede EVERY consumer writer, not just fetch_template: the three
# real writers are `curl -o`, `cp`/`mv`, and `sed -i`. Anchor on the earliest of
# any of them, so a future write added above the hook fails here.
FIRST_WRITE="$(grep -nE "curl -fsSL .*-o \"\\\$\{?dst|^[[:space:]]*(cp|mv) \"|sed -i" "$INSTALL" \
  | awk -F: -v b="$BE" '$1 > b {print $1; exit}')"
assert_ok "[ -n '${FIRST_WRITE:-}' ]" "found a consumer write path after the backup hook (anchor is meaningful)"
assert_ok "[ '${BE:-0}' -lt '${FIRST_WRITE:-999999}' ]" "backup hook precedes the first consumer write"

BLK="$TMP/ft57-block.sh"
sed -n "${BS},${BE}p" "$INSTALL" | grep -v 'backup_existing_surfaces || ' > "$BLK"

# helper: run the extracted block against a fixture dir, echo rc
_ft57_run() { # $1 = fixture root containing consumer/
  ( set -euo pipefail
    WORK_DIR="$1"; TARGET_REPO="owner/repo"
    cd "$1/consumer"
    # shellcheck disable=SC1090
    source "$BLK"
    # match production semantics: the call site invokes it in a `||` condition,
    # which disables set -e inside the function body.
    if backup_existing_surfaces; then :; else exit 1; fi ) > "$1/out.txt" 2>&1
  echo $?
}

# --- the requirement: a consumer's OWN established flow is captured -----------
BK="$TMP/ft57"; rm -rf "$BK"; mkdir -p "$BK/consumer/.github/workflows" "$BK/consumer/.github/ai-review" "$BK/consumer/scripts"
printf 'name: My Custom Deploy\n' > "$BK/consumer/.github/workflows/my-custom-deploy.yml"
printf 'name: pre-commit\n'       > "$BK/consumer/.github/workflows/pre-commit.yml"
printf '{"customized":true}\n'    > "$BK/consumer/.github/ai-review/config.json"
printf 'CUSTOMIZED\n'             > "$BK/consumer/scripts/pre_push_check.sh"
printf 'untouched\n'              > "$BK/consumer/README.md"
# every root-list entry, so dropping any one of them goes red
for r in .markdownlint.json .lychee.toml .yamllint.yaml .yamllint.yml .pre-commit-config.yaml .gitignore .gitattributes CLAUDE.md; do
  printf 'local\n' > "$BK/consumer/$r"
done
rc="$(_ft57_run "$BK")"
assert_eq "$rc" "0" "backup succeeds on a populated consumer"
assert_ok "[ -f '$BK/backup/.github/workflows/my-custom-deploy.yml' ]" "captures the consumer's OWN workflow (not just canon-owned)"
assert_ok "[ -f '$BK/backup/.github/workflows/pre-commit.yml' ]" "captures a canon-owned workflow"
assert_ok "[ -f '$BK/backup/.github/ai-review/config.json' ]" "captures nested .github config"
assert_ok "[ -f '$BK/backup/scripts/pre_push_check.sh' ]" "captures scripts/pre_push_check.sh (a manifest path outside .github/)"
assert_fail "[ -f '$BK/backup/README.md' ]" "scoped — does not sweep unrelated repo files"
assert_ok "diff -q '$BK/consumer/.github/workflows/my-custom-deploy.yml' '$BK/backup/.github/workflows/my-custom-deploy.yml'" "backed-up content is byte-identical"
_ft57_missing=""
for r in .markdownlint.json .lychee.toml .yamllint.yaml .yamllint.yml .pre-commit-config.yaml .gitignore .gitattributes CLAUDE.md; do
  [ -f "$BK/backup/$r" ] || _ft57_missing="$_ft57_missing $r"
done
assert_eq "$_ft57_missing" "" "every root-list entry is actually backed up"

# --- BLOCKER regressions: paths a word-split list mangled --------------------
SP="$TMP/ft57-space"; rm -rf "$SP"; mkdir -p "$SP/consumer/.github/ISSUE_TEMPLATE"
printf 'x\n' > "$SP/consumer/.github/ISSUE_TEMPLATE/bug report.md"
rc="$(_ft57_run "$SP")"
assert_eq "$rc" "0" "a filename with a SPACE does not break the backup"
assert_ok "[ -f '$SP/backup/.github/ISSUE_TEMPLATE/bug report.md' ]" "space-named file is backed up"

GL="$TMP/ft57-glob"; rm -rf "$GL"; mkdir -p "$GL/consumer/.github"
printf 'BRACKET\n' > "$GL/consumer/.github/notes[1].md"; printf 'PLAIN\n' > "$GL/consumer/.github/notes1.md"
rc="$(_ft57_run "$GL")"
assert_eq "$rc" "0" "a filename with a GLOB metachar does not break the backup"
assert_ok "[ -f '$GL/backup/.github/notes[1].md' ]" "glob-metachar file is backed up (not silently globbed onto a sibling)"
assert_eq "$(find "$GL/backup" -type f | wc -l | tr -d ' ')" "2" "count matches files actually written (no fail-open over-count)"

SY="$TMP/ft57-symlink"; rm -rf "$SY"; mkdir -p "$SY/consumer/real/workflows"
printf 'w\n' > "$SY/consumer/real/workflows/ci.yml"; ( cd "$SY/consumer" && ln -s real .github )
rc="$(_ft57_run "$SY")"
assert_eq "$rc" "0" "a SYMLINKED .github does not break the backup"
assert_ok "[ -f '$SY/backup/.github/workflows/ci.yml' ]" "symlinked .github is followed, not silently bypassed"

# --- CI-0023: a DANGLING symlink must not brick the installer ----------------
# `find -L … ! -type d` enumerates a broken symlink (the stat fails, so find
# yields the link itself), but `cp -p` DEREFERENCES and therefore fails on it.
# Because the backup is fail-CLOSED, that aborted install.sh in EVERY mode —
# including the documented `--repin` upgrade path — on any consumer that merely
# happened to carry a dangling link under .github/. Shipped in FT-57; this is
# the regression guard.
DS="$TMP/ft57-dangling"; rm -rf "$DS"; mkdir -p "$DS/consumer/.github/workflows"
printf 'w\n' > "$DS/consumer/.github/workflows/real.yml"
ln -s ../../nowhere/gone.yml "$DS/consumer/.github/workflows/dangling.yml"
printf 'target\n' > "$DS/consumer/.github/resolvable-target.yml"
ln -s resolvable-target.yml "$DS/consumer/.github/good-link.yml"
rc="$(_ft57_run "$DS")"
assert_eq "$rc" "0" "a DANGLING symlink does not abort the mandatory backup (CI-0023)"
assert_ok "[ -L '$DS/backup/.github/workflows/dangling.yml' ]" "the dangling symlink is preserved AS A LINK"
assert_ok "[ -f '$DS/backup/.github/workflows/real.yml' ]" "a real file alongside a dangling link is still captured"
# The resolvable link must still be captured BY CONTENT — this is what stops a
# future 'simplify' from collapsing the branch to a blanket `cp -P`.
assert_ok "[ -f '$DS/backup/.github/good-link.yml' ] && [ ! -L '$DS/backup/.github/good-link.yml' ]" \
  "a RESOLVABLE symlink is still captured by content, not as a link"
assert_contains "$(cat "$DS/backup/.github/good-link.yml" 2>/dev/null)" "target" "the resolvable link's content is the target's"

# The ROOT list lost the same broken-symlink case one step EARLIER, at
# enumeration: `[ -e "$r" ]` dereferences, so a dangling link at a root path
# tested false and was skipped silently — rc=0, "success", that surface absent
# from the snapshot while install.sh could still overwrite it. Fail-OPEN, which
# is strictly worse than the fail-closed abort above.
RD="$TMP/ft57-dangling-root"; rm -rf "$RD"; mkdir -p "$RD/consumer"
printf 'real\n' > "$RD/consumer/.gitattributes"
ln -s ../nowhere/gone "$RD/consumer/.gitignore"
rc="$(_ft57_run "$RD")"
assert_eq "$rc" "0" "a dangling ROOT-list symlink does not abort the backup"
assert_ok "[ -L '$RD/backup/.gitignore' ]" "a dangling ROOT-list symlink IS backed up, as a link (CI-0023 fail-open)"
assert_ok "[ -f '$RD/backup/.gitattributes' ]" "its real sibling is still captured"

# A symlink LOOP is deliberately the other classification: a genuine fault that
# still aborts, because `find -L` cannot traverse it and the snapshot therefore
# cannot be proven complete. What must NOT happen is the old behaviour of
# blaming permissions — no chmod fixes a cycle.
LP="$TMP/ft57-loop"; rm -rf "$LP"; mkdir -p "$LP/consumer/.github"
ln -s l2 "$LP/consumer/.github/l1"; ln -s l1 "$LP/consumer/.github/l2"
rc="$(_ft57_run "$LP")"
lp_out="$(cat "$LP/out.txt")"
assert_eq "$rc" "1" "a symlink LOOP is a fault and still fails closed"
assert_contains "$lp_out" "symlink LOOP" "the loop is named as the cause, not blamed on permissions"
assert_absent "$lp_out" "check permissions" "the permissions remedy is NOT offered for a loop"

# Mutation: restore the bare `cp -p` and the abort comes back. Without this the
# assertions above could pass on a fixture that never exercised the branch.
MUT="$TMP/ft57-dangling-mutant"; rm -rf "$MUT"; mkdir -p "$MUT"
sed -e 's#^      cp -Pp "\$p" "\$BACKUP_DIR/\$p" || rc=1#      cp -p "$p" "$BACKUP_DIR/$p" || rc=1#' "$BLK" > "$MUT/blk.sh"
assert_ok "! diff -q '$BLK' '$MUT/blk.sh' >/dev/null" "mutation actually changed the extracted block"
cp -r "$DS/consumer" "$MUT/consumer"
# WORK_DIR/TARGET_REPO are consumed by the SOURCED block, which shellcheck
# cannot follow — hence the disable, not a rename.
mut_rc="$( ( set -euo pipefail
  # shellcheck disable=SC2034
  WORK_DIR="$MUT"
  # shellcheck disable=SC2034
  TARGET_REPO="owner/repo"
  cd "$MUT/consumer"
  # shellcheck disable=SC1090
  source "$MUT/blk.sh"
  if backup_existing_surfaces; then :; else exit 1; fi ) >"$MUT/out.txt" 2>&1; echo $? )"
assert_eq "$mut_rc" "1" "mutant (bare cp -p) DOES abort on a dangling link — the CI-0023 bug, reproduced"

# --- fail-closed paths -------------------------------------------------------
FR="$TMP/ft57-fresh"; rm -rf "$FR"; mkdir -p "$FR/consumer"
rc="$(_ft57_run "$FR")"
assert_eq "$rc" "0" "fresh repo: nothing to back up is not an error"
assert_contains "$(cat "$FR/out.txt")" "no pre-existing CI/governance surfaces" "fresh repo says so explicitly"

if [ "$(id -u)" != "0" ]; then
  UN="$TMP/ft57-unreadable"; rm -rf "$UN"; mkdir -p "$UN/consumer/.github/secretdir"
  printf 'HIDDEN\n' > "$UN/consumer/.github/secretdir/x.yml"; printf 'v\n' > "$UN/consumer/.github/CODEOWNERS"
  chmod 000 "$UN/consumer/.github/secretdir"
  rc="$(_ft57_run "$UN")"
  chmod 755 "$UN/consumer/.github/secretdir" 2>/dev/null || true
  assert_eq "$rc" "1" "an unenumerable .github FAILS CLOSED (no silent partial backup)"

  # Isolate the COPY failure: the enclosing dirs must be enumerable and mkdir-able
  # so that only `cp` can fail. An unwritable backup dir would trip mkdir first
  # and pass for the wrong reason. An unreadable SOURCE file does exactly this.
  NW="$TMP/ft57-nowrite"; rm -rf "$NW"; mkdir -p "$NW/consumer/.github"
  printf 'v\n' > "$NW/consumer/.github/CODEOWNERS"
  printf 'secret\n' > "$NW/consumer/.github/unreadable.yml"; chmod 000 "$NW/consumer/.github/unreadable.yml"
  rc="$(_ft57_run "$NW")"
  chmod 644 "$NW/consumer/.github/unreadable.yml" 2>/dev/null || true
  assert_eq "$rc" "1" "a failed copy FAILS CLOSED (cp error is not swallowed)"
  assert_contains "$(cat "$NW/out.txt")" "refusing to write" "the copy failure names the refusal"
fi

# --- the call site itself must abort the run (execute it, do not grep it) ----
CS="$TMP/ft57-callsite.sh"
{ echo 'set -euo pipefail'; echo 'TARGET_REPO="owner/repo"'
  echo 'backup_existing_surfaces() { return 1; }'
  grep 'backup_existing_surfaces || ' "$INSTALL"
  echo 'echo REACHED_WRITE'; } > "$CS"
cs_out="$(bash "$CS" 2>&1)"; cs_rc=$?
assert_eq "$cs_rc" "1" "call site EXITS when the backup fails (guard executed, not grepped)"
assert_absent "$cs_out" "REACHED_WRITE" "call site does not fall through to the writes"

# --- scope must not drift from the manifest ---------------------------------
# A manifest path outside .github/ that is not in the backup's root list would be
# writable-but-unbacked. Fails here rather than in an adopter's repo.
_ft57_scope="$(python3 - "$ROOT/install/templates/manifest.json" "$INSTALL" <<'PYEOF'
import sys, json, re
manifest, install = sys.argv[1], sys.argv[2]
src = open(install, encoding="utf-8").read()
# Anchor on the loop HEADER and require its body to be the enumeration
# (`files+=`), not on the exact existence test — that expression is load-bearing
# and has changed once already (CI-0023 added `|| [ -L … ]` so a dangling
# root-list symlink is admitted). A regex pinned to its shape turns any future
# correction there into a spurious failure HERE, which reads as "the manifest
# drifted" and sends the next reader to the wrong file.
m = re.search(r"for r in (.*?); do\n(.*?)\n\s*done", src, re.S)
if m and "files+=" not in m.group(2):
    m = None          # matched some other loop — fail loud, never vacuously pass
roots = set(re.findall(r"[^\s\\]+", m.group(1))) if m else set()
bad = [f["path"] for f in json.load(open(manifest, encoding="utf-8"))["files"]
       if not f["path"].startswith(".github/") and f["path"] not in roots]
print(",".join(sorted(bad)))
PYEOF
)"
assert_eq "$_ft57_scope" "" "every manifest path is inside the backup scope (.github/ or the root list)"

echo ""
echo "== bootstrap resolves visibility from the LIVE repo, not from the flag default =="
# THE DEFECT THIS CATCHES, found by actually RUNNING a cold start rather than
# reading one: `VISIBILITY` defaults to `private` and the bootstrap block reads
# it, while `update_mode` and `add_surface_mode` both resolve from the live repo.
# So a PUBLIC cold start run without `--visibility public` installed
# `composition-private.yml`. That is the D7 / fork-code-on-self-hosted violation
# CLAUDE.md says NEVER to make, arriving via the default value of a flag nobody
# passed. It would extend to `quick-gates-private.yml` — a self-hosted caller
# whose job executes the PR's own files — whenever quick-gates rejoins the
# bootstrap set, which #481 deferred to the combined §C0 change.
VIS_BLK="$(mktemp)"
sed -n '/^# --- visibility, resolved from the LIVE repo/,/^fi$/p' "$INSTALL" > "$VIS_BLK"
assert_ok "[ -s '$VIS_BLK' ]" "the visibility-resolution block was located in install.sh"

_vis_run() {  # $1=gh stdout ("true"/"false"/"" = gh fails) $2=explicit $3=preset -> resolved value or ABORTED
  ( FAKE="$1"
    # These four are read by the SOURCED block below, which shellcheck cannot
    # follow. A `# shellcheck disable=SC2034` did NOT silence it here — the
    # directive did not attach to a multi-assignment line inside a subshell — so
    # the reference is made explicit instead, which is honest either way: `:`
    # marks them as consumed and costs nothing.
    VISIBILITY="${3:-private}"; VISIBILITY_EXPLICIT="$2"; TARGET_REPO="o/r"; MODE_VERIFY=0
    : "$VISIBILITY" "$VISIBILITY_EXPLICIT" "$TARGET_REPO" "$MODE_VERIFY"
    # shellcheck disable=SC2317,SC2329
    gh() { [ -n "$FAKE" ] || return 1; printf '%s\n' "$FAKE"; }
    # shellcheck disable=SC1090
    . "$VIS_BLK" >/dev/null 2>&1
    echo "$VISIBILITY" )
}
# The abort path calls `exit 1` from the SOURCED block, which terminates the
# subshell before any `||` fallback attached to `.` can run — so the refusal has
# to be observed as a STATUS, not as a sentinel on stdout. (Measured: the
# sentinel form reported empty and the assertion read it as a mismatch.)
_vis_rc() { ( _vis_run "$@" ) >/dev/null 2>&1; echo "$?"; }
assert_eq "$(_vis_run false 0)"         "public"  "a PUBLIC repo resolves to public, overriding the private default"
assert_eq "$(_vis_run true 0)"          "private" "a PRIVATE repo resolves to private"
assert_eq "$(_vis_run false 1 private)" "private" "an EXPLICIT --visibility wins over detection"
assert_ok "[ \"$(_vis_rc '' 0)\" -ne 0 ]" "an unreadable repo ABORTS rather than falling back to the default"
assert_eq "$(_vis_rc false 0)" "0" "...while a readable one exits 0"

# ARGUMENT VALIDATION MUST NOT REQUIRE THE NETWORK. An earlier draft placed the
# detection immediately after the `--visibility` value check, so
# `--add-surface X --update` aborted with "could not read visibility" instead of
# "not combinable" — a flags error that needed `gh` to work. Pinned by line
# order so the placement is stated rather than incidental.
_vis_line="$(grep -n '^# --- visibility, resolved from the LIVE repo' "$INSTALL" | cut -d: -f1)"
_tier_line="$(grep -n 'case "\$TIER" in governance' "$INSTALL" | cut -d: -f1)"
assert_ok "[ '${_vis_line:-0}' -gt '${_tier_line:-0}' ]" \
  "visibility detection runs AFTER every pure-argument validation (line ${_vis_line:-?} > ${_tier_line:-?})"
rm -f "$VIS_BLK"

echo "== the bootstrap tier gate has a producer, and installs no unrequired caller (#438/#481) =="
# THE HAZARD: `apply-standards.sh` PUTs the tier branch-protection file as one
# whole payload, so if bootstrap does not install a producer for the context that
# file requires, a COLD START arms a required check nothing satisfies — and
# consumer tiers have no `--admin` escape.
#
# THE INVARIANT IS AN EQUALITY, AND #481 IS WHAT BREAKING IT LOOKS LIKE: the
# caller bootstrap installs and the caller the tier templates require must be the
# SAME ONE. v3 means to move that from `pre-commit.yml` to `quick-gates.yml`, but
# that is two edits — the `auto_install` flag, and PLAN-026 §C0 substituting the
# context into the four tier templates. #441 landed the flag alone, so bootstrap
# installed `quick-gates.yml` while the templates still required pre-commit's
# context, and a cold start bricked. Reverted here until both can land together,
# after C1–C5 put quick-gates.yml on the fleet.
#
# So this drives BOTH directions: the required producer must be installed, and a
# caller no tier requires must NOT be. Each evaluates the SHIPPED block — the
# same harness Part 2 uses, so it cannot drift from what install.sh actually does.
_bootstrap_in() {   # $1=sandbox  $2=visibility ; echoes resolved "template<TAB>dest" lines
  # Also leaves the block's stdout in $TMP/bs-log and its exit status in
  # $TMP/bs-rc. Both are load-bearing: the block's own status used to be
  # discarded by `|| true`, so a stanza that aborted under `set -euo pipefail`
  # was indistinguishable from one that ran — and every ABSENCE claim made
  # against the capture then passed for the wrong reason.
  local sandbox="$1" vis="$2" out="$TMP/bs-out"
  : > "$out"; : > "$TMP/bs-log"
  (
    set -euo pipefail
    cd "$sandbox" || exit 1
    # shellcheck disable=SC2034
    VISIBILITY="$vis"
    # The stub RECORDS the call and also MATERIALISES the destination. Recording
    # alone made every "is the existing file left byte-unchanged" assertion
    # vacuous: nothing in the evaluated block writes to the filesystem, so such a
    # check passed even if the stanza dropped its `[ -f ]` guard entirely.
    # shellcheck disable=SC2317,SC2329
    fetch_template() {
      printf '%s\t%s\n' "$1" "$2" >> "$out"
      mkdir -p "$(dirname "$2")" && printf 'FETCHED %s\n' "$1" > "$2"
    }
    # shellcheck disable=SC1090
    . "$TMP/block.sh" >>"$TMP/bs-log" 2>&1
  ); printf '%s' "$?" > "$TMP/bs-rc"
  cat "$out"
}

# (a) COLD START — nothing installed. The tier gate's producer must land.
_cold="$TMP/bs-cold"; mkdir -p "$_cold/.github/workflows"
_cold_out="$(_bootstrap_in "$_cold" public)"
assert_contains "$_cold_out" ".github/workflows/pre-commit.yml" \
  "cold start installs pre-commit — the producer for the context the tier templates require"
# ASYMMETRIC (§16.9): the PUBLIC variant is the bare name. A `-public` form is a
# file canon does not ship, and `|| exit 1` would abort the install.
assert_contains "$_cold_out" "workflows/pre-commit.yml	" \
  "public cold start resolves the BARE template name, not pre-commit-public.yml"

# (b) PRIVATE cold start resolves the labelled variant, not the generic.
_coldp="$TMP/bs-coldp"; mkdir -p "$_coldp/.github/workflows"
assert_contains "$(_bootstrap_in "$_coldp" private)" "workflows/pre-commit-private.yml" \
  "private cold start resolves the self-hosted variant (D1/OPS-0049)"

# (c) #481, THE OTHER DIRECTION — bootstrap must not install a caller whose
#     context no tier template requires. Asserted against (a)'s output, which
#     assert_contains above has already proven NON-EMPTY: `assert_absent` passes
#     on the empty string, so an absence claim made against an unproven capture
#     is a check that cannot fail.
assert_absent "$_cold_out" ".github/workflows/quick-gates.yml" \
  "cold start does NOT install quick-gates — no tier requires its context yet (#481)"

# (d) An existing caller is a local override — preserved, never re-fetched.
#     Captured to a variable and proven non-empty FIRST, for the same reason (c)
#     is asserted against (a)'s output: `_bootstrap_in` suppresses stderr and
#     swallows the status, so a block that aborted under `set -euo pipefail`
#     yields an empty capture, and an absence claim against it cannot fail.
_done="$TMP/bs-done"; mkdir -p "$_done/.github/workflows"
printf 'local override\n' > "$_done/.github/workflows/pre-commit.yml"
_done_out="$(_bootstrap_in "$_done" public)"
# Anchor on the block's EXIT STATUS and on the stanza under test, not on an
# earlier stanza. `composition` is the SECOND of three (ai-review, composition,
# pre-commit), so its presence proves only that the block got that far — an
# abort anywhere after it would still satisfy it and leave the absence claim
# below passing vacuously. On this sandbox the pre-commit stanza emits a
# `preserve` line rather than a fetch, so the proof of arrival is in the log.
assert_eq "$(cat "$TMP/bs-rc")" "0" \
  "the override sandbox ran clean under set -euo pipefail"
assert_contains "$(cat "$TMP/bs-log")" "preserve  .github/workflows/pre-commit.yml" \
  "the block REACHED the pre-commit stanza and took the preserve branch"
assert_absent "$_done_out" ".github/workflows/pre-commit.yml" \
  "an existing pre-commit.yml is preserved, never re-fetched"
assert_eq "$(cat "$_done/.github/workflows/pre-commit.yml")" "local override" \
  "...and is left byte-unchanged"

echo ""
echo "== every manifested surface has SOME install path (#429) =="
# THE GENERAL FORM OF #429, not a v3 check. A surface reaches a consumer by
# exactly one of three routes: bootstrap (auto_install:true), `--update` (only
# files they ALREADY have), or `--add-surface`. The v3 callers were
# auto_install:false and predated --add-surface, so they had NO route at all —
# manifested, shipped, and uninstallable. Assert the invariant rather than the
# instance, so the next opt-in surface cannot repeat it.
assert_ok "grep -q -- '--add-surface' '$INSTALL'" \
  "install.sh offers --add-surface (the route for auto_install:false surfaces)"
_optin="$(python3 - "$ROOT/install/templates/manifest.json" <<'PYEOF'
import sys, json
m = json.load(open(sys.argv[1], encoding="utf-8"))
print(" ".join(f["path"] for f in m["files"]
                if f.get("template", "").startswith("workflows/")
                and not f.get("auto_install")))
PYEOF
)"
assert_ok "[ -n '$_optin' ]" "found opt-in workflow surfaces to check (got: ${_optin:-none})"
# Resolution-by-path is asserted BEHAVIOURALLY below — the mode is driven with a
# real manifest path and the installed file inspected. An earlier version grepped
# install.sh for the python source string `f["path"] == want`, which is a
# tripwire, not a test: it survives any refactor that keeps the string and breaks
# the logic, and reds on any refactor that changes the string and keeps the logic.

echo ""
echo "== --add-surface: DRIVEN, not grepped =="
# The first version of this block asserted source strings — `grep -q` for the
# never-overwrite message and for a python fragment. Two mutations that each
# disarmed a documented safety property survived it at 124 passed / 0 failed:
# stubbing the collision guard to `if false`, and dropping variant resolution so
# a private consumer gets the ubuntu-latest caller and queues forever (D1). That
# is this file's own doctrine (:20-23) violated in this file: "a test carrying
# its own copy passes happily while the installer rots."
#
# So: run install.sh for real against stubbed `gh` and `curl`. The stubs resolve
# canon templates from THIS working tree, so what is asserted is the installer's
# actual resolution, not a re-implementation.
ASTUB="$TMP/stub"; mkdir -p "$ASTUB"
cat > "$ASTUB/curl" <<'STUBCURL'
#!/usr/bin/env bash
url=""; out=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
src="$REPO_ROOT/install/templates/${url#*/install/templates/}"
[ -f "$src" ] || { echo "stub curl: 404 $url" >&2; exit 22; }
if [ -n "$out" ]; then cp "$src" "$out"; else cat "$src"; fi
STUBCURL
cat > "$ASTUB/gh" <<'STUBGH'
#!/usr/bin/env bash
if [ "$1" = "repo" ] && [ "$2" = "view" ]; then echo "${FAKE_ISPRIVATE:-false}"; exit 0; fi
if [ "$1" = "repo" ] && [ "$2" = "clone" ]; then
  dest="$4"; mkdir -p "$dest/.github/workflows"
  [ -z "${PREEXISTING:-}" ] || printf 'LOCAL EDIT DO NOT CLOBBER
' > "$dest/$PREEXISTING"
  ( cd "$dest" && git init -q . && git config user.email t@t && git config user.name t ) || true
  exit 0
fi
exit 0
STUBGH
chmod +x "$ASTUB/curl" "$ASTUB/gh"

_add_run() {  # $1=isprivate  $2..=extra args ; echoes the WORK_DIR
  local priv="$1"; shift
  local wd; wd="$(mktemp -d "$TMP/wd.XXXXXX")"
  ( cd "$wd" && PATH="$ASTUB:$PATH" REPO_ROOT="$ROOT" FAKE_ISPRIVATE="$priv"       WORK_DIR="$wd" CI_TAG="ci/v9.9.9" bash "$INSTALL" owner/repo "$@" ) >"$wd/out.log" 2>&1
  printf '%s' "$wd"
}

# (a) VARIANT RESOLUTION — the mutation that dropped it survived the old block.
_wd_pub="$(_add_run false --add-surface .github/workflows/quick-gates.yml)"
_wd_priv="$(_add_run true --add-surface .github/workflows/quick-gates.yml)"
# THE runs-on LINE, not the file. `grep -q 'self-hosted'` over the whole file
# PASSED under the dropped-variant mutation, because the PUBLIC template's D7
# comment explains that "the `-private` sibling carries the self-hosted labels".
# An assertion about what runs must see only what runs — this file's own rule,
# and the mutation is what exposed that I had broken it here.
_privline="$(grep -E '^\s*runs-on:' "$_wd_priv/consumer/.github/workflows/quick-gates.yml" || true)"
assert_contains "$_privline" "self-hosted" \
  "--add-surface on a PRIVATE repo installs the self-hosted variant (D1/OPS-0049)"
assert_contains "$_privline" '"ci"' "...naming the real pool label"
assert_absent   "$_privline" "ubuntu-latest" "...and never GitHub-hosted on a private repo"
_publine="$(grep -E '^\s*runs-on:' "$_wd_pub/consumer/.github/workflows/quick-gates.yml" || true)"
assert_contains "$_publine" "ubuntu-latest" "...while the public variant's runner line stays ubuntu-latest"

# (b) NEVER OVERWRITE — the other surviving mutation.
_wd_pre="$(PREEXISTING=.github/workflows/quick-gates.yml _add_run false --add-surface .github/workflows/quick-gates.yml)"
assert_eq "$(cat "$_wd_pre/consumer/.github/workflows/quick-gates.yml")" "LOCAL EDIT DO NOT CLOBBER" \
  "--add-surface leaves an existing file byte-unchanged (FT-9)"
assert_contains "$(cat "$_wd_pre/out.log")" "already present" "...and says it skipped it"

# (c) THE EXECUTABLE BIT, from the manifest. mktemp makes 0600 and mv preserves
# it, so this landed non-executable — and pre-commit's `language: script` canon
# hook cannot exec `pre_push_check.sh`, so every clone failed while the mode
# reported success.
_wd_x="$(_add_run false --add-surface scripts/pre_push_check.sh)"
assert_ok "[ -x '$_wd_x/consumer/scripts/pre_push_check.sh' ]" \
  "--add-surface honours the manifest executable bit (pre-commit language: script)"
assert_ok "[ ! -x '$_wd_pub/consumer/.github/workflows/quick-gates.yml' ]" \
  "...and does not make a non-executable surface executable"

# (d) ARMS NOTHING, and an unknown surface is an ERROR not a silent skip.
assert_absent "$(cat "$_wd_pub/out.log")" "branch protection applied" "--add-surface armed nothing"
assert_contains "$(cat "$_wd_pub/out.log")" "Branch protection and rulesets were NOT touched" \
  "--add-surface says it armed nothing"
_wd_bogus="$(_add_run false --add-surface .github/workflows/not-a-real-surface.yml)"
assert_contains "$(cat "$_wd_bogus/out.log")" "is not a manifested surface" \
  "--add-surface rejects an unknown path loudly"

# (e) THE JOINT-REPLACEMENT WARNING. links.yml is replaced by quick-gates AND
# links-external; naming only one licences a deletion that drops external link
# checking with nothing reporting it.
_wd_j="$(PREEXISTING=.github/workflows/links.yml _add_run false --add-surface .github/workflows/quick-gates.yml)"
assert_contains "$(cat "$_wd_j/out.log")" "replaced JOINTLY by" \
  "--add-surface warns that links.yml is replaced jointly, not by quick-gates alone"
assert_contains "$(cat "$_wd_j/out.log")" "links-external.yml" \
  "...and names the co-requisite by path"
# Standalone. Combining modes makes "what did this run do to my tree?"
# unanswerable, which is the question FT-9 was lost on.
_ax="$(bash "$INSTALL" owner/repo --add-surface .github/workflows/quick-gates.yml --update 2>&1 || true)"
assert_contains "$_ax" "not combinable" "--add-surface refuses to combine with --update"
_ax2="$(bash "$INSTALL" owner/repo --add-surface .github/workflows/quick-gates.yml --repin 2>&1 || true)"
assert_contains "$_ax2" "not combinable" "--add-surface refuses to combine with --repin"

echo ""
echo '== the duplicate-run warning has real targets (manifest replaces) =='
# Adding v3 while the v2 callers it replaces are installed runs BOTH — doubled
# jobs on a serial self-hosted pool. The warning is only as good as the mapping,
# and a `replaces` entry naming a file canon does not ship would warn about
# nothing, forever, with nobody the wiser.
_repl_bad="$(python3 - "$ROOT/install/templates/manifest.json" "$ROOT" <<'PYEOF'
import sys, json, os
m = json.load(open(sys.argv[1], encoding="utf-8"))
root = sys.argv[2]
known = {f["path"] for f in m["files"]}
bad = []
for f in m["files"]:
    for r in f.get("replaces") or []:
        # A replaced caller is either still manifested, or a template canon
        # still ships (v2 callers stay shippable through the migration).
        base = os.path.basename(r)
        if r not in known and not os.path.exists(os.path.join(root, "install/templates/workflows", base)):
            bad.append("%s->%s" % (f["path"], r))
print(",".join(sorted(bad)))
PYEOF
)"
assert_eq "$_repl_bad" "" "every \`replaces\` entry names a caller canon actually ships"
_repl_v3="$(python3 - "$ROOT/install/templates/manifest.json" <<'PYEOF'
import sys, json
m = json.load(open(sys.argv[1], encoding="utf-8"))
print(" ".join(sorted(f["path"] for f in m["files"] if f.get("replaces"))))
PYEOF
)"
assert_eq "$_repl_v3" \
  ".github/workflows/links-external.yml .github/workflows/quick-gates.yml .github/workflows/scanners.yml" \
  "the three consolidating callers declare what they replace"

echo ""
echo "== hard dependencies are preflighted BEFORE anything mutates =="
# install.sh's own header states "Requires: gh … + curl + git + python3" and
# checked only `gh`, at :1531 — more than a thousand lines after it clones the
# target and writes the pre-write backup. A host without python3 therefore
# mutated a real repo and then died inside substitute_placeholders with a bare
# `python3: command not found`. Drive it with a PATH that has every OTHER
# dependency, so a pass cannot come from the script failing for some other reason.
_pfbin="$(mktemp -d)"
for _b in gh curl git bash sed grep cat mktemp; do
  _r="$(command -v "$_b" 2>/dev/null)" && ln -sf "$_r" "$_pfbin/$_b"
done
_pf_out="$(PATH="$_pfbin" bash "$ROOT/install/install.sh" owner/repo 2>&1; echo "rc=$?")"
assert_contains "$_pf_out" "requires: python3" "install.sh refuses when python3 is absent, naming it"
assert_contains "$_pf_out" "rc=1" "  and exits non-zero"
# The point is that it refuses EARLY. If it had reached the network/clone path it
# would have printed the visibility ABORT or a gh error instead.
assert_absent "$_pf_out" "could not read" "  and refuses BEFORE the first network call (no partial install)"
# Negative control: with a complete PATH it must NOT trip the dependency guard,
# or the assertion above is satisfied by a script that refuses unconditionally.
# NEGATIVE CONTROL, WITHOUT A NETWORK CALL. This originally ran
# `install.sh owner/repo` with a complete PATH, which clears the preflight and
# proceeds to `gh repo view owner/repo` — a live API call on every suite run
# (so: offline-flaky), whose safety rested entirely on `github.com/owner/repo`
# not resolving. If it ever resolves for whoever is running the suite, the
# installer clones that repo and creates ~21 labels on it.
#
# Prove the same property by stopping at ARGUMENT VALIDATION instead: mutually
# exclusive flags are rejected at install.sh:152, before any network call. The
# run got past the dependency guard iff it reached that message.
_pf_ok="$(bash "$ROOT/install/install.sh" owner/repo --update --repin 2>&1 || true)"
assert_absent "$_pf_ok" "not found on PATH" "  a complete PATH does NOT trip the dependency guard"
assert_contains "$_pf_ok" "mutually exclusive" "  ...and it reached ARGUMENT validation, i.e. the guard passed rather than the run dying early"
assert_absent "$_pf_ok" "could not read" "  ...without making a network call (the control must not touch a live repo)"
rm -rf "$_pfbin"

echo ""
echo "== --add-surface pulls .github/actionlint.yaml for a literal self-hosted caller =="
# v3 callers carry `runs-on: ["self-hosted","ci","ephemeral"]` LITERALLY (v2
# passed labels as a string input, so actionlint saw only an expression).
# actionlint rejects labels it does not know, so without `.github/actionlint.yaml`
# every private v3 caller fails the consumer's own `pre_push_check.sh` check 3 —
# and the manifest entry for that file said "manifest entry + install.sh fetch"
# while carrying `auto_install: false`, delivering nothing. Assert the DEPENDENCY
# exists in add_surface_mode and is conditioned on the literal label, not on a
# hardcoded filename list that the next such caller would fall outside of.
# ANCHOR TO THE NEW BLOCK, not to `add_surface_mode` as a whole. Two of the
# three original assertions could not fail: `add_surface_mode` ALREADY contained
# "self-hosted" (a comment about doubled jobs on a serial pool) and
# "validate_fetched" (the pre-existing template fetch), so both passed with the
# entire actionlint dependency deleted. An assertion satisfied by code it is not
# about is not covering that code.
_as_blk="$(awk '/^add_surface_mode\(\) \{/,/^\}/' "$ROOT/install/install.sh")"
_as_len="${#_as_blk}"
assert_ok "[ \"$_as_len\" -gt 500 ]" "add_surface_mode was located in install.sh (${_as_len} chars)"
_dep_blk="$(printf '%s\n' "$_as_blk" | sed -n '/DEPENDENCY: a caller with a LITERAL self-hosted/,/^  done$/p')"
_dep_len="${#_dep_blk}"
assert_ok "[ \"$_dep_len\" -gt 200 ]" "  the actionlint dependency block was located (${_dep_len} chars)"
assert_contains "$_dep_blk" 'TEMPLATE_BASE}/actionlint.yaml' "  it FETCHES the config (not merely mentions the filename)"
assert_contains "$_dep_blk" 'validate_fetched "$alcfg"' "  and validates THAT fetch (FT-39: no empty/HTML 200 over a config)"
_dep_code="$(printf '%s\n' "$_dep_blk" | grep -vE '^[[:space:]]*#' || true)"
assert_contains "$_dep_code" "self-hosted" "  gated on the caller carrying a literal self-hosted runs-on: (in CODE, not a comment)"

echo ""
echo "== the zero-hook detector is VALIDATED before it is executed (FT-39 ∩ FT-31) =="
# This body is FETCHED over the network and then `bash`ed. `curl -f` rejects a
# 4xx/5xx but a proxy/CDN/captive portal answers 200 with HTML — and an empty or
# HTML file bashes to rc 0, so the detector silently became a no-op and the F3
# vacuous-gate advisory NEVER fired. Every other fetched asset goes through
# validate_fetched; the one that is EXECUTED did not.
_zh_blk="$(awk '/PLAN-018 FT-31 — the zero-hook detector/,/^# Canonical labels/' "$ROOT/install/install.sh")"
_zh_len="${#_zh_blk}"
assert_ok "[ \"$_zh_len\" -gt 400 ]" "the zero-hook detector block was located (${_zh_len} chars)"
assert_contains "$_zh_blk" "validate_fetched" \
  "the fetched detector is validated before it is executed (an HTML 200 would otherwise run as a no-op)"
# And the detector's own shebang must satisfy the marker the installer requires,
# or validation rejects the real file and the advisory is skipped every run.
assert_ok "grep -qE '^#!.*(bash|sh)' '$ROOT/install/check-precommit-hooks.sh'" \
  "check-precommit-hooks.sh carries the shebang the installer's marker requires"
# rc 2 (cannot determine) was discarded outright, making "could not check" look
# identical to "checked and clean".
assert_contains "$_zh_blk" "could not determine" \
  "rc 2 (no PyYAML / unparseable) is REPORTED, not silently read as a pass"

suite_summary "test_install"
