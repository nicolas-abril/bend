"""The programs the parallel measurements run, and where their sources are.

Each entry: name -> (source .bend, expected last output line or None, group,
sequential twin name or None). Paths are resolved against BEND (a bend
checkout, for bench/ and demos/), KORU (the osprey kernels suite) and HERE
(this directory, for the extra programs).
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
KORU = os.environ.get("KORU", os.path.expanduser(
    "~/Software/koru-benchmarks/suites/osprey-compute-kernels"))

BENCHES = ["bfs", "editdist", "gameoflife", "hashmap", "histogram", "kmeans",
           "lexer", "mandelbrot", "merkle", "nbody", "queens", "raytrace",
           "symreg", "terrain", "tree-bitonic", "tree-matmul", "tree-radix"]

KORU_PAR = ["binarytrees", "coins", "collatz", "coprime", "digitsum",
            "factorial", "fib", "gcdsum", "isqrt", "mutual", "nestedloop",
            "pascal", "powmod", "primes", "tak", "textstats", "wordfreq"]

DEMOS = ["pure_par_sort", "pure_par_sum"]


def expected(path):
    p = os.path.join(os.path.dirname(path), "expected.txt")
    if os.path.exists(p):
        return open(p).read().strip().splitlines()[-1].strip()
    return None


def programs(bend):
    """All programs, given the bend checkout whose bench/ and demos/ to use."""
    out = {}
    pins = {}
    pin = os.path.join(bend, "bench/runtime/_pin_/apple_m4.txt")
    for line in open(pin):
        cols = [c.strip() for c in line.split("|")]
        if len(cols) > 6 and cols[1] in BENCHES:
            pins[cols[1]] = cols[6]
    for b in BENCHES:
        out["bench/" + b] = (os.path.join(bend, "bench/runtime", b, "main.bend"),
                             pins.get(b), "bench", None)
    for k in KORU_PAR:
        par = os.path.join(KORU, "bend-par", k, k + ".bend")
        seq = os.path.join(KORU, "bend", k, k + ".bend")
        out["koru-seq/" + k] = (seq, expected(seq), "koru-seq", None)
        out["koru-par/" + k] = (par, expected(par), "koru-par", "koru-seq/" + k)
    for d in DEMOS:
        out["demo/" + d] = (os.path.join(bend, "demos", d, "main.bend"), None,
                            "demo", None)
    for name, twin in [("fork_wake_par", "x/fork_wake_seq"),
                       ("fork_wake_seq", None)]:
        out["x/" + name] = (os.path.join(HERE, "progs", name + ".bend"), None,
                            "extra", twin)
    return out
