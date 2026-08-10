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
# 2026-07-20). jq, curl, and git are already present. AI calls LiteLLM
# over HTTP; no vendor CLI or durable subscription authentication is installed
# in the image.
#
# `python3-yaml`: `actions/pre-commit`'s D11 precondition guard parses the hook
# config to count what would actually be SELECTED at the runner's stage, and it
# runs BEFORE `actions/setup-python` — deliberately, so a config that selects
# zero hooks is refused before anything is provisioned. That means it uses the
# SYSTEM interpreter, where PyYAML is not present by default. Without this the
# guard raises a raw ImportError traceback and fails the whole consolidated
# `quick-gates` gate for a reason that names neither PyYAML nor the image.
#
# `python3-venv` + `python3-pip`: the base image ships the `python3` INTERPRETER
# but not `ensurepip`, so `python3 -m venv` fails with "ensurepip is not
# available" — a distinction that reads as "python3 is present, we are fine"
# right up until something tries to build an environment. `actions/sast-scan`
# installs semgrep into an isolated venv (D21), so without these the action dies
# at provisioning on every self-hosted run. That was aidoc-flow-ci#349, and under
# v3 it is not contained: `scanners.yml` consolidates dep-scan + trivy-scan +
# sast-scan into ONE job with one collect-then-fail verdict, so a semgrep that
# cannot install reds the whole `scanners` required context and takes two working
# scanners down with it. The v2 blast radius was one context; the v3 blast radius
# is three.
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
    apt-get install -y -qq --no-install-recommends \
      "gh=${GH_VERSION}" ripgrep libatomic1 python3-venv python3-pip python3-yaml; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    gh --version | head -1; \
    # BUILD-TIME PROOF, not a package-list assertion. `apt-get install
    # python3-venv` succeeding does not establish that `python3 -m venv` works —
    # noble's `python3-venv` is a metapackage over the versioned
    # `python3.N-venv`, and a base-image python3 that does not match N leaves
    # ensurepip absent while the install still exits 0. Build the environment the
    # way sast-scan does and fail the IMAGE BUILD if it cannot be built, so #349
    # can never again be discovered by a consumer's red required check.
    python3 -m venv /tmp/_venvcheck; \
    /tmp/_venvcheck/bin/pip --version; \
    rm -rf /tmp/_venvcheck

# Back to the unprivileged runner user before the runner agent starts.
USER runner
