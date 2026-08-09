#!/usr/bin/env bash
# tests/test_sigpipe_guard.sh — CI-0033. The OPS-0069 audit-trail gate must not
# decide anything on the exit status of a pipeline feeding `grep -q`.
#
# The defect (#417, observed on PR #416): `grep -q` exits the instant it
# matches, the writer takes EPIPE (141), and `set -o pipefail` hands the
# pipeline that 141 — so a MATCH is reported as a miss and the gate reds a PR
# whose evidence is present. What decides it is whether the WRITER has finished
# issuing its writes, not the payload size: a single-`write` builtin is clean at
# 40 KB while a multi-write process inverts at 8 KB. PR #416's 38 KB `echo`
# fired in the runner and not on a dev laptop, which is why "I tested the real
# payload" was not evidence of absence.
#
# Two layers here, because either alone is weak:
#   1. BEHAVIOURAL — run the workflow's real `run:` block against a throwaway
#      git repo whose range is far larger than any pipe buffer, and require a
#      PASS. This exercises shipped code, not a paraphrase of it.
#   2. STRUCTURAL — the construct must not reappear anywhere in the scope
#      REPO_STANDARDS §27.2 declares. This half GLOBS that scope rather than
#      listing files: the first draft hand-listed four files while the rule
#      declared four directories, and that gap is exactly how eleven fail-open
#      instances stayed invisible. The behavioural layer cannot catch a
#      reintroduction on a path it does not walk.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
cd "$ROOT" || exit 1

WF=".github/workflows/audit-trail-check.yml"
T="$(mktemp -d)"
# Each handler must exit itself: a `trap` that only cleans up lets bash RESUME,
# which deletes the temp dir out from under the still-running test (CLAUDE.md).
trap 'rm -rf "$T"' EXIT
trap 'rm -rf "$T"; exit 130' INT
trap 'rm -rf "$T"; exit 143' TERM

echo "== CI-0033: audit-trail gate survives a range larger than any pipe buffer =="

# --- extract the shipped run: block ------------------------------------------
# Fails CLOSED: an extractor that yields empty must abort, never hand the
# assertions an empty string they would happily pass against.
python3 - "$WF" "$T/step.sh" <<'PY' || { echo "  FAIL could not extract run: block from $WF"; exit 1; }
import sys, yaml
wf, out = sys.argv[1], sys.argv[2]
d = yaml.safe_load(open(wf, encoding="utf-8"))
steps = d["jobs"]["verify"]["steps"]
run = [s["run"] for s in steps if "run" in s]
assert len(run) == 1, f"expected exactly 1 run: step, got {len(run)}"
body = run[0]
assert "OPS-0069 phrase" in body, "extracted block is not the audit-trail check"
assert len(body) > 500, f"extracted block implausibly short ({len(body)} bytes)"
open(out, "w", encoding="utf-8").write(body)
PY
[ -s "$T/step.sh" ] || { echo "  FAIL extracted step script is empty"; exit 1; }

# --- a throwaway repo whose commit range dwarfs the 64 KiB pipe buffer -------
# 4 MiB of filler after the phrase. `grep -q` matches in the first read and
# exits; the writer is then guaranteed to still be mid-write, so the buggy
# shape takes EPIPE deterministically on any host. The fixed shape has no pipe.
REPO="$T/repo"
git init -q "$REPO"
git -C "$REPO" config user.email t@example.com
git -C "$REPO" config user.name  Test
git -C "$REPO" commit -q --allow-empty -m "base"
BASE="$(git -C "$REPO" rev-parse HEAD)"

{
  printf 'fix: a change with the audit-trail phrase early in the body\n\n'
  printf 'Multi-agent self-review per OPS-0065 (code-reviewer): no findings.\n\n'
  head -c $((4 * 1024 * 1024)) /dev/zero | tr '\0' 'x'
  printf '\n'
} > "$T/msg"
git -C "$REPO" commit -q --allow-empty -F "$T/msg"
HEAD_="$(git -C "$REPO" rev-parse HEAD)"

range_bytes="$(git -C "$REPO" log --format=%B "$BASE..$HEAD_" | wc -c)"
assert_ok "[ '$range_bytes' -gt $((1024 * 1024)) ]" \
  "fixture range is $((range_bytes / 1024)) KB — well past any pipe buffer"

run_gate() { # $1 = PR_LABELS json
  ( cd "$REPO" && \
    BASE_SHA="$BASE" HEAD_SHA="$HEAD_" PR_LABELS="$1" \
    PR_USER_TYPE="User" PR_USER_LOGIN="someone" \
    bash "$T/step.sh" 2>&1 )
}

