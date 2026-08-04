#!/usr/bin/env bash
# tests/test_litellm_secrets.sh — guards for install/set-litellm-secrets.sh.
#
# WHY THIS EXISTS: issue #350. A run to add the OPTIONAL doc key also rewrote
# LITELLM_BASE_URL and LITELLM_REVIEW_API_KEY from the operator's environment,
# with no validation of either. Both writes reported ✓ and the script exited 0;
# the break surfaced only on the next PR, as a red REQUIRED ai-review gate on a
# consumer. The inventory had this script as "low risk; accepted-no-FT" — that
# row was wrong, and this suite is what replaces it.
#
# HOW THE STUBS STAY HONEST: `gh` and `curl` are stubbed on PATH and LOG THEIR
# ARGV, to a log kept SEPARATE from the one holding secret values. Asserting on
# argv is the point — a stub that controls only what a command RETURNS proves
# nothing about how it was CALLED, which is how three live mutations once stayed
# green here. Keeping the two logs apart is what lets the PLAN-015 L3 assertion
# below be a blanket "this value appears on no argv line at all"; when both went
# to one log, the assertion had to guess an argv POSITION, and a review's
# mutation test showed it passed while the key sat in the process table.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(cd "$HERE/.." && pwd)"
SCRIPT="$ROOT/install/set-litellm-secrets.sh"

assert_ok "[ -f '$SCRIPT' ]" "set-litellm-secrets.sh exists"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"; mkdir -p "$BIN"

# ---- stubs -----------------------------------------------------------------
cat > "$BIN/gh" <<'STUB'
#!/usr/bin/env bash
# argv goes to its OWN log; secret VALUES only ever go to $GH_LOG.
printf 'ARGV %s\n' "$*" >> "$GH_ARGV_LOG"
case "${1:-} ${2:-}" in
  "auth status") exit 0 ;;
  "repo view")
    case " ${STUB_NO_ACCESS_REPOS:-} " in *" $3 "*) exit 1 ;; esac
    exit 0 ;;
  "secret list")
    repo=""
    for ((i=1; i<=$#; i++)); do
      if [ "${!i}" = "-R" ]; then j=$((i+1)); repo="${!j}"; fi
    done
    case " ${STUB_LIST_FAIL_REPOS:-} " in *" $repo "*) exit 1 ;; esac
    [ "${STUB_LIST_FAIL:-0}" = 1 ] && exit 1
    var="STUB_EXISTING_${repo#*/}"; var="${var//[^A-Za-z0-9_]/_}"
    val="${!var:-${STUB_EXISTING:-}}"
    [ -n "$val" ] && printf '%s\n' "$val"
    exit 0 ;;
  "secret set")
    value="$(cat)"
    printf 'SET %s -> %s = %s\n' "$3" "$5" "$value" >> "$GH_LOG"
    exit 0 ;;
esac
exit 0
STUB
cat > "$BIN/curl" <<'STUB'
#!/usr/bin/env bash
printf 'ARGV %s\n' "$*" >> "$CURL_LOG"
# Any -H @file header: record the FILE CONTENT separately, so a test can prove
# the bearer key travelled in a file and never on argv (PLAN-015 L3).
for a in "$@"; do
  case "$a" in @*) cat "${a#@}" >> "$CURL_HDR_LOG" 2>/dev/null || true ;; esac
done
# How many token files exist AT THIS MOMENT. Lets a test observe the in-run
# window: the EXIT trap guarantees nothing survives the run, so a probe that
# forgets to remove its own header file is invisible afterwards.
printf 'TMPFILES %s\n' "$(find "${TMPDIR:-/tmp}" -maxdepth 2 -type f 2>/dev/null | wc -l)" >> "$CURL_LOG"
for a in "$@"; do
  case "$a" in *key/generate*) printf '{"key":"sk-minted-%s"}' "$$"; exit 0 ;; esac
