#!/usr/bin/env bash
# build.sh CHECKOUT TAG [progs file] -> W/bin/TAG/<name>{.c,} and .names; CFLAGS_EXTRA for cc.
# Emits and cc's run one at a time, in batches of 9 programs per hold of the shared lock, each
# step capped at 5120 MB (bun with BUN_JSC_forceRAMSize).
set -u
H=$(cd "$(dirname "$0")" && pwd)
root=$1; tag=$2; list=${3:-$H/progs.txt}
B=/Users/macolas/Software/bend-benchmarks
out=/private/tmp/bend-opt/par/work/bin/$tag; mkdir -p $out
until [ -x ~/Software/supgen-bend/limit ]; do sleep 1; done
todo=$(mktemp); : > $todo
while read n p; do
  case $p in /*) src=$p;; *) src=$B/$p;; esac
  echo "$n $p" >> $out/.names
  if [ -n "${FORCE:-}" ] || [ ! -x $out/$n ]; then echo "$n $src" >> $todo; fi
done < $list
sort -u $out/.names -o $out/.names
split -l 9 $todo $todo.part.
for part in $todo.part.*; do
  [ -s $part ] || continue
  script=""
  while read n src; do
    script+="BUN_JSC_forceRAMSize=3000000000 ~/Software/supgen-bend/limit 600 5120 bun $root/bend2/main.ts $src -o $out/$n.c > $out/$n.log 2>&1 && ~/Software/supgen-bend/limit 600 5120 cc -std=c11 -O3 -w $out/$n.c -o $out/$n -lpthread ${CFLAGS_EXTRA:-} >> $out/$n.log 2>&1 || echo 'FAIL $n';"$'\n'
  done < $part
  lockf /private/tmp/bend-opt/timing.lock bash -c "$script"
done
rm -f $todo $todo.part.*
