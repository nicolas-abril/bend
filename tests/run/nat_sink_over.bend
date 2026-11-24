# A loop's sum that grows in two arms is tested where the loop answers it
# and every 2^15 turns (C lane), not at each add: six turns that add a third
# of 2^48-1 three times land on it and pass; with one more on the other
# three turns the sum passes it on the fifth turn and the program stops
# with the limit's message. The third, 5592405 * 16777217, is scaled by
# the command line's length (1 in the harness), so no compiler sees it.
import Base

def cnt(+n: Nat, even: Bool, acc: Nat, +big: Nat, +s: Nat) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+p:
      match even:
        case True{}:
          cnt(p, Nat.is_eq(Nat.mod(p, 2n), 0n), Nat.add(acc, big), big, s)
        case False{}:
          cnt(p, Nat.is_eq(Nat.mod(p, 2n), 0n), Nat.add(acc, s), big, s)

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    +k : Nat = List.length(&1, String, xs)
    +big : Nat = Nat.mul(k, Nat.mul(5592405n, 16777217n))
    IO.print(Nat.show(cnt(4n, True{}, 0n, big, k)))
    IO.print(Nat.show(cnt(6n, True{}, 0n, big, Nat.sub(k, 1n))))
    IO.print(Nat.show(cnt(6n, True{}, 0n, big, k)))

#|187649984473772
#|281474976710655
#|bend: a Nat past the largest immediate 2^48-1
#|exit 1
