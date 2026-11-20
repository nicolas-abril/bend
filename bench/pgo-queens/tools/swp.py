#!/usr/bin/env python3
"""swp.py: placement sweeps of C variants, interleaved.

    swp.py --out F.jsonl [--rounds R] [--pos 16] [--args "..."]
           LABEL=FILE.c[:FN1,FN2..][@CFLAGS] ...
    swp.py --table F.jsonl

Each variant is compiled to assembly (`cc -std=c11 -O3 -w` plus its CFLAGS),
then for K = 0..pos-1 gets `.p2align 6` and K `nop`s (never executed) before
the earliest of FN1, FN2.. in the file (default: the first function whose
name starts with WL_FID_ or is `solve`), every later function 4-byte
aligned; linked with -lpthread -lm. Runs: R rounds, every (variant,
position) once per round, variants innermost; through tm (instructions,
cycles, P-core share). Bend binaries get `+RTS --threads 1 --gpu off -RTS`
when --rts is given. Table: instructions (median), P-core cycles least / median /
most over positions (P-core cycles: instructions times the run's cycles per
instruction on performance cores; under load from other processes this
repeats to 0.1% where raw cycles move by 3%) (each position's least over rounds), counting only runs
with at least --pmin of their cycles on performance cores (a slot is rerun
up to --tries times to get one).
"""
import argparse, json, os, re, statistics as st, subprocess, sys, time

TM = os.environ.get("TM", "/private/tmp/bend-opt/pq-work/tools/tm")


def pad_lines(lines, fn_pick, k):
    """The pad goes right before the label of the chosen function, in
    __text (clang puts a function's 'Begin function' marker on its constant
    pool when it has one); every later function in __text becomes 4-byte
    aligned. fn_pick(present) -> the function to pad before, from the
    (index, name) of the functions in __text."""
    sec, begins = "", []
    for i, l in enumerate(lines):
        m = re.match(r"^\s*\.section\s+(\S+)", l)
        if m:
            sec = m.group(1)
        m = re.search(r"-- Begin function (\S+)", l)
        if m:
            begins.append((i, m.group(1), sec.startswith("__TEXT,__text")))
    fn = fn_pick([(i, f) for i, f, t in begins])
    lab = next(i for i, l in enumerate(lines) if re.match(r"^_?" + re.escape(fn) + r":", l))
    for i, f, t in begins:
        if t and i >= lab:
            lines[i] = re.sub(r"\.p2align\s+\d+(, 0x0)?", ".p2align\t2", lines[i])
    lines[lab:lab] = ["\t.p2align\t6"] + (["\t.rept\t%d" % k, "\tnop", "\t.endr"] if k else [])
    return fn


def pad(src, dst, fns, k):
    lines = open(src).read().split("\n")
    pick = (lambda present: next(f for _, f in present if f in fns)) if fns else \
        (lambda present: next(f for _, f in present if f.startswith("WL_FID_") or f == "solve"))
    pad_lines(lines, pick, k)
    open(dst, "w").write("\n".join(lines))


def build(label, spec, npos, wdir):
    m = re.match(r"([^:@]+)(?::([^@]*))?(?:@(.*))?$", spec)
    cfile, fns, flags = m.group(1), m.group(2), m.group(3) or ""
    fns = fns.split(",") if fns else None
    d = f"{wdir}/{label}"
    os.makedirs(d, exist_ok=True)
    s = f"{d}/x.s"
    subprocess.run(f"cc -std=c11 -O3 -w {flags} -S {cfile} -o {s}", shell=True, check=True)
    out = []
    for k in range(npos):
        b = f"{d}/p{k}"
        pad(s, b + ".s", fns, k)
        subprocess.run(f"cc {b}.s -o {b} -lpthread -lm", shell=True, check=True)
        os.remove(b + ".s")
        out.append((label, k, b))
    return out


def run(cmd):
    p = subprocess.run([TM] + cmd, capture_output=True, text=True, stdin=subprocess.DEVNULL)
    line = ([l for l in p.stderr.splitlines() if l.startswith("rc=")] or [""])[-1]
    rec = {a: (float(b) if re.match(r"^-?[\d.]+$", b) else b) for a, b in (kv.split("=") for kv in line.split())}
    rec["out"] = (p.stdout.strip().splitlines() or [""])[-1]
    return rec


def pshare(r):
    return r.get("pcycles", 0) / max(r.get("cycles", 1), 1)


def pcyc(r):
    """P-core cycles: instructions times the run's CPI on performance cores."""
    return r["instr"] * r["pcycles"] / r["pinstr"]


def table(path, pmin=0.5):
    rs = [json.loads(l) for l in open(path) if l.strip()]
    g, order = {}, []
    for r in rs:
        if r["label"] not in order:
            order.append(r["label"])
        if r.get("rc") == 0 and pshare(r) >= pmin:
            g.setdefault(r["label"], {}).setdefault(r["pos"], []).append(r)
    outs = {l: sorted({r["out"] for v in g.get(l, {}).values() for r in v}) for l in order}
    print("| variant | instructions G | P-core cycles G least / median / most | raw cycles G least / median | P-core % | runs | output |")
    print("|---|---:|---|---:|---:|---|")
    for l in order:
        pos = g.get(l, {})
        if not pos:
            print(f"| {l} | failed | | | | |")
            continue
        best = [min(v, key=pcyc) for v in pos.values()]
        cyc = sorted(pcyc(r) / 1e9 for r in best)
        raw = sorted(min(r["cycles"] for r in v) / 1e9 for v in pos.values())
        ins = st.median(r["instr"] for v in pos.values() for r in v) / 1e9
        pc = st.median(r["pcycles"] / r["cycles"] for r in best) * 100
        print(f"| {l} | {ins:.3f} | {cyc[0]:.3f} / {st.median(cyc):.3f} / {cyc[-1]:.3f} | {raw[0]:.3f} / {st.median(raw):.3f} | {pc:.0f} | {sum(map(len, pos.values()))} | {','.join(outs[l])} |")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("variants", nargs="*")
    ap.add_argument("--out")
    ap.add_argument("--table")
    ap.add_argument("--rounds", type=int, default=2)
    ap.add_argument("--pos", type=int, default=16)
    ap.add_argument("--rts", action="store_true")
    ap.add_argument("--pmin", type=float, default=0.5, help="P-core share a run needs to count")
    ap.add_argument("--tries", type=int, default=2, help="runs per slot until one is on P-cores")
    ap.add_argument("--wdir", default="/private/tmp/bend-opt/pq-work/swp")
    a = ap.parse_args()
    if a.table:
        return table(a.table, a.pmin)
    jobs = []
    for v in a.variants:
        label, spec = v.split("=", 1)
        jobs += build(label, spec, a.pos, a.wdir)
    rts = ["+RTS", "--threads", "1", "--gpu", "off", "-RTS"] if a.rts else []
    with open(a.out, "a") as f:
        for r in range(a.rounds):
            for k in range(a.pos):
                for (label, kk, b) in jobs:
                    if kk != k:
                        continue
                    for t in range(a.tries):
                        rec = run([b] + rts)
                        rec.update(label=label, pos=k, round=r, load=os.getloadavg()[0], try_=t)
                        f.write(json.dumps(rec) + "\n")
                        f.flush()
                        if pshare(rec) >= a.pmin:
                            break


if __name__ == "__main__":
    main()
