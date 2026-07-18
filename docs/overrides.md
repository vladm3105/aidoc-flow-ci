# Overrides — `aidoc-flow-ci`

How consumers customize `aidoc-flow-ci`'s shared workflows for
their repo's needs. The pattern is intentionally simple — GitHub
gives us "local always wins" by default; you don't engineer it,
you just use it.

For the broader architecture, see [`architecture.md`](architecture.md)
§7. For runner-label choices, see [`runners.md`](runners.md). For
per-repo config files, see [`architecture.md`](architecture.md) §4.

## 1. The foundational rule

GitHub Actions runs whatever's in your consumer repo's
`.github/workflows/*.yml`. A shared workflow from `aidoc-flow-ci`
only runs when your consumer workflow explicitly calls it via
`uses:`. So **local always wins** — by GitHub's default, not by
engineering.

This means:

- There is no merge/inheritance/diamond pattern. GitHub doesn't
  support one.
- "Override" means **your workflow file is what runs**.
- Drift between your workflows and the canonical templates is
  expected over time; detecting drift is the discipline (see
  [`architecture.md`](architecture.md) §8).

## 2. Three override modes (in order of preference)

Pick the smallest override that solves your need.

### Mode 1: Parameter override (preferred — smallest deviation)

**When:** You want the canonical workflow behavior but with one
or two knobs different (e.g., `runner_labels`, `reviewer`,
`fail-on-error`).

**How:** Keep the `uses:` call. Set inputs via `with:`.

**Example: PRIVATE consumer overriding runner labels**

```yaml
# .github/workflows/markdown-lint.yml in consumer repo
name: markdown-lint
on:
  pull_request:
  push: { branches: [main] }
permissions:
  contents: read
jobs:
  call:
    uses: vladm3105/aidoc-flow-ci/.github/workflows/markdown-lint.yml@ci/v2.7.0
    with:
      runner_labels: '["self-hosted", "ci-runner", "single-use"]'   # PRIVATE override; default is "ubuntu-latest"
      globs: |
        **/*.md
        !node_modules
```

**Example: codeql consumer overriding languages**

```yaml
jobs:
  codeql:
    uses: vladm3105/aidoc-flow-ci/.github/workflows/codeql.yml@ci/v2.7.0
    with:
      languages: '["python","actions","javascript-typescript"]'
```

**Example: links consumer narrowing scope to docs/ only**

```yaml
jobs:
  internal:
    uses: vladm3105/aidoc-flow-ci/.github/workflows/links.yml@ci/v2.7.0
    with:
      mode: internal
      paths: docs
```

Parameter override keeps you on the canonical `uses:` call — the
smallest possible deviation. Note that `sync/check-drift.sh` is
`diff`-based: it **will** flag the changed `with:` block as a
`::warning::` (it can't distinguish an intentional parameter override
from accidental drift). That warning is expected and reconcilable — it
is the signal described in §5, not an error.

### Mode 2: Full replacement (when canonical genuinely doesn't fit)

**When:** Your repo's logic for that workflow genuinely differs
from the canonical (different AI gateway, custom trust-gate
algorithm, vendor-specific scanning, etc.).

**How:** Drop the `uses:` call. Write your own jobs/steps in the
consumer workflow file.

**Example: replacing ai-review with a custom reviewer**

```yaml
# .github/workflows/ai-review.yml in consumer repo
name: ai-review
on:
  pull_request_target:
    types: [opened, synchronize, reopened, labeled, unlabeled]
permissions:
  contents: read
  pull-requests: write
jobs:
  custom-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { ref: ${{ github.event.pull_request.head.sha }} }
      # ... your custom reviewer logic
```

Full replacement is fully your file; drift detection will warn
that this file diverges from canonical, but won't block. Document
the WHY in a comment at the top of the file so future contributors
understand the deviation.

### Mode 3: Add a custom workflow (when canonical doesn't have it)

**When:** You need a check `aidoc-flow-ci` doesn't ship (e.g.,
vendor-specific test runner, custom deploy gate).

**How:** Create a new `.github/workflows/<custom>.yml` in your
consumer repo, siblings to the shared callers.

**Example: a per-repo conformance job**

```yaml
# .github/workflows/conformance.yml in consumer repo (not in aidoc-flow-ci)
name: conformance
on:
  pull_request:
jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/conformance.sh
```

This is the cleanest mode — no override at all, just an additive
check. No drift to flag.

## 3. When to use which mode

| Question | Use mode |
|---|---|
| "I want the canonical self-hosted `ci-runner` / `single-use` pool instead of `ubuntu-latest`" | Mode 1 (parameter override) |
| "I want a different LiteLLM model alias" | Mode 1 (`model` input override) |
| "I want to add a new check `aidoc-flow-ci` doesn't have" | Mode 3 (custom workflow) |
| "I want to wrap the canonical workflow in some pre/post steps" | Mode 2 (full replacement) — reusable workflows are single-job-call from caller's perspective; you can't insert steps inside the called job |
| "I want to skip a job under some condition" | Mode 1 (`if:` on the caller job) OR Mode 2 (custom skip logic) |

## 4. What you cannot do

- **Cannot insert steps inside the called reusable workflow's job.**
  GitHub's reusable-workflow model is opaque from the caller side —
  you call the whole workflow or you don't. Mode 2 (full
  replacement) is the workaround.
- **Cannot pin `uses: ...@main`** and expect stability. Always pin
  to a release tag (`ci/vX.Y.Z`). See
  [`architecture.md`](architecture.md) §6.
- **Cannot use compound runner labels with colons.** GitHub
  Actions runner labels are alphanumeric + `-` + `_` only. See
  [`../LABELS.md`](../LABELS.md) §2.

## 5. Conflict resolution: local vs shared

When the canonical template ships a change (in a new `ci/vX.Y.Z`
tag) and your override conflicts (e.g., different parameter
default), **your local file still wins** because that's what
GitHub runs. Drift detection flags it as a warning. You then
choose:

- **Re-align with canonical** — update your override to match the
  new default (or remove the override if the new default works
  for you).
- **Intentionally keep the divergence** — add a comment in your
  workflow file explaining why; drift detection still warns but
  the reason is documented for future contributors.
- **Upstream the change** — if your override would be useful for
  every consumer, open a PR on `vladm3105/aidoc-flow-ci` to make
  it the new canonical default, then drop your local override.

## 6. Examples in the wild

These rows are **illustrative of each mode**, not a live status board —
for the actual current per-repo adoption, see
[`WORKFLOWS.md`](WORKFLOWS.md) §2 (applicability matrix) + §5 (current pins).

| Repo | Mode illustrated | Why |
|---|---|---|
| `aidoc-flow-operations` | Mode 2 (full replacement) for `ai-review` + `composition` | Operations is the reference repo for these workflows — its local files are the historical canonical source |
| `aidoc-flow-framework` | Mode 1 for `ai-review` | PUBLIC consumer; pins `runner_labels: '"ubuntu-latest"'` (the default) |
| `aidoc-flow-business` | Mode 1 for `ai-review` + Mode 3 for a custom `plan-gate.yml` | PRIVATE consumer; overrides `runner_labels` to the self-hosted `ci-runner` / `single-use` array; adds a custom plan-gate check |
