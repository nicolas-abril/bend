#!/usr/bin/env python3
"""Thread-scaling runner for bend's CPU lane.

    scale.py build --builds main=/path/to/bend,int=/path/... [--only RE] [-j 4]
    scale.py run   --builds main,int --threads 1,2,4,8,def --rounds 5 \
                   [--only RE] [--out runs.jsonl] [--timeout 120]
    scale.py table [--out runs.jsonl] [--base main]

`build` emits each program's C with each build's compiler and compiles it
(build.sh) into $PAR_BIN/<build>/<program>. `run` runs every (program,
thread count, build) once per round, the builds innermost so that they are
interleaved, each through `tm` (wall, user, sys, context switches, P-core
share, runnable time), and appends one JSON line a run with the 1-minute
load average read just before it. A thread count `def` passes no --threads
(the runtime's default, the CPU count). `table` prints medians and spreads.
The sources of bench/ and demos/ come from $PAR_SRC (a bend checkout;
default: the first build's root), so every build runs the same program.
"""
import argparse, json, os, re, statistics, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import progs as P

WORK = os.environ.get("PAR_WORK", "/private/tmp/bend-opt/par-work")
BIN = os.environ.get("PAR_BIN", os.path.join(WORK, "bin"))
TM = os.path.join(WORK, "tm")


def parse_builds(s):
    out = {}
    for kv in s.split(","):
        k, _, v = kv.partition("=")
        out[k] = v
    return out


def ensure_tm():
    if not os.path.exists(TM):
        subprocess.check_call(["cc", "-O2", os.path.join(HERE, "tm.c"), "-o", TM])


def program_set(args, roots):
    src = os.environ.get("PAR_SRC") or next(iter(roots.values()))
    ps = P.programs(src)
    if args.only:
        ps = {k: v for k, v in ps.items() if re.search(args.only, k)}
    return ps


def cmd_build(args):
    roots = parse_builds(args.builds)
    ps = program_set(args, roots)
    jobs = []
    for b, root in roots.items():
        for name, (src, _, _, _) in ps.items():
            out = os.path.join(BIN, b, name.replace("/", "__"))
            if args.force or not os.path.exists(out):
                jobs.append((b, name, root, src, out))

    def one(j):
        b, name, root, src, out = j
        r = subprocess.run([os.path.join(HERE, "build.sh"), root, src, out],
                           capture_output=True, text=True)
        return j, r.returncode

    with ThreadPoolExecutor(args.j) as ex:
        for (b, name, *_), rc in ex.map(one, jobs):
            print(("ok  " if rc == 0 else "FAIL") + f" {b} {name}", flush=True)


def run_one(exe, threads, timeout):
    rts = ["+RTS"] + ([] if threads == "def" else ["--threads", str(threads)]) \
        + ["--gpu", "off", "-RTS"]
    load = os.getloadavg()[0]
    others = others_cpu()
    try:
        p = subprocess.run([TM, exe] + rts, capture_output=True, text=True,
                           timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"rc": "timeout", "load": load}
    # tm's line is the last line of stderr that starts with rc=
    line = ([l for l in p.stderr.splitlines() if l.startswith("rc=")] or [""])[-1]
    rec = {k: (float(v) if re.match(r"^-?[\d.]+$", v) else v)
           for k, v in (kv.split("=") for kv in line.split())}
    rec["load"] = load
    rec["out"] = (p.stdout.strip().splitlines() or [""])[-1]
    return rec


def others_cpu():
    """Cores in use by processes outside this run's process group (ps %CPU)."""
    me = os.getpgrp()
    out = subprocess.run(["ps", "-A", "-o", "pgid=,pcpu="], capture_output=True,
                         text=True).stdout
    tot = 0.0
    for line in out.splitlines():
        g, c = line.split()
        if int(g) != me:
            tot += float(c)
    return tot / 100.0


def wait_quiet(max_load, max_wait, log):
    """Wait (up to max_wait s) until other processes use under max_load cores.

    The 1-minute load average is not used: this run's own threads raise it.
    """
    t0 = time.time()
    while others_cpu() > max_load and time.time() - t0 < max_wait:
        time.sleep(15)
    waited = time.time() - t0
    if waited > 1 and log:
        print("waited %.0f s; others at %.1f cores" % (waited, others_cpu()), flush=True)


