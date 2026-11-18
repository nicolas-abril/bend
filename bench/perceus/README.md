# The Perceus benchmark set in Bend

Ports of the five programs of the Perceus paper ("Perceus: Garbage Free
Reference Counting with Reuse", PLDI 2021), taken from the Koka repository,
`test/bench/koka/` at commit b66091b2a5a7ea20c5ed9498ad1e1f03caee9589
(https://github.com/koka-lang/koka). The Koka sources are not copied here:
they carry their own licence. Each port is the same algorithm on the same
data structure at the same problem size, and prints what the Koka program
prints.

These are not graded by the perf gate (that is `bench/runtime`) and this
directory is not in `gates/repo.ts`' allow list.

| port | Koka source | size | prints |
|---|---|---|---|
| `rbtree` | `rbtree.kk` | 4,200,000 inserts, keys 4,199,999 down to 0 | `420000` |
| `rbtree-ck` | `rbtree-ck.kk` | 4,200,000 inserts, keys 4,200,000 down to 1, every 5th tree kept | `420000` |
| `deriv` | `deriv.kk` | 10 derivatives of `x^x` | `1 count: 6` to `10 count: 40230090`, then `done` |
| `cfold` | `cfold.kk` | `mk_expr(20, 1)` | `3447966` twice, one per line |
| `nqueens` | `nqueens.kk` | 13 queens | `73712` |

`rbtree-unsafe` and `rbtree-ck-unsafe` are second spellings of the two tree
programs, shaped exactly like the Koka source (see below).

## Running

    bend bench/perceus/rbtree/main.bend -o rbtree
    ./rbtree +RTS --threads 1 --gpu off -RTS

Run with no arguments. Every size is multiplied by the length of `IO.args`
(1 with no arguments), so that no compiler lane sees a literal size and
unrolls or folds the work. Check outputs on the native lane: the
interpreter and the JS lane fault on deep recursion at these sizes.

## Deviations from the Koka sources

All five:
- Sizes come from `IO.args` as above; the Koka programs use literals (and
  `rbtree.kk` an optional argument).
- The programs are sequential, as the references are: no parallel `let`.
- A countdown that Koka writes on an `int` is a `Nat` matched as `1n+p`
  (structural recursion); the key or queen is `U32.from_nat` of it.
- A `match` in Bend inspects a parameter, not a computed value, so a test
  on a computed value is a small helper def (`leaf`, `dec0`, `cfold.add`,
  `d.var`, `push`, `keep`, `count_true`).

`rbtree`:
- Keys are `U32` (Koka: `int32`).
- `fold` takes its function as a template (`~f`), since a closure is
  affine and `fold` applies it once per node.
- `ins` takes the comparison of the key with the root's key as a parameter
  (`o: Cmp`) and looks one level down in its patterns to compute the
  comparison for the child it descends into. This is the spelling the
  termination checker accepts (the idiom of Base's `Map`): the Koka shape,
  a comparison followed by a recursive call in the chosen branch, needs
  either a `match` on a computed value or two defs that call each other.
  `is-red` and the `Leaf` insert are folded into `ins`' patterns for the
  same reason. Same inserts, same rebalancing, same tree.
- `rbtree-unsafe` is the Koka shape itself: `ins` matches the tree and
  hands the comparison to helper defs (`ins.red`, `ins.black`, ...) that
  call back into `ins`. That is mutual recursion, so those defs are
  `@unsafe`. `is_red` hands the tree back beside its answer.

`rbtree-ck`:
- Keys are `U32` (Koka: `int`, never above 4,200,000 here).
- The frequency is 5, as in every reference (`make-tree(5, 4200000)`).
- Otherwise as `rbtree`, with `rbtree-ck-unsafe` as the Koka shape.

`deriv`:
- `Val` holds a `U32` (Koka: an unbounded `int`). `Val(-1)` is
  `4294967295`; add and multiply wrap, which is two's complement, and the
  only tests are against 0 and 1. In the C++ reference no `Val` in this
  run is anything but -1, 0 or 1, so nothing wraps.
- `pown` is a product over a `Nat` exponent. It is never called in this
  run (every `Pow` has the variable as its base); a negative exponent
  would not be supported.
- `add` and `mul` are `@unsafe`: they recurse on swapped and rebuilt
  arguments (`add(Val{n}, f)` from `add(f, Val{n})`), which is not
  structural. Koka marks the same two functions `div`.
- `Var` holds a `String`, compared with `String.eq`, as in Koka.
- `nest` takes `deriv` as a template; `deriv` prints through `IO`.
- Koka marks `d`'s and `count`'s expression as borrowed (`^e`). Bend has
  no such mark: the compiler decides.

`cfold`:
- Values are `U32` (Koka: `int`); the largest is the result, 3,447,966.
- `max(v - 1, 0)` is `dec0`, which tests for zero first.

`nqueens`:
- Queens are `U32` (Koka: `int32`). `q - diag` wraps where Koka's goes
  negative; neither can equal a queen.
- `safe` carries its answer so far as a parameter and stops at the first
  node after a clash, instead of Koka's short-circuit `&&` around the
  recursive call (a tail call under a computed test is again a `match` on
  a computed value). One extra step per clash.
- `append_safe` hands the test's answer to `push`, which conses or not.
- The result is a `Nat` (`List.length`).

## References

The other implementations are in the Koka repository under `test/bench/`
(`cpp`, `ocaml`, `haskell`, `swift`, `java`, `lean`), built by its CMake
files with `-O3 -DNDEBUG` (C++17), `ghc -O2`, `ocamlopt -O2`,
`swiftc -O -whole-module-optimization`. Three are not the same work:
`cpp/rbtree.cpp` is `std::map` (a mutable tree, updated in place);
`cpp/rbtree-ck.cpp` copies the whole map at each checkpoint and is run at
4,200 in the repository (it returns 1, "not working"); `cpp/cfold.cpp`'s
`const_folding` does not recurse. The C++ `deriv`, `cfold` and `nqueens`
never free.
