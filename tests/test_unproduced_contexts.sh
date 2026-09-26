#!/usr/bin/env bash
# tests/test_unproduced_contexts.sh — PLAN-031 Phase C guard tests.
#
# WHY THIS EXISTS: the #481 class — `apply-standards.sh --apply` PUTs a tier's
# required_status_checks whole with no producer check, while canon ships two of
# those producers at `auto_install:false` (a cold start never installs them).
# With enforce_admins:true on all four armed tiers, arming such a context pins
# every PR on "Expected — Waiting for status to be reported" forever, with no
# --admin escape. The guard in apply-standards.sh REFUSES before the PUT
# (override: --allow-unproduced-context).
#
# TEETH DESIGN (mirrors tests/test_required_contexts.sh:182-224):
#  - the committed artifact must MATCH regeneration (drift gate), and the gate
#    must be shown able to go red (sandbox mutation changes regeneration);
#  - the generator fails closed on a missing map and on an empty map;
#  - `gh` is stubbed by RECORDING ITS ARGUMENTS, not just its return value —
#    assertions read the recorded contents-API paths ("a stub that controls
#    only what a command returns tests nothing about how it was called");
#  - the mutation flips a genuinely-`auto_install:true` producer and asserts
#    the guard fires, with an unrelated true-valued entry as control, and the
#    harness REFUSES an already-false target rather than silently no-opping
#    (a false→false "mutation" tests that a no-op is a no-op).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(cd "$HERE/.." && pwd)"
GEN="$ROOT/install/generate-required-contexts.py"
ART="$ROOT/install/templates/required-contexts.json"
SCRIPT="$ROOT/install/apply-standards.sh"

SANDBOXES=""
cleanup_sandboxes() { [ -n "$SANDBOXES" ] && rm -rf "$SANDBOXES"; }
trap cleanup_sandboxes EXIT
new_sandbox() { local d; d="$(mktemp -d)"; SANDBOXES="$SANDBOXES $d"; printf '%s' "$d"; }

# ---------------------------------------------------------------------------
# 1. The artifact is valid, and MATCHES regeneration (the drift gate).
# ---------------------------------------------------------------------------
echo "== committed artifact matches regeneration (drift gate) =="
assert_ok "[ -f '$ART' ]" "required-contexts.json exists"
assert_ok "python3 -c \"import json;json.load(open('$ART'))\"" \
  "required-contexts.json parses as JSON"
# Tiers are the template FILES, so umbrella (null contexts) has a row too.
assert_eq "$(jq -r 'keys | sort | join(",")' "$ART")" \
  "$(ls "$ROOT"/install/templates/branch-protection-*.json | sed -E 's#.*/branch-protection-(.*)\.json#\1#' | sort | tr '\n' ',' | sed 's/,$//')" \
  "artifact tiers are exactly the branch-protection template tiers"
assert_ok "python3 '$GEN' --check '$ROOT' >/dev/null" \
  "generator --check passes on the committed tree"
# The gate must be ABLE to go red: mutate a sandbox manifest, regenerate
# THERE, and confirm the output moves. A drift gate that cannot fail is a
# check that can only ever pass.
SB1="$(new_sandbox)"
cp -r "$ROOT/.github" "$ROOT/install" "$SB1/" 2>/dev/null
SB1_EXP="$SB1"; export SB1_EXP
python3 <<'PY'
import json, os
sb = os.environ["SB1_EXP"]
p = sb + "/install/templates/manifest.json"
m = json.load(open(p))
for f in m["files"]:
    if f.get("path") == ".github/workflows/pre-commit.yml":
        assert f.get("auto_install") is True, "precondition: pre-commit.yml must be genuinely auto_install:true"
        f["auto_install"] = False
json.dump(m, open(p, "w"), indent=2)
PY
python3 "$GEN" "$SB1" >/dev/null
assert_eq "$(jq -r '.bootstrap[0].cold_start_installed' "$SB1/install/templates/required-contexts.json")" \
  "false" \
  "flipping pre-commit.yml auto_install:false in a sandbox moves regeneration (the drift gate can go red)"

