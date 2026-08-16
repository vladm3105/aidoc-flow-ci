#!/usr/bin/env bash
# tests/test_required_contexts.sh — required-context ↔ producer validator
# (PLAN-018 FT-18), install/required-context-map.py.
#
# WHY THIS EXISTS: F2 was "a required status-check context has no producing
# workflow installed, so arming protection pins every PR forever." test_checknames
# already proves each required context names a real reusable JOB; this proves the
# next link — that canon ships a CALLER that produces it, and it drives the map
# the wizard uses to catch a consumer missing that caller.
#
# THE INVARIANT (general form of F2 as a canon self-check): every required
# context in every tier template must resolve to a producing caller canon ships.
# A tier that requires `call / X` with no producer is F2 latent in canon — a
# `?` in the map, and a red test here.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(cd "$HERE/.." && pwd)"
MAP="$ROOT/install/required-context-map.py"

assert_ok "[ -f '$MAP' ]" "required-context map generator exists"

out="$(python3 "$MAP" "$ROOT" 2>/dev/null || echo '')"
if [ "$out" = SKIP ] || [ -z "$out" ]; then
  if [ "${CI:-}" = "true" ]; then
    _r "map generator returned SKIP/empty in CI (install python3-yaml)"
    suite_summary "required-contexts"; exit $?
  fi
  printf '  \033[33mskip\033[0m PyYAML unavailable — required-context tests skipped\n'
  suite_summary "required-contexts"; exit $?
fi

# ---------------------------------------------------------------------------
# 1. THE INVARIANT — every required context resolves to a producer (no `?`).
# ---------------------------------------------------------------------------
echo "== every required context has a canon producer (no orphan required check) =="
orphans=0
while IFS=$'\t' read -r tier ctx producer; do
  [ -n "$tier" ] || continue
  case "$producer" in
    '?')       _r "$tier: '$ctx' has NO producing caller in canon — arming would hang (F2 latent)"; orphans=1 ;;
    # `?non-call` is GONE as of PLAN-025 P8, and its removal is the point.
    #
    # It used to score a PASS for any context without a `<jobkey> / ` prefix, on
    # the reasoning that a bare context must be repo-local. That held while every
    # canon caller wrapped a reusable. v3 ships PLAIN jobs (composite-action
    # steps), and a plain job's check run is bare — so the branch would have
    # blessed exactly the contexts v3 arms, without checking them. A context
    # armed against nothing pins every PR forever, which is the F2 class this
    # suite exists to detect.
    #
    # The map now resolves bare contexts against canon's plain jobs and returns
    # `?` when it cannot. If this label ever reappears in the output, the map
    # regressed — fail rather than pass.
    '?non-call') _r "$tier: '$ctx' returned the retired '?non-call' label — required-context-map.py has regressed (P8)"; orphans=1 ;;
    *)         _g "$tier: '$ctx' <- $producer" ;;
  esac
done < <(printf '%s\n' "$out")
assert_eq "$orphans" "0" "no required context is missing a canon producer"

# ---------------------------------------------------------------------------
# 2. The chain is DERIVED correctly — spot-check the non-obvious resolutions
#    against source. These are asserted, not hardcoded in the map: the map reads
#    reusable job names + caller `uses:` + the manifest. In particular
#    `call / verify` must resolve through the audit-trail-check REUSABLE to the
#    audit-trail CALLER (different basenames — the case a naive map gets wrong).
# ---------------------------------------------------------------------------
echo ""
echo "== producer resolution is correct for the non-obvious chains =="
# These assert RESOLUTION — that the context->reusable->caller->consumer chain
# lands on the right file — which is a separate question from whether a cold
# start installs it (#481, section 5). Strip the leading install symbol so the
# two concerns stay independent: otherwise flipping any `auto_install` would red
# a chain assertion that has nothing to do with installation.
producer_for() { printf '%s\n' "$out" | awk -F'\t' -v c="$1" '$2==c{sub(/^!/,"",$3); print $3; exit}'; }
assert_eq "$(producer_for 'call / verify')" "audit-trail.yml" \
  "call / verify resolves through audit-trail-check reusable to the audit-trail caller"
