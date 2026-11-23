#!/usr/bin/env python3
# emit244.py ROOT TAG: (each emit one call of tools/heavy.sh, 4096 MB) bend-benchmarks' 244 programs to W/c/TAG/<name>.c (cwd = the program's dir)
import concurrent.futures as cf, os, subprocess, sys
BB = "/Users/macolas/Software/bend-benchmarks"; W = "/private/tmp/bend-opt/par/b244"
def programs():
    out = []
    for d, _, fs in os.walk(BB):
        if "/.git" in d or "/reference" in d or "/tools" in d: continue
        out += [os.path.join(d, f) for f in fs if f.endswith(".bend")]
    return sorted(out)
name = lambda p: os.path.relpath(p, BB).replace("/", "__")[:-5]
root, tag = sys.argv[1], sys.argv[2]
j = 1  # one heavy process at a time (memory rules)
os.makedirs(f"{W}/c/{tag}", exist_ok=True)
def emit(p):
    dst = f"{W}/c/{tag}/{name(p)}.c"
    if os.path.exists(dst): return "cached"
    env = dict(os.environ, BUN_JSC_forceRAMSize="3000000000")
    r = subprocess.run(["/Users/macolas/Software/bend-benchmarks/tools/heavy.sh", "900", "4096", "--",
                        "bun", f"{root}/bend2/main.ts", p, "-o", dst + ".tmp.c"], cwd=os.path.dirname(p), capture_output=True, text=True, env=env)
    if r.returncode == 0 and os.path.exists(dst + ".tmp.c"): os.rename(dst + ".tmp.c", dst); return "ok"
    open(dst[:-2] + ".emitfail", "w").write(r.stdout[-2000:] + r.stderr[-2000:]); return "FAIL"
ps = programs(); print(len(ps))
with cf.ThreadPoolExecutor(j) as ex:
    for p, st in zip(ps, ex.map(emit, ps)):
        if st == "FAIL": print("EMITFAIL", name(p), flush=True)
print("done", tag)
