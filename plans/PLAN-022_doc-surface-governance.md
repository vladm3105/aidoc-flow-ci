# PLAN-022 — doc-surface governance: three surfaces, three edit shapes

**Status:** **NOT READY — review cap reached (OPS-0066).** Three independent passes returned 12, 9 and 7 load-bearing findings; the trend did not converge. **§3.0 is a 🔴 blocker: the entry-routing rule is not decidable from the data**, and §3.1's partition was derived under it. One founder decision (§3.0) unblocks the rest. **Do not file any issue and do not delete the TODO file while this reads NOT READY.**
**Scope:** Retire `plans/FRAMEWORK-TODO.md`; correct the governance table it
contradicts; specify the per-surface edit-mode taxonomy that PLAN-021's
`apply.py` work inherits.
**Semver:** **none for Phase 1** (no canon body, no manifest surface changes).
Phase 2 is MINOR when it lands.
**Decision record:** `CI-0028` (new)

> ⚠️ **The citation gate reports `ok` on this plan and that green is FALSE.**
> `check_plan.py`'s readiness regex includes `(?:result|status):\s*\**\s*ready`
> and matches **anywhere in the final Pass entry** — including a quotation of
> *another* plan's status. Pass 4 below quotes ``PLAN-007`` as `Status: ready`,
> and that alone flips the gate green on a plan whose own header says NOT READY.
> Trust the **Status** line at the top of this file, never the gate's exit code.
> Upstream defect in the global `verified-planning` skill
> (`~/.claude/skills/verified-planning/check_plan.py`, the `ZERO_FINDINGS_RE`
> block) — 🟡, needs a human to file it against the config repo, which is not one
> of the ten workspace repos the OPS-0076 carve-out covers.
>
> **Gate invocation** (root order is load-bearing; see the ledger's closing note):
>
> ```sh
> python3 ~/.claude/skills/verified-planning/check_plan.py \
>   plans/PLAN-022_doc-surface-governance.md \
>   --root /opt/data/aidoc-flow/operations \
>   --root /home/ya/.claude
> ```

---

## 1. Three surfaces, three edit shapes

The governing insight is that these are **opposite artifacts**, and treating them
alike is what produces both of the failures below.

| Surface | Lifespan | Correct edit | Never |
|---|---|---|---|
| **CHANGELOG** | permanent, grows monotonically | **anchored insert** under the Unreleased heading | regenerate · reorder · prune · prepend to the file |
| **HANDOFF** | ephemeral, rewritten each wrap | **full regeneration** | append · accrete "previous state" sections |
| **TODO** | — | **retired** — the repo's open GitHub issues are the backlog | — |

**The changelog is the permanent record of what happened; the handoff is a
disposable briefing about now.** A correction to a changelog entry is a *new
dated entry saying so*, never an edit to the old one. A handoff that needs
skimming has already failed.

### 1.1 "Add at the beginning" means under the anchor, not at the top of the file

This is the precision that decides whether an implementation works. A new entry
goes **beneath the `## [Unreleased]` heading**, below the H1 and the preamble. A
naive file-prepend puts entries above the title. So the primitive is
**anchored insert**, never *prepend*.

**Measured across the workspace (2026-07-30)** —
`grep -m1 -nE '^## *(\[Unreleased\]|Unreleased)' <repo>/CHANGELOG.md`:

| Anchor | Repos |
|---|---|
| `## [Unreleased]` | framework, operations, iplanic, engramory, iplan-runner, iplan-standard, interlog (7) |
| `## Unreleased` | **`aidoc-flow-ci` itself** — the outlier, and it is canon |
| *(no changelog)* | `business` — declined by its own governance table, deliberately |

**Consequences for Phase 2:** the anchor must be **configurable**, defaulting to
`## [Unreleased]`; a repo that declares no changelog must be a supported state,
not an error; and **canon should normalise its own heading to the bracketed
form** rather than shipping a tool whose default its own repo violates.

### 1.2 The handoff rule that is missing: volatile claims carry their command

Regeneration alone is not enough, and this repo proves it. `HANDOFF.md` is
**1,393 lines** carrying a "Previous state (2026-07-25)" block and PLAN-018/019
history — against the ~200-line target. But length is the *symptom*.

**The defect is that a carried-forward claim reads as freshly verified.** This
session, the handoff's headline stated *"0 open issues, 0 open PRs"*; there were
**eight** open issues, and the claim had been stale for three days. Nothing in the
file marked it as a claim rather than a fact.

**Rule:** every volatile claim in a handoff carries the command that re-derives
it. `0 open issues` is unfalsifiable prose;
`` 0 open issues (`gh issue list --state all --limit 200 | wc -l`) `` is checkable
in one paste. That converts a stale handoff from *misleading* to *obviously
stale* — which is the whole difference.

---

## 2. Feedback is a direction of travel, not a class of issue

**A repo's open issues are its TODO — regardless of who filed them.** Filing on
another repo is the *act* of giving feedback; it does not create a distinct
species of issue on the receiving side.

This was settled after an explicit wrong turn: an earlier draft of this work
proposed labelling inbound issues as a separate category. That is wrong, because
**provenance does not change what the owner does.** ci#352 (filed by a framework
session) and a ci-found bug both mean "ci must fix this" — same triage, same
queue, same close-on-merge. A classifier that drives no action is precisely the
second surface this plan exists to delete.

