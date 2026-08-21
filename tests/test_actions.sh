#!/usr/bin/env bash
# tests/test_actions.sh — contract for the v3 COMPOSITE ACTIONS (PLAN-025 §3.1).
#
# A composite action shares the caller's runner, which is the whole point: a
# `workflow_call` reusable gets its own runner, so twelve checks cost twelve
# provisioning cycles. Sharing a runner also means these actions inherit the
# caller's working tree and token, so the defenses that used to live in each
# reusable's own job have to be asserted HERE instead — nothing else checks them.
#
# Each assertion below maps to a PLAN-025 §2 defense row and exists because that
# defense was paid for once already. Do not relax one without amending §2.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
cd "$ROOT" || exit 1

# ─── PARSERS. Never `cat` a YAML file into a variable and grep it. ────────────
#
# Every file in this diff DOCUMENTS the defenses it implements, so a grep over
# the whole file matches the comment after the code is gone. Measured across
# this branch: SIX assertions passed against a deleted defense because the
# header still named it — `--ignore-scripts`, `--no-call-analysis=all`,
# `.semgrepignore`, `terraform`, `mode: internal`, `mode: external`. One
# mutation survived TWO successive fixes.
#
# The rule, and the reason these helpers exist: AN ASSERTION ABOUT WHAT RUNS
# MUST SEE ONLY WHAT RUNS. Parse the structure; never the prose around it.

# `run:` scalars of an action, whole-line comments stripped.
runbody() {
  python3 - "$1" <<'PY_RB'
import sys, re, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
for s in ((d.get("runs") or {}).get("steps") or []):
    if isinstance(s, dict) and "run" in s:
        for line in str(s["run"]).split("\n"):
            if not re.match(r'\s*#', line):
                print(line)
PY_RB
}

# The value a caller passes for one input of one action step.
# `<ABSENT>` = the step exists but omits the input (so a DEFAULT applies).
# `<NOSTEP>` = the caller does not invoke that action at all — which is how a
# whole check can be deleted from a consolidated gate without any grep noticing.
stepwith() {
  python3 - "$1" "$2" "$3" <<'PY_SW'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
for j in (d.get("jobs") or {}).values():
    for s in (j.get("steps") or []):
        if isinstance(s, dict) and ("/actions/%s@" % sys.argv[2]) in str(s.get("uses", "")):
            print(str((s.get("with") or {}).get(sys.argv[3], "<ABSENT>"))); raise SystemExit(0)
print("<NOSTEP>")
PY_SW
}

# The verdict step's run: body, comments stripped. Empty = no verdict step,
# which on a caller whose checks are all `continue-on-error` means the job
# CANNOT FAIL.
verdict_body() {
  python3 - "$1" <<'PY_VB'
import sys, re, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
for j in (d.get("jobs") or {}).values():
    for s in (j.get("steps") or []):
        if isinstance(s, dict) and s.get("name") == "verdict":
            for line in str(s.get("run", "")).split("\n"):
                if not re.match(r'\s*#', line):
                    print(line)
PY_VB
}

# A named caller step's `run:` body, comments stripped. `verdict_body` above is
# this specialised to "verdict"; the report-only callers name theirs "report",
# and a report that is not asserted is how links-external's unreachable failure
# arm survived review.
named_step_body() {
  python3 - "$1" "$2" <<'PY_NB'
import sys, re, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
for j in (d.get("jobs") or {}).values():
    for s in (j.get("steps") or []):
        if isinstance(s, dict) and s.get("name") == sys.argv[2]:
            for line in str(s.get("run", "")).split("\n"):
                if not re.match(r'\s*#', line):
                    print(line)
PY_NB
}

# Every `run:` body of a file, for EITHER shape — `runs.steps` (composite action)
# or `jobs.*.steps` (reusable workflow). `runbody` handles only the first and
# returns EMPTY for a reusable, which makes any assertion against it vacuous.
anybody() {
  python3 - "$1" "${2:-action}" <<'PY_AB'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
steps = []
if sys.argv[2] == "job":
    for j in (d.get("jobs") or {}).values():
        steps += (j.get("steps") or [])
else:
    steps = (d.get("runs") or {}).get("steps") or []
for s in steps:
    if "run" in s:
        print(str(s["run"]))
PY_AB
}

# The EXECUTABLE D23 segment of a scanner surface — from the banner to the
# scanner invocation that follows it. Sliced (never hand-copied) so the test
# drives the SHIPPED code: a hand-copy is a second statement of the same fact
# and drifts silently.
#
# `set -euo pipefail` is PREPENDED because the slice starts BELOW the run body's
# own `set` line. Without it the driver runs under different shell options than
# production, and every `set -e` property the block's comments call load-bearing
# is unfalsifiable — a verification narrower than its claim.
# $1 = file, $2 = end marker, $3 = "job" for a reusable workflow (else action).
d23_block() {
  python3 - "$1" "$2" "${3:-action}" <<'PY_D23'
import sys, yaml
f, end, kind = sys.argv[1], sys.argv[2], sys.argv[3]
d = yaml.safe_load(open(f)) or {}
steps = (list((d.get("jobs") or {}).values())[0].get("steps") or []) if kind == "job" \
        else ((d.get("runs") or {}).get("steps") or [])
for s in steps:
    r = str(s.get("run", ""))
    if "# \u2500\u2500 D23" in r and end in r:
        seg = r[r.index("# \u2500\u2500 D23"):r.index(end)]
        print("set -euo pipefail")
        # $1 is the scan-path under test. The action supplies it via `env:`; the
        # driver supplies it positionally. Unbound under `set -u` aborts instantly.
        print('SCAN_PATH="${1:-.}"')
        print('summary() { :; }')
        print(seg)
        break
PY_D23
}

# Sorted action basenames a caller invokes — catches a silently dropped check.
invoked_actions() {
  python3 - "$1" <<'PY_IA'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
n = sorted(str(s["uses"]).split("/actions/")[1].split("@")[0]
           for j in (d.get("jobs") or {}).values()
           for s in (j.get("steps") or [])
           if isinstance(s, dict) and "/actions/" in str(s.get("uses", "")))
print(" ".join(n))
PY_IA
}

# Exact permissions mapping — D9 is a CEILING, and a containment check cannot
# express a ceiling: `assert_contains "contents: read"` still passes after
# `pull-requests: write` is added beside it.
perms_of() {
  python3 -c "
import yaml, json, sys
print(json.dumps(yaml.safe_load(open(sys.argv[1])).get('permissions'), sort_keys=True))" "$1"
}

# Env vars a step's `run:` READS that the SAME step never declared. In a
# composite action every step is its own shell AND its own `env:` scope, so a
# value declared on step 4 is simply absent in step 1 — with no error, because
# `${VAR:-default}` is exactly how you write "optional". That is how the D11
# guard came to validate a stage the run would not use: `RUN_STAGE` was declared
# on "Run hooks" and read by the precondition step, so `${RUN_STAGE:-pre-commit}`
# silently took the default and the guard checked the wrong stage for every
# consumer that set the input. Nothing failed; the gate just stopped meaning
# what it said.
#
# Reported per step, not per file — the same name legitimately appears declared
# in one step and undeclared in another, which is the whole defect shape.
undeclared_env() {
  python3 - "$@" <<'PY_UE'
import sys, re, yaml
# Provided by the runner itself, so reading one without declaring it is correct.
PROVIDED = re.compile(r'^(GITHUB_|RUNNER_|ACTIONS_|INPUT_|CI$|HOME$|PATH$|TMPDIR$|LANG$|PWD$|SHELL$|USER$|IFS$|OSTYPE$|BASH)')
REF    = re.compile(r'\$\{([A-Z][A-Z0-9_]*)(?:[:#%/^,-][^}]*)?\}|\$([A-Z][A-Z0-9_]*)')
# re.M is load-bearing on ASSIGN and GHENV — both anchor with `^`, and without
# the flag `^` binds to the start of the whole body, so only a first-line match
# counts and every later one reads as undeclared. The prototype reported five
# false positives for exactly that. LOOPRD has no anchor and does not need it;
# an earlier version of this comment claimed all three, which was wrong.
ASSIGN = re.compile(r'(?:^|[;&|(]|\bthen\b|\bdo\b|\bexport\b|\blocal\b|\bdeclare\b|\breadonly\b)\s*([A-Z][A-Z0-9_]*)\s*(?:=|\+=)', re.M)
LOOPRD = re.compile(r'\b(?:for|read(?:\s+-\w+)*|mapfile(?:\s+-\w+)*(?:\s+\S+)?)\s+([A-Z][A-Z0-9_]*)')
# `echo FOO=bar >> "$GITHUB_ENV"` exports to LATER steps, so the name is
# legitimately defined without appearing in any `env:` block.
GHENV  = re.compile(r'^\s*(?:echo|printf)[^\n]*?\b([A-Z][A-Z0-9_]*)=[^\n]*>>\s*"?\$(?:\{)?GITHUB_ENV', re.M)

# A DECLARER MUST NOT BE ABLE TO FIRE ON PROSE. Both false negatives found in
# review were of that shape: `echo "cannot read CONFIG_PATH from the tree"` made
# LOOPRD believe CONFIG_PATH was bound, and a heredoc body line `RUN_STAGE=…`
# made ASSIGN believe RUN_STAGE was. Either one masks a genuinely undeclared
# read of that same name — the exact variables of the defect this check exists
# for. Strip heredoc bodies and string literals BEFORE looking for declarers.
# References are matched on the unstripped code, because a `$VAR` inside a
# double-quoted string is a real expansion.
HEREDOC = re.compile(r'<<-?\s*[\'"]?([A-Za-z_][A-Za-z0-9_]*)[\'"]?.*?^\s*\1\s*$',
                     re.S | re.M)
def no_heredoc(code):
    return HEREDOC.sub("", code)

def declarer_view(code):
    # Strings blanked for ASSIGN and LOOPRD only. NOT for GHENV — that declarer
    # matches `echo "FOO=bar" >> "$GITHUB_ENV"`, whose whole payload lives inside
    # quotes, so blanking strings makes it match nothing. Applying one view to
    # all three silently disarmed GHENV; caught by the per-declarer probe.
    code = no_heredoc(code)
    code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', code)
    code = re.sub(r"'[^']*'", "''", code)
    return code

def strip_comments(body):
    return "\n".join(l for l in str(body).split("\n") if not re.match(r'\s*#', l))

clean = True
for path in sys.argv[1:]:
    d = yaml.safe_load(open(path)) or {}
    for i, s in enumerate((d.get("runs") or {}).get("steps") or []):
        if not isinstance(s, dict) or "run" not in s:
            continue
        # Comments name the variables they explain, so strip them first — the
        # "an assertion about what runs must see only what runs" rule applies
        # here in reverse: an unstripped comment would HIDE a real hit only if
        # it declared one, but it would just as easily invent one.
        code = strip_comments(s["run"])
        dv = declarer_view(code)
        env = s.get("env") or {}
        # A list-valued `env:` is schema-invalid but parses, and `.keys()` on it
        # raised AttributeError — which printed nothing and read as CLEAN at the
        # one call site where "found nothing" and "produced nothing" were the
        # same value. Degrade to no declarations rather than crash; the sentinel
        # below is the real fix.
        declared = set(env.keys()) if isinstance(env, dict) else set()
        known = declared | set(ASSIGN.findall(dv)) | set(LOOPRD.findall(dv)) \
                         | set(GHENV.findall(no_heredoc(code)))
        for name in dict.fromkeys(m.group(1) or m.group(2) for m in REF.finditer(code)):
            if name not in known and not PROVIDED.match(name):
                clean = False
                print("%s step %d (%s): reads $%s, never declared in that step" %
                      (path, i, s.get("name", "?"), name))
# SENTINEL. Without it `assert_eq "$out" ""` treats a crash, a typo'd path or an
# empty input as a pass — the only assertion in this file where silence is the
# success value. Printed last so any traceback replaces it.
if clean:
    print("UE-CLEAN")
PY_UE
}

mapfile -t ACTIONS < <(find actions -name action.yml 2>/dev/null | sort)

