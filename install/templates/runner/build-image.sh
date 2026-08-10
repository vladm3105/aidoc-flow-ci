#!/usr/bin/env bash
# Build the custom single-use CI runner image from the digest-pinned Dockerfile.
# Local-only — no registry push. Re-run this script on each runner host (and after
# deliberately updating the upstream actions-runner digest) to refresh the tag.
#
# Usage (from any directory — the script resolves its own location):
#   bash build-image.sh                               # builds aidoc-flow-runner:latest
#   IMAGE_TAG=aidoc-flow-runner:2026-07-20 bash build-image.sh
#   GH_VERSION=<newer> bash build-image.sh   # if the pinned gh version has
#                                            # rotated out of the apt repo
#
# After building, run-ephemeral.sh uses the local image automatically via
# RUNNER_IMAGE (see README.md in this directory). No service restart is needed
# — the next ephemeral container spawned by the supervisor will pick up the
# new image, because each container is one-shot.

set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-aidoc-flow-runner:latest}"
CONTEXT_DIR="$(dirname "$(readlink -f "$0")")"

echo "==> building ${IMAGE_TAG}"
docker build --pull ${GH_VERSION:+--build-arg "GH_VERSION=${GH_VERSION}"} -t "${IMAGE_TAG}" "${CONTEXT_DIR}"

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

echo "==> ${IMAGE_TAG} ready. To use it:"
echo "    RUNNER_IMAGE=${IMAGE_TAG} ./run-ephemeral.sh"
echo "    # or set RUNNER_IMAGE in ~/.config/ci-runner/<nick>.env for the systemd unit"
