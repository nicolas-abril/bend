# micro: nested forks with tiny leaves: fib(36) with a fork at every level.
import Base

@unsafe
def fib(+n: U32) -> U32:
  fib.go(U32.is_lt(n, 2), n)

@unsafe
def fib.go(small: Bool, +n: U32) -> U32:
  match small:
    case True{}:
      n
    case False{}:
      a b = fib((n - 1 : U32)) fib((n - 2 : U32))
      (a + b : U32)

@unsafe
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    IO.print(U32.show(fib((35 + U32.from_nat(List.length(&1, String, args)) : U32))))
