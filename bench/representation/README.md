# Representation changes: reach, bounds, and the one built

Which change in how bend2 represents a type or a function in the emitted
code, invisible to the program, is worth building? This directory counts the
candidates over the corpus, bounds the ones with hot reach, and holds the
measurements of the one built: draft PR "a heap node's U32 and tag fields
share a word when that drops its size class" (branch
`opt/packed-node-fields`). Nothing here changes the compiler. Not a gate,
and not in `gates/repo.ts`' allow list.

M4, one thread, GPU off, Apple clang 17, 2026-11-21/22, load average 6 to 18
from other sessions throughout (so cycles are P-core cycles over 16
placements, see `tools/swp.py`). Builds: bendlang/bend main 0e2f38f7; the
Perceus ports from `bench/perceus` 50e89cd6; the koru kernels and their
forked ports as they are on disk. Scripts name their work directory
(`/private/tmp/bend-opt/rep-work`) and worktrees in their first lines.

## What bend2 already does

- **Non-recursive types are words.** `lay_of` gives a type that holds no
  value of itself a flat vector of words (`w32`, `w64`, `box`): a tag word
  when it has more than one constructor, then the constructors' fields laid
  over each other. These ride in registers and frame slots, are passed and
  returned in `r0..`, and become a heap node only when they reach an open
  (polymorphic) position (`val_box`, read back by `val_unbox`). A
  one-constructor type has no tag: a wrapper is already its field.
- **Recursive types are heap nodes.** `lay_node` gives each constructor one
  64-bit word per field word (a `U32` or a `Bool` takes a whole word), in a
  block of the next power of two (`cls_fit`), its constructor id in the
  term. A node whose only word is a `w32`, or that has none, is packed into
  the term itself (`term_pak`). Generic fields are boxes.
- **Sharing.** A type whose values are shared gets the "ctr" fact (the "hot"
  fact): its fields are sealed on build (`rfc_seal`) and a shared read copies
  the node (`ctr_take`, `span_fade`). The runtime walks node fields as terms
  (`term_drop`, `span_fade`): a raw word must look trivial (top byte zero).
- **Closures and arity.** A lambda off a def's head is a node of its captured
  words plus a segment (`emit_clo`, `term_clo`); `Clo~apply` loads the
  captures and jumps. A partial application is eta-expanded into such a
  closure (`call_eta`); an over-application goes through `Clo~apply`.
  `fun_of` raises a def's arity by the lambdas its body opens under every
  arm (`def_raise`), and `~` templates specialise function parameters.

## Count (hook over checked terms) and run-time counters

`hook/rep_hook.ts` is appended to a scratch copy of `bend2/comp.ts` by
`tools/apply_rep_hook.py`; `tools/count.sh` runs it over Base, the tests, the
demos, the 17 benches, the 22 koru kernels, their 17 forked ports and the 7
Perceus ports (lists from `bench/acc-rewrite/results/lists`); `tools/agg.py`
makes `results/reach.txt` from its records (`results/hook-raw.tar.gz`).
862 files check (the 623 that do not are expected failures and LAWS files).

`tools/rtc_patch.py` makes a scratch compiler whose C counts, at run time,
every record boxed or unboxed, every heap node built (per constructor),
every closure built, `Clo~apply` call, partial application and `rfc_wrap`;
`tools/rtc_run.sh` ran the 63 programs (17 benches, 22 kernels, 17 forked
ports, 7 Perceus ports) at their sizes, `results/runtime_counts.txt`.

| candidate | qualifying | sound at every consumer | hot (run-time counters) |
|---|---:|---:|---|
| 1. sum with a default collapsed into its product, per def | 1,146 (def, type, C0 -> C) pairs; 29 types where some def holds | 316 pairs; 13 types where every def holds | queens' `Stats` only (solve, every node); symreg's `esize` and tree-radix's `chk_out` hold in one def each and are not on the hot path. From `bench/acc-rewrite`'s raw records |
| 2. one-constructor wrapper erased | 83 one-constructor one-field types | all 83 are already words (no tag, no node) | nothing left: no heap-node wrapper in the corpus |
| 3. closures applied fully (arity raising) | 5,219 closure sites, 5,990 partial applications, 390 `Clo~apply` spines in 1,491 / 1,518 / 310 defs | not checked | none: 0 static sites in the benches and kernels; at run time at most 77 closures per run (deriv), 6 or fewer elsewhere |
| 4. list-like types as buffers | 97 types (one nullary, one constructor with a single self field) | not checked | lexer's `String` (507.5M `SCon` per run), hashmap's `Chain` (33.4M), nqueens' `List` (9.3M) |
| 5a. tag and `U32` words of a heap node sharing a word (built) | 20 node constructors with a tag word; 5 where it drops a size class | all 5 (foreign C fixes none of them) | the 4 rbtree Perceus ports (340M to 504M `Node`s per run) |
| 5b. the same in a record (registers, frames) | 101 of 704 records could lose a word | not checked | queens' `Stats`, lexer's `Mode`, raytrace's `Hit`, tree-radix's `Chk` |
| 6. records boxed in polymorphic nodes | every record that reaches an open position | | none: at most 10 boxes or unboxes per run |

## Bounds

- 1: `bench/acc-rewrite` measured it: queens -14.7% cycles on main, 65% of
  it the second return target #2153 removes, -4.0% on `opt/integration`.
  The per-def version reaches nothing else hot.
- 3, 6: no hot reach, not bounded.
- 4: the bound measured earlier (OPTIMIZATIONS.md section 16): a C lexer over
  a cons list with raw pointers was faster than one over bytes; lexer's cost
  is Bend's reference encoding, not the list. Not rebounded here.