echo "== composite actions exist =="
if [ "${#ACTIONS[@]}" -eq 0 ]; then
  _r "no actions/*/action.yml found — PLAN-025 P2 has not landed"
  suite_summary "test_actions.sh"; exit $?
fi
_g "found ${#ACTIONS[@]} composite action(s)"

for a in "${ACTIONS[@]}"; do
  name="$(basename "$(dirname "$a")")"
  body="$(cat "$a")"

  echo "== $name =="

  assert_ok "python3 -c \"import yaml,sys; yaml.safe_load(open('$a'))\"" \
    "$name: valid YAML"

  assert_contains "$body" "using: composite" \
    "$name: declares 'using: composite'"

  # D-checkout (PLAN-025 §3.2): checkout is the CALLER's job — the shared tree is
  # where the saving comes from, and a second checkout inside an action would
  # clobber a tree another action already depends on.
  assert_absent "$body" "actions/checkout" \
    "$name: does NOT check out (caller owns the tree)"

  # D5 (REPO_STANDARDS §4.3): every `uses:` SHA-pinned. A git tag is
  # attacker-mutable state on infrastructure we do not control, and these
  # actions run on the ephemeral pool, which re-resolves refs every run — a
  # moved tag reaches the whole fleet in one CI cycle.
  unpinned="$(grep -nE '^\s*uses:\s' "$a" | grep -vE 'uses:\s*[^@]+@[0-9a-f]{40}' || true)"
  if [ -z "$unpinned" ]; then
    _g "$name: every 'uses:' is SHA-pinned (D5)"
  else
    _r "$name: unpinned 'uses:' — $unpinned"
  fi

  # A composite action's `run:` steps MUST declare a shell; GitHub does not
  # default one (unlike a workflow job), and omitting it is a load error.
  #
  # PARSE, DO NOT GREP. The first version of this counted `grep -c '^\s*run: |'`,
  # which matches only the block-scalar spelling — so an action written
  # `run: npm ci` yielded 0 run / 0 shell, the equality passed VACUOUSLY, and the
  # strict-mode assertion below was skipped by the `-gt 0` guard. A measurement
  # mutation (verified 2026-08-08) sailed through the whole suite while shipping
  # an action GitHub would refuse to load. A test extractor must fail closed.
  # FAIL CLOSED — this is the SECOND instance of the same class, found inside the
  # fix for the first. The parsing version above still failed open two ways: a
  # raising extractor prints nothing, `read` assigns three empty strings, and
  # `assert_eq "" ""` reports PASS; and a `steps:` that is a scalar rather than a
  # list yields 0/0/0, so a structurally invalid action passed every assertion
  # (verified 2026-08-08). So the extractor now emits a sentinel and asserts the
  # SHAPE of its own output before any count is trusted.
  parsed="$(python3 - "$a" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
runs_block = d.get("runs")
if not isinstance(runs_block, dict):
    print("BADSHAPE runs-not-a-mapping"); raise SystemExit(0)
steps = runs_block.get("steps")
if not isinstance(steps, list):
    print("BADSHAPE steps-not-a-list"); raise SystemExit(0)
if any(not isinstance(s, dict) for s in steps):
    print("BADSHAPE step-not-a-mapping"); raise SystemExit(0)
runs = [s for s in steps if "run" in s]
shells = [s for s in runs if s.get("shell") == "bash"]
# D15 wants `set -euo pipefail`. ONE documented exception: a step whose
# contract is "must never fail the gate" cannot carry `-e`, because a SIGPIPE
# from `cmd | head` aborts it before its own `exit 0`. v2 used `set -uo
# pipefail` there deliberately. Accept that form ONLY where the step opts in
# with a NEVER-FAILS marker, so the exception is declared, not inferred.
strict = []
for s in runs:
    b = str(s.get("run", ""))
    if "set -euo pipefail" in b:
        strict.append(s)
    elif "set -uo pipefail" in b and "NEVER FAIL" in str(s.get("name", "")) + b:
        strict.append(s)
print("OK", len(runs), len(shells), len(strict))
PY
  )" || parsed="CRASH"
  read -r tag runs shells strict <<< "$parsed"
  if [ "$tag" != "OK" ]; then
    _r "$name: step extractor could not read this action ($parsed) — refusing to report pass"
    runs=-1; shells=-2; strict=-3   # guarantee the assertions below also fail
  fi
  assert_eq "$runs" "$shells" "$name: every run: has 'shell: bash' ($runs run / $shells shell)"

  # D15 (REPO_STANDARDS §24.1): GitHub already applies an implicit `bash -e`, so
  # a step that does not set its own strict mode aborts at the first non-zero
  # BEFORE any guard can forgive it. Asserted PER STEP, not "somewhere in the
  # file" — one strict step must not vouch for four sloppy ones.
  assert_eq "$runs" "$strict" "$name: every run: sets strict mode ($strict/$runs) (D15)"

  # D21: canon may `uses:` only actions/*, github/* or vladm3105/*. A marketplace
  # action is a run-init `startup_failure` with a web-UI-only message that
  # actionlint does not catch, in every consumer at once.
  #
  # PARSED, not grepped — the first version matched the literal text `uses:`
  # inside a COMMENT explaining this very rule, and reported the prose as a
  # non-allowlisted owner. Grepping a structured file for a key finds the key's
  # name wherever it appears, including in the documentation of the key.
  badowner="$(python3 - "$a" <<'PY'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
ok = ("actions/", "github/", "vladm3105/")
for s in ((d.get("runs") or {}).get("steps") or []):
    u = s.get("uses") if isinstance(s, dict) else None
    if u and not u.startswith(ok):
        print(u)
PY
  )"
  if [ -z "$badowner" ]; then
    _g "$name: every 'uses:' is an allowlisted owner (D21)"
  else
    _r "$name: non-allowlisted action owner — $badowner"
  fi

  # §3.2: every action verifies its own precondition and fails LOUD. Asserted as
  # the FIRST step: a guard placed after the tool has run cannot prevent the
  # green-having-inspected-nothing shape it exists to stop. Deleting the guard
  # entirely from an action previously survived the whole suite.
  guard="$(python3 - "$a" <<'PY_G'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
steps = (d.get("runs") or {}).get("steps") or []
if not steps or not isinstance(steps[0], dict):
    print("NONE"); raise SystemExit(0)