assert_eq "$(producer_for 'call / Lint / format / security hooks')" "pre-commit.yml" \
  "call / Lint / format / security hooks resolves to pre-commit.yml (the F2 instance)"
assert_eq "$(producer_for 'call / gitleaks')" "secret-scan.yml" \
  "call / gitleaks resolves to secret-scan.yml"

# ---------------------------------------------------------------------------
# 3. TEETH — remove a caller template and the context it produced loses its
#    producer (-> `?`). Confirms the map really reads the templates rather than
#    inventing the answer, and that the invariant would catch the regression.
# ---------------------------------------------------------------------------
echo ""
echo "== removing a producer's caller template is detected =="
SB="$(mktemp -d)"; trap 'rm -rf "$SB"' EXIT
cp -r "$ROOT/.github" "$ROOT/install" "$SB/" 2>/dev/null
# Drop BOTH secret-scan caller templates so nothing produces call / gitleaks.
rm -f "$SB"/install/templates/workflows/secret-scan.yml "$SB"/install/templates/workflows/secret-scan-private.yml
mut="$(python3 "$MAP" "$SB" 2>/dev/null || echo '')"
gitleaks_prod="$(printf '%s\n' "$mut" | awk -F'\t' '$2=="call / gitleaks"{print $3; exit}')"
assert_eq "$gitleaks_prod" "?" "with secret-scan caller templates removed, call / gitleaks has NO producer"

# ---------------------------------------------------------------------------
# 4. FT-45 — the JOB-KEY half of `<jobid> / <name>` is validated, not dropped.
#    A required context resolves only when an installed caller job KEYED <jobid>
#    calls the reusable. `standards-drift`'s caller job is `drift`, so
#    `drift / check-standards-drift` is produced but `call / check-standards-drift`
#    (same name, wrong key) is NOT — arming the latter would hang every PR. Before
#    FT-45 the map dropped <jobid> and passed both.
# ---------------------------------------------------------------------------
echo ""
echo "== FT-45: a wrong job-key resolves the name but is flagged as no producer =="
SB2="$(mktemp -d)"; cp -r "$ROOT/.github" "$ROOT/install" "$SB2/" 2>/dev/null
cat > "$SB2/install/templates/branch-protection-ft45.json" <<'JSON'
{"required_status_checks": {"contexts": ["drift / check-standards-drift", "call / check-standards-drift"]}}
JSON
m45="$(python3 "$MAP" "$SB2" 2>/dev/null || echo '')"
p_right="$(printf '%s\n' "$m45" | awk -F'\t' '$2=="drift / check-standards-drift"{sub(/^!/,"",$3); print $3; exit}')"
p_wrong="$(printf '%s\n' "$m45" | awk -F'\t' '$2=="call / check-standards-drift"{print $3; exit}')"
assert_eq "$p_right" "standards-drift.yml" "correct job-key (drift / check-standards-drift) resolves to its caller"
assert_eq "$p_wrong" "?" "wrong job-key (call / check-standards-drift) is FLAGGED, not passed (FT-45)"
rm -rf "$SB2"

