#!/usr/bin/env bash
# tests/test_runner_image.sh — the runner image's install path (#435).
#
# WHY THIS FILE EXISTS: nothing tested `install/templates/runner/` at all, and
# that is precisely how the same defect armed itself TWICE with no commit in
# between. `gh` was installed from cli.github.com's apt repo with an exact
# `gh=${GH_VERSION}` pin — and that repo carries only the CURRENT release, so
# the pin stops being installable the moment upstream ships the next one:
#
#   2026-08-09  pinned 2.96.0, apt carried only 2.97.0  -> unbuildable
#   2026-08-20  pinned 2.97.0, apt carried only 2.98.0  -> unbuildable again
#
# An unbuildable image is worse than a stale one: it makes every fix that needs
# a rebuild undeliverable while it sits merged (#349 spent that way).
#
# These assertions are OFFLINE by design — the suite must not depend on
# cli.github.com being reachable, or a network blip becomes a red gate.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tests/lib.sh
. "$HERE/lib.sh"
ROOT="$(cd "$HERE/.." && pwd)"
DF="$ROOT/install/templates/runner/Dockerfile"

echo "== the runner image's gh install cannot expire on its own (#435) =="
if [ ! -s "$DF" ]; then
  _r "runner Dockerfile missing at install/templates/runner/Dockerfile"
  suite_summary "runner-image"
  exit
fi
_g "runner Dockerfile exists"

body="$(sed -E 's/^[[:space:]]*#.*$//' "$DF")"

# THE DEFECT ITSELF. An exact apt version pin for gh is the shape that expires.
# Matched against comment-stripped text so the explanation cannot satisfy it.
if printf '%s' "$body" | grep -qE '"?gh=\$\{?GH_VERSION\}?"?|"?gh=[0-9]+\.[0-9]+\.[0-9]+"?'; then
  _r "gh is pinned by APT VERSION — cli.github.com carries only the CURRENT release, so this pin expires with no commit (#435)"
else
  _g "gh is NOT installed by an apt exact-version pin (the shape that expires)"
fi

assert_contains "$body" "releases/download/v\${GH_VERSION}" \
  "gh comes from a versioned RELEASE ASSET (immutable — an exact pin against one never expires)"
assert_contains "$body" "gh_\${GH_VERSION}_linux_" \
  "the asset FILENAME carries GH_VERSION too — bumping the version cannot leave the URL stale"
assert_contains "$body" "sha256sum --check --strict" \
  "the downloaded .deb is checksum-verified BEFORE install (D20)"
_sha_line="$(printf '%s\n' "$body" | grep -n 'sha256sum --check' | head -1 | cut -d: -f1)"
_ins_line="$(printf '%s\n' "$body" | grep -n 'install .*gh\.deb' | head -1 | cut -d: -f1)"
if [ -n "$_sha_line" ] && [ -n "$_ins_line" ] && [ "$_sha_line" -lt "$_ins_line" ]; then
  _g "checksum is verified BEFORE the .deb is installed, not after"
else
  _r "checksum/install ordering wrong or unreadable (sha at '${_sha_line:-?}', install at '${_ins_line:-?}')"
fi

for arch in AMD64 ARM64; do
  val="$(printf '%s\n' "$body" | sed -nE "s/^ARG GH_SHA256_${arch}=([0-9a-f]+).*/\1/p" | head -1)"
  if [ "${#val}" -eq 64 ]; then
    _g "GH_SHA256_${arch} is a full 64-char sha256"
  else
    _r "GH_SHA256_${arch} missing or not 64 hex chars (got '${val:-<none>}')"
  fi
done
assert_contains "$body" "no pinned gh checksum for architecture" \
  "an unsupported architecture REFUSES rather than installing an unverified gh"
assert_contains "$(cat "$DF")" "checksums.txt" \
  "the Dockerfile states where a bump's checksums come from"

echo "== a host that skipped a rebuild announces itself (#458) =="
RE="$ROOT/install/templates/runner/run-ephemeral.sh"
BI="$ROOT/install/templates/runner/build-image.sh"

assert_contains "$body" "ARG RUNNER_CONTRACT=" \
  "the image declares a CONTRACT version — the thing a host can be stale against"
assert_contains "$body" "dev.aidoc-flow.runner.contract" \
  "...and stamps it as a label, so the state is READ from the image, not remembered"

