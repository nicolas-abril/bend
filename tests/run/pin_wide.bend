# A record parameter of twelve words or more, words alone, that every call
# inside a cycle of defs passes back as it is goes as one borrowed box
# inside the cycle: a call from outside hands its words to the def, whose
# first call into the cycle boxes them and drops the box after, and the
# cycle's calls, frames and forks move one word. Here: a walk that keeps the
# record over its first call (walk), entered at depths 0 and 1 too
# (shallow), the same forked (pwalk), a record of two records and a tag
# (deep), a tail loop that hands its record to walk (loop), a record used
# again after the call that took it, then handed to a tail call (again), a
# constant record (konst), a record built in a tail call (tail), records
# built in a fork (split), a fork whose second call is the first into the
# cycle (fan), a recursion that also matches its record at every level
# (peek), two defs that call each other (ping, pong). It stays
# words where a callee stores it in a list (keep), where a self call changes
# it (drift) and where one of two defs that call each other changes it
# (zig, zag). Counts come from the argument list, so no call is unrolled.
# Every line is the same at any thread count.
import Base

type Cfg is Data:
  Cfg{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32, i: U32, j: U32, k: U32, m: U32, n: Nat}

type Mode is Data:
  Add{}
  Mul{}
  Xor{}

type Two is Data:
  Two{m: Mode, lo: Cfg, hi: Cfg}

def len(xs: List<String>, acc: Nat) -> Nat:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      len(t, 1n+acc)

def mix(r: Cfg, +x: U32) -> U32:
  match r:
    case Cfg{a, b, c, d, e, f, g, h, i, j, k, m, n}:
      U32.add(U32.xor(U32.mul(x, a), U32.add(b, h)),
        U32.mul(U32.xor(x, d), U32.add(U32.from_nat(n), U32.xor(f, U32.add(g, U32.xor(i, U32.add(j, U32.mul(k, m))))))))

def mk(+x: U32, +n: Nat) -> Cfg:
  Cfg{x, U32.add(x, 1), U32.mul(x, 3), 4, 5, U32.xor(x, 6), 7, 8, U32.add(x, 9), 10, U32.mul(x, 11), 12, n}

def walk(+d: Nat, +r: Cfg, +x: U32) -> U32:
  match d:
    case 0n:
      mix(r, x)
    case 1n+e:
      +l = walk(e, r, U32.add(x, 1))
      U32.add(l, walk(e, r, U32.mul(l, 3)))

def pwalk(+d: Nat, +r: Cfg, +x: U32) -> U32:
  match d:
    case 0n:
      mix(r, x)
    case 1n+e:
      l s = pwalk(e, r, U32.add(x, 1)) pwalk(e, r, U32.mul(x, 3))
      U32.xor(l, U32.add(s, 1))

def two(t: Two, +x: U32) -> U32:
  match t:
    case Two{m, lo, hi}:
      match m:
        case Add{}:
          U32.add(mix(lo, x), mix(hi, x))
        case Mul{}:
          U32.mul(mix(lo, x), mix(hi, x))
        case Xor{}:
          U32.xor(mix(lo, x), mix(hi, x))

def deep(+d: Nat, +t: Two, +x: U32) -> U32:
  match d:
    case 0n:
      two(t, x)
    case 1n+e:
      +l = deep(e, t, U32.add(x, 5))
      U32.xor(l, deep(e, t, U32.add(l, 1)))