Three places where direction genuinely has teeth — none needing a classifier:

1. **The promotion bar and the five-part body attach to the outbound act.**
   Filing on someone else's repo spends their attention, so it must clear the bar
   (the test is *ownership, not severity*) and carry reproduction at `file:line`,
   blast radius, why it was hard to diagnose, a suggested fix, and what is *not*
   broken. Filing on your own tracker is your own queue — lower bar.
2. **The close permission stays asymmetric.** The owning repo closes its own
   issue when the fix merges; a reporter never closes another repo's. That is a
   permission rule under OPS-0076, not a taxonomy.
3. **`source:` survives as provenance, not classification** — its job is "who do
   I go back to for more evidence", never a sort key.

**Consequence — this removes a blocker.** No new label family is needed, so
**provisioning the `type:*` / `tier:*` / `source:*` taxonomy is not a
prerequisite** for retiring the TODO. Measured 2026-07-30: those families are
**absent on all four target repos** (`gh label list -R <repo> | grep -E
'^(type|tier|source):'` → framework has one stray `type:infra`; ci, operations
and iplanic have none). Under the earlier draft's model that absence blocked the
migration. Under this one it is an indexing gap to close later.

**It does NOT dissolve the queue-only category — and an earlier draft of this
plan claimed it did.** The contract addresses this repo by name: *"On
`aidoc-flow-ci`, capture and publish coincide because its declared backlog is
GitHub issues. That does **not** mean file everything: the promotion bar still
decides. A finding that fails the bar stays in the worked `plans/` entry, not in
the tracker."* So below-bar items resolve to **the plan being worked**, not to a
low-priority issue. The contract governs where an operational surface disagrees
with it, and this plan defers.

**That correction removes four entries from the filing set** — FT-54, FT-55 and
FT-56 are the declared scope of `PLAN-020` (which names "Closes: FT-55, FT-56"),
and FT-37's own text says its fix is "none in canon — the existing PLAN-009
Phase 0 pool registration, already 🔴-gated on the founder". All four are
*already-planned*, which the bar excludes by name. They move to their plans.

---

## 3. Migration — 57 entries triaged

`plans/FRAMEWORK-TODO.md` holds **57 `FT-NN` entries in 1,896 lines**. Each was
cross-referenced against `CHANGELOG.md` and `HANDOFF.md`, then the ambiguous ones
were read in full.

### 3.0 🔴 BLOCKER — the routing rule is not decidable from the data

An earlier revision declared this "SETTLED": *an entry stays in a plan only if
that plan is `READY` or `EXECUTING`.* Three review passes each found one more
plan that rule had not been applied to, so on the third I stopped hand-picking
and **swept every file in `plans/`**. The sweep falsifies the rule:

```sh
for f in plans/*.md; do
  fts=$(grep -oE '\bFT-[0-9]+\b' "$f" | sort -u -V | tr '\n' ' ')
  [ -z "$fts" ] && continue
  st=$(grep -m1 -iE '^\*\*Status:?\*\*|^> Status:' "$f")
  printf '%-46s %-40s %s\n' "$(basename $f .md)" "${st:-<none>}" "$fts"
done
```

**17 files mention `FT-NN`.** Two problems, either of which alone sinks the rule:

1. **Mention ≠ ownership, and no mechanical test separates them.** `PLAN-018`
   mentions **27** FTs and `PLAN-019` mentions **24** — they are the plans that
   pulled entries into workstreams, so most mentions are history. But `PLAN-019`
   is `READY` and mentions FT-33, FT-35 and FT-37, all of which this plan routes
   to the tracker; `PLAN-007` is `ready` and mentions FT-5, FT-6, FT-11, FT-12.
   Deciding whether each is *owned* or merely *cited* requires reading 17 files
   entry by entry — judgement, not a rule.
2. **The status vocabulary is 8-way and 5 files have no status line at all.**
   Observed: `active` · `ready` · `READY` · `EXECUTING` · `COMPLETE` ·
   `IMPLEMENTED (code)` · `DEFERRED` · `DRAFT — NOT READY` — plus
   `PREPARED, NOT EXECUTED` in the ROLLOUT runbooks and **no status line** in
   five, including three that carry executable "close FT-NN" instructions.
   §3.0's three-value rule has no mapping for most of what `plans/` says.

**Recommended replacement — file every open entry, and let plans reference the
issue.** Drop the below-bar/queue-only routing entirely for this migration:

- It is **decidable**: is the entry open? then it is an issue.
- It matches the model already agreed — *a repo's open issues are its TODO*.
- **It is not duplication**, because the issue becomes the single state-holder
  and a plan that also covers the work links to it. What the contract forbids is
  the tracker becoming *a second copy of the backlog*; here it becomes the
  **only** copy, which is the point of the migration.
- It dissolves five separate findings at once: FT-11/FT-12 (PLAN-007), FT-13
  (`ROLLOUT_plan015-arming`), FT-54/55 (PLAN-020), FT-56's third part, and the
  verbatim-body-vs-residual collision.

