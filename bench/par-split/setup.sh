#!/usr/bin/env bash
# setup.sh: after a wipe of /private/tmp: worktrees, tm, and the binaries of
# progs.txt for main, integ, exit (opt/par-exit-seq), sp (opt/par-split) and
# sp2 (sp with -DFK_CONT=1). Results go to W=/private/tmp/bend-opt/par/work.
set -u
H=$(cd "$(dirname "$0")" && pwd)
R=/Users/macolas/Software/bend2-core; P=/private/tmp/bend-opt/par
mkdir -p $P/work; touch /private/tmp/bend-opt/timing.lock
cc -O2 -o $P/tm $H/tm.c
for b in main integ exit sp; do
  case $b in main) d=main;; integ) d=integ;; exit) d=exit;; sp) d=split;; esac
  [ -d $P/$d ] && $H/build.sh $P/$d $b
done
mkdir -p $P/work/bin/sp2
for n in $(awk '{print $1}' $P/work/bin/sp/.names); do
  [ -x $P/work/bin/sp2/$n ] || cc -std=c11 -O3 -w -DFK_CONT=1 $P/work/bin/sp/$n.c -o $P/work/bin/sp2/$n -lpthread
done
cp $P/work/bin/sp/.names $P/work/bin/sp2/