b = str(steps[0].get("run", ""))
print("OK" if ("exit 1" in b and "::error::" in b and ".git" in b) else "NONE")
PY_G
  )"
  assert_eq "$guard" "OK" "$name: FIRST step is a fail-loud checkout precondition guard (§3.2)"

  # D20: any action that downloads a binary MUST verify it before executing it.
  # D21 forces these bodies to curl their own tools instead of using a
  # marketplace action, so the integrity check is the only thing standing
  # between a substituted release asset and code execution on the runner.
  # Added after a mutation deleting `sha256sum -c` survived the whole suite.
  # UNCONDITIONAL and on the COMMAND. The old form fired only `if` the body
  # matched `curl .*-o`, so switching the fetch to wget RETIRED the check rather
  # than failing it — verified: the lychee tarball lost its sha256sum and the
  # whole suite stayed green.
  rb="$(runbody "$a")"
  dl=$(printf '%s
' "$rb" | grep -cE '(^|[^[:alnum:]_])(curl|wget)([^[:alnum:]_]|$)' || true)
  ck=$(printf '%s
' "$rb" | grep -cE 'sha256sum (-c|--check)' || true)
  if [ "$dl" -gt 0 ]; then
    if [ "$ck" -ge 1 ]; then
      _g "$name: $dl download(s), $ck checksum verification(s) in the COMMAND (D20)"
    else
      _r "$name: $dl download(s) with NO checksum verification in the COMMAND (D20)"
    fi
  fi
done

echo "== tool parity (PLAN-025 §3.3) =="
# The CI check and the local hook must run the SAME markdownlint. The
# pre-commit ecosystem's usual hook is markdownlint-cli (v1) with different
# ignore semantics; a mismatch means local passes and CI reds, which trains
# contributors to bypass hooks.
if [ -f actions/markdownlint/action.yml ]; then
  ml="$(runbody actions/markdownlint/action.yml)"
  assert_contains "$ml" "markdownlint-cli2@" "markdownlint: pins cli2 with a version"
  # cli1 would appear as `markdownlint-cli@` — the `2` is what distinguishes them.
  assert_absent "$ml" "markdownlint-cli@" "markdownlint: does NOT use cli1"
  assert_contains "$ml" "--ignore-scripts" "markdownlint: npm install skips lifecycle scripts"
fi

echo "== quick-gates caller (PLAN-025 §3.2) =="
QG=install/templates/workflows/quick-gates.yml
if [ -f "$QG" ]; then
  qg="$(cat "$QG")"

  # D3 / CI-0025 / §23: an allowlist, never a blanket cancel. This job feeds a
  # required context, and a cancelled required check is not success — it is
  # retained alongside any later success, so the rollup stays FAILURE.
  assert_contains "$qg" 'contains(fromJSON(' "quick-gates: concurrency uses the §23 allowlist (D3)"
  assert_absent "$qg" "cancel-in-progress: true" "quick-gates: no blanket cancel (D3)"

  # D4: the job id renders the required context `quick-gates`.
  assert_contains "$qg" "  quick-gates:" "quick-gates: job id is 'quick-gates' (D4)"

  # The shared checkout must NOT pin a ref. On `pull_request` the default is the
  # MERGE commit, which is what the v2 pre-commit/markdown-lint/links reusables
  # lint. An earlier draft pinned `pull_request.head.sha` (copied from
  # audit-trail), which lints the branch TIP — so a PR whose merge result is
  # dirty but whose tip is clean would go green. Weaker, not stricter.
  assert_absent "$qg" "ref: \${{ github.event.pull_request.head.sha }}" \
    "quick-gates: no head.sha pin — lints the merge commit like v2"
  assert_contains "$qg" "persist-credentials: false" "quick-gates: no persisted creds"

  # audit-trail is deliberately NOT consolidated here (PLAN-025 §3.2d): it needs
  # label types the other checks must not have, a job-level event refusal (D31),
  # and the D36 credential asymmetry. Three defenses for one provisioning cycle.
  assert_absent "$qg" "actions/audit-trail" \
    "quick-gates: does not absorb audit-trail (types/D31/D36 conflict)"

  # D7: this job runs pre-commit over the PR's own files — fork-code execution.
  # The public variant must stay ubuntu-latest; moving it to the self-hosted
  # pool is the untrusted-code leak.
  assert_contains "$qg" "runs-on: ubuntu-latest" "quick-gates: public variant is ubuntu-latest (D7)"

  # composition fires on pull_request_review/workflow_run, so it cannot share
  # this job's trigger. Catching it here stops the consolidation from silently
  # swallowing a check that would then never run.
  assert_absent "$qg" "actions/composition" "quick-gates: does not absorb composition (different trigger)"

  if command -v actionlint >/dev/null 2>&1; then
    assert_ok "actionlint '$QG' >/dev/null 2>&1" "quick-gates: actionlint clean"
  else
    printf '  \033[33mskip\033[0m actionlint not installed\n'
  fi
else
  _r "quick-gates caller template missing"
fi

echo "== links posture: internal blocks, external is weekly and report-only (D42) =="
# The v2 split is a defense: external link rot is TIME-based, so blocking a PR on
# a third party's 429 is a false signal — but the check must still run. An
# earlier draft defaulted the action to mode=external and passed nothing from
# quick-gates, which would have made the REQUIRED gate do live network calls.
LA=actions/links/action.yml
if [ -f "$LA" ]; then
  la="$(cat "$LA")"
  assert_contains "$la" "default: 'internal'" "links action: defaults to internal (offline), not external"
  assert_contains "$la" "default: '.lychee.toml'" "links action: default config path is the one canon installs"
fi
if [ -f "$QG" ]; then
  # Explicit beats inherited on a required gate.
  assert_contains "$qg" "mode: internal" "quick-gates: passes mode explicitly"
  assert_contains "$qg" "config-file: .lychee.toml" "quick-gates: passes the config path explicitly"
  # NO token here — see the mode-keyed rule asserted below. `mode: internal`
  # adds `--offline`, so lychee makes no request and the credential is never
  # read; it would only sit in the same job as the step that executes the PR's
  # own pre-commit hooks.
  assert_absent "$qg" "github-token:" "quick-gates: does NOT pass a token it cannot use (mode: internal)"
fi
LX=install/templates/workflows/links-external.yml
if [ -f "$LX" ]; then
  lx="$(cat "$LX")"
  assert_contains "$lx" "schedule:" "links-external: is scheduled"
  assert_contains "$lx" "mode: external" "links-external: checks external URLs"
  # NOT `fail-on-error: 'false'` — that spelling of "report-only" was the defect,
  # not the property. It makes actions/links exit 0 for every result short of a
  # timeout, which pins `steps.links.outcome` to `success` and leaves the report
  # step's failure arm unreachable: dead links, green tick, no warning. The job's
  # non-blocking-ness comes from `continue-on-error` (asserted below with its
  # partner), which rewrites the CONCLUSION while leaving the OUTCOME true.
  assert_contains "$lx" "continue-on-error: true" "links-external: never blocking"
else
  _r "links-external.yml missing — adopting quick-gates would drop external link checking entirely (D42)"
fi

echo "== ignore markers track the pin, in BOTH directions (FT-21) =="
# `sync-version-refs --check` is a DEFAULT-STAGE, always_run pre-commit hook, so
# it runs on every commit AND inside canon's `call / Lint / format / security
# hooks` required context. A v3 template pinning `@ci/v3.0.0` while VERSION is
# ci/v2.16.0 reports STALE and reds the branch, and the rewriter's suggested
# remedy would point the pin at a tag where `actions/` does not exist. So while
# the pin is AHEAD of VERSION the markers are mandatory (FT-21 chicken-and-egg).
#
# THE OTHER DIRECTION IS WHY THIS IS A BICONDITIONAL, and the earlier one-way
# version made the tag cut impossible to perform. Every one of these templates
# instructs the operator to REMOVE THE MARKERS AT THE v3.0.0 TAG CUT. Under a
# markers-must-be-present rule, doing so reds the suite — so they stay, and
# `sync-version-refs` never descends into an ignore span again: the six
# composite-action pins freeze at ci/v3.0.0 through every later release, silently,
# because `--check` cannot see inside the span it is told to skip. That is
# CI-0024's class inverted. Once VERSION reaches the pinned tag the reference is
# no longer forward, and the markers must be GONE.
#
# DISCOVERED, not enumerated. The old list named three files by hand and
# `scanners.yml` — which carries the same markers and the same six-pin exposure —
# was simply not in it. Any new caller is covered the moment it exists.
_ver="$(tr -d '[:space:]' < VERSION)"
mapfile -t PINNED_TPL < <(grep -rlE 'vladm3105/aidoc-flow-ci/actions/[^@]+@ci/v' install/templates/workflows/ 2>/dev/null | sort)
assert_ok "[ ${#PINNED_TPL[@]} -ge 1 ]" "marker check found caller templates carrying an actions pin"
for tpl in "${PINNED_TPL[@]}"; do
  b="$(basename "$tpl")"
  # The pin's own tag, read from the file — not assumed to be ci/v3.0.0, so this
  # keeps working at v3.1.0 and beyond.
  pin="$(grep -oE 'vladm3105/aidoc-flow-ci/actions/[^@]+@(ci/v[0-9]+\.[0-9]+\.[0-9]+)' "$tpl" | sed -E 's/.*@//' | sort -u | head -1)"
  has_start=no; has_end=no
  grep -q 'sync-version-refs:ignore-start' "$tpl" && has_start=yes
  grep -q 'sync-version-refs:ignore-end'   "$tpl" && has_end=yes
  if [ "$pin" != "$_ver" ]; then
    assert_eq "$has_start$has_end" "yesyes" \
      "$b: pin $pin is AHEAD of VERSION $_ver — forward reference, markers required"
  else
    assert_eq "$has_start$has_end" "nono" \
      "$b: pin $pin now EQUALS VERSION — markers must be removed or the pin freezes here"
  fi
done
if command -v bash >/dev/null && [ -x scripts/sync-version-refs.sh ]; then
  assert_ok "bash scripts/sync-version-refs.sh --check >/dev/null 2>&1" \
    "sync-version-refs --check passes (the gate that blocks the branch)"
fi

echo "== scanners caller: the P3a defenses (D27, D35, verdict) =="
SC=install/templates/workflows/scanners.yml
if [ -f "$SC" ]; then
  sc="$(cat "$SC")"

  # D27 — the fork guard MUST be job-level. A step-level skip runs after the job
  # has already checked the fork's code out, turning an admission guard into a
  # no-op. Assert it sits at job indentation (4 spaces), not step (6+).
  # The spelling matters as much as the placement. `head.repo.fork != true` is
  # NULL-PERMISSIVE — a deleted fork on a `reopened` event gives a null
  # `head.repo`, so the guard reads TRUE and the job runs on a fork-origin tree
  # with `security-events: write`. Require the identity test, which fails closed
  # on null, and BAN the negated-flag spelling so a "restore v2 parity" edit
  # cannot quietly reintroduce it.
  if grep -qE '^    if: .*head\.repo\.full_name == github\.repository' "$SC"; then
    _g "scanners: fork guard is JOB-level and null-safe (D27)"
  else
    _r "scanners: fork guard is not job-level, or uses a null-permissive spelling (D27)"
  fi
  # PARSED, not grepped. `assert_absent "$sc" …` matched the COMMENT that
  # explains why the spelling is banned — this file's opening rule ("an
  # assertion about what runs must see only what runs") applied to itself.
  assert_eq "$(python3 - "$SC" <<'PY_NULLPERM'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
conds = []
for j in (d.get("jobs") or {}).values():
    if j.get("if"): conds.append(str(j["if"]))
    for s in (j.get("steps") or []):
        if isinstance(s, dict) and s.get("if"): conds.append(str(s["if"]))
print("BANNED" if any("head.repo.fork" in c for c in conds) else "NONE")
PY_NULLPERM
)" "NONE" "scanners: no null-permissive fork guard in any evaluated if: (null != true is TRUE)"

  # secret-scan must NOT be folded in: it is fork-VISIBLE by design, and a
  # skipped job satisfies a required context, so gitleaks would go green on
  # every fork PR having never run (P3a).
  assert_absent "$sc" "actions/secret-scan" \
    "scanners: does not absorb secret-scan (fork-visible; skipped satisfies a required context)"

  assert_contains "$sc" "security-events: write" "scanners: SARIF grant present (D35)"
  assert_contains "$sc" "continue-on-error: true" "scanners: SARIF upload is best-effort (D35)"
  assert_contains "$sc" 'contains(fromJSON(' "scanners: §23 allowlist, not the v2 blanket cancel (D3)"
  assert_contains "$sc" "  scanners:" "scanners: job id is 'scanners' (D4)"

  # §3.2c — one failing scanner must not hide the other two.
  assert_contains "$sc" "name: verdict" "scanners: has a collect-then-fail verdict step (§3.2c)"
  for s in depscan trivy sast; do
    assert_contains "$sc" "id: $s" "scanners: $s has an id: for the verdict step"
  done

  tmo="$(grep -oE 'timeout-minutes: [0-9]+' "$SC" | grep -oE '[0-9]+' || echo 0)"
  if [ "${tmo:-0}" -ge 50 ]; then _g "scanners: timeout ${tmo} >= 50 (sum of absorbed budgets)"
  else _r "scanners: timeout ${tmo} < 50 — a slow scanner would kill ones that passed"; fi

  # No drift guard and no -private assertion here: `scanners` is UNIFORM
  # PROTECTED (PLAN-014 §1a) — one template, self-hosted on both visibilities —
  # so there is no second file to drift from. The positive assertions that it
  # stays that way live in the "callers invoke EXACTLY" block below.
else
  _r "scanners caller template missing — P2's three scanner actions have no caller"
fi

echo "== scanner actions: the defenses that make them 100-line bodies =="
if [ -f actions/dep-scan/action.yml ]; then
  ds="$(runbody actions/dep-scan/action.yml)"
  assert_contains "$ds" "--no-call-analysis=all" "dep-scan: call analysis disabled in the COMMAND — it compiles source by default (D24)"
  assert_contains "$ds" 'rc" -eq 128' "dep-scan: handles the zero-coverage exit code (D12)"
  assert_contains "$ds" "sha256sum --check --strict" "dep-scan: binary checksum-verified (D20)"
fi
if [ -f actions/trivy-scan/action.yml ]; then
  ts="$(runbody actions/trivy-scan/action.yml)"
  sclist="$(printf '%s' "$ts" | grep -oE '\-\-misconfig-scanners [a-z,]+' | head -1)"
  assert_contains "$sclist" "dockerfile" "trivy: dockerfile scanner enabled (D25)"
  assert_absent "$sclist" "terraform" "trivy: terraform NOT in --misconfig-scanners (SSRF via module source)"
  assert_absent "$sclist" "helm" "trivy: helm NOT in --misconfig-scanners (fetches remote charts)"
  assert_contains "$ts" "sha256sum --check --strict" "trivy: tarball checksum-verified (D20)"
fi
# D23 IS NOT SAST-ONLY (#425), and it is not ACTION-only either. Four shipped
# surfaces run a scanner: the two composite actions AND the two `workflow_call`
# reusables of the same names, which carry their own inline bodies and are what
# `install/templates/workflows/{dep,trivy}-scan.yml` pin. Assert all four, then
# DRIVE them — a static assertion passes against code that deletes nothing.
#
# MEASURED bypasses this closes (pinned tool versions):
#   trivy 0.72.0        root `.trivyignore` / `trivy.yaml`  -> misconfigs 3 -> 0
#   osv-scanner 2.4.0   `osv-scanner.toml` beside a manifest -> results 24 -> 0
#   osv-scanner 2.4.0   `.gitignore` naming a manifest       -> 70 -> 24 (targeted,
#                       exit 1 so D12's zero-coverage arm never fires) or rc=128
D23_SURFACES="actions/trivy-scan/action.yml:trivy:action actions/dep-scan/action.yml:dep:action .github/workflows/trivy-scan.yml:trivy:job .github/workflows/dep-scan.yml:dep:job"
d23_end() { if [ "$1" = trivy ]; then printf '# STATIC scanners ONLY'; else printf '# `--no-ignore` IS A D23 DEFENSE'; fi; }

for _e in $D23_SURFACES; do
  _act="${_e%%:*}"; _rest="${_e#*:}"; _kind="${_rest%%:*}"; _shape="${_rest##*:}"
  if [ ! -f "$_act" ]; then _r "D23: $_act missing — a scanner surface vanished from the guard"; continue; fi
  _b="$(d23_block "$_act" "$(d23_end "$_kind")" "$_shape")"
  if [ -z "$_b" ]; then _r "D23: no D23 block found in $_act — the strip is absent or the slice broke"; continue; fi
  _g "D23: $_act carries a D23 block"
  # Comments are stripped for the static asserts: the block deliberately QUOTES
  # the banned `-print -quit | grep -q .` pattern in order to explain CI-0033,
  # and an assert_absent against the raw text matches that explanation.
  _code="$(printf '%s\n' "$_b" | grep -vE '^[[:space:]]*#' || true)"
  assert_contains "$_code" "-delete" "$_act: the strip is EXECUTED, not described"
  assert_contains "$_code" "-type l" "$_act: the strip matches SYMLINKS (git stores mode 120000)"
  assert_contains "$_code" "exit 1" "$_act: D23 refuses rather than scanning with attacker-chosen coverage"
  # §27.1 / CI-0033: decide on captured OUTPUT, never a pipeline's exit status.
  assert_absent "$_code" "-print -quit | grep" "$_act: D23 does not decide on a pipeline (CI-0033)"
  # ONE definition read by strip and post-condition — the #423 drift class.
  assert_eq "$(printf '%s' "$_code" | grep -c 'd23_scan ')" "2" \
    "$_act: strip AND post-condition call the SAME d23_scan (cannot cover different sets)"
  # scan-path is PR-controllable; `find` reads a leading '-' as an OPTION.
  assert_contains "$_code" "may not begin with" "$_act: scan-path is validated before it reaches find"
done

# `--no-ignore` is a D23 defense on dep-scan, not a tuning knob: osv-scanner
# honours `.gitignore` by default and `.gitignore` cannot be stripped (every repo
# has a legitimate one), so the discovery is disabled gate-side instead.
for _dep in actions/dep-scan/action.yml .github/workflows/dep-scan.yml; do
  [ -f "$_dep" ] || continue
  _shape=action; case "$_dep" in .github/*) _shape=job ;; esac
  assert_contains "$(anybody "$_dep" "$_shape" | grep -vE '^[[:space:]]*#' || true)" "--no-ignore" \
    "$_dep: osv-scanner runs with --no-ignore (a PR-committed .gitignore otherwise picks the coverage)"
done

# RUN THE SHIPPED BLOCK. Both directions, and asserting EFFECT rather than exit
# status: because the strip and the post-condition share one expression, any
# SYMMETRIC scoping regression is self-consistent — the strip stops deleting,
# the check stops looking, rc=0, green. Dropping `-type l` was measured to do
# exactly that, leaving the symlinked config on disk with the suite passing.
_d23="$(mktemp -d)" || _d23=""
if [ -z "$_d23" ] || [ ! -d "$_d23" ]; then
  _r "D23: could not allocate a temp dir — the driven D23 cases did not run"
else
_d23_fixture() {
  rm -rf "$1"; mkdir -p "$1/sub/deep" "$1/deploy"
  : > "$1/.trivyignore"; : > "$1/trivy.yaml"
  : > "$1/sub/deep/osv-scanner.toml"; : > "$1/sub/osv-scanner.toml"
  ln -sf /etc/hostname "$1/sub/.trivyignore"
  mkdir -p "$1/svc"
  ln -sf /etc/hostname "$1/svc/osv-scanner.toml"
  : > "$1/sub/README.md"
  # SCANNABLE CONTENT that shares a config name. `deploy/trivy.yaml` is a
  # plausible Kubernetes manifest and kubernetes is in --misconfig-scanners;
  # MEASURED: trivy reads its config from the working directory ONLY, so a
  # recursive strip of that name would delete coverage in the name of coverage.
  : > "$1/deploy/trivy.yaml"
}
for _e in $D23_SURFACES; do
  _act="${_e%%:*}"; _rest="${_e#*:}"; _kind="${_rest%%:*}"; _shape="${_rest##*:}"
  [ -f "$_act" ] || continue
  _tag="$(basename "$(dirname "$_act")")/$(basename "$_act")"
  d23_block "$_act" "$(d23_end "$_kind")" "$_shape" > "$_d23/blk.sh"
  assert_ok "[ -s '$_d23/blk.sh' ]" "$_tag: a D23 block was found to drive"

  # (a) CLEAN DIRECTION — exits 0, and the configs this scanner owns are GONE.
  _d23_fixture "$_d23/t"
  ( cd "$_d23/t" && bash "$_d23/blk.sh" . >/dev/null 2>&1 )
  assert_eq "$?" "0" "$_tag: D23 exits 0 on a tree it can clean"
  if [ "$_kind" = trivy ]; then
    assert_fail "[ -e '$_d23/t/.trivyignore' ]"     "$_tag: the root .trivyignore is actually GONE (not just rc=0)"
    assert_fail "[ -e '$_d23/t/trivy.yaml' ]"       "$_tag: the root trivy.yaml is actually GONE"
    assert_fail "[ -L '$_d23/t/sub/.trivyignore' ]" "$_tag: the SYMLINKED .trivyignore is GONE (the reproduced bypass)"
    assert_ok   "[ -e '$_d23/t/deploy/trivy.yaml' ]" \
      "$_tag: a NESTED trivy.yaml SURVIVES — trivy reads config from CWD only, so stripping it would delete coverage"
  else
    assert_fail "[ -e '$_d23/t/sub/osv-scanner.toml' ]"      "$_tag: a nested osv-scanner.toml is GONE (config is per-directory)"
    assert_fail "[ -e '$_d23/t/sub/deep/osv-scanner.toml' ]" "$_tag: a DEEPER osv-scanner.toml is GONE"
    assert_fail "[ -L '$_d23/t/svc/osv-scanner.toml' ]"      "$_tag: a SYMLINKED osv-scanner.toml is GONE (the reproduced bypass)"
  fi
  assert_ok "[ -e '$_d23/t/sub/README.md' ]" "$_tag: D23 strips configs, NOT the repo"

  # (b) SURVIVOR DIRECTION — a post-condition that cannot red is decoration.
  _d23_fixture "$_d23/t"
  sed 's/-print -delete/-print/' "$_d23/blk.sh" > "$_d23/mut.sh"
  _out="$( cd "$_d23/t" && bash "$_d23/mut.sh" . 2>&1 || true )"
  assert_fail "( cd '$_d23/t' && bash '$_d23/mut.sh' . >/dev/null 2>&1 )" \
    "$_tag: D23 FAILS CLOSED when a config survives the strip"
  assert_contains "$_out" "::error::" "$_tag: ...and says why, rather than dying under set -e"
  assert_contains "$_out" "D23" "$_tag: ...and names the defense it is enforcing"

  # (c) scan-path as a find OPTION. MEASURED: `find -delete . …` has no path
  # operand, so -delete evaluates against the WHOLE tree and empties the
  # workspace — after which the post-condition certifies the empty tree clean.
  _d23_fixture "$_d23/t"
  # The directory makes `[ ! -d "$SCAN_PATH" ]` PASS, so only the `case -*)` guard
  # can refuse here. Without it the earlier guard masks the mutation and this case
  # certifies a validation that is not there.
  mkdir -p "$_d23/t/-delete"
  _out="$( cd "$_d23/t" && bash "$_d23/blk.sh" '-delete' 2>&1 || true )"
  assert_fail "( cd '$_d23/t' && bash '$_d23/blk.sh' '-delete' >/dev/null 2>&1 )" \
    "$_tag: a scan-path beginning with '-' is REFUSED, not handed to find"
  assert_ok "[ -e '$_d23/t/sub/README.md' ]" "$_tag: ...and the workspace still exists"
  # Assert the VALIDATION's own message, not merely that something refused. The
  # post-condition also fails closed here (find errors, `fst != 0`), so a generic
  # ::error:: check certifies a guard that may not exist — "a guard that cannot be
  # observed to fail is not a guard".
  assert_contains "$_out" "may not begin with" \
    "$_tag: ...refused by the scan-path VALIDATION, not incidentally by the post-condition"

  # (d) a scan-path that does not exist must red with the RIGHT diagnosis, not a
  # supply-chain story about ignore files.
  _d23_fixture "$_d23/t"
  _out="$( cd "$_d23/t" && bash "$_d23/blk.sh" 'no/such/dir' 2>&1 || true )"
  assert_contains "$_out" "not an existing directory" "$_tag: a bad scan-path is diagnosed as a bad scan-path"

  # (e) mktemp failure must not abort before the ::error:: — the bare-assignment
  # shape the block's own `|| fst=$?` comment exists to prevent.
  _d23_fixture "$_d23/t"
  _out="$( cd "$_d23/t" && TMPDIR=/nonexistent-d23-dir bash "$_d23/blk.sh" . 2>&1 || true )"
  assert_contains "$_out" "D23" "$_tag: a mktemp failure still names the gate that refused"
done

# (f) trivy only: a DIRECTORY at the config path. MEASURED: trivy exits FATAL
# ("read trivy.yaml: is a directory"), which the tool-error arm reports as
# "infrastructure/tool error … Re-run." — a permanent red whose stated remedy can
# never work. D23 must name the real cause instead.
for _act in actions/trivy-scan/action.yml .github/workflows/trivy-scan.yml; do
  [ -f "$_act" ] || continue
  _shape=action; case "$_act" in .github/*) _shape=job ;; esac
  d23_block "$_act" "$(d23_end trivy)" "$_shape" > "$_d23/blk.sh"
  _d23_fixture "$_d23/t"; rm -f "$_d23/t/trivy.yaml"; mkdir -p "$_d23/t/trivy.yaml/x"
  _out="$( cd "$_d23/t" && bash "$_d23/blk.sh" . 2>&1 || true )"
  assert_fail "( cd '$_d23/t' && bash '$_d23/blk.sh' . >/dev/null 2>&1 )" \
    "$_act: a DIRECTORY occupying trivy's config path is REFUSED"
  assert_contains "$_out" "NOT an infrastructure error" \
    "$_act: ...and is not mis-sold as an infrastructure failure with a useless 'Re-run'"
done
rm -rf "$_d23"
fi

if [ -f actions/sast-scan/action.yml ]; then
  ss="$(runbody actions/sast-scan/action.yml)"
  # The strip must be an executed `find … -delete`, not a mention.
  strip="$(printf '%s' "$ss" | grep -E "find .*semgrepignore.*-delete" || true)"
  if [ -n "$strip" ]; then
    _g "sast: PR-supplied .semgrepignore is DELETED before scanning (D23 — a verified gate bypass)"
  else
    _r "sast: no executed strip of .semgrepignore — a PR committing '*' silently zeroes coverage (D23)"
  fi
  assert_contains "$ss" "--metrics off" "sast: no telemetry (D26)"
  assert_contains "$ss" '--config "$CONFIG"' "sast: explicit ruleset, never repo-local discovery (D26)"
fi

echo "== verdict steps fail closed, and evaluate every check (D6/§3.2c) =="
# THE GATE-BYPASS CLASS. Deleting the verdict step from BOTH quick-gates variants
# left every check `continue-on-error: true` with nothing to fail the job — the
# required context could never fail — and the suite reported 112 passed, 0 failed.
# Nothing asserted the verdict at all beyond `name: verdict` on `scanners`.
for wf in quick-gates quick-gates-private scanners; do
  f="install/templates/workflows/$wf.yml"
  if [ ! -f "$f" ]; then _r "$wf: template missing"; continue; fi
  vb="$(verdict_body "$f")"
  if [ -z "$vb" ]; then
    _r "$wf: NO verdict step — every check is continue-on-error, so the job can NEVER fail (D6/§3.2c)"
    continue
  fi
  assert_contains "$vb" 'exit "$rc"' "$wf: verdict exits the collected code, not a constant"
  # Fail CLOSED: the failure arm AND the unknown-outcome arm must each set rc=1.
  # `skipped` matters most — P3a establishes that a skipped job SATISFIES a
  # required context, so the same reasoning on a step would launder a crash green.
  assert_eq "$(printf '%s' "$vb" | grep -c 'rc=1')" "2" \
    "$wf: both the failure arm and the unknown-outcome arm set rc=1 (D6/CI-0026)"
  # `rc=0` as the initialiser is correct; `rc=0` inside a case ARM is the
  # mutation (a failing check laundered into a pass). Scope to the arms.
  arms="$(printf '%s' "$vb" | grep -E '^\s*(success|failure|\*)\)' || true)"
  assert_absent "$arms" "rc=0" "$wf: no verdict ARM resets rc to 0"

  # Every check must be continue-on-error AND appear in the verdict loop; every
  # loop entry must correspond to a real step. Either half missing re-opens the
  # bypass: an unevaluated check can fail silently, a phantom entry reads a
  # never-set var.
  cov="$(python3 - "$f" <<'PY_COV'
import sys, re, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
out = []
for j in (d.get("jobs") or {}).values():
    steps = j.get("steps") or []
    checks = [s for s in steps if isinstance(s, dict) and "/actions/" in str(s.get("uses", ""))]
    v = next((s for s in steps if isinstance(s, dict) and s.get("name") == "verdict"), None)
    if v is None:
        out.append("NOVERDICT"); continue
    env, run = (v.get("env") or {}), str(v.get("run", ""))
    m = re.search(r'for chk in ([^;]+); do', run)
    loop = m.group(1).split() if m else []
    for s in checks:
        act = str(s["uses"]).split("/actions/")[1].split("@")[0]
        if s.get("continue-on-error") is not True: out.append("NOTCOE:" + act)
        if not s.get("id"): out.append("NOID:" + act); continue
        key = next((k for k, val in env.items() if "steps.%s.outcome" % s["id"] in str(val)), None)
        if key is None: out.append("UNGUARDED:" + s["id"])
        elif key[2:] not in loop: out.append("NOTINLOOP:" + s["id"])
    for w in loop:
        if ("R_" + w) not in env: out.append("PHANTOM:" + w)
print(" ".join(out) or "OK")
PY_COV
  )"
  assert_eq "$cov" "OK" "$wf: every check is continue-on-error AND evaluated by the verdict (§3.2c)"
done

echo "== callers invoke EXACTLY the documented check set =="
# Deleting a whole check step from a consolidated gate survived the suite: the
# "every referenced action resolves" block checks references→files, never
# files→references, so a gate can silently lose a third of its coverage.
for wf in quick-gates quick-gates-private; do
  f="install/templates/workflows/$wf.yml"; [ -f "$f" ] || continue
  assert_eq "$(invoked_actions "$f")" "links markdownlint pre-commit" \
    "$wf: invokes exactly the three §3.2 checks — no silent drop"
done
assert_eq "$(invoked_actions "$SC")" "dep-scan sast-scan trivy-scan" \
  "scanners: invokes exactly the three P3a scanners"

# UNIFORM PROTECTED (PLAN-014 §1a): self-hosted on public AND private, matching
# the v2 callers, so a visibility flip is a no-op and D1 does NOT require a
# split. Assert BOTH halves — the labels, and the absence of a variant — or a
# future edit re-creates the ubuntu-latest regression this replaced.
scrl="$(grep -E '^\s*runs-on:' "$SC" || true)"
assert_contains "$scrl" "self-hosted" "scanners: self-hosted on public too (PLAN-014 §1a uniform-protected)"
assert_contains "$scrl" "ci-runner"   "scanners: names the real pool label"
if [ -f install/templates/workflows/scanners-private.yml ]; then
  _r "scanners-private.yml exists — a uniform-protected flow must NOT have a visibility split (D1 does not apply)"
else
  _g "scanners: no -private variant, correct for a uniform-protected flow"
fi

echo "== caller inputs asserted from the PARSED mapping, never the file text =="
for wf in quick-gates quick-gates-private; do
  f="install/templates/workflows/$wf.yml"; [ -f "$f" ] || continue
  assert_eq "$(stepwith "$f" links mode)"          "internal"     "$wf: links mode=internal (parsed)"
  assert_eq "$(stepwith "$f" links config-file)"   ".lychee.toml" "$wf: links config-file (parsed)"
  assert_eq "$(stepwith "$f" links fail-on-error)" "true"         "$wf: links is BLOCKING (parsed)"
  assert_eq "$(stepwith "$f" links github-token)"  "<ABSENT>" \
    "$wf: no token passed to an offline links step"
  assert_eq "$(stepwith "$f" markdownlint fail-on-findings)" "true" "$wf: markdownlint is BLOCKING (parsed)"
done
if [ -f "$LX" ]; then
  assert_eq "$(stepwith "$LX" links mode)"          "external" "links-external: mode=external (parsed)"
  assert_eq "$(stepwith "$LX" links fail-on-error)" "true"     "links-external: fail-on-error true so outcome can vary (parsed)"
  assert_eq "$(stepwith "$LX" links github-token)"  '${{ secrets.GITHUB_TOKEN }}' \
    "links-external: token passed (D42)"
fi

echo "== permissions are a CEILING, not a containment (D9/D35) =="
for wf in quick-gates quick-gates-private; do
  f="install/templates/workflows/$wf.yml"; [ -f "$f" ] || continue
  assert_eq "$(perms_of "$f")" '{"contents": "read"}' \
    "$wf: permissions are EXACTLY contents:read (D9)"
done
assert_eq "$(perms_of "$SC")" '{"contents": "read", "security-events": "write"}' \
  "scanners: exactly the two grants D35 needs"

echo "== every -private variant takes the self-hosted pool (D1/OPS-0049) =="
# Looped, not enumerated: `scanners-private` had no runner assertion at all, and
# the drift guard sed's `runs-on:` away before diffing, so the runner line was
# the one thing structurally excluded from comparison.
# Scoped to callers carrying a LITERAL `runs-on:` — i.e. the v3 composite-action
# callers. The v2 `-private` templates express the pool as a `runner_labels`
# STRING INPUT to a reusable, which is why actionlint never saw a label there
# (§3.2e) and why this shape check does not apply to them.
for pv in install/templates/workflows/*-private.yml; do
  [ -f "$pv" ] || continue
  rl="$(grep -E '^\s*runs-on:' "$pv" || true)"
  [ -n "$rl" ] || continue
  b="$(basename "$pv")"
  assert_contains "$rl" "self-hosted"   "$b: runs-on line is the self-hosted pool"
  assert_contains "$rl" "ci-runner"     "$b: names the real pool label"
  assert_absent   "$rl" "runner-self"   "$b: not the dead pre-v1.9.0 placeholder"
  assert_absent   "$rl" "ubuntu-latest" "$b: never GitHub-hosted on a private repo"
done

echo "== every SARIF upload carries its own fork clause (D35) =="
# Looped over the uses:, not enumerated per category — the drop hit all three
# upload steps at once, so any check written per-scanner would have had to be
# wrong three times to miss it, and instead there simply was none. The job-level
# `if:` is NOT a substitute: it is null-permissive on a deleted-fork `reopened`
# event, and in v2 each upload guarded itself.
mapfile -t SARIF_STEPS < <(python3 - <<'PY_SS'
import glob, yaml
for f in sorted(glob.glob("install/templates/workflows/*.yml")):
    d = yaml.safe_load(open(f)) or {}
    for j in (d.get("jobs") or {}).values():
        for s in (j.get("steps") or []):
            if isinstance(s, dict) and "codeql-action/upload-sarif" in str(s.get("uses", "")):
                print("%s|%s|%s" % (f, s.get("name", "?"), s.get("if", "")))
PY_SS
)
assert_ok "[ ${#SARIF_STEPS[@]} -ge 3 ]" "SARIF-upload check found the upload steps to check"
for row in "${SARIF_STEPS[@]}"; do
  IFS='|' read -r sf sname sif <<< "$row"
  assert_contains "$sif" "head.repo.full_name == github.repository" \
    "$(basename "$sf") / $sname: upload carries its own null-safe fork clause (D35)"
  assert_contains "$sif" "hashFiles"      "$(basename "$sf") / $sname: upload is guarded on a produced report"
done

echo "== the SARIF paths cannot be supplied by the PR (H1) =="
# A PR-committed osv/trivy/semgrep.sarif satisfies `hashFiles` exactly as a real
# report does, and an empty `results` array REPLACES the category's analysis —
# resolving every open alert as fixed. The purge must run BEFORE the first
# scanner, or the scanner overwrites the evidence that it was there.
if [ -f "$SC" ]; then
  assert_eq "$(python3 - "$SC" <<'PY_PURGE'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
steps = [s for j in (d.get("jobs") or {}).values() for s in (j.get("steps") or []) if isinstance(s, dict)]
purge = next((i for i, s in enumerate(steps) if "PR-supplied SARIF" in str(s.get("name", ""))), None)
first = next((i for i, s in enumerate(steps) if "/actions/" in str(s.get("uses", ""))), None)
print("ORDERED" if purge is not None and first is not None and purge < first else "BAD")
PY_PURGE
)" "ORDERED" "scanners: the SARIF purge runs before the first scanner"
  purge_body="$(named_step_body "$SC" "Purge PR-supplied SARIF before scanning (gate-decides-the-report)")"
  assert_contains "$purge_body" "exit 1" "scanners: the purge REFUSES on a survivor rather than continuing"
  # §27.1: the survivor test must read captured output, not a pipeline status.
  assert_absent "$purge_body" "-print -quit | grep" "scanners: purge does not decide on a pipeline (CI-0033)"

  # RUN THE SHIPPED BODY. Every assertion above passed against a first draft
  # whose `rm -f` aborted under `set -e` on a directory survivor — fail-closed,
  # but with NO ::error::, so the operator got a red step and no cause. Reading
  # could not see it; only executing it could. Four trees, because the
  # interesting cases are the ones `rm` cannot clear.
  _pg="$(mktemp -d)"; printf '%s\n' "$purge_body" > "$_pg/purge.sh"
  _run_purge() { ( cd "$1" && bash "$_pg/purge.sh" 2>&1 ); }

  mkdir -p "$_pg/clean"
  assert_ok "_run_purge '$_pg/clean' >/dev/null" "purge: clean tree passes"

  mkdir -p "$_pg/file"; echo '{}' > "$_pg/file/semgrep.sarif"
  assert_ok "_run_purge '$_pg/file' >/dev/null" "purge: a PR-committed SARIF file is removed and the step passes"
  assert_ok "[ ! -e '$_pg/file/semgrep.sarif' ]" "purge: ...and the file is actually gone"

  mkdir -p "$_pg/link"; ln -sf /etc/hostname "$_pg/link/trivy.sarif"
  assert_ok "_run_purge '$_pg/link' >/dev/null" "purge: a SYMLINK survivor is removed (git stores mode 120000)"
  assert_ok "[ ! -e '$_pg/link/trivy.sarif' ]" "purge: ...and the symlink is actually gone"

  # The case that broke the first draft: `rm -f` cannot remove a directory.
  mkdir -p "$_pg/dir/osv.sarif"
  _dir_out="$(_run_purge "$_pg/dir" || true)"
  assert_fail "_run_purge '$_pg/dir' >/dev/null 2>&1" "purge: a DIRECTORY survivor fails the step closed"
  assert_contains "$_dir_out" "::error::" "purge: ...and says why, rather than dying under set -e"
  assert_contains "$_dir_out" "osv.sarif" "purge: ...and names the survivor"
  rm -rf "$_pg"
fi

echo "== every ubuntu-latest caller HAS a private variant (D1/OPS-0049) =="
# THE OTHER DIRECTION, and the one that was missing. The loop above checks that
# a private variant, IF PRESENT, is self-hosted. Nothing asserted that a template
# which NEEDS one HAS one — so `links-external.yml` shipped `ubuntu-latest` with
# no sibling and every assertion stayed green. On a private consumer that job
# queues forever, and because it feeds no required context nothing ever reds:
# the external link reports simply stop arriving.
#
# The rule is not "fork-code execution" — that is why quick-gates SPLITS rather
# than going uniformly self-hosted. It is OPS-0049: no GitHub-hosted minutes on
# a private repo at all. So every manifested caller pinning a literal
# `ubuntu-latest` must name a private variant; a caller already self-hosted on
# both (uniform-protected, PLAN-014 §1a — `scanners`) needs none.
# TWO assertions per caller, and the second is not redundant. Deleting
# links-external-private.yml while leaving its manifest row in place left this
# block fully green on the first draft — the check read the MANIFEST'S CLAIM
# about the file rather than the file. `install.sh` resolves the variant by
# path, so a declared-but-absent private template is exactly the queue-forever
# state, arrived at from the other side.
# ROW-COUNT FLOOR. Measured: making the manifest query return nothing (a renamed
# key) emptied this whole section with the suite still green — the CI-0034 shape.
# The floor is the one statement not derived from the query it polices.
mapfile -t _vv_rows < <(python3 - <<'PY_VV0'
import json
m = json.load(open("install/templates/manifest.json"))
for e in m.get("files") or []:
    t = e.get("template") or ""
    if not t.startswith("workflows/"):
        continue
    v = e.get("visibility_variants") or {}
    ok = bool(v.get("public") and v.get("private"))
    print("%s|%s|%s" % (t, "yes" if ok else "no", v.get("private") or ""))
PY_VV0
)
assert_ok "[ ${#_vv_rows[@]} -ge 10 ]" "manifest yielded workflow rows to check (got ${#_vv_rows[@]})"
for _row in "${_vv_rows[@]}"; do
  IFS='|' read -r tpl variants priv <<< "$_row"
  [ -n "$tpl" ] || continue
  f="install/templates/$tpl"
  [ -f "$f" ] || continue
  rl="$(grep -E '^\s*runs-on:' "$f" || true)"
  case "$rl" in
    *ubuntu-latest*) ;;
    *) continue ;;   # self-hosted already, or a v2 runner_labels reusable caller
  esac
  b="$(basename "$tpl")"
  assert_eq "$variants" "yes" \
    "$b: pins ubuntu-latest, so manifest.json must give it a private variant (OPS-0049)"
  [ "$variants" = "yes" ] || continue
  assert_ok "[ -f 'install/templates/$priv' ]" \
    "$b: the private variant it declares ($priv) is actually on disk"
done

echo "== links-external actually reports (D42) =="
# `fail-on-error` and `continue-on-error` are a PAIR here. actions/links exits 0
# for every lychee result short of a timeout when fail-on-error is false, so
# `steps.links.outcome` is pinned to `success`, the report's `failure` arm is
# unreachable and dead links render as "no dead outbound links". The job must
# still not FAIL, which is what continue-on-error delivers — outcome varies,
# conclusion does not.
for lx in install/templates/workflows/links-external.yml \
          install/templates/workflows/links-external-private.yml; do
  [ -f "$lx" ] || continue
  b="$(basename "$lx")"
  assert_eq "$(stepwith "$lx" links fail-on-error)" "true" \
    "$b: fail-on-error true, or steps.links.outcome can never be 'failure'"
  assert_eq "$(python3 - "$lx" <<'PY_COE'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
for j in (d.get("jobs") or {}).values():
    for s in (j.get("steps") or []):
        if isinstance(s, dict) and "/actions/links@" in str(s.get("uses", "")):
            print(str(s.get("continue-on-error", "<ABSENT>")).lower()); raise SystemExit(0)
print("<NOSTEP>")
PY_COE
)" "true" "$b: continue-on-error true, so the report stays non-blocking"
  # And the arm the pairing exists to make reachable is still there.
  assert_contains "$(named_step_body "$lx" report)" "dead outbound link" \
    "$b: the failure arm still emits a warning a human will see"
done

echo "== private variant (D1) =="
# D1: install.sh --update resolves each surface through manifest.json's
# visibility_variants. With no private variant it re-applies the label-less
# generic, the ubuntu-latest default wins, and jobs QUEUE FOREVER on a private
# repo — the defect ci/v2.1.0 shipped the variants to close.
QGP=install/templates/workflows/quick-gates-private.yml
if [ -f "$QGP" ]; then
  qgp="$(cat "$QGP")"

  # Assert the LABEL LINE, not the file. `assert_contains "$qgp" "self-hosted"`
  # is satisfied by the header comment that explains the private variant, so it
  # would survive a revert of runs-on: to ubuntu-latest — the same
  # grep-the-key's-own-documentation failure this suite already fixed for D21.
  runsline="$(grep -E '^\s*runs-on:' "$QGP" || true)"
  assert_contains "$runsline" "self-hosted" "quick-gates-private: runs-on line uses the self-hosted pool (D1/OPS-0049)"
  assert_contains "$runsline" "ci-runner" "quick-gates-private: runs-on names the real pool label"
  # 'runner-self' was a placeholder shipped before ci/v1.9.0 and is NOT a
  # registered label — a caller left on it queues forever.
  assert_absent "$runsline" "runner-self" "quick-gates-private: not the dead 'runner-self' placeholder"

  # The private variant carries D3, D4, D9 and the checkout posture exactly as
  # the public one does, and NOTHING else in the repo reaches it:
  # test_contract.sh's caller checks key off `runner_labels` (v3 uses a literal
  # runs-on, so they skip), and its CI-0025 evaluator builds its set from
  # required-context-map.py, which only sees jobs whose body is `uses:` a
  # reusable. Per §3.2a, a defense that moved to a file nothing checks is a
  # defense that was dropped — so assert the two files are identical apart from
  # the documented runner line and header block.
  assert_contains "$qgp" 'contains(fromJSON(' "quick-gates-private: §23 allowlist (D3)"
  assert_absent "$qgp" "cancel-in-progress: true" "quick-gates-private: no blanket cancel (D3)"
  assert_contains "$qgp" "  quick-gates:" "quick-gates-private: same job id, same context (D4)"
  assert_contains "$qgp" "persist-credentials: false" "quick-gates-private: no persisted creds"
  assert_absent "$qgp" "ref: \${{ github.event.pull_request.head.sha }}" \
    "quick-gates-private: no head.sha pin — merge-commit parity"
  assert_contains "$qgp" "contents: read" "quick-gates-private: least-privilege grant (D9)"

  # Drift guard: normalise the two known deltas and require the rest to match.
  # Without this the variants diverge silently, which is what regenerating one
  # by script was meant to prevent — and a script can be run once and forgotten.
  if command -v diff >/dev/null 2>&1; then
    d="$(diff <(sed -E 's/^\s*runs-on:.*/RUNNER/' "$QGP" | sed -n '/^name:/,$p') \
              <(sed -E 's/^\s*runs-on:.*/RUNNER/' "$QG"  | sed -n '/^name:/,$p') | grep -c '^[<>]' || true)"
    assert_eq "$d" "0" "quick-gates public/private bodies identical below the header (drift guard)"
  fi

  if command -v actionlint >/dev/null 2>&1; then
    assert_ok "actionlint '$QGP' >/dev/null 2>&1" "quick-gates-private: actionlint clean (needs .github/actionlint.yaml)"
  fi
else
  _r "quick-gates-private variant missing — --update will revert private consumers to ubuntu-latest (D1)"
fi

echo "== actionlint knows the self-hosted labels (PLAN-025 §3.2e) =="
# v3 callers carry a LITERAL runs-on with custom labels (v2 passed a JSON string
# input, so actionlint never saw a label). Without this config every private
# caller fails actionlint — here, in pre_push_check.sh, and on every consumer.
AL=.github/actionlint.yaml
if [ -f "$AL" ]; then
  al="$(cat "$AL")"
  assert_contains "$al" "ci-runner" "actionlint.yaml declares ci-runner"
  assert_contains "$al" "single-use" "actionlint.yaml declares single-use"
else
  _r "no .github/actionlint.yaml — every private v3 caller fails the runner-label rule"
fi

echo "== every referenced action resolves =="
# A caller naming an action that does not exist in the tree is a run-init
# `startup_failure` on every consumer — the same invisible class as an
# unmatched runner label, and nothing else in the suite catches it. The first
# quick-gates draft referenced three actions that had not been written.
missing=0
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  act="${ref#vladm3105/aidoc-flow-ci/actions/}"; act="${act%@*}"
  if [ -f "actions/$act/action.yml" ]; then
    _g "resolves: actions/$act/action.yml"
  else
    _r "DANGLING: '$ref' has no actions/$act/action.yml"
    missing=$((missing+1))
  fi
done < <(grep -rhoE 'vladm3105/aidoc-flow-ci/actions/[^@[:space:]]+@[^[:space:]]+' \
           install/templates/workflows/ .github/workflows/ 2>/dev/null | sort -u)
[ "$missing" -eq 0 ] || printf '  \033[33mnote\033[0m %d dangling reference(s) — the caller will startup_failure\n' "$missing"

echo "== the links token is passed IFF the mode can use it =="
# A biconditional, because both directions are real defects and the one-way rule
# ("callers must pass the token, the secrets context is unavailable inside a
# composite action") was applied universally and put an unusable credential in
# `quick-gates`.
#   mode: external → lychee makes live requests and hits github.com's anonymous
#     rate limits without a token. Omitting it degrades the weekly report.
#   mode: internal → `--offline` (actions/links/action.yml:110), no request is
#     made, the token is never read — and in v3 it would sit in the same job,
#     PATH and process namespace as the step that executes the PR's own
#     `.pre-commit-config.yaml`. v2 kept those on separate runners.
mapfile -t _tok_rows < <(python3 - <<'PY_TOK0'
import glob, yaml
for wf in sorted(glob.glob("install/templates/workflows/*.yml")):
    d = yaml.safe_load(open(wf)) or {}
    for j in (d.get("jobs") or {}).values():
        for s in (j.get("steps") or []):
            if not isinstance(s, dict) or "/actions/links@" not in str(s.get("uses", "")):
                continue
            w = s.get("with") or {}
            print("%s|%s|%s" % (wf, w.get("mode", "<ABSENT>"), w.get("github-token", "<ABSENT>")))
PY_TOK0
)
# FLOOR: four callers invoke actions/links (quick-gates{,-private},
# links-external{,-private}). A typo in the `uses:` match emptied this section.
assert_ok "[ ${#_tok_rows[@]} -ge 4 ]" "found the links call sites to check (got ${#_tok_rows[@]})"
for _row in "${_tok_rows[@]}"; do
  IFS='|' read -r wf mode tok <<< "$_row"
  [ -n "$wf" ] || continue
  b="$(basename "$wf")"
  if [ "$mode" = "external" ]; then
    assert_ok "[ '$tok' != '<ABSENT>' ]" "$b: mode=external MUST carry a token (rate limits)"
  else
    assert_eq "$tok" "<ABSENT>" "$b: mode=$mode is offline — must NOT carry a token it cannot use"
  fi
done

echo "== job timeout EXCEEDS the sum of the inner tool timeouts (§3.2b) =="
# v2: pre-commit 15 + markdownlint 10 + links 20 = 45. A consolidated job that
# takes the MAX kills checks that already passed when the slowest one runs long.
#
# But the sum is a FLOOR, not the answer, and shipping exactly the sum was the
# defect. Each action wraps its tool in `timeout N`, and those wrappers are the
# only path that prints "infrastructure failure, not a clean run" — a job-level
# kill at the same minute pre-empts every one of them, and additionally CANCELS
# the `if: always()` verdict step, losing collect-then-fail in exactly the case
# it exists for. Provisioning (checkout, setup-python, setup-node, `npm -g`,
# `python3 -m venv` + pip, three verified binary downloads) is unbudgeted by the
# sum entirely.
#
# DERIVED FROM THE ACTIONS, not restated. A hardcoded `>= 45` is satisfiable by
# editing the caller alone; this resolves each `uses:` to its action file and
# adds up what that action actually enforces, so raising an inner timeout
# without raising the job's is a red.
mapfile -t _tmo_rows < <(python3 - <<'PY_TMO'
import glob, re, yaml

def code_only(body):
    # STRIP COMMENTS. `re.findall(r'timeout (\d+)')` over a raw body reads the
    # PROSE explaining a timeout as if it were one: dep-scan step 1 yielded
    # ['900','900','900'] where only one is code. `max()` hid it here, but a
    # comment naming a larger number would have inflated the demanded budget.
    return "\n".join(l for l in str(body).split("\n") if not re.match(r'\s*#', l))

def inner_seconds(action_path, opt_in_enabled):
    d = yaml.safe_load(open(action_path)) or {}
    total = 0
    for s in ((d.get("runs") or {}).get("steps") or []):
        if not isinstance(s, dict) or "run" not in s:
            continue
        # A conditional step counts ONLY when the caller turns it on. Skipping
        # every `if:` step unconditionally under-budgeted the exact case this
        # check exists for: sast-scan's autofix preview carries its own
        # `timeout 1200`, so a caller passing `autofix-preview: true` really
        # needs 70m against scanners' 60 — and the check computed 50 and passed.
        if s.get("if") and not opt_in_enabled:
            continue
        found = [int(m) for m in re.findall(r'\btimeout\s+(\d+)\b', code_only(s["run"]))]
        total += max(found) if found else 0
    return total

# Inputs whose truthiness enables an `if:`-gated step inside the action.
OPT_IN = {"sast-scan": "autofix-preview"}

for wf in sorted(glob.glob("install/templates/workflows/*.yml")):
    d = yaml.safe_load(open(wf)) or {}
    tot = 0
    for j in (d.get("jobs") or {}).values():
        for s in (j.get("steps") or []):
            u = str(s.get("uses", "")) if isinstance(s, dict) else ""
            if "/actions/" not in u:
                continue
            name = u.split("/actions/")[1].split("@")[0]
            w = s.get("with") or {}
            key = OPT_IN.get(name)
            enabled = key is not None and str(w.get(key, "false")).lower() == "true"
            for cand in ("actions/%s/action.yml" % name, "actions/%s/action.yaml" % name):
                try:
                    tot += inner_seconds(cand, enabled); break
                except FileNotFoundError:
                    continue
    if tot:
        print("%s|%d" % (wf, tot))
PY_TMO
)
# FLOOR: five callers invoke composite actions. Pointing the resolver at a
# nonexistent filename emptied this section with the suite green.
assert_ok "[ ${#_tmo_rows[@]} -ge 5 ]" "resolved inner timeouts for the callers (got ${#_tmo_rows[@]})"
for _row in "${_tmo_rows[@]}"; do
  IFS='|' read -r wf inner_s <<< "$_row"
  [ -n "$wf" ] || continue
  b="$(basename "$wf")"
  job_m="$(grep -oE 'timeout-minutes: [0-9]+' "$wf" | grep -oE '[0-9]+' | head -1 || echo 0)"
  inner_m=$(( inner_s / 60 ))
  assert_ok "[ ${job_m:-0} -gt $inner_m ]" \
    "$b: job timeout ${job_m}m EXCEEDS the ${inner_m}m its actions enforce internally"
done

echo "== every step declares the env it reads (the D11 wrong-stage class) =="
# ASSERT THE INPUT IS NON-EMPTY FIRST. A checker handed zero files prints
# nothing and reads as a pass — the same vacuous-oracle failure the
# invoked-action check in test_sigpipe_guard.sh was rewritten to close.
assert_ok "[ ${#ACTIONS[@]} -ge 6 ]" "env-declaration check has all six actions as input"
undeclared="$(undeclared_env "${ACTIONS[@]}")"
assert_eq "$undeclared" "UE-CLEAN" "no composite step reads an env var its own step never declared"

# GUARD THE GUARD. Two synthetic actions, because "prints nothing" is the
# expected output of both a clean tree and a broken checker.
_ue_probe="$(mktemp -d)"
cat > "$_ue_probe/bad.yml" <<'PROBE_BAD'
name: probe
runs:
  using: composite
  steps:
    - name: reads an undeclared var
      shell: bash
      run: echo "${SOME_STAGE:-fallback}"
    - name: declares it too late
      shell: bash
      env:
        SOME_STAGE: x
      run: echo "$SOME_STAGE"
PROBE_BAD
cat > "$_ue_probe/good.yml" <<'PROBE_GOOD'
name: probe
runs:
  using: composite
  steps:
    - name: declared in this step
      shell: bash
      env:
        SOME_STAGE: x
      run: echo "${SOME_STAGE:-fallback}"
    - name: assigned locally, and one the runner provides
      shell: bash
      run: |
        LOCAL_DIR="$RUNNER_TEMP/x"
        echo "$LOCAL_DIR" >> "$GITHUB_STEP_SUMMARY"
PROBE_GOOD
assert_contains "$(undeclared_env "$_ue_probe/bad.yml")" 'reads $SOME_STAGE' \
  "checker catches a var declared on a LATER step (the actual B2 shape)"
assert_eq "$(undeclared_env "$_ue_probe/good.yml")" "UE-CLEAN" \
  "checker does not flag env-declared, locally-assigned or runner-provided vars"

# ONE PROBE PER DECLARER. Measured: disabling LOOPRD or GHENV against the real
# six actions suppressed NOTHING — ASSIGN accounted for all five suppressions —
# so two of four declarers were unexercised by both the corpus and the probes,
# and a defect in either was undetectable.
cat > "$_ue_probe/declarers.yml" <<'PROBE_DECL'
name: probe
runs:
  using: composite
  steps:
    - name: for-loop variable
      shell: bash
      run: |
        for CHK in a b; do echo "$CHK"; done
    - name: exported to later steps via GITHUB_ENV
      shell: bash
      run: |
        echo "BIN_DIR=/tmp/x" >> "$GITHUB_ENV"
        echo "$BIN_DIR"
PROBE_DECL
assert_eq "$(undeclared_env "$_ue_probe/declarers.yml")" "UE-CLEAN" \
  "checker honours for-loop vars (LOOPRD) and \$GITHUB_ENV exports (GHENV)"

# THE TWO FALSE NEGATIVES, as expected-HIT cases. A declarer that can fire on
# prose masks a real undeclared read of the same name — and both of these named
# the exact variables of the B2 defect.
cat > "$_ue_probe/prose.yml" <<'PROBE_PROSE'
name: probe
runs:
  using: composite
  steps:
    - name: the word read inside a string is not a declaration
      shell: bash
      run: |
        echo "cannot read CONFIG_PATH from the tree"
        cat "$CONFIG_PATH"
    - name: a heredoc body line is not a declaration
      shell: bash
      run: |
        cat > out.env <<CFG
        RUN_STAGE=${RUN_STAGE:-pre-commit}
        CFG
PROBE_PROSE
_prose="$(undeclared_env "$_ue_probe/prose.yml")"
assert_contains "$_prose" 'reads $CONFIG_PATH' \
  "checker is not fooled by the word 'read' inside a string literal"
assert_contains "$_prose" 'reads $RUN_STAGE' \
  "checker is not fooled by an assignment inside a heredoc body"

# A CRASH MUST NOT READ AS CLEAN. This is the call site where silence was the
# success value; a schema-invalid list-valued env: used to raise AttributeError,
# print nothing, and pass.
cat > "$_ue_probe/weird.yml" <<'PROBE_WEIRD'
name: probe
runs:
  using: composite
  steps:
    - name: list-valued env is schema-invalid but parses
      shell: bash
      env:
        - NOT_A_MAPPING
      run: echo "$UNDECLARED_THING"
PROBE_WEIRD
assert_contains "$(undeclared_env "$_ue_probe/weird.yml" 2>&1)" 'reads $UNDECLARED_THING' \
  "a malformed env: block degrades to 'undeclared', never to silence"
rm -rf "$_ue_probe"

echo "== the D11 guard validates the stage the run will actually use =="
# Structural, not textual: find the step whose body counts hooks and the step
# that runs them, and require both to resolve run-stage from the SAME input. A
# grep for `RUN_STAGE` passed throughout the defect — the name was present in
# both steps, just declared in only one.
assert_eq "$(python3 - <<'PY_D11'
import yaml
d = yaml.safe_load(open("actions/pre-commit/action.yml"))
steps = d["runs"]["steps"]
guard = next(s for s in steps if "selects ZERO hooks" in str(s.get("run", "")))
run   = next(s for s in steps if "--all-files" in str(s.get("run", "")))
g, r = (guard.get("env") or {}).get("RUN_STAGE"), (run.get("env") or {}).get("RUN_STAGE")
# ASSERT THE LITERAL, not just equality. `g == r` is satisfied by wiring BOTH to
# a nonexistent input, and the execution test injects RUN_STAGE from outside so
# it cannot see that either — two green checks over a guard reading nothing.
want = "${{ inputs.run-stage }}"
print("MATCH" if g == want and r == want else "MISMATCH(g=%r r=%r)" % (g, r))
PY_D11
)" "MATCH" "D11 guard and hook run resolve run-stage from the same input"

