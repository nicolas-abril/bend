#!/usr/bin/env python3
"""emit.py: compile every benchmark program to C with each variant (no run).

  emit.py VARIANT [VARIANT..] [-j N]

Each variant is a bend2 checkout at /private/tmp/bend-opt/m230/<VARIANT>; the C
goes to /private/tmp/bend-opt/m230/c/<VARIANT>/<name>.c, where <name> is the
program's path in bend-benchmarks with '/' as '__' (as run.py names it). Each
compile runs as run.py's does (bun bend2/main.ts f -o x.c, cwd = the program's
directory). An existing .c is kept. SMOL=1 runs bun --smol (perceus/deriv
needs over 6 GB without it on the integration+observe branch). The caller wraps this in `limit`.
"""
import concurrent.futures as cf, os, subprocess, sys

M = "/private/tmp/bend-opt/clo/m230"
BB = "/Users/macolas/Software/bend-benchmarks"


def programs():
    out = []
    for d, _, fs in os.walk(BB):
        if "/.git" in d or "/reference" in d or "/tools" in d:
            continue
        out += [os.path.join(d, f) for f in fs if f.endswith(".bend")]
    return sorted(out)


def name_of(p):
    return os.path.relpath(p, BB).replace("/", "__")[:-5]


def emit(var, p):
    dst = f"{M}/c/{var}/{name_of(p)}.c"
    if os.path.exists(dst):
        return "cached"
    tmp = dst + ".tmp.c"
    lim = [os.path.expanduser("~/Software/supgen-bend/limit"), "600", os.environ.get("EMIT_MB", "6144")]
    cmd = lim + ["bun", f"/private/tmp/bend-opt/clo/{var}/bend2/main.ts", p, "-o", tmp]
    r = subprocess.run(cmd, cwd=os.path.dirname(p), capture_output=True, text=True, timeout=700)
    if r.returncode == 137:
        # over the cap: JSC's heap sized down, the same output
        r = subprocess.run(cmd, cwd=os.path.dirname(p), capture_output=True, text=True, timeout=700,
                           env={**os.environ, "BUN_JSC_forceRAMSize": "3000000000"})
    if r.returncode == 0 and os.path.exists(tmp):
        os.rename(tmp, dst)
        return "ok"
    open(dst[:-2] + ".emitfail", "w").write(f"{r.returncode}\n{r.stdout}\n{r.stderr}")
    return "FAIL"


if __name__ == "__main__":
    a = sys.argv[1:]
    j = int(a[a.index("-j") + 1]) if "-j" in a else 1
    vs = [x for i, x in enumerate(a) if x != "-j" and (i == 0 or a[i - 1] != "-j")]
    ps = programs()
    for v in vs:
        os.makedirs(f"{M}/c/{v}", exist_ok=True)
        with cf.ThreadPoolExecutor(j) as ex:
            for p, st in zip(ps, ex.map(lambda p: emit(v, p), ps)):
                if st == "FAIL":
                    print("EMITFAIL", v, name_of(p), flush=True)
        print("done", v, flush=True)
