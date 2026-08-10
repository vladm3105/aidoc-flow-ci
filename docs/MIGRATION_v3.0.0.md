# Migration — ci/v2.x → ci/v3.0.0

**Status:** written ahead of the tag. `ci/v3.0.0` is not cut, and nothing below
is actionable until it is. Steps 1–7 are the procedure; §"Before you start"
lists what must be true first.

v3 changes **packaging, not checks**. No check is deleted and no defense is
dropped — PLAN-025 §2 inventories 46 of them and carries all 46. What changes is
that six checks stop being `workflow_call` reusables and become **composite
actions** invoked from two consolidated jobs.

## Why

A `workflow_call` reusable always gets its own runner. On
`aidoc-flow-operations` the `audit-trail` reusable took ~167 seconds to run a
`grep`, almost all of it provisioning. A private repo's PR fanned out to ~8
self-hosted jobs, and one supervisor instance runs them **serially**.

Composite actions run inside the calling job and share one provisioning cycle.
Six jobs become two.

## Summary of changes

| | v2 | v3 |
|---|---|---|
| Packaging | 6 reusable workflows | 6 composite actions under `actions/` |
| PR lint jobs | 3 (`pre-commit`, `markdown-lint`, `links` internal) | 1 (`quick-gates`) |
| Scanner jobs | 3 (`dep-scan`, `trivy-scan`, `sast-scan`) | 1 (`scanners`) |
| Required-context shape | `call / <name>` | bare job name |
| External link check | a job inside `links.yml` | its own `links-external.yml` |
| Failure reporting | one job per check, all verdicts arrive together | `continue-on-error` per step + one collect-then-fail verdict step |

**Breaking, and this is the whole of it:** the required status-check context
strings change. A required context that no job emits is never satisfied, and the
PR is blocked with no way to clear it except `--admin`. Step 4 exists for that.

## The mapping — old context → new context

Read this table as the migration. The left column is what your branch protection
and rulesets name **today**.

| v2 caller file | v2 required context | v3 caller file | v3 context |
|---|---|---|---|
| `pre-commit.yml` | `call / Lint / format / security hooks` | `quick-gates.yml` | `quick-gates` |
| `markdown-lint.yml` | `call / markdownlint` | `quick-gates.yml` | `quick-gates` |
| `links.yml` (job `internal`) | `internal / lychee (internal)` | `quick-gates.yml` | `quick-gates` |
| `links.yml` (job `external`) | *not required — weekly* | `links-external.yml` | `links-external` (not required) |
| `dep-scan.yml` | `call / dep-scan` | `scanners.yml` | `scanners` |
| `trivy-scan.yml` | `call / trivy-scan` | `scanners.yml` | `scanners` |
| `sast-scan.yml` | `call / sast-scan` | `scanners.yml` | `scanners` |

**Three v2 contexts collapse into `quick-gates`, three into `scanners`.** You
add two and remove six.

### Why the shape changes

`call / X` is not a naming convention — it is `<caller-job-key> / <callee-job-name>`,
and **only a reusable call produces it**. A plain job emits its own job name with
no prefix. v3's jobs are plain jobs, so their contexts are bare.

### What does NOT change

Leave these alone. They are not part of v3.

| Workflow | Context | Why unchanged |
|---|---|---|
| `secret-scan.yml` | `call / gitleaks` | Stays a reusable. It runs on `ubuntu-latest` and is **fork-visible by design** — it must see a fork's code. The other three scanners are self-hosted and fork-*guarded*. One job has one `runs-on`, and a job skipped on a fork **satisfies** a required context — so merging them would have made `scanners` go green on every fork PR with gitleaks never having run (PLAN-025 P3a) |
| `audit-trail.yml` | `call / verify` | Needs `types: [… labeled, unlabeled]` for its skip-label escape hatch, which would re-run lint on every label write. Also needs a job-level event refusal and the credential asymmetry — three defenses for one provisioning cycle |
| `composition.yml` | per repo | Fires on `pull_request_review` + `workflow_run`, never `pull_request`. Only same-trigger checks can share a job |
| `ai-review.yml` | `ai-review` | Untouched by v3 |

## Before you start

