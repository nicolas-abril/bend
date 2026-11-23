#!/usr/bin/env bash
# setup.sh: after a wipe of /private/tmp: tm, and the binaries of progs.txt for
# main, integ, exit (opt/par-exit-seq) and sp (opt/par-split).
# W=/private/tmp/bend-opt/par/work. Heavy steps through tools/heavy.sh.
set -u
H=$(cd "$(dirname "$0")" && pwd)
P=/private/tmp/bend-opt/par
mkdir -p $P/work; touch /private/tmp/bend-opt/timing.lock
cc -O2 -o $P/tm $H/tm.c
for x in ${BUILDS:-integ:integ exit:exit split:sp main:main}; do
  d=${x%:*}; b=${x#*:}; [ -d $P/$d ] && $H/build.sh $P/$d $b
done
