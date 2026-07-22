# install/

One-shot bootstrap for a consumer repo. Clones the consumer, drops the
default workflow callers + config + governance-canon scaffolding + labels
with safe defaults, then prints next steps for the founder. Preserves any
existing files (local override always wins).

## Prerequisites

### You must ALREADY have (infrastructure — not installed by this script)

Copying the workflow files is the easy 10%. The ai-review gate hard-fails
without the infrastructure below, so stand it up **before** the adoption PR or
the consumer's first PR ships a permanently-red required check. The
`install/deploy-ci-wizard.sh preflight <owner/repo>` command audits all of these
and prints a 🟢/🔴 report — run it first.

| Prerequisite | Why | Where |
|---|---|---|
| A reachable **LiteLLM proxy** (OpenAI-compatible) | `ai-review` connects to it via `LITELLM_BASE_URL`; without it the review job `exit 1`s. It is **yours to operate** — canon does not provide one. | `../docs/AI_CI_DEPLOYMENT.md` §1 |
| The **reviewer GitHub App** (id + private key) | mints the token that submits the App approval `composition` enforces | `../docs/REVIEWER_APP_ONBOARDING.md` |
| A **runner pool** for private repos | private consumers run on `["self-hosted","ci-runner","single-use"]`; this account has no GitHub-hosted minutes for private repos (OPS-0049), so an unregistered pool queues every job forever | `../docs/runners.md` |
| **Per-repo secrets + the bot-id var** | `APP_REVIEWER_1_ID/_KEY`, `LITELLM_BASE_URL`, `LITELLM_REVIEW_API_KEY` (+ `LITELLM_DOC_API_KEY` for doc-maintainer), and `vars.APP_REVIEWER_1_BOT_ID` | set BEFORE the first PR; the wizard preflight lists which are missing |

**Public-repo caveat:** the LiteLLM proxy is private-network-only, so a public
repo's ai-review *review* job must run on the self-hosted pool
(`runner_labels_review`), not `ubuntu-latest` — GitHub-hosted public runners
cannot reach the proxy. `../docs/runners.md` §5a has the wiring. Adopting a public
repo without this leaves ai-review unable to connect, with no error naming why.

### Operator tooling

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
bash <(curl -fsSL https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v2.11.0/install/install.sh) \
  vladm3105/<consumer-repo> --visibility private

# Or override the tag explicitly:
CI_TAG=ci/v2.11.0 bash install.sh vladm3105/<consumer-repo> --visibility public
```

The pinned tag is resolved as **`CI_TAG` env > repo-root `VERSION` file
(when run from a checkout) > hardcoded fallback**; `install.sh` prints
which source it used at startup. In `curl`-piped mode there is no local
`VERSION`, so the hardcoded fallback (bumped every release cut) is
authoritative — pass `CI_TAG=` to pin a specific tag.

### De-branding for external adopters

The installed `config.json` trust handle and the `CLAUDE.md` canon-repo
links default to the aidoc-flow workspace's own values. A different org
overrides them at install time; the values are substituted into the
templates as they are fetched.

| Flag | Substitutes | Default |
|---|---|---|
| `--codeowner <handle>` | `config.json` `trust.ai_review` + `governance.code_owners`, and every owner route in `.github/CODEOWNERS` (leading `@` optional) | `vladm3105` |
| `--canon-operations-url <url>` | the 7 `CLAUDE.md` links to the operations canon repo | `../operations` |
| `--canon-ci-url <url>` | the `CLAUDE.md` link to this CI canon repo | `../aidoc-flow-ci` |

```bash
CI_TAG=ci/v2.11.0 bash install.sh acme/their-repo --visibility private \
  --codeowner acme-bot \
  --canon-operations-url https://github.com/acme/ops-canon \
  --canon-ci-url https://github.com/acme/ci-canon
