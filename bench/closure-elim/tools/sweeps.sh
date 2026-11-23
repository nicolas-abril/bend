#!/bin/bash
# placement sweeps, integration against closure-elim, one program at a time
cd /private/tmp/bend-opt/clo
for n in "$@"; do
  d=/Users/macolas/Software/bend-benchmarks/$(echo $n | sed 's#__#/#g; s#/main$##; s#/helpers$##')
  (cd $d && TM=/private/tmp/bend-opt/int2-work/tools/tm ~/Software/supgen-bend/limit 3000 6144 python3 /private/tmp/bend-opt/eqsat/tools/swp.py --out /private/tmp/bend-opt/clo/swp/$n.jsonl --rounds 2 --rts --wdir /private/tmp/bend-opt/clo/swp/w_$n int=/private/tmp/bend-opt/clo/m230/c/int/$n.c elim=/private/tmp/bend-opt/clo/m230/c/elim/$n.c > /private/tmp/bend-opt/clo/swp/$n.log 2>&1)
  echo "== $n"; python3 /private/tmp/bend-opt/eqsat/tools/swp.py --table swp/$n.jsonl
done