# ---------------------------------------------------------------------------
# 5. #481 — THE BOOTSTRAP TIER'S PRODUCERS MUST BE COLD-START GUARANTEED.
#
#    "canon ships a producer" and "the consumer will HAVE that producer" are
#    different questions, and until #481 only the first was asked. Both answers
#    to the second have now been wrong in production:
#
#      #438/#441 moved `auto_install` to `quick-gates.yml` while all four tier
#      templates still required `pre-commit.yml`'s context. Every row of this
#      map stayed green, because canon did still ship `pre-commit.yml` — it just
#      stopped installing it. A post-v3 cold start + `apply-standards.sh --apply`
#      armed a context with nothing to satisfy it.
#
#    SCOPED TO THE BOOTSTRAP TIER ON PURPOSE. Bootstrap is the one tier whose
#    contract is "what you have immediately after install.sh", and `--apply
#    --tier bootstrap` is the documented onboarding path — the case with no
#    `--admin` escape. The higher tiers legitimately require callers adopted
#    later via `--update` / `--add-surface` (the three routes test_install.sh
#    documents), so `!` there is expected and is REPORTED, not asserted. Widening
#    this to every tier would red the suite permanently and get it tuned out.
#
#    WHAT IT DOES NOT COVER, because nothing here can: `auto_install` describes a
#    COLD START. It says nothing about what an already-installed consumer has on
#    disk, and canon cannot read consumer repos. So this catches PLAN-026 §C0
#    landing alone, but NOT §C0 landing with the flag flip before the C1–C5 fleet
#    rollout. That ordering is a review-enforced rule (DECISIONS.md CI-0038), and
#    a green suite is not clearance for it.
# ---------------------------------------------------------------------------
echo ""
echo "== #481: every bootstrap-tier required context has a cold-start-installed producer =="
notinstalled=0
bootrows=0
while IFS=$'\t' read -r tier ctx prod; do
  [ "$tier" = bootstrap ] || continue
  bootrows=$((bootrows + 1))
  case "$prod" in
    '!'*) _r "bootstrap: '$ctx' <- ${prod#!} is auto_install:false — a COLD START does not install it (#481)"; notinstalled=1 ;;
    # Deliberately reported TWICE: section 1 names the class (no producer in
    # canon at all), this names the tier it strands. Both are `_r`, so a
    # bootstrap-tier orphan yields four failure lines. Fail-closed and noisy
    # beats one line for a defect with no `--admin` escape.
    '?'|'?non-call') _r "bootstrap: '$ctx' has no producer at all — see the section-1 failure above"; notinstalled=1 ;;
    *)    _g "bootstrap: '$ctx' <- $prod (bootstrapped unconditionally)" ;;
  esac
done < <(printf '%s\n' "$out")
# WITHOUT THIS THE SECTION CANNOT FAIL. `continue` skips every row when the
# bootstrap template is deleted, renamed, or its `contexts` array empties, and
# `notinstalled` then stays 0 and the assertion below passes having inspected
# nothing. Section 1's empty guard does not backstop it: with the other four
# tier templates present, `$out` is non-empty and section 1 iterates happily.
assert_ok "[ '$bootrows' -gt 0 ]" "the bootstrap tier contributed at least one required-context row to inspect"
assert_eq "$notinstalled" "0" "no bootstrap-tier required context depends on a caller the cold start omits"

# ---------------------------------------------------------------------------
# 6. TEETH for #481 — `!` must be REACHABLE, or section 5 is a check that can
#    only ever pass. The mutation edits ONLY manifest.json and leaves every
#    template alone: the producer still resolves, so a map that ignores
#    `auto_install` prints a bare `pre-commit.yml` and section 5 stays green
#    against a tree that bricks a new repo. That is exactly what shipped.
# ---------------------------------------------------------------------------
echo ""
echo "== #481 teeth: flipping auto_install off is detected =="
mutate_manifest() {  # $1 = consumer path to flip auto_install:false on
  local sb; sb="$(mktemp -d)"
  cp -r "$ROOT/.github" "$ROOT/install" "$sb/" 2>/dev/null
  # THE HEREDOC'S EXIT STATUS MUST BE PROPAGATED. Without this `if`, a mutation
  # that refused to apply left the sandbox UNMUTATED and the function went on to
  # print the unmutated map — which is the expected value for any control
  # assertion, so the control passed precisely when the harness was broken.
  if ! python3 - "$sb" "$1" <<'PY'
import json, sys
sb, target = sys.argv[1], sys.argv[2]
p = sb + "/install/templates/manifest.json"
m = json.load(open(p))
hit = 0
for f in m["files"]:
    if f.get("path") == target:
        # A flip that flips nothing is not a mutation. Asserting against an
        # already-false entry tests that a no-op is a no-op.
        if f.get("auto_install") is not True:
            raise SystemExit("precondition: %s is already auto_install:false — no-op mutation" % target)
        f["auto_install"] = False
        hit += 1
# A mutation that did not apply looks exactly like a survivor. Fail loudly.
if hit != 1:
    raise SystemExit("mutation did not apply: matched %d entries for %s" % (hit, target))
json.dump(m, open(p, "w"), indent=2)
PY
  then rm -rf "$sb"; printf 'MUTATION-FAILED\n'; return 1; fi
  python3 "$MAP" "$sb" 2>/dev/null | awk -F'\t' '$1=="bootstrap" && $2=="call / Lint / format / security hooks"{print $3; exit}'
  rm -rf "$sb"
}
assert_eq "$(mutate_manifest .github/workflows/pre-commit.yml)" '!pre-commit.yml' \
  "auto_install:false on the bootstrap producer surfaces as '!' (the #438/#441 state)"