# RUN THE SHIPPED GUARD. The structural check above proves the wiring; only
# execution proves the COUNT is right, and every one of these cases was either a
# live defect or a near miss.
_d11="$(mktemp -d)"
python3 - > "$_d11/guard.sh" <<'PY_X'
import yaml
d = yaml.safe_load(open("actions/pre-commit/action.yml"))
for s in d["runs"]["steps"]:
    if "selects ZERO hooks" in str(s.get("run", "")):
        print(s["run"]); break
PY_X
_hook_cfg() { printf 'repos:\n- repo: local\n  hooks:\n  - id: a\n%s\n' "$1"; }
_hook_cfg "    stages: [pre-commit]" > "$_d11/normal.yaml"
_hook_cfg "    stages: [commit]"     > "$_d11/legacy.yaml"
_hook_cfg "    stages: [manual]"     > "$_d11/manual.yaml"
_hook_cfg ""                         > "$_d11/nostages.yaml"
_d11_run() { ( CONFIG_PATH="$_d11/$1.yaml" RUN_STAGE="$2" bash "$_d11/guard.sh" >/dev/null 2>&1 ); }

assert_ok   "_d11_run normal pre-commit"   "D11: a commit-stage hook counts at pre-commit"
assert_fail "_d11_run normal manual"       "D11: it does NOT count at manual (B2 scenario A — the silent pass)"
assert_fail "_d11_run manual pre-commit"   "D11: an all-manual config is refused at pre-commit"
assert_ok   "_d11_run manual manual"       "D11: ...and accepted at manual (B2 scenario B — the false red)"
# NOTE THE WORDING. An earlier version of these two said "a hook with no
# stages: counts at every stage", which is FALSE and the guard's own comment
# repeated it: when the consumer config omits `stages:`, the hook repo's remote
# MANIFEST decides, and a manifest declaring `stages: [pre-push]` means
# `pre-commit run` selects nothing while this guard counts one. What these
# assert is only the guard's LOCAL behaviour on the config it can see — the
# guard is a fast pre-check, NOT D11's post-condition. #426 closed that hole in
# the "Run hooks" step, and the block at the end of this section drives it.
assert_ok   "_d11_run nostages pre-commit" "D11: a config-level hook with no stages: is counted (local view)"
assert_ok   "_d11_run nostages manual"     "D11: ...at any requested stage"
# The action must not be STRICTER than the operator-side detector that clears a
# repo for adoption — tests/lib_count_stage_hooks.py accepts the legacy spelling,
# so a consumer cleared by it must not be hard-failed by the action on day one.
assert_ok   "_d11_run legacy pre-commit"   "D11: legacy 'commit' stage is accepted, matching canon's own detector"

