# stored folds: a tree read only by one fold, on every path, carries the
# fold's result instead. sum1 and cnt2 change: their trees are never built,
# each node is its arm of the fold (mk2's two equal subtrees computed once).
# The others are folded on some path only, so their trees stay: a fold on a
# path not taken (pick3), behind a match in the fold's arm (prod4) or a
# lambda its arm passes on (prod8), of a tree
# a let leaves unread (keep5), from a tree passed through generic code
# (via_gen6), and a tree matched by two defs (two7). Each would overflow a
# Nat if its fold ran where the program does not run it.
# Arguments are read at run time, so no call is evaluated by the compiler.
import Base

type T1 is Data:
  Lf1{v: U32}
  Nd1{l: T1, r: T1}

def mk1(+n: Nat, +x: U32) -> T1:
  match n:
    case 0n:
      Lf1{x}
    case 1n+p:
      Nd1{mk1(p, U32.add(x, 1)), mk1(p, U32.mul(x, 3))}

def sum1(t: T1) -> U32:
  match t:
    case Lf1{v}:
      v
    case Nd1{l, r}:
      U32.add(sum1(l), U32.mul(sum1(r), 2))

type T2 is Data:
  Lf2{}
  Nd2{l: T2, r: T2}

def mk2(+n: Nat) -> T2:
  match n:
    case 0n:
      Lf2{}
    case 1n+p:
      Nd2{mk2(p), mk2(p)}

def cnt2(t: T2) -> Nat:
  match t:
    case Lf2{}:
      1n
    case Nd2{l, r}:
      Nat.add(cnt2(l), cnt2(r))

type T3 is Data:
  Lf3{v: Nat}
  Nd3{l: T3, r: T3}

def mk3(+n: Nat, +x: Nat) -> T3:
  match n:
    case 0n:
      Lf3{x}
    case 1n+p:
      Nd3{mk3(p, x), mk3(p, x)}

def prod3(t: T3) -> Nat:
  match t:
    case Lf3{v}:
      v
    case Nd3{l, r}:
      Nat.mul(prod3(l), prod3(r))

def pick3(t: T3, c: Bool) -> Nat:
  match c:
    case True{}:
      prod3(t)
    case False{}:
      0n

type T4 is Data:
  Lf4{v: Nat}
  Nd4{c: Bool, l: T4, r: T4}

def mk4(+n: Nat, +x: Nat, c: Bool) -> T4:
  match n:
    case 0n:
      Lf4{x}
    case 1n+p:
      Nd4{c, mk4(p, x, True{}), mk4(p, x, True{})}

def prod4(t: T4) -> Nat:
  match t:
    case Lf4{v}:
      v
    case Nd4{c, l, r}:
      match c:
        case True{}:
          Nat.mul(prod4(l), prod4(r))
        case False{}:
          0n

type T5 is Data:
  Lf5{v: Nat}
  Nd5{l: T5, r: T5}

def mk5(+n: Nat, +x: Nat) -> T5:
  match n:
    case 0n:
      Lf5{x}
    case 1n+p:
      Nd5{mk5(p, x), mk5(p, x)}

def prod5(t: T5) -> Nat:
  match t:
    case Lf5{v}:
      v
    case Nd5{l, r}:
      Nat.mul(prod5(l), prod5(r))

def keep5(+n: Nat) -> Nat:
  t = mk5(Nat.mul(n, 6n), 1000n)
  u = mk5(n, 2n)
  prod5(u)

type T6 is Data:
  Lf6{v: Nat}
  Nd6{l: T6, r: T6}

def mk6(+n: Nat, +x: Nat) -> T6:
  match n:
    case 0n:
      Lf6{x}
    case 1n+p:
      Nd6{mk6(p, x), mk6(p, x)}

def prod6(t: T6) -> Nat:
  match t:
    case Lf6{v}:
      v
    case Nd6{l, r}:
      Nat.mul(prod6(l), prod6(r))

def via_gen6(t: T6) -> Nat:
  prod6(Maybe.default(&2, T6, Some{t}, Lf6{3n}))

type T7 is Data:
  Lf7{v: Nat}
  Nd7{l: T7, r: T7}

def mk7(+n: Nat, +x: Nat) -> T7:
  match n:
    case 0n:
      Lf7{x}
    case 1n+p:
      Nd7{mk7(p, x), mk7(p, x)}

def prod7(t: T7) -> Nat:
  match t:
    case Lf7{v}:
      v
    case Nd7{l, r}:
      Nat.mul(prod7(l), prod7(r))

def leaves7(t: T7) -> Nat:
  match t:
    case Lf7{v}:
      1n
    case Nd7{l, r}:
      Nat.add(leaves7(l), leaves7(r))

def two7(t: T7, c: Bool) -> Nat:
  match c:
    case True{}:
      prod7(t)
    case False{}:
      leaves7(t)

type T8 is Data:
  Lf8{v: Nat}
  Nd8{c: Bool, l: T8, r: T8}

def mk8(+n: Nat, +x: Nat, +c: Bool) -> T8:
  match n:
    case 0n:
      Lf8{x}
    case 1n+p:
      Nd8{c, mk8(p, x, True{}), mk8(p, x, c)}

def app8(g: Nat -> Nat, c: Bool) -> Nat:
  match c:
    case True{}:
      g(0n)
    case False{}:
      1n

def prod8(t: T8) -> Nat:
  match t:
    case Lf8{v}:
      v
    case Nd8{c, l, r}:
      Nat.mul(prod8(r), app8(x => prod8(l), c))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    +one : Nat = List.length(&1, String, args)
    +u : U32 = U32.from_nat(one)
    +n : Nat = Nat.mul(5n, one)
    IO.print(U32.show(sum1(mk1(n, u))))
    IO.print(Nat.show(cnt2(mk2(Nat.mul(n, 4n)))))
    IO.print(Nat.show(pick3(mk3(n, 1000n), Nat.is_eq(one, 2n))))
    IO.print(Nat.show(prod4(mk4(n, 1000n, Nat.is_eq(one, 2n)))))
    IO.print(Nat.show(keep5(one)))
    IO.print(Nat.show(via_gen6(mk6(Nat.sub(n, 4n), 2n))))
    IO.print(Nat.show(two7(mk7(n, 1000n), Nat.is_eq(one, 2n))))
    IO.print(Nat.show(prod8(mk8(n, 1000n, Nat.is_eq(one, 2n)))))

#|20948
#|1048576
#|0
#|0
#|4
#|4
#|32
#|1000
