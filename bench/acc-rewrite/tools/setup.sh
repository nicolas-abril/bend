#!/bin/bash
# setup.sh W: emits every queens variant into W/q from the worktrees below
# and builds tm into W/tools. Worktrees (detached):
#   MAIN  bendlang/bend main 0e2f38f7
#   INT   nicolas-abril/bend opt/integration 60c755f4
#   PGOQ  nicolas-abril/bend bench/pgo-queens e4ee4bcb (respell/r1.bend)
set -e
W=${1:-/private/tmp/bend-opt/acc2-work}
MAIN=${MAIN:-/private/tmp/bend-opt/acc2/main}
INT=${INT:-/private/tmp/bend-opt/acc2/int}
PGOQ=${PGOQ:-/private/tmp/bend-opt/acc2/pgoq}
H=$(cd "$(dirname "$0")" && pwd)
mkdir -p $W/q $W/tools
cc -O2 -w $H/tm.c -o $W/tools/tm
cp $MAIN/bench/runtime/queens/main.bend $W/q/queens.bend
cp $PGOQ/bench/pgo-queens/respell/r1.bend $W/q/r1.bend
cp $H/../variants/s1.bend $W/q/s1.bend
cd $W/q
for b in main int; do
  [ $b = main ] && C=$MAIN || C=$INT
  for p in queens r1 s1; do bun $C/bend2/main.ts $p.bend -o ${p}_$b.c > /dev/null; done
  python3 $H/edits.py s2a queens_$b.c s2a_$b.c
  python3 $H/edits.py s2b r1_$b.c s2b_$b.c
  python3 $H/edits.py s12a s1_$b.c s12a_$b.c
  python3 $H/edits.py s12b s1_$b.c s12b_$b.c
done