- 5b: not bounded by hand. In registers a shared word only adds shifts and
  masks; the frames carry the same values. Its upper bound on queens is the
  `s1` variant of `bench/acc-rewrite` (the tag dropped entirely, 3 to 2
  return words): 0.72 to 0.75G of 21.8G cycles on main as straight-line
  work, which packing would not reach (it keeps the tag test). Inferred.
- 5a: built directly (its C is the bound): see below.

## 5a, as built (`opt/packed-node-fields`)

`node_pack(k)`: a constructor's word bits (`lay_bits`: a tag's bits, 32 for
a `w32`, 64 for a box or `w64`) are first-fit packed, widest first, into
words of at most 56 bits (at most one `U32` each), the shared words first;
taken only when that lowers the node's size class. Not for Base's runtime
types (`OWNED`), nor any type foreign C names (`CID(..)` in an effect
source) or takes (its signature), nor what those hold.

Programs whose C changes: the 4 rbtree ports, raytrace (a `CID_T` entry
only: `Hit` is never boxed at run time), 4 demos (pong's `Pong`, slash
boss's `Cue`, `Sound`, `Voice`, netcode's walkers test `Key`,
pure_hvm5_mini's `Bind`), 9 tests (`results/c_changed.txt`), and the two new
tests. Every other bench, kernel, forked port, Perceus port, test and demo
emits byte-identical C; the JS of all 985 programs that emit JS is identical.

### Measured

`results/sweep*.md`: instructions (median) and P-core cycles least / median
/ most over 16 placements.

Main against the branch, three rounds (`results/sweep12.jsonl`: one, then
two more), the least per placement; the last column is the branch's cycles
over main's at the same placement.

| port | instructions G, main | branch | | P-core cycles G, main | branch | branch / main |
|---|---:|---:|---:|---|---|---|
| rbtree | 22.205 | 19.207 | -13.5% | 8.323 / 8.510 / 8.809 | 7.407 / 7.806 / 7.930 | 0.846 to 0.936 |
| rbtree-ck | 81.810 | 69.713 | -14.8% | 15.50 / 20.52 / 23.76 | 11.98 / 14.10 / 15.89 | 0.614 to 0.778 |
| rbtree-unsafe | 11.295 | 10.076 | -10.8% | 2.749 / 2.829 / 2.906 | 2.607 / 2.684 / 2.787 | 0.917 to 0.978 |
| rbtree-ck-unsafe | 54.493 | 45.702 | -16.1% | 11.35 / 13.88 / 15.51 | 9.14 / 9.88 / 12.64 | 0.638 to 0.893 |

Maximum resident set, rbtree: 270 MB on main, 132 MB on the branch (one run
each). raytrace (one `CID_T` entry differs): 83.02G and 83.24G instructions
on main, 83.20G and 83.16G on the branch.

Where the gain comes from (`results/split.md`, one round): `pad` shares the
words but pads the node back to 5 words, so its block stays at 8
(`tools/split.sh`; the compiler change for it is three lines in a scratch
copy, see the script).

| port | variant | instructions G | P-core cycles G | over main, per placement |
|---|---|---:|---|---|
| rbtree | main | 22.067 | 8.363 / 8.591 / 8.861 | |
| | pad | 19.966 | 8.369 / 8.454 / 8.735 | 0.969 to 1.019 |
| | branch | 19.180 | 7.703 / 7.853 / 8.060 | 0.891 to 0.937 |
| rbtree-ck | main | 81.683 | 15.34 / 21.32 / 25.84 | |
| | pad | 78.333 | 15.02 / 19.69 / 22.96 | 0.692 to 1.147 |
| | branch | 68.169 | 11.79 / 13.80 / 16.26 | 0.546 to 0.818 |

Sharing the words alone takes 9.5% of rbtree's instructions (fewer loads)
and none of its cycles; the cycles come with the smaller block. That is why
the rule asks for a lower size class.

### Checks

- `results/lanes.jsonl`, `results/lanes_new_tests.jsonl`: every program whose C changes, main against the
  branch: C lane, JS lane, interpreter, and the C with poisoned frees and a
  live-word count at 1 and 8 threads (`tools/lanes.py --mem`): all the same,
  every test's `#|` lines met, 0 live words at exit everywhere.
- `adv/`: `pack_deep.bend` (the new test with a 1,000,000-node spine; C only,
  the interpreter overflows), `pack_foreign.*` (foreign C writes a packable
  type): same output and 0 live words on main and the branch, 1 and 8
  threads (the lanes compare the last 12 lines of a demo's output; the demos
  have no `#|` lines). The new test on Metal (`--gpu on`): same as the interpreter.
- Wrong versions (`tools/wrong.py`, `tools/wrong_run.sh`,
  `tools/wrong_repo.sh`), each against the new tests (`adv/` and the
branch's two tests: C, poisoned frees, 1 and 8 threads) and against the
repo's 9 tests whose C changes:

| wrong version | new tests | repo's tests |
|---|---|---|
| `nofixed`: pack a type foreign C writes | caught (foreign test faults) | not caught |
| `noreadmask`: a tag read without its mask | caught (hashes) | not caught |
| `overlap`: a field one bit short of its width | caught (hashes) | caught (bst_insert) |
| `arity`: `CID_T` keeps the old word count | caught (faults) | not caught |
| `spine`: the spine's slot not remapped | caught (20,415 live words at exit; a fault at 8 threads) | not caught |
| `bits64`: two `U32` in one word | caught (faults) once the test shares and drops a `Qn`; not before | not caught |
| `nowritemask`: no mask on write | not caught: tags are in range by construction, the mask is a guard | not caught |
| `sparecls`: a reused node's class from the old word count | caught (faults) | caught (bst_insert) |
