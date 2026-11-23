#!/usr/bin/env python3
import json, sys, math, re
rows = [json.loads(l) for l in open(sys.argv[1])]
APART = re.compile(r"^(awfy__|perceus__rbtree-ck|clbg__binary-trees|osprey__binarytrees|parallel-ml__ocaml-binarytrees5|koka-extra__(binarytrees-fbip|lookup|msort|msort-fip|qsort|qsort-fip|rbtree-clrs|rbtree-fip|tmap|tmap-std)__)")
KNOWN = re.compile(r"seam-carve-index|fannkuch-redux|osprey__pascal__bend-par|josephus|seidel-2d|respelled__factorial|raytracer|wordfreq__bend-par")
sites = set(sys.argv[2].split(",")) if len(sys.argv) > 2 else set()
bad = [r["name"] for r in rows if not (r["base"]["ok"] and r["new"]["ok"] and r["base"].get("ok10", True) and r["new"].get("ok10", True))]
print("not ok:", bad)
lr = lambda r, k: math.log(r["new"][k] / r["base"][k])
for grp, sel in (("set apart", lambda n: APART.match(n)), ("rest", lambda n: not APART.match(n))):
    rs = [r for r in rows if sel(r["name"])]
    if not rs: continue
    gi = math.exp(sum(lr(r, "ins") for r in rs) / len(rs)); gc = math.exp(sum(lr(r, "cycm") for r in rs) / len(rs))
    print(f"== {grp}: {len(rs)} programs, geomean ins {gi:.4f} cyc {gc:.4f}")
    for r in sorted(rs, key=lambda r: lr(r, "ins")):
        di = r["new"]["ins"] / r["base"]["ins"] - 1; dc = r["new"]["cycm"] / r["base"]["cycm"] - 1
        if abs(di) >= 0.01 or abs(dc) >= 0.05:
            print(f"  {r['name']:55s} ins {di:+.2%} cyc {dc:+.2%} rss {r['new']['rss']/max(r['base']['rss'],1)-1:+.1%}" + (" (known int loss)" if KNOWN.search(r['name']) else ""))
