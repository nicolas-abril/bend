# A sum tested only where its loop answers it would wrap the 64-bit word
# after 2^16 adds past 2^48-1 and answer a small number; the loop also
# tests it every 2^15 turns (C lane), so 196611 turns that add a third of
# 2^48-1 (its 2^64 + 2^48 + ... wraps to under 2^48) still stop with the
# limit's message. The third is scaled by the command line's length (1 in
# the harness).
import Base

def cnt(+n: Nat, even: Bool, acc: Nat, +big: Nat) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+p:
      match even:
        case True{}:
          cnt(p, Nat.is_eq(Nat.mod(p, 2n), 0n), Nat.add(acc, big), big)
        case False{}:
          cnt(p, Nat.is_eq(Nat.mod(p, 2n), 0n), Nat.add(big, acc), big)

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    +k : Nat = List.length(&1, String, xs)
    IO.print(Nat.show(cnt(Nat.mul(k, 196611n), False{}, 0n, Nat.mul(k, Nat.mul(5592405n, 16777217n)))))

#|bend: a Nat past the largest immediate 2^48-1
#|exit 1