# A SCALAR `stages:` is legal-looking YAML. Before normalisation `accepted
# .intersection("manual")` walked the string CHARACTER-wise, matched nothing,
# and hard-failed a correct config while blaming the stage.
printf 'repos:\n- repo: local\n  hooks:\n  - id: a\n    stages: manual\n' > "$_d11/scalar.yaml"
assert_ok   "_d11_run scalar manual"       "D11: a scalar stages: value is honoured, not walked character-wise"
assert_fail "_d11_run scalar pre-commit"   "D11: ...and still refuses at a stage it does not name"
# ── D11's REAL post-condition: the RUN, not the prediction (#426) ────────────
# The guard above parses the config. When a hook omits `stages:` the hook repo's
# remote MANIFEST decides, and no parser can see it. REPRODUCED at pre-commit
# 4.5.1 and 4.6.0 (the pinned version) against a manifest of `stages: [pre-push]`
# with a silent config:
#   guard -> "1 hook(s) selected at stage 'pre-commit'", exit 0
#   run   -> no hook output at all,                      exit 0
#
# BOTH SURFACES are driven. Every consumer calls the REUSABLE, not the composite
# action, so an action-only fix would have landed where nothing runs — the same
# two-surface mistake #425 had to correct. FT-31 reserved this move for a founder
# call; resolved as CI-0039.
_D11_SURFACES="actions/pre-commit/action.yml:action .github/workflows/pre-commit.yml:job"