done
code="${STUB_HTTP_CODE:-200}"
printf '%s' "$code"
[ "$code" = "000" ] && exit 7
exit 0
STUB
chmod +x "$BIN/gh" "$BIN/curl"

REVIEW_KEY="sk-review-secret-value"
DOC_KEY="sk-doc-secret-value"
MASTER_KEY="sk-master-secret-value"
BRIDGE="http://172.17.0.1:4001/v1"

# run [script args...]
# Callers configure a case with `VAR=x run …` prefixes: BASE, REPOS_ARG,
# NO_REVIEW_KEY, STUB_EXISTING, STUB_EXISTING_<repo>, STUB_HTTP_CODE,
# STUB_LIST_FAIL, STUB_LIST_FAIL_REPOS, STUB_NO_ACCESS_REPOS.
# Sets: RC, OUT (stdout+stderr), GH_OUT (writes), GH_ARGV_OUT (argv),
#       CURL_OUT (argv), HDR_OUT (header-file contents).
run() {
  GH_LOG="$TMP/gh.log"; GH_ARGV_LOG="$TMP/gh-argv.log"
  CURL_LOG="$TMP/curl.log"; CURL_HDR_LOG="$TMP/hdr.log"
  : > "$GH_LOG"; : > "$GH_ARGV_LOG"; : > "$CURL_LOG"; : > "$CURL_HDR_LOG"
  export GH_LOG GH_ARGV_LOG CURL_LOG CURL_HDR_LOG
  local review="$REVIEW_KEY"
  [ "${NO_REVIEW_KEY:-0}" = 1 ] && review=""
  OUT="$(PATH="$BIN:$PATH" \
     LITELLM_BASE_URL="${BASE:-$BRIDGE}" \
     LITELLM_REVIEW_API_KEY="$review" \
     LITELLM_DOC_API_KEY="$DOC_KEY" \
     LITELLM_MASTER_KEY="$MASTER_KEY" \
     STUB_EXISTING="${STUB_EXISTING:-}" \
     STUB_EXISTING_repoA="${STUB_EXISTING_repoA:-}" \
     STUB_EXISTING_repoB="${STUB_EXISTING_repoB:-}" \
     STUB_EXISTING_repoC="${STUB_EXISTING_repoC:-}" \
     STUB_HTTP_CODE="${STUB_HTTP_CODE:-200}" \
     STUB_LIST_FAIL="${STUB_LIST_FAIL:-0}" \
     STUB_LIST_FAIL_REPOS="${STUB_LIST_FAIL_REPOS:-}" \
     STUB_NO_ACCESS_REPOS="${STUB_NO_ACCESS_REPOS:-}" \
     bash "$SCRIPT" --repos "${REPOS_ARG:-owner/repo}" "$@" 2>&1)"
  RC=$?
  GH_OUT="$(cat "$GH_LOG")"; GH_ARGV_OUT="$(cat "$GH_ARGV_LOG")"
  CURL_OUT="$(cat "$CURL_LOG")"; HDR_OUT="$(cat "$CURL_HDR_LOG")"
  # bash leaks `VAR=x func` assignments into the shell after the function
  # returns. Left alone, one case's STUB_EXISTING would silently configure the
  # next — a green suite testing the wrong thing. Clear them every time.
  unset BASE REPOS_ARG NO_REVIEW_KEY STUB_EXISTING STUB_HTTP_CODE STUB_LIST_FAIL \
        STUB_LIST_FAIL_REPOS STUB_NO_ACCESS_REPOS \
        STUB_EXISTING_repoA STUB_EXISTING_repoB STUB_EXISTING_repoC
}

