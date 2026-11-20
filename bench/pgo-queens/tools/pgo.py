#!/usr/bin/env python3
"""Profile-guided builds of Bend programs and their C references, and
16-position placement sweeps of both.

    pgo.py prep [--builds main,int,ref] [NAME ...]   build everything
    pgo.py sweep --out F.jsonl [--rounds R] [--pos 16] [--builds ..] NAME ...
    pgo.py once --out F.jsonl [--rounds R] NAME ...     unpadded, interleaved
    pgo.py table F.jsonl                                 per program and build
    pgo.py summary F.jsonl                               Bend against C, plain and PGO

Layout: $W/<name>/<build>/{tr,ms}/x.c (or x.cpp). tr/ holds the training
source (sizes changed, progs.py) and its instrumented binary and profile;
ms/ the measured source, plain.s / pgo.s and the binaries. Both files are
named x.c so that the profile's names of static functions (`x.c:f`) match.

Bend builds: `bun <root>/bend2/main.ts src -o x.c`, `cc -std=c11 -O3 -w`,
run with `+RTS --threads 1 --gpu off -RTS`. PGO: `-fprofile-instr-generate`
on tr/x.c, one training run, `xcrun llvm-profdata merge`,
`-fprofile-instr-use` on ms/x.c.

Placement: the assembly gets `.p2align 6` and K `nop`s (K = 0..15, never
executed) right before the earliest, in file order, of the functions present
in the assembly whose largest block count is at least 2% of the largest
among them (from the training profile); that function and every later one
become 4-byte aligned. So the hot code starts at 4*K bytes into a 64-byte
line, and everything after it moves with it.

Cycles are P-core cycles: instructions times the run's cycles per
instruction on performance cores (rusage v6), because other sessions' load
moves single-thread runs between core types; a run counts when at least
--pmin of its cycles are on P-cores.
"""
import argparse, json, os, re, shutil, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from progs import progs

W = os.environ.get("PGO_WORK", "/private/tmp/bend-opt/pq-work/pgo/w")
ROOTS = {"main": "/private/tmp/bend-opt/pq-main", "int": "/private/tmp/bend-opt/pq-int"}
TM = os.environ.get("TM", "/private/tmp/bend-opt/pq-work/tools/tm")
RTS = ["+RTS", "--threads", "1", "--gpu", "off", "-RTS"]
BCC = "cc -std=c11 -O3 -w"
WARN = "-Wno-everything -Wprofile-instr-out-of-date -Wprofile-instr-unprofiled -Wprofile-instr-missing"


def sh(cmd, cwd=None, check=True, timeout=1200):
    p = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    if check and p.returncode != 0:
        raise RuntimeError(f"{cmd} (in {cwd}) failed: {p.stderr[-2000:]}")
    return p


def subst(text, subs):
    for a, b in subs:
        text, n = re.subn(a, b, text)
        if n == 0:
            raise RuntimeError(f"training substitution {a!r} matched nothing")
    return text


def run_cmd(p, build, binary):
    if build == "ref":
        return [binary]
    return [binary] + RTS