1. **Self-hosted consumers: rebuild the runner image.** v3's `sast-scan`
   installs semgrep into a venv and `pre-commit`'s guard parses YAML on the
   system interpreter. The pre-v3 image has neither `python3-venv` nor
   `python3-yaml` ([#349](https://github.com/vladm3105/aidoc-flow-ci/issues/349)).
   The image is built **per host with no registry push**, so a host that has not
   re-run `build-image.sh` keeps the old one:

   ```sh
   cd install/templates/runner && bash build-image.sh
   ```

   `build-image.sh` now *builds a venv* to verify rather than checking the
   package list, and fails the build if it cannot. **Do this before step 3** — if
   you do not, `scanners` is red on its first run and takes the two working
   scanners down with `sast-scan`.

2. **Actions Runner >= 2.327.1.** Unchanged from v2, still a hard floor:
   `gh api repos/<owner>/<repo>/actions/runners --jq '.runners[].version'`.

3. **Know your two surfaces.** Required contexts live in branch protection
   **and** in rulesets. `apply-standards.sh` never touches rulesets (CI-0029).
   Read both, or step 4 will look done and not be.

## Required consumer actions

### 1. Repin everything else to `@ci/v3.0.0`

<!-- sync-version-refs:ignore-start -->
<!-- CI-0024: this tag is the SUBJECT of this document, not a pin that tracks
     VERSION. Without these markers every later release cut would rewrite it,
     and a "migrate to v3.0.0" guide would instruct the reader to install
     whatever the newest tag happens to be. -->
```sh
CI_TAG=ci/v3.0.0 bash install.sh <owner/repo> --repin
```
<!-- sync-version-refs:ignore-end -->

`--repin` rewrites `uses:` tag strings only. It does **not** deliver a change
that lives in a caller *body*, and it does not add new files.

### 2. Install the v3 callers

<!-- sync-version-refs:ignore-start -->
<!-- CI-0024: the tag here is the SUBJECT of this document. -->
```sh
CI_TAG=ci/v3.0.0 bash install.sh <owner/repo> \
  --add-surface .github/workflows/quick-gates.yml \
  --add-surface .github/workflows/scanners.yml \
  --add-surface .github/workflows/links-external.yml
```
<!-- sync-version-refs:ignore-end -->

The files land in a **fresh clone** the run prints
(`aidoc-flow-ci-bootstrap-<pid>/consumer/`), not in your current checkout —
commit and push from there. `git status` in the directory you launched from will
look clean, which is not the mode having done nothing.

`--add-surface` is the route for a surface you do not already have — bootstrap
installs only the `auto_install: true` set, and `--update` deliberately never
introduces a new one. It:

- **resolves the public/private variant from your repo's live visibility**, so
  you cannot pick wrong (a private repo left on the public variant pins
  `ubuntu-latest`, and this account has no GitHub-hosted minutes for private
  repos — the job **queues forever**, and `timeout-minutes` cannot fire on a job
  that never starts);
- **never overwrites** an existing file — refreshing one is `--update`'s job;
- **warns** when a v2 caller it replaces is still installed, because both will
  run until you remove them. That is expected during step 3, not a mistake;
- **arms nothing.** Branch protection and rulesets are untouched. Step 4 is
  yours.

#### If you are pinned to a release before `--add-surface` existed

Fetch them directly. Take the variant that matches your visibility:

<!-- sync-version-refs:ignore-start -->
<!-- CI-0024: same reason as step 1 — the tag in this URL is what the reader is
     migrating TO, so it must not be rewritten to the current VERSION. -->
```sh
BASE=https://raw.githubusercontent.com/vladm3105/aidoc-flow-ci/ci/v3.0.0/install/templates/workflows

# PUBLIC repo
curl -fsSL "$BASE/quick-gates.yml"     -o .github/workflows/quick-gates.yml
curl -fsSL "$BASE/links-external.yml"  -o .github/workflows/links-external.yml

# PRIVATE repo — the -private variants carry the self-hosted labels.
curl -fsSL "$BASE/quick-gates-private.yml"    -o .github/workflows/quick-gates.yml
curl -fsSL "$BASE/links-external-private.yml" -o .github/workflows/links-external.yml

# BOTH visibilities — scanners is uniform-protected (self-hosted either way).
curl -fsSL "$BASE/scanners.yml"        -o .github/workflows/scanners.yml
```
<!-- sync-version-refs:ignore-end -->

The symptom of picking the wrong variant is a check pinned on "Expected —
Waiting for status to be reported", not a failure. `--add-surface` above removes
that choice; this fallback does not.

Do **not** delete the v2 callers yet. Steps 3–4 depend on both being present.

### 3. Observe the new contexts green — before requiring anything

Open a throwaway PR. Confirm `quick-gates`, `scanners` and `links-external`
appear and pass. Both old and new run in this window, so you are paying double
briefly; that is the cost of not stranding a required context.

**Do not skip to step 4.** Arming a context nothing produces is the failure this
sequence exists to prevent, and it has no `--admin`-free exit.

### 4. Swap the required contexts — add first, then remove

Add `quick-gates` and `scanners`. Only once they are green on a real PR, remove
the six v2 contexts from the mapping table.

Do it in **both** places:

```sh
# branch protection
gh api repos/<owner>/<repo>/branches/main/protection/required_status_checks \
  --method PATCH -f 'checks[][context]=quick-gates' -f 'checks[][context]=scanners'

# rulesets — a SEPARATE surface apply-standards.sh does not touch (CI-0029)
gh api repos/<owner>/<repo>/rulesets --jq '.[] | {id, name}'
gh api repos/<owner>/<repo>/rulesets/<id>   # inspect, then PATCH
```

`links-external` is weekly and non-blocking — **do not** make it required.

### 5. Delete the v2 callers

Only after step 4 shows the new contexts required and the old ones gone:

```sh
git rm .github/workflows/{pre-commit,markdown-lint,links,dep-scan,trivy-scan,sast-scan}.yml
```

Keep `secret-scan.yml`, `audit-trail.yml`, `composition.yml`, `ai-review.yml`.

### 6. Re-check for a stranded context

```sh
gh pr checks <a-fresh-PR>
```

A context stuck on "Expected — Waiting for status to be reported" means
something is still required that nothing emits. Go back to step 4 and check the
surface you did not check.

### 7. Expect one behaviour change in how failures surface

In v2 each check was its own job and every verdict arrived together. In v3 the
three checks inside a job run **sequentially as steps**. They are
`continue-on-error: true` with a single collect-then-fail `verdict` step, so you
still get all three verdicts in one run — but they are in one job's log, not
three job entries.

The verdict fails **closed**: any outcome that is not exactly `success` reds the
job, including `skipped`, `cancelled`, and the empty string a step that never ran
produces.

## Known issues

- **`sast-scan` needs the rebuilt image.** See "Before you start" step 1. This
  is the single most likely cause of a red `scanners` on day one.
- **The full `docs/v3/` documentation set is not written** (PLAN-025 P5). This
  guide is the migration path; the architecture, flows and rules documents are
  not yet available.
- **No rollback script** (PLAN-025 P9). The manual procedure is below.

## Rollback

v3 deletes nothing: **the v2 tags remain and the v2 reusables are still in
canon.** To go back:

<!-- sync-version-refs:ignore-start -->
<!-- CI-0024, AND THIS IS THE DAMAGING ONE. The command in item 1 exists to pin
     a consumer BACK to the last v2 tag during an incident. When the v2 migration
     guide's equivalent line was left unmarked, every release cut rewrote it to
     the new tag — so the published rollback instruction re-pinned FORWARD, and
     an operator following it mid-incident did the exact opposite of what the
     heading promised. Do not remove these markers.
     The span covers the WHOLE list: an ignore-end between items splits the
     ordered list and reds MD029. -->
1. Re-add the six v2 caller files at your previous tag. **Do not rely on a bare
   bootstrap for this** — only `pre-commit.yml` is `auto_install: true`; the
   other five are `false`, so `bash install.sh <owner/repo>` restores **one of
   six**, and step 2 then arms six contexts of which five have no producer. That
   is the hang this procedure exists to end, re-created by it. Restore each one
   explicitly:

   ```sh
   CI_TAG=ci/v2.16.0 bash install.sh <owner/repo> \
     --add-surface .github/workflows/pre-commit.yml \
     --add-surface .github/workflows/markdown-lint.yml \
     --add-surface .github/workflows/links.yml \
     --add-surface .github/workflows/dep-scan.yml \
     --add-surface .github/workflows/trivy-scan.yml \
     --add-surface .github/workflows/sast-scan.yml
   ```

   Verify all six are present before step 2. `--add-surface` skips any that
   already exist, so re-running it is safe.
2. Re-add the six v2 contexts to branch protection **and** rulesets; observe
   green.
3. Remove `quick-gates` and `scanners` from both surfaces.
4. Delete `quick-gates.yml`, `scanners.yml`, `links-external.yml`.
<!-- sync-version-refs:ignore-end -->

Reverse-order the same add-new → observe → remove-old discipline. The reason it
is safe in both directions is the same reason it is slow in both: at no point is
a required context left with nothing producing it.
