# A remainder by a divisor that may be zero is its dividend, not under the
# divisor (C lane): the bounds of `a % b` for b in 0..2 reach a's, so the
# add of two such remainders keeps its test and stops at the limit. b is 0
# when the command line has one argument, as in the harness.
import Base

def top() -> Nat:
  Nat.add(Nat.mul(16777215n, 16777216n), 16777215n)

def small(+k: Nat) -> Nat:
  match k:
    case 0n:
      2n
    case 1n+p:
      match p:
        case 0n:
          0n
        case 1n+q:
          1n

def twice(+a: Nat, +b: Nat) -> Nat:
  Nat.add(Nat.mod(a, b), Nat.mod(a, b))

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    +b : Nat = small(List.length(&1, String, xs))
    IO.print(Nat.show(twice(9n, b)))
    IO.print(Nat.show(twice(top(), b)))

#|18
#|bend: a Nat past the largest immediate 2^48-1
#|exit 1
