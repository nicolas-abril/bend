#!/usr/bin/env python3
"""lanes.py --a ROOT_A --b ROOT_B [-j N] [--mem] FILE.bend ...

For each program, with both compilers (A the reference, e.g. main; B the
change): the C lane (cc -O3, default threads, GPU off), the JS lane (bun),
the interpreter (`bun main.ts file.bend`), each under a 20 s alarm; with
--mem, the memory check: the C with heap_alloc / heap_free counting live
heap words (printed at exit) built with -DBEND_POISON, run at 1 and at 8
threads. Prints one JSON line per program: each probe's output (last 3
lines) for A and B, whether it matches the file's `#|` lines, and a verdict
`same` (every probe prints the same for A and B) or `DIFF`.
"""
import argparse, concurrent.futures as cf, json, os, re, subprocess, sys, tempfile

BUN = "bun"


def sh(cmd, cwd, timeout=60):
    try:
        p = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout + p.stderr)
    except subprocess.TimeoutExpired:
        return "timeout", ""


MEM_HDR = r'''
#include <stdatomic.h>
#include <stdio.h>
static _Atomic long long bend_live_words;
static void bend_live_dump(void) __attribute__((destructor));
static void bend_live_dump(void) { fprintf(stderr, "LIVE %lld\n", (long long)bend_live_words); }
'''


def mem_patch(c):
    c = c.replace("typedef u64 Term;\n", "typedef u64 Term;\n" + MEM_HDR, 1)
    a = "INLINE u64 heap_alloc(Env e, u32 cls) {\n"
    b = "INLINE void heap_free(Env e, u32 cls, u64 loc) {\n  if (err_peek(e.mem)) {\n    return;\n  }\n"
    if a not in c or b not in c:
        return None
    c = c.replace(a, a + "  atomic_fetch_add_explicit(&bend_live_words, 1ll << cls, memory_order_relaxed);\n", 1)
    c = c.replace(b, b + "  atomic_fetch_sub_explicit(&bend_live_words, 1ll << cls, memory_order_relaxed);\n", 1)
    return c


def tail(s, n=3):
    return "\n".join(s.strip().splitlines()[-n:])


def one(src, roots, mem):
    want = "\n".join(l[2:] for l in open(src).read().split("\n") if l.startswith("#|")).strip()
    want = re.sub(r"[ \t]+$", "", want, flags=re.M)
    out = {"src": src}
    with tempfile.TemporaryDirectory(prefix="lanes_") as d:
        for tag, root in roots.items():
            r = {}
            rc, o = sh(f"{BUN} {root}/bend2/main.ts {src} -o {d}/{tag}.c", d, 120)
            if rc != 0:
                r["emit"] = "fail: " + tail(o, 2)
                out[tag] = r
                continue
            rc, o = sh(f"cc -std=c11 -O3 -w {tag}.c -o {tag} -lpthread -lm", d, 300)
            r["c"] = tail(sh(f"perl -e 'alarm 20; exec @ARGV' ./{tag} +RTS --gpu off -RTS", d)[1]) if rc == 0 else "build fail"
            rc, o = sh(f"{BUN} {root}/bend2/main.ts {src} -o {d}/{tag}.js", d, 120)
            r["js"] = tail(sh(f"perl -e 'alarm 20; exec @ARGV' {BUN} {tag}.js", d)[1]) if rc == 0 else "emit fail"
            r["interp"] = tail(sh(f"perl -e 'alarm 20; exec @ARGV' {BUN} {root}/bend2/main.ts {src}", d)[1])
            if mem:
                c = mem_patch(open(f"{d}/{tag}.c").read())
                if c is None:
                    r["mem"] = "no patch"
                else:
                    open(f"{d}/{tag}_m.c", "w").write(c)
                    rc, o = sh(f"cc -std=c11 -O3 -w -DBEND_POISON {tag}_m.c -o {tag}_m -lpthread -lm", d, 300)
                    for t in (1, 8):
                        r[f"mem{t}"] = tail(sh(f"perl -e 'alarm 30; exec @ARGV' ./{tag}_m +RTS --threads {t} --gpu off -RTS", d)[1]) if rc == 0 else "build fail"
            out[tag] = r
    keys = sorted(set(out.get("a", {})) | set(out.get("b", {})))
    out["ok_a"] = {k: out.get("a", {}).get(k, "").strip() == want for k in ("c", "js", "interp")}
    out["ok_b"] = {k: out.get("b", {}).get(k, "").strip() == want for k in ("c", "js", "interp")}
    out["verdict"] = "same" if all(out.get("a", {}).get(k) == out.get("b", {}).get(k) for k in keys) else "DIFF"
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--a", required=True)
    ap.add_argument("--b", required=True)
    ap.add_argument("-j", type=int, default=2)
    ap.add_argument("--mem", action="store_true")
    a = ap.parse_args()
    roots = {"a": a.a, "b": a.b}
    with cf.ThreadPoolExecutor(a.j) as ex:
        for r in ex.map(lambda f: one(os.path.abspath(f), roots, a.mem), a.files):
            print(json.dumps(r), flush=True)


if __name__ == "__main__":
    main()
