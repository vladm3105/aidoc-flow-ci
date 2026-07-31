# PLAN-022 — doc-surface governance: three surfaces, three edit shapes

**Status:** **NOT READY** — two independent passes returned 12 and 9 load-bearing findings. Pass 3's findings 1-4 are folded; 5-9 are recorded and unresolved. A founder call (§3.4) gates the filing set. **Do not file, and do not delete the TODO file, while this reads NOT READY.**
**Scope:** Retire `plans/FRAMEWORK-TODO.md`; correct the governance table it
contradicts; specify the per-surface edit-mode taxonomy that PLAN-021's
`apply.py` work inherits.
**Semver:** **none for Phase 1** (no canon body, no manifest surface changes).
Phase 2 is MINOR when it lands.
**Decision record:** `CI-0028` (new)

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
cross-referenced against `CHANGELOG.md` and `HANDOFF.md` for closure evidence.

| Disposition | Count | Action |
|---|---:|---|
| **Resolved / shipped** | **36** | Drop — git is the archive |
| **Open, ci-owned → file here** | **11** | FT-4,5,6,16,17,19,20,24,33,35,57 |
| **Open, ci-owned → stays in its plan (below the bar)** | **5** | FT-18, 37, 54, 55, 56 — already-planned; see §2 |
| **Open, cross-repo** | **4** | FT-11,12,13,38 |
| **Neither — comment on an existing issue** | **1** | FT-23 → a comment on #352, not a new issue (§3.2) |

Three corrections against the first triage, each of which would have cost
something real:

- **FT-57 and FT-18 were bucketed "resolved" and would have been deleted.** Both
  state an open residual in their own text — FT-57 ends *"**Status:** fix landed;
  the `--update` refusal is OPEN"*, a pending **founder decision** on the same
  destructive `--update` path FT-9 once bricked the fleet with; FT-18's remaining
  scope *"stays open and 🔴 founder-manual"*.
- **FT-16, FT-19 and FT-20 were assigned to `operations` and are ci-owned.** The
  *incident* was on operations' runner host, but every fix surface they name is a
  file in **this** repo (`install/templates/runner/{run-ephemeral,provision-runner}.sh`,
  `README.md`, `docs/runners.md`). The contract's test is where the fix lives.
  Filing them on operations would have misdirected three issues, two of them 🔴
  with a founder interrupt, while deleting the ci-owned record in the same wave.