# ---------------------------------------------------------------------------
echo "== a loopback LITELLM_BASE_URL is refused before anything is written =="
# The incident's first half. Loopback resolves to the job CONTAINER, so it
# passes every check the operator can run from the host and fails only in CI.
# The variants below are not hypothetical: each was verified to reach 127.0.0.1
# while an earlier version of this guard allowed it.
for host in "http://127.0.0.1:4001/v1" "http://localhost:4001/v1" "http://[::1]:4001/v1" \
            "http://LOCALHOST:4001/v1" "http://localhost.:4001/v1" \
            "http://2130706433:4001/v1" "http://0x7f000001:4001/v1" "http://[::]:4001/v1"; do
  BASE="$host" STUB_EXISTING="" run
  assert_ok "[ $RC -ne 0 ]" "refused: $host"
  assert_absent "$GH_OUT" "SET " "no secret written for $host"
done
# Hex and octal spellings, which the resolver (not the literal patterns) is what
# catches. A `return` from inside the integer branch once short-circuited the
# resolver fallback, so these two passed while resolving to 127.0.0.1.
if command -v getent >/dev/null 2>&1 && getent ahosts 0177.0.0.1 2>/dev/null | grep -q '^127\.'; then
  for host in "http://0177.0.0.1:4001/v1" "http://0x7f000001:4001/v1" "http://017700000001:4001/v1"; do
    BASE="$host" STUB_EXISTING="" run
    assert_ok "[ $RC -ne 0 ]" "refused via the resolver: $host"
    assert_absent "$GH_OUT" "SET " "no secret written for $host"
  done
else
  printf '  \033[33mskip\033[0m resolver-backed loopback spellings (getent unavailable)\n'
fi
# A host that makes bash arithmetic THROW must not silently skip the guard: an
# evaluation error unwinds the caller's `if` and runs neither branch.
for host in "http://3fa:4001/v1" "http://08:4001/v1" "http://0e5:4001/v1"; do
  BASE="$host" STUB_EXISTING="" run --skip-validate
  assert_absent "$OUT" "value too great for base" "no raw arithmetic error for $host"
  assert_absent "$OUT" "syntax error" "no raw arithmetic error for $host"
done

BASE="http://127.0.0.1:4001/v1" STUB_EXISTING="" run
assert_contains "$OUT" "loopback" "the refusal names the cause"
assert_contains "$OUT" "172.17.0.1" "the refusal names the correct bridge default"
assert_contains "$OUT" "--allow-loopback" "the refusal names the override flag"
# A non-loopback host must NOT be caught, or the guard is useless in production.
BASE="https://proxy.example/v1" STUB_EXISTING="" run
assert_ok "[ $RC -eq 0 ]" "a real proxy host is not misclassified as loopback"

echo "== --allow-loopback is the documented escape hatch =="
BASE="http://127.0.0.1:4001/v1" STUB_EXISTING="" run --allow-loopback
assert_ok "[ $RC -eq 0 ]" "--allow-loopback proceeds"
assert_contains "$GH_OUT" "SET LITELLM_BASE_URL" "--allow-loopback still writes"
assert_contains "$OUT" "WARN" "--allow-loopback still warns"

echo "== the URL+key pair is probed before any write =="
STUB_EXISTING="" STUB_HTTP_CODE=401 run
assert_ok "[ $RC -ne 0 ]" "401 from the proxy aborts"
assert_absent "$GH_OUT" "SET " "401: nothing is written"
# Match the refusal wording, not just the secret name: an earlier version of
# this assertion passed against the old SUCCESS line, which named the same key.
assert_contains "$OUT" "proxy REJECTS" "401: the message says the proxy rejected the key"
assert_contains "$OUT" "LITELLM_REVIEW_API_KEY (HTTP 401)" "401: the message names the rejected secret"

STUB_EXISTING="" STUB_HTTP_CODE=000 run
assert_ok "[ $RC -ne 0 ]" "an unreachable proxy aborts"
assert_absent "$GH_OUT" "SET " "unreachable: nothing is written"

STUB_EXISTING="" STUB_HTTP_CODE=200 run
assert_ok "[ $RC -eq 0 ]" "200 proceeds"
STUB_EXISTING="" STUB_HTTP_CODE=403 run
assert_ok "[ $RC -eq 0 ]" "403 (authenticated, unauthorized for /models) proceeds"

