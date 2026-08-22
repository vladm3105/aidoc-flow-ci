#!/usr/bin/env bash
# Build the custom ephemeral CI runner image from the digest-pinned Dockerfile.
# Local-only — no registry push. Re-run this script on each runner host (and after
# deliberately updating the upstream actions-runner digest) to refresh the tag.
#
# Usage (from any directory — the script resolves its own location):
#   bash build-image.sh                               # builds aidoc-flow-runner:latest
#   IMAGE_TAG=aidoc-flow-runner:2026-07-20 bash build-image.sh
#
# There is deliberately NO GH_VERSION env override. It used to exist for when the
# apt pin rotated out of the repo (#435) — a failure mode that no longer exists —
# and it cannot work now: the version and its two checksums must move together,
# and the checksums are only settable by editing the Dockerfile. An override that
# can only ever fail the checksum is worse than none.
#
# After building, run-ephemeral.sh uses the local image automatically via
# RUNNER_IMAGE (see README.md in this directory). No service restart is needed
# — the next ephemeral container spawned by the supervisor will pick up the
# new image, because each container is one-shot.

set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-aidoc-flow-runner:latest}"
CONTEXT_DIR="$(dirname "$(readlink -f "$0")")"

echo "==> building ${IMAGE_TAG}"
# THE `gh` PIN GOES STALE ON ITS OWN, WITH NO CHANGE HERE. cli.github.com's apt
# repo carries only the CURRENT release, so an exact `gh=<version>` stops being
# installable the moment upstream ships the next one — and the raw failure is
# `E: Version 'X' for 'gh' was not found` buried in `exit code: 100` under 80
# lines of Dockerfile echo. Measured 2026-08-09: the image had been unbuildable
# since the 2.97.0 release, so the #349 fix could not have been delivered by
# anyone, and nothing detected it because no CI job builds this image.
#
# Capture the build output so the diagnosis can be made from it, then re-emit it
# — a bare `docker build` loses nothing but tells the operator nothing either.
build_log="$(mktemp)"
if docker build --pull ${GH_VERSION:+--build-arg "GH_VERSION=${GH_VERSION}"} \
     -t "${IMAGE_TAG}" "${CONTEXT_DIR}" 2>&1 | tee "$build_log"; then
  :
else
  # Decide on the captured OUTPUT, never on the pipeline's status (CI-0033):
  # `tee` is the last stage, so `$?` here is tee's, not docker's.
  case "$(cat "$build_log")" in
  *"sha256sum"*|*"does not match"*|*"WARNING: 1 computed checksum did NOT match"*)
    echo "❌ the pinned gh checksum did not match the downloaded asset." >&2
    echo "   Either GH_VERSION was bumped without its checksums, or the download was corrupted." >&2
    echo "   Re-derive both from the release's own checksums file:" >&2
    echo "     curl -sSfL https://github.com/cli/cli/releases/download/v<VERSION>/gh_<VERSION>_checksums.txt" >&2
    echo "   then set GH_VERSION, GH_SHA256_AMD64 and GH_SHA256_ARM64 in the Dockerfile TOGETHER." >&2
    ;;
  *"curl"*|*"404"*)
    echo "❌ the pinned gh release asset could not be downloaded." >&2
    echo "   Release assets are immutable, so a 404 means GH_VERSION names a release that does not exist" >&2
    echo "   (a typo, or a version never published for this architecture) — not that a pin expired (#435)." >&2
    ;;
    *)
      echo "" >&2
      echo "❌ image build failed — see the output above." >&2
      ;;
  esac
  rm -f "$build_log"; exit 1
fi
rm -f "$build_log"

echo "==> verifying gh is installed in the built image"
# Capture first (no live pipe to gh → no SIGPIPE under pipefail), then trim.
# A genuine docker/gh failure still surfaces and fails the build — the point
# of this verification step — rather than being masked by a blanket `|| true`.
if gh_ver="$(docker run --rm "${IMAGE_TAG}" gh --version)"; then
  printf '%s\n' "$gh_ver" | head -1
else
  echo "❌ gh not found / not runnable in ${IMAGE_TAG} — image verification failed." >&2
  exit 1
fi

echo "==> verifying libatomic is present (node-backed lint tools need it)"
if docker run --rm "${IMAGE_TAG}" sh -c 'ldconfig -p | grep -q libatomic'; then
  echo "libatomic OK"
else
  echo "❌ libatomic.so not found in ${IMAGE_TAG} — markdownlint's node will crash." >&2
  exit 1
fi

echo "==> verifying python3 -m venv works (sast-scan installs semgrep into one)"
# BUILD THE THING, do not ask whether the package is installed. `python3` being
# present says nothing about `ensurepip`: noble's `python3-venv` is a metapackage
# over a versioned `python3.N-venv`, so a mismatched base leaves `python3 -m venv`
# broken while `dpkg -l python3-venv` and `command -v python3` both look healthy.
# That gap is aidoc-flow-ci#349, and under v3 it reds the whole consolidated
# `scanners` context rather than one scanner. No pipe: the exit status IS the
# decision here (CI-0033 / §27.1), so nothing may sit downstream of it.
if venv_check="$(docker run --rm "${IMAGE_TAG}" sh -c 'python3 -m venv /tmp/_v && /tmp/_v/bin/pip --version' 2>&1)"; then
  printf '%s\n' "$venv_check"
else
  echo "❌ python3 -m venv failed in ${IMAGE_TAG} — sast-scan cannot install semgrep (#349)." >&2
  printf '%s\n' "$venv_check" >&2
  exit 1
fi

echo "==> verifying PyYAML is importable (the D11 guard parses YAML pre-setup-python)"
# Same argument as the venv check above, and it applies verbatim: `python3` being
# present says nothing about `dist-packages/yaml`. `actions/pre-commit`'s D11
# guard runs on the SYSTEM interpreter before `actions/setup-python`, and it
# FAILS CLOSED on ImportError — reddening the whole consolidated `quick-gates`
# required context. The first version of this script proved the venv and merely
# apt-installed `python3-yaml`, which is the asymmetry the venv comment argues
# against. No pipe: the exit status is the decision (CI-0033 / §27.1).
if yaml_check="$(docker run --rm "${IMAGE_TAG}" python3 -c 'import yaml; print("PyYAML " + yaml.__version__)' 2>&1)"; then
  printf '%s\n' "$yaml_check"
else
  echo "❌ PyYAML not importable in ${IMAGE_TAG} — actions/pre-commit's D11 guard will red quick-gates." >&2
  printf '%s\n' "$yaml_check" >&2
  exit 1
fi

echo "==> verifying the image carries its contract stamp (#458)"
# Without the label the supervisor cannot tell a current host from a stale one,
# and #458's whole point is that the state must be readable rather than
# remembered. No pipe: the exit status is the decision (CI-0033 / §27.1).
if contract="$(docker image inspect --format '{{ index .Config.Labels "dev.aidoc-flow.runner.contract" }}' "${IMAGE_TAG}" 2>&1)" \
   && [ -n "$contract" ] && [ "$contract" != "<no value>" ]; then
  echo "runner contract ${contract}"
else
  echo "❌ ${IMAGE_TAG} carries no dev.aidoc-flow.runner.contract label — run-ephemeral.sh will refuse it." >&2
  exit 1
fi

echo "==> ${IMAGE_TAG} ready. To use it:"
echo "    RUNNER_IMAGE=${IMAGE_TAG} ./run-ephemeral.sh"
echo "    # or set RUNNER_IMAGE in ~/.config/ci-runner/<nick>.env for the systemd unit"
