# Array.sets nested at one word plus constants write through one pointer
# below the array's end; across it they wrap as each set does alone. Out of
# order and repeated offsets keep each set's order; constant indices make a
# run too, and a variable mixed with constants does not.
import Base

def put8(a: Array<U32>, +p: U32, +v0: U32, +v1: U32, +v2: U32, +v3: U32, +v4: U32, +v5: U32, +v6: U32, +v7: U32) -> Array<U32>:
  Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, a, p, v0), (p + 1 : U32), v1), (p + 2 : U32), v2), (p + 3 : U32), v3), (p + 4 : U32), v4), (p + 5 : U32), v5), (p + 6 : U32), v6), (p + 7 : U32), v7)

def put8v(a: Array<U32>, +p: U32, +v: U32) -> Array<U32>:
  put8(a, p, v, (v + 1 : U32), (v + 2 : U32), (v + 3 : U32), (v + 4 : U32), (v + 5 : U32), (v + 6 : U32), (v + 7 : U32))

def put_odd(a: Array<U32>, +p: U32, +x: U32, +y: U32) -> Array<U32>:
  Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, a, (p + 3 : U32), x), (p + 1 : U32), y), (p + 3 : U32), y), (p + 9 : U32), x), p, x)

type S is Type:
  S{a: Array<U32>, i: U32, acc: U32}

def put_lit(a: Array<U32>, +x: U32, +y: U32) -> Array<U32>:
  Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, a, 70, x), 72, y), 71, x), 73, y)

def put_mix(a: Array<U32>, +p: U32, +x: U32, +y: U32) -> Array<U32>:
  Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, a, p, x), 3, y), (p + 1 : U32), y), (p + 2 : U32), x)

def sum_got(r: Array<U32> & U32, +i: U32, +acc: U32) -> S:
  (a, v) = r
  S{a, (i + 1 : U32), (acc * 31 + v : U32)}

def sum(n: Nat, st: S) -> U32:
  match n, st:
    case 0n, S{a, i, acc}:
      acc
    case 1n+k, S{a, i, acc}:
      +j = i
      sum(k, sum_got(Array.get(U32, a, j), j, acc))

law main.out:
  U32

def main.out():
  sum(128n, S{put_mix(put_lit(put_odd(put_odd(put8v(put8v(put8v(Array.new(U32, 7n, 0), 3, 100), 124, 200), 4294967295, 300), 40, 7, 9), 120, 5, 6), 11, 12), 90, 13, 14), 0, 0})

law main:
  IO(Unit)

def main():
  IO.print(U32.show(main.out()))
#|3730883539