OUT="$(run_gate '[]')"; rc=$?
assert_eq "$rc" "0" "gate PASSES on a 4 MB range whose phrase is present (the #417 regression)"
assert_contains "$OUT" "OPS-0069 phrase present in range" "gate reports the phrase as found"
assert_absent "$OUT" "no OPS-0069 phrase found" "gate does not emit the false-negative error"
# NB: no assertion on a "Broken pipe" diagnostic. Mutation-tested — it passes
# against the BUGGY shape too, because whether bash reports EPIPE or the writer
# just dies on SIGPIPE is platform-dependent. An assertion that cannot fail on
# the defect is not coverage, and leaving it in would read as if it were.

# --- fail-closed direction still works ---------------------------------------
# A gate that passes everything would satisfy the assertions above. Prove it
# still REFUSES a range with no phrase, at the same size.
REPO2="$T/repo2"
git init -q "$REPO2"
git -C "$REPO2" config user.email t@example.com
git -C "$REPO2" config user.name  Test
git -C "$REPO2" commit -q --allow-empty -m "base"
BASE2="$(git -C "$REPO2" rev-parse HEAD)"
{
  printf 'fix: a change with NO audit-trail phrase anywhere in the body\n\n'
  head -c $((4 * 1024 * 1024)) /dev/zero | tr '\0' 'x'
  printf '\n'
} > "$T/msg2"
git -C "$REPO2" commit -q --allow-empty -F "$T/msg2"
HEAD2="$(git -C "$REPO2" rev-parse HEAD)"

OUT2="$( cd "$REPO2" && \
  BASE_SHA="$BASE2" HEAD_SHA="$HEAD2" PR_LABELS='[]' \
  PR_USER_TYPE="User" PR_USER_LOGIN="someone" \
  bash "$T/step.sh" 2>&1 )"; rc2=$?
assert_eq "$rc2" "1" "gate still FAILS a large range with no phrase (not pass-everything)"
assert_contains "$OUT2" "no OPS-0069 phrase found" "refusal names the missing phrase"

# --- the two-signal override reads the same string ---------------------------
# Before CI-0033 the body-marker probe was its own `git log | grep -qF`, so the
# documented escape hatch inverted at exactly the sizes the gate did — the
# remedy the error message recommends would itself have silently failed.
REPO3="$T/repo3"
git init -q "$REPO3"
git -C "$REPO3" config user.email t@example.com
git -C "$REPO3" config user.name  Test
git -C "$REPO3" commit -q --allow-empty -m "base"
BASE3="$(git -C "$REPO3" rev-parse HEAD)"
{
  printf 'chore: an exempt change\n\n[skip-audit-trail]\n\n'
  head -c $((4 * 1024 * 1024)) /dev/zero | tr '\0' 'x'
  printf '\n'
} > "$T/msg3"
git -C "$REPO3" commit -q --allow-empty -F "$T/msg3"
HEAD3="$(git -C "$REPO3" rev-parse HEAD)"

OUT3="$( cd "$REPO3" && \
  BASE_SHA="$BASE3" HEAD_SHA="$HEAD3" PR_LABELS='["skip-audit-trail"]' \
  PR_USER_TYPE="User" PR_USER_LOGIN="someone" \
  bash "$T/step.sh" 2>&1 )"; rc3=$?
assert_eq "$rc3" "0" "two-signal override engages on a 4 MB range"
assert_contains "$OUT3" "two-signal override" "override is the stated reason, not an accidental pass"

# One signal only must NOT exempt. Both of these must fail for the RIGHT reason:
# a bare exit 1 could also come from the gate erroring out, so assert on the
# message too rather than on the status alone.
OUT4="$( cd "$REPO3" && \
  BASE_SHA="$BASE3" HEAD_SHA="$HEAD3" PR_LABELS='[]' \
  PR_USER_TYPE="User" PR_USER_LOGIN="someone" \
  bash "$T/step.sh" 2>&1 )"; rc4=$?
assert_eq "$rc4" "1" "body marker alone does not exempt (both signals required)"
assert_contains "$OUT4" "no OPS-0069 phrase found" "…and it is the phrase check that refuses it"

# `skip-audit-trail-later` must not satisfy the label signal via substring.
OUT5="$( cd "$REPO3" && \
  BASE_SHA="$BASE3" HEAD_SHA="$HEAD3" PR_LABELS='["skip-audit-trail-later"]' \
  PR_USER_TYPE="User" PR_USER_LOGIN="someone" \
  bash "$T/step.sh" 2>&1 )"; rc5=$?
