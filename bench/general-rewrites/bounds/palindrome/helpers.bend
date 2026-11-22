# Origin: written for this repository (nicolas-abril/bend-benchmarks).
# A Bend port of MPLLang/parallel-ml-bench @ 3831357ad8, mpl/bench/palindrome/main.sml
# and Pal.sml, with MPLLang/mpllib @ 06b8a55d60, lib/github.com/mpllang/mpllib/
# SeqBasis.sml (tabulate, scan, reduce); deviations in parallel-ml/README.md.
# Licence: MIT (LICENSES/parallel-ml-bench-MIT, LICENSES/mpllib-MIT, for the programs it ports).
#
# palindrome: the longest palindrome in the string `ababab...` of n characters,
# n = 1,000,000 times the number of command-line words, by Pal.longest. The
# string is tabulated in parallel (grain 5000). Pal.check builds polynomial
# hashes modulo p = 1045678717 with base 500000000: the powers of the base are
# one parallel scan (SeqBasis.scan 10000, by multiplication), and the prefix
# hashes of the string and of its reverse two more (by addition). Then, for
# every centre i, a doubling-then-binary search finds the longest odd (and,
# in a second pass, even) palindrome around i whose two hashes agree; each pass
# is a parallel reduce (SeqBasis.reduce 1000) keeping the longest. The answer is
# checked by a parallel reduce (grain 10000) comparing its two halves. Prints
# the answer and the line main.sml prints (correct? yes).
#
# The arrays are shared, read only, between the sides of every fork with
# Base's @unsafe Array.fork; the tabulate and scans write only their own slots.

import Base

# Fork-join kit
# -------------

def depth(+n: U32) -> Nat:
  1n+U32.log2((n - 1 : U32))

# k(a, b) of a pair (a, b)
def pair.go(-A: Type, -B: Type, -R: Type, p: A & B, k: A -> B -> R) -> R:
  (a, b) = p
  k(a, b)

# ForkJoin.parfor g (i, j): halves down to ranges of at most g; body(e, lo, hi)
# runs one range; small says whether (i, j) is one
@unsafe
def pfor.go(~T: Type, ~E: Data, ~split: T -> T & T, ~join: T -> T -> T, ~body: @+e:E -> @+lo:U32 -> @+hi:U32 -> T -> T, small: Bool, +e: E, +g: U32, +i: U32, +j: U32, s: T) -> T:
  match small:
    case True{}:
      body(e, i, j, s)
    case False{}:
      +mid = (i + U32.shr((j - i : U32)) : U32)
      +sl = U32.is_le((mid - i : U32), g)
      +sr = U32.is_le((j - mid : U32), g)
      pair.go(T, T, T, split(s), a => b => (
        l r = pfor.go(T, E, split, join, body, sl, e, g, i, mid, a) pfor.go(T, E, split, join, body, sr, e, g, mid, j, b)
        join(l, r)))

# SeqBasis.reduce's block tree over blocks [i, j), j > i: leaf(e, b) folds block
# b; one says whether j - i is 1
@unsafe
def pred.go(~T: Type, ~E: Data, ~R: Type, ~split: T -> T & T, ~leaf: @+e:E -> @+b:U32 -> T -> R, ~comb: R -> R -> R, one: Bool, +e: E, +i: U32, +j: U32, s: T) -> R:
  match one:
    case True{}:
      leaf(e, i, s)
    case False{}:
      +mid = (i + U32.shr((j - i : U32)) : U32)
      +ol = U32.is_eq((mid - i : U32), 1)
      +or = U32.is_eq((j - mid : U32), 1)
      pair.go(T, T, R, split(s), a => b => (
        l r = pred.go(T, E, R, split, leaf, comb, ol, e, i, mid, a) pred.go(T, E, R, split, leaf, comb, or, e, mid, j, b)
        comb(l, r)))

@unsafe
def pfor(~T: Type, ~E: Data, ~split: T -> T & T, ~join: T -> T -> T, ~body: @+e:E -> @+lo:U32 -> @+hi:U32 -> T -> T, +e: E, +g: U32, +i: U32, +j: U32, s: T) -> T:
  pfor.go(~T, ~E, ~split, ~join, ~body, U32.is_le((j - i : U32), g), e, g, i, j, s)

