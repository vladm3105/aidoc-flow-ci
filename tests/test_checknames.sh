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

# PLAN-025 P8: the names PLAIN caller jobs emit. A plain job (steps are composite
# actions, no job-level `uses:`) produces a check run named `name:` — or the job
# key — with NO `<jobkey> / ` prefix. The prefix exists only because a reusable
# call surfaces as `<caller-job-key> / <callee-job-name>`; canon's own `main`
# carries both shapes side by side (bare `suite`, and `call / markdownlint`).
plainjobs="$(python3 - <<'PY'
import glob, yaml
names = set()
for f in glob.glob('install/templates/workflows/*.yml'):
    try:
        d = yaml.safe_load(open(f)) or {}
    except Exception:
        continue
    for jk, jb in (d.get('jobs') or {}).items():
        if isinstance(jb, dict) and not jb.get('uses'):
            names.add(jb.get('name', jk))
for n in sorted(names):
    print(n)
PY
)"

echo "== branch-protection templates only require REAL emitted check-names =="
for tpl in install/templates/branch-protection-*.json; do
  tier="$(basename "$tpl" .json)"
  while read -r ctx; do
    [ -z "$ctx" ] && continue
    # PLAN-025 P8: bare contexts are no longer skipped.
    #
    # This `case` used to `continue` on anything without a `call / ` prefix, on
    # the reasoning that a bare name must be repo-local. v3 ships PLAIN jobs
    # (composite-action steps), whose check runs ARE bare — so the skip would
    # have silently excluded every v3 context from the one check that verifies a
    # required name is actually emitted. Combined with the same blind spot in
    # required-context-map.py, both guards would have passed a context nothing
    # produces.
    #
    # A bare context is now resolved against canon's PLAIN caller jobs. Only a
    # name matching neither shape is out of scope, and that is reported rather
    # than skipped, so a genuinely repo-local context stays visible in the log.
    case "$ctx" in
      "call / "*)
        job="${ctx#call / }" ;;
      *)
        if printf '%s\n' "$plainjobs" | grep -qxF "$ctx"; then
          _g "$tier: '$ctx' matches a real plain caller job (v3 shape)"
        else
          printf '  \033[33mnote\033[0m %s: %s matches no canon job — repo-local, or an orphan\n' "$tier" "$ctx"
        fi
        continue ;;
    esac
    if printf '%s\n' "$emitted" | grep -qxF "$job"; then
      _g "$tier: '$ctx' matches a real reusable job"
    else
      _r "$tier: '$ctx' has NO matching reusable job (would never turn green — arming bricks the gate)"
    fi
  done < <(python3 -c "import json;print('\n'.join(json.load(open('$tpl'))['required_status_checks']['contexts']))" 2>/dev/null)
done

suite_summary "checknames"
