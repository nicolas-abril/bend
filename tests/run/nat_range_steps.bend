# A loop's turns are bounded by a parameter only if every self-call steps
# it down (C lane): here one arm passes i on as 1 + its predecessor, so i
# bounds no turns and the sum of a third of 2^48-1 per turn keeps its test.
# One turn on i and two or three on j: three thirds land on the limit, four
# pass it.
import Base

def third() -> Nat:
  Nat.mul(5592405n, 16777217n)

@unsafe
def loop(+i: Nat, +j: Nat, +acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      match j:
        case 0n:
          loop(p, 0n, Nat.add(acc, third()))
        case 1n+q:
          loop(Nat.add(p, 1n), q, Nat.add(acc, third()))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Nat.show(loop(1n, 2n, 0n)))
    IO.print(Nat.show(loop(1n, 3n, 0n)))

#|281474976710655
#|bend: a Nat past the largest immediate 2^48-1
#|exit 1