# 404 is the likeliest operator error the probe exists to catch: MODELS_URL
# appends /models, so a base URL missing or doubling /v1 lands here. Warning and
# writing anyway would let the guard pass the failure it was built for.
STUB_EXISTING="" STUB_HTTP_CODE=404 run
assert_ok "[ $RC -ne 0 ]" "404 aborts rather than warning"
assert_absent "$GH_OUT" "SET " "404: nothing is written"
assert_contains "$OUT" "/v1" "404: the message names the likely /v1 cause"
STUB_EXISTING="" STUB_HTTP_CODE=502 run
assert_ok "[ $RC -ne 0 ]" "an unexpected 5xx aborts rather than warning"

echo "== --skip-validate bypasses the probe, and says so =="
STUB_EXISTING="" STUB_HTTP_CODE=401 run --skip-validate
assert_ok "[ $RC -eq 0 ]" "--skip-validate ignores a 401"
assert_absent "$CURL_OUT" "models" "--skip-validate makes no probe request"
assert_contains "$OUT" "validate=0" "--skip-validate announces itself in the banner"

echo "== the bearer key never reaches argv (PLAN-015 L3) =="
# Blanket, not positional: assert the VALUE appears on no argv line at all.
STUB_EXISTING="" run --doc
assert_absent "$CURL_OUT" "$REVIEW_KEY" "probe: review key absent from curl argv"
assert_absent "$CURL_OUT" "$DOC_KEY" "probe: doc key absent from curl argv"
assert_contains "$HDR_OUT" "$REVIEW_KEY" "probe: review key travelled in a header file"
assert_absent "$GH_ARGV_OUT" "$REVIEW_KEY" "gh: review value appears on no argv line"
assert_absent "$GH_ARGV_OUT" "$DOC_KEY" "gh: doc value appears on no argv line"
STUB_EXISTING="" run --mint
assert_absent "$CURL_OUT" "$MASTER_KEY" "mint: master key absent from curl argv"
assert_absent "$GH_ARGV_OUT" "$MASTER_KEY" "mint: master key appears on no gh argv line"

echo "== an EXISTING secret is kept unless --overwrite (issue #350) =="
# The exact incident: --doc on a provisioned repo must add the doc key ONLY.
STUB_EXISTING="LITELLM_BASE_URL
LITELLM_REVIEW_API_KEY" run --doc
assert_ok "[ $RC -eq 0 ]" "--doc on a provisioned repo succeeds"
assert_contains "$GH_OUT" "SET LITELLM_DOC_API_KEY" "--doc: the new key IS written"
assert_absent "$GH_OUT" "SET LITELLM_BASE_URL" "--doc: the working base URL is NOT touched"
assert_absent "$GH_OUT" "SET LITELLM_REVIEW_API_KEY" "--doc: the working review key is NOT touched"
assert_contains "$OUT" "1 created, 0 overwritten, 2 kept" "the summary counts the kept secrets"
assert_contains "$OUT" "--overwrite" "the report names the flag that would replace them"

# ...and it must not demand the review key be re-exported. Requiring it is what
# sends an operator back to the stale shell value that caused #350.
NO_REVIEW_KEY=1 STUB_EXISTING="LITELLM_BASE_URL
LITELLM_REVIEW_API_KEY" run --doc
assert_ok "[ $RC -eq 0 ]" "--doc works with ONLY the doc key exported"
assert_contains "$GH_OUT" "SET LITELLM_DOC_API_KEY" "--doc without a review key still writes the doc key"
assert_absent "$CURL_OUT" "$REVIEW_KEY" "--doc without a review key probes no review key"

# But a repo that genuinely needs the review key CREATED must not get a blank one.
NO_REVIEW_KEY=1 STUB_EXISTING="" run --doc
assert_ok "[ $RC -ne 0 ]" "a missing review key that must be CREATED fails the run"
assert_absent "$GH_OUT" "SET LITELLM_REVIEW_API_KEY = " "no blank secret is ever written"
assert_contains "$OUT" "LITELLM_REVIEW_API_KEY" "the error names the variable to export"

