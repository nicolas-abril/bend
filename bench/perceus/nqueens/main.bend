import Base

def safe(xs: List<&2, U32>, ok: Bool, +queen: U32, +diag: U32) -> Bool:
  match xs ok:
    case Nil{} b:
      b
    case Con{_, _} False{}:
      False{}
    case Con{+q, qs} True{}:
      safe(qs, U32.is_ne(queen, q) && U32.is_ne(queen, U32.add(q, diag)) && U32.is_ne(queen, U32.sub(q, diag)), queen, U32.inc(diag))

def push(ok: Bool, queen: U32, xs: List<&2, U32>, xss: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match ok:
    case True{}:
      (queen <> xs) <> xss
    case False{}:
      xss

def append_safe(+queen: Nat, +xs: List<&2, U32>, xss: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match queen:
    case 0n:
      xss
    case 1n+p:
      +q = U32.from_nat(queen)
      append_safe(p, xs, push(safe(xs, True{}, q, 1), q, xs, xss))

def extend(xss: List<&2, List<&2, U32>>, +queen: Nat, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xss:
    case Nil{}:
      acc
    case xs <> rest:
      extend(rest, queen, append_safe(queen, xs, acc))

def find_solutions(+n: Nat, +queen: Nat) -> List<&2, List<&2, U32>>:
  match queen:
    case 0n:
      [[]]
    case 1n+p:
      extend(find_solutions(n, p), n, [])

def queens(+n: Nat) -> Nat:
  List.length(&2, List<&2, U32>, find_solutions(n, n))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    n : Nat = Nat.mul(13n, List.length(&1, String, args))
    IO.print(Nat.show(queens(n)))