# FIXTURES ARE GENERATED BY THE REAL TOOL WHERE IT IS AVAILABLE. Hand-typed
# padding is what hid the defect: the width is computed per run from the LONGEST
# selected hook name, and for that hook's `(no files to check)` line it collapses
# to THREE dots — a hand-written literal with 35 dots can never expose a regex
# that requires four. Where pre-commit is absent the literals below are used, and
# they are the MEASURED shapes, not invented ones.
_rh="$(mktemp -d)" || _rh=""
if [ -z "$_rh" ] || [ ! -d "$_rh" ]; then
  _r "D11: could not allocate a temp dir — the run-post-condition cases did not run"
else
_PASSLINE='check yaml...............................................................Passed'
# THE 3-DOT CASE. Measured from pre-commit against a 60-character hook name whose
# `files:` matches nothing; this is the line the previous `\.\.\.\.+` missed.
_SKIPLINE='Ensure every BDD scenario has a paired TDD test in the suite...(no files to check)Skipped'
if command -v pre-commit >/dev/null 2>&1; then
  ( mkdir -p "$_rh/gen" && cd "$_rh/gen" && git init -q . && : > a.txt && git add -A
    printf 'repos:\n  - repo: local\n    hooks:\n      - id: l\n        name: Ensure every BDD scenario has a paired TDD test in the suite\n        entry: "true"\n        language: system\n        files: ^no-match$\n      - id: s\n        name: short one\n        entry: "true"\n        language: system\n        always_run: true\n' > .pre-commit-config.yaml
    pre-commit run --all-files --color=never > gen.txt 2>&1 || true ) >/dev/null 2>&1
  if [ -s "$_rh/gen/gen.txt" ]; then
    _gen_skip="$(grep -E '\(no files to check\)Skipped$' "$_rh/gen/gen.txt" | head -1)"
    _gen_pass="$(grep -E '[^)]Passed$' "$_rh/gen/gen.txt" | head -1)"
    [ -n "$_gen_skip" ] && _SKIPLINE="$_gen_skip"
    [ -n "$_gen_pass" ] && _PASSLINE="$_gen_pass"
    _g "D11 run: fixtures GENERATED by the real pre-commit (padding is computed, never assumed)"
    # The property that broke the first implementation, pinned directly.
    _dots="$(printf '%s' "$_SKIPLINE" | grep -oE '\.+\(no files' | head -1)"
    assert_ok "[ ${#_dots} -lt 14 ]" "D11 run: the longest hook's no-files line has FEW dots (padding is per-run, not fixed)"
  else
    _g "D11 run: pre-commit present but fixture generation produced nothing — using measured literals"
  fi
