#!/bin/bash
# count.sh W: runs the hook over each corpus list in W/cnt (*.list), one
# group at a time, each under the memory limit; output W/cnt/GROUP.jsonl
W=${1:-/private/tmp/bend-opt/acc2-work}
for l in tests demos benches kernels perceus par; do
  rm -f $W/cnt/$l.jsonl
  echo "== $l $(uptime | sed 's/.*averages: //')"
  ACC_LIST=$W/cnt/$l.list ACC_OUT=$W/cnt/$l.jsonl \
    ~/Software/supgen-bend/limit 1800 6144 bun $W/hook/bend2/main.ts x
  echo "exit $? $(wc -l < $W/cnt/$l.jsonl)"
done