- **FT-23 is founder-descoped, not open.** A 2026-07-22 scope decision descoped
  the `ai-review`/`doc-maintainer`/`composition` self-callers ("**descoped**, not
  deferred"); what remained (FT-36, FT-34, the inventory) is closed. Filing it
  would reopen a closed founder decision.

**The argument for retiring it is real but I first stated it backwards.** The
per-entry markers are mostly *good* — FT-25, 26, 28, 29, 31, 32, 34 and 36 all
carry an explicit `Status: CLOSED`, several with dated corrections. What is stale
is the single `## Open` heading every entry sits under, which says "open" about
57 entries of which 36 are closed. The genuinely unreliable direction is the one
the first triage missed: **partially**-resolved entries whose fix landed while a
residual stayed open (FT-57, FT-18). A file needs a second manual write to close
an entry; an issue closes on the merge that fixes it, and cannot be partially
closed without saying so.

### 3.1 Cross-repo targets — ⚠️ NOT SETTLED, do not file from this section

**This table is the executor-facing surface and it is the plan's weakest part.**
An earlier revision corrected §3's prose to move FT-16/19/20 to ci-owned and
FT-37 into its plan, and **left this table routing all four to `operations`** —
i.e. the corrected finding survived in the one place someone would act on. It is
now reduced to the four §3 declares, but three of those four are themselves
unresolved:

| FT | Subject | Target | Tier | State |
|---|---|---|---|---|
| 13 | private-repo `standards-drift`: `business` + `interlog` have **no caller at all**; iplanic pins an unresolvable annotated tag; every private run on record has failed | **unsettled** — 3 findings, ≥3 repos | 🔴 | ⚠️ also PLAN-010 scope (§3.4); the entry forbids direct cross-repo edits and routes via the ops runbook — reconcile with OPS-0076 before filing |
| 38 | four fleet repos pin `pre-commit-hooks` at a mutable rev the refresh cannot move | framework · iplanic · **`vladm3105/iplan-runner`** · operations — **4 issues, not 1** | 🔴 (cross-repo coordination) | ready to file once bodies are written |
| 11 | graduate `markdown-lint` / `docs-sync` per repo | — | — | ⚠️ **mostly closed** — the `markdown-lint` graduation is DONE across all canon consumers (PLAN-007 W3, six merged PRs); the only remainder is arming, "which is FT-12", plus a 🔴 founder `docs-sync` App provisioning. **Do not file as written.** |
| 12 | fleet branch-protection arming anomalies | **not operations** | — | ⚠️ its sub-items are branch-protection settings on framework / business / iplanic, remediated via *this repo's* arming runbook; one iplan-runner item is already RESOLVED. Fails the plan's own ownership test the same way FT-16/19/20 did. |

**Consequence: the cross-repo wave is 4 entries and an unknown number of issues,
not "4 issues".** Only FT-38 is ready, and it is four filings. FT-13, FT-11 and
FT-12 each need a measurement pass before anyone writes a body — FT-13 carries
its own warning that it *"has now been wrong three times."*

### 3.4 The already-planned exclusion is applied inconsistently

§2 routes FT-54/55/56/37 to their plans as *already-planned*. **FT-5 and FT-13
are equally declared** — FT-5 says "it belongs with the PLAN-010 adoption-model
work, not a drive-by" and is a numbered PLAN-010 deliverable; FT-13 says it "is
the scope of the adoption-model plan" and appears twice in PLAN-010. PLAN-010 is
`DRAFT — NOT READY, DO NOT EXECUTE`, which is the same state as PLAN-020 — the
stated reason FT-54/55/56 were pulled.

**So the rule must be stated and applied uniformly**, because it decides 2 of the
filings. Either "declared in any plan, ready or not → stays in the plan" (pulls
FT-5 and FT-13 out of the filing set) or "only a *ready* plan holds an entry"
(pushes FT-54/55/56 back in). **Founder call; do not file FT-5 or FT-13 until it
is made.**

**And a below-bar entry needs a destination, which no PR currently provides.**
"Stays in its plan" is not a no-op when the file holding it is being deleted:
**FT-54's three options, its revised recommendation and its dated CORRECTION
exist only in the TODO file**, and PLAN-020 explicitly declines to decide FT-54
("**Not** deciding FT-54") — its only FT-54 task is to correct that paragraph
*inside the file this plan deletes*. PLAN-009 mentions neither FT-18 nor FT-37.
**PR-2 must write each below-bar entry into its destination plan, or the
deletion destroys it.**

### 3.2 Three entries that must not become new issues as first triaged

- **FT-56 is TWO defects, and the first framing was wrong** — its own text says
  so. **56a (blindness):** the drift job grants only `contents: read` and
  `administration` is not a grantable scope, so the highest-value comparisons
  403 into `warn_uncheckable` and verify nothing. **56b (unconsumed signal):** a
  `::warning::` nobody reads. Only **56b** matches open issue **#351**. So: comment
  56b's evidence onto #351, and **file 56a separately** — it is a permissions
  defect of FT-5's class, and "one issue per defect" applies. *(But see §2 — FT-56
  is PLAN-020 scope, so confirm the bar before filing 56a rather than
  transcribing it.)*
- **FT-23 is founder-descoped**, not open (§3). If the intent is to record
  PLAN-021 #352's root cause, that is a **comment on #352** — not a new issue that
  reopens a closed scope decision.