# ---------------------------------------------------------------------------
# 2. The generator FAILS CLOSED.
# ---------------------------------------------------------------------------
echo ""
echo "== generator fails closed =="
SB2="$(new_sandbox)"
mkdir -p "$SB2/install/templates"
if python3 "$GEN" "$SB2" >/dev/null 2>&1; then
  _r "generator with no map present should fail, but exited 0"
else
  _g "generator with no required-context-map.py fails (no artifact from nothing)"
fi
assert_ok "[ ! -f '$SB2/install/templates/required-contexts.json' ]" \
  "failed generation writes no artifact"
# A map that emits NOTHING (only an umbrella tier: null contexts, zero rows)
# must not produce an "every tier requires nothing" artifact.
SB3="$(new_sandbox)"
mkdir -p "$SB3/.github/workflows" "$SB3/install/templates"
cp "$ROOT/install/templates/manifest.json" "$SB3/install/templates/"
cp "$ROOT/install/templates/branch-protection-umbrella.json" "$SB3/install/templates/"
cp "$ROOT/install/required-context-map.py" "$SB3/install/"
if python3 "$GEN" "$SB3" >/dev/null 2>&1; then
  _r "generator over an empty (row-less) map should fail, but exited 0"
else
  _g "generator over an empty map fails instead of writing a vacuous artifact"
fi
assert_ok "[ ! -f '$SB3/install/templates/required-contexts.json' ]" \
  "empty-map generation writes no artifact"
# A map emitting a MALFORMED row (wrong field count) must fail rather than
# write a corrupt artifact — this exercises the generator's ValueError arm,
# which the inventory row cites and nothing previously drove.
SBM="$(new_sandbox)"
mkdir -p "$SBM/.github/workflows" "$SBM/install/templates"
cp "$ROOT/install/templates/manifest.json" "$SBM/install/templates/"
cp "$ROOT/install/templates/branch-protection-umbrella.json" "$SBM/install/templates/"
cp "$ROOT/install/required-context-map.py" "$SBM/install/"
printf '\nprint("MALFORMED-ROW-WITHOUT-TABS")\n' >> "$SBM/install/required-context-map.py"
if python3 "$GEN" "$SBM" >/dev/null 2>&1; then
  _r "generator over a malformed map row should fail, but exited 0"
else
  _g "generator over a malformed map row fails instead of writing a corrupt artifact"
fi
assert_ok "[ ! -f '$SBM/install/templates/required-contexts.json' ]" \
  "malformed-map generation writes no artifact"

