#!/bin/sh
# emit_pair.sh SRC: emits SRC with main and with opt/queens; prints "same|diff|fail SRC"
s=$1
k=$(echo "$s" | sed 's|/|__|g')
a=/private/tmp/bend-opt/pq-work/reach/$TAG/a/$k.c
b=/private/tmp/bend-opt/pq-work/reach/$TAG/b/$k.c
timeout 120 bun $RA/bend2/main.ts "$s" -o $a > /dev/null 2>&1; ra=$?
timeout 120 bun $RB/bend2/main.ts "$s" -o $b > /dev/null 2>&1; rb=$?
if [ $ra -ne 0 ] || [ $rb -ne 0 ]; then echo "fail $ra $rb $s"; elif cmp -s $a $b; then echo "same $s"; rm -f $a $b; else echo "diff $s"; fi