def prep_one(name, P, build):
    d = f"{W}/{name}/{build}"
    tr, ms = f"{d}/tr", f"{d}/ms"
    os.makedirs(tr, exist_ok=True)
    os.makedirs(ms, exist_ok=True)
    info = {"name": name, "build": build}
    if build == "ref":
        if not P["ref"]:
            return None
        ext = "cpp" if P["ref_lang"] == "cpp" else "c"
        src = open(P["ref"]).read()
        open(f"{ms}/x.{ext}", "w").write(src)
        open(f"{tr}/x.{ext}", "w").write(subst(src, P["ref_train"]))
        cc = P["ref_cc"]
        link = "clang++" if ext == "cpp" else "cc"
        libs = "-lm"
    else:
        ext = "c"
        root = ROOTS[build]
        src = open(P["bend"]).read()
        # same base name as the original (the sources import Base only)
        tsrc = f"{tr}/{os.path.basename(P['bend'])}"
        open(tsrc, "w").write(subst(src, P["bend_train"]))
        sh(f"bun {root}/bend2/main.ts {P['bend']} -o {ms}/x.c")
        sh(f"bun {root}/bend2/main.ts {tsrc} -o {tr}/x.c")
        a = re.sub(r"\d+", "N", open(f"{ms}/x.c").read())
        b = re.sub(r"\d+", "N", open(f"{tr}/x.c").read())
        info["same_shape"] = a == b
        if not info["same_shape"]:
            na = a.splitlines(); nb = b.splitlines()
            info["shape_diff_lines"] = abs(len(na) - len(nb)) + sum(x != y for x, y in zip(na, nb))
        cc = BCC
        link = "cc"
        libs = "-lpthread -lm"
    x = f"x.{ext}"
    # training
    sh(f"{cc} -fprofile-instr-generate {x} -o gen {libs}", cwd=tr)
    env = f"LLVM_PROFILE_FILE=x.profraw"
    cmd = " ".join(run_cmd(None, build, "./gen"))
    t0 = time.time()
    pre = "ulimit -s 65520; " if build == "ref" else ""
    sh(f"{pre}{env} {cmd} < /dev/null > train.out", cwd=tr, timeout=1800)
    info["train_s"] = round(time.time() - t0, 2)
    sh("xcrun llvm-profdata merge -o x.profdata x.profraw && rm -f x.profraw", cwd=tr)
    # measured builds
    sh(f"{cc} -S {x} -o plain.s", cwd=ms)
    p = sh(f"{cc} {WARN} -fprofile-instr-use=../tr/x.profdata -S {x} -o pgo.s", cwd=ms)
    info["pgo_warn"] = [l for l in p.stderr.splitlines() if "warning" in l]
    for k in ("plain", "pgo"):
        sh(f"{link} {k}.s -o {k} {libs}", cwd=ms)
    # hot functions from the profile
    top = sh("xcrun llvm-profdata show --topn=40 ../tr/x.profdata", cwd=ms).stdout
    fs = re.findall(r"^\s+(\S+), max count = (\d+)", top, re.M)
    mx = max(int(c) for _, c in fs) if fs else 0
    hot = [f.split(":")[-1] for f, c in fs if int(c) * 50 >= mx]
    info["hot"] = hot
    json.dump(info, open(f"{d}/info.json", "w"), indent=1)
    return info


def prof_counts(d):
    """function -> largest block count, from the training profile."""
    top = sh(f"xcrun llvm-profdata show --topn=400 {d}/tr/x.profdata").stdout
    return {f.split(":")[-1]: int(c) for f, c in re.findall(r"^\s+(\S+), max count = (\d+)", top, re.M)}


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


def pad_asm(src, dst, counts, k):
    """Pad before the earliest function present in the assembly whose count
    is at least 2% of the largest count among the present ones."""
    lines = open(src).read().split("\n")
    def pick(present):
        mx = max(counts.get(f, 0) for _, f in present)
        return next(f for _, f in present if counts.get(f, 0) * 50 >= mx)
    fn = pad_lines(lines, pick, k)
    open(dst, "w").write("\n".join(lines))
    return fn


def sweep_bins(name, build, npos):
    d = f"{W}/{name}/{build}"
    if not os.path.exists(f"{d}/info.json"):
        return []
    info = json.load(open(f"{d}/info.json"))
    ms = f"{d}/ms"
    cpp = os.path.exists(f"{ms}/x.cpp")
    link = "clang++" if cpp else "cc"
    libs = "-lm" if build == "ref" else "-lpthread -lm"
    os.makedirs(f"{ms}/sw", exist_ok=True)
    counts = prof_counts(d)
    out = []
    for kind in ("plain", "pgo"):
        for k in range(npos):
            b = f"{ms}/sw/{kind}{k}"
            if not os.path.exists(b) or os.path.getmtime(b) < os.path.getmtime(f"{ms}/{kind}.s"):
                fn = pad_asm(f"{ms}/{kind}.s", b + ".s", counts, k)
                if k == 0:
                    open(f"{ms}/sw/{kind}.padfn", "w").write(fn + "\n")
                sh(f"{link} {b}.s -o {b} {libs}")
                os.remove(b + ".s")
            out.append((build, kind, k, b))
    return out