# ---------------------------------------------------------------------------
# 3. Stub harness: gh + curl record their arguments; curl serves canon
#    templates offline so these tests need no network.
# ---------------------------------------------------------------------------
echo ""
echo "== stub harness for the --apply guard =="
BIN="$(new_sandbox)/bin"
mkdir -p "$BIN"
cat > "$BIN/gh" <<'STUB'
#!/usr/bin/env bash
# Test stub: RECORDS its arguments, then answers from env.
#   GH_MISSING: space-separated consumer paths that 404 (absent producers).
#   GH_BROKEN:  non-empty -> every producer contents read fails non-404
#               (bad scope/net). The declaration read stays 404 regardless.
printf 'gh %s\n' "$*" >> "$GH_ARGS"
api=""
for a in "$@"; do case "$a" in repos/*) api="$a";; esac; done
case "$*" in
  *"auth status"*) exit 0 ;;
esac
case "$api" in
  */contents/*)
    p="${api#repos/*/contents/}"
    # An absent declaration is the valid single-branch default, never an error —
    # the fixture repo has no declaration file, whatever GH_BROKEN says.
    case "$p" in
      ".github/aidoc-ci.json")
        echo '{"message":"Not Found"} - 404 (stub)' >&2; exit 1 ;;
    esac
    if [ -n "${GH_BROKEN:-}" ]; then echo "401 Unauthorized (stub)" >&2; exit 1; fi
    case " ${GH_MISSING:-} " in
      *" $p "*) echo '{"message":"Not Found"} - 404 (stub)' >&2; exit 1 ;;
    esac
    echo '{"content":"e30=","sha":"stub"}'
    exit 0
    ;;
  */branches/*/protection) echo '{}'; exit 0 ;;
  */labels*) echo '[]'; exit 0 ;;
  *actions/permissions*) echo '{}'; exit 0 ;;
  repos/*/*) echo '{"default_branch":"main","visibility":"private"}'; exit 0 ;;
esac
echo '{}'
exit 0
STUB
cat > "$BIN/curl" <<'STUB'
#!/usr/bin/env bash
# Test stub: RECORDS its arguments, serves canon templates offline.
# CURL_FIXTURE, when set to a dir holding required-contexts.json, overrides
# just that file (lets a test control the guard's input).
printf 'curl %s\n' "$*" >> "$CURL_ARGS"
url="${*: -1}"
base="${url##*/}"
if [ "$base" = "required-contexts.json" ] && [ -n "${CURL_FIXTURE:-}" ] \
   && [ -f "$CURL_FIXTURE/required-contexts.json" ]; then
  cat "$CURL_FIXTURE/required-contexts.json"; exit 0
fi
if [ -f "$ROOT_TEMPLATES/$base" ]; then cat "$ROOT_TEMPLATES/$base"; exit 0; fi
if [ "$base" = "parse-governance-table.py" ] && [ -f "$ROOT/install/parse-governance-table.py" ]; then
  cat "$ROOT/install/parse-governance-table.py"; exit 0
fi
echo "stub-curl: no fixture for $base" >&2; exit 1
STUB
chmod +x "$BIN/gh" "$BIN/curl"
export ROOT_TEMPLATES="$ROOT/install/templates"

# run_apply <sandbox> [--allow-unproduced-context] [--skip-branch-protection] [--tier T]:
# copies the REAL script into a sandbox (so backup files land there, never in
# $sandbox/apply-out.log; the exit code lands in $APPLY_RC. (File-based, not
# command substitution: $(...) runs in a subshell whose assignments never
# reach the caller.)
run_apply() {
  local sb="$1"; shift
  local tier="product" extra=""
  while [ $# -gt 0 ]; do case "$1" in
    --tier) tier="$2"; shift 2 ;;
    *) extra="$extra $1"; shift ;;
  esac; done
  cp "$SCRIPT" "$sb/apply-standards.sh"
  GH_ARGS="$sb/gh-args.log" CURL_ARGS="$sb/curl-args.log" \
  GH_MISSING="${GH_MISSING:-}" GH_BROKEN="${GH_BROKEN:-}" \
  CURL_FIXTURE="${CURL_FIXTURE:-}" ROOT_TEMPLATES="$ROOT_TEMPLATES" \
  PATH="$BIN:$PATH" bash "$sb/apply-standards.sh" --apply \
    --repo testowner/testrepo --tier "$tier" --yes --ci-tag ci/v9.9.9 $extra >"$sb/apply-out.log" 2>&1
  APPLY_RC=$?
}

echo ""
echo "== guard REFUSES when producers are absent (naming context + recovery) =="
SB4="$(new_sandbox)"
GH_MISSING=".github/workflows/audit-trail.yml .github/workflows/secret-scan.yml"
GH_BROKEN=""; CURL_FIXTURE=""
export GH_MISSING GH_BROKEN CURL_FIXTURE
run_apply "$SB4"; rc=$APPLY_RC; out="$(cat $SB4/apply-out.log)"
assert_eq "$rc" "4" "refusal exits 4"
assert_contains "$out" "call / verify" "refusal names the missing context"
assert_contains "$out" ".github/workflows/audit-trail.yml" "refusal names the producer"
assert_contains "$out" "bash install.sh testowner/testrepo --add-surface .github/workflows/audit-trail.yml" \
  "refusal prints the exact --add-surface recovery command"
