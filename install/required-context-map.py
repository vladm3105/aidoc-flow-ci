#!/usr/bin/env python3
"""Derive: for every required status-check context in every branch-protection
template, the CONSUMER caller file that must be installed to produce it.

PLAN-018 FT-18 — the general form of F2. F2 was "this one required context
(`call / Lint / format / security hooks`) has no producing workflow installed,
so arming protection pins every PR forever." This computes the producer for
EVERY required context so the class is detected, not just the one instance.

The map is DERIVED, never hand-maintained (a hardcoded context->caller table is
the F1 failure mode — a future template addition silently invalidates it). Chain:

  required context `<jobid> / <name>`
    -> the reusable whose job `name:` (or key) is <name>          [.github/workflows/*.yml]
    -> a caller TEMPLATE that `uses:` that reusable               [install/templates/workflows/*.yml]
    -> that template's CONSUMER path basename                     [manifest.json]

Output: TSV `<tier>\\t<context>\\t<producer>` on stdout, one row per required
context per tier. The producer field carries TWO failure symbols, because
"canon ships a producer" and "a cold start installs that producer" are different
questions and only the first used to be asked:

  `pre-commit.yml`   OK — canon ships it and a cold start installs it.
  `?`                canon ships NO producer for this context (the original F2).
  `!pre-commit.yml`  canon ships it, but `auto_install: false` — a COLD START
                     does not install it, so a new repo arms this context with
                     nothing to satisfy it.

Both are failures. `!` exists because aidoc-flow-ci#481 was live in BOTH
directions without detection: #438/#441 moved `auto_install` from
`pre-commit.yml` to `quick-gates.yml` while the tier templates still required
`pre-commit.yml`'s context, and this script reported every row green because it
only ever asked whether canon SHIPS a producer.

WHAT THIS STILL CANNOT SEE, stated because the gap is the whole point of the
file. `auto_install` is canon's declaration about a COLD START. It says nothing
about what an EXISTING consumer has on disk, and canon cannot read consumer
repos. So `!` catches PLAN-026 §C0 landing alone — substituting `quick-gates`
into the tier templates while its entry is still `auto_install: false` — but
nothing here can catch §C0 landing together with the flag flip BEFORE the C1–C5
fleet rollout, which would arm a context every already-installed consumer lacks
a producer for. That ordering is a documented sequencing rule (DECISIONS.md
CI-0038), enforced by review, not by this script. Do not read a green map as
clearance to land §C0.

Prints the single line `SKIP` when PyYAML is unavailable (suite convention).
"""
import glob
import json
import os
import re
import sys

try:
    import yaml
except ImportError:
    print("SKIP")
    raise SystemExit(0)

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."


def reusable_on(d):
    # `on:` parses to the YAML boolean True; handle both keys.
    on = d.get(True) if True in d else d.get("on")
    return isinstance(on, dict) and "workflow_call" in on


# 1. job-name -> reusable basename (name: if set, else the job key).
# sorted() so that IF two reusables ever shared a job name, `setdefault` resolves
# it deterministically (first by filename) rather than by filesystem glob order.
name_to_reusable = {}
for f in sorted(glob.glob(os.path.join(ROOT, ".github/workflows/*.yml"))):
    try:
        d = yaml.safe_load(open(f, encoding="utf-8")) or {}
    except Exception:
        continue
    if not reusable_on(d):
        continue
    base = os.path.basename(f)
    for jk, jb in (d.get("jobs") or {}).items():
        nm = jb.get("name", jk) if isinstance(jb, dict) else jk
        name_to_reusable.setdefault(nm, base)

# 2. caller template -> the reusable basename it uses, AND reusable -> the caller
# JOB KEYS that call it. FT-45: a required context is `<caller-job-key> / <name>`;
# validating only <name> lets a wrong <caller-job-key> pass, and that context is
# never emitted (arming it hangs every PR — the F2 class). Parse jobs so the
# job-key half is checked, not dropped.
tmpl_to_reusable = {}
reusable_to_jobkeys = {}
# PLAN-025 P8: a caller template may now emit a context WITHOUT calling a
# reusable at all. A job whose steps are composite actions is a PLAIN job, and a
# plain job's check run is named `<name:>` (or the job key) with NO `<jobkey> / `
# prefix — the prefix exists only because a reusable call surfaces as
# `<caller-job-key> / <callee-job-name>`. Canon's own `main` demonstrates both
# shapes side by side: bare `suite` from tests.yml, `call / markdownlint` from a
# caller keyed `call`.
#
# Without this map the v3 contexts fell through to the `?non-call` branch below,
# which the suite treated as a PASS — so a context armed against nothing would
# have reported green. That is the F2 class the whole script exists to detect,
# reintroduced by a new packaging shape.
plainjob_to_tmpl = {}
USES = re.compile(r"aidoc-flow-ci/\.github/workflows/([A-Za-z0-9._-]+\.yml)")
for f in sorted(glob.glob(os.path.join(ROOT, "install/templates/workflows/*.yml"))):
    try:
        d = yaml.safe_load(open(f, encoding="utf-8")) or {}
    except Exception:
        continue
    tb = os.path.basename(f)
    for jk, jb in (d.get("jobs") or {}).items():
        uses = jb.get("uses") if isinstance(jb, dict) else None
        m = USES.search(uses) if isinstance(uses, str) else None
        if not m:
            # A plain job: it emits its own name. `setdefault` + sorted() glob so
            # a collision between two templates resolves deterministically by
            # filename, matching the reusable map's convention above.
            if isinstance(jb, dict):
                plainjob_to_tmpl.setdefault(jb.get("name", jk), tb)
            continue
        reu = m.group(1)
        tmpl_to_reusable.setdefault(tb, reu)
        reusable_to_jobkeys.setdefault(reu, set()).add(jk)

