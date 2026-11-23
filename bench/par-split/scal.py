#!/usr/bin/env python3 -I
# scal.py OUT.jsonl --builds a,b --progs x,y --threads 1,2,4,10 --rounds 5 --group G
# Binaries are W/bin/<build>/<prog>; W/bin/<build>/.names maps prog -> source path (for expected.txt).
# One lock acquisition per group of programs (all builds x threads x rounds, interleaved).
import argparse, json, os, subprocess, sys, time, tempfile
H = os.path.dirname(os.path.abspath(__file__))
W = "/private/tmp/bend-opt/par/work"
B = "/Users/macolas/Software/bend-benchmarks"
ap = argparse.ArgumentParser()
ap.add_argument("out"); ap.add_argument("--builds"); ap.add_argument("--progs")
ap.add_argument("--threads", default="1,2,4,10"); ap.add_argument("--rounds", type=int, default=5)
ap.add_argument("--group", type=int, default=1)
a = ap.parse_args()
names = {}
for b in a.builds.split(","):
    for l in open(f"{W}/bin/{b}/.names"):
        n, p = l.split(); names[n] = p
def expected(p):
    d = os.path.dirname(os.path.join(B, p))
    for e in (f"{d}/expected.txt", f"{os.path.dirname(d)}/expected.txt"):
        if os.path.exists(e): return open(e).read()
ps = a.progs.split(",")
for gi in range(0, len(ps), a.group):
    grp = ps[gi:gi + a.group]
    jobs = []
    for n in grp:
        for r in range(a.rounds):
            for t in a.threads.split(","):
                for b in a.builds.split(","):
                    exe = f"{W}/bin/{b}/{n}"
                    if os.path.exists(exe):
                        jobs.append({"exe": exe, "threads": int(t), "meta": [n, b, int(t), r]})
    jf = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, dir=W); json.dump(jobs, jf); jf.close()
    p = subprocess.run(["lockf", "/private/tmp/bend-opt/timing.lock", os.path.expanduser("~/Software/supgen-bend/limit"), str(60 + 30 * len(jobs)), "5120",
                        "python3", "-I", f"{H}/batch.py", jf.name], capture_output=True, text=True)
    os.unlink(jf.name)
    with open(a.out, "a") as f:
        for line in p.stdout.splitlines():
            rec = json.loads(line)
            n_, b, t, r = rec.pop("meta")
            want = expected(names[n_])
            rec["ok"] = want is not None and rec.get("out") == want
            rec.pop("out", None)
            rec.update(prog=n_, build=b, threads=t, round=r, t=time.time())
            f.write(json.dumps(rec) + "\n")
    print(",".join(grp), "done", len(p.stdout.splitlines()), "runs", flush=True)