assert_contains "$out" "call / gitleaks" "refusal names the second missing context"
assert_contains "$out" "bash install.sh testowner/testrepo --add-surface .github/workflows/secret-scan.yml" \
  "refusal prints the second recovery command"
assert_contains "$(cat "$SB4/gh-args.log")" "contents/.github/workflows/audit-trail.yml" \
  "guard read the producer via the gh contents API (recorded args, not just return value)"
assert_eq "$(grep -c 'PUT.*protection' "$SB4/gh-args.log" || true)" "0" \
  "refusal precedes the PUT — no branch-protection PUT was recorded"
assert_contains "$(cat "$SB4/curl-args.log")" "required-contexts.json" \
  "guard fetched the derived artifact (not a hardcoded table)"

echo ""
echo "== guard PROCEEDS when every producer is present =="
SB5="$(new_sandbox)"
GH_MISSING=""; GH_BROKEN=""; CURL_FIXTURE=""
export GH_MISSING GH_BROKEN CURL_FIXTURE
run_apply "$SB5"; rc=$APPLY_RC; out="$(cat $SB5/apply-out.log)"
assert_eq "$rc" "0" "all-present --apply exits 0"
assert_contains "$out" "producer guard OK" "guard reports its pass"
assert_ok "[ '$(grep -c 'PUT.*protection' "$SB5/gh-args.log")' -gt 0 ]" \
  "proceeding run records the branch-protection PUT"

echo ""
echo "== --allow-unproduced-context proceeds but still names every gap =="
SB6="$(new_sandbox)"
GH_MISSING=".github/workflows/audit-trail.yml .github/workflows/secret-scan.yml"
GH_BROKEN=""; CURL_FIXTURE=""
export GH_MISSING GH_BROKEN CURL_FIXTURE
run_apply "$SB6" --allow-unproduced-context; rc=$APPLY_RC; out="$(cat $SB6/apply-out.log)"
assert_eq "$rc" "0" "override exits 0"
assert_contains "$out" "WARNING" "override prints a loud warning"
assert_contains "$out" "call / verify" "override still names the unproduced context"
assert_contains "$out" ".github/workflows/secret-scan.yml" "override still names every unproduced producer"
assert_ok "[ '$(grep -c 'PUT.*protection' "$SB6/gh-args.log")' -gt 0 ]" \
  "override run records the branch-protection PUT"

echo ""
echo "== '?' (canon ships NO producer) is at least as severe as '!' =="
SB7="$(new_sandbox)"
mkdir -p "$SB7/fixture"
# Full product-tier shape with ONLY verify as `?`: a real artifact always
# covers every template context (the guard cross-checks this and refuses on
# skew), so a single-row fixture would trip the skew refusal instead of the
# `?` path under test.
cat > "$SB7/fixture/required-contexts.json" <<'JSON'
{"product": [{"context": "call / ai-review", "producer": ".github/workflows/ai-review.yml", "cold_start_installed": true}, {"context": "call / composition", "producer": ".github/workflows/composition.yml", "cold_start_installed": true}, {"context": "call / verify", "producer": null, "cold_start_installed": false}, {"context": "call / Lint / format / security hooks", "producer": ".github/workflows/pre-commit.yml", "cold_start_installed": true}, {"context": "call / gitleaks", "producer": ".github/workflows/secret-scan.yml", "cold_start_installed": false}]}
JSON
GH_MISSING=""; GH_BROKEN=""; CURL_FIXTURE="$SB7/fixture"
export GH_MISSING GH_BROKEN CURL_FIXTURE
# The target HAS audit-trail.yml (GH_MISSING empty) — yet the guard must still
# refuse, because the artifact says canon ships no producer. This also proves
# the verdict follows the ARTIFACT, not just target state.
run_apply "$SB7"; rc=$APPLY_RC; out="$(cat $SB7/apply-out.log)"
assert_eq "$rc" "4" "'?' refuses even when the target has the file"
assert_contains "$out" "call / verify" "'?' refusal names the context"
assert_contains "$out" "NO producer" "'?' refusal says canon ships no producer"
CURL_FIXTURE="$SB7/fixture"
run_apply "$SB7" --allow-unproduced-context; rc2=$APPLY_RC; out2="$(cat $SB7/apply-out.log)"
assert_eq "$rc2" "0" "'?' with the override proceeds"
assert_contains "$out2" "call / verify" "'?' with the override still names the context"

