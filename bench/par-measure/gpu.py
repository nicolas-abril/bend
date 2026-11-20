#!/usr/bin/env python3
"""The Metal lane: wall time with the GPU on, and a split of a run.

    gpu.py run   DIR [--rounds 5] [--out gpu.jsonl]
    gpu.py split DIR [--out gpu_split.jsonl]

DIR holds, per program X, the user binary X (built with `bend X.bend -o X`,
which also writes X.gpu) and for `split` a counted Metal build cnt_X (see
README). `run` does one warm run (a cold first run pays seconds in Metal's
setup; the perf gate warms each cell too) and then --rounds timed runs of
`X +RTS --gpu SPAN -RTS`, SPAN being the perf gate's MEMORY entry for the
bench (else "on"), through tm. `split` runs cnt_X once warm and once
measured and keeps the counted line: device probe, pipeline load, passes,
command buffers, the GPU's own busy time, the host's wait. The busy time
sums GPUEndTime - GPUStartTime over command buffers, and up to three are in
flight, so it can exceed the passes' wall time (overlap is counted twice).
Each run waits until other processes use under 2.5 cores (added after the
2026-11-20 run, which had no gate).
"""
import argparse, json, os, re, subprocess, sys, time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scale import others_cpu, wait_quiet

WORK = os.environ.get("PAR_WORK", "/private/tmp/bend-opt/par-work")
TM = os.path.join(WORK, "tm")
MEMORY = {"tree-bitonic": "768MB", "gameoflife": "512MB", "kmeans": "768MB",
          "mandelbrot": "512MB", "merkle": "768MB", "nbody": "768MB",
          "queens": "512MB", "raytrace": "512MB", "symreg": "512MB",
          "terrain": "1GB"}


def span(name):
    for k, v in MEMORY.items():
        if name.endswith(k):
            return v
    return "on"


def tm(exe, args, env=None):
    wait_quiet(2.5, 10800, False)
    load = os.getloadavg()[0]
    others = others_cpu()
    p = subprocess.run([TM, exe] + args, capture_output=True, text=True,
                       timeout=300, env=env)
    line = ([l for l in p.stderr.splitlines() if l.startswith("rc=")] or [""])[-1]
    rec = {k: (float(v) if re.match(r"^-?[\d.]+$", v) else v)
           for k, v in (kv.split("=") for kv in line.split())}
    rec["load"] = load
    rec["others"] = others
    rec["out"] = (p.stdout.strip().splitlines() or [""])[-1]
    return rec


def names(d):
    return sorted(f for f in os.listdir(d) if os.access(os.path.join(d, f), os.X_OK)
                  and not f.startswith("cnt_") and "." not in f
                  and os.path.exists(os.path.join(d, f + ".gpu")))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["run", "split"])
    ap.add_argument("dir")
    ap.add_argument("--rounds", type=int, default=5)
    ap.add_argument("--out")
    a = ap.parse_args()
    out = open(a.out or os.path.join(WORK, "gpu_%s.jsonl" % a.cmd), "a")
    for n in names(a.dir):
        exe = os.path.join(a.dir, n)
        rts = ["+RTS", "--gpu", span(n), "-RTS"]
        if a.cmd == "run":
            tm(exe, rts)
            for r in range(a.rounds):
                rec = tm(exe, rts)
                rec.update(prog=n, span=span(n), round=r, time=time.time())
                out.write(json.dumps(rec) + "\n")
                out.flush()
        else:
            cnt = os.path.join(a.dir, "cnt_" + n)
            if not os.path.exists(cnt):
                continue
            path = os.path.join(WORK, "gpu_split.tmp")
            env = dict(os.environ, PAR_COUNT_OUT=path)
            tm(cnt, rts, env)
            for r in range(a.rounds):
                if os.path.exists(path):
                    os.remove(path)
                rec = tm(cnt, rts, env)
                d = json.loads(open(path).read().splitlines()[-1])
                d.pop("per_thread", None)
                rec.update(prog=n, span=span(n), round=r, count=d)
                out.write(json.dumps(rec) + "\n")
                out.flush()


if __name__ == "__main__":
    main()