**This needs a founder decision** — it reverses the contract's queue-only clause
for this one migration, on the grounds that the clause presumes a queue file that
is being deleted. Until it is answered, **§3.1's partition below is not
executable**: its 15/2/2/3 split was derived under the falsified rule.

### 3.1 The partition

| Disposition | Count | Entries |
|---|---:|---|
| **Resolved → drop** (git is the archive) | **35** | — |
| **Open, ci-owned → file here** | **15** | FT-4, 5, 6, 11, 16, 17, 19, 20, 24, 31, 33, 35, 54, 55, 57 |
| **Stays in an EXECUTING plan** (PLAN-009) | **2** | FT-18, FT-37 |
| **Absorbed — no new issue** | **2** | FT-23 → comment on #352 · FT-56 → 56a into FT-5's issue, 56b as a comment on #351 |
| **Open, cross-repo** | **3** | FT-12, FT-13, FT-38 → **11 issues** (§3.2) |

35 + 15 + 2 + 2 + 3 = **57**, each entry exactly once.

**Four entries were rescued from the drop bucket across three review passes** —
each states an open residual inside an entry whose header reads closed:

| FT | Header says | Residual |
|---|---|---|
| 57 | fix landed | *"the `--update` refusal is OPEN"* — a pending **founder decision** on the destructive `--update` path FT-9 once bricked the fleet with |
| 18 | validator shipped | remaining scope *"stays open and 🔴 founder-manual"* → PLAN-009 |
| 31 | `Status: CLOSED` | runs **operator-side only**; *"a consumer's own hook-less config can still produce a vacuous pass"* on a **required** check. *"**Needs:** a real signal"* |
| 11 | — | the `markdown-lint` half is **DONE across all canon consumers**; only 🔴 founder `docs-sync` App provisioning remains, so filing it as written would re-file completed work |

