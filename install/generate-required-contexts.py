#!/usr/bin/env python3
"""Generate install/templates/required-contexts.json from required-context-map.py.

PLAN-031 Phase C. apply-standards.sh runs from a CONSUMER checkout with no
canon tree and fetches canon files one at a time over HTTPS, but the map needs
all 15 reusables + manifest.json + the tier templates — too many fetches. So
this generator runs the map once at canon-authoring time and commits a small
derived artifact the script fetches as ONE file.

The artifact is DERIVED, never hand-maintained: a hardcoded context->caller
table is the F1 failure mode (a future template addition silently invalidates
it). The drift gate that makes a committed table acceptable lives in
tests/test_unproduced_contexts.sh — it regenerates from the map and FAILS when
the committed copy differs.

Shape (per tier, template order; tiers sorted; stable formatting so
regeneration diffs cleanly):

    {"<tier>": [{"context": "call / verify",
                 "producer": ".github/workflows/audit-trail.yml",
                 "cold_start_installed": false}, ...],
     ...}

The map's `!`/`?` prefix becomes the boolean, with a DISTINCT representation
for `?` (canon ships NO producer at all — worse than `!`, where canon ships it
but a cold start does not install it): `?` renders as `"producer": null` with
`"cold_start_installed": false`.

FAILS CLOSED: a missing map, a map that errors, or a map that emits nothing
all exit non-zero and write nothing. An empty artifact would read as "no tier
requires anything" — a silent pass over exactly the defect this exists to
catch.

Usage:
    install/generate-required-contexts.py [ROOT]          # regenerate in place
    install/generate-required-contexts.py [ROOT] --check  # exit 1 on drift
"""
import difflib
import glob
import json
import os
import subprocess
import sys

ARGS = [a for a in sys.argv[1:] if not a.startswith("-")]
FLAGS = set(a for a in sys.argv[1:] if a.startswith("-"))
if FLAGS - {"--check"}:
    print("usage: generate-required-contexts.py [ROOT] [--check]",
          file=sys.stderr)
    raise SystemExit(2)

ROOT = ARGS[0] if ARGS else "."
CHECK = "--check" in FLAGS
MAP = os.path.join(ROOT, "install/required-context-map.py")
OUT = os.path.join(ROOT, "install/templates/required-contexts.json")

if not os.path.isfile(MAP):
    print("generate-required-contexts: FATAL required-context map not found: %s"
          % MAP, file=sys.stderr)
    raise SystemExit(1)

try:
    proc = subprocess.run([sys.executable, MAP, ROOT],
                          capture_output=True, text=True, timeout=120)
except (OSError, subprocess.SubprocessError) as e:
    print("generate-required-contexts: FATAL could not run the map: %s" % e,
          file=sys.stderr)
    raise SystemExit(1)
if proc.returncode != 0:
    print("generate-required-contexts: FATAL the map exited %d: %s"
          % (proc.returncode, proc.stderr.strip()), file=sys.stderr)
    raise SystemExit(1)
rows = [ln for ln in proc.stdout.splitlines() if ln and ln != "SKIP"]
if not rows:
    # An empty map means "nothing is required anywhere" — which is how a
    # broken derivation reports a bricked tier set as green. Refuse.
    print("generate-required-contexts: FATAL the map emitted no rows "
          "(SKIP/empty) — refusing to write an empty artifact", file=sys.stderr)
    raise SystemExit(1)

# Tiers come from the template FILES, not only tiers the map emitted rows for,
# so umbrella — whose required_status_checks is null — still gets an (empty)
# list rather than being silently omitted.
tiers = sorted(
    os.path.basename(p)[len("branch-protection-"):-len(".json")]
    for p in glob.glob(os.path.join(ROOT, "install/templates",
                                    "branch-protection-*.json")))
if not tiers:
    print("generate-required-contexts: FATAL no branch-protection-*.json "
          "templates under %s" % ROOT, file=sys.stderr)
    raise SystemExit(1)

data = {t: [] for t in tiers}
for ln in rows:
    try:
        tier, ctx, prod = ln.split("\t")
    except ValueError:
        print("generate-required-contexts: FATAL malformed map row: %r" % ln,
              file=sys.stderr)
        raise SystemExit(1)
    if tier not in data:
        print("generate-required-contexts: FATAL map names unknown tier %r"
              % tier, file=sys.stderr)
        raise SystemExit(1)
    if prod == "?":
        data[tier].append({"context": ctx, "producer": None,
                           "cold_start_installed": False})
    elif prod.startswith("!"):
        data[tier].append({"context": ctx,
                           "producer": ".github/workflows/" + prod[1:],
                           "cold_start_installed": False})
    else:
        data[tier].append({"context": ctx,
                           "producer": ".github/workflows/" + prod,
                           "cold_start_installed": True})

rendered = json.dumps(data, indent=2, sort_keys=False) + "\n"

if CHECK:
    try:
        committed = open(OUT, encoding="utf-8").read()
    except OSError as e:
        print("generate-required-contexts: FATAL cannot read %s: %s"
              % (OUT, e), file=sys.stderr)
        raise SystemExit(1)
    if committed != rendered:
        print("generate-required-contexts: DRIFT in %s — regenerate with "
              "install/generate-required-contexts.py" % OUT, file=sys.stderr)
        for diff_ln in difflib.unified_diff(
                committed.splitlines(), rendered.splitlines(),
                "committed", "regenerated", lineterm=""):
            print(diff_ln, file=sys.stderr)
        raise SystemExit(1)
    print("generate-required-contexts: %s matches regeneration" % OUT)
    raise SystemExit(0)

with open(OUT, "w", encoding="utf-8") as f:
    f.write(rendered)
print("generate-required-contexts: wrote %s (%d tiers, %d contexts)"
      % (OUT, len(data), sum(len(v) for v in data.values())))
