#!/usr/bin/env python3
"""Interleaved runs of several variants at several thread counts.

    ab.py --out FILE [--rounds 5] [--threads 1,2,4,8,def] [--max-load 3]
          LABEL=COMMAND [LABEL=COMMAND ...]

A COMMAND with `{n}` in it gets the thread count there (`def` becomes the
CPU count); one without gets `+RTS --threads N --gpu off -RTS` appended (no
--threads for `def`). Each round runs every (thread count, variant) once,
the variants innermost, through tm; one JSON line a run. `ab.py --table
FILE` prints medians, min-max and the medians of user, sys, context
switches, P-core share and runnable time.
"""
import argparse, json, os, re, shlex, statistics, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from scale import TM, ensure_tm, wait_quiet, others_cpu


def run(cmd, timeout=300):
    load = os.getloadavg()[0]
    others = others_cpu()
    try:
        p = subprocess.run([TM] + cmd, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"rc": "timeout", "load": load}
    line = ([l for l in p.stderr.splitlines() if l.startswith("rc=")] or [""])[-1]
    rec = {k: (float(v) if re.match(r"^-?[\d.]+$", v) else v)
           for k, v in (kv.split("=") for kv in line.split())}
    rec["load"] = load
    rec["others"] = others
    rec["out"] = (p.stdout.strip().splitlines() or [""])[-1]
    return rec


def table(path):
    rs = [json.loads(l) for l in open(path) if l.strip()]
    g = {}
    for r in rs:
        if r.get("rc") == 0:
            g.setdefault((r["label"], r["threads"]), []).append(r)
    med = statistics.median
    print("| variant | threads | wall ms med (min-max) | n | user | sys | vcsw | ivcsw | P% | runnable | load/others | out |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    order = []
    for r in rs:
        k = (r["label"], r["threads"])
        if k not in order:
            order.append(k)
    for k in sorted(order, key=lambda k: (order.index((k[0], order[0][1])) if (k[0], order[0][1]) in order else 0, k)):
        if k not in g:
            continue
        v = g[k]
        w = [x["wall_ms"] for x in v]
        pu = [100 * x.get("puser_ms", 0) / max(x["user_ms"], 1e-9) for x in v]
        outs = sorted(set(x["out"] for x in v))
        print(f"| {k[0]} | {k[1]} | {med(w):.1f} ({min(w):.1f}-{max(w):.1f}) | {len(v)}"
              f" | {med([x['user_ms'] for x in v]):.0f} | {med([x['sys_ms'] for x in v]):.0f}"
              f" | {med([x['vcsw'] for x in v]):.0f} | {med([x['ivcsw'] for x in v]):.0f}"
              f" | {med(pu):.0f} | {med([x.get('runnable_ms', 0) for x in v]):.0f}"
              f" | {med([x['load'] for x in v]):.1f}/{med([x.get('others', 0) for x in v]):.1f} | {' '.join(outs)} |")
    bad = [r for r in rs if r.get("rc") != 0]
    if bad:
        print(f"{len(bad)} failed runs", file=sys.stderr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--rounds", type=int, default=5)
    ap.add_argument("--threads", default="1,2,4,8,def")
    ap.add_argument("--max-load", type=float, default=1e9)
    ap.add_argument("--max-wait", type=float, default=1800)
    ap.add_argument("--table", action="store_true")
    ap.add_argument("variants", nargs="*")
    a = ap.parse_args()
    if a.table:
        return table(a.out)
    ensure_tm()
    vs = [v.split("=", 1) for v in a.variants]
    ncpu = os.cpu_count()
    with open(a.out, "a") as f:
        for rnd in range(a.rounds):
            for t in a.threads.split(","):
                for label, cmd in vs:
                    n = str(ncpu) if t == "def" else t
                    if "{n}" in cmd:
                        argv = shlex.split(cmd.replace("{n}", n))
                    else:
                        argv = shlex.split(cmd) + ["+RTS"] + \
                            ([] if t == "def" else ["--threads", t]) + ["--gpu", "off", "-RTS"]
                    wait_quiet(a.max_load, a.max_wait, False)
                    rec = run(argv)
                    rec.update(label=label, threads=t, round=rnd, time=time.time())
                    f.write(json.dumps(rec) + "\n")
                    f.flush()


if __name__ == "__main__":
    main()
