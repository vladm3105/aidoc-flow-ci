# Deploying the full CI stack on a new repo — AI-agent playbook

**Audience: an AI agent** (Claude Code / Codex / etc.) deploying the complete
aidoc-flow CI surface — ai-review, composition, auto-merge, pre-commit,
audit-trail, secret-scan, links, markdown-lint, labeler, docs-sync, codeql —
onto a new (or under-covered) workspace repo.

This is the **operational how-to**. It encodes every failure mode learned in
the 2026-07 fleet rollout so you don't re-derive them. Companion docs (read
when a step points you there): [`WORKFLOWS.md`](WORKFLOWS.md) (catalog + skip
rules), [`REVIEWER_APP_ONBOARDING.md`](REVIEWER_APP_ONBOARDING.md) (App +
secrets), [`runners.md`](runners.md) (self-hosted pools),
[`REPO_STANDARDS.md`](REPO_STANDARDS.md) (tiers + settings).

> **Fast path:** run [`install/deploy-ci-wizard.sh`](../install/deploy-ci-wizard.sh)
> `preflight <owner/repo>` first — it audits every prerequisite below and
> prints a 🟢/🔴 report. Then `scaffold` to generate the caller files. The
> wizard automates the deterministic parts; this doc explains the judgment
> calls + gotchas it can't.

---

## 0. TL;DR — the deployment in one screen

```text
1. PREFLIGHT   →  determine visibility; verify runner pool (private), reviewer
                  App + secrets + bot-id var, labels, allowed-actions policy.
                  Some items are 🔴 FOUNDER-ONLY — you cannot do them.
2. DEPLOY      →  add caller workflows + config files, in dependency order,
                  using the PUBLIC or PRIVATE variant. One PR per workflow (or
                  a small batch); each PR carries a CHANGELOG entry + the
                  OPS-0069 audit-trail phrase. First adoption: admin-merge the
                  bootstrap PR (pull_request_target workflows read from base
                  branch, which doesn't have them yet).
3. VERIFY      →  open a throwaway test PR; confirm the App submits an APPROVED
                  review (ai-review green) and composition resolves SUCCESS.
                  Verify labeler fires and canonical labels are applied.
                  Do NOT skip this — it's the only end-to-end smoke test.
4. ARM         →  (opt-in) add the checks to branch-protection
                  required_status_checks so they actually block merges. Do this
                  only after the probe PR shows them all green.
```

**🔴 vs 🟢 — know what you cannot do.** Three prerequisites are FOUNDER-ONLY
(you prepare the ask, the human executes):

| 🔴 Founder-only | Why you can't |
| --- | --- |
| Install the reviewer **App** on the repo (+ on `aidoc-flow-operations`) | App installation is F5 blast-radius; needs org/repo admin UI |
| Set the AI **secrets** (`APP_REVIEWER_1_ID`, `APP_REVIEWER_1_KEY`, `LITELLM_BASE_URL`, `LITELLM_REVIEW_API_KEY`, `LITELLM_DOC_API_KEY`) | You don't hold the App private key / token values |
| Register a self-hosted **runner pool** for a private repo | Provisions infra on the runner host; use the canon `install/templates/runner/provision-runner.sh` (see below) |
| Merge the first CI-adoption PR (pull_request_target chicken-and-egg) | ai-review/composition can't self-trigger until the workflows are on `main`; admin-merge the adoption PR, then verify on a follow-up test PR |

Everything else (caller workflows, config files, non-secret variables, labels,
verification, arming) is 🟢 — you do it.

---

## 1. Preflight — gather facts + verify prerequisites

### 1.1 Visibility (decides EVERYTHING downstream)

```bash
gh repo view <owner/repo> --json visibility -q .visibility   # PUBLIC | PRIVATE
```

