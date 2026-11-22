# General rewrites: static counts over the 230 benchmark programs

Scratch material, not for merging. Compiler: `opt/integration` (bae64757).
Programs: `nicolas-abril/bend-benchmarks` (all 230). Compile-only: no
program was run (another agent was timing the machine).

- `tools/hook.ts`: appended to a copy of `bend2/comp.ts`; `survey(book)` runs
  `file_book` as `compile_book` does, then `c_units`, and records, over the
  defs main reaches, the sites where each candidate rewrite would fire.
  Hotness is static: a def's loop depth is the number of recursive SCCs on the
  deepest call path from `main` ("in a loop" = depth >= 1, "innermost" = the
  program's deepest level). Print and IO defs of Base are left out.
- `tools/survey.ts FILE`, `tools/survey_all.sh OUT`: one JSON line per program
  (`results/survey_integration.jsonl`); `tools/agg.py` sums them.
- `bounds/`: hand bounds, ready to measure with `bounds/run_bounds.sh`
  (instructions, one thread): palindrome with closures against the helper
  chains it was respelled into (bench repo eb33fbb); symreg's `eval` with an
  affine context `a * x + c` carried; #1810 (548fc4a1) against its base
  (4f99f4c1) on eight programs with constructor-context recursion.

## Counts (sites in a loop / programs; innermost sites / programs)

| candidate | in a loop | innermost |
|---|---|---|
| lambda passed to a non-recursive def (closure built) | 851 / 44 | 0 / 0 |
| lambda passed to a recursive def | 0 | 0 |
| self call under a constructor in tail position (TMC) | 126 / 39 | 54 / 21 |
| of those, on a shared (counted) constructor, which #1810 refuses | 57 / 15 | 21 / 7 |
| self call under an operator other than #2175's add | 19 / 13 | 12 / 8 |
| non-tail recursive SCCs, innermost, by context: TMC / op / #2175 acc / helper def / other | | 27 / 9 / 8 / 14 / 22 (21 / 8 / 8 / 12 / 20 programs) |
| frame-pushing calls | 3,837 / 126 | 142 / 43 |
| a word let that could move below a frame push (any op; #2217 is U32) | 3 / 2 | 0 |
| recursion-invariant expression clang cannot hoist (checked op, call, or any op in a segment loop) | 30 / 19 | 5 / 3 |
| a checked op twice in one arm (#2222's domain) | 105 / 33 | 30 / 11 |
| a non-flat call twice in one arm | 7 / 5 | 4 / 4 |
| tail cycles across defs: flat / still segments | 560 / 78 ; 54 / 36 | 123 / 64 ; 2 / 2 |
| #2175 makes a `~acc` def | 15 programs | 12 |
| #2180 makes a `~fix` def | 28 programs | |
| #2218 packs a node | 16 programs | |
| a shared (counted) user constructor (#2207's domain) | 98 programs | |

#2180 fires in 28 programs, and in 23 of them it computes a benchmark
harness's repeated call once: `run~fix` in all 14 `awfy` programs,
`test~fix` / `repeat~fix` in 9 `koka-extra` programs (the other 5 are the
binarytrees ports, as before). Their timings on a build with #2180 measure one iteration.
