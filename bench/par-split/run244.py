#!/usr/bin/env python3
# run244.py TAG [--batch 30] [--threads 1,10] [--filter S] [--cflags ".."] [--reps 1]: build W/c/TAG/*.c to
# W/bin/TAG, run each at each thread count in lock batches (instructions and cycles from /usr/bin/time -l),
# check stdout against expected.txt. Appends JSON lines to W/res/TAG.jsonl.
import json, os, re, subprocess, sys
W = "/private/tmp/bend-opt/par/b244"; BB = "/Users/macolas/Software/bend-benchmarks"
LIMIT = os.path.expanduser("~/Software/supgen-bend/limit"); LOCK = "/private/tmp/bend-opt/timing.lock"
a = sys.argv[1:]
opt = lambda k, d: (a.pop(a.index(k) + 1), a.remove(k))[0] if k in a else d
batch, ths, filt, cfl = int(opt("--batch", "30")), opt("--threads", "1,10").split(","), opt("--filter", ""), opt("--cflags", "")
reps = int(opt("--reps", "1"))
tag = a[0]; btag = opt("--as", tag) if False else tag
os.makedirs(f"{W}/bin/{tag}", exist_ok=True); os.makedirs(f"{W}/res", exist_ok=True)
names = sorted(f[:-2] for f in os.listdir(f"{W}/c/{tag}") if f.endswith(".c") and not f.endswith(".tmp.c") and filt in f)
for n in names:
    b = f"{W}/bin/{tag}/{n}"
    if not os.path.exists(b):
        r = subprocess.run(["lockf", LOCK, LIMIT, "600", "5120", "cc", "-std=c11", "-O3", "-w"] + cfl.split() + [f"{W}/c/{tag}/{n}.c", "-o", b, "-lpthread", "-lm"], capture_output=True, text=True)
        if r.returncode: print("CCFAIL", n, r.stderr[-300:], flush=True)
def expected(n):
    p = os.path.join(BB, n.replace("__", "/") + ".bend"); d = os.path.dirname(p)
    for e in (f"{d}/expected.txt", f"{os.path.dirname(d)}/expected.txt"):
        if os.path.exists(e): return open(e).read().rstrip("\n")
names = [n for n in names if os.path.exists(f"{W}/bin/{tag}/{n}")]
for i in range(0, len(names), batch):
    grp = names[i:i + batch]; lines = []
    for n in grp:
        cwd = os.path.dirname(os.path.join(BB, n.replace("__", "/")))
        for r in range(reps):
            for t in ths:
                lines.append(f"cd {cwd}; echo '@@ {n} {t} {r}'; /usr/bin/time -l {W}/bin/{tag}/{n} +RTS --threads {t} --gpu off -RTS > {W}/o.$$ 2> {W}/e.$$; echo rc=$?; cat {W}/e.$$; echo '@@out'; head -c 200000 {W}/o.$$; echo")
    p = subprocess.run(["lockf", LOCK, LIMIT, str(120 * len(lines) + 60), "5120", "bash", "-c", "uptime; " + "\n".join(lines)], capture_output=True, text=True, errors="replace")
    up = p.stdout.split("\n", 1)[0]
    with open(f"{W}/res/{tag}.jsonl", "a") as f:
        for blk in p.stdout.split("@@ ")[1:]:
            hd = blk.split("\n", 1)[0].split(); n, t, r = hd[0], int(hd[1]), int(hd[2])
            g = lambda k: (lambda m: int(m.group(1)) if m else None)(re.search(r"(\d+)\s+" + k, blk))
            wall = re.search(r"([\d.]+) real", blk); rc = re.search(r"rc=(\d+)", blk)
            out = blk.split("@@out\n", 1)[1].rstrip("\n") if "@@out\n" in blk else ""
            want = expected(n)
            f.write(json.dumps({"prog": n, "tag": tag, "threads": t, "rep": r, "rc": int(rc.group(1)) if rc else None,
                "ok": want is not None and out == want, "ins": g("instructions retired"), "cyc": g("cycles elapsed"),
                "wall": float(wall.group(1)) if wall else None, "uptime": up}) + "\n")
    print(f"batch {i // batch} done ({len(grp)}) {up}", flush=True)
