# lets of U32 ops before a non-tail self call, the last two read only after
# it (they sink), the first read by the call (it stays); queens' shape
import Base

def walk(+f: Nat, +a: U32, +b: U32, +acc: U32) -> U32:
  match f:
    case 0n:
      U32.add(acc, a)
    case 1n+g:
      +c = U32.xor(a, U32.shl(b))
      +x = U32.and(a, U32.sub(0, a))
      +y = U32.or(b, x)
      walk(g, U32.sub(a, x), U32.add(y, b), walk(g, U32.add(c, 3), U32.shr(b), U32.add(acc, c)))

def main() -> IO(Unit):
  IO.print(U32.show(walk(16n, 2654435761, 40503, 7)))
