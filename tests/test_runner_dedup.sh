#!/usr/bin/env bash
# tests/test_runner_dedup.sh — CI-0033 behavioral teeth for the runner-pool
# templates (PLAN-031 Phase A).
#
# WHY THIS EXISTS ALONGSIDE test_sigpipe_guard.sh. That suite is a LINT walk:
# it greps for an early-exiting `grep` on the right of a pipe. It caught the
# three violations in manage.sh/monitor.sh, but it cannot tell a correct
# rewrite from a wrong-but-clean one — `case` with misplaced delimiters has no
# pipe and passes it silently. This suite executes the shipped dedup and
# asserts what it DOES.
#
# THE DISCRIMINATOR IS SIZE, not correctness on toy input. The defect class is
# that `echo "$accumulator" | grep -qF "$needle"` only inverts once the
# accumulator outgrows the pipe buffer (64 KiB), because that is when `echo` is
# still writing as `grep -q` exits and takes EPIPE. So every scenario here
# runs TWICE: small (where even the buggy form passed) and >64 KiB (where it
# did not). A fix that is right only at small sizes fails the second run.
#
# Both drivers SOURCE THE SHIPPED FILE (minus its trailing `main "$@"`), so
# these assertions break if the real code changes — they are not a re-typed
# copy of the logic under test.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
cd "$ROOT" || exit 1

MANAGE="$ROOT/install/templates/runner/manage.sh"
MONITOR="$ROOT/install/templates/runner/monitor.sh"

T="$(mktemp -d)"
trap 'rm -rf "$T"; exit 130' INT
trap 'rm -rf "$T"; exit 143' TERM
trap 'rm -rf "$T"' EXIT

for pair in "manage:$MANAGE" "monitor:$MONITOR"; do
  name="${pair%%:*}"; src="${pair#*:}"
  [ -f "$src" ] || { _r "$name: shipped template missing at $src"; continue; }
  # Fail CLOSED: a stripper that silently produced an empty file would leave
  # every driver sourcing nothing and reporting a clean 0, which reads as a
  # pass. Assert the library really carries the function under test.
  sed '$d' "$src" > "$T/${name}_lib.sh"
  assert_ok "[ -s '$T/${name}_lib.sh' ]" "$name: library copy is non-empty after stripping main"
  assert_absent "$(cat "$T/${name}_lib.sh")" 'main "$@"' \
    "$name: the trailing main dispatch was stripped (sourcing must not execute)"
done

# --- scenario builder -------------------------------------------------------
# Creates a real ENV_DIR of <inst>.env files so `instance_repo` /
# `discover_repos` exercise their actual read path (grep -m1 TARGET_REPO= | cut)
# rather than a stub.
#   $1 = env dir; $2 = number of DISTINCT repos; $3 = number of REPEAT instances
#        appended afterwards (each duplicating an early repo); $4 = repo-name
#        padding length (drives the accumulator past the pipe buffer)
_mk_env() {
  local dir="$1" distinct="$2" repeats="$3" pad="$4"
  rm -rf "$dir"; mkdir -p "$dir"
  local filler=""
  while [ "${#filler}" -lt "$pad" ]; do filler="${filler}pad-segment-"; done
  local i
  for ((i = 0; i < distinct; i++)); do
    printf 'TARGET_REPO=org/repo-%04d-%s\n' "$i" "$filler" > "$dir/inst-$i.env"
  done
  # Repeats reference DISTINCT-LATER instances but reuse EARLY repo names, so a
  # working dedup must skip them and a broken one must re-query them.
  for ((i = 0; i < repeats; i++)); do
    printf 'TARGET_REPO=org/repo-%04d-%s\n' "$((i % 5))" "$filler" \
      > "$dir/repeat-$i.env"
  done
}

