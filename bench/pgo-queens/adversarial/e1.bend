# tree recursions whose calls often end at once (a callee that calls itself
# twice on a path): continuations that read several frame words, an owned
# list kept across the call, a pair result, and a call into another tree def
import Base

type T is Data:
  Leaf{+v: U32}
  Node{l: T, r: T}

def mk(+d: Nat, +s: U32) -> T:
  match d:
    case 0n:
      Leaf{s}
    case 1n+p:
      Node{mk(p, U32.mul(s, 3)), mk(p, U32.add(s, 7))}

def sum(t: T, +k: U32, +m: U32) -> U32:
  match t:
    case Leaf{v}:
      U32.xor(v, k)
    case Node{l, r}:
      +a = U32.add(k, m)
      U32.add(U32.mul(sum(l, a, m), 3), U32.add(sum(r, U32.inc(k), a), U32.xor(a, m)))

def keep(t: T, xs: List<U32>) -> List<U32>:
  match t:
    case Leaf{v}:
      v <> xs
    case Node{l, r}:
      keep(r, keep(l, xs))

def len(xs: List<U32>, +n: U32) -> U32:
  match xs:
    case Nil{}:
      n
    case h <> t:
      len(t, U32.add(n, h))

def two.join(a: U32 & U32, b: U32 & U32, +k: U32) -> U32 & U32:
  (a1, a2) = a
  (b1, b2) = b
  (U32.add(a1, b2), U32.xor(a2, U32.add(b1, k)))

def two(t: T, +k: U32) -> U32 & U32:
  match t:
    case Leaf{v}:
      (v, U32.add(v, k))
    case Node{l, r}:
      two.join(two(l, U32.inc(k)), two(r, U32.add(k, 2)), k)

def two.fst(p: U32 & U32) -> U32:
  (a, b) = p
  U32.add(a, U32.mul(b, 5))

def via(t: T, +k: U32) -> U32:
  match t:
    case Leaf{v}:
      U32.add(v, k)
    case Node{l, r}:
      U32.add(sum(l, k, 1), via(r, U32.inc(k)))

def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.print(U32.show(sum(mk(14n, 1), 5, 9)))
    Unit <- IO.print(U32.show(len(keep(mk(12n, 2), []), 0)))
    Unit <- IO.print(U32.show(two.fst(two(mk(13n, 3), 1))))
    IO.print(U32.show(via(mk(11n, 4), 2)))