def cmd_run(args):
    ensure_tm()
    builds = args.builds.split(",")
    roots = {b: None for b in builds}
    src = os.environ.get("PAR_SRC", "/private/tmp/bend-opt/par-main")
    os.environ["PAR_SRC"] = src
    ps = program_set(args, {"x": src})
    threads = args.threads.split(",")
    with open(args.out, "a") as f:
        for rnd in range(args.rounds):
            for name, (_, want, group, twin) in ps.items():
                for t in threads:
                    for b in builds:
                        exe = os.path.join(BIN, b, name.replace("/", "__"))
                        if not os.path.exists(exe):
                            continue
                        if group == "koru-seq" or name == "x/fork_wake_seq":
                            if t not in ("1", "def"):
                                continue
                        wait_quiet(args.max_load, args.max_wait, args.verbose)
                        rec = run_one(exe, t, args.timeout)
                        rec.update(prog=name, build=b, threads=t, round=rnd,
                                   time=time.time())
                        if want is not None and rec.get("out") != want:
                            rec["wrong"] = want
                        f.write(json.dumps(rec) + "\n")
                        f.flush()
                        if args.verbose:
                            print(name, b, t, rec.get("wall_ms"),
                                  "load %.1f" % rec["load"], flush=True)


def load_runs(path):
    return [json.loads(l) for l in open(path) if l.strip()]


def cmd_table(args):
    runs = [r for r in load_runs(args.out) if r.get("rc") == 0]
    if args.only:
        runs = [r for r in runs if re.search(args.only, r["prog"])]
    key = lambda r: (r["prog"], r["build"], r["threads"])
    groups = {}
    for r in runs:
        groups.setdefault(key(r), []).append(r)
    med = lambda xs: statistics.median(xs) if xs else float("nan")
    rows = sorted(groups)
    print("| program | build | threads | wall ms med (min-max) | n | user ms | sys ms"
          " | vcsw | ivcsw | P-core user % | runnable ms | load |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for k in rows:
        g = groups[k]
        w = [r["wall_ms"] for r in g]
        pu = [100 * r.get("puser_ms", 0) / max(r["user_ms"], 1e-9) for r in g]
        print(f"| {k[0]} | {k[1]} | {k[2]} | {med(w):.1f} ({min(w):.1f}-{max(w):.1f})"
              f" | {len(g)} | {med([r['user_ms'] for r in g]):.0f}"
              f" | {med([r['sys_ms'] for r in g]):.0f}"
              f" | {med([r['vcsw'] for r in g]):.0f}"
              f" | {med([r['ivcsw'] for r in g]):.0f}"
              f" | {med(pu):.0f}"
              f" | {med([r.get('runnable_ms', 0) for r in g]):.0f}"
              f" | {med([r['load'] for r in g]):.1f} |")
    bad = [r for r in load_runs(args.out) if r.get("rc") != 0 or "wrong" in r]
    for r in bad:
        print("BAD", r["prog"], r["build"], r["threads"], r.get("rc"),
              r.get("out"), r.get("wrong"), file=sys.stderr)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["build", "run", "table"])
    ap.add_argument("--builds", default="main")
    ap.add_argument("--only")
    ap.add_argument("--threads", default="1,2,4,8,def")
    ap.add_argument("--rounds", type=int, default=3)
    ap.add_argument("--timeout", type=float, default=120)
    ap.add_argument("--out", default=os.path.join(WORK, "runs.jsonl"))
    ap.add_argument("-j", type=int, default=4)
    ap.add_argument("--max-load", type=float, default=1e9,
                    help="pause before a run while other processes use more cores than this")
    ap.add_argument("--max-wait", type=float, default=600,
                    help="the longest pause (s); the run then goes ahead")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("-v", "--verbose", action="store_true")
    a = ap.parse_args()
    {"build": cmd_build, "run": cmd_run, "table": cmd_table}[a.cmd](a)
