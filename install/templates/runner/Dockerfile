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
# `gh` is required by composition, ai-review, and drift checks.
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
# gh from its immutable GitHub release asset (#435) + Ubuntu apt for the rest.

FROM ghcr.io/actions/actions-runner@sha256:0cfdcc701ce933c6d243c6b0b2da767366dc9f2e99961d4c3754b0b78084cdda

# The actions-runner image runs as the unprivileged `runner` user. Install as
# root, then drop back. apt-get needs root.
USER root

# gh is installed from its IMMUTABLE RELEASE ASSET, not from the apt repo.
#
# WHY (#435): cli.github.com's apt repo carries only the CURRENT release, so an
# exact `gh=${GH_VERSION}` pin stops being installable the moment upstream ships
# the next one — with no change to this repo, and with nothing detecting it. The
# image then cannot be rebuilt BY ANYONE, which is worse than a stale pin: it
# makes every fix that requires a rebuild undeliverable while it sits merged.
# That already happened once — `sast-scan` could not install semgrep (#349), the
# fix landed here, and the image had been unbuildable since 2.97.0 shipped.
#
# MEASURED TWICE, which is why this is a class fix and not another bump:
#   2026-08-09  pinned 2.96.0, apt carried only 2.97.0  -> unbuildable
#   2026-08-20  pinned 2.97.0, apt carried only 2.98.0  -> unbuildable again
# The second is the same defect re-arming itself with no commit in between.
#
# A GitHub release asset is immutable, so an exact pin against one never
# expires. Verified: the 2.97.0 .deb is still downloadable after 2.98.0 shipped.
# Checksums come from the release's own published `gh_<version>_checksums.txt`
# and are verified BEFORE install (D20 — a downloaded artifact is mutable state
# on infrastructure we do not control, and canon installs tools as verified
# BINARIES rather than trusting a package index, per REPO_STANDARDS §4.3).
#
# TO BUMP: change GH_VERSION and BOTH checksums together, from
#   curl -sSfL https://github.com/cli/cli/releases/download/v<V>/gh_<V>_checksums.txt
# A version bumped without its checksums fails the build loudly, which is the
# intended failure mode.
# ── IMAGE CONTRACT (#458) ────────────────────────────────────────────────────
# The image is built PER HOST with no registry push, so a host that has not
# re-run build-image.sh keeps the old one and NOTHING prompts it. That state used
# to exist in exactly one place — HANDOFF.md — which CI-0028 regenerates wholesale
# at every wrap, so it was re-summarised or dropped on each pass.
#
# The fix is not a hand-maintained list of hosts (that is a second queue, and it
# goes stale the same way). It is to make the image STATE ITS OWN VERSION, so
# "which hosts have rebuilt?" is answerable from any run instead of remembered.
#
# BUMP THIS whenever a change here must reach every host before it takes effect
# — a new package a gate depends on, a base-digest move, a gh bump. Then raise
# `RUNNER_CONTRACT_MIN` in run-ephemeral.sh in the SAME change: the supervisor
# refuses to start a runner on an image below the minimum, and says how to fix it.
ARG RUNNER_CONTRACT=2
# LABEL only, deliberately: every consumer (build-image.sh, run-ephemeral.sh,
# the README's one-liner) reads the label. An ENV would be a second copy of the
# same fact, injected into every job container, with no reader.
LABEL org.opencontainers.image.title="aidoc-flow-runner" \
      dev.aidoc-flow.runner.contract="${RUNNER_CONTRACT}"

ARG GH_VERSION=2.98.0
ARG GH_SHA256_AMD64=f65a3fa2fa0eb2e97c445ee3f5e087a40aae03b64847f45a8f13805e504535d6
ARG GH_SHA256_ARM64=bbc4ac7964c2a091fd555cd1758d10a7cfcfdc472e405f0b0fb958f05d535cb6
RUN set -eux; \
    apt-get update -qq; \
    apt-get install -y -qq --no-install-recommends ca-certificates curl; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) gh_sha="${GH_SHA256_AMD64}" ;; \
      arm64) gh_sha="${GH_SHA256_ARM64}" ;; \
      *) echo "ERROR: no pinned gh checksum for architecture '${arch}' — refusing to install an unverified gh." >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/gh.deb \
      "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${arch}.deb"; \
    printf '%s  %s\n' "${gh_sha}" /tmp/gh.deb | sha256sum --check --strict; \
    apt-get install -y -qq --no-install-recommends /tmp/gh.deb; \
    rm -f /tmp/gh.deb; \
    apt-get install -y -qq --no-install-recommends \
      ripgrep libatomic1 python3-venv python3-pip python3-yaml; \
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
