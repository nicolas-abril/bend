# a deep tree recursion (a comb 30000 deep) whose calls end at once on one
# side, and a fuel-bounded search shaped like queens' solve
import Base

type T is Data:
  Leaf{v: U32}
  Node{l: T, r: T}

def comb(+d: Nat, +s: U32) -> T:
  match d:
    case 0n:
      Leaf{s}
    case 1n+p:
      Node{Leaf{U32.add(s, 1)}, comb(p, U32.mul(s, 5))}

def dep(t: T, +k: U32) -> U32:
  match t:
    case Leaf{v}:
      U32.add(v, k)
    case Node{l, r}:
      U32.xor(dep(r, U32.inc(k)), U32.add(dep(l, k), k))

def srch(+f: Nat, z: Bool, +c: U32, +full: U32, +acc: U32) -> U32:
  match f z:
    case 0n _:
      acc
    case 1n+g True{}:
      acc
    case 1n+g False{}:
      +b = U32.and(c, U32.sub(0, c))
      +rest = U32.sub(c, b)
      +cc = U32.and(full, U32.shr(U32.or(rest, U32.shl(b))))
      srch(g, U32.is_zero(rest), rest, full, srch(g, U32.is_zero(cc), cc, full, U32.add(acc, b)))

def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.print(U32.show(dep(comb(30000n, 1), 3)))
    IO.print(U32.show(srch(40n, False{}, 4095, 4095, 0)))