- **PUBLIC** → callers run on `ubuntu-latest`; use the `*-public.yml` templates.
- **PRIVATE** → callers run on the self-hosted pool; use the `*-private.yml`
  templates. **Private repos are self-hosted ONLY — never `ubuntu-latest`**
  (OPS-0049 billing + policy). The canonical private label is the JSON array
  `["self-hosted", "ci-runner", "single-use"]`. AI jobs use the same
  disposable pool and authenticate to LiteLLM with scoped repository secrets.

Do NOT trust a stale doc's visibility column — always re-check with `gh`.

### 1.2 Runner pool (PRIVATE repos only) — 🔴 if absent

```bash
gh api repos/<owner/repo>/actions/runners --jq '.runners[]|{name,status,labels:[.labels[].name]}'
```

Expect an online runner with labels `self-hosted,ci-runner,single-use`. If none:
**do not fall back to `ubuntu-latest`** — a private caller left on
`ubuntu-latest` or the placeholder `runner-self` queues forever.

**Provisioning a runner for a new private repo (🔴 founder, 🟢 AI assistants pre-flight):**

The runner host must already be set up with Docker and a copy of the canon
runner templates (`install/templates/runner/` from this repo — workspace hosts
use the vendored copy in their operations checkout once PLAN-016 W3 lands).
From the runner host, as the user running the CI supervisor:

```bash
cd <path-to>/install/templates/runner
TARGET_REPO=<owner/repo> \
INSTANCE=<short-nick> \
bash provision-runner.sh
```