assert_eq "$rc5" "1" "a label merely PREFIXED skip-audit-trail does not exempt"
assert_contains "$OUT5" "no OPS-0069 phrase found" "…and it is the phrase check that refuses it"

# --- no jq: the override is REFUSED, not approximated -------------------------
# CI-0033 changed that branch and every case above takes the `jq` path, so
# without this the change has structural coverage only. Whether a label is
# present is an authorization decision; the only jq-free way to make it is a
# substring test over JSON-escaped text, which a label named `", "skip-audit-trail`
# defeats. So the branch now declines the override and lets the phrase check
# run. Fail-closed in the direction that matters: the gate still works, only
# the EXEMPTION is unavailable.
PRETTY_LABELS=$'[\n  "bug",\n  "skip-audit-trail"\n]'
nojq="$T/nojq"; mkdir -p "$nojq"
for tool in git bash sed grep; do
  src="$(command -v "$tool")" && ln -sf "$src" "$nojq/$tool"
done
run_nojq() { # $1 = PR_LABELS
  ( cd "$REPO3" && PATH="$nojq" \
    BASE_SHA="$BASE3" HEAD_SHA="$HEAD3" PR_LABELS="$1" \
    PR_USER_TYPE="User" PR_USER_LOGIN="someone" \
    bash "$T/step.sh" 2>&1 )
}
assert_fail "PATH='$nojq' command -v jq" "fixture PATH really has no jq (else this proves nothing)"

# Both signals genuinely present, and it STILL must not exempt without jq.
OUT6="$(run_nojq "$PRETTY_LABELS")"; rc6=$?
assert_eq "$rc6" "1" "no jq: a real skip-audit-trail label does NOT engage the override"
assert_contains "$OUT6" "jq not found" "…and the runner is told why the override is unavailable"
assert_absent "$OUT6" "SKIPPED per PLAN-002" "…the override did not silently engage (the help text mentions it; the NOTICE is the tell)"
assert_contains "$OUT6" "no OPS-0069 phrase found" "…the phrase check still ran and decided"

# The forged-label case the substring test could not have distinguished.
OUT7="$(run_nojq $'[\n  "x\\", \\"skip-audit-trail"\n]')"; rc7=$?
assert_eq "$rc7" "1" "no jq: a label CRAFTED to contain the JSON-escaped pattern does not exempt"
assert_absent "$OUT7" "SKIPPED per PLAN-002" "…and the forged label engaged nothing"

# And with jq present the override still works — this branch is not a regression
# of the exemption itself, only of the jq-free approximation of it.
assert_ok "command -v jq" "jq present on this host, so the jq path above was the one exercised"

echo
echo "== structural: the shape must not reappear on any OPS-0069 surface =="
# `grep -q` is fine when nothing is piped INTO it (reading a file is safe: no
# writer to signal). What must never return is `… | grep -q…`.
#
# Comment lines are stripped first, and deliberately so: every one of these
# files now carries a comment NAMING the banned shape so the next reader learns
# why it is banned. A check that cannot tell code from the prose warning
# against it would force those warnings to be deleted to stay green.
code_only() { sed -E 's/^[[:space:]]*#.*$//' "$1"; }

# The pattern covers every spelling that makes `grep` leave before EOF, not just
# `-q`. Each of these was verified to evade the first version of this regex:
#   … | grep --quiet     (long form)
#   … | grep -F -q       (q outside the first option cluster)
#   … | grep -m1         (exits after N matches — same mechanism, no -q at all)
#   … | grep --max-count=1  (long form of -m; measured to evade the -m branch)
#   … | grep --silent    (GNU documents it as an exact synonym for -q)
# NOT banned, and the reason is recorded so it is not re-litigated: `grep -l`
# also stops at the first match per input, but its output is the FILENAME, so a
# `… | grep -l` on a pipe is `(standard input)` — a shape with no legitimate use
# here and no instance in the tree. It is left out rather than guessed at.
BANNED_RE='\|[[:space:]]*grep([[:space:]]+-[^|]*)?[[:space:]]+(-[a-zA-Z]*q|--quiet|--silent|-m[[:space:]]*[0-9]|--max-count[[:space:]=]*[0-9])'

