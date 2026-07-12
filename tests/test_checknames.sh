#!/usr/bin/env bash
# tests/test_checknames.sh — FT-1/FT-2 regression guard (PLAN-007 W2).
# Every `call / <name>` required-check in a branch-protection template MUST
# correspond to a real reusable job (a job whose `name:` — or key, if unnamed —
# is <name>). A mismatched required context never turns green → PR blocked
# forever; this test makes such a drift a red test instead of a bricked gate.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
cd "$ROOT"

# Build the set of check-names the canon reusables actually emit as `call / X`:
# X = a job's `name:` if set, else the job key. (Callers name the job `call`.)
emitted="$(python3 - <<'PY'
import glob, yaml
names=set()
for f in glob.glob('.github/workflows/*.yml'):
    d=yaml.safe_load(open(f)) or {}
    if 'workflow_call' not in ((d.get(True) or d.get('on') or {}) if isinstance(d.get(True) or d.get('on'),dict) else {}):
        # 'on' parses to True in YAML; handle both
        on=d.get(True) if True in d else d.get('on')
        if not (isinstance(on,dict) and 'workflow_call' in on):
            continue
    for jk,jb in (d.get('jobs') or {}).items():
        names.add(jb.get('name', jk) if isinstance(jb,dict) else jk)
for n in sorted(names): print(n)
PY
)"

echo "== branch-protection templates only require REAL emitted check-names =="
for tpl in install/templates/branch-protection-*.json; do
  tier="$(basename "$tpl" .json)"
  while read -r ctx; do
    [ -z "$ctx" ] && continue
    # only the reusable-emitted `call / X` contexts are verifiable here;
    # bare names (e.g. standalone security.yml's "Secret scan (gitleaks)") are
    # repo-local, out of scope for this canon check.
    case "$ctx" in
      "call / "*) job="${ctx#call / }" ;;
      *) continue ;;
    esac
    if printf '%s\n' "$emitted" | grep -qxF "$job"; then
      _g "$tier: '$ctx' matches a real reusable job"
    else
      _r "$tier: '$ctx' has NO matching reusable job (would never turn green — arming bricks the gate)"
    fi
  done < <(python3 -c "import json;print('\n'.join(json.load(open('$tpl'))['required_status_checks']['contexts']))" 2>/dev/null)
done

suite_summary "checknames"