@unsafe
def pred(~T: Type, ~E: Data, ~R: Type, ~split: T -> T & T, ~leaf: @+e:E -> @+b:U32 -> T -> R, ~comb: R -> R -> R, +e: E, +i: U32, +j: U32, s: T) -> R:
  pred.go(~T, ~E, ~R, ~split, ~leaf, ~comb, U32.is_eq((j - i : U32), 1), e, i, j, s)

# A state t with one more array a
type With<-A: Type> is Type:
  With{t: A, a: Array<U32>}

def with.mk(-A: Type, ft: A & A, fa: Array<U32> & Array<U32>) -> With<A> & With<A>:
  (t0, t1) = ft
  (a0, a1) = fa
  (With{t0, a0}, With{t1, a1})

def with.split(~A: Type, ~split: A -> A & A, w: With<A>) -> With<A> & With<A>:
  With{t, a} = w
  with.mk(A, split(t), Array.fork(U32, a))

def with.join(~A: Type, ~join: A -> A -> A, l: With<A>, r: With<A>) -> With<A>:
  With{t0, a0} = l
  With{t1, a1} = r
  With{join(t0, t1), Array.join(U32, a0, a1)}

# k(t, a) of With{t, a}
def with.go(-A: Type, -R: Type, w: With<A>, k: A -> Array<U32> -> R) -> R:
  With{t, a} = w
  k(t, a)

# The scan's environment: the caller's, the grain k, the length n, the identity z
type SE<-E: Data> is Data:
  SE{e: E, k: U32, n: U32, z: U32}

# foldl op acc over f(i), i in [i, i + k), with r = (t, v) holding the value
# not yet added
@unsafe
def scan.fold(~T: Type, ~E: Data, ~op: @+a:U32 -> @+b:U32 -> U32, ~f: @+e:E -> @+i:U32 -> T -> T & U32, r: T & U32, k: Nat, +e: E, +i: U32, +acc: U32) -> T & U32:
  (t, +v) = r
  match k:
    case 0n:
      (t, op(acc, v))
    case 1n+p:
      scan.fold(T, E, op, f, f(e, i, t), p, e, (i + 1 : U32), op(acc, v))

# over [i, i + k): a[j] = acc, then acc = op(acc, f(i)), j counting from j;
# r = (t, v) holds the value not yet added
@unsafe
def scan.bump(~T: Type, ~E: Data, ~op: @+a:U32 -> @+b:U32 -> U32, ~f: @+e:E -> @+i:U32 -> T -> T & U32, r: T & U32, k: Nat, +e: E, +i: U32, +j: U32, +acc: U32, a: Array<U32>) -> With<T> & U32:
  (t, +v) = r
  match k:
    case 0n:
      (With{t, a}, op(acc, v))
    case 1n+p:
      +acc2 = op(acc, v)
      scan.bump(T, E, op, f, f(e, i, t), p, e, (i + 1 : U32), (j + 1 : U32), acc2, a[j] <- acc2)

def scan.lo(+b: U32, +k: U32) -> U32:
  (b * k : U32)

def scan.hi(+b: U32, +k: U32, +n: U32) -> U32:
  U32.min(((b + 1) * k : U32), n)

# block b's total into a[b] (SeqBasis.scan's tabulate 1 of the block sums)
def scan.sum(~T: Type, ~E: Data, ~op: @+a:U32 -> @+b:U32 -> U32, ~f: @+e:E -> @+i:U32 -> T -> T & U32, +se: SE<E>, +b: U32, +hi: U32, w: With<T>) -> With<T>:
  match se:
    case SE{+e, +k, +n, +z}:
      With{t, a} = w
      pair.go(T, U32, With<T>, scan.fold(~T, ~E, ~op, ~f, (t, z), U32.to_nat((scan.hi(b, k, n) - scan.lo(b, k) : U32)), e, scan.lo(b, k), z), t2 => +s => With{t2, a[b] <- s})

# The state with the block prefixes p (read only) and the result r
type With2<-A: Type> is Type:
  With2{t: A, p: Array<U32>, r: Array<U32>}

