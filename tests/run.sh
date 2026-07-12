#!/usr/bin/env bash
# tests/run.sh — aidoc-flow-ci test-suite entrypoint (PLAN-007 W1).
# Runs every tests/test_*.sh; exits non-zero if any group has a failing
# assertion. Run locally (`bash tests/run.sh`) or in CI (tests.yml).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rc=0
for t in "$HERE"/test_*.sh; do
  [ -f "$t" ] || continue
  printf '\n\033[1m━━ %s ━━\033[0m\n' "$(basename "$t")"
  bash "$t" || rc=1
done
printf '\n\033[1m════ suite %s ════\033[0m\n' "$([ "$rc" -eq 0 ] && printf '\033[32mPASS\033[0m' || printf '\033[31mFAIL\033[0m')"
exit "$rc"