```

Omitting all three produces **byte-identical** output to the pre-D2
templates. `install.sh` fails closed if any placeholder survives
substitution, so a half-branded file is never written. Only files
`install.sh` newly writes are substituted — an existing `config.json`,
`CLAUDE.md`, or `.github/CODEOWNERS` is preserved untouched.

### Updating an already-adopted consumer

Bootstrap adds new surfaces and preserves everything. To pull a *newer*
canon into a repo that already adopted, use `--update`:

```bash
CI_TAG=ci/vX.Y.Z bash install.sh <owner/repo> --update [--non-interactive]
```

It walks `install/templates/manifest.json`, re-fetches each surface the
consumer already has, diffs it against canon, and (interactively) prompts
`[k]eep / [r]eplace / [d]iff-only` per file. `--non-interactive` replaces
only `safe_to_replace` files (the mechanical workflow files + `dependabot.yml`)
and keeps policy/governance files (and the consumer-customized `codeql.yml`).
Full walkthrough: [`../docs/UPDATE_GUIDE.md`](../docs/UPDATE_GUIDE.md).

## What it does

1. **Clones** the consumer repo to `$PWD/aidoc-flow-ci-bootstrap-$$/consumer`
   (stable; not auto-deleted — inspect + commit after the script exits).
2. **Drops the default callers** `.github/workflows/ai-review.yml` +
   `composition.yml` + `pre-commit.yml`. Preserves any existing local
   files. Template naming is **not** one convention — `ai-review` has no
   per-visibility variants, `composition` suffixes both, and `pre-commit`'s
   *public* variant is the bare name (see `../docs/REPO_STANDARDS.md`
   §16.9). `pre-commit.yml` is bootstrapped **unconditionally**, regardless
   of `--tier`: it emits `call / Lint / format / security hooks`, which is a
   required status check on every tier that has required checks at all, and
   is the bootstrap tier's only one.
3. **Drops `.github/ai-review/config.json`** (the per-repo policy).
   Preserves existing.
4. **Drops `.github/CODEOWNERS`** (owner routes substituted with
   `--codeowner`; the drift check normalizes owner identity, so a
   consumer's own handle is not read as drift). Preserves existing.
5. **Governance-canon bootstrap (PLAN-003):** if the consumer has no
   `CLAUDE.md`, installs the canon template (with placeholders to fill
   before commit). If it has one, checks for the 5 required canonical
   sections and prints a manual-merge suggestion — it never auto-edits an
   existing `CLAUDE.md`.
6. **Self-review canon (PLAN-002):** installs `scripts/pre_push_check.sh`
   (preserves an existing one) and **merges** the canon hook block into
   `.pre-commit-config.yaml` idempotently (via a `# CANON:` marker). The
   merge needs `ruamel.yaml` or `pyyaml` (see Prerequisites) and upgrades
   `default_install_hook_types` to include `pre-push`.
7. **Creates the 18 canonical labels** via `gh label create` (idempotent +
   fail-loud — prefetches existing labels, exits nonzero on real
   failures): 7 state/control (`ai:review-passed`, `ai:review-changes`,
   `ai:review-infra-error`, `ai:human-review-required`, `skip-ai-review`,
   `ai:autofix-applied`, `ai:autofix-escalated`), 8 diff-class
   (`governance`, `docs`, `workflows`, `scripts`, `agents`, `tests`,
   `config`, `plans`), plus `dependencies`, `security`, and
   `skip-audit-trail`. (`ai:enforcer-failed` is NOT installer-created — the
   auto-merge enforcer self-provisions it on demand; see `LABELS.md`.)
8. **Prints founder next steps** (secrets, branch protection — see below).

The additional caller templates that ship in `install/templates/workflows/`
(`labeler.yml`, `codeql.yml`, `markdown-lint.yml`, `links.yml`,
`secret-scan.yml`, `docs-sync.yml`, `doc-maintainer.yml`,
`auto-merge-ai-prs.yml`) are **not** bootstrapped automatically — the consumer
chooses which to adopt per
[`../docs/WORKFLOWS.md`](../docs/WORKFLOWS.md) §4 adoption sequencing.
Use the matching `*-private.yml` / `*-public.yml` variant where both exist.
Private templates select `[self-hosted, ci-runner, single-use]`; public
templates select `ubuntu-latest`.

## What it does NOT do

- **Doesn't add secrets** — the founder adds `APP_REVIEWER_1_ID` /
  `APP_REVIEWER_1_KEY` plus `LITELLM_BASE_URL`, `LITELLM_REVIEW_API_KEY`, and
  `LITELLM_DOC_API_KEY`. See
  [`../docs/REVIEWER_APP_ONBOARDING.md`](../docs/REVIEWER_APP_ONBOARDING.md).
- **Doesn't change branch protection** — the required checks
  (`call / ai-review`, `call / composition`, `call / verify`) must be
  added for the gates to actually enforce. See
  [`../docs/BRANCH_PROTECTION.md`](../docs/BRANCH_PROTECTION.md). It **does**
  now VERIFY server-side standards at the end of a bootstrap (when `--tier` is
  given) and reports honestly — clean / drift-or-absent / uncheckable — so
  "installed" never reads as "standards on" (PLAN-015 B2). Run the check
  standalone anytime: `install.sh <owner/repo> --verify-standards --tier <tier>`
  (exits non-zero on genuine drift; needs an admin-scoped `gh` token to read
  branch protection).
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
| **LiteLLM secrets** (ci/v2.0.0) | `LITELLM_BASE_URL` + `LITELLM_REVIEW_API_KEY` are required for the ai-review gate to connect to the LiteLLM proxy. `LITELLM_DOC_API_KEY` is required for doc-maintainer (optional). Set per-repo or at org level. | [`../docs/REVIEWER_APP_ONBOARDING.md`](../docs/REVIEWER_APP_ONBOARDING.md), [`../docs/MIGRATION_v2.0.0.md`](../docs/MIGRATION_v2.0.0.md) |

See [`../docs/troubleshooting.md`](../docs/troubleshooting.md) for the full
troubleshooting guide.
