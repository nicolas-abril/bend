# loops over two arrays whose counter a helper steps, in range (the copy
# without the masks runs, the arrays apart) and out of it; and two forks of
# one array, a cell read through one right after the other wrote it
import Base

# a count the compiler cannot read: no loop here is unrolled
def zero(r: Array<U32> & U32) -> U32:
  (a, x) = r
  x

def nat(+k: U32) -> Nat:
  U32.to_nat((k + zero(Array.get(U32, [0 : U32*1n], 0)) : U32))

def hash.go(n: Nat, +j: U32, acc: U32, r: Array<U32> & U32) -> U32:
  match n:
    case 0n:
      (a, x) = r
      (acc * 31 + x : U32)
    case 1n+p:
      (a, x) = r
      +q = (j + 1 : U32)
      hash.go(p, q, (acc * 31 + x : U32), a[q])

# the hash of a's first n + 1 cells
def hash(+n: U32, a: Array<U32>) -> U32:
  hash.go(nat(n), 0, 0, a[0])

def ramp(n: Nat, +i: U32, a: Array<U32>) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      ramp(p, (i + 1 : U32), a[i] <- ((i * 37 + 11) .&. 255 : U32))

type Pk is Type:
  Pk{src: Array<U32>, dst: Array<U32>, j: U32}

# dst[j] packs src[4j..4j+3]: the helpers return j + 1 in the record
def pk.put(r: Array<U32> & U32, dst: Array<U32>, +j: U32, +b0: U32, +b1: U32, +b2: U32) -> Pk:
  (src, b3) = r
  +v = b3
  Pk{src, dst[j] <- (b0 .|. (b1 << 8n) .|. (b2 << 16n) .|. (v << 24n) : U32), (j + 1 : U32)}

def pk.b2(r: Array<U32> & U32, dst: Array<U32>, +j: U32, +b0: U32, +b1: U32) -> Pk:
  (src, b2) = r
  +v = b2
  pk.put(src[((j << 2n) + 3 : U32)], dst, j, b0, b1, v)

def pk.b1(r: Array<U32> & U32, dst: Array<U32>, +j: U32, +b0: U32) -> Pk:
  (src, b1) = r
  +v = b1
  pk.b2(src[((j << 2n) + 2 : U32)], dst, j, b0, v)

def pk.b0(r: Array<U32> & U32, dst: Array<U32>, +j: U32) -> Pk:
  (src, b0) = r
  +v = b0
  pk.b1(src[((j << 2n) + 1 : U32)], dst, j, v)

def pk(n: Nat, st: Pk) -> Pk:
  match n, st:
    case 0n, r:
      r
    case 1n+k, Pk{src, dst, j}:
      +jj = j
      pk(k, pk.b0(src[(jj << 2n : U32)], dst, jj))

def pk.dst(st: Pk) -> Array<U32>:
  match st:
    case Pk{src, dst, j}:
      dst

# a step of two: dst[j] and dst[j + 1] from src[j], j + 2 in the record
def two.put(r: Array<U32> & U32, dst: Array<U32>, +j: U32) -> Pk:
  (src, x) = r
  +v = x
  Pk{src, Array.set(U32, Array.set(U32, dst, j, v), (j + 1 : U32), (v * 3 + 1 : U32)), (j + 2 : U32)}

def two(n: Nat, st: Pk) -> Pk:
  match n, st:
    case 0n, r:
      r
    case 1n+k, Pk{src, dst, j}:
      +jj = j
      two(k, two.put(src[jj], dst, jj))

# b[i] <- a[i - 1] + 1: forks of one array, each cell the one before plus 1
type Fk is Type:
  Fk{a: Array<U32>, b: Array<U32>, i: U32}

def fk.put(r: Array<U32> & U32, b: Array<U32>, +i: U32) -> Fk:
  (a, x) = r
  +v = x
  Fk{a, b[i] <- (v + 1 : U32), (i + 1 : U32)}

