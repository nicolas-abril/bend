# micro: a shared array forked per element. 4096 queries in parallel (grain
# 1); each descends a fork tree of depth 12, handing both sides an Array.fork
# of one shared array, each leaf reading one cell.
import Base

def lcg(+x: U32) -> U32:
  (x * 1664525 + 1013904223 : U32)

def rd(+x: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (a, +v) = r
  (a, (x + v : U32))

def q.join(l: Array<U32> & U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (a, +x) = l
  (b, +y) = r
  (Array.join(U32, a, b), (x + y : U32))

@unsafe
def q.fork(+d: Nat, +x: U32, f: Array<U32> & Array<U32>) -> Array<U32> & U32:
  (a0, a1) = f
  l r = q(d, lcg(x), a0) q(d, lcg((x + 1 : U32)), a1)
  q.join(l, r)

@unsafe
def q(+d: Nat, +x: U32, a: Array<U32>) -> Array<U32> & U32:
  match d:
    case 0n:
      rd(x, a[(x % 1048576 : U32)])
    case 1n+p:
      q.fork(p, x, Array.fork(U32, a))

@unsafe
def qs(+d: Nat, +lo: U32, +hi: U32, a: Array<U32>) -> Array<U32> & U32:
  qs.go(U32.is_eq((hi - lo : U32), 1), d, lo, hi, a)

@unsafe
def qs.fork(+d: Nat, +lo: U32, +mid: U32, +hi: U32, f: Array<U32> & Array<U32>) -> Array<U32> & U32:
  (a0, a1) = f
  l r = qs(d, lo, mid, a0) qs(d, mid, hi, a1)
  q.join(l, r)

@unsafe
def qs.go(one: Bool, +d: Nat, +lo: U32, +hi: U32, a: Array<U32>) -> Array<U32> & U32:
  match one:
    case True{}:
      q(d, lcg(lo), a)
    case False{}:
      qs.fork(d, lo, (lo + (hi - lo) / 2 : U32), hi, Array.fork(U32, a))

def fin(r: Array<U32> & U32) -> U32:
  (a, +x) = r
  x

@unsafe
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    IO.print(U32.show(fin(qs(12n, 0, (4096 * U32.from_nat(List.length(&1, String, args)) : U32), Array.new(U32, 20n, 7)))))
