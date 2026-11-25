# A record parameter that a recursion passes back as it is goes as one
# borrowed box on the device too: a walk that keeps it over its first call
# (walk), the same forked (pwalk), and a record of two records and a tag
# (deep), each run by a bang call that boxes the record it is given. Counts
# come from the argument list, so no call is unrolled. Every line is the
# same at any thread count and on either lane.
import Base

type Cfg is Data:
  Cfg{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32, n: Nat}

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
    case Cfg{a, b, c, d, e, f, g, h, n}:
      U32.add(U32.xor(U32.mul(x, a), U32.add(b, h)),
        U32.mul(U32.xor(x, d), U32.add(U32.from_nat(n), U32.xor(f, g))))

def mk(+x: U32, +n: Nat) -> Cfg:
  Cfg{x, U32.add(x, 1), U32.mul(x, 3), 4, 5, U32.xor(x, 6), 7, 8, n}

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
      l s = deep(e, t, U32.add(x, 5)) deep(e, t, U32.mul(x, 7))
      U32.add(l, s)

def run(+z: Nat) -> U32:
  l s = pwalk(Nat.add(z, 12n), mk(5, z), 2) deep(Nat.add(z, 11n),
    Two{Mul{}, mk(7, 1n), mk(11, 2n)}, 3)
  U32.xor(l, U32.add(s, walk(Nat.add(z, 10n), mk(3, 9n), 1)))

def go(+z: Nat) -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.print(U32.show(run!(z)))
    Unit <- IO.print(U32.show(pwalk!(Nat.add(z, 13n), mk(13, 4n), 4)))
    IO.print(U32.show(walk!(Nat.add(z, 9n), mk(17, 5n), 6)))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    go(len(args, 0n))