# SCOPE = what §27.2 declares mandatory, not a hand-listed four. A guard whose
# list is narrower than the rule it enforces is why ai-review.yml and
# secret-scan.yml sat unflagged through this defect's whole lifetime.
# §27.2 declares four DIRECTORIES. Glob each one WHOLE — every depth, and every
# extension that can carry a shell pipeline (`*.sh`/`*.bash`, and the YAML that
# embeds `run:` bodies). Three narrower spellings have each been measured to let
# a planted construct through: `ls .github/workflows/*.yml` (depth-1, .yml only)
# missed `zz-probe.yaml`; `ls scripts/*.sh` missed `scripts/doc-maintainer/`;
# `actions/*/action.yml` missed both an `action.yaml` rename and a depth-3
# action, because the "check" on it carried the same two assumptions.
# NOTE the exact extension list is the contract §27.2 states — widen BOTH
# together or the rulebook claims a coverage the guard does not have.
SURFACE_DIRS=(.github/workflows scripts install/templates actions)
_surface_files() { find "$1" -type f \( -name '*.sh' -o -name '*.bash' -o -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort; }

mapfile -t GUARDED < <(
  for _d in "${SURFACE_DIRS[@]}"; do _surface_files "$_d"; done
  echo tests/lib.sh
)
[ "${#GUARDED[@]}" -ge 20 ] || _r "guard scope collapsed to ${#GUARDED[@]} files — expected 20+"

# PER-SURFACE FLOORS, asserted against GUARDED — the PRODUCT — not against the
# arrays that feed it. The previous version asserted a floor on its own private
# enumeration, so deleting the line that copies that enumeration INTO `GUARDED`
# left six action files unscanned with the suite fully green (measured: 111 → 105
# passed, 0 failed). A floor that does not police the array actually iterated is
# not a floor. The total floor cannot substitute: 20+ is met by
# .github/workflows/ alone, so any one surface can vanish beneath it.
for _d in "${SURFACE_DIRS[@]}"; do
  _in_scope=0
  for _f in "${GUARDED[@]}"; do case "$_f" in "$_d"/*) _in_scope=$((_in_scope + 1)) ;; esac; done
  _on_disk="$(_surface_files "$_d" | wc -l)"
  assert_ok "[ $_on_disk -ge 1 ]" "§27.2 surface $_d/ exists and is non-empty"
  assert_eq "$_in_scope" "$_on_disk" "every globbable file under $_d/ reached guard scope (§27.2)"
done

# PIN THE SURFACE LIST. Every check above iterates `SURFACE_DIRS`, so deleting
# an entry deletes its own floor — measured: dropping `actions` and planting the
# construct in a real action file left the suite at 111 passed, 0 failed. A list
# that supplies both the work and the check on the work cannot detect its own
# truncation. This pin is the one statement that does not come from the list.
# Changing the scope means editing this string AND §27.2 in the same commit,
# which is the intended cost.
assert_eq "${SURFACE_DIRS[*]}" ".github/workflows scripts install/templates actions" \
  "the §27.2 surface list is exactly the four directories the rulebook declares"

mapfile -t ACTION_FILES < <(find actions -type f \( -name 'action.yml' -o -name 'action.yaml' \) 2>/dev/null | sort)

# ...and the same question asked from a SEPARATE enumeration, so it survives any
# edit to SURFACE_DIRS: every composite action file on disk must be in GUARDED.
for _f in "${ACTION_FILES[@]}"; do
  case " ${GUARDED[*]} " in
    *" $_f "*) ;;
    *) _r "composite action is on disk but not in guard scope: $_f" ;;
  esac
done

# INDEPENDENT ORACLE. The floors above are derived from the same glob they check,
# so they catch a surface leaving scope but share the glob's blind spots. This
# asks a different question of a different file set: every composite action canon
# actually INVOKES must resolve to a guarded file. An action is reachable only by
# a `uses:`, so an unguarded one shows up here even when the glob misses it.
# Callers write `vladm3105/aidoc-flow-ci/actions/<name>@ci/vX.Y.Z`, NOT
# `./actions/<name>` — the owner/repo form is what a consumer installs. A
# `./actions/`-only pattern matched zero files and made this whole oracle vacuous
# while printing nothing, so its input is asserted non-empty below: an oracle
# that silently examines an empty set is the failure mode it was added to catch.
mapfile -t USED_ACTIONS < <(
  grep -rhoE 'uses:[[:space:]]*(\./|[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/)actions/[A-Za-z0-9._/-]+' \
    .github/workflows install/templates actions 2>/dev/null |
    sed -E 's#.*/actions/##' | sort -u
)
assert_ok "[ ${#USED_ACTIONS[@]} -ge 1 ]" \
  "the invoked-action oracle found at least one \`uses:\` to check"
for _a in "${USED_ACTIONS[@]}"; do
  _found=""
  for _f in "${ACTION_FILES[@]}"; do
    case "$_f" in "actions/$_a/action.yml" | "actions/$_a/action.yaml") _found=1 ;; esac
  done
  assert_eq "$_found" "1" "invoked action actions/$_a resolves to a guarded action file"