def load():
    return os.getloadavg()[0]


def run_one(cmd, timeout=600, ref=False):
    # the Koka C++ references recurse deep (cfold needs a 64 MB stack); the
    # limit is raised by a shell that then execs tm, so tm counts only the run
    full = [TM] + cmd
    if ref:
        full = ["sh", "-c", 'ulimit -s 65520 && exec "$@"', "sh"] + full
    p = subprocess.run(full, capture_output=True, text=True, timeout=timeout,
                       stdin=subprocess.DEVNULL)
    line = ([l for l in p.stderr.splitlines() if l.startswith("rc=")] or [""])[-1]
    rec = {}
    for kv in line.split():
        a, b = kv.split("=")
        try:
            rec[a] = float(b)
        except ValueError:
            rec[a] = b
    rec["out"] = p.stdout.strip().splitlines()[-1] if p.stdout.strip() else ""
    return rec


def measure(args, padded):
    """Every (variant, position) of a program once per round, positions
    outermost so that all variants at one position run back to back. A slot
    that already has a P-core run in --out is skipped (resume)."""
    P = progs()
    names = args.names or list(P)
    builds = args.builds.split(",")
    done = set()
    if os.path.exists(args.out):
        for l in open(args.out):
            r = json.loads(l)
            if r.get("rc") == 0 and pshare(r) >= args.pmin:
                done.add((r["name"], r["build"], r["kind"], r["pos"], r["round"]))
    with open(args.out, "a") as f:
        for name in names:
            jobs = []
            for b in builds:
                if padded:
                    jobs += sweep_bins(name, b, args.pos)
                else:
                    ms = f"{W}/{name}/{b}/ms"
                    if os.path.exists(f"{ms}/plain"):
                        jobs += [(b, k, -1, f"{ms}/{k}") for k in ("plain", "pgo")]
            jobs.sort(key=lambda j: j[2])
            for r in range(args.rounds):
                for (b, kind, k, binary) in jobs:
                    if (name, b, kind, k, r) in done:
                        continue
                    while args.max_load and load() > args.max_load:
                        time.sleep(5)
                    for t in range(args.tries):
                        rec = run_one(run_cmd(None, b, binary), ref=(b == "ref"))
                        rec.update(name=name, build=b, kind=kind, pos=k, round=r, load=load(), try_=t)
                        f.write(json.dumps(rec) + "\n")
                        f.flush()
                        if pshare(rec) >= args.pmin:
                            break


def pshare(r):
    return r.get("pcycles", 0) / max(r.get("cycles", 1), 1)


def pcyc(r):
    """P-core cycles: instructions times the run's CPI on performance cores."""
    return r["instr"] * r["pcycles"] / r["pinstr"]


def table(path, pmin=0.5):
    import statistics as st
    rs = [json.loads(l) for l in open(path) if l.strip()]
    g = {}
    for r in rs:
        if r.get("rc") != 0 or pshare(r) < pmin:
            continue
        g.setdefault((r["name"], r["build"], r["kind"]), {}).setdefault(r["pos"], []).append(r)
    names = []
    for r in rs:
        if r["name"] not in names:
            names.append(r["name"])
    print("| program | build | kind | instr G | P-core cycles G least / median / most (per-position least) | P-core % | n |")
    print("|---|---|---|---:|---|---:|---:|")
    for n in names:
        for b in ("main", "int", "ref"):
            for k in ("plain", "pgo"):
                if (n, b, k) not in g:
                    continue
                pos = g[(n, b, k)]
                best = [min(v, key=pcyc) for v in pos.values()]
                cyc = sorted(pcyc(r) / 1e9 for r in best)
                ins = st.median(r["instr"] for v in pos.values() for r in v) / 1e9
                pc = st.median(r["pcycles"] / max(r["cycles"], 1) for r in best) * 100
                print(f"| {n} | {b} | {k} | {ins:.3f} | {cyc[0]:.3f} / {st.median(cyc):.3f} / {cyc[-1]:.3f} | {pc:.0f} | {sum(len(v) for v in pos.values())} |")


