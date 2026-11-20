#!/bin/sh
# prof.sh SECONDS BIN [ARGS..]: per-function share of samples (top of stack),
# from macOS `sample` attached right after launch, 1 ms interval.
secs=$1; shift
"$@" > /dev/null 2>&1 &
pid=$!
out=$(mktemp)
sample $pid $secs 1 -mayDie -file $out > /dev/null 2>&1
wait $pid 2>/dev/null
awk '/Sort by top of stack/{p=1; next} p && NF>=2 {print}' $out | awk '{n=$NF; $NF=""; s[$0]+=n; t+=n} END {for (k in s) printf "%6.1f%%  %s\n", 100*s[k]/t, k}' | sort -rn | head -${TOP:-12}
rm -f $out