done

# ALLOWLIST: sites where the construct cannot invert, each with the reason.
# An entry here is a claim that must stay true; it is not a way to silence a hit.
banned_allowed() {
  case "$1" in
    # Runs inside `sh -c` in a container with no `pipefail`, so the pipeline's
    # status is grep's alone and EPIPE on the writer cannot be observed.
    install/templates/runner/build-image.sh) return 0 ;;
    *) return 1 ;;
  esac
}

for f in "${GUARDED[@]}"; do
  # A missing/unreadable file must FAIL, not pass. `|| true` below absorbs
  # grep's no-match exit 1 — it would equally absorb sed's ENOENT, so a renamed
  # file would silently report "clean" for a file never opened.
  if [ ! -s "$f" ]; then _r "guard target missing or empty: $f"; continue; fi
  banned_allowed "$f" && continue
  hits="$(code_only "$f" | grep -nE "$BANNED_RE" || true)"
  # Label with the full path: two of the guarded files share a basename.
  # Label names exactly what BANNED_RE covers. `head -N` / `sed …q` / `awk …exit`
  # are the same mechanism but are NOT banned: `| head -1` for DISPLAY is
  # legitimate and blanket-banning it across 33 files would be wrong. What is
  # banned is an early-exiting GREP on the right of a pipe.
  assert_eq "$hits" "" "$f: no piped grep -q/--quiet/-m<N> (CI-0033)"
done

# Guard the guard. These probes are pipe-free on purpose — a probe written in
# the very construct under test can be satisfied BY an inversion (`assert_fail`
# passes on any non-zero status, and 141 is non-zero).
probe_hits() { code_only "$1" | grep -cE "$BANNED_RE" || true; }
probe="$T/probe.sh"
printf '%s\n' 'echo "$x" | grep -qF "y"' > "$probe"
assert_eq "$(probe_hits "$probe")" "1" "stripper still sees a real piped grep -q"
printf '%s\n' '  # never write echo "$x" | grep -qF "y"' > "$probe"
assert_eq "$(probe_hits "$probe")" "0" "stripper ignores the shape inside a comment"
printf '%s\n' 'echo "$x" | grep --quiet y' > "$probe"
assert_eq "$(probe_hits "$probe")" "1" "long-form --quiet is caught"
printf '%s\n' 'echo "$x" | grep -F -q y' > "$probe"
assert_eq "$(probe_hits "$probe")" "1" "q outside the first option cluster is caught"
printf '%s\n' 'echo "$x" | grep -m1 y' > "$probe"
assert_eq "$(probe_hits "$probe")" "1" "-m1 is caught (exits early with no -q)"
# These three spellings were unprobed, so a weakening of BANNED_RE that broke
# them survived every probe. -Fq and -m 1 were already caught by the shipped
# regex; --max-count=1 was NOT, and is the reason for the new alternation branch.
printf '%s\n' 'echo "$x" | grep -Fq y' > "$probe"
assert_eq "$(probe_hits "$probe")" "1" "q LAST in the option cluster is caught"
printf '%s\n' 'echo "$x" | grep -m 1 y' > "$probe"
assert_eq "$(probe_hits "$probe")" "1" "-m with a separated argument is caught"
printf '%s\n' 'echo "$x" | grep --max-count=1 y' > "$probe"
assert_eq "$(probe_hits "$probe")" "1" "--max-count=1 is caught (long form of -m)"
printf '%s\n' 'echo "$x" | grep --silent y' > "$probe"
assert_eq "$(probe_hits "$probe")" "1" "--silent is caught (GNU synonym for -q)"
printf '%s\n' 'grep -q needle somefile.txt' > "$probe"
assert_eq "$(probe_hits "$probe")" "0" "grep -q READING A FILE is not flagged (no writer to signal)"

# The two pre_push_check copies must not drift apart on this fix.
canon_hunk="$(sed -n '/for phrase in "Multi-agent self-review per OPS-0065"/,/esac/p' scripts/pre_push_check.sh)"
tmpl_hunk="$(sed -n '/for phrase in "Multi-agent self-review per OPS-0065"/,/esac/p' install/templates/pre_push_check.sh)"
assert_ok "[ -n \"\$(printf '%s' \"\$canon_hunk\")\" ]" "canon pre_push_check phrase loop located"
assert_eq "$canon_hunk" "$tmpl_hunk" "scripts/ and install/templates/ pre_push_check phrase loops are identical"

suite_summary "test_sigpipe_guard"