echo ""
echo "== unreachable target / bad scope REFUSES, even with the override =="
SB8="$(new_sandbox)"
GH_MISSING=""; GH_BROKEN="1"; CURL_FIXTURE=""
export GH_MISSING GH_BROKEN CURL_FIXTURE
run_apply "$SB8"; rc=$APPLY_RC; out="$(cat $SB8/apply-out.log)"
assert_eq "$rc" "4" "unverifiable target refuses"
assert_contains "$out" "could not verify" "refusal says it could not verify (not 'verified')"
run_apply "$SB8" --allow-unproduced-context; rc2=$APPLY_RC; out2="$(cat $SB8/apply-out.log)"
assert_eq "$rc2" "4" "the override does NOT bless an unreadable target"
CURL_FIXTURE=""; GH_BROKEN=""
export CURL_FIXTURE GH_BROKEN

echo ""
echo "== --skip-branch-protection skips the guard (no PUT to guard) =="
SB9="$(new_sandbox)"
GH_MISSING=".github/workflows/audit-trail.yml .github/workflows/secret-scan.yml"
GH_BROKEN=""; CURL_FIXTURE=""
export GH_MISSING GH_BROKEN CURL_FIXTURE
run_apply "$SB9" --skip-branch-protection; rc=$APPLY_RC; out="$(cat $SB9/apply-out.log)"
assert_eq "$rc" "0" "skipped protection exits 0 despite absent producers"
assert_contains "$out" "SKIPPED (--skip-branch-protection)" "skip is reported"
assert_absent "$out" "REFUSING" "no refusal when the PUT is skipped"
assert_eq "$(grep -c 'PUT.*protection' "$SB9/gh-args.log" || true)" "0" \
  "no branch-protection PUT when skipped"

echo ""
echo "== umbrella (no required contexts) passes explicitly =="
SB10="$(new_sandbox)"
GH_MISSING=".github/workflows/audit-trail.yml"; GH_BROKEN=""; CURL_FIXTURE=""
export GH_MISSING GH_BROKEN CURL_FIXTURE
run_apply "$SB10" --tier umbrella; rc=$APPLY_RC; out="$(cat $SB10/apply-out.log)"
assert_eq "$rc" "0" "umbrella exits 0"
assert_contains "$out" "nothing to guard" "empty tier passes explicitly, not silently"

echo ""
echo "== a non-JSON artifact fails closed (exit 4, zero PUTs) =="
# A fetch that returns 200 with the WRONG body (stale cache, error page) must
# refuse, not parse nothing into "nothing to guard". CURL_FIXTURE serves the
# HTML as the artifact; the jq object-gate must reject it.
SBH="$(new_sandbox)"
mkdir -p "$SBH/fixture"
printf '<html><body>Bad Gateway</body></html>\n' > "$SBH/fixture/required-contexts.json"
GH_MISSING=""; GH_BROKEN=""; CURL_FIXTURE="$SBH/fixture"
export GH_MISSING GH_BROKEN CURL_FIXTURE
run_apply "$SBH"; rc=$APPLY_RC; out="$(cat $SBH/apply-out.log)"
assert_eq "$rc" "4" "HTML artifact refuses (exit 4)"
assert_contains "$out" "not a JSON object" "refusal names the malformed artifact"
assert_eq "$(grep -c 'PUT.*protection' "$SBH/gh-args.log" || true)" "0" \
  "no branch-protection PUT on a malformed artifact"