def with2.mk(-A: Type, ft: A & A, fp: Array<U32> & Array<U32>, fr: Array<U32> & Array<U32>) -> With2<A> & With2<A>:
  (t0, t1) = ft
  (p0, p1) = fp
  (r0, r1) = fr
  (With2{t0, p0, r0}, With2{t1, p1, r1})

def with2.split(~A: Type, ~split: A -> A & A, w: With2<A>) -> With2<A> & With2<A>:
  With2{t, p, r} = w
  with2.mk(A, split(t), Array.fork(U32, p), Array.fork(U32, r))

def with2.join(~A: Type, ~join: A -> A -> A, l: With2<A>, r: With2<A>) -> With2<A>:
  With2{t0, p0, r0} = l
  With2{t1, p1, r1} = r
  With2{join(t0, t1), Array.join(U32, p0, p1), Array.join(U32, r0, r1)}

# block b writes its prefixes from p[b] (SeqBasis.scan's parfor 1)
def scan.put(~T: Type, ~E: Data, ~op: @+a:U32 -> @+b:U32 -> U32, ~f: @+e:E -> @+i:U32 -> T -> T & U32, +se: SE<E>, +b: U32, +hi: U32, w: With2<T>) -> With2<T>:
  match se:
    case SE{+e, +k, +n, +z}:
      With2{t, p, r} = w
      pair.go(Array<U32>, U32, With2<T>, p[b], p2 => +c => pair.go(With<T>, U32, With2<T>, scan.bump(~T, ~E, ~op, ~f, (t, z), U32.to_nat((scan.hi(b, k, n) - scan.lo(b, k) : U32)), e, scan.lo(b, k), scan.lo(b, k), c, r), w2 => +x => with.go(T, With2<T>, w2, t2 => r2 => With2{t2, p2, r2})))

# the sequential scan of the block sums: (sums, prefixes of m + 1)
def scan.sums(~op: @+a:U32 -> @+b:U32 -> U32, +m: U32, +z: U32, s: Array<U32>) -> Array<U32> & Array<U32>:
  pair.go(With<Array<U32>>, U32, Array<U32> & Array<U32>, scan.bump(~Array<U32>, ~U32, ~op, ~(+e => +i => t => t[i]), (s, z), U32.to_nat(m), 0, 0, 0, z, Array.new(U32, depth((m + 1 : U32)), 0)), w => +tot => with.go(Array<U32>, Array<U32> & Array<U32>, w, s2 => ps => (s2, ps[m] <- tot)))

def with2.go(-A: Type, -R: Type, w: With2<A>, k: A -> Array<U32> -> Array<U32> -> R) -> R:
  With2{t, p, r} = w
  k(t, p, r)

@unsafe
def scan.at(~T: Type, ~E: Data, ~split: T -> T & T, ~join: T -> T -> T, ~op: @+a:U32 -> @+b:U32 -> U32, ~f: @+e:E -> @+i:U32 -> T -> T & U32, small: Bool, +e: E, +k: U32, +z: U32, +n: U32, t: T) -> T & Array<U32>:
  match small:
    case True{}:
      pair.go(With<T>, U32, T & Array<U32>, scan.bump(~T, ~E, ~op, ~f, (t, z), U32.to_nat(n), e, 0, 0, z, Array.new(U32, depth((n + 1 : U32)), 0)), w => +tot => with.go(T, T & Array<U32>, w, t2 => r => (t2, r[n] <- tot)))
    case False{}:
      +m = (1 + (n - 1) / k : U32)
      +se = {SE{e, k, n, z} : SE<E>}
      with.go(T, T & Array<U32>, pfor(~With<T>, ~SE<E>, ~(w => with.split(~T, ~split, w)), ~(l => r => with.join(~T, ~join, l, r)), ~(+se => +b => +hi => w => scan.sum(~T, ~E, ~op, ~f, se, b, hi, w)), se, 1, 0, m, With{t, Array.new(U32, depth(m), 0)}), t2 => sums =>
        pair.go(Array<U32>, Array<U32>, T & Array<U32>, scan.sums(~op, m, z, sums), s2 => ps =>
          pair.go(Array<U32>, U32, T & Array<U32>, ps[m], ps2 => +tot =>
            with2.go(T, T & Array<U32>, pfor(~With2<T>, ~SE<E>, ~(w => with2.split(~T, ~split, w)), ~(l => r => with2.join(~T, ~join, l, r)), ~(+se => +b => +hi => w => scan.put(~T, ~E, ~op, ~f, se, b, hi, w)), se, 1, 0, m, With2{t2, ps2, Array.new(U32, depth((n + 1 : U32)), 0)}), t3 => p3 => r => (t3, r[n] <- tot)))))