**The argument for retiring the file, stated correctly.** The per-entry markers
are mostly good — eight carry an explicit `Status: CLOSED`. What is stale is the
single `## Open` heading all 57 sit under. The genuinely unreliable direction is
**partial** resolution: a file needs a second manual write to close an entry and
has no way to say "closed except for this", so a landed fix and an open residual
share one header. Three entries are also stale in the *opposite* direction —
marked open, actually closed (FT-15, FT-30, FT-27's residual). An issue closes on
the merge that fixes it, and a residual is a separate issue.

### 3.2 Cross-repo — one issue per (repo, defect), 11 in total

Measured, not transcribed. `iplan-runner`'s slug is **`vladm3105/iplan-runner`**,
not `aidoc-flow-*`.

| Defect | Repos | Issues |
|---|---|---:|
| **FT-12a** phantom required-context (a required check armed with no producer) | framework · business · iplanic | 3 |
| **FT-12b** `call / composition` armed but not emitting | interlog | 1 |
| **FT-13a** **no `standards-drift.yml` caller at all** — no drift and no pin-currency signal from any source | business · interlog | 2 |
| **FT-13b** caller pins an unresolvable annotated tag | iplanic | 1 |
| **FT-38** `pre-commit-hooks` pinned at a mutable `rev:` the refresh cannot move | framework · iplanic · iplan-runner · operations | 4 |

*FT-12's iplan-runner sub-item is already **RESOLVED** (iplan-runner #88) and is
not filed.*

**Tier: 🔴.** FT-38 spans four repos and *cross-repo coordination* is an explicit
🔴 trigger; escalation is fail-safe. FT-12/FT-13 touch branch protection and a
required gate. All interrupt the founder in-session by contract.

**FT-13's own routing line and OPS-0076 do not conflict.** The entry says
consumer-side callers *"go through the ops/inbox runbook, never a direct edit
from a canon session"* — it forbids **editing** another repo. OPS-0076 permits
**filing an issue**, which is not an edit. Filing is in scope; fixing is not.

**Re-measure before writing any body.** FT-13 carries its own warning that it
*"has now been wrong three times; do not add a fourth without measuring."*

### 3.2a Two entries that are absorbed, not filed

- **FT-23 is founder-descoped** (2026-07-22: the AI self-callers are *"descoped,
  not deferred"*; what remained — FT-36, FT-34, the inventory — is closed).
  Filing it would reopen a closed scope decision. Its value is as PLAN-021 #352's
  root cause → **a comment on #352**.
- **FT-56 splits, and neither half is a new issue.** **56a** (the drift job grants
  only `contents: read`, `administration` is not a grantable `GITHUB_TOKEN` scope,
  so the branch-protection and actions-permissions reads 403 into
  `warn_uncheckable`) **cites FT-5 as its own mechanism — it *is* FT-5**, so it
  goes into FT-5's issue body as the "why instances 1 and 2 went unnoticed"
  evidence, not a duplicate issue. **56b** (the signal is emitted and never read)
  is #351's §1 — **a comment on #351**, whose body I read to confirm: its five
  sections are all about the verdict's reachability, and **none** covers 56a's
  permissions defect.

### 3.3 Filing discipline

`--body-file -`, never `--body -` (which publishes a literal `-`, exits 0, and
prints a URL). Read every artifact back; a non-zero length is the only proof it
published. **Do not trust a single empty read-back** — a comment read-back can
report 0 for a comment that published in full, and the symptom is identical to
the `--body -` bug, so the natural reaction is to re-post and duplicate.

---

## 4. Governance corrections

**`CLAUDE.md`'s governance table is currently false.** Its TODO row reads
*"Not adopted — `plans/` per-initiative plans + GitHub issues serve as the
backlog; no separate TODO.md needed for a small canon repo"* — while a
1,896-line TODO file sits in `plans/`. The declared model was right; the repo
did not follow it.

The row is corrected to state the model **and** the trap that comes with it:

> | TODO / backlog | **`plans/` per-initiative plans + GitHub issues** — capture and publish coincide here; no TODO file. This repo's open issues **are** its backlog regardless of who filed them (an inbound cross-repo report becomes an ordinary task here). **That does not mean file everything** — a finding that fails the promotion bar stays in the worked `plans/` entry, not in the tracker; sequencing lives in `plans/` too. Read the tracker with `--state all --limit 200`: `gh issue list` defaults to `--limit 30` and silently truncates. |

The row deliberately keeps **both halves** of the contract's declaration. An
earlier draft led with "GitHub issues" alone and demoted `plans/` to sequencing —
which drops `plans/` as half the *capture* surface and drops the below-bar
disposition entirely, so a session would read it as "everything becomes an
issue".

The `submit-feedback` skill's own scope table already declares this repo's
capture surface as *"`plans/` per-initiative + GitHub issues — capture and
publish coincide"*, so the correction brings the repo into line with a contract
that already described it.

**`DECISIONS.md` CI-0028** records: the three-surface taxonomy, feedback-as-
direction, the retirement, and the anchor decision for canon's own changelog.

---

## 5. The edit-mode taxonomy — the contract PLAN-021 inherits

`apply.py` has exactly one edit mode: it demands *"Return the COMPLETE
replacement file"*, and refuses any source over 200 KB. §1 shows that is the
wrong shape for two of the three surfaces.

| Surface | Mode | Guard that replaces the heuristics |
|---|---|---|
| CHANGELOG | anchored insert | **assert the diff is a pure insertion** — mechanically checkable |
| HANDOFF | whole-file regeneration | stays high-risk / human-reviewed: whole-file is *correct* here, and it is the highest-judgment document |
| README / docs / ROADMAP | targeted edit | unchanged |

**Stronger in one direction and WEAKER in the other — state both.** `apply.py`
computes `changed = sum(max(i2 - i1, j2 - j1) ...)`, and for an `insert` opcode
`i2-i1` is 0 while `j2-j1` is the inserted-line count — so **the 400-line ceiling
already bounds insertions**, not only deletions. "The diff is a pure insertion"
bounds deletions only; a 5,000-line runaway or an injected append satisfies it.
**Keep a volume ceiling alongside the insertion invariant.**

**Two further constraints Phase 2 must not conflate:**

- **The mode change and the guard change are separate.** Removing the 200 KB
  refusal is justified by "nothing reads the whole file" — but that only holds if
  Phase 2 also changes what is **sent to the model**. As written, `apply.py`
  prompts for a complete replacement file and writes `<path>.proposed`; a
  pure-insertion assert over a whole-file regeneration is satisfiable only if the
  model reproduces every other byte exactly, which is *harder* on long files.
  Specify the prompt/IO change, not just the guard.
- **Legitimate heading-touching changelog edits exist**, so "pure insertion"
  cannot be unconditional: `release.sh prep` promotes `## Unreleased` →
  `## ci/vX.Y.Z` at every release, and §1.1's own recommendation to normalise
  canon's heading is itself a non-insertion edit. Scope the invariant to the
  *maintainer* path, not to all changelog writes.

**Sequencing: Phase 2 lands after PLAN-021.** Both touch `apply.py`, PLAN-021 is
in flight, and PLAN-021's §7 currently parks *"section-scoped edits for
append-only docs"* as indefinitely out of scope — a line this plan supersedes.
Update it when Phase 2 opens, not before; two plans claiming the same scope is
its own defect.

**Phase 2 also retires a cost this plan otherwise imposes.** PLAN-021's PR-C
demotes `CHANGELOG.md` to high-risk on `operations`, retiring changelog
auto-maintenance there. With the anchored-insert mode that demotion becomes a
**bridge, not a retirement** — which is what makes it acceptable.

---

## 6. Out of scope

- **Retiring framework's `plans/FRAMEWORK-TODO.md`** (1,874 lines). It is
  governed by that repo's `GOV-TODO-ISSUE-SPLIT` rule, which mandates *both* a
  TODO entry and an issue — so retiring it is a governance supersession in
  another repo, not a file deletion. Do it as its own change, after this one
  proves out.
- `engramory/TODO.md` (458 L) and `iplan-runner/TODO.md` (189 L) — same reasoning,
  lower stakes.
- **Regenerating this repo's 1,393-line HANDOFF.** §1.2 specifies the rule; the
  rewrite is a separate act and should happen at the next merge-wrap, not here.
- Provisioning the label taxonomy (founder-run; no longer a prerequisite — §2).
- The 30 %-deletion guard's blast radius — tracked from PLAN-021 §7.

---

## 7. Execution sequence

### 7.1 What gets written where

**26 creates + 2 comments** — 15 ci issues, 11 cross-repo issues (§3.2), and
comments on #352 (FT-23) and #351 (FT-56b).

**Each issue body reproduces its entry verbatim**, not a five-part summary. The
entries carry analysis that summarising destroys — FT-54's three options and its
dated CORRECTION, FT-13's three-corrections caution, FT-24's named Dependabot PR
list. **Any `plans/FRAMEWORK-TODO.md:NNN` citation inside a body is pinned to the
pre-deletion blob SHA**, or every filed issue cites a path that will not exist on
`main` the next day.

**Two entries need re-measuring before a body is written**, because both assert
live fleet state that has moved before: **FT-13** (its own warning) and **FT-24**
(a 2026-07-21 triage naming six specific Dependabot PRs as open).

### 7.2 Deleting the file is not a one-file change

`FRAMEWORK-TODO` has **49 external references across 18 files** (excluding this
plan and the file itself). They split three ways:

| Class | Files | Treatment |
|---|---|---|
| **`CHANGELOG.md`** | 1 | **Do not touch.** These are historical entries, and §1 of this plan says a changelog is never rewritten. A reference to a file that existed when the entry was written is *correct history*. Editing them would violate the rule this plan exists to establish. |
| **Live, executable** | `.github/workflows/standards-drift-self.yml` (a comment telling the reader to go read the file) · **`PLAN-020`** (DEFERRED but live, whose **Phase 1 tasks instruct a session to file entries *into* this file**) · `docs/FLEET_BRANCH_PROTECTION_ARMING.md` (an **instruction to write into** it) · `docs/WORKFLOWS.md` · `docs/BRANCH_PROTECTION.md` · `HANDOFF.md` (7 pointers) | Must be updated — a live instruction to write into a deleted file is the same defect class as the workflow comment |
| **Merged plans' claim ledgers** | PLAN-003, 005, 007, 008, 010, 015, 017, 018, 019, ROLLOUT ×2 | **Leave.** They are history, no automated gate reads them (this repo does not wire `check_plan.py` into pre-commit, and none is a markdown link so the link checker stays green). **Several are already stale** — PLAN-020's ledger cites `:869` for FT-5, now at `:987` — so the gate fails on them *today*; say so, or the deletion gets blamed for a pre-existing condition. |

### 7.3 The PRs

The OPS-0061 ≤3-doc-surface cap forces three:

1. **File the issues** (no repo change) — §7.1.
2. **PR-1** — delete `plans/FRAMEWORK-TODO.md`; correct the `CLAUDE.md`
   governance row; `DECISIONS.md` CI-0028. **Exactly 3 surfaces, zero headroom.**
   This repo's own precedent counts a CHANGELOG entry both ways; **this plan
   settles it as a 4th surface**, so the changelog entry rides PR-2 rather than
   silently busting the cap.
3. **PR-2** — the live inbound references + the CHANGELOG entry. That is 6
   surfaces, so **PR-2 itself splits**: (a) `standards-drift-self.yml` +
   `PLAN-020`'s Phase 1 tasks + CHANGELOG; (b) the three adopter docs; (c) the
   HANDOFF pointers, which the handoff regeneration absorbs (§6).

**Ordering and what reverts.** File first, so the entries are durable before the
file goes. If PR-1 stalls after filing, the repo holds 26 new issues **and** the
1,896-line file — exactly the two-surface drift this plan removes. **Revert =
close the new issues with a pointer to the file, or land PR-1.** Do not leave it
half-done across a session boundary.

**Phase 2** — the anchored-insert mode, after PLAN-021 lands.

---

## Claim ledger

| # | Claim | Symbol | Citation |
| --- | --- | --- | --- |
| 1 | The governance table declares TODO not adopted — while the file exists | `TODO / backlog \| Not adopted` | CLAUDE.md:73 |
| 2 | The TODO file that contradicts it | `# FRAMEWORK-TODO — ` | plans/FRAMEWORK-TODO.md:1 |
| 3 | ...whose entries all sit under one Open heading | `## Open` | plans/FRAMEWORK-TODO.md:9 |
| 4 | Canon's own changelog uses the UNBRACKETED anchor — the fleet outlier | `## Unreleased` | CHANGELOG.md:6 |
| 5 | `apply.py` has exactly one edit mode: whole-file regeneration | `Return the COMPLETE replacement file` | scripts/doc-maintainer/apply.py:66 |
| 6 | ...and refuses any source over 200 KB, which the insert mode makes moot for changelogs | `if len(original.encode()) > 200_000:` | scripts/doc-maintainer/apply.py:59 |
| 7 | PLAN-021 parks section-scoped edits as out of scope — the line this plan supersedes | `section-scoped edits for append-only docs` | plans/PLAN-021_doc-maintainer-dry-run-cluster.md:479 |
| 8 | The promotion bar's test is ownership, not severity | `ownership, not severity` | docs/AGENT_FEEDBACK_INTAKE.md:47 |
| 9 | The bar itself — what must hold before publishing | `Promotion bar` | docs/AGENT_FEEDBACK_INTAKE.md:119 |
| 10 | The five-part body contract that attaches to the outbound act | `Issue body contract` | docs/AGENT_FEEDBACK_INTAKE.md:159 |
| 11 | Close asymmetry — the reporter never closes another repo's issue | `never close another repo's issue` | docs/AGENT_FEEDBACK_INTAKE.md:204 |
| 12 | Label authority is bounded to three families | `Label authority is bounded` | docs/AGENT_FEEDBACK_INTAKE.md:215 |
| 13 | `source` vs `target` vocabulary — provenance vs ownership | `Vocabulary` | docs/AGENT_FEEDBACK_INTAKE.md:229 |
| 14 | What the carve-out permits — three writes, no inbox artifact | `What the autonomy-tier carve-out permits (OPS-0076)` | docs/AGENT_FEEDBACK_INTAKE.md:277 |
| 15 | The decision granting it | `## OPS-0076` | ops/DECISIONS.md:2921 |
| 16 | The skill's scope table already declares ci's surface as GitHub issues | `capture and publish coincide` | skills/submit-feedback/SKILL.md:39 |
| 17 | The contract's below-bar rule for THIS repo — a failing finding stays in the worked plan, not the tracker | `stays in the worked ` | docs/AGENT_FEEDBACK_INTAKE.md:88 |
| 18 | ...and its capture-surface row, which names `plans/` as half the surface | `capture and publish coincide here (TODO file declined)` | docs/AGENT_FEEDBACK_INTAKE.md:73 |
| 19 | FT-54/55/56 are an existing plan's declared scope, so they fail the bar as already-planned | `**Closes:** FT-55, FT-56` | plans/PLAN-020_canon-self-adoption-and-ruleset-canon.md:17 |
| 20 | FT-57's fix landed but its `--update` refusal is OPEN and needs a founder call | `the ` | plans/FRAMEWORK-TODO.md:143 |
| 21 | FT-23 is founder-descoped, not open | `SCOPE DECISION (founder, 2026-07-22):` | plans/FRAMEWORK-TODO.md:1642 |
| 22 | FT-13 carries its own warning against transcribing it unmeasured | `wrong three times` | plans/FRAMEWORK-TODO.md:1351 |
| 23 | The 400-line ceiling already bounds INSERTIONS — so pure-insertion alone is weaker | `max(i2 - i1, j2 - j1)` | scripts/doc-maintainer/apply.py:91 |
| 24 | A live workflow comment points readers at the file this plan deletes | `Tracked as FT-13 in plans/FRAMEWORK-TODO.md` | .github/workflows/standards-drift-self.yml:73 |
| 25 | PLAN-009 is EXECUTING, so it holds FT-18 and FT-37 under §3.0's rule | `Status: EXECUTING` | plans/PLAN-009_fleet-v2-cutover.md:29 |
| 26 | PLAN-010 is not executable, so it releases FT-5 and FT-13 to the tracker | `NOT READY, DO NOT EXECUTE` | plans/PLAN-010_adoption-model.md:8 |
| 27 | PLAN-020 is not executable, so it releases FT-54/55/56 | `DEFERRED to the next release cycle` | plans/PLAN-020_canon-self-adoption-and-ruleset-canon.md:3 |
| 28 | FT-31 is a partial resolution — closed header, open residual on a required check | `**Needs:** a real signal` | plans/FRAMEWORK-TODO.md:723 |
| 29 | FT-11's markdown-lint half is already done fleet-wide, so filing it as written re-files completed work | `DONE across all canon consumers` | plans/FRAMEWORK-TODO.md:1262 |
| 30 | FT-12's iplan-runner sub-item is already resolved and is not filed | `iplan-runner canon adoption — RESOLVED` | plans/FRAMEWORK-TODO.md:1301 |
| 31 | FT-56's 56a cites FT-5 as its own mechanism — so it is not a separate defect | `not a grantable ` | plans/FRAMEWORK-TODO.md:179 |
| 32 | FT-13 forbids cross-repo EDITS, which OPS-0076's filing carve-out does not contradict | `never a direct edit from a canon session` | plans/FRAMEWORK-TODO.md:1389 |

*Cited paths resolve: rows 1-7 against this repo; 8-14 against
`/opt/data/aidoc-flow/operations`; 15 likewise; 16 against `/home/ya/.claude`.*

*Deliberately **not** in the ledger, because the path collides with this repo's
own file and the gate would resolve it to the wrong source — the same hazard
PLAN-021 documented. Verify by absolute path:*

```sh
# the `gh issue list` --limit 30 trap, recorded in framework's durable traps
grep -n 'defaults to .--limit 30' /opt/data/aidoc-flow/framework/CLAUDE.md   # :901
# the workspace changelog/handoff policy this plan restates
grep -n 'append-only' /home/ya/.claude/CLAUDE.md
```

*Measured facts verified by command rather than cited symbol (2026-07-30):
the changelog-anchor survey in §1.1; the label-family absence in §2
(`gh label list -R <repo> --limit 300 --json name --jq '.[].name' | grep -E
'^(type|tier|source):'`); this repo's `HANDOFF.md` at 1,393 lines against 8 open
issues while claiming zero; and the 57-entry triage in §3.*

---

## Review log

### Pass 1 — 2026-07-30 — self (author, during drafting)

1. **The separation this plan was originally asked to build does not exist.** The
   first design labelled inbound issues as a distinct class. Working it through
   showed the classifier drives no action on the receiving side — which would
   have re-created the two-surface drift the plan is deleting. Rewritten as
   §2 (feedback is a direction), which also **removed the label-provisioning
   blocker** the earlier design had introduced.
2. **"Add at the beginning" was ambiguous enough to produce a broken
   implementation.** Pinned to *anchored insert under the Unreleased heading*,
   never file-prepend, and surveyed the anchor across the fleet — which found
   canon itself is the one repo using the unbracketed form, and `business`
   deliberately has no changelog at all. Both are now Phase-2 requirements.
3. **Handoff regeneration alone would not have fixed the handoff.** Added §1.2:
   the failure is a stale claim reading as verified, not length. Evidence is
   this session's own misread.
4. **Scope creep caught.** An early outline retired framework's TODO in the same
   plan. That is a governance supersession in another repo (`GOV-TODO-ISSUE-SPLIT`
   mandates both surfaces) — moved to §6 out of scope.
5. **Two entries would have been mis-filed.** FT-56 duplicates open issue #351
   (comment, not create, per search-first) and FT-23 is PLAN-021's root cause and
   needs cross-linking.

**Result:** folded; not yet independently reviewed.

### Pass 2 — 2026-07-30 — independent (`verified-planning-reviewer`, fresh context)

**Twelve load-bearing findings.** Four were verified by direct read before
folding; each of the first three would have caused real damage.

1. **§2 contradicted the governing contract on the point that decides what gets
   filed.** `AGENT_FEEDBACK_INTAKE.md:86-89` addresses this repo **by name**: on
   `aidoc-flow-ci` capture and publish coincide, *"That does not mean file
   everything… A finding that fails the bar stays in the worked `plans/` entry,
   not in the tracker."* My §2 claimed the queue-only category dissolves. It does
   not — it resolves to the worked plan. **Removes FT-54, 55, 56 (PLAN-020 scope)
   and FT-37 (PLAN-009 Phase 0) from the filing set.**
2. **Three "cross-repo" entries are ci-owned.** FT-16, FT-19 and FT-20 name fix
   surfaces that are all files in *this* repo (`install/templates/runner/*`,
   `docs/runners.md`); only the incident was on operations' host. Would have
   misfiled three issues, **two of them 🔴 with a founder interrupt**, while
   deleting the ci-owned record in the same wave.
3. **FT-57 and FT-18 were bucketed "resolved" and would have been deleted.** Both
   state an open residual in their own text; FT-57's is a pending **founder
   decision** on the destructive `--update` path.
4. **FT-23 is founder-descoped, not open** — filing it reopens a closed 2026-07-22
   scope decision. Becomes a comment on #352 instead.
5. **§3's argument was backwards.** The per-entry markers are mostly good
   (`Status: CLOSED` on eight of them); what is stale is the single `## Open`
   heading. The genuinely unreliable direction is *partial* resolution — which is
   exactly what finding 3 caught me missing.
6. **FT-56 is two defects** (56a permissions blindness, 56b unconsumed signal);
   only 56b matches #351, so a single comment would bury 56a.
7. **FT-13 is three findings, two of them not iplanic's** — `business` and
   `interlog` carry no `standards-drift.yml` at all.
8. **§5's "pure insertion" is weaker, not stronger, in the addition direction** —
   `apply.py:91` uses `max(i2-i1, j2-j1)`, so the 400-line ceiling already bounds
   insertions. Also flagged the mode-vs-guard conflation and the legitimate
   heading-touching edits (`release.sh prep` promotes the Unreleased heading).
9. **§5 vs PLAN-021 §7** — PLAN-021 says *file* the 30 %-deletion blast-radius
   item separately and this is the plan that converts backlog to issues, so
   nothing files it. Folded into §6.
10. **Deleting the file strands 55 references across 20 files**, including a live
    workflow comment and — the one I had missed entirely — **`PLAN-020`, whose
    Phase 1 tasks instruct a session to file entries *into* this file.** PR-1
    therefore exceeds the ≤3-surface cap and splits into PR-1 + PR-2.
11. **Durability is a property of the issue bodies, not the ordering.** Bodies
    must reproduce entries verbatim and pin any `path:NNN` citation to the
    pre-deletion blob SHA. Also: 18 creates + 2 comments, not "19 issues", and
    **FT-38 is four issues** — one per repo that owns a `rev:` line.
12. **§4's replacement row narrowed the contract** it claimed to align with,
    dropping `plans/` as half the capture surface and the below-bar disposition.

Minors folded: `iplan-runner`'s slug is `vladm3105/iplan-runner`; FT-38 and
FT-37 are 🔴 not 🟡; FT-11 is half-stale (the `markdown-lint` graduation is
already DONE across canon consumers, only arming remains, which is FT-12);
§1.1's survey covers 9 of the ten repos — `feedback-desk` has no changelog and
was not counted.

**Result:** all twelve folded; ledger grew 16 → 24 rows; the filing set fell from
19 issues to 18 creates + 2 comments with four entries rerouted to their plans.
Not yet re-reviewed.

### Pass 3 — 2026-07-30 — independent (`verified-planning-reviewer`, fresh context) — **verdict: NOT READY**

Nine load-bearing findings. **The first is a fold error of mine**, and it is the
one that would have done the damage:

1. **§3.1's table was never folded.** Pass 2's finding that FT-16/19/20 are
   ci-owned was applied to §3's prose and *not* to the table an executor files
   from — so the corrected defect survived in the only place it could act. Table
   rewritten, and marked NOT SETTLED.
2. **FT-54's pending founder decision had no destination.** PLAN-020 declines to
   decide it by name; its options and CORRECTION live only in the file being
   deleted. Added to §3.4.
3. **No PR performed the "moves to its plan" step** for any below-bar entry.
   PR-2's scope now includes it.
4. **The already-planned exclusion was applied arbitrarily** — FT-5 and FT-13 are
   equally declared in PLAN-010 (itself DRAFT/NOT-READY, the same state as
   PLAN-020). Now a stated founder call in §3.4.
5. **56a *is* FT-5**, so filing both duplicates within one wave.
6. **Inbound references were undercounted** — three adopter docs point at the
   file (one of them an *instruction to write into it*), and six plans carry
   claim-ledger rows, not three. Some are already stale, which the deletion would
   be blamed for.
7. **FT-11 is mostly closed** and would have re-filed completed work.
8. **FT-12's target fails the plan's own ownership test**, exactly as FT-16/19/20
   did.
9. **FT-31 is a third partial-resolution in the drop bucket** — `Status: CLOSED`
   but "Needs: a real signal … before this can be closed without breaking
   consumers", over a vacuous pass on a required check. Verify before deleting.

The reviewer independently re-enumerated all 57 headings and confirmed the
partition is complete and non-overlapping, and that the remaining drop-36 holds —
including three entries whose markers are stale in the *opposite* direction
(marked open, actually closed: FT-15, FT-30, FT-27's residual).

**Result:** finding 1 folded (the dangerous one); 2-4 folded as §3.4; 5-9 recorded
and NOT yet resolved. **NOT READY** — see §3.4 for the founder call that gates
the filing set, and §3.1 for the three cross-repo entries needing a measurement
pass before any body is written.

### Pass 4 — 2026-07-31 — independent (`verified-planning-reviewer`, fresh context) — **NOT READY; this was the 3rd independent pass, so the OPS-0066 cap is reached**

Seven load-bearing findings. Three change what gets filed, one changes what gets
deleted. Rather than fold them one at a time — which is what the previous two
passes did, each finding one more plan the rule had not been applied to — I ran
the sweep the rule always needed and **falsified the rule itself** (§3.0).

1. **`PLAN-007` is `Status: ready` and declares FT-11 (W3) and FT-12 (W4).** Under
   §3.0's own rule it holds both, so 1 ci issue and 4 cross-repo issues — **3 of
   them 🔴 founder interrupts** — should not be filed.
2. **`ROLLOUT_plan015-arming` is `PREPARED, NOT EXECUTED` and declares FT-13**,
   removing 3 more cross-repo filings. §3.0's vocabulary has no mapping for that
   status, nor for `active` / `IMPLEMENTED` / no-status-line.
3. **Two live founder runbooks were misclassified as "merged plans — leave"** —
   `ROLLOUT_plan017-verify` and `ROLLOUT_plan015-arming` each contain an
   executable instruction to *close an entry in the file being deleted*, the same
   defect class as the PLAN-020 instance already caught.
4. **§2 still stated the pre-rewrite disposition** for FT-54/55/56 — §3 was
   rewritten around it and §2 was not.
5. **FT-56 is three parts, not two.** Its coverage-holes paragraph
   (`can_approve_pull_request_reviews` shipped but never compared; label
   colour/description written but never compared) is neither 56a nor 56b, has no
   destination, and would be deleted with the file.
6. **The header gated execution on §3.4, which no longer exists** after §3's
   rewrite folded it into §3.0 — so the plan forbade its own execution with an
   undischargeable condition.
7. **§7.1's verbatim-body rule collides with §3.1's FT-11 caveat** — "reproduce
   the entry verbatim" against "filing it as written re-files completed work",
   with no rule reconciling them.

**The reviewer's drop-35 hunt came back clean** — every residual in the drop
bucket has a surviving home, and the partition sums and covers FT-1..FT-57 exactly
once. So the *triage* is sound; the *routing* is not.

Non-blocking, recorded not folded: §3.1 says "four entries rescued from the drop
bucket" (three were — FT-11 was rescued from the file bucket); §5 calls PLAN-021
"in flight" when it reads NOT READY; §6 parks an item in a NOT-READY plan, which
§3.0 says cannot hold one; §7.3 says "three PRs" then splits into four; PR-1's
deliberate no-CHANGELOG ships against an `ai-review` rubric that raises a blocking
finding for exactly that; FT-13 names `operations` among the broken callers while
§3.2 files only three repos; and the "49 external references" figure is 48 by a
line-based count — state the command or say "occurrences".

**Result:** the cap is reached with load-bearing findings outstanding, so no
fourth pass was dispatched. §3.0 is rewritten as the blocker it is; findings 1-3
and 5 are subsumed by the recommended replacement rule; 4, 6 and 7 are folded.
**Escalating to the founder** rather than continuing to iterate.