- **FT-13 is three findings, only one of which is iplanic's.** Its verified facts
  are (1) `business` and `interlog` carry **no `standards-drift.yml` at all**, so
  they get no drift or pin-currency signal from any source; (2) iplanic pins an
  unresolvable annotated tag; (3) every private run on record has failed. Filing
  one issue on iplanic drops (1) and (3). The entry also carries its own warning
  that it *"has now been wrong three times; do not add a fourth without
  measuring"* — **re-measure before filing, do not transcribe.**

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

## 7. PR sequence

**Deleting the file strands live inbound references — it is not a one-file
change.** `FRAMEWORK-TODO` appears **55 times across 20 files** in this repo. The
ones that cannot be left alone:

- `.github/workflows/standards-drift-self.yml` — a **live workflow comment**
  telling the reader to go read the file for FT-13.
- `HANDOFF.md` — 7 references, including one pointing at the file for FT-54's
  options. §6 defers the handoff rewrite, so PR-1 would ship a handoff citing a
  deleted file.
- **`PLAN-020` is DEFERRED but live, and its Phase 1 tasks are literally "file
  FT-55 and FT-56 in `plans/FRAMEWORK-TODO.md`" and "correct FT-54's Effect
  paragraph."** An earlier draft of this plan never mentioned PLAN-020 at all.
  Retiring the file **changes PLAN-020's instructions**, so PLAN-020 must be
  updated in the same wave or it becomes unexecutable.
- Claim-ledger rows in merged plans citing the file by `path:line` (PLAN-010,
  PLAN-017, PLAN-020). No automated gate breaks today — this repo does not wire
  `check_plan.py` into pre-commit, and none of the 55 references is a markdown
  link so the link checker stays green — but re-running the gate on those plans
  will fail.

**So PR-1 exceeds the OPS-0061 three-surface cap and must split:**

1. **File the issues** (no repo change) — see the count below.
2. **PR-1** — delete `plans/FRAMEWORK-TODO.md`; correct the `CLAUDE.md`
   governance row; `DECISIONS.md` CI-0028.
3. **PR-2** — the inbound references: the `standards-drift-self.yml` comment,
   `PLAN-020`'s Phase 1 tasks, and the HANDOFF's 7 pointers (which the handoff
   regeneration can absorb).

**Count, corrected:** 11 ci issues + 4 cross-repo entries + 2 comments (#351 for
FT-56b, #352 for FT-23). **FT-38 is four issues, not one** — an issue is filed on
one repo, and framework, iplanic, iplan-runner and operations each own their own
`rev:` line. So 11 + 3 + 4 = **18 creates and 2 comments**, not "19 issues".

**Durability is a property of the issue bodies, not of the ordering.** Filing
before deleting only preserves the entries if the bodies carry them:

- **Each issue body reproduces its entry verbatim**, not a five-part summary. The
  entries carry analysis that summarising destroys — FT-13's three-corrections
  caution, FT-54's option matrix and its dated CORRECTION.
- **Any `plans/FRAMEWORK-TODO.md:NNN` citation inside an issue body is pinned to
  the pre-deletion blob SHA**, or every filed issue cites a path that will not
  exist on `main` the next day.
- **Say what reverts.** If PR-1 stalls after filing, the repo holds 18 new issues
  *and* the 1,896-line file — exactly the two-surface drift this plan exists to
  remove. Revert = close the new issues with a pointer, or land PR-1.

**Two tier corrections:** FT-38 spans four repos, and *cross-repo coordination*
is an explicit **🔴** trigger — §3.1 marks it 🟡 and escalation is fail-safe.
FT-37's own entry marks its surface 🔴 against §3.1's 🟡.

**Slug trap:** `iplan-runner`'s slug is **`vladm3105/iplan-runner`**, not
`aidoc-flow-*`. FT-38 is the one filing that hits it. It fails loudly, so it
costs a retry rather than a wrong write.

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
