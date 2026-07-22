# Custom single-use CI runner image — pinned official actions-runner plus `gh`.
#
# Why this exists: the official `ghcr.io/actions/actions-runner:latest` is a
# bare runner agent (Ubuntu noble + the runner binaries). GitHub-HOSTED runners
# come with a 50 GB toolchain (gh, node, python, …) on top of the same base
# image — self-hosted runners using `actions-runner:latest` do NOT. Workflows
# that assume `gh` is available (composition.yml, ai-review.yml) silently fail
# `gh: not found` and — because their retry loops do `gh api ... 2>/dev/null` —
# the failure surfaces as a misleading "(api.github.com) — retrying" warning.
#
# `gh` is required by composition, ai-review, doc-maintainer, and drift checks.
# `libatomic1` is required by node-backed tools the lint workflows install at
# job time (markdownlint-cli2's node crashes with "libatomic.so.1: cannot open
# shared object file" without it — shipped defect class, business #63
# 2026-07-20). Python, jq, curl, and git are already present. AI calls LiteLLM
# over HTTP; no vendor CLI or durable subscription authentication is installed
# in the image.
#
# Build (on the runner host, from this directory):
#   docker build -t aidoc-flow-runner:latest .
#   # or: bash build-image.sh
#
# No registry push — the image is built locally on each runner host. That keeps
# the supply chain on this repo + the official actions-runner image + the
# official cli.github.com apt repo + Ubuntu apt.

FROM ghcr.io/actions/actions-runner@sha256:0cfdcc701ce933c6d243c6b0b2da767366dc9f2e99961d4c3754b0b78084cdda

# The actions-runner image runs as the unprivileged `runner` user. Install as
# root, then drop back. apt-get + gpg manipulation needs root.
USER root

# Install gh from cli.github.com's official apt repo (the canonical install
# path for Debian/Ubuntu per https://github.com/cli/cli/blob/trunk/docs/install_linux.md).
ARG GH_VERSION=2.96.0
RUN set -eux; \
    apt-get update -qq; \
    apt-get install -y -qq --no-install-recommends ca-certificates curl gnupg; \
    install -d -m 0755 /etc/apt/keyrings; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list; \
    apt-get update -qq; \
    apt-get install -y -qq --no-install-recommends "gh=${GH_VERSION}" ripgrep libatomic1; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    gh --version | head -1

# Back to the unprivileged runner user before the runner agent starts.
USER runner
