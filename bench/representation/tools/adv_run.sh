#!/bin/bash
# adv_run.sh FILE.bend: the C lane of base and branch, plain and with the
# live-word count and poisoned frees, at 1 and 8 threads; and the JS lane
F=$1; n=$(basename $F .bend); T=/private/tmp/bend-opt/rep-work/tools
for tag in base new; do
  R=/private/tmp/bend-opt/rep; [ $tag = base ] && R=/private/tmp/bend-opt/rep-base
  bun $R/bend2/main.ts $F -o ${n}_$tag.c > /dev/null || { echo "$tag emit fail"; continue; }
  python3 -c "
import sys; sys.path.insert(0, '$T'); import lanes
c = lanes.mem_patch(open('${n}_$tag.c').read()); open('${n}_${tag}_m.c', 'w').write(c)"
  cc -std=c11 -O3 -w ${n}_$tag.c -o ${n}_$tag -lpthread -lm
  cc -std=c11 -O3 -w -DBEND_POISON ${n}_${tag}_m.c -o ${n}_${tag}_m -lpthread -lm
  for t in 1 8; do
    ~/Software/supgen-bend/limit 120 6144 ./${n}_$tag +RTS --threads $t --gpu off -RTS > ${n}_${tag}_t$t.out 2>&1; echo "rc $?" >> ${n}_${tag}_t$t.out
    ~/Software/supgen-bend/limit 120 6144 ./${n}_${tag}_m +RTS --threads $t --gpu off -RTS > ${n}_${tag}_m$t.out 2>&1; echo "rc $?" >> ${n}_${tag}_m$t.out
  done
  bun $R/bend2/main.ts $F -o ${n}_$tag.js > /dev/null && ~/Software/supgen-bend/limit 120 6144 bun ${n}_$tag.js > ${n}_${tag}_js.out 2>&1
done
for f in ${n}_*_{t1,t8,m1,m8,js}.out; do echo "$f $(md5 -q $f) $(grep LIVE $f)"; done
