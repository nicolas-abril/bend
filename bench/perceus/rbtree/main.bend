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

def ins(t: Tree, o: Cmp, +k: U32, +v: Bool) -> Tree:
  match t o:
    case Leaf{} _:
      Node{Red{}, Leaf{}, k, v, Leaf{}}
    case Node{Red{}, Leaf{}, kx, vx, r} LT{}:
      Node{Red{}, Node{Red{}, Leaf{}, k, v, Leaf{}}, kx, vx, r}
    case Node{Red{}, Node{c, a, +ky, vy, b}, kx, vx, r} LT{}:
      Node{Red{}, ins(Node{c, a, ky, vy, b}, U32.cmp(k, ky), k, v), kx, vx, r}
    case Node{Red{}, l, kx, vx, Leaf{}} GT{}:
      Node{Red{}, l, kx, vx, Node{Red{}, Leaf{}, k, v, Leaf{}}}
    case Node{Red{}, l, kx, vx, Node{c, a, +ky, vy, b}} GT{}:
      Node{Red{}, l, kx, vx, ins(Node{c, a, ky, vy, b}, U32.cmp(k, ky), k, v)}
    case Node{Red{}, l, kx, vx, r} EQ{}:
      Node{Red{}, l, k, v, r}
    case Node{Black{}, Leaf{}, kx, vx, r} LT{}:
      Node{Black{}, Node{Red{}, Leaf{}, k, v, Leaf{}}, kx, vx, r}
    case Node{Black{}, Node{Red{}, a, +ky, vy, b}, kx, vx, r} LT{}:
      balance_left(ins(Node{Red{}, a, ky, vy, b}, U32.cmp(k, ky), k, v), kx, vx, r)
    case Node{Black{}, Node{Black{}, a, +ky, vy, b}, kx, vx, r} LT{}:
      Node{Black{}, ins(Node{Black{}, a, ky, vy, b}, U32.cmp(k, ky), k, v), kx, vx, r}
    case Node{Black{}, l, kx, vx, Leaf{}} GT{}:
      Node{Black{}, l, kx, vx, Node{Red{}, Leaf{}, k, v, Leaf{}}}
    case Node{Black{}, l, kx, vx, Node{Red{}, a, +ky, vy, b}} GT{}:
      balance_right(l, kx, vx, ins(Node{Red{}, a, ky, vy, b}, U32.cmp(k, ky), k, v))
    case Node{Black{}, l, kx, vx, Node{Black{}, a, +ky, vy, b}} GT{}:
      Node{Black{}, l, kx, vx, ins(Node{Black{}, a, ky, vy, b}, U32.cmp(k, ky), k, v)}
    case Node{Black{}, l, kx, vx, r} EQ{}:
      Node{Black{}, l, k, v, r}

def set_black(t: Tree) -> Tree:
  match t:
    case Node{_, l, k, v, r}:
      Node{Black{}, l, k, v, r}
    case Leaf{}:
      Leaf{}

def insert(t: Tree, +k: U32, v: Bool) -> Tree:
  match t:
    case Leaf{}:
      set_black(ins(Leaf{}, EQ{}, k, v))
    case Node{c, l, +kx, vx, r}:
      set_black(ins(Node{c, l, kx, vx, r}, U32.cmp(k, kx), k, v))

def fold(~f: U32 -> Bool -> U32 -> U32, t: Tree, b: U32) -> U32:
  match t:
    case Leaf{}:
      b
    case Node{_, l, k, v, r}:
      fold(~f, r, f(k, v, fold(~f, l, b)))

def make_tree_aux(+n: Nat, t: Tree) -> Tree:
  match n:
    case 0n:
      t
    case 1n+p:
      +n1 = U32.from_nat(p)
      make_tree_aux(p, insert(t, n1, U32.is_eq(U32.mod(n1, 10), 0)))

def make_tree(n: Nat) -> Tree:
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