else
  _g "D11 run: pre-commit not installed — using MEASURED literals for the fixtures"
fi

mkdir -p "$_rh/bin"
# The shim records ARGV as well as emitting scripted output: "a stub that controls
# only what a command returns tests nothing about how it was called".
cat > "$_rh/bin/pre-commit" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SHIM_ARGV"
# Record whether SKIP reached the CHILD. That is the property `env -u SKIP`
# buys, and it is invisible to an argv-only stub.
printf 'SKIP_IN_CHILD=%s\n' "${SKIP-<unset>}" >> "$SHIM_ARGV"
[ -n "${SHIM_OUT:-}" ] && printf '%s\n' "$SHIM_OUT"
exit "${SHIM_RC:-0}"
SHIM
chmod +x "$_rh/bin/pre-commit"

for _e in $_D11_SURFACES; do
  _sf="${_e%%:*}"; _sk="${_e##*:}"
  if [ ! -f "$_sf" ]; then _r "D11 run: $_sf missing — a pre-commit surface vanished"; continue; fi
  python3 - "$_sf" "$_sk" > "$_rh/runhooks.sh" <<'PY_RH'
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
steps = [s for j in (d.get("jobs") or {}).values() for s in (j.get("steps") or [])] \
        if sys.argv[2] == "job" else ((d.get("runs") or {}).get("steps") or [])
