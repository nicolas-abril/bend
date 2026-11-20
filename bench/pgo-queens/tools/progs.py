"""The programs of the PGO study: source, reference, and the training input.

Every program here takes its size from a literal in its source (the Perceus
ports from the argument count, which cannot go below 1), so the training
input is the same source with its size literals changed (`*_train`: regex,
replacement pairs). Training and measured C differ only in those literals;
pgo.py checks that the emitted C has the same shape with numbers masked, and
that clang reports no profile mismatch.
"""
import os

BEND2 = os.environ.get("BEND2_SRC", "/private/tmp/bend-opt/pq-main")
PERC = os.environ.get("PERC_SRC", "/private/tmp/bend-opt/pq-perc/bench/perceus")
KORU = "/Users/macolas/Software/koru-benchmarks/suites/osprey-compute-kernels"
KOKA = os.environ.get("KOKA_CPP", "/private/tmp/bend-opt/pq-work/koka/src/test/bench/cpp")

CC_TWIN = "cc -std=c11 -O3 -w"          # bench twins (their headers: cc -O3)
CC_KORU = "cc -O2 -w"                   # koru's bench.sh / close.sh
CXX_KOKA = "clang++ -O3 -DNDEBUG -std=c++17 -w"  # Koka's CMake for test/bench/cpp

def lit(name, old, new):
    """`def name() -> T:` whose body is the literal `old`."""
    return (r"(def %s\(\) -> \w+:\n  )%s\b" % (name.replace(".", r"\."), old), r"\g<1>" + new)

# bench name: (bend subs, twin subs)
BENCH = {
    "bfs": ([lit("size", "19n", "18n")], [(r"#define DEPTH 19\b", "#define DEPTH 18")]),
    "editdist": ([lit("size.big", "15n", "14n")], [(r"#define DEPTH 15\b", "#define DEPTH 14")]),
    "gameoflife": ([lit("size", "18n", "17n")], [(r"size = 18u", "size = 17u")]),
    "hashmap": ([lit("tables", "11n", "10n")], [(r"#define TABLES 11\b", "#define TABLES 10")]),
    "histogram": ([lit("size", "24n", "23n")], [(r"#define D 24u", "#define D 23u")]),
    "kmeans": ([lit("size", "19n", "18n")], [(r"return 19;", "return 18;")]),
    "lexer": ([lit("size.big", "23n", "22n")], [(r"#define DEPTH 23\b", "#define DEPTH 22")]),
    "mandelbrot": ([(r"rend!\(18n,", "rend!(17n,")], [(r"rend\(18,", "rend(17,")]),
    "merkle": ([(r"build!\(22n,", "build!(21n,"), (r"pgen!\(22n,", "pgen!(21n,")],
               [(r"#define SIZE 22\b", "#define SIZE 21")]),
    "nbody": ([lit("sy", "17n", "16n")], [(r"#define SY 17\b", "#define SY 16")]),
    "queens": ([lit("size", "17", "16")], [(r"#define SIZE 17u", "#define SIZE 16u")]),
    "raytrace": ([lit("rows", "12n", "11n")], [(r"#define ROWS 12u", "#define ROWS 11u")]),
    "symreg": ([lit("size", "18n", "17n")], [(r"#define SIZE 18u", "#define SIZE 17u")]),
    "terrain": ([lit("size", "16n", "15n")], [(r"size = 16u", "size = 15u")]),
    "tree-bitonic": ([(r"bsort!\(23n,", "bsort!(22n,")], [(r"#define SIZE 23\b", "#define SIZE 22")]),
    "tree-matmul": ([lit("blog", "9n", "8n")], [(r"blog = 9u", "blog = 8u")]),
    "tree-radix": ([(r"gen!\(22n,", "gen!(21n,")], [(r"#define DEPTH 22\b", "#define DEPTH 21")]),
}