echo "== the doc key is probed too, not just the review key =="
STUB_EXISTING="" run --doc
assert_contains "$HDR_OUT" "$DOC_KEY" "--doc probes the doc key"
NO_REVIEW_KEY=1 STUB_EXISTING="LITELLM_BASE_URL
LITELLM_REVIEW_API_KEY" STUB_HTTP_CODE=401 run --doc
assert_ok "[ $RC -ne 0 ]" "--doc: a rejected doc key aborts before any write"
assert_absent "$GH_OUT" "SET " "--doc 401: nothing is written"

echo "== --overwrite is the explicit opt-in =="
STUB_EXISTING="LITELLM_BASE_URL
LITELLM_REVIEW_API_KEY" run --doc --overwrite
assert_contains "$GH_OUT" "SET LITELLM_BASE_URL" "--overwrite replaces the base URL"
assert_contains "$GH_OUT" "SET LITELLM_REVIEW_API_KEY" "--overwrite replaces the review key"
assert_contains "$OUT" "1 created, 2 overwritten, 0 kept" "the summary counts the overwrites"

echo "== a fresh repo still provisions in one run, no flag needed =="
STUB_EXISTING="" run --doc
assert_contains "$GH_OUT" "SET LITELLM_BASE_URL" "fresh: base URL created"
assert_contains "$GH_OUT" "SET LITELLM_REVIEW_API_KEY" "fresh: review key created"
assert_contains "$GH_OUT" "SET LITELLM_DOC_API_KEY" "fresh: doc key created"
assert_contains "$OUT" "3 created, 0 overwritten, 0 kept" "fresh: summary"

echo "== the written VALUES go to the right SECRET and the right REPO =="
STUB_EXISTING="" run --doc
assert_contains "$GH_OUT" "SET LITELLM_REVIEW_API_KEY -> owner/repo = $REVIEW_KEY" "review key: name, repo and value"
assert_contains "$GH_OUT" "SET LITELLM_DOC_API_KEY -> owner/repo = $DOC_KEY" "doc key: name, repo and value"
assert_contains "$GH_OUT" "SET LITELLM_BASE_URL -> owner/repo = $BRIDGE" "base URL: name, repo and value"

echo "== fail closed when the existing set cannot be read =="
# Writing blind is how a silent overwrite happens; an unreadable list is not
# evidence of an empty one. Listing and writing need the same admin scope, so
# there is deliberately NO override for this.
STUB_EXISTING="" STUB_LIST_FAIL=1 run
assert_absent "$GH_OUT" "SET " "unreadable secret list: nothing is written"
assert_contains "$OUT" "refusing to write blind" "unreadable secret list: says why"
assert_ok "[ $RC -ne 0 ]" "unreadable secret list: the run does NOT exit 0"
STUB_EXISTING="" STUB_LIST_FAIL=1 run --overwrite
assert_absent "$GH_OUT" "SET " "--overwrite does NOT unlock a blind write"
assert_ok "[ $RC -ne 0 ]" "--overwrite on an unreadable list still fails"

echo "== a skipped repo is never reported as success =="
STUB_EXISTING="" STUB_NO_ACCESS_REPOS="owner/repo" run
assert_ok "[ $RC -ne 0 ]" "no-access repo: the run exits non-zero"
assert_contains "$OUT" "1 repo(s) skipped" "the summary counts the skip"