# SeqBasis.scan k op z (0, n) f, f(e, i, t) reading element i from the state t:
# (t, r) with r[i] the op-prefix before element i and r[n] the total. Above k
# elements: blocks of k summed in parallel (tabulate 1), the block sums scanned
# sequentially (SeqBasis recurses; here they are at most k), and the blocks
# written in parallel (parfor 1).
@unsafe
def scan(~T: Type, ~E: Data, ~split: T -> T & T, ~join: T -> T -> T, ~op: @+a:U32 -> @+b:U32 -> U32, ~f: @+e:E -> @+i:U32 -> T -> T & U32, +e: E, +k: U32, +z: U32, +n: U32, t: T) -> T & Array<U32>:
  scan.at(~T, ~E, ~split, ~join, ~op, ~f, U32.is_le(n, k), e, k, z, n, t)

# Shared arrays
# -------------

def a.split(a: Array<U32>) -> Array<U32> & Array<U32>:
  Array.fork(U32, a)

def a.join(a: Array<U32>, b: Array<U32>) -> Array<U32>:
  Array.join(U32, a, b)

type Two is Type:
  Two{s: Array<U32>, b: Array<U32>}

def two.split(t: Two) -> Two & Two:
  Two{s, b} = t
  pair.go(Array<U32>, Array<U32>, Two & Two, Array.fork(U32, s), s0 => s1 => pair.go(Array<U32>, Array<U32>, Two & Two, Array.fork(U32, b), b0 => b1 => (Two{s0, b0}, Two{s1, b1})))

def two.join(l: Two, r: Two) -> Two:
  Two{s0, b0} = l
  Two{s1, b1} = r
  Two{Array.join(U32, s0, s1), Array.join(U32, b0, b1)}

# the powers bp and the forward and backward prefix hashes
type H is Type:
  H{bp: Array<U32>, f: Array<U32>, b: Array<U32>}

def h.split(t: H) -> H & H:
  H{bp, f, b} = t
  pair.go(Array<U32>, Array<U32>, H & H, Array.fork(U32, bp), p0 => p1 => pair.go(Array<U32>, Array<U32>, H & H, Array.fork(U32, f), f0 => f1 => pair.go(Array<U32>, Array<U32>, H & H, Array.fork(U32, b), b0 => b1 => (H{p0, f0, b0}, H{p1, f1, b1}))))

# Arithmetic modulo p (Int64 in the reference)
# --------------------------------------------

# p = 1045678717 < 2^30
def modp(+v: Nat) -> Nat:
  Nat.mod(v, 1045678717n)

# a * b mod p, through 48-bit Nat: b in 16-bit halves
def mul(+a: U32, +b: U32) -> U32:
  +an = U32.to_nat(a)
  U32.from_nat(modp(Nat.add(Nat.mul(modp(Nat.mul(an, U32.to_nat(U32.shrn(b, 16n)))), 65536n), Nat.mul(an, U32.to_nat(U32.and(b, 65535))))))

def add(+a: U32, +b: U32) -> U32:
  U32.from_nat(modp(Nat.add(U32.to_nat(a), U32.to_nat(b))))

# The input: Seq.tabulate gen n, 'a' at even i
# --------------------------------------------

def gen.loop(+k: Nat, +i: U32, a: Array<U32>) -> Array<U32>:
  match k:
    case 0n:
      a
    case 1n+p:
      gen.loop(p, (i + 1 : U32), a[i] <- (97 + U32.and(i, 1) : U32))

def gen.body(+e: U32, +lo: U32, +hi: U32, a: Array<U32>) -> Array<U32>:
  gen.loop(U32.to_nat((hi - lo : U32)), lo, a)

# Pal.check: the hashes
# ---------------------

