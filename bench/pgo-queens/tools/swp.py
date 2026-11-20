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
when --rts is given. Table: instructions (median), cycles least / median /
most over positions (each position's least over rounds).
"""
import argparse, json, os, re, statistics as st, subprocess, sys, time

TM = os.environ.get("TM", "/private/tmp/bend-opt/pq-work/tools/tm")


def pad(src, dst, fns, k):
    lines = open(src).read().split("\n")
    begins = [(i, m.group(1)) for i, l in enumerate(lines)
              for m in [re.search(r"-- Begin function (\S+)", l)] if m]
    if fns:
        idx = next(i for i, f in begins if f in fns)
    else:
        idx = next(i for i, f in begins if f.startswith("WL_FID_") or f == "solve")
    for i, _ in begins:
        if i >= idx:
            lines[i] = re.sub(r"\.p2align\s+\d+(, 0x0)?", ".p2align\t2", lines[i])
    lines[idx:idx] = ["\t.p2align\t6"] + (["\t.rept\t%d" % k, "\tnop", "\t.endr"] if k else [])
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


def table(path):
    rs = [json.loads(l) for l in open(path) if l.strip()]
    g, order = {}, []
    for r in rs:
        if r["label"] not in order:
            order.append(r["label"])
        if r.get("rc") == 0:
            g.setdefault(r["label"], {}).setdefault(r["pos"], []).append(r)
    outs = {l: sorted({r["out"] for v in g.get(l, {}).values() for r in v}) for l in order}
    print("| variant | instructions G | cycles G least / median / most | P-core % | runs | output |")
    print("|---|---:|---|---:|---:|---|")
    for l in order:
        pos = g.get(l, {})
        if not pos:
            print(f"| {l} | failed | | | | |")
            continue
        best = [min(v, key=lambda r: r["cycles"]) for v in pos.values()]
        cyc = sorted(r["cycles"] / 1e9 for r in best)
        ins = st.median(r["instr"] for v in pos.values() for r in v) / 1e9
        pc = st.median(r["pcycles"] / r["cycles"] for r in best) * 100
        print(f"| {l} | {ins:.3f} | {cyc[0]:.3f} / {st.median(cyc):.3f} / {cyc[-1]:.3f} | {pc:.0f} | {sum(map(len, pos.values()))} | {','.join(outs[l])} |")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("variants", nargs="*")
    ap.add_argument("--out")
    ap.add_argument("--table")
    ap.add_argument("--rounds", type=int, default=2)
    ap.add_argument("--pos", type=int, default=16)
    ap.add_argument("--rts", action="store_true")
    ap.add_argument("--wdir", default="/private/tmp/bend-opt/pq-work/swp")
    a = ap.parse_args()
    if a.table:
        return table(a.table)
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
                    rec = run([b] + rts)
                    rec.update(label=label, pos=k, round=r, load=os.getloadavg()[0])
                    f.write(json.dumps(rec) + "\n")
                    f.flush()


if __name__ == "__main__":
    main()