echo "== --dry-run writes nothing, sends nothing, and shows the plan =="
STUB_EXISTING="LITELLM_BASE_URL" run --doc --dry-run
assert_ok "[ $RC -eq 0 ]" "dry-run exits 0"
assert_absent "$GH_OUT" "SET " "dry-run writes nothing"
# The probe transmits a live bearer token; --dry-run must not do that at all.
assert_absent "$CURL_OUT" "models" "dry-run makes NO network request"
assert_absent "$HDR_OUT" "$REVIEW_KEY" "dry-run never writes the key to a header file"
assert_contains "$OUT" "[dry-run] LITELLM_DOC_API_KEY" "dry-run names the secret it would create"
assert_contains "$OUT" "would be created" "dry-run states the action"
assert_contains "$OUT" "(exists, kept" "dry-run marks the existing secret kept"
assert_contains "$OUT" "(dry-run — nothing written)" "the summary cannot be misread as a real run"

STUB_EXISTING="LITELLM_BASE_URL" run --dry-run --overwrite
assert_contains "$OUT" "would be OVERWRITTEN" "dry-run shouts a pending overwrite"
assert_absent "$GH_OUT" "SET " "dry-run --overwrite still writes nothing"

echo "== --mint does not burn a key it would not write =="
STUB_EXISTING="LITELLM_BASE_URL
LITELLM_REVIEW_API_KEY" run --mint
assert_absent "$CURL_OUT" "key/generate" "mint: no key minted when the secret is kept"
STUB_EXISTING="" run --mint
assert_contains "$CURL_OUT" "key/generate" "mint: a key IS minted for a fresh repo"
assert_contains "$GH_OUT" "SET LITELLM_REVIEW_API_KEY -> owner/repo = sk-minted-" "mint: the minted key is written"
STUB_EXISTING="" run --mint --dry-run
assert_absent "$CURL_OUT" "key/generate" "mint: --dry-run mints nothing"

echo "== the loop keeps per-repo state separate and aggregates counters =="
# repoA provisioned, repoB fresh, repoC unreadable. One case covers counter
# aggregation, per-repo isolation, and that an unreadable repo cannot leak its
# state into the next one.
REPOS_ARG="owner/repoA owner/repoB owner/repoC" \
  STUB_EXISTING_repoA="LITELLM_BASE_URL
LITELLM_REVIEW_API_KEY" \
  STUB_LIST_FAIL_REPOS="owner/repoC" run
assert_contains "$OUT" "2 created, 0 overwritten, 2 kept, 1 repo(s) skipped" "counters aggregate across repos"
assert_contains "$GH_OUT" "SET LITELLM_BASE_URL -> owner/repoB" "repoB is provisioned independently of repoA"
assert_absent "$GH_OUT" "-> owner/repoA" "repoA's existing secrets are untouched"
assert_absent "$GH_OUT" "-> owner/repoC" "nothing is written to the unreadable repo"
assert_ok "[ $RC -ne 0 ]" "a partially-skipped fan-out does not exit 0"

echo "== a failed write is reported, not silently fatal =="
# `set -e` on the write aborted mid-fleet with no summary, so an operator could
# not tell which repos were written and which were never reached.
cat > "$BIN/gh" <<'STUB'
#!/usr/bin/env bash
printf 'ARGV %s\n' "$*" >> "$GH_ARGV_LOG"
case "${1:-} ${2:-}" in
  "auth status"|"repo view") exit 0 ;;
  "secret list") exit 0 ;;
  "secret set") cat >/dev/null; exit 1 ;;   # every write fails
