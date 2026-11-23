#!/usr/bin/env python3
"""meas230.py BASE_DIR NEW_DIR OUT [--reps 5] [--only LIST]: every program whose
C differs (cdiff's normalisation) is built from both C files and run REPS times
at one thread, the two builds interleaved; instructions from run 1, cycles
median; outputs checked against expected.txt. parallel-ml / bend-par ports also
run once at 10 threads. One run at a time, each through limit."""
import json, os, re, subprocess, sys, statistics
sys.path.insert(0, os.path.dirname(__file__))
BB = "/Users/macolas/Software/bend-benchmarks"
LIMIT = os.path.expanduser("~/Software/supgen-bend/limit")
a = sys.argv[1:]
base, new, out = a[0], a[1], a[2]
reps = int(a[a.index("--reps") + 1]) if "--reps" in a else 5
only = set(open(a[a.index("--only") + 1]).read().split()) if "--only" in a else None
spec = __import__("importlib.util").util.spec_from_file_location("cd", os.path.join(os.path.dirname(__file__), "cdiff.py"))


def norm(t):
    t = re.sub(r"// A hole is a field's word.*?\n// pushes one \[R, hole, FID\]\) and makes R's field J the hole\.\n", "", t, flags=re.S)
    t = re.sub(r"#define DST_PUT\(H, X\) do \{.*?\} while \(0\)\n", "", t, flags=re.S)
    t = re.sub(r"#define WL_DEST\(R, J, S\) do \{.*?\} while \(0\)\n", "", t, flags=re.S)
    return re.sub(r"#ifdef FID_Dst_put\n.*?#endif\n", "", t, flags=re.S)


def expected(rel):
    d = os.path.dirname(os.path.join(BB, rel))
    for e in [os.path.join(d, "expected.txt"), os.path.join(os.path.dirname(d), "expected.txt")]:
        if os.path.exists(e):
            return open(e).read().rstrip("\n")


def run(b, cwd, t):
    r = subprocess.run([LIMIT, "300", "6144", "/usr/bin/time", "-l", b, "+RTS", "--threads", str(t), "--gpu", "off", "-RTS"],
                       cwd=cwd, capture_output=True, text=True, errors="replace")
    g = lambda k: (lambda m: int(m.group(1)) if m else None)(re.search(r"(\d+)\s+" + k, r.stderr))
    return r.stdout.rstrip("\n"), g("instructions retired"), g("cycles elapsed"), g("maximum resident set size"), r.returncode


done = set()
if os.path.exists(out):
    done = {json.loads(l)["name"] for l in open(out)}
os.makedirs("/private/tmp/bend-opt/gen/bin", exist_ok=True)
for f in sorted(os.listdir(new)):
    if not f.endswith(".c"):
        continue
    n = f[:-2]
    if n in done or (only is not None and n not in only):
        continue
    fb, fn = os.path.join(base, f), os.path.join(new, f)
    if not os.path.exists(fb) or open(fb).read() == norm(open(fn).read()):
        continue
    rel = n.replace("__", "/") + ".bend"
    cwd = os.path.dirname(os.path.join(BB, rel))
    want = expected(rel)
    bins = {}
    for k, c in (("base", fb), ("new", fn)):
        b = f"/private/tmp/bend-opt/gen/bin/{n}.{k}"
        subprocess.run([LIMIT, "900", "6144", "cc", "-std=c11", "-O3", "-w", c, "-o", b, "-lpthread", "-lm"], check=True)
        bins[k] = b
    res = {k: {"ins": None, "cyc": [], "rss": None, "ok": True} for k in bins}
    for i in range(reps):
        for k, b in bins.items():
            o, ins, cyc, rss, rc = run(b, cwd, 1)
            res[k]["ok"] &= rc == 0 and (want is None or o == want)
            res[k]["cyc"].append(cyc)
            if i == 0:
                res[k]["ins"], res[k]["rss"] = ins, rss
    if rel.startswith("parallel-ml/") or "/bend-par/" in rel:
        for k, b in bins.items():
            o, ins, cyc, rss, rc = run(b, cwd, 10)
            res[k]["ok10"] = rc == 0 and (want is None or o == want)
    for k in res:
        res[k]["cycm"] = statistics.median(c for c in res[k]["cyc"] if c)
    line = {"name": n, **res}
    open(out, "a").write(json.dumps(line) + "\n")
    print(n, res["base"]["ins"], res["new"]["ins"], round(res["new"]["ins"] / res["base"]["ins"] - 1, 4),
          round(res["new"]["cycm"] / res["base"]["cycm"] - 1, 4), res["base"]["ok"], res["new"]["ok"], flush=True)
