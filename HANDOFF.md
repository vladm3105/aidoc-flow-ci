# HANDOFF — aidoc-flow-ci

Briefing for a fresh session with zero context. Two questions, in order: what the
last session did, and what to do next. **Regenerated wholesale at every wrap per
CI-0028** — nothing here is history, and every volatile claim carries the command
that re-derives it. Durable facts live in `CLAUDE.md` § "Durable traps"; the
decision record is `DECISIONS.md`, which is authoritative — this file never
summarises it.

**Scope: `aidoc-flow-ci` ONLY** (founder, 2026-08-16). Do not edit, adopt into,
or file on sibling repos this session. Sibling checkouts may be read as evidence.

**State:** **`ci/v3.0.0` is RELEASED** (2026-08-12) and published as Latest. The
deployable artifact is the **tag**, at `6d68b26` — canon ships by tag, so that is
the identifier that survives; `main`'s tip moves and is not it. At this wrap
`main` is **13 commits above the tag**, tree clean, **46** open issues, **0** open
PRs. **None of the thirteen reaches a consumer on `ci/v3.0.0`.** Re-derive with
`git log --oneline ci/v3.0.0..origin/main`.

| Claim | Command | Value at wrap |
|---|---|---|
| Released version | `git describe --tags --abbrev=0` | `ci/v3.0.0` |
| Tag points at | `git ls-remote --tags origin 'refs/tags/ci/v3.0.0^{}'` | `6d68b26` |
| Release is Latest | `gh api repos/vladm3105/aidoc-flow-ci/releases/latest --jq .tag_name` — **not** `--json isLatest`, which is not a field | `ci/v3.0.0` |
| Suite | `bash tests/run.sh \| sed 's/\x1b\[[0-9;]*m//g' \| grep -oE '[0-9]+ passed, [0-9]+ failed' \| awk '{p+=$1;f+=$3} END{print NR" suites, "p" passed, "f" failed"}'` | **19 suites, 1707 passed, 0 failed** |
| pre-commit | `pre-commit run --all-files` | exit 0 |
| Governance table | `python3 install/parse-governance-table.py CLAUDE.md --repo-root .` | PASS |
| markdownlint | `git ls-files '*.md' \| xargs npx markdownlint-cli2` — use `git ls-files`, **never** a `**/*.md` glob, which reaches the gitignored bootstrap scratch trees | 0 errors |
| Ledger gate baseline | `bash scripts/pre_push_check_ci.sh --ledger-only` | **79 failing rows, 14 of 15 gated plans** |
| Open issues | `gh issue list --state open --limit 200 --json number --jq 'length'` | **46** |
| Open PRs | `gh pr list --state open --json number --jq 'length'` | **0** |
| Stale in-progress markers | `gh issue view <N> --json labels` — **not** `gh issue list --label`, which reads a lagging search index and reported a label seconds after it had been removed | **0** |

**`pre_push_check.sh` on `main` exits 1, and since #482 that is CORRECT and no
longer misleading.** The range is empty (`@{upstream}` IS `HEAD`), so it prints
`NOTHING VERIFIED — the push range is EMPTY`. It no longer claims an OPS-0069
violation and no longer silently skips the linters behind a claim of having run.
**An OPS-0069 failure on a branch whose range is non-empty is a real one, not
this.**

## What this session did