esac
exit 0
STUB
REPOS_ARG="owner/repoA owner/repoB" STUB_EXISTING="" run
assert_contains "$OUT" "write FAILED" "a failed write is reported"
assert_contains "$OUT" "Done" "the summary still prints after a failed write"
assert_contains "$GH_ARGV_OUT" "owner/repoB" "the fan-out continues to the next repo"
assert_ok "[ $RC -ne 0 ]" "a failed write makes the run exit non-zero"
cat > "$BIN/gh" <<'STUB'
#!/usr/bin/env bash
printf 'ARGV %s\n' "$*" >> "$GH_ARGV_LOG"
case "${1:-} ${2:-}" in
  "auth status") exit 0 ;;
  "repo view")
    case " ${STUB_NO_ACCESS_REPOS:-} " in *" $3 "*) exit 1 ;; esac
    exit 0 ;;
  "secret list")
    repo=""
    for ((i=1; i<=$#; i++)); do
      if [ "${!i}" = "-R" ]; then j=$((i+1)); repo="${!j}"; fi
    done
    case " ${STUB_LIST_FAIL_REPOS:-} " in *" $repo "*) exit 1 ;; esac
    [ "${STUB_LIST_FAIL:-0}" = 1 ] && exit 1
    var="STUB_EXISTING_${repo#*/}"; var="${var//[^A-Za-z0-9_]/_}"
    val="${!var:-${STUB_EXISTING:-}}"
    [ -n "$val" ] && printf '%s\n' "$val"
    exit 0 ;;
  "secret set")
    value="$(cat)"
    printf 'SET %s -> %s = %s\n' "$3" "$5" "$value" >> "$GH_LOG"
    exit 0 ;;
esac
exit 0
STUB

echo "== argument handling =="
STUB_EXISTING="" run --no-such-flag
assert_ok "[ $RC -eq 2 ]" "an unknown flag exits 2"
assert_absent "$GH_OUT" "SET " "unknown flag: nothing is written"
# `--budget --mint` used to set BUDGET=--mint and silently run in SHARED mode.
STUB_EXISTING="" run --budget --mint
assert_ok "[ $RC -eq 2 ]" "--budget rejects a non-numeric value instead of eating the next flag"
assert_absent "$GH_OUT" "SET " "bad --budget: nothing is written"
STUB_EXISTING="" run --mint --budget 7
assert_contains "$CURL_OUT" "max_budget\":7" "a valid --budget reaches the mint payload"

echo "== no file holding a bearer token survives the run =="
# Point the script's mktemp at a directory we own, so this observes the script
# and nothing else. Counting /tmp/tmp.* instead would be both flaky (unrelated
# concurrent activity) and blind to the header files nested inside SECRET_TMP —
# a mutation deleting probe()'s `rm -f "$hdr"` survived that version.
SECRET_SCAN="$TMP/tmpdir"; rm -rf "$SECRET_SCAN"; mkdir -p "$SECRET_SCAN"
# Truncate: the log still holds TMPFILES lines from earlier cases, which ran
# with the real /tmp and so counted unrelated files. Left in, they both
# false-fail (a busy /tmp reads as "TMPFILES 2…") and false-pass (a leftover
# count satisfies the "exactly one" assertion on its own).
: > "$TMP/curl.log"
OUT="$(PATH="$BIN:$PATH" TMPDIR="$SECRET_SCAN" \
   GH_LOG="$TMP/gh.log" GH_ARGV_LOG="$TMP/gh-argv.log" \
   CURL_LOG="$TMP/curl.log" CURL_HDR_LOG="$TMP/hdr.log" \
   LITELLM_BASE_URL="$BRIDGE" LITELLM_REVIEW_API_KEY="$REVIEW_KEY" \
   LITELLM_DOC_API_KEY="$DOC_KEY" STUB_EXISTING="" STUB_HTTP_CODE=200 \
   bash "$SCRIPT" --repos owner/repo --doc 2>&1)"
leftover="$(find "$SECRET_SCAN" -type f 2>/dev/null | wc -l)"
assert_eq "0" "$leftover" "no file is left behind anywhere under TMPDIR"
grepped="$(grep -rl "$REVIEW_KEY" "$SECRET_SCAN" 2>/dev/null | wc -l)"
assert_eq "0" "$grepped" "no surviving file contains the bearer key"
# --doc probes twice. Each probe must clean up its own header file, so a token
# file never coexists with the next one; without that, the second probe sees 2.
# Compare the PARSED maximum, not a substring — "TMPFILES 2" also matches 25.
assert_eq "1" "$(awk '/^TMPFILES /{print $2}' "$TMP/curl.log" | sort -n | tail -1)" \
  "a probe holds exactly one header file, and never two at once"

suite_summary "test_litellm_secrets.sh"