# Drives manage.sh cmd_status with the network/systemd edges stubbed, printing
# the number of API queries it made. list_instances is overridden to enumerate
# the env dir (the real one shells out to systemctl); instance_repo and the two
# counters are the shipped code path.
_run_manage() { # $1 = lib; $2 = env dir; $3 = counter file
  cat > "$T/drive_manage.sh" <<DRV
#!/usr/bin/env bash
ENV_DIR="$2"
QUERIES="$3"
. "$1"
: > "\$QUERIES"
list_instances() {
  local f
  for f in "\$ENV_DIR"/*.env; do basename "\$f" .env; done
}
systemctl() { printf 'active\n'; }
count_queued_jobs()  { printf 'q\n' >> "\$QUERIES"; printf '0\n'; }
count_running_jobs() { printf '0\n'; }
cmd_status > /dev/null
wc -l < "\$QUERIES" | tr -d ' '
DRV
  bash "$T/drive_manage.sh" 2>/dev/null
}

# Drives monitor.sh discover_repos over the same env dir, printing how many
# repo lines it emits.
_run_monitor() { # $1 = lib; $2 = env dir
  cat > "$T/drive_monitor.sh" <<DRV
#!/usr/bin/env bash
ENV_DIR="$2"
. "$1"
discover_repos | wc -l | tr -d ' '
DRV
  bash "$T/drive_monitor.sh" 2>/dev/null
}

echo ""
echo "== manage.sh cmd_status dedups one API query per distinct repo =="
# pad 120 keeps the small case far under 64 KiB; pad 260 x 320 distinct pushes
# repos_seen past it (~83 KiB), which is where the piped form inverted.
for scenario in "small:12:8:40" "large:320:40:260"; do
  label="${scenario%%:*}"; rest="${scenario#*:}"
  IFS=: read -r distinct repeats pad <<< "$rest"
  dir="$T/env_manage_$label"
  _mk_env "$dir" "$distinct" "$repeats" "$pad"
  cnt="$T/queries_$label"
  got="$(_run_manage "$T/manage_lib.sh" "$dir" "$cnt")"
  # Distinct repos only: the `repeats` instances duplicate repo 0..4 and must
  # be skipped entirely.
  assert_eq "$got" "$distinct" \
    "manage.sh [$label]: queried exactly $distinct repos (got '$got') — repeats skipped"
  accsize=$(( (distinct + repeats) * (pad + 24) ))
  if [ "$label" = large ]; then
    assert_ok "[ $accsize -gt 65536 ]" \
      "manage.sh [$label]: accumulator exceeded the 64 KiB pipe buffer (~$((accsize / 1024)) KiB) — the size discriminator is live"
  fi
done

echo ""
echo "== monitor.sh discover_repos emits each repo once =="
for scenario in "small:12:8:40" "large:320:40:260"; do
  label="${scenario%%:*}"; rest="${scenario#*:}"
  IFS=: read -r distinct repeats pad <<< "$rest"
  dir="$T/env_monitor_$label"
  _mk_env "$dir" "$distinct" "$repeats" "$pad"
  got="$(_run_monitor "$T/monitor_lib.sh" "$dir")"
  assert_eq "$got" "$distinct" \
    "monitor.sh [$label]: emitted $distinct unique repos, no duplicates and no empty line (got '$got')"
done

echo ""
echo "== a malformed .env must not abort either script =="
# Found by this suite, not by the sigpipe lint walk: `grep -m1 '^TARGET_REPO='`
# exits 1 on a file lacking that key, `pipefail` propagates it, and under
# `set -euo pipefail` the plain assignment is FATAL — one stray .env silently
# empties the whole monitored set. Empty output is the intended signal.
dir="$T/env_empty"
rm -rf "$dir"; mkdir -p "$dir"
printf 'TARGET_REPO=org/real-one\n' > "$dir/a.env"
printf 'TARGET_REPO=\n'             > "$dir/b.env"
printf 'OTHER_KEY=x\n'              > "$dir/c.env"
printf 'TARGET_REPO=org/real-two\n' > "$dir/d.env"
got="$(_run_monitor "$T/monitor_lib.sh" "$dir")"
assert_eq "$got" "2" \
  "monitor.sh: empty and absent TARGET_REPO produce no repo line (got '$got' lines, expected 2)"

cnt="$T/queries_malformed"
got="$(_run_manage "$T/manage_lib.sh" "$dir" "$cnt")"
assert_ok "[ -n '$got' ]" \
  "manage.sh: the driver completed rather than aborting on the malformed .env"
# 2 real repos are queried; the two malformed instances (empty TARGET_REPO)
# collapse into one dedup group, so exactly one extra query. The point is that
# this is a NUMBER, not an empty string from an aborted run.
assert_eq "$got" "3" \
  "manage.sh: queried the 2 real repos plus 1 empty-repo group (got '$got')"
assert_contains "$(cat "$dir/a.env")" 'TARGET_REPO=org/real-one' \
  "harness sanity: the fixture env file really carries TARGET_REPO"

echo ""
echo "== teeth: the measured count can actually go wrong =="
# A harness that reports the same number whatever the shipped code does is the
# defect this suite exists to prevent. Drive a variant with the dedup REMOVED
# and confirm the count RISES — proving the assertion above discriminates.
# Note this deliberately uses the SMALL input: at 3 instances the accumulator is
# far under the pipe buffer, so the pre-fix piped form was CORRECT here too.
# That is the whole point of the large scenario above, and why teeth and size
# are separate assertions.
cat > "$T/nodedup_lib.sh" <<'BROKEN'
set -uo pipefail
log() { :; }
instance_repo() { printf 'org/same-repo\n'; }
count_queued_jobs() { printf 'q\n' >> "$QUERIES"; printf '0\n'; }
cmd_status() {
  local inst repo
  while read -r inst; do
    [ -n "$inst" ] || continue
    repo="$(instance_repo "$inst")"
    count_queued_jobs "$repo" > /dev/null
  done <<< "a
b
c"
}
BROKEN
cat > "$T/drive_nodedup.sh" <<DRV
#!/usr/bin/env bash
QUERIES="$T/nodedup_queries"
. "$T/nodedup_lib.sh"
: > "\$QUERIES"
cmd_status > /dev/null
wc -l < "\$QUERIES" | tr -d ' '
DRV
got_nodedup="$(bash "$T/drive_nodedup.sh" 2>/dev/null)"
assert_eq "$got_nodedup" "3" \
  "teeth: with the dedup removed the harness measures 3 (got '$got_nodedup') — so an expected-count assertion here is falsifiable"

# And the deduped form over the same shape measures 1, i.e. the two are
# distinguishable rather than both reading 3.
cat > "$T/dedup_lib.sh" <<'DEDUP'
set -uo pipefail
log() { :; }
instance_repo() { printf 'org/same-repo\n'; }
count_queued_jobs() { printf 'q\n' >> "$QUERIES"; printf '0\n'; }
cmd_status() {
  local repos_seen="" inst repo
  while read -r inst; do
    [ -n "$inst" ] || continue
    repo="$(instance_repo "$inst")"
    case "$repos_seen" in
      *"|$repo|"*) continue ;;
    esac
    repos_seen="${repos_seen}|$repo|"
    count_queued_jobs "$repo" > /dev/null
  done <<< "a
b
c"
}
DEDUP
cat > "$T/drive_dedup.sh" <<DRV
#!/usr/bin/env bash
QUERIES="$T/dedup_queries"
. "$T/dedup_lib.sh"
: > "\$QUERIES"
cmd_status > /dev/null
wc -l < "\$QUERIES" | tr -d ' '
DRV
got_dedup="$(bash "$T/drive_dedup.sh" 2>/dev/null)"
assert_eq "$got_dedup" "1" \
  "teeth: the same shape WITH the dedup measures 1 (got '$got_dedup') — 3 vs 1 is the discriminator"

suite_summary "runner-dedup"
