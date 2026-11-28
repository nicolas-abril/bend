# A product's bounds are taken whole, not modulo the machine word (C lane):
# 2^40 * 2^40 is 2^80, which a 64-bit word holds as 0, and the mul keeps
# its test. 2^20 * 2^20 fits and passes.
import Base

def sq(+x: Nat) -> Nat:
  Nat.mul(x, x)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Nat.show(sq(Nat.mul(1024n, 1024n))))
    IO.print(Nat.show(sq(Nat.mul(Nat.mul(16777216n, 256n), 256n))))

#|1099511627776
#|bend: a Nat past the largest immediate 2^48-1
#|exit 1
