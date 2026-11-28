# A Bool parameter bounds a Nat one only if every call passes it as the
# comparison (C lane): f is called once as f(x, x < 10) (in h) and once with True
# and 2^48-1, so in its True arm n is not under 10, and g, which multiplies
# what that arm hands it by 2^40, keeps the test of its mul.
import Base

def top() -> Nat:
  Nat.add(Nat.mul(16777215n, 16777216n), 16777215n)

def g(+m: Nat) -> Nat:
  Nat.mul(m, Nat.mul(1048576n, 1048576n))

@unsafe
def f(+n: Nat, small: Bool) -> Nat:
  match small:
    case True{}:
      g(n)
    case False{}:
      f(Nat.div(n, 10n), Nat.is_lt(Nat.div(n, 10n), 10n))

def h(+x: Nat) -> Nat:
  f(x, Nat.is_lt(x, 10n))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Nat.show(h(12345n)))
    IO.print(Nat.show(f(top(), True{})))

#|1099511627776
#|bend: a Nat past the largest immediate 2^48-1
#|exit 1
