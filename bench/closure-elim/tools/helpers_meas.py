#!/usr/bin/env python3
# instructions (median of 5) and cycles (median of 5) of the helper spellings, built from int's C
import os, subprocess, statistics as st, sys, json
sys.path.insert(0, "/private/tmp/bend-opt/clo/tools")
from measure import run, LIMIT, M
BB = "/Users/macolas/Software/bend-benchmarks"
for n in sys.argv[1:]:
    rel = n.replace("__", "/") + ".bend"
    b = f"{M}/bin/{n}.h"
    subprocess.run([LIMIT, "600", "6144", "cc", "-std=c11", "-O3", "-w", f"{M}/c/int/{n}.c", "-o", b, "-lpthread", "-lm"], check=True)
    rs = [run(b, os.path.dirname(f"{BB}/{rel}"), 1) for _ in range(5)]
    want = open(f"{BB}/{os.path.dirname(rel)}/expected.txt").read().rstrip("\n")
    ok = all(r["rc"] == 0 and r["out"] == want for r in rs)
    print(json.dumps({"prog": rel, "ok": ok, "ins": st.median(r["ins"] for r in rs), "cyc": st.median(r["cyc"] for r in rs)}), flush=True)
    os.remove(b)
