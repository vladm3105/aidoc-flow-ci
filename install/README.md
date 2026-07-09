# install/

One-shot bootstrap for a consumer repo. Clones the consumer, drops the
default workflow callers + config + governance-canon scaffolding + labels
with safe defaults, then prints next steps for the founder. Preserves any
existing files (local override always wins).

## Prerequisites

Install these on the **operator's machine** before running (not on CI
runners):

| Tool | Why |
|---|---|
| **`bash` ≥ 4.0** | The canon `scripts/pre_push_check.sh` this installs uses `mapfile` (bash 4+). macOS ships bash 3.2 — `brew install bash`, or skip installing the pre-push hook. |
| **`gh`** (authenticated, write on the target repo) | clones the consumer + creates labels |
| **`git`** + **`curl`** | clone + template fetch |
| **`python3`** | **always** — used for canonical-label creation (stdlib only) and, when present, the `.pre-commit-config.yaml` merge |
| **`ruamel.yaml`** \| **`pyyaml`** (one of) | only when the consumer **already has** a `.pre-commit-config.yaml` to merge into (ruamel preferred — it preserves the consumer's comments; PyYAML strips them) |

## Run it

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v1.7.0/install/install.sh) \
  vladm3105/<consumer-repo> --visibility private

# Or override the tag explicitly:
CI_TAG=ci/v1.7.0 bash install.sh vladm3105/<consumer-repo> --visibility public
```

The pinned tag is resolved as **`CI_TAG` env > repo-root `VERSION` file
(when run from a checkout) > hardcoded fallback**; `install.sh` prints
which source it used at startup. In `curl`-piped mode there is no local
`VERSION`, so the hardcoded fallback (bumped every release cut) is
authoritative — pass `CI_TAG=` to pin a specific tag.

## What it does

1. **Clones** the consumer repo to `$PWD/aidoc-flow-ci-bootstrap-$$/consumer`
   (stable; not auto-deleted — inspect + commit after the script exits).
2. **Drops the default callers** `.github/workflows/ai-review.yml` +
   `composition.yml` (per-visibility templates). Preserves any existing
   local files.
3. **Drops `.github/ai-review/config.json`** (the per-repo policy).
   Preserves existing.
4. **Governance-canon bootstrap (PLAN-003):** if the consumer has no
   `CLAUDE.md`, installs the canon template (with placeholders to fill
   before commit). If it has one, checks for the 5 required canonical
   sections and prints a manual-merge suggestion — it never auto-edits an
   existing `CLAUDE.md`.
5. **Self-review canon (PLAN-002):** installs `scripts/pre_push_check.sh`
   (preserves an existing one) and **merges** the canon hook block into
   `.pre-commit-config.yaml` idempotently (via a `# CANON:` marker). The
   merge needs `ruamel.yaml` or `pyyaml` (see Prerequisites) and upgrades
   `default_install_hook_types` to include `pre-push`.
6. **Creates the 16 canonical labels** via `gh label create` (idempotent +
   fail-loud — prefetches existing labels, exits nonzero on real
   failures): 5 state/control (`ai:review-passed`, `ai:review-changes`,
   `ai:human-review-required`, `skip-ai-review`, `ai:autofix-applied`),
   8 diff-class (`governance`, `docs`, `workflows`, `scripts`, `agents`,
   `tests`, `config`, `plans`), plus `dependencies`, `security`, and
   `skip-audit-trail`.
7. **Prints founder next steps** (secrets, branch protection — see below).

The additional caller templates that ship in `install/templates/workflows/`
(`labeler.yml`, `codeql.yml`, `markdown-lint.yml`, `links.yml`,
`secret-scan.yml`, `pre-commit.yml`, `docs-sync.yml`, `doc-maintainer.yml`,
`auto-merge-ai-prs.yml`) are **not** bootstrapped automatically — the consumer
chooses which to adopt per
[`../docs/WORKFLOWS.md`](../docs/WORKFLOWS.md) §4 adoption sequencing.
(`audit-trail-check.yml` has no distributed caller template yet — adopt it by
hand-authoring a caller from this repo's own `.github/workflows/audit-trail.yml`
until the template ships.)

## What it does NOT do

- **Doesn't add secrets** — the founder adds `APP_REVIEWER_1_ID` /
  `APP_REVIEWER_1_KEY` + the reviewer auth token (`CLAUDE_CODE_OAUTH_TOKEN`
  / `ANTHROPIC_API_KEY` / `OPENAI_API_KEY`). See
  [`../docs/REVIEWER_APP_ONBOARDING.md`](../docs/REVIEWER_APP_ONBOARDING.md).
- **Doesn't change branch protection** — the required checks
  (`call / ai-review`, `call / composition`, `call / verify`) must be
  added for the gates to actually enforce. See
  [`../docs/BRANCH_PROTECTION.md`](../docs/BRANCH_PROTECTION.md).
- **Doesn't install the GitHub App** on the consumer repo (founder, per
  the F5 "only select repositories" blast-radius rule).
- **Doesn't overwrite existing files** — preserve = local override always
  wins.

## After install — per-consumer prerequisites

Two settings are required for the reusable workflow to start (both
discovered during framework Phase A):

| Setting | Why | Doc |
|---|---|---|
| **Actions allowlist** | If the consumer is in `selected actions` mode, `vladm3105/aidoc-flow-ci/*` must be in `patterns_allowed` or the reusable returns `startup_failure` | [`../docs/troubleshooting.md` §13](../docs/troubleshooting.md) |
| **Caller `permissions:` block** | If the consumer's repo-default `workflow_permissions: read`, the reusable's `contents: write` is rejected — add an explicit `permissions:` block to the caller | [`../docs/troubleshooting.md` §14](../docs/troubleshooting.md) |

See [`../docs/troubleshooting.md`](../docs/troubleshooting.md) for the full
troubleshooting guide.