# charMul (str[i], bp[i]), and for the reverse string str[n - i - 1]
def fwd.at(+i: U32, s: Array<U32>, r: Array<U32> & U32) -> Two & U32:
  (b, +x) = r
  pair.go(Array<U32>, U32, Two & U32, s[i], s2 => +c => (Two{s2, b}, mul(c, x)))

def fwd(+n: U32, +i: U32, t: Two) -> Two & U32:
  Two{s, b} = t
  fwd.at(i, s, b[i])

def bwd.at(+n: U32, +i: U32, s: Array<U32>, r: Array<U32> & U32) -> Two & U32:
  (b, +x) = r
  pair.go(Array<U32>, U32, Two & U32, s[(n - i - 1 : U32)], s2 => +c => (Two{s2, b}, mul(c, x)))

def bwd(+n: U32, +i: U32, t: Two) -> Two & U32:
  Two{s, b} = t
  bwd.at(n, i, s, b[i])

type HR is Type:
  HR{bp: Array<U32>, x: Array<U32>, h: U32}

# (a - b) mod p, for a, b below p
def subp(+a: U32, +b: U32) -> U32:
  U32.from_nat(modp(Nat.sub(Nat.add(U32.to_nat(a), 1045678717n), U32.to_nat(b))))

def hash.off(+d: U32, x: Array<U32>, r: Array<U32> & U32) -> HR:
  (bp, +o) = r
  HR{bp, x, mul(d, o)}

def hash.first(+n: U32, +i: U32, +last: U32, bp: Array<U32>, r: Array<U32> & U32) -> HR:
  (x, +first) = r
  hash.off(subp(last, first), x, bp[(n - i - 1 : U32)])

def hash.last(+n: U32, +i: U32, bp: Array<U32>, r: Array<U32> & U32) -> HR:
  (x, +last) = r
  hash.first(n, i, last, bp, x[i])

# H(i, j) = (P[j] - P[i]) * bp[n - i - 1] mod p, with P the prefixes in x
def hash(+n: U32, +i: U32, +j: U32, bp: Array<U32>, x: Array<U32>) -> HR:
  hash.last(n, i, bp, x[j])

def perhaps.back(+hf: U32, f: Array<U32>, r: HR) -> H & Bool:
  HR{bp, b, +hb} = r
  (H{bp, f, b}, U32.is_eq(hf, hb))

def perhaps.fwd(+n: U32, +i: U32, +j: U32, b: Array<U32>, r: HR) -> H & Bool:
  HR{bp, f, +hf} = r
  perhaps.back(hf, f, hash(n, (n - j : U32), (n - i : U32), bp, b))

# perhaps (i, j): forward H(i, j) = backward H(n - j, n - i)
def perhaps(+n: U32, +i: U32, +j: U32, t: H) -> H & Bool:
  H{bp, f, b} = t
  perhaps.fwd(n, i, j, b, hash(n, i, j, bp, f))

# Pal.longest
# -----------

def check.at(ok: Bool, +n: U32, +lo: U32, +hi: U32, t: H) -> H & Bool:
  match ok:
    case True{}:
      perhaps(n, lo, hi, t)
    case False{}:
      (t, False{})

# checkOdd i j (odd) or checkEven i j: is str[i - j, i + j] (or [i - j + 1, i + j]) a palindrome?
def check(odd: Bool, +n: U32, +i: U32, +j: U32, t: H) -> H & Bool:
  match odd:
    case True{}:
      check.at(U32.is_le(j, i) && U32.is_lt((i + j : U32), n), n, (i - j : U32), (i + j + 1 : U32), t)
    case False{}:
      check.at(U32.is_le(j, (i + 1 : U32)) && U32.is_lt((i + j : U32), n), n, (i - j + 1 : U32), (i + j + 1 : U32), t)

@unsafe
def bs.at(yes: Bool, +odd: Bool, +n: U32, +c: U32, +lo: U32, +mid: U32, +hi: U32, t: H) -> H & U32:
  match yes:
    case True{}:
      bs(odd, n, c, mid, hi, t)
    case False{}:
      bs(odd, n, c, lo, mid, t)

@unsafe
def bs.next(+odd: Bool, +n: U32, +c: U32, +lo: U32, +mid: U32, +hi: U32, r: H & Bool) -> H & U32:
  (t, yes) = r
  bs.at(yes, odd, n, c, lo, mid, hi, t)

