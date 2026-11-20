# a name rebound between the sunk let and the call: the let must read the
# old value, which the code after the call also reads
import Base

def f(+n: Nat, +x: U32) -> U32:
  match n:
    case 0n:
      x
    case 1n+p:
      +x2 = U32.add(x, 7)
      +b = U32.mul(x, 3)
      U32.add(f(p, x2), U32.xor(b, U32.add(x2, x)))

def g(+n: Nat, +x: U32, +k: U32) -> U32:
  match n:
    case 0n:
      U32.add(x, k)
    case 1n+p:
      +b = U32.mul(x, k)
      +k = U32.add(k, 1)
      U32.xor(g(p, U32.add(x, 1), k), U32.add(b, U32.add(x, k)))

def h(+n: Nat, +x: U32) -> U32:
  match n:
    case 0n:
      x
    case 1n+p:
      +y = U32.add(x, 1)
      +b = U32.mul(x, 5)
      +x = U32.add(y, 100)
      U32.add(h(p, y), U32.xor(b, x))

def main() -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.print(U32.show(f(18n, 12345)))
    Unit <- IO.print(U32.show(g(18n, 99, 5)))
    IO.print(U32.show(h(18n, 4242)))
