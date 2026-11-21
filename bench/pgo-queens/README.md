# PGO bound and `queens`

Two studies on an M4 (4 P-cores, 6 E-cores), one thread, GPU off, Apple
clang 17, 2026-11-20. Not a gate; not in `gates/repo.ts`' allow list.

1. How much of each gap between Bend and its C twins is code layout and
   branch weighting (what a profile fixes), and how much is work.
2. Where `queens`' gap to its twin goes.

Builds: bendlang/bend main 0e2f38f7; `opt/integration` 60c755f4 (the 14
drafts); the Perceus ports of `bench/perceus` 50e89cd6 with Koka's C++
references at b66091b2; the 22 koru kernels with their C references (`-O2`,
as koru's `bench.sh`); the bench twins at `-O3`.

## Rebuild and rerun

`tools/setup.sh` rebuilds every scratch input from worktrees (paths in its
header); `tools/queue_all.sh` runs every measurement in order and commits
each result here. `results/` holds the raw runs (`*.jsonl`) and tables.

## Method

- `tools/pgo.py prep`: per program, Bend's C from main and from
  `opt/integration`, and the reference; each built plain and with
  `-fprofile-instr-generate`, trained on a different input (size literals
  changed, `tools/progs.py`: queens n=16 for n=17, one fork level less for
  the benches, about 70% of the count for the kernels, 3,000,000 for
  4,200,000 inserts...), merged with `xcrun llvm-profdata`, rebuilt with
  `-fprofile-instr-use`. The training C differs from the measured C only in
  literals (checked, numbers masked) and clang reports no profile mismatch.
  No BOLT: not in Xcode, not in Homebrew LLVM 22, and it does not take
  Mach-O.
- Placement: 16 positions, `.p2align 6` and K nops right before the label
  of the earliest hot function (from the profile), every later `__text`
  function 4-byte aligned.
- Cycles: P-core cycles, instructions times the run's cycles per
  instruction on performance cores (rusage v6); a run counts when at least
  half its cycles are on P-cores. The final runs were on a quiet machine:
  100% on P-cores, equal to raw cycles. Least per position, then least /
  median / most over the 16.

## Part 1: what a profile buys

`results/summary1.md` has every program; `results/table1.md` every build.
"Share" is (gap plain - gap PGO) / (gap plain - 1), gaps from medians.

Where PGO speeds Bend beyond the placement range (P-core cycles G, plain
range -> PGO range):

| program | build | Bend | C | gap plain -> PGO |
|---|---|---|---|---|
| symreg | main | 12.21-14.05 -> 9.42-9.56 | 8.87-9.11 -> 8.48-8.55 | 1.52 -> 1.12 (78%) |
| lexer | main | 8.40-9.28 -> 7.66-8.08 | 4.26-4.29 -> 4.28-4.30 | 1.98 -> 1.82 (17%) |
| lexer | int | 6.21-6.51 -> 5.55-5.62 | same | 1.48 -> 1.30 (38%) |
| hashmap | main | 9.53-9.89 -> 8.86-9.35 | 2.50-2.59 -> 2.49-2.52 | 3.80 -> 3.62 (6%) |
| deriv | main / int | 2.49-2.54 -> 2.14-2.17 / 2.18-2.29 -> 2.00-2.06 | 1.58-1.88 | 1.56 -> 1.36 / 1.40 -> 1.27 |
| rbtree | main / int | 8.28-8.43 -> 7.69-7.87 / 7.98-8.09 -> 7.67-7.81 | 0.90-0.94 | 9.1 -> 8.4 / 8.8 -> 8.4 |
| rbtree-ck (-unsafe) | both | -6% to -7% | no reference | |
| queens | int | 18.49-18.71 -> 18.17-18.42 | 15.11-15.35 -> 15.04-15.26 | 1.22 -> 1.20 (7%) |

Everywhere else the PGO range overlaps the plain one, or PGO is slower:
raytrace +13% (PGO puts the hottest spin, `spin_nearest`, out of line), and
in the kernels factorial, powmod, nestedloop, primes, collatz (int), where
PGO also slows the C side (digitsum's C 2.4x). The gaps that stay with PGO
on both sides are work: queens (1.44 main, 1.20 int), merkle 1.24,
mandelbrot 1.19 (main), gameoflife 1.15 (main), tree-radix 1.25,
histogram 1.38 (main), bfs 1.03 to 1.08, and every Perceus port.

What PGO changed where it mattered (from the assembly):
- symreg `eval`: the dispatch's first compare splits the two leaf
  constructors from the operators, the dispatch is duplicated at the end of
  each arm (no jump back to a loop head), and main's task path (`seq`
  tests) leaves the hot path.
- lexer: the first five turns of `ident`'s and `num`'s frame-push loops
  peeled (profiled trip counts); on main also the `seq` tests.
- rbtree: `spin_balance_left` inlined into `ins`' continuation `k19`.
- deriv: inlining moved (`term_drop` 251 -> 402 instructions, `mul`
  2,978 -> 3,736, `count` 121 -> 81); hashmap main: `ctr_take`, `heap_free`
  out of line, `span_fade` smaller.
- queens: on main, the `seq` tests weighted (+6% instructions, no cycles);
  on int nothing visible.

Decisions a compiler can make without a profile, bounded by hand
(`edits/expect.py`: the sequential test before a push expected true, a
continuation's task path expected false), 16 positions x 2 rounds:

| program | plain | hints | PGO (Part 1 sweep) |
|---|---|---|---|
| symreg main | 12.20 / 13.02 / 13.71 | 11.83 / 12.21 / 12.84 | 9.42-9.56 |
| symreg int | 7.64 / 7.88 / 8.18 | 7.55 / 7.89 / 8.28 | 6.86-8.06 |
| lexer main | 8.40 / 8.46 / 8.65 | 8.09 / 8.11 / 8.15 | 7.66-8.08 |
| lexer int | 6.20 / 6.31 / 6.49 | 6.29 / 6.32 / 6.37 | 5.55-5.62 |
| queens main | 21.81 / 22.11 / 22.33 | 21.80 / 22.20 / 22.64 | 21.70-22.00 |

On main the hints take lexer most of the way to PGO and symreg a quarter of
it; on `opt/integration` they do nothing (#2176 already makes the test a
constant). What is left is symreg's dispatch order and tail duplication
(section 18 bounded leaf-first by hand at 9.08G; it rests on knowing the
hot arms) and lexer's loop peeling (needs trip counts).

## Part 2: `queens`

Counts (patched C, `tools/cnt_patch.py`): 864.0M nodes, 6.9M solutions;
857.1M frames of 9 words (g, sib, cols, ld, rd, full, b2, n2, id) on both
builds; `solve` entered 1,721M times on main (857M child calls, 857M
sibling calls, the rest solution steps), 1,414M on int; 857M returns
through the table on main, 550M on int, where #2177 answers 306.7M child
calls at the call site (they still store the frame); no 2^48 tests; 784
heap allocations. Instructions per frame: twin 31.7, main 104.8, int 83.2.

Ladder (`ladder/`, C twins taking Bend's constraints one at a time;
instructions G, P-core cycles G least / median / most):

| rung | instructions | cycles |
|---|---:|---|
| L0 the twin (`full` folds to a constant) | 27.19 | 15.10 / 15.21 / 15.36 |
| L1a Bend's argument list: peeled state, bools precomputed by the caller | 50.25 | 17.01 / 17.05 / 17.16 |
| L1b + a Nat fuel | 51.74 | 16.96 / 17.01 / 17.16 |
| L1c + ret as a tagged Stats accumulator | 65.71 | 17.55 / 17.58 / 17.62 |
| L2 + Bend's term encoding (u64 words, U32_BIN) | 69.35 | 17.69 / 17.71 / 17.81 |
| L3 + an explicit 9-word frame stack, one loop, compare return | 44.20 | 17.04 / 17.09 / 17.14 |
| L4 + segments (preserve_none, musttail), table return | 76.55 | 18.99 / 19.04 / 19.09 |
| L4 with main's two equal continuations | 77.40 | 20.56 / 20.72 / 21.12 |
| Bend main | 89.81 | 21.81 / 22.11 / 22.33 |
| Bend `opt/integration` | 71.33 | 18.50 / 18.57 / 18.72 |

So, in cycles: the port's argument list +1.84G, the fuel 0, the tagged
accumulator +0.57G, the encoding +0.13G, C recursion against a frame stack
-0.62G, segments +1.95G, a second return target +1.68G (#2153 removes it).
`opt/integration` is below L4 because #2177 answers a third of the calls
at the call site. In instructions the segments are the largest step
(+32G over the one-loop rung).

Hand edits of the emitted C (`edits/`):

| edit | main | int |
|---|---|---|
| base | 89.81 / 22.11 | 71.33 / 18.57 |
| `full` out of the frame, read from its register (static argument) | 90.67 / 22.39 | 70.78 / 18.29 |
| b2, n2 recomputed in the continuation | 88.10 / 22.35 | 66.81 / 18.21 |
| both | 88.96 / 22.93 | 67.12 / 18.35 |
| no fuel (unsound; bounds its cost) | 82.00 / 20.69 | 68.62 / 18.47 |
| answered calls push no frame, continuation inline (`early.py`) | | 66.52 / 17.33 |
| that + recompute | | 64.55 / 17.45 |
| PGO (Part 1) | 95.4 / 21.70-22.00 | 71.36 / 18.17-18.42 |

Respelled for current Bend, same algorithm (`respell/`): r1 the port with a
`(sols, nodes)` pair accumulator instead of the tagged Stats; r2 the twin's
state (cand, cols, ld, rd), bools passed by the caller, fuel; r3 r2 under
`@unsafe` with no fuel.

| | main | int |
|---|---|---|
| port | 89.81 / 22.11 | 71.33 / 18.57 |
| r1 | 79.81 / 18.84 | 62.45 / 17.70 |
| r2 | 65.26 / 19.74 | 55.72 / 18.42 |
| r3 | 56.19 / 18.92 | 49.23 / 17.58 |

The port's shape costs 15% of cycles on main and 4.7% on int (r1); a
destructuring `let` of a call is a match on a computed value, so the
child's result must ride into the sibling call as a parameter, which the
pair does without the tag.

Built (16 positions x 2 rounds):

| build | instructions | cycles |
|---|---:|---|
| main | 89.82 | 21.81 / 22.12 / 22.29 |
| `opt/queens` (sink) | 87.57 | 22.12 / 22.28 / 22.37 |
| `opt/integration` | 71.33 | 18.50 / 18.56 / 18.71 |
| `opt/integration` + sink | 66.81 | 18.10 / 18.21 / 18.39 |
| #2177 (`opt/call-site-returns`) | 71.10 | 19.84 / 19.90 / 20.09 |
| #2177 + early (`opt/queens-early`) | 61.84 | 18.98 / 19.24 / 19.31 |