# koru kernel: (bend subs, C subs)
KERNEL = {
    "ackermann": ([(r"ack\(3n, 10n\)", "ack(3n, 9n)")], [(r"ack\(3, 10\)", "ack(3, 9)")]),
    "binarytrees": ([(r"go\(1200n,", "go(600n,")], [(r"i < 1200;", "i < 600;")]),
    "coins": ([(r"600n, 5n\)", "500n, 5n)")], [(r"ways\(600, 5\)", "ways(500, 5)")]),
    "collatz": ([(r"Nat.mul\(100n, 1000n\)", "Nat.mul(70n, 1000n)")], [(r"i < 100001;", "i < 70001;")]),
    "coprime": ([(r"loopI\(2000n, 2000n,", "loopI(1500n, 1500n,")], [(r"n = 2000;", "n = 1500;")]),
    "digitsum": ([(r"Nat.mul\(2000n, 1000n\)", "Nat.mul(1400n, 1000n)")], [(r"i < 2000001;", "i < 1400001;")]),
    "exprtree": ([(r"go\(9n, 1n, 0n\)", "go(6n, 1n, 0n)")], [(r"t < 10;", "t < 7;")]),
    "factorial": ([(r"Nat.mul\(10n, Nat.mul", "Nat.mul(7n, Nat.mul")], [(r"i <= 10000000;", "i <= 7000000;")]),
    "fib": ([(r"fib\(35n\)", "fib(33n)")], [(r"fib\(35\)", "fib(33)")]),
    "gcdsum": ([(r"Nat.mul\(2000n, 1000n\)", "Nat.mul(1400n, 1000n)")], [(r"i < 2000000;", "i < 1400000;")]),
    "hanoi": ([(r"hanoi\(25n,", "hanoi(23n,")], [(r"hanoi\(25,", "hanoi(23,")]),
    "isqrt": ([(r"Nat.mul\(1000n, 1000n\)", "Nat.mul(700n, 1000n)")], [(r"i < 1000001;", "i < 700001;")]),
    "josephus": ([(r"Nat.mul\(10n, Nat.mul", "Nat.mul(7n, Nat.mul")], [(r"i < 10000001;", "i < 7000001;")]),
    "listops": ([(r"go\(7n, 1n, 0n\)", "go(5n, 1n, 0n)")], [(r"t < 8;", "t < 6;")]),
    "mutual": ([(r"130n", "90n")], [(r"i < 130000;", "i < 90000;")]),
    "nestedloop": ([(r"li\(250n, 250n,", "li(200n, 200n,")], [(r"loop_i\(250, 250,", "loop_i(200, 200,")]),
    "pascal": ([(r"binom\(27n, 13n\)", "binom(25n, 12n)")], [(r"binom\(27, 13\)", "binom(25, 12)")]),
    "powmod": ([(r"Nat.mul\(1000n, 1000n\)", "Nat.mul(700n, 1000n)")], [(r"i < 1000000;", "i < 700000;")]),
    "primes": ([(r"200n", "140n")], [(r"n < 200000;", "n < 140000;")]),
    "tak": ([(r"32n", "30n")], [(r"tak\(32, 16, 8\)", "tak(30, 16, 8)")]),
    "textstats": ([(r"Nat.mul\(200n, 1000n\)", "Nat.mul(140n, 1000n)")], [(r"i < 200000;", "i < 140000;")]),
    "wordfreq": ([(r"Nat.mul\(200n, 1000n\)", "Nat.mul(140n, 1000n)")], [(r"i < 200000;", "i < 140000;")]),
}

# Perceus port: (bend subs, Koka C++ reference or None, C++ subs)
PERCEUS = {
    "rbtree": ([(r"4200000n", "3000000n")], "rbtree", [(r"unsigned n = 4200000;", "unsigned n = 3000000;")]),
    "rbtree-unsafe": ([(r"4200000n", "3000000n")], "rbtree", [(r"unsigned n = 4200000;", "unsigned n = 3000000;")]),
    "rbtree-ck": ([(r"4200000n", "3000000n")], None, []),
    "rbtree-ck-unsafe": ([(r"4200000n", "3000000n")], None, []),
    "deriv": ([(r"Nat.mul\(10n,", "Nat.mul(9n,")], "deriv", [(r"nest\(10,e\)", "nest(9,e)")]),
    "cfold": ([(r"Nat.mul\(20n,", "Nat.mul(19n,")], "cfold", [(r"mk_expr\(20,1\)", "mk_expr(19,1)")]),
    "nqueens": ([(r"Nat.mul\(13n,", "Nat.mul(12n,")], "nqueens", [(r"int n = 13;", "int n = 12;")]),
}


def progs():
    """name -> dict(set, bend, bend_train, ref, ref_lang, ref_cc, ref_train)."""
    out = {}
    for b, (bs, cs) in BENCH.items():
        d = f"{BEND2}/bench/runtime/{b}"
        out[b] = dict(set="bench", bend=f"{d}/main.bend", bend_train=bs,
                      ref=f"{d}/main.c", ref_lang="c", ref_cc=CC_TWIN, ref_train=cs)
    for k, (bs, cs) in KERNEL.items():
        out["k-" + k] = dict(set="koru", bend=f"{KORU}/bend/{k}/{k}.bend", bend_train=bs,
                             ref=f"{KORU}/reference/cases/{k}/{k}.c", ref_lang="c",
                             ref_cc=CC_KORU, ref_train=cs)
    for p, (bs, ref, cs) in PERCEUS.items():
        out["p-" + p] = dict(set="perceus", bend=f"{PERC}/{p}/main.bend", bend_train=bs,
                             ref=f"{KOKA}/{ref}.cpp" if ref else None, ref_lang="cpp",
                             ref_cc=CXX_KOKA, ref_train=cs)
    return out
