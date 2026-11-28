# Bounds the compiler reads off literals, matches and calls let it emit a
# Nat add or mul with no test of the limit 2^48-1 (C lane): here each lands
# on the limit or near it and passes. 2^48-1 = 16777215 * 16777216 +
# 16777215, and a third of it is 5592405 * 16777217. A countdown of three
# turns adds three thirds; a digit sum loop as the Osprey port spells it (a
# Bool that compares n); a division and a remainder by a zero, which answer
# 0 and the dividend.
import Base

def top() -> Nat:
  Nat.add(Nat.mul(16777215n, 16777216n), 16777215n)

def thirds(+i: Nat, acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      thirds(p, Nat.add(acc, Nat.mul(5592405n, 16777217n)))

@unsafe
def digsum(+n: Nat, small: Bool) -> Nat:
  match small:
    case True{}:
      n
    case False{}:
      Nat.add(Nat.mod(n, 10n), digsum(Nat.div(n, 10n), Nat.is_lt(Nat.div(n, 10n), 10n)))

def go(+i: Nat, acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      go(p, Nat.add(acc, digsum(i, Nat.is_lt(i, 10n))))

def zdiv(+a: Nat, +b: Nat) -> Nat:
  Nat.add(Nat.div(a, b), Nat.mod(a, b))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Nat.show(top()))
    IO.print(Nat.show(thirds(3n, 0n)))
    IO.print(Nat.show(go(1000n, 0n)))
    IO.print(Nat.show(zdiv(Nat.sub(top(), 5n), 0n)))
    IO.print(Nat.show(Nat.add(zdiv(top(), 0n), 0n)))

#|281474976710655
#|281474976710655
#|13501
#|281474976710650
#|281474976710655