(`RUNNER_LABELS` defaults to the final `self-hosted,ci-runner,single-use`;
override it only for a label-migration coexistence window — see the
directory's README.)

This builds the runner Docker image, installs the systemd unit, writes the
per-repo environment file, enables lingering, and starts the supervisor. The
runner self-registers with the requested labels and begins accepting jobs
immediately. The `INSTANCE` nickname is used for the systemd instance name
(`ci-runner@<nick>.service`) and the environment file
(`~/.config/ci-runner/<nick>.env`).

Each private repo needs its own runner instance because GitHub Actions
self-hosted runners are repo-scoped by default. The supervisor creates a fresh
single-use container per job — multiple repo instances can run concurrently on
the same host.

Pass `--dry-run` to the script to inspect what it would do without changing state.
See [`runners.md`](runners.md) for the underlying run-ephemeral.sh architecture.

### 1.3 Reviewer App + secrets + bot-id (needed for ai-review + composition)

A working ai-review repo has FOUR repo-level secrets and ONE variable
(`vladm3105` is a user account — no org secrets to inherit, so these are
**per-repo**):

```bash
gh secret   list -R <owner/repo> | grep -E 'APP_REVIEWER_1_ID|APP_REVIEWER_1_KEY|LITELLM_BASE_URL|LITELLM_REVIEW_API_KEY|LITELLM_DOC_API_KEY'
gh variable list -R <owner/repo> | grep APP_REVIEWER_1_BOT_ID
```

- **Secrets missing → 🔴 founder** must (a) install the `aidoc-reviewer` App on
  the repo and trust-config repo, then (b) set the App credentials plus a
  reachable LiteLLM URL and scoped virtual key. The model alias is
  `.litellm.model` in the trusted AI-review config.
- **`APP_REVIEWER_1_BOT_ID` variable → 🟢 you set it.** It's the App's bot-user
  id and is **App-global** (same on every repo): **`294948438`**. Set it
  directly — no need to wait for the first review to capture it:

  ```bash
  gh variable set APP_REVIEWER_1_BOT_ID -R <owner/repo> --body "294948438"
  ```

  Without it, `composition` runs **INERT** (passes without enforcing).
- **Trust allowlist:** the repo's PRs are only auto-reviewed if the PR author is
  in `operations@main` `.github/ai-review/config.json` `trust.ai_review`
  (`vladm3105` is already listed). No local `config.json` is required in the
  consumer for the default trust flow (composition reads the bot-id variable +
  operations' config).

### 1.4 Labels — 🟢 create the canon set

```bash
# state-machine + skip labels (ai-review + audit-trail need these)
gh label create ai:review-passed         -R <owner/repo> --color 0e8a16 --force
gh label create ai:review-changes        -R <owner/repo> --color d93f0b --force
gh label create ai:human-review-required -R <owner/repo> --color fbca04 --force
gh label create skip-ai-review           -R <owner/repo> --color ededed --force
gh label create skip-audit-trail         -R <owner/repo> --color d876e3 --force
```

Plus the diff-class / path labels your `.github/labeler.yml` references
(`labeler` does NOT create labels). Canonical specs:
`install/templates/labels.json`.

### 1.5 Allowed-actions policy (sanity check)

```bash
gh api repos/<owner/repo>/actions/permissions/selected-actions \
  --jq '{patterns_allowed, verified_allowed, github_owned_allowed}'
```

Should allow `vladm3105/*`, `actions/*`, `github/*` — and `verified_allowed`
**false** (CI-0011: the founder's own account replaces the verified marketplace
as the sole non-GitHub-owned allowance).
This is why the reusables install tools as **binaries/npm**, never third-party
marketplace actions (see §5). If a repo's policy is stricter, a caller that
pulls a blocked action will `startup_failure` silently.

---

## 2. Deployment sequence (dependency-ordered)

Deploy in this order — later phases depend on earlier ones. One PR per
workflow, or batch the independent content-checks. **Pin every caller at the
current tag** (read `../VERSION`; do not copy a tag from prose).

| # | Phase | Workflow(s) | Depends on | Notes |
| --- | --- | --- | --- | --- |
| 1 | Hygiene | `pre-commit` | repo has `.pre-commit-config.yaml` | runs `pre-commit run --all-files` |
| 2 | Doc-quality | `links`, `markdown-lint` (report-only), `labeler` | §1.4 labels; per-repo configs (§4) | content floor |
| 3 | Secrets | `secret-scan` | — | skip if repo ships its own gitleaks `security.yml` (covered-by-own) |
| 4 | Audit | `audit-trail` | `skip-audit-trail` label | renders as `call / verify` |
| 5 | **Review** | `ai-review` + `composition` | §1.3 App + secrets + bot-id | deploy together; verify (§6) |
| 6 | Merge | `auto-merge-ai-prs` | ai-review + repo in `auto_merge.repos` allowlist | inert without ai-review |
| 7 | Documentation | `doc-maintainer` (dry-run) | LiteLLM doc key + config/conventions | AI decides which docs the merged PR made stale; live mode needs `aidoc-flow-bot` App (🔴) |
| 8 | Code-scan | `codeql` | repo has compiled/interpreted code | skip docs-only repos |

**Covered-by-own exception:** if a repo already lints markdown via its own
pre-commit hook, or scans secrets via its own `security.yml`, treat that
workflow as satisfied — do NOT also add the canon one (and NEVER overwrite the
repo's existing `.markdownlint.json` — see §5). Record it as `🕳 own` in
`WORKFLOWS.md` §2.

### First-adoption sequence (do NOT skip)

When deploying CI to a repo that has never had it before, chicken-and-egg
patterns block several workflows from firing on the adoption PR itself:

| Order | Action | Why this order |
|---|---|---|
| 1 | **Provision the runner** | Private repos need a `[ci-runner, single-use]` pool before any job can be picked up (§1.2). |
| 2 | **Set App secrets + bot-id variable** | `APP_REVIEWER_1_ID`/`_KEY`, `LITELLM_BASE_URL`/`_REVIEW_API_KEY`/`_DOC_API_KEY`, `APP_REVIEWER_1_BOT_ID` — all required for trust + ai-review + composition. |
| 3 | **Create canonical labels** | `apply-standards.sh --apply` on the target repo creates the 18 canon labels that the labeler and ai-review expect. |
| 4 | **Open the CI adoption PR** | Add caller workflows, `.github/labeler.yml`, `.pre-commit-config.yaml`, config files. This PR CANNOT trigger ai-review/composition/labeler (they read from `main`, which doesn't have them yet). |
| 5 | **Merge via admin** | Admin-merge the adoption PR. The workflows are now on `main`. |
| 6 | **Open a probe PR** | A trivial content PR (e.g. whitespace in HANDOFF.md). ai-review, composition, and labeler MUST now fire from `main`. Verify all return green. |
| 7 | **Arm branch protection** | Only after the probe PR shows all checks green (§7). Do not arm a check whose workflow has never run on this repo. |

Do not skip the probe PR — it's the only way to confirm the full chain works
before arming checks that would block every future PR.

---

## 3. Deploying a caller (the mechanical loop)

For each workflow, per PR:

1. **Branch first** (never commit to `main` directly).
2. Copy the caller to `.github/workflows/<name>.yml`. **On a private repo use the
   `-private.yml` variant** — `pre-commit`/`markdown-lint`/`links`/`labeler`/
   `secret-scan`/`standards-drift` each ship `install/templates/workflows/<name>-private.yml`
   (the bare-name `<name>.yml` is the PUBLIC template — `ubuntu-latest`/no labels,
   which queues forever on a private repo's self-hosted pool, the FT-9 brick).
   Only `doc-maintainer` (and the PLAN-013-unified `ai-review`) is genuinely
   single-template.
3. **Pin the tag** to the current `ci/vX.Y.Z`; for a PRIVATE repo add
   `runner_labels: '["self-hosted", "ci-runner", "single-use"]'` under `with:`.
4. Add the repo-specific config file(s) (§4).
5. **Add a CHANGELOG entry** in the same PR if the repo has a `## [Unreleased]`
   section + a doc-currency rule (operations-style repos enforce it — a missing
   entry is a guaranteed ai-review `CHANGES_REQUESTED`).
6. Commit with the **OPS-0069 audit-trail phrase** in the body (either
   `Multi-agent self-review per OPS-0065 (<agents>): <verdict>` or
   `Self-review skipped per founder OK <reason>`), else the local pre-push hook /
   `audit-trail` CI check blocks.
7. Open the PR, watch checks, merge when green (`--admin` only per the repo's
   rules; private repos with strict protection can't bypass a failing required
   check).

Use `install.sh <owner/repo> --repin` to bump an existing caller's tag
(version-string-only). **Never `install.sh --update` on a customized repo** — it
re-applies the template body and clobbers `runner_labels`/permissions/triggers
(FT-9).

---

## 4. Per-repo config files

| Workflow | Config file | Notes |
| --- | --- | --- |
| `markdown-lint` | `.markdownlint.json` | Copy `install/templates/.markdownlint.json` **only if the repo has none**. If it already has one (or its own pre-commit markdownlint), DO NOT overwrite it — you'll break its gate (see §5). |
| `links` | `.lychee.toml` | Base on `install/templates/.lychee.toml`. Add repo-specific `exclude`/`exclude_path` for cross-repo `../sibling/` links + debt paths (see §5). |
| `labeler` | `.github/labeler.yml` | Map the repo's ACTUAL paths → its ACTUAL labels (v5 `changed-files: any-glob-to-any-file:` format). Labels must pre-exist. |
| `doc-maintainer` | `.github/doc-maintainer.json` + `.github/doc-maintainer-conventions.md` | Copy both starter templates, keep `dry_run: true`, and tailor allowed/low-risk paths and repository documentation rules before the first run. |
| `pre-commit` | `.pre-commit-config.yaml` | Consumer-owned; the workflow just runs it. |

---

## 5. Gotchas checklist — READ BEFORE YOU DEPLOY

Every one of these cost real debugging time. They are load-bearing.

1. **Private repos = self-hosted ONLY.** Never `ubuntu-latest` on a private
   repo. `runner-self` is a placeholder, not a registered label — a caller left
   on it queues forever.
2. **`runner_labels` must be valid JSON.** `'["self-hosted", "ci-runner", "single-use"]'`
   — with the double-quotes. A shell heredoc silently strips inner quotes
   (`'[self-hosted, ci-runner, ...]'` → invalid JSON → `fromJSON()` breaks the
   workflow). Write caller files with a real editor / quoted heredoc and
   validate: `python3 -c "import yaml,json; print(json.loads(yaml.safe_load(open(F))['jobs']['call']['with']['runner_labels']))"`.
3. **`ai-review` caller MUST point at the canon reusable**, not at another
   consumer. `uses: vladm3105/aidoc-flow-ci/.github/workflows/ai-review.yml@ci/vX.Y.Z`
   — NOT `vladm3105/aidoc-flow-operations/.github/workflows/ai-review.yml@main`
   (operations' file is itself a `pull_request_target` *caller*, not a
   `workflow_call` reusable → `uses:`-ing it fails with "workflow file issue").
4. **`ai-review` + `composition` callers need a top-level `permissions:` block.**
   Without it they `startup_failure` at run-init (zero jobs, web-UI-only error)
   under the repo read-default token. ai-review needs
   `contents/pull-requests/issues: write`; composition needs
   `pull-requests/contents: read`. The public/private templates ship these as of
   `ci/v1.7.1`/`v1.9.5` — verify they're present after copying.
5. **`composition` needs `vars.APP_REVIEWER_1_BOT_ID`** (= `294948438`) or it
   runs INERT (passes without enforcing). Set it in preflight (§1.3).
6. **Content-checks install tools directly, never third-party actions.** Canon
   may `uses:` only `actions/*`, `github/*`, `vladm3105/aidoc-flow-ci/*`
   (REPO_STANDARDS §4.3). `gacts/gitleaks`, `lycheeverse/lychee-action` and
   `DavidAnson/markdownlint-cli2-action` are additionally published by
   **non-verified** creators, so they are blocked at run-init → silent
   `startup_failure` (the error is web-UI-only; `actionlint` does NOT catch
   it). Since FT-46 / CI-0011 the deployed allowlist sets `verified_allowed:
   false`, so a verified creator's action is **also** blocked unless it matches
   `patterns_allowed` (`vladm3105/*`, `actions/*`, `github/*`). Note the deployed
   boundary is deliberately a little **wider** than the canon authoring rule above
   — the owner's whole account versus canon's single repo; do not infer one from
   the other. The reusables already install
   binaries/npm — you don't touch this, but know the failure signature.
   `continue-on-error` is ILLEGAL on a reusable-call job — for report-only, use
   the reusable's `fail-on-findings: false` input, not `continue-on-error`.
7. **`links`: cross-repo `../sibling/` links break in single-repo CI.** They
   resolve in the local multi-repo workspace but not in CI (only the one repo is
   checked out). If a local `lychee --offline` says 0 errors but CI fails on
   `business/…`/`operations/…` paths, add sibling excludes to `.lychee.toml`
   (`exclude = ["/business/", "/operations/", …]`). Also base the config on the
   canonical template — a hand-written one that omits `accept = ["200","206","429"]`
   - host excludes will flake on the weekly external run, and the `include_fragments`
   key is INVALID in lychee 0.24.2 (fatal TOML parse error — fixed in the
   template `ci/v1.9.5`).
8. **`markdown-lint`: NEVER clobber an existing `.markdownlint.json`.** If the
   repo already tunes it (or lints markdown via its own pre-commit hook), leave
   it alone and treat markdown-lint as covered-by-own. Overwriting a repo's
   relaxed config with the canon one re-enables rules its prose violates and
   breaks its pre-commit gate.
9. **`markdown-lint` deploys report-only.** A repo with existing markdown has
   hundreds of cosmetic violations. Deploy `fail-on-findings: false` (surfaces
   annotations, doesn't block). Graduating to blocking needs a per-repo
   `markdownlint-cli2 --fix` pass + arming (§7). Tracked as FT-11.
10. **`doc-maintainer` dry-run needs LiteLLM but no bot App.** It requires
    `LITELLM_BASE_URL` and the model-restricted `LITELLM_DOC_API_KEY`. The
    `aidoc-flow-bot` App is required only for live-mode PR creation. Inspect
    several coherent dry-run plans and patches before enabling live mode.
11. **`pull_request_target` callers (ai-review, composition) don't self-trigger on
    the adoption PR.** GitHub runs `pull_request_target` from the BASE branch,
    which doesn't have the caller yet. So the PR that ADDS ai-review won't run it.
    **Workaround:** merge the adoption PR via admin override (the caller workflows
    aren't required checks yet), then open a fresh test PR to verify (§6). After
    verification, arm the required checks per §7.
12. **Doc-currency + `secrets: inherit`.** Repos with the "every PR updates
    CHANGELOG" rule will `CHANGES_REQUESTED` any workflow PR lacking a CHANGELOG
    entry. And match the repo's caller convention — if its other callers use
    `secrets: inherit`, add it (harmless; its absence gets flagged).
13. **`APP_REVIEWER_1_KEY` must be a valid PEM private key.** A miscopied,
    truncated, or incorrectly-encoded key produces `A JSON web token could not
    be decoded` when the trust step signs the JWT, followed by `fatal: repository
    not found` on `aidoc-flow-operations` (the token has no access). Verify the
    key starts with `-----BEGIN RSA PRIVATE KEY-----` and ends with
    `-----END RSA PRIVATE KEY-----`. Set it from the file, not copy-paste:
    `gh secret set APP_REVIEWER_1_KEY -R <owner/repo> < app-key.pem`. The trust
    step fetches the allowlist from `aidoc-flow-operations` containing — the
    reviewer App MUST also be installed on that repo for the token to have access.
14. **`.github/labeler.yml` must exist on the base branch before labeler fires.**
    The labeler workflow uses `pull_request_target`, which reads config from
    `main`. Adding `.github/labeler.yml` in the CI adoption PR has no effect
    until that PR is merged — the same chicken-and-egg pattern as ai-review.
    After merging the adoption PR, the labeler will work on subsequent PRs.
15. **Canonical labels must be created before labeler can apply them.**
    `actions/labeler` applies existing labels — it does not create them. Run
    `apply-standards.sh --apply` (or `gh label create` for each canon label)
    before expecting the labeler to work. Without this, the labeler job
    succeeds silently but produces `Label does not exist` annotations.
    The 18 canonical labels are defined in `install/templates/labels.json`.
16. **Design-spec repos still need a `.pre-commit-config.yaml`.** The ops-tier
    branch protection includes `call / Lint / format / security hooks` as a
    required check. Even a docs-only or design-spec repo needs a minimal
    pre-commit config to satisfy it. A valid bare-minimum config:

    ```yaml
    repos:
      - repo: https://github.com/pre-commit/pre-commit-hooks
        rev: v5.0.0
        hooks:
          - id: check-yaml
          - id: check-json
          - id: end-of-file-fixer
          - id: trailing-whitespace
    ```

    If a repo genuinely has no checkable files, remove the check from branch
    protection rather than carrying a hollow pre-commit config.

---

## 6. Verification protocol (do NOT skip)

After ai-review + composition are on `main`:

1. Open a **throwaway test PR** with a one-line doc edit (e.g. a comment in
   `HANDOFF.md`). ai-review (`pull_request_target`, from main) now fires.
2. Watch for ALL of:
   - `call / ai-review` → **SUCCESS** (you'll often see a stale `CANCELLED` +
     a `SUCCESS` — the SUCCESS is the real one).
   - An **APPROVED review by `aidoc-reviewer[bot]`** (id `294948438`):

     ```bash
     gh api repos/<owner/repo>/pulls/<pr>/reviews \
       --jq '.[]|select(.user.type=="Bot")|{login:.user.login,id:.user.id,state:.state}'
     ```

   - `ai:review-passed` label applied.
   - `call / composition` → **SUCCESS** (fires on the App's review + on
     ai-review's `workflow_run`).
3. If ai-review/composition show `startup_failure` → §5 items 3, 4, 6. If
   composition is green but never enforces → item 5 (bot-id var).
4. Merge (or close) the test PR.

---

## 7. Arming — making checks actually gate (opt-in)

A deployed check RUNS but does not BLOCK until it's in branch protection.
Arm only checks you've confirmed run **green**, and never arm a check whose
gate is still flaky (e.g. don't arm `composition` while `ai-review` is
failing). Add contexts:

```bash
gh api -X PATCH repos/<owner/repo>/branches/main/protection/required_status_checks \
  -f 'contexts[]=call / ai-review' -f 'contexts[]=call / composition' \
  -f 'contexts[]=call / verify'  # audit-trail
```

(Or edit the full protection payload — see `install/templates/branch-protection-*.json`
per tier.) Arming is a hard-to-reverse, blast-radius change — confirm with the
human before arming a repo you don't own.

---

## 8. Troubleshooting quick-reference

| Symptom | Cause | Fix |
| --- | --- | --- |
| `startup_failure`, zero jobs, no logs | (a) missing `permissions:` block; (b) blocked third-party action; (c) invalid `runner_labels` JSON | §5 items 2, 4, 6 |
| ai-review "workflow file issue" | caller points at a non-reusable (operations' caller) | §5 item 3 |
| Private caller queues forever | `ubuntu-latest`/`runner-self` on a private repo, or no pool | §1.2, §5 item 1 |
| composition green but doesn't block | not armed, OR bot-id var unset (inert) | §7 / §5 item 5 |
| links green locally, red in CI | cross-repo `../sibling/` links | §5 item 7 |
| pre-commit red after adding `.markdownlint.json` | clobbered the repo's tuned config | §5 item 8 (restore original) |
| `A JSON web token could not be decoded` on trust step | `APP_REVIEWER_1_KEY` not valid PEM or App not installed on `aidoc-flow-operations` | §5 item 13 |
| labeler "Label does not exist" | canonical labels not created on repo | §5 item 15 |
| labeler queued forever, never fires | `.github/labeler.yml` missing from base branch, or no labels present | §5 items 14, 15 |
| `call / Lint / format / security hooks` never fires on PRs | no `.pre-commit-config.yaml`; or pre-commit workflow not on main (pull_request reads from PR branch — verify it | §5 item 16 |
| ai-review `CHANGES_REQUESTED` on a workflow PR | missing CHANGELOG entry / `secrets: inherit` | §5 item 12 |

---

## 9. The wizard

[`install/deploy-ci-wizard.sh`](../install/deploy-ci-wizard.sh) automates the
safe, deterministic parts:

```bash
install/deploy-ci-wizard.sh preflight <owner/repo>   # read-only prerequisite audit → 🟢/🔴 report
install/deploy-ci-wizard.sh plan      <owner/repo>   # ordered deployment plan for this repo
install/deploy-ci-wizard.sh scaffold  <owner/repo> <dir>  # write caller files + configs into <dir> for you to review + commit
install/deploy-ci-wizard.sh verify    <owner/repo> <pr>   # poll ai-review + composition + App review on a PR
```

The wizard does NOT commit, push, merge, set secrets, or install Apps — those
stay under your (and the human's) control. It surfaces 🔴 blockers, picks the
right public/private variant + runner labels, and generates valid caller files
so you avoid the JSON-quoting and permissions-block gotchas. Follow this doc for
the judgment calls it can't make (covered-by-own decisions, per-repo lychee/
labeler config, arming).
