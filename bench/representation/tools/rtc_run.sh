#!/bin/bash
# rtc_run.sh PROGS OUTDIR COMPILER: build each program with the counting
# compiler and run it at one thread, GPU off, under the memory limit.
P=$1; O=$2; C=$3
mkdir -p $O
while read n f; do
  [ -s $O/$n.cnt ] && continue
  echo "== $n $(uptime | sed 's/.*averages: //')"
  bun $C/main.ts $f -o $O/$n.c > $O/$n.emit 2>&1 || { echo "emit fail $n"; continue; }
  cc -std=c11 -O2 -w $O/$n.c -o $O/$n.x -lpthread || { echo "cc fail $n"; continue; }
  (cd $(dirname $f) && REPC_OUT=$O/$n.cnt ~/Software/supgen-bend/limit 600 6144 $O/$n.x +RTS --threads 1 --gpu off -RTS > $O/$n.out 2>&1); echo "rc $?"
  rm -f $O/$n.x
done < $P
