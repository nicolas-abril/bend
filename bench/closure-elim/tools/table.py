#!/usr/bin/env python3
# table.py MEAS.jsonl: per program, int vs elim instructions (run 1) and median cycles
import json, sys, statistics
rows = {}
for l in open(sys.argv[1]):
    j = json.loads(l)
    for v in j["variants"]:
        rows.setdefault(j["prog"], {})[v] = j
out = []
for p, d in sorted(rows.items()):
    if "int" not in d or "elim" not in d:
        continue
    a, b = d["int"], d["elim"]
    ok = all(r["ok"] for r in a["runs"] + b["runs"]) and all(x is None or x["ok"] for x in (a["par"], b["par"]))
    ia, ib = statistics.median(r["ins"] for r in a["runs"]), statistics.median(r["ins"] for r in b["runs"])
    ca, cb = statistics.median(r["cyc"] for r in a["runs"]), statistics.median(r["cyc"] for r in b["runs"])
    spread = lambda rs: (min(r["cyc"] for r in rs), max(r["cyc"] for r in rs))
    out.append((p, ia, ib, ca, cb, spread(a["runs"]), spread(b["runs"]), ok,
                a["par"] and a["par"]["cyc"], b["par"] and b["par"]["cyc"]))
print("| program | instructions int | elim | Δ | cycles int (median) | elim | Δ | ok |")
print("|---|---:|---:|---:|---:|---:|---:|---|")
for p, ia, ib, ca, cb, sa, sb, ok, pa, pb in out:
    print(f"| {p} | {ia/1e9:.3f}G | {ib/1e9:.3f}G | {100*(ib-ia)/ia:+.1f}% | {ca/1e9:.3f}G | {cb/1e9:.3f}G | {100*(cb-ca)/ca:+.1f}% | {'ok' if ok else 'BAD'} |")
