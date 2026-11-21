#!/bin/bash
# emit_diff.sh PROGS OUT: emit each program's C with the base and branch
# compilers; list those whose C differs
P=$1; O=$2; mkdir -p $O
while read n f; do
  bun /private/tmp/bend-opt/rep-base/bend2/main.ts $f -o $O/${n}_base.c >/dev/null 2>&1
  bun /private/tmp/bend-opt/rep/bend2/main.ts $f -o $O/${n}_new.c >/dev/null 2>&1
  cmp -s $O/${n}_base.c $O/${n}_new.c && echo "same $n" || echo "DIFF $n"
done < $P
