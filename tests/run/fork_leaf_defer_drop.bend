# a leaf whose segment drops a value before its loop: rerunning the segment
# would drop it twice, so the grow runs this leaf as it would (no deferral);
# the list is dropped once and the sum is as in sequence.
import Base

@unsafe
def gcd(+a: Nat, +b: Nat) -> Nat:
  match b:
    case 0n:
      a
    case 1n+bp:
      gcd(b, Nat.mod(a, b))

def go(+n: Nat, +i: Nat, acc: Nat) -> Nat:
  match n:
    case 0n:
      acc
    case 1n+p:
      go(p, Nat.add(i, 1n), Nat.add(acc, gcd(i, 1234567n)))

def len(xs: List<Nat>) -> Nat:
  match xs:
    case []:
      0n
    case h <> t:
      Nat.add(1n, len(t))

def psum(+k: Nat, xs: List<Nat>, +n: Nat, +i: Nat) -> Nat:
  match k:
    case 0n:
      go(n, i, 0n)
    case 1n+kp:
      a b = psum(kp, [kp, n], n, i)  psum(kp, [i, kp], n, Nat.add(i, len(xs)))
      Nat.add(a, b)

def main() -> Nat:
  psum(4n, [1n, 2n, 3n], 30000n, 1n)

#|1422336n