def loop(+n: Nat, +k: Nat, +r: Cfg, +acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+m:
      loop(m, k, r, walk(k, r, acc))

def again(+z: Nat, +x: U32) -> U32:
  +r = mk(x, Nat.add(z, 2n))
  +a = walk(Nat.add(z, 6n), r, x)
  +b = mix(r, a)
  walk(Nat.add(z, 5n), r, b)

def konst(+z: Nat) -> U32:
  walk(Nat.add(z, 7n), Cfg{13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1n}, 11)

def tail(+z: Nat, +x: U32) -> U32:
  walk(Nat.add(z, 6n), mk(U32.add(x, 2), z), x)

def split(+z: Nat, +x: U32) -> U32:
  l s = pwalk(Nat.add(z, 6n), mk(x, z), 1) pwalk(Nat.add(z, 5n), mk(U32.add(x, 1), 3n), 2)
  U32.add(l, s)

def fan(+d: Nat, +r: Cfg, +x: U32) -> U32:
  match d:
    case 0n:
      mix(r, x)
    case 1n+e:
      l s = walk(e, mk(x, 1n), x) fan(e, r, U32.add(x, 1))
      U32.add(l, s)

def peek(+d: Nat, +r: Cfg, +x: U32) -> U32:
  match d:
    case 0n:
      x
    case 1n+e:
      +y = U32.add(mix(r, x), 1)
      +l = peek(e, r, y)
      U32.xor(l, peek(e, r, U32.add(l, x)))

def keep(+d: Nat, +r: Cfg, acc: List<Cfg>) -> List<Cfg>:
  match d:
    case 0n:
      r <> acc
    case 1n+e:
      keep(e, r, keep(e, r, acc))

def sumc(xs: List<Cfg>, +i: U32, +acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      sumc(t, U32.add(i, 1), U32.add(acc, mix(h, i)))

def bump(r: Cfg) -> Cfg:
  match r:
    case Cfg{a, b, c, d, e, f, g, h, i, j, k, m, n}:
      Cfg{b, U32.add(a, 1), c, d, e, f, g, h, i, j, k, m, n}

def drift(+d: Nat, +r: Cfg, +x: U32) -> U32:
  match d:
    case 0n:
      mix(r, x)
    case 1n+e:
      +l = drift(e, r, U32.add(x, 1))
      U32.add(l, drift(e, bump(r), l))

law ping:
  for +d: Nat
  for +r: Cfg
  for +x: U32
  U32

law pong:
  for +d: Nat
  for +r: Cfg
  for +x: U32
  U32

@unsafe
def ping(d, r, x):
  match d:
    case 0n:
      mix(r, x)
    case 1n+e:
      +l = pong(e, r, x)
      U32.add(l, ping(e, r, U32.add(l, 1)))

@unsafe
def pong(d, r, x):
  match d:
    case 0n:
      x
    case 1n+e:
      ping(e, r, U32.mul(x, 5))

law zig:
  for +d: Nat
  for +r: Cfg
  for +x: U32
  U32

law zag:
  for +d: Nat
  for +r: Cfg
  for +x: U32
  U32

@unsafe
def zig(d, r, x):
  match d:
    case 0n:
      mix(r, x)
    case 1n+e:
      +l = zag(e, r, x)
      U32.add(l, zig(e, r, U32.add(l, 1)))

@unsafe
def zag(d, r, x):
  match d:
    case 0n:
      x
    case 1n+e:
      zig(e, bump(r), U32.mul(x, 5))

def shallow(+z: Nat) -> U32:
  U32.add(walk(Nat.sub(z, 1n), mk(47, 1n), 12), walk(z, mk(53, 2n), 13))

def go(+z: Nat) -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.print(U32.show(shallow(z)))
    Unit <- IO.print(U32.show(walk(Nat.add(z, 10n), mk(3, 9n), 1)))
    Unit <- IO.print(U32.show(pwalk(Nat.add(z, 10n), mk(5, z), 2)))
    Unit <- IO.print(U32.show(deep(Nat.add(z, 8n),
      Two{Xor{}, mk(7, 1n), mk(11, 2n)}, 3)))
    Unit <- IO.print(U32.show(loop(Nat.add(z, 20000n), Nat.add(z, 2n),
      mk(13, 4n), 4)))
    Unit <- IO.print(U32.show(again(z, 17)))
    Unit <- IO.print(U32.show(konst(z)))
    Unit <- IO.print(U32.show(tail(z, 19)))
    Unit <- IO.print(U32.show(split(z, 23)))
    Unit <- IO.print(U32.show(fan(Nat.add(z, 6n), mk(59, 3n), 14)))
    Unit <- IO.print(U32.show(peek(Nat.add(z, 9n), mk(29, 5n), 6)))
    Unit <- IO.print(U32.show(sumc(keep(Nat.add(z, 5n), mk(31, 6n), []), 0, 0)))
    Unit <- IO.print(U32.show(drift(Nat.add(z, 9n), mk(37, 7n), 8)))
    Unit <- IO.print(U32.show(ping(Nat.add(z, 9n), mk(41, 8n), 9)))
    IO.print(U32.show(zig(Nat.add(z, 9n), mk(43, 9n), 10)))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    go(len(args, 0n))

#|1495780138
#|2350442392
#|176632447
#|2028662630
#|2378174020
#|490190400
#|286823240
#|2196707372
#|10168862
#|3037582279
#|3939938248
#|8420832
#|2729430620
#|1182788124
#|1634144345
