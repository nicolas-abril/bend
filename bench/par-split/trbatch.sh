#!/usr/bin/env bash
# trbatch.sh OUTDIR BIN:THREADS ... : traced runs; the caller holds the lock
out=$1; shift; mkdir -p $out; uptime > $out/uptime.txt
for spec in $@; do b=${spec%:*}; t=${spec##*:}; n=$(basename $b)
  PAR_TRACE_OUT=$out/$n.t$t.bin $b +RTS --threads $t --gpu off -RTS > $out/$n.t$t.out 2>&1; echo "$n $t rc=$?" >> $out/runs.txt; done
uptime >> $out/uptime.txt
