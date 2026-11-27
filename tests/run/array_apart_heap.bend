# a loop over two arrays apart whose turns also allocate and free on the
# heap: each turn builds a list from a cell of one array and writes its
# sum to the other (the arrays' bases are told apart, the heap is not)
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

def hash(+n: U32, a: Array<U32>) -> U32:
  hash.go(nat(n), 0, 0, a[0])

def ramp(n: Nat, +i: U32, a: Array<U32>) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      ramp(p, (i + 1 : U32), a[i] <- ((i * 37 + 11) .&. 255 : U32))

# the list x, x + 1, .., x + k - 1
def build(k: Nat, +x: U32, acc: List<U32>) -> List<U32>:
  match k:
    case 0n:
      acc
    case 1n+p:
      build(p, (x + 1 : U32), x <> acc)

def total(xs: List<U32>, acc: U32) -> U32:
  match xs:
    case []:
      acc
    case x <> rest:
      total(rest, (acc * 3 + x : U32))

type Mv is Type:
  Mv{a: Array<U32>, b: Array<U32>, i: U32}

def mv.put(r: Array<U32> & U32, b: Array<U32>, +i: U32) -> Mv:
  (a, x) = r
  +v = x
  Mv{a, b[i] <- total(build(U32.to_nat(((v .&. 7) + 1 : U32)), v, []), i), (i + 1 : U32)}

def mv(n: Nat, st: Mv) -> Mv:
  match n, st:
    case 0n, r:
      r
    case 1n+k, Mv{a, b, i}:
      +ii = i
      mv(k, mv.put(a[ii], b, ii))

def mv.hash(+n: U32, st: Mv) -> U32:
  match st:
    case Mv{a, b, i}:
      hash(n, b)

def rounds(m: Nat, +n: U32, acc: U32) -> U32:
  match m:
    case 0n:
      acc
    case 1n+k:
      +h = mv.hash((n - 1 : U32), mv(nat(n), Mv{ramp(nat(n), 0, [0 : U32*256n]), [0 : U32*256n], 0}))
      rounds(k, n, (acc * 7 + h : U32))

# a vector of records that hold lists, grown by moving every cell from the
# old array to a new one of twice the size (each swapped out for a blank)
type Ids is Data:
  INil{}
  ICons{head: U32, tail: Ids}

def ibuild(k: Nat, +x: U32, acc: Ids) -> Ids:
  match k:
    case 0n:
      acc
    case 1n+p:
      ibuild(p, (x + 1 : U32), ICons{x, acc})

def itotal(xs: Ids, acc: U32) -> U32:
  match xs:
    case INil{}:
      acc
    case ICons{x, rest}:
      itotal(rest, (acc * 3 + x : U32))

type R is Data:
  R{k: U32, xs: Ids, flag: Bool, ys: Ids, w: U32}

def blank() -> R:
  R{0, INil{}, False{}, INil{}, 0}

def grow.one(+i: U32, new: Array<R>, r: Array<R> & R) -> Array<R> & Array<R>:
  (old, x) = r
  (old, Array.set(R, new, i, x))

def grow(n: Nat, +i: U32, r: Array<R> & Array<R>) -> Array<R>:
  match n:
    case 0n:
      (old, new) = r
      new
    case 1n+p:
      (old, new) = r
      grow(p, (i + 1 : U32), grow.one(i, new, Array.swap(R, old, i, blank())))

def put.at(+i: U32, r: Array<R> & R) -> Array<R>:
  (a, x) = r
  Array.set(R, a, i, R{i, ibuild(U32.to_nat(((i .&. 3) + 1 : U32)), i, INil{}), True{}, ICons{i, ICons{(i * 3 : U32), INil{}}}, (i * 7 : U32)})

def score(r: R, acc: U32) -> U32:
  match r:
    case R{k, xs, flag, ys, w}:
      itotal(ys, itotal(xs, (acc * 5 + k + w : U32)))

def vsum.at(n: Nat, +i: U32, acc: U32, r: Array<R> & R) -> U32:
  match n:
    case 0n:
      (a, x) = r
      score(x, acc)
    case 1n+p:
      (a, x) = r
      +q = (i + 1 : U32)
      vsum.at(p, q, score(x, acc), Array.swap(R, a, q, blank()))

# a vector of count records in cap = 2^d cells: full, it doubles
type V is Type:
  V{a: Array<R>, d: Nat, cap: U32, count: U32}

