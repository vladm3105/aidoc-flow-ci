#!/usr/bin/env bash
# tests/lib.sh — shared assertion helpers for the aidoc-flow-ci test suite.
# Source this; call pass/fail/assert_*; the sourcing script tracks PASS/FAIL
# counts in $T_PASS/$T_FAIL and exits non-zero if any assertion failed.
T_PASS=0; T_FAIL=0
_g() { printf '  \033[32mok\033[0m   %s\n' "$*"; T_PASS=$((T_PASS+1)); }
_r() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; T_FAIL=$((T_FAIL+1)); }

assert_ok()      { if eval "$1"; then _g "${2:-$1}"; else _r "${2:-$1}"; fi; }          # cmd succeeds
assert_fail()    { if eval "$1"; then _r "${2:-expected fail: $1}"; else _g "${2:-$1}"; fi; }  # cmd fails
# CI-0033: `case`, NOT `printf … | grep -qF`. `grep -q` exits on first match,
# the writer takes EPIPE, and under `set -o pipefail` the pipeline reports 141 —
# so a MATCH reads as a miss. For assert_absent that inverts to a SILENT PASS on
# exactly the large haystacks (whole rendered files) where it is load-bearing.
# Size-dependent, so it does not show up on small fixtures. Keep it pipe-free.
#
# An EMPTY needle is refused in BOTH wrappers, and refusing it must itself be a
# FAILURE, not a verdict. This was gotten wrong once here: `grep -qF -- ''`
# MATCHES every haystack (measured, rc=0 — it does not "miss"), so returning a
# plain false from the helper flipped `assert_absent` from a loud red to a
# SILENT PASS, re-creating one direction over the very defect class this file
# was being changed to fix. An assertion whose needle came back empty proves
# nothing and must say so.
#
# One deliberate divergence from `grep -qF` remains: a MULTILINE needle. `grep -F`
# treats each line as an ALTERNATIVE and matches if any one is present; `case`
# requires the whole sequence contiguously. `case` is the stricter reading and the
# one the call sites intend. The only multiline call site is
# tests/test_contract.sh:131 — verified same verdict under both engines.
_haystack_has() { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
_empty_needle()  { _r "${2:-empty needle}: needle is empty — the assertion proves nothing"; }
assert_contains(){ if [ -z "$2" ]; then _empty_needle "$1" "$3"; elif _haystack_has "$1" "$2"; then _g "${3:-contains '$2'}"; else _r "${3:-missing '$2'}"; fi; }
assert_absent()  { if [ -z "$2" ]; then _empty_needle "$1" "$3"; elif _haystack_has "$1" "$2"; then _r "${3:-unexpected '$2'}"; else _g "${3:-absent '$2'}"; fi; }
assert_eq()      { if [ "$1" = "$2" ]; then _g "${3:-'$1' == '$2'}"; else _r "${3:-'$1' != '$2'}"; fi; }

suite_summary() { printf '\n%s: \033[32m%d passed\033[0m, %s%d failed\033[0m\n' "${1:-suite}" "$T_PASS" "$([ "$T_FAIL" -gt 0 ] && printf '\033[31m' || printf '\033[32m')" "$T_FAIL"; [ "$T_FAIL" -eq 0 ]; }
