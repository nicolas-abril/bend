#!/usr/bin/env python3
"""Tables from scale.py's runs.

    report.py scale FILE [--builds main,int,r2207]
        per program and build: median wall at each thread count, speedup
        over one thread (S1) and over the sequential twin at one thread
        (Sseq, when there is one), and at the default count: sys, voluntary
        and involuntary switches, P-core share of user time, runnable time,
        spread (max/min) and the load range of its runs. Ready-not-running is
        runnable time less user and sys (RUSAGE runnable time includes the
        time on a core): the threads' time waiting for a core.
    report.py builds FILE
        main against the other builds, per program and thread count:
        wall ratio (build / main) of the medians, and geometric means.

Runs marked busy (other processes over the gate during the run) are left
out; so are failed runs.
"""
import json, math, statistics, sys
from collections import defaultdict

THREADS = ["1", "2", "4", "8", "def"]


def load(path):
    rs = [json.loads(l) for l in open(path) if l.strip()]
    return [r for r in rs if r.get("rc") == 0 and not r.get("busy") and "wall_ms" in r]


def groups(rs):
    g = defaultdict(list)
    for r in rs:
        g[(r["prog"], r["build"], r["threads"])].append(r)
    return g


def med(v, k):
    return statistics.median([x[k] for x in v])


def scale(path, builds):
    g = groups(load(path))
    progs = sorted({k[0] for k in g if not k[0].startswith("koru-seq/")})
    print("| program | build | " + " | ".join(f"{t} ms" for t in THREADS)
          + " | S1 at 2/4/8/def | Sseq at 1/def | sys ms def | vcsw/ivcsw def | P% 1/def | ready-not-running ms def | spread def | load def |")
    print("|---" * 12 + "|")
    for p in progs:
        twin = None
        if p.startswith("koru-par/"):
            twin = "koru-seq/" + p.split("/", 1)[1]
        elif p == "x/fork_wake_par":
            twin = "x/fork_wake_seq"
        for b in builds:
            w = {t: med(g[(p, b, t)], "wall_ms") for t in THREADS if g.get((p, b, t))}
            if not w:
                continue
            d = g.get((p, b, "def"), [])
            one = g.get((p, b, "1"), [])
            s1 = "/".join(f"{w['1'] / w[t]:.2f}" if "1" in w and t in w else "-"
                          for t in ["2", "4", "8", "def"])
            sseq = "-"
            if twin and g.get((twin, b, "1")):
                ts = med(g[(twin, b, "1")], "wall_ms")
                sseq = "/".join(f"{ts / w[t]:.2f}" if t in w else "-" for t in ["1", "def"])
            pc = lambda v: 100 * statistics.median(
                [x.get("puser_ms", 0) / max(x["user_ms"], 1e-9) for x in v]) if v else float("nan")
            ws = [x["wall_ms"] for x in d]
            ld = [x["load"] for x in d]
            print(f"| {p} | {b} | " + " | ".join(f"{w[t]:.1f}" if t in w else "-" for t in THREADS)
                  + f" | {s1} | {sseq}"
                  + (f" | {med(d, 'sys_ms'):.0f} | {med(d, 'vcsw'):.0f}/{med(d, 'ivcsw'):.0f}"
                     f" | {pc(one):.0f}/{pc(d):.0f} | {statistics.median([x.get('runnable_ms', 0) - x['user_ms'] - x['sys_ms'] for x in d]):.0f}"
                     f" | {max(ws) / min(ws):.2f} | {min(ld):.1f}-{max(ld):.1f} |" if d else " | - | - | - | - | - | - |"))


def builds(path):
    g = groups(load(path))
    bs = sorted({k[1] for k in g} - {"main"})
    progs = sorted({k[0] for k in g})
    logs = defaultdict(list)
    print("| program | " + " | ".join(f"{b}/main at {t}" for b in bs for t in THREADS) + " |")
    print("|---" * (1 + len(bs) * len(THREADS)) + "|")
    for p in progs:
        cells = []
        for b in bs:
            for t in THREADS:
                if g.get((p, "main", t)) and g.get((p, b, t)):
                    r = med(g[(p, b, t)], "wall_ms") / med(g[(p, "main", t)], "wall_ms")
                    cells.append(f"{r:.2f}")
                    grp = p.split("/")[0]
                    logs[(grp, b, t)].append(math.log(r))
                else:
                    cells.append("-")
        print(f"| {p} | " + " | ".join(cells) + " |")
    print()
    print("| group | build | " + " | ".join(f"geomean at {t}" for t in THREADS) + " |")
    print("|---" * (2 + len(THREADS)) + "|")
    for grp in sorted({k[0] for k in logs}):
        for b in bs:
            print(f"| {grp} | {b}/main | " + " | ".join(
                f"{math.exp(statistics.mean(logs[(grp, b, t)])):.3f}" if logs.get((grp, b, t)) else "-"
                for t in THREADS) + " |")


if __name__ == "__main__":
    if sys.argv[1] == "scale":
        bl = sys.argv[sys.argv.index("--builds") + 1].split(",") if "--builds" in sys.argv else ["main", "int", "r2207"]
        scale(sys.argv[2], bl)
    else:
        builds(sys.argv[2])
