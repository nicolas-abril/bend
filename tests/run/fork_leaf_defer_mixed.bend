# deferred leaves beside a three-call fork (eager, so the grow runs it):
# psum's leaves are deferred as tasks, and the results add up as in sequence.
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
      go(p, Nat.add(i, 3n), Nat.add(acc, gcd(1234567n, i)))

def psum(+k: Nat, +n: Nat, +i: Nat) -> Nat:
  match k:
    case 0n:
      go(n, i, 0n)
    case 1n+kp:
      a b = psum(kp, n, i)  psum(kp, Nat.add(n, 7n), Nat.add(i, n))
      Nat.add(a, b)

def main() -> Nat:
  a b c = psum(3n, 30000n, 1n) psum(2n, 40000n, 5n) psum(4n, 12000n, 11n)
  Nat.add(Nat.add(a, b), c)

#|1792738n
