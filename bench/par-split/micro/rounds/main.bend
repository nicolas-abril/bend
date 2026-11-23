# micro: a round-based loop of short parallel maps. 1000 rounds; each round is
# a fork tree of depth 6 whose 64 leaves each run 20000 steps of an LCG; the
# next round's seed depends on this round's sum.
import Base

def work(+k: Nat, +x: U32) -> U32:
  match k:
    case 0n:
      x
    case 1n+p:
      work(p, (x * 1664525 + 1013904223 : U32))

def tree(+d: Nat, +k: Nat, +i: U32) -> U32:
  match d:
    case 0n:
      work(k, i)
    case 1n+p:
      a b = tree(p, k, (i * 2 : U32)) tree(p, k, (i * 2 + 1 : U32))
      (a + b : U32)

def rounds(+r: Nat, +d: Nat, +k: Nat, +acc: U32) -> U32:
  match r:
    case 0n:
      acc
    case 1n+p:
      rounds(p, d, k, (acc + tree(d, k, acc) : U32))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    IO.print(U32.show(rounds(Nat.mul(1000n, List.length(&1, String, args)), 6n, 20000n, 0)))
