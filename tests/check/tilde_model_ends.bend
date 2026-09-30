# a ~ parameter's model search ends: a datatype whose argument holds a λ
# meets itself again under a ∀-typed field (its lowered key named the
# λ's depth, so it never repeated); a nested datatype, which meets a new
# type at every step, runs out of steps, then finds NNil in a pass that
# takes its name on the path as a cycle; a function of it is the
# projection λx => x; and a law that applies an earlier ~ model
# substitutes into the λ built once, not a new search
import Base

type W<-F: Nat -> Type> is Type:
  C{g: Nat -> W<F>}

def f(~w: W<(n => Nat)>, y: Nat) -> Nat:
  y

type Nest<-A: Type> is Type:
  NCons{x: A, rest: Nest<Pair(A, A)>}
  NNil{}

def g(~n: Nest<Nat>, y: Nat) -> Nest<Nat>:
  n

def h(~k: Nest<Nat> -> Nest<Nat>, n: Nest<Nat>) -> Nest<Nat>:
  k(n)

law t:
  for ~op: @A: Type -> Nest<A>
  for ~e: {op(Nat) == NNil{} : Nest<Nat>}
  {op(Nat) == NNil{} : Nest<Nat>}

def t(op, e):
  e

#|ALL PROOFS CHECK
#|Use --verdict for mathematical validity.
