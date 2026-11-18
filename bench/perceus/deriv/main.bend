import Base

type Expr is Data:
  Val{value: U32}
  Var{name: String}
  Add{l: Expr, r: Expr}
  Mul{l: Expr, r: Expr}
  Pow{l: Expr, r: Expr}
  Ln{e: Expr}

def pown(+a: U32, b: Nat) -> U32:
  match b:
    case 0n:
      1
    case 1n+p:
      U32.mul(a, pown(a, p))

@unsafe def add(n0: Expr, m0: Expr) -> Expr:
  match n0 m0:
    case Val{n} Val{m}:
      Val{U32.add(n, m)}
    case Val{0} f:
      f
    case f Val{0}:
      f
    case f Val{n}:
      add(Val{n}, f)
    case Val{n} Add{Val{m}, f}:
      add(Val{U32.add(n, m)}, f)
    case f Add{Val{n}, g}:
      add(Val{n}, add(f, g))
    case Add{f, g} h:
      add(f, add(g, h))
    case f g:
      Add{f, g}

@unsafe def mul(n0: Expr, m0: Expr) -> Expr:
  match n0 m0:
    case Val{n} Val{m}:
      Val{U32.mul(n, m)}
    case Val{0} _:
      Val{0}
    case _ Val{0}:
      Val{0}
    case Val{1} f:
      f
    case f Val{1}:
      f
    case f Val{n}:
      mul(Val{n}, f)
    case Val{n} Mul{Val{m}, f}:
      mul(Val{U32.mul(n, m)}, f)
    case f Mul{Val{n}, g}:
      mul(Val{n}, mul(f, g))
    case Mul{f, g} h:
      mul(f, mul(g, h))
    case f g:
      Mul{f, g}

def powr(m0: Expr, n0: Expr) -> Expr:
  match m0 n0:
    case Val{m} Val{n}:
      Val{pown(m, U32.to_nat(n))}
    case _ Val{0}:
      Val{1}
    case f Val{1}:
      f
    case Val{0} _:
      Val{0}
    case f g:
      Pow{f, g}

def ln(n: Expr) -> Expr:
  match n:
    case Val{1}:
      Val{0}
    case f:
      Ln{f}

def d.var(same: Bool) -> Expr:
  match same:
    case True{}:
      Val{1}
    case False{}:
      Val{0}

def d(+x: String, e: Expr) -> Expr:
  match e:
    case Val{_}:
      Val{0}
    case Var{y}:
      d.var(String.eq(x, y))
    case Add{f, g}:
      add(d(x, f), d(x, g))
    case Mul{+f, +g}:
      add(mul(f, d(x, g)), mul(g, d(x, f)))
    case Pow{+f, +g}:
      mul(powr(f, g), add(mul(mul(g, d(x, f)), powr(f, Val{4294967295})), mul(ln(f), d(x, g))))
    case Ln{+f}:
      mul(d(x, f), powr(f, Val{4294967295}))

def count(e: Expr) -> U32:
  match e:
    case Val{_}:
      1
    case Var{_}:
      1
    case Add{f, g}:
      U32.add(count(f), count(g))
    case Mul{f, g}:
      U32.add(count(f), count(g))
    case Pow{f, g}:
      U32.add(count(f), count(g))
    case Ln{f}:
      count(f)

def nest_aux(~f: U32 -> Expr -> IO(Expr), +n: Nat, +s: U32, x: Expr) -> IO(Expr):
  match n:
    case 0n:
      IO.pure(Expr, x)
    case 1n+p:
      do IO<Expr>:
        y : Expr <- f(U32.sub(s, U32.inc(U32.from_nat(p))), x)
        nest_aux(~f, p, s, y)

def nest(~f: U32 -> Expr -> IO(Expr), +n: Nat, e: Expr) -> IO(Expr):
  nest_aux(~f, n, U32.from_nat(n), e)

def deriv(i: U32, f: Expr) -> IO(Expr):
  do IO<Expr>:
    +d : Expr = d("x", f)
    Unit <- IO.print(U32.show(U32.inc(i)) ++ " count: " ++ U32.show(count(d)))
    return d

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    n : Nat = Nat.mul(10n, List.length(&1, String, args))
    +x : Expr = Var{"x"}
    f : Expr = powr(x, x)
    r : Expr <- nest(~deriv, n, f)
    IO.print("done")