CURL_FIXTURE=""
export CURL_FIXTURE

echo ""
echo "== a failed artifact fetch fails closed (exit 3, zero PUTs) =="
# Point the stub curl at an empty template dir so EVERY fetch 404s. The guard
# is the first network operation (it runs before backup), so the failure must
# surface as fetch-failure exit 3 with nothing mutated — never as a silent
# "verified nothing" pass.
SBC="$(new_sandbox)"
mkdir -p "$SBC/empty-templates"
GH_MISSING=""; GH_BROKEN=""; CURL_FIXTURE=""
export GH_MISSING GH_BROKEN CURL_FIXTURE
ROOT_TEMPLATES="$SBC/empty-templates" run_apply "$SBC"; rc=$APPLY_RC; out="$(cat $SBC/apply-out.log)"
assert_eq "$rc" "3" "unfetchable artifact exits 3 (fetch failure, not guard verdict)"
assert_contains "$out" "FATAL canon fetch failed" "fetch failure is loud, not silent"
assert_eq "$(grep -c 'PUT.*protection' "$SBC/gh-args.log" || true)" "0" \
  "no branch-protection PUT when the artifact cannot be fetched"

# ---------------------------------------------------------------------------
# 4. MUTATION with teeth: flip a genuinely-true producer, guard must fire.
# ---------------------------------------------------------------------------
echo ""
echo "== mutation: flipping a true producer fires the guard =="
assert_eq "$(jq -r '.files[] | select(.path==".github/workflows/pre-commit.yml") | .auto_install' "$ROOT/install/templates/manifest.json")" \
  "true" "precondition: pre-commit.yml is genuinely auto_install:true (verify in manifest.json)"
assert_eq "$(jq -r '.files[] | select(.path==".github/workflows/ai-review.yml") | .auto_install' "$ROOT/install/templates/manifest.json")" \
  "true" "precondition: ai-review.yml is genuinely auto_install:true (control)"
mutate_manifest() {  # $1 = sandbox, $2 = consumer path to flip to false
  if ! python3 - "$1" "$2" <<'PY'
import json, sys
sb, target = sys.argv[1], sys.argv[2]
p = sb + "/install/templates/manifest.json"
m = json.load(open(p))
hit = 0
for f in m["files"]:
    if f.get("path") == target:
        if f.get("auto_install") is not True:
            raise SystemExit("precondition: %s is already auto_install:false — no-op mutation" % target)
        f["auto_install"] = False
        hit += 1
if hit != 1:
    raise SystemExit("mutation did not apply: matched %d entries for %s" % (hit, target))
json.dump(m, open(p, "w"), indent=2)
PY
  then printf 'MUTATION-REFUSED'; return 1; fi
  python3 "$GEN" "$1" >/dev/null 2>&1 || { printf 'MUTATION-REGEN-FAILED'; return 1; }
}
SB11="$(new_sandbox)"
cp -r "$ROOT/.github" "$ROOT/install" "$SB11/" 2>/dev/null
mutate_manifest "$SB11" ".github/workflows/pre-commit.yml" >/dev/null
assert_eq "$(jq -r '.bootstrap[] | select(.context=="call / Lint / format / security hooks") | .cold_start_installed' "$SB11/install/templates/required-contexts.json")" \
  "false" "mutated sandbox artifact marks the bootstrap producer cold_start:false"
# End to end: the mutated artifact + a target lacking pre-commit.yml.
# The target HAS ai-review/composition (only pre-commit is missing), so the
# firing context must be exactly the mutated producer's.
GH_MISSING=".github/workflows/pre-commit.yml"; GH_BROKEN=""
CURL_FIXTURE="$SB11/install/templates"
export GH_MISSING GH_BROKEN CURL_FIXTURE
run_apply "$SB11" --tier bootstrap; rc=$APPLY_RC; out="$(cat $SB11/apply-out.log)"
assert_eq "$rc" "4" "guard fires on the mutated producer"
assert_contains "$out" "call / Lint / format / security hooks" "firing names the mutated producer's context"
assert_contains "$out" "bash install.sh testowner/testrepo --add-surface .github/workflows/pre-commit.yml" \
  "firing prints the recovery command"
