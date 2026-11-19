# Issue #2141's repro: 2,000 rounds of a sequential stretch (400,000 steps)
# and then two leaves of 2,000 steps, in a parallel let (0n = 1n) or one
# after the other (0n = 0n).
import Base

def spin(n: Nat, +x: U32) -> U32:
  match n:
    case 0n:
      x
    case 1n+p:
      spin(p, ((x * 1664525 : U32) + 1013904223 : U32))

def pair(fork: Nat, +s: U32) -> U32:
  match fork:
    case 0n:
      (spin(2000n, s) + spin(2000n, (s + 1 : U32)) : U32)
    case 1n+f:
      a b = spin(2000n, s) spin(2000n, (s + 1 : U32))
      (a + b : U32)

def go(k: Nat, +x: U32) -> U32:
  match k:
    case 0n:
      x
    case 1n+p:
      go(p, pair(0n, spin(400000n, x)))

def main() -> IO(Unit):
  IO.print(U32.show(go(2000n, 1)))
