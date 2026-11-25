# Parameters of words alone that every call inside a cycle of defs passes
# back as they are, eight words or more in all where the cycle forks (twenty
# where it does not), go as one node inside the cycle: a call from outside
# hands the words to the def, whose first call into the cycle builds the
# node and frees it after, and the cycle's calls, frames and forks move one
# word. Here: twenty words down a walk (walk), entered at depths 0 and 1 too
# (shallow), twelve down a fork (pwalk), a Nat and eight words down a fork
# and into a loop (nine), two defs that call each other and pass the words
# in another order (ga, gb), a record and words in one group (mixr), a flag
# in the group that the walk matches (flag), a closure that takes grouped
# words (clo) and closures applied after the cycle returns (mkf), a group
# beside a pinned record (both), one word a self call changes while the rest
# stay grouped (vary), calls from a tail and from a fork (tail, split), and
# bang calls into a fork and into two defs that call each other. Counts come
# from the argument list, so no call is unrolled. Every line is the same at
# any thread count and on either lane.
import Base

type Small is Data:
  Small{p: U32, q: U32, r: U32, s: U32, t: U32, u: U32}

type Cfg is Data:
  Cfg{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32, i: U32, j: U32, k: U32, m: U32, n: Nat}

def len(xs: List<String>, acc: Nat) -> Nat:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      len(t, 1n+acc)

def mix(+x: U32, +y: U32, +z: U32) -> U32:
  U32.add(U32.xor(U32.mul(x, 2654435761), y), U32.mul(z, 40503))

def walk(+d: Nat, +a0: U32, +a1: U32, +a2: U32, +a3: U32, +a4: U32,
         +a5: U32, +a6: U32, +a7: U32, +a8: U32, +a9: U32, +b0: U32,
         +b1: U32, +b2: U32, +b3: U32, +b4: U32, +b5: U32, +b6: U32,
         +b7: U32, +b8: U32, +b9: U32, +x: U32) -> U32:
  match d:
    case 0n:
      mix(x, U32.add(a0, b9), U32.xor(a5, b4))
    case 1n+e:
      +l = walk(e, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, U32.add(x, a1))
      U32.add(l, walk(e, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, U32.mul(l, b2)))

def run(+z: Nat, +d: Nat, +v: U32) -> U32:
  walk(d, v, U32.add(v, 1), 2, 3, U32.mul(v, 5), 5, 6, 7, 8, 9, 10, 11, 12,
    U32.xor(v, 13), 14, 15, 16, 17, 18, U32.from_nat(z), 1)

def shallow(+z: Nat) -> U32:
  U32.add(run(z, Nat.sub(z, 1n), 21), run(z, z, 22))

def pwalk(+d: Nat, +a0: U32, +a1: U32, +a2: U32, +a3: U32, +a4: U32,
          +a5: U32, +a6: U32, +a7: U32, +a8: U32, +a9: U32, +a10: U32,
          +a11: U32, +x: U32) -> U32:
  match d:
    case 0n:
      mix(x, U32.add(a0, a11), U32.xor(a3, a7))
    case 1n+e:
      l r = pwalk(e, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, U32.add(x, a1)) pwalk(e, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, U32.mul(x, a2))
      U32.xor(l, U32.add(r, a4))

