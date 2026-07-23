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
  # Read the repo-root .yamllint.yaml — the SAME profile the pre-push hook uses
  # (single source of truth; FT-14). Previously an inline -d duplicate here that
  # the hook did not share, so the hook ran bare-strict and failed on canon main.
  out="$(yamllint -c .yamllint.yaml .github/workflows/ install/templates/workflows/ 2>&1)" \
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

echo "== codeql-action steps pin one PEELED COMMIT, not a tag object (FT-26) =="
# init/autobuild/analyze must all pin the SAME 40-hex SHA. The FT-26 defect was
# autobuild pinning the annotated TAG OBJECT (422s on the commits API, trips the
# mandatory SHA audit) while the siblings used the peeled commit. A single distinct
# SHA proves they agree; a tag-object drift makes this count > 1.
cql_shas="$(grep -oE 'github/codeql-action/[a-z-]+@[0-9a-f]{40}' .github/workflows/codeql.yml | grep -oE '[0-9a-f]{40}$' | sort -u)"
cql_n="$(printf '%s\n' "$cql_shas" | grep -c . || true)"
if [ "$cql_n" = "1" ]; then _g "codeql-action pins are one commit ($cql_shas)"
else _r "codeql-action pins disagree ($cql_n distinct SHAs) — a tag-object/commit mismatch (FT-26):"; printf '%s\n' "$cql_shas" | sed 's/^/      /'; fi
# Belt: the single agreed SHA must not be the KNOWN-BAD v4.36.1 tag object — the
# 'agree' check alone would pass if all three drifted to it together.
if grep -q '21eb7f7842f33eafc83782b56fff2a2c43e9696f' .github/workflows/codeql.yml; then
  _r "codeql.yml pins the v4.36.1 tag OBJECT (21eb7f78) — use the peeled commit 87557b9c (FT-26)"
else
  _g "codeql.yml does not pin the known-bad v4.36.1 tag object"
fi

suite_summary "lint"
