# A def named anywhere but as the head of a full call takes anything (C
# lane): dbl's one direct call passes 5, but app also hands it to a closure
# call with 2^48-1, so dbl's mul keeps its test.
import Base

def top() -> Nat:
  Nat.add(Nat.mul(16777215n, 16777216n), 16777215n)

def dbl(n: Nat) -> Nat:
  Nat.mul(n, 2n)

def app(f: Nat -> Nat, x: Nat) -> Nat:
  f(x)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Nat.show(dbl(5n)))
    IO.print(Nat.show(app(dbl, top())))

#|10
#|bend: a Nat past the largest immediate 2^48-1
#|exit 1