if [ -s "$RE" ]; then
  re_body="$(sed -E 's/^[[:space:]]*#.*$//' "$RE")"
  assert_contains "$re_body" "RUNNER_CONTRACT_MIN" "the supervisor declares a minimum contract"
  assert_contains "$re_body" "build-image.sh" "...and names the command that fixes a stale host"
  # TWO OUTCOMES, and the split is the whole safety property. The unit is
  # `Restart=always`/`RestartSec=5`, so a hard refusal on a condition true of
  # EVERY host today would not "stop the fleet" — it would CRASH-LOOP it,
  # fleet-wide, every five seconds.
  assert_contains "$re_body" "RUNNER_CONTRACT_REFUSE_RC=78" \
    "...refuses with a DISTINCT exit code, not a bare 1"
  assert_contains "$re_body" 'exit "$RUNNER_CONTRACT_REFUSE_RC"' \
    "...and exits with it when the contract is below the minimum"
  # A missing label is the state of every host until it rebuilds once, so it must
  # WARN, not exit — otherwise landing this change crash-loops the whole fleet.
  _nolabel_arm="$(printf '%s\n' "$re_body" | sed -n "/''|'<no value>'/,/;;/p")"
  assert_contains "$_nolabel_arm" "WARNING" "a MISSING label warns (every host is in that state until it rebuilds)"
  assert_absent   "$_nolabel_arm" "exit"    "...and does NOT exit — Restart=always would crash-loop it every 5s"

  # The unit must know 78 is terminal, or Restart=always defeats the refusal.
  UNIT="$ROOT/install/templates/runner/ci-runner@.service"
  if [ -s "$UNIT" ]; then
    # EXTRACT AND COMPARE, do not match two literals. Changing one of them to 79
    # leaves both literal assertions green while the refusal becomes a 5s
    # crash-loop — the same drift shape the contract pair above guards against,
    # on the pair whose drift actually takes the fleet down.
    _rc_declared="$(printf '%s\n' "$re_body" | sed -nE 's/^RUNNER_CONTRACT_REFUSE_RC=([0-9]+).*/\1/p' | head -1)"
    _rc_unit="$(sed -nE 's/^RestartPreventExitStatus=(.*)$/\1/p' "$UNIT" | tr ' ' '\n' | grep -Fx "${_rc_declared:-none}" | head -1)"
    if [ -n "$_rc_declared" ] && [ "$_rc_unit" = "$_rc_declared" ]; then
      _g "the unit names the SAME refusal code the supervisor exits ($_rc_declared) — verified by comparison, not by two literals"
    else
      _r "refusal-code drift: supervisor exits '${_rc_declared:-?}' but the unit's RestartPreventExitStatus does not list it — the refusal becomes a 5s crash-loop"
    fi
    # ...and the refusal must verify that precondition AT RUN TIME, because the
    # unit is installed only by provision-runner.sh while every operator-facing
    # refresh instruction says to run build-image.sh.
    assert_contains "$re_body" "unit_knows_refuse_rc" \
      "the refusal CHECKS the installed unit before exiting, and degrades to a warning when it cannot"
  else
    _r "ci-runner@.service missing — nothing makes the refusal terminal"
  fi
  # THE DRIFT CLASS, and this repo has been bitten by it three times this cycle
  # (#423, #426, #428): the same fact stated in two files, where only one moves.
  df_contract="$(printf '%s\n' "$body"    | sed -nE 's/^ARG RUNNER_CONTRACT=([0-9]+).*/\1/p'        | head -1)"
  re_min="$(     printf '%s\n' "$re_body" | sed -nE 's/.*RUNNER_CONTRACT_MIN=.*:-([0-9]+)\}.*/\1/p' | head -1)"
  if [ -n "$df_contract" ] && [ "$df_contract" = "$re_min" ]; then
    _g "the Dockerfile's contract ($df_contract) and the supervisor's minimum ($re_min) AGREE"
  else
    _r "contract drift: Dockerfile declares '${df_contract:-?}' but the supervisor requires '${re_min:-?}' — raise both in ONE change, or every host is refused (or none is)"
  fi
else
  _r "run-ephemeral.sh missing — nothing refuses a stale image"
fi

if [ -s "$BI" ]; then
  assert_contains "$(sed -E 's/^[[:space:]]*#.*$//' "$BI")" "dev.aidoc-flow.runner.contract" \
    "build-image.sh PROVES the stamp landed (an unstamped image is refused at run time)"
else
  _r "build-image.sh missing"
fi

suite_summary "runner-image"
