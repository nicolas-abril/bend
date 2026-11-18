import Base

type Expr is Data:
  Var{name: U32}
  Val{value: U32}
  Add{l: Expr, r: Expr}
  Mul{l: Expr, r: Expr}

def leaf(v: U32, z: Bool) -> Expr:
  match z:
    case True{}:
      Var{1}
    case False{}:
      Val{v}

def dec0(v: U32, z: Bool) -> U32:
  match z:
    case True{}:
      0
    case False{}:
      U32.sub(v, 1)

def mk_expr(+n: Nat, +v: U32) -> Expr:
  match n:
    case 0n:
      leaf(v, U32.is_zero(v))
    case 1n+p:
      Add{mk_expr(p, U32.inc(v)), mk_expr(p, dec0(v, U32.is_zero(v)))}

def append_add(e0: Expr, e3: Expr) -> Expr:
  match e0:
    case Add{e1, e2}:
      Add{e1, append_add(e2, e3)}
    case e:
      Add{e, e3}

def append_mul(e0: Expr, e3: Expr) -> Expr:
  match e0:
    case Mul{e1, e2}:
      Mul{e1, append_mul(e2, e3)}
    case e:
      Mul{e, e3}

def reassoc(e: Expr) -> Expr:
  match e:
    case Add{e1, e2}:
      append_add(reassoc(e1), reassoc(e2))
    case Mul{e1, e2}:
      append_mul(reassoc(e1), reassoc(e2))
    case e0:
      e0

def cfold.add(e1: Expr, e2: Expr) -> Expr:
  match e1 e2:
    case Val{a} Val{b}:
      Val{U32.add(a, b)}
    case Val{a} Add{f, Val{b}}:
      Add{Val{U32.add(a, b)}, f}
    case Val{a} Add{Val{b}, f}:
      Add{Val{U32.add(a, b)}, f}
    case x y:
      Add{x, y}

def cfold.mul(e1: Expr, e2: Expr) -> Expr:
  match e1 e2:
    case Val{a} Val{b}:
      Val{U32.mul(a, b)}
    case Val{a} Mul{f, Val{b}}:
      Mul{Val{U32.mul(a, b)}, f}
    case Val{a} Mul{Val{b}, f}:
      Mul{Val{U32.mul(a, b)}, f}
    case x y:
      Mul{x, y}

def cfold(e: Expr) -> Expr:
  match e:
    case Add{e1, e2}:
      cfold.add(cfold(e1), cfold(e2))
    case Mul{e1, e2}:
      cfold.mul(cfold(e1), cfold(e2))
    case e0:
      e0

def eval(e: Expr) -> U32:
  match e:
    case Var{_}:
      0
    case Val{v}:
      v
    case Add{l, r}:
      U32.add(eval(l), eval(r))
    case Mul{l, r}:
      U32.mul(eval(l), eval(r))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    +one : Nat = List.length(&1, String, args)
    +e : Expr = mk_expr(Nat.mul(20n, one), U32.from_nat(one))
    v1 : U32 = eval(e)
    v2 : U32 = eval(cfold(reassoc(e)))
    Unit <- IO.print(U32.show(v1))
    IO.print(U32.show(v2))
