# lazy splits from inside a spin: each leaf of a depth-4 fork runs a long
# counted loop (go) whose step runs an inner loop (gcd), so a thread in a
# leaf offers its noted frames, the newest (the fork right above the leaf)
# included, to idle threads. The second call's argument is itself such a
# loop, run by whoever splits the frame (a poll inside a split).
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

def psum(+k: Nat, +n: Nat, +i: Nat) -> Nat:
  match k:
    case 0n:
      go(n, i, 0n)
    case 1n+kp:
      a b = psum(kp, n, i)  psum(kp, n, Nat.add(i, Nat.mod(go(n, i, 0n), 977n)))
      Nat.add(a, b)

def main() -> Nat:
  psum(4n, 60000n, 1n)

#|2845176n