def spin8(+n: Nat, +k0: U32, +k1: U32, +k2: U32, +k3: U32, +k4: U32,
          +k5: U32, +k6: U32, +k7: U32, +acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+m:
      spin8(m, k0, k1, k2, k3, k4, k5, k6, k7, mix(acc, U32.xor(k0, k6), U32.add(k3, k7)))

def nine(+d: Nat, +i: U32, +n: Nat, +k0: U32, +k1: U32, +k2: U32, +k3: U32,
         +k4: U32, +k5: U32, +k6: U32, +k7: U32) -> U32:
  match d:
    case 0n:
      spin8(n, k0, k1, k2, k3, k4, k5, k6, k7, i)
    case 1n+e:
      a b = nine(e, i, n, k0, k1, k2, k3, k4, k5, k6, k7) nine(e, U32.add(i, U32.shln(1, e)), n, k0, k1, k2, k3, k4, k5, k6, k7)
      U32.add(a, U32.mul(b, k1))

law ga:
  for +d: Nat
  for +a0: U32
  for +a1: U32
  for +a2: U32
  for +a3: U32
  for +a4: U32
  for +a5: U32
  for +a6: U32
  for +a7: U32
  for +a8: U32
  for +a9: U32
  for +a10: U32
  for +a11: U32
  for +x: U32
  U32

law gb:
  for +x: U32
  for +b11: U32
  for +b10: U32
  for +b9: U32
  for +b8: U32
  for +b7: U32
  for +b6: U32
  for +b5: U32
  for +b4: U32
  for +b3: U32
  for +b2: U32
  for +b1: U32
  for +b0: U32
  for +d: Nat
  U32

@unsafe
def ga(d, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, x):
  match d:
    case 0n:
      mix(x, a0, a11)
    case 1n+e:
      l r = gb(U32.add(x, 1), a11, a10, a9, a8, a7, a6, a5, a4, a3, a2, a1, a0, e) ga(e, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, U32.mul(x, 3))
      U32.add(l, r)

@unsafe
def gb(x, b11, b10, b9, b8, b7, b6, b5, b4, b3, b2, b1, b0, d):
  match d:
    case 0n:
      mix(x, b2, b9)
    case 1n+e:
      l r = ga(e, b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, U32.add(x, b5)) gb(U32.mul(x, 7), b11, b10, b9, b8, b7, b6, b5, b4, b3, b2, b1, b0, e)
      U32.xor(l, r)

def small(s: Small, +x: U32) -> U32:
  match s:
    case Small{p, q, r, s, t, u}:
      mix(U32.add(x, p), U32.xor(q, r), U32.add(s, U32.mul(t, u)))

def mixr(+d: Nat, +s: Small, +a0: U32, +a1: U32, +a2: U32, +a3: U32,
         +a4: U32, +a5: U32, +x: U32) -> U32:
  match d:
    case 0n:
      U32.add(small(s, x), mix(a0, a3, a5))
    case 1n+e:
      l r = mixr(e, s, a0, a1, a2, a3, a4, a5, U32.add(x, a2)) mixr(e, s, a0, a1, a2, a3, a4, a5, U32.mul(x, a4))
      U32.add(l, U32.mul(r, 3))

def flag(+d: Nat, +f: Bool, +a0: U32, +a1: U32, +a2: U32, +a3: U32,
         +a4: U32, +a5: U32, +a6: U32, +a7: U32, +a8: U32, +a9: U32,
         +a10: U32, +x: U32) -> U32:
  match d:
    case 0n:
      match f:
        case True{}:
          mix(x, a0, a10)
        case False{}:
          mix(a5, x, a9)
    case 1n+e:
      l r = flag(e, f, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, U32.add(x, 1)) flag(e, f, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, U32.add(x, 2))
      U32.xor(l, r)

def app(f: U32 -> U32, +x: U32) -> U32:
  f(x)

def clo(+d: Nat, +a0: U32, +a1: U32, +a2: U32, +a3: U32, +a4: U32,
        +a5: U32, +a6: U32, +a7: U32, +a8: U32, +a9: U32, +a10: U32,
        +a11: U32, +x: U32) -> U32:
  match d:
    case 0n:
      app(y => mix(y, a3, a11), x)
    case 1n+e:
      l r = clo(e, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, U32.add(x, a0)) clo(e, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, U32.add(x, a6))
      U32.add(l, r)

def mkf(+d: Nat, +a0: U32, +a1: U32, +a2: U32, +a3: U32, +a4: U32,
        +a5: U32, +a6: U32, +a7: U32, +a8: U32, +a9: U32, +a10: U32,
        +a11: U32) -> U32 -> U32:
  match d:
    case 0n:
      y => mix(y, a3, a11)
    case 1n+e:
      l r = mkf(e, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11) mkf(e, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11)
      +y => U32.add(l(y), r(U32.add(y, a5)))

def cfg(r: Cfg, +x: U32) -> U32:
  match r:
    case Cfg{a, b, c, d, e, f, g, h, i, j, k, m, n}:
      mix(U32.add(x, a), U32.xor(m, U32.from_nat(n)), U32.add(f, k))

def both(+d: Nat, +r: Cfg, +a0: U32, +a1: U32, +a2: U32, +a3: U32,
         +a4: U32, +a5: U32, +a6: U32, +a7: U32, +a8: U32, +a9: U32,
         +a10: U32, +a11: U32, +x: U32) -> U32:
  match d:
    case 0n:
      U32.xor(cfg(r, x), mix(a0, a6, a11))
    case 1n+e:
      l s = both(e, r, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, U32.add(x, a1)) both(e, r, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, U32.add(x, a9))
      U32.add(l, s)

def vary(+d: Nat, +a0: U32, +a1: U32, +a2: U32, +a3: U32, +a4: U32,
         +a5: U32, +a6: U32, +a7: U32, +a8: U32, +a9: U32, +a10: U32,
         +a11: U32, +w: U32, +x: U32) -> U32:
  match d:
    case 0n:
      mix(x, U32.add(a0, w), a11)
    case 1n+e:
      l r = vary(e, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, U32.add(w, 1), U32.add(x, a2)) vary(e, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, w, U32.mul(x, a8))
      U32.add(l, r)

def tail(+z: Nat, +v: U32) -> U32:
  pwalk(Nat.add(z, 5n), v, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13)

def split(+z: Nat, +v: U32) -> U32:
  l r = pwalk(Nat.add(z, 5n), v, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13) pwalk(Nat.add(z, 4n), 1, v, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13)
  U32.add(l, r)

def mk(+x: U32, +n: Nat) -> Cfg:
  Cfg{x, U32.add(x, 1), U32.mul(x, 3), 4, 5, U32.xor(x, 6), 7, 8, U32.add(x, 9), 10, U32.mul(x, 11), 12, n}

def go(+z: Nat) -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.print(U32.show(run(z, Nat.add(z, 9n), 3)))
    Unit <- IO.print(U32.show(shallow(z)))
    Unit <- IO.print(U32.show(pwalk(Nat.add(z, 9n), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13)))
    Unit <- IO.print(U32.show(nine(Nat.add(z, 9n), 0, Nat.add(z, 4n), 1, 2, 3, 4, 5, 6, 7, 8)))
    Unit <- IO.print(U32.show(ga(Nat.add(z, 8n), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13)))
    Unit <- IO.print(U32.show(mixr(Nat.add(z, 8n), Small{1, 2, 3, 4, 5, 6}, 7, 8, 9, 10, 11, 12, 13)))
    Unit <- IO.print(U32.show(U32.add(flag(Nat.add(z, 7n), True{}, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12), flag(Nat.add(z, 6n), False{}, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13))))
    Unit <- IO.print(U32.show(clo(Nat.add(z, 7n), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13)))
    Unit <- IO.print(U32.show(app(mkf(Nat.add(z, 4n), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12), 13)))
    Unit <- IO.print(U32.show(both(Nat.add(z, 7n), mk(5, 3n), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13)))
    Unit <- IO.print(U32.show(vary(Nat.add(z, 8n), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14)))
    Unit <- IO.print(U32.show(tail(z, 31)))
    Unit <- IO.print(U32.show(split(z, 37)))
    Unit <- IO.print(U32.show(pwalk!(Nat.add(z, 12n), 3, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 41)))
    IO.print(U32.show(ga!(Nat.add(z, 10n), 3, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 43)))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    go(len(args, 0n))

#|472072381
#|118025556
#|811794875
#|993149276
#|1791740736
#|736740096
#|306468288
#|3352211648
#|3273080320
#|3825020032
#|1011159040
#|594903963
#|3449828574
#|2099198843
#|3080122624
