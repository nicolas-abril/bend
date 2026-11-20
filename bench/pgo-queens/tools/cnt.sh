#!/bin/sh
# cnt.sh BIN...: one run each through tm; prints label, output, instructions G, cycles G, P-core share
for b in "$@"; do
  r=$( { /private/tmp/bend-opt/pq-work/tools/tm $b +RTS --threads 1 --gpu off -RTS > /tmp/cnt_out.$$; } 2>&1 | grep '^rc=')
  o=$(tail -1 /tmp/cnt_out.$$)
  echo "$b $o $r" | awk '{for(i=1;i<=NF;i++){split($i,a,"="); v[a[1]]=a[2]} printf "%-28s %s instr=%.3fG cycles=%.3fG p=%.0f%%\n", $1, $2, v["instr"]/1e9, v["cycles"]/1e9, 100*v["pcycles"]/v["cycles"]}'
done
rm -f /tmp/cnt_out.$$
