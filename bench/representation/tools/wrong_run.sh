#!/bin/bash
# wrong_run.sh: each wrong version on the adversarial programs (C, 1 and 8
# threads, poisoned frees, live words) against the branch's outputs
cd /private/tmp/bend-opt/rep-work/adv
for w in nofixed noreadmask overlap arity spine bits64 nowritemask sparecls; do
  python3 ../tools/wrong.py $w ../wr/bend2 || continue
  res=""
  for f in pack_adv pack_deep pack_foreign; do
    bun ../wr/bend2/main.ts $f.bend -o w_$f.c > /dev/null 2>&1 || { res="$res $f:emitfail"; continue; }
    cmp -s w_$f.c ${f}_new.c 2>/dev/null && [ $f != pack_foreign ] && { res="$res $f:sameC"; continue; }
    python3 -c "
import sys; sys.path.insert(0, '../tools'); import lanes
open('w_${f}_m.c', 'w').write(lanes.mem_patch(open('w_$f.c').read()))"
    cc -std=c11 -O3 -w -DBEND_POISON w_${f}_m.c -o w_${f}_m -lpthread -lm 2>/dev/null || { res="$res $f:ccfail"; continue; }
    for t in 1 8; do
      ~/Software/supgen-bend/limit 60 6144 ./w_${f}_m +RTS --threads $t --gpu off -RTS > w.out 2>&1; rc=$?
      ref=${f}_new_m$t.out; [ $f = pack_foreign ] && ref=pf_ref.out
      grep -v "^rc" w.out > w1; grep -v "^rc" $ref > w2
      cmp -s w1 w2 && res="$res $f/t$t:ok" || res="$res $f/t$t:CAUGHT(rc=$rc,$(grep -c . w1)l,$(grep LIVE w.out | tr -d ' '))"
    done
  done
  echo "$w:$res"
done
