# A tail call into a def that calls itself twice on one path runs that
# def's returning arms where the call is, and returns from there as the def
# would. Such tail calls here: a continuation into its own def (ack, the
# shape of Ackermann; fold, a tree walked with an accumulator), into another
# def (mm into mirror, whose arm builds a node; spans into span, a
# three-word result; flat into fold, from a def's entry), and a fork's
# continuation into a def (pf into tw, run as a task at 8 threads). The rest
# keep their tail calls: a callee whose returning arm drops a parameter
# (shed), a recursion down a list (take). Sizes come from the argument
# list, so nothing is folded. Every line is the same at any thread count.
import Base

type Tree is Data:
  Leaf{a: U32, b: U32}
  Node{l: Tree, r: Tree}

type Span is Data:
  Span{lo: U32, hi: U32, n: U32}

def len(xs: List<String>, acc: Nat) -> Nat:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      len(t, 1n+acc)

def grow(+d: Nat, +i: U32) -> Tree:
  match d:
    case 0n:
      Leaf{i, U32.xor(i, 2654435761)}
    case 1n+p:
      Node{grow(p, U32.add(U32.mul(i, 3), 1)),
        grow(p, U32.add(U32.mul(i, 5), 2))}

def ack(+m: Nat, +n: Nat) -> Nat:
  match m:
    case 0n:
      Nat.add(n, 1n)
    case 1n+mp:
      match n:
        case 0n:
          ack(mp, 1n)
        case 1n+np:
          r = ack(m, np)
          ack(mp, r)

# owns the tree: the returning arm frees the leaf
def fold(t: Tree, +acc: U32) -> U32:
  match t:
    case Leaf{a, b}:
      U32.add(U32.mul(acc, 31), U32.xor(a, b))
    case Node{l, r}:
      fold(r, U32.add(fold(l, acc), 1))

# a tail call from a def's entry
def flat(+k: Nat, t: Tree) -> U32:
  match k:
    case 0n:
      7
    case 1n+p:
      fold(t, U32.from_nat(k))

# the returning arm builds a node
def mirror(t: Tree) -> Tree:
  match t:
    case Leaf{a, b}:
      Leaf{b, U32.add(a, 1)}
    case Node{l, r}:
      Node{mirror(r), mirror(l)}

def mm(+n: Nat, t: Tree) -> Tree:
  match n:
    case 0n:
      t
    case 1n+p:
      u = mm(p, t)
      mirror(u)

def sum(t: Tree) -> U32:
  match t:
    case Leaf{a, b}:
      U32.add(a, U32.mul(b, 3))
    case Node{l, r}:
      U32.add(sum(l), U32.mul(sum(r), 5))

def join(x: Span, y: Span) -> Span:
  match x y:
    case Span{a, b, n} Span{c, d, m}:
      Span{U32.add(a, c), U32.xor(b, d), U32.add(n, m)}

# a three-word result
def span(t: Tree) -> Span:
  match t:
    case Leaf{a, b}:
      Span{a, b, 1}
    case Node{l, r}:
      join(span(l), span(r))

def seed(s: Span) -> Tree:
  match s:
    case Span{a, b, c}:
      grow(Nat.mod(U32.to_nat(a), 3n), U32.xor(b, c))

def spans(+n: Nat, +i: U32) -> Span:
  match n:
    case 0n:
      Span{i, i, 0}
    case 1n+p:
      s = spans(p, U32.add(i, 1))
      span(seed(s))

def tw(+n: Nat, +x: U32) -> U32:
  match n:
    case 0n:
      U32.add(U32.mul(x, 5), 1)
    case 1n+p:
      tw(p, U32.xor(tw(p, x), 3))

# forks, then its continuation tail-calls tw
def pf(+d: Nat, +z: Nat, +i: U32) -> U32:
  match d:
    case 0n:
      tw(Nat.add(z, 2n), i)
    case 1n+e:
      x y = pf(e, z, U32.mul(i, 3)) pf(e, z, U32.add(i, 7))
      tw(U32.to_nat(U32.and(i, 1)), U32.xor(x, y))

def fill(+n: Nat, +x: U32) -> List<U32>:
  match n:
    case 0n:
      []
    case 1n+p:
      Con{x, fill(p, U32.add(U32.mul(x, 7), 3))}

# the returning arm drops the list it was handed: it stays in the callee
def shed(t: Tree, xs: List<U32>) -> U32:
  match t:
    case Leaf{a, b}:
      U32.add(a, b)
    case Node{l, r}:
      U32.add(shed(l, fill(2n, 1)), U32.mul(shed(r, xs), 3))

def sheds(+n: Nat, +i: U32) -> U32:
  match n:
    case 0n:
      i
    case 1n+p:
      +x = sheds(p, U32.add(i, 1))
      shed(Leaf{x, 3}, fill(3n, x))

# a recursion down a list: its tail call keeps its jump
def take(xs: List<U32>, +acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{h, tl}:
      take(tl, U32.add(U32.mul(acc, 3), h))

def takes(+n: Nat, +i: U32) -> U32:
  match n:
    case 0n:
      i
    case 1n+p:
      +x = takes(p, U32.add(i, 1))
      take(fill(2n, x), x)

def show(s: Span) -> U32:
  match s:
    case Span{a, b, c}:
      U32.add(U32.add(a, U32.mul(b, 3)), U32.mul(c, 7))

def go(+z: Nat) -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.print(Nat.show(ack(3n, Nat.add(z, 6n))))
    Unit <- IO.print(Nat.show(ack(2n, Nat.add(z, 3000n))))
    Unit <- IO.print(U32.show(fold(grow(Nat.add(z, 12n), 1), 9)))
    Unit <- IO.print(U32.show(flat(z, grow(4n, 2))))
    Unit <- IO.print(U32.show(flat(Nat.add(z, 3n), grow(Nat.add(z, 9n), 2))))
    Unit <- IO.print(U32.show(flat(Nat.add(z, 1n), Leaf{U32.from_nat(z), 6})))
    Unit <- IO.print(U32.show(sum(mm(Nat.add(z, 7n), grow(Nat.add(z, 6n), 4)))))
    Unit <- IO.print(U32.show(sum(mm(Nat.add(z, 5n), Leaf{3, 4}))))
    Unit <- IO.print(U32.show(show(spans(Nat.add(z, 300n), 5))))
    Unit <- IO.print(U32.show(pf(Nat.add(z, 10n), z, 1)))
    Unit <- IO.print(U32.show(pf(Nat.add(z, 6n), Nat.add(z, 1n), 2)))
    Unit <- IO.print(U32.show(sheds(Nat.add(z, 200n), 1)))
    IO.print(U32.show(takes(Nat.add(z, 200n), 1)))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    go(len(args, 0n))


#|1021
#|6005
#|2776629256
#|3510882304
#|3000664067
#|69
#|1421592832
#|27
#|3668458218
#|3055932649
#|3091693707
#|805
#|3684296913
