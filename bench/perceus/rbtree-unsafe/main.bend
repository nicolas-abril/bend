import Base

type Color is Data:
  Red{}
  Black{}

type Tree is Data:
  Leaf{}
  Node{color: Color, lchild: Tree, key: U32, value: Bool, rchild: Tree}

def balance_left(l: Tree, k: U32, v: Bool, r: Tree) -> Tree:
  match l:
    case Node{_, Node{Red{}, lx, kx, vx, rx}, ky, vy, ry}:
      Node{Red{}, Node{Black{}, lx, kx, vx, rx}, ky, vy, Node{Black{}, ry, k, v, r}}
    case Node{_, ly, ky, vy, Node{Red{}, lx, kx, vx, rx}}:
      Node{Red{}, Node{Black{}, ly, ky, vy, lx}, kx, vx, Node{Black{}, rx, k, v, r}}
    case Node{_, lx, kx, vx, rx}:
      Node{Black{}, Node{Red{}, lx, kx, vx, rx}, k, v, r}
    case Leaf{}:
      Leaf{}

def balance_right(l: Tree, k: U32, v: Bool, r: Tree) -> Tree:
  match r:
    case Node{_, Node{Red{}, lx, kx, vx, rx}, ky, vy, ry}:
      Node{Red{}, Node{Black{}, l, k, v, lx}, kx, vx, Node{Black{}, rx, ky, vy, ry}}
    case Node{_, lx, kx, vx, Node{Red{}, ly, ky, vy, ry}}:
      Node{Red{}, Node{Black{}, l, k, v, lx}, kx, vx, Node{Black{}, ly, ky, vy, ry}}
    case Node{_, lx, kx, vx, rx}:
      Node{Black{}, l, k, v, Node{Red{}, lx, kx, vx, rx}}
    case Leaf{}:
      Leaf{}

def is_red(t: Tree) -> Tree & Bool:
  match t:
    case Node{Red{}, l, k, v, r}:
      (Node{Red{}, l, k, v, r}, True{})
    case t0:
      (t0, False{})

@unsafe def ins(t: Tree, +k: U32, +v: Bool) -> Tree:
  match t:
    case Node{Red{}, l, +kx, vx, r}:
      ins.red(l, kx, vx, r, k, v, U32.cmp(k, kx))
    case Node{Black{}, l, +kx, vx, r}:
      ins.black(l, kx, vx, r, k, v, U32.cmp(k, kx))
    case Leaf{}:
      Node{Red{}, Leaf{}, k, v, Leaf{}}

@unsafe def ins.red(l: Tree, kx: U32, vx: Bool, r: Tree, +k: U32, +v: Bool, o: Cmp) -> Tree:
  match o:
    case LT{}:
      Node{Red{}, ins(l, k, v), kx, vx, r}
    case GT{}:
      Node{Red{}, l, kx, vx, ins(r, k, v)}
    case EQ{}:
      Node{Red{}, l, k, v, r}

@unsafe def ins.black(l: Tree, kx: U32, vx: Bool, r: Tree, +k: U32, +v: Bool, o: Cmp) -> Tree:
  match o:
    case LT{}:
      ins.black.lt(is_red(l), kx, vx, r, k, v)
    case GT{}:
      ins.black.gt(l, kx, vx, is_red(r), k, v)
    case EQ{}:
      Node{Black{}, l, k, v, r}

@unsafe def ins.black.lt(lz: Tree & Bool, kx: U32, vx: Bool, r: Tree, +k: U32, +v: Bool) -> Tree:
  match lz:
    case (l, True{}):
      balance_left(ins(l, k, v), kx, vx, r)
    case (l, False{}):
      Node{Black{}, ins(l, k, v), kx, vx, r}

@unsafe def ins.black.gt(l: Tree, kx: U32, vx: Bool, rz: Tree & Bool, +k: U32, +v: Bool) -> Tree:
  match rz:
    case (r, True{}):
      balance_right(l, kx, vx, ins(r, k, v))
    case (r, False{}):
      Node{Black{}, l, kx, vx, ins(r, k, v)}

def set_black(t: Tree) -> Tree:
  match t:
    case Node{_, l, k, v, r}:
      Node{Black{}, l, k, v, r}
    case Leaf{}:
      Leaf{}

@unsafe def insert(t: Tree, k: U32, v: Bool) -> Tree:
  set_black(ins(t, k, v))

def fold(~f: U32 -> Bool -> U32 -> U32, t: Tree, b: U32) -> U32:
  match t:
    case Leaf{}:
      b
    case Node{_, l, k, v, r}:
      fold(~f, r, f(k, v, fold(~f, l, b)))

@unsafe def make_tree_aux(+n: Nat, t: Tree) -> Tree:
  match n:
    case 0n:
      t
    case 1n+p:
      +n1 = U32.from_nat(p)
      make_tree_aux(p, insert(t, n1, U32.is_eq(U32.mod(n1, 10), 0)))

@unsafe def make_tree(n: Nat) -> Tree:
  make_tree_aux(n, Leaf{})

def count_true(k: U32, v: Bool, r: U32) -> U32:
  match v:
    case True{}:
      U32.inc(r)
    case False{}:
      r

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    n : Nat = Nat.mul(4200000n, List.length(&1, String, args))
    IO.print(U32.show(fold(~count_true, make_tree(n), 0)))
