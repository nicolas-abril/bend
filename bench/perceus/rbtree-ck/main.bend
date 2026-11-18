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

def ins(t: Tree, o: Cmp, +kx: U32, +vx: Bool) -> Tree:
  match t o:
    case Leaf{} _:
      Node{Red{}, Leaf{}, kx, vx, Leaf{}}
    case Node{Red{}, Leaf{}, ky, vy, r} LT{}:
      Node{Red{}, Node{Red{}, Leaf{}, kx, vx, Leaf{}}, ky, vy, r}
    case Node{Red{}, Node{c, a, +kz, vz, b}, ky, vy, r} LT{}:
      Node{Red{}, ins(Node{c, a, kz, vz, b}, U32.cmp(kx, kz), kx, vx), ky, vy, r}
    case Node{Red{}, l, ky, vy, r} EQ{}:
      Node{Red{}, l, kx, vx, r}
    case Node{Red{}, l, ky, vy, Leaf{}} GT{}:
      Node{Red{}, l, ky, vy, Node{Red{}, Leaf{}, kx, vx, Leaf{}}}
    case Node{Red{}, l, ky, vy, Node{c, a, +kz, vz, b}} GT{}:
      Node{Red{}, l, ky, vy, ins(Node{c, a, kz, vz, b}, U32.cmp(kx, kz), kx, vx)}
    case Node{Black{}, Leaf{}, ky, vy, r} LT{}:
      Node{Black{}, Node{Red{}, Leaf{}, kx, vx, Leaf{}}, ky, vy, r}
    case Node{Black{}, Node{Red{}, a, +kz, vz, b}, ky, vy, r} LT{}:
      balance1(ky, vy, r, ins(Node{Red{}, a, kz, vz, b}, U32.cmp(kx, kz), kx, vx))
    case Node{Black{}, Node{Black{}, a, +kz, vz, b}, ky, vy, r} LT{}:
      Node{Black{}, ins(Node{Black{}, a, kz, vz, b}, U32.cmp(kx, kz), kx, vx), ky, vy, r}
    case Node{Black{}, l, ky, vy, r} EQ{}:
      Node{Black{}, l, kx, vx, r}
    case Node{Black{}, l, ky, vy, Leaf{}} GT{}:
      Node{Black{}, l, ky, vy, Node{Red{}, Leaf{}, kx, vx, Leaf{}}}
    case Node{Black{}, l, ky, vy, Node{Red{}, a, +kz, vz, b}} GT{}:
      balance2(l, ky, vy, ins(Node{Red{}, a, kz, vz, b}, U32.cmp(kx, kz), kx, vx))
    case Node{Black{}, l, ky, vy, Node{Black{}, a, +kz, vz, b}} GT{}:
      Node{Black{}, l, ky, vy, ins(Node{Black{}, a, kz, vz, b}, U32.cmp(kx, kz), kx, vx)}

def set_black(t: Tree) -> Tree:
  match t:
    case Node{_, l, k, v, r}:
      Node{Black{}, l, k, v, r}
    case Leaf{}:
      Leaf{}

def insert(t: Tree, +k: U32, v: Bool) -> Tree:
  match t:
    case Leaf{}:
      ins(Leaf{}, EQ{}, k, v)
    case Node{Red{}, l, +ky, vy, r}:
      set_black(ins(Node{Red{}, l, ky, vy, r}, U32.cmp(k, ky), k, v))
    case Node{Black{}, l, +ky, vy, r}:
      ins(Node{Black{}, l, ky, vy, r}, U32.cmp(k, ky), k, v)

def keep(z: Bool, +t: Tree, acc: List<&2, Tree>) -> List<&2, Tree>:
  match z:
    case True{}:
      t <> acc
    case False{}:
      acc

def make_tree_aux(+n: Nat, +freq: U32, t: Tree, acc: List<&2, Tree>) -> List<&2, Tree>:
  match n:
    case 0n:
      t <> acc
    case 1n+p:
      +k = U32.from_nat(n)
      +t1 = insert(t, k, U32.is_eq(U32.mod(k, 10), 0))
      make_tree_aux(p, freq, t1, keep(U32.is_eq(U32.mod(k, freq), 0), t1, acc))

def make_tree(freq: U32, n: Nat) -> List<&2, Tree>:
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
