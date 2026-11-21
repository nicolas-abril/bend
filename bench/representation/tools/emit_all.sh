#!/bin/bash
# emit_all.sh: hash of the emitted C of every test and demo, base and branch
W=/private/tmp/bend-opt/rep-work
cd $W/ed; rm -f base.txt new.txt
for c in ch.*; do
  for v in base new; do
    H=$W/hk/bend2; [ $v = base ] && H=$W/hkb/bend2
    REP_LIST=$W/ed/$c REP_EMIT=$W/ed/$v.txt ~/Software/supgen-bend/limit 1800 6144 bun $H/main.ts x > /dev/null 2>&1
    echo "$c $v $? $(wc -l < $W/ed/$v.txt)"
  done
done