# bs (i, j)
@unsafe
def bs(+odd: Bool, +n: U32, +c: U32, +lo: U32, +hi: U32, t: H) -> H & U32:
  bs.go(U32.is_eq((hi - lo : U32), 1), odd, n, c, lo, hi, t)

@unsafe
def bs.go(one: Bool, +odd: Bool, +n: U32, +c: U32, +lo: U32, +hi: U32, t: H) -> H & U32:
  match one:
    case True{}:
      (t, lo)
    case False{}:
      +mid = ((lo + hi) / 2 : U32)
      bs.next(odd, n, c, lo, mid, hi, check(odd, n, c, mid, t))

@unsafe
def double.at(yes: Bool, +odd: Bool, +n: U32, +c: U32, +i: U32, t: H) -> H & U32:
  match yes:
    case True{}:
      double(odd, n, c, (2 * i : U32), t)
    case False{}:
      bs(odd, n, c, i, (2 * i : U32), t)

@unsafe
def double.next(+odd: Bool, +n: U32, +c: U32, +i: U32, r: H & Bool) -> H & U32:
  (t, yes) = r
  double.at(yes, odd, n, c, i, t)

# double i
@unsafe
def double(+odd: Bool, +n: U32, +c: U32, +i: U32, t: H) -> H & U32:
  double.next(odd, n, c, i, check(odd, n, c, (2 * i : U32), t))

def search.at(yes: Bool, +odd: Bool, +n: U32, +c: U32, t: H) -> H & U32:
  match yes:
    case True{}:
      double(odd, n, c, 1, t)
    case False{}:
      (t, 0)

def search.next(+odd: Bool, +n: U32, +c: U32, r: H & Bool) -> H & U32:
  (t, yes) = r
  search.at(yes, odd, n, c, t)

# binarySearch (check c)
def search(+odd: Bool, +n: U32, +c: U32, t: H) -> H & U32:
  search.next(odd, n, c, check(odd, n, c, 1, t))

type IL is Data:
  IL{i: U32, l: U32}

def maxval(a: IL, b: IL) -> IL:
  match a b:
    case IL{+ia, +la} IL{+ib, +lb}:
      Bool.pick(IL, U32.is_gt(la, lb), IL{ia, la}, IL{ib, lb})

type Env is Data:
  Env{odd: Bool, n: U32}

@unsafe
def best.put(k: Nat, +odd: Bool, +n: U32, +i: U32, acc: IL, r: H & U32) -> IL:
  (t, +l) = r
  best.fold(k, odd, n, (i + 1 : U32), maxval(acc, IL{i, l}), t)

# foldl maxval acc over (i, binarySearch (check i)), i in [i, i + k)
@unsafe
def best.fold(k: Nat, +odd: Bool, +n: U32, +i: U32, acc: IL, t: H) -> IL:
  match k:
    case 0n:
      acc
    case 1n+p:
      best.put(p, odd, n, i, acc, search(odd, n, i, t))

def best.leaf(+e: Env, +b: U32, t: H) -> IL:
  match e:
    case Env{+odd, +n}:
      +lo = (b * 1000 : U32)
      best.fold(U32.to_nat((U32.min((lo + 1000 : U32), n) - lo : U32)), odd, n, lo, IL{0, 0}, t)

# getMax: SeqBasis.reduce 1000 maxval (0, 0) (0, n)
def best(+odd: Bool, +n: U32, t: H) -> IL:
  pred(~H, ~Env, ~IL, ~h.split, ~best.leaf, ~maxval, Env{odd, n}, 0, (1 + (n - 1) / 1000 : U32), t)

# verify: SeqBasis.reduce 10000 andalso true (i, i + l div 2), comparing str[k]
# and str[i + (j - k - 1)]
type VE is Data:
  VE{i: U32, j: U32, hi: U32}

@unsafe
def ver.fold(k: Nat, +i: U32, +j: U32, +x: U32, acc: Bool, s: Array<U32>) -> Bool:
  match k:
    case 0n:
      acc
    case 1n+p:
      ver.a(p, i, j, x, acc, s[x])

