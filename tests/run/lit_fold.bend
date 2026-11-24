# Calls of defs on closed arguments are run at compile time when their value
# is a small constant: String.length, String.contains and String.starts_with
# on literals, Nat and U32 arithmetic (U32 wraps), a user def that matches on
# a literal, a string and a list built from literals, and Bool results. A
# call whose one open argument calls a def that answers a literal from every
# arm (score(word(k)), count(word(k), Chr{111})) calls a copy of that def whose
# arms answer the outer call's values. The rest stay calls: a closed call
# past the fuel (fib(27n)), a value past the size bound (a 300-char string),
# F32 arithmetic, and calls on open arguments. Sizes come from the argument
# list, so the open calls are not folded by other means.
import Base

def len(xs: List<String>, acc: Nat) -> Nat:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      len(t, 1n+acc)

def word(+k: Nat) -> String:
  match k:
    case 0n:
      "the"
    case 1n:
      "quick"
    case 2n:
      "brown"
    case 3n:
      ""
    case 1n+p:
      "fox"

def score(+w: String) -> Nat:
  Nat.add(Nat.add(String.length(w),
    Bool.pick(Nat, String.contains(w, "o"), 7n, 0n)),
    Bool.pick(Nat, String.starts_with(w, "t"), 3n, 0n))

def count(s: String, +c: Char) -> Nat:
  match s:
    case SNil{}:
      0n
    case SCon{h, t}:
      Nat.add(count(t, c), Bool.pick(Nat, Char.is_eq(h, c), 1n, 0n))

def pick(+k: Nat) -> U32:
  match k:
    case 0n:
      7
    case 1n+p:
      4000000000

def wrap(+x: U32) -> U32:
  U32.add(U32.mul(x, x), 12345)

def fib(+n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+p:
      match p:
        case 0n:
          1n
        case 1n+q:
          Nat.add(fib(p), fib(q))

def rep(+n: Nat, +s: String) -> String:
  match n:
    case 0n:
      ""
    case 1n+p:
      String.append(s, rep(p, s))

def sum(xs: List<Nat>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case Con{h, t}:
      Nat.add(h, sum(t))

def go(+i: Nat, +z: Nat, acc: Nat) -> Nat:
  match i:
    case 0n:
      acc
    case 1n+p:
      go(p, z, Nat.add(acc, Nat.add(score(word(Nat.mod(Nat.add(p, z), 6n))),
        count(word(Nat.mod(p, 5n)), Chr{111}))))

def show(b: Bool) -> String:
  match b:
    case True{}:
      "yes"
    case False{}:
      "no"

def run(+z: Nat) -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.print(Nat.show(Nat.add(String.length("hello"), z)))
    Unit <- IO.print(Nat.show(Nat.add(score("brown"), z)))
    Unit <- IO.print(Nat.show(Nat.add(score("the"), z)))
    Unit <- IO.print(show(String.contains("quick", "ui")))
    Unit <- IO.print(show(String.starts_with("quick", "qx")))
    Unit <- IO.print(Nat.show(Nat.add(Nat.mul(49n, 343n), z)))
    Unit <- IO.print(Nat.show(Nat.add(Nat.sub(3n, 5n), z)))
    Unit <- IO.print(U32.show(U32.add(wrap(70000), U32.from_nat(z))))
    Unit <- IO.print(U32.show(U32.add(pick(1n), U32.from_nat(z))))
    Unit <- IO.print(Nat.show(Nat.add(count("foo boo", Chr{111}), z)))
    Unit <- IO.print(String.append("ab", String.append("cd", Nat.show(z))))
    Unit <- IO.print(Nat.show(Nat.add(sum([1n, 2n, 3n, 40n]), z)))
    Unit <- IO.print(Nat.show(Nat.add(fib(27n), z)))
    Unit <- IO.print(Nat.show(Nat.add(String.length(rep(100n, "abc")), z)))
    Unit <- IO.print(F32.show(F32.lerp(1.5, 2.25, 0.5)))
    Unit <- IO.print(Nat.show(score(word(Nat.mod(z, 6n)))))
    IO.print(Nat.show(go(Nat.add(z, 1000n), z, 0n)))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(len(args, 0n))

#|6
#|13
#|7
#|yes
#|no
#|16808
#|1
#|605045050
#|4000000001
#|5
#|abcd1
#|47
#|196419
#|301
#|1.875
#|5
#|7575