**Merged [#482](https://github.com/vladm3105/aidoc-flow-ci/pull/482) at
`cbe719b`, closing [#477](https://github.com/vladm3105/aidoc-flow-ci/issues/477).**
Canon and the shipped template had diverged on `BASE=`; the template carried the
pre-PLAN-015-M3 form, so any consumer adopting a tag installed a hook that
re-lints every pre-existing branch commit on every push. The copies are now
byte-for-byte identical, asserted with `cmp` by the new suite
`tests/test_pre_push_range.sh`, which executes **both** copies in scratch repos.
The `sed`-scoped hunk comparison in `test_sigpipe_guard.sh` that let the
divergence age is retired.

**The scope was deliberately CUT mid-session — read this before
re-attempting #432.** Its fix was to make an empty push range exit 0. It was implemented and
withdrawn: two review cycles each **measured** an unreviewed commit reaching a
remote through it — once via `git push origin feat` from an up-to-date `main`,
once via multi-ref `git push origin a b`. What shipped is the message half only,
with the exit status left non-zero so no fail-open is reachable. Reasoning and
the four things a real fix needs are on
[#432](https://github.com/vladm3105/aidoc-flow-ci/issues/432), which stays open
and **keeps its `status:in-progress` marker** — advanced, not closed.

**Filed [#481](https://github.com/vladm3105/aidoc-flow-ci/issues/481)**, which
became the next task. Corrected a false claim on #455 by comment.

## What to do next

**ONE change: "finish #438" — take
[#481](https://github.com/vladm3105/aidoc-flow-ci/issues/481) and
[#455](https://github.com/vladm3105/aidoc-flow-ci/issues/455) together**
(founder, 2026-08-16). They are two halves of one unfinished decision, and
doing #455 alone is a coin-flip on whether its prose survives.

**The situation.** #438 decided that `quick-gates.yml` is the bootstrap tier's
required-context producer, and flipped the `auto_install` flags to match
(`quick-gates` → `true`, `pre-commit` → `false`). **PLAN-026 §C0 — the tier-template
edit those flags were unblocking — never ran.** So all four
`branch-protection-*.json` templates still require `call / Lint / format /
security hooks`, produced only by `pre-commit.yml`, which bootstrap no longer
installs; and no tier requires the bare `quick-gates` context that bootstrap
does install. #481 is that missing edit. #455 is the three doc sites that still
describe the pre-#438 world — `manifest.json`'s `_note` (which contradicts the
`auto_install` key on the very next line), `REPO_STANDARDS` §16, and
`docs/WORKFLOWS.md:275`, which #455 does not mention.

**#455 has NO unconditional content** — every one of its three sites asserts
"pre-commit is the bootstrapped producer", so which way each is rewritten
depends entirely on #481. If #438's direction is reverted instead, #455 closes
with zero edits.

**Read #481's fleet-measurement comment BEFORE editing any template.** Measured
2026-08-16: all nine workspace repos have `pre-commit.yml` installed, **none has
`quick-gates.yml`**, none is pinned at `ci/v3.0.0`. So landing §C0 arms a
required context that **every** repo lacks a producer for, the moment anyone runs
`apply-standards.sh --apply` — `apply-standards.sh:706` PUTs the tier file as one
whole payload. The sequencing question is real and is not a doc question:
**§C0 probably should not land until the fleet has `quick-gates.yml` installed**,
which is PLAN-026 C1–C5, a rollout this session's scope excludes.

**Open first, before touching templates:** whether `apply-standards.sh --apply`
is run on any cadence or only by hand. Nothing in `.github/workflows/` invokes it
(that gap is #355), so a manual-only trigger is **presumed, not verified** — and
it decides whether the hazard is latent or imminent.

Everything else is the backlog; do not restate it here:

```sh
gh issue list --state open --limit 200      # the --limit 30 default truncates silently
```

Next after that, unchanged and all **inherited, not re-verified this session**:
[#478](https://github.com/vladm3105/aidoc-flow-ci/issues/478) (marker bump breaks
`PLAN-023:1200`'s pinned symbol — read its ledger-impact section first), the
79-row ledger backlog (`bash scripts/pre_push_check_ci.sh --ledger-only`; re-pin
LAST, after code freeze, #393), and Wave 0 self-adoption (canon runs the **v2**
architecture at a v3 pin — `ls .github/workflows/ | grep -E 'quick-gates|scanners'`
is empty).

## Blockers

| Blocker | Why | What would clear it |
| --- | --- | --- |
| **§C0 cannot land safely while the fleet has no `quick-gates.yml`** | Arms a required context with no installed producer on every repo; consumer tiers have no `--admin` escape | PLAN-026 C1–C5 (a rollout, out of this session's scope), or a decision to revert #438's direction. Evidence on [#481](https://github.com/vladm3105/aidoc-flow-ci/issues/481) |
| **Runner image is stale on every host but this one** | Until each rebuilds, `scanners` is red on arrival there | [#458](https://github.com/vladm3105/aidoc-flow-ci/issues/458); the `gh`-pin half is [#435](https://github.com/vladm3105/aidoc-flow-ci/issues/435). **Inherited, not re-verified this session** |
| **PLAN-025 P7 must not run** | Still the only irreversible phase; P9 (rollback) must exist first. **P4** and **P5** are also not started | P9 landing. `docs/MIGRATION_v3.0.0.md` is the migration path, not the P5 documentation set. **Inherited** |
| **The ledger gate cannot become a CI job** | `check_plan.py` ships with the verified-planning Claude skill, not this repo; the ephemeral runners have no `~/.claude` | Vendoring it — a separate decision with its own drift surface. Until then the pre-push hook is the only reader that can exist |

## What did NOT change

No consumer repo, no branch protection, no ruleset, no required context, no
workflow, no template. `.github/workflows/*` and `install/templates/*` untouched
since #482. No `doc-maintainer` / `docs-sync` / `ai-review` / `secret-scan`
behaviour. No plan file was edited, so the 79-row ledger baseline is unchanged
and no failing row cites a file this session touched.

`doc-maintainer` live on `operations` and paused on `framework` — **inherited
from an earlier wrap, not re-verified this session.** Re-derive with
`.github/doc-maintainer.json` in each.

Lessons went to auto-memory, which is **gitignored and machine-local**
(`~/.claude/.gitignore:5`) — safe on this host only, not backed up. Read them
there; they are not restated here.
