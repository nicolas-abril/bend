import Base

type Color is Data:
  Red{}
  Black{}

type Tree is Data:
  Leaf{}
  Node{color: Color, lchild: Tree, key: U32, value: Bool, rchild: Tree}

def fold(~f: U32 -> Bool -> U32 -> U32, t: Tree, acc: U32) -> U32:
  match t:
    case Leaf{}:
      acc
    case Node{_, l, k, v, r}:
      fold(~f, r, f(k, v, fold(~f, l, acc)))

def balance1(kv: U32, vv: Bool, t: Tree, s: Tree) -> Tree:
  match s:
    case Leaf{}:
      Leaf{}
    case Node{_, Node{Red{}, l, kx, vx, r1}, ky, vy, r2}:
      Node{Red{}, Node{Black{}, l, kx, vx, r1}, ky, vy, Node{Black{}, r2, kv, vv, t}}
    case Node{_, l1, ky, vy, Node{Red{}, l2, kx, vx, r}}:
      Node{Red{}, Node{Black{}, l1, ky, vy, l2}, kx, vx, Node{Black{}, r, kv, vv, t}}
    case Node{_, l, ky, vy, r}:
      Node{Black{}, Node{Red{}, l, ky, vy, r}, kv, vv, t}

def balance2(t: Tree, kv: U32, vv: Bool, s: Tree) -> Tree:
  match s:
    case Leaf{}:
      Leaf{}
    case Node{_, Node{Red{}, l, kx1, vx1, r1}, ky, vy, r2}:
      Node{Red{}, Node{Black{}, t, kv, vv, l}, kx1, vx1, Node{Black{}, r1, ky, vy, r2}}
    case Node{_, l1, ky, vy, Node{Red{}, l2, kx2, vx2, r2}}:
      Node{Red{}, Node{Black{}, t, kv, vv, l1}, ky, vy, Node{Black{}, l2, kx2, vx2, r2}}
    case Node{_, l, ky, vy, r}:
      Node{Black{}, t, kv, vv, Node{Red{}, l, ky, vy, r}}

def is_red(t: Tree) -> Tree & Bool:
  match t:
    case Node{Red{}, l, k, v, r}:
      (Node{Red{}, l, k, v, r}, True{})
    case t0:
      (t0, False{})

@unsafe def ins(t: Tree, +kx: U32, +vx: Bool) -> Tree:
  match t:
    case Leaf{}:
      Node{Red{}, Leaf{}, kx, vx, Leaf{}}
    case Node{Red{}, l, +ky, vy, r}:
      ins.red(l, ky, vy, r, kx, vx, U32.cmp(kx, ky))
    case Node{Black{}, l, +ky, vy, r}:
      ins.black(l, ky, vy, r, kx, vx, U32.cmp(kx, ky))

@unsafe def ins.red(l: Tree, ky: U32, vy: Bool, r: Tree, +kx: U32, +vx: Bool, o: Cmp) -> Tree:
  match o:
    case LT{}:
      Node{Red{}, ins(l, kx, vx), ky, vy, r}
    case EQ{}:
      Node{Red{}, l, kx, vx, r}
    case GT{}:
      Node{Red{}, l, ky, vy, ins(r, kx, vx)}

@unsafe def ins.black(l: Tree, ky: U32, vy: Bool, r: Tree, +kx: U32, +vx: Bool, o: Cmp) -> Tree:
  match o:
    case LT{}:
      ins.black.lt(is_red(l), ky, vy, r, kx, vx)
    case EQ{}:
      Node{Black{}, l, kx, vx, r}
    case GT{}:
      ins.black.gt(l, ky, vy, is_red(r), kx, vx)

@unsafe def ins.black.lt(lz: Tree & Bool, ky: U32, vy: Bool, r: Tree, +kx: U32, +vx: Bool) -> Tree:
  match lz:
    case (l, True{}):
      balance1(ky, vy, r, ins(l, kx, vx))
    case (l, False{}):
      Node{Black{}, ins(l, kx, vx), ky, vy, r}

@unsafe def ins.black.gt(l: Tree, ky: U32, vy: Bool, rz: Tree & Bool, +kx: U32, +vx: Bool) -> Tree:
  match rz:
    case (r, True{}):
      balance2(l, ky, vy, ins(r, kx, vx))
    case (r, False{}):
      Node{Black{}, l, ky, vy, ins(r, kx, vx)}

def set_black(t: Tree) -> Tree:
  match t:
    case Node{_, l, k, v, r}:
      Node{Black{}, l, k, v, r}
    case Leaf{}:
      Leaf{}

@unsafe def insert.go(tz: Tree & Bool, k: U32, v: Bool) -> Tree:
  match tz:
    case (t, True{}):
      set_black(ins(t, k, v))
    case (t, False{}):
      ins(t, k, v)

@unsafe def insert(t: Tree, k: U32, v: Bool) -> Tree:
  insert.go(is_red(t), k, v)

def keep(z: Bool, +t: Tree, acc: List<&2, Tree>) -> List<&2, Tree>:
  match z:
    case True{}:
      t <> acc
    case False{}:
      acc

@unsafe def make_tree_aux(+n: Nat, +freq: U32, t: Tree, acc: List<&2, Tree>) -> List<&2, Tree>:
  match n:
    case 0n:
      t <> acc
    case 1n+p:
      +k = U32.from_nat(n)
      +t1 = insert(t, k, U32.is_eq(U32.mod(k, 10), 0))
      make_tree_aux(p, freq, t1, keep(U32.is_eq(U32.mod(k, freq), 0), t1, acc))

@unsafe def make_tree(freq: U32, n: Nat) -> List<&2, Tree>:
  make_tree_aux(n, freq, Leaf{}, [])

def count_true(k: U32, v: Bool, r: U32) -> U32:
  match v:
    case True{}:
      U32.inc(r)
    case False{}:
      r

def head(ts: List<&2, Tree>) -> Tree:
  match ts:
    case Nil{}:
      Leaf{}
    case t <> rest:
      t

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    +one : Nat = List.length(&1, String, args)
    trees : List<&2, Tree> = make_tree(U32.from_nat(Nat.mul(5n, one)), Nat.mul(4200000n, one))
    IO.print(U32.show(fold(~count_true, head(trees), 0)))
