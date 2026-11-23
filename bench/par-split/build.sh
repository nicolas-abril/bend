#!/usr/bin/env bash
# build.sh CHECKOUT TAG [progs file] -> W/bin/TAG/<name>{.c,} and .names; CFLAGS_EXTRA for cc.
# Every emit and cc runs alone under the shared lock, capped at 5120 MB.
set -u
H=$(cd "$(dirname "$0")" && pwd)
root=$1; tag=$2; list=${3:-$H/progs.txt}
B=/Users/macolas/Software/bend-benchmarks
out=/private/tmp/bend-opt/par/work/bin/$tag; mkdir -p $out
. $H/heavy.sh
while read n p; do
  case $p in /*) src=$p;; *) src=$B/$p;; esac
  if [ -n "${FORCE:-}" ] || [ ! -x $out/$n ]; then
    heavy 600 bun $root/bend2/main.ts $src -o $out/$n.c > $out/$n.log 2>&1 || { echo "EMIT FAIL $n"; continue; }
    heavy 600 cc -std=c11 -O3 -w $out/$n.c -o $out/$n -lpthread ${CFLAGS_EXTRA:-} >> $out/$n.log 2>&1 || echo "CC FAIL $n"
  fi
  echo "$n $p" >> $out/.names
done < $list
sort -u $out/.names -o $out/.names
