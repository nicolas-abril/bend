# A Bool parameter bounds a Nat one only if every call passes it as the
# comparison (C lane): f is called once as f(x, x < 10) and once with True
# and a large n, so in its True arm n is not under 10 and n + n keeps its
# test.
import Base

def top() -> Nat:
  Nat.add(Nat.mul(16777215n, 16777216n), 16777215n)

@unsafe
def f(+n: Nat, small: Bool) -> Nat:
  match small:
    case True{}:
      Nat.add(n, n)
    case False{}:
      f(Nat.div(n, 10n), Nat.is_lt(Nat.div(n, 10n), 10n))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Nat.show(f(12345n, Nat.is_lt(12345n, 10n))))
    IO.print(Nat.show(f(top(), True{})))

#|2
#|bend: a Nat past the largest immediate 2^48-1
#|exit 1
