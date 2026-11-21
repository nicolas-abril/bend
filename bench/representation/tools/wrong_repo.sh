#!/bin/bash
# wrong_repo.sh: each wrong version on the repo's tests whose C changes (not
# this branch's new tests): C lane, 1 thread, poisoned frees, vs #| lines
cd /private/tmp/bend-opt/rep-work/wt
T=$(grep tests/ ../ed/changed.list)
for w in nofixed noreadmask overlap arity spine bits64 nowritemask sparecls; do
  python3 ../tools/wrong.py $w ../wr/bend2
  res=""
  for f in $T; do
    n=$(basename $f .bend)
    grep '^#|' $f | sed 's/^#|//' > want
    (cd $(dirname $f) && bun /private/tmp/bend-opt/rep-work/wr/bend2/main.ts $f -o /private/tmp/bend-opt/rep-work/wt/$n.c > /dev/null 2>&1) || { res="$res $n:emitfail"; continue; }
    cc -std=c11 -O3 -w -DBEND_POISON $n.c -o $n -lpthread -lm 2>/dev/null
    (cd $(dirname $f) && perl -e 'alarm 30; exec @ARGV' /private/tmp/bend-opt/rep-work/wt/$n +RTS --threads 1 --gpu off -RTS > /private/tmp/bend-opt/rep-work/wt/got 2>&1)
    cmp -s got want || res="$res $n:CAUGHT"
  done
  echo "$w:${res:- none caught}"
done