for s in steps:
    if s.get("name") == "Run hooks":
        print(s["run"]); break
PY_RH
  # A truncated or empty extraction must be ONE clear failure, not a cascade of
  # unrelated assertion errors from an empty script.
  if [ ! -s "$_rh/runhooks.sh" ]; then
    _r "D11 run: could not extract the 'Run hooks' body from $_sf — every case below would be vacuous"
    continue
  fi
  _g "D11 run: extracted the shipped 'Run hooks' body from $_sf"
  _rh_run() { # $1 stage, $2 shim stdout, $3 shim rc
    : > "$_rh/argv"
    ( PATH="$_rh/bin:$PATH" RUN_STAGE="$1" SHIM_OUT="$2" SHIM_RC="$3" SHIM_ARGV="$_rh/argv" \
      bash "$_rh/runhooks.sh" 2>&1 )
  }

  # 1. THE #426 CASE — exits 0 having printed nothing.
  _out="$(_rh_run pre-commit "" 0)"; _rc=$?
  assert_eq "$_rc" "1" "$_sf: a green run that executed ZERO hooks REDS (#426)"
  assert_contains "$_out" "executed ZERO hooks" "$_sf: ...and says exactly that"
  assert_contains "$_out" "MANIFEST" "$_sf: ...and names the cause a config parser cannot see"

  # 2. a real run passes and reports what it verified
  _out="$(_rh_run pre-commit "$_PASSLINE" 0)"; _rc=$?
  assert_eq "$_rc" "0" "$_sf: a run that executed a hook passes"
  assert_contains "$_out" "1 hook(s) EXECUTED" "$_sf: ...and states the count it verified"

  # 3. THE REGRESSION THAT A HAND-WRITTEN FIXTURE HID. The longest selected hook's
  #    no-files line carries THREE dots; an earlier `\.\.\.\.+` required four and
  #    hard-failed a CORRECT config while blaming stage selection.
  _out="$(_rh_run pre-commit "$_SKIPLINE" 0)"; _rc=$?
  assert_eq "$_rc" "1" "$_sf: a run where EVERY hook found no files REDS — nothing was inspected"
  assert_contains "$_out" "(no files to check)" "$_sf: ...diagnosed as file patterns, NOT as stage selection"
  assert_absent "$_out" "executed ZERO hooks" "$_sf: ...and not mis-sold as zero-selection"
  _out="$(_rh_run pre-commit "$(printf '%s\n%s' "$_SKIPLINE" "$_PASSLINE")" 0)"; _rc=$?
  assert_eq "$_rc" "0" "$_sf: a no-files hook ALONGSIDE a real one is counted, not a false red"
  assert_contains "$_out" "2 hook(s) EXECUTED" "$_sf: ...and the 3-dot line IS counted (the missed-line regression)"

  # 4. SKIP must not buy a green. MEASURED before the fix: SKIP=a,b gave
  #    "2 hook(s) EXECUTED … satisfied", exit 0, with nothing run.
  : > "$_rh/argv"
  ( PATH="$_rh/bin:$PATH" RUN_STAGE=pre-commit SKIP=a,b SHIM_OUT="$_PASSLINE" \
    SHIM_RC=0 SHIM_ARGV="$_rh/argv" bash "$_rh/runhooks.sh" >/dev/null 2>&1 )
  assert_contains "$(cat "$_rh/argv")" "SKIP_IN_CHILD=<unset>" \
    "$_sf: SKIP does NOT reach pre-commit — the gate decides what runs, not the environment"
  # Control: without the defense the child WOULD see it, so the assertion above
  # is discriminating rather than trivially true.
  : > "$_rh/argv"
  ( PATH="$_rh/bin:$PATH" SKIP=a,b SHIM_ARGV="$_rh/argv" pre-commit run >/dev/null 2>&1 )
  assert_contains "$(cat "$_rh/argv")" "SKIP_IN_CHILD=a,b" \
    "$_sf: (control) an UNDEFENDED invocation does leak SKIP to the child"

  # 5. a FAILING run keeps pre-commit's own diagnosis...
  _out="$(_rh_run pre-commit "" 1)"; _rc=$?
  assert_eq "$_rc" "1" "$_sf: a failing run still fails"
  assert_absent "$_out" "executed ZERO hooks" "$_sf: ...with its OWN cause, not a D11 misdiagnosis"
  # ...and must NOT claim the post-condition was satisfied: it was never evaluated.
  assert_absent "$_out" "post-condition satisfied" "$_sf: ...and does not attest a check it never ran"

  # 6. CI-0033: status from the WRITER, not the pipeline.
  _out="$(_rh_run pre-commit "$_PASSLINE" 1)"; _rc=$?
  assert_eq "$_rc" "1" "$_sf: a hook FAILURE survives the tee pipeline"
  # MUTATION-CHECKED: with pipefail set, a bare `rc=$?` passes the case above too,
  # so it alone certifies nothing. Drop pipefail — the one edit that makes the
  # difference observable — and a `$?` version reads tee's 0 and laundres it green.
  sed 's/^set -euo pipefail$/set -eu/' "$_rh/runhooks.sh" > "$_rh/nopipefail.sh"
  _out="$( PATH="$_rh/bin:$PATH" RUN_STAGE=pre-commit SHIM_OUT="$_PASSLINE" SHIM_RC=1 SHIM_ARGV="$_rh/argv" \
           bash "$_rh/nopipefail.sh" 2>&1 )"; _rc=$?
  assert_eq "$_rc" "1" "$_sf: ...and survives WITHOUT pipefail — read from PIPESTATUS, not \$?"

  # 7. timeout stays infrastructure. Capture the code: a mutant that prints the
  #    message and exits 0 must not pass.
  _out="$(_rh_run pre-commit "" 124)"; _rc=$?
  assert_eq "$_rc" "1" "$_sf: a killed run FAILS"
  assert_contains "$_out" "timed out" "$_sf: ...reported as infrastructure"
  assert_absent "$_out" "executed ZERO hooks" "$_sf: ...not as a D11 zero-hook run"

  # 8. OVER-counting. The count is published as a measurement, so non-hook lines
  #    must not inflate it — `- hook id: x`, tool chatter, and (on a failing run)
  #    `--show-diff-on-failure` hunks that quote a hook line verbatim.
  _out="$(_rh_run pre-commit "$(printf '%s\n%s\n%s' '[INFO] Initializing environment for local.' "$_PASSLINE" '- hook id: check-yaml')" 0)"
  assert_contains "$_out" "1 hook(s) EXECUTED" "$_sf: tool chatter and 'hook id:' lines are NOT counted as hooks"

  # 9. HOW it was called, not only what it returned.
  _rh_run pre-commit "$_PASSLINE" 0 >/dev/null
  assert_contains "$(cat "$_rh/argv")" "--hook-stage pre-commit" "$_sf: run-stage reaches pre-commit's argv"
  assert_contains "$(cat "$_rh/argv")" "--all-files" "$_sf: the run is --all-files, not a diff subset"
  assert_contains "$(cat "$_rh/argv")" "--color=never" "$_sf: colour is pinned off (ANSI breaks the outcome anchor)"
  _rh_run "" "$_PASSLINE" 0 >/dev/null
  # PAIRED with a positive assertion: `assert_absent` on an EMPTY file is
  # vacuously true, so this arm would pass if the step stopped invoking the tool.
  assert_contains "$(cat "$_rh/argv")" "--all-files" "$_sf: the empty-stage arm still invokes pre-commit"
  assert_absent   "$(cat "$_rh/argv")" "--hook-stage" "$_sf: ...and passes NO --hook-stage (tool default)"
done

# The two surfaces must not drift: one is a verbatim port of the other.
_a_body="$(python3 -c "import yaml;d=yaml.safe_load(open('actions/pre-commit/action.yml'));print(next(s['run'] for s in d['runs']['steps'] if s.get('name')=='Run hooks'))" | grep -vE '^\s*#' | tr -d ' \n')"
_r_body="$(python3 -c "import yaml;d=yaml.safe_load(open('.github/workflows/pre-commit.yml'));print(next(s['run'] for j in d['jobs'].values() for s in j['steps'] if s.get('name')=='Run hooks'))" | grep -vE '^\s*#' | sed 's/pre-commit reusable:/pre-commit action:/g' | tr -d ' \n')"
assert_eq "$_a_body" "$_r_body" "D11 run: the action and the reusable run the SAME body (no drift between the two surfaces)"
rm -rf "$_rh"
fi

# A non-iterable must fail CLOSED with a stated cause, not a bare TypeError —
# the one path the PyYAML branch above was written to avoid.
printf 'repos:\n- repo: local\n  hooks:\n  - id: a\n    stages: 3\n' > "$_d11/badtype.yaml"
_bt="$( CONFIG_PATH="$_d11/badtype.yaml" RUN_STAGE=pre-commit bash "$_d11/guard.sh" 2>&1 || true )"
assert_contains "$_bt" "::error::" "D11: a non-iterable stages: fails with a stated cause"
assert_absent   "$_bt" "Traceback"  "D11: ...not a raw traceback"
rm -rf "$_d11"

suite_summary "test_actions.sh"
