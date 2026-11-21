# The accumulator rewrite: reach and bound

Is the compiler rewrite that turns `queens`' tagged `Stats` accumulator into
`r1`'s pair (bench/pgo-queens on nicolas-abril/bend) worth building? This
directory counts what its two steps would reach and splits its measured gain
between them. Nothing here changes the compiler. Not a gate, and not in
`gates/repo.ts`' allow list.

M4, one thread, GPU off, Apple clang 17, 2026-11-21. Builds: bendlang/bend
main 0e2f38f7; `opt/integration` 60c755f4; the Perceus ports from
`bench/perceus` 50e89cd6; the koru kernels and their forked ports as they
were on disk.

The two steps:

1. **A nullary constructor that acts as a constant.** At every match on a
   type T, C0's arm equals C's arm with C's fields replaced by constants
   (`Stat0{}` is `Stats{0, 0}`), so T drops C0, its tag and the arms.
2. **A returned record whose fields are only added into parameters.** A
   call's result passed straight into another call as a parameter whose
   fields are only added into other parameters: add where the result arrives
   and carry one running total, dropping the parameter.

## Reach (hook over checked terms)

`hook/acc_hook.ts` is appended to a scratch copy of `bend2/comp.ts`
(`tools/apply_hook.py`); `tools/count.sh` runs it over the corpus lists in
`results/lists/`, `tools/agg.py` makes `results/reach.md` (all counts and
every hit) from its records (`results/hook-raw.tar.gz`). It walks every
runnable def's checked core term: a match is a `Mat` chain; arms are compared
with fields replaced by candidate constants (0, 1, ~0, 0n, False, True, the
field type's nullary constructors) under the alias C0{} = C{constants}, with
and without the identities x+0, x-0, x*1, x*0, x|0, x^0, x&~0, x&0 and
folding of U32 ops on literals; "broad" also lets a field be any variable in
scope or a later parameter (the Option-plus-default shape). A hit holds at
every consumer when every match on T in the program (its defs reachable from
main, Base's included) accepts one same constant tuple. Identical chains of
one def, and a module's defs imported by several files of one directory,
count once. Files that do not check (623, nearly all expected-failure tests
under tests/check, parse, flatten, import, and the demos' LAWS.bend with
their TODOs) are not counted.

### Step 1

| | count |
|---|---:|
| files checked | 1374 |
| match chains | 5218 |
| on a builtin (Nat, U32, Bool, ...) | 2061 |
| on a declared type | 3157 |
| ... whose type has a nullary constructor | 1202 |
| ... and a constructor with fields (eligible) | 1016 (856 on a parameter, 160 on a field) |
| ... of which every C with fields holds a T (list-like, no finite constant) | 715 |
| hit, constants, no identities | 61 |
| hit, constants + identities | 71 |
| hit, constants or variables + identities (broad) | 78 |
| hit and holding at every consumer of the type | see below |

Hits that hold at every consumer of their type in their program, outside
trivial matches (a match that re-forms its scrutinee or ignores the fields):

| file | defs | type | constants | hot |
|---|---|---|---|---|
| bench/runtime/queens/main.bend | solve, smerge, run.fin | Stats (Stat0 -> Stats) | 0, 0 | solve: yes (every node); smerge 2^17 per run; run.fin once |
| tests/compile/array_single_slot.bend | pairsum | Pr | 0, 0 | test |
| tests/compile/nodeless_dup_drop.bend | box_val | BoxB | 0, 0 | test |
| tests/io/cid_capture.bend | keep | Forgery | 0, 0, 0 | test |
| tests/io/foreign_shared.bend, chan_try_wake_timers, marshal_native_forms, nat_host_chan, tests/run/fork_shared_flat.bend | tree.sum, val, unwrap, got, use | Tree, Maybe | 0 / 0n | tests |
| tests/rfc/drop_spine_wordless.bend | get | PL | *, 0, * | test |
| demos/pure_hvm5_mini (PROOF.bend only) | go_cov | Cell (Nul -> Num) | 0 | not reached from main |

Everything else that matches somewhere fails at another consumer of its type:
Base's `Map` (MTip -> MLeaf in Map.get.go, has.go, pop.go, upd.go, refused by
Map.ins.go), tree-radix's `Chk` (chk_join's lo / hi have no neutral constant),
symreg's `Expr` (Var -> Lit only through a variable), the slash_boss `Cells`
and the pure_hvm5_mini terms, Base's `Maybe.default` (broad only). No kernel,
forked port or Perceus port has a hit.

