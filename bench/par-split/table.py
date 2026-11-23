#!/usr/bin/env python3 -I
# table.py RUNS.jsonl [prog-regex]: median wall (min-max) per prog x build x threads; speedup over 1 thread
import json, re, statistics, sys
rs = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
rx = re.compile(sys.argv[2]) if len(sys.argv) > 2 else None
g = {}
for r in rs:
    if r.get("rc") != 0 or (rx and not rx.search(r["prog"])): continue
    g.setdefault((r["prog"], r["build"]), {}).setdefault(r["threads"], []).append(r)
ths = sorted({r["threads"] for r in rs})
print("| program | build | " + " | ".join(f"{t} thr ms" for t in ths) + " | x at %d | bad | others max |" % ths[-1])
print("|---|---|" + "---|" * len(ths) + "---|---|---|")
for (p, b) in sorted(g):
    d = g[(p, b)]; cells = []; meds = {}
    for t in ths:
        w = [r["wall_ms"] for r in d.get(t, [])]
        if not w: cells.append("-"); continue
        meds[t] = statistics.median(w)
        cells.append(f"{meds[t]:.0f} ({min(w):.0f}-{max(w):.0f})")
    sp = meds.get(ths[0], 0) / meds[ths[-1]] if ths[-1] in meds else 0
    bad = sum(not r["ok"] for t in d for r in d[t])
    om = max(max(r.get("others", 0), r.get("others_after", 0)) for t in d for r in d[t])
    print(f"| {p} | {b} | " + " | ".join(cells) + f" | {sp:.2f} | {bad} | {om:.1f} |")
