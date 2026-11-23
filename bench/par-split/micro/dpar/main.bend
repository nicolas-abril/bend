# Origin: written for this repository (nicolas-abril/bend-benchmarks).
# A Bend port of MPLLang/parallel-ml-bench @ 3831357ad8, mpl/bench/delaunay/
# main.sml, DelaunayTriangulation.sml and Split.sml, with MPLLang/mpllib @
# 06b8a55d60, lib/github.com/mpllang/mpllib/ Topology2D.sml, Geometry2D.sml,
# Geometry3D.sml, NearestNeighbors.sml and CountingSort.sml; deviations in
# parallel-ml/README.md.
# Licence: MIT (LICENSES/parallel-ml-bench-MIT, LICENSES/mpllib-MIT, for the programs it ports).
#
# delaunay: the Delaunay triangulation of n points, n = 1,000,000 times the
# number of command-line words, by MaPLe's parallel incremental insertion. Point
# i is (rand(2i), rand(2i + 1)), rand(s) = (hash(15210 + s) mod 10^6) / 10^6.
#
# The mesh (Topology2D) starts as 10 boundary points on a circle around the
# points' box (two parallel reduces); its arrays are tabulated in parallel.
# Point 0 is inserted from the boundary, then points are inserted one at a time
# up to 10000 (smallLoop), each walking (findPoint) from the triangle of its
# nearest inserted point, found in a quadtree (NearestNeighbors, rebuilt at 10,
# 100, 1000, ... points while at most n / 10 are in), and ripping and tenting
# its cavity (a split, then flips). Then rounds of batches (3.5% of the points
# in, at most n / 10): a parallel loop (grain 20) finds each point's triangle
# and reserves the vertices around its cavity (an atomic max of its id), a
# parallel loop (grain 20) checks which points hold all their reservations, a
# parallel loop (grain 20) rips and tents the winners' cavities (disjoint, so
# in place), and Split.split splits the batch into winners and losers, the
# losers going first in the next batch. Prints the number of rounds, main.sml's
# hint about -output, and a hash of the mesh.
#
# Every array is shared between the sides of every fork with Base's @unsafe
# Array.fork and Array.join: the mesh is read by every lane, and each lane
# writes only the triangles of its own cavities (and its reservations, by
# atomics). The quadtree is Data, shared by every lane.

import Base


# mpllib's Util.hash32 (Util.hash on 32-bit ints).
def hash(+a0: U32) -> U32:
  +a1 = (a0 + 2127912214 + U32.shln(a0, 12n) : U32)
  +a2 = ((a1 .^. 3345072700) .^. U32.shrn(a1, 19n) : U32)
  +a3 = (a2 + 374761393 + U32.shln(a2, 5n) : U32)
  +a4 = ((a3 + 3550635116) .^. U32.shln(a3, 9n) : U32)
  +a5 = (a4 + 4251993797 + U32.shln(a4, 3n) : U32)
  ((a5 .^. 3042594569) .^. U32.shrn(a5, 16n) : U32)

def depth(+n: U32) -> Nat:
  1n+U32.log2((U32.max(n, 2) - 1 : U32))

def join2(l: Array<U32> & Array<U32>, r: Array<U32> & Array<U32>) -> Array<U32> & Array<U32>:
  (la, lb) = l
  (ra, rb) = r
  (Array.join(U32, la, ra), Array.join(U32, lb, rb))

