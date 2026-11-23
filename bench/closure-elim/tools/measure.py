#!/usr/bin/env python3
"""measure.py: build, check and time every program whose C differs from main's.

  measure.py VARIANT.. [--filter S] [--reps 5] [--out FILE]

For each of the 230 programs, the distinct C files among main and VARIANT..
(from /private/tmp/bend-opt/m230/c/<variant>/<name>.c, by content hash). A
program whose every variant's C equals main's is skipped. Each distinct C is
built once (cc -std=c11 -O3 -w, as run.py) and run REPS times at one thread
under /usr/bin/time -l, the distinct builds interleaved run by run; each run's
output is checked against expected.txt. Programs in parallel-ml/ and
osprey/*/bend-par/ also run once at --threads 10 and are checked. Every run
goes through `limit` (timeout, 6 GB cap); one run at a time.

Results: one JSON line per (program, C hash) appended to FILE (default
/private/tmp/bend-opt/m230/meas.jsonl); a (program, hash) already there is
skipped, so the script resumes.
"""
import hashlib, json, os, re, subprocess, sys

M = "/private/tmp/bend-opt/clo/m230"
BB = "/Users/macolas/Software/bend-benchmarks"
LIMIT = os.path.expanduser("~/Software/supgen-bend/limit")
sys.path.insert(0, os.path.dirname(__file__))
from emit import programs, name_of


def expected_for(p):
    d = os.path.dirname(p)
    for e in [os.path.join(d, "expected.txt"), os.path.join(os.path.dirname(d), "expected.txt")]:
        if os.path.exists(e):
            return open(e).read().rstrip("\n")
    return None


def is_par(rel):
    return rel.startswith("parallel-ml/") or re.match(r"osprey/[^/]+/bend-par/", rel) is not None


def run(binp, cwd, threads, secs=120):
    cmd = [LIMIT, str(secs), "6144", "/usr/bin/time", "-l", binp, "+RTS", "--threads", str(threads), "--gpu", "off", "-RTS"]
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, errors="replace")
    g = lambda k: (lambda m: int(m.group(1)) if m else None)(re.search(r"(\d+)\s+" + k, r.stderr))
    return {"rc": r.returncode, "out": r.stdout.rstrip("\n"), "ins": g("instructions retired"),
            "cyc": g("cycles elapsed"), "rss": g("maximum resident set size"),
            "err": r.stderr[-600:] if r.returncode else ""}


def main():
    a = sys.argv[1:]
    opt = lambda k, d: a[a.index(k) + 1] if k in a else d
    filt, reps, out = opt("--filter", ""), int(opt("--reps", "5")), opt("--out", f"{M}/meas.jsonl")
    vs = [x for i, x in enumerate(a) if not x.startswith("--") and (i == 0 or not a[i - 1].startswith("--"))]
    done = set()
    if os.path.exists(out):
        for l in open(out):
            j = json.loads(l)
            done.add((j["prog"], j["hash"]))
    os.makedirs(f"{M}/bin", exist_ok=True)
    for p in programs():
        rel = os.path.relpath(p, BB)
        if filt not in rel:
            continue
        n = name_of(p)
        hs = {}
        for v in ["int"] + vs:
            f = f"{M}/c/{v}/{n}.c"
            if not os.path.exists(f):
                hs[v] = "EMITFAIL"
                continue
            hs[v] = hashlib.sha1(open(f, "rb").read()).hexdigest()[:12]
        if all(h == hs["int"] for h in hs.values()):
            continue
        todo = {}
        for v, h in hs.items():
            if h != "EMITFAIL" and (rel, h) not in done:
                todo.setdefault(h, v)
        if not todo:
            continue
        want = expected_for(p)
        res = {}
        for h, v in todo.items():
            binp = f"{M}/bin/{n}.{h}"
            r = subprocess.run([LIMIT, "600", "6144", "cc", "-std=c11", "-O3", "-w", f"{M}/c/{v}/{n}.c", "-o", binp, "-lpthread", "-lm"],
                               capture_output=True, text=True)
            res[h] = {"prog": rel, "hash": h, "variants": [x for x, y in hs.items() if y == h],
                      "build": "ok" if r.returncode == 0 else "FAIL " + r.stderr[-400:], "runs": [], "par": None}
        for i in range(reps):
            for h in todo:
                if res[h]["build"] != "ok":
                    continue
                rr = run(f"{M}/bin/{n}.{h}", os.path.dirname(p), 1)
                rr["ok"] = rr["rc"] == 0 and rr["out"] == want
                if i > 0 and rr["ok"]:
                    rr["out"] = ""
                res[h]["runs"].append(rr)
        if is_par(rel):
            for h in todo:
                if res[h]["build"] == "ok":
                    rr = run(f"{M}/bin/{n}.{h}", os.path.dirname(p), 10)
                    rr["ok"] = rr["rc"] == 0 and rr["out"] == want
                    if rr["ok"]:
                        rr["out"] = ""
                    res[h]["par"] = rr
        with open(out, "a") as fo:
            for h, r in res.items():
                fo.write(json.dumps(r) + "\n")
        for h, r in res.items():
            bad = r["build"] != "ok" or not all(x["ok"] for x in r["runs"]) or (r["par"] and not r["par"]["ok"])
            cy = sorted(x["cyc"] or 0 for x in r["runs"])
            print(f"{'BAD ' if bad else 'ok  '} {rel:50} {','.join(r['variants']):32} "
                  f"ins {r['runs'][0]['ins'] if r['runs'] else None} cyc {cy[len(cy)//2] if cy else None}", flush=True)
        for h in todo:
            try:
                os.remove(f"{M}/bin/{n}.{h}")
            except OSError:
                pass


if __name__ == "__main__":
    main()
