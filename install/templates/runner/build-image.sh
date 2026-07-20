#!/usr/bin/env bash
# Build the custom single-use CI runner image from the digest-pinned Dockerfile.
# Local-only — no registry push. Re-run this script on each runner host (and after
# deliberately updating the upstream actions-runner digest) to refresh the tag.
#
# Usage (from any directory — the script resolves its own location):
#   bash build-image.sh                               # builds aidoc-flow-runner:latest
#   IMAGE_TAG=aidoc-flow-runner:2026-07-20 bash build-image.sh
#
# After building, run-ephemeral.sh uses the local image automatically via
# RUNNER_IMAGE (see README.md in this directory). No service restart is needed
# — the next ephemeral container spawned by the supervisor will pick up the
# new image, because each container is one-shot.

set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-aidoc-flow-runner:latest}"
CONTEXT_DIR="$(dirname "$(readlink -f "$0")")"

echo "==> building ${IMAGE_TAG}"
docker build --pull -t "${IMAGE_TAG}" "${CONTEXT_DIR}"

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

echo "==> ${IMAGE_TAG} ready. To use it:"
echo "    RUNNER_IMAGE=${IMAGE_TAG} ./run-ephemeral.sh"
echo "    # or set RUNNER_IMAGE in ~/.config/ci-runner/<nick>.env for the systemd unit"
