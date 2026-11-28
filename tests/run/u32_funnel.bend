# word funnels, (lo >> s) | ((hi << 1) << (31 - s)) and its spellings: the
# compiler emits each as one 64-bit shift (a constant s as one word funnel).
# Amounts 0..39 (32 and past give 0 unmasked), masked amounts past 32, words
# read from an array pair and in registers, and constant amounts
import Base

# a count the compiler cannot read: no loop here is unrolled
def zero(r: Array<U32> & U32) -> U32:
  (a, x) = r
  x

def var(+k: U32) -> U32:
  (k + zero(Array.get(U32, [0 : U32*1n], 0)) : U32)

# the << 1 inside
def fa(+lo: U32, +hi: U32, +s: U32) -> U32:
  ((lo >> U32.to_nat(s)) .|. ((hi << 1n) << U32.to_nat((31 - s : U32))) : U32)

# the << 1 outside, the or's sides swapped
def fb(+lo: U32, +hi: U32, +s: U32) -> U32:
  ((U32.shln(hi, U32.to_nat((31 - s : U32))) << 1n) .|. U32.shrn(lo, U32.to_nat(s)) : U32)

# masked amounts
def fm(+lo: U32, +hi: U32, +n: U32) -> U32:
  ((lo >> U32.to_nat((n .&. 31 : U32))) .|. ((hi << 1n) << U32.to_nat(((31 - n) .&. 31 : U32))) : U32)

def peek_hi(r: Array<U32> & U32, +lo: U32, +s: U32) -> Array<U32> & U32:
  (a, hi) = r
  (a, fb(lo, hi, s))

def peek_lo(r: Array<U32> & U32, +q: U32, +s: U32) -> Array<U32> & U32:
  (a, lo) = r
  peek_hi(Array.get_unchecked(U32, a, (q + 1 : U32)), lo, s)

# the 32 bits from bit bp of a
def peek(a: Array<U32>, +bp: U32) -> Array<U32> & U32:
  peek_lo(Array.get_unchecked(U32, a, (bp >> 5n : U32)), (bp >> 5n : U32), (bp .&. 31 : U32))

def mix(+acc: U32, +x: U32) -> U32:
  ((acc * 31) .^. x : U32)

# the three funnels at amounts k..k + n - 1, mixed
def regs(n: Nat, +k: U32, +acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      +lo = (2654435761 * (k + 1) : U32)
      +hi = (2246822519 * (k + 7) : U32)
      regs(p, (k + 1 : U32), mix(mix(mix(acc, fa(lo, hi, k)), fb(lo, hi, k)), fm(lo, hi, (k * 37 : U32))))

type Pz is Type:
  Pz{a: Array<U32>, bp: U32, acc: U32}

def peeks.got(r: Array<U32> & U32, +bp: U32, +acc: U32) -> Pz:
  (a, x) = r
  +v = x
  Pz{a, (bp + 3 : U32), mix(acc, v)}

# peeks from bits 0, 3, 6, ...
def peeks(n: Nat, st: Pz) -> Pz:
  match n, st:
    case 0n, r:
      r
    case 1n+p, Pz{a, bp, acc}:
      +b = bp
      peeks(p, peeks.got(peek(a, b), b, acc))

def peeks.acc(st: Pz) -> U32:
  match st:
    case Pz{a, bp, acc}:
      acc

def ramp(n: Nat, +i: U32, a: Array<U32>) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      ramp(p, (i + 1 : U32), a[i] <- (3266489917 * (i + 3) : U32))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(U32.show(regs(U32.to_nat(var(40)), var(0), 0)))
    IO.print(U32.show(peeks.acc(peeks(U32.to_nat(var(300)), Pz{ramp(U32.to_nat(var(32)), 0, [0 : U32*32n]), var(0), 0}))))
    # constant amounts
    IO.print(U32.show(fa(2654435761, 2246822519, 0)))
    IO.print(U32.show(fa(2654435761, 2246822519, 13)))
    IO.print(U32.show(fb(2654435761, 2246822519, 31)))
    IO.print(U32.show(fa(2654435761, 2246822519, 32)))
    IO.print(U32.show(fm(2654435761, 2246822519, 45)))

#|1771246049
#|3561747553
#|2654435761
#|1404891579
#|198677743
#|0
#|1404891579
