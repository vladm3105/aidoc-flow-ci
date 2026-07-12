#!/usr/bin/env bash
# tests/test_lint.sh — static analysis. Each tool is skipped-with-notice if not
# installed (so local runs don't fail on a missing tool; CI installs all three).
# static analysis: shellcheck -S error (real bugs, not style); yamllint relaxed (no line-length
# noise); actionlint over every workflow + caller template.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
cd "$ROOT"

echo "== shellcheck (install/ sync/ scripts/ tests/) =="
if command -v shellcheck >/dev/null 2>&1; then
  mapfile -t shfiles < <(find install sync scripts tests -maxdepth 2 -name '*.sh' 2>/dev/null)
  out="$(shellcheck -S error -e SC1091 "${shfiles[@]}" 2>&1)" && _g "shellcheck: no errors in ${#shfiles[@]} scripts" \
    || { _r "shellcheck errors:"; printf '%s\n' "$out" | sed 's/^/      /'; }
elif [ "${CI:-}" = "true" ]; then _r "shellcheck missing in CI"
else printf '  \033[33mskip\033[0m shellcheck not installed\n'; fi

echo "== yamllint (workflows + templates, relaxed) =="
if command -v yamllint >/dev/null 2>&1; then
  out="$(yamllint -d '{extends: relaxed, rules: {line-length: disable, document-start: disable, truthy: disable, comments: disable, comments-indentation: disable, empty-lines: disable, trailing-spaces: disable, indentation: disable, brackets: disable, new-line-at-end-of-file: disable}}' .github/workflows/ install/templates/workflows/ 2>&1)" \
    && _g "yamllint: clean" || { _r "yamllint issues:"; printf '%s\n' "$out" | sed 's/^/      /'; }
elif [ "${CI:-}" = "true" ]; then _r "yamllint missing in CI"
else printf '  \033[33mskip\033[0m yamllint not installed\n'; fi

echo "== actionlint (workflows + templates) =="
if command -v actionlint >/dev/null 2>&1; then
  # actionlint also delegates embedded `run:` blocks to shellcheck, closing the
  # gap where workflow shell passed while only standalone .sh files were linted.
  out="$(actionlint .github/workflows/*.yml install/templates/workflows/*.yml 2>&1)" \
    && _g "actionlint: clean" || { _r "actionlint issues:"; printf '%s\n' "$out" | sed 's/^/      /'; }
elif [ "${CI:-}" = "true" ]; then _r "actionlint missing in CI"
else printf '  \033[33mskip\033[0m actionlint not installed (CI installs it)\n'; fi

suite_summary "lint"