def fk(n: Nat, st: Fk) -> Fk:
  match n, st:
    case 0n, r:
      r
    case 1n+k, Fk{a, b, i}:
      +ii = i
      fk(k, fk.put(a[(ii - 1 : U32)], b, ii))

def fk.hash(+n: U32, st: Fk) -> U32:
  match st:
    case Fk{a, b, i}:
      hash((n + 1 : U32), Array.join(U32, a, b))

def fk.run(+n: U32, fs: Array<U32> & Array<U32>) -> U32:
  (a, b) = fs
  fk.hash(n, fk(nat(n), Fk{a, b, 1}))

# a[i] <- a[i - 1] + b[i]: two arrays apart, a cell of a read right after
# the step before wrote it
type Sc is Type:
  Sc{a: Array<U32>, b: Array<U32>, i: U32}

def sc.put(r: Array<U32> & U32, b: Array<U32>, +i: U32, +x: U32) -> Sc:
  (a, y) = r
  +v = y
  Sc{a[i] <- (x + v : U32), b, (i + 1 : U32)}

def sc.get(r: Array<U32> & U32, a: Array<U32>, +i: U32) -> Sc:
  (b, y) = r
  +v = y
  sc.put(a[(i - 1 : U32)], b, i, v)

def scan(n: Nat, st: Sc) -> Sc:
  match n, st:
    case 0n, r:
      r
    case 1n+k, Sc{a, b, i}:
      +ii = i
      scan(k, sc.get(b[ii], a, ii))

def sc.hash(+n: U32, st: Sc) -> U32:
  match st:
    case Sc{a, b, i}:
      hash(n, a)

def main() -> IO(Unit):
  do IO<Unit>:
    # 16 packed words from 64 cells: all in range; 20 words into 16 (the
    # last four wrap onto the first); 4 words into 4
    IO.print(U32.show(hash(15, pk.dst(pk(nat(16), Pk{ramp(nat(64), 0, [0 : U32*64n]), [0 : U32*16n], 0})))))
    IO.print(U32.show(hash(15, pk.dst(pk(nat(20), Pk{ramp(nat(64), 0, [0 : U32*128n]), [0 : U32*16n], 0})))))
    IO.print(U32.show(hash(3, pk.dst(pk(nat(4), Pk{ramp(nat(16), 0, [0 : U32*16n]), [9 : U32*4n], 0})))))
    # from an offset: 8 words from 8 on, in range, and 12 from 8 (wraps)
    IO.print(U32.show(hash(15, pk.dst(pk(nat(8), Pk{ramp(nat(128), 0, [0 : U32*128n]), [0 : U32*16n], 8})))))
    IO.print(U32.show(hash(15, pk.dst(pk(nat(12), Pk{ramp(nat(128), 0, [0 : U32*128n]), [0 : U32*16n], 8})))))
    # steps of two: 8 steps in 16 cells, and 10 (wraps)
    IO.print(U32.show(hash(15, pk.dst(two(nat(8), Pk{ramp(nat(16), 0, [0 : U32*16n]), [0 : U32*16n], 0})))))
    IO.print(U32.show(hash(15, pk.dst(two(nat(10), Pk{ramp(nat(32), 0, [0 : U32*32n]), [0 : U32*16n], 0})))))
    # forks of one array: cells 1..n are 1..n
    IO.print(U32.show(fk.run(31, Array.fork(U32, [0 : U32*32n]))))
    IO.print(U32.show(fk.run(63, Array.fork(U32, [0 : U32*64n]))))
    # a scan: a[i] = a[i - 1] + b[i], 31 and 63 steps
    IO.print(U32.show(sc.hash(31, scan(nat(31), Sc{[1 : U32*32n], ramp(nat(32), 0, [0 : U32*32n]), 1}))))
    IO.print(U32.show(sc.hash(63, scan(nat(63), Sc{[1 : U32*64n], ramp(nat(64), 0, [0 : U32*64n]), 1}))))

#|3934825376
#|3142239160
#|3727459304
#|211293392
#|2426637240
#|488975336
#|143866152
#|4067041776
#|2488288224
#|2878018736
#|1838033504
