#!/usr/bin/env python3
"""rtc_sum.py DIR [min]: per program, the counted events over min (default
1e5), grouped by kind (box, unbox, node, clo, apply, eta, rfc_wrap)."""
import os, sys, collections
d = sys.argv[1]; mn = float(sys.argv[2]) if len(sys.argv) > 2 else 1e5
for f in sorted(os.listdir(d)):
    if not f.endswith(".cnt"): continue
    n = f[:-4]
    keys = open(f"{d}/{n}.c.keys").read().split("\n")
    rows = []
    for l in open(f"{d}/{f}"):
        i, c = l.split(); rows.append((int(c), keys[int(i)]))
    tot = collections.Counter()
    for c, k in rows: tot[k.split()[0]] += c
    print(f"== {n}  " + "  ".join(f"{k}={v:.3g}" for k, v in sorted(tot.items())))
    for c, k in sorted(rows, reverse=True):
        if c >= mn and not k.startswith("node"): print(f"   {c:>14,} {k}")
    nodes = sorted([(c, k) for c, k in rows if k.startswith("node")], reverse=True)[:4]
    for c, k in nodes:
        if c >= mn: print(f"   {c:>14,} {k}")
