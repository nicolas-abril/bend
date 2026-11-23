#!/usr/bin/env bash
# build.sh CHECKOUT TAG [progs file] -> W/bin/TAG/<name>{.c,} and .names; CFLAGS_EXTRA for cc
set -u
H=$(cd "$(dirname "$0")" && pwd)
root=$1; tag=$2; list=${3:-$H/progs.txt}
B=/Users/macolas/Software/bend-benchmarks
out=/private/tmp/bend-opt/par/work/bin/$tag; mkdir -p $out
lim() { until [ -x ~/Software/supgen-bend/limit ]; do sleep 1; done; ~/Software/supgen-bend/limit "$@"; }
while read n p; do
  case $p in /*) src=$p;; *) src=$B/$p;; esac
  if [ -n "${FORCE:-}" ] || [ ! -x $out/$n ]; then
    lim 600 6144 bun $root/bend2/main.ts $src -o $out/$n.c > $out/$n.log 2>&1 || { echo "EMIT FAIL $n"; continue; }
    lim 600 6144 cc -std=c11 -O3 -w $out/$n.c -o $out/$n -lpthread ${CFLAGS_EXTRA:-} >> $out/$n.log 2>&1 || echo "CC FAIL $n"
  fi
  echo "$n $p" >> $out/.names
done < $list
sort -u $out/.names -o $out/.names