def v.push(a: Array<R>, +d: Nat, +k: U32, +c: U32, full: Bool) -> V:
  match full:
    case True{}:
      V{put.at(c, Array.swap(R, grow(U32.to_nat(c), 0, (a, Array.new(R, 1n+d, blank()))), c, blank())), 1n+d, (k * 2 : U32), (c + 1 : U32)}
    case False{}:
      V{put.at(c, Array.swap(R, a, c, blank())), d, k, (c + 1 : U32)}

def v.fill(n: Nat, v: V) -> V:
  match n, v:
    case 0n, r:
      r
    case 1n+p, V{a, d, cap, count}:
      +k = cap
      +c = count
      v.fill(p, v.push(a, d, k, c, U32.is_eq(c, k)))

def v.sum(v: V) -> U32:
  match v:
    case V{a, d, cap, count}:
      +c = count
      vsum.at(U32.to_nat((c - 1 : U32)), 0, 0, Array.swap(R, a, 0, blank()))

def vrounds(m: Nat, acc: U32) -> U32:
  match m:
    case 0n:
      acc
    case 1n+k:
      vrounds(k, (acc * 7 + v.sum(v.fill(nat(1000), V{Array.new(R, 1n, blank()), 1n, 2, 0})) : U32))

# the same with cells of two kinds: an empty slot, or two lists
type B is Data:
  NoB{}
  B{ins: Ids, outs: Ids}

def bgrow.one(+i: U32, new: Array<B>, r: Array<B> & B) -> Array<B> & Array<B>:
  (old, x) = r
  (old, Array.set(B, new, i, x))

def bgrow(n: Nat, +i: U32, r: Array<B> & Array<B>) -> Array<B>:
  match n:
    case 0n:
      (old, new) = r
      new
    case 1n+p:
      (old, new) = r
      bgrow(p, (i + 1 : U32), bgrow.one(i, new, Array.swap(B, old, i, NoB{})))

def bput.at(+i: U32, r: Array<B> & B) -> Array<B>:
  (a, x) = r
  Array.set(B, a, i, B{ibuild(U32.to_nat(((i .&. 3) + 1 : U32)), i, INil{}), ICons{(i * 3 : U32), INil{}}})

def bscore(r: B, acc: U32) -> U32:
  match r:
    case NoB{}:
      (acc * 5 + 1 : U32)
    case B{ins, outs}:
      itotal(outs, itotal(ins, (acc * 5 : U32)))

def bsum.at(n: Nat, +i: U32, acc: U32, r: Array<B> & B) -> U32:
  match n:
    case 0n:
      (a, x) = r
      bscore(x, acc)
    case 1n+p:
      (a, x) = r
      +q = (i + 1 : U32)
      bsum.at(p, q, bscore(x, acc), Array.swap(B, a, q, NoB{}))

type W is Type:
  W{a: Array<B>, d: Nat, cap: U32, count: U32}

def w.push(a: Array<B>, +d: Nat, +k: U32, +c: U32, full: Bool) -> W:
  match full:
    case True{}:
      W{bput.at(c, Array.swap(B, bgrow(U32.to_nat(c), 0, (a, Array.new(B, 1n+d, NoB{}))), c, NoB{})), 1n+d, (k * 2 : U32), (c + 1 : U32)}
    case False{}:
      W{bput.at(c, Array.swap(B, a, c, NoB{})), d, k, (c + 1 : U32)}

def w.fill(n: Nat, v: W) -> W:
  match n, v:
    case 0n, r:
      r
    case 1n+p, W{a, d, cap, count}:
      +k = cap
      +c = count
      w.fill(p, w.push(a, d, k, c, U32.is_eq(c, k)))

def w.sum(v: W) -> U32:
  match v:
    case W{a, d, cap, count}:
      +c = count
      bsum.at(U32.to_nat((c - 1 : U32)), 0, 0, Array.swap(B, a, 0, NoB{}))

def wrounds(m: Nat, acc: U32) -> U32:
  match m:
    case 0n:
      acc
    case 1n+k:
      wrounds(k, (acc * 7 + w.sum(w.fill(nat(5000), W{Array.new(B, 1n, NoB{}), 1n, 2, 0})) : U32))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(U32.show(mv.hash(255, mv(nat(256), Mv{ramp(nat(256), 0, [0 : U32*256n]), [0 : U32*256n], 0}))))
    IO.print(U32.show(rounds(nat(200), 256, 0)))
    IO.print(U32.show(vrounds(nat(300), 0)))
    IO.print(U32.show(wrounds(nat(200), 0)))

#|3273309952
#|1773395968
#|1108860736
#|428048384