### Step 2

| | count |
|---|---:|
| calls with a call to a def as an argument | 5797 |
| ... the parameter taken whole (a word or value) | 3559 |
| ... the parameter matched (a record) | 1686 |
| ... matched, its fields only added into another value | 17 |
| ... taken whole, only added into another value (#2175's word case) | 13 |
| ... with or, xor, mul, and, min, max as well | 22 (matched), 43 (whole) |

Hits outside tests (the 17 matched ones are otherwise all tests, Duo/Sigma
records summed once):

| file | site | param | hot |
|---|---|---|---|
| bench/runtime/queens/main.bend | solve(..., solve(...), 0, 0), `ret` | Stats, fields added into sols / nodes | yes: 857M sites per run |
| koru/bend/listops | pairSum(sumBelow(...)) | pair, fields added to each other and returned | no: 7 calls per run |
| koru/bend/listops, exprtree | go: addM(acc, runOne(...)); eval: addM(eval(l), eval(r)) | Nat word, then mod | no (7-9 calls) / a tree sum then a mod: #2175's shape, not this one |
| demos/app_slash_boss_3d | Sums.next: Sums.add(..., Probe.ms(...)) | words | per frame |

### The broader family

Of 472 declared types, 112 have a nullary constructor and one with fields;
81 are exactly two constructors. Most are recursive (a list end): 722 matches
are on types whose only constructors with fields hold a T. On the rest:

| | matches | C0 = C with constants | C0 = C with variables (default) | fields only combined into other values |
|---|---:|---:|---:|---:|
| two constructors | 158 | 21 | 5 | 6 |
| more constructors | 156 | 63 | 2 | 1 |

The non-recursive absent / present types outside tests: queens' `Stats`;
tree-radix's `Chk` (the empty check, a monoid whose lo / hi have no identity);
Base's `Maybe` and `Map`; the demos' `Maybe` (http parsing, netcode, slash
boss), `Event`, `Cells`, `Shape`; lexer's `Mode` (a state machine). The `ret`
shape (fields only combined into other values) is queens' solve and smerge
and five tests. No kernel, forked port or Perceus port has one.

## Split of queens' gain

`tools/setup.sh` makes every variant, `tools/edits.py` the hand edits:

| variant | what | params in | return words | continuations | asm instrs solve + k (main / int) |
|---|---|---:|---:|---:|---|
| port | as written | 16 | 3 | 2 / 1 | 233+80+80 / 124+29 |
| m1k (main) | the Stats arms push k1 (#2153 by hand) | 16 | 3 | 1 | 233+80 (k3 dead) |
| s2a | step 2, ret kept: the continuation adds the child's pair into sols / nodes and passes Stat0 | 16 | 3 | 2 / 1, only k1 runs | 233+76+76 / 123+28 |
| s1 | step 1 (variants/s1.bend: Stats has one constructor, arms merged) | 15 | 2 | 1 | 166+75 / 102+27 |
| s2b | step 2 with ret dropped, Stats tag kept on the return (r1's C, 3-word return) | 13 | 3 | 1 | 142+72 / 90+25 |
| s12a | both, ret kept as a (0, 0) parameter | 15 | 2 | 1 | 166+75 / 102+27 |
| s12b | both, ret dropped (s1's C) | 13 | 2 | 1 | 140+72 / 90+25 |
| r1 | the respelling, compiled | 13 | 2 | 1 | 140+72 / 90+25 |

Every variant pushes the same 9-word frame (g, sib, cols, ld, rd, full, b2,
n2, id) per child call, 857.1M times per run; every variant prints
2063750025.

### Measured (results/sweep2.md)

16 positions each (`tools/swp.py`: `.p2align 6` and K nops before
`WL_FID_solve`, every later function 4-byte aligned), one round, three
chunks of five variants, run under load average 6 to 9 from other sessions;
P-core cycles G (instructions times the run's P-core cycles per
instruction), least / median / most over the positions. Gain is against the
port's median on the same build.

| variant | main instr G | main cycles | main gain | int instr G | int cycles | int gain |
|---|---:|---|---:|---:|---|---:|
| port | 89.84 | 21.84 / 22.14 / 22.42 | | 71.36 | 18.53 / 18.68 / 18.90 | |
| m1k (one continuation) | 89.83 | 19.90 / 20.00 / 20.39 | -9.7% | (= port) | | |
| s2a (step 2, ret kept) | 88.43 | 19.58 / 19.61 / 19.67 | -11.4% | 69.68 | 18.18 / 18.31 / 18.76 | -2.0% |
| s1 (step 1) | 85.00 | 18.78 / 18.89 / 19.71 | -14.7% | 66.18 | 17.74 / 17.94 / 18.18 | -4.0% |
| s2b (step 2, ret dropped) | 80.71 | 18.81 / 18.96 / 19.33 | -14.4% | 60.95 | 17.75 / 17.78 / 17.98 | -4.8% |
| s12a (both, ret kept) | 85.10 | 18.77 / 18.94 / 19.14 | -14.4% | 66.18 | 17.79 / 17.94 / 18.13 | -4.0% |
| s12b (both, ret dropped) | 79.86 | 18.78 / 18.94 / 19.27 | -14.5% | 62.51 | 17.66 / 17.78 / 17.97 | -4.8% |
| r1 | 79.83 | 18.77 / 18.86 / 19.27 | -14.8% | 62.48 | 17.59 / 17.79 / 17.95 | -4.8% |

`results/sweep1.md` (two rounds, cut short by a memory reap, load 10 to 18,
10 to 15 positions each) agrees within 0.25G on every median (r1 on int the
furthest, 18.00 against 17.79) and gives the same order.

Every variant's range on main lies below the port's least (21.84); the gain
survives placement. On int, s1, s2b, s12b and r1 lie below the port's least
(18.53); s2a's range overlaps the port's. The variants that drop the tag
overlap each other on both builds: s1, s12a, s2b, s12b and r1 are one result
within placement on main, and s2b / s12b / r1 sit 0.15G under s1 on int,
inside s1's range.

Per frame (857.1M frames): main 25.8 cycles and 104.8 instructions (port),
23.3 / 104.8 (m1k), 22.9 / 103.2 (s2a), 22.0 / 99.2 (s1), 22.0 / 93.1 (r1);
int 21.8 / 83.3 (port), 21.4 / 81.3 (s2a), 20.9 / 77.2 (s1), 20.7 / 71.1
(s2b), 20.8 / 72.9 (r1).

### The split

The steps do not add: on main either one alone takes the whole gain, on int
step 2 (with the parameter dropped) takes all of it and step 1 84%. Both
together are r1 (s12b against r1: 18.94 / 18.86 on main, 17.78 / 17.79 on
int, inside each other's ranges), so the two steps account for r1's gain and
there is no remainder to find beyond them. What the gain is made of, by
elimination (each line one change, measured):

| part (main) | cycles G | share of r1's 3.28G |
|---|---:|---:|
| the second return target: the Stats arms push k3, the Stat0 arms k1, and returns alternate between them (port -> m1k, no instruction change) | 2.14 | 65% |
| the tag test alternating: a child's result makes the sibling take the Stats arm, everything else the Stat0 arm (m1k -> s2a: the same code, at run time only Stat0) | 0.39 | 12% |
| straight-line work: 16 -> 15 or 13 parameter words, no tag word or test, no adds of 0, 3 -> 2 return words, 393 -> 241 or 212 asm instructions in solve and its continuations (s2a -> s1, s2b, r1) | 0.72 to 0.75 | 22% |

On int #2153 has already made the two continuations one (that is why its
gain is 4.8%, not 15%): 0.37G is the tag test's alternation (port -> s2a,
same code), 0.38G the straight-line work of step 1 (s2a -> s1), 0.15G the
three dropped words of step 2 (s1 -> s2b, inside placement).

Why the C ladder saw +27% instructions but +3% cycles for the tagged `ret`:
its rung is C recursion, with one return address that the return stack
predicts, and an add of the tag's fields that clang can make branchless.
Bend's segments return through `wl_tab` (an indirect jump), and on main the
tag gives solve two arms that each push their own continuation; the ladder's
own "L4 with main's two equal continuations" rung (+1.68G) is the same
effect as m1k's 2.14G. That the costs are branch mispredictions (the return
target, the tag test) is inferred: `tm` reads instructions and cycles only,
no branch-miss counter. The measured fact is that m1k and s2a change cycles
by 2.14G and 0.39G with instructions unchanged (m1k) or 1.6% lower (s2a).


## Verdict

Cost estimates in ttok (gpt-3.5-turbo, as `gates/repo.ts` counts): comp.ts
is at 65,995 of its 66,000 on main, so any addition must be paid for by
simplification elsewhere. For scale: #2211's arm comparison and column pick
(`opt/match-columns`) added 2,125; #2175's word accumulator
(`opt/nat-accumulate`) 1,133. The hook's own analysis pieces, written for
counting and not for size, are 1,343 (identity-aware equality with the
alias), 1,405 (the candidate search per match) and 1,311 (the parameter-use
walk).

**Step 1 (a nullary constructor as a constant).** Reach: one bench, queens
(solve, which runs every node; smerge and run.fin, cold), and about ten
toy tests. No demo, kernel, forked port or Perceus port has a hit that holds
at every consumer of its type; Base's Map and Maybe fail at Map.ins.go and
at variables. Bound: queens -14.7% cycles on main (3.25G, of which 2.14G is
the second continuation #2153 removes anyway), -4.0% on `opt/integration`
(0.75G); nothing else. Cost, estimated: 1.5k to 2.5k ttok (an equality
under the identities and the alias as an extension of term_same, about
500; a scan of every match on T and of T's escapes into foreign or
polymorphic code, about 400; the rewrite, dropping C0 from the ADT so the
layout loses its tag, C0{} to C{constants}, C0's arms gone, 600 to 900;
constants picked from the field's operator, not searched). Would not build:
it is `queens` only, worth 4% once #2153 is in.

**Step 2 (a returned record added into parameters).** Reach: one hot site,
queens' solve(..., solve(...), 0, 0); outside tests the other candidates are
cold (koru listops' pairSum and go, 7 calls a run; slash_boss's Sums.next,
per frame) or another shape (exprtree's eval sums two self calls then takes a
mod: #2175's shape). Bound: queens -14.4% on main and -4.8% on
`opt/integration` with the parameter dropped; -11.4% and -2.0% if the
parameter is kept and only routed through C0 (s2a), which is what a version
without a constant-parameter drop gives. Cost, estimated: 1.5k to 2.5k ttok
(#2175's 1,133 is the word case; a record adds the field walk, the
continuation that unpacks and adds, the drop of the parameter at every call
site, and the local check that the C0 arm is the C arm with zeros). Would
not build: `queens` only, the same 4.8% on `opt/integration`, and the source
already has the fix (r1).

Together the two are r1, not more (they remove the same costs), so building
both is no better than building either. Only `queens`.

## What was not checked

- Branch-miss counts (no counter in `tm`); the misprediction reading of
  m1k and s2a is inferred from equal instructions and lower cycles.
- Hot paths of the hits are from reachability and reading the code, not a
  profile, except queens (solve 1,721M entries on main, 857.1M frames).
- The consumer condition checks every match on T; it does not look for T
  escaping into foreign defs, IO or polymorphic code (queens' Stats does
  not escape: run.fin consumes it).
- The identities cover U32 and Nat ops only (no F32: x+0 is not x at -0).
- sweep2 is one round, run while other sessions loaded the machine (load 6
  to 9); sweep1 (two rounds, cut short, load 10 to 18) agrees within 0.25G.

## Rebuild

`tools/setup.sh` (worktree paths in its header) emits every variant;
`tools/sweep.sh` sweeps them; `tools/apply_hook.py` and `tools/count.sh`
rerun the hook (corpus lists in `results/lists/`, with paths relative to the
repo, `[bench/perceus]` for that branch, `koru/` for
koru-benchmarks/suites/osprey-compute-kernels); `tools/agg.py DIR` makes
`results/reach.md`.

