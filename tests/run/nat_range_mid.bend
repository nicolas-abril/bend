# A loop that prints as it goes stops at the add that passes 2^48-1 (C
# lane), after printing every value before it: the bounds of its five
# turns of a third each reach past the limit, so the add keeps its test.
import Base

def third() -> Nat:
  Nat.mul(5592405n, 16777217n)

def walk(+i: Nat, +acc: Nat) -> IO(Unit):
  match i:
    case 0n:
      IO.print("end")
    case 1n+p:
      do IO<Unit>:
        IO.print(Nat.show(acc))
        walk(p, Nat.add(acc, third()))

def main() -> IO(Unit):
  walk(5n, 0n)

#|0
#|93824992236885
#|187649984473770
#|281474976710655
#|bend: a Nat past the largest immediate 2^48-1
#|exit 1
