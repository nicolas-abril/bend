#!/bin/bash
# Hand bounds for the general rewrites, instructions retired at one thread.
# NOT RUN YET (another agent was timing the 230 programs). Each pair is
# measured with /usr/bin/time -l under ~/Software/supgen-bend/limit.
#
#   run_bounds.sh INT TMC TMCBASE
#     INT      a bend2 checkout at opt/integration (bae64757)
#     TMC      a bend2 checkout at #1810's head (548fc4a1)
#     TMCBASE  its merge base with main (4f99f4c1)
set -e
INT=$1; TMC=$2; TMCB=$3
H=$(cd "$(dirname "$0")" && pwd)
BB=${BB:-$HOME/Software/bend-benchmarks}
L="$HOME/Software/supgen-bend/limit"
W=$(mktemp -d)
one() { # compiler src out
  (cd "$(dirname "$2")" && $L 600 6144 bun "$1/bend2/main.ts" "$2" -o "$3.c" > /dev/null)
  $L 600 6144 cc -std=c11 -O3 -w "$3.c" -o "$3" -lpthread -lm
  local r; r=$( (cd "$(dirname "$2")" && $L 120 6144 /usr/bin/time -l "$3" +RTS --threads 1 --gpu off -RTS) 2>&1)
  echo "$(basename "$3") $(echo "$r" | awk '/instructions retired/{print $1}') $(echo "$r" | head -1 | cut -c1-60)"
}
# closures: palindrome as first ported (pair.go + lambdas) and with helper defs
one "$INT" "$H/palindrome/closures.bend" "$W/pal_closures"
one "$INT" "$H/palindrome/helpers.bend" "$W/pal_helpers"
# affine TRMc: symreg's eval with the context a * x + c carried
one "$INT" "$H/symreg/base.bend" "$W/sym_base"
one "$INT" "$H/symreg/affine.bend" "$W/sym_affine"
# constructor TRMc as #1810 builds it (it refuses shared constructors)
for p in bend-runtime/lexer perceus/rbtree kostya/json clbg/pidigits clbg/k-nucleotide awfy/havlak koka-extra/msort koka-extra/qsort; do
  n=$(echo $p | tr / _)
  one "$TMCB" "$BB/$p/main.bend" "$W/${n}_base"
  one "$TMC" "$BB/$p/main.bend" "$W/${n}_1810"
done
