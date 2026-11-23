#!/usr/bin/env python3
# Applies each wrong version to clo/wrong/bend2/comp.ts (from the branch head),
# runs the closure tests on C at 1 thread, and reports which ones catch it.
import subprocess, sys, os, re
W = "/private/tmp/bend-opt/clo/wrong"
SRC = open("/private/tmp/bend-opt/clo/elim/bend2/comp.ts").read()
TESTS = ["tests/run/clo_elim.bend", "tests/run/clo_elim_generic.bend", "tests/run/known_callback.bend",
         "tests/run/known_callback_array.bend", "tests/run/known_callback_edges.bend",
         "tests/run/known_callback_layouts.bend", "tests/run/known_callback_shapes.bend",
         "tests/compile/known_fn_inline.bend", "tests/compile/record_wide_boxed_params.bend"] + sys.argv[2:]
WRONG = {
 "key ignores the lambda": [("...xs.map((x, j) => ren(is.includes(\n    ks[j]) && x.$ === \"Ann\" ? x.x : x, d)), ", "")],
 "captures passed in reverse": [("  return [...g.cs.map((l) => Bend.Ann(", "  return [...[...g.cs].reverse().map((l) => Bend.Ann(")],
 "body kept with its cells": [("  const [h, T0] = [f.h!, tld.T].map((t) =>\n    Bend.term_higher(Bend.term_lower(t)));", "  const [h, T0] = [f.h!, tld.T];")],
 "type-only captures passed live": [("  const qs = cs.map((l) => live.has(l));", "  const qs = cs.map((l) => c.env[l].q.$ !== \"None\");")],
 "beta binds every argument to the first": [("      ? re(lam.f(all[0])) : Bend.Let([lam.k], [0], [Bend.Ann(all[0], dom.A)],", "      ? re(lam.f(all[0])) : Bend.Let([lam.k], [0], [Bend.Ann(all[all.length - 1], dom.A)],")],
 "lend without the box test": [("    && lays[i] === BOX && sc.uses.get(probe_of(x))!.val.lay === BOX\n", "    && lays[i] === BOX\n")],
 "erased arguments not filled": [("    || !dom_live(doms[i])) ? [i] : []);", ") ? [i] : []);")],
}
only = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] != "all" else None
for name, edits in WRONG.items():
    if only and only != name:
        continue
    s = SRC
    for a, b in edits:
        assert s.count(a) == 1, (name, a)
        s = s.replace(a, b)
    open(f"{W}/bend2/comp.ts", "w").write(s)
    caught = []
    for t in TESTS:
        want = "\n".join(l[2:] for l in open(f"{W}/{t}").read().split("\n") if l.startswith("#|")).strip()
        r = subprocess.run(["/private/tmp/bend-opt/clo/scratch/runone.sh", W, f"{W}/{t}"], capture_output=True, text=True)
        out = r.stdout.strip()
        if out != want:
            caught.append(os.path.basename(t) + (" (build)" if "FAIL" in out.split("\n")[-1] else ""))
    print(f"{name}: {'CAUGHT by ' + ', '.join(caught) if caught else 'MISSED'}", flush=True)
open(f"{W}/bend2/comp.ts", "w").write(SRC)