@unsafe
def ver.b(k: Nat, +i: U32, +j: U32, +x: U32, acc: Bool, +a: U32, r: Array<U32> & U32) -> Bool:
  (s, +b) = r
  ver.fold(k, i, j, (x + 1 : U32), acc && U32.is_eq(a, b), s)

@unsafe
def ver.a(k: Nat, +i: U32, +j: U32, +x: U32, acc: Bool, r: Array<U32> & U32) -> Bool:
  (s, +a) = r
  ver.b(k, i, j, x, acc, a, s[(i + j - x - 1 : U32)])

def ver.leaf(+e: VE, +b: U32, s: Array<U32>) -> Bool:
  match e:
    case VE{+i, +j, +hi}:
      +lo = (i + b * 10000 : U32)
      ver.fold(U32.to_nat((U32.min((lo + 10000 : U32), hi) - lo : U32)), i, j, lo, True{}, s)

def verify(+i: U32, +j: U32, s: Array<U32>) -> Bool:
  +hi = (i + (j - i) / 2 : U32)
  pred(~Array<U32>, ~VE, ~Bool, ~a.split, ~ver.leaf, ~(a => b => a && b), VE{i, j, hi}, 0, U32.max((1 + (hi - i - 1) / 10000 : U32), 1), s)

# Driver
# ------

def failed(ok: Bool) -> String:
  match ok:
    case True{}:
      ""
    case False{}:
      "Failed!\n"

def yes.show(b: Bool) -> String:
  match b:
    case True{}:
      "yes"
    case False{}:
      "no"

def answer(+n: U32, s: Array<U32>, +i: U32, +l: U32) -> String:
  +even = U32.is_zero(U32.and(n, 1))
  +correct = Bool.pick(Bool, even, U32.is_eq(i, 1) && U32.is_eq(l, (n - 1 : U32)), U32.is_eq(i, 0) && U32.is_eq(l, n))
  failed(verify(i, (i + l : U32), s)) ++ "result (" ++ U32.show(i) ++ ", " ++ U32.show(l) ++ ")\ncorrect? " ++ yes.show(correct)

def pick.at(even: Bool, +n: U32, s: Array<U32>, +io: U32, +lo: U32, +ie: U32, +le: U32) -> String:
  match even:
    case True{}:
      answer(n, s, (ie - le + 1 : U32), (2 * le : U32))
    case False{}:
      answer(n, s, (io - lo : U32), (2 * lo + 1 : U32))

def pick(+n: U32, s: Array<U32>, o: IL, e: IL) -> String:
  match o e:
    case IL{+io, +lo} IL{+ie, +le}:
      pick.at(U32.is_gt(le, lo), n, s, io, lo, ie, le)

def longest.go(+n: U32, s: Array<U32>, bp: Array<U32>, f: Array<U32>, b: Array<U32>) -> String:
  pair.go(H, H, String, h.split(H{bp, f, b}), t0 => t1 => pick(n, s, best(True{}, n, t0), best(False{}, n, t1)))

def longest.bwd(+n: U32, f: Array<U32>, r: Two & Array<U32>) -> String:
  (t, b) = r
  Two{s, bp} = t
  longest.go(n, s, bp, f, b)

def longest.fwd(+n: U32, r: Two & Array<U32>) -> String:
  (t, f) = r
  longest.bwd(n, f, scan(~Two, ~U32, ~two.split, ~two.join, ~add, ~bwd, n, 10000, 0, n, t))

def longest.bp(+n: U32, r: Array<U32> & Array<U32>) -> String:
  (s, bp) = r
  longest.fwd(n, scan(~Two, ~U32, ~two.split, ~two.join, ~add, ~fwd, n, 10000, 0, n, Two{s, bp}))

# Pal.longest str
def longest(+n: U32, s: Array<U32>) -> String:
  longest.bp(n, scan(~Array<U32>, ~U32, ~a.split, ~a.join, ~mul, ~(+e => +i => t => (t, 500000000)), 0, 10000, 1, n, s))

def run(+n: U32) -> String:
  longest(n, pfor(~Array<U32>, ~U32, ~a.split, ~a.join, ~gen.body, 0, 5000, 0, n, Array.new(U32, depth(n), 0)))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    IO.print(run(U32.from_nat(Nat.mul(1000000n, List.length(&1, String, args)))))
