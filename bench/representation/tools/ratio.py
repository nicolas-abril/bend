#!/usr/bin/env python3
"""ratio.py F.jsonl PROG..: per placement, the branch's P-core cycles over
main's (each the least over rounds, P-core runs only); range and median"""
import json, sys, statistics as st
pc = lambda r: r["instr"] * r["pcycles"] / r["pinstr"] if r["pinstr"] else float("inf")
g = {}
for l in open(sys.argv[1]):
    r = json.loads(l)
    if r["pcycles"] / max(r["cycles"], 1) < 0.5: continue
    g.setdefault(r["label"], {}).setdefault(r["pos"], []).append(pc(r))
for p in sys.argv[2:]:
    for v in sys.argv[2:] and ["new", "pad"]:
        b, n = g.get(p + "_base", {}), g.get(p + "_" + v, {})
        rs = sorted(min(n[k]) / min(b[k]) for k in b if k in n)
        if rs: print(f"{p} {v}/base: {rs[0]:.3f} to {rs[-1]:.3f}, median {st.median(rs):.3f} over {len(rs)} placements")
