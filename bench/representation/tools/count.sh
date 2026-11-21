#!/bin/bash
# count.sh W: runs the rep hook over each corpus list in W/cnt, one group at
# a time under the memory limit; output W/cnt/GROUP.jsonl
W=${1:-/private/tmp/bend-opt/rep-work}
cd $W/cnt
rm -f *.jsonl
REP_BASE=1 REP_LIST=/dev/null REP_OUT=$W/cnt/base.jsonl ~/Software/supgen-bend/limit 600 6144 bun $W/hk/bend2/main.ts x
for l in benches kernels par perceus demos tchunk.aa tchunk.ab tchunk.ac tchunk.ad tchunk.ae tchunk.af; do
  f=$l; [ -f $l.list ] && f=$l.list
  echo "== $l $(uptime | sed 's/.*averages: //')"
  REP_LIST=$W/cnt/$f REP_OUT=$W/cnt/$l.jsonl ~/Software/supgen-bend/limit 1800 6144 bun $W/hk/bend2/main.ts x
  echo "exit $? $(wc -l < $W/cnt/$l.jsonl)"
done
