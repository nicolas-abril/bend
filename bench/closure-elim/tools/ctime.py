#!/usr/bin/env python3
# emit wall time, int vs elim, alternating, REPS runs each; prints per program min times
import subprocess, time, sys, os
L = os.path.expanduser("~/Software/supgen-bend/limit")
reps = int(sys.argv[1]); files = sys.argv[2:]
tot = {"int": 0.0, "elim": 0.0}
for f in files:
    best = {}
    for _ in range(reps):
        for v in ("int", "elim"):
            t = time.time()
            r = subprocess.run([L, "600", "6144", "bun", f"/private/tmp/bend-opt/clo/{v}/bend2/main.ts", f, "-o", f"/private/tmp/bend-opt/clo/scratch/build/ct_{v}.c"],
                               cwd=os.path.dirname(f), capture_output=True)
            dt = time.time() - t
            best[v] = min(best.get(v, 1e9), dt) if r.returncode == 0 else float("nan")
    for v in tot: tot[v] += best[v]
    print(f"{os.path.relpath(f, '/Users/macolas/Software'):70} int {best['int']:6.2f}s elim {best['elim']:6.2f}s {100*(best['elim']-best['int'])/best['int']:+5.1f}%", flush=True)
print(f"total int {tot['int']:.1f}s elim {tot['elim']:.1f}s {100*(tot['elim']-tot['int'])/tot['int']:+.1f}%")
