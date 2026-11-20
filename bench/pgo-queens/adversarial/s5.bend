# deep non-tail recursion (20000 frames) with sunk lets at each level; a
# closure that captures the sunk let's operand; a sunk let feeding a match's
# helper (a def that is also passed as a template)
import Base

def deep(+n: Nat, +a: U32) -> U32:
  match n:
    case 0n:
      a
    case 1n+p:
      +x = U32.mul(a, 31)
      +y = U32.add(x, 1)
      U32.xor(deep(p, U32.inc(a)), U32.add(y, a))

def cl(+n: Nat, +a: U32) -> U32:
  match n:
    case 0n:
      a
    case 1n+p:
      +x = U32.mul(a, 7)
      f : U32 -> U32 = z => U32.add(z, a)
      f(U32.add(cl(p, U32.inc(a)), U32.add(x, a)))

def tw(x: U32) -> U32:
  U32.mul(x, 3)

def ap(~t: U32 -> U32, +n: Nat, +a: U32) -> U32:
  match n:
    case 0n:
      t(a)
    case 1n+p:
      +x = U32.add(a, 9)
      U32.add(t(ap(~t, p, U32.inc(a))), U32.add(x, a))

def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.print(U32.show(deep(20000n, 1)))
    Unit <- IO.print(U32.show(cl(1000n, 2)))
    Unit <- IO.print(U32.show(ap(~tw, 30n, 5)))
    IO.print(U32.show(tw(ap(~tw, 3n, 1))))