# Control: flipping an UNRELATED true entry must not move this verdict, and a
# present producer must not be listed even when the artifact calls it `!`.
SB12="$(new_sandbox)"
cp -r "$ROOT/.github" "$ROOT/install" "$SB12/" 2>/dev/null
mutate_manifest "$SB12" ".github/workflows/ai-review.yml" >/dev/null
GH_MISSING=".github/workflows/pre-commit.yml"; GH_BROKEN=""
CURL_FIXTURE="$SB12/install/templates"
export GH_MISSING GH_BROKEN CURL_FIXTURE
run_apply "$SB12" --tier product; rc=$APPLY_RC; out="$(cat $SB12/apply-out.log)"
assert_eq "$rc" "4" "control run still refuses on the (unmutated) absent pre-commit producer"
assert_contains "$out" "call / Lint / format / security hooks" "control refusal names the truly-absent producer"
assert_absent "$out" "ai-review.yml" "present ai-review producer is NOT listed despite its flipped '!' (present beats cold-start flag)"
# The precondition guard itself has teeth: an already-false target refuses.
SB13="$(new_sandbox)"
cp -r "$ROOT/.github" "$ROOT/install" "$SB13/" 2>/dev/null
assert_eq "$(mutate_manifest "$SB13" ".github/workflows/secret-scan.yml" 2>/dev/null)" \
  'MUTATION-REFUSED' "a no-op (false→false) mutation is REFUSED, not silently reported"
GH_MISSING=""; GH_BROKEN=""; CURL_FIXTURE=""
export GH_MISSING GH_BROKEN CURL_FIXTURE

# ---------------------------------------------------------------------------
# 5. Non-mutating modes REPORT what --apply would refuse (never fail on it).
# ---------------------------------------------------------------------------
echo ""
echo "== non-mutating modes report, never refuse =="
SB14="$(new_sandbox)"
mkdir -p "$SB14/empty-checkout"
GH_MISSING=""; GH_BROKEN=""; CURL_FIXTURE=""
export GH_MISSING GH_BROKEN CURL_FIXTURE ROOT_TEMPLATES
out="$(cd "$SB14/empty-checkout" && PATH="$BIN:$PATH" bash "$SCRIPT" --dry-run --tier product --ci-tag ci/v9.9.9 2>&1)"; rc=$?
assert_eq "$rc" "0" "--dry-run exits 0 despite missing producers"
assert_contains "$out" "would REFUSE" "--dry-run reports what --apply would refuse"
assert_contains "$out" "call / gitleaks" "report names the missing context"
assert_contains "$out" "--add-surface .github/workflows/secret-scan.yml" "report prints the recovery command"
out="$(cd "$SB14/empty-checkout" && PATH="$BIN:$PATH" bash "$SCRIPT" --dry-run --ci-tag ci/v9.9.9 2>&1)"; rc=$?
assert_eq "$rc" "0" "--dry-run without --tier exits 0"
assert_absent "$out" "would REFUSE" "no guard report when no tier is selected"

echo ""
echo "== unknown flags still fail (the new flag doesn't open a hole) =="
SBF="$(new_sandbox)"
GH_MISSING=""; GH_BROKEN=""; CURL_FIXTURE=""
export GH_MISSING GH_BROKEN CURL_FIXTURE
run_apply "$SBF" --allow-unproduced-contex; rc=$APPLY_RC
assert_eq "$rc" "2" "a misspelled --allow-unproduced-context flag exits 2 instead of silently proceeding"

suite_summary "unproduced-contexts"
