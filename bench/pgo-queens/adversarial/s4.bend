# every U32 operation kind in sunk lets, with division and modulo by zero,
# shifts by a Nat and past 32, a comparison, and a constant
import Base

def ops(+n: Nat, +a: U32, +b: U32) -> U32:
  match n:
    case 0n:
      U32.add(a, b)
    case 1n+p:
      +q = U32.div(a, U32.and(b, 3))
      +m = U32.mod(a, U32.and(b, 1))
      +s = U32.shln(a, U32.to_nat(U32.and(b, 63)))
      +t = U32.shrn(b, 33n)
      +c : U32 = 1000
      +z = U32.add(U32.mul(U32.not(a), b), U32.sub(q, m))
      +e = U32.add(U32.mul(a, a), U32.xor(b, 77))
      U32.add(ops(p, U32.add(b, 1), U32.mul(a, 3)), U32.add(U32.add(U32.add(q, m), e), U32.add(U32.add(s, U32.add(t, U32.add(a, b))), U32.add(c, z))))

def main() -> IO(Unit):
  IO.print(U32.show(ops(20n, 77, 1234567)))
