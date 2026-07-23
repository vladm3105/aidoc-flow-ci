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

Output: TSV `<tier>\\t<context>\\t<producer-basename-or-?>` on stdout, one row per
required context per tier. A `?` producer means canon requires a context it ships
no producer for — F2 latent in canon itself. Prints the single line `SKIP` when
PyYAML is unavailable (suite convention).
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

# 2. caller template -> the reusable basename it uses.
tmpl_to_reusable = {}
USES = re.compile(r"uses:\s*\S*aidoc-flow-ci/\.github/workflows/([A-Za-z0-9._-]+\.yml)")
for f in sorted(glob.glob(os.path.join(ROOT, "install/templates/workflows/*.yml"))):
    try:
        m = USES.search(open(f, encoding="utf-8").read())
    except OSError:
        continue
    if m:
        tmpl_to_reusable[os.path.basename(f)] = m.group(1)

# 3. template basename -> consumer path basename (manifest, incl. visibility variants).
try:
    manifest = json.load(open(os.path.join(ROOT, "install/templates/manifest.json"), encoding="utf-8"))
except (OSError, ValueError) as e:
    print("ERR:manifest %s" % e, file=sys.stderr)
    raise SystemExit(1)
tmpl_to_consumer = {}
for e in manifest["files"]:
    cb = os.path.basename(e["path"])
    tb = os.path.basename(e.get("template", ""))
    if tb:
        tmpl_to_consumer[tb] = cb
    for v in (e.get("visibility_variants") or {}).values():
        tmpl_to_consumer[os.path.basename(v)] = cb

# reusable -> consumer caller basename (via any caller template that uses it).
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
            # a bare (non-reusable) context — repo-local, no canon producer to map.
            print("%s\t%s\t?non-call" % (tier, ctx))
            continue
        _jobid, name = ctx.split(" / ", 1)
        reu = name_to_reusable.get(name)
        cons = reusable_to_consumer.get(reu) if reu else None
        print("%s\t%s\t%s" % (tier, ctx, cons or "?"))
