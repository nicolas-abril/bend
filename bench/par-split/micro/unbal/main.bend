# micro: an unbalanced parfor. An outer fork tree over 1024 items (grain 1);
# item i is an inner fork tree (grain 4096) summing an LCG over W / (i + 1)
# elements, so the first items hold most of the work (harmonic), as in primes.
import Base

def work(+k: Nat, +x: U32) -> U32:
  match k:
    case 0n:
      x
    case 1n+p:
      work(p, (x * 1664525 + 1013904223 : U32))

@unsafe
def inner(+lo: U32, +hi: U32) -> U32:
  inner.go(U32.is_le((hi - lo : U32), 4096), lo, hi)

@unsafe
def inner.go(small: Bool, +lo: U32, +hi: U32) -> U32:
  match small:
    case True{}:
      work(U32.to_nat((hi - lo : U32)), lo)
    case False{}:
      +mid = (lo + (hi - lo) / 2 : U32)
      a b = inner(lo, mid) inner(mid, hi)
      (a + b : U32)

@unsafe
def outer(+w: U32, +lo: U32, +hi: U32) -> U32:
  outer.go(U32.is_eq((hi - lo : U32), 1), w, lo, hi)

@unsafe
def outer.go(one: Bool, +w: U32, +lo: U32, +hi: U32) -> U32:
  match one:
    case True{}:
      inner(0, (w / (lo + 1) : U32))
    case False{}:
      +mid = (lo + (hi - lo) / 2 : U32)
      a b = outer(w, lo, mid) outer(w, mid, hi)
      (a + b : U32)

@unsafe
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    IO.print(U32.show(outer(U32.from_nat(Nat.mul(400000000n, List.length(&1, String, args))), 0, 1024)))