# 3. template basename -> consumer path basename (manifest, incl. visibility variants).
try:
    manifest = json.load(open(os.path.join(ROOT, "install/templates/manifest.json"), encoding="utf-8"))
except (OSError, ValueError) as e:
    print("ERR:manifest %s" % e, file=sys.stderr)
    raise SystemExit(1)
# `consumer_install` is KEYED by the manifest's consumer PATH; `tmpl_to_consumer`
# and `reusable_to_consumer` carry that PATH as their VALUE. Neither uses the
# basename as an identity. Two entries may share a basename
# (`doc-maintainer.yml` / `doc-maintainer.json` are the near miss today), and a
# basename key would resolve the chain through one entry while reporting the
# OTHER entry's install symbol — a silent false pass in exactly the direction
# this script exists to catch. Basename is applied once, at print.
tmpl_to_consumer = {}
# consumer path -> the install symbol its manifest entry earns. This is the
# `auto_install` half of the chain: WITHOUT it the script answers "does canon
# ship a producer?" and silently passes that off as "will a cold start have
# one?". See the module docstring for why both directions of that gap shipped.
consumer_install = {}
for e in manifest["files"]:
    cp = e["path"]
    tb = os.path.basename(e.get("template", ""))
    if tb:
        tmpl_to_consumer[tb] = cp
    for v in (e.get("visibility_variants") or {}).values():
        tmpl_to_consumer[os.path.basename(v)] = cp
    consumer_install[cp] = "" if e.get("auto_install") else "!"


def producer(cons):
    """Render a resolved consumer path as `[symbol]<basename>`, or `?`.

    FAILS CLOSED. An unknown path defaults to `!`, not to the passing empty
    string: this function's whole purpose is detecting a producer a cold start
    will not have, so the default for "I could not determine that" must be the
    failing answer. (`?` would NOT work as the default — the callers match `?`
    exactly to mean "no producer at all", so `?foo.yml` would fall through to
    the pass arm.)
    """
    if not cons:
        return "?"
    return consumer_install.get(cons, "!") + os.path.basename(cons)

# reusable -> consumer caller PATH (via any caller template that uses it).
reusable_to_consumer = {}
for tmpl, reu in tmpl_to_reusable.items():
    cb = tmpl_to_consumer.get(tmpl)
    if cb:
        reusable_to_consumer.setdefault(reu, cb)

# 4. emit: tier, context, producing consumer basename (or ?).
for tpl in sorted(glob.glob(os.path.join(ROOT, "install/templates/branch-protection-*.json"))):
    tier = os.path.basename(tpl)[len("branch-protection-"):-len(".json")]
    d = json.load(open(tpl, encoding="utf-8"))
    for ctx in (d.get("required_status_checks") or {}).get("contexts", []):
        if " / " not in ctx:
            # PLAN-025 P8. A bare context is emitted by a PLAIN job — which since
            # v3 is a shape canon ships, not only a repo-local one. Resolve it
            # against the plain-job map.
            #
            # THIS BRANCH USED TO PRINT `?non-call` UNCONDITIONALLY, and the
            # suite scored that as a pass ("no canon producer expected"). That
            # was defensible while every canon caller was a reusable wrapper; it
            # became a hole the moment canon shipped a plain job, because the
            # tool would bless a context it had not checked. An unresolved bare
            # context now returns `?` like any other orphan: if a canon
            # branch-protection template requires a context, canon must ship
            # something that produces it, whatever the packaging.
            cons = tmpl_to_consumer.get(plainjob_to_tmpl.get(ctx, ""), None)
            print("%s\t%s\t%s" % (tier, ctx, producer(cons)))
            continue
        jobid, name = ctx.split(" / ", 1)
        reu = name_to_reusable.get(name)
        cons = reusable_to_consumer.get(reu) if reu else None
        # FT-45: the JOB-KEY half must match a caller job that actually calls this
        # reusable. `<name>` resolving is not enough — `call / check-standards-drift`
        # resolves the reusable but is never PRODUCED if the caller job is keyed
        # `drift`, so branch protection would wait on it forever. A resolved name
        # under an unproduced job-key is NOT a producer.
        if cons and jobid not in reusable_to_jobkeys.get(reu, set()):
            cons = None
        print("%s\t%s\t%s" % (tier, ctx, producer(cons)))