def summary(path, pmin=0.5):
    """Per program and Bend build: instructions and P-core cycles (median
    over positions) of Bend and C, plain and PGO; the gap B/C plain and with
    PGO on both; the share of the plain gap that PGO removes; and whether
    PGO's change to Bend clears the placement range (no overlap)."""
    import statistics as st
    rs = [json.loads(l) for l in open(path) if l.strip()]
    g = {}
    for r in rs:
        if r.get("rc") != 0 or pshare(r) < pmin:
            continue
        g.setdefault((r["name"], r["build"], r["kind"]), {}).setdefault(r["pos"], []).append(r)
    def stat(n, b, k):
        pos = g.get((n, b, k))
        if not pos:
            return None
        cyc = sorted(min(pcyc(r) for r in v) / 1e9 for v in pos.values())
        ins = st.median(r["instr"] for v in pos.values() for r in v) / 1e9
        return dict(i=ins, lo=cyc[0], med=st.median(cyc), hi=cyc[-1], n=len(cyc))
    names = []
    for r in rs:
        if r["name"] not in names:
            names.append(r["name"])
    print("| program | Bend | instr B/C plain | PGO | cycles B (plain range -> PGO range) | C (plain -> PGO) | gap plain | gap PGO | share of gap PGO removes | PGO on Bend clears placement |")
    print("|---|---|---:|---:|---|---|---:|---:|---:|---|")
    for n in names:
        for b in ("main", "int"):
            bp, bq = stat(n, b, "plain"), stat(n, b, "pgo")
            cp, cq = stat(n, "ref", "plain"), stat(n, "ref", "pgo")
            if not (bp and bq):
                continue
            rng = lambda s: f"{s['lo']:.3f}-{s['hi']:.3f}"
            clear = "faster" if bq["hi"] < bp["lo"] else "slower" if bq["lo"] > bp["hi"] else "overlap"
            if cp and cq:
                gp, gq = bp["med"] / cp["med"], bq["med"] / cq["med"]
                share = f"{(gp - gq) / (gp - 1):.0%}" if gp > 1.02 else "-"
                print(f"| {n} | {b} | {bp['i'] / cp['i']:.2f} | {bq['i'] / cq['i']:.2f} | {rng(bp)} -> {rng(bq)} | {rng(cp)} -> {rng(cq)} | {gp:.3f} | {gq:.3f} | {share} | {clear} |")
            else:
                print(f"| {n} | {b} | - | - | {rng(bp)} -> {rng(bq)} | - | - | - | - | {clear} |")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd")
    ap.add_argument("names", nargs="*")
    ap.add_argument("--builds", default="main,int,ref")
    ap.add_argument("--out")
    ap.add_argument("--rounds", type=int, default=1)
    ap.add_argument("--pos", type=int, default=16)
    ap.add_argument("--max-load", type=float, default=0)
    ap.add_argument("--pmin", type=float, default=0.5, help="P-core share a run needs to count")
    ap.add_argument("--tries", type=int, default=2, help="runs per slot until one is on P-cores")
    a = ap.parse_args()
    if a.cmd == "prep":
        P = progs()
        for n in a.names or list(P):
            for b in a.builds.split(","):
                try:
                    info = prep_one(n, P[n], b)
                    if info:
                        print(json.dumps(info), flush=True)
                except Exception as e:
                    print(json.dumps({"name": n, "build": b, "error": str(e)[:600]}), flush=True)
    elif a.cmd == "sweep":
        measure(a, True)
    elif a.cmd == "once":
        measure(a, False)
    elif a.cmd == "table":
        table(a.names[0], a.pmin)
    elif a.cmd == "summary":
        summary(a.names[0], a.pmin)


if __name__ == "__main__":
    main()