# The unmutated control: without it, a mutate_manifest that silently failed to
# THE CONTROL must target an entry that is genuinely `auto_install: true`, or it
# asserts that a no-op is a no-op. `secret-scan.yml` — the obvious "unrelated"
# pick — is ALREADY false, so flipping it changed nothing and the assertion
# passed without discriminating anything. `ai-review.yml` is true and produces
# `call / ai-review`, not the bootstrap context: a real, targeted control.
assert_eq "$(mutate_manifest .github/workflows/ai-review.yml)" 'pre-commit.yml' \
  "flipping an UNRELATED auto_install:true entry leaves the bootstrap producer clean"
# ...and the precondition guard itself has teeth: an already-false target refuses.
assert_eq "$(mutate_manifest .github/workflows/secret-scan.yml 2>/dev/null)" 'MUTATION-FAILED' \
  "a no-op mutation is REFUSED, not silently reported as a passing control"

# ---------------------------------------------------------------------------
# 8. #481 — EVERY CONSUMER OF THIS MAP HANDLES EVERY SYMBOL IT CAN EMIT.
#
#    The map is read by more than this suite. `install/deploy-ci-wizard.sh` §6
#    matches the producer field against the consumer's installed filenames, and
#    adding the `!` prefix broke it silently: `grep -qw '!audit-trail.yml'`
#    cannot match a filename, so a healthy product/ops/governance consumer was
#    told "arming would HANG PRs" and pointed at a file that does not exist.
#    The whole suite stayed green, because nothing drives the wizard.
#
#    So the symbol vocabulary is pinned next to the code that defines it, and
#    every reader must be shown to handle it.
# ---------------------------------------------------------------------------
echo ""
echo "== #481: the wizard handles every symbol required-context-map.py emits =="
WIZ="$ROOT/install/deploy-ci-wizard.sh"
assert_ok "[ -f '$WIZ' ]" "deploy-ci-wizard.sh exists (the map's other reader)"

# Read the vocabulary from the map's own source rather than restating it.
symbols="$(grep -oE 'else "[!~?]"' "$MAP" | grep -oE '[!~?]' | sort -u | tr -d '\n')"
assert_eq "$symbols" "!" \
  "producer() emits exactly one install symbol — teach the wizard too if this changes"

wiz_case="$(sed -n '/case "\$producer" in/,/esac/p' "$WIZ")"
assert_contains "$wiz_case" "'!'*)" \
  "wizard §6 has a case arm for the '!' symbol"
assert_contains "$wiz_case" '${producer#!}' \
  "wizard §6 STRIPS '!' before matching the producer against installed filenames"
assert_absent "$wiz_case" "'?non-call') : ;;" \
  "wizard §6 no longer silently passes the retired '?non-call' label (PLAN-025 P8)"

suite_summary "required-contexts"
