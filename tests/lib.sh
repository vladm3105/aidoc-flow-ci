#!/usr/bin/env bash
# tests/lib.sh — shared assertion helpers for the aidoc-flow-ci test suite.
# Source this; call pass/fail/assert_*; the sourcing script tracks PASS/FAIL
# counts in $T_PASS/$T_FAIL and exits non-zero if any assertion failed.
T_PASS=0; T_FAIL=0
_g() { printf '  \033[32mok\033[0m   %s\n' "$*"; T_PASS=$((T_PASS+1)); }
_r() { printf '  \033[31mFAIL\033[0m %s\n' "$*"; T_FAIL=$((T_FAIL+1)); }

assert_ok()      { if eval "$1"; then _g "${2:-$1}"; else _r "${2:-$1}"; fi; }          # cmd succeeds
assert_fail()    { if eval "$1"; then _r "${2:-expected fail: $1}"; else _g "${2:-$1}"; fi; }  # cmd fails
assert_contains(){ if printf '%s' "$1" | grep -qF -- "$2"; then _g "${3:-contains '$2'}"; else _r "${3:-missing '$2'}"; fi; }
assert_absent()  { if printf '%s' "$1" | grep -qF -- "$2"; then _r "${3:-unexpected '$2'}"; else _g "${3:-absent '$2'}"; fi; }
assert_eq()      { if [ "$1" = "$2" ]; then _g "${3:-'$1' == '$2'}"; else _r "${3:-'$1' != '$2'}"; fi; }

suite_summary() { printf '\n%s: \033[32m%d passed\033[0m, %s%d failed\033[0m\n' "${1:-suite}" "$T_PASS" "$([ "$T_FAIL" -gt 0 ] && printf '\033[31m' || printf '\033[32m')" "$T_FAIL"; [ "$T_FAIL" -eq 0 ]; }
