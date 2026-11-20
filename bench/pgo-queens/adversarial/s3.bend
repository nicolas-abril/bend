# two non-tail calls in a row: a let read only after the second; a let read
# between them; a let before a parallel let (a fork is not a frame call)
import Base

def h(+n: Nat, +a: U32) -> U32:
  match n:
    case 0n:
      a
    case 1n+p:
      +w = U32.shr(U32.mul(a, 2654435761))
      +u = U32.mul(a, 2654435761)
      +v = U32.add(a, 17)
      +r1 = h(p, w)
      +r2 = h(p, U32.add(r1, a))
      U32.add(U32.xor(r2, u), U32.add(v, a))

def k(+n: Nat, +a: U32) -> U32:
  match n:
    case 0n:
      U32.inc(a)
    case 1n+p:
      +u = U32.add(a, 5)
      l r = k(p, a) k(p, U32.inc(a))
      U32.add(U32.add(l, r), U32.add(u, a))

def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.print(U32.show(h(12n, 7)))
    IO.print(U32.show(k(12n, 3)))
