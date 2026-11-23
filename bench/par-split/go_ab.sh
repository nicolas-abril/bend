#!/usr/bin/env bash
# go_ab.sh OUT BUILDS THREADS ROUNDS PROG...: one program at a time through scal.py, results pushed after each
H=$(cd "$(dirname "$0")" && pwd); W=/private/tmp/bend-opt/par/work
out=$1; builds=$2; th=$3; rounds=$4; shift 4
for p in "$@"; do
  python3 -I $H/scal.py $W/$out --builds $builds --progs $p --threads $th --rounds $rounds >> $W/${out%.jsonl}.log 2>&1
  $H/save.sh > /dev/null 2>&1
done
echo ALLDONE >> $W/${out%.jsonl}.log
