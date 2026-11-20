#!/usr/bin/env bash
# setup_m4.sh: rebuild every binary queue_m4.sh needs, from worktrees at
#   /private/tmp/bend-opt/par-{main,int,2207,pr2164m,pr2183m,pin}
# (main 0e2f38f7; opt/integration 60c755f4; #2207 e34e9cea; #2164 and #2183
# merged onto main; 386b7fc1, kmeans' PAR-CPU pin commit). Builds go to
# $PAR_WORK (default /private/tmp/bend-opt/par-work).
set -eu
T=$(cd "$(dirname "$0")" && pwd)
O=/private/tmp/bend-opt
W=${PAR_WORK:-$O/par-work}
mkdir -p $W && cd $W
cc -O2 $T/tm.c -o tm
export PAR_SRC=$O/par-main
python3 $T/scale.py build -j 4 --builds main=$O/par-main,int=$O/par-int,r2207=$O/par-2207,p2164=$O/par-pr2164m,p2183=$O/par-pr2183m | grep -v "^ok" || true
# the binarytrees twin
mkdir -p tw && cc -std=gnu11 -O2 -w $T/twins/bt_twin.c -o tw/bt_twin -lpthread
# wait edits: binarytrees, #2141's repro, the multi-turn benches
mkdir -p bt/bin mt
for m in noyield spin y16; do
  python3 $T/edits/wait_edits.py bin/main/koru-par__binarytrees.c bt/bin/bt_wait_$m.c $m
  python3 $T/edits/wait_edits.py bin/main/x__fork_wake_par.c bt/bin/fw_wait_$m.c $m
done
for p in bench__histogram bench__tree-bitonic bench__kmeans bench__tree-matmul demo__pure_par_sort; do
  for m in noyield spin; do python3 $T/edits/wait_edits.py bin/main/$p.c mt/${p#*__}_$m.c $m; done
done
ls bt/bin/*.c mt/*.c | sed 's/\.c$//' | xargs -P 4 -I@ cc -std=c11 -O3 -w @.c -o @ -lpthread
# the cutoffs on main, #2164 and #2183
for b in main:par-main p2164:par-pr2164m p2183:par-pr2183m; do
  for c in 0 1 2 3 5 6 8 13; do
    echo "$O/${b#*:} $T/progs/binarytrees_cut$c.bend $W/bt/bin/${b%%:*}_cut$c"
  done
done | xargs -P 4 -n 3 $T/build.sh
# counted builds (CPU)
mkdir -p cnt/main
for b in main p2164 p2183 int r2207; do
  echo "bin/$b/koru-par__binarytrees.c cnt/bt_$b"; echo "bin/$b/x__fork_wake_par.c cnt/fw_$b"
done | xargs -P 4 -n 2 $T/cnt_build.sh
ls bin/main/*.c | grep -v seq | while read c; do echo "$c cnt/main/$(basename $c .c)"; done | xargs -P 4 -n 2 $T/cnt_build.sh
# kmeans at its pin commit (its own source: main's does not parse there)
mkdir -p km
$T/build.sh $O/par-pin $O/par-pin/bench/runtime/kmeans/main.bend km/kmeans_pin_ownsrc
# Metal: user binaries (bend -o, with .gpu) and counted Metal builds
mkdir -p gpu
for b in bfs editdist gameoflife hashmap histogram kmeans lexer mandelbrot merkle nbody queens raytrace symreg terrain tree-bitonic tree-matmul tree-radix; do
  echo "$O/par-main/bench/runtime/$b/main.bend $W/gpu/b_$b"
done > gpu/list
for d in pure_par_sort pure_par_sum; do echo "$O/par-main/demos/$d/main.bend $W/gpu/d_$d"; done >> gpu/list
BEND_GPU=1 xargs -P 3 -n 2 $T/build.sh $O/par-main < gpu/list
(ls bin/main/bench__*.c | while read c; do n=$(basename $c .c); echo "$c gpu/cnt_b_${n#bench__}"; done
 ls bin/main/demo__*.c | while read c; do n=$(basename $c .c); echo "$c gpu/cnt_d_${n#demo__}"; done) | xargs -P 3 -n 2 $T/cnt_metal.sh
echo SETUP DONE