def fpick(c: Bool, +a: F32, +b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def wpick(c: Bool, +a: U32, +b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

# Real.min, Real.max
def fmin(+a: F32, +b: F32) -> F32:
  fpick((a < b : F32), a, b)

def fmax(+a: F32, +b: F32) -> F32:
  fpick((a > b : F32), a, b)

# Points
# ------

type Pts is Type:
  Pts{xs: Array<F32>, ys: Array<F32>}

def pts.split(fx: Array<F32> & Array<F32>, fy: Array<F32> & Array<F32>) -> Pts & Pts:
  (x0, x1) = fx
  (y0, y1) = fy
  (Pts{x0, y0}, Pts{x1, y1})

def pts.fork(p: Pts) -> Pts & Pts:
  Pts{xs, ys} = p
  pts.split(Array.fork(F32, xs), Array.fork(F32, ys))

def pts.join(a: Pts, b: Pts) -> Pts:
  Pts{ax, ay} = a
  Pts{bx, by} = b
  Pts{Array.join(F32, ax, bx), Array.join(F32, ay, by)}

type At is Type:
  At{p: Pts, x: F32, y: F32}

def at.y(xs: Array<F32>, +x: F32, r: Array<F32> & F32) -> At:
  (ys, +y) = r
  At{Pts{xs, ys}, x, y}

def at.x(+i: U32, ys: Array<F32>, r: Array<F32> & F32) -> At:
  (xs, +x) = r
  at.y(xs, x, Array.get(F32, ys, i))

# point i, handed back with the points
def at(+i: U32, p: Pts) -> At:
  Pts{xs, ys} = p
  at.x(i, ys, Array.get(F32, xs, i))

# main.sml's genReal
def rand(+s: U32) -> F32:
  (U32.to_f32((hash((15210 + s : U32)) % 1000000 : U32)) / 1000000.0 : F32)

def gen.leaf(+k: Nat, +i: U32, p: Pts) -> Pts:
  match k:
    case 0n:
      p
    case 1n+q:
      Pts{xs, ys} = p
      gen.leaf(q, (i + 1 : U32), Pts{Array.set(F32, xs, i, rand((2 * i : U32))), Array.set(F32, ys, i, rand((2 * i + 1 : U32)))})

# Seq.tabulate genPoint n (SeqBasis.tabulate 5000)
@unsafe
def gen(+lo: U32, +k: U32, p: Pts) -> Pts:
  gen.at(U32.is_le(k, 5000), lo, k, p)

@unsafe
def gen.at(small: Bool, +lo: U32, +k: U32, p: Pts) -> Pts:
  match small:
    case True{}:
      gen.leaf(U32.to_nat(k), lo, p)
    case False{}:
      gen.fork(lo, U32.shr(k), k, pts.fork(p))

@unsafe
def gen.fork(+lo: U32, +h: U32, +k: U32, f: Pts & Pts) -> Pts:
  (p0, p1) = f
  a b = gen(lo, h, p0) gen((lo + h : U32), (k - h : U32), p1)
  pts.join(a, b)

# The bounding box: NearestNeighbors.reduce 10000, from (+inf, +inf) and (-inf, -inf)
# ----------------------------------------------------------------------------------

type Pt is Data:
  Pt{x: F32, y: F32}

def pt.min(a: Pt, b: Pt) -> Pt:
  match a b:
    case Pt{+x1, +y1} Pt{+x2, +y2}:
      Pt{fmin(x1, x2), fmin(y1, y2)}

def pt.max(a: Pt, b: Pt) -> Pt:
  match a b:
    case Pt{+x1, +y1} Pt{+x2, +y2}:
      Pt{fmax(x1, x2), fmax(y1, y2)}

def pt.op(hi: Bool, a: Pt, b: Pt) -> Pt:
  match hi:
    case True{}:
      pt.max(a, b)
    case False{}:
      pt.min(a, b)

@unsafe
def box.pt(+k: Nat, +i: U32, +hi: Bool, acc: Pt, r: At) -> Pt:
  At{p, +x, +y} = r
  box.loop(k, (i + 1 : U32), hi, pt.op(hi, acc, Pt{x, y}), p)

@unsafe
def box.loop(+k: Nat, +i: U32, +hi: Bool, acc: Pt, p: Pts) -> Pt:
  match k:
    case 0n:
      acc
    case 1n+q:
      box.pt(q, i, hi, acc, at(i, p))

def box.id(hi: Bool) -> Pt:
  match hi:
    case True{}:
      Pt{(0.0 - 1.0 / 0.0 : F32), (0.0 - 1.0 / 0.0 : F32)}
    case False{}:
      Pt{(1.0 / 0.0 : F32), (1.0 / 0.0 : F32)}

@unsafe
def box(+lo: U32, +hi: U32, +up: Bool, p: Pts) -> Pt:
  box.at(((hi - lo : U32) <= 10000 : U32), lo, hi, up, p)

@unsafe
def box.at(small: Bool, +lo: U32, +hi: U32, +up: Bool, p: Pts) -> Pt:
  match small:
    case True{}:
      box.loop(U32.to_nat((hi - lo : U32)), lo, up, box.id(up), p)
    case False{}:
      box.fork(lo, (lo + U32.shr((hi - lo : U32)) : U32), hi, up, pts.fork(p))

@unsafe
def box.fork(+lo: U32, +mid: U32, +hi: U32, +up: Bool, f: Pts & Pts) -> Pt:
  (p0, p1) = f
  a b = box(lo, mid, up, p0) box(mid, hi, up, p1)
  pt.op(up, a, b)

# The tree
# --------

type Tree is Data:
  Leaf{ax: F32, ay: F32, w: F32, n: U32, vs: List<&2, U32>}
  Node{ax: F32, ay: F32, w: F32, n: U32, a: Tree, b: Tree, c: Tree, d: Tree}

def count(t: Tree) -> U32:
  match t:
    case Leaf{ax, ay, w, +n, vs}:
      n
    case Node{ax, ay, w, +n, a, b, c, d}:
      n

# Geometry2D.quadrant (cx, cy) (x, y)
def quadrant(+cx: F32, +cy: F32, +x: F32, +y: F32) -> U32:
  wpick((y < cy : F32), wpick((x < cx : F32), 2, 3), wpick((x < cx : F32), 1, 0))

# CountingSort.sort idx (quadrant of each point) 4: a stable sort by quadrant.
# The slice idx[lo, lo + n) is cut into nb blocks of bs; the blocks count
# their quadrants in parallel into cs[q * nb + b], an exclusive scan of cs gives
# each (quadrant, block) its place, and the blocks write their indices in
# parallel into out. With one block it is CountingSort.seqSort.

type Srt is Type:
  Srt{p: Pts, idx: Array<U32>, cs: Array<U32>}

def srt.join(a: Srt, b: Srt) -> Srt:
  Srt{p0, i0, c0} = a
  Srt{p1, i1, c1} = b
  Srt{pts.join(p0, p1), Array.join(U32, i0, i1), Array.join(U32, c0, c1)}

def srt.split(fp: Pts & Pts, fi: Array<U32> & Array<U32>, fc: Array<U32> & Array<U32>) -> Srt & Srt:
  (p0, p1) = fp
  (i0, i1) = fi
  (c0, c1) = fc
  (Srt{p0, i0, c0}, Srt{p1, i1, c1})

def srt.fork(s: Srt) -> Srt & Srt:
  Srt{p, idx, cs} = s
  srt.split(pts.fork(p), Array.fork(U32, idx), Array.fork(U32, cs))

# the counts of one block, then written at cs[q * nb + b]
type C4 is Data:
  C4{c0: U32, c1: U32, c2: U32, c3: U32}

def c4.inc(+q: U32, c: C4) -> C4:
  match c:
    case C4{a, b, d, e}:
      C4{(a + Bool.to_u32(U32.is_eq(q, 0)) : U32), (b + Bool.to_u32(U32.is_eq(q, 1)) : U32), (d + Bool.to_u32(U32.is_eq(q, 2)) : U32), (e + Bool.to_u32(U32.is_eq(q, 3)) : U32)}

def c4.get(+q: U32, c: C4) -> U32:
  match c:
    case C4{a, b, d, e}:
      wpick(U32.is_lt(q, 2), wpick(U32.is_zero(q), a, b), wpick(U32.is_eq(q, 2), d, e))

type Cr is Type:
  Cr{p: Pts, idx: Array<U32>, c: C4}

@unsafe
def cnt.put(+k: Nat, +t: U32, +cx: F32, +cy: F32, idx: Array<U32>, c: C4, r: At) -> Cr:
  At{p, +x, +y} = r
  cnt.loop(k, (t + 1 : U32), cx, cy, idx, c4.inc(quadrant(cx, cy, x, y), c), p)

def cnt.idx(+k: Nat, +t: U32, +cx: F32, +cy: F32, c: C4, p: Pts, r: Array<U32> & U32) -> Cr:
  (idx, +i) = r
  cnt.put(k, t, cx, cy, idx, c, at(i, p))

@unsafe
def cnt.loop(+k: Nat, +t: U32, +cx: F32, +cy: F32, idx: Array<U32>, c: C4, p: Pts) -> Cr:
  match k:
    case 0n:
      Cr{p, idx, c}
    case 1n+q:
      cnt.idx(q, t, cx, cy, c, p, idx[t])

def cnt.fin(+b: U32, +nb: U32, cs: Array<U32>, r: Cr) -> Srt:
  Cr{p, idx, c} = r
  match c:
    case C4{c0, c1, c2, c3}:
      Srt{p, idx, (((cs[b] <- c0)[(nb + b : U32)] <- c1)[(2 * nb + b : U32)] <- c2)[(3 * nb + b : U32)] <- c3}

def block.lo(+lo: U32, +n: U32, +bs: U32, +b: U32) -> U32:
  (lo + U32.min((b * bs : U32), n) : U32)

def block.len(+n: U32, +bs: U32, +b: U32) -> U32:
  (U32.min(((b + 1) * bs : U32), n) - U32.min((b * bs : U32), n) : U32)

def cnt.block(+lo: U32, +n: U32, +bs: U32, +nb: U32, +b: U32, +cx: F32, +cy: F32, s: Srt) -> Srt:
  Srt{p, idx, cs} = s
  cnt.fin(b, nb, cs, cnt.loop(U32.to_nat(block.len(n, bs, b)), block.lo(lo, n, bs, b), cx, cy, idx, C4{0, 0, 0, 0}, p))

# parfor 1 (i, j) over the blocks
@unsafe
def cnt(+i: U32, +j: U32, +lo: U32, +n: U32, +bs: U32, +nb: U32, +cx: F32, +cy: F32, s: Srt) -> Srt:
  cnt.at(U32.is_eq((j - i : U32), 1), i, j, lo, n, bs, nb, cx, cy, s)

@unsafe
def cnt.at(one: Bool, +i: U32, +j: U32, +lo: U32, +n: U32, +bs: U32, +nb: U32, +cx: F32, +cy: F32, s: Srt) -> Srt:
  match one:
    case True{}:
      cnt.block(lo, n, bs, nb, i, cx, cy, s)
    case False{}:
      cnt.fork(i, (i + U32.shr((j - i : U32)) : U32), j, lo, n, bs, nb, cx, cy, srt.fork(s))

@unsafe
def cnt.fork(+i: U32, +mid: U32, +j: U32, +lo: U32, +n: U32, +bs: U32, +nb: U32, +cx: F32, +cy: F32, f: Srt & Srt) -> Srt:
  (s0, s1) = f
  a b = cnt(i, mid, lo, n, bs, nb, cx, cy, s0) cnt(mid, j, lo, n, bs, nb, cx, cy, s1)
  srt.join(a, b)

# the exclusive scan of cs, in place
@unsafe
def scan.put(+k: Nat, +j: U32, +s: U32, r: Array<U32> & U32) -> Array<U32>:
  (c, +x) = r
  scan(k, (j + 1 : U32), (s + x : U32), c[j] <- s)

@unsafe
def scan(+k: Nat, +j: U32, +s: U32, c: Array<U32>) -> Array<U32>:
  match k:
    case 0n:
      c
    case 1n+q:
      scan.put(q, j, s, c[j])

# the writes of a block: quadrant q's next index goes to out[o.q]
type Wr is Type:
  Wr{p: Pts, idx: Array<U32>, out: Array<U32>}

def wr.join(a: Wr, b: Wr) -> Wr:
  Wr{p0, i0, o0} = a
  Wr{p1, i1, o1} = b
  Wr{pts.join(p0, p1), Array.join(U32, i0, i1), Array.join(U32, o0, o1)}

@unsafe
def wr.put(+k: Nat, +t: U32, +cx: F32, +cy: F32, +i: U32, idx: Array<U32>, out: Array<U32>, +o: C4, r: At) -> Wr:
  At{p, +x, +y} = r
  +q = quadrant(cx, cy, x, y)
  +at = c4.get(q, o)
  wr.loop(k, (t + 1 : U32), cx, cy, c4.inc(q, o), Wr{p, idx, out[at] <- i})

def wr.idx(+k: Nat, +t: U32, +cx: F32, +cy: F32, out: Array<U32>, o: C4, p: Pts, r: Array<U32> & U32) -> Wr:
  (idx, +i) = r
  wr.put(k, t, cx, cy, i, idx, out, o, at(i, p))

@unsafe
def wr.loop(+k: Nat, +t: U32, +cx: F32, +cy: F32, o: C4, w: Wr) -> Wr:
  match k:
    case 0n:
      w
    case 1n+q:
      Wr{p, idx, out} = w
      wr.idx(q, t, cx, cy, out, o, p, idx[t])

def wr.o3(+lo: U32, +n: U32, +bs: U32, +b: U32, +cx: F32, +cy: F32, +o0: U32, +o1: U32, +o2: U32, p: Pts, idx: Array<U32>, out: Array<U32>, r: Array<U32> & U32) -> Wr & Array<U32>:
  (offs, +o3) = r
  (wr.loop(U32.to_nat(block.len(n, bs, b)), block.lo(lo, n, bs, b), cx, cy, C4{o0, o1, o2, o3}, Wr{p, idx, out}), offs)

def wr.o2(+lo: U32, +n: U32, +bs: U32, +nb: U32, +b: U32, +cx: F32, +cy: F32, +o0: U32, +o1: U32, p: Pts, idx: Array<U32>, out: Array<U32>, r: Array<U32> & U32) -> Wr & Array<U32>:
  (offs, +o2) = r
  wr.o3(lo, n, bs, b, cx, cy, o0, o1, o2, p, idx, out, offs[(3 * nb + b : U32)])

def wr.o1(+lo: U32, +n: U32, +bs: U32, +nb: U32, +b: U32, +cx: F32, +cy: F32, +o0: U32, p: Pts, idx: Array<U32>, out: Array<U32>, r: Array<U32> & U32) -> Wr & Array<U32>:
  (offs, +o1) = r
  wr.o2(lo, n, bs, nb, b, cx, cy, o0, o1, p, idx, out, offs[(2 * nb + b : U32)])

def wr.o0(+lo: U32, +n: U32, +bs: U32, +nb: U32, +b: U32, +cx: F32, +cy: F32, p: Pts, idx: Array<U32>, out: Array<U32>, r: Array<U32> & U32) -> Wr & Array<U32>:
  (offs, +o0) = r
  wr.o1(lo, n, bs, nb, b, cx, cy, o0, p, idx, out, offs[(nb + b : U32)])

def wr.block(+lo: U32, +n: U32, +bs: U32, +nb: U32, +b: U32, +cx: F32, +cy: F32, w: Wr, offs: Array<U32>) -> Wr & Array<U32>:
  Wr{p, idx, out} = w
  wr.o0(lo, n, bs, nb, b, cx, cy, p, idx, out, offs[b])

def wr.join2(l: Wr & Array<U32>, r: Wr & Array<U32>) -> Wr & Array<U32>:
  (a, x) = l
  (b, y) = r
  (wr.join(a, b), Array.join(U32, x, y))

def wr.split(fp: Pts & Pts, fi: Array<U32> & Array<U32>, fo: Array<U32> & Array<U32>, ff: Array<U32> & Array<U32>) -> (Wr & Array<U32>) & (Wr & Array<U32>):
  (p0, p1) = fp
  (i0, i1) = fi
  (o0, o1) = fo
  (f0, f1) = ff
  ((Wr{p0, i0, o0}, f0), (Wr{p1, i1, o1}, f1))

def wr.fork(w: Wr, offs: Array<U32>) -> (Wr & Array<U32>) & (Wr & Array<U32>):
  Wr{p, idx, out} = w
  wr.split(pts.fork(p), Array.fork(U32, idx), Array.fork(U32, out), Array.fork(U32, offs))

@unsafe
def wrs(+i: U32, +j: U32, +lo: U32, +n: U32, +bs: U32, +nb: U32, +cx: F32, +cy: F32, s: Wr & Array<U32>) -> Wr & Array<U32>:
  (w, offs) = s
  wrs.at(U32.is_eq((j - i : U32), 1), i, j, lo, n, bs, nb, cx, cy, w, offs)

@unsafe
def wrs.at(one: Bool, +i: U32, +j: U32, +lo: U32, +n: U32, +bs: U32, +nb: U32, +cx: F32, +cy: F32, w: Wr, offs: Array<U32>) -> Wr & Array<U32>:
  match one:
    case True{}:
      wr.block(lo, n, bs, nb, i, cx, cy, w, offs)
    case False{}:
      wrs.fork(i, (i + U32.shr((j - i : U32)) : U32), j, lo, n, bs, nb, cx, cy, wr.fork(w, offs))

@unsafe
def wrs.fork(+i: U32, +mid: U32, +j: U32, +lo: U32, +n: U32, +bs: U32, +nb: U32, +cx: F32, +cy: F32, f: (Wr & Array<U32>) & (Wr & Array<U32>)) -> Wr & Array<U32>:
  (s0, s1) = f
  a b = wrs(i, mid, lo, n, bs, nb, cx, cy, s0) wrs(mid, j, lo, n, bs, nb, cx, cy, s1)
  wr.join2(a, b)

# Quadrant offsets of the sorted slice: offs[q * nb] for q in 0..3
type Q4 is Data:
  Q4{o1: U32, o2: U32, o3: U32}

type Sorted is Type:
  Sorted{p: Pts, out: Array<U32>, q: Q4}

def sorted.o3(+o1: U32, +o2: U32, p: Pts, out: Array<U32>, r: Array<U32> & U32) -> Sorted:
  (offs, +o3) = r
  Sorted{p, out, Q4{o1, o2, o3}}

def sorted.o2(+nb: U32, +o1: U32, p: Pts, out: Array<U32>, r: Array<U32> & U32) -> Sorted:
  (offs, +o2) = r
  sorted.o3(o1, o2, p, out, offs[(3 * nb : U32)])

def sorted.o1(+nb: U32, p: Pts, out: Array<U32>, r: Array<U32> & U32) -> Sorted:
  (offs, +o1) = r
  sorted.o2(nb, o1, p, out, offs[(2 * nb : U32)])

def sorted.fin(+nb: U32, r: Wr & Array<U32>) -> Sorted:
  (w, offs) = r
  Wr{p, idx, out} = w
  sorted.o1(nb, p, out, offs[nb])

def sort.cnt(+lo: U32, +n: U32, +bs: U32, +nb: U32, +cx: F32, +cy: F32, s: Srt) -> Sorted:
  Srt{p, idx, cs} = s
  sorted.fin(nb, wrs(0, nb, lo, n, bs, nb, cx, cy, (Wr{p, idx, Array.new(U32, depth(n), 0)}, scan(U32.to_nat((4 * nb : U32)), 0, 0, cs))))

def sort.blocks(+n: U32) -> U32:
  wpick((n < 8192 : U32) || (n / 128 <= 1 : U32), 1, (n / 128 : U32))

# the slice idx[lo, lo + n), sorted by quadrant around (cx, cy) into a new array
def sort(+lo: U32, +n: U32, +cx: F32, +cy: F32, p: Pts, idx: Array<U32>) -> Sorted:
  +nb = sort.blocks(n)
  +bs = ((n - 1) / nb + 1 : U32)
  sort.cnt(lo, n, bs, nb, cx, cy, cnt(0, nb, lo, n, bs, nb, cx, cy, Srt{p, idx, Array.new(U32, depth((4 * nb : U32)), 0)}))

# makeTreeBounded
# ---------------

@unsafe
def leaf.put(+k: Nat, +t: U32, acc: List<&2, U32>, r: Array<U32> & U32) -> List<&2, U32>:
  (idx, +i) = r
  leaf.go(k, (t - 1 : U32), Con{i, acc}, idx)

# idx[t - k, t] as a list, read from the end
@unsafe
def leaf.go(+k: Nat, +t: U32, acc: List<&2, U32>, idx: Array<U32>) -> List<&2, U32>:
  match k:
    case 0n:
      acc
    case 1n+q:
      leaf.put(q, t, acc, idx[t])

def leaf(+lo: U32, +n: U32, idx: Array<U32>) -> List<&2, U32>:
  leaf.go(U32.to_nat(n), (lo + n - 1 : U32), Nil{}, idx)

type Kids is Type:
  Kids{a: Tree, b: Tree, c: Tree, d: Tree}

def node(+ax: F32, +ay: F32, +w: F32, +n: U32, k: Kids) -> Tree:
  Kids{a, b, c, d} = k
  Node{ax, ay, w, n, a, b, c, d}

type Fork4 is Type:
  Fork4{a: Pts & Array<U32>, b: Pts & Array<U32>, c: Pts & Array<U32>, d: Pts & Array<U32>}

def fork4.go(fp: Pts & Pts, fq: Pts & Pts, fi: Array<U32> & Array<U32>, fj: Array<U32> & Array<U32>) -> Fork4:
  (p0, p1) = fp
  (q0, q1) = fq
  (i0, i1) = fi
  (j0, j1) = fj
  Fork4{(p0, i0), (p1, i1), (q0, j0), (q1, j1)}

def fork4.two(f: Pts & Pts, g: Array<U32> & Array<U32>) -> Fork4:
  (p, q) = f
  (i, j) = g
  fork4.go(pts.fork(p), pts.fork(q), Array.fork(U32, i), Array.fork(U32, j))

# four handles to the points and to the sorted indices
def fork4(p: Pts, out: Array<U32>) -> Fork4:
  fork4.two(pts.fork(p), Array.fork(U32, out))

@unsafe
def quad.par(+ax: F32, +ay: F32, +qw: F32, +o1: U32, +o2: U32, +o3: U32, +n: U32, f: Fork4) -> Kids:
  Fork4{fa, fb, fc, fd} = f
  (pa, ia) = fa
  (pb, ib) = fb
  (pc, ic) = fc
  (pd, id) = fd
  a b c d = build(0, o1, (ax + qw : F32), (ay + qw : F32), qw, pa, ia) build(o1, (o2 - o1 : U32), ax, (ay + qw : F32), qw, pb, ib)
    build(o2, (o3 - o2 : U32), ax, ay, qw, pc, ic) build(o3, (n - o3 : U32), (ax + qw : F32), ay, qw, pd, id)
  Kids{a, b, c, d}

@unsafe
def quad.seq(+ax: F32, +ay: F32, +qw: F32, +o1: U32, +o2: U32, +o3: U32, +n: U32, f: Fork4) -> Kids:
  Fork4{fa, fb, fc, fd} = f
  (pa, ia) = fa
  (pb, ib) = fb
  (pc, ic) = fc
  (pd, id) = fd
  Kids{build(0, o1, (ax + qw : F32), (ay + qw : F32), qw, pa, ia), build(o1, (o2 - o1 : U32), ax, (ay + qw : F32), qw, pb, ib),
    build(o2, (o3 - o2 : U32), ax, ay, qw, pc, ic), build(o3, (n - o3 : U32), (ax + qw : F32), ay, qw, pd, id)}

@unsafe
def quads.at(small: Bool, +ax: F32, +ay: F32, +qw: F32, +o1: U32, +o2: U32, +o3: U32, +n: U32, f: Fork4) -> Kids:
  match small:
    case True{}:
      quad.seq(ax, ay, qw, o1, o2, o3, n, f)
    case False{}:
      quad.par(ax, ay, qw, o1, o2, o3, n, f)

@unsafe
def quads(+ax: F32, +ay: F32, +w: F32, +qw: F32, +n: U32, s: Sorted) -> Tree:
  Sorted{p, out, q} = s
  match q:
    case Q4{+o1, +o2, +o3}:
      node(ax, ay, w, n, quads.at((n <= 100 : U32), ax, ay, qw, o1, o2, o3, n, fork4(p, out)))

@unsafe
def build.at(small: Bool, +lo: U32, +n: U32, +ax: F32, +ay: F32, +w: F32, p: Pts, idx: Array<U32>) -> Tree:
  match small:
    case True{}:
      Leaf{ax, ay, w, n, leaf(lo, n, idx)}
    case False{}:
      +qw = (w / 2.0 : F32)
      quads(ax, ay, w, qw, n, sort(lo, n, (ax + qw : F32), (ay + qw : F32), p, idx))

# makeTreeBounded 16 verts idx[lo, lo + n) (ax, ay) w
@unsafe
def build(+lo: U32, +n: U32, +ax: F32, +ay: F32, +w: F32, p: Pts, idx: Array<U32>) -> Tree:
  build.at((n <= 16 : U32), lo, n, ax, ay, w, p, idx)

# The search
# ----------

type Best is Data:
  Best{i: U32, d: F32}

# Geometry2D.distance
def distance(+x1: F32, +y1: F32, +x2: F32, +y2: F32) -> F32:
  +dx = (x2 - x1 : F32)
  +dy = (y2 - y1 : F32)
  F32.sqrt((dx * dx + dy * dy : F32))

def constrain(+x: F32, +lo: F32, +hi: F32) -> F32:
  fpick((x < lo : F32), lo, fpick((x > hi : F32), hi, x))

def to_box(+x: F32, +y: F32, +ax: F32, +ay: F32, +w: F32) -> F32:
  distance(x, y, constrain(x, ax, (ax + w : F32)), constrain(y, ay, (ay + w : F32)))

def refine.at(closer: Bool, +qi: U32, +qd: F32, b: Best) -> Best:
  match closer:
    case True{}:
      Best{qi, qd}
    case False{}:
      b

def refine.pt(+pi: U32, +x: F32, +y: F32, +qi: U32, b: Best, r: At) -> Pts & Best:
  match b:
    case Best{+bi, +bd}:
      At{p, +qx, +qy} = r
      +qd = distance(x, y, qx, qy)
      (p, refine.at((qd < bd : F32), qi, qd, Best{bi, bd}))

def refine.go(same: Bool, +pi: U32, +x: F32, +y: F32, +qi: U32, b: Best, p: Pts) -> Pts & Best:
  match same:
    case True{}:
      (p, b)
    case False{}:
      refine.pt(pi, x, y, qi, b, at(qi, p))

@unsafe
def refine.next(+pi: U32, +x: F32, +y: F32, vs: List<&2, U32>, r: Pts & Best) -> Pts & Best:
  (p, b) = r
  refine(pi, x, y, vs, b, p)

# AS.foldl refineNearest best vertices
@unsafe
def refine(+pi: U32, +x: F32, +y: F32, vs: List<&2, U32>, b: Best, p: Pts) -> Pts & Best:
  match vs:
    case Nil{}:
      (p, b)
    case Con{+qi, rest}:
      refine.next(pi, x, y, rest, refine.go(U32.is_eq(qi, pi), pi, x, y, qi, b, p))

@unsafe
def search.next(+pi: U32, +x: F32, +y: F32, t: Tree, r: Pts & Best) -> Pts & Best:
  (p, b) = r
  search(pi, x, y, b, t, p)

# children in the order of the heuristic, from the quadrant of the point
@unsafe
def search.kids(lo: Bool, left: Bool, +pi: U32, +x: F32, +y: F32, b: Best, a: Tree, kb: Tree, c: Tree, d: Tree, p: Pts) -> Pts & Best:
  match lo left:
    case False{} False{}:
      search.next(pi, x, y, d, search.next(pi, x, y, c, search.next(pi, x, y, kb, search(pi, x, y, b, a, p))))
    case False{} True{}:
      search.next(pi, x, y, d, search.next(pi, x, y, c, search.next(pi, x, y, a, search(pi, x, y, b, kb, p))))
    case True{} True{}:
      search.next(pi, x, y, a, search.next(pi, x, y, d, search.next(pi, x, y, kb, search(pi, x, y, b, c, p))))
    case True{} False{}:
      search.next(pi, x, y, kb, search.next(pi, x, y, c, search.next(pi, x, y, a, search(pi, x, y, b, d, p))))

def search.in(+pi: U32, +x: F32, +y: F32, b: Best, t: Tree, p: Pts) -> Pts & Best:
  match t:
    case Leaf{ax, ay, w, n, vs}:
      refine(pi, x, y, vs, b, p)
    case Node{+ax, +ay, +w, n, a, kb, c, d}:
      +qw = (w / 2.0 : F32)
      search.kids((y < (ay + qw : F32) : F32), (x < (ax + qw : F32) : F32), pi, x, y, b, a, kb, c, d, p)

def search.go(far: Bool, +pi: U32, +x: F32, +y: F32, b: Best, t: Tree, p: Pts) -> Pts & Best:
  match far:
    case True{}:
      (p, b)
    case False{}:
      search.in(pi, x, y, b, t, p)

def box.ax(t: Tree) -> F32:
  match t:
    case Leaf{ax, ay, w, n, vs}:
      ax
    case Node{ax, ay, w, n, a, b, c, d}:
      ax

def box.ay(t: Tree) -> F32:
  match t:
    case Leaf{ax, ay, w, n, vs}:
      ay
    case Node{ax, ay, w, n, a, b, c, d}:
      ay

def box.w(t: Tree) -> F32:
  match t:
    case Leaf{ax, ay, w, n, vs}:
      w
    case Node{ax, ay, w, n, a, b, c, d}:
      w

# nearestNeighbor_'s search best t
@unsafe
def search(+pi: U32, +x: F32, +y: F32, b: Best, +t: Tree, p: Pts) -> Pts & Best:
  match b:
    case Best{+bi, +bd}:
      search.go((to_box(x, y, box.ax(t), box.ay(t), box.w(t)) > bd : F32), pi, x, y, Best{bi, bd}, t, p)

def iota.leaf(+k: Nat, +i: U32, a: Array<U32>) -> Array<U32>:
  match k:
    case 0n:
      a
    case 1n+q:
      iota.leaf(q, (i + 1 : U32), a[i] <- i)

# idx = Seq.tabulate (fn i => i) n
@unsafe
def iota(+lo: U32, +k: U32, a: Array<U32>) -> Array<U32>:
  iota.at(U32.is_le(k, 5000), lo, k, a)

@unsafe
def iota.at(small: Bool, +lo: U32, +k: U32, a: Array<U32>) -> Array<U32>:
  match small:
    case True{}:
      iota.leaf(U32.to_nat(k), lo, a)
    case False{}:
      iota.fork(lo, U32.shr(k), k, Array.fork(U32, a))

@unsafe
def iota.fork(+lo: U32, +h: U32, +k: U32, f: Array<U32> & Array<U32>) -> Array<U32>:
  (a0, a1) = f
  x y = iota(lo, h, a0) iota((lo + h : U32), (k - h : U32), a1)
  Array.join(U32, x, y)

@unsafe


# Fork-join kit
# -------------

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

@unsafe
def pfor(~T: Type, ~E: Data, ~split: T -> T & T, ~join: T -> T -> T, ~body: @+e:E -> @+lo:U32 -> @+hi:U32 -> T -> T, +e: E, +g: U32, +i: U32, +j: U32, s: T) -> T:
  pfor.go(~T, ~E, ~split, ~join, ~body, U32.is_le((j - i : U32), g), e, g, i, j, s)

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
def pred(~T: Type, ~E: Data, ~R: Type, ~split: T -> T & T, ~leaf: @+e:E -> @+b:U32 -> T -> R, ~comb: R -> R -> R, +e: E, +i: U32, +j: U32, s: T) -> R:
  pred.go(~T, ~E, ~R, ~split, ~leaf, ~comb, U32.is_eq((j - i : U32), 1), e, i, j, s)

# the same loop run sequentially, one range at a time: body(e, b, b + 1) for b
# in [i, j)
@unsafe
def sfor.go(~T: Type, ~E: Data, ~body: @+e:E -> @+lo:U32 -> @+hi:U32 -> T -> T, k: Nat, +e: E, +i: U32, s: T) -> T:
  match k:
    case 0n:
      s
    case 1n+q:
      sfor.go(T, E, body, q, e, (i + 1 : U32), body(e, i, (i + 1 : U32), s))

@unsafe
def sfor(~T: Type, ~E: Data, ~body: @+e:E -> @+lo:U32 -> @+hi:U32 -> T -> T, +e: E, +i: U32, +j: U32, s: T) -> T:
  sfor.go(~T, ~E, ~body, U32.to_nat((j - i : U32)), e, i, s)

def a.split(a: Array<U32>) -> Array<U32> & Array<U32>:
  Array.fork(U32, a)

def a.join(a: Array<U32>, b: Array<U32>) -> Array<U32>:
  Array.join(U32, a, b)

# The mesh (Topology2D)
# ---------------------

def none() -> U32:
  4294967295

def mod3(+i: U32) -> U32:
  wpick((i > 2 : U32), (i - 3 : U32), i)

def bpick(c: Bool, a: Bool, b: Bool) -> Bool:
  match c:
    case True{}:
      a
    case False{}:
      b

# The vertex points (vdata), the triangles (triangle t: vertices at tri[8t],
# tri[8t + 1], tri[8t + 2], neighbours at tri[8t + 4], ..., none() for
# INVALID_ID), triangleOfVertex, and the reservations (id + 1, 0 for ~1).
type M is Type:
  M{p: Pts, tri: Array<U32>, tov: Array<U32>, res: Array<U32>}

def m.mk(fp: Pts & Pts, ft: Array<U32> & Array<U32>, fv: Array<U32> & Array<U32>, fr: Array<U32> & Array<U32>) -> M & M:
  (p0, p1) = fp
  (t0, t1) = ft
  (v0, v1) = fv
  (r0, r1) = fr
  (M{p0, t0, v0, r0}, M{p1, t1, v1, r1})

def m.fork(m: M) -> M & M:
  M{p, tri, tov, res} = m
  m.mk(pts.fork(p), Array.fork(U32, tri), Array.fork(U32, tov), Array.fork(U32, res))

def m.join(a: M, b: M) -> M:
  M{p0, t0, v0, r0} = a
  M{p1, t1, v1, r1} = b
  M{pts.join(p0, p1), Array.join(U32, t0, t1), Array.join(U32, v0, v1), Array.join(U32, r0, r1)}

def m.tri.r(p: Pts, tov: Array<U32>, res: Array<U32>, r: Array<U32> & U32) -> M & U32:
  (tri, +v) = r
  (M{p, tri, tov, res}, v)

def m.tri(+k: U32, m: M) -> M & U32:
  M{p, tri, tov, res} = m
  m.tri.r(p, tov, res, tri[k])

def m.tov.r(p: Pts, tri: Array<U32>, res: Array<U32>, r: Array<U32> & U32) -> M & U32:
  (tov, +v) = r
  (M{p, tri, tov, res}, v)

def m.tov(+k: U32, m: M) -> M & U32:
  M{p, tri, tov, res} = m
  m.tov.r(p, tri, res, tov[k])

def m.res.r(p: Pts, tri: Array<U32>, tov: Array<U32>, r: Array<U32> & U32) -> M & U32:
  (res, +v) = r
  (M{p, tri, tov, res}, v)

def m.res(+k: U32, m: M) -> M & U32:
  M{p, tri, tov, res} = m
  m.res.r(p, tri, tov, res[k])

def m.set(+k: U32, +v: U32, m: M) -> M:
  M{p, tri, tov, res} = m
  M{p, tri[k] <- v, tov, res}

def m.stov(+k: U32, +v: U32, m: M) -> M:
  M{p, tri, tov, res} = m
  M{p, tri, tov[k] <- v, res}

def m.sres(+k: U32, +v: U32, m: M) -> M:
  M{p, tri, tov, res} = m
  M{p, tri, tov, res[k] <- v}

def m.rmax.r(p: Pts, tri: Array<U32>, tov: Array<U32>, r: Array<U32> & U32) -> M:
  (res, old) = r
  M{p, tri, tov, res}

# writeMax reserved k v: an atomic max (MaPLe's compare-and-swap loop)
def m.rmax(+k: U32, +v: U32, m: M) -> M:
  M{p, tri, tov, res} = m
  m.rmax.r(p, tri, tov, Array.atomic.max(res, k, v))

def m.pt.r(tri: Array<U32>, tov: Array<U32>, res: Array<U32>, r: At) -> M & Pt:
  At{p, +x, +y} = r
  (M{p, tri, tov, res}, Pt{x, y})

# vdata v
def m.pt(+v: U32, m: M) -> M & Pt:
  M{p, tri, tov, res} = m
  m.pt.r(tri, tov, res, at(v, p))

type V3 is Data:
  V3{a: U32, b: U32, c: U32}

def v3.c(+a: U32, +b: U32, r: M & U32) -> M & V3:
  (m, +c) = r
  (m, V3{a, b, c})

def v3.b(+k: U32, +a: U32, r: M & U32) -> M & V3:
  (m, +b) = r
  v3.c(a, b, m.tri((k + 2 : U32), m))

def v3.a(+k: U32, r: M & U32) -> M & V3:
  (m, +a) = r
  v3.b(k, a, m.tri((k + 1 : U32), m))

# tri[k], tri[k + 1], tri[k + 2]: a triangle's vertices (k = 8t) or neighbours (k = 8t + 4)
def m.v3(+k: U32, m: M) -> M & V3:
  v3.a(k, m.tri(k, m))

def v3.at(+i: U32, v: V3) -> U32:
  match v:
    case V3{+a, +b, +c}:
      wpick(U32.is_eq(i, 0), a, wpick(U32.is_eq(i, 1), b, c))

# locate: the position of t, or none()
def v3.find(+t: U32, v: V3) -> U32:
  match v:
    case V3{+a, +b, +c}:
      wpick(U32.is_eq(a, t), 0, wpick(U32.is_eq(b, t), 1, wpick(U32.is_eq(c, t), 2, none())))

# fastLocate
def v3.fast(+t: U32, v: V3) -> U32:
  match v:
    case V3{+a, +b, +c}:
      wpick(U32.is_eq(a, t), 0, wpick(U32.is_eq(b, t), 1, 2))

# Geometry2D.Point.counterClockwise (a, b, c): triArea > 0
def ccw(+ax: F32, +ay: F32, +bx: F32, +by: F32, +cx: F32, +cy: F32) -> Bool:
  ((bx - ax) * (cy - ay) - (by - ay) * (cx - ax) > 0.0 : F32)

# Geometry2D.Point.inCircle (a, b, c) d, through Geometry3D's cross and dot
def incircle(+ax: F32, +ay: F32, +bx: F32, +by: F32, +cx: F32, +cy: F32, +dx: F32, +dy: F32) -> Bool:
  +a1 = (ax - dx : F32)
  +a2 = (ay - dy : F32)
  +a3 = (a1 * a1 + a2 * a2 : F32)
  +b1 = (bx - dx : F32)
  +b2 = (by - dy : F32)
  +b3 = (b1 * b1 + b2 * b2 : F32)
  +c1 = (cx - dx : F32)
  +c2 = (cy - dy : F32)
  +c3 = (c1 * c1 + c2 * c2 : F32)
  ((a2 * b3 - a3 * b2) * c1 + (a3 * b1 - a1 * b3) * c2 + (a1 * b2 - a2 * b1) * c3 > 0.0 : F32)

def ic.c(+x: F32, +y: F32, +ax: F32, +ay: F32, +bx: F32, +by: F32, r: M & Pt) -> M & Bool:
  (m, q) = r
  match q:
    case Pt{+cx, +cy}:
      (m, incircle(ax, ay, bx, by, cx, cy, x, y))

def ic.b(+x: F32, +y: F32, +ax: F32, +ay: F32, +c: U32, r: M & Pt) -> M & Bool:
  (m, q) = r
  match q:
    case Pt{+bx, +by}:
      ic.c(x, y, ax, ay, bx, by, m.pt(c, m))

def ic.a(+x: F32, +y: F32, +b: U32, +c: U32, r: M & Pt) -> M & Bool:
  (m, q) = r
  match q:
    case Pt{+ax, +ay}:
      ic.b(x, y, ax, ay, c, m.pt(b, m))

def ic.v(+x: F32, +y: F32, r: M & V3) -> M & Bool:
  (m, vs) = r
  match vs:
    case V3{+a, +b, +c}:
      ic.a(x, y, b, c, m.pt(a, m))

# pointInCircle mesh (t, _) (x, y)
def in_circle(+t: U32, +x: F32, +y: F32, m: M) -> M & Bool:
  ic.v(x, y, m.v3((8 * t : U32), m))

def po.c(+x: F32, +y: F32, +ax: F32, +ay: F32, r: M & Pt) -> M & Bool:
  (m, q) = r
  match q:
    case Pt{+cx, +cy}:
      (m, ccw(ax, ay, x, y, cx, cy))

def po.a(+x: F32, +y: F32, +w3: U32, r: M & Pt) -> M & Bool:
  (m, q) = r
  match q:
    case Pt{+ax, +ay}:
      po.c(x, y, ax, ay, m.pt(w3, m))

def po.v(+i: U32, +x: F32, +y: F32, r: M & V3) -> M & Bool:
  (m, +vs) = r
  po.a(x, y, v3.at(i, vs), m.pt(v3.at(mod3((i + 2 : U32)), vs), m))

# pointOutside mesh (t, i) (x, y)
def point_outside(+t: U32, +i: U32, +x: F32, +y: F32, m: M) -> M & Bool:
  po.v(i, x, y, m.v3((8 * t : U32), m))

# A simplex (t, i); t = none() for NONE
type S is Data:
  S{t: U32, i: U32}

def ac.l(+t: U32, +tp: U32, r: M & V3) -> M & S:
  (m, +vs) = r
  +j = v3.find(t, vs)
  (m, S{wpick(U32.is_eq(j, none()), none(), tp), j})

def ac.go(isnone: Bool, +t: U32, +tp: U32, m: M) -> M & S:
  match isnone:
    case True{}:
      (m, S{none(), 0})
    case False{}:
      ac.l(t, tp, m.v3((8 * tp + 4 : U32), m))

def ac.r(+t: U32, r: M & U32) -> M & S:
  (m, +tp) = r
  ac.go(U32.is_eq(tp, none()), t, tp, m)

# across mesh (t, i)
def across(+t: U32, +i: U32, m: M) -> M & S:
  ac.r(t, m.tri((8 * t + 4 + i : U32), m))

# findPoint mesh (x, y) (t, i), k rotations tried at t; the triangle found
@unsafe
def fp(+t: U32, +i: U32, +k: U32, +x: F32, +y: F32, m: M) -> M & U32:
  fp.o(t, i, k, x, y, point_outside(t, i, x, y, m))

@unsafe
def fp.b(+t: U32, +tp: U32, +x: F32, +y: F32, r: M & V3) -> M & U32:
  (m, +vs) = r
  fp(tp, v3.fast(t, vs), 0, x, y, m)

@unsafe
def fp.a(+t: U32, +x: F32, +y: F32, r: M & U32) -> M & U32:
  (m, +tp) = r
  fp.b(t, tp, x, y, m.v3((8 * tp + 4 : U32), m))

@unsafe
def fp.next(last: Bool, +t: U32, +i: U32, +k: U32, +x: F32, +y: F32, m: M) -> M & U32:
  match last:
    case True{}:
      (m, t)
    case False{}:
      fp(t, mod3((i + 1 : U32)), (k + 1 : U32), x, y, m)

@unsafe
def fp.o(+t: U32, +i: U32, +k: U32, +x: F32, +y: F32, r: M & Bool) -> M & U32:
  (m, out) = r
  match out:
    case True{}:
      fp.a(t, x, y, m.tri((8 * t + 4 + i : U32), m))
    case False{}:
      fp.next(U32.is_eq(k, 2), t, i, k, x, y, m)

# loopPerimeter, f being writeMax reserved v (id + 1) (chk False) or the check
# of the rip-and-tent loop (chk True): a reservation of id is cleared, any
# other one makes the result False.
def lp.chk.go(mine: Bool, +v: U32, b: Bool, m: M) -> M & Bool:
  match mine:
    case True{}:
      (m.sres(v, 0, m), b)
    case False{}:
      (m, False{})

def lp.chk(+id: U32, +v: U32, b: Bool, r: M & U32) -> M & Bool:
  (m, +rv) = r
  lp.chk.go(U32.is_eq(rv, (id + 1 : U32)), v, b, m)

def lp.f(chk: Bool, +id: U32, +v: U32, b: Bool, m: M) -> M & Bool:
  match chk:
    case True{}:
      lp.chk(id, v, b, m.res(v, m))
    case False{}:
      (m.rmax(v, (id + 1 : U32), m), b)

@unsafe
def lp.loop(+chk: Bool, +id: U32, +x: F32, +y: F32, +t: U32, +i: U32, b: Bool, m: M) -> M & Bool:
  lp.in(chk, id, x, y, t, i, b, in_circle(t, x, y, m))

@unsafe
def lp.ac.go(isnone: Bool, +chk: Bool, +id: U32, +x: F32, +y: F32, +t: U32, +i: U32, b: Bool, m: M) -> M & Bool:
  match isnone:
    case True{}:
      (m, b)
    case False{}:
      lp.loop(chk, id, x, y, t, i, b, m)

@unsafe
def lp.ac(+chk: Bool, +id: U32, +x: F32, +y: F32, b: Bool, r: M & S) -> M & Bool:
  (m, s) = r
  match s:
    case S{+tp, +ip}:
      lp.ac.go(U32.is_eq(tp, none()), chk, id, x, y, tp, ip, b, m)

# loopAcross b (t, i)
@unsafe
def lp.across(+chk: Bool, +id: U32, +x: F32, +y: F32, +t: U32, +i: U32, b: Bool, m: M) -> M & Bool:
  lp.ac(chk, id, x, y, b, across(t, i, m))

@unsafe
def lp.last(+chk: Bool, +id: U32, +x: F32, +y: F32, +t: U32, +i1: U32, r: M & Bool) -> M & Bool:
  (m, b) = r
  lp.across(chk, id, x, y, t, mod3((i1 + 1 : U32)), b, m)

@unsafe
def lp.mid2(+chk: Bool, +id: U32, +x: F32, +y: F32, +t: U32, +i1: U32, b: Bool, r: M & U32) -> M & Bool:
  (m, +v) = r
  lp.last(chk, id, x, y, t, i1, lp.f(chk, id, v, b, m))

@unsafe
def lp.mid(+chk: Bool, +id: U32, +x: F32, +y: F32, +t: U32, +i1: U32, r: M & Bool) -> M & Bool:
  (m, b) = r
  lp.mid2(chk, id, x, y, t, i1, b, m.tri((8 * t + i1 : U32), m))

@unsafe
def lp.in(+chk: Bool, +id: U32, +x: F32, +y: F32, +t: U32, +i: U32, b: Bool, r: M & Bool) -> M & Bool:
  (m, inside) = r
  match inside:
    case True{}:
      +i1 = mod3((i + 1 : U32))
      lp.mid(chk, id, x, y, t, i1, lp.across(chk, id, x, y, t, i1, b, m))
    case False{}:
      (m, b)

@unsafe
def lp.t2(+chk: Bool, +id: U32, +x: F32, +y: F32, +c: U32, +i: U32, r: M & Bool) -> M & Bool:
  (m, b) = r
  lp.across(chk, id, x, y, c, i, b, m)

@unsafe
def lp.t1(+chk: Bool, +id: U32, +x: F32, +y: F32, +c: U32, +i: U32, b: Bool, r: M & U32) -> M & Bool:
  (m, +v) = r
  lp.t2(chk, id, x, y, c, i, lp.f(chk, id, v, b, m))

# f (b, firstVertex (c, i)), then loopAcross (c, i)
@unsafe
def lp.side(+chk: Bool, +id: U32, +x: F32, +y: F32, +c: U32, +i: U32, b: Bool, m: M) -> M & Bool:
  lp.t1(chk, id, x, y, c, i, b, m.tri((8 * c + i : U32), m))

@unsafe
def lp.s(+chk: Bool, +id: U32, +x: F32, +y: F32, +c: U32, +i: U32, r: M & Bool) -> M & Bool:
  (m, b) = r
  lp.side(chk, id, x, y, c, i, b, m)

# loopPerimeter mesh c (x, y) True f
@unsafe
def loop_perimeter(+chk: Bool, +id: U32, +x: F32, +y: F32, +c: U32, m: M) -> M & Bool:
  lp.s(chk, id, x, y, c, 2, lp.s(chk, id, x, y, c, 1, lp.side(chk, id, x, y, c, 0, True{}, m)))

# updateTriangle t (a, b, c) (d, e, f)
def set_tri(+t: U32, +a: U32, +b: U32, +c: U32, +d: U32, +e: U32, +f: U32, m: M) -> M:
  M{p, tri, tov, res} = m
  +k = (8 * t : U32)
  M{p, (((((tri[k] <- a)[(k + 1 : U32)] <- b)[(k + 2 : U32)] <- c)[(k + 4 : U32)] <- d)[(k + 5 : U32)] <- e)[(k + 6 : U32)] <- f, tov, res}

def rn.put(miss: Bool, +k: U32, +nw: U32, m: M) -> M:
  match miss:
    case True{}:
      m
    case False{}:
      m.set(k, nw, m)

def rn.v(+t: U32, +old: U32, +nw: U32, r: M & V3) -> M:
  (m, +vs) = r
  +j = v3.find(old, vs)
  rn.put(U32.is_eq(j, none()), (8 * t + 4 + j : U32), nw, m)

def rn.go(isnone: Bool, +t: U32, +old: U32, +nw: U32, m: M) -> M:
  match isnone:
    case True{}:
      m
    case False{}:
      rn.v(t, old, nw, m.v3((8 * t + 4 : U32), m))

# replaceNeighbor mesh t (old, new) (a missing old, FailedReplaceNeighbor in
# MaPLe, leaves t as it is)
def rn(+t: U32, +old: U32, +nw: U32, m: M) -> M:
  rn.go(U32.is_eq(t, none()), t, old, nw, m)

# if triangleOfVertex v = old then set it to nw
def tov.fix(c: Bool, +v: U32, +nw: U32, m: M) -> M:
  match c:
    case True{}:
      m.stov(v, nw, m)
    case False{}:
      m

def ds.tov(+t: U32, +v: U32, +ta0: U32, +ta1: U32, +w1: U32, +w2: U32, +w3: U32, +t1: U32, +t2: U32, +t3: U32, r: M & U32) -> M:
  (m, +x) = r
  rn(t3, t, ta1, rn(t2, t, ta0, set_tri(ta1, w3, v, w2, t3, t, ta0, set_tri(ta0, w2, v, w1, t2, ta1, t, set_tri(t, w1, v, w3, t1, ta0, ta1, tov.fix(U32.is_eq(x, t), w2, ta0, m))))))

def ds.n(+t: U32, +v: U32, +ta0: U32, +ta1: U32, +w1: U32, +w2: U32, +w3: U32, r: M & V3) -> M:
  (m, ns) = r
  match ns:
    case V3{+t1, +t2, +t3}:
      ds.tov(t, v, ta0, ta1, w1, w2, w3, t1, t2, t3, m.tov(w2, m.stov(v, t, m)))

def ds.v(+t: U32, +v: U32, +ta0: U32, +ta1: U32, r: M & V3) -> M:
  (m, vs) = r
  match vs:
    case V3{+w1, +w2, +w3}:
      ds.n(t, v, ta0, ta1, w1, w2, w3, m.v3((8 * t + 4 : U32), m))

# doSplit mesh t (v, p) (ta0, ta1); vdata v already holds p
def do_split(+t: U32, +v: U32, +ta0: U32, +ta1: U32, m: M) -> M:
  ds.v(t, v, ta0, ta1, m.v3((8 * t : U32), m))

def df.t3(+t: U32, +t1: U32, +w3: U32, +t2: U32, +t4: U32, r: M & U32) -> M:
  (m, +x) = r
  rn(t4, t1, t, rn(t2, t, t1, tov.fix(U32.is_eq(x, t1), w3, t, m)))

def df.t1(+t: U32, +t1: U32, +w1: U32, +w3: U32, +t2: U32, +t4: U32, r: M & U32) -> M:
  (m, +x) = r
  df.t3(t, t1, w3, t2, t4, m.tov(w3, tov.fix(U32.is_eq(x, t), w1, t1, m)))

def df.pv(+i: U32, +va: V3, +na: V3, +ip: U32, +nb: V3, r: M & V3) -> M:
  (m, +vb) = r
  +w1 = v3.at(i, va)
  +w2 = v3.at(mod3((i + 1 : U32)), va)
  +w3 = v3.at(mod3((i + 2 : U32)), va)
  +t1 = v3.at(i, na)
  +t2 = v3.at(mod3((i + 1 : U32)), na)
  +t3 = v3.at(mod3((i + 2 : U32)), na)
  +w4 = v3.at(mod3((ip + 1 : U32)), vb)
  +t = v3.at(ip, nb)
  +t4 = v3.at(mod3((ip + 1 : U32)), nb)
  +t5 = v3.at(mod3((ip + 2 : U32)), nb)
  df.t1(t, t1, w1, w3, t2, t4, m.tov(w1, set_tri(t1, w1, w2, w4, t5, t2, t, set_tri(t, w2, w3, w4, t1, t3, t4, m))))

def df.pn(+t: U32, +i: U32, +va: V3, +na: V3, +tp: U32, r: M & V3) -> M:
  (m, +nb) = r
  +ip = v3.fast(t, nb)
  df.pv(i, va, na, ip, nb, m.v3((8 * tp : U32), m))

def df.n(+t: U32, +i: U32, +va: V3, r: M & V3) -> M:
  (m, +na) = r
  +tp = v3.at(i, na)
  df.pn(t, i, va, na, tp, m.v3((8 * tp + 4 : U32), m))

def df.v(+t: U32, +i: U32, r: M & V3) -> M:
  (m, +va) = r
  df.n(t, i, va, m.v3((8 * t + 4 : U32), m))

# doFlip mesh (t, i)
def do_flip(+t: U32, +i: U32, m: M) -> M:
  df.v(t, i, m.v3((8 * t : U32), m))

@unsafe
def rt.maybe.go(isnone: Bool, +t: U32, +i: U32, +x: F32, +y: F32, m: M) -> M:
  match isnone:
    case True{}:
      m
    case False{}:
      rt.loop(t, i, x, y, m)

@unsafe
def rt.maybe(+x: F32, +y: F32, s: S, m: M) -> M:
  match s:
    case S{+t, +i}:
      rt.maybe.go(U32.is_eq(t, none()), t, i, x, y, m)

@unsafe
def rt.b(+t: U32, +i: U32, +x: F32, +y: F32, +sa: S, r: M & S) -> M:
  (m, +sb) = r
  rt.maybe(x, y, sb, rt.maybe(x, y, sa, do_flip(t, i, m)))

@unsafe
def rt.a(+t: U32, +i: U32, +x: F32, +y: F32, r: M & S) -> M:
  (m, +sa) = r
  rt.b(t, i, x, y, sa, across(t, mod3((i + 2 : U32)), m))

@unsafe
def rt.in(+t: U32, +i: U32, +x: F32, +y: F32, r: M & Bool) -> M:
  (m, inside) = r
  match inside:
    case True{}:
      rt.a(t, i, x, y, across(t, mod3((i + 1 : U32)), m))
    case False{}:
      m

# ripAndTentCavity's loop
@unsafe
def rt.loop(+t: U32, +i: U32, +x: F32, +y: F32, m: M) -> M:
  rt.in(t, i, x, y, in_circle(t, x, y, m))

@unsafe
def rat.c(+c: U32, +v: U32, +x: F32, +y: F32, +s1: S, +s2: S, r: M & S) -> M:
  (m, +s3) = r
  rt.maybe(x, y, s3, rt.maybe(x, y, s2, rt.maybe(x, y, s1, do_split(c, v, (2 * v : U32), (2 * v + 1 : U32), m))))

@unsafe
def rat.b(+c: U32, +v: U32, +x: F32, +y: F32, +s1: S, r: M & S) -> M:
  (m, +s2) = r
  rat.c(c, v, x, y, s1, s2, across(c, 2, m))

@unsafe
def rat.a(+c: U32, +v: U32, +x: F32, +y: F32, r: M & S) -> M:
  (m, +s1) = r
  rat.b(c, v, x, y, s1, across(c, 1, m))

# ripAndTentCavity mesh c (v, (x, y)) (2v, 2v + 1)
@unsafe
def rip_and_tent(+c: U32, +v: U32, +x: F32, +y: F32, m: M) -> M:
  rat.a(c, v, x, y, across(c, 0, m))


# The triangulation's state (DelaunayTriangulation)
# -------------------------------------------------

# A run of the done list: Run{al, s, l} is allVertices[s, s + l) if al, else
# d[s, s + l), d holding the winners of every round
type Run is Data:
  Run{al: Bool, s: U32, l: U32}

# allVertices, the nearest-neighbour points and their vertices (done), the
# losers, centers and winnerFlags of the round, d, the new losers, and the
# split's block counts
type X is Type:
  X{al: Array<U32>, np: Pts, nd: Array<U32>, los: Array<U32>, cen: Array<U32>, flg: Array<U32>, d: Array<U32>, nlo: Array<U32>, cl: Array<U32>, cr: Array<U32>}

type B is Type:
  B{m: M, x: X}

def x.mk2(al: Array<U32> & Array<U32>, np: Pts & Pts, nd: Array<U32> & Array<U32>, los: Array<U32> & Array<U32>, cen: Array<U32> & Array<U32>, flg: Array<U32> & Array<U32>, d: Array<U32> & Array<U32>, nlo: Array<U32> & Array<U32>, cl: Array<U32> & Array<U32>, cr: Array<U32> & Array<U32>) -> X & X:
  (a0, a1) = al
  (p0, p1) = np
  (n0, n1) = nd
  (l0, l1) = los
  (c0, c1) = cen
  (f0, f1) = flg
  (d0, d1) = d
  (o0, o1) = nlo
  (x0, x1) = cl
  (y0, y1) = cr
  (X{a0, p0, n0, l0, c0, f0, d0, o0, x0, y0}, X{a1, p1, n1, l1, c1, f1, d1, o1, x1, y1})

def x.fork(x: X) -> X & X:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  x.mk2(Array.fork(U32, al), pts.fork(np), Array.fork(U32, nd), Array.fork(U32, los), Array.fork(U32, cen), Array.fork(U32, flg), Array.fork(U32, d), Array.fork(U32, nlo), Array.fork(U32, cl), Array.fork(U32, cr))

def x.join(a: X, b: X) -> X:
  X{a0, p0, n0, l0, c0, f0, d0, o0, x0, y0} = a
  X{a1, p1, n1, l1, c1, f1, d1, o1, x1, y1} = b
  X{Array.join(U32, a0, a1), pts.join(p0, p1), Array.join(U32, n0, n1), Array.join(U32, l0, l1), Array.join(U32, c0, c1), Array.join(U32, f0, f1), Array.join(U32, d0, d1), Array.join(U32, o0, o1), Array.join(U32, x0, x1), Array.join(U32, y0, y1)}

def b.mk2(fm: M & M, fx: X & X) -> B & B:
  (m0, m1) = fm
  (x0, x1) = fx
  (B{m0, x0}, B{m1, x1})

def b.fork(s: B) -> B & B:
  B{m, x} = s
  b.mk2(m.fork(m), x.fork(x))

def b.join(a: B, b: B) -> B:
  B{m0, x0} = a
  B{m1, x1} = b
  B{m.join(m0, m1), x.join(x0, x1)}

# reads and writes of X's arrays
def x.al(+i: U32, x: X) -> X & U32:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  pair.go(Array<U32>, U32, X & U32, al[i], a => +v => (X{a, np, nd, los, cen, flg, d, nlo, cl, cr}, v))

def x.nd(+i: U32, x: X) -> X & U32:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  pair.go(Array<U32>, U32, X & U32, nd[i], a => +v => (X{al, np, a, los, cen, flg, d, nlo, cl, cr}, v))

def x.los(+i: U32, x: X) -> X & U32:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  pair.go(Array<U32>, U32, X & U32, los[i], a => +v => (X{al, np, nd, a, cen, flg, d, nlo, cl, cr}, v))

def x.cen(+i: U32, x: X) -> X & U32:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  pair.go(Array<U32>, U32, X & U32, cen[i], a => +v => (X{al, np, nd, los, a, flg, d, nlo, cl, cr}, v))

def x.flg(+i: U32, x: X) -> X & U32:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  pair.go(Array<U32>, U32, X & U32, flg[i], a => +v => (X{al, np, nd, los, cen, a, d, nlo, cl, cr}, v))

def x.cl(+i: U32, x: X) -> X & U32:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  pair.go(Array<U32>, U32, X & U32, cl[i], a => +v => (X{al, np, nd, los, cen, flg, d, nlo, a, cr}, v))

def x.cr(+i: U32, x: X) -> X & U32:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  pair.go(Array<U32>, U32, X & U32, cr[i], a => +v => (X{al, np, nd, los, cen, flg, d, nlo, cl, a}, v))

def x.sal(+i: U32, +v: U32, x: X) -> X:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  X{al[i] <- v, np, nd, los, cen, flg, d, nlo, cl, cr}

def x.scen(+i: U32, +v: U32, x: X) -> X:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  X{al, np, nd, los, cen[i] <- v, flg, d, nlo, cl, cr}

def x.sflg(+i: U32, +v: U32, x: X) -> X:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  X{al, np, nd, los, cen, flg[i] <- v, d, nlo, cl, cr}

def x.sd(+i: U32, +v: U32, x: X) -> X:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  X{al, np, nd, los, cen, flg, d[i] <- v, nlo, cl, cr}

def x.snlo(+i: U32, +v: U32, x: X) -> X:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  X{al, np, nd, los, cen, flg, d, nlo[i] <- v, cl, cr}

def x.scl(+i: U32, +v: U32, x: X) -> X:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  X{al, np, nd, los, cen, flg, d, nlo, cl[i] <- v, cr}

def x.scr(+i: U32, +v: U32, x: X) -> X:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr[i] <- v}

def x.id.go(lo: Bool, +nl: U32, +rem: U32, +i: U32, x: X) -> X & U32:
  match lo:
    case True{}:
      x.los(i, x)
    case False{}:
      x.al((rem + i - nl : U32), x)

# vertsToInsert i: dsAppend (losers, newcomers), newcomers = allVertices[rem, ..)
def x.id(+nl: U32, +rem: U32, +i: U32, x: X) -> X & U32:
  x.id.go((i < nl : U32), nl, rem, i, x)

def nn.q2(b: Best, x: X) -> X & U32:
  match b:
    case Best{+bi, bd}:
      x.nd(bi, x)

def nn.q1(al: Array<U32>, nd: Array<U32>, los: Array<U32>, cen: Array<U32>, flg: Array<U32>, d: Array<U32>, nlo: Array<U32>, cl: Array<U32>, cr: Array<U32>, r: Pts & Best) -> X & U32:
  (np, b) = r
  nn.q2(b, X{al, np, nd, los, cen, flg, d, nlo, cl, cr})

# nearestSimplex's nn pt: the done vertex nearest to (x, y)
@unsafe
def nn.q(+tree: Tree, +px: F32, +py: F32, x: X) -> X & U32:
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  nn.q1(al, nd, los, cen, flg, d, nlo, cl, cr, search(none(), px, py, Best{none(), (1.0 / 0.0 : F32)}, tree, np))

# The rounds' environment: the number of losers retried, where the newcomers
# start in allVertices, the nearest-neighbour tree
type E is Data:
  E{nl: U32, rem: U32, tree: Tree}

# The reservations (SeqBasis.tabulate reserveGrain: centers)
# ---------------------------------------------------------

def rsv.fin(x: X, r: M & Bool) -> B:
  (m, b) = r
  B{m, x}

@unsafe
def rsv.c(+i: U32, +id: U32, +px: F32, +py: F32, x: X, r: M & U32) -> B:
  (m, +c) = r
  rsv.fin(x.scen(i, c, x), loop_perimeter(False{}, id, px, py, c, m))

@unsafe
def rsv.c0(+i: U32, +id: U32, +px: F32, +py: F32, x: X, r: M & U32) -> B:
  (m, +c0) = r
  rsv.c(i, id, px, py, x, fp(c0, 0, 0, px, py, m))

@unsafe
def rsv.nn(+i: U32, +id: U32, +px: F32, +py: F32, m: M, r: X & U32) -> B:
  (x, +v) = r
  rsv.c0(i, id, px, py, x, m.tov(v, m))

@unsafe
def rsv.pt(+tree: Tree, +i: U32, +id: U32, x: X, r: M & Pt) -> B:
  (m, q) = r
  match q:
    case Pt{+px, +py}:
      rsv.nn(i, id, px, py, m, nn.q(tree, px, py, x))

@unsafe
def rsv.id(+tree: Tree, +i: U32, m: M, r: X & U32) -> B:
  (x, +id) = r
  rsv.pt(tree, i, id, x, m.pt(id, m))

@unsafe
def rsv.one(+e: E, +i: U32, s: B) -> B:
  match e:
    case E{+nl, +rem, +tree}:
      B{m, x} = s
      rsv.id(tree, i, m, x.id(nl, rem, i, x))

@unsafe
def rsv.loop(k: Nat, +e: E, +i: U32, s: B) -> B:
  match k:
    case 0n:
      s
    case 1n+q:
      rsv.loop(q, e, (i + 1 : U32), rsv.one(e, i, s))

@unsafe
def rsv.body(+e: E, +lo: U32, +hi: U32, s: B) -> B:
  rsv.loop(U32.to_nat((hi - lo : U32)), e, lo, s)

# The checks (the first half of SeqBasis.tabulate ripAndTentGrain: winnerFlags)
# ----------------------------------------------------------------------------

def chk.fin(+i: U32, x: X, r: M & Bool) -> B:
  (m, w) = r
  B{m, x.sflg(i, Bool.to_u32(w), x)}

@unsafe
def chk.pt(+i: U32, +id: U32, +c: U32, x: X, r: M & Pt) -> B:
  (m, q) = r
  match q:
    case Pt{+px, +py}:
      chk.fin(i, x, loop_perimeter(True{}, id, px, py, c, m))

@unsafe
def chk.c(+i: U32, +id: U32, m: M, r: X & U32) -> B:
  (x, +c) = r
  chk.pt(i, id, c, x, m.pt(id, m))

@unsafe
def chk.id(+i: U32, m: M, r: X & U32) -> B:
  (x, +id) = r
  chk.c(i, id, m, x.cen(i, x))

@unsafe
def chk.one(+e: E, +i: U32, s: B) -> B:
  match e:
    case E{+nl, +rem, +tree}:
      B{m, x} = s
      chk.id(i, m, x.id(nl, rem, i, x))

@unsafe
def chk.loop(k: Nat, +e: E, +i: U32, s: B) -> B:
  match k:
    case 0n:
      s
    case 1n+q:
      chk.loop(q, e, (i + 1 : U32), chk.one(e, i, s))

@unsafe
def chk.body(+e: E, +lo: U32, +hi: U32, s: B) -> B:
  chk.loop(U32.to_nat((hi - lo : U32)), e, lo, s)

# The rip-and-tents of the winners (its second half)
# --------------------------------------------------

@unsafe
def rip.pt(+id: U32, +c: U32, x: X, r: M & Pt) -> B:
  (m, q) = r
  match q:
    case Pt{+px, +py}:
      B{rip_and_tent(c, id, px, py, m), x}

@unsafe
def rip.c(+id: U32, m: M, r: X & U32) -> B:
  (x, +c) = r
  rip.pt(id, c, x, m.pt(id, m))

@unsafe
def rip.id(+i: U32, m: M, r: X & U32) -> B:
  (x, +id) = r
  rip.c(id, m, x.cen(i, x))

@unsafe
def rip.go(w: Bool, +nl: U32, +rem: U32, +i: U32, m: M, x: X) -> B:
  match w:
    case True{}:
      rip.id(i, m, x.id(nl, rem, i, x))
    case False{}:
      B{m, x}

@unsafe
def rip.f(+nl: U32, +rem: U32, +i: U32, m: M, r: X & U32) -> B:
  (x, +f) = r
  rip.go(U32.is_eq(f, 1), nl, rem, i, m, x)

@unsafe
def rip.one(+e: E, +i: U32, s: B) -> B:
  match e:
    case E{+nl, +rem, +tree}:
      B{m, x} = s
      rip.f(nl, rem, i, m, x.flg(i, x))

@unsafe
def rip.loop(k: Nat, +e: E, +i: U32, s: B) -> B:
  match k:
    case 0n:
      s
    case 1n+q:
      rip.loop(q, e, (i + 1 : U32), rip.one(e, i, s))

@unsafe
def rip.body(+e: E, +lo: U32, +hi: U32, s: B) -> B:
  rip.loop(U32.to_nat((hi - lo : U32)), e, lo, s)

# Split.split (blocks of 2000): winners to d from dlen, losers to nlo. Its two
# parfor 1 loops over the blocks run sequentially here (see the README).
# ------------------------------------------------------------------

type SE is Data:
  SE{m: U32, nl: U32, rem: U32, dlen: U32}

def sp.lo(+b: U32) -> U32:
  (b * 2000 : U32)

def sp.hi(+b: U32, +m: U32) -> U32:
  U32.min(((b + 1) * 2000 : U32), m)

@unsafe
def sp.cnt.f(k: Nat, +b: U32, +i: U32, +l: U32, +rr: U32, r: X & U32) -> X:
  (x, +f) = r
  sp.cnt(k, b, (i + 1 : U32), (l + f : U32), (rr + 1 - f : U32), x)

@unsafe
def sp.cnt(k: Nat, +b: U32, +i: U32, +l: U32, +rr: U32, x: X) -> X:
  match k:
    case 0n:
      x.scr(b, rr, x.scl(b, l, x))
    case 1n+q:
      sp.cnt.f(q, b, i, l, rr, x.flg(i, x))

@unsafe
def sp.cnt.body(+e: SE, +b: U32, +hi: U32, s: B) -> B:
  match e:
    case SE{+m, +nl, +rem, +dlen}:
      B{mm, x} = s
      B{mm, sp.cnt(U32.to_nat((sp.hi(b, m) - sp.lo(b) : U32)), b, sp.lo(b), 0, 0, x)}

def sp.put(w: Bool, +dlen: U32, +l: U32, +rr: U32, +v: U32, x: X) -> X:
  match w:
    case True{}:
      x.sd((dlen + l : U32), v, x)
    case False{}:
      x.snlo(rr, v, x)

@unsafe
def sp.wr.v(k: Nat, +nl: U32, +rem: U32, +dlen: U32, +i: U32, +l: U32, +rr: U32, +f: U32, r: X & U32) -> X:
  (x, +v) = r
  sp.wr(k, nl, rem, dlen, (i + 1 : U32), (l + f : U32), (rr + 1 - f : U32), sp.put(U32.is_eq(f, 1), dlen, l, rr, v, x))

@unsafe
def sp.wr.f(k: Nat, +nl: U32, +rem: U32, +dlen: U32, +i: U32, +l: U32, +rr: U32, r: X & U32) -> X:
  (x, +f) = r
  sp.wr.v(k, nl, rem, dlen, i, l, rr, f, x.id(nl, rem, i, x))

@unsafe
def sp.wr(k: Nat, +nl: U32, +rem: U32, +dlen: U32, +i: U32, +l: U32, +rr: U32, x: X) -> X:
  match k:
    case 0n:
      x
    case 1n+q:
      sp.wr.f(q, nl, rem, dlen, i, l, rr, x.flg(i, x))

@unsafe
def sp.wr.r(+e: SE, +b: U32, +l: U32, r: X & U32) -> X:
  match e:
    case SE{+m, +nl, +rem, +dlen}:
      (x, +rr) = r
      sp.wr(U32.to_nat((sp.hi(b, m) - sp.lo(b) : U32)), nl, rem, dlen, sp.lo(b), l, rr, x)

@unsafe
def sp.wr.l(+e: SE, +b: U32, r: X & U32) -> X:
  (x, +l) = r
  sp.wr.r(e, b, l, x.cr(b, x))

@unsafe
def sp.wr.body(+e: SE, +b: U32, +hi: U32, s: B) -> B:
  B{mm, x} = s
  B{mm, sp.wr.l(e, b, x.cl(b, x))}

# the exclusive scan of a[0, k) in place; the total
@unsafe
def sp.scan.r(k: Nat, +i: U32, +t: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (a, +v) = r
  sp.scan(k, (i + 1 : U32), (t + v : U32), a[i] <- t)

@unsafe
def sp.scan(k: Nat, +i: U32, +t: U32, a: Array<U32>) -> Array<U32> & U32:
  match k:
    case 0n:
      (a, t)
    case 1n+q:
      sp.scan.r(q, i, t, a[i])

# the split's result: the state, with the new losers as los (and the old ones
# as nlo), and the number of winners
@unsafe
def sp.wrote(+totl: U32, s: B) -> B & U32:
  B{m, x} = s
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  (B{m, X{al, np, nd, nlo, cen, flg, d, los, cl, cr}}, totl)

@unsafe
def sp.scr(+e: SE, +nb: U32, +totl: U32, m: M, al: Array<U32>, np: Pts, nd: Array<U32>, los: Array<U32>, cen: Array<U32>, flg: Array<U32>, d: Array<U32>, cl: Array<U32>, r: Array<U32> & U32) -> B & U32:
  (cr, +totr) = r
  sp.wrote(totl, pfor(~B, ~SE, ~b.fork, ~b.join, ~sp.wr.body, e, 1, 0, nb, B{m, X{al, np, nd, los, cen, flg, d, Array.new(U32, depth(totr), 0), cl, cr}}))

@unsafe
def sp.scl(+e: SE, +nb: U32, m: M, al: Array<U32>, np: Pts, nd: Array<U32>, los: Array<U32>, cen: Array<U32>, flg: Array<U32>, d: Array<U32>, cr: Array<U32>, r: Array<U32> & U32) -> B & U32:
  (cl, +totl) = r
  sp.scr(e, nb, totl, m, al, np, nd, los, cen, flg, d, cl, sp.scan(U32.to_nat(nb), 0, 0, cr))

@unsafe
def sp.counted(+e: SE, +nb: U32, s: B) -> B & U32:
  B{m, x} = s
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  sp.scl(e, nb, m, al, np, nd, los, cen, flg, d, cr, sp.scan(U32.to_nat(nb), 0, 0, cl))

# Split.split vertsToInsert winnerFlags, m elements
@unsafe
def split(+m: U32, +nl: U32, +rem: U32, +dlen: U32, s: B) -> B & U32:
  B{mm, x} = s
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  +nb = (1 + (m - 1) / 2000 : U32)
  +e = {SE{m, nl, rem, dlen} : SE}
  sp.counted(e, nb, pfor(~B, ~SE, ~b.fork, ~b.join, ~sp.cnt.body, e, 1, 0, nb, B{mm, X{al, np, nd, los, cen, flg, d, nlo, Array.new(U32, depth(nb), 0), Array.new(U32, depth(nb), 0)}}))


# buildNN done: the done points (Seq.map, grain 5000), then NN.makeTree 16
# -------------------------------------------------------------------------

type G is Type:
  G{p: Pts, nd: Array<U32>, np: Pts}

def g.mk2(fp: Pts & Pts, fd: Array<U32> & Array<U32>, fq: Pts & Pts) -> G & G:
  (p0, p1) = fp
  (d0, d1) = fd
  (q0, q1) = fq
  (G{p0, d0, q0}, G{p1, d1, q1})

def g.fork(g: G) -> G & G:
  G{p, nd, np} = g
  g.mk2(pts.fork(p), Array.fork(U32, nd), pts.fork(np))

def g.join(a: G, b: G) -> G:
  G{p0, d0, q0} = a
  G{p1, d1, q1} = b
  G{pts.join(p0, p1), Array.join(U32, d0, d1), pts.join(q0, q1)}

@unsafe
def ga.pt(k: Nat, +i: U32, nd: Array<U32>, np: Pts, r: At) -> G:
  Pts{xs, ys} = np
  At{p, +x, +y} = r
  ga.leaf(k, (i + 1 : U32), G{p, nd, Pts{Array.set(F32, xs, i, x), Array.set(F32, ys, i, y)}})

@unsafe
def ga.v(k: Nat, +i: U32, p: Pts, np: Pts, r: Array<U32> & U32) -> G:
  (nd, +v) = r
  ga.pt(k, i, nd, np, at(v, p))

@unsafe
def ga.leaf(k: Nat, +i: U32, g: G) -> G:
  match k:
    case 0n:
      g
    case 1n+q:
      G{p, nd, np} = g
      ga.v(q, i, p, np, nd[i])

@unsafe
def ga.body(+e: U32, +lo: U32, +hi: U32, g: G) -> G:
  ga.leaf(U32.to_nat((hi - lo : U32)), lo, g)

@unsafe
def mk.t5(+k: U32, +xl: F32, +yb: F32, +w: F32, idx: Array<U32>, f: Pts & Pts) -> Tree & Pts:
  (a, b) = f
  (build(0, k, xl, yb, w, a, idx), b)

@unsafe
def mk.t4(+k: U32, lo: Pt, hi: Pt, d: Pts) -> Tree & Pts:
  match lo hi:
    case Pt{+xl, +yb} Pt{+xr, +yt}:
      mk.t5(k, xl, yb, fmax((xr - xl : F32), (yt - yb : F32)), iota(0, k, Array.new(U32, depth(k), 0)), pts.fork(d))

@unsafe
def mk.t3(+k: U32, lo: Pt, f: Pts & Pts) -> Tree & Pts:
  (c, d) = f
  mk.t4(k, lo, box(0, k, True{}, c), d)

@unsafe
def mk.t2(+k: U32, a: Pts, f: Pts & Pts) -> Tree & Pts:
  (b, c) = f
  mk.t3(k, box(0, k, False{}, a), pts.fork(c))

@unsafe
def mk.t1(+k: U32, f: Pts & Pts) -> Tree & Pts:
  (a, b) = f
  mk.t2(k, a, pts.fork(b))

# NN.makeTree 16 np (k points): the tree, and the points handed back
@unsafe
def mk.tree(+k: U32, np: Pts) -> Tree & Pts:
  mk.t1(k, pts.fork(np))

def b.nn.t(p: Pts, tri: Array<U32>, tov: Array<U32>, res: Array<U32>, al: Array<U32>, nd: Array<U32>, los: Array<U32>, cen: Array<U32>, flg: Array<U32>, d: Array<U32>, nlo: Array<U32>, cl: Array<U32>, cr: Array<U32>, r: Tree & Pts) -> B & Tree:
  (tree, np) = r
  (B{M{p, tri, tov, res}, X{al, np, nd, los, cen, flg, d, nlo, cl, cr}}, tree)

@unsafe
def b.nn.g(+k: U32, tri: Array<U32>, tov: Array<U32>, res: Array<U32>, al: Array<U32>, los: Array<U32>, cen: Array<U32>, flg: Array<U32>, d: Array<U32>, nlo: Array<U32>, cl: Array<U32>, cr: Array<U32>, g: G) -> B & Tree:
  G{p, nd, np} = g
  b.nn.t(p, tri, tov, res, al, nd, los, cen, flg, d, nlo, cl, cr, mk.tree(k, np))

# buildNN over nd[0, k): the new state (with the new points np) and the tree
@unsafe
def b.nn(+k: U32, s: B) -> B & Tree:
  B{m, x} = s
  M{p, tri, tov, res} = m
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  b.nn.g(k, tri, tov, res, al, los, cen, flg, d, nlo, cl, cr, pfor(~G, ~U32, ~g.fork, ~g.join, ~ga.body, 0, 5000, 0, k, G{p, nd, Pts{Array.new(F32, depth(k), 0.0), Array.new(F32, depth(k), 0.0)}}))

def b.take2(m: M, np: Pts, los: Array<U32>, cen: Array<U32>, flg: Array<U32>, d: Array<U32>, nlo: Array<U32>, cl: Array<U32>, cr: Array<U32>, r: Array<U32> & Array<U32>) -> B:
  (a1, a2) = r
  B{m, X{a1, np, a2, los, cen, flg, d, nlo, cl, cr}}

# done = Seq.take allVertices numDone: nd becomes a handle to allVertices
def b.take(s: B) -> B:
  B{m, x} = s
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  b.take2(m, np, los, cen, flg, d, nlo, cl, cr, Array.fork(U32, al))

# fresh centers and winnerFlags for m points
def b.fresh(+m: U32, s: B) -> B:
  B{mm, x} = s
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  B{mm, X{al, np, nd, los, Array.new(U32, depth(m), 0), Array.new(U32, depth(m), 0), d, nlo, cl, cr}}

# shouldRebuild numNextRebuild numDone
def rebuild(+next: U32, +done: U32, +lim: U32) -> Bool:
  (done >= next : U32) && (done <= lim : U32)

# Real.ceil (Real.fromInt numNextRebuild * nnRebuildFactor)
def next10(+next: U32) -> U32:
  F32.to_u32(F32.ceil((U32.to_f32(next) * 10.0 : F32)))

# Real.round: to nearest, ties to even (x >= 0)
def rround(+x: F32) -> U32:
  +f = F32.floor(x)
  +d = (x - f : F32)
  +r = F32.to_u32(f)
  (r + Bool.to_u32((d > 0.5 : F32) || (F32.is_eq(d, 0.5) && U32.is_eq((r .&. 1 : U32), 1))) : U32)

# smallLoop: single inserts until 10000 points are in
# ----------------------------------------------------

type SR is Data:
  SR{done: U32, next: U32, tree: Tree}

@unsafe
def small.re(+n: U32, +lim: U32, +done: U32, +next: U32, r: B & Tree) -> B & SR:
  (s, tree) = r
  small(n, lim, done, next, tree, s)

@unsafe
def small.rb(rb: Bool, +n: U32, +lim: U32, +done: U32, +next: U32, +tree: Tree, s: B) -> B & SR:
  match rb:
    case True{}:
      small.re(n, lim, done, next10(next), b.nn(done, b.take(s)))
    case False{}:
      small(n, lim, done, next, tree, s)

@unsafe
def small.c(+n: U32, +lim: U32, +done: U32, +next: U32, +tree: Tree, +id: U32, +px: F32, +py: F32, x: X, r: M & U32) -> B & SR:
  (m, +c) = r
  +d1 = (done + 1 : U32)
  small.rb(rebuild(next, d1, lim), n, lim, d1, next, tree, B{rip_and_tent(c, id, px, py, m), x})

@unsafe
def small.c0(+n: U32, +lim: U32, +done: U32, +next: U32, +tree: Tree, +id: U32, +px: F32, +py: F32, x: X, r: M & U32) -> B & SR:
  (m, +c0) = r
  small.c(n, lim, done, next, tree, id, px, py, x, fp(c0, 0, 0, px, py, m))

@unsafe
def small.nn(+n: U32, +lim: U32, +done: U32, +next: U32, +tree: Tree, +id: U32, +px: F32, +py: F32, m: M, r: X & U32) -> B & SR:
  (x, +v) = r
  small.c0(n, lim, done, next, tree, id, px, py, x, m.tov(v, m))

@unsafe
def small.pt(+n: U32, +lim: U32, +done: U32, +next: U32, +tree: Tree, +id: U32, x: X, r: M & Pt) -> B & SR:
  (m, q) = r
  match q:
    case Pt{+px, +py}:
      small.nn(n, lim, done, next, tree, id, px, py, m, nn.q(tree, px, py, x))

@unsafe
def small.id(+n: U32, +lim: U32, +done: U32, +next: U32, +tree: Tree, m: M, r: X & U32) -> B & SR:
  (x, +id) = r
  small.pt(n, lim, done, next, tree, id, x, m.pt(id, m))

@unsafe
def small.go(stop: Bool, +n: U32, +lim: U32, +done: U32, +next: U32, +tree: Tree, s: B) -> B & SR:
  match stop:
    case True{}:
      (s, SR{done, next, tree})
    case False{}:
      B{m, x} = s
      small.id(n, lim, done, next, tree, m, x.al(done, x))

@unsafe
def small(+n: U32, +lim: U32, +done: U32, +next: U32, +tree: Tree, s: B) -> B & SR:
  small.go((done >= init.threshold() : U32) || U32.is_eq(done, n), n, lim, done, next, tree, s)

# initialThreshold
def init.threshold() -> U32:
  10000

# Seq.flatten (Seq.fromList done): blocks of 5000 in parallel (parfor 1)
# -------------------------------------------------------------------

type FL is Type:
  FL{al: Array<U32>, d: Array<U32>, f: Array<U32>}

def fl.mk2(fa: Array<U32> & Array<U32>, fd: Array<U32> & Array<U32>, ff: Array<U32> & Array<U32>) -> FL & FL:
  (a0, a1) = fa
  (d0, d1) = fd
  (f0, f1) = ff
  (FL{a0, d0, f0}, FL{a1, d1, f1})

def fl.fork(s: FL) -> FL & FL:
  FL{al, d, f} = s
  fl.mk2(Array.fork(U32, al), Array.fork(U32, d), Array.fork(U32, f))

def fl.join(a: FL, b: FL) -> FL:
  FL{a0, d0, f0} = a
  FL{a1, d1, f1} = b
  FL{Array.join(U32, a0, a1), Array.join(U32, d0, d1), Array.join(U32, f0, f1)}

type FE is Data:
  FE{runs: List<&2, Run>, tot: U32}

def fl.put.a(+pos: U32, d: Array<U32>, f: Array<U32>, r: Array<U32> & U32) -> FL:
  (al, +v) = r
  FL{al, d, f[pos] <- v}

def fl.put.d(+pos: U32, al: Array<U32>, f: Array<U32>, r: Array<U32> & U32) -> FL:
  (d, +v) = r
  FL{al, d, f[pos] <- v}

# f[pos] = (if fromAl then allVertices else d)[i]
def fl.put(fromal: Bool, +i: U32, +pos: U32, s: FL) -> FL:
  match fromal:
    case True{}:
      FL{al, d, f} = s
      fl.put.a(pos, d, f, al[i])
    case False{}:
      FL{al, d, f} = s
      fl.put.d(pos, al, f, d[i])

@unsafe
def fl.next(k: Nat, rest: List<&2, Run>, +pos: U32, s: FL) -> FL:
  match rest:
    case Nil{}:
      s
    case Con{r, rs}:
      match r:
        case Run{+al, +st, +l}:
          fl.copy(k, al, st, l, 0, rs, pos, s)

@unsafe
def fl.copy.c(avail: Bool, q: Nat, +al: Bool, +st: U32, +l: U32, +j: U32, rest: List<&2, Run>, +pos: U32, s: FL) -> FL:
  match avail:
    case True{}:
      fl.copy(q, al, st, l, (j + 1 : U32), rest, (pos + 1 : U32), fl.put(al, (st + j : U32), pos, s))
    case False{}:
      fl.next(1n+q, rest, pos, s)

# copy k elements to f from pos, from the run (al, st, l) at j, then the rest
@unsafe
def fl.copy(k: Nat, +al: Bool, +st: U32, +l: U32, +j: U32, rest: List<&2, Run>, +pos: U32, s: FL) -> FL:
  match k:
    case 0n:
      s
    case 1n+q:
      fl.copy.c((j < l : U32), q, al, st, l, j, rest, pos, s)

@unsafe
def fl.seek.go(here: Bool, k: Nat, +al: Bool, +st: U32, +l: U32, rest: List<&2, Run>, +o: U32, +lo: U32, s: FL) -> FL:
  match here:
    case True{}:
      fl.copy(k, al, st, l, (lo - o : U32), rest, lo, s)
    case False{}:
      fl.seek(k, rest, (o + l : U32), lo, s)

# the run holding output position lo (the runs start at o)
@unsafe
def fl.seek(k: Nat, rs: List<&2, Run>, +o: U32, +lo: U32, s: FL) -> FL:
  match rs:
    case Nil{}:
      s
    case Con{r, rest}:
      match r:
        case Run{+al, +st, +l}:
          fl.seek.go((lo < (o + l : U32) : U32), k, al, st, l, rest, o, lo, s)

@unsafe
def fl.body(+e: FE, +b: U32, +hi: U32, s: FL) -> FL:
  match e:
    case FE{+runs, +tot}:
      +lo = (b * 5000 : U32)
      fl.seek(U32.to_nat((U32.min((lo + 5000 : U32), tot) - lo : U32)), runs, 0, lo, s)

def fl.done2(m: M, al: Array<U32>, np: Pts, los: Array<U32>, cen: Array<U32>, flg: Array<U32>, nlo: Array<U32>, cl: Array<U32>, cr: Array<U32>, r: Array<U32> & Array<U32>) -> B:
  (f1, f2) = r
  B{m, X{al, np, f2, los, cen, flg, f1, nlo, cl, cr}}

def fl.done(m: M, np: Pts, los: Array<U32>, cen: Array<U32>, flg: Array<U32>, nlo: Array<U32>, cl: Array<U32>, cr: Array<U32>, s: FL) -> B:
  FL{al, d, f} = s
  fl.done2(m, al, np, los, cen, flg, nlo, cl, cr, Array.fork(U32, f))

# the done runs (tot vertices) flattened into a new d of n slots; nd is a handle to it
@unsafe
def flatten(+n: U32, +tot: U32, +runs: List<&2, Run>, s: B) -> B:
  B{m, x} = s
  X{al, np, nd, los, cen, flg, d, nlo, cl, cr} = x
  fl.done(m, np, los, cen, flg, nlo, cl, cr, pfor(~FL, ~FE, ~fl.fork, ~fl.join, ~fl.body, FE{runs, tot}, 1, 0, (1 + (tot - 1) / 5000 : U32), FL{al, d, Array.new(U32, depth(n), 0)}))

# The rounds (DelaunayTriangulation's loop)
# -----------------------------------------

@unsafe
def rounds.re(+n: U32, +mb: U32, +lim: U32, +done: U32, +next: U32, +rnd: U32, +nl: U32, +rem: U32, r: B & Tree) -> B & U32:
  (s, tree) = r
  rounds(n, mb, lim, done, next, rnd, nl, rem, done, [Run{False{}, 0, done}], tree, s)

@unsafe
def rounds.rb(rb: Bool, +n: U32, +mb: U32, +lim: U32, +done: U32, +next: U32, +rnd: U32, +nl: U32, +rem: U32, +dlen: U32, +runs: List<&2, Run>, +tree: Tree, s: B) -> B & U32:
  match rb:
    case True{}:
      rounds.re(n, mb, lim, done, next10(next), rnd, nl, rem, b.nn(done, flatten(n, done, runs, s)))
    case False{}:
      rounds(n, mb, lim, done, next, rnd, nl, rem, dlen, runs, tree, s)

@unsafe
def rounds.split(+n: U32, +mb: U32, +lim: U32, +done: U32, +next: U32, +rnd: U32, +mm: U32, +rem: U32, +dlen: U32, +runs: List<&2, Run>, +tree: Tree, r: B & U32) -> B & U32:
  (s, +nw) = r
  +done2 = (done + nw : U32)
  rounds.rb(rebuild(next, done2, lim), n, mb, lim, done2, next, (rnd + 1 : U32), (mm - nw : U32), rem, (dlen + nw : U32), Run{False{}, dlen, nw} <> runs, tree, s)

@unsafe
def rounds.go(fin: Bool, +n: U32, +mb: U32, +lim: U32, +done: U32, +next: U32, +rnd: U32, +nl: U32, +rem: U32, +dlen: U32, +runs: List<&2, Run>, +tree: Tree, s: B) -> B & U32:
  match fin:
    case True{}:
      (s, rnd)
    case False{}:
      +tot = (nl + n - rem : U32)
      +des = U32.min(mb, U32.min(tot, (1 + rround((U32.to_f32(done) * 0.035 : F32)) : U32)))
      +add = wpick((des <= nl : U32), 0, U32.min((des - nl : U32), (n - rem : U32)))
      +mm = (nl + add : U32)
      +e = {E{nl, rem, tree} : E}
      rounds.split(n, mb, lim, done, next, rnd, mm, (rem + add : U32), dlen, runs, tree, split(mm, nl, rem, dlen, pfor(~B, ~E, ~b.fork, ~b.join, ~rip.body, e, 20, 0, mm, pfor(~B, ~E, ~b.fork, ~b.join, ~chk.body, e, 20, 0, mm, pfor(~B, ~E, ~b.fork, ~b.join, ~rsv.body, e, 20, 0, mm, b.fresh(mm, s))))))

@unsafe
def rounds(+n: U32, +mb: U32, +lim: U32, +done: U32, +next: U32, +rnd: U32, +nl: U32, +rem: U32, +dlen: U32, +runs: List<&2, Run>, +tree: Tree, s: B) -> B & U32:
  rounds.go(U32.is_eq(done, n), n, mb, lim, done, next, rnd, nl, rem, dlen, runs, tree, s)

# The initial mesh (generateBoundary, initialMeshWithBoundaryCircle)
# ------------------------------------------------------------------

# Seq.reduce minCoords (or maxCoords) p0 over the points: blocks of 5000
type BE is Data:
  BE{n: U32, up: Bool, x0: F32, y0: F32}

@unsafe
def bnd.leaf(+e: BE, +b: U32, p: Pts) -> Pt:
  match e:
    case BE{+n, +up, +x0, +y0}:
      +lo = (b * 5000 : U32)
      box.loop(U32.to_nat((U32.min((lo + 5000 : U32), n) - lo : U32)), lo, up, Pt{x0, y0}, p)

def bnd.pts(k: Nat, +i: U32, +n: U32, +cx: F32, +cy: F32, +r: F32, p: Pts) -> Pts:
  match k:
    case 0n:
      p
    case 1n+q:
      Pts{xs, ys} = p
      +a = (2.0 * F32.pi() * (U32.to_f32(i) / 10.0) : F32)
      bnd.pts(q, (i + 1 : U32), n, cx, cy, r, Pts{Array.set(F32, xs, (n + i : U32), (cx + r * F32.cos(a) : F32)), Array.set(F32, ys, (n + i : U32), (cy + r * F32.sin(a) : F32))})

# the 10 boundary points on the circle of radius 10 |max - min| around the box's center
def boundary(+n: U32, lo: Pt, hi: Pt, p: Pts) -> Pts:
  match lo hi:
    case Pt{+lx, +ly} Pt{+hx, +hy}:
      +dx = (hx - lx : F32)
      +dy = (hy - ly : F32)
      +size = F32.sqrt((dx * dx + dy * dy : F32))
      +radius = (10.0 * size : F32)
      bnd.pts(10n, 0, n, (lx + 0.5 * dx : F32), (ly + 0.5 * dy : F32), radius, p)

def tov.v(+n: U32, +v: U32) -> U32:
  +k = (v - n : U32)
  wpick((v < n : U32), none(), wpick((k < 2 : U32), (2 * n : U32), (2 * n + k - 2 : U32)))

def tov.leaf(k: Nat, +n: U32, +v: U32, a: Array<U32>) -> Array<U32>:
  match k:
    case 0n:
      a
    case 1n+q:
      tov.leaf(q, n, (v + 1 : U32), a[v] <- tov.v(n, v))

def tov.body(+n: U32, +lo: U32, +hi: U32, a: Array<U32>) -> Array<U32>:
  tov.leaf(U32.to_nat((hi - lo : U32)), n, lo, a)

type TE is Data:
  TE{n: U32, nb: Bool}

def put3(+k: U32, +a: U32, +b: U32, +c: U32, arr: Array<U32>) -> Array<U32>:
  ((arr[k] <- a)[(k + 1 : U32)] <- b)[(k + 2 : U32)] <- c

# verticesOfTriangle t (nb False) or neighborsOfTriangle t (nb True)
def tri.one(nb: Bool, +n: U32, +t: U32, arr: Array<U32>) -> Array<U32>:
  match nb:
    case False{}:
      +inner = (t < (2 * n : U32) : U32)
      +j = (t - n : U32)
      put3((8 * t : U32), wpick(inner, none(), (j + 1 : U32)), wpick(inner, none(), (j + 2 : U32)), wpick(inner, none(), n), arr)
    case True{}:
      +inner = (t < (2 * n : U32) : U32)
      put3((8 * t + 4 : U32), wpick(inner || U32.is_eq(t, (2 * n : U32)), none(), (t - 1 : U32)), none(), wpick(inner || U32.is_eq(t, (2 * n + 7 : U32)), none(), (t + 1 : U32)), arr)

def tri.leaf(k: Nat, +e: TE, +t: U32, a: Array<U32>) -> Array<U32>:
  match k:
    case 0n:
      a
    case 1n+q:
      match e:
        case TE{+n, +nb}:
          tri.leaf(q, TE{n, nb}, (t + 1 : U32), tri.one(nb, n, t, a))

def tri.body(+e: TE, +lo: U32, +hi: U32, a: Array<U32>) -> Array<U32>:
  tri.leaf(U32.to_nat((hi - lo : U32)), e, lo, a)

def fill.leaf(k: Nat, +z: U32, +i: U32, a: Array<U32>) -> Array<U32>:
  match k:
    case 0n:
      a
    case 1n+q:
      fill.leaf(q, z, (i + 1 : U32), a[i] <- (i * (1 - z) : U32))

# a[i] = i (z = 0) or ~1 (reserved: 0, z = 1)
def fill.body(+z: U32, +lo: U32, +hi: U32, a: Array<U32>) -> Array<U32>:
  fill.leaf(U32.to_nat((hi - lo : U32)), z, lo, a)

# Driver
# ------

@unsafe
def hsh.r(k: Nat, +j: U32, +h: U32, r: Array<U32> & U32) -> U32:
  (tri, +v) = r
  hsh(k, (j + 1 : U32), wpick(U32.is_eq((j .&. 3 : U32), 3), h, (h * 31 + v : U32)), tri)

# h = h * 31 + x over every triangle's vertices and neighbours
@unsafe
def hsh(k: Nat, +j: U32, +h: U32, tri: Array<U32>) -> U32:
  match k:
    case 0n:
      h
    case 1n+q:
      hsh.r(q, j, h, tri[j])

def report(+n: U32, r: B & U32) -> String:
  (s, +rnd) = r
  B{m, x} = s
  M{p, tri, tov, res} = m
  "num rounds " ++ U32.show(rnd) ++ "\n\nto see output, use -output and -resolution arguments\nfor example: delaunay -n 1000 -output result.ppm -resolution 1000\ncheck " ++ U32.show(hsh(U32.to_nat((8 * (2 * n + 8) : U32)), 0, 0, tri))

@unsafe
def run.small(+n: U32, r: B & SR) -> String:
  (s, sr) = r
  match sr:
    case SR{+done, +next, +tree}:
      report(n, rounds(n, (1 + (n - 1) / 10 : U32), F32.to_u32(F32.floor((U32.to_f32(n) / 10.0 : F32))), done, next, 0, 0, done, 0, [Run{True{}, 0, done}], tree, s))

@unsafe
def run.nn(+n: U32, r: B & Tree) -> String:
  (s, tree) = r
  run.small(n, small(n, F32.to_u32(F32.floor((U32.to_f32(n) / 10.0 : F32))), 1, 10, tree, s))

@unsafe
def run.first(+n: U32, al: Array<U32>, r: M & Pt) -> String:
  (m, q) = r
  match q:
    case Pt{+x0, +y0}:
      run.first2(n, al, x0, y0, fp((2 * n : U32), 0, 0, x0, y0, m))

@unsafe
def run.first2(+n: U32, al: Array<U32>, +x0: F32, +y0: F32, r: M & U32) -> String:
  (m, +c) = r
  run.nn(n, b.nn(1, B{rip_and_tent(c, 0, x0, y0, m), X{al, Pts{Array.new(F32, 0n, 0.0), Array.new(F32, 0n, 0.0)}, Array.new(U32, 0n, 0), Array.new(U32, 0n, 0), Array.new(U32, 0n, 0), Array.new(U32, 0n, 0), Array.new(U32, depth(n), 0), Array.new(U32, 0n, 0), Array.new(U32, 0n, 0), Array.new(U32, 0n, 0)}}))

@unsafe
def run.mesh(+n: U32, p: Pts) -> String:
  +nv = (n + 10 : U32)
  +nt = (2 * n + 8 : U32)
  tov = pfor(~Array<U32>, ~U32, ~a.split, ~a.join, ~tov.body, n, 5000, 0, nv, Array.new(U32, depth(nv), 0))
  tri = pfor(~Array<U32>, ~TE, ~a.split, ~a.join, ~tri.body, TE{n, True{}}, 5000, 0, nt, pfor(~Array<U32>, ~TE, ~a.split, ~a.join, ~tri.body, TE{n, False{}}, 5000, 0, nt, Array.new(U32, depth((8 * nt : U32)), 0)))
  res = pfor(~Array<U32>, ~U32, ~a.split, ~a.join, ~fill.body, 1, 10000, 0, nv, Array.new(U32, depth(nv), 0))
  al = pfor(~Array<U32>, ~U32, ~a.split, ~a.join, ~fill.body, 0, 5000, 0, n, Array.new(U32, depth(n), 0))
  run.first(n, al, m.pt(0, M{p, tri, tov, res}))

@unsafe
def run.bnd3(+n: U32, a: Pts, b: Pts, r: At) -> String:
  At{c, +x0, +y0} = r
  +nb = (1 + (n - 1) / 5000 : U32)
  run.mesh(n, boundary(n, pred(~Pts, ~BE, ~Pt, ~pts.fork, ~bnd.leaf, ~pt.min, BE{n, False{}, x0, y0}, 0, nb, a), pred(~Pts, ~BE, ~Pt, ~pts.fork, ~bnd.leaf, ~pt.max, BE{n, True{}, x0, y0}, 0, nb, b), c))

@unsafe
def run.bnd2(+n: U32, a: Pts, f: Pts & Pts) -> String:
  (b, c) = f
  run.bnd3(n, a, b, at(0, c))

@unsafe
def run.bnd(+n: U32, f: Pts & Pts) -> String:
  (a, b) = f
  run.bnd2(n, a, pts.fork(b))

@unsafe
def run(+n: U32) -> String:
  run.bnd(n, pts.fork(gen(0, n, Pts{Array.new(F32, depth((n + 10 : U32)), 0.0), Array.new(F32, depth((n + 10 : U32)), 0.0)})))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    IO.print(run(U32.from_nat(Nat.mul(1000000n, List.length(&1, String, args)))))
