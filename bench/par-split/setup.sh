#!/usr/bin/env bash
# setup.sh: after a wipe of /private/tmp: tm, and the binaries of progs.txt for
# main, integ, exit (opt/par-exit-seq), sp (opt/par-split) and sp2 (sp with
# -DFK_CONT=1). W=/private/tmp/bend-opt/par/work. Heavy steps under the lock.
set -u
H=$(cd "$(dirname "$0")" && pwd); . $H/heavy.sh
P=/private/tmp/bend-opt/par
mkdir -p $P/work; touch /private/tmp/bend-opt/timing.lock
cc -O2 -o $P/tm $H/tm.c
for x in ${BUILDS:-integ:integ exit:exit split:sp main:main}; do
  d=${x%:*}; b=${x#*:}; [ -d $P/$d ] && $H/build.sh $P/$d $b
done
mkdir -p $P/work/bin/sp2
script=""
for n in $(awk '{print $1}' $P/work/bin/sp/.names); do
  [ -x $P/work/bin/sp2/$n ] || script+="~/Software/supgen-bend/limit 600 5120 cc -std=c11 -O3 -w -DFK_CONT=1 $P/work/bin/sp/$n.c -o $P/work/bin/sp2/$n -lpthread;"$'\n'
done
[ -n "$script" ] && lockf /private/tmp/bend-opt/timing.lock bash -c "$script"
cp $P/work/bin/sp/.names $P/work/bin/sp2/
